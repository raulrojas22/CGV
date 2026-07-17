#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

lock_path <- file.path("desktop", "guide-media-lock.json")
if (!file.exists(lock_path)) stop("Missing CGV Guide media lock: ", lock_path, call. = FALSE)
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required to prepare CGV Guide media.", call. = FALSE)

lock <- jsonlite::fromJSON(lock_path)
expected <- sort(as.character(lock$expectedFiles %||% character(0)))
if (!identical(as.integer(lock$version), 1L) ||
    !grepl("^https://", as.character(lock$url), perl = TRUE) ||
    !grepl("^[a-f0-9]{64}$", as.character(lock$sha256), perl = TRUE) ||
    length(expected) != 35L) {
  stop("Invalid CGV Guide media lock.", call. = FALSE)
}

destination <- file.path("www", "screencasts")
is_complete <- dir.exists(destination) && all(file.exists(file.path(destination, expected)))
if (is_complete) {
  message("guide-media-ok files=", length(expected), " source=existing")
  quit(status = 0L)
}

archive <- tempfile("cgv-guide-media-", fileext = ".zip")
staging <- tempfile("cgv-guide-media-staging-")
on.exit(unlink(c(archive, staging), recursive = TRUE, force = TRUE), add = TRUE)
utils::download.file(as.character(lock$url), archive, mode = "wb", quiet = FALSE)

hash_line <- system2("sha256sum", archive, stdout = TRUE, stderr = TRUE)
actual_hash <- tolower(strsplit(trimws(hash_line[[1L]]), "\\s+", perl = TRUE)[[1L]][[1L]])
if (!identical(actual_hash, tolower(as.character(lock$sha256)))) {
  stop("CGV Guide media checksum mismatch.", call. = FALSE)
}

archive_entries <- utils::unzip(archive, list = TRUE)
entry_names <- sort(as.character(archive_entries$Name %||% character(0)))
if (!identical(entry_names, expected) || any(grepl("[/\\\\]", entry_names))) {
  stop("CGV Guide media archive contents do not match the lock.", call. = FALSE)
}

dir.create(staging, recursive = TRUE, showWarnings = FALSE)
utils::unzip(archive, exdir = staging)
sizes <- file.info(file.path(staging, expected))$size
if (any(!is.finite(sizes) | sizes <= 1024)) {
  stop("CGV Guide media archive contains missing or empty videos.", call. = FALSE)
}

unlink(destination, recursive = TRUE, force = TRUE)
dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
if (!file.rename(staging, destination)) stop("Could not install CGV Guide media.", call. = FALSE)
message("guide-media-ok files=", length(expected), " source=locked-release")
