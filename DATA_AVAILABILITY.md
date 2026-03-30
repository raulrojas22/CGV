# Data Availability and Repository Policy

This project includes both application code and large local biological resources. For public release and journal submission, these components should not be handled in the same way.

## Recommended separation

### 1. Source code and configuration

Store in **GitHub**:

- R/Shiny application code
- Docker and deployment files
- helper scripts
- lightweight registries such as `annotations/registry.tsv`, `genomes/registry.tsv`, and `go_annotations/registry.tsv`
- documentation, figures, and manuscript-support files

### 2. Large biological resources

Do **not** store in standard Git history:

- genome sequence files (`.2bit`, `.fa`, `.fna`, `.fasta`)
- compressed annotations (`.gff.gz`, `.gff3.gz`, `.gtf.gz`) and indexes
- GO annotation archives (`.gaf.gz`)
- ontology snapshots and large derived caches
- generated cache artifacts under `cache/`

These files are too large for healthy long-term GitHub repository use and are operational data rather than source code.

## Recommended publication model

### Software

- Keep the canonical development repository in GitHub.
- Create versioned GitHub releases for each public software version.
- Connect the repository to Zenodo and archive releases to obtain a DOI.

### Data

Choose one of these paths depending on journal requirements:

1. **Preferred for this project:** keep production-scale data outside GitHub and document how to obtain or reconstruct it from upstream sources.
2. Archive a **small example dataset** in Zenodo so reviewers and readers can run a lightweight demonstration.
3. If the journal requires a frozen full dataset, deposit the data in Zenodo, Figshare, OSF, or an institutional repository as a separate record from the software.

## What should go to Zenodo

### Definitely

- release snapshots of the software repository
- release metadata used for citation
- optional small demo dataset

### Maybe

- full registries used in the published release
- exact frozen metadata tables used in the manuscript

### Usually not ideal

- the entire live production dataset if it is very large and can be reconstructed from public upstream sources

## Practical guidance for CGV

Given the current project structure:

- `genomes/` is production data and should stay out of GitHub
- `annotations/` is production data and should stay out of GitHub
- `go_annotations/raw/` should stay out of GitHub
- `cache/` should stay out of GitHub
- the small registry files should remain versioned
- the repository should explain where datasets live and how they are mounted into Docker

## What reviewers usually need

For a scientific software release, reviewers generally need:

- access to the source code
- clear installation instructions
- a stable citation target
- enough example data to verify functionality
- an explanation of how full datasets are managed

This means a strong public release often consists of:

1. a clean GitHub repository
2. a Zenodo DOI for the software release
3. a small demo dataset or precise reconstruction instructions
4. a manuscript-ready README and citation metadata

## Suggested statement for manuscript or README

> The CGV source code is distributed through GitHub and archived in Zenodo for versioned citation. Due to size and update frequency, production genome, annotation, and GO resources are maintained outside Git history and mounted at runtime; lightweight registries and reconstruction instructions are provided in the repository.
