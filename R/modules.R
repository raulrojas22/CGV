# R/modules.R

# Plot module UI function (compartida por homólogos y ortólogos)
plotUIModule <- function(id) {
    ns <- NS(id)
    tagList(
        div(
            class = "promoter-plot-container",
            style = "width: 100%; height: 110px; margin: 0;",
            girafeOutput(ns("plot"), height = "110px", width = "100%")
        )
    )
}

# Aliases para compatibilidad con las llamadas en server.R
plotUIHomologous <- plotUIModule
plotUIOrtologous <- plotUIModule

# Defensive fallback for perf helpers.
if (!exists("app_perf_new_run", mode = "function")) {
    app_perf_new_run <- function(prefix = "RUN") {
        p <- as.character(prefix)
        if (length(p) == 0 || is.na(p[1]) || !nzchar(trimws(p[1]))) {
            p <- "RUN"
        } else {
            p <- trimws(p[1])
        }
        list(
            id = paste0(p, "-fallback"),
            t0 = as.numeric(proc.time()[["elapsed"]])
        )
    }
}
if (!exists("app_perf_mark", mode = "function")) {
    app_perf_mark <- function(run = NULL, step = "", context = "APP") {
        invisible(NA_real_)
    }
}
if (!exists("refresh_girafe_widget_uid", mode = "function")) {
    .next_girafe_uid_local <- local({
        counter <- 0L
        function() {
            counter <<- counter + 1L
            ts_ms <- suppressWarnings(as.integer(round(as.numeric(Sys.time()) * 1000)))
            if (!is.finite(ts_ms)) {
                ts_ms <- as.integer(counter)
            }
            paste0("svg_", ts_ms, "_", counter)
        }
    })
    refresh_girafe_widget_uid <- function(widget_obj) {
        if (is.null(widget_obj)) return(widget_obj)
        if (!inherits(widget_obj, "girafe")) return(widget_obj)
        out <- widget_obj
        if (is.list(out$x)) {
            old_uid <- trimws(as.character(out$x$uid %||% ""))
            new_uid <- .next_girafe_uid_local()
            if (nzchar(old_uid) && nzchar(new_uid) && !identical(old_uid, new_uid)) {
                if (is.character(out$x$html) && length(out$x$html) > 0L) {
                    out$x$html <- gsub(old_uid, new_uid, out$x$html, fixed = TRUE)
                }
                if (is.character(out$x$js) && length(out$x$js) > 0L) {
                    out$x$js <- gsub(old_uid, new_uid, out$x$js, fixed = TRUE)
                }
            }
            out$x$uid <- new_uid
        }
        out
    }
}

# Función auxiliar para procesar datos del gen (compartida)
process_gene_data <- function(data) {
  # Eliminamos el tidyr::separate. Nos quedamos solo con lo necesario.
  df_separated <- data %>%
    mutate(V3_norm = tolower(stringr::str_trim(V3)))
  
  df_gene <- df_separated %>% filter(V3_norm == "gene")
  
  tx_level_types <- c(
    "mrna", "transcript", "lnc_rna", "trna", "rrna", "snorna", "snrna", "mirna",
    "ncrna", "primary_transcript", "pre_mirna", "guide_rna", "rnase_p_rna",
    "rnase_mrp_rna", "telomerase_rna", "antisense_rna", "srp_rna", "scarna",
    "vault_rna", "y_rna", "antisense_lncrna", "lncrna"
  )
  df_transcript <- df_separated %>% filter(V3_norm %in% tx_level_types)
  
  df_other <- df_separated %>%
    filter(V3_norm %in% c("exon", "cds", "start_codon", "stop_codon") | grepl("utr", V3_norm)) %>%
    mutate(
      group = case_when(
        V3_norm == "exon" ~ "exon",
        V3_norm == "cds" ~ "cds",
        V3_norm %in% c("start_codon", "stop_codon") ~ "codon",
        grepl("utr", V3_norm) ~ "utr",
        TRUE ~ "other"
      ),
      text = gsub(";", "\n", V9) 
    )
  
  if (nrow(df_other) == 0 && nrow(df_gene) > 0) {
    df_other <- df_gene %>% mutate(group = "gene", V3_norm = "gene", text = gsub(";", "\n", V9))
  }
  
  df <- data.frame(
    y = rep(1, nrow(df_other)),
    xstart = as.numeric(df_other$V4),
    xend = as.numeric(df_other$V5),
    group = factor(df_other$group),
    text = df_other$text,
    feature_type = as.character(df_other$V3_norm),
    seqid = as.character(df_other$V1),
    source = as.character(df_other$V2),
    feature_raw = as.character(df_other$V3),
    score = as.character(df_other$V6),
    strand = as.character(df_other$V7),
    phase = as.character(df_other$V8),
    attributes_raw = as.character(df_other$V9) # Conservamos el V9 intacto aquí
  )
  
  df$largo <- df$xend - df$xstart + 1
  df_gene$largo <- as.numeric(df_gene$V5) - as.numeric(df_gene$V4) + 1
  
  list(df = df, df_gene = df_gene, df_transcript = df_transcript)
}

truncate_neighbor_label <- function(x, max_chars = 18) {
    x <- as.character(x %||% "None")
    x <- trimws(utils::URLdecode(x))
    x <- str_remove(x, regex("^(transcript|gene)\\s*:\\s*", ignore_case = TRUE))
    if (!nzchar(x)) {
        return("None")
    }
    if (nchar(x) <= max_chars) {
        return(x)
    }
    paste0(substr(x, 1, max_chars - 3), "...")
}

extract_composition_percentages <- function(composition_label) {
    lbl <- as.character(composition_label %||% "")
    if (!nzchar(lbl) || grepl("N/A", lbl, ignore.case = TRUE)) {
        return(NULL)
    }
    bases <- c("A", "T", "C", "G")
    vals <- vapply(bases, function(b) {
        m <- str_match(lbl, paste0("\\b", b, "\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)%"))
        if (is.na(m[1, 2])) NA_real_ else as.numeric(m[1, 2])
    }, numeric(1))
    if (any(!is.finite(vals))) {
        return(NULL)
    }
    data.frame(base = bases, pct = vals, stringsAsFactors = FALSE)
}

# Función auxiliar para crear el gráfico (compartida)
create_gene_plot <- function(df, df_gene, df_transcript = NULL, current_transcript_length, length_difference, composicion_secuencia, gene_length_label, transcript_length_label, neighbor_context = NULL, visual_mode = "compact", width_svg = 22, height_svg = 1.75, organism_label = NULL, annotation_file_path = NULL, use_report_map = FALSE, report_path = "", plot_id = NULL, plot_context = NULL, genome_fasta_path = NULL, is_dark_theme = FALSE, is_colorblind_mode = FALSE, gene_display_name = NULL) {
    visual_mode <- match.arg(visual_mode, c("compact", "detailed"))
    plot_perf <- app_perf_new_run(sprintf("PLOT_BUILD-%s", as.character(plot_id %||% "NA")))
    app_perf_mark(plot_perf, sprintf("start mode=%s", visual_mode), "PLOT_BUILD")
    df <- df %>% filter(is.finite(xstart), is.finite(xend))
    df_gene <- df_gene %>%
        mutate(V4 = as.numeric(V4), V5 = as.numeric(V5)) %>%
        filter(is.finite(V4), is.finite(V5))
    if (is.null(df_transcript) || nrow(df_transcript) == 0) {
        df_transcript <- data.frame()
    } else {
        df_transcript <- df_transcript %>%
            mutate(V4 = suppressWarnings(as.numeric(V4)), V5 = suppressWarnings(as.numeric(V5)))
    }
    app_perf_mark(plot_perf, "data normalize done", "PLOT_BUILD")
    is_dark_theme <- isTRUE(is_dark_theme)
    is_colorblind_mode <- isTRUE(is_colorblind_mode)
    gene_line_color <- if (is_dark_theme) "#C7D6E4" else "#2C3E50"
    gene_direction_color <- if (is_dark_theme) "#9EB2C4" else "#97A6B2"
    center_label_col <- if (is_dark_theme) "#E6F0FA" else "#4B6072"
    panel_bg_fill <- if (is_dark_theme) "#102438" else "#FFFFFF"
    format_bp <- function(x) format(as.integer(round(x)), big.mark = ",", scientific = FALSE, trim = TRUE)
    pick_first_value <- function(...) {
        vals <- list(...)
        for (v in vals) {
            vv <- as.character(v %||% "")
            if (length(vv) > 0 && !is.na(vv[1]) && nzchar(trimws(vv[1]))) {
                return(vv[1])
            }
        }
        "N/A"
    }
    esc_html <- function(x) {
        out <- as.character(x %||% "")
        out <- gsub("&", "&amp;", out, fixed = TRUE)
        out <- gsub("<", "&lt;", out, fixed = TRUE)
        out <- gsub(">", "&gt;", out, fixed = TRUE)
        out
    }
    genome_fasta_path <- trimws(as.character(genome_fasta_path %||% ""))
    has_gc_source <- nzchar(genome_fasta_path) && file.exists(genome_fasta_path)
    is_compact_mode <- identical(visual_mode, "compact")
    needs_feature_gc <- isTRUE(has_gc_source)
    format_gc_pct <- function(gc_pct) {
        if (!is.finite(gc_pct)) {
            return("N/A")
        }
        sprintf("%.2f%%", as.numeric(gc_pct))
    }
    calc_gc_pct <- function(seq_txt) {
        seq_txt <- toupper(gsub("\\s+", "", as.character(seq_txt %||% "")))
        if (!nzchar(seq_txt)) {
            return(NA_real_)
        }
        known_bases <- gsub("[^ATCG]", "", seq_txt)
        known_total <- nchar(known_bases)
        if (known_total <= 0) {
            return(NA_real_)
        }
        gc_count <- nchar(gsub("[^GC]", "", known_bases))
        round(100 * gc_count / known_total, 2)
    }
    calc_gc_pct_batch <- function(seqs) {
        seqs <- toupper(gsub("\\s+", "", as.character(seqs)))
        known <- gsub("[^ATCG]", "", seqs)
        known_total <- nchar(known)
        gc_count <- nchar(gsub("[^GC]", "", known))
        result <- ifelse(known_total > 0L, round(100 * gc_count / known_total, 2), NA_real_)
        result[!nzchar(seqs)] <- NA_real_
        result
    }
    batch_gc_pct <- function(starts, ends) {
        if (!nzchar(full_transcript_seq)) return(rep(NA_real_, length(starts)))
        start_i <- as.integer(round(pmin(starts, ends)))
        end_i <- as.integer(round(pmax(starts, ends)))
        rel_start <- start_i - transcript_min + 1L
        rel_end <- end_i - transcript_min + 1L
        seq_len_total <- nchar(full_transcript_seq)
        valid <- rel_start >= 1L & rel_end <= seq_len_total
        result <- rep(NA_real_, length(starts))
        if (any(valid)) {
            seqs <- substring(full_transcript_seq, rel_start[valid], rel_end[valid])
            result[valid] <- calc_gc_pct_batch(seqs)
        }
        result
    }
    transcript_min <- min(df$xstart, na.rm = TRUE)
    transcript_max <- max(df$xend, na.rm = TRUE)

    full_transcript_seq <- ""
    if (isTRUE(needs_feature_gc) && is.finite(transcript_min) && is.finite(transcript_max)) {
      full_transcript_seq <- tryCatch(
        extract_sequence_from_fasta(genome_fasta_path, df$seqid[1], as.integer(transcript_min), as.integer(transcript_max)),
        error = function(e) ""
      )
    }
    app_perf_mark(plot_perf, sprintf("gc source ready len=%d", as.integer(nchar(full_transcript_seq %||% ""))), "PLOT_BUILD")

    get_feature_gc_pct <- function(seqid, start_pos, end_pos) {
      if (!nzchar(full_transcript_seq)) return(NA_real_)
      
      start_i <- as.integer(round(min(start_pos, end_pos)))
      end_i <- as.integer(round(max(start_pos, end_pos)))
      
      # Calcular índices relativos al bloque extraído
      rel_start <- start_i - transcript_min + 1
      rel_end <- end_i - transcript_min + 1
      
      # Validación para evitar errores si el exón sale del margen extraído
      if (rel_start < 1 || rel_end > nchar(full_transcript_seq)) return(NA_real_)
      
      seq_txt <- substr(full_transcript_seq, rel_start, rel_end)
      calc_gc_pct(seq_txt)
    }
    get_region_gc_pct <- function(start_pos, end_pos) {
      get_feature_gc_pct("", start_pos, end_pos)
    }
    feature_label_map <- function(ft) {
        ft <- tolower(trimws(as.character(ft %||% "")))
        case_when(
            ft == "exon" ~ "EXON",
            ft == "cds" ~ "CDS",
            ft == "start_codon" ~ "START CODON",
            ft == "stop_codon" ~ "STOP CODON",
            grepl("utr", ft) ~ "UTR",
            TRUE ~ toupper(ft)
        )
    }
    feature_priority_map <- function(ft) {
        ft <- tolower(trimws(as.character(ft %||% "")))
        case_when(
            ft == "exon" ~ 5,
            ft == "cds" ~ 4,
            grepl("utr", ft) ~ 3,
            ft %in% c("start_codon", "stop_codon") ~ 2,
            TRUE ~ 1
        )
    }

    extract_feature_id <- function(attr_txt) {
        attrs <- parse_gff_attributes(as.character(attr_txt %||% ""))
        pick_first_value(
            attrs[["id"]][1],
            attrs[["name"]][1],
            attrs[["gene_id"]][1],
            attrs[["transcript_id"]][1],
            attrs[["parent"]][1]
        )
    }

    format_attr_lines <- function(attrs, exclude_keys = character()) {
        keys <- names(attrs)
        keys <- keys[!is.na(keys) & nzchar(keys)]
        if (length(keys) == 0) {
            return(character())
        }
        if (length(exclude_keys) > 0) {
            keys <- keys[!(tolower(keys) %in% tolower(exclude_keys))]
        }
        if (length(keys) == 0) {
            return(character())
        }
        vapply(keys, function(k) {
            vals <- attrs[[k]]
            vals <- vals[!is.na(vals) & nzchar(trimws(vals))]
            val_txt <- if (length(vals) == 0) "N/A" else paste(unique(vals), collapse = ", ")
            lbl <- stringr::str_to_title(gsub("_", " ", k))
            sprintf("<b>%s:</b> %s", esc_html(lbl), esc_html(val_txt))
        }, character(1))
    }

    if (identical(visual_mode, "compact")) {
        df <- df %>%
            mutate(
                feature_type_norm = tolower(trimws(as.character(feature_type))),
                feature_uid = paste0("feature_", seq_len(n()))
            )
    } else {
        df <- df %>%
            mutate(
                feature_type_norm = tolower(trimws(as.character(feature_type))),
                feature_label = feature_label_map(feature_type_norm),
                feature_priority = feature_priority_map(feature_type_norm),
                feature_draw_rank = case_when(
                    feature_type_norm == "exon" ~ 1,
                    feature_type_norm == "cds" ~ 2,
                    grepl("utr", feature_type_norm) ~ 3,
                    feature_type_norm %in% c("start_codon", "stop_codon") ~ 4,
                    TRUE ~ 5
                )
            ) %>%
            arrange(feature_draw_rank, xstart, xend) %>%
            mutate(feature_uid = paste0("feature_", row_number()))
    }
    # Parse GFF attributes ONCE per feature in detailed mode.
    # feature_attrs_cache is computed first so both feature_id extraction and
    # tooltip building can reuse the already-parsed list, avoiding a second full
    # lapply(parse_gff_attributes) pass that was previously duplicating this work.
    feature_attrs_cache <- if (identical(visual_mode, "detailed")) {
        lapply(df$attributes_raw, function(attr_txt) {
            parse_gff_attributes(as.character(attr_txt %||% ""))
        })
    } else {
        vector("list", nrow(df))
    }
    df$feature_id <- if (identical(visual_mode, "detailed")) {
        vapply(seq_len(nrow(df)), function(i) {
            attrs <- feature_attrs_cache[[i]]
            pick_first_value(
                attrs[["id"]][1],
                attrs[["name"]][1],
                attrs[["gene_id"]][1],
                attrs[["transcript_id"]][1],
                attrs[["parent"]][1]
            )
        }, character(1))
    } else {
        rep("N/A", nrow(df))
    }
    if (isTRUE(needs_feature_gc) && !isTRUE(is_compact_mode)) {
        df$gc_pct <- batch_gc_pct(df$xstart, df$xend)
        df$gc_label <- ifelse(is.finite(df$gc_pct), sprintf("%.2f%%", df$gc_pct), "N/A")
    } else {
        df$gc_pct <- rep(NA_real_, nrow(df))
        df$gc_label <- rep("N/A", nrow(df))
    }

    overlap_tol_bp <- 2
    app_perf_mark(plot_perf, "feature typing done", "PLOT_BUILD")
    build_overlap_html <- function(idx) {
        idx <- as.integer(idx)
        idx <- idx[idx >= 1 & idx <= nrow(df)]
        if (length(idx) == 0) {
            return("<b style='color:var(--app-message-accent);font-weight:700;'>Feature In This Region</b><br/>N/A")
        }
        if (!identical(visual_mode, "detailed")) {
            feature_count <- length(idx)
            exon_n <- sum(df$feature_type_norm[idx] == "exon", na.rm = TRUE)
            cds_n <- sum(df$feature_type_norm[idx] == "cds", na.rm = TRUE)
            utr_n <- sum(grepl("utr", df$feature_type_norm[idx]), na.rm = TRUE)
            codon_n <- sum(df$feature_type_norm[idx] %in% c("start_codon", "stop_codon"), na.rm = TRUE)
            region_gc <- get_region_gc_pct(min(df$xstart[idx], na.rm = TRUE), max(df$xend[idx], na.rm = TRUE))
            gc_txt <- format_gc_pct(region_gc)
            return(
                paste0(
                    "<b style='color:var(--app-message-accent);font-weight:700;'>Features In This Region</b><br/>",
                    "<b>Total Features:</b> ", as.integer(feature_count), "<br/>",
                    "<b>Exons:</b> ", as.integer(exon_n), "<br/>",
                    "<b>CDS:</b> ", as.integer(cds_n), "<br/>",
                    "<b>UTR:</b> ", as.integer(utr_n), "<br/>",
                    "<b>Codons:</b> ", as.integer(codon_n), "<br/>",
                    "<b>%GC (mean):</b> ", gc_txt
                )
            )
        }
        idx <- idx[order(-df$feature_priority[idx], df$xstart[idx], df$xend[idx], df$feature_label[idx])]
        attrs_list <- feature_attrs_cache[idx]
        sep_html <- "<br/><hr style='border:none;border-top:1px solid #B6CCC6;margin:5px 0;'/>"
        shared_keys <- character()
        shared_lines <- character()
        if (length(idx) > 1) {
            key_lists <- lapply(attrs_list, function(a) names(a)[!is.na(names(a)) & nzchar(names(a))])
            common_keys <- if (length(key_lists) > 0) Reduce(intersect, key_lists) else character()
            if (length(common_keys) > 0) {
                shared_lines <- vapply(common_keys, function(k) {
                    vals_per_feature <- lapply(attrs_list, function(a) {
                        v <- a[[k]]
                        v <- v[!is.na(v) & nzchar(trimws(v))]
                        sort(unique(v))
                    })
                    sig <- vapply(vals_per_feature, function(v) paste(v, collapse = " | "), character(1))
                    if (length(sig) == 0 || any(!nzchar(sig))) {
                        return(NA_character_)
                    }
                    if (length(unique(sig)) != 1) {
                        return(NA_character_)
                    }
                    lbl <- stringr::str_to_title(gsub("_", " ", k))
                    sprintf("<b>%s:</b> %s", esc_html(lbl), esc_html(sig[1]))
                }, character(1))
                keep_shared <- !is.na(shared_lines)
                shared_lines <- shared_lines[keep_shared]
                shared_keys <- common_keys[keep_shared]
            }
        }
        feature_blocks <- vapply(seq_along(idx), function(k) {
            j <- idx[k]
            fid <- as.character(df$feature_id[j] %||% "N/A")
            sid <- if (is.na(fid) || !nzchar(trimws(fid)) || fid == "N/A") "N/A" else esc_html(fid)

            feature_attr_lines <- format_attr_lines(attrs_list[[k]], exclude_keys = shared_keys)
            if (length(feature_attr_lines) == 0) {
                raw_txt <- utils::URLdecode(as.character(df$attributes_raw[j] %||% ""))
                raw_txt <- trimws(raw_txt)
                if (nzchar(raw_txt)) {
                    feature_attr_lines <- sprintf("<b>Raw Attributes:</b> %s", esc_html(raw_txt))
                }
            }
            feature_attr_block <- if (length(feature_attr_lines) == 0) {
                "<b>Feature Attributes:</b> N/A"
            } else {
                paste0("<b>Feature Attributes:</b><br/>", paste(feature_attr_lines, collapse = "<br/>"))
            }
            sprintf(
                "<b style='color:var(--app-message-accent);font-weight:700;'>%s</b><br/><b>Start:</b> %s<br/><b>End:</b> %s<br/><b>ID:</b> %s<br/><b>GC:</b> %s<br/>%s",
                esc_html(df$feature_label[j]),
                format_bp(df$xstart[j]),
                format_bp(df$xend[j]),
                sid,
                df$gc_label[j],
                feature_attr_block
            )
        }, character(1))
        feature_blocks <- unique(feature_blocks)
        shared_block <- if (length(shared_lines) > 0) {
            paste0(
                sep_html,
                "<b style='color:var(--app-message-accent);font-weight:700;'>Shared Attributes</b><br/>",
                paste(shared_lines, collapse = "<br/>")
            )
        } else {
            ""
        }
        title_txt <- if (length(idx) > 1) "Overlapping Features In This Region" else "Feature In This Region"
        paste0(
            "<b style='color:var(--app-message-accent);font-weight:700;'>", title_txt, "</b><br/>",
            paste(feature_blocks, collapse = sep_html),
            shared_block
        )
    }
    app_perf_mark(plot_perf, "tooltip builders ready", "PLOT_BUILD")

    build_single_feature_attr_block <- function(attrs, attr_txt) {
        attr_lines <- format_attr_lines(attrs)
        if (length(attr_lines) > 0) {
            return(paste0("<b>Feature Attributes:</b><br/>", paste(attr_lines, collapse = "<br/>")))
        }
        raw_txt <- utils::URLdecode(as.character(attr_txt %||% ""))
        raw_txt <- trimws(raw_txt)
        if (nzchar(raw_txt)) {
            return(sprintf("<b>Raw Attributes:</b> %s", esc_html(raw_txt)))
        }
        "<b>Feature Attributes:</b> N/A"
    }
    if (identical(visual_mode, "detailed")) {
        feature_attr_html <- vapply(seq_len(nrow(df)), function(i) {
            build_single_feature_attr_block(feature_attrs_cache[[i]], df$attributes_raw[i])
        }, character(1))

        df <- df %>%
            mutate(
                # Solo exón/CDS muestran atributos completos; el resto usa tooltip liviano.
                tooltip_html_detailed = case_when(
                    feature_type_norm %in% c("exon", "cds") ~ sprintf(
                        "<b style='color:var(--app-message-accent);font-weight:700;'>%s</b><br/><b>Seqid:</b> %s<br/><b>Source:</b> %s<br/><b>Type:</b> %s<br/><b>Start:</b> %s<br/><b>End:</b> %s<br/><b>Score:</b> %s<br/><b>Strand:</b> %s<br/><b>Phase:</b> %s<br/><b>Length:</b> %s bp<br/><b>GC:</b> %s<br/><hr style='border:none;border-top:1px solid #B6CCC6;margin:5px 0;'/>%s",
                        feature_label, esc_html(seqid), esc_html(source), esc_html(feature_raw), format_bp(xstart), format_bp(xend), esc_html(score), esc_html(strand), esc_html(phase), format_bp(largo), gc_label, feature_attr_html
                    ),
                    TRUE ~ sprintf(
                        "<b style='color:var(--app-message-accent);font-weight:700;'>%s</b><br/><b>Start:</b> %s<br/><b>End:</b> %s<br/><b>Length:</b> %s bp<br/><b>GC:</b> %s",
                        feature_label, format_bp(xstart), format_bp(xend), format_bp(largo), gc_label
                    )
                )
            )
    } else {
        df$tooltip_html_detailed <- rep("", nrow(df))
    }

    # Build intron segments from exon features only (not CDS/UTR).
    row_ft <- tolower(as.character(df$feature_type %||% rep("", nrow(df))))
    exon_mask <- row_ft == "exon"
    intron_df <- data.frame()
    if (any(exon_mask)) {
        exon_ranges <- data.frame(
            seqid = as.character(df$seqid[exon_mask]),
            xstart = suppressWarnings(as.numeric(df$xstart[exon_mask])),
            xend = suppressWarnings(as.numeric(df$xend[exon_mask])),
            stringsAsFactors = FALSE
        )
        keep_ex <- !is.na(exon_ranges$seqid) &
            nzchar(exon_ranges$seqid) &
            is.finite(exon_ranges$xstart) &
            is.finite(exon_ranges$xend)
        exon_ranges <- exon_ranges[keep_ex, , drop = FALSE]
        if (nrow(exon_ranges) > 1) {
            ord_ex <- order(exon_ranges$seqid, exon_ranges$xstart, exon_ranges$xend)
            exon_ranges <- exon_ranges[ord_ex, , drop = FALSE]
            exon_ranges <- exon_ranges[!duplicated(paste(exon_ranges$seqid, exon_ranges$xstart, exon_ranges$xend, sep = "::")), , drop = FALSE]
            if (nrow(exon_ranges) > 1) {
                prev_seqid <- exon_ranges$seqid[-nrow(exon_ranges)]
                prev_xend <- exon_ranges$xend[-nrow(exon_ranges)]
                curr_seqid <- exon_ranges$seqid[-1]
                curr_xstart <- exon_ranges$xstart[-1]
                gap_keep <- (curr_seqid == prev_seqid) & (curr_xstart > (prev_xend + 1))
                if (any(gap_keep)) {
                    intron_start_bp <- as.integer(round(prev_xend[gap_keep] + 1))
                    intron_end_bp <- as.integer(round(curr_xstart[gap_keep] - 1))
                    intron_bp <- as.integer(round(curr_xstart[gap_keep] - prev_xend[gap_keep] - 1))
                    intron_tmp <- data.frame(
                        seqid = curr_seqid[gap_keep],
                        intron_start = as.numeric(prev_xend[gap_keep] + 1),
                        intron_end = as.numeric(curr_xstart[gap_keep] - 1),
                        intron_start_bp = intron_start_bp,
                        intron_end_bp = intron_end_bp,
                        intron_bp = intron_bp,
                        stringsAsFactors = FALSE
                    )
                    keep_intron_tmp <- is.finite(intron_tmp$intron_start) &
                        is.finite(intron_tmp$intron_end) &
                        (intron_tmp$intron_end >= intron_tmp$intron_start) &
                        is.finite(intron_tmp$intron_bp) &
                        (intron_tmp$intron_bp > 0)
                    intron_tmp <- intron_tmp[keep_intron_tmp, , drop = FALSE]
                    if (nrow(intron_tmp) > 0) {
                        if (isTRUE(needs_feature_gc)) {
                            intron_gc <- batch_gc_pct(intron_tmp$intron_start_bp, intron_tmp$intron_end_bp)
                            intron_gc_label <- ifelse(is.finite(intron_gc), sprintf("%.2f%%", intron_gc), "N/A")
                        } else {
                            intron_gc_label <- rep("N/A", nrow(intron_tmp))
                        }
                        intron_tmp$tooltip <- sprintf(
                            "<b style='color:var(--app-message-accent);font-weight:700;'>INTRON</b><br/><b>Start:</b> %s<br/><b>End:</b> %s<br/><b>Length:</b> %s bp<br/><b>GC:</b> %s",
                            format(as.integer(round(intron_tmp$intron_start_bp)), big.mark = ","),
                            format(as.integer(round(intron_tmp$intron_end_bp)), big.mark = ","),
                            format(as.integer(round(intron_tmp$intron_bp)), big.mark = ","),
                            intron_gc_label
                        )
                        intron_tmp$data_id <- paste0("intron_", seq_len(nrow(intron_tmp)))
                        intron_df <- intron_tmp[, c("intron_start", "intron_end", "intron_bp", "tooltip", "data_id"), drop = FALSE]
                    }
                }
            }
        }
    }
    app_perf_mark(plot_perf, sprintf("introns done n=%d", as.integer(nrow(intron_df))), "PLOT_BUILD")
    if (nrow(intron_df) > 0) {
        intron_df$tooltip <- as.character(intron_df$tooltip)
        intron_df$data_id <- as.character(intron_df$data_id)
        keep_intron <- is.finite(intron_df$intron_start) &
            is.finite(intron_df$intron_end) &
            (intron_df$intron_end > intron_df$intron_start) &
            !is.na(intron_df$tooltip) &
            nzchar(trimws(intron_df$tooltip)) &
            !is.na(intron_df$data_id) &
            nzchar(trimws(intron_df$data_id))
        intron_df <- intron_df[keep_intron, , drop = FALSE]
    }

    merge_overlapping_ranges <- function(starts, ends) {
        starts <- as.numeric(starts)
        ends <- as.numeric(ends)
        keep <- is.finite(starts) & is.finite(ends)
        starts <- starts[keep]
        ends <- ends[keep]
        if (length(starts) == 0) {
            return(data.frame(xstart = numeric(0), xend = numeric(0), stringsAsFactors = FALSE))
        }
        ord <- order(starts, ends)
        starts <- starts[ord]
        ends <- ends[ord]
        merged_start <- numeric(0)
        merged_end <- numeric(0)
        cur_start <- starts[1]
        cur_end <- ends[1]
        if (length(starts) > 1) {
            for (k in 2:length(starts)) {
                if (starts[k] <= cur_end) {
                    cur_end <- max(cur_end, ends[k])
                } else {
                    merged_start <- c(merged_start, cur_start)
                    merged_end <- c(merged_end, cur_end)
                    cur_start <- starts[k]
                    cur_end <- ends[k]
                }
            }
        }
        merged_start <- c(merged_start, cur_start)
        merged_end <- c(merged_end, cur_end)
        data.frame(xstart = merged_start, xend = merged_end, stringsAsFactors = FALSE)
    }

    structure_y_offset <- 0
    structure_y_base <- 1 + structure_y_offset

    df_rect <- if (visual_mode == "compact") {
        compact_rects <- merge_overlapping_ranges(df$xstart, df$xend)
        if (nrow(compact_rects) > 0) {
            compact_rects$plot_group <- "compact"
            compact_rects$ymin_feat <- 0.952
            compact_rects$ymax_feat <- 1.048
            compact_rects$feature_uid <- paste0("compact_region_", seq_len(nrow(compact_rects)))
            # Pre-assign features to merged rects in O(n*m) but with vectorized ops
            # instead of per-rect which() calls. For each feature, find which merged
            # rect(s) it overlaps using vectorized comparisons.
            feature_to_rect <- if (nrow(df) > 0 && nrow(compact_rects) > 0) {
                # Use findInterval on sorted compact_rects$xstart for O(n log m)
                # Each feature overlaps rect i if: df$xend >= compact_rects$xstart[i] - tol AND df$xstart <= compact_rects$xend[i] + tol
                rect_assignments <- vector("list", nrow(compact_rects))
                for (i in seq_len(nrow(compact_rects))) {
                    rect_assignments[[i]] <- integer(0)
                }
                for (j in seq_len(nrow(df))) {
                    # Binary search: find first rect whose xstart <= df$xend[j] + tol
                    candidate <- findInterval(df$xstart[j], compact_rects$xend + overlap_tol_bp + 1L)
                    start_rect <- candidate + 1L
                    if (start_rect <= nrow(compact_rects)) {
                        for (i in start_rect:nrow(compact_rects)) {
                            if (compact_rects$xstart[i] - overlap_tol_bp > df$xend[j]) break
                            rect_assignments[[i]] <- c(rect_assignments[[i]], j)
                        }
                    }
                }
                rect_assignments
            } else {
                vector("list", nrow(compact_rects))
            }
            compact_rects$plot_tooltip <- vapply(seq_len(nrow(compact_rects)), function(i) {
                idx <- feature_to_rect[[i]]
                region_length <- as.numeric(compact_rects$xend[i] - compact_rects$xstart[i] + 1)
                paste0(
                    "<b style='color:var(--app-message-accent);font-weight:700;'>Merged Gene Region</b><br/>",
                    "<b>Start:</b> ", format_bp(compact_rects$xstart[i]), "<br/>",
                    "<b>End:</b> ", format_bp(compact_rects$xend[i]), "<br/>",
                    "<b>Length:</b> ", format_bp(region_length), " bp<br/>",
                    "<hr style='border:none;border-top:1px solid #B6CCC6;margin:5px 0;'/>",
                    build_overlap_html(idx)
                )
            }, character(1))
        } else {
            compact_rects <- data.frame(
                xstart = numeric(0), xend = numeric(0),
                plot_group = character(0),
                ymin_feat = numeric(0), ymax_feat = numeric(0),
                feature_uid = character(0),
                plot_tooltip = character(0),
                stringsAsFactors = FALSE
            )
        }
        compact_rects
    } else {
        df %>%
            mutate(
                plot_group = case_when(
                    feature_type_norm == "gene" ~ "gene",
                    feature_type_norm == "exon" ~ "exon",
                    feature_type_norm == "cds" ~ "cds",
                    grepl("utr", feature_type_norm) ~ "utr",
                    feature_type_norm %in% c("start_codon", "stop_codon") ~ "codon",
                    TRUE ~ "other"
                ),
                ymin_feat = case_when(
                    feature_type_norm == "exon" ~ 0.960,
                    feature_type_norm == "cds" ~ 0.915,
                    grepl("utr", feature_type_norm) ~ 0.870,
                    feature_type_norm %in% c("start_codon", "stop_codon") ~ 0.825,
                    TRUE ~ 0.780
                ),
                ymax_feat = case_when(
                    feature_type_norm == "exon" ~ 1.040,
                    feature_type_norm == "cds" ~ 0.955,
                    grepl("utr", feature_type_norm) ~ 0.910,
                    feature_type_norm %in% c("start_codon", "stop_codon") ~ 0.865,
                    TRUE ~ 0.820
                ),
                ymin_feat = ymin_feat + structure_y_offset,
                ymax_feat = ymax_feat + structure_y_offset,
                plot_tooltip = tooltip_html_detailed
            ) %>%
            arrange(feature_draw_rank, xstart, xend)
    }
    app_perf_mark(plot_perf, sprintf("rectangles done n=%d", as.integer(nrow(df_rect))), "PLOT_BUILD")
    if (nrow(df_rect) > 0) {
        df_rect$plot_tooltip <- as.character(df_rect$plot_tooltip)
        df_rect$feature_uid <- as.character(df_rect$feature_uid)
        keep_rect <- is.finite(df_rect$xstart) &
            is.finite(df_rect$xend) &
            is.finite(df_rect$ymin_feat) &
            is.finite(df_rect$ymax_feat) &
            (df_rect$xend > df_rect$xstart) &
            !is.na(df_rect$plot_tooltip) &
            nzchar(trimws(df_rect$plot_tooltip)) &
            !is.na(df_rect$feature_uid) &
            nzchar(trimws(df_rect$feature_uid))
        df_rect <- df_rect[keep_rect, , drop = FALSE]
    }
    app_perf_mark(
        plot_perf,
        sprintf("features ready rect=%d intron=%d", as.integer(nrow(df_rect)), as.integer(nrow(intron_df))),
        "PLOT_BUILD"
    )

    custom_colors <- get_transcript_feature_palette(
        is_dark_theme = is_dark_theme,
        is_colorblind_mode = is_colorblind_mode
    )
    if (visual_mode == "compact") {
        neighbor_rule_col <- "#5F7282"
        neighbor_dash_col <- gene_direction_color
        promoter_dash_col <- "#2C93AB"
        neighbor_tick_col <- "#70818D"
        neighbor_label_col <- "#4F6270"
        neighbor_tick_size <- 3.2
        neighbor_name_size <- 3.4
        center_gene_size <- 4.1
        center_gene_label_y <- 1.102
        neighbor_gene_label_y <- 0.935
        neighbor_dist_size <- 2.7
        neighbor_marker_size <- 2.8
        neighbor_marker_fill <- "#5D8FB8"
        neighbor_marker_col <- "#3A6D95"
        neighbor_marker_stroke <- 0.42
    } else {
        neighbor_rule_col <- "#34495E"
        neighbor_dash_col <- gene_direction_color
        promoter_dash_col <- "#2587A3"
        neighbor_tick_col <- "#5D6D7E"
        neighbor_label_col <- "#2C3E50"
        neighbor_tick_size <- 3.4
        neighbor_name_size <- 3.6
        center_gene_size <- 4.3
        center_gene_label_y <- 1.108
        neighbor_gene_label_y <- 0.939 + structure_y_offset
        neighbor_dist_size <- 2.9
        neighbor_marker_size <- 3.0
        neighbor_marker_fill <- "#2C7FB8"
        neighbor_marker_col <- "#1B4F72"
        neighbor_marker_stroke <- 0.46
    }
    if (is_dark_theme) {
        neighbor_rule_col <- "#9BB3C7"
        neighbor_dash_col <- "#AFC2D2"
        promoter_dash_col <- "#5DBED6"
        neighbor_tick_col <- "#D7E4F0"
        neighbor_label_col <- "#EAF2FB"
        neighbor_marker_fill <- "#76AFD8"
        neighbor_marker_col <- "#BCD2E6"
    }

    target_start <- suppressWarnings(min(df$xstart, na.rm = TRUE))
    target_end <- suppressWarnings(max(df$xend, na.rm = TRUE))
    if (!is.finite(target_start) || !is.finite(target_end) || target_end <= target_start) {
        target_start <- suppressWarnings(min(df_gene$V4, na.rm = TRUE))
        target_end <- suppressWarnings(max(df_gene$V5, na.rm = TRUE))
    }
    if (!is.finite(target_start) || !is.finite(target_end) || target_end <= target_start) {
        target_start <- suppressWarnings(min(as.numeric(df_transcript$V4), na.rm = TRUE))
        target_end <- suppressWarnings(max(as.numeric(df_transcript$V5), na.rm = TRUE))
    }
    if (!is.finite(target_start) || !is.finite(target_end) || target_end <= target_start) {
        target_start <- suppressWarnings(min(as.numeric(df$xstart), na.rm = TRUE))
        target_end <- suppressWarnings(max(as.numeric(df$xend), na.rm = TRUE))
    }
    if (!is.finite(current_transcript_length) || current_transcript_length <= 0) {
        current_transcript_length <- as.numeric(target_end - target_start + 1)
    }
    gene_strand <- pick_first_value(
        if (nrow(df_gene) > 0) df_gene$V7[1] else NA_character_,
        if (nrow(df_transcript) > 0) df_transcript$V7[1] else NA_character_,
        if (nrow(df) > 0) df$strand[1] else NA_character_,
        "+"
    )
    gene_strand <- trimws(as.character(gene_strand %||% "+"))
    if (!gene_strand %in% c("+", "-")) gene_strand <- "+"

    # Use symmetric virtual extension so scaling does not leave a visible right-side tail.
    total_plot_length <- current_transcript_length + length_difference
    symmetric_extension <- max(0, length_difference) / 2
    virtual_target_start <- target_start - symmetric_extension
    virtual_target_end <- target_end + symmetric_extension
    neighbor_panel_width <- 0.255 * total_plot_length
    panel_gap <- 0.006 * total_plot_length

    # Keep a minimum visual buffer so left-oriented arrowheads never collide with the first exon.
    arrow_ext <- max(0.18 * current_transcript_length, 0.08 * total_plot_length)
    arrow_left_tip <- if (gene_strand == "-") target_start - arrow_ext else target_start
    arrow_right_tip <- if (gene_strand == "+") target_end + arrow_ext else target_end

    # Keep side panels outside arrowheads so dashed connectors never cross arrows.
    side_scale_padding <- 0.022 * total_plot_length
    left_panel_end_raw <- virtual_target_start - side_scale_padding - panel_gap
    right_panel_start_raw <- virtual_target_end + side_scale_padding + panel_gap
    min_connector_len <- 0.032 * total_plot_length
    left_panel_end <- min(left_panel_end_raw, arrow_left_tip - min_connector_len)
    left_panel_start <- left_panel_end - neighbor_panel_width
    right_panel_start <- max(right_panel_start_raw, arrow_right_tip + min_connector_len)
    right_panel_end <- right_panel_start + neighbor_panel_width

    edge_pad <- 0.004 * total_plot_length
    raw_left <- left_panel_start - edge_pad
    raw_right <- right_panel_end + edge_pad

    # Balance both sides around the transcript center so we avoid one-sided blank areas.
    plot_mid <- (virtual_target_start + virtual_target_end) / 2
    left_span <- plot_mid - raw_left
    right_span <- raw_right - plot_mid
    if (left_span > right_span) {
        delta <- left_span - right_span
        right_panel_start <- right_panel_start + delta
        right_panel_end <- right_panel_end + delta
        raw_right <- raw_right + delta
    } else if (right_span > left_span) {
        delta <- right_span - left_span
        left_panel_start <- left_panel_start - delta
        left_panel_end <- left_panel_end - delta
        raw_left <- raw_left - delta
    }

    # Keep a subtle border on both sides without wasting horizontal space.
    scene_width <- max(raw_right - raw_left, .Machine$double.eps)
    outer_margin <- 0.02 * scene_width
    plot_left <- raw_left - outer_margin
    plot_right <- raw_right + outer_margin

    d_min <- 10
    d_max <- 1e5
    base_line_df <- data.frame(
        x = target_start,
        xend = target_end,
        y = structure_y_base,
        yend = structure_y_base
    )
    arrow_line_df <- data.frame(
        x = if (gene_strand == "-") arrow_left_tip else target_end,
        xend = if (gene_strand == "+") arrow_right_tip else target_start,
        y = structure_y_base,
        yend = structure_y_base
    )
    arrow_line_start <- as.numeric(arrow_line_df$x[1])
    arrow_line_end <- as.numeric(arrow_line_df$xend[1])
    # Place the arrow tip a bit beyond the midpoint toward the strand direction.
    tip_fraction <- 0.58
    tip_t <- if (gene_strand == "+") tip_fraction else (1 - tip_fraction)
    arrow_tip_x <- arrow_line_start + (arrow_line_end - arrow_line_start) * tip_t
    # Thick dashed "arrow shaft" must end exactly at the arrow tip.
    arrow_shaft_df <- data.frame(
        x = if (gene_strand == "+") arrow_line_start else arrow_tip_x,
        xend = if (gene_strand == "+") arrow_tip_x else arrow_line_end,
        y = structure_y_base,
        yend = structure_y_base
    )
    arrow_head_len <- 0.012 * scene_width
    arrow_head_half_height <- 0.022
    arrow_base_x <- if (gene_strand == "-") arrow_tip_x + arrow_head_len else arrow_tip_x - arrow_head_len
    arrow_head_df <- data.frame(
        x = c(arrow_base_x, arrow_base_x, arrow_tip_x),
        y = c(structure_y_base - arrow_head_half_height, structure_y_base + arrow_head_half_height, structure_y_base),
        grp = 1
    )
    gene_attr <- pick_first_value(
        if (nrow(df_gene) > 0) as.character(df_gene$V9[1] %||% NA_character_) else NA_character_,
        if (nrow(df_transcript) > 0) as.character(df_transcript$V9[1] %||% NA_character_) else NA_character_,
        if (nrow(df) > 0) as.character(df$attributes_raw[1] %||% NA_character_) else NA_character_,
        ""
    )
    gene_name_value <- pick_first_value(
        extract_primary_gene_name(gene_attr),
        extract_primary_gene_id(gene_attr)
    )
    tx_row <- if (nrow(df_transcript) > 0) df_transcript[1, , drop = FALSE] else NULL
    tx_attr <- if (!is.null(tx_row)) as.character(tx_row$V9[1] %||% "") else ""
    tx_attrs <- parse_gff_attributes(tx_attr %||% "")
    gene_attrs <- parse_gff_attributes(gene_attr %||% "")
    tx_id <- pick_first_value(
        tx_attrs[["id"]][1], tx_attrs[["transcript_id"]][1], tx_attrs[["name"]][1],
        gene_attrs[["id"]][1], gene_attrs[["gene_id"]][1], gene_attrs[["locus_tag"]][1], gene_attrs[["name"]][1]
    )
    tx_name <- pick_first_value(
        tx_attrs[["name"]][1], tx_attrs[["transcript"]][1], tx_id,
        gene_attrs[["name"]][1], gene_attrs[["gene"]][1], gene_attrs[["gene_name"]][1], gene_name_value
    )
    tx_biotype <- pick_first_value(
        tx_attrs[["biotype"]][1],
        tx_attrs[["transcript_biotype"]][1],
        tx_attrs[["gene_biotype"]][1],
        tx_attrs[["gbkey"]][1],
        gene_attrs[["gene_biotype"]][1],
        gene_attrs[["gbkey"]][1],
        if (nrow(df_rect) > 0) as.character(df_rect$plot_group[1]) else NA_character_
    )
    tx_chr <- pick_first_value(
        if (!is.null(tx_row)) tx_row$V1[1] else NA_character_,
        if (nrow(df_gene) > 0) df_gene$V1[1] else NA_character_,
        if (nrow(df) > 0) df$seqid[1] else NA_character_
    )
    tx_chr_short <- tryCatch(
        get_short_chromosome_name(
            tx_chr,
            as.character(annotation_file_path %||% ""),
            use_report_map = isTRUE(use_report_map),
            report_path = as.character(report_path %||% "")
        ),
        error = function(e) tx_chr
    )
    tx_start_num <- suppressWarnings(as.numeric(if (!is.null(tx_row)) tx_row$V4[1] else target_start))
    tx_end_num <- suppressWarnings(as.numeric(if (!is.null(tx_row)) tx_row$V5[1] else target_end))
    if (!is.finite(tx_start_num)) tx_start_num <- target_start
    if (!is.finite(tx_end_num)) tx_end_num <- target_end
    tx_strand <- pick_first_value(if (!is.null(tx_row)) tx_row$V7[1] else NA_character_, gene_strand)
    tx_strand <- trimws(as.character(tx_strand %||% gene_strand))
    if (!tx_strand %in% c("+", "-")) tx_strand <- gene_strand
    gene_display_label <- trimws(utils::URLdecode(as.character(gene_display_name %||% "")))
    center_gene_label <- pick_first_value(gene_display_label, gene_name_value, tx_name, tx_id)
    organism_display <- trimws(as.character(organism_label %||% "N/A"))
    if (!nzchar(organism_display)) organism_display <- "N/A"
    encode_data_id_value <- function(x) {
        xx <- trimws(as.character(x %||% "N/A"))
        if (!nzchar(xx)) xx <- "N/A"
        utils::URLencode(xx, reserved = TRUE)
    }
    promoter_side_label <- if (gene_strand == "+") "Upstream (left side)" else "Upstream (right side)"
    tx_start_int <- if (is.finite(tx_start_num)) as.integer(round(tx_start_num)) else NA_integer_
    tx_end_int <- if (is.finite(tx_end_num)) as.integer(round(tx_end_num)) else NA_integer_
    plot_id_txt <- trimws(as.character(plot_id %||% ""))
    if (!nzchar(plot_id_txt)) plot_id_txt <- "N/A"
    plot_context_txt <- trimws(as.character(plot_context %||% ""))
    if (!nzchar(plot_context_txt)) plot_context_txt <- "N/A"
    promoter_popup_data_id <- paste0(
        "promoter_region",
        "|panel=", encode_data_id_value(plot_context_txt),
        "|plot_id=", encode_data_id_value(plot_id_txt),
        "|organism=", encode_data_id_value(organism_display),
        "|gene=", encode_data_id_value(center_gene_label),
        "|transcript=", encode_data_id_value(tx_name),
        "|transcript_id=", encode_data_id_value(tx_id),
        "|seqid=", encode_data_id_value(tx_chr),
        "|chromosome=", encode_data_id_value(tx_chr_short),
        "|tx_start=", encode_data_id_value(tx_start_int),
        "|tx_end=", encode_data_id_value(tx_end_int),
        "|strand=", encode_data_id_value(tx_strand),
        "|side=", encode_data_id_value(promoter_side_label)
    )
    center_title <- if (!is.null(tx_row)) "Transcript Annotation" else "Gene Annotation"
    center_tooltip <- sprintf(
        "<b style='color:var(--app-message-accent);font-weight:700;'>%s</b><br/><b>Gene Name:</b> %s<br/><b>Transcript Id:</b> %s<br/><b>Transcript Name:</b> %s<br/><b>Chromosome:</b> %s<br/><b>Start:</b> %s<br/><b>End:</b> %s<br/><b>Strand:</b> %s<br/><b>Biotype:</b> %s",
        center_title,
        center_gene_label,
        tx_id,
        tx_name,
        tx_chr,
        format_bp(tx_start_num),
        format_bp(tx_end_num),
        tx_strand,
        tx_biotype
    )
    center_label_df <- data.frame(
        x = (plot_left + plot_right) / 2,
        y = center_gene_label_y,
        label = center_gene_label,
        tooltip = center_tooltip,
        data_id = "center_gene_label",
        stringsAsFactors = FALSE
    )

    if (visual_mode == "compact") {
        plot_ymin <- 0.88
        plot_ymax <- 1.16
    } else {
        detailed_feature_ymin <- if (nrow(df_rect) > 0) suppressWarnings(min(df_rect$ymin_feat, na.rm = TRUE)) else 0.825
        if (!is.finite(detailed_feature_ymin)) detailed_feature_ymin <- 0.825
        plot_ymin <- max(0.72, detailed_feature_ymin - 0.07)
        plot_ymax <- max(1.14, center_gene_label_y + 0.028)
    }

    gg_lines <- ggplot() +
        # Línea base
        geom_segment(
            data = base_line_df,
            aes(x = x, xend = xend, y = y, yend = yend),
            color = gene_line_color, linewidth = 1.05
        ) +

        # Flecha de dirección
        geom_segment(
            data = arrow_line_df,
            aes(x = x, xend = xend, y = y, yend = yend),
            colour = neighbor_dash_col,
            linewidth = 0.42,
            linetype = "22",
            lineend = "butt"
        ) +
        geom_segment(
            data = arrow_shaft_df,
            aes(x = x, xend = xend, y = y, yend = yend),
            colour = gene_direction_color,
            linewidth = 0.62,
            linetype = "22",
            lineend = "butt"
        ) +

        # Solid triangular arrowhead with no solid shaft.
        geom_polygon(
            data = arrow_head_df,
            aes(x = x, y = y, group = grp),
            fill = gene_direction_color,
            color = gene_direction_color,
            linewidth = 0.15
        ) +
        {
            if (nrow(intron_df) > 0) {
                geom_segment_interactive(
                    data = intron_df,
                    aes(
                        x = intron_start, xend = intron_end, y = 1, yend = 1,
                        tooltip = tooltip, data_id = data_id
                    ),
                    color = gene_line_color,
                    linewidth = 0.8,
                    linetype = "solid"
                )
            } else {
                NULL
            }
        } +
        {
            if (nrow(df_rect) > 0) {
                geom_rect_interactive(
                    data = df_rect,
                    aes(
                        xmin = xstart, xmax = xend,
                        ymin = ymin_feat, ymax = ymax_feat,
                        fill = plot_group,
                        tooltip = plot_tooltip,
                        data_id = feature_uid
                    ),
                    alpha = 1
                )
            } else {
                NULL
            }
        } +
        geom_text_interactive(
            data = center_label_df,
            aes(x = x, y = y, label = label, tooltip = tooltip, data_id = data_id),
            size = center_gene_size,
            color = center_label_col,
            fontface = "bold",
            hjust = 0.5,
            vjust = 0.5
        ) +
        {
            if (nrow(df_rect) > 0) scale_fill_manual(values = custom_colors, na.value = "#95A5A6") else NULL
        } +
        scale_x_continuous(expand = expansion(mult = 0, add = 0)) +
        scale_y_continuous(expand = expansion(mult = 0, add = 0)) +
        coord_cartesian(
          xlim = c(plot_left, plot_right),
          ylim = c(plot_ymin, plot_ymax),
          clip = "off"
        ) +
        theme_minimal() +
        theme(
            legend.position = "none",
            panel.grid = element_blank(),
            panel.background = element_rect(fill = panel_bg_fill, colour = panel_bg_fill),
            plot.background = element_rect(fill = panel_bg_fill, colour = panel_bg_fill),
            axis.title = element_blank(),
            axis.text = element_blank(),
            axis.ticks = element_blank(),
            plot.margin = margin(0, 0, 0, 0)
        )

    # Length/composition metadata is shown in card footers (server.R),
    # so we keep the plot area focused on gene structure + neighbors.

    if (!is.null(neighbor_context)) {
        interval_ratio <- 1.4
        interval_weights <- interval_ratio^(0:3)
        interval_edges <- c(0, cumsum(interval_weights) / sum(interval_weights))
        to_panel_s <- function(bp) {
            if (bp <= 0) {
                return(0)
            }
            bp_clamped <- min(as.numeric(bp), d_max)
            # Piecewise decade index:
            # 0..100 bp -> [0,1], then 100..100k bp -> [1,4] in log10 decades.
            u <- if (bp_clamped <= 100) {
                bp_clamped / 100
            } else {
                1 + log10(bp_clamped / 100)
            }
            u <- min(max(u, 0), 4)
            seg <- min(3, floor(u))
            frac <- u - seg
            left <- interval_edges[seg + 1]
            right <- interval_edges[seg + 2]
            s <- left + (right - left) * frac
            min(max(s, 0), 1)
        }

        ticks_vals <- c(0, 100, 1000, 10000, 100000)
        tick_numbers <- c("0", "100", "1", "10", "100")
        tick_units <- c("bp", "bp", "kbp", "kbp", "kbp")
        tick_s <- vapply(ticks_vals, to_panel_s, numeric(1))

        left_ticks <- data.frame(
            x = left_panel_end - tick_s * neighbor_panel_width,
            xend = left_panel_end - tick_s * neighbor_panel_width,
            y = structure_y_base,
            yend = structure_y_base + 0.035,
            num_label = tick_numbers,
            unit_label = tick_units,
            stringsAsFactors = FALSE
        )
        right_ticks <- data.frame(
            x = right_panel_start + tick_s * neighbor_panel_width,
            xend = right_panel_start + tick_s * neighbor_panel_width,
            y = structure_y_base,
            yend = structure_y_base + 0.035,
            num_label = tick_numbers,
            unit_label = tick_units,
            stringsAsFactors = FALSE
        )
        promoter_fraction <- 0.58
        split_connector_segments <- function(panel_x, gene_x, is_promoter_side = FALSE) {
            panel_x <- as.numeric(panel_x)
            gene_x <- as.numeric(gene_x)
            if (!is.finite(panel_x) || !is.finite(gene_x) || panel_x == gene_x) {
                return(data.frame(x = numeric(0), xend = numeric(0), part = character(0), stringsAsFactors = FALSE))
            }
            if (!isTRUE(is_promoter_side)) {
                return(data.frame(x = panel_x, xend = gene_x, part = "base", stringsAsFactors = FALSE))
            }
            # Keep a visual/interactive gap near the gene edge so promoter and exon
            # do not share the same hover pixel when the scene is highly compressed.
            edge_gap <- max(2, 0.004 * scene_width)
            max_gap <- abs(panel_x - gene_x) * 0.45
            if (!is.finite(max_gap) || max_gap <= 0) {
                return(data.frame(x = panel_x, xend = gene_x, part = "base", stringsAsFactors = FALSE))
            }
            edge_gap <- min(edge_gap, max_gap)
            dir_sign <- if (panel_x > gene_x) 1 else -1
            promoter_start <- gene_x + dir_sign * edge_gap
            split_x <- promoter_start + (panel_x - promoter_start) * promoter_fraction
            data.frame(
                # base: non-promoter side of the connector
                # promoter: visual promoter segment (includes anti-flicker gap)
                # promoter_hit: invisible interactive subsegment (stops before the exon edge)
                x = c(panel_x, split_x, split_x),
                xend = c(split_x, gene_x, promoter_start),
                part = c("base", "promoter", "promoter_hit"),
                stringsAsFactors = FALSE
            )
        }
        connector_segments <- rbind(
            split_connector_segments(
                panel_x = left_panel_end,
                gene_x = arrow_left_tip,
                is_promoter_side = (gene_strand == "+")
            ),
            split_connector_segments(
                panel_x = right_panel_start,
                gene_x = arrow_right_tip,
                is_promoter_side = (gene_strand == "-")
            )
        )
        if (nrow(connector_segments) > 0) {
            connector_segments$y <- structure_y_base
            connector_segments$yend <- structure_y_base
            is_prom_part <- connector_segments$part %in% c("promoter", "promoter_hit")
            connector_segments$promoter_tooltip <- ifelse(is_prom_part, "Promoter region", NA_character_)
            connector_segments$promoter_data_id <- ifelse(is_prom_part, promoter_popup_data_id, NA_character_)
        }
        promoter_click_target <- connector_segments[connector_segments$part == "promoter_hit", , drop = FALSE]
        if (nrow(promoter_click_target) > 0) {
            promoter_click_target$promoter_tooltip <- as.character(promoter_click_target$promoter_tooltip)
            promoter_click_target$promoter_data_id <- as.character(promoter_click_target$promoter_data_id)
            keep_prom <- is.finite(promoter_click_target$x) &
                is.finite(promoter_click_target$xend) &
                (abs(promoter_click_target$xend - promoter_click_target$x) > 1e-9) &
                !is.na(promoter_click_target$promoter_tooltip) &
                nzchar(trimws(promoter_click_target$promoter_tooltip)) &
                !is.na(promoter_click_target$promoter_data_id) &
                nzchar(trimws(promoter_click_target$promoter_data_id))
            promoter_click_target <- promoter_click_target[keep_prom, , drop = FALSE]
        }
        both_ticks <- rbind(left_ticks, right_ticks)
        both_ticks_num <- both_ticks
        both_ticks_num$y <- structure_y_base + 0.068
        both_ticks_unit <- both_ticks
        both_ticks_unit$y <- structure_y_base + 0.043
        connector_base <- connector_segments[connector_segments$part == "base", , drop = FALSE]
        connector_promoter <- connector_segments[connector_segments$part == "promoter", , drop = FALSE]

        gg_lines <- gg_lines +
            geom_segment(
                data = data.frame(
                    x = c(left_panel_start, right_panel_start),
                    xend = c(left_panel_end, right_panel_end),
                    y = c(structure_y_base, structure_y_base),
                    yend = c(structure_y_base, structure_y_base)
                ),
                aes(x = x, xend = xend, y = y, yend = yend),
                color = neighbor_rule_col,
                linewidth = 0.48
            ) +
            geom_segment(
                data = connector_base,
                aes(x = x, xend = xend, y = y, yend = yend),
                color = neighbor_dash_col,
                linewidth = 0.42,
                linetype = "22",
                lineend = "butt"
            ) +
            geom_segment(
                data = connector_promoter,
                aes(
                    x = x, xend = xend, y = y, yend = yend
                ),
                color = promoter_dash_col,
                linewidth = 0.48,
                linetype = "22",
                lineend = "butt"
            ) +
            # Invisible wide hit area to make promoter clicks easier without changing appearance.
            geom_segment_interactive(
                data = promoter_click_target,
                aes(
                    x = x, xend = xend, y = y, yend = yend,
                    tooltip = promoter_tooltip, data_id = promoter_data_id
                ),
                color = promoter_dash_col,
                linewidth = 6.2,
                alpha = 0.001,
                linetype = "solid",
                lineend = "butt"
            ) +
            geom_segment(
                data = both_ticks,
                aes(x = x, xend = xend, y = y, yend = yend),
                color = neighbor_rule_col,
                linewidth = 0.32
            ) +
            geom_text(
                data = both_ticks_num,
                aes(x = x, y = y, label = num_label),
                size = neighbor_tick_size,
                color = neighbor_tick_col,
                hjust = 0.5,
                lineheight = 0.9,
                vjust = 0
            ) +
            geom_text(
                data = both_ticks_unit,
                aes(x = x, y = y, label = unit_label),
                size = neighbor_tick_size * 0.78,
                color = neighbor_tick_col,
                hjust = 0.5,
                lineheight = 0.9,
                vjust = 0
            )

        make_side_df <- function(side_name, neighbor, is_left = TRUE) {
            side_title <- ifelse(side_name == "upstream", "Upstream Neighbor", "Downstream Neighbor")
            has_neighbor <- !is.null(neighbor) && !is.na(neighbor$dist_bp)
            if (!has_neighbor) {
                name_text <- "None"
                tooltip <- sprintf(
                    "<b style='color:var(--app-message-accent);font-weight:700;'>%s</b><br/><span style='font-size:13px;font-weight:700;'>Distance To Query Gene: N/A</span><br/><b>Neighbor Gene:</b> None<br/><b>Neighbor Chromosome:</b> N/A<br/><b>Neighbor Start:</b> N/A<br/><b>Neighbor End:</b> N/A<br/><b>Neighbor Strand:</b> N/A<br/><b>Overlap:</b> No",
                    side_title
                )
                marker_x <- NA_real_
                overlap <- FALSE
            } else {
                dist_bp_raw <- suppressWarnings(as.numeric(neighbor$dist_bp))
                neighbor_display_clean <- truncate_neighbor_label(
                    pick_first_value(neighbor$neighbor_label, neighbor$neighbor_name, neighbor$neighbor_id),
                    max_chars = 100
                )
                name_text <- truncate_neighbor_label(neighbor_display_clean, max_chars = 24)
                plot_bp <- ifelse(dist_bp_raw < 0, 0, dist_bp_raw)
                dist_bp_label <- if (is.finite(plot_bp)) paste0(format_bp(plot_bp), " bp") else "N/A"
                if (is.finite(dist_bp_raw) && dist_bp_raw > d_max) dist_bp_label <- paste0(dist_bp_label, " (>100 kb)")
                if (is.finite(dist_bp_raw) && dist_bp_raw > 0 && dist_bp_raw < d_min) dist_bp_label <- paste0(dist_bp_label, " (<10 bp)")
                neighbor_start_num <- suppressWarnings(as.numeric(neighbor$neighbor_start))
                neighbor_end_num <- suppressWarnings(as.numeric(neighbor$neighbor_end))
                neighbor_start_lbl <- if (is.finite(neighbor_start_num)) format_bp(neighbor_start_num) else as.character(neighbor$neighbor_start %||% "N/A")
                neighbor_end_lbl <- if (is.finite(neighbor_end_num)) format_bp(neighbor_end_num) else as.character(neighbor$neighbor_end %||% "N/A")
                overlap <- is.finite(dist_bp_raw) && dist_bp_raw < 0
                tooltip <- sprintf(
                    "<b style='color:var(--app-message-accent);font-weight:700;'>%s</b><br/><span style='font-size:13px;font-weight:700;'>Distance To Query Gene: %s</span><br/><b>Neighbor Gene:</b> %s<br/><b>Neighbor Chromosome:</b> %s<br/><b>Neighbor Start:</b> %s<br/><b>Neighbor End:</b> %s<br/><b>Neighbor Strand:</b> %s<br/><b>Overlap:</b> %s",
                    side_title,
                    dist_bp_label,
                    neighbor_display_clean %||% "N/A",
                    neighbor$neighbor_chr %||% "N/A",
                    neighbor_start_lbl,
                    neighbor_end_lbl,
                    neighbor$neighbor_strand %||% "N/A",
                    ifelse(overlap, "Yes", "No")
                )
                s <- to_panel_s(plot_bp)
                marker_x <- if (is_left) left_panel_end - s * neighbor_panel_width else right_panel_start + s * neighbor_panel_width
            }

            label_x <- if (is.finite(marker_x)) {
                marker_x
            } else if (is_left) {
                (left_panel_start + left_panel_end) / 2
            } else {
                (right_panel_start + right_panel_end) / 2
            }

            list(
                label = data.frame(
                    side = side_name,
                    name_x = label_x,
                    hjust_name = 0.5,
                    name_text = name_text,
                    tooltip = tooltip,
                    data_id = paste0("neighbor_label_", side_name),
                    stringsAsFactors = FALSE
                ),
                marker = data.frame(
                    side = side_name,
                    x = marker_x,
                    y = structure_y_base,
                    overlap = overlap,
                    tooltip = tooltip,
                    data_id = paste0("neighbor_marker_", side_name),
                    stringsAsFactors = FALSE
                )
            )
        }

        up_df <- make_side_df("upstream", neighbor_context$upstream, is_left = TRUE)
        down_df <- make_side_df("downstream", neighbor_context$downstream, is_left = FALSE)
        text_df <- rbind(up_df$label, down_df$label)
        text_df$name_x <- suppressWarnings(as.numeric(text_df$name_x))
        text_df$tooltip <- as.character(text_df$tooltip)
        text_df$data_id <- as.character(text_df$data_id)
        text_df$name_text <- as.character(text_df$name_text)
        keep_text <- is.finite(text_df$name_x) &
            !is.na(text_df$tooltip) &
            nzchar(trimws(text_df$tooltip)) &
            !is.na(text_df$data_id) &
            nzchar(trimws(text_df$data_id)) &
            !is.na(text_df$name_text) &
            nzchar(trimws(text_df$name_text))
        text_df <- text_df[keep_text, , drop = FALSE]
        marker_df <- rbind(up_df$marker, down_df$marker)
        marker_df$x <- suppressWarnings(as.numeric(marker_df$x))
        marker_df$tooltip <- as.character(marker_df$tooltip)
        marker_df$data_id <- as.character(marker_df$data_id)
        keep_marker <- is.finite(marker_df$x) &
            !is.na(marker_df$tooltip) &
            nzchar(trimws(marker_df$tooltip)) &
            !is.na(marker_df$data_id) &
            nzchar(trimws(marker_df$data_id))
        marker_df <- marker_df[keep_marker, , drop = FALSE]

        gg_lines <- gg_lines +
            geom_text_interactive(
                data = text_df,
                aes(x = name_x, y = neighbor_gene_label_y, label = name_text, hjust = hjust_name, tooltip = tooltip, data_id = data_id),
                size = neighbor_name_size,
                color = neighbor_label_col
            ) +
            geom_point_interactive(
                data = marker_df,
                aes(x = x, y = y, tooltip = tooltip, data_id = data_id),
                shape = 21,
                size = neighbor_marker_size,
                fill = neighbor_marker_fill,
                color = neighbor_marker_col,
                stroke = neighbor_marker_stroke
            )
    }

    # Disable hover restyling to avoid rapid style thrash in ultra-dense regions.
    hover_css_str <- ""

    app_perf_mark(plot_perf, "girafe build start", "PLOT_BUILD")
    plot_widget <- withCallingHandlers(
        girafe(
            ggobj = gg_lines,
            width_svg = width_svg,
            height_svg = height_svg,
            options = list(
                opts_hover(css = hover_css_str),
                opts_selection(type = "none"),
                opts_tooltip(
                    css = paste(
                        "background: var(--app-message-bg);",
                        "color: var(--app-message-text);",
                        "border: 1px solid var(--app-message-border);",
                        "border-radius: var(--app-message-radius);",
                        "padding: 8px 11px;",
                        "font-family: var(--app-font-family), Roboto, 'Helvetica Neue', Arial, sans-serif;",
                        "font-size: 12px;",
                        "font-weight: 400;",
                        "line-height: 1.4;",
                        "letter-spacing: 0.01em;",
                        "box-shadow: var(--app-message-shadow);"
                    ),
                    delay_mouseover = 45,
                    delay_mouseout = 180
                ),
                opts_toolbar(position = "topright", saveaspng = FALSE, hidden = c("selection", "zoom", "misc")),
                opts_sizing(rescale = FALSE)
            )
        ),
        warning = function(w) {
            msg <- conditionMessage(w)
            if (grepl("Failed setting attribute 'title'", msg, fixed = TRUE) ||
                grepl("Failed setting attribute 'data-id'", msg, fixed = TRUE) ||
                grepl("set_attr(name = attrName", msg, fixed = TRUE)) {
                invokeRestart("muffleWarning")
            }
        }
    )
    app_perf_mark(plot_perf, "girafe build done", "PLOT_BUILD")
    plot_widget
}

# Función server del módulo de Plot para homólogos
plotServerHomologous <- function(id, data, max_gene_length, min_gene_coord, max_gene_coord, genSequences, plotIndex, gene_name, genome_fasta_path = NULL, annotation_file_path = NULL, visual_mode = NULL, organism_name = NULL, use_report_map = FALSE, report_path = "", app_theme = NULL, app_colorblind = NULL, precomputed_neighbor_context = NULL, prefetch_sequence = TRUE, prefetch_neighbor_context = FALSE, perf_run_id = NULL, on_plot_ready = NULL) {
    moduleServer(
        id,
        function(input, output, session) {
            # OPT-4: Process data ONCE at module init (data is a static data.frame)
            processed_cache <- process_gene_data(data)

            # Reactive value to store gene info
            gene_info <- reactiveVal(NULL)
            neighbor_context <- reactiveVal(NULL)
            neighbor_context_resolved <- reactiveVal(FALSE)
            cached_plot_key <- reactiveVal("")
            cached_plot_obj <- reactiveVal(NULL)
            plot_ready_notified <- FALSE
            module_destroyed <- FALSE
            is_homo_plot_cache_enabled <- function() {
                raw <- tolower(trimws(as.character(Sys.getenv("APP_HOMO_PLOT_CACHE", "1") %||% "1")))
                !raw %in% c("", "0", "false", "no", "off")
            }
            notify_plot_ready <- function() {
                if (!isTRUE(plot_ready_notified)) {
                    if (is.function(on_plot_ready)) {
                        tryCatch(on_plot_ready(as.character(plotIndex)), error = function(e) NULL)
                    }
                    plot_ready_notified <<- TRUE
                }
                invisible(NULL)
            }
            module_perf <- app_perf_new_run(sprintf("HOMO-%s", as.character(plotIndex %||% id)))
            perf_parent <- trimws(as.character(perf_run_id %||% ""))
            if (nzchar(perf_parent)) {
                module_perf$id <- paste0(perf_parent, "|plot=", as.character(plotIndex))
            }
            app_perf_mark(module_perf, "module init", "HOMO_MOD")
            destroy_module <- function() {
                if (isTRUE(module_destroyed)) {
                    return(invisible(FALSE))
                }
                module_destroyed <<- TRUE
                tryCatch(prefetch_observer$destroy(), error = function(e) NULL)
                tryCatch({
                    output$plot <- NULL
                }, error = function(e) NULL)
                tryCatch(gene_info(NULL), error = function(e) NULL)
                tryCatch(neighbor_context(NULL), error = function(e) NULL)
                tryCatch(neighbor_context_resolved(FALSE), error = function(e) NULL)
                tryCatch(cached_plot_key(""), error = function(e) NULL)
                tryCatch(cached_plot_obj(NULL), error = function(e) NULL)
                processed_cache <<- NULL
                invisible(TRUE)
            }
            session$onSessionEnded(function() {
                destroy_module()
            })

            resolve_neighbor_context_sync <- function(step_prefix = "neighbor context") {
                df_gene <- processed_cache$df_gene
                df_plot <- processed_cache$df
                if (is.null(annotation_file_path) || !nzchar(annotation_file_path) || (nrow(df_gene) <= 0 && nrow(df_plot) <= 0)) {
                    return(NULL)
                }
                app_perf_mark(module_perf, sprintf("%s start", as.character(step_prefix)), "HOMO_MOD")
                tgt_chr <- as.character(df_gene$V1[1] %||% df_plot$seqid[1] %||% data$V1[1] %||% NA_character_)
                tgt_start <- suppressWarnings(as.numeric(min(df_gene$V4, na.rm = TRUE)))
                tgt_end <- suppressWarnings(as.numeric(max(df_gene$V5, na.rm = TRUE)))
                if (!is.finite(tgt_start) || !is.finite(tgt_end) || tgt_end < tgt_start) {
                    tgt_start <- suppressWarnings(as.numeric(min(df_plot$xstart, na.rm = TRUE)))
                    tgt_end <- suppressWarnings(as.numeric(max(df_plot$xend, na.rm = TRUE)))
                }
                if (!is.finite(tgt_start) || !is.finite(tgt_end) || tgt_end < tgt_start) {
                    tgt_start <- suppressWarnings(as.numeric(min(data$V4, na.rm = TRUE)))
                    tgt_end <- suppressWarnings(as.numeric(max(data$V5, na.rm = TRUE)))
                }
                tgt_attr <- as.character(df_gene$V9[1] %||% data$V9[1] %||% "")
                target_gene <- data.frame(
                    gene_id = extract_primary_gene_id(tgt_attr),
                    chr = tgt_chr,
                    start = tgt_start,
                    end = tgt_end,
                    strand = as.character(df_gene$V7[1] %||% data$V7[1] %||% NA_character_),
                    stringsAsFactors = FALSE
                )
                out_ctx <- get_neighbor_context_for_target(annotation_file_path, target_gene)
                app_perf_mark(module_perf, sprintf("%s done", as.character(step_prefix)), "HOMO_MOD")
                out_ctx
            }

            # Trigger data fetching
            prefetch_observer <- observe({
                req(data)
                app_perf_mark(module_perf, "observe start", "HOMO_MOD")
                # OPT-4: Use pre-computed processed data
                df_gene <- processed_cache$df_gene
                df_plot <- processed_cache$df
                df_transcript <- processed_cache$df_transcript

                if (!is.null(precomputed_neighbor_context)) {
                    neighbor_context(precomputed_neighbor_context)
                    neighbor_context_resolved(TRUE)
                    app_perf_mark(module_perf, "neighbor context precomputed", "HOMO_MOD")
                } else if (isTRUE(prefetch_neighbor_context)) {
                    neighbor_context(resolve_neighbor_context_sync("neighbor context prefetch"))
                    neighbor_context_resolved(TRUE)
                } else {
                    neighbor_context(NULL)
                    neighbor_context_resolved(FALSE)
                    app_perf_mark(module_perf, "neighbor context deferred", "HOMO_MOD")
                }

                if (isTRUE(prefetch_sequence)) {
                    app_perf_mark(module_perf, "prefetch sequence start", "HOMO_MOD")
                    tx_start <- suppressWarnings(min(as.numeric(df_transcript$V4), na.rm = TRUE))
                    tx_end <- suppressWarnings(max(as.numeric(df_transcript$V5), na.rm = TRUE))
                    if (!is.finite(tx_start) || !is.finite(tx_end) || tx_end <= tx_start) {
                        tx_start <- suppressWarnings(min(df_plot$xstart, na.rm = TRUE))
                        tx_end <- suppressWarnings(max(df_plot$xend, na.rm = TRUE))
                    }
                    if (!is.finite(tx_start) || !is.finite(tx_end) || tx_end <= tx_start) {
                        tx_start <- suppressWarnings(min(df_gene$V4, na.rm = TRUE))
                        tx_end <- suppressWarnings(max(df_gene$V5, na.rm = TRUE))
                    }
                    if (!is.finite(tx_start) || !is.finite(tx_end) || tx_end <= tx_start) {
                        tx_start <- suppressWarnings(min(as.numeric(data$V4), na.rm = TRUE))
                        tx_end <- suppressWarnings(max(as.numeric(data$V5), na.rm = TRUE))
                    }

                    tx_attr <- if (nrow(df_transcript) > 0) as.character(df_transcript$V9[1] %||% "") else ""
                    tx_attrs <- parse_gff_attributes(tx_attr %||% "")
                    gene_attr <- if (nrow(df_gene) > 0) as.character(df_gene$V9[1] %||% "") else ""
                    tx_label_candidates <- c(
                        tx_attrs[["name"]][1],
                        tx_attrs[["transcript"]][1],
                        tx_attrs[["id"]][1],
                        tx_attrs[["transcript_id"]][1],
                        extract_primary_gene_name(gene_attr),
                        extract_primary_gene_id(gene_attr)
                    )
                    tx_label_candidates <- as.character(tx_label_candidates %||% character(0))
                    tx_label_candidates <- tx_label_candidates[!is.na(tx_label_candidates) & nzchar(trimws(tx_label_candidates))]
                    tx_label <- if (length(tx_label_candidates) > 0) tx_label_candidates[1] else "transcript"
                    tx_label <- trimws(utils::URLdecode(tx_label))
                    if (!nzchar(tx_label)) tx_label <- "transcript"
                    tx_strand <- trimws(as.character(df_transcript$V7[1] %||% df_gene$V7[1] %||% data$V7[1] %||% "+"))
                    if (!nzchar(tx_strand)) tx_strand <- "+"
                    if (!tx_strand %in% c("+", "-")) tx_strand <- "+"

                    exon_idx <- which(tolower(as.character(df_plot$feature_type %||% rep("", nrow(df_plot)))) == "exon")
                    if (length(exon_idx) == 0) {
                        exon_idx <- which(tolower(as.character(df_plot$feature_type %||% rep("", nrow(df_plot)))) == "cds")
                    }
                    exon_ranges <- if (length(exon_idx) > 0) {
                        data.frame(
                            start = suppressWarnings(as.numeric(df_plot$xstart[exon_idx])),
                            end = suppressWarnings(as.numeric(df_plot$xend[exon_idx])),
                            stringsAsFactors = FALSE
                        )
                    } else {
                        NULL
                    }
                    chr_for_fetch <- as.character(
                        df_gene$V1[1] %||%
                            df_transcript$V1[1] %||%
                            df_plot$seqid[1] %||%
                            data$V1[1] %||%
                            ""
                    )

                    result <- fetch_gene_data_sync(
                        chr_for_fetch,
                        list(start = as.numeric(tx_start), end = as.numeric(tx_end)),
                        fasta_path = genome_fasta_path,
                        fasta_id = tx_label,
                        exon_ranges = exon_ranges,
                        strand = tx_strand
                    )
                    gene_info(result)

                    # Update shared sequences
                    current_genSequences <- isolate(genSequences())
                    current_genSequences[[plotIndex]] <- result$file_content
                    genSequences(current_genSequences)
                    seq_len <- nchar(as.character(result$sequence %||% ""))
                    app_perf_mark(module_perf, sprintf("prefetch resolved seq_len=%d", as.integer(seq_len)), "HOMO_MOD")
                } else {
                    gene_info(NULL)
                    app_perf_mark(module_perf, "prefetch disabled", "HOMO_MOD")
                }
            })

            render_trigger <- reactive({
                info_evt <- NULL
                if (isTRUE(prefetch_sequence)) {
                    info_evt <- gene_info()
                    if (is.null(info_evt)) {
                        return(NULL)
                    }
                } else {
                    info_evt <- isolate(gene_info())
                }
                max_gene_length_evt <- suppressWarnings(as.numeric(max_gene_length() %||% 0))
                if (!is.finite(max_gene_length_evt)) max_gene_length_evt <- 0
                visual_mode_evt <- "compact"
                if (!is.null(visual_mode)) {
                    visual_mode_evt <- tryCatch(as.character(visual_mode())[1], error = function(e) "compact")
                }
                visual_mode_evt <- tolower(visual_mode_evt %||% "compact")
                if (!visual_mode_evt %in% c("compact", "detailed")) visual_mode_evt <- "compact"
                theme_mode_evt <- "light"
                if (!is.null(app_theme)) {
                    theme_mode_evt <- tryCatch(as.character(app_theme())[1], error = function(e) "light")
                }
                theme_mode_evt <- tolower(theme_mode_evt %||% "light")
                if (!theme_mode_evt %in% c("light", "dark")) theme_mode_evt <- "light"
                colorblind_evt <- FALSE
                if (!is.null(app_colorblind)) {
                    colorblind_evt <- tryCatch(isTRUE(app_colorblind()), error = function(e) FALSE)
                }
                seq_len_evt <- 0L
                if (!is.null(info_evt) && !is.null(info_evt$sequence)) {
                    seq_len_evt <- suppressWarnings(as.integer(nchar(as.character(info_evt$sequence %||% ""))))
                    if (!is.finite(seq_len_evt)) seq_len_evt <- 0L
                }
                neighbor_evt <- if (isTRUE(prefetch_neighbor_context)) {
                    !is.null(neighbor_context())
                } else {
                    !is.null(isolate(neighbor_context()))
                }
                list(
                    max_gene_length_evt,
                    visual_mode_evt,
                    theme_mode_evt,
                    colorblind_evt,
                    as.logical(neighbor_evt),
                    seq_len_evt
                )
            })

            output$plot <- bindEvent(renderGirafe({
                on.exit(notify_plot_ready(), add = TRUE)
                req(data)
                info <- gene_info()
                if (!isTRUE(prefetch_neighbor_context) && !isTRUE(neighbor_context_resolved()) && is.null(precomputed_neighbor_context)) {
                    lazy_ctx <- tryCatch(
                        resolve_neighbor_context_sync("neighbor context lazy"),
                        error = function(e) {
                            app_perf_mark(module_perf, sprintf("neighbor context lazy error: %s", as.character(e$message %||% "unknown")), "HOMO_MOD")
                            NULL
                        }
                    )
                    neighbor_context(lazy_ctx)
                    neighbor_context_resolved(TRUE)
                }
                current_neighbor_context <- if (isTRUE(prefetch_neighbor_context)) neighbor_context() else isolate(neighbor_context())
                app_perf_mark(module_perf, sprintf("render start info_ready=%s", ifelse(is.null(info), "FALSE", "TRUE")), "HOMO_MOD")
                if (isTRUE(prefetch_sequence)) {
                    req(!is.null(info))
                }
                width_svg <- 16.7

                # Detectamos el modo visual AHORA para darle la altura exacta al SVG
                this_visual_mode <- "compact"
                if (!is.null(visual_mode)) {
                    candidate_mode <- tryCatch(as.character(visual_mode())[1], error = function(e) NA_character_)
                    if (tolower(candidate_mode %||% "compact") %in% c("compact", "detailed")) {
                        this_visual_mode <- tolower(candidate_mode)
                    }
                }

                # Si es compacta, el lienzo es delgado. Si es detallada, crece.
                height_svg <- if (this_visual_mode == "compact") 1.15 else 1.85
                # OPT-4: Use pre-computed processed data
                df <- processed_cache$df
                df_gene <- processed_cache$df_gene
                df_transcript <- processed_cache$df_transcript

                composicion_secuencia <- "Sequence Composition: N/A (genome FASTA not available)"
                if (!is.null(info) && !is.null(info$sequence) && nzchar(info$sequence)) {
                    seq_info <- calculate_sequence_composition(info$sequence)
                    composicion_secuencia <- seq_info$composition
                }

                transcript_start <- suppressWarnings(min(df$xstart, na.rm = TRUE))
                transcript_end <- suppressWarnings(max(df$xend, na.rm = TRUE))
                if (!is.finite(transcript_start) || !is.finite(transcript_end) || transcript_end <= transcript_start) {
                    transcript_start <- suppressWarnings(min(df_gene$V4, na.rm = TRUE))
                    transcript_end <- suppressWarnings(max(df_gene$V5, na.rm = TRUE))
                }
                current_transcript_length <- as.numeric(transcript_end - transcript_start + 1)
                if (!is.finite(current_transcript_length) || current_transcript_length <= 0) current_transcript_length <- 1
                length_difference <- max(0, max_gene_length() - current_transcript_length)

                gene_length_bp <- if (nrow(df_gene) > 0) as.numeric(max(df_gene$V5) - min(df_gene$V4) + 1) else current_transcript_length
                gene_length_label <- sprintf("Gene Length: %s pb", format(as.integer(round(gene_length_bp)), big.mark = ","))
                transcript_length_label <- sprintf("Transcript Length: %s pb", format(as.integer(round(current_transcript_length)), big.mark = ","))
                theme_mode <- "light"
                if (!is.null(app_theme)) {
                    theme_mode <- tryCatch(as.character(app_theme())[1], error = function(e) "light")
                }
                theme_mode <- tolower(theme_mode %||% "light")
                is_dark_theme <- identical(theme_mode, "dark")

                is_colorblind_mode <- FALSE
                if (!is.null(app_colorblind)) {
                    is_colorblind_mode <- tryCatch(isTRUE(app_colorblind()), error = function(e) FALSE)
                }

                cache_enabled <- isTRUE(is_homo_plot_cache_enabled())
                max_gene_length_key <- suppressWarnings(as.numeric(max_gene_length() %||% 0))
                if (!is.finite(max_gene_length_key)) max_gene_length_key <- 0
                seq_len_key <- 0L
                if (!is.null(info) && !is.null(info$sequence)) {
                    seq_len_key <- suppressWarnings(as.integer(nchar(as.character(info$sequence %||% ""))))
                    if (!is.finite(seq_len_key)) seq_len_key <- 0L
                }
                has_neighbor_context <- !is.null(current_neighbor_context)
                cache_key <- paste(
                    as.character(plotIndex %||% ""),
                    format(max_gene_length_key, scientific = FALSE, trim = TRUE),
                    this_visual_mode,
                    theme_mode,
                    as.character(isTRUE(is_colorblind_mode)),
                    as.character(seq_len_key),
                    as.character(isTRUE(has_neighbor_context)),
                    sep = "|"
                )

                if (cache_enabled) {
                    if (identical(cached_plot_key(), cache_key)) {
                        cached_plot <- cached_plot_obj()
                        if (!is.null(cached_plot)) {
                            app_perf_mark(module_perf, "render cache hit", "HOMO_MOD")
                            return(refresh_girafe_widget_uid(cached_plot))
                        }
                    }
                    app_perf_mark(module_perf, "render cache miss", "HOMO_MOD")
                } else {
                    app_perf_mark(module_perf, "render cache disabled", "HOMO_MOD")
                    if (!identical(cached_plot_key(), "") || !is.null(cached_plot_obj())) {
                        cached_plot_key("")
                        cached_plot_obj(NULL)
                    }
                }

                app_perf_mark(module_perf, "create_gene_plot start", "HOMO_MOD")
                plot_obj <- create_gene_plot(
                    df, df_gene, df_transcript, current_transcript_length, length_difference,
                    composicion_secuencia, gene_length_label, transcript_length_label,
                    neighbor_context = current_neighbor_context,
                    visual_mode = this_visual_mode,
                    width_svg = width_svg,
                    height_svg = height_svg,
                    organism_label = organism_name,
                    annotation_file_path = annotation_file_path,
                    use_report_map = use_report_map,
                    report_path = report_path,
                    plot_id = as.character(plotIndex),
                    plot_context = "homologous",
                    genome_fasta_path = genome_fasta_path,
                    is_dark_theme = is_dark_theme,
                    is_colorblind_mode = is_colorblind_mode,
                    gene_display_name = gene_name
                )
                app_perf_mark(module_perf, "create_gene_plot done", "HOMO_MOD")
                if (cache_enabled) {
                    cached_plot_key(cache_key)
                    cached_plot_obj(plot_obj)
                }
                plot_obj
            }), render_trigger(), ignoreNULL = TRUE)
            outputOptions(output, "plot", suspendWhenHidden = TRUE)
            list(
                destroy = destroy_module,
                is_destroyed = function() {
                    isTRUE(module_destroyed)
                }
            )
        }
    )
}

# Función server del módulo de Plot para ortólogos
plotServerOrtologous <- function(id, data, max_gene_length, min_gene_coord, max_gene_coord, genSequences, plotIndex, gene_name, genome_fasta_path = NULL, annotation_file_path = NULL, visual_mode = NULL, organism_name = NULL, use_report_map = FALSE, report_path = "", app_theme = NULL, app_colorblind = NULL, precomputed_neighbor_context = NULL, prefetch_sequence = TRUE, prefetch_neighbor_context = FALSE, perf_run_id = NULL, on_plot_ready = NULL) {
    moduleServer(
        id,
        function(input, output, session) {
            # OPT-4: Process data ONCE at module init (data is a static data.frame)
            processed_cache <- process_gene_data(data)

            gene_info <- reactiveVal(NULL)
            neighbor_context <- reactiveVal(NULL)
            neighbor_context_resolved <- reactiveVal(FALSE)
            cached_plot_key <- reactiveVal("")
            cached_plot_obj <- reactiveVal(NULL)
            plot_ready_notified <- FALSE
            module_destroyed <- FALSE
            is_ortho_plot_cache_enabled <- function() {
                raw <- tolower(trimws(as.character(Sys.getenv("APP_ORTHO_PLOT_CACHE", "1") %||% "1")))
                !raw %in% c("", "0", "false", "no", "off")
            }
            notify_plot_ready <- function() {
                if (!isTRUE(plot_ready_notified)) {
                    if (is.function(on_plot_ready)) {
                        tryCatch(on_plot_ready(as.character(plotIndex)), error = function(e) NULL)
                    }
                    plot_ready_notified <<- TRUE
                }
                invisible(NULL)
            }
            module_perf <- app_perf_new_run(sprintf("ORTHO-%s", as.character(plotIndex %||% id)))
            perf_parent <- trimws(as.character(perf_run_id %||% ""))
            if (nzchar(perf_parent)) {
                module_perf$id <- paste0(perf_parent, "|plot=", as.character(plotIndex))
            }
            app_perf_mark(module_perf, "module init", "ORTHO_MOD")
            destroy_module <- function() {
                if (isTRUE(module_destroyed)) {
                    return(invisible(FALSE))
                }
                module_destroyed <<- TRUE
                tryCatch(prefetch_observer$destroy(), error = function(e) NULL)
                tryCatch({
                    output$plot <- NULL
                }, error = function(e) NULL)
                tryCatch(gene_info(NULL), error = function(e) NULL)
                tryCatch(neighbor_context(NULL), error = function(e) NULL)
                tryCatch(neighbor_context_resolved(FALSE), error = function(e) NULL)
                tryCatch(cached_plot_key(""), error = function(e) NULL)
                tryCatch(cached_plot_obj(NULL), error = function(e) NULL)
                processed_cache <<- NULL
                invisible(TRUE)
            }
            session$onSessionEnded(function() {
                destroy_module()
            })

            resolve_neighbor_context_sync <- function(step_prefix = "neighbor context") {
                df_gene <- processed_cache$df_gene
                df_plot <- processed_cache$df
                if (is.null(annotation_file_path) || !nzchar(annotation_file_path) || (nrow(df_gene) <= 0 && nrow(df_plot) <= 0)) {
                    return(NULL)
                }
                app_perf_mark(module_perf, sprintf("%s start", as.character(step_prefix)), "ORTHO_MOD")
                tgt_chr <- as.character(df_gene$V1[1] %||% df_plot$seqid[1] %||% data$V1[1] %||% NA_character_)
                tgt_start <- suppressWarnings(as.numeric(min(df_gene$V4, na.rm = TRUE)))
                tgt_end <- suppressWarnings(as.numeric(max(df_gene$V5, na.rm = TRUE)))
                if (!is.finite(tgt_start) || !is.finite(tgt_end) || tgt_end < tgt_start) {
                    tgt_start <- suppressWarnings(as.numeric(min(df_plot$xstart, na.rm = TRUE)))
                    tgt_end <- suppressWarnings(as.numeric(max(df_plot$xend, na.rm = TRUE)))
                }
                if (!is.finite(tgt_start) || !is.finite(tgt_end) || tgt_end < tgt_start) {
                    tgt_start <- suppressWarnings(as.numeric(min(data$V4, na.rm = TRUE)))
                    tgt_end <- suppressWarnings(as.numeric(max(data$V5, na.rm = TRUE)))
                }
                tgt_attr <- as.character(df_gene$V9[1] %||% data$V9[1] %||% "")
                target_gene <- data.frame(
                    gene_id = extract_primary_gene_id(tgt_attr),
                    chr = tgt_chr,
                    start = tgt_start,
                    end = tgt_end,
                    strand = as.character(df_gene$V7[1] %||% data$V7[1] %||% NA_character_),
                    stringsAsFactors = FALSE
                )
                out_ctx <- get_neighbor_context_for_target(annotation_file_path, target_gene)
                app_perf_mark(module_perf, sprintf("%s done", as.character(step_prefix)), "ORTHO_MOD")
                out_ctx
            }

            resolve_gene_info_sync <- function(step_prefix = "prefetch") {
                df_gene <- processed_cache$df_gene
                df_plot <- processed_cache$df
                df_transcript <- processed_cache$df_transcript

                tx_start <- suppressWarnings(min(as.numeric(df_transcript$V4), na.rm = TRUE))
                tx_end <- suppressWarnings(max(as.numeric(df_transcript$V5), na.rm = TRUE))
                if (!is.finite(tx_start) || !is.finite(tx_end) || tx_end <= tx_start) {
                    tx_start <- suppressWarnings(min(df_plot$xstart, na.rm = TRUE))
                    tx_end <- suppressWarnings(max(df_plot$xend, na.rm = TRUE))
                }
                if (!is.finite(tx_start) || !is.finite(tx_end) || tx_end <= tx_start) {
                    tx_start <- suppressWarnings(min(df_gene$V4, na.rm = TRUE))
                    tx_end <- suppressWarnings(max(df_gene$V5, na.rm = TRUE))
                }
                if (!is.finite(tx_start) || !is.finite(tx_end) || tx_end <= tx_start) {
                    tx_start <- suppressWarnings(min(as.numeric(data$V4), na.rm = TRUE))
                    tx_end <- suppressWarnings(max(as.numeric(data$V5), na.rm = TRUE))
                }

                tx_attr <- if (nrow(df_transcript) > 0) as.character(df_transcript$V9[1] %||% "") else ""
                tx_attrs <- parse_gff_attributes(tx_attr %||% "")
                gene_attr <- if (nrow(df_gene) > 0) as.character(df_gene$V9[1] %||% "") else ""
                tx_label_candidates <- c(
                    tx_attrs[["name"]][1],
                    tx_attrs[["transcript"]][1],
                    tx_attrs[["id"]][1],
                    tx_attrs[["transcript_id"]][1],
                    extract_primary_gene_name(gene_attr),
                    extract_primary_gene_id(gene_attr)
                )
                tx_label_candidates <- as.character(tx_label_candidates %||% character(0))
                tx_label_candidates <- tx_label_candidates[!is.na(tx_label_candidates) & nzchar(trimws(tx_label_candidates))]
                tx_label <- if (length(tx_label_candidates) > 0) tx_label_candidates[1] else "transcript"
                tx_label <- trimws(utils::URLdecode(tx_label))
                if (!nzchar(tx_label)) tx_label <- "transcript"
                tx_strand <- trimws(as.character(df_transcript$V7[1] %||% df_gene$V7[1] %||% data$V7[1] %||% "+"))
                if (!nzchar(tx_strand)) tx_strand <- "+"
                if (!tx_strand %in% c("+", "-")) tx_strand <- "+"

                exon_idx <- which(tolower(as.character(df_plot$feature_type %||% rep("", nrow(df_plot)))) == "exon")
                if (length(exon_idx) == 0) {
                    exon_idx <- which(tolower(as.character(df_plot$feature_type %||% rep("", nrow(df_plot)))) == "cds")
                }
                exon_ranges <- if (length(exon_idx) > 0) {
                    data.frame(
                        start = suppressWarnings(as.numeric(df_plot$xstart[exon_idx])),
                        end = suppressWarnings(as.numeric(df_plot$xend[exon_idx])),
                        stringsAsFactors = FALSE
                    )
                } else {
                    NULL
                }
                chr_for_fetch <- as.character(
                    df_gene$V1[1] %||%
                        df_transcript$V1[1] %||%
                        df_plot$seqid[1] %||%
                        data$V1[1] %||%
                        ""
                )

                result <- fetch_gene_data_sync(
                    chr_for_fetch,
                    list(start = as.numeric(tx_start), end = as.numeric(tx_end)),
                    fasta_path = genome_fasta_path,
                    fasta_id = tx_label,
                    exon_ranges = exon_ranges,
                    strand = tx_strand
                )
                current_genSequences <- isolate(genSequences())
                current_genSequences[[plotIndex]] <- result$file_content
                genSequences(current_genSequences)
                seq_len <- nchar(as.character(result$sequence %||% ""))
                app_perf_mark(module_perf, sprintf("%s resolved seq_len=%d", as.character(step_prefix), as.integer(seq_len)), "ORTHO_MOD")
                result
            }

            prefetch_observer <- observe({
                req(data)
                app_perf_mark(module_perf, "observe start", "ORTHO_MOD")
                # OPT-4: Use pre-computed processed data
                df_gene <- processed_cache$df_gene
                df_plot <- processed_cache$df
                df_transcript <- processed_cache$df_transcript

                if (!is.null(precomputed_neighbor_context)) {
                    neighbor_context(precomputed_neighbor_context)
                    neighbor_context_resolved(TRUE)
                    app_perf_mark(module_perf, "neighbor context precomputed", "ORTHO_MOD")
                } else if (isTRUE(prefetch_neighbor_context)) {
                    neighbor_context(resolve_neighbor_context_sync("neighbor context prefetch"))
                    neighbor_context_resolved(TRUE)
                } else {
                    neighbor_context(NULL)
                    neighbor_context_resolved(FALSE)
                    app_perf_mark(module_perf, "neighbor context deferred", "ORTHO_MOD")
                }

                if (isTRUE(prefetch_sequence)) {
                    app_perf_mark(module_perf, "prefetch sequence start", "ORTHO_MOD")
                    result <- resolve_gene_info_sync("prefetch")
                    gene_info(result)
                } else {
                    gene_info(NULL)
                    app_perf_mark(module_perf, "prefetch disabled", "ORTHO_MOD")
                }
            })

            render_trigger <- reactive({
                # With lazy sequence mode, avoid tracking gene_info as a reactive dependency
                # so the internal gene_info(info) assignment does not trigger a second rerender.
                info_evt <- if (isTRUE(prefetch_sequence)) gene_info() else isolate(gene_info())
                if (isTRUE(prefetch_sequence) && is.null(info_evt)) {
                    return(NULL)
                }
                max_gene_length_evt <- suppressWarnings(as.numeric(max_gene_length() %||% 0))
                if (!is.finite(max_gene_length_evt)) max_gene_length_evt <- 0
                visual_mode_evt <- "compact"
                if (!is.null(visual_mode)) {
                    visual_mode_evt <- tryCatch(as.character(visual_mode())[1], error = function(e) "compact")
                }
                visual_mode_evt <- tolower(visual_mode_evt %||% "compact")
                if (!visual_mode_evt %in% c("compact", "detailed")) visual_mode_evt <- "compact"
                theme_mode_evt <- "light"
                if (!is.null(app_theme)) {
                    theme_mode_evt <- tryCatch(as.character(app_theme())[1], error = function(e) "light")
                }
                theme_mode_evt <- tolower(theme_mode_evt %||% "light")
                if (!theme_mode_evt %in% c("light", "dark")) theme_mode_evt <- "light"
                colorblind_evt <- FALSE
                if (!is.null(app_colorblind)) {
                    colorblind_evt <- tryCatch(isTRUE(app_colorblind()), error = function(e) FALSE)
                }
                seq_len_evt <- 0L
                if (!is.null(info_evt) && !is.null(info_evt$sequence)) {
                    seq_len_evt <- suppressWarnings(as.integer(nchar(as.character(info_evt$sequence %||% ""))))
                    if (!is.finite(seq_len_evt)) seq_len_evt <- 0L
                }
                neighbor_evt <- if (isTRUE(prefetch_neighbor_context)) {
                    !is.null(neighbor_context())
                } else {
                    !is.null(isolate(neighbor_context()))
                }
                list(
                    max_gene_length_evt,
                    visual_mode_evt,
                    theme_mode_evt,
                    colorblind_evt,
                    as.logical(neighbor_evt),
                    seq_len_evt
                )
            })

            output$plot <- bindEvent(renderGirafe({
                on.exit(notify_plot_ready(), add = TRUE)
                req(data)
                info <- gene_info()
                if (!isTRUE(prefetch_neighbor_context) && !isTRUE(neighbor_context_resolved()) && is.null(precomputed_neighbor_context)) {
                    lazy_ctx <- tryCatch(
                        resolve_neighbor_context_sync("neighbor context lazy"),
                        error = function(e) {
                            app_perf_mark(module_perf, sprintf("neighbor context lazy error: %s", as.character(e$message %||% "unknown")), "ORTHO_MOD")
                            NULL
                        }
                    )
                    neighbor_context(lazy_ctx)
                    neighbor_context_resolved(TRUE)
                }
                if (!isTRUE(prefetch_sequence) && is.null(info)) {
                    app_perf_mark(module_perf, "lazy sequence fetch start", "ORTHO_MOD")
                    info <- tryCatch(
                        resolve_gene_info_sync("lazy_fetch"),
                        error = function(e) {
                            app_perf_mark(module_perf, sprintf("lazy fetch error: %s", as.character(e$message %||% "unknown")), "ORTHO_MOD")
                            list(sequence = "", file_content = "")
                        }
                    )
                    gene_info(info)
                }
                current_neighbor_context <- if (isTRUE(prefetch_neighbor_context)) neighbor_context() else isolate(neighbor_context())
                app_perf_mark(module_perf, sprintf("render start info_ready=%s", ifelse(is.null(info), "FALSE", "TRUE")), "ORTHO_MOD")
                if (isTRUE(prefetch_sequence)) {
                    req(!is.null(info))
                }
                width_svg <- 16.7
                
                # Detectamos el modo visual AHORA para darle la altura exacta al SVG
                this_visual_mode <- "compact"
                if (!is.null(visual_mode)) {
                    candidate_mode <- tryCatch(as.character(visual_mode())[1], error = function(e) NA_character_)
                    if (tolower(candidate_mode %||% "compact") %in% c("compact", "detailed")) {
                        this_visual_mode <- tolower(candidate_mode)
                    }
                }

                # Si es compacta, el lienzo es delgado. Si es detallada, crece.
                height_svg <- if (this_visual_mode == "compact") 1.15 else 1.85
                # Reuse preprocessed structures computed at module init.
                df <- processed_cache$df
                df_gene <- processed_cache$df_gene
                df_transcript <- processed_cache$df_transcript

                composicion_secuencia <- "Sequence Composition: N/A (genome FASTA not available)"
                if (!is.null(info) && !is.null(info$sequence) && nzchar(info$sequence)) {
                    seq_info <- calculate_sequence_composition(info$sequence)
                    composicion_secuencia <- seq_info$composition
                }

                transcript_start <- suppressWarnings(min(df$xstart, na.rm = TRUE))
                transcript_end <- suppressWarnings(max(df$xend, na.rm = TRUE))
                if (!is.finite(transcript_start) || !is.finite(transcript_end) || transcript_end <= transcript_start) {
                    transcript_start <- suppressWarnings(min(df_gene$V4, na.rm = TRUE))
                    transcript_end <- suppressWarnings(max(df_gene$V5, na.rm = TRUE))
                }
                current_transcript_length <- as.numeric(transcript_end - transcript_start + 1)
                if (!is.finite(current_transcript_length) || current_transcript_length <= 0) current_transcript_length <- 1
                length_difference <- max(0, max_gene_length() - current_transcript_length)

                gene_length_bp <- if (nrow(df_gene) > 0) as.numeric(max(df_gene$V5) - min(df_gene$V4) + 1) else current_transcript_length
                gene_length_label <- sprintf("Gene Length: %s pb", format(as.integer(round(gene_length_bp)), big.mark = ","))
                transcript_length_label <- sprintf("Transcript Length: %s pb", format(as.integer(round(current_transcript_length)), big.mark = ","))

                this_visual_mode <- "compact"
                if (!is.null(visual_mode)) {
                    candidate_mode <- tryCatch(as.character(visual_mode())[1], error = function(e) NA_character_)
                    candidate_mode <- tolower(candidate_mode %||% "compact")
                    if (candidate_mode %in% c("compact", "detailed")) this_visual_mode <- candidate_mode
                }
                theme_mode <- "light"
                if (!is.null(app_theme)) {
                    theme_mode <- tryCatch(as.character(app_theme())[1], error = function(e) "light")
                }
                theme_mode <- tolower(theme_mode %||% "light")
                is_dark_theme <- identical(theme_mode, "dark")

                is_colorblind_mode <- FALSE
                if (!is.null(app_colorblind)) {
                    is_colorblind_mode <- tryCatch(isTRUE(app_colorblind()), error = function(e) FALSE)
                }

                cache_enabled <- isTRUE(is_ortho_plot_cache_enabled())
                max_gene_length_key <- suppressWarnings(as.numeric(max_gene_length() %||% 0))
                if (!is.finite(max_gene_length_key)) max_gene_length_key <- 0
                seq_len_key <- 0L
                if (!is.null(info) && !is.null(info$sequence)) {
                    seq_len_key <- suppressWarnings(as.integer(nchar(as.character(info$sequence %||% ""))))
                    if (!is.finite(seq_len_key)) seq_len_key <- 0L
                }
                has_neighbor_context <- !is.null(current_neighbor_context)
                cache_key <- paste(
                    as.character(plotIndex %||% ""),
                    format(max_gene_length_key, scientific = FALSE, trim = TRUE),
                    this_visual_mode,
                    theme_mode,
                    as.character(isTRUE(is_colorblind_mode)),
                    as.character(seq_len_key),
                    as.character(isTRUE(has_neighbor_context)),
                    sep = "|"
                )

                if (cache_enabled) {
                    if (identical(cached_plot_key(), cache_key)) {
                        cached_plot <- cached_plot_obj()
                        if (!is.null(cached_plot)) {
                            app_perf_mark(module_perf, "render cache hit", "ORTHO_MOD")
                            return(refresh_girafe_widget_uid(cached_plot))
                        }
                    }
                    app_perf_mark(module_perf, "render cache miss", "ORTHO_MOD")
                } else {
                    app_perf_mark(module_perf, "render cache disabled", "ORTHO_MOD")
                    if (!identical(cached_plot_key(), "") || !is.null(cached_plot_obj())) {
                        cached_plot_key("")
                        cached_plot_obj(NULL)
                    }
                }

                app_perf_mark(module_perf, "create_gene_plot start", "ORTHO_MOD")
                plot_obj <- create_gene_plot(
                    df, df_gene, df_transcript, current_transcript_length, length_difference,
                    composicion_secuencia, gene_length_label, transcript_length_label,
                    neighbor_context = current_neighbor_context,
                    visual_mode = this_visual_mode,
                    width_svg = width_svg,
                    height_svg = height_svg,
                    organism_label = organism_name,
                    annotation_file_path = annotation_file_path,
                    use_report_map = use_report_map,
                    report_path = report_path,
                    plot_id = as.character(plotIndex),
                    plot_context = "orthologous",
                    genome_fasta_path = genome_fasta_path,
                    is_dark_theme = is_dark_theme,
                    is_colorblind_mode = is_colorblind_mode,
                    gene_display_name = gene_name
                )
                app_perf_mark(module_perf, "create_gene_plot done", "ORTHO_MOD")
                if (cache_enabled) {
                    cached_plot_key(cache_key)
                    cached_plot_obj(plot_obj)
                }
                plot_obj
            }), render_trigger(), ignoreNULL = TRUE)
            outputOptions(output, "plot", suspendWhenHidden = TRUE)
            list(
                destroy = destroy_module,
                is_destroyed = function() {
                    isTRUE(module_destroyed)
                }
            )
        }
    )
}
