test_that("NCBI cache lookup matches accession punctuation variants", {
    skip_if_not(exists("ncbi_check_already_downloaded", mode = "function"))

    tmp <- tempfile("ncbi-cache-")
    dir.create(tmp, recursive = TRUE)
    old <- Sys.getenv("CGV_NCBI_DOWNLOADS_DIR", unset = NA_character_)
    on.exit({
        if (is.na(old)) Sys.unsetenv("CGV_NCBI_DOWNLOADS_DIR") else Sys.setenv(CGV_NCBI_DOWNLOADS_DIR = old)
        unlink(tmp, recursive = TRUE, force = TRUE)
    }, add = TRUE)
    Sys.setenv(CGV_NCBI_DOWNLOADS_DIR = tmp)

    acc_dir <- file.path(tmp, "GCF_030788295.1")
    dir.create(acc_dir, recursive = TRUE)
    ann <- file.path(acc_dir, "GCF_030788295.1_genomic.gff.gz")
    two_bit <- file.path(acc_dir, "GCF_030788295.1_genomic.2bit")
    file.create(ann)
    file.create(two_bit)

    reg <- data.frame(
        species_id = "drosophila_virilis_gcf_030788295_1",
        label = "Drosophila virilis",
        organism = "Drosophila virilis",
        taxid = "7244",
        annotation = ann,
        annotation_tabix = ann,
        annotation_index = "",
        genome = "",
        genome_2bit = two_bit,
        aliases = "drosophila virilis",
        icon = "",
        kingdom = "",
        accession = "GCF_030788295.1",
        source = "ncbi_download",
        stringsAsFactors = FALSE
    )
    ncbi_atomic_write_tsv(reg, file.path(tmp, "registry.tsv"))

    hit <- ncbi_check_already_downloaded("GCF_030788295.1")
    expect_false(is.null(hit))
    expect_identical(as.character(hit$accession), "GCF_030788295.1")

    hit_by_species_id <- ncbi_check_already_downloaded("GCF_030788295_1")
    expect_false(is.null(hit_by_species_id))
    expect_identical(as.character(hit_by_species_id$organism), "Drosophila virilis")
})

test_that("NCBI cache validation rejects incomplete entries", {
    skip_if_not(exists("ncbi_validate_cache_entry", mode = "function"))
    tmp <- tempfile("ncbi-cache-broken-")
    dir.create(tmp, recursive = TRUE)
    on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)

    ann <- file.path(tmp, "ok.gff.gz")
    file.create(ann)
    entry <- list(annotation_tabix = ann, genome_2bit = file.path(tmp, "missing.2bit"))
    validation <- ncbi_validate_cache_entry(entry)
    expect_false(isTRUE(validation$ok))
    expect_match(validation$reason, "genome 2bit")
})

test_that("NCBI LRU eviction only removes ncbi_download registry rows", {
    skip_if_not(exists("ncbi_cache_evict_lru", mode = "function"))

    tmp <- tempfile("ncbi-cache-lru-")
    dir.create(tmp, recursive = TRUE)
    old_dir <- Sys.getenv("CGV_NCBI_DOWNLOADS_DIR", unset = NA_character_)
    old_max <- Sys.getenv("CGV_NCBI_CACHE_MAX_GB", unset = NA_character_)
    on.exit({
        if (is.na(old_dir)) Sys.unsetenv("CGV_NCBI_DOWNLOADS_DIR") else Sys.setenv(CGV_NCBI_DOWNLOADS_DIR = old_dir)
        if (is.na(old_max)) Sys.unsetenv("CGV_NCBI_CACHE_MAX_GB") else Sys.setenv(CGV_NCBI_CACHE_MAX_GB = old_max)
        unlink(tmp, recursive = TRUE, force = TRUE)
    }, add = TRUE)
    Sys.setenv(CGV_NCBI_DOWNLOADS_DIR = tmp, CGV_NCBI_CACHE_MAX_GB = "0.000001")

    ncbi_dir <- file.path(tmp, "GCF_111111111.1")
    keep_dir <- file.path(tmp, "KEEP_222222222.1")
    dir.create(ncbi_dir, recursive = TRUE)
    dir.create(keep_dir, recursive = TRUE)
    writeLines(strrep("x", 2048), file.path(ncbi_dir, "payload.txt"))
    writeLines(strrep("y", 2048), file.path(keep_dir, "payload.txt"))

    reg <- data.frame(
        species_id = c("test_gcf_111111111_1", "manual_keep_222222222_1"),
        label = c("Test", "Manual"),
        organism = c("Test", "Manual"),
        taxid = c("1", "2"),
        annotation = "",
        annotation_tabix = "",
        annotation_index = "",
        genome = "",
        genome_2bit = "",
        aliases = "",
        icon = "",
        kingdom = "",
        accession = c("GCF_111111111.1", "KEEP_222222222.1"),
        source = c("ncbi_download", "manual"),
        stringsAsFactors = FALSE
    )
    ncbi_atomic_write_tsv(reg, file.path(tmp, "registry.tsv"))

    ncbi_cache_evict_lru(needed_bytes = 0)
    expect_false(dir.exists(ncbi_dir))
    expect_true(dir.exists(keep_dir))
    reg_after <- read_ncbi_downloads_registry()
    expect_true("manual" %in% as.character(reg_after$source))
    expect_false("ncbi_download" %in% as.character(reg_after$source))
})

test_that("NCBI usage log records anonymous loads and builds a summary", {
    skip_if_not(exists("ncbi_record_usage_event", mode = "function"))

    tmp <- tempfile("ncbi-usage-")
    dir.create(tmp, recursive = TRUE)
    old_dir <- Sys.getenv("CGV_NCBI_DOWNLOADS_DIR", unset = NA_character_)
    old_enabled <- Sys.getenv("CGV_NCBI_USAGE_LOG_ENABLED", unset = NA_character_)
    on.exit({
        if (is.na(old_dir)) Sys.unsetenv("CGV_NCBI_DOWNLOADS_DIR") else Sys.setenv(CGV_NCBI_DOWNLOADS_DIR = old_dir)
        if (is.na(old_enabled)) Sys.unsetenv("CGV_NCBI_USAGE_LOG_ENABLED") else Sys.setenv(CGV_NCBI_USAGE_LOG_ENABLED = old_enabled)
        unlink(tmp, recursive = TRUE, force = TRUE)
    }, add = TRUE)
    Sys.setenv(
        CGV_NCBI_DOWNLOADS_DIR = tmp,
        CGV_NCBI_USAGE_LOG_ENABLED = "true"
    )

    expect_true(ncbi_record_usage_event(
        "GCF_030788295.1", "Drosophila virilis", "7244",
        event = "download_complete", context = "shared_cache", cache_hit = FALSE
    ))
    expect_true(ncbi_record_usage_event(
        "GCF_030788295.1", "Drosophila virilis", "7244",
        event = "organism_loaded", context = "single_species", cache_hit = FALSE,
        session_token = "private-session-token"
    ))
    expect_true(ncbi_record_usage_event(
        "GCF_030788295.1", "Drosophila virilis", "7244",
        event = "organism_loaded", context = "cross_species", cache_hit = TRUE,
        session_token = "second-private-session"
    ))

    log_text <- paste(readLines(ncbi_usage_log_path()), collapse = "\n")
    expect_false(grepl("private-session-token", log_text, fixed = TRUE))

    summary <- ncbi_build_usage_summary(write_file = TRUE)
    expect_equal(nrow(summary), 1L)
    expect_equal(summary$total_loads[[1]], 2L)
    expect_equal(summary$unique_sessions[[1]], 2L)
    expect_equal(summary$downloads[[1]], 1L)
    expect_equal(summary$cache_loads[[1]], 1L)
    expect_equal(summary$single_species_loads[[1]], 1L)
    expect_equal(summary$cross_species_loads[[1]], 1L)
    expect_true(file.exists(ncbi_usage_summary_path()))
})
