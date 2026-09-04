#!/usr/bin/env Rscript

options(warn = 1)

`%||%` <- function(a, b) if (!is.null(a)) a else b

base_dir <- normalizePath(Sys.getenv("APP_DIR", "."), winslash = "/", mustWork = TRUE)
setwd(base_dir)

source(file.path("R", "utils.R"), local = .GlobalEnv)
source(file.path("R", "feedback_delivery.R"), local = .GlobalEnv)
source(file.path("R", "background_report_jobs.R"), local = .GlobalEnv)

worker_log <- function(...) {
    message(sprintf("[background-report-worker] %s", sprintf(...)))
}

worker_home <- trimws(Sys.getenv("HOME", ""))
if (nzchar(worker_home) && startsWith(worker_home, "/tmp/")) {
    dir.create(worker_home, recursive = TRUE, showWarnings = FALSE)
}

resolve_worker_chrome <- function() {
    configured <- trimws(Sys.getenv("CHROMOTE_CHROME", ""))
    discovered <- unname(Sys.which(c(
        "google-chrome",
        "google-chrome-stable",
        "chromium",
        "chromium-browser"
    )))
    candidates <- unique(c(configured, discovered))
    candidates <- candidates[nzchar(candidates) & file.exists(candidates)]
    for (candidate in candidates) {
        usable <- tryCatch({
            version <- suppressWarnings(system2(candidate, "--version", stdout = TRUE, stderr = TRUE))
            identical(as.integer(attr(version, "status") %||% 0L), 0L)
        }, error = function(e) FALSE)
        if (isTRUE(usable)) return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
    stop(
        "No usable headless Chrome/Chromium executable was found. ",
        "Install Google Chrome in the CGV dependency image or set CHROMOTE_CHROME to a working executable."
    )
}

worker_chrome <- resolve_worker_chrome()
Sys.setenv(CHROMOTE_CHROME = worker_chrome)
worker_log("headless browser=%s", worker_chrome)

required <- c("processx", "chromote", "httr2", "jsonlite")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing worker packages: ", paste(missing, collapse = ", "))

worker_chrome_args <- unique(c(
    "--no-sandbox",
    "--disable-dev-shm-usage",
    "--disable-gpu",
    chromote::get_chrome_args()
))
chromote::set_chrome_args(worker_chrome_args)
worker_log("headless browser args=%s", paste(worker_chrome_args, collapse = " "))

verify_worker_chrome <- function(timeout_seconds = 30) {
    verifier <- file.path(base_dir, "scripts", "verify_headless_chrome.R")
    if (!file.exists(verifier)) stop("Missing isolated headless Chrome verifier: ", verifier)

    child_env <- Sys.getenv()
    child_env[["CHROMOTE_CHROME"]] <- worker_chrome
    result <- processx::run(
        "Rscript",
        c("--vanilla", verifier),
        env = child_env,
        echo = FALSE,
        error_on_status = FALSE,
        timeout = max(1, as.numeric(timeout_seconds)) * 1000
    )
    if (!identical(as.integer(result$status %||% 1L), 0L)) {
        detail <- trimws(paste(c(result$stderr, result$stdout), collapse = "\n"))
        if (!nzchar(detail)) detail <- "isolated verifier exited unsuccessfully"
        stop("Headless Chrome preflight failed: ", detail)
    }
    products <- trimws(as.character(result$stdout %||% character(0)))
    products <- products[grepl("^(Chrome|Chromium)/", products)]
    if (!length(products)) stop("Headless Chrome preflight did not return a browser product.")
    products[[length(products)]]
}

poll_seconds <- max(1, suppressWarnings(as.numeric(Sys.getenv("APP_BACKGROUND_REPORT_POLL_SECONDS", "3"))))
timeout_minutes <- max(5, suppressWarnings(as.numeric(Sys.getenv("APP_BACKGROUND_REPORT_TIMEOUT_MINUTES", "30"))))
renderer_port <- suppressWarnings(as.integer(Sys.getenv("APP_BACKGROUND_REPORT_PORT", "3891")))
if (!is.finite(renderer_port) || renderer_port < 1024L || renderer_port > 65535L) renderer_port <- 3891L

paths <- cgv_background_report_paths(base_dir)
log_dir <- file.path(paths$root, "logs")
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
ready_path <- file.path(paths$root, "worker.ready")
if (file.exists(ready_path)) unlink(ready_path, force = TRUE)
delivery_config <- cgv_report_delivery_config()
delivery_preflight <- cgv_report_delivery_preflight(delivery_config)
if (!isTRUE(delivery_preflight$ok)) {
    stop("Report email delivery preflight failed: ", delivery_preflight$error)
}
headless_product <- verify_worker_chrome()
worker_log("headless browser preflight ready; product=%s", headless_product)
writeLines(c(
    format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    paste0("browser=", headless_product)
), ready_path, useBytes = TRUE)
worker_log(
    "email delivery ready; sender=%s reply_to=%s",
    delivery_config$from_email,
    delivery_config$reply_to
)
try(cgv_recover_stale_background_reports(base_dir, stale_minutes = timeout_minutes + 10), silent = TRUE)

wait_for_renderer <- function(process, port, timeout_seconds = 180) {
    deadline <- Sys.time() + timeout_seconds
    url <- sprintf("http://127.0.0.1:%d/", port)
    repeat {
        if (!process$is_alive()) return(FALSE)
        response <- tryCatch(
            httr2::request(url) |>
                httr2::req_timeout(3) |>
                httr2::req_error(is_error = function(resp) FALSE) |>
                httr2::req_perform(),
            error = function(e) NULL
        )
        if (!is.null(response) && httr2::resp_status(response) >= 200L && httr2::resp_status(response) < 500L) {
            return(TRUE)
        }
        if (Sys.time() >= deadline) return(FALSE)
        Sys.sleep(1)
    }
}

deliver_with_retry <- function(job, success) {
    attempts <- max(1L, suppressWarnings(as.integer(Sys.getenv("APP_BACKGROUND_EMAIL_ATTEMPTS", "3"))))
    result <- NULL
    for (attempt in seq_len(attempts)) {
        result <- cgv_report_send_email(job, success = success)
        if (isTRUE(result$ok) || identical(result$state, "not_configured")) break
        if (attempt < attempts) Sys.sleep(min(20, 3 * attempt))
    }
    result
}

render_job <- function(claimed) {
    job <- claimed$job
    job_id <- job$id
    log_path <- file.path(log_dir, paste0(job_id, ".log"))
    worker_log("starting job %s for %s", job_id, job$email)

    child_env <- Sys.getenv()
    child_env[["APP_DIR"]] <- base_dir
    child_env[["APP_HOST"]] <- "127.0.0.1"
    child_env[["APP_PORT"]] <- as.character(renderer_port)
    child_env[["CGV_PUBLIC_BASE_URL"]] <- trimws(Sys.getenv(
        "CGV_PUBLIC_BASE_URL",
        "https://cgev.mobilomics.org"
    ))
    child_env[["APP_PREWARM_ON_START"]] <- "0"
    child_env[["APP_PREWARM_BLOCK_START"]] <- "0"
    child_env[["APP_BACKGROUND_REPORTS_ENABLED"]] <- "1"
    child_env[["CGV_BACKGROUND_REPORT_RENDERER"]] <- "1"
    child_env[["CGV_BACKGROUND_REPORT_JOB_PATH"]] <- claimed$path
    child_env[["APP_SESSION_METRICS"]] <- "0"
    child_env[["APP_FUTURE_WORKERS"]] <- Sys.getenv("APP_BACKGROUND_REPORT_FUTURE_WORKERS", "2")
    child_env[["APP_LASTZ_WORKERS"]] <- Sys.getenv("APP_BACKGROUND_REPORT_LASTZ_WORKERS", "1")

    expression <- paste0(
        "shiny::runApp(Sys.getenv('APP_DIR'), host='127.0.0.1', ",
        "port=as.integer(Sys.getenv('APP_PORT')), launch.browser=FALSE)"
    )
    app_process <- processx::process$new(
        "Rscript",
        c("-e", expression),
        env = child_env,
        stdout = log_path,
        stderr = "2>&1",
        cleanup = TRUE,
        supervise = TRUE
    )
    browser <- NULL
    on.exit({
        if (!is.null(browser)) try(browser$close(), silent = TRUE)
        if (app_process$is_alive()) try(app_process$kill(), silent = TRUE)
    }, add = TRUE)

    if (!wait_for_renderer(app_process, renderer_port)) {
        stop("The internal CGV renderer did not become ready. See ", log_path)
    }

    browser <- chromote::ChromoteSession$new()
    browser$Page$navigate(sprintf("http://127.0.0.1:%d/", renderer_port))
    try(browser$Page$loadEventFired(wait_ = TRUE, timeout_ = 180), silent = TRUE)

    deadline <- Sys.time() + timeout_minutes * 60
    terminal <- NULL
    repeat {
        current <- cgv_read_background_report_job(job_id = job_id, base_dir = base_dir)
        if (!is.list(current)) stop("The worker job file disappeared during rendering.")
        state <- as.character(current$state %||% "")
        if (state %in% c("ready", "failed")) {
            terminal <- current
            break
        }
        if (!app_process$is_alive()) {
            stop("The internal CGV renderer exited before publishing the report. See ", log_path)
        }
        if (Sys.time() >= deadline) stop("Background report generation exceeded the configured timeout.")
        Sys.sleep(2)
    }

    success <- identical(terminal$state, "ready") && is.list(terminal$result) && nzchar(as.character(terminal$result$url %||% ""))
    delivery <- deliver_with_retry(terminal, success = success)
    if (success) {
        final_state <- if (isTRUE(delivery$ok)) "completed" else "failed"
        error <- if (isTRUE(delivery$ok)) "" else paste0("The report was published, but email delivery failed: ", delivery$error %||% "unknown error")
        cgv_update_background_report(job_id, state = final_state, error = error, delivery = delivery, base_dir = base_dir)
        if (isTRUE(delivery$ok)) {
            worker_log("completed job %s; report email accepted", job_id)
        } else {
            worker_log("job %s report ready but email failed: %s", job_id, delivery$error %||% "unknown error")
        }
    } else {
        cgv_update_background_report(job_id, state = "failed", error = terminal$error %||% "Report generation failed.", delivery = delivery, base_dir = base_dir)
        worker_log("failed job %s: %s", job_id, terminal$error %||% "unknown error")
    }
    invisible(TRUE)
}

worker_log("ready; queue=%s", paths$queued)
repeat {
    claimed <- tryCatch(cgv_claim_next_background_report(base_dir), error = function(e) {
        worker_log("queue claim failed: %s", conditionMessage(e))
        NULL
    })
    if (is.null(claimed)) {
        try(cgv_cleanup_background_reports(base_dir), silent = TRUE)
        Sys.sleep(poll_seconds)
        next
    }

    tryCatch(
        render_job(claimed),
        error = function(e) {
            job_id <- claimed$job$id
            message_text <- conditionMessage(e)
            failed_job <- tryCatch(
                cgv_update_background_report(job_id, state = "failed", error = message_text, base_dir = base_dir),
                error = function(update_error) claimed$job
            )
            failed_job$error <- message_text
            delivery <- tryCatch(deliver_with_retry(failed_job, success = FALSE), error = function(mail_error) list(ok = FALSE, state = "failed", error = conditionMessage(mail_error)))
            try(cgv_update_background_report(job_id, state = "failed", error = message_text, delivery = delivery, base_dir = base_dir), silent = TRUE)
            worker_log("job %s crashed: %s", job_id, message_text)
        }
    )
    cgv_finish_background_report_marker(claimed$job$id, base_dir)
}
