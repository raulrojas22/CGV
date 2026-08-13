#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(vroom)
  library(httr2)
  library(jsonlite)
  library(purrr)
})

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- if (length(script_arg) > 0L) {
  sub("^--file=", "", script_arg[[1L]])
} else {
  file.path("scripts", "test_alias_index_resolution.R")
}
root <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
source(file.path(root, "R", "alias_resolution.R"))
source(file.path(root, "R", "utils.R"))
source(file.path(root, "gene_search_lib.R"))
alias_sqlite_builder_env <- new.env(parent = globalenv())
sys.source(file.path(root, "scripts", "build_alias_index_sqlite.R"), envir = alias_sqlite_builder_env)

assert_true <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

# Operation-local reuse must be result-equivalent, context-sensitive, and must
# not retain no-match/error outcomes that the existing pipeline is allowed to retry.
positive_lookup_calls <- 0L
positive_lookup_result <- list(
  status = "unique_exact",
  matches = data.frame(local_gene_id = "gene-positive", stringsAsFactors = FALSE)
)
positive_lookup <- make_operation_alias_index_lookup(
  query = "POSITIVE_ALIAS",
  file_path = "mock.gff3",
  file_label = "Mock organism",
  lookup_fun = function(...) {
    positive_lookup_calls <<- positive_lookup_calls + 1L
    positive_lookup_result
  }
)
positive_first <- positive_lookup(list(species_id = "mock_species", organism = "Mock organism", taxid = "999999", source = "first"))
positive_second <- positive_lookup(list(species_id = "mock_species", organism = "Mock organism", taxid = "999999", source = "second"))
assert_true(identical(positive_first$result, positive_second$result),
            "Operation-local alias reuse changed the successful lookup result.")
assert_true(identical(positive_lookup_calls, 1L) && !isTRUE(positive_first$reused) && isTRUE(positive_second$reused),
            "Equivalent alias contexts did not reuse exactly one successful lookup.")
invisible(positive_lookup(list(species_id = "mock_species", organism = "Mock organism", taxid = "1000000")))
assert_true(identical(positive_lookup_calls, 2L),
            "A changed effective alias context incorrectly reused a prior result.")

retry_lookup_calls <- 0L
retry_lookup <- make_operation_alias_index_lookup(
  query = "RETRY_ALIAS",
  file_path = "mock.gff3",
  lookup_fun = function(...) {
    retry_lookup_calls <<- retry_lookup_calls + 1L
    if (retry_lookup_calls == 1L) {
      return(list(status = "no_match", matches = data.frame()))
    }
    positive_lookup_result
  }
)
retry_first <- retry_lookup(list(species_id = "mock_species"))
retry_second <- retry_lookup(list(species_id = "mock_species"))
retry_third <- retry_lookup(list(species_id = "mock_species"))
assert_true(identical(retry_first$result$status, "no_match") &&
              identical(retry_second$result, positive_lookup_result) &&
              identical(retry_third$result, positive_lookup_result) &&
              identical(retry_lookup_calls, 2L) &&
              !isTRUE(retry_second$reused) && isTRUE(retry_third$reused),
            "No-match retry semantics changed under operation-local alias reuse.")

error_lookup_calls <- 0L
error_lookup <- make_operation_alias_index_lookup(
  query = "ERROR_ALIAS",
  file_path = "mock.gff3",
  lookup_fun = function(...) {
    error_lookup_calls <<- error_lookup_calls + 1L
    if (error_lookup_calls == 1L) stop("transient alias lookup failure")
    positive_lookup_result
  }
)
error_first <- tryCatch(error_lookup(list(species_id = "mock_species")), error = identity)
error_second <- error_lookup(list(species_id = "mock_species"))
assert_true(inherits(error_first, "error") &&
              identical(error_second$result, positive_lookup_result) &&
              identical(error_lookup_calls, 2L) && !isTRUE(error_second$reused),
            "Alias lookup errors were retained instead of preserving the existing retry path.")

tmp_root <- tempfile("cgv-alias-index-test-")
dir.create(tmp_root, recursive = TRUE, showWarnings = FALSE)
old_wd <- getwd()
setwd(tmp_root)
on.exit({
  setwd(old_wd)
  unlink(tmp_root, recursive = TRUE, force = TRUE)
}, add = TRUE)

tmp_gff <- file.path(tmp_root, "mock.gff3")
writeLines(
  c(
    "##gff-version 3",
    "chr1\tsrc\tgene\t1\t100\t.\t+\t.\tID=gene-1;gene_name=LOC_TEST123;Name=LOC_TEST123;Alias=SKC1;description=Sodium transporter HKT1%3B5",
    "chr1\tsrc\tmRNA\t1\t100\t.\t+\t.\tID=tx-1;Parent=gene-1;Name=LOC_TEST123.1",
    "chr1\tsrc\tgene\t300\t450\t.\t-\t.\tID=gene-2;gene_name=NHX2;Name=NHX2;locus_tag=LOC_NHX2",
    "chr1\tsrc\tmRNA\t300\t450\t.\t-\t.\tID=tx-2;Parent=gene-2;Name=NHX2.1",
    "chr2\tsrc\tgene\t500\t650\t.\t+\t.\tID=gene-3;gene_name=NHX3;Name=NHX3;locus_tag=LOC_NHX3",
    "chr2\tsrc\tmRNA\t500\t650\t.\t+\t.\tID=tx-3;Parent=gene-3;Name=NHX3.1"
  ),
  tmp_gff,
  useBytes = TRUE
)

det <- list(
  organism = "Mock organism",
  taxid = 999999,
  source = "preloaded_catalog",
  input_source = "preloaded",
  species_id = "mock_species"
)

local_exact <- search_gene_in_file(tmp_gff, "gene-1", show_diagnostics = FALSE, match_mode = "exact", return_meta = TRUE)
assert_true(is.data.frame(local_exact$data) && nrow(local_exact$data) > 0L, "Local gene ID exact lookup failed.")

gene_name_exact <- search_gene_in_file(tmp_gff, "LOC_TEST123", show_diagnostics = FALSE, match_mode = "exact", return_meta = TRUE)
assert_true(is.data.frame(gene_name_exact$data) && nrow(gene_name_exact$data) > 0L, "gene_name exact lookup failed.")

gff_alias_idx <- build_alias_index_from_gff(tmp_gff, organism_id = "mock_species", organism_name = "Mock organism", taxid = "999999")
gff_alias_hit <- search_alias_index("SKC1", gff_alias_idx, organism_id = "mock_species")
assert_true(startsWith(gff_alias_hit$status, "unique"), "GFF alias exact lookup failed.")

mock_rows <- rbind(
  gff_alias_idx,
  data.frame(
    organism_id = "mock_species",
    organism_name = "Mock organism",
    taxid = "999999",
    alias_query_keys_df(c("HKT1;5", "Q9MOCK1", "NM_000001", "TP53")),
    term_type = c("synonym", "uniprot_id", "refseq_mrna", "synonym"),
    local_gene_id = "gene-1",
    local_transcript_id = "tx-1",
    local_feature_id = "gene-1",
    local_symbol = "LOC_TEST123",
    chromosome = "chr1",
    start = 1,
    end = 100,
    strand = "+",
    description = "Mock HKT transporter",
    source_db = "BioMart:mock",
    source_release = "mock_release",
    confidence = c("MEDIUM", "MEDIUM", "MEDIUM", "MEDIUM"),
    evidence_source = "mock",
    stringsAsFactors = FALSE
  ),
  data.frame(
    organism_id = "mock_species",
    organism_name = "Mock organism",
    taxid = "999999",
    alias_query_keys_df("SKC1"),
    term_type = "gene_symbol",
    local_gene_id = "gene-2",
    local_transcript_id = "tx-2",
    local_feature_id = "gene-2",
    local_symbol = "NHX2",
    chromosome = "chr1",
    start = 300,
    end = 450,
    strand = "-",
    description = "Mock official symbol that collides with another gene alias",
    source_db = "NCBI:mock",
    source_release = "mock_release",
    confidence = "HIGH",
    evidence_source = "mock",
    stringsAsFactors = FALSE
  ),
  data.frame(
    organism_id = "mock_species",
    organism_name = "Mock organism",
    taxid = "999999",
    alias_query_keys_df(c("DUPALIAS", "DUPALIAS")),
    term_type = c("synonym", "synonym"),
    local_gene_id = c("gene-2", "gene-3"),
    local_transcript_id = c("tx-2", "tx-3"),
    local_feature_id = c("gene-2", "gene-3"),
    local_symbol = c("NHX2", "NHX3"),
    chromosome = c("chr1", "chr2"),
    start = c(300, 500),
    end = c(450, 650),
    strand = c("-", "+"),
    description = c("Mock NHX2", "Mock NHX3"),
    source_db = "BioMart:mock",
    source_release = "mock_release",
    confidence = "MEDIUM",
    evidence_source = "mock",
    stringsAsFactors = FALSE
  )
)
mock_tsv <- write_alias_index_tsv(mock_rows, "mock_species", base_dir = tmp_root)

has_exact_sqlite_index <- function(sqlite_path) {
  con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  alias_sqlite_builder_env$alias_sqlite_has_exact_index(con)
}

exact_alias_query_plan <- function(con, query, organism_id) {
  qn <- normalize_gene_query(query)
  org <- gsub("'", "''", as.character(organism_id), fixed = TRUE)
  sql <- sprintf(
    paste0(
      "EXPLAIN QUERY PLAN SELECT * FROM alias_index WHERE 1=1 ",
      "AND (organism_id = '%s' OR organism_id = '') AND (",
      "query_term_original = ?1 OR query_term_upper = ?2 OR ",
      "query_term_upper = ?3 OR query_term_clean_basic = ?4 OR ",
      "query_term_clean_strict = ?5)"
    ),
    org
  )
  DBI::dbGetQuery(
    con,
    sql,
    params = list(qn$original, qn$upper, qn$upper, qn$clean_basic, qn$clean_strict)
  )
}

# A legacy SQLite fixture reproduces the exact-query plan before the migration.
# Extra rows keep the plan representative while all returned lookup data remains deterministic.
legacy_rows <- normalize_alias_index_df(mock_rows)
filler <- legacy_rows[rep(1L, 200L), , drop = FALSE]
filler_terms <- sprintf("NOISE_ALIAS_%03d", seq_len(nrow(filler)))
filler_keys <- alias_query_keys_df(filler_terms)
filler[, names(filler_keys)] <- filler_keys
filler$local_gene_id <- sprintf("noise-gene-%03d", seq_len(nrow(filler)))
filler$local_feature_id <- filler$local_gene_id
legacy_rows <- rbind(legacy_rows, filler)

legacy_sqlite <- file.path(tmp_root, "legacy.alias_index.sqlite")
legacy_con <- DBI::dbConnect(RSQLite::SQLite(), legacy_sqlite)
DBI::dbWriteTable(legacy_con, "alias_index", legacy_rows, overwrite = TRUE)
DBI::dbExecute(legacy_con, "CREATE INDEX idx_upper ON alias_index(query_term_upper)")
DBI::dbExecute(legacy_con, "CREATE INDEX idx_clean_basic ON alias_index(query_term_clean_basic)")
DBI::dbExecute(legacy_con, "CREATE INDEX idx_clean_strict ON alias_index(query_term_clean_strict)")
legacy_before <- search_alias_index_sqlite("HKT1;5", legacy_con, organism_id = "mock_species")
plan_before <- exact_alias_query_plan(legacy_con, "HKT1;5", "mock_species")
assert_true(any(grepl("SCAN alias_index", plan_before$detail, fixed = TRUE)),
            "Legacy exact alias fixture did not reproduce the full-table scan.")
DBI::dbDisconnect(legacy_con)

migration_first <- alias_sqlite_builder_env$ensure_alias_sqlite_exact_index(legacy_sqlite)
migration_second <- alias_sqlite_builder_env$ensure_alias_sqlite_exact_index(legacy_sqlite)
assert_true(isTRUE(migration_first$ok) && isTRUE(migration_first$created),
            "Existing alias SQLite migration did not create idx_query_term_original.")
assert_true(isTRUE(migration_second$ok) && !isTRUE(migration_second$created),
            "Existing alias SQLite migration is not idempotent.")

legacy_con <- DBI::dbConnect(RSQLite::SQLite(), legacy_sqlite, flags = RSQLite::SQLITE_RO)
legacy_after <- search_alias_index_sqlite("HKT1;5", legacy_con, organism_id = "mock_species")
plan_after <- exact_alias_query_plan(legacy_con, "HKT1;5", "mock_species")
DBI::dbDisconnect(legacy_con)
assert_true(identical(legacy_before, legacy_after),
            "Adding idx_query_term_original changed exact alias lookup results.")
assert_true(!any(grepl("SCAN alias_index", plan_after$detail, fixed = TRUE)),
            "Exact alias query still performs a full alias_index scan after migration.")
assert_true(any(grepl("idx_query_term_original", plan_after$detail, fixed = TRUE)),
            "Exact alias query plan does not use idx_query_term_original.")

compact_sqlite <- file.path(tmp_root, "compact-builder.alias_index.sqlite")
write_alias_sqlite_compact(mock_rows, compact_sqlite)
assert_true(has_exact_sqlite_index(compact_sqlite),
            "Compact alias SQLite builder omitted idx_query_term_original.")

full_sqlite <- file.path(tmp_root, "full-builder.alias_index.sqlite")
build_alias_sqlite_from_tsv(mock_tsv, full_sqlite, external_compact = FALSE)
assert_true(has_exact_sqlite_index(full_sqlite),
            "Full alias SQLite builder omitted idx_query_term_original.")

script_sqlite <- file.path(tmp_root, "script-builder.alias_index.sqlite")
alias_sqlite_builder_env$build_sqlite_for_tsv(mock_tsv, script_sqlite, external_compact = TRUE)
assert_true(has_exact_sqlite_index(script_sqlite),
            "Standalone alias SQLite builder omitted idx_query_term_original.")
assert_true(alias_sqlite_builder_env$sqlite_is_current(mock_tsv, script_sqlite, external_compact = TRUE),
            "Standalone alias SQLite validation did not recognize the required exact-query index.")

loaded_idx <- load_alias_index("mock_species", annotation_path = tmp_gff, organism_name = "Mock organism", taxid = "999999", base_dir = tmp_root)
assert_true(nrow(loaded_idx) >= nrow(mock_rows), "Mock alias index did not load.")

format_hit <- search_alias_index("HKT1-5", loaded_idx, organism_id = "mock_species")
assert_true(startsWith(format_hit$status, "unique"), "Alias format-normalized lookup failed.")

strict_hit <- search_alias_index("HKT15", loaded_idx, organism_id = "mock_species")
assert_true(startsWith(strict_hit$status, "unique"), "Strict alias lookup failed.")

uniprot_hit <- search_alias_index("q9mock1", loaded_idx, organism_id = "mock_species")
assert_true(startsWith(uniprot_hit$status, "unique"), "UniProt alias lookup failed.")

refseq_hit <- search_alias_index("NM_000001", loaded_idx, organism_id = "mock_species")
assert_true(startsWith(refseq_hit$status, "unique"), "RefSeq alias lookup failed.")

tp53_hit <- search_alias_index("tp53", loaded_idx, organism_id = "mock_species")
assert_true(startsWith(tp53_hit$status, "unique"), "Explicit TP53 alias index lookup failed.")

ambig_hit <- search_alias_index("DUPALIAS", loaded_idx, organism_id = "mock_species")
assert_true(startsWith(ambig_hit$status, "multiple") && nrow(ambig_hit$matches) == 2L, "Ambiguous alias did not return multiple genes.")

pipe_alias <- run_lookup_pipeline_pure(
  file_path = tmp_gff,
  input_gene = "Q9MOCK1",
  det_info = det,
  enabled_external_sources = character(0),
  allow_partial_suggestions = FALSE
)
assert_true(identical(pipe_alias$lookup_stage, "alias_index"), "Pipeline did not resolve through alias_index.")

alias_context_lookup_env <- environment()
alias_context_lookup_original <- get("search_alias_index_for_context", envir = alias_context_lookup_env, inherits = TRUE)
operation_lookup_factory_original <- get("make_operation_alias_index_lookup", envir = alias_context_lookup_env, inherits = TRUE)
alias_context_lookup_calls <- 0L
tp53_reuse_probe <- tryCatch({
  assign(
    "search_alias_index_for_context",
    function(...) {
      alias_context_lookup_calls <<- alias_context_lookup_calls + 1L
      alias_context_lookup_original(...)
    },
    envir = alias_context_lookup_env
  )
  assign("make_operation_alias_index_lookup", NULL, envir = alias_context_lookup_env)
  baseline <- run_lookup_pipeline_pure(
    file_path = tmp_gff,
    input_gene = "TP53",
    det_info = det,
    enabled_external_sources = character(0),
    allow_partial_suggestions = FALSE
  )
  baseline_calls <- alias_context_lookup_calls

  alias_context_lookup_calls <- 0L
  assign("make_operation_alias_index_lookup", operation_lookup_factory_original, envir = alias_context_lookup_env)
  optimized <- run_lookup_pipeline_pure(
    file_path = tmp_gff,
    input_gene = "TP53",
    det_info = det,
    enabled_external_sources = character(0),
    allow_partial_suggestions = FALSE
  )
  list(
    baseline = baseline,
    baseline_calls = baseline_calls,
    optimized = optimized,
    optimized_calls = alias_context_lookup_calls
  )
}, finally = {
  assign("search_alias_index_for_context", alias_context_lookup_original, envir = alias_context_lookup_env)
  assign("make_operation_alias_index_lookup", operation_lookup_factory_original, envir = alias_context_lookup_env)
})
pipe_tp53_baseline_compare <- tp53_reuse_probe$baseline
pipe_tp53_alias <- tp53_reuse_probe$optimized
pipe_tp53_counted_compare <- pipe_tp53_alias
pipe_tp53_baseline_compare$lookup_elapsed_ms <- NULL
pipe_tp53_counted_compare$lookup_elapsed_ms <- NULL
assert_true(isTRUE(all.equal(pipe_tp53_counted_compare, pipe_tp53_baseline_compare, check.attributes = TRUE)),
            "Operation-local alias reuse changed the pure pipeline result.")
assert_true(identical(tp53_reuse_probe$baseline_calls, 2L) && identical(tp53_reuse_probe$optimized_calls, 1L),
            "The pure pipeline did not reduce the successful exact alias lookup from two calls to one.")
assert_true(identical(pipe_tp53_alias$lookup_stage, "alias_index"), "Pipeline did not resolve explicit TP53 alias through alias_index.")

pipe_ambig <- run_lookup_pipeline_pure(
  file_path = tmp_gff,
  input_gene = "DUPALIAS",
  det_info = det,
  enabled_external_sources = character(0),
  allow_partial_suggestions = FALSE
)
assert_true(identical(pipe_ambig$lookup_stage, "alias_index_ambiguous"), "Pipeline did not preserve ambiguous alias status.")

pipe_shadowed_alias <- run_lookup_pipeline_pure(
  file_path = tmp_gff,
  input_gene = "SKC1",
  det_info = det,
  enabled_external_sources = character(0),
  allow_partial_suggestions = FALSE
)
assert_true(identical(pipe_shadowed_alias$lookup_stage, "alias_index_ambiguous"),
            "Ambiguous alias preflight did not run before local exact lookup.")
assert_true(is.data.frame(pipe_shadowed_alias$alias_index_matches) &&
              identical(as.character(pipe_shadowed_alias$alias_index_matches$local_gene_id[1]), "gene-2") &&
              identical(as.character(pipe_shadowed_alias$alias_index_matches$match_role[1]), "official_symbol") &&
              isTRUE(pipe_shadowed_alias$alias_index_matches$recommended[1]),
            "Ambiguous alias candidates were not ranked with the official symbol first.")

pipe_direct_id <- run_lookup_pipeline_pure(
  file_path = tmp_gff,
  input_gene = "gene-1",
  det_info = det,
  enabled_external_sources = character(0),
  allow_partial_suggestions = FALSE
)
assert_true(!identical(pipe_direct_id$lookup_stage, "alias_index_ambiguous") &&
              identical(as.character(pipe_direct_id$matched_gene_id), "gene-1"),
            "Stable direct gene IDs should still resolve without ambiguity.")

upload_idx <- load_alias_index("", annotation_path = tmp_gff, organism_name = "Uploaded mock", taxid = "", base_dir = tmp_root, allow_gff_fallback = TRUE)
upload_hit <- search_alias_index("skc1", upload_idx, organism_id = "")
assert_true(startsWith(upload_hit$status, "unique"), "Uploaded-organism GFF mini index failed.")

arabidopsis_gff <- file.path(root, "annotations", "GCF_000001735.4_TAIR10.1_genomic.gff.gz")
arabidopsis_sqlite <- alias_sqlite_path("arabidopsis_thaliana_gcf_000001735_4_tair10_1_genomic", base_dir = root)
if (file.exists(arabidopsis_gff) && file.exists(arabidopsis_sqlite)) {
  test_cwd <- getwd()
  setwd(root)
  on.exit(setwd(test_cwd), add = TRUE)
  arabidopsis_det <- list(
    organism = "Arabidopsis thaliana",
    taxid = 3702,
    source = "preloaded_catalog",
    input_source = "preloaded",
    species_id = "arabidopsis_thaliana_gcf_000001735_4_tair10_1_genomic"
  )
  kat1_direct <- run_lookup_pipeline_pure(
    file_path = arabidopsis_gff,
    input_gene = "AT5G46240",
    det_info = arabidopsis_det,
    enabled_external_sources = character(0),
    allow_partial_suggestions = FALSE
  )
  assert_true(identical(as.character(kat1_direct$matched_gene_id), "gene-AT5G46240") &&
                identical(as.character(kat1_direct$matched_gene_name), "KAT1"),
              "Stable Arabidopsis locus AT5G46240 should resolve to KAT1.")
}

query_mygene <- function(gene, taxid) "gene-2"
query_uniprot <- function(gene, taxid) character(0)
query_ncbi <- function(gene, taxid) character(0)
query_ensembl_with_species <- function(gene, species_name) character(0)

external_pipe <- run_lookup_pipeline_pure(
  file_path = tmp_gff,
  input_gene = "EXTERNAL_ONLY",
  det_info = det,
  enabled_external_sources = "mygene",
  allow_partial_suggestions = FALSE
)
assert_true(identical(external_pipe$lookup_stage, "external_alias"), "No-match term did not fall through to external alias lookup.")

cat("alias_index_resolution tests passed\n")
