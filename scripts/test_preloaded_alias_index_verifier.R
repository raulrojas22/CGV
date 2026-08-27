#!/usr/bin/env Rscript

if (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("RSQLite", quietly = TRUE)) {
  stop("DBI and RSQLite are required for this test.", call. = FALSE)
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- if (length(script_arg) > 0L) {
  sub("^--file=", "", script_arg[[1L]])
} else {
  file.path("scripts", "test_preloaded_alias_index_verifier.R")
}
repo_root <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
verifier <- file.path(repo_root, "scripts", "verify_preloaded_alias_indexes.R")
fixture_root <- tempfile("alias-verifier-")
annotations_dir <- file.path(fixture_root, "annotations")
alias_dir <- file.path(fixture_root, "data", "alias_index")
dir.create(annotations_dir, recursive = TRUE)
dir.create(alias_dir, recursive = TRUE)
on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE), add = TRUE)

write_registry <- function(species_ids) {
  writeLines(
    c("species_id\tlabel", paste(species_ids, species_ids, sep = "\t")),
    file.path(annotations_dir, "registry.tsv")
  )
}

run_verifier <- function(expect_success, expected_text = NULL) {
  output <- suppressWarnings(
    system2(
      file.path(R.home("bin"), "Rscript"),
      c(verifier, paste0("--root=", fixture_root)),
      stdout = TRUE,
      stderr = TRUE
    )
  )
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  if (expect_success && status != 0L) {
    stop("Verifier unexpectedly failed:\n", paste(output, collapse = "\n"), call. = FALSE)
  }
  if (!expect_success && status == 0L) {
    stop("Verifier unexpectedly accepted an invalid alias index.", call. = FALSE)
  }
  if (!is.null(expected_text) && !any(grepl(expected_text, output, fixed = TRUE))) {
    stop(
      "Verifier output did not contain '", expected_text, "':\n",
      paste(output, collapse = "\n"),
      call. = FALSE
    )
  }
  invisible(output)
}

sqlite_path_for <- function(species_id) {
  safe_id <- gsub("[^A-Za-z0-9._-]+", "_", species_id)
  file.path(alias_dir, paste0(safe_id, ".alias_index.sqlite"))
}

create_alias_table <- function(path, include_all_columns = TRUE, insert_row = FALSE) {
  if (file.exists(path)) unlink(path, force = TRUE)
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  columns <- c(
    "organism_id TEXT",
    "query_term_original TEXT",
    "query_term_upper TEXT",
    "query_term_clean_basic TEXT",
    "query_term_clean_strict TEXT",
    "term_type TEXT",
    "local_gene_id TEXT",
    "local_feature_id TEXT",
    "local_symbol TEXT",
    "confidence TEXT",
    "source_db TEXT"
  )
  if (!include_all_columns) columns <- columns[columns != "query_term_clean_strict TEXT"]
  DBI::dbExecute(con, paste0("CREATE TABLE alias_index (", paste(columns, collapse = ", "), ")"))
  if (insert_row) {
    values <- setNames(
      as.list(c("fixture_species", "ABC1", "ABC1", "ABC1", "ABC1", "symbol", "gene-1", "gene-1", "ABC1", "HIGH", "NCBI")),
      sub(" TEXT$", "", columns)
    )
    DBI::dbAppendTable(con, "alias_index", as.data.frame(values, stringsAsFactors = FALSE))
  }
  con
}

species_id <- "fixture_species"
write_registry(species_id)
sqlite_path <- sqlite_path_for(species_id)
legacy_path <- file.path(alias_dir, paste0(species_id, ".alias_index.tsv.gz"))

run_verifier(FALSE, "missing")

con_gz <- gzfile(legacy_path, open = "wt")
writeLines(c("query_term\tgene_id", "ABC1\tgene-1"), con_gz)
close(con_gz)
run_verifier(FALSE, "legacy")

invisible(file.create(sqlite_path))
run_verifier(FALSE, "sqlite-empty-file")

con <- create_alias_table(sqlite_path, include_all_columns = FALSE, insert_row = FALSE)
DBI::dbDisconnect(con)
run_verifier(FALSE, "sqlite-missing-columns")

con <- create_alias_table(sqlite_path, include_all_columns = TRUE, insert_row = FALSE)
invisible(DBI::dbExecute(con, "CREATE INDEX idx_query_term_original ON alias_index(query_term_original)"))
DBI::dbDisconnect(con)
run_verifier(FALSE, "sqlite-empty-table")

con <- create_alias_table(sqlite_path, include_all_columns = TRUE, insert_row = TRUE)
DBI::dbDisconnect(con)
run_verifier(FALSE, "sqlite-missing-exact-index")

con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
invisible(DBI::dbExecute(
  con,
  "CREATE INDEX idx_query_term_original ON alias_index(query_term_original) WHERE query_term_original <> ''"
))
DBI::dbDisconnect(con)
run_verifier(FALSE, "sqlite-partial-exact-index")

con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
invisible(DBI::dbExecute(con, "DROP INDEX idx_query_term_original"))
invisible(DBI::dbExecute(con, "CREATE INDEX idx_query_term_original ON alias_index(query_term_original COLLATE NOCASE)"))
DBI::dbDisconnect(con)
run_verifier(FALSE, "sqlite-invalid-exact-index")

con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
invisible(DBI::dbExecute(con, "DROP INDEX idx_query_term_original"))
invisible(DBI::dbExecute(con, "CREATE INDEX idx_query_term_original ON alias_index(query_term_original)"))
DBI::dbDisconnect(con)
run_verifier(FALSE, "sqlite-missing-partial-symbol-index")

con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
invisible(DBI::dbExecute(
  con,
  "CREATE INDEX idx_local_symbol_upper ON alias_index(UPPER(local_symbol)) WHERE local_symbol <> ''"
))
DBI::dbDisconnect(con)
run_verifier(FALSE, "sqlite-partial-partial-symbol-index")

con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
invisible(DBI::dbExecute(con, "DROP INDEX idx_local_symbol_upper"))
invisible(DBI::dbExecute(con, "CREATE INDEX idx_local_symbol_upper ON alias_index(local_symbol)"))
DBI::dbDisconnect(con)
run_verifier(FALSE, "sqlite-invalid-partial-symbol-index")

con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
invisible(DBI::dbExecute(con, "DROP INDEX idx_local_symbol_upper"))
invisible(DBI::dbExecute(
  con,
  "CREATE INDEX idx_local_symbol_upper ON alias_index(UPPER(local_symbol), local_gene_id)"
))
DBI::dbDisconnect(con)
run_verifier(FALSE, "sqlite-invalid-partial-symbol-index")

con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
invisible(DBI::dbExecute(con, "DROP INDEX idx_local_symbol_upper"))
invisible(DBI::dbExecute(con, "CREATE INDEX idx_local_symbol_upper ON alias_index(UPPER(local_symbol))"))
DBI::dbDisconnect(con)
run_verifier(TRUE, "preloaded-alias-index-mount-ok")

sanitized_species_id <- "fixture species/with spaces"
write_registry(sanitized_species_id)
sanitized_path <- sqlite_path_for(sanitized_species_id)
invisible(file.rename(sqlite_path, sanitized_path))
run_verifier(TRUE, "preloaded-alias-index-mount-ok")

write_registry(c("species/a", "species a"))
run_verifier(FALSE, "collide after filename normalization")

write_registry(character(0))
run_verifier(FALSE, "contains no usable species_id")

cat("preloaded alias index verifier tests passed\n")
