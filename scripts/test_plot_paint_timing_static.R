#!/usr/bin/env Rscript

read_project_file <- function(...) {
    paste(readLines(file.path(...), warn = FALSE), collapse = "\n")
}

expect_pattern <- function(txt, pattern, label) {
    if (!grepl(pattern, txt, perl = TRUE)) {
        stop(sprintf("Missing plot timing behavior: %s", label), call. = FALSE)
    }
}

expect_fixed <- function(txt, pattern, label) {
    if (!grepl(pattern, txt, fixed = TRUE)) {
        stop(sprintf("Missing plot timing behavior: %s", label), call. = FALSE)
    }
}

ui_txt <- read_project_file("ui.R")
server_txt <- read_project_file("server.R")
modules_txt <- read_project_file("R", "modules.R")
paint_js <- read_project_file("www", "js", "plot_paint_timing.js")
summary_scripts <- vapply(
    c("summarize_perf_log.R", "compare_perf_logs.R", "summarize_perf_benchmark_dir.R"),
    function(name) read_project_file("scripts", name),
    character(1)
)

expect_fixed(ui_txt, "__cgvPlotPaintTiming = %s", "performance-controlled browser timing flag")
expect_fixed(ui_txt, 'versioned_asset_path("js/plot_paint_timing.js")', "browser timing asset")
expect_fixed(server_txt, 'sendCustomMessage("cgv_plot_timing_start"', "server-to-browser timing start")
expect_fixed(server_txt, 'sendCustomMessage("cgv_plot_timing_expect"', "expected output identifiers")
expect_fixed(server_txt, 'observeEvent(input$cgv_plot_painted', "browser paint event receiver")
expect_fixed(server_txt, '"browser_first_plot_painted_ms"', "first browser paint metric")
expect_fixed(server_txt, '"server_ready_to_browser_paint_ms"', "server-to-paint gap metric")

expect_pattern(paint_js, "requestAnimationFrame", "paint-frame synchronization")
expect_pattern(paint_js, "MutationObserver", "render mutation tracking")
expect_pattern(paint_js, "snapshotVisibleSvgs", "stale SVG protection")
expect_pattern(paint_js, "cgv_plot_painted", "paint event publication")
expect_pattern(paint_js, "svg_bytes", "rendered SVG size")

for (metric in c(
    "gc_span_fetch_ms",
    "gene_sequence_fetch_ms",
    "create_gene_plot_entry_delay_ms",
    "create_gene_plot_gc_ms",
    "model_build_ms",
    "girafe_build_ms",
    "compact_svg_ms"
)) {
    expect_fixed(modules_txt, sprintf('"%s"', metric), metric)
    for (script_name in names(summary_scripts)) {
        expect_fixed(
            summary_scripts[[script_name]],
            sprintf('"%s"', metric),
            sprintf("%s in %s", metric, script_name)
        )
    }
}

for (metric in c(
    "browser_first_plot_painted_ms",
    "browser_total_plots_painted_ms",
    "client_click_to_first_paint_ms",
    "server_ready_to_browser_paint_ms"
)) {
    for (script_name in names(summary_scripts)) {
        expect_fixed(
            summary_scripts[[script_name]],
            sprintf('"%s"', metric),
            sprintf("%s in %s", metric, script_name)
        )
    }
}

cat("plot-paint-timing-static-ok\n")
