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
    "  - Builds persistent 2bit seqname sidecars in cache/genome_seqnames/.\n",
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
do_alias_sqlite <- has_flag("alias-sqlite") || has_flag("all")

utils_path <- file.path(root, "R", "utils.R")
if (!file.exists(utils_path)) stop("Cannot find R/utils.R at: ", utils_path)
source(utils_path, local = TRUE)

alias_resolution_path <- file.path(root, "R", "alias_resolution.R")
has_alias_module <- file.exists(alias_resolution_path)
if (has_alias_module) source(alias_resolution_path, local = TRUE)

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
ok_seqside <- 0L
ok_alias <- 0L
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
      sn <- tryCatch(get_twobit_seqnames(gen, base_dir = root), error = function(e) character(0))
      if (length(sn) > 0) {
        cat(sprintf("  - genome 2bit: OK (%s seqnames)\n", format(length(sn), big.mark = ",")))
        sidecar_path <- tryCatch(twobit_seqnames_sidecar_path(gen, base_dir = root), error = function(e) "")
        if (nzchar(sidecar_path) && file.exists(sidecar_path)) {
          cat(sprintf("  - genome 2bit seqnames sidecar: OK (%s)\n", sidecar_path))
          ok_seqside <- ok_seqside + 1L
        } else {
          cat("  - genome 2bit seqnames sidecar: missing/skip\n")
        }
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

# ── Alias index SQLite prewarming ──────────────────────────────────────────
if (has_alias_module && exists("warm_alias_index", mode = "function")) {
  for (i in seq_len(nrow(ready))) {
    org_id <- as.character(ready$species_id[i] %||% "")
    if (!nzchar(org_id)) next
    label <- as.character(ready$label[i] %||% org_id)
    sqlite_path <- alias_sqlite_path(org_id, base_dir = root)
    if (!file.exists(sqlite_path)) {
      cat(sprintf("  - alias sqlite: not built (%s)\n", basename(sqlite_path)))
      next
    }
    ok <- tryCatch(warm_alias_index(org_id, base_dir = root), error = function(e) FALSE)
    if (isTRUE(ok)) {
      ok_alias <- ok_alias + 1L
    } else {
      cat(sprintf("  - alias sqlite: prewarm FAIL (%s)\n", label))
    }
  }
}

# ── Optional: Build SQLite alias indexes from TSV.gz ───────────────────────
if (do_alias_sqlite && has_alias_module) {
  for (i in seq_len(nrow(ready))) {
    org_id <- as.character(ready$species_id[i] %||% "")
    if (!nzchar(org_id)) next
    label <- as.character(ready$label[i] %||% org_id)
    sqlite_path <- alias_sqlite_path(org_id, base_dir = root)
    tsv_path <- alias_index_path(org_id, base_dir = root)
    if (file.exists(sqlite_path) && !do_clean) next
    if (!file.exists(tsv_path)) {
      cat(sprintf("  - alias sqlite: no TSV source (%s)\n", label))
      next
    }
    cat(sprintf("  - building alias sqlite for %s...\n", label))
    ok <- tryCatch({
      build_alias_sqlite_from_tsv(tsv_path, sqlite_path)
      TRUE
    }, error = function(e) { cat(sprintf("    FAIL: %s\n", e$message)); FALSE })
    if (ok && exists("warm_alias_index", mode = "function")) {
      tryCatch(warm_alias_index(org_id, base_dir = root), error = function(e) NULL)
    }
  }
}

cache_dir <- get_annotation_disk_cache_dir(base_dir = root)
cache_files <- if (dir.exists(cache_dir)) list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE) else character(0)

cat("\nSummary\n")
cat(sprintf("- Ready species: %d\n", nrow(ready)))
cat(sprintf("- Annotation caches OK: %d\n", ok_ann))
cat(sprintf("- Genome checks/indexes OK: %d\n", ok_gen))
cat(sprintf("- 2bit seqname sidecars OK: %d\n", ok_seqside))
cat(sprintf("- Alias index connections: %d\n", ok_alias))
cat(sprintf("- Issues: %d\n", fail))
cat(sprintf("- Cache files: %d (%s)\n", length(cache_files), cache_dir))
