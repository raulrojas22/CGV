test_that("reproducibility packages stage beside their final destination", {
  domain_path <- file.path("R", "server_shared_analysis_domain.R")
  if (!file.exists(domain_path)) {
    domain_path <- file.path("..", "..", "R", "server_shared_analysis_domain.R")
  }
  expect_true(file.exists(domain_path))

  domain_env <- new.env(parent = globalenv())
  sys.source(domain_path, envir = domain_env)

  package_root <- tempfile("cgv-package-root-")
  dir.create(package_root, recursive = TRUE)
  on.exit(unlink(package_root, recursive = TRUE, force = TRUE), add = TRUE)

  staging_path <- domain_env$cgv_reproducibility_staging_path(package_root)

  expect_identical(
    normalizePath(dirname(staging_path), winslash = "/", mustWork = FALSE),
    normalizePath(package_root, winslash = "/", mustWork = TRUE)
  )
  expect_match(basename(staging_path), "^\\.cgv-reproducibility-.*\\.zip$")
})
