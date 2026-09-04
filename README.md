# CGeV

**CGeV (Comparative Gene Viewer)** is an open-source R/Shiny application for
gene-centered structural comparison and functional context across species. It
combines indexed genome annotations, sequence retrieval, transcript and
cross-species comparison, alignment views, analytical summaries, and
publication-ready export in one web and desktop interface.

[![Web application](https://img.shields.io/badge/Web-cgev.mobilomics.org-0F766E.svg)](https://cgev.mobilomics.org/)
[![Continuous integration](https://github.com/raulrojas22/CGeV/actions/workflows/ci.yml/badge.svg)](https://github.com/raulrojas22/CGeV/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-111827.svg)](LICENSE)
[![R/Shiny](https://img.shields.io/badge/R-Shiny-276DC3.svg)](https://shiny.posit.co/)

## Project status

- **CGeV Web 1.1.0:** available at [cgev.mobilomics.org](https://cgev.mobilomics.org/).
- **CGeV Desktop 1.2.2:** source and reproducible packaging workflows are
  included; public installers are pending release in the
  [download repository](https://github.com/raulrojas22/CGV-Desktop-Releases/releases).

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
docker build -f deploy/docker/Dockerfile.dependencies -t cgv-deps:1.0.0 .
docker compose build
docker compose up -d
```

The dependency image is built separately because it contains the R,
Bioconductor, browser, and native-tool environment shared by deployments.

Open `http://localhost:3838`. Stop the service with:

```bash
docker compose down
```

Production biological resources are intentionally not stored in Git history.
The application expects genome, annotation, GO, data, and cache directories;
their default mounts are defined in `docker-compose.yml`. See
[Data availability](docs/DATA_AVAILABILITY.md) and the reconstruction notes in
[annotations](annotations/README.md), [genomes](genomes/README.md), and
[GO annotations](go_annotations/README.md).

For server deployment details, see [Docker deployment](docs/deployment/DOCKER_DEPLOY.md). For
the packaged application, see [CGeV Desktop](desktop/README.md).

## Repository contents

```text
R/                         Shiny modules and application helpers
annotations/registry.tsv   versioned annotation dataset registry
genomes/registry.tsv       versioned genome dataset registry
go_annotations/            GO registry and reconstruction notes
deploy/                    production and ShinyProxy deployment tooling
www/                       browser assets, styles, and public documents
scripts/                    validation, build, and maintenance scripts
tests/                      automated regression tests
desktop/                    Electron desktop wrapper and packaging
docs/                       deployment, release, and manual sources
Dockerfile                  primary application container
docker-compose.yml          local Docker environment
global.R, ui.R, server.R    Shiny application entry points
```

Large genomes, annotations, generated caches, local environment files,
credentials, logs, and installers are excluded through `.gitignore` and
`.dockerignore`. The repository contains lightweight registries and
reconstruction instructions instead. Deployment-specific files are grouped in
[`deploy/`](deploy/) so the repository root remains focused on the application.

## Reproducibility and testing

- Data policy and provenance: [DATA_AVAILABILITY.md](docs/DATA_AVAILABILITY.md)
- Automated regression tests: `scripts/test_*.R`, `tests/testthat/`, and
  `tests/js/`
- Desktop tests: `npm --prefix desktop test`
- Continuous integration: [GitHub Actions](https://github.com/raulrojas22/CGeV/actions)
- Citation metadata: [CITATION.cff](CITATION.cff)

Network-backed layers such as STRING, Europe PMC, and external alias services
are optional and can change as their upstream databases evolve. Reproducible
analyses should therefore record the fixed local assemblies, resolved gene
models, parameters, and software version used.

## Data and privacy

CGeV processes preloaded or user-supplied genome resources. Private uploads,
runtime caches, exported reports, and local configuration are not committed to
this repository. Desktop analyses remain local unless a user explicitly opens
an external resource. Web deployments may configure external services; consult
the deployment operator's policy before uploading unpublished data.

## Citation

Until an archival software DOI is assigned, cite the repository version or
commit used for the analysis. Machine-readable authorship and repository
metadata are available in [CITATION.cff](CITATION.cff).

## License and contact

CGeV is distributed under the [MIT License](LICENSE).

For reproducibility questions or software issues, use
[GitHub Issues](https://github.com/raulrojas22/CGeV/issues). Software contact:
`cgvviewer@gmail.com`.
