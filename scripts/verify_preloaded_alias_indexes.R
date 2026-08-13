#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
root_arg <- grep("^--root=", args, value = TRUE)
root <- if (length(root_arg) > 0L) {
  sub("^--root=", "", root_arg[[1L]])
} else {
  "."
}
root <- normalizePath(root, winslash = "/", mustWork = TRUE)

if (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("RSQLite", quietly = TRUE)) {
  stop("DBI and RSQLite are required to verify preloaded alias indexes.", call. = FALSE)
}

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
if (length(species_ids) == 0L) {
  stop("Preloaded annotation registry contains no usable species_id values.", call. = FALSE)
}
index_ids <- gsub("[^A-Za-z0-9._-]+", "_", species_ids)
if (anyDuplicated(index_ids)) {
  collisions <- unique(index_ids[duplicated(index_ids) | duplicated(index_ids, fromLast = TRUE)])
  stop(
    "Preloaded species_id values collide after filename normalization: ",
    paste(collisions, collapse = ", "),
    call. = FALSE
  )
}
alias_dir <- file.path(root, "data", "alias_index")

has_nonempty_file <- function(path) {
  file.exists(path) && isTRUE(file.info(path)$size > 0)
}

required_alias_columns <- c(
  "organism_id",
  "query_term_original",
  "query_term_upper",
  "query_term_clean_basic",
  "query_term_clean_strict",
  "term_type",
  "local_gene_id",
  "local_feature_id",
  "local_symbol",
  "confidence",
  "source_db"
)

sqlite_alias_index_status <- function(path) {
  if (!file.exists(path)) {
    return("missing")
  }
  size <- file.info(path)$size
  if (is.na(size) || size <= 0) {
    return("sqlite-empty-file")
  }
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), path, flags = RSQLite::SQLITE_RO)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    if (!"alias_index" %in% DBI::dbListTables(con)) {
      return("sqlite-missing-table")
    }
    missing_columns <- setdiff(required_alias_columns, DBI::dbListFields(con, "alias_index"))
    if (length(missing_columns) > 0L) {
      return("sqlite-missing-columns")
    }
    if (nrow(DBI::dbGetQuery(con, "SELECT 1 AS present FROM alias_index LIMIT 1")) == 0L) {
      return("sqlite-empty-table")
    }

    indexes <- DBI::dbGetQuery(con, "PRAGMA index_list('alias_index')")
    if (!"name" %in% names(indexes)) {
      return("sqlite-missing-exact-index")
    }
    exact_row <- indexes[as.character(indexes$name) == "idx_query_term_original", , drop = FALSE]
    if (nrow(exact_row) != 1L) {
      return("sqlite-missing-exact-index")
    }
    if ("partial" %in% names(exact_row) && !identical(as.integer(exact_row$partial), 0L)) {
      return("sqlite-partial-exact-index")
    }

    index_info <- DBI::dbGetQuery(con, "PRAGMA index_xinfo('idx_query_term_original')")
    if (!all(c("name", "key") %in% names(index_info))) {
      return("sqlite-invalid-exact-index")
    }
    key_columns <- index_info[as.integer(index_info$key) == 1L, , drop = FALSE]
    if (!identical(as.character(key_columns$name), "query_term_original")) {
      return("sqlite-invalid-exact-index")
    }
    if ("coll" %in% names(key_columns) &&
        !identical(toupper(as.character(key_columns$coll)), "BINARY")) {
      return("sqlite-invalid-exact-index")
    }
    if ("desc" %in% names(key_columns) && !identical(as.integer(key_columns$desc), 0L)) {
      return("sqlite-invalid-exact-index")
    }

    "sqlite"
  }, error = function(...) "sqlite-unreadable")
}

alias_index_status <- vapply(seq_along(species_ids), function(index) {
  index_id <- index_ids[[index]]
  sqlite_path <- file.path(alias_dir, paste0(index_id, ".alias_index.sqlite"))
  legacy_path <- file.path(alias_dir, paste0(index_id, ".alias_index.tsv.gz"))
  sqlite_status <- sqlite_alias_index_status(sqlite_path)
  if (identical(sqlite_status, "missing") && has_nonempty_file(legacy_path)) {
    "legacy"
  } else {
    sqlite_status
  }
}, character(1))

invalid <- species_ids[alias_index_status != "sqlite"]
if (length(invalid) > 0L) {
  preview_limit <- 5L
  invalid_preview <- paste(
    sprintf(
      "%s [%s]",
      utils::head(invalid, preview_limit),
      alias_index_status[match(utils::head(invalid, preview_limit), species_ids)]
    ),
    collapse = ", "
  )
  if (length(invalid) > preview_limit) {
    invalid_preview <- paste0(
      invalid_preview,
      sprintf(" (+%d more)", length(invalid) - preview_limit)
    )
  }
  stop(
    paste0(
      "Preloaded alias indexes are missing or incomplete for ",
      length(invalid),
      " organism(s): ",
      invalid_preview,
      ". Every preloaded organism requires a non-empty SQLite alias table and ",
      "idx_query_term_original on query_term_original. Run ",
      "scripts/build_alias_index_sqlite.R before mounting data read-only."
    ),
    call. = FALSE
  )
}

cat(sprintf(
  "preloaded-alias-index-mount-ok (%d organisms; %d sqlite)\n",
  length(species_ids),
  sum(alias_index_status == "sqlite")
))
