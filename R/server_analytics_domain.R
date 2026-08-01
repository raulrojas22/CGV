init_analytics_domain <- function(
    analyticsPreparedCache_env,
    analyticsMetricMatrixCache_env,
    analyticsExonDistCache_env,
    analyticsScatterPrepCache_env,
    analyticsScatterRenderCache_env,
    analyticsRadarSceneCache_env,
    analyticsRadarRenderCache_env,
    analyticsCorrSceneCache_env,
    analyticsCorrRenderCache_env,
    summary_plot_data_fingerprint_fn = NULL,
    get_homo_plot_signatures_fn = NULL,
    get_ortho_plot_signatures_fn = NULL
) {
    summary_plot_data_fingerprint_safe <- function(plot_data) {
        if (is.function(summary_plot_data_fingerprint_fn)) {
            return(summary_plot_data_fingerprint_fn(plot_data))
        }
        if (is.null(plot_data) || !is.data.frame(plot_data) || nrow(plot_data) == 0L) {
            return("plot:none")
        }
        paste0("plot:", nrow(plot_data))
    }

    get_mode_plot_signatures <- function(mode = "homo") {
        mode_txt <- tolower(trimws(as.character(mode %||% "homo")))
        getter <- if (identical(mode_txt, "ortho")) {
            get_ortho_plot_signatures_fn
        } else {
            get_homo_plot_signatures_fn
        }
        if (!is.function(getter)) {
            return(list())
        }
        tryCatch(getter(), error = function(e) list())
    }

    clear_cache_env_prefix <- function(env, prefix) {
        prefix_txt <- as.character(prefix %||% "")
        if (!nzchar(prefix_txt)) {
            return(invisible(NULL))
        }
        keys <- ls(envir = env, all.names = TRUE)
        keys <- keys[startsWith(keys, prefix_txt)]
        if (length(keys) > 0L) {
            rm(list = keys, envir = env)
        }
        invisible(NULL)
    }

    clear_analytics_cache_scope <- function(scope = "analytics") {
        scope_txt <- trimws(as.character(scope %||% "analytics"))
        if (!nzchar(scope_txt)) {
            scope_txt <- "analytics"
        }
        clear_cache_env_prefix(analyticsPreparedCache_env, paste0("analytics-prep-v1||", scope_txt, "||"))
        clear_cache_env_prefix(analyticsMetricMatrixCache_env, paste0("analytics-mat-v1||", scope_txt, "||"))
        clear_cache_env_prefix(analyticsExonDistCache_env, paste0("analytics-exons-v1||", scope_txt, "||"))
        clear_cache_env_prefix(analyticsExonDistCache_env, paste0("analytics-introns-v1||", scope_txt, "||"))
        clear_cache_env_prefix(analyticsScatterPrepCache_env, paste0("analytics-scatter-v1||", scope_txt, "||"))
        clear_cache_env_prefix(analyticsScatterRenderCache_env, paste0("analytics-scatter-render-v1||", scope_txt, "||"))
        clear_cache_env_prefix(analyticsRadarSceneCache_env, paste0("analytics-radar-scene-v1||", scope_txt, "||"))
        clear_cache_env_prefix(analyticsRadarRenderCache_env, paste0("analytics-radar-render-v1||", scope_txt, "||"))
        clear_cache_env_prefix(analyticsCorrSceneCache_env, paste0("analytics-corr-scene-v1||", scope_txt, "||"))
        clear_cache_env_prefix(analyticsCorrRenderCache_env, paste0("analytics-corr-render-v1||", scope_txt, "||"))
        invisible(NULL)
    }

    scientific_italic_unicode <- function(x) {
        txt_vec <- as.character(x %||% "")
        txt_vec[is.na(txt_vec)] <- ""
        vapply(txt_vec, function(txt) {
            if (!nzchar(txt)) {
                return("")
            }
            chars <- strsplit(txt, "", fixed = TRUE)[[1]]
            out <- vapply(chars, function(ch) {
                code <- utf8ToInt(ch)
                if (length(code) != 1L) {
                    return(ch)
                }
                if (code >= utf8ToInt("A") && code <= utf8ToInt("Z")) {
                    return(intToUtf8(0x1D434 + (code - utf8ToInt("A"))))
                }
                if (code >= utf8ToInt("a") && code <= utf8ToInt("z")) {
                    if (identical(ch, "h")) {
                        return("\u210E")
                    }
                    return(intToUtf8(0x1D44E + (code - utf8ToInt("a"))))
                }
                ch
            }, character(1))
            paste0(out, collapse = "")
        }, character(1))
    }

    plotmath_quote_text <- function(x) {
        txt_vec <- as.character(x %||% "")
        txt_vec[is.na(txt_vec)] <- ""
        vapply(txt_vec, function(txt) {
            txt <- gsub("\\", "\\\\", txt, fixed = TRUE)
            txt <- gsub("\"", "\\\"", txt, fixed = TRUE)
            paste0("\"", txt, "\"")
        }, character(1))
    }

    make_x_labels <- function(df, mode = "homo") {
        if (is.null(df) || nrow(df) == 0) {
            return(df)
        }

        df_out <- df
        mode_txt <- tolower(trimws(as.character(mode %||% "homo")))
        org_raw <- if ("Organism" %in% names(df_out)) trimws(as.character(df_out$Organism)) else rep("", nrow(df_out))
        gene_raw <- if ("Gene" %in% names(df_out)) trimws(as.character(df_out$Gene)) else rep("", nrow(df_out))
        tx_raw <- if ("Transcript" %in% names(df_out)) trimws(as.character(df_out$Transcript)) else rep("", nrow(df_out))
        icon_raw <- if ("Organism_Icon" %in% names(df_out)) trimws(as.character(df_out$Organism_Icon)) else rep("", nrow(df_out))

        org_full <- ifelse(nzchar(org_raw), org_raw, "Organism")
        gene_full <- ifelse(nzchar(gene_raw), gene_raw, "Gene")
        tx_full <- ifelse(nzchar(tx_raw), tx_raw, "N/A")
        icon_full <- ifelse(nzchar(icon_raw), icon_raw, "/icons/DNA.ico")
        org_short <- stringr::str_trunc(org_full, width = 28, ellipsis = "\u2026")
        gene_short <- stringr::str_trunc(gene_full, width = 28, ellipsis = "\u2026")
        tx_short <- stringr::str_trunc(tx_full, width = 32, ellipsis = "\u2026")

        if (identical(mode_txt, "modal")) {
            n_org <- dplyr::n_distinct(org_full[nzchar(org_raw)])
            include_org <- identical(mode_txt, "ortho") || (is.finite(n_org) && n_org > 1L)
            if (include_org) {
                df_out$x_label_plain <- paste0(org_full, " | ", gene_full, " | ", tx_full)
                df_out$x_label <- paste0(org_full, "\n", gene_full, " | ", tx_full)
                df_out$x_label_scatter <- paste0(
                    stringr::str_wrap(org_short, width = 24),
                    "\n",
                    stringr::str_wrap(gene_short, width = 24),
                    "\n",
                    stringr::str_wrap(tx_short, width = 24)
                )
            } else {
                df_out$x_label_plain <- paste0(gene_full, " | ", tx_full)
                df_out$x_label <- df_out$x_label_plain
                df_out$x_label_scatter <- paste0(
                    stringr::str_wrap(gene_short, width = 24),
                    "\n",
                    stringr::str_wrap(tx_short, width = 24)
                )
            }
        } else if (identical(mode_txt, "ortho")) {
            df_out$x_label_plain <- paste0(org_full, " | ", gene_full, " | ", tx_full)
            df_out$x_label <- gene_full
            df_out$x_label_organism <- org_short
            df_out$x_label_scatter <- paste0(
                stringr::str_wrap(gene_short, width = 24),
                "\n",
                stringr::str_wrap(org_short, width = 24)
            )
        } else {
            df_out$x_label_plain <- paste0(org_full, " | ", gene_full, " | ", tx_full)
            df_out$x_label <- gene_full
            df_out$x_label_scatter <- stringr::str_wrap(gene_short, width = 24)
        }

        if (!"x_label_organism" %in% names(df_out)) {
            df_out$x_label_organism <- ""
        }

        df_out$organism_full <- org_full
        df_out$organism_short <- org_short
        df_out$gene_full <- gene_full
        df_out$gene_short <- gene_short
        df_out$transcript_full <- tx_full
        df_out$transcript_short <- tx_short
        df_out$organism_icon <- icon_full
        df_out
    }

    apply_analytics_order <- function(df, mode = "homo", order_mode = "load") {
        if (is.null(df) || nrow(df) == 0) {
            return(df)
        }

        key <- tolower(trimws(as.character(order_mode %||% "load")))
        if (!nzchar(key)) key <- "load"

        safe_num_col <- function(dat, col) {
            if (col %in% names(dat)) {
                suppressWarnings(as.numeric(dat[[col]]))
            } else {
                rep(NA_real_, nrow(dat))
            }
        }

        df_lab <- df %>%
            make_x_labels(mode = mode)

        gene_len_v <- safe_num_col(df_lab, "Gene_Length_bp")
        tx_len_v <- safe_num_col(df_lab, "Transcript_Length_bp")
        exons_n_v <- safe_num_col(df_lab, "Exons")
        introns_n_v <- safe_num_col(df_lab, "Introns")
        gc_pct_v <- safe_num_col(df_lab, "GC_Content_pct")
        cds_tx_v <- safe_num_col(df_lab, "CDS_to_Tx_pct")
        exonic_bp_v <- safe_num_col(df_lab, "Exonic_bp")
        a_pct_v <- safe_num_col(df_lab, "A_pct")
        t_pct_v <- safe_num_col(df_lab, "T_pct")
        c_pct_v <- safe_num_col(df_lab, "C_pct")
        g_pct_v <- safe_num_col(df_lab, "G_pct")
        up_dist_v <- safe_num_col(df_lab, "Upstream_Distance_bp")
        down_dist_v <- safe_num_col(df_lab, "Downstream_Distance_bp")

        df_lab <- df_lab %>%
            dplyr::mutate(
                .load_idx = dplyr::row_number(),
                .gene_len = gene_len_v,
                .tx_len = tx_len_v,
                .exons_n = exons_n_v,
                .introns_n = introns_n_v,
                .gc_pct = gc_pct_v,
                .cds_tx_pct = cds_tx_v,
                .exonic_bp = exonic_bp_v,
                .intron_bp = pmax(0, .gene_len - .exonic_bp),
                .a_pct = a_pct_v,
                .t_pct = t_pct_v,
                .c_pct = c_pct_v,
                .g_pct = g_pct_v,
                .up_dist = up_dist_v,
                .down_dist = down_dist_v,
                .up_abs = abs(.up_dist),
                .down_abs = abs(.down_dist),
                .has_overlap = dplyr::coalesce(.up_dist < 0, FALSE) | dplyr::coalesce(.down_dist < 0, FALSE),
                .label_key = tolower(trimws(as.character(x_label_plain %||% "")))
            )

        switch(key,
            "gene_len_desc" = dplyr::arrange(df_lab, dplyr::desc(.gene_len), .label_key, .load_idx),
            "gene_len_asc" = dplyr::arrange(df_lab, .gene_len, .label_key, .load_idx),
            "tx_len_desc" = dplyr::arrange(df_lab, dplyr::desc(.tx_len), .label_key, .load_idx),
            "tx_len_asc" = dplyr::arrange(df_lab, .tx_len, .label_key, .load_idx),
            "exon_desc" = dplyr::arrange(df_lab, dplyr::desc(.exons_n), .label_key, .load_idx),
            "exon_asc" = dplyr::arrange(df_lab, .exons_n, .label_key, .load_idx),
            "intron_desc" = dplyr::arrange(df_lab, dplyr::desc(.introns_n), .label_key, .load_idx),
            "intron_asc" = dplyr::arrange(df_lab, .introns_n, .label_key, .load_idx),
            "gc_desc" = dplyr::arrange(df_lab, dplyr::desc(.gc_pct), .label_key, .load_idx),
            "gc_asc" = dplyr::arrange(df_lab, .gc_pct, .label_key, .load_idx),
            "cds_tx_desc" = dplyr::arrange(df_lab, dplyr::desc(.cds_tx_pct), .label_key, .load_idx),
            "cds_tx_asc" = dplyr::arrange(df_lab, .cds_tx_pct, .label_key, .load_idx),
            "exonic_bp_desc" = dplyr::arrange(df_lab, dplyr::desc(.exonic_bp), .label_key, .load_idx),
            "exonic_bp_asc" = dplyr::arrange(df_lab, .exonic_bp, .label_key, .load_idx),
            "intron_bp_desc" = dplyr::arrange(df_lab, dplyr::desc(.intron_bp), .label_key, .load_idx),
            "intron_bp_asc" = dplyr::arrange(df_lab, .intron_bp, .label_key, .load_idx),
            "a_desc" = dplyr::arrange(df_lab, dplyr::desc(.a_pct), .label_key, .load_idx),
            "a_asc" = dplyr::arrange(df_lab, .a_pct, .label_key, .load_idx),
            "t_desc" = dplyr::arrange(df_lab, dplyr::desc(.t_pct), .label_key, .load_idx),
            "t_asc" = dplyr::arrange(df_lab, .t_pct, .label_key, .load_idx),
            "c_desc" = dplyr::arrange(df_lab, dplyr::desc(.c_pct), .label_key, .load_idx),
            "c_asc" = dplyr::arrange(df_lab, .c_pct, .label_key, .load_idx),
            "g_desc" = dplyr::arrange(df_lab, dplyr::desc(.g_pct), .label_key, .load_idx),
            "g_asc" = dplyr::arrange(df_lab, .g_pct, .label_key, .load_idx),
            "up_abs_desc" = dplyr::arrange(df_lab, dplyr::desc(.up_abs), .label_key, .load_idx),
            "up_abs_asc" = dplyr::arrange(df_lab, .up_abs, .label_key, .load_idx),
            "down_abs_desc" = dplyr::arrange(df_lab, dplyr::desc(.down_abs), .label_key, .load_idx),
            "down_abs_asc" = dplyr::arrange(df_lab, .down_abs, .label_key, .load_idx),
            "overlap_first" = dplyr::arrange(df_lab, dplyr::desc(.has_overlap), .label_key, .load_idx),
            "overlap_last" = dplyr::arrange(df_lab, .has_overlap, .label_key, .load_idx),
            "label_asc" = dplyr::arrange(df_lab, .label_key, .load_idx),
            "label_desc" = dplyr::arrange(df_lab, dplyr::desc(.label_key), .load_idx),
            dplyr::arrange(df_lab, .load_idx)
        )
    }

    analytics_df_fingerprint <- function(df) {
        if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
            return("analytics-empty")
        }
        key_cols <- intersect(
            c(
                "Organism", "Gene", "Transcript",
                "Gene_Length_bp", "Transcript_Length_bp",
                "Exons", "Introns", "GC_Content_pct", "CDS_to_Tx_pct",
                "Exonic_bp", "CDS_bp",
                "A_pct", "T_pct", "C_pct", "G_pct",
                "Upstream_Distance_bp", "Downstream_Distance_bp"
            ),
            names(df)
        )
        if (length(key_cols) == 0L) {
            key_cols <- names(df)
        }
        parts <- vapply(key_cols, function(col) {
            paste(as.character(df[[col]] %||% ""), collapse = "|")
        }, character(1))
        paste(nrow(df), paste(parts, collapse = "||"), sep = "::")
    }

    get_cached_analytics_prepared_df <- function(df, mode = "homo", order_mode = "load") {
        mode_txt <- tolower(trimws(as.character(mode %||% "homo")))
        order_txt <- tolower(trimws(as.character(order_mode %||% "load")))
        key <- paste(
            "analytics-prep-v1",
            mode_txt,
            order_txt,
            analytics_df_fingerprint(df),
            sep = "||"
        )
        if (exists(key, envir = analyticsPreparedCache_env, inherits = FALSE)) {
            cached <- get(key, envir = analyticsPreparedCache_env, inherits = FALSE)
            if (is.data.frame(cached)) {
                return(cached)
            }
        }
        prepared <- apply_analytics_order(df, mode = mode_txt, order_mode = order_txt)
        if (!is.null(prepared) && is.data.frame(prepared) && nrow(prepared) > 0L) {
            prepared <- prepared %>%
                dplyr::mutate(axis_id = factor(dplyr::row_number(), levels = seq_len(dplyr::n())))
        }
        attr(prepared, "analytics_cache_key") <- key
        assign(key, prepared, envir = analyticsPreparedCache_env)
        trim_cache_env(analyticsPreparedCache_env, max_size = 48L)
        prepared
    }

    get_cached_analytics_metric_matrix <- function(df_prepared, metrics_raw, log_cols = character(0)) {
        prep_key <- as.character(attr(df_prepared, "analytics_cache_key") %||% analytics_df_fingerprint(df_prepared))
        metrics_raw <- as.character(metrics_raw %||% character(0))
        log_cols <- as.character(log_cols %||% character(0))
        key <- paste(
            "analytics-mat-v1",
            prep_key,
            paste(metrics_raw, collapse = ","),
            paste(log_cols, collapse = ","),
            sep = "||"
        )
        if (exists(key, envir = analyticsMetricMatrixCache_env, inherits = FALSE)) {
            cached <- get(key, envir = analyticsMetricMatrixCache_env, inherits = FALSE)
            if (is.matrix(cached)) {
                return(cached)
            }
        }
        mat <- sapply(metrics_raw, function(col) {
            x <- suppressWarnings(as.numeric(df_prepared[[col]]))
            if (col %in% log_cols) log10(pmax(x, 1)) else x
        })
        mat <- as.matrix(mat)
        if (!is.null(dim(mat)) && nrow(mat) != nrow(df_prepared) && ncol(mat) == nrow(df_prepared)) {
            mat <- t(mat)
        }
        colnames(mat) <- metrics_raw
        assign(key, mat, envir = analyticsMetricMatrixCache_env)
        trim_cache_env(analyticsMetricMatrixCache_env, max_size = 48L)
        mat
    }

    get_cached_exon_lengths_for_plot <- function(pid, mode = "homo", file_data = NULL) {
        pid_txt <- as.character(pid %||% "")
        mode_txt <- tolower(trimws(as.character(mode %||% "homo")))
        sig_map <- get_mode_plot_signatures(mode_txt)
        plot_sig <- as.character(tryCatch(sig_map[[pid_txt]], error = function(e) "") %||% "")
        if (!nzchar(plot_sig)) {
            plot_sig <- summary_plot_data_fingerprint_safe(file_data)
        }
        cache_key <- paste("analytics-exons-v1", mode_txt, pid_txt, plot_sig, sep = "||")
        if (exists(cache_key, envir = analyticsExonDistCache_env, inherits = FALSE)) {
            cached <- get(cache_key, envir = analyticsExonDistCache_env, inherits = FALSE)
            if (is.data.frame(cached)) {
                return(cached)
            }
        }
        if (is.null(file_data) || !is.data.frame(file_data) || nrow(file_data) == 0L) {
            out <- data.frame(plot_id_chr = character(0), exon_length = numeric(0), stringsAsFactors = FALSE)
            assign(cache_key, out, envir = analyticsExonDistCache_env)
            trim_cache_env(analyticsExonDistCache_env, max_size = 128L)
            return(out)
        }
        types <- tolower(trimws(as.character(file_data$V3)))
        rows <- which(types == "exon")
        if (length(rows) == 0) rows <- which(types == "cds")
        if (length(rows) == 0) {
            out <- data.frame(plot_id_chr = character(0), exon_length = numeric(0), stringsAsFactors = FALSE)
            assign(cache_key, out, envir = analyticsExonDistCache_env)
            trim_cache_env(analyticsExonDistCache_env, max_size = 128L)
            return(out)
        }
        starts <- suppressWarnings(as.numeric(file_data$V4[rows]))
        ends <- suppressWarnings(as.numeric(file_data$V5[rows]))
        lens <- ends - starts + 1
        ok <- is.finite(lens) & lens > 0
        out <- if (any(ok)) {
            data.frame(
                plot_id_chr = pid_txt,
                exon_length = lens[ok],
                stringsAsFactors = FALSE
            )
        } else {
            data.frame(plot_id_chr = character(0), exon_length = numeric(0), stringsAsFactors = FALSE)
        }
        assign(cache_key, out, envir = analyticsExonDistCache_env)
        trim_cache_env(analyticsExonDistCache_env, max_size = 128L)
        out
    }

    get_cached_intron_lengths_for_plot <- function(pid, mode = "homo", file_data = NULL) {
        empty_introns <- function() {
            data.frame(
                plot_id_chr = character(0),
                intron_n = integer(0),
                intron_start = numeric(0),
                intron_end = numeric(0),
                intron_length = numeric(0),
                stringsAsFactors = FALSE
            )
        }

        pid_txt <- as.character(pid %||% "")
        mode_txt <- tolower(trimws(as.character(mode %||% "homo")))
        sig_map <- get_mode_plot_signatures(mode_txt)
        plot_sig <- as.character(tryCatch(sig_map[[pid_txt]], error = function(e) "") %||% "")
        if (!nzchar(plot_sig)) {
            plot_sig <- summary_plot_data_fingerprint_safe(file_data)
        }
        cache_key <- paste("analytics-introns-v1", mode_txt, pid_txt, plot_sig, sep = "||")
        if (exists(cache_key, envir = analyticsExonDistCache_env, inherits = FALSE)) {
            cached <- get(cache_key, envir = analyticsExonDistCache_env, inherits = FALSE)
            if (is.data.frame(cached)) {
                return(cached)
            }
        }
        if (is.null(file_data) || !is.data.frame(file_data) || nrow(file_data) == 0L) {
            out <- empty_introns()
            assign(cache_key, out, envir = analyticsExonDistCache_env)
            trim_cache_env(analyticsExonDistCache_env, max_size = 128L)
            return(out)
        }

        types <- tolower(trimws(as.character(file_data$V3)))
        rows <- which(types == "exon")
        if (length(rows) < 2L) {
            out <- empty_introns()
            assign(cache_key, out, envir = analyticsExonDistCache_env)
            trim_cache_env(analyticsExonDistCache_env, max_size = 128L)
            return(out)
        }

        ex <- unique(data.frame(
            start = suppressWarnings(as.numeric(file_data$V4[rows])),
            end = suppressWarnings(as.numeric(file_data$V5[rows])),
            stringsAsFactors = FALSE
        ))
        ex <- ex[is.finite(ex$start) & is.finite(ex$end) & ex$end >= ex$start, , drop = FALSE]
        if (nrow(ex) < 2L) {
            out <- empty_introns()
            assign(cache_key, out, envir = analyticsExonDistCache_env)
            trim_cache_env(analyticsExonDistCache_env, max_size = 128L)
            return(out)
        }

        ex <- ex[order(ex$start, ex$end), , drop = FALSE]
        intron_start <- ex$end[-nrow(ex)] + 1
        intron_end <- ex$start[-1] - 1
        intron_length <- intron_end - intron_start + 1
        ok <- is.finite(intron_length) & intron_length > 0

        out <- if (any(ok)) {
            data.frame(
                plot_id_chr = pid_txt,
                intron_n = seq_len(sum(ok)),
                intron_start = intron_start[ok],
                intron_end = intron_end[ok],
                intron_length = intron_length[ok],
                stringsAsFactors = FALSE
            )
        } else {
            empty_introns()
        }
        assign(cache_key, out, envir = analyticsExonDistCache_env)
        trim_cache_env(analyticsExonDistCache_env, max_size = 128L)
        out
    }

    get_cached_scatter_prepared_df <- function(df_prepared, order_mode = "load") {
        prep_key <- as.character(attr(df_prepared, "analytics_cache_key") %||% analytics_df_fingerprint(df_prepared))
        order_txt <- tolower(trimws(as.character(order_mode %||% "load")))
        cache_key <- paste("analytics-scatter-v6", prep_key, order_txt, sep = "||")
        if (exists(cache_key, envir = analyticsScatterPrepCache_env, inherits = FALSE)) {
            cached <- get(cache_key, envir = analyticsScatterPrepCache_env, inherits = FALSE)
            if (is.data.frame(cached)) {
                return(cached)
            }
        }
        esc_html <- function(x) as.character(htmltools::htmlEscape(as.character(x %||% ""), attribute = FALSE))
        esc_attr <- function(x) as.character(htmltools::htmlEscape(as.character(x %||% ""), attribute = TRUE))

        df_prep <- df_prepared %>%
            dplyr::mutate(
                gc = suppressWarnings(as.numeric(GC_Content_pct)),
                len_bp = suppressWarnings(as.numeric(Gene_Length_bp)),
                n_exons = suppressWarnings(as.integer(Exons)),
                cds_pct = suppressWarnings(as.numeric(CDS_to_Tx_pct))
            ) %>%
            dplyr::filter(is.finite(gc), is.finite(len_bp)) %>%
            dplyr::mutate(
                n_exons = ifelse(is.finite(n_exons) & n_exons > 0, n_exons, 1L)
            )
        if (!is.data.frame(df_prep) || nrow(df_prep) == 0L) {
            assign(cache_key, df_prep, envir = analyticsScatterPrepCache_env)
            trim_cache_env(analyticsScatterPrepCache_env, max_size = 48L)
            return(df_prep)
        }

        df_prep <- switch(order_txt,
            "gene_len_desc" = dplyr::arrange(df_prep, len_bp, x_label_plain),
            "gene_len_asc" = dplyr::arrange(df_prep, dplyr::desc(len_bp), x_label_plain),
            "gc_desc" = dplyr::arrange(df_prep, gc, x_label_plain),
            "gc_asc" = dplyr::arrange(df_prep, dplyr::desc(gc), x_label_plain),
            "exon_desc" = dplyr::arrange(df_prep, n_exons, x_label_plain),
            "exon_asc" = dplyr::arrange(df_prep, dplyr::desc(n_exons), x_label_plain),
            "label_asc" = dplyr::arrange(df_prep, tolower(x_label_plain)),
            "label_desc" = dplyr::arrange(df_prep, dplyr::desc(tolower(x_label_plain))),
            df_prep
        )

        n_pts <- nrow(df_prep)
        label_char_limit <- if (n_pts >= 18) 28 else 36
        df_prep <- df_prep %>%
            dplyr::mutate(
                scatter_label = stringr::str_trunc(x_label_scatter, width = label_char_limit * 3L, ellipsis = "\u2026"),
                scatter_gene_label = stringr::str_trunc(gene_full, width = label_char_limit, ellipsis = "\u2026"),
                scatter_organism_label = stringr::str_trunc(organism_full, width = label_char_limit, ellipsis = "\u2026"),
                scatter_label_compact = dplyr::if_else(
                    nzchar(trimws(as.character(x_label_organism %||% ""))),
                    paste0(
                        scatter_gene_label,
                        "\n",
                        scatter_organism_label
                    ),
                    scatter_gene_label
                ),
                scatter_label_plotmath = dplyr::if_else(
                    nzchar(trimws(as.character(x_label_organism %||% ""))),
                    paste0(
                        "atop(bold(", plotmath_quote_text(scatter_gene_label), "),",
                        "italic(", plotmath_quote_text(scatter_organism_label), "))"
                    ),
                    paste0("bold(", plotmath_quote_text(scatter_gene_label), ")")
                ),
                data_id_lbl = paste0(x_label_plain, "_", dplyr::row_number()),
                tooltip_txt = paste0(
                    "<div style='display:flex;align-items:center;gap:6px;margin-bottom:2px;'>",
                    "<img src='", esc_attr(organism_icon), "' style='width:13px;height:13px;border-radius:50%;object-fit:contain;background:#eef4f8;border:1px solid #c8d7e3;'/>",
                    "<span><b>", esc_html(organism_full), "</b></span></div>",
                    "<b>Gene:</b> ", esc_html(gene_full), "<br/>",
                    "<b>Transcript:</b> ", esc_html(transcript_full), "<br/>",
                    "GC content: <b>", round(gc, 1), "%</b><br/>",
                    "Gene length: <b>", format(len_bp, big.mark = ","), " bp</b><br/>",
                    "Exons: <b>", n_exons, "</b><br/>",
                    "CDS / Tx: ", round(cds_pct, 1), "%"
                )
            )
        assign(cache_key, df_prep, envir = analyticsScatterPrepCache_env)
        trim_cache_env(analyticsScatterPrepCache_env, max_size = 48L)
        df_prep
    }

    get_cached_radar_scene <- function(df_prepared, mode = "homo") {
        prep_key <- as.character(attr(df_prepared, "analytics_cache_key") %||% analytics_df_fingerprint(df_prepared))
        mode_txt <- tolower(trimws(as.character(mode %||% "homo")))
        cache_key <- paste("analytics-radar-scene-v6", mode_txt, prep_key, sep = "||")
        cached <- cache_env_get(analyticsRadarSceneCache_env, cache_key, default = NULL)
        if (is.list(cached) && is.data.frame(cached$df_lab) && is.matrix(cached$mat_raw)) {
            return(cached)
        }

        radar_cols <- c(
            "Gene_Length_bp", "Transcript_Length_bp",
            "Exons", "Introns",
            "GC_Content_pct", "CDS_to_Tx_pct"
        )
        log_cols <- c("Gene_Length_bp", "Transcript_Length_bp")
        axis_lbl <- c(
            "Gene\nlength", "Transcript\nlength", "Exons",
            "Introns", "GC %", "CDS /\nTranscript %"
        )
        pct_cols <- c("GC_Content_pct", "CDS_to_Tx_pct")

        mat <- get_cached_analytics_metric_matrix(df_prepared, metrics_raw = radar_cols, log_cols = log_cols)
        keep_rows <- apply(mat, 1, function(v) all(is.finite(v)))
        dropped_genes <- sum(!keep_rows)
        df_lab <- df_prepared
        if (dropped_genes > 0L) {
            df_lab <- df_lab[keep_rows, , drop = FALSE]
            mat <- mat[keep_rows, , drop = FALSE]
        }
        if (nrow(df_lab) < 2L) {
            scene <- list(
                status = "insufficient_complete",
                df_lab = df_lab,
                mat_raw = mat,
                dropped_genes = dropped_genes
            )
            cache_env_set(analyticsRadarSceneCache_env, cache_key, scene, max_size = 32L)
            return(scene)
        }

        n_metrics <- length(radar_cols)
        n_genes <- nrow(df_lab)
        n_org_radar <- dplyr::n_distinct(df_lab$organism_full[df_lab$organism_full != "Organism"])
        single_org_homo <- identical(mode_txt, "homo") && (!is.finite(n_org_radar) || n_org_radar <= 1L)
        df_lab$radar_display <- ifelse(
            !single_org_homo & nzchar(trimws(as.character(df_lab$organism_full %||% ""))),
            paste0(
                as.character(df_lab$gene_full %||% df_lab$x_label %||% "Gene"),
                "\n",
                as.character(df_lab$organism_full %||% "")
            ),
            as.character(df_lab$gene_full %||% df_lab$x_label %||% "Gene")
        )
        legend_ncol <- if (single_org_homo) {
            if (n_genes >= 9L) 4L else 3L
        } else if (n_genes >= 6L) {
            2L
        } else {
            1L
        }
        legend_rows <- if (!is.null(legend_ncol)) ceiling(n_genes / legend_ncol) else 1L
        radar_height <- 5.45 + max(0, legend_rows - 1L) * 0.34

        mat_norm <- apply(mat, 2, function(x) {
            if (!any(is.finite(x))) {
                return(rep(0.5, length(x)))
            }
            rng <- range(x, na.rm = TRUE)
            if (!all(is.finite(rng)) || diff(rng) == 0) {
                return(rep(0.5, length(x)))
            }
            (x - rng[1]) / diff(rng)
        })

        angles <- seq(pi / 2, pi / 2 + 2 * pi, length.out = n_metrics + 1)[seq_len(n_metrics)]
        grid_levels <- c(0.25, 0.5, 0.75, 1.0)
        grid_theta <- seq(0, 2 * pi, length.out = 200)
        grid_df <- do.call(rbind,  lapply(grid_levels, function(r) {
            data.frame(
                x = r * cos(grid_theta),
                y = r * sin(grid_theta),
                r = r,
                stringsAsFactors = FALSE
            )
        }))
        spokes_df <- data.frame(
            xend = cos(angles),
            yend = sin(angles),
            lbl = axis_lbl,
            lbl_x = 1.28 * cos(angles),
            lbl_y = 1.28 * sin(angles),
            stringsAsFactors = FALSE
        )
        poly_df <- do.call(rbind,  lapply(seq_len(n_genes), function(i) {
            lbl <- as.character(df_lab$radar_display[i] %||% df_lab$x_label[i] %||% paste0("Gene ", i))
            gene_txt <- as.character(df_lab$gene_full[i] %||% df_lab$x_label[i] %||% paste0("Gene ", i))
            organism_txt <- trimws(as.character(df_lab$organism_full[i] %||% ""))
            tip_prefix <- if (nzchar(organism_txt)) {
                paste0("<b>", gene_txt, "</b><br/><i>", organism_txt, "</i><br/>")
            } else {
                paste0("<b>", gene_txt, "</b><br/>")
            }
            vals <- mat_norm[i, ]
            raw <- mat[i, ]
            rows <- data.frame(
                gene = lbl,
                metric = axis_lbl,
                val = vals,
                x = vals * cos(angles),
                y = vals * sin(angles),
                tip_pt = paste0(
                    tip_prefix,
                    axis_lbl, ": <b>",
                    ifelse(
                        radar_cols %in% pct_cols,
                        paste0(round(raw, 1), "%"),
                        format(round(raw, 1), big.mark = ",")
                    ),
                    "</b><br/>Normalized: ", round(vals, 2)
                ),
                tip_poly = if (nzchar(organism_txt)) {
                    paste0("<b>", gene_txt, "</b><br/><i>", organism_txt, "</i>")
                } else {
                    gene_txt
                },
                stringsAsFactors = FALSE
            )
            rbind(rows, rows[1L, , drop = FALSE])
        }))
        poly_df$is_close <- duplicated(paste0(poly_df$gene, poly_df$metric))

        scene <- list(
            status = "ok",
            df_lab = df_lab,
            mat_raw = mat,
            radar_cols = radar_cols,
            axis_lbl = axis_lbl,
            dropped_genes = dropped_genes,
            n_genes = n_genes,
            show_legend_organism = !single_org_homo,
            legend_ncol = legend_ncol,
            radar_height = radar_height,
            grid_levels = grid_levels,
            grid_df = grid_df,
            spokes_df = spokes_df,
            poly_df = poly_df
        )
        cache_env_set(analyticsRadarSceneCache_env, cache_key, scene, max_size = 32L)
        scene
    }

    get_cached_corr_scene <- function(df_prepared, mode = "homo", corr_order_mode = "metric_default") {
        prep_key <- as.character(attr(df_prepared, "analytics_cache_key") %||% analytics_df_fingerprint(df_prepared))
        mode_txt <- tolower(trimws(as.character(mode %||% "homo")))
        order_txt <- tolower(trimws(as.character(corr_order_mode %||% "metric_default")))
        cache_key <- paste("analytics-corr-scene-v1", mode_txt, order_txt, prep_key, sep = "||")
        cached <- cache_env_get(analyticsCorrSceneCache_env, cache_key, default = NULL)
        if (is.list(cached) && is.data.frame(cached$df_cor)) {
            return(cached)
        }

        metrics_raw <- c(
            "Gene_Length_bp", "Transcript_Length_bp",
            "Exons", "Introns",
            "GC_Content_pct", "CDS_to_Tx_pct",
            "Exonic_bp", "CDS_bp"
        )
        log_cols <- c(
            "Gene_Length_bp", "Transcript_Length_bp",
            "Exonic_bp", "CDS_bp"
        )
        short_lbl <- c(
            Gene_Length_bp = "Gene len",
            Transcript_Length_bp = "Transcript len",
            Exons = "Exons",
            Introns = "Introns",
            GC_Content_pct = "GC %",
            CDS_to_Tx_pct = "CDS/Transcript %",
            Exonic_bp = "Exonic bp",
            CDS_bp = "CDS bp"
        )

        mat <- get_cached_analytics_metric_matrix(df_prepared, metrics_raw = metrics_raw, log_cols = log_cols)
        colnames(mat) <- short_lbl[metrics_raw]
        keep <- apply(mat, 2, function(x) {
            v <- x[is.finite(x)]
            if (length(v) < 3) {
                return(FALSE)
            }
            sd_v <- suppressWarnings(stats::sd(v))
            is.finite(sd_v) && sd_v > 0
        })
        mat <- mat[, keep, drop = FALSE]
        if (ncol(mat) < 2L) {
            scene <- list(status = "insufficient_metrics", df_cor = data.frame(stringsAsFactors = FALSE))
            cache_env_set(analyticsCorrSceneCache_env, cache_key, scene, max_size = 32L)
            return(scene)
        }

        cor_mat <- suppressWarnings(cor(
            mat,
            method = "pearson",
            use = "pairwise.complete.obs"
        ))

        interp_r <- function(r) {
            if (!is.finite(r)) {
                return("insufficient")
            }
            a <- abs(r)
            if (a > 0.9) {
                "very strong"
            } else if (a > 0.7) {
                "strong"
            } else if (a > 0.5) {
                "moderate"
            } else if (a > 0.3) {
                "weak"
            } else {
                "negligible"
            }
        }

        lv <- colnames(cor_mat)
        if (!identical(order_txt, "metric_default")) {
            lv_ord <- switch(order_txt,
                "metric_alpha_asc" = sort(lv),
                "metric_alpha_desc" = sort(lv, decreasing = TRUE),
                "mean_abs_corr_desc" = {
                    score <- rowMeans(abs(cor_mat - diag(ncol(cor_mat))), na.rm = TRUE)
                    names(sort(score, decreasing = TRUE))
                },
                "mean_abs_corr_asc" = {
                    score <- rowMeans(abs(cor_mat - diag(ncol(cor_mat))), na.rm = TRUE)
                    names(sort(score, decreasing = FALSE))
                },
                "cluster" = {
                    if (ncol(cor_mat) >= 3) {
                        hc <- stats::hclust(stats::as.dist(1 - abs(cor_mat)), method = "average")
                        lv[hc$order]
                    } else {
                        lv
                    }
                },
                lv
            )
            lv_ord <- lv_ord[lv_ord %in% lv]
            if (length(lv_ord) == length(lv)) {
                cor_mat <- cor_mat[lv_ord, lv_ord, drop = FALSE]
                lv <- lv_ord
            }
        }

        df_cor <- expand.grid(Var1 = lv, Var2 = lv, stringsAsFactors = FALSE)
        df_cor$r <- as.vector(cor_mat)
        df_cor$Var1 <- factor(df_cor$Var1, levels = lv)
        df_cor$Var2 <- factor(df_cor$Var2, levels = rev(lv))
        df_cor$var1_chr <- as.character(df_cor$Var1)
        df_cor$var2_chr <- as.character(df_cor$Var2)
        df_cor$r_round <- ifelse(is.finite(df_cor$r), round(df_cor$r, 3), NA_real_)
        df_cor$r_sign <- ifelse(!is.finite(df_cor$r), "", ifelse(df_cor$r >= 0, " positive", " negative"))
        df_cor$data_id <- paste0(df_cor$var1_chr, "_", df_cor$var2_chr)
        df_cor$tip <- ifelse(
            is.finite(df_cor$r),
            paste0(
                "<b>", df_cor$var1_chr, " \u00d7 ", df_cor$var2_chr, "</b><br/>",
                "r = <b>", df_cor$r_round, "</b><br/>",
                vapply(df_cor$r, interp_r, character(1)),
                df_cor$r_sign,
                " correlation"
            ),
            paste0(
                "<b>", df_cor$var1_chr, " \u00d7 ", df_cor$var2_chr, "</b><br/>",
                "r = <b>N/A</b><br/>insufficient overlapping observations"
            )
        )
        df_cor$r_lbl <- ifelse(
            as.character(df_cor$Var1) == as.character(df_cor$Var2),
            "1",
            ifelse(is.finite(df_cor$r), sprintf("%.2f", df_cor$r), "NA")
        )

        scene <- list(
            status = "ok",
            n_m = ncol(cor_mat),
            df_cor = df_cor,
            df_cor_ok = df_cor[is.finite(df_cor$r), , drop = FALSE],
            df_cor_na = df_cor[!is.finite(df_cor$r), , drop = FALSE]
        )
        cache_env_set(analyticsCorrSceneCache_env, cache_key, scene, max_size = 32L)
        scene
    }

    list(
        clear_analytics_cache_scope = clear_analytics_cache_scope,
        scientific_italic_unicode = scientific_italic_unicode,
        make_x_labels = make_x_labels,
        apply_analytics_order = apply_analytics_order,
        analytics_df_fingerprint = analytics_df_fingerprint,
        get_cached_analytics_prepared_df = get_cached_analytics_prepared_df,
        get_cached_analytics_metric_matrix = get_cached_analytics_metric_matrix,
        get_mode_plot_signatures = get_mode_plot_signatures,
        get_cached_exon_lengths_for_plot = get_cached_exon_lengths_for_plot,
        get_cached_intron_lengths_for_plot = get_cached_intron_lengths_for_plot,
        get_cached_scatter_prepared_df = get_cached_scatter_prepared_df,
        get_cached_radar_scene = get_cached_radar_scene,
        get_cached_corr_scene = get_cached_corr_scene
    )
}
