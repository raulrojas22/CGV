#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
    cat("Usage: Rscript scripts/summarize_perf_benchmark_dir.R /path/to/benchmark_dir\n")
    quit(status = 1L)
}

bench_dir <- normalizePath(args[[1]], winslash = "/", mustWork = FALSE)
if (!dir.exists(bench_dir)) {
    stop(sprintf("Benchmark directory not found: %s", bench_dir))
}

extract_trial_num <- function(path) {
    m <- regexec("_(\\d+)\\.log$", basename(path), perl = TRUE)
    g <- regmatches(basename(path), m)
    out <- vapply(g, function(x) if (length(x) >= 2L) x[[2]] else NA_character_, character(1))
    suppressWarnings(as.integer(out))
}

on_files <- list.files(bench_dir, pattern = "^on_[0-9]+\\.log$", full.names = TRUE)
off_files <- list.files(bench_dir, pattern = "^off_[0-9]+\\.log$", full.names = TRUE)
if (length(on_files) == 0L || length(off_files) == 0L) {
    stop("Expected files named on_<n>.log and off_<n>.log in benchmark directory.")
}

on_trials <- extract_trial_num(on_files)
off_trials <- extract_trial_num(off_files)
common_trials <- sort(intersect(on_trials[is.finite(on_trials)], off_trials[is.finite(off_trials)]))
if (length(common_trials) == 0L) {
    stop("No matching ON/OFF trial numbers found.")
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
        if (length(vals) == 0L) NA_real_ else round(mean(vals), 1)
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
    summary_df
}

all_rows <- list()
for (trial in common_trials) {
    on_file <- on_files[extract_trial_num(on_files) == trial][1]
    off_file <- off_files[extract_trial_num(off_files) == trial][1]
    on_df <- summarize_log(on_file)
    off_df <- summarize_log(off_file)
    on_df$mode <- "ON"
    off_df$mode <- "OFF"
    on_df$trial <- trial
    off_df$trial <- trial
    all_rows[[length(all_rows) + 1L]] <- on_df
    all_rows[[length(all_rows) + 1L]] <- off_df
}

raw_df <- do.call(rbind, all_rows)
metric_cols <- c(
    "render_start", "create_start", "create_done",
    "cache_hit", "cache_miss", "cache_disabled", "cache_hit_rate",
    "first_plot_ms", "total_plots_ready_ms", "search_finish_ms"
)

median_df <- stats::aggregate(
    raw_df[, metric_cols, drop = FALSE],
    by = list(module = raw_df$module, mode = raw_df$mode),
    FUN = function(x) if (all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
)

on_med <- median_df[median_df$mode == "ON", c("module", metric_cols), drop = FALSE]
off_med <- median_df[median_df$mode == "OFF", c("module", metric_cols), drop = FALSE]
colnames(on_med)[-1] <- paste0(colnames(on_med)[-1], "_on")
colnames(off_med)[-1] <- paste0(colnames(off_med)[-1], "_off")
cmp <- merge(on_med, off_med, by = "module", sort = FALSE)

cmp$create_start_saved <- cmp$create_start_off - cmp$create_start_on
cmp$render_start_saved <- cmp$render_start_off - cmp$render_start_on
cmp$first_plot_ms_saved <- cmp$first_plot_ms_off - cmp$first_plot_ms_on
cmp$total_plots_ready_ms_saved <- cmp$total_plots_ready_ms_off - cmp$total_plots_ready_ms_on
cmp$search_finish_ms_saved <- cmp$search_finish_ms_off - cmp$search_finish_ms_on

cmp$create_start_reduction_pct <- ifelse(
    cmp$create_start_off > 0, round(100 * cmp$create_start_saved / cmp$create_start_off, 2), NA_real_
)
cmp$render_start_reduction_pct <- ifelse(
    cmp$render_start_off > 0, round(100 * cmp$render_start_saved / cmp$render_start_off, 2), NA_real_
)

cat(sprintf("Benchmark directory: %s\n", bench_dir))
cat(sprintf("Matched trials: %s\n\n", paste(common_trials, collapse = ", ")))

cat("Per-trial raw summary:\n")
print(raw_df[order(raw_df$trial, raw_df$mode, raw_df$module), ], row.names = FALSE)

cat("\nMedian summary by mode:\n")
print(median_df[order(median_df$module, median_df$mode), ], row.names = FALSE)

report <- cmp[, c(
    "module",
    "render_start_on", "render_start_off", "render_start_saved", "render_start_reduction_pct",
    "create_start_on", "create_start_off", "create_start_saved", "create_start_reduction_pct",
    "first_plot_ms_on", "first_plot_ms_off", "first_plot_ms_saved",
    "total_plots_ready_ms_on", "total_plots_ready_ms_off", "total_plots_ready_ms_saved",
    "search_finish_ms_on", "search_finish_ms_off", "search_finish_ms_saved"
)]

cat("\nMedian ON vs OFF comparison:\n")
print(report, row.names = FALSE)
