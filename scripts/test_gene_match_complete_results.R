#!/usr/bin/env Rscript

workspace <- normalizePath(".", winslash = "/", mustWork = TRUE)
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

source(file.path(workspace, "R", "alias_resolution.R"))
source(file.path(workspace, "R", "utils.R"))

assert_true <- function(cond, msg) {
    if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

fox_choices <- c("FOX", "FOXP1", "FOXP2", sprintf("FOX%03d", seq_len(45L)))
fox_matches <- find_partial_gene_suggestions_from_choices(
    choices = fox_choices,
    query = "fox",
    file_label = "Human fixture",
    max_suggestions = Inf
)

assert_true(
    nrow(fox_matches) == length(fox_choices),
    "Unlimited family suggestions must return every FOX member, including results beyond the old first 20."
)
assert_true(
    identical(as.character(fox_matches$gene_name[[1L]]), "FOX") &&
        identical(as.character(fox_matches$match_type[[1L]]), "exact"),
    "The exact FOX match must be retained, labelled exact, and ranked first."
)
assert_true(
    all(c("FOXP1", "FOXP2", "FOX045") %in% fox_matches$gene_name),
    "FOX family results must include FOXP1, FOXP2, and members after the legacy display limit."
)

hkt_alias_rows <- data.frame(
    gene_name = c("HKT1;1", "hkt4", "OsHKT4", "OsHKT1;1"),
    file_label = rep("Oryza fixture", 4L),
    match_type = rep("prefix", 4L),
    score = c(100, 95, 94, 93),
    source_count = rep(1L, 4L),
    local_gene_id = c("", rep("gene-HKT1;1", 3L)),
    local_symbol = c("", rep("HKT1;1", 3L)),
    term_type = c("", rep("gene_synonym", 3L)),
    source_db = c("", rep("GFF", 3L)),
    confidence = rep("HIGH", 4L),
    match_role = c("", rep("synonym", 3L)),
    requires_confirmation = rep(FALSE, 4L),
    stringsAsFactors = FALSE
)
hkt_collapsed <- collapse_partial_gene_suggestions_by_locus(hkt_alias_rows, query = "hkt")
assert_true(
    nrow(hkt_collapsed) == 1L &&
        identical(hkt_collapsed$gene_name[[1L]], "HKT1;1") &&
        identical(hkt_collapsed$local_gene_id[[1L]], "gene-HKT1;1"),
    "Aliases resolving to one local locus must render as one canonical gene suggestion."
)
assert_true(
    all(c("hkt4", "OsHKT4", "OsHKT1;1") %in%
        strsplit(hkt_collapsed$alias_names[[1L]], " | ", fixed = TRUE)[[1L]]),
    "The collapsed canonical suggestion must retain every alternate alias for display and filtering."
)

trp_alias <- hkt_alias_rows[1L, , drop = FALSE]
trp_alias$gene_name <- "TRP"
trp_alias$match_type <- "exact"
trp_alias$local_gene_id <- "gene-TYRP1"
trp_alias$local_symbol <- "TYRP1"
trp_collapsed <- collapse_partial_gene_suggestions_by_locus(trp_alias, query = "TRP")
assert_true(
    identical(trp_collapsed$gene_name[[1L]], "TYRP1") &&
        identical(trp_collapsed$alias_names[[1L]], "TRP") &&
        identical(trp_collapsed$match_type[[1L]], "exact"),
    "An exact alias must highlight the canonical locus while preserving the exact alias on the same card."
)

server_text <- paste(readLines(file.path(workspace, "server.R"), warn = FALSE), collapse = "\n")
ui_text <- paste(readLines(file.path(workspace, "ui.R"), warn = FALSE), collapse = "\n")
scss_text <- paste(readLines(file.path(workspace, "www", "css", "custom.scss"), warn = FALSE), collapse = "\n")

for (token in c(
    "gene-match-browser",
    "gene-match-filter-input",
    "gene-match-result-count",
    "gene-match-pagination",
    "gene-match-exact-badge",
    "gene-match-card-header",
    "gene-match-detail-row",
    "gene-match-help",
    "gene-match-detail-value--organism",
    "alias-index-match-card",
    "collapse_partial_gene_suggestions_by_locus"
)) {
    assert_true(
        grepl(token, paste(server_text, ui_text, scss_text), fixed = TRUE),
        paste("Missing complete-results modal feature:", token)
    )
}
assert_true(
    grepl("max_per_file <- Inf", server_text, fixed = TRUE) &&
        grepl("max_total <- Inf", server_text, fixed = TRUE),
    "Possible Gene Matches must not reintroduce the legacy per-file or total truncation."
)
assert_true(
    !grepl("max_rows <- min(nrow(matches), 20L)", server_text, fixed = TRUE),
    "Alias match rendering must not silently truncate at 20 rows."
)
assert_true(
    !grepl("box-shadow: inset 3px 0 0", scss_text, fixed = TRUE),
    "Exact-match cards must not reintroduce the artificial vertical accent stripe."
)
assert_true(
    grepl('if (identical(mode, "orthologous")) detail_row("Name seen in"', server_text, fixed = TRUE) &&
        !grepl('else "Organism", organism_value', server_text, fixed = TRUE),
    "Organism details must be omitted from Multi-Gene cards and reserved for Cross-Species cards."
)
assert_true(
    grepl("HIGH: a stable gene, transcript, or protein identifier.", server_text, fixed = TRUE) &&
        grepl("MEDIUM: an annotation name, alias, synonym", server_text, fixed = TRUE) &&
        grepl("LOW: a descriptive or less-specific term", server_text, fixed = TRUE),
    "Evidence help must explain HIGH, MEDIUM, and LOW confidence levels."
)

cat("gene-match-complete-results-ok\n")
