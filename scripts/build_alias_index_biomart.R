#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0L) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
}

has_flag <- function(name) paste0("--", name) %in% args
library_only <- identical(Sys.getenv("CGV_BIOMART_LIBRARY_ONLY", unset = ""), "1")

if (!isTRUE(library_only) && has_flag("help")) {
  cat(
    "Usage:\n",
    "  Rscript scripts/build_alias_index_biomart.R --all [--root=PATH] [--biomart-timeout-sec=120] [--organism-timeout-sec=600]\n",
    "  Rscript scripts/build_alias_index_biomart.R --organism-id=SPECIES_ID [--root=PATH] [--biomart-timeout-sec=120]\n\n",
    "Builds data/alias_index/<species_id>.alias_index.tsv.gz and metadata JSON.\n",
    "BioMart is optional at runtime; if BioMart fails, a local GFF-only index is still written.\n",
    sep = ""
  )
  quit(save = "no", status = 0)
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

root <- normalizePath(arg_value("root", "."), winslash = "/", mustWork = FALSE)
registry_rel <- arg_value("registry", file.path("annotations", "registry.tsv"))
organism_id_arg <- arg_value("organism-id", "")
run_all <- has_flag("all")
biomart_timeout_sec <- suppressWarnings(as.numeric(arg_value("biomart-timeout-sec", "120")))
if (!is.finite(biomart_timeout_sec) || is.na(biomart_timeout_sec) || biomart_timeout_sec < 10) {
  biomart_timeout_sec <- 120
}
organism_timeout_sec <- suppressWarnings(as.numeric(arg_value("organism-timeout-sec", "600")))
if (!is.finite(organism_timeout_sec) || is.na(organism_timeout_sec) || organism_timeout_sec < 60) {
  organism_timeout_sec <- 600
}
require_biomart <- has_flag("require-biomart")

source(file.path(root, "R", "alias_resolution.R"), local = TRUE)
source(file.path(root, "R", "utils.R"), local = TRUE)

if (!isTRUE(library_only) && !run_all && !nzchar(organism_id_arg)) {
  stop("Pass --all or --organism-id=<species_id>.")
}

biomart_available <- requireNamespace("biomaRt", quietly = TRUE)
if (!biomart_available) {
  message("biomaRt is not installed; writing local GFF-only alias indexes.")
}

with_biomart_timeout <- function(expr, timeout_sec = biomart_timeout_sec) {
  old <- tryCatch(getOption("timeout"), error = function(e) 60)
  options(timeout = max(old %||% 60, timeout_sec))
  on.exit({
    options(timeout = old)
  }, add = TRUE)
  force(expr)
}

dataset_candidates <- function(organism_name, taxid = NA_integer_, species_id = "") {
  org <- tolower(trimws(as.character(organism_name %||% "")))
  sid <- tolower(trimws(as.character(species_id %||% "")))
  words <- strsplit(gsub("[^a-z0-9 ]+", " ", org), "\\s+")[[1]]
  words <- words[nzchar(words)]
  candidates <- character(0)

  if (grepl("indica", org, fixed = TRUE) ||
      grepl("oryza_sativa_indica|oryza_indica|asm465", sid, fixed = TRUE)) {
    candidates <- c(
      candidates,
      "oindica_eg_gene",
      "osir64_eg_gene",
      "osgobolsailbalam_eg_gene"
    )
  }

  special <- c(
    "homo sapiens" = "hsapiens_gene_ensembl",
    "mus musculus" = "mmusculus_gene_ensembl",
    "danio rerio" = "drerio_gene_ensembl",
    "drosophila melanogaster" = "dmelanogaster_gene_ensembl",
    "caenorhabditis elegans" = "celegans_gene_ensembl",
    "saccharomyces cerevisiae" = "scerevisiae_gene_ensembl",
    "oryza sativa ssp. japonica" = "osativa_eg_gene",
    "oryza sativa japonica" = "osativa_eg_gene",
    "oryza sativa" = "osativa_eg_gene",
    "arabidopsis thaliana" = "athaliana_eg_gene",
    "zea mays" = "zmays_eg_gene",
    "triticum aestivum" = "taestivum_eg_gene",
    "solanum lycopersicum" = "slycopersicum_eg_gene",
    "phaseolus vulgaris" = "pvulgaris_eg_gene",
    "vitis vinifera" = "vvinifera_eg_gene",
    "fragaria vesca" = "fvesca_eg_gene"
  )
  for (nm in names(special)) {
    if (grepl(nm, org, fixed = TRUE) || grepl(gsub(" ", "_", nm), sid, fixed = TRUE)) {
      candidates <- c(candidates, special[[nm]])
    }
  }
  if (length(words) >= 2L) {
    genus <- words[[1]]
    species <- words[[2]]
    candidates <- c(
      candidates,
      paste0(substr(genus, 1, 1), species, "_gene_ensembl"),
      paste0(substr(genus, 1, 1), species, "_eg_gene"),
      paste0(genus, "_", species, "_gene_ensembl"),
      paste0(genus, "_", species, "_eg_gene")
    )
    if (length(words) >= 4L && words[[3]] %in% c("ssp", "subsp", "var")) {
      candidates <- c(candidates, paste0(substr(genus, 1, 1), words[[4]], "_eg_gene"))
    }
  }
  unique(candidates[nzchar(candidates)])
}

mart_candidates <- function(kingdom = "") {
  k <- tolower(trimws(as.character(kingdom %||% "")))
  out <- list(list(kind = "ensembl", biomart = "genes"))
  if (grepl("plantae|plant", k)) {
    out <- c(list(list(kind = "genomes", biomart = "plants_mart")), out)
  } else if (grepl("fungi|fungus", k)) {
    out <- c(list(list(kind = "genomes", biomart = "fungi_mart")), out)
  } else if (grepl("animalia|metazoa", k)) {
    out <- c(out, list(list(kind = "genomes", biomart = "metazoa_mart")))
  } else {
    out <- c(
      out,
      list(
        list(kind = "genomes", biomart = "plants_mart"),
        list(kind = "genomes", biomart = "fungi_mart"),
        list(kind = "genomes", biomart = "metazoa_mart"),
        list(kind = "genomes", biomart = "protists_mart")
      )
    )
  }
  out
}

connect_biomart <- function(dataset, kingdom = "") {
  if (!biomart_available) return(NULL)
  for (mc in mart_candidates(kingdom)) {
    mart <- tryCatch({
      with_biomart_timeout({
        if (identical(mc$kind, "genomes")) {
          biomaRt::useEnsemblGenomes(biomart = mc$biomart, dataset = dataset)
        } else {
          biomaRt::useEnsembl(biomart = mc$biomart, dataset = dataset)
        }
      })
    }, error = function(e) NULL)
    if (!is.null(mart)) {
      attr(mart, "cgv_biomart_name") <- mc$biomart
      return(mart)
    }
  }
  NULL
}

fetch_biomart_aliases <- function(entry) {
  if (!biomart_available) return(list(data = data.frame(), dataset = "", biomart = "", warning = "biomaRt unavailable"))
  org <- as.character(entry$organism[1] %||% entry$label[1] %||% "")
  taxid <- suppressWarnings(as.integer(entry$taxid[1] %||% NA_integer_))
  sid <- as.character(entry$species_id[1] %||% "")
  kingdom <- as.character(entry$kingdom[1] %||% "")
  warnings <- character(0)

  for (dataset in dataset_candidates(org, taxid = taxid, species_id = sid)) {
    message(sprintf("  - BioMart: trying dataset %s", dataset))
    mart <- connect_biomart(dataset, kingdom = kingdom)
    if (is.null(mart)) {
      warnings <- c(warnings, paste0("Could not connect dataset ", dataset))
      next
    }
    attrs_available <- tryCatch(
      with_biomart_timeout(biomaRt::listAttributes(mart)),
      error = function(e) {
        warnings <<- c(warnings, paste0("Could not list attributes for ", dataset, ": ", conditionMessage(e)))
        data.frame()
      }
    )
    if (!is.data.frame(attrs_available) || !"name" %in% names(attrs_available)) {
      warnings <- c(warnings, paste0("Could not list attributes for ", dataset))
      next
    }
    wanted <- c(
      "ensembl_gene_id", "ensembl_transcript_id", "ensembl_peptide_id",
      "external_gene_name", "external_synonym", "entrezgene_id",
      "refseq_mrna", "refseq_peptide", "uniprotswissprot", "uniprotsptrembl",
      "chromosome_name", "start_position", "end_position", "strand", "description"
    )
    attrs <- intersect(wanted, as.character(attrs_available$name))
    if (length(attrs) == 0L) {
      warnings <- c(warnings, paste0("No useful attributes in ", dataset))
      next
    }
    id_attrs <- intersect(c("ensembl_gene_id", "ensembl_transcript_id"), attrs)
    core_attrs <- intersect(
      c("ensembl_gene_id", "ensembl_transcript_id", "ensembl_peptide_id",
        "external_gene_name", "chromosome_name", "start_position",
        "end_position", "strand", "description"),
      attrs
    )
    external_attrs <- setdiff(attrs, core_attrs)
    query_attrs <- function(attr_set, label) {
      attr_set <- unique(attr_set[nzchar(attr_set)])
      if (length(attr_set) == 0L) return(data.frame())
      message(sprintf("    - getBM %s (%d attrs)", label, length(attr_set)))
      tryCatch(
        with_biomart_timeout(biomaRt::getBM(attributes = attr_set, mart = mart)),
        error = function(e) {
          warnings <<- c(warnings, paste0("getBM failed for ", dataset, " [", label, "]: ", conditionMessage(e)))
          data.frame()
        }
      )
    }
    bm_parts <- list()
    core <- query_attrs(core_attrs, "core")
    if (is.data.frame(core) && nrow(core) > 0L) {
      bm_parts[[length(bm_parts) + 1L]] <- core
    }
    if (length(id_attrs) > 0L && length(external_attrs) > 0L) {
      for (ext_attr in external_attrs) {
        part <- query_attrs(unique(c(id_attrs, ext_attr)), ext_attr)
        if (is.data.frame(part) && nrow(part) > 0L) {
          bm_parts[[length(bm_parts) + 1L]] <- part
        }
      }
    }
    bm <- if (length(bm_parts) == 0L) {
      data.frame()
    } else if (length(bm_parts) == 1L) {
      bm_parts[[1L]]
    } else {
      # Keep BioMart responses as independent alias evidence rows. Joining
      # external-reference tables by Ensembl IDs creates legitimate many-to-many
      # expansions and can stall the build for large organisms.
      dplyr::bind_rows(bm_parts)
    }
    if (is.data.frame(bm) && nrow(bm) > 0L) {
      return(list(
        data = bm,
        dataset = dataset,
        biomart = as.character(attr(mart, "cgv_biomart_name") %||% ""),
        warning = paste(warnings, collapse = " | ")
      ))
    }
  }
  list(data = data.frame(), dataset = "", biomart = "", warning = paste(warnings, collapse = " | "))
}

biomart_to_alias_rows <- function(bm, local_idx, entry, dataset = "", biomart = "") {
  if (!is.data.frame(bm) || nrow(bm) == 0L || !is.data.frame(local_idx) || nrow(local_idx) == 0L) {
    return(alias_index_empty())
  }
  term_cols <- intersect(
    c("ensembl_gene_id", "ensembl_transcript_id", "ensembl_peptide_id", "external_gene_name",
      "external_synonym", "entrezgene_id", "refseq_mrna", "refseq_peptide",
      "uniprotswissprot", "uniprotsptrembl"),
    names(bm)
  )
  if (length(term_cols) == 0L) return(alias_index_empty())

  local_keys <- unique(local_idx[, c(
    "query_term_clean_strict", "local_gene_id", "local_transcript_id", "local_feature_id",
    "local_symbol", "chromosome", "start", "end", "strand", "description"
  ), drop = FALSE])
  rows <- list()
  row_i <- 0L
  for (i in seq_len(nrow(bm))) {
    terms <- unlist(bm[i, term_cols, drop = FALSE], use.names = TRUE)
    terms <- trimws(as.character(terms %||% character(0)))
    terms <- terms[!is.na(terms) & nzchar(terms)]
    if (length(terms) == 0L) next
    keys_df <- alias_query_keys_df(unique(terms))
    if (nrow(keys_df) == 0L) next
    hit <- local_keys[local_keys$query_term_clean_strict %in% keys_df$query_term_clean_strict, , drop = FALSE]
    if (nrow(hit) == 0L) next
    for (h in seq_len(nrow(hit))) {
      for (k in seq_len(nrow(keys_df))) {
        term_original <- keys_df$query_term_original[k]
        source_col <- names(terms)[match(term_original, terms)]
        term_type <- switch(
          source_col %||% "",
          ensembl_gene_id = "ensembl_gene_id",
          ensembl_transcript_id = "ensembl_transcript_id",
          ensembl_peptide_id = "protein_id",
          external_gene_name = "external_gene_name",
          external_synonym = "synonym",
          entrezgene_id = "entrezgene_id",
          refseq_mrna = "refseq_mrna",
          refseq_peptide = "refseq_peptide",
          uniprotswissprot = "uniprot_id",
          uniprotsptrembl = "uniprot_id",
          "alias"
        )
        row_i <- row_i + 1L
        rows[[row_i]] <- data.frame(
          organism_id = as.character(entry$species_id[1] %||% ""),
          organism_name = as.character(entry$organism[1] %||% entry$label[1] %||% ""),
          taxid = as.character(entry$taxid[1] %||% ""),
          keys_df[k, , drop = FALSE],
          term_type = term_type,
          local_gene_id = hit$local_gene_id[h],
          local_transcript_id = hit$local_transcript_id[h],
          local_feature_id = hit$local_feature_id[h],
          local_symbol = hit$local_symbol[h],
          chromosome = hit$chromosome[h],
          start = hit$start[h],
          end = hit$end[h],
          strand = hit$strand[h],
          description = as.character(bm$description[i] %||% hit$description[h] %||% ""),
          source_db = paste(c("BioMart", biomart), collapse = ":"),
          source_release = dataset,
          confidence = alias_term_confidence(term_type),
          evidence_source = "BioMart",
          stringsAsFactors = FALSE
        )
      }
    }
  }
  if (length(rows) == 0L) return(alias_index_empty())
  out <- do.call(rbind, rows)
  out <- out[!duplicated(paste(out$query_term_upper, out$local_gene_id, out$term_type, out$source_db, sep = "\r")), , drop = FALSE]
  rownames(out) <- NULL
  normalize_alias_index_df(out)
}

write_metadata <- function(entry, path, local_idx, final_idx, bm_info, warnings = character(0), build_status = "ok") {
  biomart_rows <- sum(grepl("^BioMart", as.character(final_idx$source_db %||% character(0))))
  biomart_enriched <- biomart_rows > 0L
  meta <- list(
    organism_id = as.character(entry$species_id[1] %||% ""),
    organism_name = as.character(entry$organism[1] %||% entry$label[1] %||% ""),
    taxid = as.character(entry$taxid[1] %||% ""),
    local_annotation_file = as.character(entry$annotation_path[1] %||% ""),
    build_status = as.character(build_status %||% "ok"),
    biomart_enriched = isTRUE(biomart_enriched),
    n_biomart_alias_terms = as.integer(biomart_rows),
    biomart_dataset = as.character((bm_info %||% list())$dataset %||% ""),
    biomart = as.character((bm_info %||% list())$biomart %||% ""),
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    n_local_genes = length(unique(as.character(local_idx$local_gene_id %||% character(0)))),
    n_alias_terms = nrow(final_idx),
    n_unique_query_terms = length(unique(as.character(final_idx$query_term_upper %||% character(0)))),
    sources = unique(as.character(final_idx$source_db %||% character(0))),
    warnings = unique(c(as.character(warnings %||% character(0)), as.character((bm_info %||% list())$warning %||% "")))
  )
  meta$warnings <- meta$warnings[nzchar(meta$warnings)]
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = "null"), path)
}

if (!isTRUE(library_only)) {
  reg <- get_preloaded_species_registry(registry_path = registry_rel, base_dir = root)
  if (nrow(reg) == 0L) stop("No preloaded registry rows found.")

  targets <- if (run_all) {
    reg[as.logical(reg$ready), , drop = FALSE]
  } else {
    reg[as.character(reg$species_id) == organism_id_arg & as.logical(reg$ready), , drop = FALSE]
  }
  if (nrow(targets) == 0L) stop("No ready target organisms matched.")

  if (run_all &&
      !identical(Sys.getenv("CGV_ALIAS_INDEX_CHILD", unset = ""), "1") &&
      requireNamespace("processx", quietly = TRUE)) {
    script_path <- tryCatch(
      normalizePath(sys.frames()[[1]]$ofile %||% file.path(root, "scripts", "build_alias_index_biomart.R"),
                    winslash = "/", mustWork = FALSE),
      error = function(e) file.path(root, "scripts", "build_alias_index_biomart.R")
    )
    if (!file.exists(script_path)) {
      script_path <- file.path(root, "scripts", "build_alias_index_biomart.R")
    }
    message(sprintf("Running %d organisms as isolated child jobs (timeout %.0fs each).",
                    nrow(targets), organism_timeout_sec))
    for (i in seq_len(nrow(targets))) {
      sid <- as.character(targets$species_id[i] %||% "")
      label <- as.character(targets$label[i] %||% sid)
      message(sprintf("[%d/%d] %s", i, nrow(targets), label))
      child_args <- c(
        script_path,
        paste0("--root=", root),
        paste0("--registry=", registry_rel),
        paste0("--organism-id=", sid),
        paste0("--biomart-timeout-sec=", as.character(biomart_timeout_sec)),
        if (isTRUE(require_biomart)) "--require-biomart" else character(0)
      )
      child <- tryCatch(
        processx::run(
          command = "Rscript",
          args = child_args,
          echo = TRUE,
          timeout = organism_timeout_sec,
          error_on_status = FALSE,
          env = c(Sys.getenv(), CGV_ALIAS_INDEX_CHILD = "1")
        ),
        error = function(e) {
          message(sprintf("  - child job failed for %s: %s", sid, conditionMessage(e)))
          NULL
        }
      )
      if (is.null(child)) {
        next
      }
      if (!identical(as.integer(child$status %||% 1L), 0L)) {
        message(sprintf("  - child job exited non-zero for %s (status %s)", sid, as.character(child$status %||% "unknown")))
      }
    }
    quit(save = "no", status = 0)
  }

  for (i in seq_len(nrow(targets))) {
    entry <- targets[i, , drop = FALSE]
    sid <- as.character(entry$species_id[1] %||% "")
    label <- as.character(entry$label[1] %||% sid)
    ann <- as.character(entry$annotation_path[1] %||% "")
    message(sprintf("[%d/%d] %s", i, nrow(targets), label))
    warnings <- character(0)
    local_idx <- tryCatch(
      build_alias_index_from_gff(
        file_path = ann,
        organism_id = sid,
        organism_name = as.character(entry$organism[1] %||% label),
        taxid = as.character(entry$taxid[1] %||% ""),
        source_release = basename(ann),
        base_dir = root
      ),
      error = function(e) {
        warnings <<- c(warnings, paste0("Local GFF alias build failed: ", conditionMessage(e)))
        alias_index_empty()
      }
    )
    bm_info <- fetch_biomart_aliases(entry)
    bm_idx <- tryCatch(
      biomart_to_alias_rows(bm_info$data, local_idx, entry, dataset = bm_info$dataset, biomart = bm_info$biomart),
      error = function(e) {
        warnings <<- c(warnings, paste0("BioMart conversion failed: ", conditionMessage(e)))
        alias_index_empty()
      }
    )
    biomart_enriched <- is.data.frame(bm_idx) && nrow(bm_idx) > 0L
    build_status <- if (isTRUE(biomart_enriched)) "biomart_enriched" else "local_only"
    if (!isTRUE(biomart_enriched)) {
      warnings <- c(warnings, "BioMart enrichment produced zero local alias mappings; output is local GFF only.")
    }
    final_idx <- normalize_alias_index_df(rbind(local_idx, bm_idx))
    final_idx <- final_idx[!duplicated(paste(
      final_idx$query_term_upper,
      final_idx$query_term_clean_basic,
      final_idx$query_term_clean_strict,
      final_idx$local_gene_id,
      final_idx$term_type,
      final_idx$source_db,
      sep = "\r"
    )), , drop = FALSE]
    out_path <- write_alias_index_tsv(final_idx, organism_id = sid, base_dir = root)
    meta_path <- alias_index_metadata_path(sid, base_dir = root)
    write_metadata(entry, meta_path, local_idx, final_idx, bm_info, warnings = warnings, build_status = build_status)
    message(sprintf("  - wrote %s (%s rows; status=%s)", out_path, format(nrow(final_idx), big.mark = ","), build_status))
    message(sprintf("  - metadata %s", meta_path))
    if (isTRUE(require_biomart) && !isTRUE(biomart_enriched)) {
      quit(save = "no", status = 2)
    }
  }
}
