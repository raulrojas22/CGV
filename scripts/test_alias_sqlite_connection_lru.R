#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
})

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- if (length(script_arg) > 0L) {
  sub("^--file=", "", script_arg[[1L]])
} else {
  file.path("scripts", "test_alias_sqlite_connection_lru.R")
}
root <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
source(file.path(root, "R", "alias_resolution.R"))
source(file.path(root, "R", "utils.R"))

assert_true <- function(value, message) {
  if (!isTRUE(value)) stop(message, call. = FALSE)
}

old_runtime <- Sys.getenv("CGV_RUNTIME", unset = NA_character_)
old_max_connections <- Sys.getenv("APP_ALIAS_SQLITE_MAX_CONNECTIONS", unset = NA_character_)
restore_env <- function(name, value) {
  if (is.na(value)) {
    Sys.unsetenv(name)
  } else {
    do.call(Sys.setenv, stats::setNames(list(value), name))
  }
}
on.exit({
  close_all_alias_sqlite_connections()
  restore_env("CGV_RUNTIME", old_runtime)
  restore_env("APP_ALIAS_SQLITE_MAX_CONNECTIONS", old_max_connections)
}, add = TRUE)

Sys.unsetenv(c("CGV_RUNTIME", "APP_ALIAS_SQLITE_MAX_CONNECTIONS"))
assert_true(identical(alias_sqlite_max_connections(), 4L), "Web LRU default must be 4 connections.")
Sys.setenv(CGV_RUNTIME = "desktop")
assert_true(identical(alias_sqlite_max_connections(), 8L), "Desktop LRU default must be 8 connections.")
for (max_connections in c(1L, 4L, 8L, 32L)) {
  Sys.setenv(APP_ALIAS_SQLITE_MAX_CONNECTIONS = as.character(max_connections))
  assert_true(
    identical(alias_sqlite_max_connections(), max_connections),
    sprintf("Explicit LRU limit %d was not honored.", max_connections)
  )
}
Sys.setenv(APP_ALIAS_SQLITE_MAX_CONNECTIONS = "0")
assert_true(identical(alias_sqlite_max_connections(), 1L), "LRU limit was not clamped to 1.")
Sys.setenv(APP_ALIAS_SQLITE_MAX_CONNECTIONS = "64")
assert_true(identical(alias_sqlite_max_connections(), 32L), "LRU limit was not clamped to 32.")
Sys.setenv(APP_ALIAS_SQLITE_MAX_CONNECTIONS = "invalid")
assert_true(identical(alias_sqlite_max_connections(), 8L), "Invalid Desktop LRU value did not use its default.")

tmp_root <- tempfile("alias-sqlite-lru-")
alias_dir <- file.path(tmp_root, "data", "alias_index")
dir.create(alias_dir, recursive = TRUE, showWarnings = FALSE)
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
invisible(dbWriteTable(fixture_con, "alias_index", fixture, overwrite = TRUE))
invisible(dbExecute(fixture_con, "CREATE INDEX idx_query_term_original ON alias_index(query_term_original)"))
invisible(dbExecute(fixture_con, "CREATE INDEX idx_upper ON alias_index(query_term_upper)"))
invisible(dbExecute(fixture_con, "CREATE INDEX idx_clean_basic ON alias_index(query_term_clean_basic)"))
invisible(dbExecute(fixture_con, "CREATE INDEX idx_clean_strict ON alias_index(query_term_clean_strict)"))
dbDisconnect(fixture_con)

organism_ids <- sprintf("lru_fixture_%02d", seq_len(40L))
for (organism_id in organism_ids) {
  assert_true(
    file.copy(fixture_source, alias_sqlite_path(organism_id, base_dir = tmp_root)),
    paste("Could not copy LRU fixture for", organism_id)
  )
}

cache_keys <- function() ls(.alias_sqlite_connection_cache, all.names = TRUE)
access_keys <- function() ls(.alias_sqlite_connection_access, all.names = TRUE)
cache_key <- function(organism_id) .alias_sqlite_conn_key(organism_id, tmp_root)
open_fixture <- function(organism_id) {
  con <- load_alias_index_sqlite(organism_id = organism_id, base_dir = tmp_root)
  assert_true(alias_sqlite_connection_is_valid(con), paste("Invalid connection for", organism_id))
  con
}
query_fixture <- function(con) search_alias_index_sqlite("TP53", con, organism_id = "")

# A cache hit must reuse the same handle and make it the most recently used key.
close_all_alias_sqlite_connections()
Sys.setenv(APP_ALIAS_SQLITE_MAX_CONNECTIONS = "4")
con_a <- open_fixture(organism_ids[[1L]])
key_a <- cache_key(organism_ids[[1L]])
stamp_before <- get(key_a, envir = .alias_sqlite_connection_access, inherits = FALSE)
con_a_reused <- open_fixture(organism_ids[[1L]])
stamp_after <- get(key_a, envir = .alias_sqlite_connection_access, inherits = FALSE)
assert_true(identical(con_a, con_a_reused), "Cache hit did not reuse the SQLite handle.")
assert_true(stamp_after > stamp_before, "Cache hit did not touch the LRU access order.")
reference_result <- query_fixture(con_a)
assert_true(
  identical(as.character(reference_result$status), "unique_exact"),
  "Reference alias query was not an exact match."
)

# With capacity two, touching A must preserve it while B is evicted for C.
close_all_alias_sqlite_connections()
Sys.setenv(APP_ALIAS_SQLITE_MAX_CONNECTIONS = "2")
con_a <- open_fixture(organism_ids[[1L]])
con_b <- open_fixture(organism_ids[[2L]])
con_a_reused <- open_fixture(organism_ids[[1L]])
con_c <- open_fixture(organism_ids[[3L]])
assert_true(alias_sqlite_connection_is_valid(con_a), "Touched connection A was evicted.")
assert_true(identical(con_a, con_a_reused), "Touched connection A was unexpectedly reopened.")
assert_true(!alias_sqlite_connection_is_valid(con_b), "LRU connection B was not dbDisconnect()ed.")
assert_true(alias_sqlite_connection_is_valid(con_c), "Newly requested connection C was evicted.")
assert_true(
  identical(sort(cache_keys()), sort(c(cache_key(organism_ids[[1L]]), cache_key(organism_ids[[3L]])))),
  "LRU cache retained the wrong keys after touch and eviction."
)
assert_true(identical(query_fixture(con_a), reference_result), "LRU touch changed query semantics.")

# Exercise every supported boundary with one more database than the limit.
for (max_connections in c(1L, 4L, 8L, 32L)) {
  close_all_alias_sqlite_connections()
  Sys.setenv(APP_ALIAS_SQLITE_MAX_CONNECTIONS = as.character(max_connections))
  opened <- vector("list", max_connections + 1L)
  results <- vector("list", max_connections + 1L)
  for (index in seq_along(opened)) {
    opened[[index]] <- open_fixture(organism_ids[[index]])
    results[[index]] <- query_fixture(opened[[index]])
  }
  assert_true(
    length(cache_keys()) == max_connections && length(access_keys()) == max_connections,
    sprintf("LRU cache did not enforce capacity %d.", max_connections)
  )
  assert_true(
    !alias_sqlite_connection_is_valid(opened[[1L]]),
    sprintf("Oldest handle was not disconnected at capacity %d.", max_connections)
  )
  assert_true(
    alias_sqlite_connection_is_valid(opened[[length(opened)]]),
    sprintf("Newest handle was disconnected at capacity %d.", max_connections)
  )
  assert_true(
    all(vapply(results, identical, logical(1), reference_result)),
    sprintf("Alias query result changed at capacity %d.", max_connections)
  )
}

# A stale invalid handle must be forgotten and transparently reopened.
close_all_alias_sqlite_connections()
Sys.setenv(APP_ALIAS_SQLITE_MAX_CONNECTIONS = "4")
stale_con <- open_fixture(organism_ids[[1L]])
dbDisconnect(stale_con)
assert_true(!alias_sqlite_connection_is_valid(stale_con), "Invalid-handle fixture remained valid.")
replacement_con <- open_fixture(organism_ids[[1L]])
assert_true(alias_sqlite_connection_is_valid(replacement_con), "Invalid cached handle was not reopened.")
assert_true(length(cache_keys()) == 1L && identical(cache_keys(), key_a), "Invalid handle left stale cache state.")
assert_true(identical(query_fixture(replacement_con), reference_result), "Reopened handle changed query semantics.")

# Explicit per-organism purge must release the file handle without disturbing peers.
peer_con <- open_fixture(organism_ids[[2L]])
purge_path <- alias_sqlite_path(organism_ids[[1L]], base_dir = tmp_root)
renamed_path <- paste0(purge_path, ".renamed")
assert_true(
  isTRUE(purge_alias_sqlite_connection(organism_ids[[1L]], base_dir = tmp_root)),
  "Explicit SQLite purge did not report success."
)
assert_true(!alias_sqlite_connection_is_valid(replacement_con), "Purged handle is still valid.")
assert_true(alias_sqlite_connection_is_valid(peer_con), "Per-organism purge disconnected a peer.")
assert_true(!key_a %in% cache_keys() && !key_a %in% access_keys(), "Purge left cache metadata behind.")
assert_true(file.rename(purge_path, renamed_path), "Closed SQLite file could not be renamed safely.")
assert_true(file.rename(renamed_path, purge_path), "Renamed SQLite fixture could not be restored.")

# Close-all must dbDisconnect every handle, clear metadata, and release files.
extra_cons <- lapply(organism_ids[3:5], open_fixture)
all_cons <- c(list(peer_con), extra_cons)
closed_count <- close_all_alias_sqlite_connections()
assert_true(identical(closed_count, length(all_cons)), "close-all returned the wrong connection count.")
assert_true(
  all(!vapply(all_cons, alias_sqlite_connection_is_valid, logical(1))),
  "close-all left at least one SQLite handle valid."
)
assert_true(length(cache_keys()) == 0L && length(access_keys()) == 0L, "close-all left cache state behind.")
close_all_path <- alias_sqlite_path(organism_ids[[2L]], base_dir = tmp_root)
assert_true(unlink(close_all_path, force = TRUE) == 0L && !file.exists(close_all_path),
            "Closed SQLite file could not be removed safely.")

cat("alias-sqlite-connection-lru-ok\n")
