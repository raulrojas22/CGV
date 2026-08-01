server_source <- paste(readLines("server.R", warn = FALSE), collapse = "\n")
report_source <- paste(
    readLines("R/server_shared_analysis_domain.R", warn = FALSE),
    collapse = "\n"
)

required_lastz_routes <- c(
    "input$ortho_pip_run_alignments",
    "input$ortho_multipip_run_alignments",
    "input$homo_pip_run_alignments",
    "input$homo_multipip_run_alignments"
)

stopifnot(all(vapply(
    required_lastz_routes,
    function(route) grepl(route, server_source, fixed = TRUE),
    logical(1)
)))
stopifnot(!grepl("input$ortho_pip_suggest_reference", server_source, fixed = TRUE))
stopifnot(!grepl("input$ortho_multipip_suggest_reference", server_source, fixed = TRUE))
stopifnot(grepl("lastz_patience_notice", server_source, fixed = TRUE))
stopifnot(grepl("LASTZ is computationally intensive and may take several minutes.", server_source, fixed = TRUE))
stopifnot(grepl('headline = "Please be patient"', server_source, fixed = TRUE))
stopifnot(grepl("auto_open = TRUE", server_source, fixed = TRUE))
stopifnot(grepl('context = "Multi-Gene LASTZ"', server_source, fixed = TRUE))
stopifnot(grepl('context = "Multi-Gene MultiPIP"', server_source, fixed = TRUE))

stopifnot(grepl("Report generation can take several minutes.", report_source, fixed = TRUE))
stopifnot(grepl("This is one of CGV's most intensive processes.", report_source, fixed = TRUE))
stopifnot(grepl("Optional and computationally intensive.", report_source, fixed = TRUE))
stopifnot(grepl("keep CGV open and please wait", report_source, fixed = TRUE))

cat("Long-running task warning checks passed.\n")
