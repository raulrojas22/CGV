#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
    cat("Usage: Rscript scripts/summarize_perf_benchmark_dir.R /path/to/benchmark_dir\n")
    quit(status = 1L)
}
`%||%` <- function(a, b) if (!is.null(a)) a else b

bench_dir <- normalizePath(args[[1]], winslash = "/", mustWork = FALSE)
if (!dir.exists(bench_dir)) {
    stop(sprintf("Benchmark directory not found: %s", bench_dir))
}

focus_metrics <- c(
    "first_plot_ready_ms",
    "total_plots_ready_ms",
    "browser_first_plot_painted_ms",
    "browser_total_plots_painted_ms",
    "client_click_to_first_paint_ms",
    "server_ready_to_browser_paint_ms",
    "browser_first_card_complete_ms",
    "client_click_to_card_complete_ms",
    "browser_first_paint_to_card_complete_ms",
    "search_finish_ms",
    "search_observer_total_ms",
    "lookup_local_exact_ms",
    "lookup_external_alias_ms",
    "lookup_local_flex_ms",
    "lookup_total_ms",
    "lookup_alias_fast_region_ms",
    "split_transcripts_ms",
    "split_blocks_only_ms",
    "canonical_select_ms",
    "split_setup_ms",
    "split_id_extract_ms",
    "split_parent_index_ms",
    "split_tx_key_order_ms",
    "split_traversal_copy_ms",
    "genome_resolve_ms",
    "neighbor_context_prepare_ms",
    "batch_scale_prepare_ms",
    "transcript_state_loop_ms",
    "plot_state_prepare_total_ms",
    "metrics_payload_build_ms",
    "reactive_state_commit_ms",
    "module_init_ms",
    "sequence_prefetch_ms",
    "inline_fast_prefetch_ms",
    "gc_span_fetch_ms",
    "gene_sequence_fetch_ms",
    "seqnames_resolve_ms",
    "native_twobit_ms",
    "rtracklayer_namespace_ms",
    "twobit_handle_ms",
    "range_build_ms",
    "twobit_import_ms",
    "sequence_stringify_ms",
    "twobit_total_ms",
    "single_span_fetch_ms",
    "spliced_total_ms",
    "fetch_gene_total_ms",
    "spliced_sequence_ms",
    "composition_prepare_ms",
    "apply_sequence_prefetch_ms",
    "sequence_composition_ms",
    "render_prepare_ms",
    "neighbor_prefetch_ms",
    "neighbor_context_ms",
    "create_gene_plot_ms",
    "create_gene_plot_entry_delay_ms",
    "create_gene_plot_gc_ms",
    "model_build_ms",
    "girafe_build_ms",
    "compact_svg_ms"
)

extract_trial_num <- function(path_txt) {
    m <- regexec("_(\\d+)\\.log$", basename(path_txt), perl = TRUE)
    g <- regmatches(basename(path_txt), m)
    out <- vapply(g, function(x) if (length(x) >= 2L) x[[2]] else NA_character_, character(1))
    suppressWarnings(as.integer(out))
}

extract_context <- function(x) {
    m <- regexec("\\[PERF\\]\\[([^\\]]+)\\]", x, perl = TRUE)
    out <- regmatches(x, m)
    vapply(out, function(y) if (length(y) >= 2L) y[[2]] else NA_character_, character(1))
}

infer_search_mode <- function(context) {
    ctx <- toupper(trimws(as.character(context %||% "")))
    if (startsWith(ctx, "HOMO")) return("homologous")
    if (startsWith(ctx, "ORTHO")) return("orthologous")
    NA_character_
}

infer_scenario <- function(path_txt) {
    nm <- tolower(basename(path_txt %||% ""))
    if (grepl("cold", nm, fixed = TRUE)) return("cold")
    if (grepl("warm", nm, fixed = TRUE) || grepl("prewarm", nm, fixed = TRUE) || grepl("hot", nm, fixed = TRUE)) return("warm")
    "default"
}

infer_bench_mode <- function(path_txt) {
    nm <- tolower(basename(path_txt %||% ""))
    if (startsWith(nm, "on_")) return("ON")
    if (startsWith(nm, "off_")) return("OFF")
    "UNKNOWN"
}

summarize_log <- function(path_txt) {
    lines <- readLines(path_txt, warn = FALSE)
    perf_lines <- lines[grepl("\\[PERF\\]\\[[^\\]]+\\]", lines, perl = TRUE)]
    if (length(perf_lines) == 0L) {
        stop(sprintf("No PERF lines found in: %s", path_txt))
    }
    contexts <- extract_context(perf_lines)
    rows <- list()
    row_idx <- 0L
    for (i in seq_along(perf_lines)) {
        search_mode <- infer_search_mode(contexts[[i]])
        if (is.na(search_mode)) next
        matches <- gregexpr("([A-Za-z][A-Za-z0-9_]+)=([0-9]+(?:\\.[0-9]+)?)", perf_lines[[i]], perl = TRUE)
        captures <- regmatches(perf_lines[[i]], matches)[[1]]
        if (length(captures) == 0L) next
        for (capture in captures) {
            parts <- strsplit(capture, "=", fixed = TRUE)[[1]]
            metric <- as.character(parts[1] %||% "")
            value <- suppressWarnings(as.numeric(parts[2] %||% NA_real_))
            if (!metric %in% focus_metrics || !is.finite(value)) next
            row_idx <- row_idx + 1L
            rows[[row_idx]] <- data.frame(
                trial = extract_trial_num(path_txt),
                bench_mode = infer_bench_mode(path_txt),
                scenario = infer_scenario(path_txt),
                mode = search_mode,
                metric = metric,
                value = value,
                stringsAsFactors = FALSE
            )
        }
    }
    if (length(rows) == 0L) {
        stop(sprintf("No focused timing metrics found in: %s", path_txt))
    }
    df <- do.call(rbind, rows)
    stats::aggregate(
        df$value,
        by = list(
            trial = df$trial,
            bench_mode = df$bench_mode,
            scenario = df$scenario,
            mode = df$mode,
            metric = df$metric
        ),
        FUN = function(x) round(stats::median(x, na.rm = TRUE), 1)
    )
}

log_files <- list.files(bench_dir, pattern = "\\.log$", full.names = TRUE)
if (length(log_files) == 0L) {
    stop("No .log files found in benchmark directory.")
}

all_rows <- lapply(log_files, summarize_log)
raw_df <- do.call(rbind, all_rows)
colnames(raw_df)[colnames(raw_df) == "x"] <- "median_ms"

median_df <- stats::aggregate(
    raw_df$median_ms,
    by = list(
        bench_mode = raw_df$bench_mode,
        scenario = raw_df$scenario,
        mode = raw_df$mode,
        metric = raw_df$metric
    ),
    FUN = function(x) round(stats::median(x, na.rm = TRUE), 1)
)
colnames(median_df)[colnames(median_df) == "x"] <- "median_ms"

on_df <- median_df[median_df$bench_mode == "ON", , drop = FALSE]
off_df <- median_df[median_df$bench_mode == "OFF", , drop = FALSE]
cmp <- merge(
    on_df,
    off_df,
    by = c("scenario", "mode", "metric"),
    suffixes = c("_on", "_off"),
    all = TRUE,
    sort = FALSE
)
cmp$median_ms_saved <- cmp$median_ms_off - cmp$median_ms_on
cmp$improvement_pct <- ifelse(
    is.finite(cmp$median_ms_off) & cmp$median_ms_off > 0,
    round(100 * cmp$median_ms_saved / cmp$median_ms_off, 2),
    NA_real_
)

cat(sprintf("Benchmark directory: %s\n\n", bench_dir))
cat("Per-trial median summary:\n")
print(raw_df[order(raw_df$trial, raw_df$bench_mode, raw_df$scenario, raw_df$mode, raw_df$metric), ], row.names = FALSE)
cat("\nMedian summary by benchmark mode:\n")
print(median_df[order(median_df$bench_mode, median_df$scenario, median_df$mode, median_df$metric), ], row.names = FALSE)
cat("\nMedian ON vs OFF comparison:\n")
print(cmp[order(cmp$scenario, cmp$mode, cmp$metric), c("scenario", "mode", "metric", "median_ms_on", "median_ms_off", "median_ms_saved", "improvement_pct")], row.names = FALSE)
