#!/usr/bin/env Rscript

source(file.path("R", "utils.R"))

assert_true <- function(value, message) {
    if (!isTRUE(value)) stop(message, call. = FALSE)
}

tmp_root <- tempfile("cgv-twobit-sidecar-")
dir.create(tmp_root, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(tmp_root, recursive = TRUE, force = TRUE), add = TRUE)

old_cache_dir <- Sys.getenv("CGV_CACHE_DIR", unset = "")
Sys.setenv(CGV_CACHE_DIR = file.path(tmp_root, "cache"))
on.exit({
    if (nzchar(old_cache_dir)) {
        Sys.setenv(CGV_CACHE_DIR = old_cache_dir)
    } else {
        Sys.unsetenv("CGV_CACHE_DIR")
    }
}, add = TRUE)

fake_twobit <- file.path(tmp_root, "genomes", "mock.2bit")
dir.create(dirname(fake_twobit), recursive = TRUE, showWarnings = FALSE)
writeBin(charToRaw("mock-two-bit-v1"), fake_twobit)

expected <- c("chr1", "chr2", "scaffold_3")
assert_true(
    write_twobit_seqnames_sidecar(fake_twobit, expected, base_dir = tmp_root),
    "Could not write 2bit seqname sidecar."
)

sidecar_path <- twobit_seqnames_sidecar_path(fake_twobit, base_dir = tmp_root)
assert_true(file.exists(sidecar_path), "2bit seqname sidecar was not created under cache/genome_seqnames.")

observed <- get_twobit_seqnames(fake_twobit, base_dir = tmp_root)
assert_true(identical(observed, expected), "get_twobit_seqnames did not read the valid sidecar.")

rm(list = ls(envir = .twobit_seqinfo_cache, all.names = TRUE), envir = .twobit_seqinfo_cache)
Sys.sleep(1.1)
writeBin(charToRaw("mock-two-bit-v2"), fake_twobit)

stale <- read_twobit_seqnames_sidecar(fake_twobit, base_dir = tmp_root)
assert_true(is.null(stale), "A stale 2bit seqname sidecar must be rejected.")

cat("twobit-seqnames-sidecar-ok\n")
