#!/usr/bin/env Rscript

source("R/utils.R", local = TRUE)
source("R/server_shared_analysis_domain.R", local = TRUE)

make_svg <- function(index, payload_kb = 48L) {
    filler <- paste(rep(sprintf("M%d 0L%d 10", index, index + 1L), payload_kb * 70L), collapse = " ")
    paste0(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 520">',
        '<path d="', filler, '" data-tooltip="Synthetic benchmark figure ', index, '"/>',
        "</svg>"
    )
}

make_analysis <- function(figure_count) {
    figures <- lapply(seq_len(figure_count), function(index) {
        list(
            id = paste0("benchmark_", index),
            title = paste("Benchmark figure", index),
            group = if (index %% 4L == 0L) "analytics" else "structural",
            context = if (index %% 2L == 0L) "cross_species" else "multi_gene",
            source_id = paste0("benchmark_", index),
            record_id = as.character(index),
            gene = paste0("GENE", index),
            comparison_gene = "",
            transcript = paste0("TX", index),
            organism = paste("Organism", (index %% 8L) + 1L),
            svg = make_svg(index)
        )
    })
    list(
        schema_version = cgv_analysis_schema_version,
        analysis_id = cgv_random_secret(16L),
        created_at = "2026-07-30T12:00:00-0400",
        expires_at = "2026-08-06T12:00:00-0400",
        generator = list(name = "CGV", version = "benchmark"),
        branding = list(name = "CGV", logo_data_uri = ""),
        workflows = I(c("multi_gene", "cross_species")),
        query = list(genes = I("BENCHMARK"), selected_transcripts = I(character(0))),
        organisms = list(),
        references = list(),
        parameters = list(),
        provenance = list(),
        results = list(structural = list(), alignments = list(), external = list()),
        tables = list(multi_gene = list(), cross_species = list()),
        figures = figures,
        figure_studio = list(state = list(), included = FALSE),
        privacy = list(
            access = "secret_link",
            private_data_included = FALSE,
            public_downloads = FALSE,
            ttl_days = 7L
        ),
        capture = list(
            mode = "complete",
            missing = I(character(0)),
            omitted = I(character(0)),
            captured_figure_count = figure_count
        )
    )
}

benchmark_one <- function(figure_count) {
    root <- tempfile(paste0("cgv-report-benchmark-", figure_count, "-"))
    dir.create(root, recursive = TRUE)
    on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
    analysis <- make_analysis(figure_count)

    prepare_time <- system.time({
        artifacts <- cgv_prepare_report_artifacts(analysis)
    })[["elapsed"]]
    package_time <- system.time({
        package_path <- cgv_write_reproducibility_package(
            analysis,
            session_snapshot = list(),
            base_dir = root,
            artifacts = artifacts
        )
    })[["elapsed"]]
    publish_time <- system.time({
        published <- cgv_publish_static_report(
            analysis,
            base_dir = root,
            artifacts = artifacts
        )
    })[["elapsed"]]

    data.frame(
        figures = figure_count,
        json_mb = nchar(artifacts$json, type = "bytes") / 1024^2,
        html_mb = nchar(artifacts$html, type = "bytes") / 1024^2,
        zip_mb = file.info(package_path)$size / 1024^2,
        prepare_seconds = prepare_time,
        package_seconds = package_time,
        publish_seconds = publish_time,
        total_seconds = prepare_time + package_time + publish_time,
        published_mb = published$size_bytes / 1024^2
    )
}

counts <- suppressWarnings(as.integer(commandArgs(trailingOnly = TRUE)))
counts <- counts[is.finite(counts) & counts > 0L]
if (!length(counts)) counts <- c(12L, 75L, 150L)

results <- do.call(rbind, lapply(counts, benchmark_one))
print(results, row.names = FALSE, digits = 3)
