#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(dplyr)
    library(stringr)
})

source(file.path("R", "utils.R"))
source(file.path("R", "server_analytics_domain.R"))

cache_env <- function() new.env(parent = emptyenv())
domain <- init_analytics_domain(
    analyticsPreparedCache_env = cache_env(),
    analyticsMetricMatrixCache_env = cache_env(),
    analyticsExonDistCache_env = cache_env(),
    analyticsScatterPrepCache_env = cache_env(),
    analyticsScatterRenderCache_env = cache_env(),
    analyticsRadarSceneCache_env = cache_env(),
    analyticsRadarRenderCache_env = cache_env(),
    analyticsCorrSceneCache_env = cache_env(),
    analyticsCorrRenderCache_env = cache_env()
)

italic_h <- unname(domain$scientific_italic_unicode("h"))
stopifnot(identical(italic_h, "\u210E"))
stopifnot(!identical(utf8ToInt(italic_h), 0x1D455L))

prepared <- data.frame(
    GC_Content_pct = 41.2,
    Gene_Length_bp = 12345,
    Exons = 7L,
    CDS_to_Tx_pct = 73.5,
    x_label_plain = "Drosophila melanogaster | TP53 | tx1",
    x_label_scatter = "TP53\nDrosophila melanogaster",
    x_label_organism = "Drosophila melanogaster",
    x_label = "TP53",
    gene_full = "TP53",
    organism_full = "Drosophila melanogaster",
    organism_icon = "/icons/DNA.ico",
    transcript_full = "tx1",
    stringsAsFactors = FALSE
)

scatter <- domain$get_cached_scatter_prepared_df(prepared)
stopifnot(nrow(scatter) == 1L)
stopifnot(identical(
    scatter$scatter_label_plotmath,
    'atop(bold("TP53"),italic("Drosophila melanogaster"))'
))
stopifnot(identical(scatter$scatter_label_compact, "TP53\nDrosophila melanogaster"))

cat("analytics-scientific-labels-ok\n")
