#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(IRanges)
})

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

source("/Users/rarojas/Documents/A_FULLAPP/R/utils.R")

app_perf_mark <- function(run = NULL, step = "", context = "APP") invisible(NULL)

feature_ranges_union_length <- function(ranges_df) {
  if (is.null(ranges_df) || !is.data.frame(ranges_df) || nrow(ranges_df) == 0L) {
    return(0)
  }
  ranges_df <- unique(data.frame(
    start = pmin(as.numeric(ranges_df$start), as.numeric(ranges_df$end)),
    end = pmax(as.numeric(ranges_df$start), as.numeric(ranges_df$end))
  ))
  ranges_df <- ranges_df[order(ranges_df$start, ranges_df$end), , drop = FALSE]
  merged <- ranges_df[1, , drop = FALSE]
  if (nrow(ranges_df) > 1L) {
    for (idx in 2:nrow(ranges_df)) {
      if (ranges_df$start[idx] <= merged$end[nrow(merged)] + 1) {
        merged$end[nrow(merged)] <- max(merged$end[nrow(merged)], ranges_df$end[idx])
      } else {
        merged <- rbind(merged, ranges_df[idx, , drop = FALSE])
      }
    }
  }
  sum(merged$end - merged$start + 1)
}

assert_true <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

extract_server_block <- function(path, start_pattern, end_pattern) {
  lines <- readLines(path, warn = FALSE)
  start_idx <- grep(start_pattern, lines, fixed = TRUE)[1]
  end_idx <- grep(end_pattern, lines, fixed = TRUE)[1]
  if (!is.finite(start_idx) || !is.finite(end_idx) || end_idx <= start_idx) {
    stop(sprintf("Unable to extract server block: %s -> %s", start_pattern, end_pattern), call. = FALSE)
  }
  paste(lines[start_idx:(end_idx - 1L)], collapse = "\n")
}

server_env <- new.env(parent = globalenv())
server_env$feature_ranges_union_length <- feature_ranges_union_length
eval(parse(text = extract_server_block(
  "/Users/rarojas/Documents/A_FULLAPP/server.R",
  "    normalize_pip_local_blocks <- function(df_blocks,",
  "    summarize_pip_reference_support <- function(df_blocks, min_identity = 70, min_block_length = 100) {"
)), envir = server_env)
eval(parse(text = extract_server_block(
  "/Users/rarojas/Documents/A_FULLAPP/server.R",
  "    build_multipip_display_segments <- function(df_segments,",
  "    summarize_multipip_reference_support <- function(df_segments,"
)), envir = server_env)

fixture_dir <- "/Users/rarojas/Documents/A_FULLAPP/scripts/fixtures"
general_lines <- readLines(file.path(fixture_dir, "lastz_general_sample.tsv"), warn = FALSE)
lav_lines <- readLines(file.path(fixture_dir, "lastz_sample.lav"), warn = FALSE)

ref_ctx <- list(plot_id = "ref", seqid = "chrRef", window_start = 1000L, window_end = 1500L)
qry_ctx <- list(plot_id = "qry", seqid = "chrQry", window_start = 2000L, window_end = 2500L)

old_lastz_timeout <- Sys.getenv("APP_LASTZ_TIMEOUT_SECONDS", unset = "")
old_lastz_max_bp <- Sys.getenv("APP_LASTZ_MAX_SEQUENCE_BP", unset = "")
on.exit({
  Sys.setenv(
    APP_LASTZ_TIMEOUT_SECONDS = old_lastz_timeout,
    APP_LASTZ_MAX_SEQUENCE_BP = old_lastz_max_bp
  )
}, add = TRUE)
Sys.setenv(APP_LASTZ_TIMEOUT_SECONDS = "17", APP_LASTZ_MAX_SEQUENCE_BP = "12345")
assert_true(identical(lastz_process_timeout_ms(), 17000L), "LASTZ timeout environment setting was not converted to milliseconds.")
assert_true(identical(lastz_max_sequence_bp(), 12345L), "LASTZ maximum sequence guard was not applied.")
Sys.setenv(APP_LASTZ_TIMEOUT_SECONDS = old_lastz_timeout, APP_LASTZ_MAX_SEQUENCE_BP = old_lastz_max_bp)
server_source <- paste(readLines("server.R", warn = FALSE), collapse = "\n")
assert_true(
  grepl("I(as.integer(target_workers))", server_source, fixed = TRUE),
  "LASTZ with one worker must remain on a real background multisession process."
)

parsed_blocks <- parse_lastz_general_output(general_lines, reference_ctx = ref_ctx, query_ctx = qry_ctx)
assert_true(is.data.frame(parsed_blocks) && nrow(parsed_blocks) == 2L, "General LASTZ fixture did not parse into two blocks.")
assert_true(all(parsed_blocks$identity_pct > 80), "General LASTZ fixture identity values are incorrect.")

parsed_lav <- parse_lastz_lav_output(lav_lines, reference_ctx = ref_ctx, query_ctx = qry_ctx)
gap_free_segments <- compute_gap_free_segment_identity(extract_gap_free_segments_from_alignment(parsed_lav))
assert_true(is.data.frame(gap_free_segments) && nrow(gap_free_segments) == 2L, "LAV fixture did not produce two gap-free segments.")
assert_true(all(gap_free_segments$segment_bp >= 60), "Gap-free segment lengths are incorrect.")

pip_view <- server_env$build_pip_display_blocks(parsed_blocks, min_identity = 70, min_block_length = 20)
assert_true(is.data.frame(pip_view$deduplicated_blocks) && nrow(pip_view$deduplicated_blocks) == 2L, "PIP build unexpectedly removed fixture blocks.")
assert_true(is.data.frame(pip_view$chained_blocks) && length(unique(stats::na.omit(pip_view$chained_blocks$chain_id))) >= 1L, "PIP build did not assign chain ids.")

multipip_view <- server_env$build_multipip_display_segments(gap_free_segments, min_identity = 70, min_segment_bp = 20)
assert_true(is.data.frame(multipip_view$pruned_segments) && nrow(multipip_view$pruned_segments) == 2L, "MultiPIP build unexpectedly pruned fixture segments.")

synthetic_blocks <- data.frame(
  ref_plot_id = "ref",
  query_plot_id = "qry",
  ref_seqid = "chrRef",
  query_seqid = "chrQry",
  ref_genomic_start = c(100, 170, 260, 100, 170),
  ref_genomic_end = c(160, 230, 320, 160, 230),
  query_genomic_start = c(500, 570, 660, 900, 830),
  query_genomic_end = c(560, 630, 720, 840, 770),
  strand2 = c("+", "+", "+", "-", "-"),
  identity_pct = c(96, 94, 92, 91, 90),
  align_len = c(61, 61, 61, 61, 61),
  score = c(5000, 4800, 4700, 4600, 4500),
  stringsAsFactors = FALSE
)
synthetic_pip <- server_env$build_pip_display_blocks(synthetic_blocks, min_identity = 70, min_block_length = 20)
assert_true(length(unique(synthetic_pip$chained_blocks$chain_id[synthetic_pip$chained_blocks$strand_state == "forward"])) == 1L, "Forward conservation chain should stay contiguous.")
assert_true(length(unique(synthetic_pip$chained_blocks$chain_id[synthetic_pip$chained_blocks$strand_state == "reverse"])) >= 1L, "Reverse-strand blocks should remain separable from forward chains.")

ref_feature_df <- data.frame(
  feature_group = c("cds", "utr", "exon"),
  xstart_clip = c(100, 220, 340),
  xend_clip = c(180, 260, 380),
  stringsAsFactors = FALSE
)
synthetic_segments <- data.frame(
  query_plot_id = c("qry", "qry", "qry"),
  strand = c("+", "+", "+"),
  identity_pct = c(97, 89, 84),
  score = c(2000, 1800, 1500),
  segment_bp = c(40L, 30L, 35L),
  ref_start = c(120, 230, 300),
  ref_end = c(159, 259, 334),
  qry_start = c(500, 700, 900),
  qry_end = c(539, 729, 934),
  qry_lav_start = c(500L, 700L, 900L),
  qry_lav_end = c(539L, 729L, 934L),
  qry_width = c(2000L, 2000L, 2000L),
  query_window_start = c(2000L, 2000L, 2000L),
  stringsAsFactors = FALSE
)
classified <- server_env$build_multipip_display_segments(
  synthetic_segments,
  min_identity = 70,
  min_segment_bp = 20,
  ref_feature_df = ref_feature_df
)$pruned_segments
assert_true(identical(as.character(classified$underlay_context), c("cds", "noncoding_exon", "intron_or_flank")), "Reference underlay classification is biologically inconsistent.")

timing_blocks <- synthetic_blocks[rep(seq_len(nrow(synthetic_blocks)), 80), , drop = FALSE]
timing_blocks$ref_genomic_start <- timing_blocks$ref_genomic_start + rep(seq(0, by = 7, length.out = nrow(timing_blocks)), 1)
timing_blocks$ref_genomic_end <- timing_blocks$ref_genomic_start + timing_blocks$align_len - 1L
timing_blocks$query_genomic_start <- timing_blocks$query_genomic_start + rep(seq(0, by = 7, length.out = nrow(timing_blocks)), 1)
timing_blocks$query_genomic_end <- timing_blocks$query_genomic_start + timing_blocks$align_len - 1L
elapsed_pip <- system.time(server_env$build_pip_display_blocks(timing_blocks, min_identity = 70, min_block_length = 20))[["elapsed"]]
assert_true(elapsed_pip < 20, "PIP pipeline regression smoke test exceeded the time budget.")

cat("pip-pipeline-regression-ok\n")
