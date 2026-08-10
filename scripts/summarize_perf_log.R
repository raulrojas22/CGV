#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
strict_mode <- "--strict" %in% args
args <- args[args != "--strict"]
`%||%` <- function(a, b) if (!is.null(a)) a else b

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
if (length(all_perf) == 0L) {
    cat("No PERF lines found at all.\n")
    if (isTRUE(strict_mode)) {
        quit(status = 2L)
    }
    quit(status = 0L)
}

focus_metrics <- c(
    "first_plot_ready_ms",
    "total_plots_ready_ms",
    "browser_first_plot_painted_ms",
    "browser_total_plots_painted_ms",
    "client_click_to_first_paint_ms",
    "server_ready_to_browser_paint_ms",
    "search_finish_ms",
    "search_observer_total_ms",
    "lookup_local_exact_ms",
    "lookup_external_alias_ms",
    "lookup_local_flex_ms",
    "split_transcripts_ms",
    "metrics_payload_build_ms",
    "reactive_state_commit_ms",
    "module_init_ms",
    "sequence_prefetch_ms",
    "inline_fast_prefetch_ms",
    "gc_span_fetch_ms",
    "gene_sequence_fetch_ms",
    "neighbor_prefetch_ms",
    "neighbor_context_ms",
    "create_gene_plot_ms",
    "create_gene_plot_entry_delay_ms",
    "create_gene_plot_gc_ms",
    "model_build_ms",
    "girafe_build_ms",
    "compact_svg_ms"
)

extract_context <- function(x) {
    m <- regexec("\\[PERF\\]\\[([^\\]]+)\\]", x, perl = TRUE)
    out <- regmatches(x, m)
    vapply(out, function(y) if (length(y) >= 2L) y[[2]] else NA_character_, character(1))
}

infer_search_mode <- function(context) {
    ctx <- toupper(trimws(as.character(context %||% "")))
    if (startsWith(ctx, "HOMO")) {
        return("homologous")
    }
    if (startsWith(ctx, "ORTHO")) {
        return("orthologous")
    }
    NA_character_
}

infer_scenario <- function(path_txt) {
    nm <- tolower(basename(path_txt %||% ""))
    if (grepl("cold", nm, fixed = TRUE)) return("cold")
    if (grepl("warm", nm, fixed = TRUE) || grepl("prewarm", nm, fixed = TRUE) || grepl("hot", nm, fixed = TRUE)) return("warm")
    "default"
}

parse_metric_rows <- function(lines_vec, source_path) {
    contexts <- extract_context(lines_vec)
    scenario <- infer_scenario(source_path)
    rows <- list()
    row_idx <- 0L
    for (i in seq_along(lines_vec)) {
        ctx <- contexts[[i]]
        search_mode <- infer_search_mode(ctx)
        if (is.na(search_mode)) {
            next
        }
        matches <- gregexpr("([A-Za-z][A-Za-z0-9_]+)=([0-9]+(?:\\.[0-9]+)?)", lines_vec[[i]], perl = TRUE)
        captures <- regmatches(lines_vec[[i]], matches)[[1]]
        if (length(captures) == 0L) {
            next
        }
        for (capture in captures) {
            parts <- strsplit(capture, "=", fixed = TRUE)[[1]]
            metric <- as.character(parts[1] %||% "")
            value <- suppressWarnings(as.numeric(parts[2] %||% NA_real_))
            if (!metric %in% focus_metrics || !is.finite(value)) {
                next
            }
            row_idx <- row_idx + 1L
            rows[[row_idx]] <- data.frame(
                mode = search_mode,
                scenario = scenario,
                context = as.character(ctx),
                metric = metric,
                value = value,
                stringsAsFactors = FALSE
            )
        }
    }
    if (length(rows) == 0L) {
        return(data.frame())
    }
    do.call(rbind, rows)
}

timing_rows <- parse_metric_rows(all_perf, log_path)

module_lines <- all_perf[grepl("\\[PERF\\]\\[(HOMO_MOD|ORTHO_MOD)\\]", all_perf, perl = TRUE)]
module_context <- extract_context(module_lines)
count_pattern <- function(pattern, idx) {
    sum(grepl(pattern, module_lines[idx], perl = TRUE))
}
module_df <- if (length(module_lines) > 0L) {
    data.frame(
        module = c("HOMO_MOD", "ORTHO_MOD"),
        render_start = c(count_pattern("render start", module_context == "HOMO_MOD"), count_pattern("render start", module_context == "ORTHO_MOD")),
        create_start = c(count_pattern("create_gene_plot start", module_context == "HOMO_MOD"), count_pattern("create_gene_plot start", module_context == "ORTHO_MOD")),
        create_done = c(count_pattern("create_gene_plot done", module_context == "HOMO_MOD"), count_pattern("create_gene_plot done", module_context == "ORTHO_MOD")),
        cache_hit = c(count_pattern("render cache hit", module_context == "HOMO_MOD"), count_pattern("render cache hit", module_context == "ORTHO_MOD")),
        cache_miss = c(count_pattern("render cache miss", module_context == "HOMO_MOD"), count_pattern("render cache miss", module_context == "ORTHO_MOD")),
        cache_disabled = c(count_pattern("render cache disabled", module_context == "HOMO_MOD"), count_pattern("render cache disabled", module_context == "ORTHO_MOD")),
        stringsAsFactors = FALSE
    )
} else {
    data.frame()
}

cat(sprintf("Log: %s\n", log_path))
cat(sprintf("Scenario inference: %s\n\n", infer_scenario(log_path)))

if (nrow(module_df) > 0L) {
    module_df$cache_hit_rate <- ifelse(
        (module_df$cache_hit + module_df$cache_miss) > 0,
        round(module_df$cache_hit / (module_df$cache_hit + module_df$cache_miss), 4),
        NA_real_
    )
    cat("Module summary:\n")
    print(module_df, row.names = FALSE)
    cat("\n")
}

if (nrow(timing_rows) == 0L) {
    cat("No numeric timing metrics from the focused PERF keys were found.\n")
    if (isTRUE(strict_mode)) {
        quit(status = 2L)
    }
    quit(status = 0L)
}

median_rows <- stats::aggregate(
    timing_rows$value,
    by = list(mode = timing_rows$mode, scenario = timing_rows$scenario, metric = timing_rows$metric),
    FUN = function(x) round(stats::median(x, na.rm = TRUE), 1)
)
colnames(median_rows)[colnames(median_rows) == "x"] <- "median_ms"

sample_rows <- stats::aggregate(
    timing_rows$value,
    by = list(mode = timing_rows$mode, scenario = timing_rows$scenario, metric = timing_rows$metric),
    FUN = length
)
colnames(sample_rows)[colnames(sample_rows) == "x"] <- "samples"

summary_long <- merge(median_rows, sample_rows, by = c("mode", "scenario", "metric"), all = TRUE, sort = FALSE)
summary_wide <- reshape(
    summary_long[, c("mode", "scenario", "metric", "median_ms"), drop = FALSE],
    idvar = c("mode", "scenario"),
    timevar = "metric",
    direction = "wide"
)
colnames(summary_wide) <- sub("^median_ms\\.", "", colnames(summary_wide))

cat("Timing medians by search mode and scenario:\n")
print(summary_wide[order(summary_wide$mode, summary_wide$scenario), , drop = FALSE], row.names = FALSE)

cat("\nTiming samples:\n")
print(summary_long[order(summary_long$mode, summary_long$scenario, summary_long$metric), , drop = FALSE], row.names = FALSE)
