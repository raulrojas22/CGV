#!/usr/bin/env Rscript

options(warn = 1)

`%||%` <- function(a, b) if (!is.null(a)) a else b

main <- function() {
    if (!requireNamespace("chromote", quietly = TRUE)) {
        stop("The R package 'chromote' is not installed.")
    }

    chrome_home <- trimws(Sys.getenv("HOME", ""))
    if (nzchar(chrome_home) && startsWith(chrome_home, "/tmp/")) {
        dir.create(chrome_home, recursive = TRUE, showWarnings = FALSE)
    }

    chrome_args <- unique(c(
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        chromote::get_chrome_args()
    ))
    chromote::set_chrome_args(chrome_args)

    browser <- NULL
    on.exit({
        if (!is.null(browser)) try(browser$close(), silent = TRUE)
        if (chromote::has_default_chromote_object()) {
            try(chromote::default_chromote_object()$close(), silent = TRUE)
        }
    }, add = TRUE)

    browser <- chromote::ChromoteSession$new()
    version <- browser$Browser$getVersion()
    product <- trimws(as.character(version$product %||% ""))
    if (!nzchar(product)) {
        stop("Headless Chrome started but did not return its browser version.")
    }
    writeLines(product, stdout(), useBytes = TRUE)
}

main()
