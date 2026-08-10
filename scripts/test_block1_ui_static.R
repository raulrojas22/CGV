#!/usr/bin/env Rscript

ui_txt <- paste(readLines("ui.R", warn = FALSE), collapse = "\n")
server_txt <- paste(readLines("server.R", warn = FALSE), collapse = "\n")
toggle_txt <- paste(readLines(file.path("www", "js", "genomic_ruler_toggle.js"), warn = FALSE), collapse = "\n")
evidence_txt <- paste(readLines(file.path("www", "js", "gene_match_evidence_help.js"), warn = FALSE), collapse = "\n")
css_txt <- paste(readLines(file.path("www", "css", "cgv_compiled.css"), warn = FALSE), collapse = "\n")

stopifnot(grepl('summary-genomic-context-toggle-label", paste("Hide", short_label)', server_txt, fixed = TRUE))
stopifnot(grepl('header_genomic_context_button("neighbors"', server_txt, fixed = TRUE))
stopifnot(grepl('header_genomic_context_button("overlaps"', server_txt, fixed = TRUE))
stopifnot(grepl("label.textContent = (active ? 'Hide ' : 'Show ')", toggle_txt, fixed = TRUE))
stopifnot(grepl('summary-genomic-ruler-toggle-label", "Hide scale"', server_txt, fixed = TRUE))
stopifnot(grepl("label.textContent = rulerVisible ? 'Hide scale' : 'Show scale'", toggle_txt, fixed = TRUE))

stopifnot(grepl("analytics_labels_with_n <- function", server_txt, fixed = TRUE))
stopifnot(grepl('"N = ", format(nrow(all_exons)', server_txt, fixed = TRUE))
stopifnot(grepl('"N = ", format(nrow(all_introns)', server_txt, fixed = TRUE))
stopifnot(grepl("exon_labels_with_n", server_txt, fixed = TRUE))
stopifnot(grepl("intron_labels_with_n", server_txt, fixed = TRUE))

stopifnot(grepl('js/gene_match_evidence_help.js', ui_txt, fixed = TRUE))
stopifnot(grepl('`data-evidence-help` = "true"', server_txt, fixed = TRUE))
stopifnot(grepl('`aria-label` = "Explain evidence confidence"', server_txt, fixed = TRUE))
stopifnot(grepl("document.body.appendChild(tooltip)", evidence_txt, fixed = TRUE))
stopifnot(grepl("window.innerWidth - tipRect.width", evidence_txt, fixed = TRUE))
stopifnot(grepl("Stable gene, transcript or protein ID", evidence_txt, fixed = TRUE))
stopifnot(grepl("Name, alias, synonym or database link", evidence_txt, fixed = TRUE))
stopifnot(grepl("Descriptive term; verify before plotting", evidence_txt, fixed = TRUE))
stopifnot(grepl(".gene-match-evidence-tooltip {\n  position: fixed;", css_txt, fixed = TRUE))

cat("block1-ui-static-ok\n")
