#!/usr/bin/env Rscript

read_all <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")

ui_txt <- read_all("ui.R")
server_txt <- read_all("server.R")
toggle_txt <- read_all(file.path("www", "js", "genomic_ruler_toggle.js"))
scss_txt <- read_all("custom.scss")
css_txt <- read_all(file.path("www", "css", "cgv_compiled.css"))

for (txt in list(ui_txt, server_txt)) {
    stopifnot(grepl('summary-display-side summary-display-side--left', txt, fixed = TRUE))
    stopifnot(grepl('summary-display-side summary-display-side--right', txt, fixed = TRUE))
    stopifnot(grepl('summary-display-detail-label', txt, fixed = TRUE))
    stopifnot(grepl('span("Visual")', txt, fixed = TRUE))
    stopifnot(grepl('span("Detail")', txt, fixed = TRUE))
    stopifnot(grepl('summary-genomic-ruler-toggle', txt, fixed = TRUE))
    stopifnot(grepl('summary-genomic-ruler-toggle-label', txt, fixed = TRUE))
    stopifnot(!grepl('summary-genomic-ruler-toggle--standalone', txt, fixed = TRUE))
}

stopifnot(!grepl('summary-display-context-label", "Context"', ui_txt, fixed = TRUE))
stopifnot(!grepl('summary-display-context-label", "Context"', server_txt, fixed = TRUE))
stopifnot(grepl('summary-display-context-subbar[\\s\\S]{0,2500}summary-genomic-ruler-toggle', ui_txt, perl = TRUE))
stopifnot(grepl('summary-display-context-subbar[\\s\\S]{0,500}header_genomic_ruler_button\\(\\)', server_txt, perl = TRUE))
stopifnot(grepl("rulerVisible ? 'Hide scale' : 'Show scale'", toggle_txt, fixed = TRUE))

for (txt in list(scss_txt, css_txt)) {
    stopifnot(grepl('grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr)', txt, fixed = TRUE))
    stopifnot(grepl('.summary-display-side--left', txt, fixed = TRUE))
    stopifnot(grepl('grid-column: 1;', txt, fixed = TRUE))
    stopifnot(grepl('justify-self: start;', txt, fixed = TRUE))
    stopifnot(grepl('.summary-display-side--right', txt, fixed = TRUE))
    stopifnot(grepl('grid-column: 3;', txt, fixed = TRUE))
    stopifnot(grepl('width: 100%;', txt, fixed = TRUE))
    stopifnot(grepl('max-width: 390px;', txt, fixed = TRUE))
    stopifnot(grepl('@container (max-width: 1050px)', txt, fixed = TRUE))
    stopifnot(grepl('.summary-display-detail-label', txt, fixed = TRUE))
    stopifnot(grepl('font-size: 8.3px;', txt, fixed = TRUE))
}

cat("header-balanced-layout-static-ok\n")
