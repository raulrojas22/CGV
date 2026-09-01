# CGeV

**CGeV (Comparative Gene Viewer)** is an open-source R/Shiny application for
gene-centered structural comparison and functional context across species. It
combines indexed genome annotations, sequence retrieval, transcript and
cross-species comparison, alignment views, analytical summaries, and
publication-ready export in one web and desktop interface.

[![Reviewer package](https://github.com/raulrojas22/CGeV/actions/workflows/reviewer-package.yml/badge.svg)](https://github.com/raulrojas22/CGeV/actions/workflows/reviewer-package.yml)
[![Web application](https://img.shields.io/badge/Web-cgev.mobilomics.org-0F766E.svg)](https://cgev.mobilomics.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-111827.svg)](LICENSE)
[![R/Shiny](https://img.shields.io/badge/R-Shiny-276DC3.svg)](https://shiny.posit.co/)

![CGeV architecture](paper/figure1_panel_A_architecture.svg)

## Try the manuscript examples

The repository includes reviewer-ready inputs and expected outputs for both
case studies reported in the manuscript:

- multi-gene comparison of seven *Oryza sativa* ssp. *japonica* HKT loci;
- cross-species comparison of TP53 across seven vertebrates.

Start with the [reviewer walkthrough](examples/manuscript-cases/README.md).
The cases can be reproduced in the [hosted application](https://cgev.mobilomics.org/)
or in a local/desktop installation.
The package can be checked without installing R or downloading genome files:

```bash
python3 scripts/validate_reviewer_package.py
```

The command validates the case-study schemas, the 14 requested organism/query
pairs, their expected resolved labels, and their references to the versioned
dataset registry. A successful run ends with:

```text
PASS: reviewer package is internally consistent (2 cases, 14 queries, 25 registered datasets).
```

This lightweight check verifies the published test package. The scientific
views themselves are reproduced in CGeV using the fixed assemblies and
settings described in the walkthrough.

## Main capabilities

- identifier-aware gene search using symbols, accessions, and aliases;
- multi-gene transcript comparison within one organism;
- cross-species gene-structure comparison;
- exon-aware translated CDS, CDS, and complete-exon alignment;
- LASTZ blocks and MultiPIP-style conservation views;
- Gene Ontology, STRING, literature, neighborhood, and promoter context;
- strand-aware sequence and table export;
- Figure Studio compositions and read-only interactive reports;
- web deployment and offline desktop packages.

## Run locally with Docker

Requirements: Git, Docker Engine 24+ and Docker Compose v2.

```bash
git clone https://github.com/raulrojas22/CGeV.git
cd CGeV
cp .env.example .env
docker compose build
docker compose up -d
```

Open `http://localhost:3838`. Stop the service with:

```bash
docker compose down
```

Production biological resources are intentionally not stored in Git history.
The application expects genome, annotation, GO, data, and cache directories;
their default mounts are defined in `docker-compose.yml`. See
[Data availability](DATA_AVAILABILITY.md) and the reconstruction notes in
[annotations](annotations/README.md), [genomes](genomes/README.md), and
[GO annotations](go_annotations/README.md).

For server deployment details, see [Docker deployment](DOCKER_DEPLOY.md). For
the packaged application, see [CGeV Desktop](desktop/README.md).

## Repository contents

```text
R/                         Shiny modules and application helpers
annotations/registry.tsv   versioned annotation dataset registry
genomes/registry.tsv       versioned genome dataset registry
go_annotations/            GO registry and reconstruction notes
examples/manuscript-cases/ reviewer inputs and expected outputs
scripts/                    validation, build, and maintenance scripts
tests/                      automated regression tests
desktop/                    Electron desktop wrapper and packaging
global.R, ui.R, server.R    Shiny application entry points
```

Large genomes, annotations, generated caches, local environment files,
credentials, logs, and installers are excluded through `.gitignore` and
`.dockerignore`. The repository contains lightweight registries and
reconstruction instructions instead.

## Reproducibility and testing

- Reviewer package: [examples/manuscript-cases](examples/manuscript-cases/README.md)
- Data policy and provenance: [DATA_AVAILABILITY.md](DATA_AVAILABILITY.md)
- Automated regression tests: `scripts/test_*.R`, `tests/testthat/`, and
  `tests/js/`
- Desktop tests: `npm --prefix desktop test`
- Citation metadata: [CITATION.cff](CITATION.cff)

Network-backed layers such as STRING, Europe PMC, and external alias services
are optional and can change as their upstream databases evolve. The reviewer
cases therefore define acceptance criteria around the fixed local assemblies,
resolved gene models, and reproducibility metadata.

## Data and privacy

CGeV processes preloaded or user-supplied genome resources. Private uploads,
runtime caches, exported reports, and local configuration are not committed to
this repository. Desktop analyses remain local unless a user explicitly opens
an external resource. Web deployments may configure external services; consult
the deployment operator's policy before uploading unpublished data.

## Citation

The manuscript citation and archival DOI will be added when they are assigned.
Until then, cite the repository version or commit used for the analysis. The
machine-readable authorship and repository metadata are in [CITATION.cff](CITATION.cff).

## License and contact

CGeV is distributed under the [MIT License](LICENSE).

For reproducibility questions or software issues, use
[GitHub Issues](https://github.com/raulrojas22/CGeV/issues). Software contact:
`cgvviewer@gmail.com`.
