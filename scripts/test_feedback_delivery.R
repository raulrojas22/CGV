#!/usr/bin/env Rscript

source(file.path("R", "utils.R"))
source(file.path("R", "feedback_delivery.R"))

assert_true <- function(value, label) {
    if (!isTRUE(value)) {
        stop("FAIL: ", label, call. = FALSE)
    }
    message("PASS: ", label)
}

mock_getenv <- function(name, unset = "") {
    values <- c(
        FEEDBACK_RESEND_API_KEY = "test-key",
        FEEDBACK_TO_EMAIL = "",
        FEEDBACK_FROM_EMAIL = ""
    )
    if (name %in% names(values)) unname(values[[name]]) else unset
}

config <- feedback_delivery_config(getenv = mock_getenv)
assert_true(
    identical(config$send_receipt, TRUE),
    "reporter confirmation defaults on for the verified CGeV sending domain"
)
config$public_url <- "https://cgev.mobilomics.org"
config$backup_url <- "https://cgvapp.com"
config$logo_path <- ""
config$send_receipt <- TRUE
assert_true(
    identical(config$to_email, "cgvviewer@gmail.com"),
    "blank recipient falls back to the CGeV Gmail inbox"
)
assert_true(
    identical(config$from_email, "CGeV Feedback <feedback@cgvapp.com>"),
    "blank sender falls back to the verified CGeV sending domain"
)

payload <- list(
    submission_id = "feedback_test_123",
    reporter_email = "scientist@example.org",
    subject = "[CGeV Bug] Example report",
    message = "Example feedback body"
)
body <- feedback_email_body(payload, config)
assert_true(
    identical(unlist(body$to), "cgvviewer@gmail.com"),
    "email body targets the CGeV Gmail inbox"
)
assert_true(
    identical(unlist(body$reply_to), "scientist@example.org"),
    "reporter address is set as Reply-To"
)
assert_true(
    identical(
        feedback_idempotency_key(payload),
        "cgv-feedback-feedback_test_123-notification"
    ),
    "submission ID becomes a stable idempotency key"
)
assert_true(
    grepl("<html>", body$html, fixed = TRUE),
    "CGeV inbox notification includes an HTML version"
)
assert_true(
    grepl("scientist@example.org", body$html, fixed = TRUE),
    "CGeV inbox HTML identifies the reporter email"
)

receipt_body <- feedback_email_body(payload, config, kind = "receipt")
assert_true(
    identical(unlist(receipt_body$to), "scientist@example.org"),
    "confirmation copy is addressed to the reporter"
)
assert_true(
    identical(unlist(receipt_body$reply_to), "cgvviewer@gmail.com"),
    "confirmation replies return to the CGeV inbox"
)
assert_true(
    grepl("We received your feedback", receipt_body$html, fixed = TRUE),
    "confirmation copy includes the branded receipt heading"
)
assert_true(
    grepl("https://cgev.mobilomics.org", receipt_body$html, fixed = TRUE) &&
        grepl("https://cgvapp.com", receipt_body$html, fixed = TRUE),
    "confirmation identifies the official CGeV site and its backup"
)
assert_true(
    identical(
        feedback_idempotency_key(payload, "receipt"),
        "cgv-feedback-feedback_test_123-receipt"
    ),
    "confirmation copy has an independent idempotency key"
)

escaped_payload <- payload
escaped_payload$title <- "<script>alert('x')</script>"
escaped_html <- feedback_admin_email_html(escaped_payload)
assert_true(
    !grepl("<script>", escaped_html, fixed = TRUE) &&
        grepl("&lt;script&gt;", escaped_html, fixed = TRUE),
    "user content is HTML-escaped"
)

accepted <- feedback_send_notification(
    payload,
    config = config,
    transport = function(request) list(status = 200L, body = '{"id":"email_test_123"}')
)
assert_true(isTRUE(accepted$ok), "2xx Resend response is accepted")
assert_true(
    identical(accepted$provider_id, "email_test_123"),
    "Resend provider ID is preserved"
)

rejected <- feedback_send_notification(
    payload,
    config = config,
    transport = function(request) list(status = 422L, body = '{"message":"invalid"}')
)
assert_true(!isTRUE(rejected$ok), "non-2xx Resend response is rejected")
assert_true(identical(rejected$state, "failed"), "failure state is explicit")

unconfigured <- feedback_send_notification(
    payload,
    config = within(config, api_key <- "")
)
assert_true(
    identical(unconfigured$state, "not_configured"),
    "missing API key is reported instead of silently skipped"
)

receipt_accepted <- feedback_send_receipt(
    payload,
    config = config,
    transport = function(request) list(status = 200L, body = '{"id":"receipt_test_123"}')
)
assert_true(
    isTRUE(receipt_accepted$ok) &&
        identical(receipt_accepted$provider_id, "receipt_test_123"),
    "reporter confirmation uses the same checked transport"
)

assert_true(
    feedback_is_valid_email("name+tag@example.org"),
    "valid reply email is accepted"
)
assert_true(
    !feedback_is_valid_email("bad address@example.org"),
    "invalid reply email is rejected"
)

logo_config <- config
logo_config$logo_path <- file.path("www", "cgv-email-logo.png")
logo_attachment <- feedback_logo_attachment(logo_config)
assert_true(
    identical(logo_attachment$content_id, "cgv-logo") &&
        is.null(logo_attachment$contentId),
    "raw Resend JSON uses content_id so Gmail renders the logo inline"
)

message("All feedback delivery tests passed.")
