#!/usr/bin/env Rscript

suppressWarnings({
  suppressPackageStartupMessages(library(dplyr))
  args <- commandArgs(trailingOnly = TRUE)
})

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0) return(default)
  sub(prefix, "", hit[1], fixed = TRUE)
}

has_flag <- function(name) {
  paste0("--", name) %in% args
}

if (has_flag("help")) {
  cat(
    "Usage:\n",
    "  Rscript scripts/precompute_preloaded_cache.R [--root=PATH] [--registry=PATH] [--clean]\n\n",
    "Defaults:\n",
    "  --root=. --registry=annotations/registry.tsv\n\n",
    "Behavior:\n",
    "  - Reads preloaded species registry.\n",
    "  - Builds persistent annotation gene-index cache in cache/annotation_index/.\n",
    "  - For FASTA genomes, creates .fai index if missing (when writable).\n",
    "  - For 2bit genomes, validates seqname listing.\n",
    "  - Use --clean to remove old cache before rebuilding.\n",
    sep = ""
  )
  quit(save = "no", status = 0)
}

root <- normalizePath(arg_value("root", "."), winslash = "/", mustWork = FALSE)
registry_rel <- arg_value("registry", file.path("annotations", "registry.tsv"))
do_clean <- has_flag("clean")

utils_path <- file.path(root, "R", "utils.R")
if (!file.exists(utils_path)) stop("Cannot find R/utils.R at: ", utils_path)
source(utils_path, local = TRUE)

if (do_clean) {
  clear_annotation_index_cache(base_dir = root)
  cat("Old cache removed.\n")
}

reg <- get_preloaded_species_registry(registry_path = registry_rel, base_dir = root)
if (nrow(reg) == 0) {
  cat("No preloaded registry rows found.\n")
  quit(save = "no", status = 0)
}

ready <- reg[as.logical(reg$ready), , drop = FALSE]
if (nrow(ready) == 0) {
  cat("No ready preloaded species found.\n")
  quit(save = "no", status = 0)
}

ok_ann <- 0L
ok_gen <- 0L
fail <- 0L

for (i in seq_len(nrow(ready))) {
  label <- as.character(ready$label[i] %||% ready$species_id[i] %||% paste0("row_", i))
  ann <- as.character(ready$annotation_path[i] %||% "")
  gen <- as.character(ready$genome_path[i] %||% "")

  cat(sprintf("[%d/%d] %s\n", i, nrow(ready), label))

  if (nzchar(ann) && file.exists(ann)) {
    ann_idx <- tryCatch(precompute_annotation_index_cache(ann, base_dir = root), error = function(e) NULL)
    if (!is.null(ann_idx) && is.list(ann_idx)) {
      genes_n <- if (!is.null(ann_idx$genes_df)) nrow(ann_idx$genes_df) else 0L
      cat(sprintf("  - annotation cache: OK (%s genes)\n", format(genes_n, big.mark = ",")))
      ok_ann <- ok_ann + 1L
    } else {
      cat("  - annotation cache: FAIL\n")
      fail <- fail + 1L
    }
  } else {
    cat("  - annotation: missing\n")
    fail <- fail + 1L
  }

  if (nzchar(gen) && file.exists(gen)) {
    if (is_twobit_file(gen)) {
      sn <- tryCatch(get_twobit_seqnames(gen), error = function(e) character(0))
      if (length(sn) > 0) {
        cat(sprintf("  - genome 2bit: OK (%s seqnames)\n", format(length(sn), big.mark = ",")))
        ok_gen <- ok_gen + 1L
      } else {
        cat("  - genome 2bit: FAIL\n")
        fail <- fail + 1L
      }
    } else {
      fai <- paste0(gen, ".fai")
      ok_fai <- FALSE
      if (file.exists(fai)) {
        ok_fai <- TRUE
      } else if (requireNamespace("Rsamtools", quietly = TRUE) && file.access(dirname(gen), 2) == 0) {
        ok_fai <- tryCatch({
          Rsamtools::indexFa(gen)
          file.exists(fai)
        }, error = function(e) FALSE)
      }
      if (ok_fai) {
        cat("  - genome FASTA index (.fai): OK\n")
        ok_gen <- ok_gen + 1L
      } else {
        cat("  - genome FASTA index (.fai): FAIL/skip\n")
      }
    }
  } else {
    cat("  - genome: missing\n")
  }
}

cache_dir <- get_annotation_disk_cache_dir(base_dir = root)
cache_files <- if (dir.exists(cache_dir)) list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE) else character(0)

cat("\nSummary\n")
cat(sprintf("- Ready species: %d\n", nrow(ready)))
cat(sprintf("- Annotation caches OK: %d\n", ok_ann))
cat(sprintf("- Genome checks/indexes OK: %d\n", ok_gen))
cat(sprintf("- Issues: %d\n", fail))
cat(sprintf("- Cache files: %d (%s)\n", length(cache_files), cache_dir))

