# Data availability and reconstruction

CGeV separates versioned source code and metadata from production-scale
biological data. This keeps the Git repository reviewable while preserving the
assembly accessions and reconstruction information needed to reproduce an
analysis.

## Data included in this repository

The repository versions:

- application source, tests, and deployment configuration;
- `annotations/registry.tsv`, containing the 25 reference datasets used by the
  application;
- `genomes/registry.tsv` and `go_annotations/registry.tsv`;
- scripts used to build indexes, registries, and caches;
- reviewer inputs and expected outputs in `examples/manuscript-cases/`.

The reviewer package covers the HKT and TP53 examples reported in the
manuscript. Validate its integrity with:

```bash
python3 scripts/validate_reviewer_package.py
```

See the [reviewer walkthrough](examples/manuscript-cases/README.md) for the
fixed assembly accessions, input queries, settings, and acceptance criteria.

## Data maintained outside Git history

The following production assets are not committed because of their size and
update frequency:

- genome sequence files (`.2bit`, `.fa`, `.fna`, `.fasta`);
- bgzip-compressed annotations and Tabix indexes (`.gff.gz`, `.gff3.gz`,
  `.gtf.gz`, `.tbi`);
- GO annotation archives and generated ontology indexes;
- generated caches, logs, reports, uploads, and local configuration;
- desktop installers and packaged runtimes.

These assets are obtained from the public upstream providers identified by the
accessions in the registries and are mounted or installed at runtime. Dataset
packages used by CGeV Desktop are verified by checksum.

## Reconstruction

1. Choose an entry from `annotations/registry.tsv`.
2. Obtain the exact assembly and matching annotation release from its upstream
   provider, normally NCBI RefSeq/GenBank or Ensembl.
3. Follow [annotation reconstruction](annotations/README.md) to bgzip and index
   the annotation.
4. Follow [genome reconstruction](genomes/README.md) to prepare the matching
   2bit genome.
5. Place the assets at the registry paths or set the corresponding Docker
   volume variables from `.env.example`.
6. Record the CGeV version/commit, assembly accession, query, transcript,
   orientation, window, alignment threshold, and optional external-service
   results in the exported reproducibility package.

Network-backed results from STRING, Europe PMC, MyGene.info, NCBI Gene,
UniProt, or Ensembl may change independently of a CGeV release. The structural
reviewer cases therefore use the fixed local assembly and annotation references
as their reproducible core.

## Archival policy

Each public software release should be tagged in GitHub and archived in Zenodo
for an immutable software DOI. A frozen dataset snapshot, when required by a
journal or funder, should be deposited as a separate data record rather than
added to Git history. The repository's `CITATION.cff` and `.zenodo.json` contain
the current software metadata.
