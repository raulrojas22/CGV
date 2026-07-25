#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(vroom)
})

workspace <- "/Users/rarojas/Documents/A_FULLAPP"
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

source(file.path(workspace, "R", "alias_resolution.R"))
source(file.path(workspace, "R", "utils.R"))

assert_true <- function(cond, msg) {
  if (!isTRUE(cond)) {
    stop(msg, call. = FALSE)
  }
}

tmp_root <- tempfile("partial_gene_suggestions_")
dir.create(tmp_root, recursive = TRUE, showWarnings = FALSE)
old_wd <- getwd()
on.exit({
  setwd(old_wd)
  unlink(tmp_root, recursive = TRUE, force = TRUE)
}, add = TRUE)
setwd(tmp_root)

tmp_gff <- file.path(tmp_root, "partial_gene_fixture.gff3")
writeLines(
  c(
    "##gff-version 3",
    "chr1\tsrc\tgene\t1\t100\t.\t+\t.\tID=gene-HKT11;gene_name=HKT1%3B1;Name=HKT1%3B1",
    "chr1\tsrc\tgene\t200\t300\t.\t+\t.\tID=gene-HKT13;gene_name=HKT1%3B3;Name=HKT1%3B3",
    "chr1\tsrc\tgene\t400\t500\t.\t+\t.\tID=gene-HKT15;gene_name=HKT1%3B5;Name=HKT1%3B5",
    "chr1\tsrc\tgene\t600\t700\t.\t+\t.\tID=gene-HKT21;gene_name=HKT2%3B1;Name=HKT2%3B1",
    "chr1\tsrc\tgene\t800\t900\t.\t+\t.\tID=gene-SOS1;gene_name=SOS1;Name=SOS1"
  ),
  tmp_gff,
  useBytes = TRUE
)

hkt_suggestions <- find_partial_gene_suggestions(
  annotation_paths = tmp_gff,
  query = "hkt",
  file_labels = "Fixture species",
  max_total = 10L
)
assert_true(nrow(hkt_suggestions) >= 4L, "Query 'hkt' should suggest multiple HKT genes.")
assert_true(all(c("HKT1", "HKT2") %in% substr(hkt_suggestions$gene_name, 1, 4)),
            "HKT suggestions should preserve the user-facing gene names.")

hkt1_suggestions <- find_partial_gene_suggestions(tmp_gff, "HKT1", "Fixture species", max_total = 10L)
assert_true(nrow(hkt1_suggestions) >= 3L, "Query 'HKT1' should suggest HKT1 family members.")
assert_true(all(startsWith(hkt1_suggestions$gene_name[seq_len(min(3L, nrow(hkt1_suggestions)))], "HKT1")),
            "HKT1 prefix matches should be ranked first.")

none_suggestions <- find_partial_gene_suggestions(tmp_gff, "zzzz", "Fixture species", max_total = 10L)
assert_true(nrow(none_suggestions) == 0L, "Unrelated query should not produce suggestions.")

exact_dot <- search_gene_in_file(tmp_gff, "HKT1.5", show_diagnostics = FALSE, match_mode = "exact", return_meta = TRUE)
exact_dash <- search_gene_in_file(tmp_gff, "HKT1-5", show_diagnostics = FALSE, match_mode = "exact", return_meta = TRUE)
assert_true(!is.null(exact_dot$data) && nrow(exact_dot$data) > 0L,
            "Existing separator-tolerant lookup should still resolve HKT1.5.")
assert_true(!is.null(exact_dash$data) && nrow(exact_dash$data) > 0L,
            "Existing separator-tolerant lookup should still resolve HKT1-5.")

tmp_gff_2 <- file.path(tmp_root, "partial_gene_fixture_2.gff3")
writeLines(
  c(
    "##gff-version 3",
    "chr1\tsrc\tgene\t1\t100\t.\t+\t.\tID=gene-HKT15-B;gene_name=HKT1%3B5;Name=HKT1%3B5",
    "chr1\tsrc\tgene\t200\t300\t.\t+\t.\tID=gene-HKT31;gene_name=HKT3%3B1;Name=HKT3%3B1"
  ),
  tmp_gff_2,
  useBytes = TRUE
)

cross_suggestions <- find_partial_gene_suggestions(
  annotation_paths = c(tmp_gff, tmp_gff_2),
  query = "hkt",
  file_labels = c("Fixture A", "Fixture B"),
  max_total = 15L
)
hkt15_row <- cross_suggestions[tolower(cross_suggestions$gene_name) == "hkt1;5", , drop = FALSE]
assert_true(nrow(hkt15_row) == 1L && identical(as.integer(hkt15_row$source_count[1]), 2L),
            "Cross-species suggestions should aggregate repeated gene names and count sources.")
assert_true(identical(cross_suggestions$gene_name[1], "HKT1;5"),
            "Cross-species suggestions should prioritize candidates found in more organisms.")

cross_dedicated <- find_cross_species_gene_suggestions(
  annotation_paths = c(tmp_gff, tmp_gff_2),
  query = "hkt",
  file_labels = c("Fixture A", "Fixture B"),
  max_total = 15L
)
hkt15_dedicated <- cross_dedicated[tolower(cross_dedicated$gene_name) == "hkt1;5", , drop = FALSE]
assert_true(identical(cross_dedicated$gene_name[1], "HKT1;5"),
            "Dedicated cross-species suggestions should rank multi-organism support first.")
assert_true(nrow(hkt15_dedicated) == 1L && identical(as.integer(hkt15_dedicated$source_count[1]), 2L),
            "Dedicated cross-species suggestions should preserve source_count.")
assert_true("source_labels" %in% names(cross_dedicated) && grepl("Fixture A", hkt15_dedicated$source_labels[1], fixed = TRUE) &&
              grepl("Fixture B", hkt15_dedicated$source_labels[1], fixed = TRUE),
            "Dedicated cross-species suggestions should preserve organism labels.")

exact_lookup_no_partial <- run_lookup_pipeline_pure(
  file_path = tmp_gff,
  input_gene = "HKT1;5",
  det_info = list(organism = "Fixture species", taxid = NA_integer_),
  enabled_external_sources = character(0)
)
assert_true(!identical(as.character(exact_lookup_no_partial$lookup_stage), "partial_suggestions"),
            "Exact matches should not route to partial suggestions.")

partial_lookup <- run_lookup_pipeline_pure(
  file_path = tmp_gff,
  input_gene = "hkt",
  det_info = list(organism = "Fixture species", taxid = NA_integer_),
  enabled_external_sources = c("mygene", "uniprot")
)
assert_true(is.null(partial_lookup$data) || nrow(partial_lookup$data) == 0L,
            "Low-specificity family queries with local partial candidates must not auto-plot an alias.")
assert_true(identical(as.character(partial_lookup$lookup_stage), "partial_suggestions"),
            "Low-specificity family queries should route to the partial-suggestion flow.")

contains_partial_lookup <- run_lookup_pipeline_pure(
  file_path = tmp_gff,
  input_gene = "KT1",
  det_info = list(organism = "Fixture species", taxid = NA_integer_),
  enabled_external_sources = c("mygene", "uniprot")
)
assert_true(identical(as.character(contains_partial_lookup$lookup_stage), "partial_suggestions"),
            "Queries contained inside local gene names should route to partial suggestions immediately after exact lookup fails.")

invisible(precompute_annotation_index_cache(tmp_gff, base_dir = "."))
fast_index_suggestions <- find_partial_gene_suggestions_in_index(
  file_path = tmp_gff,
  query = "KT1",
  file_label = "Fixture species",
  max_suggestions = 10L,
  allow_build_index = FALSE
)
assert_true(nrow(fast_index_suggestions) >= 3L,
            "Fast partial suggestions should use an existing gene_light disk index for contained queries.")

forced_external_lookup <- run_lookup_pipeline_pure(
  file_path = tmp_gff,
  input_gene = "hkt",
  det_info = list(organism = "Fixture species", taxid = NA_integer_),
  enabled_external_sources = character(0),
  allow_partial_suggestions = FALSE
)
assert_true(!identical(as.character(forced_external_lookup$lookup_stage), "partial_suggestions"),
            "Explicit external-alias searches should bypass the partial-suggestion flow.")
assert_true(!identical(as.character(forced_external_lookup$lookup_stage), "local_flex"),
            "Explicit external-alias searches should not auto-plot local flexible partial matches.")

ortho_local_job <- list(
  file_idx = 1L,
  file_path = tmp_gff,
  file_label = "Fixture species",
  forced_genome = "",
  det = list(organism = "Fixture species", taxid = NA_integer_),
  gene_name = "hkt",
  enabled_external_sources = character(0),
  allow_partial_suggestions = FALSE
)
ortho_local_res <- run_orthologous_lookup_job_pure(ortho_local_job)
assert_true(!identical(as.character((ortho_local_res$lookup %||% list())$lookup_stage), "partial_suggestions"),
            "Cross-species local lookup jobs should keep partial suggestions out of the fast path.")

setwd(workspace)
oryza_ann <- file.path(workspace, "annotations", "GCF_034140825.1_ASM3414082v1_genomic.gff.gz")
oryza_species_id <- "oryza_sativa_ssp_japonica_gcf_034140825_1_asm3414082v1_genomic"
oryza_expected_hkt <- c(
  "HKT1;1", "HKT1;3", "HKT1;4", "HKT2;1", "HKT2;3", "HKT2;4",
  "HKT1", "hkt3", "hkt4", "hkt6", "hkt7", "HKT8", "hkt9", "HKT1.5"
)
assert_true(file.exists(oryza_ann), "Oryza japonica annotation fixture is required for the HKT smoke test.")

if (exists(".gff_gene_light_index_cache", inherits = TRUE)) {
  rm(list = ls(envir = .gff_gene_light_index_cache, all.names = TRUE), envir = .gff_gene_light_index_cache)
}
oryza_det <- list(
  organism = "Oryza sativa ssp. japonica",
  taxid = 39947L,
  species_id = oryza_species_id,
  preloaded_id = oryza_species_id
)
oryza_cold <- find_deterministic_partial_gene_suggestions(
  annotation_paths = oryza_ann,
  query = "hkt",
  file_labels = "Oryza sativa ssp. japonica",
  det_list = list(oryza_det),
  max_per_file = 20L,
  max_total = 20L,
  min_query_chars = 2L,
  include_alias_sql = TRUE,
  base_dir = workspace
)
missing_cold <- setdiff(oryza_expected_hkt, as.character(oryza_cold$gene_name %||% character(0)))
assert_true(length(missing_cold) == 0L,
            paste("Cold deterministic Oryza HKT suggestions are missing:", paste(missing_cold, collapse = ", ")))

invisible(build_gff_gene_light_index(oryza_ann))
oryza_hot <- find_deterministic_partial_gene_suggestions(
  annotation_paths = oryza_ann,
  query = "hkt",
  file_labels = "Oryza sativa ssp. japonica",
  det_list = list(oryza_det),
  max_per_file = 20L,
  max_total = 20L,
  min_query_chars = 2L,
  include_alias_sql = TRUE,
  base_dir = workspace
)
missing_hot <- setdiff(oryza_expected_hkt, as.character(oryza_hot$gene_name %||% character(0)))
assert_true(length(missing_hot) == 0L,
            paste("Hot deterministic Oryza HKT suggestions are missing:", paste(missing_hot, collapse = ", ")))

oryza_lookup <- run_lookup_pipeline_pure(
  file_path = oryza_ann,
  input_gene = "hkt",
  det_info = oryza_det,
  file_label = "Oryza sativa ssp. japonica",
  enabled_external_sources = character(0)
)
assert_true(identical(as.character(oryza_lookup$lookup_stage), "partial_suggestions"),
            "Oryza hkt should route to partial suggestions instead of plotting a partial local match.")
missing_lookup <- setdiff(oryza_expected_hkt, as.character(oryza_lookup$partial_gene_suggestions$gene_name %||% character(0)))
assert_true(length(missing_lookup) == 0L,
            paste("Lookup-carried Oryza HKT suggestions are missing:", paste(missing_lookup, collapse = ", ")))

indica_ann <- file.path(workspace, "annotations", "Oryza_indica.ASM465v1.62.gff3.gz")
indica_species_id <- "oryza_sativa_indica_group_oryza_indica_asm465v1_62"
assert_true(file.exists(indica_ann), "Oryza indica Ensembl annotation fixture is required for alias suggestion regression.")
indica_det <- list(
  organism = "Oryza sativa Indica Group",
  taxid = 39946L,
  species_id = indica_species_id,
  preloaded_id = indica_species_id
)
indica_suggestions <- find_deterministic_partial_gene_suggestions(
  annotation_paths = indica_ann,
  query = "hkt",
  file_labels = "Oryza sativa Indica Group",
  det_list = list(indica_det),
  max_per_file = 20L,
  max_total = 20L,
  min_query_chars = 2L,
  include_alias_sql = TRUE,
  base_dir = workspace
)
indica_hkt15 <- indica_suggestions[indica_suggestions$gene_name == "HKT1;5", , drop = FALSE]
assert_true(nrow(indica_hkt15) == 1L &&
              identical(as.character(indica_hkt15$local_gene_id[1]), "gene:BGIOSGA001800") &&
              identical(as.character(indica_hkt15$source_db[1]), "GFF") &&
              identical(as.character(indica_hkt15$term_type[1]), "description") &&
              !isTRUE(indica_hkt15$requires_confirmation[1]),
            "Oryza indica HKT1;5 suggestion should retain its local GFF description bridge.")

indica_hkt1 <- indica_suggestions[indica_suggestions$gene_name == "HKT1", , drop = FALSE]
assert_true(nrow(indica_hkt1) == 1L &&
              identical(as.character(indica_hkt1$local_gene_id[1]), "gene:BGIOSGA017063") &&
              grepl("BioMart", as.character(indica_hkt1$source_db[1]), fixed = TRUE) &&
              isTRUE(indica_hkt1$requires_confirmation[1]),
            "Oryza indica external HKT1 alias should be retained but require confirmation.")

indica_hkt15_lookup <- run_lookup_pipeline_pure(
  file_path = indica_ann,
  input_gene = "HKT1;5",
  det_info = indica_det,
  file_label = "Oryza sativa Indica Group",
  enabled_external_sources = character(0),
  allow_partial_suggestions = FALSE
)
assert_true(identical(as.character(indica_hkt15_lookup$lookup_stage), "alias_index") &&
              identical(as.character(indica_hkt15_lookup$matched_gene_id), "gene:BGIOSGA001800"),
            "Oryza indica local LOW/description HKT1;5 alias should resolve through the verified local bridge.")

indica_hkt15_direct <- run_lookup_pipeline_pure(
  file_path = indica_ann,
  input_gene = "gene:BGIOSGA001800",
  det_info = indica_det,
  file_label = "Oryza sativa Indica Group",
  enabled_external_sources = character(0),
  allow_partial_suggestions = TRUE
)
assert_true(!is.null(indica_hkt15_direct$data) &&
              is.data.frame(indica_hkt15_direct$data) &&
              nrow(indica_hkt15_direct$data) > 0L &&
              identical(as.character(indica_hkt15_direct$matched_gene_id), "gene:BGIOSGA001800"),
            "Oryza indica selected local_gene_id should plot directly without re-entering partial suggestions.")

indica_hkt1_forced <- run_lookup_pipeline_pure(
  file_path = indica_ann,
  input_gene = "HKT1",
  det_info = indica_det,
  file_label = "Oryza sativa Indica Group",
  enabled_external_sources = character(0),
  allow_partial_suggestions = FALSE
)
assert_true(identical(as.character(indica_hkt1_forced$lookup_stage), "alias_index") &&
              identical(as.character(indica_hkt1_forced$matched_gene_id), "gene:BGIOSGA017063"),
            "Oryza indica external HKT1 alias should remain resolvable only when the user explicitly confirms/bypasses partial suggestions.")
setwd(tmp_root)

tmp_gff_exact_family <- file.path(tmp_root, "partial_gene_exact_family_fixture.gff3")
writeLines(
  c(
    "##gff-version 3",
    "chr1\tsrc\tgene\t1\t100\t.\t+\t.\tID=gene-HKT;gene_name=HKT;Name=HKT",
    "chr1\tsrc\tgene\t120\t180\t.\t+\t.\tID=gene-HKT1;gene_name=HKT1;Name=HKT1",
    "chr1\tsrc\tgene\t200\t300\t.\t+\t.\tID=gene-HKT15;gene_name=HKT1%3B5;Name=HKT1%3B5"
  ),
  tmp_gff_exact_family,
  useBytes = TRUE
)
generic_bridge <- resolve_external_alias_bridge(
  input_gene = "hkt",
  query_candidates = "HKT",
  file_path = tmp_gff_exact_family,
  search_fun = search_gene_in_file
)
assert_true(!isTRUE(generic_bridge$found),
            "External alias bridge must not accept case-only generic family aliases such as hkt/HKT.")

subfamily_bridge <- resolve_external_alias_bridge(
  input_gene = "hkt",
  query_candidates = "HKT1",
  file_path = tmp_gff_exact_family,
  search_fun = search_gene_in_file
)
assert_true(!isTRUE(subfamily_bridge$found),
            "External alias bridge must not auto-plot subfamily aliases such as hkt/HKT1.")

specific_bridge <- resolve_external_alias_bridge(
  input_gene = "hkt",
  query_candidates = c("HKT", "HKT1;5"),
  file_path = tmp_gff_exact_family,
  search_fun = search_gene_in_file
)
assert_true(isTRUE(specific_bridge$found) && identical(as.character(specific_bridge$best_alias_used), "HKT1;5"),
            "External alias bridge should still accept specific aliases for a family query.")

cat("partial-gene-suggestions-smoke-ok\n")
