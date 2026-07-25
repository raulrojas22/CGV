source("R/utils.R")

capture_perf_output <- function(perf_enabled, debug_enabled) {
    old_perf <- Sys.getenv("APP_PERF_TIMING", unset = NA_character_)
    old_debug <- Sys.getenv("APP_DEBUG_LOGS", unset = NA_character_)
    on.exit({
        if (is.na(old_perf)) Sys.unsetenv("APP_PERF_TIMING") else Sys.setenv(APP_PERF_TIMING = old_perf)
        if (is.na(old_debug)) Sys.unsetenv("APP_DEBUG_LOGS") else Sys.setenv(APP_DEBUG_LOGS = old_debug)
    }, add = TRUE)

    Sys.setenv(
        APP_PERF_TIMING = if (isTRUE(perf_enabled)) "1" else "0",
        APP_DEBUG_LOGS = if (isTRUE(debug_enabled)) "1" else "0"
    )
    paste(
        capture.output(
            app_perf_mark(app_perf_new_run("FLAG"), "probe", "TEST"),
            type = "message"
        ),
        collapse = "\n"
    )
}

cases <- expand.grid(
    perf = c(FALSE, TRUE),
    debug = c(FALSE, TRUE),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
)

for (i in seq_len(nrow(cases))) {
    output <- capture_perf_output(cases$perf[i], cases$debug[i])
    emitted <- grepl("[PERF][TEST]", output, fixed = TRUE)
    stopifnot(identical(emitted, isTRUE(cases$perf[i])))
}

cat("perf-flag-independence-ok\n")
