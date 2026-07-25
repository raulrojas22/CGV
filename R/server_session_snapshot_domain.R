init_session_snapshot_domain <- function(
    input,
    session,
    preferredSearchWorkflow_rv,
    homoSummaryVisible_rv,
    orthoSummaryVisible_rv,
    searchStatusHomologous_rv,
    searchStatusOrthologous_rv,
    genomeSourceHomologous_rv,
    genomeSourceOrthologous_rv,
    currentOrganismHomologous_rv,
    currentOrganismOrthologous_rv,
    plotCounterHomologous_rv,
    activePlotIdsHomologous_rv,
    titlesHomologous_rv,
    fileDataHomologous_rv,
    chrNamesHomologous_rv,
    genSequencesHomologous_rv,
    plotSignaturesHomologous_rv,
    annotationPathsHomologous_rv,
    genomePathsHomologous_rv,
    organismInfoHomologous_rv,
    plotMetricsHomologous_rv,
    plotGeneMetaHomologous_rv,
    existingPlotsHomologous_rv,
    closeObserversBoundHomologous_rv,
    plotCounterOrthologous_rv,
    activePlotIdsOrthologous_rv,
    titlesOrthologous_rv,
    fileDataOrthologous_rv,
    chrNamesOrthologous_rv,
    genSequencesOrthologous_rv,
    plotSignaturesOrthologous_rv,
    annotationPathsOrthologous_rv,
    genomePathsOrthologous_rv,
    organismInfoOrthologous_rv,
    plotMetricsOrthologous_rv,
    plotGeneMetaOrthologous_rv,
    existingPlotsOrthologous_rv,
    closeObserversBoundOrthologous_rv,
    clear_homologous_visualizations_fn,
    clear_orthologous_visualizations_fn,
    recalc_plot_ranges_homologous_fn,
    recalc_plot_ranges_orthologous_fn,
    summary_toggle_label_fn,
    begin_session_source_restore_fn = NULL
) {
    snapshot_plot_records <- function(ids, titles_map, file_data_map, chr_map, seq_map, sig_map, ann_map, genome_map, org_map, metrics_map, gene_meta_map) {
        ids_chr <- as.character(ids %||% integer(0))
        ids_chr <- ids_chr[nzchar(ids_chr)]
        records <- lapply(ids_chr, function(id_chr) {
            block_data <- tryCatch(file_data_map[[id_chr]], error = function(e) NULL)
            if (is.null(block_data) || !is.data.frame(block_data) || nrow(block_data) == 0) {
                return(NULL)
            }
            list(
                id = id_chr,
                title = as.character(titles_map[[id_chr]] %||% ""),
                plot_data = block_data,
                chr_name = as.character(chr_map[[id_chr]] %||% ""),
                sequence_blob = seq_map[[id_chr]] %||% "",
                plot_signature = as.character(sig_map[[id_chr]] %||% ""),
                annotation_path = as.character(ann_map[[id_chr]] %||% ""),
                genome_path = as.character(genome_map[[id_chr]] %||% ""),
                organism_info = org_map[[id_chr]] %||% list(),
                plot_metrics = metrics_map[[id_chr]] %||% list(),
                plot_gene_meta = gene_meta_map[[id_chr]] %||% list()
            )
        })
        Filter(Negate(is.null), records)
    }

    build_work_session_snapshot <- function() {
        homo_ids <- as.character(activePlotIdsHomologous_rv() %||% integer(0))
        ortho_ids <- as.character(activePlotIdsOrthologous_rv() %||% integer(0))

        list(
            schema_version = 1L,
            saved_at = as.character(format(Sys.time(), "%Y-%m-%d %H:%M:%S %z")),
            app = list(
                navtab = as.character(input$navtabs %||% "home"),
                preferred_workflow = as.character(preferredSearchWorkflow_rv() %||% "homologous"),
                app_theme = as.character(input$app_theme %||% "light"),
                homo_data_mode = as.character(input$homo_data_mode %||% "preloaded"),
                ortho_data_mode = as.character(input$ortho_data_mode %||% "preloaded"),
                homo_preloaded_species = as.character(input$homo_preloaded_species %||% ""),
                ortho_preloaded_species = as.character(input$ortho_preloaded_species %||% character(0)),
                homo_visual_mode = as.character(input$homo_visual_mode %||% "compact"),
                ortho_visual_mode = as.character(input$ortho_visual_mode %||% "compact"),
                homo_sort_mode = as.character(input$homo_sort_mode %||% "load"),
                ortho_sort_mode = as.character(input$ortho_sort_mode %||% "load"),
                ext_alias_source_mygene = isTRUE(input$ext_alias_source_mygene %||% TRUE),
                ext_alias_source_ncbi = isTRUE(input$ext_alias_source_ncbi %||% TRUE),
                ext_alias_source_uniprot = isTRUE(input$ext_alias_source_uniprot %||% TRUE),
                ext_alias_source_ensembl = isTRUE(input$ext_alias_source_ensembl %||% TRUE),
                homo_summary_visible = isTRUE(homoSummaryVisible_rv()),
                ortho_summary_visible = isTRUE(orthoSummaryVisible_rv()),
                search_status_homo = as.character(searchStatusHomologous_rv() %||% ""),
                search_status_ortho = as.character(searchStatusOrthologous_rv() %||% ""),
                genome_source_homo = as.character(genomeSourceHomologous_rv() %||% ""),
                genome_source_ortho = as.character(genomeSourceOrthologous_rv() %||% ""),
                current_organism_homo = currentOrganismHomologous_rv(),
                current_organism_ortho = currentOrganismOrthologous_rv(),
                figure_studio_state = as.character(input$figure_studio_state %||% ""),
                global_search_query = as.character(input$global_search_query %||% ""),
                global_search_query_collapsed = as.character(input$global_search_query_collapsed %||% ""),
                filter1 = as.character(input$filter1 %||% ""),
                gene_name = as.character(input$gene_name %||% ""),
                global_search_chip_payload = as.character(unlist(input$global_search_chip_payload %||% character(0), use.names = FALSE))
            ),
            homologous = list(
                plot_counter = as.integer(plotCounterHomologous_rv() %||% 0L),
                plots = snapshot_plot_records(
                    ids = homo_ids,
                    titles_map = titlesHomologous_rv(),
                    file_data_map = fileDataHomologous_rv(),
                    chr_map = chrNamesHomologous_rv(),
                    seq_map = genSequencesHomologous_rv(),
                    sig_map = plotSignaturesHomologous_rv(),
                    ann_map = annotationPathsHomologous_rv(),
                    genome_map = genomePathsHomologous_rv(),
                    org_map = organismInfoHomologous_rv(),
                    metrics_map = plotMetricsHomologous_rv(),
                    gene_meta_map = plotGeneMetaHomologous_rv()
                )
            ),
            orthologous = list(
                plot_counter = as.integer(plotCounterOrthologous_rv() %||% 0L),
                plots = snapshot_plot_records(
                    ids = ortho_ids,
                    titles_map = titlesOrthologous_rv(),
                    file_data_map = fileDataOrthologous_rv(),
                    chr_map = chrNamesOrthologous_rv(),
                    seq_map = genSequencesOrthologous_rv(),
                    sig_map = plotSignaturesOrthologous_rv(),
                    ann_map = annotationPathsOrthologous_rv(),
                    genome_map = genomePathsOrthologous_rv(),
                    org_map = organismInfoOrthologous_rv(),
                    metrics_map = plotMetricsOrthologous_rv(),
                    gene_meta_map = plotGeneMetaOrthologous_rv()
                )
            )
        )
    }

    normalize_snapshot_plot_table <- function(panel_state) {
        plots <- panel_state$plots
        if (is.null(plots) || !is.list(plots) || length(plots) == 0) {
            return(list())
        }
        out <- list()
        for (i in seq_along(plots)) {
            p <- plots[[i]]
            if (!is.list(p)) next
            block_data <- p$plot_data
            if (is.null(block_data) || !is.data.frame(block_data) || nrow(block_data) == 0) next

            id_chr <- trimws(as.character(p$id %||% ""))
            if (!nzchar(id_chr)) {
                id_chr <- as.character(i)
            }
            if (!is.na(suppressWarnings(as.integer(id_chr))) && nzchar(id_chr) && !id_chr %in% names(out)) {
                out[[id_chr]] <- list(
                    title = as.character(p$title %||% ""),
                    plot_data = block_data,
                    chr_name = as.character(p$chr_name %||% ""),
                    sequence_blob = p$sequence_blob %||% "",
                    plot_signature = as.character(p$plot_signature %||% ""),
                    annotation_path = as.character(p$annotation_path %||% ""),
                    genome_path = as.character(p$genome_path %||% ""),
                    organism_info = p$organism_info %||% list(),
                    plot_metrics = p$plot_metrics %||% list(),
                    plot_gene_meta = p$plot_gene_meta %||% list()
                )
            }
        }
        out
    }

    restore_panel_from_snapshot <- function(panel_state, panel = c("homologous", "orthologous")) {
        panel <- match.arg(panel)
        normalized <- normalize_snapshot_plot_table(panel_state %||% list())
        ids_chr <- names(normalized)
        if (length(ids_chr) == 0) {
            if (identical(panel, "homologous")) {
                clear_homologous_visualizations_fn()
                plotCounterHomologous_rv(0L)
            } else {
                clear_orthologous_visualizations_fn()
                plotCounterOrthologous_rv(0L)
            }
            return(invisible(0L))
        }

        ids_int <- suppressWarnings(as.integer(ids_chr))
        valid <- is.finite(ids_int)
        normalized <- normalized[valid]
        ids_chr <- names(normalized)
        ids_int <- as.integer(ids_int[valid])
        if (length(ids_chr) == 0) {
            if (identical(panel, "homologous")) {
                clear_homologous_visualizations_fn()
                plotCounterHomologous_rv(0L)
            } else {
                clear_orthologous_visualizations_fn()
                plotCounterOrthologous_rv(0L)
            }
            return(invisible(0L))
        }
        ord <- order(ids_int)
        ids_chr <- ids_chr[ord]
        ids_int <- ids_int[ord]

        titles_map <- list()
        file_map <- list()
        chr_map <- list()
        seq_map <- list()
        sig_map <- list()
        ann_map <- list()
        genome_map <- list()
        org_map <- list()
        metrics_map <- list()
        gene_meta_map <- list()

        for (id_chr in ids_chr) {
            p <- normalized[[id_chr]]
            titles_map[[id_chr]] <- as.character(p$title %||% "")
            file_map[[id_chr]] <- p$plot_data
            chr_map[[id_chr]] <- as.character(p$chr_name %||% "")
            seq_map[[id_chr]] <- p$sequence_blob %||% ""
            sig_map[[id_chr]] <- as.character(p$plot_signature %||% "")
            ann_map[[id_chr]] <- as.character(p$annotation_path %||% "")
            genome_map[[id_chr]] <- as.character(p$genome_path %||% "")
            org_map[[id_chr]] <- p$organism_info %||% list()
            metrics_map[[id_chr]] <- p$plot_metrics %||% list()
            gene_meta_map[[id_chr]] <- p$plot_gene_meta %||% list()
        }

        counter_in <- suppressWarnings(as.integer(panel_state$plot_counter %||% max(ids_int)))
        if (!is.finite(counter_in)) counter_in <- max(ids_int)
        counter_out <- as.integer(max(counter_in, max(ids_int)))

        if (identical(panel, "homologous")) {
            clear_homologous_visualizations_fn()
            titlesHomologous_rv(titles_map)
            fileDataHomologous_rv(file_map)
            chrNamesHomologous_rv(chr_map)
            genSequencesHomologous_rv(seq_map)
            plotSignaturesHomologous_rv(sig_map)
            annotationPathsHomologous_rv(ann_map)
            genomePathsHomologous_rv(genome_map)
            organismInfoHomologous_rv(org_map)
            plotMetricsHomologous_rv(metrics_map)
            plotGeneMetaHomologous_rv(gene_meta_map)
            existingPlotsHomologous_rv(list())
            closeObserversBoundHomologous_rv(character())
            recalc_plot_ranges_homologous_fn()
            activePlotIdsHomologous_rv(ids_int)
            plotCounterHomologous_rv(counter_out)
        } else {
            clear_orthologous_visualizations_fn()
            titlesOrthologous_rv(titles_map)
            fileDataOrthologous_rv(file_map)
            chrNamesOrthologous_rv(chr_map)
            genSequencesOrthologous_rv(seq_map)
            plotSignaturesOrthologous_rv(sig_map)
            annotationPathsOrthologous_rv(ann_map)
            genomePathsOrthologous_rv(genome_map)
            organismInfoOrthologous_rv(org_map)
            plotMetricsOrthologous_rv(metrics_map)
            plotGeneMetaOrthologous_rv(gene_meta_map)
            existingPlotsOrthologous_rv(list())
            closeObserversBoundOrthologous_rv(character())
            recalc_plot_ranges_orthologous_fn()
            activePlotIdsOrthologous_rv(ids_int)
            plotCounterOrthologous_rv(counter_out)
        }
        invisible(as.integer(length(ids_chr)))
    }

    restore_species_grid_selection <- function(input_id, species_ids = character(0), mode = "single") {
        ids <- as.character(species_ids %||% character(0))
        ids <- unique(ids[nzchar(ids)])
        input_json <- jsonlite::toJSON(as.character(input_id %||% ""), auto_unbox = TRUE)
        ids_json <- jsonlite::toJSON(ids, auto_unbox = FALSE)
        mode_json <- jsonlite::toJSON(as.character(mode %||% "single"), auto_unbox = TRUE)
        js <- sprintf(
            paste(
                "(function(){",
                "  var inputId = %s;",
                "  var ids = %s;",
                "  var mode = %s;",
                "  var tries = 0;",
                "  var timer = window.setInterval(function(){",
                "    tries += 1;",
                "    var $grids = $('.species-grid[data-input-id=\"' + inputId + '\"]');",
                "    if (!$grids.length && tries < 24) return;",
                "    window.clearInterval(timer);",
                "    if ($grids.length) {",
                "      var idSet = {};",
                "      ids.forEach(function(v){ idSet[String(v)] = true; });",
                "      $grids.find('.species-grid-card').removeClass('selected').each(function(){",
                "        var sid = String($(this).attr('data-species-id') || '');",
                "        if (idSet[sid]) $(this).addClass('selected');",
                "      });",
                "      if (typeof updateOrganismSummaryFromGrid === 'function') {",
                "        $grids.each(function(){ updateOrganismSummaryFromGrid($(this)); });",
                "      }",
                "    }",
                "    var payload = null;",
                "    if (mode === 'single') {",
                "      payload = ids.length ? ids[0] : null;",
                "    } else {",
                "      payload = ids.length ? ids : null;",
                "    }",
                "    if (window.Shiny && typeof Shiny.setInputValue === 'function') {",
                "      Shiny.setInputValue(inputId, payload, {priority:'event'});",
                "      window.setTimeout(function(){",
                "        Shiny.setInputValue('cgv_session_source_restored',",
                "          {input_id: inputId, nonce: Date.now() + Math.random()},",
                "          {priority:'event'});",
                "      }, 30);",
                "    }",
                "  }, 80);",
                "})();",
                sep = "\n"
            ),
            input_json,
            ids_json,
            mode_json
        )
        shinyjs::runjs(js)
        invisible(NULL)
    }

    apply_summary_visibility_ui <- function() {
        homo_open <- isTRUE(homoSummaryVisible_rv()) && length(activePlotIdsHomologous_rv()) > 0
        ortho_open <- isTRUE(orthoSummaryVisible_rv()) && length(activePlotIdsOrthologous_rv()) > 0
        shinyjs::runjs(sprintf("document.getElementById('homo_summary_body').style.display='%s';", ifelse(homo_open, "block", "none")))
        shinyjs::runjs(sprintf("document.getElementById('ortho_summary_body').style.display='%s';", ifelse(ortho_open, "block", "none")))
        updateActionButton(
            session,
            "toggle_homo_summary",
            label = summary_toggle_label_fn(is_expanded = homo_open)
        )
        updateActionButton(
            session,
            "toggle_ortho_summary",
            label = summary_toggle_label_fn(is_expanded = ortho_open)
        )
        if (homo_open) {
            shinyjs::runjs(
                "setTimeout(function(){var $tb = $('#homo_summary_dt table.dataTable'); if($tb.length && $.fn.dataTable && $.fn.dataTable.isDataTable($tb)){ $tb.DataTable().columns.adjust().draw(false); }}, 80);"
            )
        }
        if (ortho_open) {
            shinyjs::runjs(
                "setTimeout(function(){var $tb = $('#ortho_summary_dt table.dataTable'); if($tb.length && $.fn.dataTable && $.fn.dataTable.isDataTable($tb)){ $tb.DataTable().columns.adjust().draw(false); }}, 80);"
            )
        }
        invisible(NULL)
    }

    apply_app_state_from_snapshot <- function(app_state = list()) {
        state <- app_state %||% list()
        mode_homo <- tolower(trimws(as.character(state$homo_data_mode %||% "preloaded")))
        mode_ortho <- tolower(trimws(as.character(state$ortho_data_mode %||% "preloaded")))
        if (!mode_homo %in% c("preloaded", "ncbi", "upload")) mode_homo <- "preloaded"
        if (!mode_ortho %in% c("preloaded", "ncbi", "upload", "mixed")) mode_ortho <- "preloaded"

        homo_species <- as.character(state$homo_preloaded_species %||% "")
        ortho_species <- as.character(state$ortho_preloaded_species %||% character(0))
        if (is.function(begin_session_source_restore_fn)) {
            homo_source_detail <- if (identical(mode_homo, "preloaded")) homo_species else ""
            ortho_source_detail <- if (mode_ortho %in% c("preloaded", "mixed")) {
                paste(sort(ortho_species), collapse = "|")
            } else {
                ""
            }
            begin_session_source_restore_fn(
                "homologous",
                paste(mode_homo, homo_source_detail, sep = "::")
            )
            begin_session_source_restore_fn(
                "orthologous",
                paste(mode_ortho, ortho_source_detail, sep = "::")
            )
        }

        updateRadioButtons(session, "homo_data_mode", selected = mode_homo)
        updateRadioButtons(session, "ortho_data_mode", selected = mode_ortho)

        homo_visual <- tolower(trimws(as.character(state$homo_visual_mode %||% "compact")))
        ortho_visual <- tolower(trimws(as.character(state$ortho_visual_mode %||% "compact")))
        if (!homo_visual %in% c("compact", "detailed")) homo_visual <- "compact"
        if (!ortho_visual %in% c("compact", "detailed", "aligned")) ortho_visual <- "compact"
        updateRadioButtons(session, "homo_visual_mode", selected = homo_visual)
        updateRadioButtons(session, "ortho_visual_mode", selected = ortho_visual)

        allowed_homo_sort <- c("load", "exondiff_desc", "exondiff_asc", "tx_len_desc", "tx_len_asc", "exon_desc", "exon_asc", "tx_asc", "tx_desc", "chr_asc", "chr_desc")
        allowed_ortho_sort <- c("load", "exondiff_desc", "exondiff_asc", "tx_len_desc", "tx_len_asc", "exon_desc", "exon_asc", "organism_asc", "organism_desc", "tx_asc", "tx_desc")
        homo_sort <- tolower(trimws(as.character(state$homo_sort_mode %||% "load")))
        ortho_sort <- tolower(trimws(as.character(state$ortho_sort_mode %||% "load")))
        if (!homo_sort %in% allowed_homo_sort) homo_sort <- "load"
        if (!ortho_sort %in% allowed_ortho_sort) ortho_sort <- "load"
        updateSelectInput(session, "homo_sort_mode", selected = homo_sort)
        updateSelectInput(session, "ortho_sort_mode", selected = ortho_sort)

        updateCheckboxInput(session, "ext_alias_source_mygene", value = isTRUE(state$ext_alias_source_mygene %||% TRUE))
        updateCheckboxInput(session, "ext_alias_source_ncbi", value = isTRUE(state$ext_alias_source_ncbi %||% TRUE))
        updateCheckboxInput(session, "ext_alias_source_uniprot", value = isTRUE(state$ext_alias_source_uniprot %||% TRUE))
        updateCheckboxInput(session, "ext_alias_source_ensembl", value = isTRUE(state$ext_alias_source_ensembl %||% TRUE))

        restore_species_grid_selection("homo_preloaded_species", if (nzchar(homo_species)) homo_species else character(0), mode = "single")
        restore_species_grid_selection("ortho_preloaded_species", ortho_species, mode = "multi")

        updateTextInput(session, "global_search_query", value = as.character(state$global_search_query %||% ""))
        updateTextInput(session, "global_search_query_collapsed", value = as.character(state$global_search_query_collapsed %||% ""))
        updateTextInput(session, "filter1", value = as.character(state$filter1 %||% ""))
        updateTextInput(session, "gene_name", value = as.character(state$gene_name %||% ""))

        preferred <- tolower(trimws(as.character(state$preferred_workflow %||% "homologous")))
        if (!preferred %in% c("homologous", "orthologous")) preferred <- "homologous"
        preferredSearchWorkflow_rv(preferred)

        theme_mode <- tolower(trimws(as.character(state$app_theme %||% "light")))
        if (!theme_mode %in% c("light", "dark")) theme_mode <- "light"
        theme_json <- jsonlite::toJSON(theme_mode, auto_unbox = TRUE)
        shinyjs::runjs(sprintf("setTimeout(function(){ if (typeof applyTheme === 'function') { applyTheme(%s); } }, 20);", theme_json))

        nav_target <- tolower(trimws(as.character(state$navtab %||% preferred)))
        if (!nav_target %in% c("home", "homologous", "orthologous", "figure-studio", "desktop-app", "settings", "help", "feedback")) nav_target <- preferred
        updateTabsetPanel(session, "navtabs", selected = nav_target)

        searchStatusHomologous_rv(as.character(state$search_status_homo %||% "Ready."))
        searchStatusOrthologous_rv(as.character(state$search_status_ortho %||% "Ready."))
        genomeSourceHomologous_rv(as.character(state$genome_source_homo %||% "N/A"))
        genomeSourceOrthologous_rv(as.character(state$genome_source_ortho %||% "N/A"))
        currentOrganismHomologous_rv(state$current_organism_homo %||% NULL)
        currentOrganismOrthologous_rv(state$current_organism_ortho %||% list())
        homoSummaryVisible_rv(isTRUE(state$homo_summary_visible))
        orthoSummaryVisible_rv(isTRUE(state$ortho_summary_visible))

        invisible(NULL)
    }

    apply_work_session_snapshot <- function(snapshot_obj) {
        snap <- snapshot_obj %||% list()
        if (!is.list(snap)) {
            stop("Invalid session file format.")
        }
        schema_version <- suppressWarnings(as.integer(snap$schema_version %||% 0L))
        if (!is.finite(schema_version) || schema_version < 1L) {
            stop("Unsupported session schema version.")
        }

        apply_app_state_from_snapshot(snap$app %||% list())
        restored_h <- restore_panel_from_snapshot(snap$homologous %||% list(), panel = "homologous")
        restored_o <- restore_panel_from_snapshot(snap$orthologous %||% list(), panel = "orthologous")
        apply_summary_visibility_ui()
        visual_state <- snap$app %||% list()
        session$onFlushed(function() {
            homo_visual <- tolower(trimws(as.character(visual_state$homo_visual_mode %||% "compact")))
            ortho_visual <- tolower(trimws(as.character(visual_state$ortho_visual_mode %||% "compact")))
            if (!homo_visual %in% c("compact", "detailed")) homo_visual <- "compact"
            if (!ortho_visual %in% c("compact", "detailed", "aligned")) ortho_visual <- "compact"
            updateRadioButtons(session, "homo_visual_mode", selected = homo_visual)
            updateRadioButtons(session, "ortho_visual_mode", selected = ortho_visual)
            shinyjs::runjs(
                "setTimeout(function(){if(window.syncVizModeToggles){window.syncVizModeToggles();}if(window.updateCompactModeLayoutState){window.updateCompactModeLayoutState();}},0);"
            )
            studio_state <- as.character(visual_state$figure_studio_state %||% "")
            if (nzchar(studio_state)) {
                session$sendCustomMessage("cgv:figure-studio-restore", studio_state)
            }
        }, once = TRUE)

        list(homologous = restored_h, orthologous = restored_o)
    }

    list(
        snapshot_plot_records = snapshot_plot_records,
        build_work_session_snapshot = build_work_session_snapshot,
        normalize_snapshot_plot_table = normalize_snapshot_plot_table,
        restore_panel_from_snapshot = restore_panel_from_snapshot,
        restore_species_grid_selection = restore_species_grid_selection,
        apply_summary_visibility_ui = apply_summary_visibility_ui,
        apply_app_state_from_snapshot = apply_app_state_from_snapshot,
        apply_work_session_snapshot = apply_work_session_snapshot
    )
}
