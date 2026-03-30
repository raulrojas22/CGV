#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
    cat("Usage: Rscript scripts/summarize_aligned_perf_log.R /path/to/app.log\n")
    quit(status = 1L)
}

log_path <- normalizePath(args[[1]], winslash = "/", mustWork = FALSE)
if (!file.exists(log_path)) {
    stop(sprintf("Log file not found: %s", log_path))
}

lines <- readLines(log_path, warn = FALSE)
if (length(lines) == 0L) {
    stop("Log file is empty.")
}

extract_num <- function(x, key) {
    pat <- sprintf("^.*%s=([0-9]+(?:\\.[0-9]+)?).*$", key)
    vals <- suppressWarnings(as.numeric(sub(pat, "\\1", x, perl = TRUE)))
    vals[is.finite(vals)]
}

summary_median <- function(x) {
    if (length(x) == 0L) return(NA_real_)
    round(stats::median(x, na.rm = TRUE), 1)
}

aligned_lines <- lines[grepl("\\[PERF\\]\\[ORTHO_ALIGNED\\]", lines, perl = TRUE)]
if (length(aligned_lines) == 0L) {
    cat("No ORTHO_ALIGNED PERF lines found.\n")
    quit(status = 2L)
}

run_id <- sub("^.*\\[PERF\\]\\[ORTHO_ALIGNED\\]\\[([^\\]]+)\\].*$", "\\1", aligned_lines, perl = TRUE)
msg <- sub("^.*\\[\\+[^\\]]+\\]\\s*", "", aligned_lines, perl = TRUE)

render_enter <- sum(grepl("^render_enter$", msg, perl = TRUE))
cache_hit <- sum(grepl("aligned_cache_hit=1", msg, perl = TRUE))
cache_miss <- sum(grepl("aligned_cache_hit=0", msg, perl = TRUE))
fast_fatal <- sum(grepl("fast_path_fatal", msg, perl = TRUE))
fallback_legacy <- sum(grepl("fast_path_fallback_legacy=1", msg, perl = TRUE))

collect_ms <- extract_num(msg[grepl("aligned_collect_ms=", msg, perl = TRUE)], "aligned_collect_ms")
gc_ms <- extract_num(msg[grepl("aligned_gc_ms=", msg, perl = TRUE)], "aligned_gc_ms")
ribbons_ms <- extract_num(msg[grepl("aligned_ribbons_ms=", msg, perl = TRUE)], "aligned_ribbons_ms")
plot_build_ms <- extract_num(msg[grepl("aligned_plot_build_ms=", msg, perl = TRUE)], "aligned_plot_build_ms")
total_ms <- extract_num(msg[grepl("aligned_total_ms=", msg, perl = TRUE)], "aligned_total_ms")
skipped_tracks <- extract_num(msg[grepl("aligned_skipped_tracks=", msg, perl = TRUE)], "aligned_skipped_tracks")

cache_hit_rate <- if ((cache_hit + cache_miss) > 0L) round(cache_hit / (cache_hit + cache_miss), 4) else NA_real_

extract_timing <- function(ctx, key) {
    pat <- sprintf("^.*\\[PERF\\]\\[%s\\]\\[[^\\]]+\\].*%s=([0-9]+(?:\\.[0-9]+)?).*$", ctx, key)
    vals <- suppressWarnings(as.numeric(sub(pat, "\\1", lines[grepl(pat, lines, perl = TRUE)], perl = TRUE)))
    vals[is.finite(vals)]
}

ortho_first <- extract_timing("ORTHO_TIMING", "first_plot_ready_ms")
ortho_total <- extract_timing("ORTHO_TIMING", "total_plots_ready_ms")
ortho_search <- extract_timing("ORTHO_TIMING", "search_finish_ms")

summary_df <- data.frame(
    metric = c(
        "aligned_runs", "render_enter", "cache_hit", "cache_miss", "cache_hit_rate",
        "fast_path_fatal", "fallback_legacy", "skipped_tracks_median", "skipped_tracks_max",
        "aligned_collect_ms_median", "aligned_gc_ms_median", "aligned_ribbons_ms_median",
        "aligned_plot_build_ms_median", "aligned_total_ms_median",
        "ortho_first_plot_ms_median", "ortho_total_ready_ms_median", "ortho_search_finish_ms_median"
    ),
    value = c(
        length(unique(run_id)), render_enter, cache_hit, cache_miss, cache_hit_rate,
        fast_fatal, fallback_legacy,
        summary_median(skipped_tracks), if (length(skipped_tracks) > 0L) max(skipped_tracks, na.rm = TRUE) else NA_real_,
        summary_median(collect_ms), summary_median(gc_ms), summary_median(ribbons_ms),
        summary_median(plot_build_ms), summary_median(total_ms),
        summary_median(ortho_first), summary_median(ortho_total), summary_median(ortho_search)
    ),
    stringsAsFactors = FALSE
)

cat(sprintf("Log: %s\n\n", log_path))
print(summary_df, row.names = FALSE)

cat("\nNotes:\n")
cat("- `aligned_total_ms_median` is the key aligned pipeline latency metric.\n")
cat("- `cache_hit_rate` near 1 means mode/theme toggles are mostly served from cache.\n")
cat("- `skipped_tracks_max` should be 0 in healthy aligned runs.\n")
