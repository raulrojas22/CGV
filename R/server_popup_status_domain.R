init_popup_status_domain <- function(session, as_text_one_fn = NULL) {
    as_text_one_safe <- function(x) {
        if (is.function(as_text_one_fn)) {
            return(as_text_one_fn(x))
        }
        vals <- as.character(x %||% "")
        if (length(vals) == 0) {
            return("")
        }
        as.character(vals[[1]] %||% "")
    }

    format_popup_label <- function(x, fallback = "N/A") {
        val <- trimws(as.character(x %||% ""))
        if (length(val) == 0 || !nzchar(val)) {
            return(as.character(fallback))
        }
        val
    }

    format_org_name <- function(x, fallback = "N/A") {
        val <- trimws(as.character(x %||% ""))
        if (length(val) == 0 || !nzchar(val) || val == fallback || val == "Organism" || val == "selected organism") {
            return(as.character(fallback))
        }
        sprintf("<em>%s</em>", htmltools::htmlEscape(val))
    }

    append_status <- function(status_rv, msg) {
        msg_txt <- trimws(as.character(msg %||% ""))
        if (!nzchar(msg_txt)) {
            return(invisible(NULL))
        }
        msg_out <- as_text_one_safe(msg_txt)
        current <- status_rv()
        if (is.null(current) || !nzchar(current)) {
            status_rv(msg_out)
        } else {
            status_rv(paste(current, msg_out, sep = "\n"))
        }
        invisible(NULL)
    }

    classify_popup_tone <- function(msg) {
        txt <- tolower(trimws(as.character(msg %||% "")))
        if (!nzchar(txt)) {
            return("info")
        }
        if (grepl("error|failed|missing|not found|could not|invalid", txt, perl = TRUE)) {
            return("error")
        }
        if (grepl("warning|required|select|skipped|no\\s+match|already\\s+plotted", txt, perl = TRUE)) {
            return("warning")
        }
        if (grepl("ready|generated|loaded|removed|warmed|done|success", txt, perl = TRUE)) {
            return("success")
        }
        "info"
    }

    emit_popup_status <- function(context, text, tone = NULL, clear = TRUE) {
        txt <- trimws(as.character(text %||% ""))
        if (!nzchar(txt)) {
            return(invisible(NULL))
        }
        ctx_txt <- as.character(context %||% "Status")
        ctx_out <- as_text_one_safe(ctx_txt)
        txt_out <- as_text_one_safe(txt)
        session$sendCustomMessage(
            "app_status_popup",
            list(
                context = ctx_out,
                text = txt_out,
                tone = as.character(tone %||% classify_popup_tone(txt)),
                clear = isTRUE(clear)
            )
        )
        invisible(NULL)
    }

    set_popup_loading <- function(active = TRUE,
                                  context = "Status",
                                  text = NULL,
                                  headline = NULL,
                                  auto_open = FALSE) {
        ctx_out <- as_text_one_safe(as.character(context %||% "Status"))
        text_out <- as_text_one_safe(as.character(text %||% if (isTRUE(active)) "Working..." else ""))
        headline_out <- as_text_one_safe(as.character(headline %||% ""))
        session$sendCustomMessage(
            "app_status_popup_loading",
            list(
                active = isTRUE(active),
                context = ctx_out,
                text = text_out,
                headline = headline_out,
                auto_open = isTRUE(auto_open)
            )
        )
        invisible(NULL)
    }

    close_popup_status <- function(clear = FALSE) {
        session$sendCustomMessage(
            "app_status_popup_close",
            list(clear = isTRUE(clear))
        )
        invisible(NULL)
    }

    list(
        format_popup_label = format_popup_label,
        format_org_name = format_org_name,
        append_status = append_status,
        classify_popup_tone = classify_popup_tone,
        emit_popup_status = emit_popup_status,
        set_popup_loading = set_popup_loading,
        close_popup_status = close_popup_status
    )
}
