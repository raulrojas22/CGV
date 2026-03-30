#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
    cat("Usage: Rscript scripts/summarize_aligned_benchmark_dir.R /path/to/benchmark_dir\n")
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

extract_num <- function(x, key) {
    pat <- sprintf("^.*%s=([0-9]+(?:\\.[0-9]+)?).*$", key)
    vals <- suppressWarnings(as.numeric(sub(pat, "\\1", x, perl = TRUE)))
    vals[is.finite(vals)]
}

med_or_na <- function(x) {
    if (length(x) == 0L) return(NA_real_)
    as.numeric(stats::median(x, na.rm = TRUE))
}

summarize_log <- function(log_path) {
    lines <- readLines(log_path, warn = FALSE)
    if (length(lines) == 0L) {
        stop(sprintf("Log file is empty: %s", log_path))
    }

    aligned_lines <- lines[grepl("\\[PERF\\]\\[ORTHO_ALIGNED\\]", lines, perl = TRUE)]
    if (length(aligned_lines) == 0L) {
        stop(sprintf("No ORTHO_ALIGNED PERF lines found in: %s", log_path))
    }

    msg <- sub("^.*\\[\\+[^\\]]+\\]\\s*", "", aligned_lines, perl = TRUE)

    cache_hit <- sum(grepl("aligned_cache_hit=1", msg, perl = TRUE))
    cache_miss <- sum(grepl("aligned_cache_hit=0", msg, perl = TRUE))

    extract_timing <- function(ctx, key) {
        pat <- sprintf("^.*\\[PERF\\]\\[%s\\]\\[[^\\]]+\\].*%s=([0-9]+(?:\\.[0-9]+)?).*$", ctx, key)
        vals <- suppressWarnings(as.numeric(sub(pat, "\\1", lines[grepl(pat, lines, perl = TRUE)], perl = TRUE)))
        vals[is.finite(vals)]
    }

    data.frame(
        aligned_runs = length(unique(sub("^.*\\[PERF\\]\\[ORTHO_ALIGNED\\]\\[([^\\]]+)\\].*$", "\\1", aligned_lines, perl = TRUE))),
        render_enter = sum(grepl("^render_enter$", msg, perl = TRUE)),
        cache_hit = cache_hit,
        cache_miss = cache_miss,
        cache_hit_rate = if ((cache_hit + cache_miss) > 0L) cache_hit / (cache_hit + cache_miss) else NA_real_,
        fast_path_fatal = sum(grepl("fast_path_fatal", msg, perl = TRUE)),
        fallback_legacy = sum(grepl("fast_path_fallback_legacy=1", msg, perl = TRUE)),
        skipped_tracks_median = med_or_na(extract_num(msg[grepl("aligned_skipped_tracks=", msg, perl = TRUE)], "aligned_skipped_tracks")),
        aligned_collect_ms_median = med_or_na(extract_num(msg[grepl("aligned_collect_ms=", msg, perl = TRUE)], "aligned_collect_ms")),
        aligned_gc_ms_median = med_or_na(extract_num(msg[grepl("aligned_gc_ms=", msg, perl = TRUE)], "aligned_gc_ms")),
        aligned_ribbons_ms_median = med_or_na(extract_num(msg[grepl("aligned_ribbons_ms=", msg, perl = TRUE)], "aligned_ribbons_ms")),
        aligned_plot_build_ms_median = med_or_na(extract_num(msg[grepl("aligned_plot_build_ms=", msg, perl = TRUE)], "aligned_plot_build_ms")),
        aligned_total_ms_median = med_or_na(extract_num(msg[grepl("aligned_total_ms=", msg, perl = TRUE)], "aligned_total_ms")),
        ortho_first_plot_ms_median = med_or_na(extract_timing("ORTHO_TIMING", "first_plot_ready_ms")),
        ortho_total_ready_ms_median = med_or_na(extract_timing("ORTHO_TIMING", "total_plots_ready_ms")),
        ortho_search_finish_ms_median = med_or_na(extract_timing("ORTHO_TIMING", "search_finish_ms")),
        stringsAsFactors = FALSE
    )
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

rows <- list()
for (trial in common_trials) {
    on_file <- on_files[extract_trial_num(on_files) == trial][1]
    off_file <- off_files[extract_trial_num(off_files) == trial][1]
    on_df <- summarize_log(on_file)
    off_df <- summarize_log(off_file)
    on_df$mode <- "ON"
    off_df$mode <- "OFF"
    on_df$trial <- trial
    off_df$trial <- trial
    rows[[length(rows) + 1L]] <- on_df
    rows[[length(rows) + 1L]] <- off_df
}

raw_df <- do.call(rbind, rows)
metric_cols <- setdiff(colnames(raw_df), c("mode", "trial"))

median_df <- stats::aggregate(
    raw_df[, metric_cols, drop = FALSE],
    by = list(mode = raw_df$mode),
    FUN = function(x) if (all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
)

on_med <- median_df[median_df$mode == "ON", , drop = FALSE]
off_med <- median_df[median_df$mode == "OFF", , drop = FALSE]

cat(sprintf("Benchmark directory: %s\n", bench_dir))
cat(sprintf("Matched trials: %s\n\n", paste(common_trials, collapse = ", ")))

cat("Per-trial raw summary:\n")
print(raw_df[order(raw_df$trial, raw_df$mode), ], row.names = FALSE)

cat("\nMedian summary by mode:\n")
print(median_df[order(median_df$mode), ], row.names = FALSE)

if (nrow(on_med) == 1L && nrow(off_med) == 1L) {
    cmp <- data.frame(
        metric = c(
            "aligned_total_ms_median",
            "aligned_collect_ms_median",
            "aligned_plot_build_ms_median",
            "ortho_first_plot_ms_median",
            "ortho_total_ready_ms_median",
            "cache_hit_rate"
        ),
        on = c(
            on_med$aligned_total_ms_median,
            on_med$aligned_collect_ms_median,
            on_med$aligned_plot_build_ms_median,
            on_med$ortho_first_plot_ms_median,
            on_med$ortho_total_ready_ms_median,
            on_med$cache_hit_rate
        ),
        off = c(
            off_med$aligned_total_ms_median,
            off_med$aligned_collect_ms_median,
            off_med$aligned_plot_build_ms_median,
            off_med$ortho_first_plot_ms_median,
            off_med$ortho_total_ready_ms_median,
            off_med$cache_hit_rate
        ),
        stringsAsFactors = FALSE
    )
    cmp$saved <- cmp$off - cmp$on
    cmp$improvement_pct <- ifelse(is.finite(cmp$off) & cmp$off > 0, round(100 * cmp$saved / cmp$off, 2), NA_real_)

    cat("\nMedian ON vs OFF comparison:\n")
    print(cmp, row.names = FALSE)
}

cat("\nInterpretation:\n")
cat("- Positive `saved` means ON is faster than OFF.\n")
cat("- `aligned_total_ms_median` is the direct aligned pipeline latency.\n")
cat("- `skipped_tracks_median` and `fast_path_fatal` should stay at 0.\n")
