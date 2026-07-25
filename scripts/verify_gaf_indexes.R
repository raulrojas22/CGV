#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = "") {
    prefix <- paste0("--", name, "=")
    hit <- args[startsWith(args, prefix)]
    if (length(hit) == 0L) return(default)
    sub(prefix, "", hit[1], fixed = TRUE)
}

script_arg <- commandArgs(trailingOnly = FALSE)
script_hit <- script_arg[grepl("^--file=", script_arg)]
script_path <- if (length(script_hit) > 0L) sub("^--file=", "", script_hit[1]) else ""
root_default <- if (nzchar(script_path)) dirname(dirname(normalizePath(script_path))) else normalizePath(".")
root <- normalizePath(arg_value("root", root_default), winslash = "/", mustWork = FALSE)
registry_path <- normalizePath(
    file.path(root, arg_value("registry", file.path("go_annotations", "registry.tsv"))),
    winslash = "/",
    mustWork = FALSE
)
expected_count <- suppressWarnings(as.integer(arg_value("expected", "24")))

source(file.path(root, "R", "utils.R"))
source(file.path(root, "R", "server_go_domain.R"))

if (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("RSQLite", quietly = TRUE)) {
    stop("DBI and RSQLite are required to verify GO indexes.")
}
if (!file.exists(registry_path)) stop("GO registry not found: ", registry_path)

registry <- read.delim(registry_path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
for (column in c("gaf_file", "index_file", "index_schema_version", "index_fingerprint")) {
    if (!column %in% names(registry)) registry[[column]] <- ""
}

resolve_path <- function(value) {
    txt <- go_optional_text(value)[1]
    if (!nzchar(txt)) return("")
    if (grepl("^/", txt) || grepl("^[A-Za-z]:[/\\\\]", txt)) {
        return(normalizePath(txt, winslash = "/", mustWork = FALSE))
    }
    normalizePath(file.path(root, txt), winslash = "/", mustWork = FALSE)
}

rows <- registry[nzchar(go_optional_text(registry$gaf_file)), , drop = FALSE]
failures <- character(0)

for (i in seq_len(nrow(rows))) {
    gaf <- resolve_path(rows$gaf_file[i])
    index <- resolve_path(rows$index_file[i])
    label <- as.character(rows$organism[i] %||% rows$species_id[i] %||% basename(gaf))
    expected_fingerprint <- go_optional_text(rows$index_fingerprint[i])[1]

    error_text <- ""
    if (!file.exists(gaf)) {
        error_text <- "GAF missing"
    } else if (!nzchar(index) || !file.exists(index)) {
        error_text <- "index missing"
    } else if (!go_index_is_valid(index, gaf, expected_fingerprint)) {
        error_text <- "schema or fingerprint mismatch"
    } else {
        con <- tryCatch(
            DBI::dbConnect(RSQLite::SQLite(), index, flags = RSQLite::SQLITE_RO),
            error = function(e) NULL
        )
        if (is.null(con)) {
            error_text <- "cannot open SQLite"
        } else {
            integrity <- tryCatch(
                DBI::dbGetQuery(con, "PRAGMA integrity_check")[[1]][1],
                error = function(e) conditionMessage(e)
            )
            count <- tryCatch(
                DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM gaf")$n[1],
                error = function(e) NA_real_
            )
            DBI::dbDisconnect(con)
            if (!identical(as.character(integrity), "ok")) {
                error_text <- paste("integrity check failed:", integrity)
            } else if (!is.finite(as.numeric(count)) || as.numeric(count) <= 0) {
                error_text <- "index contains no rows"
            } else {
                cat(sprintf("[%d/%d] OK %s rows=%s\n", i, nrow(rows), label, format(count, scientific = FALSE)))
            }
        }
    }

    if (nzchar(error_text)) {
        failures <- c(failures, sprintf("%s: %s", label, error_text))
        cat(sprintf("[%d/%d] ERROR %s: %s\n", i, nrow(rows), label, error_text))
    }
}

if (is.finite(expected_count) && nrow(rows) != expected_count) {
    failures <- c(failures, sprintf("Expected %d indexed GAF datasets, found %d.", expected_count, nrow(rows)))
}

if (length(failures) > 0L) {
    cat("\nVerification failed:\n", paste0("- ", failures, collapse = "\n"), "\n", sep = "")
    quit(save = "no", status = 1L)
}

cat(sprintf("\nVerified %d GO SQLite indexes successfully.\n", nrow(rows)))
