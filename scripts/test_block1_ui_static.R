#!/usr/bin/env Rscript

ui_txt <- paste(readLines("ui.R", warn = FALSE), collapse = "\n")
server_txt <- paste(readLines("server.R", warn = FALSE), collapse = "\n")
toggle_txt <- paste(readLines(file.path("www", "js", "genomic_ruler_toggle.js"), warn = FALSE), collapse = "\n")

stopifnot(grepl('summary-genomic-context-toggle-label", "Hide neighbors"', ui_txt, fixed = TRUE))
stopifnot(grepl('summary-genomic-context-toggle-label", "Hide overlaps"', ui_txt, fixed = TRUE))
stopifnot(grepl("label.textContent = (active ? 'Hide ' : 'Show ')", toggle_txt, fixed = TRUE))
stopifnot(grepl('summary-genomic-ruler-toggle-label", "Hide scale"', ui_txt, fixed = TRUE))
stopifnot(grepl("label.textContent = rulerVisible ? 'Hide scale' : 'Show scale'", toggle_txt, fixed = TRUE))

stopifnot(grepl("analytics_labels_with_n <- function", server_txt, fixed = TRUE))
stopifnot(grepl('"N = ", format(nrow(all_exons)', server_txt, fixed = TRUE))
stopifnot(grepl('"N = ", format(nrow(all_introns)', server_txt, fixed = TRUE))
stopifnot(grepl("exon_labels_with_n", server_txt, fixed = TRUE))
stopifnot(grepl("intron_labels_with_n", server_txt, fixed = TRUE))

cat("block1-ui-static-ok\n")
