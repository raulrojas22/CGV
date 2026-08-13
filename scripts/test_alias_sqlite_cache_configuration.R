#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
})

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- if (length(script_arg) > 0L) {
  sub("^--file=", "", script_arg[[1L]])
} else {
  file.path("scripts", "test_alias_sqlite_cache_configuration.R")
}
root <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
source(file.path(root, "R", "alias_resolution.R"))
source(file.path(root, "R", "utils.R"))

assert_true <- function(value, message) {
  if (!isTRUE(value)) stop(message, call. = FALSE)
}

old_runtime <- Sys.getenv("CGV_RUNTIME", unset = NA_character_)
old_cache_mb <- Sys.getenv("APP_ALIAS_SQLITE_CACHE_MB", unset = NA_character_)
restore_env <- function(name, value) {
  if (is.na(value)) {
    Sys.unsetenv(name)
  } else {
    do.call(Sys.setenv, stats::setNames(list(value), name))
  }
}
on.exit({
  restore_env("CGV_RUNTIME", old_runtime)
  restore_env("APP_ALIAS_SQLITE_CACHE_MB", old_cache_mb)
}, add = TRUE)

Sys.unsetenv(c("CGV_RUNTIME", "APP_ALIAS_SQLITE_CACHE_MB"))
assert_true(identical(alias_sqlite_cache_size_mb(), 8), "Web default must be 8 MiB.")
Sys.setenv(CGV_RUNTIME = "desktop")
assert_true(identical(alias_sqlite_cache_size_mb(), 16), "Desktop default must be 16 MiB.")
Sys.setenv(APP_ALIAS_SQLITE_CACHE_MB = "32")
assert_true(identical(alias_sqlite_cache_size_mb(), 32), "Explicit cache size was not honored.")
Sys.setenv(APP_ALIAS_SQLITE_CACHE_MB = "0")
assert_true(identical(alias_sqlite_cache_size_mb(), 1), "Cache size was not clamped to 1 MiB.")
Sys.setenv(APP_ALIAS_SQLITE_CACHE_MB = "128")
assert_true(identical(alias_sqlite_cache_size_mb(), 64), "Cache size was not clamped to 64 MiB.")
Sys.setenv(APP_ALIAS_SQLITE_CACHE_MB = "invalid")
assert_true(identical(alias_sqlite_cache_size_mb(), 16), "Invalid Desktop value did not use its default.")

tmp_root <- tempfile("alias-sqlite-cache-")
dir.create(file.path(tmp_root, "data", "alias_index"), recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(tmp_root, recursive = TRUE, force = TRUE), add = TRUE)

fixture <- normalize_alias_index_df(data.frame(
  organism_id = "",
  query_term_original = c("TP53", "P53"),
  query_term_upper = c("TP53", "P53"),
  query_term_clean_basic = c("TP53", "P53"),
  query_term_clean_strict = c("TP53", "P53"),
  term_type = c("gene_symbol", "gene_synonym"),
  local_gene_id = c("gene-TP53", "gene-TP53"),
  local_feature_id = c("gene-TP53", "gene-TP53"),
  local_symbol = c("TP53", "TP53"),
  confidence = c("HIGH", "MEDIUM"),
  source_db = c("GFF", "NCBI"),
  stringsAsFactors = FALSE
))

fixture_source <- file.path(tmp_root, "fixture.sqlite")
fixture_con <- dbConnect(SQLite(), fixture_source)
dbWriteTable(fixture_con, "alias_index", fixture, overwrite = TRUE)
dbExecute(fixture_con, "CREATE INDEX idx_query_term_original ON alias_index(query_term_original)")
dbExecute(fixture_con, "CREATE INDEX idx_upper ON alias_index(query_term_upper)")
dbExecute(fixture_con, "CREATE INDEX idx_clean_basic ON alias_index(query_term_clean_basic)")
dbExecute(fixture_con, "CREATE INDEX idx_clean_strict ON alias_index(query_term_clean_strict)")
dbDisconnect(fixture_con)

on.exit(close_all_alias_sqlite_connections(), add = TRUE)

reference_result <- NULL
for (cache_mb in c(4L, 8L, 16L, 32L)) {
  organism_id <- paste0("cache_fixture_", cache_mb)
  sqlite_path <- alias_sqlite_path(organism_id, base_dir = tmp_root)
  assert_true(file.copy(fixture_source, sqlite_path), "Could not copy SQLite cache fixture.")

  Sys.setenv(APP_ALIAS_SQLITE_CACHE_MB = as.character(cache_mb))
  con <- load_alias_index_sqlite(organism_id = organism_id, base_dir = tmp_root)
  assert_true(inherits(con, "SQLiteConnection"), "Read-only SQLite connection was not opened.")
  assert_true(
    identical(as.integer(dbGetQuery(con, "PRAGMA query_only")[[1L]]), 1L),
    "SQLite connection is not query-only."
  )
  assert_true(
    identical(as.integer(dbGetQuery(con, "PRAGMA cache_size")[[1L]]), -cache_mb * 1024L),
    sprintf("SQLite cache_size did not use %d MiB.", cache_mb)
  )

  result <- search_alias_index_sqlite("TP53", con, organism_id = organism_id)
  assert_true(
    identical(as.character(result$status), "unique_exact") &&
      identical(as.character(result$matches$local_gene_id[[1L]]), "gene-TP53"),
    sprintf("Alias lookup semantics failed with %d MiB cache.", cache_mb)
  )
  if (is.null(reference_result)) {
    reference_result <- result
  } else {
    assert_true(
      identical(result, reference_result),
      sprintf("Alias lookup result changed with %d MiB cache.", cache_mb)
    )
  }
}

cat("alias-sqlite-cache-configuration-ok\n")
