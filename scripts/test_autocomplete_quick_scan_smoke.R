#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(later)
  library(stringr)
  library(purrr)
})

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

source("/Users/rarojas/Documents/A_FULLAPP/R/utils.R")
source("/Users/rarojas/Documents/A_FULLAPP/R/server_autocomplete_domain.R")

assert_true <- function(cond, msg) {
  if (!isTRUE(cond)) {
    stop(msg, call. = FALSE)
  }
}

make_state_cell <- function(initial = NULL) {
  value <- initial
  function(value_new = NULL) {
    if (missing(value_new)) {
      return(value)
    }
    value <<- value_new
    invisible(value)
  }
}

session_stub <- new.env(parent = emptyenv())
session_stub$messages <- list()
session_stub$sendCustomMessage <- function(type, payload) {
  session_stub$messages[[length(session_stub$messages) + 1L]] <<- list(type = type, payload = payload)
  invisible(NULL)
}

domain <- init_autocomplete_domain(
  geneAutocompleteCache_rv = make_state_cell(list()),
  quickGeneAutocompleteCache_rv = make_state_cell(list()),
  globalGeneSuggestionSources_rv = make_state_cell(list()),
  session = session_stub
)

tmp_gff <- tempfile(fileext = ".gff3")
writeLines(
  c(
    "##gff-version 3",
    paste0("chr1\tsrc\tgene\t1\t100\t.\t+\t.\tID=gene-1;gene_name=GENE_A;Name=GENE_A"),
    paste0("chr1\tsrc\tgene\t200\t300\t.\t+\t.\tID=gene-2;Name=GENE_B"),
    rep("# filler", 5000L),
    paste0("chr1\tsrc\tgene\t400\t500\t.\t+\t.\tID=gene-3;gene_name=GENE_C;Name=GENE_C")
  ),
  tmp_gff,
  useBytes = TRUE
)
on.exit(unlink(tmp_gff, force = TRUE), add = TRUE)

sync_suggestions <- domain$extract_quick_gene_suggestions(
  tmp_gff,
  max_suggestions = 50L,
  max_lines = 20000L,
  max_seconds = 2,
  chunk_lines = 300L
)

state <- domain$init_quick_gene_scan_state(
  tmp_gff,
  max_suggestions = 50L,
  max_lines = 20000L,
  max_seconds = 2,
  chunk_lines = 300L
)
on.exit(domain$close_quick_gene_scan_state(state), add = TRUE)
repeat {
  step <- domain$step_quick_gene_scan_state(state)
  if (isTRUE(step$done)) {
    async_like <- step$suggestions
    break
  }
}

assert_true(identical(sort(sync_suggestions), sort(async_like)),
            "Incremental quick-scan path diverged from the synchronous quick-scan output.")

cat("autocomplete-quick-scan-smoke-ok\n")
