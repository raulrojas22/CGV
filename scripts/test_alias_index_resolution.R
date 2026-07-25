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

root <- normalizePath("/Users/rarojas/Documents/A_FULLAPP", winslash = "/", mustWork = TRUE)
source(file.path(root, "R", "alias_resolution.R"))
source(file.path(root, "R", "utils.R"))
source(file.path(root, "gene_search_lib.R"))

assert_true <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

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
invisible(write_alias_index_tsv(mock_rows, "mock_species", base_dir = tmp_root))

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

pipe_tp53_alias <- run_lookup_pipeline_pure(
  file_path = tmp_gff,
  input_gene = "TP53",
  det_info = det,
  enabled_external_sources = character(0),
  allow_partial_suggestions = FALSE
)
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
