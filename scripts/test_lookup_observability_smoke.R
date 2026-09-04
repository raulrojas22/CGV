#!/usr/bin/env Rscript

Sys.setenv(APP_DEBUG_LOGS = "1", APP_PERF_TIMING = "1")

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
source(file.path(workspace, "R", "gene_search_lib.R"))

on.exit(unlink(alias_cache_dir, recursive = TRUE, force = TRUE), add = TRUE)

assert_true <- function(cond, msg) {
  if (!isTRUE(cond)) {
    stop(msg, call. = FALSE)
  }
}

orig_query_fns <- mget(
  c("query_mygene", "query_ncbi", "query_uniprot", "query_ensembl_with_species"),
  inherits = TRUE
)
on.exit(list2env(orig_query_fns, environment()), add = TRUE)

query_mygene <- function(gene, taxid) c("LOC_TEST123", "SKC1")
query_ncbi <- function(gene, taxid) character(0)
query_uniprot <- function(gene, taxid) stop(simpleError("stubbed uniprot failure"))
query_ensembl_with_species <- function(gene, species_name) character(0)

captured <- capture.output(
  get_gene_aliases(
    gene = "HKT1;5",
    taxid = 4530,
    organism = "Oryza sativa ssp. japonica",
    use_parallel = FALSE,
    sources = c("uniprot", "mygene", "ncbi")
  ),
  type = "message"
)

assert_true(any(grepl("\\[PERF\\]\\[EXT_ALIAS\\]", captured)), "Missing EXT_ALIAS perf logs.")
assert_true(any(grepl("source=uniprot", captured, fixed = TRUE)), "Missing per-source observability for uniprot.")
assert_true(any(grepl("stubbed uniprot failure", captured, fixed = TRUE)), "Missing nested resolver error text.")

tmp_gff <- tempfile(fileext = ".gff3")
writeLines(
  c(
    "##gff-version 3",
    "chr1\tsrc\tgene\t1\t100\t.\t+\t.\tID=gene-1;gene_name=LOC_TEST123;Name=LOC_TEST123;description=Sodium transporter HKT1%3B5 [Source:UniProtKB]"
  ),
  tmp_gff,
  useBytes = TRUE
)
on.exit(unlink(tmp_gff, force = TRUE), add = TRUE)

bridge_logs <- capture.output(
  resolve_external_alias_bridge(
    input_gene = "HKT1;5",
    query_candidates = c("HKT1;5", "LOC_TEST123", "SKC1"),
    file_path = tmp_gff
  ),
  type = "message"
)
assert_true(any(grepl("\\[PERF\\]\\[ALIAS_BRIDGE\\]", bridge_logs)), "Missing alias bridge perf logs.")
assert_true(any(grepl("resolved alias=LOC_TEST123", bridge_logs, fixed = TRUE)), "Missing resolved alias bridge log.")

cat("lookup-observability-smoke-ok\n")
