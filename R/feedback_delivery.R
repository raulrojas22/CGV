CGV_FEEDBACK_DEFAULT_TO_EMAIL <- "cgvviewer@gmail.com"
CGV_FEEDBACK_DEFAULT_FROM_EMAIL <- "CGeV Feedback <feedback@cgvapp.com>"
CGV_FEEDBACK_DEFAULT_PUBLIC_URL <- "https://cgev.mobilomics.org"
CGV_FEEDBACK_DEFAULT_BACKUP_URL <- "https://cgvapp.com"
CGV_FEEDBACK_DEFAULT_LOGO_PATH <- file.path("www", "cgv-email-logo.png")

feedback_env_value <- function(name, default = "", getenv = Sys.getenv) {
    value <- trimws(as.character(getenv(as.character(name), unset = "") %||% ""))
    if (nzchar(value)) value else as.character(default %||% "")
}

feedback_normalize_text <- function(x) {
    text <- gsub("\r\n?", "\n", as.character(x %||% ""))
    trimws(text)
}

feedback_normalize_header_text <- function(x) {
    text <- feedback_normalize_text(x)
    trimws(gsub("[[:space:]]+", " ", text, perl = TRUE))
}

feedback_env_flag_value <- function(name, default = TRUE, getenv = Sys.getenv) {
    fallback <- if (isTRUE(default)) "1" else "0"
    value <- tolower(feedback_env_value(name, default = fallback, getenv = getenv))
    value %in% c("1", "true", "yes", "on")
}

feedback_is_valid_email <- function(x) {
    email <- feedback_normalize_header_text(x)
    nchar(email, type = "chars") <= 254L &&
        grepl("^[^\\s@<>]+@[^\\s@<>]+\\.[^\\s@<>]+$", email, perl = TRUE)
}

feedback_extract_address <- function(x) {
    value <- feedback_normalize_header_text(x)
    if (grepl("<[^<>]+>$", value, perl = TRUE)) {
        return(sub("^.*<([^<>]+)>$", "\\1", value, perl = TRUE))
    }
    value
}

feedback_delivery_config <- function(getenv = Sys.getenv) {
    list(
        api_key = feedback_env_value("FEEDBACK_RESEND_API_KEY", getenv = getenv),
        to_email = feedback_env_value(
            "FEEDBACK_TO_EMAIL",
            default = CGV_FEEDBACK_DEFAULT_TO_EMAIL,
            getenv = getenv
        ),
        from_email = feedback_env_value(
            "FEEDBACK_FROM_EMAIL",
            default = CGV_FEEDBACK_DEFAULT_FROM_EMAIL,
            getenv = getenv
        ),
        public_url = sub(
            "/+$",
            "",
            feedback_env_value(
                "FEEDBACK_PUBLIC_URL",
                default = CGV_FEEDBACK_DEFAULT_PUBLIC_URL,
                getenv = getenv
            )
        ),
        backup_url = sub(
            "/+$",
            "",
            feedback_env_value(
                "FEEDBACK_BACKUP_URL",
                default = CGV_FEEDBACK_DEFAULT_BACKUP_URL,
                getenv = getenv
            )
        ),
        logo_path = feedback_env_value(
            "FEEDBACK_LOGO_PATH",
            default = CGV_FEEDBACK_DEFAULT_LOGO_PATH,
            getenv = getenv
        ),
        send_receipt = feedback_env_flag_value(
            "FEEDBACK_SEND_RECEIPT",
            default = TRUE,
            getenv = getenv
        )
    )
}

feedback_html_escape <- function(x) {
    value <- as.character(x %||% "")
    value <- gsub("&", "&amp;", value, fixed = TRUE)
    value <- gsub("<", "&lt;", value, fixed = TRUE)
    value <- gsub(">", "&gt;", value, fixed = TRUE)
    value <- gsub('"', "&quot;", value, fixed = TRUE)
    gsub("'", "&#39;", value, fixed = TRUE)
}

feedback_html_text <- function(x) {
    gsub("\n", "<br>", feedback_html_escape(feedback_normalize_text(x)), fixed = TRUE)
}

feedback_first_name <- function(x) {
    full_name <- feedback_normalize_header_text(x)
    if (!nzchar(full_name)) return("there")
    strsplit(full_name, "[[:space:]]+", perl = TRUE)[[1L]][1L]
}

feedback_detail_values <- function(payload) {
    is_bug <- grepl("bug", payload$feedback_type %||% "", ignore.case = TRUE)
    list(
        is_bug = is_bug,
        primary_label = if (is_bug) {
            "What happened / steps to reproduce"
        } else {
            "Current limitation or need"
        },
        primary = if (is_bug) {
            payload$bug_steps %||% ""
        } else {
            payload$current_limitation %||% ""
        },
        secondary_label = if (is_bug) {
            "Expected behavior"
        } else {
            "Requested improvement"
        },
        secondary = if (is_bug) {
            payload$expected_behavior %||% ""
        } else {
            payload$requested_improvement %||% ""
        }
    )
}

feedback_email_shell <- function(content, preheader = "") {
    paste0(
        '<!doctype html><html><head><meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width,initial-scale=1">',
        '<title>Comparative Gene Viewer</title></head>',
        '<body style="margin:0;padding:0;background:#f3f6f9;color:#24364b;',
        'font-family:Arial,Helvetica,sans-serif;-webkit-font-smoothing:antialiased;">',
        '<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">',
        feedback_html_escape(preheader),
        '</div>',
        '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" ',
        'style="width:100%;background:#f3f6f9;"><tr><td align="center" style="padding:28px 14px;">',
        '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" ',
        'style="width:100%;max-width:640px;background:#ffffff;border:1px solid #dce5ed;',
        'border-radius:14px;overflow:hidden;box-shadow:0 8px 30px rgba(36,54,75,.08);">',
        '<tr><td style="height:5px;background:#18bc9c;font-size:0;line-height:0;">&nbsp;</td></tr>',
        '<tr><td style="padding:22px 28px;border-bottom:1px solid #e6edf3;">',
        '<table role="presentation" cellspacing="0" cellpadding="0" border="0"><tr>',
        '<td style="padding-right:14px;vertical-align:middle;">',
        '<img src="cid:cgv-logo" width="64" height="48" alt="CGeV" ',
        'style="display:block;width:64px;height:48px;border:0;">',
        '</td><td style="vertical-align:middle;">',
        '<div style="font-family:Georgia,Times New Roman,serif;font-size:25px;line-height:28px;',
        'font-weight:700;letter-spacing:.02em;color:#314c70;">CGeV</div>',
        '<div style="font-size:12px;line-height:18px;color:#6c8196;">Comparative Gene Viewer</div>',
        '</td></tr></table></td></tr>',
        '<tr><td style="padding:30px 28px 26px;">',
        content,
        '</td></tr>',
        '<tr><td style="padding:18px 28px;background:#f8fafc;border-top:1px solid #e6edf3;">',
        '<div style="font-size:11px;line-height:17px;color:#7b8c9d;">',
        'Comparative Gene Viewer · Gene structure, alignment, analytics and figures.',
        '</div></td></tr>',
        '</table></td></tr></table></body></html>'
    )
}

feedback_type_badge <- function(payload) {
    details <- feedback_detail_values(payload)
    colors <- if (isTRUE(details$is_bug)) {
        c(background = "#fff1f0", foreground = "#b42318", border = "#ffd6d2")
    } else {
        c(background = "#eafaf6", foreground = "#087a65", border = "#bdece1")
    }
    paste0(
        '<span style="display:inline-block;padding:6px 10px;border-radius:999px;',
        'font-size:11px;line-height:14px;font-weight:700;letter-spacing:.04em;',
        'text-transform:uppercase;background:', colors[["background"]],
        ';color:', colors[["foreground"]], ';border:1px solid:', colors[["border"]], ';">',
        feedback_html_escape(payload$feedback_type %||% "Feedback"),
        '</span>'
    )
}

feedback_message_panel <- function(label, value) {
    if (!nzchar(feedback_normalize_text(value))) return("")
    paste0(
        '<div style="margin-top:16px;padding:18px 18px 17px;background:#f7fafc;',
        'border:1px solid #dfe8ef;border-radius:10px;">',
        '<div style="margin-bottom:8px;font-size:11px;line-height:16px;font-weight:700;',
        'letter-spacing:.04em;text-transform:uppercase;color:#60758a;">',
        feedback_html_escape(label),
        '</div><div style="font-size:14px;line-height:22px;color:#263d55;">',
        feedback_html_text(value),
        '</div></div>'
    )
}

feedback_admin_email_html <- function(payload) {
    details <- feedback_detail_values(payload)
    reporter_email <- feedback_normalize_header_text(
        payload$reporter_email %||% payload$email %||% ""
    )
    reporter_name <- feedback_normalize_header_text(
        payload$full_name %||% payload$name %||% ""
    )
    context_lines <- Filter(nzchar, c(
        if (nzchar(payload$app_section %||% "")) {
            paste0("<strong>App section:</strong> ", feedback_html_escape(payload$app_section))
        } else "",
        if (nzchar(payload$submitted_at %||% "")) {
            paste0("<strong>Submitted:</strong> ", feedback_html_escape(payload$submitted_at))
        } else "",
        if (nzchar(payload$page_url %||% "")) {
            paste0("<strong>Page:</strong> ", feedback_html_escape(payload$page_url))
        } else "",
        if (nzchar(payload$submission_id %||% "")) {
            paste0("<strong>Reference:</strong> ", feedback_html_escape(payload$submission_id))
        } else ""
    ))

    content <- paste0(
        feedback_type_badge(payload),
        '<h1 style="margin:16px 0 6px;font-size:25px;line-height:32px;color:#263d55;">',
        'New feedback received</h1>',
        '<div style="font-size:17px;line-height:25px;font-weight:600;color:#314c70;">',
        feedback_html_escape(payload$title %||% "Untitled feedback"),
        '</div>',
        '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" ',
        'style="margin-top:22px;background:#edf8f6;border:1px solid #ccebe5;border-radius:10px;">',
        '<tr><td style="padding:16px 18px;">',
        '<div style="font-size:11px;line-height:16px;font-weight:700;letter-spacing:.04em;',
        'text-transform:uppercase;color:#087a65;">Reporter</div>',
        '<div style="margin-top:4px;font-size:15px;line-height:22px;font-weight:700;color:#263d55;">',
        feedback_html_escape(reporter_name),
        '</div><div style="font-size:13px;line-height:20px;">',
        '<a href="mailto:', feedback_html_escape(reporter_email),
        '" style="color:#087a65;text-decoration:none;">',
        feedback_html_escape(reporter_email),
        '</a></div></td></tr></table>',
        feedback_message_panel(details$primary_label, details$primary),
        feedback_message_panel(details$secondary_label, details$secondary),
        '<div style="margin-top:20px;padding:0 2px;font-size:12px;line-height:20px;color:#687d91;">',
        paste(context_lines, collapse = "<br>"),
        '</div>',
        '<div style="margin-top:24px;">',
        '<a href="mailto:', feedback_html_escape(reporter_email),
        '" style="display:inline-block;padding:11px 17px;border-radius:8px;background:#314c70;',
        'color:#ffffff;font-size:13px;line-height:18px;font-weight:700;text-decoration:none;">',
        'Reply to reporter</a></div>',
        '<div style="margin-top:16px;font-size:12px;line-height:18px;color:#7b8c9d;">',
        'Gmail replies are already directed to the reporter address above.</div>'
    )

    feedback_email_shell(
        content,
        preheader = paste("New CGeV feedback from", reporter_name)
    )
}

feedback_receipt_text <- function(payload, config = feedback_delivery_config()) {
    details <- feedback_detail_values(payload)
    paste(
        paste0("Hi ", feedback_first_name(payload$full_name %||% payload$name), ","),
        "",
        "We received your feedback in Comparative Gene Viewer.",
        paste0("Type: ", payload$feedback_type %||% "Feedback"),
        paste0("Title: ", payload$title %||% "Untitled feedback"),
        paste0("Reference: ", payload$submission_id %||% ""),
        "",
        details$primary_label,
        feedback_normalize_text(details$primary),
        if (nzchar(feedback_normalize_text(details$secondary))) "" else NULL,
        if (nzchar(feedback_normalize_text(details$secondary))) details$secondary_label else NULL,
        if (nzchar(feedback_normalize_text(details$secondary))) {
            feedback_normalize_text(details$secondary)
        } else NULL,
        "",
        "Your message is now in the CGeV inbox. We will use this email address only to follow up.",
        paste0("CGeV: ", config$public_url %||% CGV_FEEDBACK_DEFAULT_PUBLIC_URL),
        if (
            nzchar(config$backup_url %||% "") &&
            !identical(config$backup_url, config$public_url)
        ) {
            paste0("Backup access: ", config$backup_url)
        } else NULL,
        "",
        "You can reply to this confirmation if you want to add more context.",
        sep = "\n"
    )
}

feedback_receipt_email_html <- function(payload, config = feedback_delivery_config()) {
    details <- feedback_detail_values(payload)
    public_url <- feedback_html_escape(config$public_url %||% CGV_FEEDBACK_DEFAULT_PUBLIC_URL)
    backup_url <- feedback_html_escape(config$backup_url %||% CGV_FEEDBACK_DEFAULT_BACKUP_URL)
    backup_link <- if (nzchar(backup_url) && !identical(backup_url, public_url)) {
        paste0(
            '<div style="margin-top:12px;font-size:12px;line-height:19px;color:#7b8c9d;">',
            'If the official server is temporarily unavailable, use the ',
            '<a href="', backup_url, '" style="color:#314c70;text-decoration:underline;">',
            'CGeV backup site</a>.</div>'
        )
    } else {
        ""
    }
    content <- paste0(
        feedback_type_badge(payload),
        '<h1 style="margin:16px 0 8px;font-size:25px;line-height:32px;color:#263d55;">',
        'We received your feedback</h1>',
        '<div style="font-size:14px;line-height:22px;color:#536b81;">',
        'Hi ', feedback_html_escape(feedback_first_name(payload$full_name %||% payload$name)),
        ', thank you for helping us improve CGeV. This email is your copy of the submission.',
        '</div>',
        '<div style="margin-top:22px;padding:18px;background:#edf8f6;border:1px solid #ccebe5;',
        'border-radius:10px;">',
        '<div style="font-size:11px;line-height:16px;font-weight:700;letter-spacing:.04em;',
        'text-transform:uppercase;color:#087a65;">Your feedback</div>',
        '<div style="margin-top:5px;font-size:17px;line-height:24px;font-weight:700;color:#263d55;">',
        feedback_html_escape(payload$title %||% "Untitled feedback"),
        '</div><div style="margin-top:7px;font-size:12px;line-height:18px;color:#60758a;">',
        'Reference: ', feedback_html_escape(payload$submission_id %||% ""),
        '</div></div>',
        feedback_message_panel(details$primary_label, details$primary),
        feedback_message_panel(details$secondary_label, details$secondary),
        '<div style="margin-top:22px;padding-top:20px;border-top:1px solid #e3eaf0;">',
        '<div style="font-size:13px;line-height:20px;font-weight:700;color:#314c70;">',
        'What happens next</div>',
        '<div style="margin-top:10px;font-size:13px;line-height:21px;color:#536b81;">',
        '<strong style="color:#18a98e;">1.</strong> Your message is stored in the CGeV inbox.<br>',
        '<strong style="color:#18a98e;">2.</strong> Bug reports that block analysis are reviewed first.<br>',
        '<strong style="color:#18a98e;">3.</strong> If follow-up is needed, we will reply to this email address.',
        '</div></div>',
        '<div style="margin-top:24px;">',
        '<a href="', public_url,
        '" style="display:inline-block;padding:11px 17px;border-radius:8px;background:#18a98e;',
        'color:#ffffff;font-size:13px;line-height:18px;font-weight:700;text-decoration:none;">',
        'Visit official CGeV</a></div>',
        backup_link,
        '<div style="margin-top:18px;font-size:12px;line-height:19px;color:#7b8c9d;">',
        'You can reply to this confirmation if you want to add more context. ',
        'Your email is used only for follow-up on this submission.</div>'
    )

    feedback_email_shell(
        content,
        preheader = "CGeV received your feedback. This is your confirmation copy."
    )
}

feedback_logo_attachment <- function(config = feedback_delivery_config()) {
    logo_path <- as.character(config$logo_path %||% "")
    if (
        !nzchar(logo_path) ||
        !file.exists(logo_path) ||
        !requireNamespace("base64enc", quietly = TRUE)
    ) {
        return(NULL)
    }
    list(
        content = base64enc::base64encode(logo_path, linewidth = 0L),
        filename = "cgv-email-logo.png",
        content_id = "cgv-logo"
    )
}

feedback_email_body <- function(
    payload,
    config = feedback_delivery_config(),
    kind = c("notification", "receipt")
) {
    kind <- match.arg(kind)
    reporter_email <- feedback_normalize_header_text(
        payload$reporter_email %||% payload$email %||% ""
    )
    is_receipt <- identical(kind, "receipt")
    attachment <- feedback_logo_attachment(config)

    body <- list(
        from = feedback_normalize_header_text(config$from_email),
        to = list(if (is_receipt) reporter_email else feedback_normalize_header_text(config$to_email)),
        reply_to = list(if (is_receipt) feedback_normalize_header_text(config$to_email) else reporter_email),
        subject = if (is_receipt) {
            "We received your CGeV feedback"
        } else {
            feedback_normalize_header_text(payload$subject %||% "")
        },
        text = if (is_receipt) {
            feedback_receipt_text(payload, config)
        } else {
            feedback_normalize_text(payload$message %||% "")
        },
        html = if (is_receipt) {
            feedback_receipt_email_html(payload, config)
        } else {
            feedback_admin_email_html(payload)
        }
    )
    if (!is.null(attachment)) body$attachments <- list(attachment)
    body
}

feedback_idempotency_key <- function(payload, kind = "notification") {
    raw_id <- feedback_normalize_header_text(payload$submission_id %||% "")
    safe_id <- gsub("[^A-Za-z0-9_-]+", "-", raw_id, perl = TRUE)
    safe_id <- gsub("(^-+|-+$)", "", safe_id, perl = TRUE)
    if (!nzchar(safe_id)) {
        safe_id <- paste0(format(Sys.time(), "%Y%m%d%H%M%S"), "-", Sys.getpid())
    }
    safe_kind <- gsub("[^A-Za-z0-9_-]+", "-", kind, perl = TRUE)
    substr(paste0("cgv-feedback-", safe_id, "-", safe_kind), 1L, 200L)
}

feedback_resend_request <- function(
    payload,
    config = feedback_delivery_config(),
    kind = "notification"
) {
    body <- feedback_email_body(payload, config, kind = kind)

    httr2::request("https://api.resend.com/emails") |>
        httr2::req_headers(
            Authorization = paste("Bearer", config$api_key),
            `Content-Type` = "application/json",
            `Idempotency-Key` = feedback_idempotency_key(payload, kind = kind)
        ) |>
        httr2::req_body_json(body) |>
        httr2::req_timeout(10) |>
        httr2::req_error(is_error = function(resp) FALSE)
}

feedback_resend_transport <- function(request) {
    response <- httr2::req_perform(request)
    list(
        status = httr2::resp_status(response),
        body = tryCatch(httr2::resp_body_string(response), error = function(e) "")
    )
}

feedback_send_email <- function(
    payload,
    config = feedback_delivery_config(),
    transport = feedback_resend_transport,
    kind = c("notification", "receipt")
) {
    kind <- match.arg(kind)
    if (!nzchar(config$api_key %||% "")) {
        return(list(
            ok = FALSE,
            state = "not_configured",
            status = NA_integer_,
            provider_id = "",
            error = "FEEDBACK_RESEND_API_KEY is not configured."
        ))
    }

    body <- feedback_email_body(payload, config, kind = kind)
    to_email <- feedback_normalize_header_text(unlist(body$to)[1L] %||% "")
    from_address <- feedback_extract_address(config$from_email %||% "")
    reply_email <- feedback_normalize_header_text(unlist(body$reply_to)[1L] %||% "")

    if (
        !feedback_is_valid_email(to_email) ||
        !feedback_is_valid_email(from_address) ||
        !feedback_is_valid_email(reply_email)
    ) {
        return(list(
            ok = FALSE,
            state = "invalid_configuration",
            status = NA_integer_,
            provider_id = "",
            error = "Feedback sender, recipient, or reply email is invalid."
        ))
    }

    result <- tryCatch(
        transport(feedback_resend_request(payload, config, kind = kind)),
        error = function(e) {
            list(
                status = NA_integer_,
                body = "",
                transport_error = conditionMessage(e)
            )
        }
    )

    status <- suppressWarnings(as.integer(result$status %||% NA_integer_))
    if (is.finite(status) && status >= 200L && status < 300L) {
        parsed <- tryCatch(
            jsonlite::fromJSON(result$body %||% "", simplifyVector = TRUE),
            error = function(e) list()
        )
        return(list(
            ok = TRUE,
            state = "accepted",
            status = status,
            provider_id = as.character(parsed$id %||% ""),
            error = ""
        ))
    }

    error_text <- as.character(
        result$transport_error %||%
            if (nzchar(result$body %||% "")) result$body else "Resend rejected the request."
    )
    list(
        ok = FALSE,
        state = "failed",
        status = status,
        provider_id = "",
        error = substr(error_text, 1L, 500L)
    )
}

feedback_send_notification <- function(
    payload,
    config = feedback_delivery_config(),
    transport = feedback_resend_transport
) {
    feedback_send_email(
        payload,
        config = config,
        transport = transport,
        kind = "notification"
    )
}

feedback_send_receipt <- function(
    payload,
    config = feedback_delivery_config(),
    transport = feedback_resend_transport
) {
    if (!isTRUE(config$send_receipt)) {
        return(list(
            ok = TRUE,
            state = "disabled",
            status = NA_integer_,
            provider_id = "",
            error = ""
        ))
    }
    feedback_send_email(
        payload,
        config = config,
        transport = transport,
        kind = "receipt"
    )
}
