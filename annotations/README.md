# Preloaded Annotations

This folder stores annotation files used by the **Preloaded organism(s)** mode in the app.

## Registry file

The app reads `/Users/rarojas/Desktop/15feb_app/Version_public 2/annotations/registry.tsv`.

Required columns:

- `species_id`: unique stable id
- `label`: display name in the UI
- `organism`: organism/scientific name
- `taxid`: NCBI TaxID (optional)
- `annotation`: path to annotation file (`.gff`, `.gff3`, `.gtf`) used as fallback
- `genome`: path to genome FASTA (optional fallback)
- `aliases`: aliases separated by `|`

Optional optimized columns (used only by **Preloaded mode**):

- `annotation_tabix`: path to bgzipped annotation (`.gff.gz`/`.gff3.gz`/`.gtf.gz`)
- `annotation_index`: path to tabix index (`.tbi`) for `annotation_tabix`
- `genome_2bit`: path to genome `.2bit`
- `icon`: optional icon path for sidebar organism picker (prefer files under `www/icons/`)

If optimized files exist, the app prefers:

1. `annotation_tabix` + `annotation_index` over `annotation`
2. `genome_2bit` over `genome`

Paths can be absolute or relative to the app root.

## Example

```tsv
species_id	label	organism	taxid	annotation	annotation_tabix	annotation_index	genome	genome_2bit	aliases
oryza_sativa_irgsp	Oryza sativa (IRGSP-1.0)	Oryza sativa ssp. japonica	4530	annotations/Oryza_sativa.IRGSP-1.0.62.gff3	annotations/Oryza_sativa.IRGSP-1.0.62.gff3.gz	annotations/Oryza_sativa.IRGSP-1.0.62.gff3.gz.tbi	genomes/Oryza_sativa.IRGSP-1.0.dna.toplevel.fa	genomes/Oryza_sativa.IRGSP-1.0.dna.toplevel.2bit	rice|oryza|osativa
```

## Notes

- A preloaded organism is considered "ready" when its effective annotation file exists.
- If genome is missing (`genome_2bit` and `genome`), the app can still plot structure, but sequence extraction may be unavailable.

## Optional precompute step (recommended)

To avoid first-search latency in preloaded mode, you can prebuild caches:

```bash
Rscript scripts/precompute_preloaded_cache.R --clean
```

This creates persistent cache files in:

- `cache/annotation_index/*.rds`

It also attempts to create `.fai` for FASTA genomes when needed.
