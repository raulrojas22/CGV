source("R/utils.R")

source_text <- paste0(rep(c("A", "C", "G", "T"), 20), collapse = "")
exons <- data.frame(start = c(5, 17, 33), end = c(10, 21, 40))
span_start <- min(exons$start)
expected <- paste0(
    substr(source_text, exons$start[1] - span_start + 1, exons$end[1] - span_start + 1),
    substr(source_text, exons$start[2] - span_start + 1, exons$end[2] - span_start + 1),
    substr(source_text, exons$start[3] - span_start + 1, exons$end[3] - span_start + 1)
)

converter <- normalizePath("faToTwoBit", winslash = "/", mustWork = TRUE)
tmp_fasta <- tempfile(fileext = ".fa")
tmp_twobit <- tempfile(fileext = ".2bit")
writeLines(c(">chrTest", source_text), tmp_fasta)
on.exit(unlink(c(tmp_fasta, tmp_twobit)), add = TRUE)
status <- system2(converter, args = c(tmp_fasta, tmp_twobit))
stopifnot(identical(status, 0L), file.exists(tmp_twobit))

actual <- extract_spliced_exon_sequence(tmp_twobit, "chrTest", exons, strand = "+")
stopifnot(identical(actual, expected))
stopifnot(identical(reverse_complement_dna(reverse_complement_dna(actual)), actual))
cat("twobit-single-span-splice-ok\n")
