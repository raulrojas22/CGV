#!/usr/bin/env Rscript

source("R/utils.R")
source("R/modules.R")

assert_true <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

fasta_body <- function(txt) {
  lines <- unlist(strsplit(as.character(txt %||% ""), "\n", fixed = TRUE), use.names = FALSE)
  if (length(lines) <= 1L) return("")
  paste(lines[-1], collapse = "")
}

source_seq <- paste0(rep(c("A", "C", "G", "T"), 12), collapse = "")
source_seq <- substr(source_seq, 1, 40)
tmp_fasta <- tempfile(fileext = ".fa")
writeLines(c(">chrTest", source_seq), tmp_fasta)
on.exit(unlink(tmp_fasta), add = TRUE)

plot_data <- data.frame(
  V1 = "chrTest",
  V2 = "test",
  V3 = c("gene", "mRNA", "exon", "exon", "CDS", "CDS"),
  V4 = c(1, 5, 5, 20, 7, 20),
  V5 = c(40, 35, 10, 25, 10, 23),
  V6 = ".",
  V7 = "+",
  V8 = ".",
  V9 = c(
    "ID=gene1;Name=GENE1",
    "ID=tx1;Parent=gene1",
    "ID=exon1;Parent=tx1",
    "ID=exon2;Parent=tx1",
    "ID=cds1;Parent=tx1",
    "ID=cds2;Parent=tx1"
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
expected_tx <- paste0(substr(source_seq, 5, 10), substr(source_seq, 20, 25))
expected_cds <- paste0(substr(source_seq, 7, 10), substr(source_seq, 20, 23))
expected_introns <- substr(source_seq, 11, 19)

gene_fasta <- build_selected_sequence_fasta_content("gene", plot_data, gene_meta, "Gene: GENE1 | Transcript: tx1", tmp_fasta)
tx_fasta <- build_selected_sequence_fasta_content("transcript", plot_data, gene_meta, "Gene: GENE1 | Transcript: tx1", tmp_fasta)
cds_fasta <- build_selected_sequence_fasta_content("cds", plot_data, gene_meta, "Gene: GENE1 | Transcript: tx1", tmp_fasta)
introns_fasta <- build_selected_sequence_fasta_content("introns", plot_data, gene_meta, "Gene: GENE1 | Transcript: tx1", tmp_fasta)

assert_true(identical(fasta_body(gene_fasta), expected_gene), "gene FASTA does not match full gene span")
assert_true(identical(fasta_body(tx_fasta), expected_tx), "transcript FASTA does not match spliced exons")
assert_true(identical(fasta_body(cds_fasta), expected_cds), "CDS FASTA does not match spliced CDS")
assert_true(identical(fasta_body(introns_fasta), expected_introns), "intron FASTA does not match inferred exon gaps")
assert_true(grepl("type=introns", introns_fasta, fixed = TRUE), "intron FASTA header missing type")
assert_true(grepl("segments=1", introns_fasta, fixed = TRUE), "intron FASTA header missing segment count")

plot_data_minus <- plot_data
plot_data_minus$V7 <- "-"
gene_meta_minus <- gene_meta
gene_meta_minus$strand <- "-"
tx_minus <- build_selected_sequence_fasta_content("transcript", plot_data_minus, gene_meta_minus, "Gene: GENE1 | Transcript: tx1", tmp_fasta)
assert_true(
  identical(fasta_body(tx_minus), reverse_complement_dna(expected_tx)),
  "minus-strand transcript FASTA is not reverse complemented"
)

empty_introns <- plot_data[plot_data$V3 != "exon" | plot_data$V4 == 5, , drop = FALSE]
empty_fasta <- build_selected_sequence_fasta_content("introns", empty_introns, gene_meta, "Gene: GENE1 | Transcript: tx1", tmp_fasta)
assert_true(identical(fasta_body(empty_fasta), ""), "single-exon intron download should produce an empty sequence body")
assert_true(grepl("^>tx1 \\| type=introns", empty_fasta), "empty intron FASTA should still include a valid header")

cat("selected-sequence-download-ok\n")
