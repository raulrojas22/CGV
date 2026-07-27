#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
    if (is.null(x) || length(x) == 0L) y else x
}

suppressPackageStartupMessages(library(shiny))
source(file.path("R", "server_plot_lifecycle_domain.R"))

make_plot_df <- function(start, end) {
    data.frame(
        V3 = "transcript",
        V4 = as.numeric(start),
        V5 = as.numeric(end),
        stringsAsFactors = FALSE
    )
}

make_domain <- function() {
    rv_list <- function(value = list()) shiny::reactiveVal(value)
    rv_num <- function(value) shiny::reactiveVal(value)
    mock_session <- shiny::MockShinySession$new()
    args <- list(
        input = list(),
        output = new.env(parent = emptyenv()),
        session = mock_session,
        preferredSearchWorkflow_fn = function() "homologous",
        preloadedRegistry_rv = rv_list(),
        searchStatusHomologous_rv = rv_list(character()),
        searchStatusOrthologous_rv = rv_list(character()),
        activePlotIdsHomologous_rv = rv_list(integer()),
        titlesHomologous_rv = rv_list(),
        existingPlotsHomologous_rv = rv_list(),
        fileDataHomologous_rv = rv_list(),
        chrNamesHomologous_rv = rv_list(),
        genSequencesHomologous_rv = rv_list(),
        plotSignaturesHomologous_rv = rv_list(),
        annotationPathsHomologous_rv = rv_list(),
        genomePathsHomologous_rv = rv_list(),
        organismInfoHomologous_rv = rv_list(),
        plotMetricsHomologous_rv = rv_list(),
        plotGeneMetaHomologous_rv = rv_list(),
        closeObserversBoundHomologous_rv = rv_list(character()),
        activePlotIdsOrthologous_rv = rv_list(integer()),
        titlesOrthologous_rv = rv_list(),
        existingPlotsOrthologous_rv = rv_list(),
        fileDataOrthologous_rv = rv_list(),
        chrNamesOrthologous_rv = rv_list(),
        genSequencesOrthologous_rv = rv_list(),
        plotSignaturesOrthologous_rv = rv_list(),
        annotationPathsOrthologous_rv = rv_list(),
        genomePathsOrthologous_rv = rv_list(),
        organismInfoOrthologous_rv = rv_list(),
        plotMetricsOrthologous_rv = rv_list(),
        plotGeneMetaOrthologous_rv = rv_list(),
        closeObserversBoundOrthologous_rv = rv_list(character()),
        homoRenderedPlotIds_rv = rv_list(character()),
        homoInsertedCardIds_rv = rv_list(character()),
        homoFooterOutputsBound_rv = rv_list(character()),
        homoDownloadOutputsBound_rv = rv_list(character()),
        homoPlotTimingTracker_rv = rv_list(),
        orthoRenderedPlotIds_rv = rv_list(character()),
        orthoInsertedCardIds_rv = rv_list(character()),
        orthoFooterOutputsBound_rv = rv_list(character()),
        orthoDownloadOutputsBound_rv = rv_list(character()),
        orthoPlotTimingTracker_rv = rv_list(),
        homoVisibleCount_rv = rv_num(1L),
        homoInitialVisibleCount = 1L,
        orthoVisibleCount_rv = rv_num(1L),
        orthoInitialVisibleCount = 1L,
        max_gene_length_homo_rv = rv_num(0),
        min_gene_coord_homo_rv = rv_num(Inf),
        max_gene_coord_homo_rv = rv_num(-Inf),
        max_gene_length_ortho_rv = rv_num(0),
        min_gene_coord_ortho_rv = rv_num(Inf),
        max_gene_coord_ortho_rv = rv_num(-Inf),
        orthoAlignedRenderCache_rv = rv_list(),
        orthoAlignedTrackCache_env = new.env(parent = emptyenv()),
        orthoAlignedSceneCache_env = new.env(parent = emptyenv()),
        orthoAlignedPlotCache_env = new.env(parent = emptyenv()),
        orthoAlignedSeqCache_env = new.env(parent = emptyenv()),
        orthoAlignedGcCache_env = new.env(parent = emptyenv()),
        orthoHomologyCache_env = new.env(parent = emptyenv()),
        clear_summary_cache_scope_fn = function(...) invisible(NULL),
        clear_analytics_cache_scope_fn = function(...) invisible(NULL),
        empty_plot_timing_tracker_fn = function() list(),
        drop_plot_timing_id_fn = function(...) invisible(NULL),
        mark_plot_ready_timing_fn = function(...) invisible(NULL),
        append_status_fn = function(...) invisible(NULL),
        emit_popup_status_fn = function(...) invisible(NULL)
    )
    list(domain = do.call(init_plot_lifecycle_domain, args), args = args)
}

fixture <- make_domain()
domain <- fixture$domain
args <- fixture$args

short_gene <- make_plot_df(101, 200)
long_gene <- make_plot_df(1001, 1500)
stale_copy <- make_plot_df(5001, 6000)

args$fileDataHomologous_rv(list(
    "1" = short_gene,
    "2" = long_gene,
    "2_c" = stale_copy
))
args$activePlotIdsHomologous_rv(c(1L, 2L))
shiny::isolate(domain$recalc_plot_ranges_homologous())
stopifnot(identical(shiny::isolate(args$max_gene_length_homo_rv()), 500))

args$activePlotIdsHomologous_rv(1L)
shiny::isolate(domain$recalc_plot_ranges_homologous())
stopifnot(identical(shiny::isolate(args$max_gene_length_homo_rv()), 100))
stopifnot(identical(shiny::isolate(args$min_gene_coord_homo_rv()), 101))
stopifnot(identical(shiny::isolate(args$max_gene_coord_homo_rv()), 200))

args$fileDataOrthologous_rv(list(
    "1" = short_gene,
    "2" = long_gene,
    "2_c" = stale_copy
))
args$activePlotIdsOrthologous_rv(c(1L, 2L))
shiny::isolate(domain$recalc_plot_ranges_orthologous())
stopifnot(identical(shiny::isolate(args$max_gene_length_ortho_rv()), 500))

args$activePlotIdsOrthologous_rv(1L)
shiny::isolate(domain$recalc_plot_ranges_orthologous())
stopifnot(identical(shiny::isolate(args$max_gene_length_ortho_rv()), 100))

args$fileDataHomologous_rv(list(
    "1" = short_gene,
    "2" = long_gene,
    "3" = make_plot_df(1101, 1450),
    "2_c" = long_gene
))
args$activePlotIdsHomologous_rv(c(1L, 2L, 3L))
args$annotationPathsHomologous_rv(list(
    "1" = "annotation-a.gff",
    "2" = "annotation-a.gff",
    "3" = "annotation-a.gff",
    "2_c" = "annotation-a.gff"
))
args$organismInfoHomologous_rv(list(
    "1" = list(name = "Species A"),
    "2" = list(name = "Species A"),
    "3" = list(name = "Species A"),
    "2_c" = list(name = "Species A")
))
args$plotGeneMetaHomologous_rv(list(
    "1" = list(is_canonical = TRUE, matched_gene_id = "gene-short"),
    "2" = list(is_canonical = TRUE, matched_gene_id = "gene-long"),
    "3" = list(is_canonical = FALSE, matched_gene_id = "gene-long"),
    "2_c" = list(
        is_canonical = FALSE,
        is_canonical_copy = TRUE,
        matched_gene_id = "gene-long"
    )
))
shiny::withReactiveDomain(
    args$session,
    shiny::isolate(domain$remove_homologous_plot("2", announce = FALSE))
)
stopifnot(identical(shiny::isolate(args$activePlotIdsHomologous_rv()), 1L))
stopifnot(identical(names(shiny::isolate(args$fileDataHomologous_rv())), "1"))
stopifnot(identical(shiny::isolate(args$max_gene_length_homo_rv()), 100))

args$fileDataOrthologous_rv(list(
    "1" = short_gene,
    "2" = long_gene,
    "3" = make_plot_df(1101, 1450),
    "2_c" = long_gene
))
args$activePlotIdsOrthologous_rv(c(1L, 2L, 3L))
args$annotationPathsOrthologous_rv(list(
    "1" = "annotation-a.gff",
    "2" = "annotation-b.gff",
    "3" = "annotation-b.gff",
    "2_c" = "annotation-b.gff"
))
args$organismInfoOrthologous_rv(list(
    "1" = list(name = "Species A"),
    "2" = list(name = "Species B"),
    "3" = list(name = "Species B"),
    "2_c" = list(name = "Species B")
))
args$plotGeneMetaOrthologous_rv(list(
    "1" = list(is_canonical = TRUE, matched_gene_id = "gene-family"),
    "2" = list(is_canonical = TRUE, matched_gene_id = "gene-family"),
    "3" = list(is_canonical = FALSE, matched_gene_id = "gene-family"),
    "2_c" = list(
        is_canonical = FALSE,
        is_canonical_copy = TRUE,
        matched_gene_id = "gene-family"
    )
))
shiny::withReactiveDomain(
    args$session,
    shiny::isolate(domain$remove_orthologous_plot("2", announce = FALSE))
)
stopifnot(identical(shiny::isolate(args$activePlotIdsOrthologous_rv()), 1L))
stopifnot(identical(names(shiny::isolate(args$fileDataOrthologous_rv())), "1"))
stopifnot(identical(shiny::isolate(args$max_gene_length_ortho_rv()), 100))

modules_txt <- paste(readLines(file.path("R", "modules.R"), warn = FALSE), collapse = "\n")
orthologous_trigger <- regmatches(
    modules_txt,
    regexpr(
        "plotServerOrtologous[\\s\\S]+?render_trigger <- reactive\\(\\{[\\s\\S]+?\\n            \\}\\)",
        modules_txt,
        perl = TRUE
    )
)
stopifnot(length(orthologous_trigger) == 1L)
stopifnot(grepl("max_gene_length\\(\\)", orthologous_trigger))
stopifnot(!grepl("isolate\\(max_gene_length\\(\\)\\)", orthologous_trigger))

message("Plot scale recalculation regression checks passed.")
