cran_repository <- trimws(Sys.getenv("CGV_CRAN_REPOSITORY", "https://cloud.r-project.org"))
options(repos = c(CRAN = cran_repository))

package_type <- trimws(Sys.getenv("CGV_R_PACKAGE_TYPE", ""))
if (nzchar(package_type)) options(pkgType = package_type)

bioconductor_version <- trimws(Sys.getenv("CGV_BIOCONDUCTOR_VERSION", ""))

cran_packages <- c(
  "shiny",
  "bslib",
  "shinyjs",
  "shinycssloaders",
  "shinyWidgets",
  "dplyr",
  "tidyr",
  "purrr",
  "stringr",
  "ggiraph",
  "ggplot2",
  "ggrepel",
  "patchwork",
  "scales",
  "vroom",
  "future",
  "promises",
  "httr2",
  "furrr",
  "rbioapi",
  "visNetwork",
  "jsonlite",
  "later",
  "htmltools",
  "DT",
  "sass",
  "data.table",
  "processx",
  "chromote",
  "digest",
  "DBI",
  "RSQLite"
)

bioc_packages <- c(
  "Biostrings",
  "Rsamtools",
  "GenomicRanges",
  "IRanges",
  "GenomeInfoDb",
  "rtracklayer",
  "biomaRt"
)

optional_bioc_packages <- c("pwalign")

recommended_ncpus <- function() {
  cores <- suppressWarnings(as.integer(parallel::detectCores(logical = TRUE)))
  if (length(cores) == 0L || is.na(cores) || cores < 2L) {
    return(1L)
  }
  cores - 1L
}

install_missing_cran <- function(pkgs, max_attempts = 3L) {
  remaining <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (!length(remaining)) {
    message("CRAN packages already installed.")
    return(invisible(TRUE))
  }

  for (attempt in seq_len(max_attempts)) {
    message(sprintf("Installing CRAN packages (attempt %d/%d): %s", attempt, max_attempts, paste(remaining, collapse = ", ")))
    try(install.packages(remaining, Ncpus = recommended_ncpus()), silent = FALSE)
    remaining <- remaining[!vapply(remaining, requireNamespace, logical(1), quietly = TRUE)]
    if (!length(remaining)) {
      message("CRAN package install completed.")
      return(invisible(TRUE))
    }
  }

  stop(sprintf("Unable to install CRAN packages: %s", paste(remaining, collapse = ", ")))
}

install_missing_bioc <- function(pkgs, max_attempts = 3L, strict = TRUE) {
  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager", Ncpus = recommended_ncpus())
  }

  if (nzchar(bioconductor_version) && !identical(as.character(BiocManager::version()), bioconductor_version)) {
    BiocManager::install(version = bioconductor_version, ask = FALSE, update = FALSE)
  }

  remaining <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (!length(remaining)) {
    message("Bioconductor packages already installed.")
    return(invisible(TRUE))
  }

  for (attempt in seq_len(max_attempts)) {
    message(sprintf("Installing Bioconductor packages (attempt %d/%d): %s", attempt, max_attempts, paste(remaining, collapse = ", ")))
    try(BiocManager::install(remaining, ask = FALSE, update = FALSE), silent = FALSE)
    remaining <- remaining[!vapply(remaining, requireNamespace, logical(1), quietly = TRUE)]
    if (!length(remaining)) {
      message("Bioconductor package install completed.")
      return(invisible(TRUE))
    }
  }

  if (strict) {
    stop(sprintf("Unable to install Bioconductor packages: %s", paste(remaining, collapse = ", ")))
  }
  message(sprintf("Optional Bioconductor packages not installed: %s", paste(remaining, collapse = ", ")))
  invisible(FALSE)
}

install_missing_cran(cran_packages)
install_missing_bioc(bioc_packages)
install_missing_bioc(optional_bioc_packages, strict = FALSE)

all_required <- unique(c(cran_packages, bioc_packages))
missing_final <- all_required[!vapply(all_required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_final)) {
  stop(sprintf("Required packages still missing: %s", paste(missing_final, collapse = ", ")))
}

missing_optional <- optional_bioc_packages[!vapply(optional_bioc_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_optional)) {
  message(sprintf("Optional Bioconductor packages not available: %s", paste(missing_optional, collapse = ", ")))
}

message("R dependencies installed successfully.")
