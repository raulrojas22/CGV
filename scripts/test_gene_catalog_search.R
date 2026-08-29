#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
safe_url_decode <- function(x) x
app_debug_log <- function(...) invisible(NULL)
get_cgv_data_root <- function(base_dir = ".") normalizePath(base_dir, winslash = "/", mustWork = FALSE)

source(file.path("R", "alias_resolution.R"))

assert_true <- function(value, message) {
  if (!isTRUE(value)) stop(message, call. = FALSE)
}

tmp_root <- tempfile("cgv-gene-catalog-")
dir.create(file.path(tmp_root, "data", "alias_index"), recursive = TRUE)
on.exit(unlink(tmp_root, recursive = TRUE, force = TRUE), add = TRUE)

make_row <- function(organism_id, term, term_type, gene, symbol, description = "") {
  keys <- alias_query_keys_df(term)
  data.frame(
    organism_id = organism_id,
    organism_name = organism_id,
    taxid = "1",
    keys,
    term_type = term_type,
    local_gene_id = gene,
    local_transcript_id = "",
    local_feature_id = gene,
    local_symbol = symbol,
    chromosome = "chr1",
    start = 10,
    end = 100,
    strand = "+",
    description = description,
    source_db = "fixture",
    source_release = "test",
    confidence = if (term_type == "gene_symbol") "HIGH" else "MEDIUM",
    evidence_source = "fixture",
    stringsAsFactors = FALSE
  )
}

fixtures <- list(
  rice = rbind(
    make_row("rice", "HKT1;1", "gene_symbol", "gene-HKT1;1", "HKT1;1", "sodium transporter"),
    make_row("rice", "ShKT domain-containing protein", "gene_name", "gene-noise", "NOISE", "unrelated domain")
  ),
  vine = rbind(
    make_row("vine", "HKT", "synonym", "gene-vine-hkt", "LOC100", "sodium transporter HKT1"),
    make_row("vine", "DHKTD1", "synonym", "gene-noise-2", "DHKTD1", "unrelated enzyme")
  )
)

for (organism_id in names(fixtures)) {
  db_path <- file.path(tmp_root, "data", "alias_index", paste0(organism_id, ".alias_index.sqlite"))
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  DBI::dbWriteTable(con, "alias_index", fixtures[[organism_id]])
  DBI::dbExecute(con, "CREATE INDEX idx_upper ON alias_index(query_term_upper)")
  DBI::dbDisconnect(con)
}

registry <- data.frame(
  species_id = c("rice", "vine"),
  organism = c("Oryza test", "Vitis test"),
  icon_url = c("/icons/rice.ico", "/icons/vine.ico"),
  kingdom = "Plantae",
  taxid = c("1", "2"),
  annotation_path = "",
  ready = TRUE,
  stringsAsFactors = FALSE
)

results <- search_installed_alias_catalog("HKT", registry, base_dir = tmp_root)
assert_true(nrow(results) == 2L, "Catalog partial search included embedded-token noise or lost a valid HKT candidate.")
assert_true(identical(unique(results$organism_id), c("vine", "rice")), "Catalog ranking did not keep exact matches ahead of prefix candidates.")
assert_true(all(results$matched_term %in% c("HKT", "HKT1;1")), "Catalog returned a term without an HKT token boundary.")
assert_true(identical(results$match_type, c("exact", "prefix")), "Catalog did not classify exact and prefix results correctly.")
assert_true(all(nzchar(results$icon_url)), "Catalog results did not preserve organism icons.")


server_source <- paste(readLines(file.path("server.R"), warn = FALSE), collapse = "\n")
catalog_start <- regexpr("output$catalog_results_dt <- DT::renderDataTable", server_source, fixed = TRUE)[1]
catalog_end <- regexpr("outputOptions(output, \"catalog_results_dt\"", server_source, fixed = TRUE)[1]
assert_true(catalog_start > 0L && catalog_end > catalog_start, "Could not locate the Gene Catalog table renderer.")
catalog_renderer <- substr(server_source, catalog_start, catalog_end)
assert_true(
  grepl("esc <- function(x, attribute = FALSE)", catalog_renderer, fixed = TRUE),
  "Gene Catalog renderer must define its attribute-aware HTML escaping helper locally."
)
assert_true(
  !grepl("esc_attr(", catalog_renderer, fixed = TRUE),
  "Gene Catalog renderer references the out-of-scope esc_attr helper."
)
assert_true(
  grepl("<strong><em>", catalog_renderer, fixed = TRUE) && !grepl("catalog-gene-locus", catalog_renderer, fixed = TRUE),
  "Gene Catalog renderer must italicize organism names and omit locus coordinates."
)
assert_true(
  grepl("confidence is not evidence of orthology", catalog_renderer, fixed = TRUE),
  "Gene Catalog confidence help must retain the scientific orthology caveat."
)

cat("gene-catalog-search-ok\n")
