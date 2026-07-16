suppressPackageStartupMessages({
    library(dplyr)
    library(tidyr)
    library(purrr)
    library(stringr)
})

source("R/utils.R")

root <- tempfile("cgv-annotation-cache-portability-")
data_root <- file.path(root, "data")
cache_root <- file.path(root, "cache")
annotation_dir <- file.path(data_root, "annotations")
cache_dir <- file.path(cache_root, "annotation_index")
dir.create(annotation_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

Sys.setenv(CGV_DATA_ROOT = data_root, CGV_CACHE_DIR = cache_root)
annotation_path <- file.path(annotation_dir, "GCF_portable_fixture.gff")
writeLines(
    c(
        "##gff-version 3",
        "chr1\tfixture\tgene\t10\t100\t.\t+\t.\tID=gene-FIX1;gene=FIX1"
    ),
    annotation_path,
    useBytes = TRUE
)

idx <- list(
    genes_df = data.frame(
        seqid = "chr1",
        start = 10,
        end = 100,
        attributes = "ID=gene-FIX1;gene=FIX1",
        stringsAsFactors = FALSE
    ),
    gene_rows = 1L,
    norm_map = list(FIX1 = 1L),
    comp_map = list(FIX1 = 1L)
)
portable_gene_path <- file.path(
    cache_dir,
    paste0("gene_light__portable__", basename(annotation_path), "_fixture_desc-clean-v2.rds")
)
saveRDS(idx, portable_gene_path, compress = "gzip")

loaded_idx <- load_gff_index_from_disk(annotation_path, cache_kind = "gene_light", base_dir = ".")
stopifnot(is.list(loaded_idx), is.data.frame(loaded_idx$genes_df), nrow(loaded_idx$genes_df) == 1L)
stopifnot(file.exists(get_gff_disk_index_path(annotation_path, cache_kind = "gene_light", base_dir = ".")))

portable_autocomplete <- list(
    display = "FIX1",
    keys = normalize_partial_gene_query("FIX1"),
    version = .gff_autocomplete_cache_version,
    annotation_key = "obsolete-package-staging-path"
)
portable_autocomplete_path <- file.path(
    cache_dir,
    paste0("autocomplete__portable__", basename(annotation_path), "_fixture_desc-clean-v2.rds")
)
saveRDS(portable_autocomplete, portable_autocomplete_path, compress = "gzip")

loaded_autocomplete <- load_gff_autocomplete_cache(annotation_path, base_dir = ".")
stopifnot(validate_gff_autocomplete_cache(loaded_autocomplete, annotation_path))
stopifnot(identical(loaded_autocomplete$display, "FIX1"))
stopifnot(file.exists(get_gff_disk_index_path(annotation_path, cache_kind = "autocomplete", base_dir = ".")))

cat("annotation cache portability regression: OK\n")
