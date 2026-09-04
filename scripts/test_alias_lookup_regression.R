#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(future)
  library(furrr)
  library(httr2)
  library(jsonlite)
  library(stringr)
  library(dplyr)
  library(purrr)
  library(vroom)
})

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

alias_cache_dir <- tempfile("alias-cache-")
dir.create(alias_cache_dir, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(APP_ALIAS_DISK_CACHE_DIR = alias_cache_dir)

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
workspace <- if (length(script_arg)) {
  dirname(dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))))
} else {
  normalizePath(".")
}
source(file.path(workspace, "R", "utils.R"))
source(file.path(workspace, "gene_search_lib.R"))

assert_true <- function(cond, msg) {
  if (!isTRUE(cond)) {
    stop(msg, call. = FALSE)
  }
}

clear_alias_cache <- function(clear_disk = TRUE) {
  keys <- ls(.alias_memory_cache, all.names = TRUE)
  if (length(keys) > 0) {
    rm(list = keys, envir = .alias_memory_cache)
  }
  if (isTRUE(clear_disk) && dir.exists(alias_cache_dir)) {
    unlink(list.files(alias_cache_dir, full.names = TRUE), force = TRUE)
  }
  invisible(TRUE)
}

tmp_gff <- tempfile(fileext = ".gff3")
writeLines(
  c(
    "##gff-version 3",
    "chr1\tsrc\tgene\t1\t100\t.\t+\t.\tID=gene-1;gene_name=LOC_TEST123;Name=LOC_TEST123;description=Sodium transporter HKT1%3B5 [Source:UniProtKB]",
    "chr1\tsrc\tmRNA\t1\t100\t.\t+\t.\tID=tx-1;Parent=gene-1;Name=LOC_TEST123.1"
  ),
  tmp_gff,
  useBytes = TRUE
)

bridge_ok <- resolve_external_alias_bridge(
  input_gene = "HKT1;5",
  query_candidates = c("HKT1;5", "LOC_TEST123", "SKC1"),
  file_path = tmp_gff
)
assert_true(isTRUE(bridge_ok$found), "Alias bridge positive case failed.")
assert_true(identical(bridge_ok$best_alias_used, "LOC_TEST123"), "Alias bridge did not use the expected exact local alias.")
bridge_ok_meta <- attach_lookup_result_meta(
  bridge_ok$result,
  query_candidates = bridge_ok$query_candidates,
  best_alias_used = bridge_ok$best_alias_used,
  input_gene = "hkt1;5"
)
assert_true(identical(bridge_ok_meta$best_alias_used, "LOC_TEST123"), "Lookup metadata did not preserve the chosen alias.")
assert_true(identical(bridge_ok_meta$display_gene_name, "HKT1;5"), "Lookup metadata should expose the user-facing display gene name.")

local_exact_display <- attach_lookup_result_meta(
  list(data = data.frame(V1 = "chr1", stringsAsFactors = FALSE), matched_gene_id = "gene-HKT2", matched_gene_name = "HKT2;1"),
  query_candidates = c("hkt2;1"),
  best_alias_used = "",
  input_gene = "hkt2;1"
)
assert_true(identical(local_exact_display$display_gene_name, "HKT2;1"), "Display gene name should prefer a better-cased local annotation symbol over the raw input casing.")

bridged_loc_display <- attach_lookup_result_meta(
  list(data = data.frame(V1 = "chr1", stringsAsFactors = FALSE), matched_gene_id = "gene:BGIOSGA001800", matched_gene_name = "LOC01244231"),
  query_candidates = c("hkt1;5", "HKT1;5", "SKC1"),
  best_alias_used = "HKT1;5",
  input_gene = "hkt1;5"
)
assert_true(identical(bridged_loc_display$display_gene_name, "HKT1;5"), "Display gene name should prefer the resolved symbol over an internal LOC identifier.")

bridge_bad <- resolve_external_alias_bridge(
  input_gene = "NHX2",
  query_candidates = c("NHX2", "LOC_NOT_PRESENT"),
  file_path = tmp_gff
)
assert_true(!isTRUE(bridge_bad$found), "Alias bridge negative control should not match.")

bridge_uniprot_only <- resolve_external_alias_bridge(
  input_gene = "HKT1;5",
  query_candidates = c("HKT1;5"),
  file_path = tmp_gff
)
assert_true(!isTRUE(bridge_uniprot_only$found), "Bridge should not rescue aliases through local description tokens.")

tmp_tp53_gff <- tempfile(fileext = ".gff3")
writeLines(
  c(
    "##gff-version 3",
    "chr1\tsrc\tgene\t1\t100\t.\t+\t.\tID=gene-TP53RK;gene_name=TP53RK;Name=TP53RK;description=TP53 regulating kinase",
    "chr1\tsrc\tmRNA\t1\t100\t.\t+\t.\tID=tx-TP53RK;Parent=gene-TP53RK;Name=TP53RK.1",
    "chr1\tsrc\tgene\t201\t300\t.\t+\t.\tID=gene-TIGAR;gene_name=TIGAR;Name=TIGAR;description=TP53 induced glycolysis regulatory phosphatase",
    "chr1\tsrc\tmRNA\t201\t300\t.\t+\t.\tID=tx-TIGAR;Parent=gene-TIGAR;Name=TIGAR.1",
    "chr1\tsrc\tgene\t401\t500\t.\t+\t.\tID=gene-TP53TG5;gene_name=TP53TG5;Name=TP53TG5;description=TP53 target 5",
    "chr1\tsrc\tmRNA\t401\t500\t.\t+\t.\tID=tx-TP53TG5;Parent=gene-TP53TG5;Name=TP53TG5.1"
  ),
  tmp_tp53_gff,
  useBytes = TRUE
)
on.exit(unlink(tmp_tp53_gff, force = TRUE), add = TRUE)

tp53_false_bridge <- resolve_external_alias_bridge(
  input_gene = "TP53",
  query_candidates = c("TP53RK", "TIGAR", "TP53TG5", "TP53 regulating kinase"),
  file_path = tmp_tp53_gff
)
assert_true(!isTRUE(tp53_false_bridge$found), "TP53 should not bridge to related TP53-family/description matches.")

orig_query_fns <- mget(
  c("query_mygene", "query_ncbi", "query_uniprot", "query_ensembl_with_species"),
  inherits = TRUE
)
on.exit({
  list2env(orig_query_fns, environment())
  clear_alias_cache()
  unlink(tmp_gff, force = TRUE)
  unlink(alias_cache_dir, recursive = TRUE, force = TRUE)
}, add = TRUE)

query_mygene <- function(gene, taxid) c("LOC_TEST123", "SKC1")
query_ncbi <- function(gene, taxid) character(0)
query_uniprot <- function(gene, taxid) character(0)
query_ensembl_with_species <- function(gene, species_name) character(0)

clear_alias_cache()
seq_aliases <- get_gene_aliases(
  gene = "HKT1;5",
  taxid = 4530,
  organism = "Oryza sativa ssp. japonica",
  use_parallel = FALSE,
  sources = c("mygene", "ncbi")
)
assert_true("LOC_TEST123" %in% seq_aliases, "Sequential alias lookup did not keep the bridge alias.")
seq_meta <- attr(seq_aliases, "lookup_meta", exact = TRUE)
assert_true(is.list(seq_meta) && !isTRUE(seq_meta$had_errors), "Sequential alias lookup metadata should report a clean run.")

clear_alias_cache()
parallel_workers <- suppressWarnings(as.integer(Sys.getenv("APP_FUTURE_WORKERS", "2")))
if (!is.finite(parallel_workers) || is.na(parallel_workers) || parallel_workers < 1L) {
  parallel_workers <- 1L
}
if (parallel_workers > 1L) {
  future::plan(future::multisession, workers = parallel_workers)
} else {
  future::plan(future::sequential)
}
par_aliases <- get_gene_aliases(
  gene = "HKT1;5",
  taxid = 4530,
  organism = "Oryza sativa ssp. japonica",
  use_parallel = parallel_workers > 1L,
  sources = c("mygene", "ncbi")
)
future::plan(future::sequential)
assert_true("LOC_TEST123" %in% par_aliases, "Parallel alias lookup did not keep the bridge alias.")

clear_alias_cache()
first_hit <- get_gene_aliases(
  gene = "HKT1;5",
  taxid = 4530,
  organism = "Oryza sativa ssp. japonica",
  use_parallel = FALSE,
  sources = c("mygene")
)
query_mygene <- function(gene, taxid) stop("cache should have satisfied this lookup")
cached_hit <- get_gene_aliases(
  gene = "HKT1;5",
  taxid = 4530,
  organism = "Oryza sativa ssp. japonica",
  use_parallel = FALSE,
  sources = c("mygene")
)
assert_true(identical(sort(first_hit), sort(cached_hit)), "Hot cache alias lookup changed the returned aliases.")

clear_alias_cache()
query_mygene <- function(gene, taxid) c("LOC_TEST123")
query_uniprot <- function(gene, taxid) stop(simpleError("stubbed uniprot failure"))
captured <- capture.output(
aliases_after_error <- get_gene_aliases(
    gene = "HKT1;5",
    taxid = 4530,
    organism = "Oryza sativa ssp. japonica",
    use_parallel = FALSE,
    sources = c("uniprot", "mygene")
  ),
  type = "message"
)
assert_true("LOC_TEST123" %in% aliases_after_error, "Lookup should continue after a single-source resolver failure.")
error_meta <- attr(aliases_after_error, "lookup_meta", exact = TRUE)
assert_true(is.list(error_meta) && isTRUE(error_meta$had_errors), "Lookup metadata should flag partial external-source failures.")
assert_true(any(grepl("UniProt", error_meta$source_errors, fixed = TRUE)) || any(grepl("uniprot", error_meta$source_errors, ignore.case = TRUE)),
            "Lookup metadata should preserve the failing source label.")
assert_true(any(grepl("UniProt", captured, fixed = TRUE)) || any(grepl("uniprot", captured, ignore.case = TRUE)),
            "Resolver error output did not mention the failing source.")
assert_true(any(grepl("stubbed uniprot failure", captured, fixed = TRUE)),
            "Resolver error output did not preserve the nested message.")

tp53_plan <- build_gene_query_plan("TP53", organism = "Homo sapiens", taxid = 9606)
assert_true(!any(grepl("^Os", c(tp53_plan$primary, tp53_plan$relaxed))), "Non-Oryza queries should not generate Os-prefixed variants.")
rice_plan <- build_gene_query_plan("HKT1;5", organism = "Oryza sativa ssp. japonica", taxid = 4530)
assert_true(any(grepl("^Os", c(rice_plan$primary, rice_plan$relaxed))), "Oryza queries should keep Os-prefixed rescue variants.")

tmp_stream_gff <- tempfile(fileext = ".gff3")
writeLines(
  c(
    "##gff-version 3",
    "chr1\tsrc\tgene\t1\t100\t.\t+\t.\tID=gene-fast;gene_name=LOC_FAST123;Name=LOC_FAST123",
    "chr1\tsrc\tmRNA\t1\t100\t.\t+\t.\tID=tx-fast;Parent=gene-fast;Name=LOC_FAST123.1",
    "chr1\tsrc\tgene\t201\t300\t.\t+\t.\tID=gene-uniprot;gene_name=LOC_UNIPROT456;Name=LOC_UNIPROT456",
    "chr1\tsrc\tmRNA\t201\t300\t.\t+\t.\tID=tx-uniprot;Parent=gene-uniprot;Name=LOC_UNIPROT456.1",
    "chr1\tsrc\tgene\t401\t500\t.\t+\t.\tID=gene-ncbi;gene_name=LOC_NCBI789;Name=LOC_NCBI789",
    "chr1\tsrc\tmRNA\t401\t500\t.\t+\t.\tID=tx-ncbi;Parent=gene-ncbi;Name=LOC_NCBI789.1"
  ),
  tmp_stream_gff,
  useBytes = TRUE
)
on.exit(unlink(tmp_stream_gff, force = TRUE), add = TRUE)

clear_alias_cache()
calls <- new.env(parent = emptyenv())
calls$mygene <- 0L
calls$uniprot <- 0L
calls$ncbi <- 0L
calls$ensembl <- 0L
query_mygene <- function(gene, taxid) { calls$mygene <- calls$mygene + 1L; "LOC_FAST123" }
query_uniprot <- function(gene, taxid) { calls$uniprot <- calls$uniprot + 1L; stop("UniProt should be skipped after MyGene resolves") }
query_ncbi <- function(gene, taxid) { calls$ncbi <- calls$ncbi + 1L; stop("NCBI should be skipped after MyGene resolves") }
query_ensembl_with_species <- function(gene, species_name) { calls$ensembl <- calls$ensembl + 1L; stop("Ensembl should be skipped after MyGene resolves") }
stream_fast <- run_lookup_pipeline_pure(
  file_path = tmp_stream_gff,
  input_gene = "HKT1;5",
  det_info = list(organism = "Oryza sativa ssp. japonica", taxid = 4530),
  enabled_external_sources = c("mygene", "uniprot", "ncbi", "ensembl")
)
assert_true(identical(stream_fast$lookup_stage, "external_alias"), "MyGene streaming lookup should resolve through external alias.")
assert_true(identical(calls$mygene, 1L) && identical(calls$uniprot, 0L) && identical(calls$ncbi, 0L) && identical(calls$ensembl, 0L),
            "Streaming lookup should stop after MyGene resolves locally.")

clear_alias_cache()
calls$mygene <- calls$uniprot <- calls$ncbi <- calls$ensembl <- 0L
query_mygene <- function(gene, taxid) { calls$mygene <- calls$mygene + 1L; character(0) }
query_uniprot <- function(gene, taxid) { calls$uniprot <- calls$uniprot + 1L; "LOC_UNIPROT456" }
query_ncbi <- function(gene, taxid) { calls$ncbi <- calls$ncbi + 1L; stop("NCBI should be skipped after UniProt resolves") }
query_ensembl_with_species <- function(gene, species_name) { calls$ensembl <- calls$ensembl + 1L; stop("Ensembl should be skipped after UniProt resolves") }
stream_uniprot <- run_lookup_pipeline_pure(
  file_path = tmp_stream_gff,
  input_gene = "HKT1;5",
  det_info = list(organism = "Oryza sativa ssp. japonica", taxid = 4530),
  enabled_external_sources = c("mygene", "uniprot", "ncbi", "ensembl")
)
assert_true(identical(stream_uniprot$lookup_stage, "external_alias"), "UniProt streaming lookup should resolve after MyGene no-hit.")
assert_true(identical(calls$mygene, 1L) && identical(calls$uniprot, 1L) && identical(calls$ncbi, 0L) && identical(calls$ensembl, 0L),
            "Streaming lookup should stop after UniProt resolves locally.")

clear_alias_cache()
calls$mygene <- calls$uniprot <- calls$ncbi <- calls$ensembl <- 0L
query_mygene <- function(gene, taxid) { calls$mygene <- calls$mygene + 1L; character(0) }
query_uniprot <- function(gene, taxid) { calls$uniprot <- calls$uniprot + 1L; character(0) }
query_ncbi <- function(gene, taxid) { calls$ncbi <- calls$ncbi + 1L; "LOC_NCBI789" }
query_ensembl_with_species <- function(gene, species_name) { calls$ensembl <- calls$ensembl + 1L; stop("Ensembl should be skipped after NCBI resolves") }
stream_ncbi <- run_lookup_pipeline_pure(
  file_path = tmp_stream_gff,
  input_gene = "HKT1;5",
  det_info = list(organism = "Oryza sativa ssp. japonica", taxid = 4530),
  enabled_external_sources = c("mygene", "uniprot", "ncbi", "ensembl")
)
assert_true(identical(stream_ncbi$lookup_stage, "external_alias"), "NCBI fallback should still resolve when fast sources do not.")
assert_true(identical(calls$mygene, 1L) && identical(calls$uniprot, 1L) && identical(calls$ncbi, 1L) && identical(calls$ensembl, 0L),
            "Streaming lookup should preserve NCBI fallback and stop before Ensembl when NCBI resolves.")

clear_alias_cache()
query_mygene <- function(gene, taxid) "LOC_TEST123"
query_uniprot <- function(gene, taxid) stop(simpleError("partial provider failure"))
partial_aliases <- get_gene_aliases(
  gene = "HKT1;5",
  taxid = 4530,
  organism = "Oryza sativa ssp. japonica",
  use_parallel = FALSE,
  sources = c("mygene", "uniprot")
)
assert_true("LOC_TEST123" %in% partial_aliases, "Partial-failure lookup should still return successful provider aliases.")
clear_alias_cache(clear_disk = FALSE)
query_mygene <- function(gene, taxid) stop("provider cache should satisfy MyGene after partial failure")
cached_provider_aliases <- get_gene_aliases(
  gene = "HKT1;5",
  taxid = 4530,
  organism = "Oryza sativa ssp. japonica",
  use_parallel = FALSE,
  sources = c("mygene")
)
assert_true("LOC_TEST123" %in% cached_provider_aliases, "Provider-level cache should survive a multi-source partial failure.")

cat("alias-lookup-regression-ok\n")
