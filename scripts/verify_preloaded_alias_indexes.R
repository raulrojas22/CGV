#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
root_arg <- grep("^--root=", args, value = TRUE)
root <- if (length(root_arg) > 0L) {
  sub("^--root=", "", root_arg[[1L]])
} else {
  "."
}
root <- normalizePath(root, winslash = "/", mustWork = TRUE)

registry_path <- file.path(root, "annotations", "registry.tsv")
if (!file.exists(registry_path) || file.info(registry_path)$size <= 0) {
  stop("Preloaded annotation registry is missing: ", registry_path, call. = FALSE)
}

registry <- read.delim(
  registry_path,
  sep = "\t",
  quote = "",
  comment.char = "",
  stringsAsFactors = FALSE,
  check.names = FALSE
)
if (!"species_id" %in% names(registry)) {
  stop("Preloaded annotation registry has no species_id column.", call. = FALSE)
}

species_ids <- unique(trimws(as.character(registry$species_id)))
species_ids <- species_ids[!is.na(species_ids) & nzchar(species_ids)]
alias_dir <- file.path(root, "data", "alias_index")

has_nonempty_file <- function(path) {
  file.exists(path) && isTRUE(file.info(path)$size > 0)
}
has_alias_index <- vapply(species_ids, function(species_id) {
  sqlite_path <- file.path(alias_dir, paste0(species_id, ".alias_index.sqlite"))
  legacy_path <- file.path(alias_dir, paste0(species_id, ".alias_index.tsv.gz"))
  has_nonempty_file(sqlite_path) || has_nonempty_file(legacy_path)
}, logical(1))

missing <- species_ids[!has_alias_index]
if (length(missing) > 0L) {
  preview_limit <- 5L
  missing_preview <- paste(utils::head(missing, preview_limit), collapse = ", ")
  if (length(missing) > preview_limit) {
    missing_preview <- paste0(
      missing_preview,
      sprintf(" (+%d more)", length(missing) - preview_limit)
    )
  }
  stop(
    paste0(
      "Preloaded alias indexes are missing for ",
      length(missing),
      " organism(s): ",
      missing_preview,
      ". Ensure the host data/ directory is mounted at /app/data."
    ),
    call. = FALSE
  )
}

cat(sprintf("preloaded-alias-index-mount-ok (%d organisms)\n", length(species_ids)))
