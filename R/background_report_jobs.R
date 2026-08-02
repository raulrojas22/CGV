# Durable background-report queue and branded result delivery.
#
# The queue deliberately uses only the shared CGV cache. Every ShinyProxy
# container can enqueue a job, while one dedicated worker claims and renders
# them serially. Job files are private; only the finished /share/<token> report
# is exposed by nginx.

cgv_background_reports_enabled <- function() {
    if (exists("app_env_flag", mode = "function")) {
        return(isTRUE(app_env_flag("APP_BACKGROUND_REPORTS_ENABLED", default = FALSE)))
    }
    raw <- tolower(trimws(Sys.getenv("APP_BACKGROUND_REPORTS_ENABLED", "0")))
    raw %in% c("1", "true", "yes", "on")
}

cgv_background_report_root <- function(base_dir = ".") {
    cache_root <- if (exists("get_cgv_cache_root", mode = "function")) {
        get_cgv_cache_root(base_dir)
    } else {
        file.path(base_dir, "cache")
    }
    file.path(cache_root, "background_reports")
}

cgv_background_report_paths <- function(base_dir = ".") {
    root <- cgv_background_report_root(base_dir)
    paths <- list(
        root = root,
        jobs = file.path(root, "jobs"),
        queued = file.path(root, "queued"),
        running = file.path(root, "running")
    )
    invisible(lapply(paths, dir.create, recursive = TRUE, showWarnings = FALSE))
    # ShinyProxy may assign an arbitrary unprivileged UID to app containers,
    # while the dedicated worker has its own UID. The queue stays outside every
    # public nginx alias, but must remain writable by both processes.
    invisible(lapply(unname(paths), Sys.chmod, mode = "0777", use_umask = FALSE))
    paths
}

cgv_background_report_job_path <- function(job_id, base_dir = ".") {
    job_id <- tolower(trimws(as.character(job_id %||% "")))
    if (!grepl("^[a-f0-9]{32}$", job_id)) stop("Invalid background-report job id.")
    file.path(cgv_background_report_paths(base_dir)$jobs, paste0(job_id, ".rds"))
}

cgv_atomic_save_rds <- function(value, path) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    staging <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
    on.exit(if (file.exists(staging)) unlink(staging, force = TRUE), add = TRUE)
    saveRDS(value, staging, compress = "gzip")
    if (!file.rename(staging, path)) stop("Could not atomically persist the background-report job.")
    invisible(path)
}

cgv_read_background_report_job <- function(job_id = "", path = "", base_dir = ".") {
    target <- trimws(as.character(path %||% ""))
    if (!nzchar(target)) target <- cgv_background_report_job_path(job_id, base_dir)
    if (!file.exists(target)) return(NULL)
    job <- tryCatch(readRDS(target), error = function(e) NULL)
    if (!is.list(job) || !grepl("^[a-f0-9]{32}$", as.character(job$id %||% ""))) return(NULL)
    job
}

cgv_write_background_report_job <- function(job, base_dir = ".") {
    if (!is.list(job)) stop("Invalid background-report job.")
    path <- cgv_background_report_job_path(job$id, base_dir)
    job$updated_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    cgv_atomic_save_rds(job, path)
}

cgv_background_report_summary <- function(snapshot) {
    app <- snapshot$app %||% list()
    genes <- unique(Filter(nzchar, c(
        as.character(app$global_search_query %||% ""),
        as.character(app$global_search_query_collapsed %||% ""),
        as.character(app$filter1 %||% ""),
        as.character(app$gene_name %||% "")
    )))
    homo <- (snapshot$homologous %||% list())$plots %||% list()
    ortho <- (snapshot$orthologous %||% list())$plots %||% list()
    list(
        genes = genes,
        multi_gene_results = length(homo),
        cross_species_results = length(ortho)
    )
}

cgv_snapshot_has_unportable_sources <- function(snapshot) {
    plots <- c(
        (snapshot$homologous %||% list())$plots %||% list(),
        (snapshot$orthologous %||% list())$plots %||% list()
    )
    any(vapply(plots, function(plot) {
        if (!is.list(plot)) return(FALSE)
        refs <- list(plot$annotation_source %||% list(), plot$genome_source %||% list())
        any(vapply(refs, function(ref) {
            is.list(ref) && nzchar(as.character(ref$name %||% "")) &&
                !nzchar(as.character(ref$relative_path %||% ""))
        }, logical(1)))
    }, logical(1)))
}

cgv_enqueue_background_report <- function(snapshot,
                                          email,
                                          options = list(),
                                          base_dir = ".") {
    if (!cgv_background_reports_enabled()) stop("Background report delivery is not enabled.")
    email <- if (exists("feedback_normalize_header_text", mode = "function")) {
        feedback_normalize_header_text(email)
    } else {
        trimws(as.character(email %||% ""))
    }
    valid_email <- if (exists("feedback_is_valid_email", mode = "function")) {
        feedback_is_valid_email(email)
    } else {
        grepl("^[^\\s@<>]+@[^\\s@<>]+\\.[^\\s@<>]+$", email, perl = TRUE)
    }
    if (!isTRUE(valid_email)) stop("Enter a valid email address for report delivery.")
    if (!is.list(snapshot) || !length(snapshot)) stop("The current analysis could not be captured.")
    if (cgv_snapshot_has_unportable_sources(snapshot)) {
        stop("Background delivery currently supports preloaded CGV data only. Remove uploaded/private sources or generate the report in this session.")
    }
    max_snapshot_mb <- suppressWarnings(as.numeric(Sys.getenv("APP_BACKGROUND_REPORT_SNAPSHOT_MAX_MB", "200")))
    if (!is.finite(max_snapshot_mb) || max_snapshot_mb < 10) max_snapshot_mb <- 200
    snapshot_bytes <- as.numeric(utils::object.size(snapshot))
    if (is.finite(snapshot_bytes) && snapshot_bytes > max_snapshot_mb * 1024^2) {
        stop(sprintf(
            "This analysis snapshot is %.1f MB; the background queue limit is %.1f MB.",
            snapshot_bytes / 1024^2,
            max_snapshot_mb
        ))
    }

    paths <- cgv_background_report_paths(base_dir)
    job_id <- if (exists("cgv_random_secret", mode = "function")) {
        cgv_random_secret(16L)
    } else {
        paste(sprintf("%02x", sample.int(256L, 16L, replace = TRUE) - 1L), collapse = "")
    }
    created <- Sys.time()
    job <- list(
        schema_version = 1L,
        id = job_id,
        state = "queued",
        created_at = format(created, "%Y-%m-%dT%H:%M:%S%z"),
        updated_at = format(created, "%Y-%m-%dT%H:%M:%S%z"),
        email = email,
        summary = cgv_background_report_summary(snapshot),
        options = options,
        snapshot = snapshot,
        attempts = 0L,
        result = NULL,
        error = "",
        delivery = NULL
    )
    cgv_write_background_report_job(job, base_dir)
    marker <- file.path(paths$queued, paste0(format(created, "%Y%m%d%H%M%OS6"), "-", job_id, ".ready"))
    marker <- gsub(":", "", marker, fixed = TRUE)
    if (!file.create(marker)) {
        unlink(cgv_background_report_job_path(job_id, base_dir), force = TRUE)
        stop("Could not place the background report in the processing queue.")
    }
    list(
        id = job_id,
        state = "queued",
        email = email,
        created_at = job$created_at,
        summary = job$summary
    )
}

cgv_claim_next_background_report <- function(base_dir = ".") {
    paths <- cgv_background_report_paths(base_dir)
    markers <- sort(list.files(paths$queued, pattern = "\\.ready$", full.names = TRUE))
    if (!length(markers)) return(NULL)
    for (marker in markers) {
        match <- regexec("-([a-f0-9]{32})\\.ready$", basename(marker))
        pieces <- regmatches(basename(marker), match)[[1L]]
        if (length(pieces) != 2L) {
            unlink(marker, force = TRUE)
            next
        }
        job_id <- pieces[[2L]]
        claimed <- file.path(paths$running, paste0(job_id, ".running"))
        if (!file.rename(marker, claimed)) next
        job <- cgv_read_background_report_job(job_id = job_id, base_dir = base_dir)
        if (!is.list(job)) {
            unlink(claimed, force = TRUE)
            next
        }
        job$state <- "running"
        job$attempts <- as.integer(job$attempts %||% 0L) + 1L
        job$started_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
        cgv_write_background_report_job(job, base_dir)
        return(list(job = job, marker = claimed, path = cgv_background_report_job_path(job_id, base_dir)))
    }
    NULL
}

cgv_update_background_report <- function(job_id,
                                         state = NULL,
                                         result = NULL,
                                         error = NULL,
                                         delivery = NULL,
                                         base_dir = ".") {
    job <- cgv_read_background_report_job(job_id = job_id, base_dir = base_dir)
    if (!is.list(job)) stop("Background-report job not found.")
    if (!is.null(state)) job$state <- as.character(state)
    if (!is.null(result)) job$result <- result
    if (!is.null(error)) job$error <- substr(as.character(error %||% ""), 1L, 2000L)
    if (!is.null(delivery)) job$delivery <- delivery
    if (as.character(job$state %||% "") %in% c("ready", "completed", "failed")) {
        job$finished_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    }
    cgv_write_background_report_job(job, base_dir)
    job
}

cgv_finish_background_report_marker <- function(job_id, base_dir = ".") {
    marker <- file.path(cgv_background_report_paths(base_dir)$running, paste0(job_id, ".running"))
    if (file.exists(marker)) unlink(marker, force = TRUE)
    invisible(!file.exists(marker))
}

cgv_recover_stale_background_reports <- function(base_dir = ".", stale_minutes = 45) {
    paths <- cgv_background_report_paths(base_dir)
    markers <- list.files(paths$running, pattern = "\\.running$", full.names = TRUE)
    if (!length(markers)) return(invisible(0L))
    recovered <- 0L
    for (marker in markers) {
        info <- file.info(marker)
        age <- if (!is.na(info$mtime)) as.numeric(difftime(Sys.time(), info$mtime, units = "mins")) else Inf
        if (!is.finite(age) || age < max(5, as.numeric(stale_minutes))) next
        job_id <- sub("\\.running$", "", basename(marker))
        job <- cgv_read_background_report_job(job_id = job_id, base_dir = base_dir)
        if (!is.list(job) || as.character(job$state %||% "") %in% c("completed", "failed")) {
            unlink(marker, force = TRUE)
            next
        }
        job$state <- "queued"
        job$error <- "Recovered after the report worker restarted."
        cgv_write_background_report_job(job, base_dir)
        queued <- file.path(paths$queued, paste0(format(Sys.time(), "%Y%m%d%H%M%OS6"), "-", job_id, ".ready"))
        queued <- gsub(":", "", queued, fixed = TRUE)
        if (file.rename(marker, queued)) recovered <- recovered + 1L
    }
    invisible(recovered)
}

cgv_cleanup_background_reports <- function(base_dir = ".", now = Sys.time(), keep_days = 7) {
    paths <- cgv_background_report_paths(base_dir)
    files <- list.files(paths$jobs, pattern = "\\.rds$", full.names = TRUE)
    if (!length(files)) return(invisible(0L))
    removed <- 0L
    for (path in files) {
        job <- cgv_read_background_report_job(path = path)
        if (!is.list(job)) {
            unlink(path, force = TRUE)
            removed <- removed + as.integer(!file.exists(path))
            next
        }
        finished <- suppressWarnings(as.POSIXct(job$finished_at %||% job$updated_at, format = "%Y-%m-%dT%H:%M:%S%z"))
        terminal <- as.character(job$state %||% "") %in% c("completed", "failed")
        if (terminal && !is.na(finished) && finished <= now - max(1, keep_days) * 86400) {
            unlink(path, force = TRUE)
            cgv_finish_background_report_marker(job$id, base_dir)
            removed <- removed + as.integer(!file.exists(path))
        }
    }
    invisible(removed)
}

cgv_report_delivery_config <- function(getenv = Sys.getenv) {
    feedback_config <- if (exists("feedback_delivery_config", mode = "function")) {
        feedback_delivery_config(getenv = getenv)
    } else {
        list(api_key = "", to_email = "cgvviewer@gmail.com", from_email = "CGV <feedback@cgvapp.com>", logo_path = file.path("www", "cgv-email-logo.png"))
    }
    env_value <- function(name, fallback = "") {
        value <- trimws(as.character(getenv(name, unset = "") %||% ""))
        if (nzchar(value)) value else as.character(fallback %||% "")
    }
    list(
        api_key = env_value("REPORT_RESEND_API_KEY", feedback_config$api_key),
        from_email = env_value("REPORT_FROM_EMAIL", "CGV Reports <reports@cgvapp.com>"),
        reply_to = env_value("REPORT_REPLY_TO_EMAIL", feedback_config$to_email %||% "cgvviewer@gmail.com"),
        logo_path = env_value("REPORT_LOGO_PATH", feedback_config$logo_path),
        public_url = sub("/+$", "", env_value("CGV_PUBLIC_BASE_URL", feedback_config$public_url))
    )
}

cgv_report_request_meta <- function(job) {
    options <- job$options %||% list()
    alignment <- identical(tolower(trimws(as.character(options$request_kind %||% "report"))), "alignment")
    workflow <- if (isTRUE(options$include_multi_gene) && isTRUE(options$include_cross_species)) {
        "Multi-Gene and Cross-Species"
    } else if (isTRUE(options$include_multi_gene)) {
        "Multi-Gene"
    } else if (isTRUE(options$include_cross_species)) {
        "Cross-Species"
    } else {
        "CGV"
    }
    mode <- switch(
        tolower(trimws(as.character(options$alignment_mode %||% "complete"))),
        blocks = "LASTZ blocks and MultiPIP",
        multipip = "MultiPIP and LASTZ blocks",
        "LASTZ and MultiPIP"
    )
    list(alignment = alignment, workflow = workflow, mode = mode)
}

cgv_report_email_subject <- function(job, success = TRUE) {
    meta <- cgv_report_request_meta(job)
    if (isTRUE(success)) {
        if (isTRUE(meta$alignment)) "Your CGV alignment report is ready" else "Your interactive CGV report is ready"
    } else {
        if (isTRUE(meta$alignment)) "CGV could not complete your alignment report" else "CGV could not complete your report"
    }
}

cgv_report_email_text <- function(job, success = TRUE) {
    meta <- cgv_report_request_meta(job)
    if (isTRUE(success)) {
        paste(
            if (isTRUE(meta$alignment)) {
                "Your Comparative Gene Viewer alignment report is ready."
            } else {
                "Your Comparative Gene Viewer interactive report is ready."
            },
            "",
            if (isTRUE(meta$alignment)) paste0("Workflow: ", meta$workflow) else "",
            if (isTRUE(meta$alignment)) paste0("Alignment views: ", meta$mode) else "",
            paste0("Open report: ", job$result$url %||% ""),
            paste0("Expires: ", job$result$expires_at %||% "automatically"),
            paste0("Reference: ", job$id %||% ""),
            "",
            "The report is an immutable, read-only snapshot of the analysis submitted to the background queue.",
            "Anyone with the secret URL can view the report until it expires.",
            sep = "\n"
        )
    } else {
        paste(
            "CGV could not finish your background report.",
            "",
            paste0("Reference: ", job$id %||% ""),
            paste0("Reason: ", job$error %||% "The report worker stopped before publication."),
            "",
            "You can return to CGV and submit the analysis again.",
            sep = "\n"
        )
    }
}

cgv_report_email_html <- function(job, success = TRUE, config = cgv_report_delivery_config()) {
    esc <- if (exists("feedback_html_escape", mode = "function")) feedback_html_escape else function(x) as.character(x %||% "")
    summary <- job$summary %||% list()
    meta <- cgv_report_request_meta(job)
    genes <- paste(as.character(summary$genes %||% character(0)), collapse = ", ")
    if (!nzchar(genes)) genes <- "CGV analysis"
    if (isTRUE(success)) {
        badge <- if (isTRUE(meta$alignment)) "Alignment report ready" else "Report ready"
        heading <- if (isTRUE(meta$alignment)) {
            "Your complete CGV alignment report is ready"
        } else {
            "Your interactive CGV report is ready"
        }
        description <- if (isTRUE(meta$alignment)) {
            paste0(
                "CGV finished the requested ", esc(meta$workflow),
                " analysis in the background. The interactive report includes the structural results, analytics and completed ",
                esc(meta$mode), "."
            )
        } else {
            "CGV finished the analysis snapshot you sent to the background queue. You can open the complete read-only report without returning to the original session."
        }
        alignment_details <- if (isTRUE(meta$alignment)) paste0(
            '<div style="margin-top:7px;font-size:12px;line-height:18px;color:#60758a;">Workflow: ', esc(meta$workflow),
            '<br>Alignment views: ', esc(meta$mode), '</div>'
        ) else ""
        content <- paste0(
            '<span style="display:inline-block;padding:6px 10px;border-radius:999px;font-size:11px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;background:#eafaf6;color:#087a65;border:1px solid #bdece1;">', esc(badge), '</span>',
            '<h1 style="margin:16px 0 8px;font-size:25px;line-height:32px;color:#263d55;">', esc(heading), '</h1>',
            '<div style="font-size:14px;line-height:22px;color:#536b81;">', description, '</div>',
            '<div style="margin-top:22px;padding:18px;background:#edf8f6;border:1px solid #ccebe5;border-radius:10px;">',
            '<div style="font-size:11px;line-height:16px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;color:#087a65;">Analysis snapshot</div>',
            '<div style="margin-top:5px;font-size:17px;line-height:24px;font-weight:700;color:#263d55;">', esc(genes), '</div>',
            alignment_details,
            '<div style="margin-top:7px;font-size:12px;line-height:18px;color:#60758a;">Reference: ', esc(job$id), '<br>Expires: ', esc(job$result$expires_at %||% "automatically"), '</div></div>',
            '<div style="margin-top:24px;"><a href="', esc(job$result$url %||% ""), '" style="display:inline-block;padding:12px 18px;border-radius:8px;background:#18a98e;color:#ffffff;font-size:14px;line-height:19px;font-weight:700;text-decoration:none;">Open interactive report</a></div>',
            '<div style="margin-top:18px;font-size:12px;line-height:19px;color:#7b8c9d;">This secret URL acts as the access key. Anyone who receives it can view and copy the report until it expires. The report reflects the session exactly when the job was submitted.</div>'
        )
        preheader <- if (isTRUE(meta$alignment)) {
            "Your complete CGV alignment report is ready."
        } else {
            "Your complete interactive CGV report is ready."
        }
    } else {
        failed_heading <- if (isTRUE(meta$alignment)) {
            "CGV could not finish the alignment report"
        } else {
            "CGV could not finish the report"
        }
        content <- paste0(
            '<span style="display:inline-block;padding:6px 10px;border-radius:999px;font-size:11px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;background:#fff1f0;color:#b42318;border:1px solid #ffd6d2;">Report not completed</span>',
            '<h1 style="margin:16px 0 8px;font-size:25px;line-height:32px;color:#263d55;">', esc(failed_heading), '</h1>',
            '<div style="font-size:14px;line-height:22px;color:#536b81;">The background worker stopped before publishing the requested analysis snapshot.</div>',
            '<div style="margin-top:22px;padding:18px;background:#fff7f6;border:1px solid #f3d4d0;border-radius:10px;">',
            '<div style="font-size:11px;line-height:16px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;color:#b42318;">Reference ', esc(job$id), '</div>',
            '<div style="margin-top:7px;font-size:13px;line-height:21px;color:#536b81;">', esc(job$error %||% "The report worker stopped before publication."), '</div></div>',
            '<div style="margin-top:24px;"><a href="', esc(config$public_url %||% ""), '" style="display:inline-block;padding:11px 17px;border-radius:8px;background:#314c70;color:#ffffff;font-size:13px;line-height:18px;font-weight:700;text-decoration:none;">Return to CGV</a></div>'
        )
        preheader <- if (isTRUE(meta$alignment)) {
            "CGV could not complete your alignment report."
        } else {
            "CGV could not complete your background report."
        }
    }
    if (exists("feedback_email_shell", mode = "function")) {
        feedback_email_shell(content, preheader = preheader)
    } else {
        paste0("<!doctype html><html><body>", content, "</body></html>")
    }
}

cgv_report_send_email <- function(job,
                                  success = TRUE,
                                  config = cgv_report_delivery_config(),
                                  transport = NULL) {
    if (!nzchar(config$api_key %||% "")) {
        return(list(ok = FALSE, state = "not_configured", status = NA_integer_, provider_id = "", error = "REPORT_RESEND_API_KEY/FEEDBACK_RESEND_API_KEY is not configured."))
    }
    email <- trimws(as.character(job$email %||% ""))
    from_address <- if (exists("feedback_extract_address", mode = "function")) feedback_extract_address(config$from_email) else config$from_email
    valid <- if (exists("feedback_is_valid_email", mode = "function")) feedback_is_valid_email else function(x) grepl("@", x, fixed = TRUE)
    if (!valid(email) || !valid(from_address) || !valid(config$reply_to)) {
        return(list(ok = FALSE, state = "invalid_configuration", status = NA_integer_, provider_id = "", error = "Report sender, recipient, or reply address is invalid."))
    }
    attachment <- if (exists("feedback_logo_attachment", mode = "function")) feedback_logo_attachment(config) else NULL
    body <- list(
        from = config$from_email,
        to = list(email),
        reply_to = list(config$reply_to),
        subject = cgv_report_email_subject(job, success = success),
        text = cgv_report_email_text(job, success = success),
        html = cgv_report_email_html(job, success = success, config = config)
    )
    if (!is.null(attachment)) body$attachments <- list(attachment)
    request <- httr2::request("https://api.resend.com/emails") |>
        httr2::req_headers(
            Authorization = paste("Bearer", config$api_key),
            `Content-Type` = "application/json",
            `Idempotency-Key` = substr(paste0("cgv-report-", job$id, "-", if (isTRUE(success)) "ready" else "failed"), 1L, 200L)
        ) |>
        httr2::req_body_json(body) |>
        httr2::req_timeout(15) |>
        httr2::req_error(is_error = function(resp) FALSE)
    response <- tryCatch(
        if (is.function(transport)) transport(request) else {
            performed <- httr2::req_perform(request)
            list(status = httr2::resp_status(performed), body = tryCatch(httr2::resp_body_string(performed), error = function(e) ""))
        },
        error = function(e) list(status = NA_integer_, body = "", transport_error = conditionMessage(e))
    )
    status <- suppressWarnings(as.integer(response$status %||% NA_integer_))
    if (is.finite(status) && status >= 200L && status < 300L) {
        parsed <- tryCatch(jsonlite::fromJSON(response$body %||% "", simplifyVector = TRUE), error = function(e) list())
        return(list(ok = TRUE, state = "accepted", status = status, provider_id = as.character(parsed$id %||% ""), error = ""))
    }
    list(
        ok = FALSE,
        state = "failed",
        status = status,
        provider_id = "",
        error = substr(as.character(response$transport_error %||% response$body %||% "Resend rejected the report email."), 1L, 500L)
    )
}
