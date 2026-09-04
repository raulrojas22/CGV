#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(IRanges)
})

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
workspace <- if (length(script_arg)) {
  dirname(dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))))
} else {
  normalizePath(".")
}
source(file.path(workspace, "R", "utils.R"))

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
  file.path(workspace, "server.R"),
  "    normalize_pip_local_blocks <- function(df_blocks,",
  "    summarize_pip_reference_support <- function(df_blocks, min_identity = 70, min_block_length = 100) {"
)), envir = server_env)
eval(parse(text = extract_server_block(
  file.path(workspace, "server.R"),
  "    build_multipip_display_segments <- function(df_segments,",
  "    summarize_multipip_reference_support <- function(df_segments,"
)), envir = server_env)

fixture_dir <- file.path(workspace, "scripts", "fixtures")
general_lines <- readLines(file.path(fixture_dir, "lastz_general_sample.tsv"), warn = FALSE)
lav_lines <- readLines(file.path(fixture_dir, "lastz_sample.lav"), warn = FALSE)

old_lastz_disk_cache <- Sys.getenv("APP_LASTZ_DISK_CACHE", unset = "")
old_lastz_disk_cache_dir <- Sys.getenv("APP_LASTZ_DISK_CACHE_DIR", unset = "")
disk_cache_tmp <- tempfile("cgv-lastz-cache-")
on.exit({
  Sys.setenv(
    APP_LASTZ_DISK_CACHE = old_lastz_disk_cache,
    APP_LASTZ_DISK_CACHE_DIR = old_lastz_disk_cache_dir
  )
  unlink(disk_cache_tmp, recursive = TRUE, force = TRUE)
}, add = TRUE)
Sys.setenv(APP_LASTZ_DISK_CACHE = "1", APP_LASTZ_DISK_CACHE_DIR = disk_cache_tmp)
public_cache_ctx <- list(genome_path = file.path("genomes", "registry.tsv"))
private_cache_ctx <- list(genome_path = file.path(fixture_dir, "lastz_general_sample.tsv"))
assert_true(lastz_disk_cache_eligible(public_cache_ctx, public_cache_ctx), "Preloaded genomes should be eligible for the persistent LASTZ cache.")
assert_true(!lastz_disk_cache_eligible(private_cache_ctx, private_cache_ctx), "Files outside the shared genome registry must not enter the persistent LASTZ cache.")
disk_fixture_result <- list(status = "ok", blocks = data.frame(x = 1L), segments = data.frame(y = 2L))
lastz_disk_cache_set("fixture-ok", disk_fixture_result, public_cache_ctx, public_cache_ctx)
assert_true(identical(lastz_disk_cache_get("fixture-ok", public_cache_ctx, public_cache_ctx), disk_fixture_result), "Persistent LASTZ cache round-trip failed.")
lastz_disk_cache_set("fixture-error", list(status = "engine_error"), public_cache_ctx, public_cache_ctx)
assert_true(is.null(lastz_disk_cache_get("fixture-error", public_cache_ctx, public_cache_ctx)), "Failed LASTZ executions must not be cached.")

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
assert_true(identical(parse_locus_window_flank_bp("gene"), 0L), "Gene-only locus span was not parsed correctly.")
assert_true(identical(parse_locus_window_flank_bp("25kb"), 25000L), "Named locus span was not parsed correctly.")
assert_true(identical(parse_locus_window_flank_bp(5000L), 5000L), "A previously parsed numeric locus span must not fall back to 10 kb.")
assert_true(identical(parse_locus_window_flank_bp("50000"), 50000L), "A numeric-text locus span must retain its value.")
server_source <- paste(readLines("server.R", warn = FALSE), collapse = "\n")
assert_true(
  grepl("queue = lastzFutureQueue", server_source, fixed = TRUE) &&
    grepl("global future plan unchanged", server_source, fixed = TRUE),
  "LASTZ must use its dedicated background queue without mutating the global future plan."
)
assert_true(!grepl("homoLastzModesEnabled", server_source, fixed = TRUE), "Multi-Gene alignment choices must not expose LASTZ or MultiPIP.")
assert_true(grepl('homo_align_choices <- c("Synteny" = "aligned")', server_source, fixed = TRUE), "Multi-Gene must expose Synteny as its sole alignment method.")
assert_true(grepl('"LASTZ" = "pip_blocks",\n                "MultiPIP" = "pip_multipip"', server_source, fixed = TRUE), "Cross-Species must retain LASTZ and MultiPIP alignment methods.")
assert_true(grepl('"1:n" = "#00897B"', server_source, fixed = TRUE), "Synteny split relationships must use the distinct teal palette.")
assert_true(grepl('"n:1" = "#6F5BD3"', server_source, fixed = TRUE), "Synteny merge relationships must use the distinct violet palette.")
assert_true(grepl('"Feature boxes:"', server_source, fixed = TRUE) && grepl('"Relationship ribbons:"', server_source, fixed = TRUE), "Synteny must visibly separate feature colors from relationship colors.")
assert_true(grepl("Identity is not encoded by ribbon color.", server_source, fixed = TRUE), "Synteny legend must explain that ribbon color is not an identity scale.")
assert_true(grepl("multipip_prepared = TRUE", server_source, fixed = TRUE), "Reports must prepare both LASTZ views on the server from canonical results.")
toolbar_button_pattern <- 'actionButton\\(\\s*inputId\\s*=\\s*"ortho_(pip|multipip)_suggest_reference"'
assert_true(!grepl(toolbar_button_pattern, server_source, perl = TRUE), "The quadratic reference-suggestion buttons must not be rendered.")
ui_source <- paste(readLines("ui.R", warn = FALSE), collapse = "\n")
assert_true(!grepl(toolbar_button_pattern, ui_source, perl = TRUE), "The static UI must not expose the quadratic reference-suggestion button.")

parsed_blocks <- parse_lastz_general_output(general_lines, reference_ctx = ref_ctx, query_ctx = qry_ctx)
assert_true(is.data.frame(parsed_blocks) && nrow(parsed_blocks) == 2L, "General LASTZ fixture did not parse into two blocks.")
assert_true(all(parsed_blocks$identity_pct > 80), "General LASTZ fixture identity values are incorrect.")
canonical_segments <- parse_lastz_cigarx_segments(parsed_blocks, reference_ctx = ref_ctx, query_ctx = qry_ctx)
assert_true(is.data.frame(canonical_segments) && nrow(canonical_segments) == 2L, "Canonical CIGARX output did not produce gap-free MultiPIP segments.")
assert_true(all(abs(canonical_segments$identity_pct - c(95, 100 * 53 / 60)) < 0.001), "CIGARX segment identities were not computed exactly.")

reverse_cigar_block <- parsed_blocks[1L, , drop = FALSE]
reverse_cigar_block$strand2 <- "-"
reverse_cigar_block$start2_pos <- 15L
reverse_cigar_block$end2_pos <- 74L
reverse_cigar_block$cigarx <- "20=2X3I10=2D28="
reverse_cigar_segments <- parse_lastz_cigarx_segments(reverse_cigar_block, reference_ctx = ref_ctx, query_ctx = qry_ctx)
assert_true(nrow(reverse_cigar_segments) == 3L && all(reverse_cigar_segments$strand == "-"), "CIGARX reverse-strand segments were not preserved.")
assert_true(
  identical(as.integer(reverse_cigar_segments$qry_start[[1L]]), 2052L) && identical(as.integer(reverse_cigar_segments$qry_end[[1L]]), 2073L),
  "CIGARX reverse-strand coordinates were not mapped to the forward genomic axis correctly."
)

parsed_lav <- parse_lastz_lav_output(lav_lines, reference_ctx = ref_ctx, query_ctx = qry_ctx)
gap_free_segments <- compute_gap_free_segment_identity(extract_gap_free_segments_from_alignment(parsed_lav))
assert_true(is.data.frame(gap_free_segments) && nrow(gap_free_segments) == 2L, "LAV fixture did not produce two gap-free segments.")
assert_true(all(gap_free_segments$segment_bp >= 60), "Gap-free segment lengths are incorrect.")

reverse_lav_lines <- sub('"qry_seq\\+"', '"qry_seq-" 1 501 1 1', lav_lines, fixed = FALSE)
reverse_lav <- parse_lastz_lav_output(reverse_lav_lines, reference_ctx = ref_ctx, query_ctx = qry_ctx)
assert_true(nrow(reverse_lav) == 2L && all(reverse_lav$strand == "-"), "Real LASTZ LAV sequence metadata did not preserve the reverse strand.")
assert_true(
  identical(as.integer(reverse_lav$qry_start[[1L]]), 2427L) && identical(as.integer(reverse_lav$qry_end[[1L]]), 2486L),
  "Reverse-strand LAV coordinates were not converted to the forward genomic axis correctly."
)

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
