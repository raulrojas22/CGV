#!/usr/bin/env Rscript

source(file.path("R", "utils.R"))
source(file.path("R", "feedback_delivery.R"))
source(file.path("R", "background_report_jobs.R"))

assert <- function(ok, message) {
    if (!isTRUE(ok)) stop(message, call. = FALSE)
}

test_root <- tempfile("cgv-background-reports-")
dir.create(test_root, recursive = TRUE)
on.exit(unlink(test_root, recursive = TRUE, force = TRUE), add = TRUE)

old_cache <- Sys.getenv("CGV_CACHE_DIR", unset = "")
old_enabled <- Sys.getenv("APP_BACKGROUND_REPORTS_ENABLED", unset = "")
old_global_lastz <- Sys.getenv("APP_LASTZ_GLOBAL_WORKERS", unset = "")
on.exit({
    if (nzchar(old_cache)) Sys.setenv(CGV_CACHE_DIR = old_cache) else Sys.unsetenv("CGV_CACHE_DIR")
    if (nzchar(old_enabled)) Sys.setenv(APP_BACKGROUND_REPORTS_ENABLED = old_enabled) else Sys.unsetenv("APP_BACKGROUND_REPORTS_ENABLED")
    if (nzchar(old_global_lastz)) Sys.setenv(APP_LASTZ_GLOBAL_WORKERS = old_global_lastz) else Sys.unsetenv("APP_LASTZ_GLOBAL_WORKERS")
}, add = TRUE)
Sys.setenv(
    CGV_CACHE_DIR = file.path(test_root, "cache"),
    APP_BACKGROUND_REPORTS_ENABLED = "1",
    APP_LASTZ_GLOBAL_WORKERS = "1"
)

slot_result <- cgv_with_global_lastz_slot(function() 42L, base_dir = test_root)
assert(identical(slot_result, 42L), "global LASTZ semaphore returns the protected result")
slot_root <- file.path(Sys.getenv("CGV_CACHE_DIR"), "lastz_global_slots")
assert(length(list.dirs(slot_root, recursive = FALSE)) == 0L, "global LASTZ slot is released after execution")

preloaded_ref <- list(name = "reference.fa", relative_path = "genomes/reference.fa", available = TRUE)
snapshot <- list(
    schema_version = 2L,
    app = list(global_search_query = "TP53"),
    homologous = list(plots = list()),
    orthologous = list(plots = list(list(
        id = "1",
        plot_data = data.frame(feature = "gene"),
        annotation_source = preloaded_ref,
        genome_source = preloaded_ref
    )))
)

queued <- cgv_enqueue_background_report(
    snapshot,
    "scientist@example.org",
    options = list(capture_mode = "complete", run_lastz = TRUE),
    base_dir = test_root
)
assert(grepl("^[a-f0-9]{32}$", queued$id), "queue returns a private job id")
assert(identical(queued$state, "queued"), "new report enters queued state")

claimed <- cgv_claim_next_background_report(test_root)
assert(is.list(claimed) && identical(claimed$job$id, queued$id), "worker claims the queued job")
assert(identical(claimed$job$state, "running"), "claimed job enters running state")
assert(is.null(cgv_claim_next_background_report(test_root)), "a claimed job cannot be claimed twice")

report_result <- list(
    url = "https://cgv.example/share/secret/index.html",
    expires_at = "2026-08-08T12:00:00-0400"
)
ready <- cgv_update_background_report(queued$id, state = "ready", result = report_result, base_dir = test_root)
assert(identical(ready$result$url, report_result$url), "published URL is persisted")

config <- list(
    api_key = "test-key",
    from_email = "CGV Feedback <feedback@cgvapp.com>",
    reply_to = "cgvviewer@gmail.com",
    logo_path = "",
    public_url = "https://cgv.example"
)
delivery <- cgv_report_send_email(
    ready,
    success = TRUE,
    config = config,
    transport = function(request) list(status = 200L, body = '{"id":"report_email_123"}')
)
assert(isTRUE(delivery$ok), "result email accepts a successful Resend response")
assert(identical(delivery$provider_id, "report_email_123"), "provider id is retained")
html <- cgv_report_email_html(ready, success = TRUE, config = config)
assert(grepl(report_result$url, html, fixed = TRUE), "result email contains the secret report URL")
assert(grepl("interactive CGV report", html, fixed = TRUE), "result email uses branded interactive-report copy")

completed <- cgv_update_background_report(queued$id, state = "completed", delivery = delivery, base_dir = test_root)
assert(identical(completed$state, "completed"), "delivered report enters completed state")
cgv_finish_background_report_marker(queued$id, test_root)
assert(!file.exists(claimed$marker), "running marker is removed after completion")

private_snapshot <- snapshot
private_snapshot$orthologous$plots[[1L]]$genome_source <- list(name = "upload.fa", relative_path = "")
private_error <- tryCatch({
    cgv_enqueue_background_report(private_snapshot, "scientist@example.org", base_dir = test_root)
    ""
}, error = function(e) conditionMessage(e))
assert(grepl("preloaded CGV data", private_error, fixed = TRUE), "private uploads are rejected before queueing")

domain_text <- paste(readLines(file.path("R", "server_shared_analysis_domain.R"), warn = FALSE), collapse = "\n")
worker_text <- paste(readLines(file.path("scripts", "background_report_worker.R"), warn = FALSE), collapse = "\n")
compose_text <- paste(readLines("docker-compose.shinyproxy.yml", warn = FALSE), collapse = "\n")
browser_text <- paste(readLines(file.path("www", "js", "reproducible_report.js"), warn = FALSE), collapse = "\n")
assert(grepl('choiceValues = c("session", "email")', domain_text, fixed = TRUE), "Share exposes foreground and email delivery choices")
assert(grepl("CGV_BACKGROUND_REPORT_JOB_PATH", worker_text, fixed = TRUE), "worker launches an isolated snapshot renderer")
assert(grepl("background-report-worker:", compose_text, fixed = TRUE), "ShinyProxy compose runs the detached report worker")
assert(grepl('CGV_PUBLIC_BASE_URL: "${CGV_PUBLIC_BASE_URL:-https://cgvapp.com}"', compose_text, fixed = TRUE), "worker always publishes an externally reachable report URL")
assert(grepl("cgv:background-report-bootstrap", browser_text, fixed = TRUE), "headless browser can trigger the existing report capture")

message("All background report job tests passed.")
