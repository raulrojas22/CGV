#!/usr/bin/env Rscript
library(DBI)
library(RSQLite)
library(vroom)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

write_msg <- function(...) message(sprintf("[alias_sqlite] %s", sprintf(...)))

alias_index_dir <- function(base_dir = ".") {
    normalizePath(file.path(base_dir, "data", "alias_index"), winslash = "/", mustWork = TRUE)
}

alias_sqlite_path <- function(organism_id, base_dir = ".") {
    org <- gsub("[^A-Za-z0-9._-]+", "_", trimws(as.character(organism_id %||% "")))
    if (!nzchar(org)) return("")
    file.path(alias_index_dir(base_dir = base_dir), paste0(org, ".alias_index.sqlite"))
}

COL_TYPES <- c(
    organism_id = "c", organism_name = "c", taxid = "c",
    query_term_original = "c", query_term_upper = "c",
    query_term_clean_basic = "c", query_term_clean_strict = "c",
    term_type = "c", local_gene_id = "c", local_transcript_id = "c",
    local_feature_id = "c", local_symbol = "c", chromosome = "c",
    start = "d", end = "d", strand = "c", description = "c",
    source_db = "c", source_release = "c", confidence = "c",
    evidence_source = "c"
)

COMPACT_COLUMNS <- c(
    "organism_id",
    "query_term_original",
    "query_term_upper",
    "query_term_clean_basic",
    "query_term_clean_strict",
    "term_type",
    "local_gene_id",
    "local_feature_id",
    "local_symbol",
    "confidence",
    "source_db"
)

EXACT_QUERY_INDEX_NAME <- "idx_query_term_original"
EXACT_QUERY_INDEX_SQL <- paste(
    "CREATE INDEX IF NOT EXISTS",
    EXACT_QUERY_INDEX_NAME,
    "ON alias_index(query_term_original)"
)

alias_sqlite_has_exact_index <- function(con) {
    if (is.null(con) || !dbIsValid(con) || !("alias_index" %in% dbListTables(con))) {
        return(FALSE)
    }
    fields <- dbListFields(con, "alias_index")
    if (!("query_term_original" %in% fields)) {
        return(FALSE)
    }
    indexes <- dbGetQuery(con, "PRAGMA index_list('alias_index')")
    if (!is.data.frame(indexes) || !(EXACT_QUERY_INDEX_NAME %in% as.character(indexes$name %||% character(0)))) {
        return(FALSE)
    }
    index_info <- dbGetQuery(con, "PRAGMA index_info('idx_query_term_original')")
    identical(as.character(index_info$name %||% character(0)), "query_term_original")
}

ensure_alias_sqlite_exact_index <- function(sqlite_path) {
    path <- normalizePath(as.character(sqlite_path %||% ""), winslash = "/", mustWork = FALSE)
    if (!nzchar(path) || !file.exists(path)) {
        return(list(ok = FALSE, created = FALSE, path = path, reason = "SQLite file not found"))
    }

    con <- NULL
    tryCatch({
        con <- dbConnect(SQLite(), path)
        on.exit({
            if (!is.null(con) && dbIsValid(con)) try(dbDisconnect(con), silent = TRUE)
        }, add = TRUE)
        dbExecute(con, "PRAGMA busy_timeout = 5000")
        if (!("alias_index" %in% dbListTables(con))) {
            return(list(ok = FALSE, created = FALSE, path = path, reason = "alias_index table not found"))
        }
        if (!("query_term_original" %in% dbListFields(con, "alias_index"))) {
            return(list(ok = FALSE, created = FALSE, path = path, reason = "query_term_original column not found"))
        }
        if (alias_sqlite_has_exact_index(con)) {
            return(list(ok = TRUE, created = FALSE, path = path, reason = ""))
        }
        dbExecute(con, EXACT_QUERY_INDEX_SQL)
        ok <- alias_sqlite_has_exact_index(con)
        list(
            ok = isTRUE(ok),
            created = isTRUE(ok),
            path = path,
            reason = if (isTRUE(ok)) "" else "index definition could not be verified"
        )
    }, error = function(e) {
        list(ok = FALSE, created = FALSE, path = path, reason = conditionMessage(e))
    })
}

filter_external_alias_rows <- function(df) {
    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) return(df[0, , drop = FALSE])
    if (!("source_db" %in% names(df))) df$source_db <- ""
    if (!("evidence_source" %in% names(df))) df$evidence_source <- ""
    src <- toupper(trimws(as.character(df$source_db %||% "")))
    ev <- tolower(trimws(as.character(df$evidence_source %||% "")))
    df[!(ev == "local_annotation" | src == "GFF"), , drop = FALSE]
}

build_sqlite_for_tsv <- function(tsv_path, sqlite_path, chunk_size = 500000L, external_compact = TRUE) {
    if (file.exists(sqlite_path)) {
        write_msg("removing existing %s", basename(sqlite_path))
        unlink(sqlite_path, force = TRUE)
    }

    con <- dbConnect(SQLite(), sqlite_path)
    closed <- FALSE
    on.exit({
        try(dbExecute(con, "PRAGMA optimize"), silent = TRUE)
        if (!isTRUE(closed)) try(dbDisconnect(con), silent = TRUE)
    }, add = TRUE)

    dbExecute(con, "PRAGMA journal_mode = OFF")
    dbExecute(con, "PRAGMA synchronous = OFF")
    dbExecute(con, "PRAGMA cache_size = -64000")
    dbExecute(con, "PRAGMA temp_store = MEMORY")

    write_msg("reading %s", basename(tsv_path))
    total_rows <- 0L
    first_chunk <- TRUE

    callback <- function(df, pos) {
        total_rows <<- total_rows + nrow(df)
        if (first_chunk) {
            dbWriteTable(con, "alias_index", df, overwrite = TRUE)
            first_chunk <<- FALSE
        } else {
            dbAppendTable(con, "alias_index", df)
        }
        if (pos %||% 0 > 0) {
            write_msg("  loaded %d rows so far...", total_rows)
        }
        TRUE
    }

    vroom::vroom(tsv_path,
        delim = "\t",
        col_types = COL_TYPES,
        altrep = TRUE,
        progress = FALSE,
        show_col_types = FALSE
    )
    df <- vroom::vroom(tsv_path,
        delim = "\t",
        col_types = COL_TYPES,
        progress = FALSE,
        show_col_types = FALSE
    )
    if (isTRUE(external_compact)) {
        df <- filter_external_alias_rows(as.data.frame(df))
        if (nrow(df) == 0L) {
            write_msg("no external alias rows after compact filter; no SQLite emitted")
            try(dbDisconnect(con), silent = TRUE)
            closed <- TRUE
            unlink(sqlite_path, force = TRUE)
            return(invisible(""))
        }
        for (nm in COMPACT_COLUMNS) {
            if (!nm %in% names(df)) df[[nm]] <- ""
        }
        df <- df[, COMPACT_COLUMNS, drop = FALSE]
        df <- df[!duplicated(paste(
            df$organism_id,
            df$query_term_upper,
            df$query_term_clean_basic,
            df$query_term_clean_strict,
            df$local_gene_id,
            df$local_feature_id,
            df$term_type,
            df$source_db,
            sep = "\r"
        )), , drop = FALSE]
    }
    n <- nrow(df)
    write_msg("writing %d rows to SQLite", n)
    dbWriteTable(con, "alias_index", as.data.frame(df), overwrite = TRUE)
    rm(df)
    invisible(gc())

    write_msg("creating indexes...")
    dbExecute(con, EXACT_QUERY_INDEX_SQL)
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_upper ON alias_index(query_term_upper)")
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_clean_basic ON alias_index(query_term_clean_basic)")
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_clean_strict ON alias_index(query_term_clean_strict)")
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_local_gene ON alias_index(local_gene_id)")
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_local_feature ON alias_index(local_feature_id)")
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_local_symbol ON alias_index(local_symbol)")
    if (!isTRUE(external_compact)) {
        dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_term_type ON alias_index(term_type)")
        dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_confidence ON alias_index(confidence)")
    } else {
        meta <- data.frame(
            key = c("schema_version", "format", "row_count"),
            value = c("2", "external_compact", as.character(n)),
            stringsAsFactors = FALSE
        )
        dbWriteTable(con, "alias_index_meta", meta, overwrite = TRUE)
    }
    dbExecute(con, "VACUUM")

    count <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM alias_index")$n[1]
    write_msg("done: %s (%d rows)", basename(sqlite_path), count)
    invisible(sqlite_path)
}

sqlite_is_current <- function(tsv_path, sqlite_path, external_compact = TRUE) {
    if (!file.exists(sqlite_path)) return(FALSE)
    tsv_mtime <- file.info(tsv_path)$mtime
    sqlite_mtime <- file.info(sqlite_path)$mtime
    if (is.na(tsv_mtime) || is.na(sqlite_mtime) || sqlite_mtime < tsv_mtime) {
        return(FALSE)
    }

    con <- NULL
    tryCatch({
        con <- dbConnect(SQLite(), sqlite_path)
        on.exit(dbDisconnect(con), add = TRUE)
        tables <- dbListTables(con)
        if (!("alias_index" %in% tables)) return(FALSE)
        count <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM alias_index")$n[1]
        if (!is.finite(count) || count <= 0) return(FALSE)
        if (!alias_sqlite_has_exact_index(con)) {
            dbExecute(con, EXACT_QUERY_INDEX_SQL)
            if (!alias_sqlite_has_exact_index(con)) return(FALSE)
        }
        if (isTRUE(external_compact)) {
            if (!("alias_index_meta" %in% tables)) return(FALSE)
            fmt <- dbGetQuery(con, "SELECT value FROM alias_index_meta WHERE key = 'format' LIMIT 1")$value[1]
            return(identical(as.character(fmt), "external_compact"))
        }
        TRUE
    }, error = function(e) {
        FALSE
    })
}

main <- function() {
    args <- commandArgs(trailingOnly = TRUE)
    base_dir <- "."
    organism_filter <- NULL
    external_compact <- TRUE

    has_flag <- function(name) paste0("--", name) %in% args
    arg_value <- function(name, default = NULL) {
        prefix <- paste0("--", name, "=")
        hit <- args[startsWith(args, prefix)]
        if (length(hit) == 0) return(default)
        sub(prefix, "", hit[1], fixed = TRUE)
    }

    if (!is.null(arg_value("root"))) base_dir <- arg_value("root", ".")
    if (has_flag("all")) organism_filter <- NULL
    if (!is.null(arg_value("organism-id"))) organism_filter <- arg_value("organism-id")
    if (has_flag("full")) external_compact <- FALSE

    idx_dir <- alias_index_dir(base_dir)
    tsv_files <- list.files(idx_dir, pattern = "\\.alias_index\\.tsv\\.gz$", full.names = TRUE)
    sqlite_files <- list.files(idx_dir, pattern = "\\.alias_index\\.sqlite$", full.names = TRUE)

    if (!is.null(organism_filter)) {
        tsv_files <- tsv_files[grepl(organism_filter, basename(tsv_files), fixed = TRUE)]
        sqlite_files <- sqlite_files[grepl(organism_filter, basename(sqlite_files), fixed = TRUE)]
    }

    if (length(tsv_files) == 0L && length(sqlite_files) == 0L) {
        write_msg("no alias SQLite or .alias_index.tsv.gz files found in %s", idx_dir)
        return(invisible(NULL))
    }

    if (length(tsv_files) > 0L) {
        write_msg("found %d TSV.gz files to convert", length(tsv_files))
    } else {
        write_msg("no .alias_index.tsv.gz files found; checking existing SQLite files directly")
    }

    for (tsv_path in tsv_files) {
        base_name <- basename(tsv_path)
        org_id <- sub("\\.alias_index\\.tsv\\.gz$", "", base_name)
        sqlite_path <- alias_sqlite_path(org_id, base_dir)
        if (sqlite_is_current(tsv_path, sqlite_path, external_compact = external_compact)) {
            write_msg("skipping %s; SQLite is current", basename(sqlite_path))
            next
        }
        write_msg("converting %s -> %s", base_name, basename(sqlite_path))
        t0 <- Sys.time()
        tryCatch(
            build_sqlite_for_tsv(tsv_path, sqlite_path, external_compact = external_compact),
            error = function(e) {
                write_msg("FAILED %s: %s", base_name, e$message)
            }
        )
        elapsed <- difftime(Sys.time(), t0, units = "secs")
        write_msg("elapsed: %.1fs", as.numeric(elapsed))
    }

    # Migrate SQLite-only assets after processing TSV-backed databases. This order
    # preserves the source-vs-SQLite mtime check, so adding an index cannot make a
    # stale SQLite file appear newer than its source TSV.
    sqlite_files <- list.files(idx_dir, pattern = "\\.alias_index\\.sqlite$", full.names = TRUE)
    if (!is.null(organism_filter)) {
        sqlite_files <- sqlite_files[grepl(organism_filter, basename(sqlite_files), fixed = TRUE)]
    }
    if (length(sqlite_files) > 0L) {
        write_msg("checking exact-query index on %d existing SQLite file(s)", length(sqlite_files))
        for (sqlite_path in sqlite_files) {
            migration <- ensure_alias_sqlite_exact_index(sqlite_path)
            if (isTRUE(migration$created)) {
                write_msg("added %s to %s", EXACT_QUERY_INDEX_NAME, basename(sqlite_path))
            } else if (!isTRUE(migration$ok)) {
                write_msg("FAILED to migrate %s: %s", basename(sqlite_path), migration$reason %||% "unknown error")
            }
        }
    }

    write_msg("all done")
}

if (sys.nframe() == 0L) {
    main()
}
