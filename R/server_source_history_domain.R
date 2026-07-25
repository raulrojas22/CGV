init_source_history_store <- function(max_entries = 6L) {
    max_entries <- suppressWarnings(as.integer(max_entries))
    if (!is.finite(max_entries) || is.na(max_entries) || max_entries < 1L) {
        max_entries <- 6L
    }

    entries <- list()
    recency <- character()

    normalize_key <- function(key) {
        trimws(as.character(key %||% "")[1L])
    }

    remove <- function(key) {
        key <- normalize_key(key)
        if (!nzchar(key)) {
            return(invisible(FALSE))
        }
        existed <- key %in% names(entries)
        entries[[key]] <<- NULL
        recency <<- setdiff(recency, key)
        invisible(existed)
    }

    put <- function(key, value) {
        key <- normalize_key(key)
        if (!nzchar(key)) {
            return(invisible(FALSE))
        }
        if (is.null(value)) {
            remove(key)
            return(invisible(TRUE))
        }

        entries[[key]] <<- value
        recency <<- c(setdiff(recency, key), key)
        while (length(recency) > max_entries) {
            oldest <- recency[1L]
            entries[[oldest]] <<- NULL
            recency <<- recency[-1L]
        }
        invisible(TRUE)
    }

    get <- function(key, touch = TRUE) {
        key <- normalize_key(key)
        if (!nzchar(key) || !(key %in% names(entries))) {
            return(NULL)
        }
        if (isTRUE(touch)) {
            recency <<- c(setdiff(recency, key), key)
        }
        entries[[key]]
    }

    list(
        put = put,
        get = get,
        remove = remove,
        keys = function() recency,
        size = function() length(entries),
        clear = function() {
            entries <<- list()
            recency <<- character()
            invisible(NULL)
        }
    )
}
