source("R/utils.R")
source("R/modules.R")

reference_assign <- function(feature_starts, feature_ends, rect_starts, rect_ends, tolerance_bp = 2) {
    out <- vector("list", length(rect_starts))
    for (i in seq_along(out)) out[[i]] <- integer(0)
    for (j in seq_along(feature_starts)) {
        candidate <- findInterval(feature_starts[j], rect_ends + tolerance_bp + 1L)
        first <- candidate + 1L
        if (first <= length(rect_starts)) {
            for (i in first:length(rect_starts)) {
                if (rect_starts[i] - tolerance_bp > feature_ends[j]) break
                out[[i]] <- c(out[[i]], j)
            }
        }
    }
    out
}

feature_starts <- c(10, 18, 35, 90, 105)
feature_ends <- c(20, 25, 45, 100, 112)
rects <- merge_gene_plot_ranges(feature_starts, feature_ends)
expected_rects <- data.frame(
    xstart = c(10, 35, 90, 105),
    xend = c(25, 45, 100, 112)
)
stopifnot(isTRUE(all.equal(rects, expected_rects, check.attributes = FALSE)))

expected <- reference_assign(feature_starts, feature_ends, rects$xstart, rects$xend)
actual <- assign_features_to_rects(feature_starts, feature_ends, rects$xstart, rects$xend)
stopifnot(identical(actual, expected))

df <- data.frame(
    xstart = feature_starts,
    xend = feature_ends,
    stringsAsFactors = FALSE
)
df_gene <- data.frame(V4 = 10, V5 = 112)
model <- prepare_gene_plot_model(df, df_gene, visual_mode = "compact")
stopifnot(identical(model$feature_to_rect, expected))

cat("gene-plot-model-helpers-ok\n")
