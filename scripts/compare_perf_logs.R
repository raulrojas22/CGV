#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
    cat("Usage: Rscript scripts/compare_perf_logs.R /path/to/baseline.log /path/to/candidate.log\n")
    quit(status = 1L)
}
`%||%` <- function(a, b) if (!is.null(a)) a else b

baseline_path <- normalizePath(args[[1]], winslash = "/", mustWork = FALSE)
candidate_path <- normalizePath(args[[2]], winslash = "/", mustWork = FALSE)

for (path_txt in c(baseline_path, candidate_path)) {
    if (!file.exists(path_txt)) {
        stop(sprintf("Log file not found: %s", path_txt))
    }
}

focus_metrics <- c(
    "first_plot_ready_ms",
    "total_plots_ready_ms",
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
    "neighbor_context_ms",
    "create_gene_plot_ms",
    "girafe_build_ms"
)

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

summarize_log <- function(path_txt, label) {
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
                label = label,
                mode = search_mode,
                scenario = infer_scenario(path_txt),
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
    out <- stats::aggregate(
        df$value,
        by = list(label = df$label, mode = df$mode, scenario = df$scenario, metric = df$metric),
        FUN = function(x) round(stats::median(x, na.rm = TRUE), 1)
    )
    colnames(out)[colnames(out) == "x"] <- "median_ms"
    out
}

baseline_df <- summarize_log(baseline_path, "baseline")
candidate_df <- summarize_log(candidate_path, "candidate")
cmp <- merge(
    baseline_df,
    candidate_df,
    by = c("mode", "scenario", "metric"),
    suffixes = c("_baseline", "_candidate"),
    all = TRUE,
    sort = FALSE
)

cmp$median_ms_saved <- cmp$median_ms_baseline - cmp$median_ms_candidate
cmp$improvement_pct <- ifelse(
    is.finite(cmp$median_ms_baseline) & cmp$median_ms_baseline > 0,
    round(100 * cmp$median_ms_saved / cmp$median_ms_baseline, 2),
    NA_real_
)

cat(sprintf("Baseline log:  %s\n", baseline_path))
cat(sprintf("Candidate log: %s\n\n", candidate_path))

cat("Baseline medians:\n")
print(baseline_df[order(baseline_df$mode, baseline_df$scenario, baseline_df$metric), ], row.names = FALSE)
cat("\nCandidate medians:\n")
print(candidate_df[order(candidate_df$mode, candidate_df$scenario, candidate_df$metric), ], row.names = FALSE)
cat("\nComparison:\n")
print(cmp[order(cmp$mode, cmp$scenario, cmp$metric), c("mode", "scenario", "metric", "median_ms_baseline", "median_ms_candidate", "median_ms_saved", "improvement_pct")], row.names = FALSE)
