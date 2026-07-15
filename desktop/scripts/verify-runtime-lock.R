args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("Usage: verify-runtime-lock.R LOCK_JSON OUTPUT_JSON")

lock_path <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
output_path <- normalizePath(args[[2]], winslash = "/", mustWork = FALSE)
lock <- jsonlite::fromJSON(lock_path, simplifyVector = FALSE)

failures <- character(0)
if (!identical(as.character(getRversion()), as.character(lock$r$version))) {
  failures <- c(failures, sprintf("R expected %s, found %s", lock$r$version, getRversion()))
}

bioc_version <- if (requireNamespace("BiocManager", quietly = TRUE)) {
  as.character(BiocManager::version())
} else {
  "missing"
}
if (!identical(bioc_version, as.character(lock$bioconductorVersion))) {
  failures <- c(failures, sprintf("Bioconductor expected %s, found %s", lock$bioconductorVersion, bioc_version))
}

installed <- installed.packages()
actual_versions <- list()
check_packages <- function(expected, required) {
  for (package_name in names(expected)) {
    actual <- if (package_name %in% rownames(installed)) as.character(installed[package_name, "Version"]) else "missing"
    actual_versions[[package_name]] <<- actual
    if (required && !identical(actual, as.character(expected[[package_name]]))) {
      failures <<- c(failures, sprintf("%s expected %s, found %s", package_name, expected[[package_name]], actual))
    }
    if (!required && actual != "missing" && !identical(actual, as.character(expected[[package_name]]))) {
      failures <<- c(failures, sprintf("optional %s expected %s, found %s", package_name, expected[[package_name]], actual))
    }
  }
}

check_packages(lock$packages$required, TRUE)
check_packages(lock$packages$optional, FALSE)

if (length(failures)) {
  stop("Runtime lock verification failed:\n- ", paste(failures, collapse = "\n- "))
}

manifest <- list(
  schemaVersion = 1L,
  platform = lock$platform,
  generatedAt = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  r = lock$r,
  cranRepository = lock$cranRepository,
  bioconductorVersion = bioc_version,
  bioconductorRepository = lock$bioconductorRepository,
  lastz = lock$lastz,
  mmanWin32 = lock$mmanWin32,
  packages = actual_versions
)
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(manifest, output_path, auto_unbox = TRUE, pretty = TRUE)
cat("runtime-lock-ok", output_path, "\n")
