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
expect_fixed(server_txt, 'initial_plot_timing_ids <- function(', "initial visible plot selection")
expect_pattern(
    server_txt,
    "set_plot_timing_expected\\([\\s\\S]{0,120}homoPlotTimingTracker,[\\s\\S]{0,80}added_plot_ids",
    "homologous telemetry retains all added plot ids"
)
expect_pattern(
    server_txt,
    "gate_expected_ids = initial_plot_timing_ids\\([\\s\\S]{0,800}orthoInitialVisibleCount[\\s\\S]{0,180}primary_only = TRUE",
    "orthologous gate uses the initial primary-card scope"
)
expect_fixed(server_txt, "tr$expected <- ids_chr", "historical telemetry expectation set")
expect_fixed(server_txt, "tr$gate_expected <- gate_ids_chr", "functional first-paint expectation set")
expect_fixed(
    server_txt,
    "browser_expected_ids <- if (isTRUE(app_perf_enabled())) ids_chr else gate_ids_chr",
    "full telemetry remains separate from the functional one-shot gate"
)

initial_plot_ids_fixture <- function(ids, visible_count, meta = NULL, primary_only = FALSE) {
    ids <- unique(as.character(ids))
    ids <- ids[nzchar(ids)]
    if (isTRUE(primary_only)) {
        ids <- Filter(function(id) !identical((meta[[id]] %||% list())$is_canonical, FALSE), ids)
    }
    head(ids, max(1L, as.integer(visible_count)))
}
`%||%` <- function(x, y) if (is.null(x)) y else x
fixture_meta <- list(
    tx1 = list(is_canonical = TRUE),
    tx2 = list(is_canonical = FALSE),
    gene2 = list(is_canonical = TRUE)
)
stopifnot(
    identical(initial_plot_ids_fixture(c("tx1", "tx2", "gene2"), 1L), "tx1"),
    identical(
        initial_plot_ids_fixture(c("tx1", "tx2", "gene2"), 2L, fixture_meta, TRUE),
        c("tx1", "gene2")
    ),
    identical(
        initial_plot_ids_fixture(
            c("old", "new_b", "new_a"),
            1L
        ),
        "old"
    )
)
expect_fixed(
    server_txt,
    "isolate(as.character(primaryPlotIdsOrthologous() %||% character(0)))",
    "orthologous timing follows the active sort order"
)

expect_pattern(paint_js, "requestAnimationFrame", "paint-frame synchronization")
expect_pattern(paint_js, "MutationObserver", "render mutation tracking")
expect_pattern(paint_js, "snapshotVisibleSvgs", "stale SVG protection")
expect_pattern(paint_js, "cgv_plot_painted", "paint event publication")
expect_pattern(paint_js, "svg_bytes", "rendered SVG size")
expect_fixed(paint_js, "rawOutputIds == null ? [] : [rawOutputIds]", "single-output Shiny message normalization")
expect_fixed(paint_js, "var perfTimingEnabled = !!window.__cgvPlotPaintTiming;", "functional paint watch remains available without telemetry")
expect_fixed(paint_js, "if (perfTimingEnabled) {", "click telemetry remains disabled in functional-only mode")
expect_fixed(paint_js, "var collectMetrics = perfTimingEnabled && !run.firstPaintOnly;", "functional-only paint avoids SVG serialization")
expect_fixed(paint_js, "if (run.firstPaintOnly) {", "one-shot paint completion")
expect_fixed(paint_js, "delete runs[run.runId];", "one-shot run cleanup")
expect_fixed(paint_js, "stopObserverIfIdle();", "idle mutation observer disconnect")
expect_fixed(paint_js, "document.getElementById('ortho-plot-cards-container')", "functional watch is scoped to the Cross-Species card container")
expect_fixed(paint_js, "without installing an expensive document-wide watch", "functional mode never falls back to a global observer")
expect_fixed(paint_js, "cgv_plot_timing_stop", "server timeout cancels the one-shot browser watch")
expect_fixed(paint_js, "run.expectGeneration !== expectGeneration", "stale double-frame paint callbacks are rejected")
expect_fixed(paint_js, "runs[run.runId] !== run", "replaced one-shot runs cannot publish stale paint")
expect_fixed(server_txt, 'parse_positive_int_env("APP_ORTHO_FIRST_PAINT_TIMEOUT_MS", 30000L)', "bounded first-paint fail-safe")
expect_fixed(server_txt, "activate_ortho_first_paint_gate", "gate activation after non-empty expected plots")
expect_fixed(server_txt, 'reason = "browser_paint"', "browser paint releases automatic rendering")
expect_fixed(server_txt, 'reason = "timeout"', "fail-safe releases automatic rendering")
expect_fixed(server_txt, "expected_ready_ids <- intersect(", "timeout uses current run expectations")
expect_fixed(server_txt, "timing_tracker$gate_expected", "timeout is scoped to the visible first-paint target")
expect_fixed(server_txt, "length(expected_ready_ids) > 0L", "timeout starts only after a new primary plot is server-ready")
expect_fixed(server_txt, 'reason = "visible_target_changed"', "sorting or deletion releases a stale first-paint target")
expect_fixed(server_txt, "delegated to progressive scheduler", "external rescue cannot bypass progressive pagination")

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
