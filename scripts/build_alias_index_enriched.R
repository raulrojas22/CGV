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

if (has_flag("help")) {
  cat(
    "Usage:\n",
    "  Rscript scripts/build_alias_index_enriched.R --all [--prefilter-ncbi] [--workers=8] [--include-biomart] [--skip-download] [--download-timeout-sec=7200]\n",
    "  Rscript scripts/build_alias_index_enriched.R --organism-id=SPECIES_ID [--include-biomart] [--skip-download] [--download-timeout-sec=7200]\n\n",
    "  Rscript scripts/build_alias_index_enriched.R --organism-id=SPECIES_ID --annotation-path=FILE --organism-name=NAME --taxid=TAXID [--skip-download] [--local-only]\n\n",
    "Builds enriched local alias indexes from GFF + NCBI Gene offline tables.\n",
    "NCBI tables are downloaded once into data/ncbi_gene/ unless --skip-download is used.\n",
    "BioMart can be added as optional best-effort enrichment. Outputs data/alias_index/*.tsv.gz.\n",
    sep = ""
  )
  quit(save = "no", status = 0)
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

root <- normalizePath(arg_value("root", "."), winslash = "/", mustWork = FALSE)
registry_rel <- arg_value("registry", file.path("annotations", "registry.tsv"))
organism_id_arg <- arg_value("organism-id", "")
annotation_path_arg <- arg_value("annotation-path", "")
organism_name_arg <- arg_value("organism-name", "")
label_arg <- arg_value("label", organism_name_arg)
taxid_arg <- arg_value("taxid", "")
run_all <- has_flag("all")
include_biomart <- has_flag("include-biomart")
skip_download <- has_flag("skip-download")
local_only <- has_flag("local-only") || has_flag("skip-ncbi")
prefilter_ncbi <- has_flag("prefilter-ncbi")
workers <- suppressWarnings(as.integer(arg_value("workers", Sys.getenv("CGV_ALIAS_BUILD_WORKERS", "1"))))
if (!is.finite(workers) || is.na(workers) || workers < 1L) {
  workers <- 1L
}
download_timeout_sec <- suppressWarnings(as.numeric(arg_value("download-timeout-sec", "7200")))
if (!is.finite(download_timeout_sec) || is.na(download_timeout_sec) || download_timeout_sec < 60) {
  download_timeout_sec <- 7200
}
ncbi_dir <- normalizePath(arg_value("ncbi-dir", file.path(root, "data", "ncbi_gene")),
                          winslash = "/", mustWork = FALSE)
prefilter_cache_dir <- normalizePath(
  arg_value("prefilter-cache-dir", file.path(ncbi_dir, "prefiltered")),
  winslash = "/", mustWork = FALSE
)
refresh_prefilter <- has_flag("refresh-prefilter")

source(file.path(root, "R", "alias_resolution.R"), local = TRUE)
source(file.path(root, "R", "utils.R"), local = TRUE)

if (!run_all && !nzchar(organism_id_arg)) {
  stop("Pass --all or --organism-id=<species_id>.")
}
if (nzchar(annotation_path_arg) && (!nzchar(organism_id_arg) || !nzchar(organism_name_arg) || !nzchar(taxid_arg))) {
  stop("Custom --annotation-path requires --organism-id, --organism-name, and --taxid.")
}

ncbi_files <- c(
  gene_info = "gene_info.gz",
  gene2refseq = "gene2refseq.gz",
  gene2accession = "gene2accession.gz",
  gene2ensembl = "gene2ensembl.gz"
)

ncbi_urls <- paste0("https://ftp.ncbi.nlm.nih.gov/gene/DATA/", ncbi_files)
names(ncbi_urls) <- names(ncbi_files)

gzip_is_valid <- function(path) {
  path <- as.character(path %||% "")
  if (!nzchar(path) || !file.exists(path)) return(FALSE)
  gzip <- Sys.which("gzip")
  if (nzchar(gzip)) {
    status <- suppressWarnings(system2(gzip, c("-t", path), stdout = FALSE, stderr = FALSE))
    return(identical(as.integer(status), 0L))
  }
  con <- gzfile(path, open = "rt")
  ok <- tryCatch({
    repeat {
      lines <- readLines(con, n = 200000L, warn = FALSE)
      if (!length(lines)) break
    }
    TRUE
  }, error = function(e) FALSE)
  close(con)
  isTRUE(ok)
}

download_ncbi_file <- function(name, dest) {
  url <- ncbi_urls[[name]]
  part <- paste0(dest, ".part")
  if (file.exists(dest) && gzip_is_valid(dest)) {
    return(invisible(TRUE))
  }
  if (file.exists(dest) && !gzip_is_valid(dest)) {
    message(sprintf("  - existing %s is incomplete; resuming download", basename(dest)))
    if (!file.exists(part) || file.info(dest)$size > file.info(part)$size) {
      if (file.exists(part)) unlink(part)
      file.rename(dest, part)
    } else {
      unlink(dest)
    }
  }
  message(sprintf("Downloading NCBI %s -> %s", basename(url), dest))
  old_timeout <- getOption("timeout")
  options(timeout = max(as.numeric(old_timeout %||% 60), download_timeout_sec))
  on.exit(options(timeout = old_timeout), add = TRUE)

  curl <- Sys.which("curl")
  run_download <- function(resume = TRUE) {
    if (nzchar(curl)) {
      args <- c(
        "-L", "--fail", "--retry", "5", "--retry-delay", "5",
        "--connect-timeout", "60", "--speed-time", "120",
        "--speed-limit", "1024", "-o", part, url
      )
      if (isTRUE(resume)) {
        args <- c("-L", "--fail", "--continue-at", "-", "--retry", "5",
                  "--retry-delay", "5", "--connect-timeout", "60",
                  "--speed-time", "120", "--speed-limit", "1024",
                  "-o", part, url)
      }
      status <- suppressWarnings(system2(curl, args))
      return(identical(as.integer(status), 0L))
    }
    tryCatch({
      utils::download.file(url, destfile = part, mode = "wb", method = "libcurl", quiet = FALSE)
      TRUE
    }, error = function(e) {
      message(sprintf("  - download failed for %s: %s", name, conditionMessage(e)))
      FALSE
    })
  }

  ok <- run_download(resume = TRUE)
  if (!isTRUE(ok) || !gzip_is_valid(part)) {
    message(sprintf("  - resumed %s is not a valid gzip; retrying once from scratch", basename(part)))
    if (file.exists(part)) unlink(part)
    ok <- run_download(resume = FALSE)
  }
  if (!isTRUE(ok) || !gzip_is_valid(part)) {
    stop(sprintf(
      "NCBI download for %s is incomplete. Keep %s and rerun; the script will resume it.",
      name, part
    ))
  }
  if (file.exists(dest)) unlink(dest)
  if (!file.rename(part, dest)) {
    stop(sprintf("Could not move completed NCBI download into place: %s", dest))
  }
  invisible(TRUE)
}

ensure_ncbi_gene_tables <- function(dir_path = ncbi_dir, skip_download = FALSE) {
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  out <- file.path(dir_path, ncbi_files)
  names(out) <- names(ncbi_files)
  invalid <- out[!vapply(out, gzip_is_valid, logical(1))]
  if (length(invalid) > 0L) {
    if (isTRUE(skip_download)) {
      stop(
        "Missing or incomplete NCBI Gene tables: ", paste(names(invalid), collapse = ", "),
        ". Re-run without --skip-download so the script can download/resume them."
      )
    }
    for (nm in names(invalid)) {
      download_ncbi_file(nm, invalid[[nm]])
    }
  }
  invalid_after <- out[!vapply(out, gzip_is_valid, logical(1))]
  if (length(invalid_after) > 0L) {
    stop("NCBI Gene tables are still incomplete: ", paste(names(invalid_after), collapse = ", "))
  }
  out
}

read_ncbi_taxid_rows <- function(path, taxids, col_names, comment_char = "#",
                                 chunk_lines = 200000L) {
  taxids <- unique(as.character(taxids %||% character(0)))
  taxids <- taxids[nzchar(taxids)]
  if (!length(taxids) || !file.exists(path)) {
    return(data.frame())
  }
  con <- gzfile(path, open = "rt")
  on.exit(close(con), add = TRUE)
  rows <- list()
  row_i <- 0L
  repeat {
    lines <- readLines(con, n = chunk_lines, warn = FALSE)
    if (!length(lines)) break
    lines <- lines[nzchar(lines) & !startsWith(lines, comment_char)]
    if (!length(lines)) next
    keep <- vapply(strsplit(lines, "\t", fixed = TRUE), function(x) {
      length(x) > 0L && x[[1]] %in% taxids
    }, logical(1))
    if (!any(keep)) next
    row_i <- row_i + 1L
    rows[[row_i]] <- utils::read.delim(
      text = paste(lines[keep], collapse = "\n"),
      sep = "\t",
      header = FALSE,
      stringsAsFactors = FALSE,
      quote = "",
      comment.char = "",
      fill = TRUE,
      col.names = col_names
    )
  }
  if (!length(rows)) return(data.frame())
  bind_rows(rows)
}

write_ncbi_taxid_subset <- function(path, out_path, taxids, comment_char = "#",
                                    chunk_lines = 200000L, refresh = FALSE) {
  taxids <- unique(as.character(taxids %||% character(0)))
  taxids <- taxids[nzchar(taxids)]
  if (!length(taxids) || !file.exists(path)) {
    return(0L)
  }
  if (file.exists(out_path) && gzip_is_valid(out_path) && !isTRUE(refresh)) {
    return(NA_integer_)
  }
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  tmp_path <- paste0(out_path, ".tmp")
  if (file.exists(tmp_path)) unlink(tmp_path)

  count_gzip_lines <- function(gz_path) {
    gzip_bin <- Sys.which("gzip")
    wc_bin <- Sys.which("wc")
    bash_bin <- Sys.which("bash")
    if (nzchar(gzip_bin) && nzchar(wc_bin) && nzchar(bash_bin)) {
      cmd <- sprintf("%s -cd -- %s | %s -l", shQuote(gzip_bin), shQuote(gz_path), shQuote(wc_bin))
      out <- suppressWarnings(system2(bash_bin, c("-lc", cmd), stdout = TRUE, stderr = TRUE))
      n <- suppressWarnings(as.integer(trimws(out[length(out)] %||% "0")))
      if (is.finite(n) && !is.na(n)) return(n)
    }
    con <- gzfile(gz_path, open = "rt")
    on.exit(close(con), add = TRUE)
    n <- 0L
    repeat {
      lines <- readLines(con, n = 200000L, warn = FALSE)
      if (!length(lines)) break
      n <- n + length(lines)
    }
    n
  }

  bash <- Sys.which("bash")
  gzip <- Sys.which("gzip")
  awk <- Sys.which("awk")
  if (nzchar(bash) && nzchar(gzip) && nzchar(awk)) {
    taxid_txt <- paste(taxids, collapse = " ")
    taxid_txt <- gsub("\\\\", "\\\\\\\\", taxid_txt)
    taxid_txt <- gsub("\"", "\\\\\"", taxid_txt)
    awk_program <- sprintf(
      "BEGIN{split(\"%s\",a,\" \"); for(i in a) wanted[a[i]]=1} $1 !~ /^%s/ && ($1 in wanted)",
      taxid_txt,
      gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", comment_char)
    )
    cmd <- sprintf(
      "%s -cd -- %s | %s %s | %s -c > %s",
      shQuote(gzip),
      shQuote(path),
      shQuote(awk),
      shQuote(awk_program),
      shQuote(gzip),
      shQuote(tmp_path)
    )
    status <- suppressWarnings(system2(bash, c("-lc", cmd)))
    if (!identical(as.integer(status), 0L) || !gzip_is_valid(tmp_path)) {
      if (file.exists(tmp_path)) unlink(tmp_path)
      stop(sprintf("External streaming prefilter failed for %s", basename(path)))
    }
    if (file.exists(out_path)) unlink(out_path)
    if (!file.rename(tmp_path, out_path)) {
      stop(sprintf("Could not move NCBI subset into place: %s", out_path))
    }
    return(count_gzip_lines(out_path))
  }

  in_con <- gzfile(path, open = "rt")
  out_con <- gzfile(tmp_path, open = "wt")
  on.exit({
    try(close(in_con), silent = TRUE)
    try(close(out_con), silent = TRUE)
  }, add = TRUE)
  kept <- 0L
  repeat {
    lines <- readLines(in_con, n = chunk_lines, warn = FALSE)
    if (!length(lines)) break
    lines <- lines[nzchar(lines) & !startsWith(lines, comment_char)]
    if (!length(lines)) next
    keep <- vapply(strsplit(lines, "\t", fixed = TRUE), function(x) {
      length(x) > 0L && x[[1]] %in% taxids
    }, logical(1))
    if (!any(keep)) next
    writeLines(lines[keep], out_con, sep = "\n")
    kept <- kept + sum(keep)
  }
  close(in_con)
  close(out_con)
  if (file.exists(out_path)) unlink(out_path)
  if (!file.rename(tmp_path, out_path)) {
    stop(sprintf("Could not move NCBI subset into place: %s", out_path))
  }
  kept
}

build_ncbi_prefilter_cache <- function(ncbi_paths, taxids, cache_dir = prefilter_cache_dir,
                                       refresh = FALSE) {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  out <- file.path(cache_dir, paste0(names(ncbi_paths), ".target_taxids.tsv.gz"))
  names(out) <- names(ncbi_paths)
  message(sprintf("NCBI disk prefilter: writing target-taxid subsets to %s", cache_dir))
  for (nm in names(ncbi_paths)) {
    message(sprintf("  - prefilter %s", basename(ncbi_paths[[nm]])))
    n <- write_ncbi_taxid_subset(ncbi_paths[[nm]], out[[nm]], taxids, refresh = refresh)
    if (is.na(n)) {
      message(sprintf("    using existing %s", out[[nm]]))
    } else if (identical(as.integer(n), -1L)) {
      message(sprintf("    wrote %s with external streaming prefilter", out[[nm]]))
    } else {
      message(sprintf("    wrote %s matching row(s)", format(n, big.mark = ",")))
    }
  }
  invalid <- out[!vapply(out, gzip_is_valid, logical(1))]
  if (length(invalid)) {
    stop("Invalid NCBI prefilter cache files: ", paste(names(invalid), collapse = ", "))
  }
  out
}

clean_term <- function(x) {
  x <- safe_url_decode(as.character(x %||% character(0)))
  x <- trimws(x)
  x <- x[!is.na(x) & nzchar(x) & x != "-" & nchar(x) <= 180]
  unique(x)
}

clean_term_vector <- function(x) {
  x <- safe_url_decode(as.character(x %||% character(0)))
  x <- trimws(x)
  x[is.na(x) | x == "-" | nchar(x) > 180] <- ""
  x
}

split_terms <- function(x, sep = "\\|") {
  clean_term(unlist(strsplit(as.character(x %||% character(0)), sep)))
}

extract_geneid <- function(x) {
  x <- as.character(x %||% character(0))
  hit <- regmatches(x, regexec("(?i)(?:GeneID|NCBI_Gene|NCBI:gene)[:=]?([0-9]+)", x, perl = TRUE))
  out <- vapply(hit, function(m) if (length(m) >= 2L) m[[2]] else "", character(1))
  out[nzchar(out)]
}

extract_refseq_accessions <- function(x) {
  x <- as.character(x %||% character(0))
  vals <- unlist(regmatches(x, gregexpr("\\b(?:N[CGMPRWZ]_|X[MRP]_|Y[PR]_|W[PP]_)[A-Za-z0-9]+(?:\\.[0-9]+)?\\b", x, perl = TRUE)))
  clean_term(vals)
}

strip_version <- function(x) sub("\\.[0-9]+$", "", as.character(x %||% ""))

local_geneid_map <- function(local_idx) {
  if (!is.data.frame(local_idx) || nrow(local_idx) == 0L) return(data.frame())
  gene_ids <- lapply(seq_len(nrow(local_idx)), function(i) extract_geneid(local_idx$query_term_original[i]))
  rows <- lapply(seq_along(gene_ids), function(i) {
    gids <- gene_ids[[i]]
    if (!length(gids)) return(NULL)
    data.frame(
      GeneID = gids,
      local_gene_id = local_idx$local_gene_id[i],
      local_transcript_id = local_idx$local_transcript_id[i],
      local_feature_id = local_idx$local_feature_id[i],
      local_symbol = local_idx$local_symbol[i],
      chromosome = local_idx$chromosome[i],
      start = local_idx$start[i],
      end = local_idx$end[i],
      strand = local_idx$strand[i],
      description = local_idx$description[i],
      stringsAsFactors = FALSE
    )
  })
  out <- bind_rows(rows)
  if (!nrow(out)) return(data.frame())
  out[!duplicated(paste(out$GeneID, out$local_gene_id, sep = "\r")), , drop = FALSE]
}

local_refseq_map <- function(local_idx) {
  if (!is.data.frame(local_idx) || nrow(local_idx) == 0L) return(data.frame())
  accs <- lapply(seq_len(nrow(local_idx)), function(i) extract_refseq_accessions(local_idx$query_term_original[i]))
  rows <- lapply(seq_along(accs), function(i) {
    aa <- accs[[i]]
    if (!length(aa)) return(NULL)
    data.frame(
      accession = aa,
      accession_base = strip_version(aa),
      local_gene_id = local_idx$local_gene_id[i],
      local_transcript_id = local_idx$local_transcript_id[i],
      local_feature_id = local_idx$local_feature_id[i],
      local_symbol = local_idx$local_symbol[i],
      chromosome = local_idx$chromosome[i],
      start = local_idx$start[i],
      end = local_idx$end[i],
      strand = local_idx$strand[i],
      description = local_idx$description[i],
      stringsAsFactors = FALSE
    )
  })
  out <- bind_rows(rows)
  if (!nrow(out)) return(data.frame())
  out[!duplicated(paste(out$accession_base, out$local_gene_id, sep = "\r")), , drop = FALSE]
}

ncbi_gene_info_cols <- c(
  "tax_id", "GeneID", "Symbol", "LocusTag", "Synonyms", "dbXrefs",
  "chromosome", "map_location", "description", "type_of_gene",
  "Symbol_from_nomenclature_authority", "Full_name_from_nomenclature_authority",
  "Nomenclature_status", "Other_designations", "Modification_date", "Feature_type"
)

ncbi_gene2refseq_cols <- c(
  "tax_id", "GeneID", "status", "RNA_nucleotide_accession.version",
  "RNA_nucleotide_gi", "protein_accession.version", "protein_gi",
  "genomic_nucleotide_accession.version", "genomic_nucleotide_gi",
  "start_position_on_the_genomic_accession", "end_position_on_the_genomic_accession",
  "orientation", "assembly", "mature_peptide_accession.version",
  "mature_peptide_gi", "Symbol"
)

ncbi_gene2accession_cols <- c(
  "tax_id", "GeneID", "status", "RNA_nucleotide_accession.version",
  "RNA_nucleotide_gi", "protein_accession.version", "protein_gi",
  "genomic_nucleotide_accession.version", "genomic_nucleotide_gi",
  "start_position_on_the_genomic_accession", "end_position_on_the_genomic_accession",
  "orientation", "assembly", "mature_peptide_accession.version",
  "mature_peptide_gi", "Symbol"
)

ncbi_gene2ensembl_cols <- c(
  "tax_id", "GeneID", "Ensembl_gene_identifier", "RNA_nucleotide_accession.version",
  "Ensembl_rna_identifier", "protein_accession.version", "Ensembl_protein_identifier"
)

term_rows <- function(terms, term_type, target_rows, source_db, source_release, confidence = NULL) {
  terms <- clean_term(terms)
  if (!length(terms) || !is.data.frame(target_rows) || nrow(target_rows) == 0L) {
    return(alias_index_empty())
  }
  keys <- alias_query_keys_df(terms)
  if (!nrow(keys)) return(alias_index_empty())
  if (is.null(confidence)) confidence <- alias_term_confidence(term_type)
  bind_rows(lapply(seq_len(nrow(target_rows)), function(i) {
    data.frame(
      organism_id = as.character(target_rows$organism_id[i] %||% ""),
      organism_name = as.character(target_rows$organism_name[i] %||% ""),
      taxid = as.character(target_rows$taxid[i] %||% ""),
      keys,
      term_type = term_type,
      local_gene_id = target_rows$local_gene_id[i],
      local_transcript_id = target_rows$local_transcript_id[i],
      local_feature_id = target_rows$local_feature_id[i],
      local_symbol = target_rows$local_symbol[i],
      chromosome = target_rows$chromosome[i],
      start = suppressWarnings(as.numeric(target_rows$start[i])),
      end = suppressWarnings(as.numeric(target_rows$end[i])),
      strand = target_rows$strand[i],
      description = as.character(target_rows$description[i] %||% ""),
      source_db = source_db,
      source_release = source_release,
      confidence = confidence,
      evidence_source = source_db,
      stringsAsFactors = FALSE
    )
  }))
}

subset_ncbi_table_by_taxid <- function(df, taxid) {
  if (!is.data.frame(df) || !nrow(df) || !"tax_id" %in% names(df)) return(data.frame())
  df[as.character(df$tax_id) == as.character(taxid), , drop = FALSE]
}

build_ncbi_alias_rows_from_tables <- function(entry, local_idx, ncbi_tables, source_release = "NCBI Gene") {
  taxid <- as.character(entry$taxid[1] %||% "")
  if (!nzchar(taxid)) return(alias_index_empty())
  gene_info <- subset_ncbi_table_by_taxid(ncbi_tables$gene_info %||% data.frame(), taxid)
  gene2refseq <- subset_ncbi_table_by_taxid(ncbi_tables$gene2refseq %||% data.frame(), taxid)
  gene2accession <- subset_ncbi_table_by_taxid(ncbi_tables$gene2accession %||% data.frame(), taxid)
  gene2ensembl <- subset_ncbi_table_by_taxid(ncbi_tables$gene2ensembl %||% data.frame(), taxid)

  gid_map <- local_geneid_map(local_idx)
  ref_map <- local_refseq_map(local_idx)
  accession_gene <- bind_rows(
    gene2refseq[, intersect(c("GeneID", "RNA_nucleotide_accession.version", "protein_accession.version", "genomic_nucleotide_accession.version", "mature_peptide_accession.version"), names(gene2refseq)), drop = FALSE],
    gene2accession[, intersect(c("GeneID", "RNA_nucleotide_accession.version", "protein_accession.version", "genomic_nucleotide_accession.version", "mature_peptide_accession.version"), names(gene2accession)), drop = FALSE],
    gene2ensembl[, intersect(c("GeneID", "RNA_nucleotide_accession.version", "protein_accession.version"), names(gene2ensembl)), drop = FALSE]
  )
  if (nrow(accession_gene) > 0L && nrow(ref_map) > 0L) {
    acc_long <- bind_rows(lapply(setdiff(names(accession_gene), "GeneID"), function(col) {
      data.frame(GeneID = accession_gene$GeneID, accession = accession_gene[[col]], stringsAsFactors = FALSE)
    }))
    acc_long$accession <- clean_term_vector(acc_long$accession)
    acc_long <- acc_long[nzchar(acc_long$accession), , drop = FALSE]
    acc_long$accession_base <- strip_version(acc_long$accession)
    acc_hits <- inner_join(acc_long, ref_map, by = "accession_base", relationship = "many-to-many")
    if (nrow(acc_hits) > 0L) {
      gid_map <- bind_rows(gid_map, acc_hits[, c("GeneID", "local_gene_id", "local_transcript_id", "local_feature_id", "local_symbol", "chromosome", "start", "end", "strand", "description"), drop = FALSE])
    }
  }
  if (!nrow(gid_map)) return(alias_index_empty())
  gid_map <- gid_map[!duplicated(paste(gid_map$GeneID, gid_map$local_gene_id, sep = "\r")), , drop = FALSE]
  gid_map$organism_id <- as.character(entry$species_id[1] %||% "")
  gid_map$organism_name <- as.character(entry$organism[1] %||% entry$label[1] %||% "")
  gid_map$taxid <- taxid

  rows <- list()
  row_i <- 0L
  add_rows <- function(df, gene_col, terms, term_type, source_db = "NCBI", confidence = NULL) {
    if (!is.data.frame(df) || !nrow(df)) return(invisible(NULL))
    for (j in seq_len(nrow(df))) {
      gid <- as.character(df[[gene_col]][j] %||% "")
      targets <- gid_map[gid_map$GeneID == gid, , drop = FALSE]
      if (!nrow(targets)) next
      vals <- if (is.function(terms)) terms(df[j, , drop = FALSE]) else df[[terms]][j]
      built <- term_rows(vals, term_type, targets, source_db = source_db, source_release = source_release, confidence = confidence)
      if (nrow(built)) {
        row_i <<- row_i + 1L
        rows[[row_i]] <<- built
      }
    }
  }

  add_rows(gene_info, "GeneID", "GeneID", "entrezgene_id", confidence = "HIGH")
  add_rows(gene_info, "GeneID", "Symbol", "gene_symbol", confidence = "HIGH")
  add_rows(gene_info, "GeneID", "LocusTag", "locus_tag", confidence = "MEDIUM")
  add_rows(gene_info, "GeneID", function(r) split_terms(r$Synonyms), "synonym", confidence = "MEDIUM")
  add_rows(gene_info, "GeneID", function(r) split_terms(r$dbXrefs), "dbxref", confidence = "MEDIUM")
  add_rows(gene_info, "GeneID", "Symbol_from_nomenclature_authority", "gene_symbol", confidence = "HIGH")
  add_rows(gene_info, "GeneID", "Full_name_from_nomenclature_authority", "gene_name", confidence = "MEDIUM")
  add_rows(gene_info, "GeneID", function(r) split_terms(r$Other_designations), "synonym", confidence = "MEDIUM")

  for (df in list(gene2refseq, gene2accession)) {
    add_rows(df, "GeneID", "RNA_nucleotide_accession.version", "refseq_mrna", confidence = "HIGH")
    add_rows(df, "GeneID", "protein_accession.version", "refseq_peptide", confidence = "HIGH")
    add_rows(df, "GeneID", "mature_peptide_accession.version", "refseq_peptide", confidence = "HIGH")
    add_rows(df, "GeneID", "Symbol", "gene_symbol", confidence = "MEDIUM")
  }
  add_rows(gene2ensembl, "GeneID", "Ensembl_gene_identifier", "ensembl_gene_id", source_db = "NCBI:gene2ensembl", confidence = "HIGH")
  add_rows(gene2ensembl, "GeneID", "Ensembl_rna_identifier", "ensembl_transcript_id", source_db = "NCBI:gene2ensembl", confidence = "HIGH")
  add_rows(gene2ensembl, "GeneID", "Ensembl_protein_identifier", "ensembl_peptide_id", source_db = "NCBI:gene2ensembl", confidence = "HIGH")

  if (!length(rows)) return(alias_index_empty())
  out <- normalize_alias_index_df(bind_rows(rows))
  out <- out[!duplicated(paste(out$query_term_upper, out$local_gene_id, out$term_type, out$source_db, sep = "\r")), , drop = FALSE]
  rownames(out) <- NULL
  out
}

build_ncbi_alias_rows <- function(entry, local_idx, ncbi_paths) {
  taxid <- as.character(entry$taxid[1] %||% "")
  if (!nzchar(taxid)) return(alias_index_empty())
  message(sprintf("  - NCBI: loading taxid %s rows", taxid))
  ncbi_tables <- list(
    gene_info = read_ncbi_taxid_rows(ncbi_paths[["gene_info"]], taxid, ncbi_gene_info_cols),
    gene2refseq = read_ncbi_taxid_rows(ncbi_paths[["gene2refseq"]], taxid, ncbi_gene2refseq_cols),
    gene2accession = read_ncbi_taxid_rows(ncbi_paths[["gene2accession"]], taxid, ncbi_gene2accession_cols),
    gene2ensembl = read_ncbi_taxid_rows(ncbi_paths[["gene2ensembl"]], taxid, ncbi_gene2ensembl_cols)
  )
  build_ncbi_alias_rows_from_tables(
    entry,
    local_idx,
    ncbi_tables,
    source_release = basename(ncbi_paths[["gene_info"]])
  )
}

read_ncbi_prefiltered_tables <- function(ncbi_paths, taxids) {
  taxids <- unique(as.character(taxids %||% character(0)))
  taxids <- taxids[nzchar(taxids)]
  if (!length(taxids)) {
    return(list(
      gene_info = data.frame(),
      gene2refseq = data.frame(),
      gene2accession = data.frame(),
      gene2ensembl = data.frame()
    ))
  }
  message(sprintf(
    "NCBI prefilter: scanning 4 tables once for %d target taxid(s).",
    length(taxids)
  ))
  list(
    gene_info = {
      message("  - prefilter gene_info.gz")
      read_ncbi_taxid_rows(ncbi_paths[["gene_info"]], taxids, ncbi_gene_info_cols)
    },
    gene2refseq = {
      message("  - prefilter gene2refseq.gz")
      read_ncbi_taxid_rows(ncbi_paths[["gene2refseq"]], taxids, ncbi_gene2refseq_cols)
    },
    gene2accession = {
      message("  - prefilter gene2accession.gz")
      read_ncbi_taxid_rows(ncbi_paths[["gene2accession"]], taxids, ncbi_gene2accession_cols)
    },
    gene2ensembl = {
      message("  - prefilter gene2ensembl.gz")
      read_ncbi_taxid_rows(ncbi_paths[["gene2ensembl"]], taxids, ncbi_gene2ensembl_cols)
    }
  )
}

write_enriched_metadata <- function(entry, path, final_idx, sources_status, warnings = character(0)) {
  source_counts <- as.list(table(as.character(final_idx$source_db %||% character(0))))
  meta <- list(
    organism_id = as.character(entry$species_id[1] %||% ""),
    organism_name = as.character(entry$organism[1] %||% entry$label[1] %||% ""),
    taxid = as.character(entry$taxid[1] %||% ""),
    local_annotation_file = as.character(entry$annotation_path[1] %||% ""),
    build_status = if (any(grepl("^NCBI|^BioMart", names(source_counts)))) "enriched" else "local_only",
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    n_alias_terms = nrow(final_idx),
    n_unique_query_terms = length(unique(as.character(final_idx$query_term_upper %||% character(0)))),
    sources = unique(as.character(final_idx$source_db %||% character(0))),
    source_counts = source_counts,
    sources_status = sources_status,
    warnings = unique(as.character(warnings %||% character(0)))
  )
  meta$warnings <- meta$warnings[nzchar(meta$warnings)]
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = "null"), path)
}

run_optional_biomart <- function(entry, local_idx) {
  if (!isTRUE(include_biomart)) return(alias_index_empty())
  biomart_script <- file.path(root, "scripts", "build_alias_index_biomart.R")
  if (!file.exists(biomart_script)) return(alias_index_empty())
  env <- new.env(parent = globalenv())
  old_library_only <- Sys.getenv("CGV_BIOMART_LIBRARY_ONLY", unset = NA_character_)
  Sys.setenv(CGV_BIOMART_LIBRARY_ONLY = "1")
  on.exit({
    if (is.na(old_library_only)) {
      Sys.unsetenv("CGV_BIOMART_LIBRARY_ONLY")
    } else {
      Sys.setenv(CGV_BIOMART_LIBRARY_ONLY = old_library_only)
    }
  }, add = TRUE)
  sys.source(biomart_script, envir = env)
  if (!exists("fetch_biomart_aliases", envir = env, inherits = FALSE) ||
      !exists("biomart_to_alias_rows", envir = env, inherits = FALSE)) {
    return(alias_index_empty())
  }
  bm_info <- get("fetch_biomart_aliases", envir = env)(entry)
  get("biomart_to_alias_rows", envir = env)(bm_info$data, local_idx, entry, dataset = bm_info$dataset, biomart = bm_info$biomart)
}

if (nzchar(annotation_path_arg)) {
  ann_abs <- normalizePath(annotation_path_arg, winslash = "/", mustWork = FALSE)
  targets <- data.frame(
    species_id = organism_id_arg,
    label = if (nzchar(label_arg)) label_arg else organism_name_arg,
    organism = organism_name_arg,
    taxid = suppressWarnings(as.integer(taxid_arg)),
    annotation_path = ann_abs,
    annotation = ann_abs,
    annotation_tabix = ann_abs,
    annotation_index = "",
    genome = "",
    genome_2bit = "",
    aliases = "",
    icon = "",
    kingdom = "",
    ready = file.exists(ann_abs),
    stringsAsFactors = FALSE
  )
  if (!isTRUE(targets$ready[1])) {
    stop("Custom annotation file not found: ", ann_abs)
  }
} else {
  reg <- get_preloaded_species_registry(registry_path = registry_rel, base_dir = root)
  if (!nrow(reg)) stop("No preloaded registry rows found.")
  targets <- if (run_all) {
    reg[as.logical(reg$ready), , drop = FALSE]
  } else {
    reg[as.character(reg$species_id) == organism_id_arg & as.logical(reg$ready), , drop = FALSE]
  }
}
if (!nrow(targets)) stop("No ready target organisms matched.")

ncbi_paths <- NULL
if (!isTRUE(local_only)) {
  ncbi_paths <- ensure_ncbi_gene_tables(skip_download = skip_download)
  missing_ncbi <- names(ncbi_paths)[!file.exists(ncbi_paths)]
  if (length(missing_ncbi)) {
    stop("Missing NCBI Gene tables: ", paste(missing_ncbi, collapse = ", "),
         ". Re-run without --skip-download or download them into ", ncbi_dir)
  }
} else {
  message("NCBI enrichment disabled by --local-only/--skip-ncbi; building aliases from annotation only.")
}

ncbi_prefiltered_tables <- NULL
ncbi_prefilter_cache_paths <- NULL
if (isTRUE(prefilter_ncbi) && !isTRUE(local_only)) {
  ncbi_prefilter_cache_paths <- build_ncbi_prefilter_cache(
    ncbi_paths,
    targets$taxid,
    cache_dir = prefilter_cache_dir,
    refresh = refresh_prefilter
  )
  message("NCBI disk prefilter complete.")
}

build_one_target <- function(i) {
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
  ncbi_idx <- tryCatch(
    if (isTRUE(local_only)) {
      alias_index_empty()
    } else if (isTRUE(prefilter_ncbi)) {
      message(sprintf("  - NCBI: using prefiltered taxid %s rows", as.character(entry$taxid[1] %||% "")))
      build_ncbi_alias_rows(entry, local_idx, ncbi_prefilter_cache_paths)
    } else {
      build_ncbi_alias_rows(entry, local_idx, ncbi_paths)
    },
    error = function(e) {
      warnings <<- c(warnings, paste0("NCBI enrichment failed: ", conditionMessage(e)))
      alias_index_empty()
    }
  )
  biomart_idx <- tryCatch(
    run_optional_biomart(entry, local_idx),
    error = function(e) {
      warnings <<- c(warnings, paste0("BioMart optional enrichment failed: ", conditionMessage(e)))
      alias_index_empty()
    }
  )
  final_idx <- normalize_alias_index_df(bind_rows(local_idx, ncbi_idx, biomart_idx))
  final_idx <- final_idx[!duplicated(paste(
    final_idx$query_term_upper, final_idx$query_term_clean_basic,
    final_idx$query_term_clean_strict, final_idx$local_gene_id,
    final_idx$term_type, final_idx$source_db, sep = "\r"
  )), , drop = FALSE]
  out_path <- write_alias_index_tsv(final_idx, organism_id = sid, base_dir = root)
  meta_path <- alias_index_metadata_path(sid, base_dir = root)
  source_counts <- table(as.character(final_idx$source_db %||% character(0)))
  write_enriched_metadata(
    entry,
    meta_path,
    final_idx,
    sources_status = list(
      gff_rows = unname(source_counts[["GFF"]] %||% 0L),
      ncbi_rows = sum(source_counts[grepl("^NCBI", names(source_counts))] %||% 0L),
      biomart_rows = sum(source_counts[grepl("^BioMart", names(source_counts))] %||% 0L)
    ),
    warnings = warnings
  )
  message(sprintf(
    "  - wrote %s (%s rows; GFF=%s NCBI=%s BioMart=%s)",
    out_path,
    format(nrow(final_idx), big.mark = ","),
    as.integer(source_counts[["GFF"]] %||% 0L),
    as.integer(sum(source_counts[grepl("^NCBI", names(source_counts))] %||% 0L)),
    as.integer(sum(source_counts[grepl("^BioMart", names(source_counts))] %||% 0L))
  ))
  invisible(list(
    organism_id = sid,
    rows = nrow(final_idx),
    gff_rows = as.integer(source_counts[["GFF"]] %||% 0L),
    ncbi_rows = as.integer(sum(source_counts[grepl("^NCBI", names(source_counts))] %||% 0L)),
    biomart_rows = as.integer(sum(source_counts[grepl("^BioMart", names(source_counts))] %||% 0L)),
    warnings = warnings
  ))
}

effective_workers <- min(workers, nrow(targets))
if (isTRUE(include_biomart) && effective_workers > 1L) {
  message("BioMart enrichment requested; forcing --workers=1 to avoid concurrent BioMart calls.")
  effective_workers <- 1L
}

if (effective_workers > 1L && .Platform$OS.type == "unix") {
  message(sprintf("Building %d organism(s) with %d parallel worker(s).", nrow(targets), effective_workers))
  parallel::mclapply(
    seq_len(nrow(targets)),
    build_one_target,
    mc.cores = effective_workers,
    mc.preschedule = FALSE
  )
} else {
  if (effective_workers > 1L) {
    message("Parallel workers requested, but this platform does not support forked workers; using one worker.")
  }
  for (i in seq_len(nrow(targets))) {
    build_one_target(i)
  }
}
