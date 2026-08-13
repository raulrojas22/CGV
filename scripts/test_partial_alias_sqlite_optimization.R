#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
})

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- if (length(script_arg) > 0L) sub("^--file=", "", script_arg[[1L]]) else file.path("scripts", "test_partial_alias_sqlite_optimization.R")
root <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
source(file.path(root, "R", "alias_resolution.R"))
source(file.path(root, "R", "utils.R"))

assert_true <- function(value, message) {
  if (!isTRUE(value)) stop(message, call. = FALSE)
}

allowed_types <- c(
  "name", "gene_name", "gene", "gene_symbol", "alias", "gene_synonym",
  "gene_synonyms", "synonym", "external_gene_name", "locus_tag", "id",
  "dbxref", "entrezgene_id", "ensembl_gene_id", "uniprot_id",
  "description", "product", "note"
)
type_sql <- paste(sprintf("'%s'", allowed_types), collapse = ",")

legacy_query <- function(con, like_value, row_limit_sql = "") {
  sql <- sprintf(
    paste0(
      "SELECT query_term_original, query_term_clean_strict, query_term_upper, ",
      "local_gene_id, local_symbol, term_type, confidence, source_db ",
      "FROM alias_index WHERE term_type IN (%s) AND LENGTH(query_term_original) <= 100 AND ",
      "(query_term_clean_strict LIKE ?1 OR query_term_upper LIKE ?1 OR UPPER(local_symbol) LIKE ?1) ",
      "ORDER BY CASE confidence WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END, ",
      "LENGTH(query_term_original), query_term_original%s"
    ),
    type_sql,
    row_limit_sql
  )
  dbGetQuery(con, sql, params = list(like_value))
}

optimized_query <- function(con, like_value, prefix_value = NULL, row_limit_sql = "") {
  query_partial_alias_rows_sqlite(
    con = con,
    like_value = like_value,
    type_sql = type_sql,
    row_limit_sql = row_limit_sql,
    prefix_value = prefix_value
  )
}

fixture <- normalize_alias_index_df(data.frame(
  organism_id = "fixture",
  query_term_original = c(
    "TRP1", "TRP1", "TRP1", "TRP2", "XTRP3", "YTRP4", "OTHER"
  ),
  query_term_upper = c("TRP1", "TRP1", "TRP1", "TRP2", "XTRP3", "YTRP4", "OTHER"),
  query_term_clean_basic = c("TRP1", "TRP1", "TRP1", "TRP2", "XTRP3", "YTRP4", "OTHER"),
  query_term_clean_strict = c("TRP1", "TRP1", "TRP1", "TRP2", "XTRP3", "YTRP4", "OTHER"),
  term_type = c("name", "alias", "gene_synonym", "name", "alias", "alias", "name"),
  local_gene_id = c("gene-b", "gene-a", "gene-c", "gene-d", "gene-e", "gene-f", "gene-g"),
  local_feature_id = c("gene-b", "gene-a", "gene-c", "gene-d", "gene-e", "gene-f", "gene-g"),
  local_symbol = c("TRP1", "TRP1", "TRP1", "TRP2", "XTRP3", "YTRP4", "OTHER"),
  confidence = c("HIGH", "HIGH", "HIGH", "HIGH", "MEDIUM", "LOW", "HIGH"),
  source_db = c("GFF", "NCBI", "BioMart", "GFF", "NCBI", "NCBI", "GFF"),
  stringsAsFactors = FALSE
))

fixture_path <- tempfile("partial-alias-sqlite-", fileext = ".sqlite")
on.exit(unlink(fixture_path, force = TRUE), add = TRUE)
con <- dbConnect(SQLite(), fixture_path)
dbWriteTable(con, "alias_index", fixture, overwrite = TRUE)
dbExecute(con, "CREATE INDEX idx_clean_strict ON alias_index(query_term_clean_strict)")
dbExecute(con, "CREATE INDEX idx_upper ON alias_index(query_term_upper)")
dbExecute(con, "CREATE INDEX idx_local_symbol_upper ON alias_index(UPPER(local_symbol))")
dbExecute(con, "CREATE INDEX idx_term_type ON alias_index(term_type)")
dbExecute(con, "ANALYZE")

valid_indexes <- dbGetQuery(con, "PRAGMA index_list('alias_index')")
assert_true(
  partial_alias_sqlite_has_column_index(
    con, valid_indexes, "idx_clean_strict", "query_term_clean_strict"
  ) &&
    partial_alias_sqlite_has_column_index(con, valid_indexes, "idx_upper", "query_term_upper") &&
    partial_alias_sqlite_has_symbol_upper_index(con, valid_indexes),
  "Correct prefix index definitions were not accepted for the optimized path."
)

dbExecute(con, "DROP INDEX idx_upper")
dbExecute(con, "CREATE INDEX idx_upper ON alias_index(query_term_upper) WHERE query_term_upper <> ''")
fixture_optimized_error_legacy <- legacy_query(con, "TRP%", " LIMIT 4")
forced_partial_index_error <- tryCatch(
  dbGetQuery(
    con,
    "SELECT rowid FROM alias_index INDEXED BY idx_upper WHERE query_term_upper >= ?1 AND query_term_upper < ?2",
    params = list("TRP", "TRQ")
  ),
  error = identity
)
assert_true(inherits(forced_partial_index_error, "error"), "Broken optimized-index fixture did not force a SQL error.")
fixture_optimized_error_fallback <- optimized_query(con, "TRP%", "TRP", " LIMIT 4")
assert_true(
  identical(fixture_optimized_error_fallback, fixture_optimized_error_legacy),
  "Optimized SQL errors did not retry the legacy prefix query."
)
dbExecute(con, "DROP INDEX idx_upper")
dbExecute(con, "CREATE INDEX idx_upper ON alias_index(query_term_upper)")

dbExecute(con, "DROP INDEX idx_upper")
dbExecute(con, "CREATE INDEX idx_upper ON alias_index(local_symbol)")
wrong_indexes <- dbGetQuery(con, "PRAGMA index_list('alias_index')")
assert_true(
  !partial_alias_sqlite_has_column_index(con, wrong_indexes, "idx_upper", "query_term_upper"),
  "Wrong same-name idx_upper definition was accepted for the optimized path."
)
fixture_wrong_index_legacy <- legacy_query(con, "TRP%", " LIMIT 4")
fixture_wrong_index_fallback <- optimized_query(con, "TRP%", "TRP", " LIMIT 4")
assert_true(
  identical(fixture_wrong_index_fallback, fixture_wrong_index_legacy),
  "Wrong same-name prefix index did not preserve the legacy query fallback."
)
dbExecute(con, "DROP INDEX idx_upper")
dbExecute(con, "CREATE INDEX idx_upper ON alias_index(query_term_upper)")

fixture_prefix_legacy <- legacy_query(con, "TRP%", " LIMIT 4")
fixture_prefix_optimized <- optimized_query(con, "TRP%", "TRP", " LIMIT 4")
assert_true(
  identical(fixture_prefix_optimized, fixture_prefix_legacy),
  "Prefix optimization changed ordered SQL rows or tied-row duplicates."
)

dbExecute(con, "DROP INDEX idx_term_type")
dbExecute(con, "ANALYZE")
fixture_scan_legacy <- legacy_query(con, "TRP%", " LIMIT 4")
fixture_scan_optimized <- optimized_query(con, "TRP%", "TRP", " LIMIT 4")
assert_true(
  identical(fixture_scan_optimized, fixture_scan_legacy),
  "Prefix optimization changed tied-row order for the legacy table-scan plan."
)
dbExecute(con, "CREATE INDEX idx_term_type ON alias_index(term_type)")
dbExecute(con, "ANALYZE")

fixture_contains_legacy <- legacy_query(con, "%TRP3%", " LIMIT 4")
fixture_contains_optimized <- optimized_query(con, "%TRP3%", row_limit_sql = " LIMIT 4")
assert_true(
  identical(fixture_contains_optimized, fixture_contains_legacy),
  "Contains fallback changed ordered SQL rows."
)

fixture_no_hit_legacy <- legacy_query(con, "%ZZZZ%", " LIMIT 4")
fixture_no_hit_optimized <- optimized_query(con, "%ZZZZ%", row_limit_sql = " LIMIT 4")
assert_true(
  identical(fixture_no_hit_optimized, fixture_no_hit_legacy),
  "No-hit contains fallback changed."
)

fixture_unlimited_legacy <- legacy_query(con, "TRP%")
fixture_unlimited_optimized <- optimized_query(con, "TRP%", "TRP")
assert_true(
  identical(fixture_unlimited_optimized, fixture_unlimited_legacy),
  "Unlimited deterministic prefix query changed ordered SQL rows."
)

dbExecute(con, "DROP INDEX idx_local_symbol_upper")
fixture_missing_index_legacy <- legacy_query(con, "TRP%", " LIMIT 4")
fixture_missing_index_fallback <- optimized_query(con, "TRP%", "TRP", " LIMIT 4")
assert_true(
  identical(fixture_missing_index_fallback, fixture_missing_index_legacy),
  "Missing partial-symbol index did not preserve the legacy prefix fallback."
)
dbExecute(con, "CREATE INDEX idx_local_symbol_upper ON alias_index(UPPER(local_symbol))")

plan_sql <- paste(
  "EXPLAIN QUERY PLAN WITH candidate_rowids AS (",
  "SELECT rowid FROM alias_index INDEXED BY idx_clean_strict WHERE query_term_clean_strict >= ?2 AND query_term_clean_strict < ?3 UNION",
  "SELECT rowid FROM alias_index INDEXED BY idx_upper WHERE query_term_upper >= ?2 AND query_term_upper < ?3 UNION",
  "SELECT rowid FROM alias_index INDEXED BY idx_local_symbol_upper WHERE UPPER(local_symbol) >= ?2 AND UPPER(local_symbol) < ?3)",
  "SELECT query_term_original, query_term_clean_strict, query_term_upper, local_gene_id, local_symbol, term_type, confidence, source_db",
  "FROM candidate_rowids c CROSS JOIN alias_index a ON a.rowid = c.rowid",
  sprintf("WHERE term_type IN (%s) AND LENGTH(query_term_original) <= 100 AND", type_sql),
  "(query_term_clean_strict LIKE ?1 OR query_term_upper LIKE ?1 OR UPPER(local_symbol) LIKE ?1)",
  "ORDER BY CASE confidence WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,",
  "LENGTH(query_term_original), query_term_original LIMIT 4"
)
fixture_plan <- dbGetQuery(con, plan_sql, params = list("TRP%", "TRP", "TRQ"))
assert_true(
  any(grepl("idx_clean_strict", fixture_plan$detail, fixed = TRUE)) &&
    any(grepl("idx_upper", fixture_plan$detail, fixed = TRUE)) &&
    any(grepl("idx_local_symbol_upper", fixture_plan$detail, fixed = TRUE)) &&
    any(grepl("INTEGER PRIMARY KEY", fixture_plan$detail, fixed = TRUE)),
  "Optimized prefix plan does not use all range indexes followed by rowid lookup."
)
dbDisconnect(con)

real_candidates <- c(
  file.path(root, "data", "alias_index", "mus_musculus_gcf_000001635_27_grcm39_genomic.alias_index.sqlite"),
  file.path(root, "data", "alias_index", "homo_sapiens_gcf_000001405_40_grch38_p14_genomic.alias_index.sqlite")
)
real_path <- real_candidates[file.exists(real_candidates) & file.info(real_candidates)$size > 0][1]
if (!is.na(real_path) && nzchar(real_path)) {
  con <- dbConnect(SQLite(), real_path, flags = SQLITE_RO)
  on.exit(if (dbIsValid(con)) dbDisconnect(con), add = TRUE)
  indexes <- dbGetQuery(con, "PRAGMA index_list('alias_index')")
  if ("idx_local_symbol_upper" %in% as.character(indexes$name)) {
    for (query in c("TRP", "TP53", "ZNF", "MIR", "HLA", "ZZZZZZ")) {
      legacy <- legacy_query(con, paste0(query, "%"), " LIMIT 16")
      optimized <- optimized_query(con, paste0(query, "%"), query, " LIMIT 16")
      assert_true(
        identical(optimized, legacy),
        paste("Real read-only prefix equivalence failed for", query)
      )
    }
    for (query in c("P53", "KINASE", "ZZZZZZ")) {
      legacy <- legacy_query(con, paste0("%", query, "%"), " LIMIT 16")
      optimized <- optimized_query(con, paste0("%", query, "%"), row_limit_sql = " LIMIT 16")
      assert_true(
        identical(optimized, legacy),
        paste("Real read-only contains equivalence failed for", query)
      )
    }
  }
  dbDisconnect(con)
}

cat("partial-alias-sqlite-optimization-ok\n")
