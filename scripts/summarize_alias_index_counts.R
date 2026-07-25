#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)
alias_dir <- if (length(args) >= 1L) args[[1L]] else file.path("data", "alias_index")

metadata_files <- list.files(
  alias_dir,
  pattern = "\\.metadata\\.json$",
  full.names = TRUE
)

if (!length(metadata_files)) {
  stop("No metadata JSON files found in: ", alias_dir)
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

read_one <- function(path) {
  x <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE), error = function(e) list())
  counts <- x$source_counts %||% list()
  data.frame(
    organism_id = as.character(x$organism_id %||% sub("\\.metadata\\.json$", "", basename(path))),
    organism_name = as.character(x$organism_name %||% ""),
    taxid = as.character(x$taxid %||% ""),
    n_alias_terms = suppressWarnings(as.integer(x$n_alias_terms %||% NA_integer_)),
    gff_rows = suppressWarnings(as.integer(counts$GFF %||% 0L)),
    ncbi_rows = suppressWarnings(as.integer(sum(unlist(counts[grepl("^NCBI", names(counts))]), na.rm = TRUE))),
    biomart_rows = suppressWarnings(as.integer(sum(unlist(counts[grepl("^BioMart", names(counts))]), na.rm = TRUE))),
    generated_at = as.character(x$generated_at %||% ""),
    build_status = as.character(x$build_status %||% ""),
    file = basename(path),
    stringsAsFactors = FALSE
  )
}

out <- do.call(rbind, lapply(metadata_files, read_one))
out <- out[order(out$organism_name, out$organism_id), , drop = FALSE]
write.table(out, stdout(), sep = "\t", quote = FALSE, row.names = FALSE, na = "")
