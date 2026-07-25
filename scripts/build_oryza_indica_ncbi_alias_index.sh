#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

mkdir -p annotations data/alias_index data/ncbi_gene logs

NCBI_GFF_URL="https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/004/655/GCA_000004655.2_ASM465v1/GCA_000004655.2_ASM465v1_genomic.gff.gz"
NCBI_GFF="annotations/GCA_000004655.2_ASM465v1_genomic.gff.gz"
SPECIES_ID="oryza_sativa_indica_group_gca_000004655_2_asm465v1_ncbi"
ORGANISM_NAME="Oryza sativa Indica Group"
TAXID="39946"
NCBI_DIR="${CGV_NCBI_GENE_DIR:-build_sources/ncbi_gene}"
if [[ ! -d "$NCBI_DIR" ]]; then
  NCBI_DIR="data/ncbi_gene"
fi

echo "Building alternate NCBI-based alias index for Oryza sativa Indica Group"
echo "Project:      $PWD"
echo "Annotation:   $NCBI_GFF"
echo "Species ID:   $SPECIES_ID"
echo "NCBI tables:  $NCBI_DIR"
echo

if [[ ! -f "$NCBI_GFF" ]] || ! gzip -t "$NCBI_GFF" >/dev/null 2>&1; then
  echo "Downloading NCBI/GenBank GFF..."
  curl -L --fail --continue-at - --retry 5 --retry-delay 5 \
    -o "${NCBI_GFF}.part" \
    "$NCBI_GFF_URL"
  gzip -t "${NCBI_GFF}.part"
  mv "${NCBI_GFF}.part" "$NCBI_GFF"
else
  echo "Using existing valid GFF: $NCBI_GFF"
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="logs/oryza_indica_ncbi_alias_${STAMP}.log"

NCBI_DOWNLOAD_FLAG=()
if [[ -f "$NCBI_DIR/gene_info.gz" ]] &&
   [[ -f "$NCBI_DIR/gene2refseq.gz" ]] &&
   [[ -f "$NCBI_DIR/gene2accession.gz" ]] &&
   [[ -f "$NCBI_DIR/gene2ensembl.gz" ]] &&
   gzip -t "$NCBI_DIR/gene_info.gz" >/dev/null 2>&1 &&
   gzip -t "$NCBI_DIR/gene2refseq.gz" >/dev/null 2>&1 &&
   gzip -t "$NCBI_DIR/gene2accession.gz" >/dev/null 2>&1 &&
   gzip -t "$NCBI_DIR/gene2ensembl.gz" >/dev/null 2>&1; then
  NCBI_DOWNLOAD_FLAG=(--skip-download)
  echo "Using existing valid NCBI Gene tables; downloads disabled."
else
  echo "NCBI Gene tables are missing or invalid in $NCBI_DIR; the builder may download/resume them there."
fi

Rscript scripts/build_alias_index_enriched.R \
  --organism-id="$SPECIES_ID" \
  --annotation-path="$NCBI_GFF" \
  --organism-name="$ORGANISM_NAME" \
  --label="$ORGANISM_NAME (NCBI/GenBank ASM465v1)" \
  --taxid="$TAXID" \
  --ncbi-dir="$NCBI_DIR" \
  ${CGV_ORYZA_NCBI_LOCAL_ONLY:+--local-only} \
  "${NCBI_DOWNLOAD_FLAG[@]}" \
  ${CGV_ORYZA_NCBI_SKIP_DOWNLOAD:+--skip-download} \
  --download-timeout-sec=14400 2>&1 | tee "$LOG_FILE"

echo
echo "Done."
echo "Alias index:"
echo "  data/alias_index/${SPECIES_ID}.alias_index.tsv.gz"
echo "Metadata:"
echo "  data/alias_index/${SPECIES_ID}.metadata.json"
echo "Log:"
echo "  $LOG_FILE"
