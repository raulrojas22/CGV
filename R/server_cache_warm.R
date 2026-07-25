init_cache_warm_domain <- function(append_status_fn = NULL) {
    warmed_annotation_keys <- new.env(parent = emptyenv(), hash = TRUE)
    warmed_genome_keys <- new.env(parent = emptyenv(), hash = TRUE)

    append_status_safe <- function(status_rv, msg) {
        if (is.function(append_status_fn) && !is.null(status_rv)) {
            tryCatch(append_status_fn(status_rv, msg), error = function(e) NULL)
        }
        invisible(NULL)
    }

    normalize_annotation_key <- function(annotation_path) {
        p <- as.character(annotation_path %||% "")
        if (!nzchar(p)) {
            return("")
        }
        normalizePath(p, winslash = "/", mustWork = FALSE)
    }

    annotation_is_warmed <- function(annotation_path) {
        key <- normalize_annotation_key(annotation_path)
        if (!nzchar(key)) {
            return(FALSE)
        }
        if (exists(key, envir = warmed_annotation_keys, inherits = FALSE)) {
            return(TRUE)
        }
        cached_idx <- tryCatch(
            {
                if (exists("cache_env_get", mode = "function") &&
                    exists("gff_cache_key", mode = "function") &&
                    exists(".gff_gene_light_index_cache", inherits = TRUE)) {
                    cache_env_get(.gff_gene_light_index_cache, gff_cache_key(key), default = NULL)
                } else {
                    NULL
                }
            },
            error = function(e) NULL
        )
        if (!is.null(cached_idx) && is.list(cached_idx) && !is.null(cached_idx$genes_df)) {
            mark_annotation_warmed(key)
            return(TRUE)
        }
        FALSE
    }

    mark_annotation_warmed <- function(annotation_path) {
        key <- normalize_annotation_key(annotation_path)
        if (!nzchar(key)) {
            return(invisible(FALSE))
        }
        assign(key, TRUE, envir = warmed_annotation_keys)
        invisible(TRUE)
    }

    warm_annotation_tabix_probe <- function(annotation_path, idx = NULL) {
        p <- as.character(annotation_path %||% "")
        if (!nzchar(p) || !file.exists(p) ||
            !exists("is_tabix_annotation_file", mode = "function") ||
            !isTRUE(is_tabix_annotation_file(p))) {
            return(invisible(FALSE))
        }
        idx_obj <- idx
        if (is.null(idx_obj) || !is.list(idx_obj) || is.null(idx_obj$genes_df)) {
            idx_obj <- tryCatch(load_gff_gene_light_index_if_available(p, base_dir = "."), error = function(e) NULL)
        }
        genes_df <- idx_obj$genes_df %||% NULL
        if (is.null(genes_df) || !is.data.frame(genes_df) || nrow(genes_df) == 0L) {
            return(invisible(FALSE))
        }
        chr_col <- if ("seqid" %in% colnames(genes_df)) "seqid" else "V1"
        start_col <- if ("start" %in% colnames(genes_df)) "start" else "V4"
        end_col <- if ("end" %in% colnames(genes_df)) "end" else "V5"
        chr <- as.character(genes_df[[chr_col]][1] %||% "")
        st <- suppressWarnings(as.numeric(genes_df[[start_col]][1] %||% NA_real_))
        en <- suppressWarnings(as.numeric(genes_df[[end_col]][1] %||% NA_real_))
        if (!nzchar(chr) || !is.finite(st) || !is.finite(en)) {
            return(invisible(FALSE))
        }
        tryCatch(scan_tabix_region_gff(p, chr, st, en), error = function(e) NULL)
        invisible(TRUE)
    }

    warm_annotation_cache <- function(annotation_path, status_rv = NULL, context_label = NULL) {
        p <- as.character(annotation_path %||% "")
        if (!nzchar(p) || !file.exists(p) || annotation_is_warmed(p)) {
            return(invisible(FALSE))
        }
        disk_idx <- tryCatch(
            load_gff_index_from_disk(p, cache_kind = "gene_light", base_dir = "."),
            error = function(e) NULL
        )
        if (!is.null(disk_idx) && is.list(disk_idx) && !is.null(disk_idx$genes_df)) {
            tryCatch(
                {
                    cache_env_set(
                        .gff_gene_light_index_cache,
                        gff_cache_key(p),
                        disk_idx,
                        max_size = annotation_memory_cache_limits$gene_light_max_entries,
                        max_bytes = annotation_memory_cache_limits$gene_light_max_bytes
                    )
                },
                error = function(e) NULL
            )
            mark_annotation_warmed(p)
            return(invisible(TRUE))
        }
        warmed_ok <- FALSE
        elapsed <- system.time({
            idx <- tryCatch(build_gff_gene_light_index(p), error = function(e) NULL)
            if (!is.null(idx) && is.list(idx) && !is.null(idx$genes_df)) {
                tryCatch(
                    save_gff_index_to_disk(p, idx, cache_kind = "gene_light", base_dir = "."),
                    error = function(e) FALSE
                )
                genes_tbl <- tryCatch(
                    get_genes_table_from_annotation(p),
                    error = function(e) NULL
                )
                if (is.data.frame(genes_tbl)) {
                    tryCatch(
                        get_genes_chr_index_from_annotation(p, genes_df = genes_tbl),
                        error = function(e) NULL
                    )
                    warmed_ok <- TRUE
                } else {
                    warmed_ok <- TRUE
                }
                tryCatch(
                    get_chromosome_name_map(p),
                    error = function(e) NULL
                )
                warm_annotation_tabix_probe(p, idx)
            }
            if (isTRUE(warmed_ok)) {
                mark_annotation_warmed(p)
            }
        })
        if (!is.null(status_rv) && annotation_is_warmed(p)) {
            lbl <- as.character(context_label %||% basename(p))
            append_status_safe(
                status_rv,
                sprintf("Annotation cache warmed: %s (%.1fs)", lbl, as.numeric(elapsed[["elapsed"]]))
            )
        }
        invisible(annotation_is_warmed(p))
    }

    normalize_genome_key <- function(genome_path) {
        p <- as.character(genome_path %||% "")
        if (!nzchar(p)) {
            return("")
        }
        normalizePath(p, winslash = "/", mustWork = FALSE)
    }

    genome_is_warmed <- function(genome_path) {
        key <- normalize_genome_key(genome_path)
        if (!nzchar(key)) {
            return(FALSE)
        }
        exists(key, envir = warmed_genome_keys, inherits = FALSE)
    }

    mark_genome_warmed <- function(genome_path) {
        key <- normalize_genome_key(genome_path)
        if (!nzchar(key)) {
            return(invisible(FALSE))
        }
        assign(key, TRUE, envir = warmed_genome_keys)
        invisible(TRUE)
    }

    warm_genome_cache <- function(genome_path, status_rv = NULL, context_label = NULL) {
        gp <- as.character(genome_path %||% "")
        if (!nzchar(gp) || !file.exists(gp) || genome_is_warmed(gp)) {
            return(invisible(FALSE))
        }
        elapsed <- system.time({
            if (isTRUE(is_twobit_file(gp))) {
                tryCatch(get_twobit_seqnames(gp), error = function(e) character(0))
            } else {
                try(get_fasta_index_seqnames(gp), silent = TRUE)
                try(get_cached_fafile(gp), silent = TRUE)
            }
            mark_genome_warmed(gp)
        })
        if (!is.null(status_rv) && genome_is_warmed(gp)) {
            lbl <- as.character(context_label %||% basename(gp))
            append_status_safe(
                status_rv,
                sprintf("Genome cache warmed: %s (%.1fs)", lbl, as.numeric(elapsed[["elapsed"]]))
            )
        }
        invisible(genome_is_warmed(gp))
    }

    warm_report_cache <- function(report_path, status_rv = NULL, context_label = NULL) {
        rp <- as.character(report_path %||% "")
        if (!nzchar(rp) || !file.exists(rp)) {
            return(invisible(FALSE))
        }
        elapsed <- system.time({
            tryCatch(
                parse_assembly_report_file(rp),
                error = function(e) NULL
            )
        })
        if (!is.null(status_rv)) {
            lbl <- as.character(context_label %||% basename(rp))
            append_status_safe(
                status_rv,
                sprintf("Assembly report cache warmed: %s (%.1fs)", lbl, as.numeric(elapsed[["elapsed"]]))
            )
        }
        invisible(TRUE)
    }

    warm_alias_index_fn <- function(organism_id, base_dir = ".", status_rv = NULL, context_label = NULL) {
        org <- trimws(as.character(organism_id %||% ""))
        if (!nzchar(org)) return(invisible(FALSE))
        if (!exists("warm_alias_index", mode = "function")) return(invisible(FALSE))

        elapsed <- system.time({
            ok <- tryCatch(warm_alias_index(org, base_dir = base_dir), error = function(e) FALSE)
        })
        if (!is.null(status_rv)) {
            lbl <- as.character(context_label %||% org)
            if (isTRUE(ok)) {
                append_status_safe(
                    status_rv,
                    sprintf("Alias index warmed: %s (%.1fs)", lbl, as.numeric(elapsed[["elapsed"]]))
                )
            }
        }
        invisible(isTRUE(ok))
    }

    list(
        normalize_annotation_key = normalize_annotation_key,
        annotation_is_warmed = annotation_is_warmed,
        mark_annotation_warmed = mark_annotation_warmed,
        warm_annotation_cache = warm_annotation_cache,
        normalize_genome_key = normalize_genome_key,
        genome_is_warmed = genome_is_warmed,
        mark_genome_warmed = mark_genome_warmed,
        warm_genome_cache = warm_genome_cache,
        warm_report_cache = warm_report_cache,
        warm_annotation_tabix_probe = warm_annotation_tabix_probe,
        warm_alias_index_fn = warm_alias_index_fn
    )
}
