# Genome Dictionary

This folder stores local reference genomes (FASTA) used by the app to extract gene sequences by coordinates.

## Files

- `registry.tsv`: mapping between detected organism/taxid and FASTA file.
- `*.fa|*.fasta|*.fna`: genome FASTA files.

## `registry.tsv` format

Columns (tab-separated):

1. `organism`: canonical organism name, e.g. `Oryza sativa`
2. `taxid`: NCBI TaxID (optional but recommended)
3. `fasta`: FASTA filename (relative to this folder) or absolute path
4. `aliases`: optional aliases separated by `|`

Example:

```tsv
organism	taxid	fasta	aliases
Oryza sativa	4530	oryza_sativa.fa	rice|oryza|osativa
Homo sapiens	9606	homo_sapiens.fa	human|hsapiens
```

## Notes

- FASTA from NCBI, Ensembl, or any trusted source is supported.
- Sequence extraction depends on chromosome/contig IDs matching annotation `seqid` values.
- If local dictionary has no match, user can upload a FASTA in the UI for the current session.
