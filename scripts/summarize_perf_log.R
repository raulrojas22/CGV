#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
strict_mode <- "--strict" %in% args
args <- args[args != "--strict"]

if (length(args) < 1L) {
    cat("Usage: Rscript scripts/summarize_perf_log.R /path/to/app.log [--strict]\n")
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

all_perf <- lines[grepl("\\[PERF\\]\\[[^\\]]+\\]", lines, perl = TRUE)]
keep <- grepl("\\[PERF\\]\\[(HOMO_MOD|ORTHO_MOD)\\]", lines, perl = TRUE)
perf_lines <- lines[keep]
if (length(perf_lines) == 0L) {
    cat("No HOMO_MOD/ORTHO_MOD PERF lines found.\n")
    if (length(all_perf) > 0L) {
        extract_any_context <- function(x) {
            m <- regexec("\\[PERF\\]\\[([^\\]]+)\\]", x, perl = TRUE)
            out <- regmatches(x, m)
            vapply(out, function(y) if (length(y) >= 2L) y[[2]] else NA_character_, character(1))
        }
        ctx <- unique(stats::na.omit(extract_any_context(all_perf)))
        cat(sprintf("Found other PERF contexts: %s\n", paste(ctx, collapse = ", ")))
        cat("This usually means module render logs were not triggered in that run.\n")
    } else {
        cat("No PERF lines found at all.\n")
        cat("Run app with perf/debug flags and initial-visible defaults:\n")
        cat("  APP_HOMO_INITIAL_VISIBLE=1 APP_ORTHO_INITIAL_VISIBLE=1 APP_PERF_TIMING=1 APP_DEBUG_LOGS=1 Rscript -e \"shiny::runApp('.', launch.browser=FALSE)\" 2>&1 | tee /tmp/fullapp_perf.log\n")
    }
    cat("Then execute a real search (e.g. TP53) in Homologous/Orthologous before re-running this script.\n")
    if (isTRUE(strict_mode)) {
        quit(status = 2L)
    }
    quit(status = 0L)
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

cat(sprintf("Log: %s\n\n", log_path))
print(summary_df, row.names = FALSE)

cat("\nInterpretation tips:\n")
cat("- Lower `create_start` with high `cache_hit` indicates fewer heavy recomputations.\n")
cat("- `cache_hit_rate` near 1.0 means rerenders are mostly served from cache.\n")
cat("- If `cache_disabled` > 0, corresponding cache flag was off in that run.\n")
cat("- `first_plot_ms` and `total_plots_ready_ms` come from HOMO_TIMING/ORTHO_TIMING logs.\n")
