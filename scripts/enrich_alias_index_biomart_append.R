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
    "  Rscript scripts/enrich_alias_index_biomart_append.R --all [--biomart-timeout-sec=120]\n",
    "  Rscript scripts/enrich_alias_index_biomart_append.R --organism-id=SPECIES_ID [--biomart-timeout-sec=120]\n\n",
    "Appends BioMart-derived alias rows to existing data/alias_index/*.alias_index.tsv.gz or *.alias_index.sqlite files.\n",
    "Existing NCBI/GFF rows are preserved. BioMart failures are recorded and do not overwrite indexes.\n",
    "\nOptions:\n",
    "  --root=PATH                  Project root. Default: .\n",
    "  --registry=PATH              Registry TSV. Default: annotations/registry.tsv\n",
    "  --backup-dir=PATH            Backup directory. Default: data/alias_index/backups/<timestamp>\n",
    "  --no-backup                  Do not copy the original index before overwriting.\n",
    "  --dry-run                    Report additions but do not write files.\n",
    "  --refresh-biomart            Attempt BioMart even if metadata says BioMart already added rows.\n",
    sep = ""
  )
  quit(save = "no", status = 0)
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

root <- normalizePath(arg_value("root", "."), winslash = "/", mustWork = FALSE)
registry_rel <- arg_value("registry", file.path("annotations", "registry.tsv"))
organism_id_arg <- arg_value("organism-id", "")
run_all <- has_flag("all")
dry_run <- has_flag("dry-run")
backup_enabled <- !has_flag("no-backup")
refresh_biomart <- has_flag("refresh-biomart")
backup_stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
backup_dir <- normalizePath(
  arg_value("backup-dir", file.path(root, "data", "alias_index", "backups", backup_stamp)),
  winslash = "/",
  mustWork = FALSE
)

if (!run_all && !nzchar(organism_id_arg)) {
  stop("Pass --all or --organism-id=<species_id>.")
}

source(file.path(root, "R", "alias_resolution.R"), local = TRUE)
source(file.path(root, "R", "utils.R"), local = TRUE)

biomart_script <- file.path(root, "scripts", "build_alias_index_biomart.R")
if (!file.exists(biomart_script)) {
  stop("Missing BioMart helper script: ", biomart_script)
}

old_library_only <- Sys.getenv("CGV_BIOMART_LIBRARY_ONLY", unset = NA_character_)
Sys.setenv(CGV_BIOMART_LIBRARY_ONLY = "1")
on.exit({
  if (is.na(old_library_only)) {
    Sys.unsetenv("CGV_BIOMART_LIBRARY_ONLY")
  } else {
    Sys.setenv(CGV_BIOMART_LIBRARY_ONLY = old_library_only)
  }
}, add = TRUE)

bm_env <- new.env(parent = globalenv())
sys.source(biomart_script, envir = bm_env)

fetch_biomart_aliases <- get("fetch_biomart_aliases", envir = bm_env, inherits = FALSE)
biomart_to_alias_rows <- get("biomart_to_alias_rows", envir = bm_env, inherits = FALSE)

read_metadata <- function(path) {
  if (!file.exists(path)) return(list())
  tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE), error = function(e) list())
}

alias_row_key <- function(df) {
  df <- normalize_alias_index_df(df)
  paste(
    toupper(trimws(as.character(df$query_term_upper %||% ""))),
    toupper(trimws(as.character(df$query_term_clean_basic %||% ""))),
    toupper(trimws(as.character(df$query_term_clean_strict %||% ""))),
    trimws(as.character(df$local_gene_id %||% "")),
    sep = "\r"
  )
}

source_counts_list <- function(df) {
  df <- normalize_alias_index_df(df)
  as.list(table(as.character(df$source_db %||% character(0))))
}

write_append_metadata <- function(entry, meta_path, previous_meta, final_idx, append_info) {
  counts <- source_counts_list(final_idx)
  out <- previous_meta
  out$organism_id <- as.character(entry$species_id[1] %||% out$organism_id %||% "")
  out$organism_name <- as.character(entry$organism[1] %||% entry$label[1] %||% out$organism_name %||% "")
  out$taxid <- as.character(entry$taxid[1] %||% out$taxid %||% "")
  out$local_annotation_file <- as.character(entry$annotation_path[1] %||% out$local_annotation_file %||% "")
  out$build_status <- if (any(grepl("^NCBI|^BioMart", names(counts)))) "enriched" else "local_only"
  out$generated_at <- as.character(out$generated_at %||% "")
  out$last_updated_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  out$n_alias_terms <- nrow(final_idx)
  out$n_unique_query_terms <- length(unique(as.character(final_idx$query_term_upper %||% character(0))))
  out$sources <- unique(as.character(final_idx$source_db %||% character(0)))
  out$source_counts <- counts
  out$biomart_append <- append_info
  dir.create(dirname(meta_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(jsonlite::toJSON(out, auto_unbox = TRUE, pretty = TRUE, null = "null"), meta_path)
}

backup_index_files <- function(index_path, metadata_path, organism_id) {
  if (!isTRUE(backup_enabled) || isTRUE(dry_run)) {
    return(invisible(FALSE))
  }
  dir.create(backup_dir, recursive = TRUE, showWarnings = FALSE)
  if (file.exists(index_path)) {
    file.copy(index_path, file.path(backup_dir, basename(index_path)), overwrite = TRUE)
  }
  for (suffix in c("-wal", "-shm")) {
    sidecar <- paste0(index_path, suffix)
    if (file.exists(sidecar)) {
      file.copy(sidecar, file.path(backup_dir, basename(sidecar)), overwrite = TRUE)
    }
  }
  if (file.exists(metadata_path)) {
    file.copy(metadata_path, file.path(backup_dir, basename(metadata_path)), overwrite = TRUE)
  }
  invisible(TRUE)
}

existing_alias_index_path <- function(organism_id, base_dir = ".") {
  sqlite_path <- alias_sqlite_path(organism_id, base_dir = base_dir)
  if (nzchar(sqlite_path) && file.exists(sqlite_path)) return(sqlite_path)
  tsv_path <- alias_index_path(organism_id, base_dir = base_dir)
  if (nzchar(tsv_path) && file.exists(tsv_path)) return(tsv_path)
  tsv_path
}

read_alias_index_file <- function(path) {
  path <- as.character(path %||% "")
  if (!nzchar(path) || !file.exists(path)) return(alias_index_empty())
  if (grepl("\\.sqlite$", path, ignore.case = TRUE)) {
    if (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("RSQLite", quietly = TRUE)) {
      stop("DBI and RSQLite are required to read alias SQLite files.")
    }
    con <- DBI::dbConnect(RSQLite::SQLite(), path, flags = RSQLite::SQLITE_RO)
    on.exit(try(DBI::dbDisconnect(con), silent = TRUE), add = TRUE)
    fields <- DBI::dbListFields(con, "alias_index")
    select_cols <- paste(DBI::dbQuoteIdentifier(con, fields), collapse = ", ")
    return(normalize_alias_index_df(DBI::dbGetQuery(con, paste("SELECT", select_cols, "FROM alias_index"))))
  }
  if (requireNamespace("vroom", quietly = TRUE)) {
    return(normalize_alias_index_df(as.data.frame(vroom::vroom(path, delim = "\t", show_col_types = FALSE, progress = FALSE))))
  }
  normalize_alias_index_df(read.delim(gzfile(path, open = "rt"), sep = "\t", stringsAsFactors = FALSE, check.names = FALSE))
}

write_alias_index_sqlite_full <- function(alias_index, sqlite_path) {
  if (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("RSQLite", quietly = TRUE)) {
    stop("DBI and RSQLite are required to write alias SQLite files.")
  }
  out <- normalize_alias_index_df(alias_index)
  sqlite_path <- as.character(sqlite_path %||% "")
  if (!nzchar(sqlite_path)) stop("Missing SQLite output path.")
  dir.create(dirname(sqlite_path), recursive = TRUE, showWarnings = FALSE)
  unlink(c(sqlite_path, paste0(sqlite_path, "-wal"), paste0(sqlite_path, "-shm")), force = TRUE)
  con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
  on.exit({
    try(DBI::dbExecute(con, "PRAGMA optimize"), silent = TRUE)
    try(DBI::dbDisconnect(con), silent = TRUE)
  }, add = TRUE)
  DBI::dbExecute(con, "PRAGMA journal_mode = OFF")
  DBI::dbExecute(con, "PRAGMA synchronous = OFF")
  DBI::dbExecute(con, "PRAGMA temp_store = MEMORY")
  DBI::dbWriteTable(con, "alias_index", as.data.frame(out), overwrite = TRUE)
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_alias_org_upper ON alias_index(organism_id, query_term_upper)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_alias_org_basic ON alias_index(organism_id, query_term_clean_basic)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_alias_org_strict ON alias_index(organism_id, query_term_clean_strict)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_alias_local_gene ON alias_index(organism_id, local_gene_id)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_upper ON alias_index(query_term_upper)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_clean_basic ON alias_index(query_term_clean_basic)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_clean_strict ON alias_index(query_term_clean_strict)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_local_gene ON alias_index(local_gene_id)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_local_feature ON alias_index(local_feature_id)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_local_symbol ON alias_index(local_symbol)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_local_symbol_upper ON alias_index(UPPER(local_symbol))")
  DBI::dbExecute(con, "VACUUM")
  sqlite_path
}

write_alias_index_file <- function(alias_index, path, organism_id, base_dir = ".") {
  if (grepl("\\.sqlite$", path, ignore.case = TRUE)) {
    return(write_alias_index_sqlite_full(alias_index, path))
  }
  write_alias_index_tsv(alias_index, organism_id = organism_id, base_dir = base_dir)
}

reg <- get_preloaded_species_registry(registry_path = registry_rel, base_dir = root)
if (!nrow(reg)) stop("No preloaded registry rows found.")

targets <- if (run_all) {
  reg[as.logical(reg$ready), , drop = FALSE]
} else {
  reg[as.character(reg$species_id) == organism_id_arg & as.logical(reg$ready), , drop = FALSE]
}
if (!nrow(targets)) stop("No ready target organisms matched.")

message(sprintf(
  "BioMart append enrichment for %d organism(s). dry_run=%s backup=%s",
  nrow(targets),
  dry_run,
  backup_enabled
))
if (isTRUE(backup_enabled) && !isTRUE(dry_run)) {
  message("Backup directory: ", backup_dir)
}

summary_rows <- list()

for (i in seq_len(nrow(targets))) {
  entry <- targets[i, , drop = FALSE]
  sid <- as.character(entry$species_id[1] %||% "")
  label <- as.character(entry$label[1] %||% entry$organism[1] %||% sid)
  index_path <- existing_alias_index_path(sid, base_dir = root)
  metadata_path <- alias_index_metadata_path(sid, base_dir = root)
  message(sprintf("[%d/%d] %s", i, nrow(targets), label))

  if (!file.exists(index_path)) {
    message("  - skipped: alias index file not found: ", index_path)
    summary_rows[[length(summary_rows) + 1L]] <- data.frame(
      organism_id = sid,
      organism_name = label,
      status = "missing_index",
      previous_rows = 0L,
      biomart_candidate_rows = 0L,
      biomart_new_rows = 0L,
      final_rows = 0L,
      dataset = "",
      biomart = "",
      warning = "missing alias index",
      stringsAsFactors = FALSE
    )
    next
  }

  previous_meta <- read_metadata(metadata_path)
  previous_counts <- previous_meta$source_counts %||% list()
  previous_biomart_rows <- suppressWarnings(sum(unlist(previous_counts[grepl("^BioMart", names(previous_counts))]), na.rm = TRUE))
  if (!isTRUE(refresh_biomart) && is.finite(previous_biomart_rows) && previous_biomart_rows > 0L) {
    message(sprintf("  - skipped: metadata already contains %s BioMart row(s). Use --refresh-biomart to retry.", previous_biomart_rows))
    summary_rows[[length(summary_rows) + 1L]] <- data.frame(
      organism_id = sid,
      organism_name = label,
      status = "already_biomart_enriched",
      previous_rows = suppressWarnings(as.integer(previous_meta$n_alias_terms %||% NA_integer_)),
      biomart_candidate_rows = as.integer(previous_biomart_rows),
      biomart_new_rows = 0L,
      final_rows = suppressWarnings(as.integer(previous_meta$n_alias_terms %||% NA_integer_)),
      dataset = as.character((previous_meta$biomart_append %||% list())$dataset %||% ""),
      biomart = as.character((previous_meta$biomart_append %||% list())$biomart %||% ""),
      warning = "",
      stringsAsFactors = FALSE
    )
    next
  }

  existing_idx <- read_alias_index_file(index_path)
  existing_idx <- normalize_alias_index_df(existing_idx)
  previous_rows <- nrow(existing_idx)
  if (!previous_rows) {
    message("  - skipped: existing alias index is empty.")
    next
  }

  bm_info <- tryCatch(
    fetch_biomart_aliases(entry),
    error = function(e) list(data = data.frame(), dataset = "", biomart = "", warning = paste0("BioMart fetch failed: ", conditionMessage(e)))
  )
  bm_data <- bm_info$data %||% data.frame()
  bm_idx <- tryCatch(
    biomart_to_alias_rows(
      bm_data,
      existing_idx,
      entry,
      dataset = as.character(bm_info$dataset %||% ""),
      biomart = as.character(bm_info$biomart %||% "")
    ),
    error = function(e) {
      bm_info$warning <<- paste(c(as.character(bm_info$warning %||% ""), paste0("BioMart conversion failed: ", conditionMessage(e))), collapse = " | ")
      alias_index_empty()
    }
  )
  bm_idx <- normalize_alias_index_df(bm_idx)
  bm_candidate_rows <- nrow(bm_idx)

  existing_keys <- alias_row_key(existing_idx)
  bm_keys <- alias_row_key(bm_idx)
  bm_new <- bm_idx[!bm_keys %in% existing_keys, , drop = FALSE]
  if (nrow(bm_new) > 0L) {
    bm_new <- bm_new[!duplicated(alias_row_key(bm_new)), , drop = FALSE]
  }
  biomart_new_rows <- nrow(bm_new)

  final_idx <- normalize_alias_index_df(bind_rows(existing_idx, bm_new))
  final_idx <- final_idx[!duplicated(alias_row_key(final_idx)), , drop = FALSE]
  rownames(final_idx) <- NULL

  status <- if (biomart_new_rows > 0L) {
    "biomart_appended"
  } else if (bm_candidate_rows > 0L) {
    "biomart_no_new_rows"
  } else {
    "biomart_no_mappings"
  }
  warning_txt <- paste(unique(as.character(bm_info$warning %||% character(0))), collapse = " | ")
  warning_txt <- trimws(gsub("\\s+", " ", warning_txt))

  message(sprintf(
    "  - BioMart dataset=%s mart=%s candidates=%s new=%s",
    as.character(bm_info$dataset %||% ""),
    as.character(bm_info$biomart %||% ""),
    format(bm_candidate_rows, big.mark = ","),
    format(biomart_new_rows, big.mark = ",")
  ))
  if (nzchar(warning_txt)) {
    message("  - warnings: ", warning_txt)
  }

  append_info <- list(
    status = status,
    run_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    dataset = as.character(bm_info$dataset %||% ""),
    biomart = as.character(bm_info$biomart %||% ""),
    previous_rows = previous_rows,
    biomart_candidate_rows = bm_candidate_rows,
    biomart_new_rows = biomart_new_rows,
    final_rows = nrow(final_idx),
    warnings = if (nzchar(warning_txt)) warning_txt else character(0)
  )

  if (!isTRUE(dry_run)) {
    backup_index_files(index_path, metadata_path, sid)
    write_alias_index_file(final_idx, index_path, organism_id = sid, base_dir = root)
    write_append_metadata(entry, metadata_path, previous_meta, final_idx, append_info)
    message(sprintf("  - wrote %s (%s rows total)", index_path, format(nrow(final_idx), big.mark = ",")))
  } else {
    message(sprintf("  - dry-run: would write %s rows total", format(nrow(final_idx), big.mark = ",")))
  }

  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    organism_id = sid,
    organism_name = label,
    status = status,
    previous_rows = previous_rows,
    biomart_candidate_rows = bm_candidate_rows,
    biomart_new_rows = biomart_new_rows,
    final_rows = nrow(final_idx),
    dataset = as.character(bm_info$dataset %||% ""),
    biomart = as.character(bm_info$biomart %||% ""),
    warning = warning_txt,
    stringsAsFactors = FALSE
  )
}

summary_df <- if (length(summary_rows)) bind_rows(summary_rows) else data.frame()
summary_path <- file.path(alias_index_dir(base_dir = root), paste0("biomart_append_summary_", backup_stamp, ".tsv"))
if (nrow(summary_df) > 0L && !isTRUE(dry_run)) {
  write.table(summary_df, summary_path, sep = "\t", quote = FALSE, row.names = FALSE, na = "")
  message("Summary written: ", summary_path)
}

if (nrow(summary_df) > 0L) {
  message("BioMart append summary:")
  print(summary_df[, c("organism_name", "status", "previous_rows", "biomart_candidate_rows", "biomart_new_rows", "final_rows"), drop = FALSE], row.names = FALSE)
}
