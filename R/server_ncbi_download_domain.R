# ──────────────────────────────────────────────────────────────────────
# NCBI Organism Search & Download Domain
# Provides functions to search NCBI Datasets API v2, download genome
# packages, post-process files (bgzip/tabix/2bit), and manage a local
# registry of downloaded organisms.
# ──────────────────────────────────────────────────────────────────────

NCBI_DATASETS_BASE <- "https://api.ncbi.nlm.nih.gov/datasets/v2/"

# ── Rate limiter (simple token-bucket) ─────────────────────────────
.ncbi_rate_state <- new.env(parent = emptyenv())
.ncbi_rate_state$last_request_time <- NULL
.ncbi_rate_state$tokens <- 3L

ncbi_rate_wait <- function() {
    api_key <- Sys.getenv("NCBI_API_KEY", "")
    max_per_sec <- if (nzchar(api_key)) 10L else 3L
    now <- proc.time()[["elapsed"]]
    if (is.null(.ncbi_rate_state$last_request_time)) {
        .ncbi_rate_state$last_request_time <- now
        .ncbi_rate_state$tokens <- max_per_sec
    }
    elapsed <- now - .ncbi_rate_state$last_request_time
    .ncbi_rate_state$tokens <- min(
        max_per_sec,
        .ncbi_rate_state$tokens + floor(elapsed * max_per_sec)
    )
    .ncbi_rate_state$last_request_time <- now
    if (.ncbi_rate_state$tokens < 1L) {
        Sys.sleep(1 / max_per_sec)
        .ncbi_rate_state$tokens <- 1L
    }
    .ncbi_rate_state$tokens <- .ncbi_rate_state$tokens - 1L
    invisible(NULL)
}

# ── Build an httr2 request with common NCBI headers ───────────────
ncbi_datasets_request <- function(path, query_params = list()) {
    url <- paste0(NCBI_DATASETS_BASE, path)
    req <- httr2::request(url)
    req <- httr2::req_url_query(req, !!!query_params)
    api_key <- Sys.getenv("NCBI_API_KEY", "")
    if (nzchar(api_key)) {
        req <- httr2::req_headers(req, `api-key` = api_key)
    }
    req <- httr2::req_headers(req, Accept = "application/json")
    req <- httr2::req_user_agent(req, "CGV/1.0 (Comparative Genomics Viewer)")
    req <- httr2::req_timeout(req, 15)
    req <- httr2::req_retry(req, max_tries = 4, max_seconds = 20)
    req
}

# ── Safe JSON fetch (mirrors safe_get_json in gene_search_lib.R) ──
ncbi_safe_get_json <- function(req) {
    ncbi_rate_wait()
    tryCatch({
        resp <- httr2::req_perform(req)
        httr2::resp_body_json(resp)
    }, error = function(e) {
        message("[NCBI Datasets] Request failed: ", conditionMessage(e))
        NULL
    })
}

# ══════════════════════════════════════════════════════════════════════
# 1. Search assemblies
# ══════════════════════════════════════════════════════════════════════

ncbi_search_assemblies <- function(query,
                                   source = "refseq",
                                   has_annotation = TRUE,
                                   assembly_level = NULL,
                                   page_size = 20L) {
    query <- trimws(as.character(query %||% ""))
    if (!nzchar(query)) return(data.frame())

    filters <- list(
        page_size = page_size
    )
    if (!is.null(source) && nzchar(source)) {
        filters$filters.assembly_source <- source
    }
    if (isTRUE(has_annotation)) {
        filters$filters.has_annotation <- "true"
    }
    if (!is.null(assembly_level) && nzchar(assembly_level)) {
        filters$filters.assembly_level <- assembly_level
    }

    path <- paste0("genome/taxon/",
                    utils::URLencode(query, reserved = TRUE),
                    "/dataset_report")
    req <- ncbi_datasets_request(path, filters)
    data <- ncbi_safe_get_json(req)

    if (is.null(data) || is.null(data$reports)) {
        return(data.frame())
    }

    reports <- data$reports
    rows <- lapply(reports, function(r) {
        ai   <- r$assembly_info %||% list()
        stats <- r$assembly_stats %||% list()
        ann  <- r$annotation_info %||% ai$annotation_info %||% list()
        org  <- r$organism %||% ai$organism %||% list()

        data.frame(
            accession       = as.character(r$accession %||% ai$assembly_accession %||% ""),
            organism        = as.character(org$organism_name %||% ""),
            taxid           = as.integer(org$tax_id %||% 0L),
            assembly_name   = as.character(ai$assembly_name %||% ""),
            assembly_level  = as.character(ai$assembly_level %||% ""),
            source_database = as.character(r$source_database %||% source),
            genome_size_bp  = as.numeric(stats$total_sequence_length %||% 0),
            scaffold_n50    = as.numeric(stats$scaffold_n50 %||% 0),
            contig_count    = as.integer(stats$number_of_contigs %||% 0),
            has_annotation  = !is.null(ann$name) || length(ann) > 0,
            submission_date = as.character(ai$release_date %||% ai$submission_date %||% ""),
            stringsAsFactors = FALSE
        )
    })

    result <- do.call(rbind, rows)
    if (is.null(result) || nrow(result) == 0) return(data.frame())

    result$genome_size_mb <- round(result$genome_size_bp / 1e6, 1)
    result <- result[order(-result$scaffold_n50), , drop = FALSE]
    rownames(result) <- NULL
    result
}

# ══════════════════════════════════════════════════════════════════════
# 2. Get detailed assembly info (for preview before download)
# ══════════════════════════════════════════════════════════════════════

ncbi_get_assembly_detail <- function(accession) {
    accession <- trimws(as.character(accession %||% ""))
    if (!nzchar(accession)) return(NULL)

    path <- paste0("genome/accession/",
                    utils::URLencode(accession, reserved = TRUE),
                    "/dataset_report")
    req <- ncbi_datasets_request(path)
    data <- ncbi_safe_get_json(req)

    if (is.null(data) || is.null(data$reports) || length(data$reports) == 0) {
        return(NULL)
    }

    r <- data$reports[[1]]
    ai   <- r$assembly_info %||% list()
    stats <- r$assembly_stats %||% list()
    ann  <- r$annotation_info %||% ai$annotation_info %||% list()
    org  <- r$organism %||% ai$organism %||% list()

    list(
        accession       = as.character(r$accession %||% accession),
        organism        = as.character(org$organism_name %||% ""),
        common_name     = as.character(org$common_name %||% ""),
        taxid           = as.integer(org$tax_id %||% 0L),
        assembly_name   = as.character(ai$assembly_name %||% ""),
        assembly_level  = as.character(ai$assembly_level %||% ""),
        genome_size_bp  = as.numeric(stats$total_sequence_length %||% 0),
        genome_size_mb  = round(as.numeric(stats$total_sequence_length %||% 0) / 1e6, 1),
        scaffold_n50    = as.numeric(stats$scaffold_n50 %||% 0),
        gc_percent      = as.numeric(stats$gc_percent %||% 0),
        has_annotation  = !is.null(ann$name) || length(ann) > 0,
        annotation_name = as.character(ann$name %||% ""),
        submission_date = as.character(ai$release_date %||% ai$submission_date %||% "")
    )
}

# ══════════════════════════════════════════════════════════════════════
# 2b. Check if organism already exists in preloaded registry
# ══════════════════════════════════════════════════════════════════════

ncbi_find_in_preloaded <- function(preloaded_registry, organism_name = NULL,
                                    taxid = NULL, accession = NULL) {
    if (is.null(preloaded_registry) || nrow(preloaded_registry) == 0) {
        return(NULL)
    }
    reg <- preloaded_registry

    # Match by accession (GCF_* in species_id)
    if (!is.null(accession) && nzchar(accession)) {
        acc_pattern <- tolower(gsub("[._]", "", accession))
        sid_clean <- tolower(gsub("[._]", "", as.character(reg$species_id)))
        match_idx <- which(grepl(acc_pattern, sid_clean, fixed = TRUE))
        if (length(match_idx) > 0) {
            return(reg[match_idx[1], , drop = FALSE])
        }
    }

    # Match by taxid
    if (!is.null(taxid) && !is.na(taxid) && taxid > 0) {
        taxid_int <- as.integer(taxid)
        reg_taxids <- suppressWarnings(as.integer(reg$taxid))
        match_idx <- which(reg_taxids == taxid_int)
        if (length(match_idx) > 0) {
            return(reg[match_idx[1], , drop = FALSE])
        }
    }

    # Match by organism name (fuzzy)
    if (!is.null(organism_name) && nzchar(organism_name)) {
        org_lower <- tolower(trimws(organism_name))
        reg_org <- tolower(trimws(as.character(reg$organism)))
        reg_label <- tolower(trimws(as.character(reg$label)))
        reg_aliases <- tolower(as.character(reg$aliases %||% ""))

        # Exact match on organism or label
        match_idx <- which(reg_org == org_lower | reg_label == org_lower)
        if (length(match_idx) > 0) {
            return(reg[match_idx[1], , drop = FALSE])
        }

        # Partial match on aliases
        for (i in seq_len(nrow(reg))) {
            aliases <- unlist(strsplit(reg_aliases[i], "\\|"))
            if (any(aliases == org_lower) || any(grepl(org_lower, aliases, fixed = TRUE))) {
                return(reg[i, , drop = FALSE])
            }
        }
    }

    NULL
}

# ══════════════════════════════════════════════════════════════════════
# 2c. LRU Cache Management
# ══════════════════════════════════════════════════════════════════════

ncbi_cache_max_bytes <- function() {
    max_gb <- as.numeric(Sys.getenv("CGV_NCBI_CACHE_MAX_GB", "5"))
    if (is.na(max_gb) || max_gb <= 0) max_gb <- 5
    max_gb * 1024^3
}

ncbi_cache_dir_size <- function(cache_dir = NULL) {
    if (is.null(cache_dir)) cache_dir <- ncbi_downloads_dir()
    if (!dir.exists(cache_dir)) return(0)
    files <- list.files(cache_dir, recursive = TRUE, full.names = TRUE)
    files <- files[!grepl("registry\\.tsv$", files)]
    sum(file.info(files)$size, na.rm = TRUE)
}

ncbi_touch_access_time <- function(accession) {
    acc_dir <- file.path(ncbi_downloads_dir(), accession)
    touch_file <- file.path(acc_dir, ".last_access")
    if (dir.exists(acc_dir)) {
        writeLines(format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), touch_file)
    }
}

ncbi_cache_evict_lru <- function(needed_bytes = 0) {
    cache_dir <- ncbi_downloads_dir()
    max_bytes <- ncbi_cache_max_bytes()
    current_size <- ncbi_cache_dir_size(cache_dir)

    if (current_size + needed_bytes <= max_bytes) return(invisible(NULL))

    # List all accession directories
    acc_dirs <- list.dirs(cache_dir, recursive = FALSE, full.names = TRUE)
    if (length(acc_dirs) == 0) return(invisible(NULL))

    # Get access times
    access_info <- lapply(acc_dirs, function(d) {
        touch_file <- file.path(d, ".last_access")
        meta_file <- file.path(d, "metadata.json")
        access_time <- if (file.exists(touch_file)) {
            tryCatch(as.POSIXct(readLines(touch_file, n = 1)[1]), error = function(e) file.info(d)$mtime)
        } else if (file.exists(meta_file)) {
            file.info(meta_file)$mtime
        } else {
            file.info(d)$mtime
        }
        dir_files <- list.files(d, recursive = TRUE, full.names = TRUE)
        dir_size <- sum(file.info(dir_files)$size, na.rm = TRUE)
        list(path = d, access_time = access_time, size = dir_size)
    })

    # Sort by access time (oldest first)
    times <- vapply(access_info, function(x) as.numeric(x$access_time), numeric(1))
    access_info <- access_info[order(times)]

    # Evict until we have enough space
    freed <- 0
    for (info in access_info) {
        if (current_size + needed_bytes - freed <= max_bytes) break
        accession_name <- basename(info$path)
        message("[NCBI Cache] Evicting ", accession_name, " (", round(info$size / 1e6, 1), " MB)")
        unlink(info$path, recursive = TRUE)
        freed <- freed + info$size

        # Also remove from registry
        tryCatch({
            reg <- read_ncbi_downloads_registry()
            if (nrow(reg) > 0 && "species_id" %in% names(reg)) {
                reg <- reg[!grepl(accession_name, reg$species_id, fixed = TRUE), , drop = FALSE]
                vroom::vroom_write(reg, ncbi_downloads_registry_path(), delim = "\t")
            }
        }, error = function(e) NULL)
    }

    message("[NCBI Cache] Freed ", round(freed / 1e6, 1), " MB")
    invisible(freed)
}

# ══════════════════════════════════════════════════════════════════════
# 3. Check if already downloaded
# ══════════════════════════════════════════════════════════════════════

ncbi_downloads_dir <- function() {
    d <- Sys.getenv("CGV_NCBI_DOWNLOADS_DIR", "ncbi_downloads")
    if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
    d
}

ncbi_downloads_registry_path <- function() {
    file.path(ncbi_downloads_dir(), "registry.tsv")
}

read_ncbi_downloads_registry <- function() {
    reg_path <- ncbi_downloads_registry_path()
    if (!file.exists(reg_path)) return(data.frame())
    tryCatch(
        vroom::vroom(reg_path, delim = "\t", show_col_types = FALSE,
                     col_types = vroom::cols(.default = "c")),
        error = function(e) data.frame()
    )
}

ncbi_check_already_downloaded <- function(accession) {
    reg <- read_ncbi_downloads_registry()
    if (nrow(reg) == 0 || !"species_id" %in% names(reg)) return(NULL)
    acc_clean <- tolower(trimws(accession))
    match_idx <- which(tolower(reg$species_id) == acc_clean |
                       grepl(acc_clean, tolower(reg$species_id), fixed = TRUE))
    if (length(match_idx) == 0) return(NULL)
    as.list(reg[match_idx[1], , drop = FALSE])
}

# ══════════════════════════════════════════════════════════════════════
# 4. Download genome package from NCBI Datasets
# ══════════════════════════════════════════════════════════════════════

ncbi_download_package <- function(accession, dest_dir = NULL,
                                  include_gff = TRUE,
                                  include_sequence = TRUE,
                                  progress_callback = NULL) {
    accession <- trimws(accession)
    if (!nzchar(accession)) stop("Accession is required")

    if (is.null(dest_dir)) dest_dir <- ncbi_downloads_dir()
    acc_dir <- file.path(dest_dir, accession)
    if (!dir.exists(acc_dir)) dir.create(acc_dir, recursive = TRUE, showWarnings = FALSE)

    emit <- function(pct, msg) {
        if (is.function(progress_callback)) {
            tryCatch(progress_callback(pct, msg), error = function(e) NULL)
        }
    }

    emit(5, "Requesting download from NCBI...")

    include_types <- c()
    if (isTRUE(include_gff))      include_types <- c(include_types, "GENOME_GFF")
    if (isTRUE(include_sequence))  include_types <- c(include_types, "GENOME_FASTA")

    path <- paste0("genome/accession/", utils::URLencode(accession, reserved = TRUE),
                    "/download")
    query_params <- list(
        include_annotation_type = paste(include_types[include_types == "GENOME_GFF"], collapse = ",")
    )
    if (isTRUE(include_sequence)) {
        query_params$include_sequence <- "GENOME_FASTA"
    }

    url <- paste0(NCBI_DATASETS_BASE, path)
    req <- httr2::request(url)
    req <- httr2::req_url_query(req, !!!query_params)
    api_key <- Sys.getenv("NCBI_API_KEY", "")
    if (nzchar(api_key)) req <- httr2::req_headers(req, `api-key` = api_key)
    req <- httr2::req_user_agent(req, "CGV/1.0 (Comparative Genomics Viewer)")
    req <- httr2::req_timeout(req, 600)
    req <- httr2::req_retry(req, max_tries = 3, max_seconds = 30)

    zip_path <- file.path(acc_dir, "ncbi_dataset.zip")

    emit(10, "Downloading genome package...")

    ncbi_rate_wait()
    tryCatch({
        resp <- httr2::req_perform(req, path = zip_path)
    }, error = function(e) {
        unlink(zip_path)
        stop("Download failed: ", conditionMessage(e))
    })

    if (!file.exists(zip_path) || file.size(zip_path) < 100) {
        unlink(zip_path)
        stop("Downloaded file is empty or missing")
    }

    emit(50, "Extracting files...")

    tryCatch({
        utils::unzip(zip_path, exdir = acc_dir, overwrite = TRUE)
    }, error = function(e) {
        stop("Failed to extract ZIP: ", conditionMessage(e))
    })

    unlink(zip_path)

    emit(60, "Locating extracted files...")

    data_dir <- file.path(acc_dir, "ncbi_dataset", "data", accession)
    if (!dir.exists(data_dir)) {
        all_dirs <- list.dirs(acc_dir, recursive = TRUE, full.names = TRUE)
        data_candidates <- grep(accession, all_dirs, value = TRUE, fixed = TRUE)
        if (length(data_candidates) > 0) {
            data_dir <- data_candidates[1]
        }
    }

    found_files <- list(
        gff    = NULL,
        fasta  = NULL,
        report = NULL,
        stats  = NULL
    )

    all_files <- list.files(acc_dir, recursive = TRUE, full.names = TRUE)

    gff_candidates <- grep("\\.(gff|gff3|gtf)(\\.gz)?$", all_files, value = TRUE, ignore.case = TRUE)
    if (length(gff_candidates) > 0) found_files$gff <- gff_candidates[1]

    fasta_candidates <- grep("\\.(fna|fasta|fa)(\\.gz)?$", all_files, value = TRUE, ignore.case = TRUE)
    if (length(fasta_candidates) > 0) found_files$fasta <- fasta_candidates[1]

    report_candidates <- grep("assembly_report\\.txt$", all_files, value = TRUE, ignore.case = TRUE)
    if (length(report_candidates) > 0) found_files$report <- report_candidates[1]

    stats_candidates <- grep("assembly_stats\\.txt$", all_files, value = TRUE, ignore.case = TRUE)
    if (length(stats_candidates) > 0) found_files$stats <- stats_candidates[1]

    final <- list()
    if (!is.null(found_files$gff)) {
        final_gff <- file.path(acc_dir, paste0(accession, "_genomic.gff"))
        if (grepl("\\.gz$", found_files$gff)) {
            final_gff <- paste0(final_gff, ".gz_raw")
            file.copy(found_files$gff, final_gff, overwrite = TRUE)
        } else {
            file.copy(found_files$gff, final_gff, overwrite = TRUE)
        }
        final$gff_raw <- final_gff
    }
    if (!is.null(found_files$fasta)) {
        final_fasta <- file.path(acc_dir, paste0(accession, "_genomic.fna"))
        if (grepl("\\.gz$", found_files$fasta)) {
            final_fasta <- paste0(final_fasta, ".gz")
        }
        file.copy(found_files$fasta, final_fasta, overwrite = TRUE)
        final$fasta_raw <- final_fasta
    }
    if (!is.null(found_files$report)) {
        final_report <- file.path(acc_dir, paste0(accession, "_assembly_report.txt"))
        file.copy(found_files$report, final_report, overwrite = TRUE)
        final$assembly_report <- final_report
    }
    if (!is.null(found_files$stats)) {
        final_stats <- file.path(acc_dir, paste0(accession, "_assembly_stats.txt"))
        file.copy(found_files$stats, final_stats, overwrite = TRUE)
        final$assembly_stats <- final_stats
    }

    ncbi_data_dir <- file.path(acc_dir, "ncbi_dataset")
    if (dir.exists(ncbi_data_dir)) unlink(ncbi_data_dir, recursive = TRUE)
    readme <- file.path(acc_dir, "README.md")
    if (file.exists(readme)) unlink(readme)

    emit(65, "Files extracted successfully")
    final$accession <- accession
    final$acc_dir <- acc_dir
    final
}

# ══════════════════════════════════════════════════════════════════════
# 5. Post-process downloaded files (bgzip, tabix, 2bit)
# ══════════════════════════════════════════════════════════════════════

ncbi_has_samtools <- function() {
    tryCatch({
        res <- system2("samtools", "--version", stdout = TRUE, stderr = TRUE)
        length(res) > 0
    }, error = function(e) FALSE)
}

ncbi_has_bgzip <- function() {
    tryCatch({
        res <- system2("bgzip", "--version", stdout = TRUE, stderr = TRUE)
        TRUE
    }, error = function(e) FALSE)
}

ncbi_postprocess_files <- function(download_result, progress_callback = NULL) {
    emit <- function(pct, msg) {
        if (is.function(progress_callback)) {
            tryCatch(progress_callback(pct, msg), error = function(e) NULL)
        }
    }

    acc_dir <- download_result$acc_dir
    accession <- download_result$accession
    processed <- list(accession = accession, acc_dir = acc_dir)

    use_samtools <- ncbi_has_samtools() || ncbi_has_bgzip()

    # ── Process GFF → bgzip + tabix ──────────────────────────────
    if (!is.null(download_result$gff_raw)) {
        emit(70, "Indexing annotation (bgzip + tabix)...")

        gff_raw <- download_result$gff_raw
        gff_final <- file.path(acc_dir, paste0(accession, "_genomic.gff.gz"))
        tbi_final <- paste0(gff_final, ".tbi")

        is_already_gz <- grepl("\\.gz_raw$|\\.gz$", gff_raw)

        if (use_samtools) {
            if (is_already_gz) {
                plain_gff <- sub("\\.(gz_raw|gz)$", "", gff_raw)
                system2("gunzip", c("-f", "-k", shQuote(gff_raw)), stdout = FALSE, stderr = FALSE)
                if (!file.exists(plain_gff) && file.exists(gff_raw)) {
                    con_in <- gzfile(gff_raw, "rb")
                    con_out <- file(plain_gff, "wb")
                    while (length(chunk <- readBin(con_in, "raw", 1e6)) > 0) writeBin(chunk, con_out)
                    close(con_in)
                    close(con_out)
                }
            } else {
                plain_gff <- gff_raw
            }

            if (file.exists(plain_gff)) {
                sorted_gff <- paste0(plain_gff, ".sorted")
                sort_cmd <- sprintf(
                    "(grep '^#' %s; grep -v '^#' %s | sort -t'\t' -k1,1 -k4,4n) > %s",
                    shQuote(plain_gff), shQuote(plain_gff), shQuote(sorted_gff)
                )
                system(sort_cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
                if (file.exists(sorted_gff) && file.size(sorted_gff) > 0) {
                    file.rename(sorted_gff, plain_gff)
                } else if (file.exists(sorted_gff)) {
                    unlink(sorted_gff)
                }

                system2("bgzip", c("-f", shQuote(plain_gff)), stdout = FALSE, stderr = FALSE)
                bgzipped <- paste0(plain_gff, ".gz")
                if (file.exists(bgzipped)) {
                    file.rename(bgzipped, gff_final)
                }

                system2("tabix", c("-p", "gff", shQuote(gff_final)),
                        stdout = FALSE, stderr = FALSE)
            }
        } else {
            if (is_already_gz) {
                plain_gff <- sub("\\.(gz_raw|gz)$", "", gff_raw)
                tryCatch({
                    con_in <- gzfile(gff_raw, "rb")
                    con_out <- file(plain_gff, "wb")
                    while (length(chunk <- readBin(con_in, "raw", 1e6)) > 0) writeBin(chunk, con_out)
                    close(con_in)
                    close(con_out)
                }, error = function(e) NULL)
            } else {
                plain_gff <- gff_raw
            }

            if (file.exists(plain_gff)) {
                tryCatch({
                    bgz_path <- Rsamtools::bgzip(plain_gff, dest = gff_final, overwrite = TRUE)
                    Rsamtools::indexTabix(gff_final, format = "gff")
                }, error = function(e) {
                    message("[NCBI Post-process] R bgzip/tabix failed: ", conditionMessage(e))
                })
            }
        }

        if (file.exists(gff_final)) {
            processed$annotation_tabix <- gff_final
        }
        if (file.exists(tbi_final)) {
            processed$annotation_index <- tbi_final
        }

        for (tmp in c(download_result$gff_raw, sub("\\.(gz_raw|gz)$", "", download_result$gff_raw))) {
            if (file.exists(tmp) && tmp != gff_final) unlink(tmp, force = TRUE)
        }
    }

    # ── Process FASTA → 2bit ─────────────────────────────────────
    if (!is.null(download_result$fasta_raw)) {
        emit(85, "Converting genome to .2bit format...")

        fasta_raw <- download_result$fasta_raw
        twobit_path <- file.path(acc_dir, paste0(accession, "_genomic.2bit"))

        tryCatch({
            if (grepl("\\.gz$", fasta_raw)) {
                plain_fasta <- sub("\\.gz$", "", fasta_raw)
                con_in <- gzfile(fasta_raw, "rb")
                con_out <- file(plain_fasta, "wb")
                while (length(chunk <- readBin(con_in, "raw", 1e6)) > 0) writeBin(chunk, con_out)
                close(con_in)
                close(con_out)
                fasta_for_import <- plain_fasta
            } else {
                fasta_for_import <- fasta_raw
            }

            seqs <- Biostrings::readDNAStringSet(fasta_for_import)
            rtracklayer::export(seqs, rtracklayer::TwoBitFile(twobit_path))

            if (file.exists(twobit_path) && file.size(twobit_path) > 0) {
                processed$genome_2bit <- twobit_path
            }

            if (exists("plain_fasta") && file.exists(plain_fasta)) unlink(plain_fasta)
            if (file.exists(fasta_raw)) unlink(fasta_raw)
        }, error = function(e) {
            message("[NCBI Post-process] FASTA to 2bit failed: ", conditionMessage(e),
                    ". Keeping raw FASTA.")
            processed$genome_fasta <- fasta_raw
        })
    }

    # ── Copy assembly report & stats ─────────────────────────────
    if (!is.null(download_result$assembly_report)) {
        processed$assembly_report <- download_result$assembly_report
    }
    if (!is.null(download_result$assembly_stats)) {
        processed$assembly_stats <- download_result$assembly_stats
    }

    # ── Write metadata.json ──────────────────────────────────────
    emit(95, "Saving metadata...")
    metadata <- list(
        accession      = accession,
        download_time  = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
        source         = "NCBI Datasets API v2",
        files          = Filter(Negate(is.null), processed[setdiff(names(processed), c("accession", "acc_dir"))])
    )
    meta_path <- file.path(acc_dir, "metadata.json")
    tryCatch(
        writeLines(jsonlite::toJSON(metadata, auto_unbox = TRUE, pretty = TRUE), meta_path),
        error = function(e) NULL
    )

    emit(100, "Post-processing complete!")
    processed
}

# ══════════════════════════════════════════════════════════════════════
# 6. Download GO annotation (optional, non-blocking)
# ══════════════════════════════════════════════════════════════════════

.go_taxid_map <- list(
    "9606"   = "goa_human.gaf.gz",
    "10090"  = "mgi.gaf.gz",
    "10116"  = "rgd.gaf.gz",
    "7955"   = "zfin.gaf.gz",
    "7227"   = "fb.gaf.gz",
    "6239"   = "wb.gaf.gz",
    "4932"   = "sgd.gaf.gz",
    "3702"   = "tair.gaf.gz",
    "4530"   = "gramene_oryza.gaf.gz",
    "4577"   = "gramene_maize.gaf.gz",
    "9031"   = "goa_chicken.gaf.gz",
    "9615"   = "goa_dog.gaf.gz",
    "9913"   = "goa_cow.gaf.gz",
    "9823"   = "goa_pig.gaf.gz",
    "8364"   = "xenbase.gaf.gz"
)

ncbi_download_go <- function(taxid, dest_dir, progress_callback = NULL) {
    taxid_str <- as.character(taxid)
    gaf_name <- .go_taxid_map[[taxid_str]]

    if (is.null(gaf_name)) {
        gaf_name <- paste0("goa_uniprot_all.gaf.gz")
        return(NULL)
    }

    emit <- function(pct, msg) {
        if (is.function(progress_callback)) {
            tryCatch(progress_callback(pct, msg), error = function(e) NULL)
        }
    }

    go_url <- paste0("http://current.geneontology.org/annotations/", gaf_name)
    dest_file <- file.path(dest_dir, paste0("gene_ontology.gaf.gz"))

    emit(0, paste0("Downloading GO annotations (", gaf_name, ")..."))

    tryCatch({
        req <- httr2::request(go_url)
        req <- httr2::req_timeout(req, 120)
        req <- httr2::req_retry(req, max_tries = 2, max_seconds = 10)
        httr2::req_perform(req, path = dest_file)

        if (file.exists(dest_file) && file.size(dest_file) > 100) {
            emit(100, "GO annotations downloaded")
            return(dest_file)
        }
        NULL
    }, error = function(e) {
        message("[NCBI GO] GO download failed: ", conditionMessage(e))
        if (file.exists(dest_file)) unlink(dest_file)
        NULL
    })
}

# ══════════════════════════════════════════════════════════════════════
# 7. Update downloads registry
# ══════════════════════════════════════════════════════════════════════

ncbi_update_downloads_registry <- function(processed, organism_name, taxid) {
    reg_path <- ncbi_downloads_registry_path()
    accession <- processed$accession

    species_id <- tolower(gsub("[^a-z0-9]+", "_",
                               paste(organism_name, accession, sep = "_"),
                               ignore.case = TRUE))
    species_id <- gsub("_+", "_", species_id)
    species_id <- gsub("^_|_$", "", species_id)

    entry <- data.frame(
        species_id       = species_id,
        label            = organism_name,
        organism         = organism_name,
        taxid            = as.character(taxid),
        annotation       = as.character(processed$annotation_tabix %||% ""),
        annotation_tabix = as.character(processed$annotation_tabix %||% ""),
        annotation_index = as.character(processed$annotation_index %||% ""),
        genome           = as.character(processed$genome_fasta %||% ""),
        genome_2bit      = as.character(processed$genome_2bit %||% ""),
        aliases          = tolower(gsub("\\s+", " ", organism_name)),
        icon             = "",
        kingdom          = "",
        accession        = accession,
        source           = "ncbi_download",
        stringsAsFactors = FALSE
    )

    if (file.exists(reg_path)) {
        existing <- tryCatch(
            vroom::vroom(reg_path, delim = "\t", show_col_types = FALSE,
                         col_types = vroom::cols(.default = "c")),
            error = function(e) data.frame()
        )
        if (nrow(existing) > 0 && "species_id" %in% names(existing)) {
            existing <- existing[existing$species_id != species_id, , drop = FALSE]
        }
        combined <- dplyr::bind_rows(existing, entry)
    } else {
        combined <- entry
    }

    vroom::vroom_write(combined, reg_path, delim = "\t")
    invisible(entry)
}

# ══════════════════════════════════════════════════════════════════════
# 8. Full pipeline: search → download → process → register
# ══════════════════════════════════════════════════════════════════════

ncbi_full_download_pipeline <- function(accession, organism_name = NULL, taxid = NULL,
                                        progress_callback = NULL) {
    emit <- function(pct, msg) {
        if (is.function(progress_callback)) {
            tryCatch(progress_callback(pct, msg), error = function(e) NULL)
        }
    }

    existing <- ncbi_check_already_downloaded(accession)
    if (!is.null(existing)) {
        ncbi_touch_access_time(accession)
        emit(100, "Organism already in cache. Loading...")
        return(existing)
    }

    if (is.null(organism_name) || is.null(taxid)) {
        detail <- ncbi_get_assembly_detail(accession)
        if (is.null(detail)) stop("Could not retrieve assembly details from NCBI")
        if (is.null(organism_name)) organism_name <- detail$organism
        if (is.null(taxid))        taxid <- detail$taxid
    }

    # Evict old cache entries if needed (estimate ~500MB per organism)
    emit(3, "Checking cache space...")
    tryCatch(ncbi_cache_evict_lru(needed_bytes = 500 * 1024^2), error = function(e) NULL)

    download_result <- ncbi_download_package(accession, progress_callback = progress_callback)

    processed <- ncbi_postprocess_files(download_result, progress_callback = progress_callback)

    go_path <- tryCatch(
        ncbi_download_go(taxid, download_result$acc_dir, progress_callback = progress_callback),
        error = function(e) NULL
    )
    if (!is.null(go_path)) processed$go_annotation <- go_path

    entry <- ncbi_update_downloads_registry(processed, organism_name, taxid)

    result <- as.list(entry)
    result$acc_dir <- download_result$acc_dir
    result$go_annotation <- go_path
    result
}
