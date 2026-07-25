#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = "") {
    prefix <- paste0("--", name, "=")
    hit <- args[startsWith(args, prefix)]
    if (length(hit) == 0L) return(default)
    sub(prefix, "", hit[1], fixed = TRUE)
}

has_flag <- function(name) paste0("--", name) %in% args

if (has_flag("help")) {
    cat(
        "Usage:\n",
        "  Rscript scripts/build_gaf_index.R --root=. --all [--out-dir=go_annotations/index] [--force]\n",
        "  Rscript scripts/build_gaf_index.R --root=. --gaf=PATH [--out=PATH | --out-dir=DIR] [--force]\n\n",
        "Building all indexes also updates index_file, index_schema_version, and index_fingerprint in the GO registry.\n",
        sep = ""
    )
    quit(save = "no", status = 0L)
}

script_path <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))[1]])
root_default <- if (length(script_path) && nzchar(script_path)) dirname(dirname(normalizePath(script_path))) else normalizePath(".")
root <- normalizePath(arg_value("root", root_default), winslash = "/", mustWork = FALSE)
resolve_from_root <- function(value) {
    txt <- if (is.null(value)) "" else as.character(value)
    if (grepl("^/", txt) || grepl("^[A-Za-z]:[/\\\\]", txt)) {
        return(normalizePath(txt, winslash = "/", mustWork = FALSE))
    }
    normalizePath(file.path(root, txt), winslash = "/", mustWork = FALSE)
}
registry_path <- resolve_from_root(arg_value("registry", file.path("go_annotations", "registry.tsv")))
out_dir <- resolve_from_root(arg_value("out-dir", file.path("go_annotations", "index")))
single_out <- arg_value("out", "")
single_gaf <- arg_value("gaf", "")
build_all <- has_flag("all") || !nzchar(single_gaf)
force <- has_flag("force")
write_registry <- has_flag("write-registry") || build_all

suppressPackageStartupMessages({
    library(dplyr)
    source(file.path(root, "R", "utils.R"))
    source(file.path(root, "R", "server_go_domain.R"))
})

if (!file.exists(registry_path)) stop("GO registry not found: ", registry_path)
registry <- read.delim(registry_path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
for (column in c("index_file", "index_schema_version", "index_fingerprint")) {
    if (!column %in% names(registry)) registry[[column]] <- ""
}

resolve_gaf <- function(value) {
    txt <- trimws(as.character(value %||% ""))
    if (!nzchar(txt)) return("")
    if (grepl("^/", txt) || grepl("^[A-Za-z]:[/\\\\]", txt)) {
        return(normalizePath(txt, winslash = "/", mustWork = FALSE))
    }
    normalizePath(file.path(root, txt), winslash = "/", mustWork = FALSE)
}

targets <- if (isTRUE(build_all)) {
    unique(vapply(registry$gaf_file, resolve_gaf, character(1)))
} else {
    resolve_gaf(single_gaf)
}
targets <- targets[nzchar(targets) & file.exists(targets)]
if (length(targets) == 0L) stop("No GAF files found to index.")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
failures <- character(0)
for (i in seq_along(targets)) {
    gaf <- targets[i]
    index_path <- if (!isTRUE(build_all) && nzchar(single_out)) {
        resolve_from_root(single_out)
    } else {
        go_index_default_path(gaf, root = out_dir)
    }
    cat(sprintf("[%d/%d] %s -> %s\n", i, length(targets), basename(gaf), basename(index_path)))
    result <- tryCatch(
        build_go_gaf_index(gaf, index_path, force = force),
        error = function(e) e
    )
    if (inherits(result, "error")) {
        failures <- c(failures, sprintf("%s: %s", basename(gaf), conditionMessage(result)))
        cat("  ERROR: ", conditionMessage(result), "\n", sep = "")
        next
    }
    fingerprint <- as.character(result$fingerprint %||% go_file_fingerprint(gaf))
    registry_gaf_abs <- vapply(registry$gaf_file, resolve_gaf, character(1))
    hit <- which(registry_gaf_abs == gaf)
    if (length(hit) > 0L) {
        rel_index <- if (startsWith(index_path, paste0(root, "/"))) {
            substring(index_path, nchar(root) + 2L)
        } else {
            index_path
        }
        registry$index_file[hit] <- rel_index
        registry$index_schema_version[hit] <- as.character(.go_index_schema_version)
        registry$index_fingerprint[hit] <- fingerprint
    }
    cat(sprintf(
        "  %s rows=%s fingerprint=%s\n",
        if (isTRUE(result$skipped)) "current" else "built",
        as.character(result$rows %||% go_index_metadata(index_path)$row_count %||% "?"),
        substr(fingerprint, 1L, 12L)
    ))
}

if (isTRUE(write_registry)) {
    write.table(
        registry,
        registry_path,
        sep = "\t",
        quote = FALSE,
        row.names = FALSE,
        na = ""
    )
    cat("Registry updated: ", registry_path, "\n", sep = "")
}

if (length(failures) > 0L) {
    cat(paste(failures, collapse = "\n"), "\n")
    quit(save = "no", status = 1L)
}
