#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
    cat("Usage: Rscript scripts/compare_perf_logs.R /path/to/cache_on.log /path/to/cache_off.log\n")
    quit(status = 1L)
}

on_path <- normalizePath(args[[1]], winslash = "/", mustWork = FALSE)
off_path <- normalizePath(args[[2]], winslash = "/", mustWork = FALSE)

if (!file.exists(on_path)) {
    stop(sprintf("ON log file not found: %s", on_path))
}
if (!file.exists(off_path)) {
    stop(sprintf("OFF log file not found: %s", off_path))
}

summarize_log <- function(log_path) {
    lines <- readLines(log_path, warn = FALSE)
    if (length(lines) == 0L) {
        stop(sprintf("Log file is empty: %s", log_path))
    }

    keep <- grepl("\\[PERF\\]\\[(HOMO_MOD|ORTHO_MOD)\\]", lines, perl = TRUE)
    perf_lines <- lines[keep]
    if (length(perf_lines) == 0L) {
        stop(sprintf("No HOMO_MOD/ORTHO_MOD PERF lines found in: %s", log_path))
    }

    extract_context <- function(x) {
        m <- regexec("\\[PERF\\]\\[([^\\]]+)\\]", x, perl = TRUE)
        out <- regmatches(x, m)
        vapply(out, function(y) if (length(y) >= 2L) y[[2]] else NA_character_, character(1))
    }

    context <- extract_context(perf_lines)
    is_homo <- context == "HOMO_MOD"
    is_ortho <- context == "ORTHO_MOD"

    count_pattern <- function(pattern, idx) {
        sum(grepl(pattern, perf_lines[idx], perl = TRUE))
    }

    summary_df <- data.frame(
        module = c("HOMO_MOD", "ORTHO_MOD"),
        render_start = c(count_pattern("render start", is_homo), count_pattern("render start", is_ortho)),
        create_start = c(count_pattern("create_gene_plot start", is_homo), count_pattern("create_gene_plot start", is_ortho)),
        create_done = c(count_pattern("create_gene_plot done", is_homo), count_pattern("create_gene_plot done", is_ortho)),
        cache_hit = c(count_pattern("render cache hit", is_homo), count_pattern("render cache hit", is_ortho)),
        cache_miss = c(count_pattern("render cache miss", is_homo), count_pattern("render cache miss", is_ortho)),
        cache_disabled = c(count_pattern("render cache disabled", is_homo), count_pattern("render cache disabled", is_ortho)),
        stringsAsFactors = FALSE
    )

    summary_df$cache_hit_rate <- ifelse(
        (summary_df$cache_hit + summary_df$cache_miss) > 0,
        round(summary_df$cache_hit / (summary_df$cache_hit + summary_df$cache_miss), 4),
        NA_real_
    )

    extract_timing_values <- function(ctx, key) {
        pat <- sprintf("^.*\\[PERF\\]\\[%s\\]\\[[^\\]]+\\].*%s=([0-9]+(?:\\.[0-9]+)?).*$", ctx, key)
        vals <- as.numeric(sub(pat, "\\1", lines[grepl(pat, lines, perl = TRUE)], perl = TRUE))
        vals[is.finite(vals)]
    }

    timing_stat <- function(vals) {
        if (length(vals) == 0L) {
            return(NA_real_)
        }
        round(mean(vals), 1)
    }

    homo_first <- extract_timing_values("HOMO_TIMING", "first_plot_ready_ms")
    homo_total <- extract_timing_values("HOMO_TIMING", "total_plots_ready_ms")
    homo_finish <- extract_timing_values("HOMO_TIMING", "search_finish_ms")
    ortho_first <- extract_timing_values("ORTHO_TIMING", "first_plot_ready_ms")
    ortho_total <- extract_timing_values("ORTHO_TIMING", "total_plots_ready_ms")
    ortho_finish <- extract_timing_values("ORTHO_TIMING", "search_finish_ms")

    summary_df$first_plot_ms <- c(timing_stat(homo_first), timing_stat(ortho_first))
    summary_df$total_plots_ready_ms <- c(timing_stat(homo_total), timing_stat(ortho_total))
    summary_df$search_finish_ms <- c(timing_stat(homo_finish), timing_stat(ortho_finish))
    summary_df$timing_samples_first <- c(length(homo_first), length(ortho_first))
    summary_df$timing_samples_total <- c(length(homo_total), length(ortho_total))
    summary_df
}

on_df <- summarize_log(on_path)
off_df <- summarize_log(off_path)
cmp <- merge(on_df, off_df, by = "module", suffixes = c("_on", "_off"), sort = FALSE)

cmp$create_start_saved <- cmp$create_start_off - cmp$create_start_on
cmp$create_done_saved <- cmp$create_done_off - cmp$create_done_on
cmp$create_start_reduction_pct <- ifelse(
    cmp$create_start_off > 0L,
    round((cmp$create_start_saved / cmp$create_start_off) * 100, 2),
    NA_real_
)
cmp$create_done_reduction_pct <- ifelse(
    cmp$create_done_off > 0L,
    round((cmp$create_done_saved / cmp$create_done_off) * 100, 2),
    NA_real_
)
cmp$first_plot_ms_saved <- cmp$first_plot_ms_off - cmp$first_plot_ms_on
cmp$total_plots_ready_ms_saved <- cmp$total_plots_ready_ms_off - cmp$total_plots_ready_ms_on
cmp$search_finish_ms_saved <- cmp$search_finish_ms_off - cmp$search_finish_ms_on
cmp$first_plot_ms_improvement_pct <- ifelse(
    is.finite(cmp$first_plot_ms_off) & cmp$first_plot_ms_off > 0,
    round((cmp$first_plot_ms_saved / cmp$first_plot_ms_off) * 100, 2),
    NA_real_
)
cmp$total_plots_ready_ms_improvement_pct <- ifelse(
    is.finite(cmp$total_plots_ready_ms_off) & cmp$total_plots_ready_ms_off > 0,
    round((cmp$total_plots_ready_ms_saved / cmp$total_plots_ready_ms_off) * 100, 2),
    NA_real_
)

cat(sprintf("ON log:  %s\n", on_path))
cat(sprintf("OFF log: %s\n\n", off_path))

cat("ON summary:\n")
print(on_df, row.names = FALSE)
cat("\nOFF summary:\n")
print(off_df, row.names = FALSE)

if (any(on_df$cache_disabled > 0L, na.rm = TRUE)) {
    cat("\nWARNING: ON log has cache_disabled > 0. Cache was not actually ON for all modules.\n")
}
if (any(off_df$cache_disabled == 0L, na.rm = TRUE)) {
    cat("\nWARNING: OFF log has cache_disabled == 0 in at least one module. Verify OFF flags were applied.\n")
}

report <- cmp[, c(
    "module",
    "create_start_on", "create_start_off", "create_start_saved", "create_start_reduction_pct",
    "create_done_on", "create_done_off", "create_done_saved", "create_done_reduction_pct",
    "first_plot_ms_on", "first_plot_ms_off", "first_plot_ms_saved", "first_plot_ms_improvement_pct",
    "total_plots_ready_ms_on", "total_plots_ready_ms_off", "total_plots_ready_ms_saved", "total_plots_ready_ms_improvement_pct",
    "search_finish_ms_on", "search_finish_ms_off", "search_finish_ms_saved",
    "cache_hit_rate_on", "cache_hit_rate_off",
    "cache_disabled_on", "cache_disabled_off",
    "timing_samples_first_on", "timing_samples_first_off", "timing_samples_total_on", "timing_samples_total_off"
)]

cat("\nComparison (ON vs OFF):\n")
print(report, row.names = FALSE)

cat("\nInterpretation:\n")
cat("- Positive `create_*_saved` means cache ON avoided heavy recomputation.\n")
cat("- `create_*_reduction_pct` close to 50%+ is a strong win in chunked rerenders.\n")
cat("- Positive `*_ms_saved` means cache ON is faster for that timing metric.\n")
cat("- Expect `cache_hit_rate_off` near 0 when caches are disabled.\n")
