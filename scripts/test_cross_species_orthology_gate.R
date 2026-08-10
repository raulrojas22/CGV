#!/usr/bin/env Rscript

source(file.path("R", "alias_resolution.R"))
source(file.path("R", "utils.R"))
source("gene_search_lib.R")

assert_true <- function(value, message) {
    if (!isTRUE(value)) stop(message, call. = FALSE)
}

arab_id <- "arabidopsis_thaliana_gcf_000001735_4_tair10_1_genomic"
maize_id <- "zea_mays_gcf_902167145_1_zm_b73_reference_nam_5_0_genomic"
rice_id <- "oryza_sativa_ssp_japonica_gcf_034140825_1_asm3414082v1_genomic"
arab_path <- file.path("annotations", "GCF_000001735.4_TAIR10.1_genomic.gff.gz")
maize_path <- file.path("annotations", "GCF_902167145.1_Zm-B73-REFERENCE-NAM-5.0_genomic.gff.gz")
rice_path <- file.path("annotations", "GCF_034140825.1_ASM3414082v1_genomic.gff.gz")

arab_trp1 <- search_alias_index_for_context(
    "TRP1", arab_path,
    list(species_id = arab_id, organism = "Arabidopsis thaliana", taxid = 3702)
)
maize_trp1 <- search_alias_index_for_context(
    "TRP1", maize_path,
    list(species_id = maize_id, organism = "Zea mays", taxid = 4577)
)
rice_trp1 <- search_alias_index_for_context(
    "TRP1", rice_path,
    list(species_id = rice_id, organism = "Oryza sativa ssp. japonica", taxid = 39947)
)

assert_true(identical(arab_trp1$status, "multiple_exact"), "TRP1 must remain ambiguous between the two Arabidopsis loci.")
assert_true(identical(maize_trp1$status, "unique_exact"), "TRP1 must resolve to one maize alias-index locus.")
assert_true(identical(rice_trp1$status, "no_match"), "TRP1 must not be claimed as a local rice match.")
assert_true(
    identical(unique(as.character(maize_trp1$matches$local_gene_id)), "gene-LOC542117"),
    "The maize TRP1 synonym must resolve to LOC542117/BX1."
)

arab_ids <- ensembl_gene_ids_for_alias_locus(
    local_gene_id = "gene-AT5G17990",
    organism_id = arab_id,
    annotation_path = arab_path,
    organism_name = "Arabidopsis thaliana",
    taxid = 3702
)
maize_ids <- ensembl_gene_ids_for_alias_locus(
    local_gene_id = "gene-LOC542117",
    organism_id = maize_id,
    annotation_path = maize_path,
    organism_name = "Zea mays",
    taxid = 4577
)
assert_true(identical(arab_ids, "AT5G17990"), "Arabidopsis native locus ID must be recognized as an Ensembl gene ID.")
assert_true(identical(maize_ids, "Zm00001eb165610"), "Maize LOC542117 must resolve to its Ensembl gene ID.")

maize_true_ortholog <- search_alias_index_for_context(
    "Zm00001eb403640", maize_path,
    list(species_id = maize_id, organism = "Zea mays", taxid = 4577)
)
rice_true_ortholog <- search_alias_index_for_context(
    "Os03g0126000", rice_path,
    list(species_id = rice_id, organism = "Oryza sativa ssp. japonica", taxid = 39947)
)
assert_true(
    identical(maize_true_ortholog$status, "unique_exact") &&
        identical(unique(as.character(maize_true_ortholog$matches$local_gene_id)), "gene-LOC100192060"),
    "The true maize one-to-one ortholog of AT5G17990 must resolve to LOC100192060, not TRP1/BX1."
)
assert_true(
    identical(rice_true_ortholog$status, "unique_exact") &&
        identical(unique(as.character(rice_true_ortholog$matches$local_gene_id)), "gene-LOC4331468"),
    "The true rice one-to-one ortholog of AT5G17990 must resolve to LOC4331468."
)

one_to_one_payload <- list(data = list(list(
    id = "AT5G17990",
    homologies = list(list(
        type = "ortholog_one2one",
        method_link_type = "ENSEMBL_ORTHOLOGUES",
        taxonomy_level = "Mesangiospermae",
        source = list(id = "AT5G17990", species = "arabidopsis_thaliana", taxon_id = 3702, perc_id = 56.5),
        target = list(id = "Zm00001eb403640", species = "zea_mays", taxon_id = 4577, perc_id = 63.8)
    ))
)))
parsed <- parse_ensembl_homology_response(one_to_one_payload)
assert_true(nrow(parsed) == 1L && identical(parsed$homology_type, "ortholog_one2one"), "Ensembl homology payload parsing failed.")

good <- evaluate_ensembl_orthology_pair(
    "AT5G17990", "Zm00001eb403640", "zea_mays",
    list(status = "ok", rows = parsed)
)
wrong_same_name <- evaluate_ensembl_orthology_pair(
    "AT5G17990", "Zm00001eb165610", "zea_mays",
    list(status = "ok", rows = parsed)
)
assert_true(isTRUE(good$verified), "A matching Ensembl one-to-one pair should be accepted.")
assert_true(!isTRUE(wrong_same_name$verified) && identical(wrong_same_name$status, "different_locus"),
            "A same-name but different target locus must be rejected.")

make_result <- function(file_idx, file_path, file_label, species_id, organism, taxid, local_gene_id, local_symbol) {
    list(
        found = TRUE,
        file_idx = file_idx,
        file_path = file_path,
        file_label = file_label,
        det = list(species_id = species_id, organism = organism, taxid = taxid, kingdom = "Plantae"),
        lookup = list(matched_gene_id = local_gene_id, matched_gene_name = local_symbol)
    )
}

arab_result <- make_result(1L, arab_path, "Arabidopsis thaliana", arab_id, "Arabidopsis thaliana", 3702, "gene-AT5G17990", "TRP1")
maize_wrong_result <- make_result(2L, maize_path, "Zea mays", maize_id, "Zea mays", 4577, "gene-LOC542117", "TRP1")
maize_true_result <- make_result(2L, maize_path, "Zea mays", maize_id, "Zea mays", 4577, "gene-LOC100192060", "LOC100192060")

fixture_fetch <- function(source_gene_id, source_species, target_species, compara = "") {
    list(status = "ok", rows = parsed, error = "")
}
rejected <- validate_cross_species_orthology_results(list(arab_result, maize_wrong_result), fetch_fun = fixture_fetch)
accepted <- validate_cross_species_orthology_results(list(arab_result, maize_true_result), fetch_fun = fixture_fetch)
assert_true(identical(rejected$status, "no_verified_pair") && length(rejected$approved_positions) == 0L,
            "TRP1 name collision must not pass the cross-species gate.")
assert_true(identical(accepted$status, "verified") && identical(accepted$approved_positions, c(1L, 2L)),
            "A verified one-to-one pair must pass the cross-species gate.")

server_text <- paste(readLines("server.R", warn = FALSE), collapse = "\n")
for (token in c(
    "pendingOrthoReferenceAnchor",
    "expand_reference_result_with_one_to_one_orthologs",
    "Verifying locus-level orthology with Ensembl Compara",
    "Shared aliases or symbols alone are not accepted as biological equivalence"
)) {
    assert_true(grepl(token, server_text, fixed = TRUE), paste("Missing server orthology-gate integration:", token))
}

cat("Cross-species orthology gate regression tests passed.\n")
