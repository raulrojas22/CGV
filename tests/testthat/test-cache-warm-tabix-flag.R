library(testthat)

cache_warm_path <- file.path("R", "server_cache_warm.R")
if (!file.exists(cache_warm_path)) {
    cache_warm_path <- file.path("..", "..", "R", "server_cache_warm.R")
}

test_that("annotation Tabix warm-up is opt-in across fallback paths", {
    old_value <- Sys.getenv("APP_TABIX_PROBE_ON_WARM", unset = NA_character_)
    on.exit({
        if (is.na(old_value)) {
            Sys.unsetenv("APP_TABIX_PROBE_ON_WARM")
        } else {
            Sys.setenv(APP_TABIX_PROBE_ON_WARM = old_value)
        }
    }, add = TRUE)

    domain_env <- new.env(parent = globalenv())
    domain_env$`%||%` <- function(x, y) {
        if (is.null(x) || length(x) == 0L) y else x
    }
    domain_env$probe_calls <- 0L
    domain_env$is_tabix_annotation_file <- function(path) TRUE
    domain_env$scan_tabix_region_gff <- function(...) {
        domain_env$probe_calls <- domain_env$probe_calls + 1L
        data.frame()
    }
    sys.source(cache_warm_path, envir = domain_env)

    annotation_path <- tempfile(fileext = ".gff3.gz")
    expect_true(file.create(annotation_path))
    on.exit(unlink(annotation_path), add = TRUE)
    idx <- list(genes_df = data.frame(seqid = "chr1", start = 10, end = 20))
    cache_domain <- domain_env$init_cache_warm_domain()

    Sys.setenv(APP_TABIX_PROBE_ON_WARM = "0")
    expect_false(cache_domain$warm_annotation_tabix_probe(annotation_path, idx))
    expect_identical(domain_env$probe_calls, 0L)

    Sys.setenv(APP_TABIX_PROBE_ON_WARM = "1")
    expect_true(cache_domain$warm_annotation_tabix_probe(annotation_path, idx))
    expect_identical(domain_env$probe_calls, 1L)
})
