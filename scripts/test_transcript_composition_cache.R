source("R/utils.R")

assert_true <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

genome_path <- "genomes/GCF_000001735.4_TAIR10.1_genomic.2bit"
if (!file.exists(genome_path)) {
  cat("transcript-composition-cache-skip: fixture genome missing\n")
  quit(status = 0)
}

seqnames <- get_twobit_seqnames(genome_path)
if (length(seqnames) == 0L) {
  cat("transcript-composition-cache-skip: no 2bit seqnames\n")
  quit(status = 0)
}

seqid <- seqnames[[1]]
exons <- data.frame(
  start = c(1000, 1300, 1800),
  end = c(1099, 1399, 1899),
  stringsAsFactors = FALSE
)

for (strand in c("+", "-")) {
  .transcript_composition_cache <- new.env(parent = emptyenv())
  old_seq <- extract_spliced_exon_sequence(genome_path, seqid, exons, strand = strand)
  old_comp <- calculate_sequence_composition(old_seq)

  first <- get_transcript_composition_cached(genome_path, seqid, exons, strand = strand)
  second <- get_transcript_composition_cached(genome_path, seqid, exons, strand = strand)
  parsed <- parse_sequence_composition_blob(make_sequence_composition_blob(first))

  assert_true(identical(old_comp$composition, first$composition), paste("composition mismatch for strand", strand))
  assert_true(identical(first$counts, second$counts), paste("cache returned different counts for strand", strand))
  assert_true(identical(first$counts, parsed$counts), paste("composition blob lost counts for strand", strand))
  assert_true(is.null(first$sequence_optional), "composition helper should not return full sequence by default")
}

cat("transcript-composition-cache-ok\n")
