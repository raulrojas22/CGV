#!/usr/bin/env Rscript

source("R/utils.R", local = TRUE)
source("R/server_shared_analysis_domain.R", local = TRUE)
source("R/background_report_jobs.R", local = TRUE)

removed <- cgv_cleanup_shared_reports(base_dir = ".")
packages_removed <- cgv_cleanup_reproducibility_packages(base_dir = ".")
jobs_removed <- cgv_cleanup_background_reports(base_dir = ".")
message(sprintf(
    "[shared-reports] cleanup complete; reports_removed=%d packages_removed=%d jobs_removed=%d",
    as.integer(removed),
    as.integer(packages_removed),
    as.integer(jobs_removed)
))
