init_server_state_helpers_domain <- function(
    autocompleteBuildEpochs_rv,
    searchRunState_rv
) {
    parse_positive_int_env <- function(name, default_value) {
        raw <- trimws(as.character(Sys.getenv(name, as.character(default_value)) %||% ""))
        val <- suppressWarnings(as.integer(raw))
        if (!is.finite(val) || is.na(val) || val < 1L) {
            as.integer(default_value)
        } else {
            as.integer(val)
        }
    }

    get_autocomplete_epoch <- function(input_id) {
        key <- as.character(input_id %||% "")
        ep <- autocompleteBuildEpochs_rv()
        if (!is.list(ep)) ep <- list()
        val <- suppressWarnings(as.integer(ep[[key]] %||% 0L))
        if (!is.finite(val) || is.na(val)) {
            val <- 0L
        }
        as.integer(val)
    }

    bump_autocomplete_epoch <- function(input_id) {
        key <- as.character(input_id %||% "")
        if (!nzchar(key)) {
            return(invisible(0L))
        }
        ep <- autocompleteBuildEpochs_rv()
        if (!is.list(ep)) ep <- list()
        current <- suppressWarnings(as.integer(ep[[key]] %||% 0L))
        if (!is.finite(current) || is.na(current)) {
            current <- 0L
        }
        next_val <- as.integer(current + 1L)
        ep[[key]] <- next_val
        autocompleteBuildEpochs_rv(ep)
        next_val
    }

    cancel_autocomplete_background <- function(input_ids = c("filter1", "gene_name")) {
        ids <- unique(as.character(input_ids %||% character(0)))
        ids <- ids[nzchar(ids)]
        invisible(lapply(ids, bump_autocomplete_epoch))
    }

    compose_autocomplete_still_valid <- function(input_id, epoch_token = NULL, extra_check = NULL) {
        key <- as.character(input_id %||% "")
        epoch_target <- suppressWarnings(as.integer(epoch_token %||% get_autocomplete_epoch(key)))
        if (!is.finite(epoch_target) || is.na(epoch_target)) epoch_target <- 0L
        function() {
            same_epoch <- identical(get_autocomplete_epoch(key), as.integer(epoch_target))
            extra_ok <- TRUE
            if (is.function(extra_check)) {
                extra_ok <- tryCatch(isTRUE(extra_check()), error = function(e) FALSE)
            }
            isTRUE(same_epoch && extra_ok)
        }
    }

    get_search_run_mode_state <- function(mode) {
        mode_key <- tolower(trimws(as.character(mode %||% "")))
        if (!mode_key %in% c("homologous", "orthologous")) {
            mode_key <- "homologous"
        }
        st <- searchRunState_rv()
        if (!is.list(st)) st <- list()
        mode_st <- st[[mode_key]]
        if (!is.list(mode_st)) {
            mode_st <- list(active = FALSE, last_fingerprint = "", last_completed = as.numeric(0))
        }
        mode_st$active <- isTRUE(mode_st$active)
        mode_st$last_fingerprint <- as.character(mode_st$last_fingerprint %||% "")
        mode_st$last_completed <- suppressWarnings(as.numeric(mode_st$last_completed %||% 0))
        if (!is.finite(mode_st$last_completed)) mode_st$last_completed <- 0
        list(mode_key = mode_key, state = st, mode_state = mode_st)
    }

    begin_search_run <- function(mode, fingerprint = "", duplicate_window_sec = 1.2) {
        state_info <- get_search_run_mode_state(mode)
        mode_key <- state_info$mode_key
        st <- state_info$state
        mode_st <- state_info$mode_state
        fp <- tolower(trimws(as.character(fingerprint %||% "")))
        now_num <- as.numeric(Sys.time())
        if (isTRUE(mode_st$active)) {
            return(list(ok = FALSE, reason = "active", mode = mode_key))
        }
        if (nzchar(fp) && identical(fp, mode_st$last_fingerprint)) {
            dt <- now_num - as.numeric(mode_st$last_completed %||% 0)
            if (is.finite(dt) && dt >= 0 && dt < as.numeric(duplicate_window_sec %||% 1.2)) {
                return(list(ok = FALSE, reason = "duplicate", mode = mode_key))
            }
        }
        mode_st$active <- TRUE
        mode_st$last_fingerprint <- fp
        st[[mode_key]] <- mode_st
        searchRunState_rv(st)
        list(ok = TRUE, reason = "started", mode = mode_key)
    }

    finish_search_run <- function(mode) {
        state_info <- get_search_run_mode_state(mode)
        mode_key <- state_info$mode_key
        st <- state_info$state
        mode_st <- state_info$mode_state
        mode_st$active <- FALSE
        mode_st$last_completed <- as.numeric(Sys.time())
        st[[mode_key]] <- mode_st
        searchRunState_rv(st)
        invisible(TRUE)
    }

    list(
        parse_positive_int_env = parse_positive_int_env,
        get_autocomplete_epoch = get_autocomplete_epoch,
        bump_autocomplete_epoch = bump_autocomplete_epoch,
        cancel_autocomplete_background = cancel_autocomplete_background,
        compose_autocomplete_still_valid = compose_autocomplete_still_valid,
        get_search_run_mode_state = get_search_run_mode_state,
        begin_search_run = begin_search_run,
        finish_search_run = finish_search_run
    )
}
