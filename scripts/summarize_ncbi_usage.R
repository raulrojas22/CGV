#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
cache_dir <- if (length(args) >= 1L) args[[1]] else Sys.getenv(
    "CGV_NCBI_DOWNLOADS_DIR", "ncbi_downloads"
)
Sys.setenv(CGV_NCBI_DOWNLOADS_DIR = cache_dir)

if (!exists("%||%", mode = "function")) {
    `%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
}

domain_path <- file.path("R", "server_ncbi_download_domain.R")
if (!file.exists(domain_path)) {
    stop("Run this script from the application root directory.")
}
sys.source(domain_path, envir = globalenv())

summary <- ncbi_build_usage_summary(write_file = TRUE)
cat("NCBI usage summary written to:", ncbi_usage_summary_path(), "\n")
cat("Organisms:", nrow(summary), "\n")
if (nrow(summary) > 0L) {
    print(utils::head(summary, 20L), row.names = FALSE)
}
