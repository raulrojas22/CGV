#!/usr/bin/env Rscript

ui_txt <- paste(readLines("ui.R", warn = FALSE), collapse = "\n")
server_txt <- paste(readLines("server.R", warn = FALSE), collapse = "\n")
modules_txt <- paste(readLines(file.path("R", "modules.R"), warn = FALSE), collapse = "\n")
lifecycle_txt <- paste(readLines(file.path("R", "server_plot_lifecycle_domain.R"), warn = FALSE), collapse = "\n")
snapshot_txt <- paste(readLines(file.path("R", "server_session_snapshot_domain.R"), warn = FALSE), collapse = "\n")
analytics_txt <- paste(readLines(file.path("R", "server_analytics_domain.R"), warn = FALSE), collapse = "\n")
studio_js <- paste(readLines(file.path("www", "js", "figure_studio.js"), warn = FALSE), collapse = "\n")
app_css <- paste(readLines(file.path("www", "css", "cgv_compiled.css"), warn = FALSE), collapse = "\n")

expect_pattern <- function(txt, pattern, label) {
    if (!grepl(pattern, txt, perl = TRUE)) {
        stop(sprintf("Missing expected block 2 behavior: %s", label), call. = FALSE)
    }
}

expect_pattern(
    server_txt,
    'orientation_input_id <- paste0\\(scope, "_orientation_pick"\\)[\\s\\S]*"Genomic"[\\s\\S]*"transcription"[\\s\\S]*minus-strand loci are mirrored',
    "explicit genomic versus 5-prime-to-3-prime selector"
)
expect_pattern(
    ui_txt,
    'homo_orientation_pick|ortho_orientation_pick',
    "initial orientation controls"
)
expect_pattern(
    app_css,
    '\\.summary-display-orientation-subbar \\{[\\s\\S]*grid-column: 1 / -1;',
    "orientation selector has its own non-overlapping row"
)
expect_pattern(
    lifecycle_txt,
    'orientation_mode = reactive\\(\\{[\\s\\S]*homo_orientation_pick[\\s\\S]*orientation_mode = reactive\\(\\{[\\s\\S]*ortho_orientation_pick',
    "both search workflows pass orientation reactively"
)
expect_pattern(
    snapshot_txt,
    'homo_orientation_mode = as.character\\(input\\$homo_orientation_pick[\\s\\S]*ortho_orientation_mode = as.character\\(input\\$ortho_orientation_pick[\\s\\S]*Shiny.setInputValue\\(\'homo_orientation_pick\'[\\s\\S]*Shiny.setInputValue\\(\'ortho_orientation_pick\'',
    "orientation survives saved CGV work sessions"
)
expect_pattern(
    modules_txt,
    'gene_plot_axis_should_reverse[\\s\\S]*scale_x_reverse[\\s\\S]*orientation_mode = this_orientation_mode',
    "minus-strand plots reverse only in normalized orientation"
)
expect_pattern(
    modules_txt,
    'make_girafe_plot_cache_key[\\s\\S]*orientation_mode = "genomic"[\\s\\S]*normalize_gene_plot_orientation_mode\\(orientation_mode\\)',
    "orientation participates in plot cache identity"
)
expect_pattern(
    analytics_txt,
    'scatter_label_plotmath[\\s\\S]*italic\\(',
    "scatter labels use plotmath italics"
)
expect_pattern(
    server_txt,
    'label = scatter_label_plotmath\\)[\\s\\S]*parse = TRUE',
    "scatter rendering parses reliable scientific annotations"
)
expect_pattern(
    studio_js,
    'appendScientificSvgText\\(panelTitle, panel\\.title, panelScientificNames\\(panel\\)\\)',
    "Figure Studio export applies partial scientific italics"
)

cat("block2-ui-static-ok\n")
