# CGeV manuscript case studies

This directory contains the reviewer package for the two examples described in
the CGeV application note. It records the exact input queries, fixed reference
assemblies, relevant settings, and the gene labels expected after local
resolution. It does not duplicate the production genome and annotation files.

## Package contents

| File | Purpose |
| --- | --- |
| `inputs/queries.tsv` | One row per organism/query pair used in the paper |
| `expected/resolved_genes.tsv` | Expected local gene-model resolution |
| `expected/acceptance_criteria.md` | Views and checks expected for each case |
| `checksums.sha256` | SHA-256 checksums for the test inputs and expectations |

## Quick integrity test

From the repository root, run:

```bash
python3 scripts/validate_reviewer_package.py
```

To save the validation output for a review record:

```bash
mkdir -p reviewer-results
python3 scripts/validate_reviewer_package.py \
  | tee reviewer-results/package-validation.txt
```

`reviewer-results/` is intentionally ignored by Git so a local run does not
modify the source tree.

## Case 1: multi-gene HKT comparison

1. Open CGeV and select **Multi-Gene Search**.
2. Select **Oryza sativa ssp. japonica** and assembly
   `GCF_034140825.1`.
3. Enter these queries, one per line:

```text
HKT1;1
HKT1;3
HKT1;4
HKT1;5
HKT2;1
HKT2;3
HKT2;4
```

4. Run the search and use a common 5'-to-3' orientation.
5. Open **Gene Architecture** and **Nucleotide Composition**.
6. Compare the resolved labels with `expected/resolved_genes.tsv` and apply
   the checks in `expected/acceptance_criteria.md`.
7. Export the gene table and one SVG or PNG figure into
   `reviewer-results/hkt/`.

The query `HKT1;5` is expected to resolve to the locally annotated gene model
`LOC4327757`; this documents identifier resolution rather than silently
renaming the source annotation.

## Case 2: cross-species TP53 comparison

1. Open **Cross-Species Gene Search**.
2. Select the seven organisms listed for case `tp53_cross_species` in
   `inputs/queries.tsv`.
3. Search for `TP53` in each selected organism.
4. Display models in a common 5'-to-3' orientation.
5. Run **LASTZ Blocks** and **MultiPIP** using *Homo sapiens* as the reference,
   no added flanking sequence, and a minimum local identity of 50%.
6. Compare the resolved labels with `expected/resolved_genes.tsv` and apply
   the checks in `expected/acceptance_criteria.md`.
7. Export the resolved gene table and alignment figures into
   `reviewer-results/tp53/`.

Exact alignment blocks can vary if a reviewer changes transcript choice,
window size, identity threshold, or upstream data. CGeV records these settings
in its reproducibility export; comparisons are meaningful only when those
parameters and assembly accessions match.

## Recommended delivered output

For each case, retain:

- exported resolved-gene CSV;
- exported SVG or PNG panels;
- CGeV reproducibility ZIP or self-contained desktop report;
- `package-validation.txt` from the integrity test above.

These generated artifacts are evidence of a run and are not source files, so
they belong under the ignored `reviewer-results/` directory or in a release
archive/DOI deposit.

## Data provenance

The assembly accessions are fixed in `inputs/queries.tsv` and must also exist in
`annotations/registry.tsv`. Full sequence and annotation assets are maintained
outside Git because of their size. Reconstruction and provenance instructions
are provided in [Data availability](../../DATA_AVAILABILITY.md),
[annotations](../../annotations/README.md), and [genomes](../../genomes/README.md).
