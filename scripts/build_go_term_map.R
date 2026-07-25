#!/usr/bin/env Rscript

suppressWarnings({
  args <- commandArgs(trailingOnly = TRUE)
})

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0) return(default)
  sub(prefix, "", hit[1], fixed = TRUE)
}

has_flag <- function(name) {
  paste0("--", name) %in% args
}

if (has_flag("help")) {
  cat(
    "Usage:\n",
    "  Rscript scripts/build_go_term_map.R [--obo=PATH] [--out=PATH] [--obo-url=URL] [--download]\n\n",
    "Defaults:\n",
    "  --obo=go_annotations/go-basic.obo\n",
    "  --out=go_annotations/go_term_map.rds\n",
    "  --obo-url=https://current.geneontology.org/ontology/go-basic.obo\n\n",
    "Options:\n",
    "  --download    Download OBO automatically if missing\n",
    sep = ""
  )
  quit(save = "no", status = 0)
}

obo_rel <- arg_value("obo", file.path("go_annotations", "go-basic.obo"))
out_rel <- arg_value("out", file.path("go_annotations", "go_term_map.rds"))
obo_url <- arg_value("obo-url", "https://current.geneontology.org/ontology/go-basic.obo")
download_missing <- has_flag("download")

get_script_file <- function() {
  full_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- full_args[startsWith(full_args, "--file=")]
  if (length(file_arg) == 0) return("")
  sub("^--file=", "", file_arg[1], perl = TRUE)
}

default_project_root <- function() {
  sf <- get_script_file()
  if (!nzchar(sf)) return(normalizePath(".", winslash = "/", mustWork = FALSE))
  normalizePath(file.path(dirname(sf), ".."), winslash = "/", mustWork = FALSE)
}

root <- normalizePath(arg_value("root", default_project_root()), winslash = "/", mustWork = FALSE)

resolve_path <- function(root_dir, p) {
  x <- as.character(p %||% "")
  if (grepl("^/", x) || grepl("^[A-Za-z]:[/\\\\]", x)) {
    return(normalizePath(x, winslash = "/", mustWork = FALSE))
  }
  normalizePath(file.path(root_dir, x), winslash = "/", mustWork = FALSE)
}

`%||%` <- function(a, b) if (!is.null(a)) a else b

obo_path <- resolve_path(root, obo_rel)
out_path <- resolve_path(root, out_rel)

if (!file.exists(obo_path)) {
  if (isTRUE(download_missing)) {
    dir.create(dirname(obo_path), recursive = TRUE, showWarnings = FALSE)
    ok <- tryCatch(
      {
        utils::download.file(obo_url, obo_path, mode = "wb", quiet = TRUE)
        file.exists(obo_path)
      },
      error = function(e) FALSE
    )
    if (!isTRUE(ok)) {
      stop(
        "OBO file not found and download failed.\n",
        "Expected path: ", obo_path, "\n",
        "Tried URL: ", obo_url
      )
    }
    cat("Downloaded OBO:", obo_path, "\n")
  } else {
    stop(
      "OBO file not found: ", obo_path, "\n",
      "Download from: ", obo_url, "\n",
      "Example:\n",
      "  curl -L \"", obo_url, "\" -o \"", obo_path, "\"\n",
      "Or rerun with:\n",
      "  Rscript scripts/build_go_term_map.R --download\n"
    )
  }
}

parse_go_map <- function(path) {
  con <- if (grepl("\\.gz$", path, ignore.case = TRUE)) gzfile(path, open = "rt") else file(path, open = "rt")
  on.exit(close(con), add = TRUE)

  out <- character(0)
  current_id <- ""
  current_name <- ""
  current_obsolete <- FALSE
  in_term <- FALSE

  flush_term <- function() {
    if (isTRUE(in_term) && nzchar(current_id) && nzchar(current_name) && !isTRUE(current_obsolete)) {
      out[current_id] <<- current_name
    }
    current_id <<- ""
    current_name <<- ""
    current_obsolete <<- FALSE
    in_term <<- FALSE
  }

  repeat {
    lines <- readLines(con, n = 60000L, warn = FALSE)
    if (length(lines) == 0) break
    for (ln in lines) {
      line <- trimws(as.character(ln %||% ""))
      if (!nzchar(line) || startsWith(line, "!")) next
      if (identical(line, "[Term]")) {
        flush_term()
        in_term <- TRUE
        next
      }
      if (startsWith(line, "[")) {
        flush_term()
        next
      }
      if (!isTRUE(in_term)) next

      if (startsWith(line, "id: GO:")) {
        current_id <- trimws(sub("^id:\\s*", "", line, perl = TRUE))
      } else if (startsWith(line, "name:")) {
        if (!nzchar(current_name)) current_name <- trimws(sub("^name:\\s*", "", line, perl = TRUE))
      } else if (startsWith(line, "is_obsolete:")) {
        current_obsolete <- identical(tolower(trimws(sub("^is_obsolete:\\s*", "", line, perl = TRUE))), "true")
      }
    }
  }
  flush_term()
  out
}

map <- parse_go_map(obo_path)
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)

obo_mtime <- suppressWarnings(as.numeric(file.info(obo_path)$mtime[1]))
obo_fingerprint <- if (requireNamespace("digest", quietly = TRUE)) {
  digest::digest(file = obo_path, algo = "sha256")
} else {
  paste(as.character(file.info(obo_path)$size[1]), as.character(obo_mtime), sep = "-")
}
saveRDS(
  list(
    schema_version = 2L,
    source_file = obo_path,
    source_mtime = obo_mtime,
    source_fingerprint = obo_fingerprint,
    map = map
  ),
  file = out_path
)

cat("GO term map saved:", out_path, "\n")
cat("Terms:", length(map), "\n")
cat("Fingerprint:", obo_fingerprint, "\n")
