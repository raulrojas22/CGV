# CGV v1.0.0

First public research release of **CGV (Comparative Gene Viewer)**.

## Highlights

- public GitHub repository prepared for scientific dissemination
- curated `README`, `LICENSE`, `CITATION.cff`, and `.zenodo.json`
- repository cleaned to keep **code and lightweight registries** in Git
- large production datasets excluded from Git history
- Docker-based deployment workflow documented for reproducible setup

## Included in this release

- R/Shiny application source code
- deployment files (`Dockerfile`, `docker-compose.yml`, `deploy/docker-compose.deploy.yml`)
- data registries and dataset documentation
- paper-support material and architecture figure
- helper scripts for cache generation, registry building, benchmarking, and diagnostics

## Data policy

This release does **not** bundle production-scale genomes, compressed annotations, GO archives, or generated caches in Git history. Those resources are expected to be mounted externally at runtime, as described in `README.md` and `docs/DATA_AVAILABILITY.md`.

## Recommended citation

Please cite the software metadata in `CITATION.cff` and the corresponding Zenodo DOI once the archival record is generated.

## Web deployment

- Public application: <https://cgev.mobilomics.org>
- Source code: <https://github.com/raulrojas22/CGV>
