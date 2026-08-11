source("R/utils.R")
source("R/modules.R")

old_enabled <- Sys.getenv("APP_INLINE_FAST_SEQUENCE_PREFETCH", unset = NA_character_)
old_max <- Sys.getenv("APP_INLINE_FAST_SEQUENCE_MAX_BP", unset = NA_character_)
tmp_2bit <- tempfile(fileext = ".2bit")
tmp_fasta <- tempfile(fileext = ".fa")
file.create(tmp_2bit, tmp_fasta)

on.exit({
    unlink(c(tmp_2bit, tmp_fasta))
    if (is.na(old_enabled)) Sys.unsetenv("APP_INLINE_FAST_SEQUENCE_PREFETCH") else Sys.setenv(APP_INLINE_FAST_SEQUENCE_PREFETCH = old_enabled)
    if (is.na(old_max)) Sys.unsetenv("APP_INLINE_FAST_SEQUENCE_MAX_BP") else Sys.setenv(APP_INLINE_FAST_SEQUENCE_MAX_BP = old_max)
}, add = TRUE)

Sys.setenv(APP_INLINE_FAST_SEQUENCE_PREFETCH = "1", APP_INLINE_FAST_SEQUENCE_MAX_BP = "10000")
stopifnot(isTRUE(should_inline_fast_sequence_prefetch(tmp_2bit, 100, 1000)))
stopifnot(isTRUE(all.equal(deferred_plot_enrichment_delay_seconds(), 0.15)))
stopifnot(!isTRUE(should_inline_fast_sequence_prefetch(tmp_2bit, 1, 20000)))
stopifnot(!isTRUE(should_inline_fast_sequence_prefetch(tmp_fasta, 100, 1000)))

Sys.setenv(APP_INLINE_FAST_SEQUENCE_PREFETCH = "0")
stopifnot(!isTRUE(should_inline_fast_sequence_prefetch(tmp_2bit, 100, 1000)))
stopifnot(isTRUE(all.equal(deferred_plot_enrichment_delay_seconds(), 1.5)))
stopifnot(isTRUE(all.equal(deferred_plot_enrichment_delay_seconds(0.5), 2.0)))

cat("inline-fast-sequence-prefetch-ok\n")
