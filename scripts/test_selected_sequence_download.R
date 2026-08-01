#!/usr/bin/env Rscript

source("R/utils.R")
source("R/modules.R")

assert_true <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

fasta_body <- function(txt) {
  records <- parse_fasta(txt)
  if (length(records) == 0L) return("")
  records[[1]]$sequence
}

parse_fasta <- function(txt) {
  lines <- unlist(strsplit(as.character(txt %||% ""), "\n", fixed = TRUE), use.names = FALSE)
  header_idx <- grep("^>", lines)
  if (length(header_idx) == 0L) return(list())
  lapply(seq_along(header_idx), function(i) {
    start_i <- header_idx[i]
    end_i <- if (i < length(header_idx)) header_idx[i + 1L] - 1L else length(lines)
    body <- if (end_i > start_i) lines[seq.int(start_i + 1L, end_i)] else character(0)
    body <- body[nzchar(body)]
    list(header = lines[start_i], sequence = paste(body, collapse = ""))
  })
}

source_seq <- paste0(rep(c("A", "C", "G", "T"), 12), collapse = "")
source_seq <- substr(source_seq, 1, 40)
tmp_fasta <- tempfile(fileext = ".fa")
writeLines(c(">chrTest", source_seq), tmp_fasta)
on.exit(unlink(tmp_fasta), add = TRUE)

plot_data <- data.frame(
  V1 = "chrTest",
  V2 = "test",
  V3 = c("gene", "mRNA", "exon", "exon", "exon", "CDS", "CDS", "CDS"),
  V4 = c(1, 5, 5, 20, 30, 7, 20, 30),
  V5 = c(40, 35, 10, 25, 35, 10, 23, 33),
  V6 = ".",
  V7 = "+",
  V8 = c(".", ".", ".", ".", ".", "0", "1", "2"),
  V9 = c(
    "ID=gene1;Name=GENE1",
    "ID=tx1;Parent=gene1",
    "ID=exon1;Parent=tx1",
    "ID=exon2;Parent=tx1",
    "ID=exon3;Parent=tx1",
    "ID=cds1;Parent=tx1",
    "ID=cds2;Parent=tx1",
    "ID=cds3;Parent=tx1"
  ),
  stringsAsFactors = FALSE
)

gene_meta <- list(
  display_gene_name = "GENE1",
  matched_gene_name = "GENE1",
  seqid = "chrTest",
  gene_start_bp = 1,
  gene_end_bp = 40,
  strand = "+"
)

expected_gene <- substr(source_seq, 1, 40)
expected_tx <- paste0(substr(source_seq, 5, 10), substr(source_seq, 20, 25), substr(source_seq, 30, 35))
expected_cds_parts <- c(substr(source_seq, 7, 10), substr(source_seq, 20, 23), substr(source_seq, 30, 33))
expected_cds <- paste0(expected_cds_parts, collapse = "")
expected_intron_parts <- c(substr(source_seq, 11, 19), substr(source_seq, 26, 29))

gene_fasta <- build_selected_sequence_fasta_content("gene", plot_data, gene_meta, "Gene: GENE1 | Transcript: tx1", tmp_fasta)
tx_fasta <- build_selected_sequence_fasta_content("transcript", plot_data, gene_meta, "Gene: GENE1 | Transcript: tx1", tmp_fasta)
cds_fasta <- build_selected_sequence_fasta_content("cds", plot_data, gene_meta, "Gene: GENE1 | Transcript: tx1", tmp_fasta)
cds_segments_fasta <- build_selected_sequence_fasta_content("cds_segments", plot_data, gene_meta, "Gene: GENE1 | Transcript: tx1", tmp_fasta)
introns_fasta <- build_selected_sequence_fasta_content("introns", plot_data, gene_meta, "Gene: GENE1 | Transcript: tx1", tmp_fasta)

assert_true(identical(fasta_body(gene_fasta), expected_gene), "gene FASTA does not match full gene span")
assert_true(identical(fasta_body(tx_fasta), expected_tx), "transcript FASTA does not match spliced exons")
assert_true(identical(fasta_body(cds_fasta), expected_cds), "CDS FASTA does not match spliced CDS")
cds_segment_records <- parse_fasta(cds_segments_fasta)
intron_records <- parse_fasta(introns_fasta)
assert_true(length(cds_segment_records) == 3L, "CDS segment download should contain one FASTA record per CDS")
assert_true(
  identical(vapply(cds_segment_records, `[[`, character(1), "sequence"), expected_cds_parts),
  "CDS segment FASTA records do not preserve individual CDS sequences"
)
assert_true(length(intron_records) == 2L, "intron download should contain one FASTA record per intron")
assert_true(
  identical(vapply(intron_records, `[[`, character(1), "sequence"), expected_intron_parts),
  "intron FASTA records do not preserve individual intron sequences"
)
assert_true(all(grepl("type=cds_segment", vapply(cds_segment_records, `[[`, character(1), "header"), fixed = TRUE)), "CDS segment headers missing type")
assert_true(grepl("segment=2/3", cds_segment_records[[2]]$header, fixed = TRUE), "CDS segment header missing position within transcript")
assert_true(grepl("start=20 | end=23", cds_segment_records[[2]]$header, fixed = TRUE), "CDS segment header missing genomic coordinates")
assert_true(grepl("length_bp=4", cds_segment_records[[2]]$header, fixed = TRUE), "CDS segment header missing length")
assert_true(grepl("phase=1", cds_segment_records[[2]]$header, fixed = TRUE), "CDS segment header missing phase")
assert_true(all(grepl("type=intron", vapply(intron_records, `[[`, character(1), "header"), fixed = TRUE)), "intron FASTA headers missing type")
assert_true(grepl("segment=2/2", intron_records[[2]]$header, fixed = TRUE), "intron FASTA header missing position within transcript")

plot_data_tx2 <- data.frame(
  V1 = "chrTest",
  V2 = "test",
  V3 = c("mRNA", "exon", "CDS"),
  V4 = c(2, 2, 2),
  V5 = c(4, 4, 4),
  V6 = ".",
  V7 = "+",
  V8 = c(".", ".", "0"),
  V9 = c(
    "ID=tx2;Parent=gene1",
    "ID=tx2_exon1;Parent=tx2",
    "ID=tx2_cds1;Parent=tx2"
  ),
  stringsAsFactors = FALSE
)
multi_tx_records <- parse_fasta(build_selected_sequence_fasta_content(
  "cds_segments",
  rbind(plot_data, plot_data_tx2),
  gene_meta,
  "Gene: GENE1 | Transcript: tx1",
  tmp_fasta
))
assert_true(length(multi_tx_records) == 3L, "segmented download should only include the selected transcript")

plot_data_minus <- plot_data
plot_data_minus$V7 <- "-"
gene_meta_minus <- gene_meta
gene_meta_minus$strand <- "-"
tx_minus <- build_selected_sequence_fasta_content("transcript", plot_data_minus, gene_meta_minus, "Gene: GENE1 | Transcript: tx1", tmp_fasta)
cds_segments_minus <- parse_fasta(build_selected_sequence_fasta_content("cds_segments", plot_data_minus, gene_meta_minus, "Gene: GENE1 | Transcript: tx1", tmp_fasta))
introns_minus <- parse_fasta(build_selected_sequence_fasta_content("introns", plot_data_minus, gene_meta_minus, "Gene: GENE1 | Transcript: tx1", tmp_fasta))
assert_true(
  identical(fasta_body(tx_minus), reverse_complement_dna(expected_tx)),
  "minus-strand transcript FASTA is not reverse complemented"
)
assert_true(
  identical(
    vapply(cds_segments_minus, `[[`, character(1), "sequence"),
    unname(vapply(rev(expected_cds_parts), reverse_complement_dna, character(1)))
  ),
  "minus-strand CDS segments are not numbered in biological 5-prime to 3-prime order"
)
assert_true(
  identical(
    vapply(introns_minus, `[[`, character(1), "sequence"),
    unname(vapply(rev(expected_intron_parts), reverse_complement_dna, character(1)))
  ),
  "minus-strand introns are not numbered in biological 5-prime to 3-prime order"
)

empty_introns <- plot_data[plot_data$V3 != "exon" | plot_data$V4 == 5, , drop = FALSE]
empty_fasta <- build_selected_sequence_fasta_content("introns", empty_introns, gene_meta, "Gene: GENE1 | Transcript: tx1", tmp_fasta)
assert_true(identical(fasta_body(empty_fasta), ""), "single-exon intron download should produce an empty sequence body")
assert_true(grepl("^>tx1 \\| type=introns", empty_fasta), "empty intron FASTA should still include a valid header")

assert_true(identical(normalize_sequence_download_type("CDS segments"), "cds_segments"), "CDS segment type normalization failed")

cat("selected-sequence-download-ok\n")
