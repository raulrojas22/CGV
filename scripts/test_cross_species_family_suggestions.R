#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(shiny)
})

workspace <- "/Users/rarojas/Documents/A_FULLAPP"
setwd(workspace)

source(file.path(workspace, "global.R"))
server_fun <- source(file.path(workspace, "server.R"), local = TRUE)$value

assert_true <- function(cond, msg) {
  if (!isTRUE(cond)) {
    stop(msg, call. = FALSE)
  }
}

annotation_paths <- c(
  file.path(workspace, "annotations", "GCF_000001735.4_TAIR10.1_genomic.gff.gz"),
  file.path(workspace, "annotations", "GCF_034140825.1_ASM3414082v1_genomic.gff.gz"),
  file.path(workspace, "annotations", "GCF_902167145.1_Zm-B73-REFERENCE-NAM-5.0_genomic.gff.gz")
)
file_labels <- c("Arabidopsis thaliana", "Oryza sativa ssp. japonica", "Zea mays")
det_list <- list(
  list(
    species_id = "arabidopsis_thaliana_gcf_000001735_4_tair10_1_genomic",
    organism = "Arabidopsis thaliana"
  ),
  list(
    species_id = "oryza_sativa_ssp_japonica_gcf_034140825_1_asm3414082v1_genomic",
    organism = "Oryza sativa ssp. japonica"
  ),
  list(
    species_id = "zea_mays_gcf_902167145_1_zm_b73_reference_nam_5_0_genomic",
    organism = "Zea mays"
  )
)

assert_true(all(file.exists(annotation_paths)), "Required HKT smoke-test annotations are missing.")
assert_true(is_low_specific_gene_family_query("hkt"), "'hkt' should be treated as a family-like query.")

testServer(server_fun, {
  assert_true(
    exists("find_partial_gene_suggestions_fast", mode = "function"),
    "Server partial-suggestion helper is not available."
  )

  suggestions <- find_partial_gene_suggestions_fast(
    annotation_paths = annotation_paths,
    query = "hkt",
    file_labels = file_labels,
    max_per_file = 12L,
    max_total = 20L,
    min_shared_organisms = 2L,
    time_budget_sec = 0.001,
    det_list = det_list,
    include_alias_sql = TRUE
  )

  hkt1 <- suggestions[tolower(as.character(suggestions$gene_name)) == "hkt1", , drop = FALSE]
  assert_true(nrow(hkt1) >= 1L, "Cross-species family suggestions should include HKT1.")
  assert_true(
    max(suppressWarnings(as.integer(hkt1$source_count)), na.rm = TRUE) >= 2L,
    "HKT1 should be supported by at least two selected organisms."
  )
  assert_true(
    max(suppressWarnings(as.integer(hkt1$source_count)), na.rm = TRUE) == 3L,
    "HKT1 should be supported by Arabidopsis, rice, and maize in the bundled alias indexes."
  )
})

cat("cross-species-family-suggestions-ok\n")
