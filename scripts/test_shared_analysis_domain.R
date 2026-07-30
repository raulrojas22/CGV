#!/usr/bin/env Rscript

source("R/utils.R", local = TRUE)
source("R/server_shared_analysis_domain.R", local = TRUE)

test_root <- tempfile("cgv-shared-analysis-test-")
dir.create(test_root, recursive = TRUE)
on.exit(unlink(test_root, recursive = TRUE, force = TRUE), add = TRUE)
old_cache <- Sys.getenv("CGV_CACHE_DIR", unset = "")
on.exit(Sys.setenv(CGV_CACHE_DIR = old_cache), add = TRUE)
Sys.setenv(CGV_CACHE_DIR = file.path(test_root, "cache"))

absolute_annotation <- file.path(test_root, "private", "annotation.gff3")
absolute_genome <- file.path(test_root, "private", "genome.fa")
dir.create(dirname(absolute_annotation), recursive = TRUE)
writeLines("##gff-version 3", absolute_annotation)
writeLines(c(">chr1", "ACGTACGT"), absolute_genome)

plot_record <- list(
    id = "1",
    title = "Gene: TEST1 | Transcript: TX1",
    plot_data = data.frame(
        type = c("gene", "exon"),
        start = c(1, 1),
        end = c(8, 4),
        stringsAsFactors = FALSE
    ),
    chr_name = "chr1",
    sequence_blob = ">TX1\nACGTACGT",
    plot_signature = "test-signature",
    annotation_path = absolute_annotation,
    genome_path = absolute_genome,
    organism_info = list(
        id = "test_species",
        name = "Test species",
        taxid = "1234",
        assembly_accession = "GCF_TEST"
    ),
    plot_metrics = list(length = 8L, gc = 50),
    plot_gene_meta = list(
        input = "TEST1",
        symbol = "TEST1",
        alias_source = "local",
        annotation_path = absolute_annotation,
        feature_notation = "/ deletion"
    )
)

legacy_snapshot <- list(
    schema_version = 1L,
    saved_at = "2026-07-27 10:00:00 -0400",
    app = list(
        preferred_workflow = "homologous",
        filter1 = "TEST1",
        homo_data_mode = "upload",
        homo_visual_mode = "compact",
        homo_sort_mode = "load",
        search_status_homo = "Ready.",
        figure_studio_state = "{\"version\":2,\"panels\":[]}"
    ),
    homologous = list(plot_counter = 1L, plots = list(plot_record)),
    orthologous = list(plot_counter = 0L, plots = list())
)

malicious_svg <- paste0(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"40\" ",
    "onload=\"alert(1)\"><script>alert(1)</script><script src=https://evil.example/x.js/>",
    "<style>@import url(https://evil.example/x.css);rect{fill:url(https://evil.example/x.svg)}</style>",
    "<a href=\"javascript:alert(2)\"><rect onmouseover=alert(3) width=\"100\" height=\"40\" data-tooltip=\"TEST1\"/></a>",
    "<image href=https://evil.example/x.png /></svg>"
)

payload <- list(
    assets = list(list(
        id = "test_plot",
        title = "TEST1 structure",
        group = "structural",
        context = "multi_gene",
        record_id = "1",
        gene = "TEST1",
        transcript = "TX1",
        organism = "Test species",
        svg = malicious_svg
    )),
    missing = "STRING: result was not generated"
)
summary_df <- data.frame(Gene = "TEST1", Transcript = "TX1", Length = 8L)

analysis <- cgv_build_analysis_manifest(
    snapshot = legacy_snapshot,
    homo_summary = summary_df,
    client_payload = payload,
    include_private = FALSE,
    allow_downloads = FALSE,
    ttl_days = 30L,
    app_version = "1.1.0",
    base_dir = test_root
)

stopifnot(identical(analysis$schema_version, 1L))
stopifnot(identical(analysis$privacy$private_data_included, FALSE))
stopifnot(length(analysis$references) == 1L)
stopifnot(grepl("^sha256:[a-f0-9]{64}$", analysis$references[[1L]]$assembly$checksum))
stopifnot(grepl("^sha256:[a-f0-9]{64}$", analysis$references[[1L]]$annotation$checksum))
stopifnot(length(analysis$figures) == 1L)
stopifnot(identical(analysis$figures[[1L]]$record_id, "1"))
stopifnot(identical(analysis$figures[[1L]]$gene, "TEST1"))
stopifnot(identical(analysis$figures[[1L]]$comparison_gene, ""))
stopifnot(identical(analysis$figures[[1L]]$transcript, "TX1"))
stopifnot(identical(analysis$figures[[1L]]$organism, "Test species"))
stopifnot(is.list(analysis$branding))
stopifnot(identical(analysis$results$structural[[1L]]$gene$annotation_path, ""))
stopifnot(identical(analysis$results$structural[[1L]]$gene$feature_notation, "/ deletion"))
stopifnot(is.null(analysis$results$structural[[1L]]$organism$icon_data_uri))
stopifnot(identical(analysis$capture$mode, "complete"))
stopifnot(length(analysis$capture$omitted) == 0L)
stopifnot(length(analysis$provenance$alias_decisions) == 1L)
stopifnot(isTRUE(cgv_validate_analysis_manifest(analysis)))
invalid_analysis <- analysis
invalid_analysis$provenance$internal_path <- absolute_annotation
stopifnot(grepl(
    "absolute internal path",
    tryCatch({
        cgv_validate_analysis_manifest(invalid_analysis)
        ""
    }, error = conditionMessage),
    fixed = TRUE
))
stopifnot(!grepl("<script", analysis$figures[[1L]]$svg, ignore.case = TRUE))
stopifnot(!grepl("onload", analysis$figures[[1L]]$svg, ignore.case = TRUE))
stopifnot(!grepl("onmouseover", analysis$figures[[1L]]$svg, ignore.case = TRUE))
stopifnot(!grepl("javascript:", analysis$figures[[1L]]$svg, ignore.case = TRUE))
stopifnot(!grepl("evil.example", analysis$figures[[1L]]$svg, ignore.case = TRUE))

package_path <- cgv_write_reproducibility_package(
    analysis = analysis,
    session_snapshot = legacy_snapshot,
    homo_summary = summary_df,
    include_private = FALSE,
    base_dir = test_root,
    artifacts = cgv_prepare_report_artifacts(analysis)
)
stopifnot(file.exists(package_path))

unzip_dir <- file.path(test_root, "unzipped")
utils::unzip(package_path, exdir = unzip_dir)
required <- c(
    "analysis.json",
    "README.md",
    "CHECKSUMS.sha256",
    "session/cgv_session.rds",
    "tables/multi_gene_summary.csv",
    "figures/test_plot.svg"
)
stopifnot(all(file.exists(file.path(unzip_dir, required))))
stopifnot(length(list.files(file.path(unzip_dir, "sequences"))) == 0L)

portable_session <- readRDS(file.path(unzip_dir, "session", "cgv_session.rds"))
stopifnot(identical(portable_session$schema_version, 2L))
stopifnot(identical(portable_session$homologous$plots[[1L]]$sequence_blob, ""))
stopifnot(!cgv_is_absolute_path(portable_session$homologous$plots[[1L]]$annotation_path))
stopifnot(!cgv_is_absolute_path(portable_session$homologous$plots[[1L]]$genome_path))

json_text <- paste(readLines(file.path(unzip_dir, "analysis.json"), warn = FALSE), collapse = "\n")
stopifnot(!grepl(test_root, json_text, fixed = TRUE))
stopifnot(grepl("TEST1", json_text, fixed = TRUE))
stopifnot(length(readLines(file.path(unzip_dir, "CHECKSUMS.sha256"), warn = FALSE)) >= 5L)
json_manifest <- jsonlite::read_json(file.path(unzip_dir, "analysis.json"), simplifyVector = FALSE)
stopifnot(is.list(json_manifest$query$genes), identical(json_manifest$query$genes[[1L]], "TEST1"))

report <- cgv_publish_static_report(
    analysis = analysis,
    package_path = package_path,
    allow_downloads = FALSE,
    base_dir = test_root
)
stopifnot(grepl("^[a-f0-9]{64}$", report$token))
stopifnot(file.exists(file.path(report$path, "index.html")))
stopifnot(!file.exists(file.path(report$path, "analysis.json")))
stopifnot(!dir.exists(file.path(report$path, "downloads")))
stopifnot(!cgv_revoke_static_report(report$token, cgv_random_secret(32L), test_root))
stopifnot(cgv_revoke_static_report(report$token, report$revoke_secret, test_root))
stopifnot(!dir.exists(report$path))

expired_analysis <- analysis
expired_analysis$expires_at <- "2020-01-01T00:00:00+0000"
expired_report <- cgv_publish_static_report(expired_analysis, base_dir = test_root)
stopifnot(dir.exists(expired_report$path))
stopifnot(cgv_cleanup_shared_reports(test_root) == 1L)
stopifnot(!dir.exists(expired_report$path))

html <- cgv_render_report_html(analysis)
stopifnot(grepl("Content-Security-Policy", html, fixed = TRUE))
expected_script_hash <- paste0(
    "sha256-",
    as.character(openssl::base64_encode(openssl::sha256(charToRaw(cgv_report_js()))))
)
stopifnot(identical(cgv_report_script_csp_hash(), expected_script_hash))
stopifnot(!grepl("script-src 'unsafe-inline'", html, fixed = TRUE))
stopifnot(grepl("No live database requests", html, fixed = TRUE))
stopifnot(!grepl("<script>alert", html, fixed = TRUE))
stopifnot(grepl("transcript-filter", html, fixed = TRUE))
stopifnot(grepl("analysis-group", html, fixed = TRUE))
stopifnot(grepl("flow-group", html, fixed = TRUE))
stopifnot(grepl("decodeTooltipEntities", html, fixed = TRUE))
stopifnot(grepl("plainTooltip", html, fixed = TRUE))
stopifnot(grepl("figures-structural", html, fixed = TRUE))
stopifnot(grepl("locus-grid", html, fixed = TRUE))
stopifnot(grepl("Aligned synteny", html, fixed = TRUE))

# Full acceptance fixture: both workflows, multiple transcripts, completed
# LASTZ/MultiPIP results, Figure Studio, external results and unresolved items.
second_plot <- plot_record
second_plot$id <- "2"
second_plot$title <- "Gene: TEST1 | Transcript: TX2"
second_plot$plot_data$transcript_id <- "TX2"
second_plot$sequence_blob <- ">TX2\nTTTTCCCC"

ortho_plot <- plot_record
ortho_plot$id <- "3"
ortho_plot$title <- "Gene: TEST1 | Transcript: OTX1"
ortho_plot$plot_data$transcript_id <- "OTX1"
ortho_plot$plot_gene_meta$input <- "OTHER1"
ortho_plot$plot_gene_meta$symbol <- "OTHER1"
ortho_plot$title <- "Gene: OTHER1 | Transcript: OTX1"
ortho_plot$organism_info <- list(
    id = "other_species",
    name = "Other species",
    taxid = "5678",
    assembly_accession = "GCF_OTHER"
)

full_snapshot <- legacy_snapshot
full_snapshot$homologous$plots <- list(plot_record, second_plot)
full_snapshot$homologous$plots[[1L]]$plot_data$transcript_id <- "TX1"
full_snapshot$orthologous <- list(plot_counter = 1L, plots = list(ortho_plot))
full_snapshot$app$search_status_ortho <- "No result for Missing species."
full_snapshot$app$current_organism_ortho <- c("test_species", "missing_species")
full_snapshot$app$figure_studio_state <- "{\"version\":2,\"panels\":[{\"id\":\"panel_1\"}]}"

lastz_runs <- list(run_lastz = list(
    status = "completed",
    reference_width = 8L,
    query_width = 8L,
    parameters = list(identity = 70, seed = "12of19"),
    blocks = data.frame(reference_start = 1L, reference_end = 8L, query_start = 1L, query_end = 8L)
))
multipip_runs <- list(run_multipip = list(
    status = "completed",
    reference_width = 8L,
    parameters = list(min_identity = 60, window = 100),
    segments = data.frame(organism = "Other species", start = 1L, end = 8L, identity = 87.5)
))
full_payload <- list(
    assets = list(
        payload$assets[[1L]],
        list(
            id = "figure_studio_composition",
            title = "Figure Studio composition",
            group = "figure_studio",
            context = "figure_studio",
            svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"><rect width=\"80\" height=\"40\"/></svg>"
        ),
        list(
            id = "cross_species_pip_blocks_report",
            title = "LASTZ blocks",
            group = "alignment",
            context = "cross_species",
            svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M0 8L80 8\"/></svg>"
        ),
        list(
            id = "cross_species_pip_multipip_report",
            title = "MultiPIP",
            group = "alignment",
            context = "cross_species",
            svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M0 12L80 12\"/></svg>"
        )
    ),
    external_results = list(list(
        id = "external_saved",
        title = "Previously consulted external result",
        captured_text = "Captured without issuing another request."
    ))
)
full_analysis <- cgv_build_analysis_manifest(
    snapshot = full_snapshot,
    homo_summary = data.frame(Gene = c("TEST1", "TEST1"), Transcript = c("TX1", "TX2")),
    ortho_summary = data.frame(Organism = c("Test species", "Other species"), Transcript = c("TX1", "OTX1")),
    pip_runs = lastz_runs,
    multipip_runs = multipip_runs,
    client_payload = full_payload,
    include_private = TRUE,
    allow_downloads = TRUE,
    ttl_days = 14L,
    app_version = "1.1.0",
    base_dir = test_root
)
stopifnot(identical(as.character(full_analysis$workflows), c("multi_gene", "cross_species")))
stopifnot(all(c("TX1", "TX2", "OTX1") %in% as.character(full_analysis$query$selected_transcripts)))
stopifnot(length(full_analysis$results$alignments$lastz) == 1L)
stopifnot(length(full_analysis$results$alignments$multipip) == 1L)
alignment_figures <- Filter(function(item) identical(item$group, "alignment"), full_analysis$figures)
stopifnot(length(alignment_figures) == 2L)
stopifnot(identical(
    sort(vapply(alignment_figures, function(item) item$title, character(1))),
    sort(c("LASTZ blocks", "MultiPIP"))
))
stopifnot(isTRUE(full_analysis$figure_studio$included))
stopifnot(grepl("Missing species", full_analysis$provenance$no_result$cross_species_status, fixed = TRUE))
stopifnot(any(vapply(full_analysis$provenance$organisms_without_result, function(item) {
    identical(item$organism, "missing_species") &&
        grepl("No result", item$reason, fixed = TRUE)
}, logical(1))))
stopifnot(length(full_analysis$results$external) == 1L)
stopifnot(length(full_analysis$tables$multi_gene) == 2L)
stopifnot(identical(full_analysis$privacy$ttl_days, 14L))
stopifnot(length(full_analysis$provenance$alias_decisions) < length(full_analysis$results$structural))
stopifnot(all(vapply(full_analysis$results$structural, function(record) {
    is.null((record$organism %||% list())$icon_data_uri)
}, logical(1))))
full_html <- cgv_render_report_html(full_analysis)
stopifnot(grepl("LASTZ blocks", full_html, fixed = TRUE))
stopifnot(grepl("MultiPIP", full_html, fixed = TRUE))

scoped_snapshot <- cgv_scope_shared_snapshot(
    full_snapshot,
    include_multi_gene = TRUE,
    include_cross_species = FALSE
)
stopifnot(length(scoped_snapshot$homologous$plots) == 2L)
stopifnot(length(scoped_snapshot$orthologous$plots) == 0L)
stopifnot(identical(scoped_snapshot$orthologous$plot_counter, 0L))
stopifnot(!grepl("OTHER1", scoped_snapshot$app$global_search_query, fixed = TRUE))
scoped_payload_fixture <- list(
    assets = list(
        list(
            id = "multi_synteny_test1",
            title = "Aligned synteny · TEST1",
            group = "synteny",
            context = "multi_gene",
            comparison_gene = "TEST1",
            svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M0 0L10 10\"/></svg>"
        ),
        list(
            id = "cross_synteny_other1",
            title = "Cross-Species aligned synteny",
            group = "synteny",
            context = "cross_species",
            svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M0 10L10 0\"/></svg>"
        ),
        full_payload$assets[[2L]]
    ),
    external_results = full_payload$external_results
)
scoped_payload <- cgv_scope_client_payload(
    scoped_payload_fixture,
    include_multi_gene = TRUE,
    include_cross_species = FALSE
)
stopifnot(length(scoped_payload$assets) == 1L)
stopifnot(identical(scoped_payload$assets[[1L]]$comparison_gene, "TEST1"))
stopifnot(length(scoped_payload$external_results) == 0L)
scoped_lastz <- cgv_scope_alignment_runs(
    list(
        multi_gene_a = lastz_runs[[1L]],
        cross_species_b = lastz_runs[[1L]]
    ),
    include_multi_gene = TRUE,
    include_cross_species = FALSE
)
stopifnot(identical(names(scoped_lastz), "multi_gene_a"))
scoped_analysis <- cgv_build_analysis_manifest(
    snapshot = scoped_snapshot,
    homo_summary = data.frame(Gene = c("TEST1", "TEST1"), Transcript = c("TX1", "TX2")),
    ortho_summary = data.frame(),
    pip_runs = scoped_lastz,
    client_payload = scoped_payload,
    include_private = FALSE,
    allow_downloads = FALSE,
    ttl_days = 7L,
    app_version = "1.1.0",
    base_dir = test_root
)
stopifnot(identical(as.character(scoped_analysis$workflows), "multi_gene"))
stopifnot(length(scoped_analysis$tables$cross_species) == 0L)
stopifnot(length(scoped_analysis$results$external) == 0L)
stopifnot(all(vapply(scoped_analysis$figures, function(item) {
    identical(item$context, "multi_gene")
}, logical(1))))
stopifnot(identical(scoped_analysis$figures[[1L]]$comparison_gene, "TEST1"))

fast_payload <- scoped_payload
fast_payload$capture_mode <- "fast"
fast_payload$omitted <- "Hidden views were not generated."
fast_analysis <- cgv_build_analysis_manifest(
    snapshot = scoped_snapshot,
    homo_summary = data.frame(Gene = c("TEST1", "TEST1"), Transcript = c("TX1", "TX2")),
    client_payload = fast_payload,
    include_private = FALSE,
    allow_downloads = FALSE,
    ttl_days = 7L,
    app_version = "1.1.0",
    base_dir = test_root
)
stopifnot(identical(fast_analysis$capture$mode, "fast"))
stopifnot(identical(as.character(fast_analysis$capture$omitted), "Hidden views were not generated."))
stopifnot(grepl("Fast capture", cgv_render_report_html(fast_analysis), fixed = TRUE))

cross_scoped_snapshot <- cgv_scope_shared_snapshot(
    full_snapshot,
    include_multi_gene = FALSE,
    include_cross_species = TRUE
)
stopifnot(length(cross_scoped_snapshot$homologous$plots) == 0L)
stopifnot(length(cross_scoped_snapshot$orthologous$plots) == 1L)
cross_scoped_payload <- cgv_scope_client_payload(
    full_payload,
    include_multi_gene = FALSE,
    include_cross_species = TRUE
)
stopifnot(length(cross_scoped_payload$external_results) == 0L)
stopifnot(all(vapply(cross_scoped_payload$assets, function(item) {
    identical(item$context, "cross_species")
}, logical(1))))
stopifnot(identical(
    sort(vapply(cross_scoped_payload$assets, function(item) item$title, character(1))),
    sort(c("LASTZ blocks", "MultiPIP"))
))
cross_scoped_multipip <- cgv_scope_alignment_runs(
    list(
        multi_gene_a = multipip_runs[[1L]],
        cross_species_b = multipip_runs[[1L]]
    ),
    include_multi_gene = FALSE,
    include_cross_species = TRUE
)
stopifnot(identical(names(cross_scoped_multipip), "cross_species_b"))
no_scope_error <- tryCatch({
    cgv_scope_shared_snapshot(
        full_snapshot,
        include_multi_gene = FALSE,
        include_cross_species = FALSE
    )
    ""
}, error = conditionMessage)
stopifnot(grepl("Select at least one", no_scope_error, fixed = TRUE))

private_package <- cgv_write_reproducibility_package(
    analysis = full_analysis,
    session_snapshot = full_snapshot,
    homo_summary = data.frame(Gene = c("TEST1", "TEST1"), Transcript = c("TX1", "TX2")),
    ortho_summary = data.frame(Organism = c("Test species", "Other species"), Transcript = c("TX1", "OTX1")),
    pip_runs = lastz_runs,
    multipip_runs = multipip_runs,
    include_private = TRUE,
    base_dir = test_root
)
private_dir <- file.path(test_root, "private-unzipped")
utils::unzip(private_package, exdir = private_dir)
stopifnot(length(list.files(file.path(private_dir, "sequences"), pattern = "\\.fasta$")) == 3L)
stopifnot(file.exists(file.path(private_dir, "alignments", "lastz_run_lastz.tsv")))
stopifnot(file.exists(file.path(private_dir, "alignments", "multipip_run_multipip.tsv")))
stopifnot(file.exists(file.path(private_dir, "figures", "figure_studio_composition.svg")))
studio_svg_written <- paste(
    readLines(file.path(private_dir, "figures", "figure_studio_composition.svg"), warn = FALSE),
    collapse = "\n"
)
stopifnot(identical(studio_svg_written, full_analysis$figures[[2L]]$svg))

downloadable_report <- cgv_publish_static_report(
    full_analysis,
    package_path = private_package,
    allow_downloads = TRUE,
    base_dir = test_root
)
stopifnot(file.exists(file.path(downloadable_report$path, "downloads", "cgv_reproducibility.zip")))
stopifnot(!cgv_revoke_static_report("../../etc/passwd", "invalid", test_root))
stopifnot(cgv_revoke_static_report(downloadable_report$token, downloadable_report$revoke_secret, test_root))

old_report_limit <- Sys.getenv("APP_SHARED_REPORT_MAX_MB", unset = "")
on.exit(Sys.setenv(APP_SHARED_REPORT_MAX_MB = old_report_limit), add = TRUE)
Sys.setenv(APP_SHARED_REPORT_MAX_MB = "1")
oversized_snapshot <- full_snapshot
oversized_snapshot$homologous$plots[[1L]]$sequence_blob <- paste(rep("ACGT", 300000L), collapse = "")
limit_error <- tryCatch({
    cgv_write_reproducibility_package(
        full_analysis,
        oversized_snapshot,
        include_private = TRUE,
        base_dir = test_root
    )
    ""
}, error = conditionMessage)
stopifnot(grepl("per-report limit", limit_error, fixed = TRUE))
Sys.setenv(APP_SHARED_REPORT_MAX_MB = old_report_limit)

capture_js <- paste(readLines("www/js/reproducible_report.js", warn = FALSE), collapse = "\n")
stopifnot(grepl("analytics_export_all_nonce", capture_js, fixed = TRUE))
stopifnot(grepl("waitForHiddenAnalytics", capture_js, fixed = TRUE))
stopifnot(grepl("waitForStructuralFigures", capture_js, fixed = TRUE))
stopifnot(grepl("figure_studio_plot_render_request", capture_js, fixed = TRUE))
stopifnot(grepl("structural_targets: message.structural_targets", capture_js, fixed = TRUE))
stopifnot(grepl("record_id: recordMeta.record_id", capture_js, fixed = TRUE))
stopifnot(grepl("prepare-lastz-for-report", capture_js, fixed = TRUE))
stopifnot(grepl("preLastzCaptureByRequest", capture_js, fixed = TRUE))
stopifnot(grepl("beforeSynteny", capture_js, fixed = TRUE))
stopifnot(grepl("capture_after_synteny", capture_js, fixed = TRUE))
stopifnot(grepl("normalizeSyntenyGroups", capture_js, fixed = TRUE))
stopifnot(grepl("setReportSelectValue", capture_js, fixed = TRUE))
stopifnot(grepl("comparison_gene", capture_js, fixed = TRUE))
stopifnot(grepl("pip_multipip", capture_js, fixed = TRUE))
stopifnot(grepl("pip_plot_out", capture_js, fixed = TRUE))
stopifnot(grepl("multipip_plot_out", capture_js, fixed = TRUE))
stopifnot(grepl("target.label", capture_js, fixed = TRUE))
stopifnot(grepl("MultiPIP", capture_js, fixed = TRUE))
stopifnot(grepl("cgv-report-capture-curtain", capture_js, fixed = TRUE))
stopifnot(grepl("freezeReportBackground", capture_js, fixed = TRUE))
stopifnot(!grepl("cgv-report-frozen-app", capture_js, fixed = TRUE))
stopifnot(!grepl("var frozenApp = app.cloneNode(true)", capture_js, fixed = TRUE))
stopifnot(grepl("missingTargets", capture_js, fixed = TRUE))
stopifnot(grepl("previousHomoSvg", capture_js, fixed = TRUE))
stopifnot(grepl("svg === stableSvg", capture_js, fixed = TRUE))
stopifnot(!grepl('Shiny.setInputValue(inputId, next', capture_js, fixed = TRUE))
stopifnot(grepl('closest("#cgv-report-capture-curtain")', capture_js, fixed = TRUE))
stopifnot(grepl("syncReportCaptureCurtain", capture_js, fixed = TRUE))
stopifnot(grepl("capture_contexts", capture_js, fixed = TRUE))
stopifnot(grepl("if (document.body)", capture_js, fixed = TRUE))
stopifnot(grepl("DOMContentLoaded\", function", capture_js, fixed = TRUE))
stopifnot(grepl("skip_run", capture_js, fixed = TRUE))
stopifnot(grepl("chrGrad_", capture_js, fixed = TRUE))
stopifnot(!grepl("chrGrad_|chromosome|ideogram", capture_js, fixed = TRUE))
stopifnot(grepl("chromosome_context", capture_js, fixed = TRUE))
stopifnot(grepl("synteny", capture_js, fixed = TRUE))
stopifnot(grepl("external_results", capture_js, fixed = TRUE))
stopifnot(grepl('captureMode === "fast"', capture_js, fixed = TRUE))
stopifnot(grepl("new Set()", capture_js, fixed = TRUE))
stopifnot(grepl("cgv_report_progress", capture_js, fixed = TRUE))
stopifnot(grepl("notifyZipStart", capture_js, fixed = TRUE))
ui_source <- paste(readLines("ui.R", warn = FALSE), collapse = "\n")
server_source <- paste(readLines("server.R", warn = FALSE), collapse = "\n")
stopifnot(!grepl("app-nav-btn-share-analysis", ui_source, fixed = TRUE))
stopifnot(grepl("summary-share-analysis-btn", server_source, fixed = TRUE))
stopifnot(grepl("open_share_analysis_homo", server_source, fixed = TRUE))
stopifnot(grepl("pip_runs = completed_for_report", server_source, fixed = TRUE))
stopifnot(grepl("homo_synteny_groups_fn", server_source, fixed = TRUE))
shared_domain_source <- paste(readLines("R/server_shared_analysis_domain.R", warn = FALSE), collapse = "\n")
stopifnot(grepl("share_include_multi_gene", shared_domain_source, fixed = TRUE))
stopifnot(grepl("share_include_cross_species", shared_domain_source, fixed = TRUE))
stopifnot(grepl("Run LASTZ and MultiPIP", shared_domain_source, fixed = TRUE))
stopifnot(grepl("Preparing a complete report", shared_domain_source, fixed = TRUE))
stopifnot(grepl("Fast — include only views already rendered", shared_domain_source, fixed = TRUE))
stopifnot(grepl("ensure_reproducibility_package", shared_domain_source, fixed = TRUE))
stopifnot(grepl("cgv_prepare_report_artifacts", shared_domain_source, fixed = TRUE))
stopifnot(grepl('src = "/favicon.ico"', shared_domain_source, fixed = TRUE))
stopifnot(!grepl("Rendering the aligned synteny comparison for the report", shared_domain_source, fixed = TRUE))
snapshot_domain <- paste(readLines("R/server_session_snapshot_domain.R", warn = FALSE), collapse = "\n")
stopifnot(grepl("schema_version %in% c(1L, 2L)", snapshot_domain, fixed = TRUE))
stopifnot(grepl("resolve_snapshot_path", snapshot_domain, fixed = TRUE))
old_runtime <- Sys.getenv("CGV_RUNTIME", unset = "")
on.exit(Sys.setenv(CGV_RUNTIME = old_runtime), add = TRUE)
Sys.setenv(CGV_RUNTIME = "desktop")
stopifnot(isTRUE(cgv_runtime_is_desktop()))
desktop_main <- paste(readLines("desktop/src/main.js", warn = FALSE), collapse = "\n")
stopifnot(grepl("CGV_RUNTIME: \"desktop\"", desktop_main, fixed = TRUE))
Sys.setenv(CGV_RUNTIME = old_runtime)
nginx_config <- paste(readLines("deploy/nginx/cgv-shinyproxy.conf", warn = FALSE), collapse = "\n")
stopifnot(grepl(cgv_report_script_csp_hash(), nginx_config, fixed = TRUE))
stopifnot(grepl("location /share/", nginx_config, fixed = TRUE))
stopifnot(grepl("return 404", nginx_config, fixed = TRUE))

cat("Shared analysis domain tests passed.\n")
