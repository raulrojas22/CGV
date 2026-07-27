#!/usr/bin/env Rscript

source("R/utils.R")
source("R/modules.R")

human <- build_genomic_ruler_spec(94762681, 94855547)
stopifnot(is.data.frame(human), nrow(human) >= 4L, nrow(human) <= 6L)
stopifnot(identical(human$value[c(1, nrow(human))], c(94762681, 94855547)))
stopifnot(identical(human$unit[1], "Mb"))
stopifnot(all(grepl(" Mb$", human$label)))
stopifnot(length(unique(human$label)) == nrow(human))
stopifnot(identical(human$hjust[c(1, nrow(human))], c(0, 1)))

small <- build_genomic_ruler_spec(101, 479)
stopifnot(is.data.frame(small), identical(small$unit[1], "bp"))
stopifnot(all(grepl(" bp$", small$label)))
stopifnot(identical(small$value[c(1, nrow(small))], c(101, 479)))

reversed <- build_genomic_ruler_spec(20000, 10000)
stopifnot(is.data.frame(reversed))
stopifnot(identical(reversed$value[c(1, nrow(reversed))], c(10000, 20000)))
stopifnot(identical(reversed$unit[1], "kb"))

stopifnot(is.null(build_genomic_ruler_spec(100, 100)))
stopifnot(is.null(build_genomic_ruler_spec(NA, 100)))

spacious <- prune_genomic_ruler_spec_for_width(
    human,
    94762681,
    94855547,
    display_width_in = 12
)
stopifnot(identical(spacious$label, human$label))

efnb3 <- build_genomic_ruler_spec(7705202, 7711372)
efnb3_pruned <- prune_genomic_ruler_spec_for_width(
    efnb3,
    7705202,
    7711372,
    display_width_in = 4.38
)
stopifnot(nrow(efnb3_pruned) >= 2L, nrow(efnb3_pruned) < nrow(efnb3))
stopifnot(identical(efnb3_pruned$value[c(1, nrow(efnb3_pruned))], c(7705202, 7711372)))

single_tick <- prune_genomic_ruler_spec_for_width(
    efnb3,
    7705202,
    7711372,
    display_width_in = 0.35
)
stopifnot(nrow(single_tick) == 1L, identical(single_tick$hjust, 0.5))
stopifnot(grepl(" Mb$", single_tick$label))

lanes <- assign_genomic_overlap_lanes(
    starts = c(100, 120, 210, 215, 400),
    ends = c(200, 160, 240, 260, 450),
    padding_bp = 0
)
stopifnot(identical(lanes, c(1L, 2L, 1L, 2L, 1L)))
stopifnot(identical(assign_genomic_overlap_lanes(numeric(0), numeric(0)), integer(0)))

stopifnot(!has_genomic_overlap_context(NULL))
stopifnot(!has_genomic_overlap_context(list(
    upstream = list(dist_bp = 125),
    downstream = list(dist_bp = 0),
    overlapping = list(),
    flags = list(has_overlap = FALSE, overlap_count = 0L)
)))
stopifnot(has_genomic_overlap_context(list(
    overlapping = list(list(neighbor_start = 120, neighbor_end = 150))
)))
stopifnot(has_genomic_overlap_context(list(
    upstream = list(dist_bp = -25),
    downstream = list(dist_bp = 100),
    overlapping = list()
)))
stopifnot(has_genomic_overlap_context(list(
    overlapping = list(),
    flags = list(has_overlap = TRUE, overlap_count = 1L)
)))

svg_sample <- paste0(
    '<text x="12.34567" y="8.76543">4.112531 Mb</text>',
    '<title>Overlap length: 2.271 kb</title>'
)
svg_compact <- compact_girafe_svg_html(svg_sample, decimals = 1L)
stopifnot(grepl('x="12.3"', svg_compact, fixed = TRUE))
stopifnot(grepl('y="8.8"', svg_compact, fixed = TRUE))
stopifnot(grepl(">4.112531 Mb<", svg_compact, fixed = TRUE))
stopifnot(grepl(">Overlap length: 2.271 kb<", svg_compact, fixed = TRUE))

left_gap <- classify_neighbor_relation(100, 200, 20, 80)
stopifnot(identical(left_gap$relation, "separated_left"), identical(left_gap$gap_bp, 19))

adjacent <- classify_neighbor_relation(100, 200, 50, 99)
stopifnot(identical(adjacent$category, "adjacent"), identical(adjacent$gap_bp, 0))

inside <- classify_neighbor_relation(100, 200, 120, 150)
stopifnot(
    identical(inside$relation, "neighbor_inside_query"),
    identical(inside$overlap_bp, 31)
)

contains <- classify_neighbor_relation(100, 200, 80, 220)
stopifnot(
    identical(contains$relation, "neighbor_contains_query"),
    identical(contains$clipped_start, 100),
    identical(contains$clipped_end, 200)
)

same_span <- classify_neighbor_relation(100, 200, 100, 200)
stopifnot(identical(same_span$relation, "same_span"))

partial <- classify_neighbor_relation(100, 200, 180, 240)
stopifnot(
    identical(partial$relation, "partial_overlap_right"),
    identical(partial$overlap_bp, 21)
)

target_gene <- data.frame(
    gene_id = "query",
    chr = "chr1",
    start = 100,
    end = 200,
    strand = "+",
    stringsAsFactors = FALSE
)
light_genes <- data.frame(
    seqid = rep("chr1", 7),
    start = c(100, 50, 251, 120, 80, 100, 180),
    end = c(200, 99, 300, 140, 220, 200, 230),
    strand = c("+", "+", "-", "-", "-", "-", "+"),
    attributes = c(
        "ID=query;Name=query",
        "ID=left;Name=left",
        "ID=right;Name=right",
        "ID=inside;Name=inside",
        "ID=contains;Name=contains",
        "ID=antisense;Name=antisense",
        "ID=partial;Name=partial"
    ),
    stringsAsFactors = FALSE
)
context <- get_nearest_neighbors_from_light_index(target_gene, light_genes)
stopifnot(identical(context$upstream$neighbor_id, "left"))
stopifnot(identical(context$upstream$dist_bp, 0))
stopifnot(identical(context$downstream$neighbor_id, "right"))
stopifnot(identical(context$downstream$dist_bp, 50))
stopifnot(length(context$overlapping) == 4L)
stopifnot(isTRUE(context$flags$has_overlap), identical(context$flags$overlap_count, 4L))

cat("genomic-ruler-helpers-ok\n")
