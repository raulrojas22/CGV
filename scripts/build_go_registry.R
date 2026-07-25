#!/usr/bin/env Rscript

suppressWarnings({
  args <- commandArgs(trailingOnly = TRUE)
})

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0) {
    return(default)
  }
  sub(prefix, "", hit[1], fixed = TRUE)
}

has_flag <- function(name) {
  paste0("--", name) %in% args
}

safe_chr <- function(x) {
  out <- as.character(x %||% "")
  out[is.na(out)] <- ""
  out
}

`%||%` <- function(a, b) if (!is.null(a)) a else b

if (has_flag("help")) {
  cat(
    "Usage:\n",
    "  Rscript scripts/build_go_registry.R [--root=PATH] [--go-dir=DIR] [--annotations-registry=PATH] [--out=PATH] [--write]\n\n",
    "Defaults:\n",
    "  --root=. --go-dir=go_annotations/raw --annotations-registry=annotations/registry.tsv --out=go_annotations/registry.tsv\n\n",
    "Behavior:\n",
    "  - Scans .gaf/.gaf.gz files.\n",
    "  - Matches each file to a preloaded organism using GCF accession, taxon, or source alias.\n",
    "  - Writes a GO registry TSV when --write is provided.\n",
    "  - Without --write, prints a dry-run preview.\n",
    sep = ""
  )
  quit(save = "no", status = 0)
}

get_script_file <- function() {
  full_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- full_args[startsWith(full_args, "--file=")]
  if (length(file_arg) == 0) {
    return("")
  }
  sub("^--file=", "", file_arg[1], perl = TRUE)
}

default_project_root <- function() {
  sf <- get_script_file()
  if (!nzchar(sf)) {
    return(normalizePath(".", winslash = "/", mustWork = FALSE))
  }
  normalizePath(file.path(dirname(sf), ".."), winslash = "/", mustWork = FALSE)
}

is_abs_path <- function(p) {
  x <- safe_chr(p)[1]
  nzchar(x) && (grepl("^/", x) || grepl("^[A-Za-z]:[/\\\\]", x))
}

resolve_path <- function(root_dir, p) {
  x <- safe_chr(p)[1]
  if (!nzchar(x)) {
    return(normalizePath(root_dir, winslash = "/", mustWork = FALSE))
  }
  if (is_abs_path(x)) {
    return(normalizePath(x, winslash = "/", mustWork = FALSE))
  }
  normalizePath(file.path(root_dir, x), winslash = "/", mustWork = FALSE)
}

root <- normalizePath(arg_value("root", default_project_root()), winslash = "/", mustWork = FALSE)
go_dir_rel <- arg_value("go-dir", file.path("go_annotations", "raw"))
ann_registry_rel <- arg_value("annotations-registry", file.path("annotations", "registry.tsv"))
out_rel <- arg_value("out", file.path("go_annotations", "registry.tsv"))
write_mode <- has_flag("write")

go_dir <- resolve_path(root, go_dir_rel)
ann_registry_path <- resolve_path(root, ann_registry_rel)
out_path <- resolve_path(root, out_rel)
existing_registry <- if (file.exists(out_path)) {
  tryCatch(read.delim(out_path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE), error = function(e) data.frame())
} else {
  data.frame()
}

rel_path <- function(abs_path, root_path) {
  ap <- normalizePath(abs_path, winslash = "/", mustWork = FALSE)
  rp <- normalizePath(root_path, winslash = "/", mustWork = FALSE)
  pref <- paste0(rp, "/")
  if (startsWith(ap, pref)) {
    return(sub(pref, "", ap, fixed = TRUE))
  }
  ap
}

to_key <- function(x) {
  y <- tolower(safe_chr(x))
  y <- gsub("[^a-z0-9]+", " ", y)
  y <- gsub("\\s+", " ", y)
  trimws(y)
}

extract_gcf_accession <- function(x) {
  s <- safe_chr(x)[1]
  m <- regexpr("GCF_[0-9]+\\.[0-9]+", s, perl = TRUE, ignore.case = TRUE)
  if (m[1] <= 0) {
    return("")
  }
  toupper(substr(s, m[1], m[1] + attr(m, "match.length")[1] - 1))
}

extract_header_value <- function(lines, key) {
  pat <- paste0("^!", key, ":\\s*(.+)$")
  hits <- grep(pat, lines, ignore.case = TRUE, value = TRUE, perl = TRUE)
  if (length(hits) == 0) {
    return("")
  }
  sub(pat, "\\1", hits[1], ignore.case = TRUE, perl = TRUE)
}

scan_gaf_file <- function(path) {
  con <- if (grepl("\\.gz$", path, ignore.case = TRUE)) gzfile(path, open = "rt") else file(path, open = "rt")
  on.exit(close(con), add = TRUE)

  lines <- tryCatch(readLines(con, n = 800, warn = FALSE), error = function(e) character(0))
  lines <- enc2utf8(lines)
  lines <- lines[nzchar(trimws(lines))]

  header <- lines[startsWith(lines, "!")]
  data_lines <- lines[!startsWith(lines, "!")]
  data_lines <- data_lines[nzchar(trimws(data_lines))]

  db_ns <- ""
  taxon <- NA_integer_
  for (ln in data_lines[seq_len(min(length(data_lines), 50L))]) {
    fields <- strsplit(ln, "\t", fixed = TRUE)[[1]]
    if (!nzchar(db_ns) && length(fields) >= 1L) {
      db_ns <- safe_chr(fields[1])[1]
    }
    if (is.na(taxon) && length(fields) >= 13L) {
      tx <- safe_chr(fields[13])[1]
      hit <- regmatches(tx, regexpr("taxon:[0-9]+", tx, perl = TRUE))
      if (length(hit) > 0 && nzchar(hit[1])) {
        taxon <- suppressWarnings(as.integer(sub("taxon:", "", hit[1], fixed = TRUE)))
      }
    }
    if (nzchar(db_ns) && !is.na(taxon)) {
      break
    }
  }

  list(
    generated_by = safe_chr(extract_header_value(header, "generated-by"))[1],
    date_generated = safe_chr(extract_header_value(header, "date-generated"))[1],
    db_namespace = db_ns,
    taxon = taxon
  )
}

source_from_file <- function(file_name, generated_by) {
  fn <- tolower(file_name)
  gb <- tolower(safe_chr(generated_by)[1])
  if (grepl("^gcf_[0-9]+\\.[0-9]+.*_gene_ontology\\.gaf(\\.gz)?$", fn, perl = TRUE)) {
    return("NCBI")
  }
  if (grepl("ncbi", gb, fixed = TRUE)) {
    return("NCBI")
  }
  "GO"
}

taxid_overrides <- c(
  "4932" = "559292",  # S. cerevisiae species -> S288C strain in preloaded registry
  "5476" = "237561"   # C. albicans species -> SC5314 strain in preloaded registry
)

apply_taxid_override <- function(taxid_val) {
  t0 <- suppressWarnings(as.integer(taxid_val))
  if (is.na(t0)) {
    return(NA_integer_)
  }
  key <- as.character(t0)
  if (key %in% names(taxid_overrides)) {
    return(suppressWarnings(as.integer(taxid_overrides[[key]])))
  }
  t0
}

choose_best_idx <- function(idx, ann) {
  if (length(idx) <= 1L) {
    return(idx)
  }
  # Stable and deterministic: prioritize lowest species_id lexicographically.
  ids <- safe_chr(ann$species_id[idx])
  idx[order(ids)][1]
}

match_by_filename_alias <- function(stem, ann) {
  stem_l <- tolower(stem)
  alias_map <- list(
    "fb" = c("drosophila melanogaster", "drosophila", "fruit fly"),
    "zfin" = c("danio rerio", "zebrafish"),
    "mgi" = c("mus musculus", "mouse"),
    "wb" = c("caenorhabditis elegans", "c elegans", "nematode"),
    "sgd" = c("saccharomyces cerevisiae", "yeast"),
    "tair" = c("arabidopsis thaliana", "arabidopsis"),
    "xenbase" = c("xenopus laevis", "xenopus"),
    "cgd" = c("candida albicans", "candida"),
    "goa_human" = c("homo sapiens", "human"),
    "goa_dog" = c("canis lupus familiaris", "dog", "canine"),
    "goa_pig" = c("sus scrofa", "pig")
  )

  wanted <- alias_map[[stem_l]]
  if (is.null(wanted)) {
    return(integer(0))
  }

  ann_keys <- tolower(paste(
    safe_chr(ann$species_id),
    safe_chr(ann$organism),
    safe_chr(ann$aliases),
    sep = " | "
  ))
  hit <- integer(0)
  for (token in wanted) {
    h <- which(grepl(token, ann_keys, fixed = TRUE))
    if (length(h) > 0) {
      hit <- c(hit, h)
    }
  }
  unique(hit)
}

if (!file.exists(ann_registry_path)) {
  stop("Annotations registry not found: ", ann_registry_path)
}

ann <- tryCatch(
  read.delim(ann_registry_path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE),
  error = function(e) data.frame(stringsAsFactors = FALSE)
)
if (nrow(ann) == 0) {
  stop("Annotations registry is empty: ", ann_registry_path)
}

for (nm in setdiff(c("species_id", "organism", "taxid", "aliases", "annotation"), colnames(ann))) {
  ann[[nm]] <- NA_character_
}
ann$taxid <- suppressWarnings(as.integer(ann$taxid))
ann$gcf_accession <- vapply(safe_chr(ann$annotation), extract_gcf_accession, character(1))
ann$species_id <- safe_chr(ann$species_id)
ann$organism <- safe_chr(ann$organism)
ann$aliases <- safe_chr(ann$aliases)

if (!dir.exists(go_dir)) {
  if (!write_mode) {
    cat("GO directory does not exist (dry-run): ", go_dir, "\n", sep = "")
    quit(save = "no", status = 0)
  }
  dir.create(go_dir, recursive = TRUE, showWarnings = FALSE)
}

gaf_files <- list.files(
  go_dir,
  pattern = "\\.gaf(\\.gz)?$",
  full.names = TRUE,
  recursive = TRUE,
  ignore.case = TRUE
)
gaf_files <- sort(unique(gaf_files))

if (length(gaf_files) == 0) {
  cat("No .gaf/.gaf.gz files found in: ", go_dir, "\n", sep = "")
  if (write_mode) {
    dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
    write.table(
      data.frame(
        species_id = character(),
        organism = character(),
        taxid = integer(),
        source = character(),
        db_namespace = character(),
        gaf_file = character(),
        file_name = character(),
        gcf_accession = character(),
        taxon_from_gaf = integer(),
        match_method = character(),
        generated_by = character(),
        date_generated = character(),
        priority = integer(),
        is_primary = logical(),
        index_file = character(),
        index_schema_version = integer(),
        index_fingerprint = character(),
        notes = character(),
        stringsAsFactors = FALSE
      ),
      file = out_path,
      sep = "\t",
      row.names = FALSE,
      quote = FALSE,
      na = ""
    )
    cat("Wrote empty registry: ", out_path, "\n", sep = "")
  }
  quit(save = "no", status = 0)
}

rows <- lapply(gaf_files, function(path) {
  fbase <- basename(path)
  fstem <- sub("\\.gaf(\\.gz)?$", "", fbase, ignore.case = TRUE)
  gcf <- extract_gcf_accession(fbase)
  parsed <- scan_gaf_file(path)
  src <- source_from_file(fbase, parsed$generated_by)
  tax_raw <- suppressWarnings(as.integer(parsed$taxon))
  tax_eff <- apply_taxid_override(tax_raw)

  match_idx <- integer(0)
  method <- ""

  if (nzchar(gcf)) {
    match_idx <- which(ann$gcf_accession == gcf)
    if (length(match_idx) > 0) {
      method <- "gcf_accession"
    }
  }

  if (length(match_idx) == 0 && !is.na(tax_eff)) {
    match_idx <- which(as.character(ann$taxid) == as.character(tax_eff))
    if (length(match_idx) > 0) {
      method <- if (identical(tax_eff, tax_raw)) "taxid" else "taxid_override"
    }
  }

  if (length(match_idx) == 0) {
    match_idx <- match_by_filename_alias(fstem, ann)
    if (length(match_idx) > 0) {
      method <- "filename_alias"
    }
  }

  selected <- choose_best_idx(match_idx, ann)
  has_match <- length(selected) > 0
  sid <- if (has_match) ann$species_id[selected] else ""
  org <- if (has_match) ann$organism[selected] else ""
  tid <- if (has_match) ann$taxid[selected] else NA_integer_
  note <- if (!has_match) "No match found in annotations/registry.tsv" else ""

  prio <- if (identical(src, "NCBI")) 10L else 20L
  if (identical(method, "filename_alias")) prio <- prio + 5L
  if (!has_match) prio <- 999L

  rel_gaf <- rel_path(path, root)
  old_hit <- if (nrow(existing_registry) > 0L && "gaf_file" %in% names(existing_registry)) {
    which(as.character(existing_registry$gaf_file) == rel_gaf)[1]
  } else {
    NA_integer_
  }
  old_value <- function(column, fallback = "") {
    if (!is.finite(old_hit) || is.na(old_hit) || !column %in% names(existing_registry)) return(fallback)
    value <- safe_chr(existing_registry[[column]][old_hit])[1]
    if (is.na(value) || identical(toupper(trimws(value)), "NA")) return(fallback)
    value
  }

  data.frame(
    species_id = safe_chr(sid),
    organism = safe_chr(org),
    taxid = suppressWarnings(as.integer(tid)),
    source = safe_chr(src),
    db_namespace = safe_chr(parsed$db_namespace),
    gaf_file = rel_gaf,
    file_name = safe_chr(fbase),
    gcf_accession = safe_chr(gcf),
    taxon_from_gaf = suppressWarnings(as.integer(tax_raw)),
    match_method = safe_chr(method),
    generated_by = safe_chr(parsed$generated_by),
    date_generated = safe_chr(parsed$date_generated),
    priority = prio,
    is_primary = FALSE,
    index_file = old_value("index_file"),
    index_schema_version = suppressWarnings(as.integer(old_value("index_schema_version", NA_character_))),
    index_fingerprint = old_value("index_fingerprint"),
    notes = safe_chr(note),
    stringsAsFactors = FALSE
  )
})

out <- do.call(rbind, rows)
if (nrow(out) == 0) {
  out <- data.frame(
    species_id = character(),
    organism = character(),
    taxid = integer(),
    source = character(),
    db_namespace = character(),
    gaf_file = character(),
    file_name = character(),
    gcf_accession = character(),
    taxon_from_gaf = integer(),
    match_method = character(),
    generated_by = character(),
    date_generated = character(),
    priority = integer(),
    is_primary = logical(),
    index_file = character(),
    index_schema_version = integer(),
    index_fingerprint = character(),
    notes = character(),
    stringsAsFactors = FALSE
  )
}

if (nrow(out) > 0) {
  by_species <- split(seq_len(nrow(out)), out$species_id)
  for (sid in names(by_species)) {
    if (!nzchar(sid)) {
      next
    }
    idx <- by_species[[sid]]
    best <- idx[order(out$priority[idx], out$file_name[idx])][1]
    out$is_primary[best] <- TRUE
  }
}

out <- out[order(out$priority, out$species_id, out$file_name), , drop = FALSE]
row.names(out) <- NULL

if (write_mode) {
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  write.table(out, file = out_path, sep = "\t", row.names = FALSE, quote = FALSE, na = "")
  cat("Wrote GO registry: ", out_path, "\n", sep = "")
} else {
  cat("Dry-run preview (top 30 rows):\n")
  print(utils::head(out, 30))
  cat("\nUse --write to save the registry to: ", out_path, "\n", sep = "")
}
