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

source("/Users/rarojas/Documents/A_FULLAPP/R/utils.R")
source("/Users/rarojas/Documents/A_FULLAPP/gene_search_lib.R")

assert_true <- function(cond, msg) {
  if (!isTRUE(cond)) {
    stop(msg, call. = FALSE)
  }
}

clear_alias_cache <- function() {
  keys <- ls(.alias_memory_cache, all.names = TRUE)
  if (length(keys) > 0) {
    rm(list = keys, envir = .alias_memory_cache)
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
assert_true(identical(bridge_ok$best_alias_used, "HKT1;5"), "Alias bridge did not use the expected bridge-resolved alias.")
bridge_ok_meta <- attach_lookup_result_meta(
  bridge_ok$result,
  query_candidates = bridge_ok$query_candidates,
  best_alias_used = bridge_ok$best_alias_used,
  input_gene = "hkt1;5"
)
assert_true(identical(bridge_ok_meta$best_alias_used, "HKT1;5"), "Lookup metadata did not preserve the chosen alias.")
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
assert_true(isTRUE(bridge_uniprot_only$found), "Bridge should rescue a UniProt-style alias through local description tokens.")
assert_true(identical(bridge_uniprot_only$best_alias_used, "HKT1;5"), "Bridge should prefer the direct UniProt gene alias when it resolves locally through description tokens.")

orig_query_fns <- mget(
  c("query_mygene", "query_ncbi", "query_uniprot", "query_ensembl_with_species"),
  inherits = TRUE
)
on.exit({
  list2env(orig_query_fns, environment())
  clear_alias_cache()
  unlink(tmp_gff, force = TRUE)
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
future::plan(future::multisession, workers = 2)
par_aliases <- get_gene_aliases(
  gene = "HKT1;5",
  taxid = 4530,
  organism = "Oryza sativa ssp. japonica",
  use_parallel = TRUE,
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

cat("alias-lookup-regression-ok\n")
