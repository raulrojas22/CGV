init_autocomplete_domain <- function(
    geneAutocompleteCache_rv,
    quickGeneAutocompleteCache_rv,
    globalGeneSuggestionSources_rv,
    session,
    warm_annotation_cache_fn = NULL,
    normalize_annotation_key_fn = NULL
) {
    quick_scan_tokens <- new.env(parent = emptyenv(), hash = TRUE)

    normalize_annotation_key_safe <- function(annotation_path) {
        if (is.function(normalize_annotation_key_fn)) {
            return(normalize_annotation_key_fn(annotation_path))
        }
        p <- as.character(annotation_path %||% "")
        if (!nzchar(p)) {
            return("")
        }
        normalizePath(p, winslash = "/", mustWork = FALSE)
    }

    gene_autocomplete_cache_key <- function(annotation_path) {
        p <- as.character(annotation_path %||% "")
        if (!nzchar(p) || !file.exists(p)) {
            return("")
        }
        tryCatch(gff_cache_key(p), error = function(e) normalize_annotation_key_safe(p))
    }

    trim_autocomplete_cache_map <- function(cache_map, max_entries = 24L) {
        if (!is.list(cache_map)) {
            return(list())
        }
        max_entries <- suppressWarnings(as.integer(max_entries))
        if (!is.finite(max_entries) || is.na(max_entries) || max_entries < 1L) {
            max_entries <- 24L
        }
        if (length(cache_map) <= max_entries) {
            return(cache_map)
        }
        keep <- tail(names(cache_map), max_entries)
        keep <- keep[!is.na(keep) & nzchar(keep)]
        if (length(keep) == 0L) {
            return(list())
        }
        cache_map[keep]
    }

    extract_autocomplete_name_lists <- function(attrs) {
        attrs <- as.character(attrs %||% "")
        gene_name <- stringr::str_match(
            attrs,
            '(?:^|;|\\t)\\s*gene_name\\s*[= ]\\s*"?([^;"\\t]+)'
        )[, 2]
        name_fallback <- stringr::str_match(attrs, "(?:^|;)\\s*Name=([^;]+)")[, 2]
        gene_name <- sanitize_gene_display_name_batch(gene_name)
        name_fallback <- sanitize_gene_display_name_batch(name_fallback)

        has_primary <- !is.na(gene_name) & nzchar(trimws(gene_name))
        name_fallback[has_primary] <- NA_character_

        primary <- gene_name[has_primary]
        fallback <- name_fallback[!is.na(name_fallback) & nzchar(trimws(name_fallback))]
        list(
            primary = as.character(primary %||% character(0)),
            fallback = as.character(fallback %||% character(0))
        )
    }

    sanitize_autocomplete_choices <- function(choices, max_total = 20000L) {
        vals <- as.character(choices %||% character(0))
        vals <- gsub("[\u00A0\u2007\u202F]", " ", vals, perl = TRUE)
        vals <- trimws(vals)
        vals <- vals[!is.na(vals) & nzchar(vals)]
        vals <- vals[nchar(vals) <= 80]
        vals <- unique(vals)
        max_cap <- suppressWarnings(as.integer(max_total))
        if (!is.finite(max_cap) || max_cap <= 0L) {
            max_cap <- 20000L
        }
        if (length(vals) > max_cap) {
            vals <- vals[seq_len(max_cap)]
        }
        vals
    }

    next_quick_scan_token <- function(input_id) {
        key <- as.character(input_id %||% "")
        if (!nzchar(key)) {
            return(0L)
        }
        current <- if (exists(key, envir = quick_scan_tokens, inherits = FALSE)) {
            suppressWarnings(as.integer(get(key, envir = quick_scan_tokens, inherits = FALSE)))
        } else {
            0L
        }
        if (!is.finite(current) || is.na(current) || current < 0L) {
            current <- 0L
        }
        next_val <- current + 1L
        assign(key, next_val, envir = quick_scan_tokens)
        next_val
    }

    quick_scan_token_is_current <- function(input_id, token) {
        key <- as.character(input_id %||% "")
        if (!nzchar(key)) {
            return(FALSE)
        }
        current <- if (exists(key, envir = quick_scan_tokens, inherits = FALSE)) {
            suppressWarnings(as.integer(get(key, envir = quick_scan_tokens, inherits = FALSE)))
        } else {
            NA_integer_
        }
        token_int <- suppressWarnings(as.integer(token %||% NA_integer_))
        is.finite(current) && is.finite(token_int) && identical(current, token_int)
    }

    get_gene_suggestions_for_annotation <- function(annotation_path, max_suggestions = 12000L) {
        p <- as.character(annotation_path %||% "")
        if (!nzchar(p) || !file.exists(p)) {
            return(character(0))
        }
        max_suggestions <- suppressWarnings(as.integer(max_suggestions))
        if (!is.finite(max_suggestions) || max_suggestions <= 0L) {
            max_suggestions <- 12000L
        }
        ckey <- gene_autocomplete_cache_key(p)
        if (!nzchar(ckey)) {
            return(character(0))
        }

        cache_map <- geneAutocompleteCache_rv()
        if (!is.null(cache_map[[ckey]])) {
            return(cache_map[[ckey]])
        }

        idx <- tryCatch(build_gff_gene_light_index(p), error = function(e) NULL)
        if (is.null(idx) || !is.list(idx) || is.null(idx$genes_df) || nrow(idx$genes_df) == 0) {
            cache_map[[ckey]] <- character(0)
            geneAutocompleteCache_rv(trim_autocomplete_cache_map(cache_map))
            return(character(0))
        }

        attrs <- as.character(idx$genes_df$attributes %||% rep("", nrow(idx$genes_df)))
        names_lists <- extract_autocomplete_name_lists(attrs)
        suggestions <- c(names_lists$primary, names_lists$fallback)
        suggestions <- trimws(utils::URLdecode(as.character(suggestions)))
        suggestions <- suggestions[!is.na(suggestions) & nzchar(suggestions)]
        suggestions <- suggestions[nchar(suggestions) <= 80]
        suggestions <- unique(suggestions)
        if (length(suggestions) > max_suggestions) suggestions <- suggestions[seq_len(max_suggestions)]

        cache_map[[ckey]] <- suggestions
        geneAutocompleteCache_rv(trim_autocomplete_cache_map(cache_map))
        suggestions
    }

    get_gene_suggestions_from_disk_index <- function(annotation_path, max_suggestions = 12000L) {
        p <- as.character(annotation_path %||% "")
        if (!nzchar(p) || !file.exists(p)) {
            return(NULL)
        }
        max_suggestions <- suppressWarnings(as.integer(max_suggestions))
        if (!is.finite(max_suggestions) || max_suggestions <= 0L) {
            max_suggestions <- 12000L
        }
        ckey <- gene_autocomplete_cache_key(p)
        if (!nzchar(ckey)) {
            return(NULL)
        }

        idx <- tryCatch(load_gff_index_from_disk(p, cache_kind = "gene_light", base_dir = "."), error = function(e) NULL)
        if (is.null(idx) || !is.list(idx) || is.null(idx$genes_df) || !is.data.frame(idx$genes_df)) {
            return(NULL)
        }

        attrs <- as.character(idx$genes_df$attributes %||% rep("", nrow(idx$genes_df)))
        names_lists <- extract_autocomplete_name_lists(attrs)
        suggestions <- c(names_lists$primary, names_lists$fallback)
        suggestions <- trimws(utils::URLdecode(as.character(suggestions)))
        suggestions <- suggestions[!is.na(suggestions) & nzchar(suggestions)]
        suggestions <- suggestions[nchar(suggestions) <= 80]
        suggestions <- unique(suggestions)
        if (length(suggestions) > max_suggestions) {
            suggestions <- suggestions[seq_len(max_suggestions)]
        }

        cache_map <- geneAutocompleteCache_rv()
        cache_map[[ckey]] <- suggestions
        geneAutocompleteCache_rv(trim_autocomplete_cache_map(cache_map))
        suggestions
    }

    get_cached_quick_gene_suggestions <- function(annotation_path, max_suggestions = 1200L, max_lines = 180000L, max_seconds = 0.45) {
        ckey <- gene_autocomplete_cache_key(annotation_path)
        if (!nzchar(ckey)) {
            return(NULL)
        }
        cache_map <- quickGeneAutocompleteCache_rv()
        entry <- cache_map[[ckey]]
        if (!is.list(entry) || is.null(entry$suggestions)) {
            return(NULL)
        }
        entry_cap <- suppressWarnings(as.integer(entry$max_suggestions %||% 0L))
        entry_lines <- suppressWarnings(as.integer(entry$max_lines %||% 0L))
        entry_seconds <- suppressWarnings(as.numeric(entry$max_seconds %||% 0))
        if (!is.finite(entry_cap) || !is.finite(entry_lines) || !is.finite(entry_seconds)) {
            return(NULL)
        }
        if (entry_cap < as.integer(max_suggestions) || entry_lines < as.integer(max_lines) || entry_seconds + 1e-9 < as.numeric(max_seconds)) {
            return(NULL)
        }
        suggestions <- as.character(entry$suggestions %||% character(0))
        if (length(suggestions) > max_suggestions) {
            suggestions <- suggestions[seq_len(max_suggestions)]
        }
        suggestions
    }

    store_cached_quick_gene_suggestions <- function(annotation_path, suggestions, max_suggestions = 1200L, max_lines = 180000L, max_seconds = 0.45) {
        ckey <- gene_autocomplete_cache_key(annotation_path)
        if (!nzchar(ckey)) {
            return(as.character(suggestions %||% character(0)))
        }
        clean_suggestions <- sanitize_autocomplete_choices(suggestions, max_total = max_suggestions)
        cache_map <- quickGeneAutocompleteCache_rv()
        prev <- cache_map[[ckey]]
        prev_score <- if (is.list(prev)) {
            c(
                suppressWarnings(as.integer(prev$max_suggestions %||% 0L)),
                suppressWarnings(as.integer(prev$max_lines %||% 0L)),
                suppressWarnings(as.numeric(prev$max_seconds %||% 0)),
                length(as.character(prev$suggestions %||% character(0)))
            )
        } else {
            c(0L, 0L, 0, 0L)
        }
        next_score <- c(
            suppressWarnings(as.integer(max_suggestions %||% 0L)),
            suppressWarnings(as.integer(max_lines %||% 0L)),
            suppressWarnings(as.numeric(max_seconds %||% 0)),
            length(clean_suggestions)
        )
        if (!is.list(prev) || any(next_score > prev_score)) {
            cache_map[[ckey]] <- list(
                suggestions = clean_suggestions,
                max_suggestions = as.integer(max_suggestions %||% length(clean_suggestions)),
                max_lines = as.integer(max_lines %||% 0L),
                max_seconds = as.numeric(max_seconds %||% 0),
                updated_at = as.numeric(Sys.time())
            )
            quickGeneAutocompleteCache_rv(trim_autocomplete_cache_map(cache_map, max_entries = 48L))
        }
        clean_suggestions
    }

    init_quick_gene_scan_state <- function(annotation_path, max_suggestions = 1200L, max_lines = 180000L, max_seconds = 0.45, chunk_lines = 1000L) {
        p <- as.character(annotation_path %||% "")
        if (!nzchar(p) || !file.exists(p)) {
            return(NULL)
        }
        max_suggestions <- suppressWarnings(as.integer(max_suggestions))
        if (!is.finite(max_suggestions) || max_suggestions <= 0L) {
            max_suggestions <- 1200L
        }
        max_lines <- suppressWarnings(as.integer(max_lines))
        if (!is.finite(max_lines) || max_lines <= 0L) {
            max_lines <- 180000L
        }
        max_seconds <- suppressWarnings(as.numeric(max_seconds))
        if (!is.finite(max_seconds) || max_seconds <= 0) {
            max_seconds <- 0.45
        }
        chunk_lines <- suppressWarnings(as.integer(chunk_lines))
        if (!is.finite(chunk_lines) || chunk_lines <= 0L) {
            chunk_lines <- 1000L
        }

        con <- if (grepl("\\.(gz|bgz)$", p, ignore.case = TRUE)) {
            gzfile(p, open = "rt")
        } else {
            file(p, open = "rt")
        }
        state <- new.env(parent = emptyenv())
        state$annotation_path <- p
        state$con <- con
        state$max_suggestions <- max_suggestions
        state$max_lines <- max_lines
        state$max_seconds <- max_seconds
        state$chunk_lines <- chunk_lines
        state$started_at <- Sys.time()
        state$lines_seen <- 0L
        state$out_primary <- character(0)
        state$out_fallback <- character(0)
        state$done <- FALSE
        state
    }

    close_quick_gene_scan_state <- function(state) {
        if (is.null(state) || !is.environment(state)) {
            return(invisible(FALSE))
        }
        if (!is.null(state$con)) {
            try(close(state$con), silent = TRUE)
            state$con <- NULL
        }
        state$done <- TRUE
        invisible(TRUE)
    }

    quick_gene_scan_state_suggestions <- function(state) {
        if (is.null(state) || !is.environment(state)) {
            return(character(0))
        }
        out <- unique(c(
            as.character(state$out_primary %||% character(0)),
            as.character(state$out_fallback %||% character(0))
        ))
        max_suggestions <- suppressWarnings(as.integer(state$max_suggestions %||% length(out)))
        if (is.finite(max_suggestions) && max_suggestions > 0L && length(out) > max_suggestions) {
            out <- out[seq_len(max_suggestions)]
        }
        out
    }

    step_quick_gene_scan_state <- function(state) {
        if (is.null(state) || !is.environment(state) || isTRUE(state$done) || is.null(state$con)) {
            return(list(done = TRUE, suggestions = quick_gene_scan_state_suggestions(state)))
        }
        chunk <- readLines(state$con, n = as.integer(state$chunk_lines %||% 1000L), warn = FALSE)
        if (length(chunk) == 0) {
            state$done <- TRUE
            return(list(done = TRUE, suggestions = quick_gene_scan_state_suggestions(state)))
        }
        state$lines_seen <- as.integer(state$lines_seen %||% 0L) + length(chunk)
        chunk <- chunk[nzchar(chunk) & !startsWith(chunk, "#")]
        if (length(chunk) > 0) {
            gene_lines <- chunk[grepl("^[^\t]+\t[^\t]*\tgene\t", chunk, perl = TRUE)]
            if (length(gene_lines) > 0) {
                attrs <- sub("^(?:[^\t]*\t){8}", "", gene_lines, perl = TRUE)
                names_lists <- extract_autocomplete_name_lists(attrs)
                if (length(names_lists$primary) > 0) {
                    state$out_primary <- unique(c(state$out_primary, names_lists$primary))
                }
                if (length(names_lists$fallback) > 0) {
                    state$out_fallback <- unique(c(state$out_fallback, names_lists$fallback))
                }
                out_merged <- unique(c(state$out_primary, state$out_fallback))
                max_suggestions <- as.integer(state$max_suggestions %||% length(out_merged))
                if (is.finite(max_suggestions) && max_suggestions > 0L && length(out_merged) >= max_suggestions) {
                    out_merged <- out_merged[seq_len(max_suggestions)]
                    state$out_primary <- out_merged
                    state$out_fallback <- character(0)
                    state$done <- TRUE
                }
            }
        }
        elapsed <- as.numeric(difftime(Sys.time(), state$started_at, units = "secs"))
        if (as.integer(state$lines_seen %||% 0L) >= as.integer(state$max_lines %||% 0L) ||
            elapsed >= as.numeric(state$max_seconds %||% 0)) {
            state$done <- TRUE
        }
        list(done = isTRUE(state$done), suggestions = quick_gene_scan_state_suggestions(state))
    }

    extract_quick_gene_suggestions <- function(annotation_path, max_suggestions = 1200L, max_lines = 180000L, max_seconds = 0.45, chunk_lines = 1000L) {
        state <- init_quick_gene_scan_state(
            annotation_path = annotation_path,
            max_suggestions = max_suggestions,
            max_lines = max_lines,
            max_seconds = max_seconds,
            chunk_lines = chunk_lines
        )
        if (is.null(state)) {
            return(character(0))
        }
        on.exit(close_quick_gene_scan_state(state), add = TRUE)
        repeat {
            step <- step_quick_gene_scan_state(state)
            if (isTRUE(step$done)) {
                break
            }
        }
        quick_gene_scan_state_suggestions(state)
    }

    schedule_quick_gene_autocomplete_scan <- function(input_id, quick_specs, request_token, max_total = 20000L, delay_sec = 0.02) {
        if (!requireNamespace("later", quietly = TRUE)) {
            return(invisible(FALSE))
        }
        specs <- quick_specs
        if (!is.list(specs) || length(specs) == 0L) {
            return(invisible(FALSE))
        }
        states <- lapply(specs, function(spec) {
            init_quick_gene_scan_state(
                annotation_path = spec$path,
                max_suggestions = spec$max_suggestions,
                max_lines = spec$max_lines,
                max_seconds = spec$max_seconds,
                chunk_lines = spec$chunk_lines %||% 1000L
            )
        })
        states <- Filter(Negate(is.null), states)
        if (length(states) == 0L) {
            return(invisible(FALSE))
        }
        max_total <- suppressWarnings(as.integer(max_total))
        if (!is.finite(max_total) || max_total <= 0L) {
            max_total <- 20000L
        }
        delay_val <- suppressWarnings(as.numeric(delay_sec))
        if (!is.finite(delay_val) || delay_val < 0) {
            delay_val <- 0.02
        }
        accumulated <- character(0)
        current_idx <- 1L
        publish_accumulated <- function() {
            src <- globalGeneSuggestionSources_rv()
            if (!is.list(src)) {
                src <- list()
            }
            current_choices <- as.character(src[[as.character(input_id %||% "")]] %||% character(0))
            merged <- sanitize_autocomplete_choices(unique(c(current_choices, accumulated)), max_total = max_total)
            publish_gene_autocomplete(
                input_id = input_id,
                choices = merged,
                source_id = input_id,
                max_total = max_total
            )
            invisible(NULL)
        }
        run_next <- NULL
        run_next <- function() {
            if (!quick_scan_token_is_current(input_id, request_token)) {
                invisible(lapply(states, close_quick_gene_scan_state))
                return(invisible(FALSE))
            }
            if (current_idx > length(states)) {
                return(invisible(TRUE))
            }
            state <- states[[current_idx]]
            step <- step_quick_gene_scan_state(state)
            if (isTRUE(step$done)) {
                spec <- specs[[current_idx]]
                suggestions <- store_cached_quick_gene_suggestions(
                    spec$path,
                    step$suggestions,
                    max_suggestions = spec$max_suggestions,
                    max_lines = spec$max_lines,
                    max_seconds = spec$max_seconds
                )
                if (length(suggestions) > 0) {
                    accumulated <<- unique(c(accumulated, suggestions))
                    publish_accumulated()
                }
                close_quick_gene_scan_state(state)
                current_idx <<- current_idx + 1L
            }
            later::later(run_next, delay = delay_val)
            invisible(TRUE)
        }
        later::later(run_next, delay = delay_val)
        invisible(TRUE)
    }

    publish_gene_autocomplete <- function(input_id, choices, source_id = NULL, max_total = 20000L) {
        target_id <- as.character(input_id %||% "")
        if (!nzchar(target_id)) {
            return(invisible(NULL))
        }
        source_key <- as.character(source_id %||% target_id)
        cleaned <- sanitize_autocomplete_choices(choices, max_total = max_total)

        session$sendCustomMessage(
            "update_gene_autocomplete",
            list(input_id = target_id, choices = cleaned)
        )

        src <- globalGeneSuggestionSources_rv()
        if (!is.list(src)) src <- list()
        src[[source_key]] <- cleaned
        globalGeneSuggestionSources_rv(src)

        all_global <- unique(unlist(src, use.names = FALSE))
        all_global <- sanitize_autocomplete_choices(all_global, max_total = 15000L)
        session$sendCustomMessage(
            "update_gene_autocomplete",
            list(input_id = "global_search_query", choices = all_global)
        )
        invisible(cleaned)
    }

    update_gene_autocomplete <- function(input_id, annotation_paths, status_rv = NULL, max_files = Inf, max_total = 20000L, allow_build = TRUE, allow_quick_scan = TRUE) {
        auto_perf <- app_perf_new_run(sprintf("AUTO-%s", as.character(input_id %||% "input")))
        app_perf_mark(
            auto_perf,
            sprintf(
                "start allow_build=%s allow_quick_scan=%s",
                as.character(isTRUE(allow_build)),
                as.character(isTRUE(allow_quick_scan))
            ),
            "AUTO"
        )
        paths <- unique(as.character(annotation_paths %||% character(0)))
        paths <- paths[nzchar(paths) & file.exists(paths)]
        app_perf_mark(auto_perf, sprintf("paths normalized n=%d", as.integer(length(paths))), "AUTO")
        max_total <- suppressWarnings(as.integer(max_total))
        if (!is.finite(max_total) || max_total <= 0L) {
            max_total <- 20000L
        }

        if (length(paths) == 0) {
            next_quick_scan_token(input_id)
            publish_gene_autocomplete(
                input_id = input_id,
                choices = character(0),
                source_id = input_id,
                max_total = max_total
            )
            app_perf_mark(auto_perf, "no valid paths -> empty choices", "AUTO")
            return(invisible(NULL))
        }

        if (is.finite(max_files) && length(paths) > as.integer(max_files)) {
            paths <- paths[seq_len(as.integer(max_files))]
        }
        if (!isTRUE(allow_build) && length(paths) > 12L) {
            paths <- paths[seq_len(12L)]
        }
        app_perf_mark(auto_perf, sprintf("paths after caps n=%d", as.integer(length(paths))), "AUTO")

        request_token <- next_quick_scan_token(input_id)
        cache_map_check <- geneAutocompleteCache_rv()
        all_suggestions <- character(0)
        quick_scan_specs <- list()
        path_count <- max(length(paths), 1L)
        per_path_cap <- as.integer(max(600L, min(10000L, ceiling(max_total / path_count))))

        for (p in paths) {
            if (length(all_suggestions) >= max_total) {
                app_perf_mark(auto_perf, "max_total reached before finishing paths", "AUTO")
                break
            }
            ckey <- gene_autocomplete_cache_key(p)
            cached <- if (nzchar(ckey)) cache_map_check[[ckey]] else NULL
            app_perf_mark(
                auto_perf,
                sprintf(
                    "path=%s cache=%s",
                    basename(as.character(p %||% "")),
                    if (is.null(cached)) "miss" else "hit"
                ),
                "AUTO"
            )
            remaining <- as.integer(max_total - length(all_suggestions))
            if (remaining <= 0L) {
                break
            }
            if (is.null(cached)) {
                suggestion_cap <- as.integer(max(1L, min(per_path_cap, remaining)))
                if (isTRUE(allow_build)) {
                    app_perf_mark(auto_perf, sprintf("build mode start cap=%d", as.integer(suggestion_cap)), "AUTO")
                    if (is.function(warm_annotation_cache_fn)) {
                        warm_annotation_cache_fn(annotation_path = p, status_rv = NULL, context_label = NULL)
                    }
                    cached <- get_gene_suggestions_for_annotation(
                        p,
                        max_suggestions = suggestion_cap
                    )
                    cache_map_check <- geneAutocompleteCache_rv()
                    app_perf_mark(auto_perf, sprintf("build mode done n=%d", as.integer(length(cached %||% character(0)))), "AUTO")
                } else {
                    app_perf_mark(auto_perf, sprintf("disk index lookup start cap=%d", as.integer(suggestion_cap)), "AUTO")
                    cached <- get_gene_suggestions_from_disk_index(
                        p,
                        max_suggestions = suggestion_cap
                    )
                    cache_map_check <- geneAutocompleteCache_rv()
                    if (!is.null(cached)) {
                        app_perf_mark(auto_perf, sprintf("disk index hit n=%d", as.integer(length(cached %||% character(0)))), "AUTO")
                    }
                    if (isTRUE(allow_quick_scan)) {
                        if (is.null(cached)) {
                            quick_cap_base <- if (path_count <= 1L) {
                                7000L
                            } else if (path_count <= 3L) {
                                4200L
                            } else {
                                1800L
                            }
                            quick_cap <- as.integer(max(200L, min(quick_cap_base, suggestion_cap)))
                            quick_lines <- as.integer(if (path_count <= 1L) {
                                1200000L
                            } else if (path_count <= 3L) {
                                700000L
                            } else {
                                320000L
                            })
                            quick_seconds <- if (path_count <= 1L) {
                                1.20
                            } else if (path_count <= 3L) {
                                0.80
                            } else {
                                0.35
                            }
                            cached <- get_cached_quick_gene_suggestions(
                                p,
                                max_suggestions = quick_cap,
                                max_lines = quick_lines,
                                max_seconds = quick_seconds
                            )
                            if (!is.null(cached)) {
                                app_perf_mark(auto_perf, sprintf("quick cache hit n=%d", as.integer(length(cached %||% character(0)))), "AUTO")
                            } else {
                                if (requireNamespace("later", quietly = TRUE)) {
                                    quick_scan_specs[[length(quick_scan_specs) + 1L]] <- list(
                                        path = p,
                                        max_suggestions = quick_cap,
                                        max_lines = quick_lines,
                                        max_seconds = quick_seconds,
                                        chunk_lines = 1000L
                                    )
                                    cached <- character(0)
                                    app_perf_mark(
                                        auto_perf,
                                        sprintf("quick scan scheduled cap=%d lines=%d secs=%.2f", as.integer(quick_cap), as.integer(quick_lines), as.numeric(quick_seconds)),
                                        "AUTO"
                                    )
                                } else {
                                    cached <- extract_quick_gene_suggestions(
                                        p,
                                        max_suggestions = quick_cap,
                                        max_lines = quick_lines,
                                        max_seconds = quick_seconds
                                    )
                                    cached <- store_cached_quick_gene_suggestions(
                                        p,
                                        cached,
                                        max_suggestions = quick_cap,
                                        max_lines = quick_lines,
                                        max_seconds = quick_seconds
                                    )
                                    app_perf_mark(
                                        auto_perf,
                                        sprintf(
                                            "quick scan done n=%d cap=%d lines=%d secs=%.2f",
                                            as.integer(length(cached %||% character(0))),
                                            as.integer(quick_cap),
                                            as.integer(quick_lines),
                                            as.numeric(quick_seconds)
                                        ),
                                        "AUTO"
                                    )
                                }
                            }
                        }
                    } else {
                        cached <- cached %||% character(0)
                        app_perf_mark(auto_perf, "cache miss and quick scan disabled", "AUTO")
                    }
                }
            }
            cached <- as.character(cached %||% character(0))
            if (length(cached) > remaining) {
                cached <- cached[seq_len(remaining)]
            }
            if (length(cached) > 0) {
                all_suggestions <- unique(c(all_suggestions, cached))
            }
        }

        all_suggestions <- sanitize_autocomplete_choices(all_suggestions, max_total = max_total)
        publish_gene_autocomplete(
            input_id = input_id,
            choices = all_suggestions,
            source_id = input_id,
            max_total = max_total
        )
        app_perf_mark(
            auto_perf,
            sprintf("done choices=%d", as.integer(length(all_suggestions))),
            "AUTO"
        )
        if (length(quick_scan_specs) > 0L) {
            schedule_quick_gene_autocomplete_scan(
                input_id = input_id,
                quick_specs = quick_scan_specs,
                request_token = request_token,
                max_total = max_total,
                delay_sec = 0.02
            )
            app_perf_mark(auto_perf, sprintf("async quick scan queued paths=%d", as.integer(length(quick_scan_specs))), "AUTO")
        }
        invisible(NULL)
    }

    schedule_gene_autocomplete_build <- function(input_id, annotation_paths, max_total = 20000L, delay_sec = 0.8, still_valid = NULL) {
        sched_perf <- app_perf_new_run(sprintf("AUTO_BG-%s", as.character(input_id %||% "input")))
        app_perf_mark(sched_perf, "start", "AUTO_BG")
        if (!requireNamespace("later", quietly = TRUE)) {
            app_perf_mark(sched_perf, "later package unavailable", "AUTO_BG")
            return(invisible(FALSE))
        }
        paths <- unique(as.character(annotation_paths %||% character(0)))
        paths <- paths[nzchar(paths) & file.exists(paths)]
        if (length(paths) == 0) {
            app_perf_mark(sched_perf, "no valid paths", "AUTO_BG")
            return(invisible(FALSE))
        }
        max_total <- suppressWarnings(as.integer(max_total))
        if (!is.finite(max_total) || max_total <= 0L) {
            max_total <- 20000L
        }
        delay_val <- suppressWarnings(as.numeric(delay_sec))
        if (!is.finite(delay_val) || delay_val < 0) {
            delay_val <- 0.8
        }
        app_perf_mark(
            sched_perf,
            sprintf("queue paths=%d delay=%.2f", as.integer(length(paths)), as.numeric(delay_val)),
            "AUTO_BG"
        )

        path_count <- max(length(paths), 1L)
        per_path_cap <- as.integer(max(600L, min(10000L, ceiling(max_total / path_count))))
        cache_map_check <- geneAutocompleteCache_rv()
        all_suggestions <- character(0)
        next_idx <- 1L
        run_next <- NULL
        # Helper: extract suggestions from a GFF light index (pure, no reactives)
        extract_suggestions_from_index <- function(idx, max_suggestions) {
            if (is.null(idx) || !is.list(idx) || is.null(idx$genes_df) || nrow(idx$genes_df) == 0) {
                return(character(0))
            }
            attrs <- as.character(idx$genes_df$attributes %||% rep("", nrow(idx$genes_df)))
            names_lists <- extract_autocomplete_name_lists(attrs)
            suggestions <- c(names_lists$primary, names_lists$fallback)
            suggestions <- trimws(utils::URLdecode(as.character(suggestions)))
            suggestions <- suggestions[!is.na(suggestions) & nzchar(suggestions)]
            suggestions <- suggestions[nchar(suggestions) <= 80]
            suggestions <- unique(suggestions)
            if (length(suggestions) > max_suggestions) suggestions <- suggestions[seq_len(max_suggestions)]
            suggestions
        }

        continue_after_build <- function(cached, p, remaining) {
            cached <- sanitize_autocomplete_choices(cached, max_total = remaining)
            if (length(cached) > 0) {
                all_suggestions <<- unique(c(all_suggestions, cached))
            }
            # Update autocomplete cache for this path
            ckey <- gene_autocomplete_cache_key(p)
            if (nzchar(ckey) && length(cached) > 0) {
                cm <- geneAutocompleteCache_rv()
                if (is.null(cm[[ckey]])) {
                    cm[[ckey]] <- cached
                    geneAutocompleteCache_rv(trim_autocomplete_cache_map(cm))
                }
                cache_map_check <<- geneAutocompleteCache_rv()
            }
            later::later(run_next, delay = 0.04)
            invisible(TRUE)
        }

        run_next <- function() {
            if (is.function(still_valid)) {
                is_valid <- tryCatch(isTRUE(still_valid()), error = function(e) FALSE)
                if (!is_valid) {
                    app_perf_mark(sched_perf, "stopped: still_valid=FALSE", "AUTO_BG")
                    return(invisible(FALSE))
                }
            }

            if (next_idx > length(paths) || length(all_suggestions) >= max_total) {
                final_choices <- sanitize_autocomplete_choices(all_suggestions, max_total = max_total)
                publish_gene_autocomplete(
                    input_id = input_id,
                    choices = final_choices,
                    source_id = input_id,
                    max_total = max_total
                )
                app_perf_mark(sched_perf, sprintf("done final_choices=%d", as.integer(length(final_choices))), "AUTO_BG")
                return(invisible(TRUE))
            }

            p <- paths[[next_idx]]
            next_idx <<- next_idx + 1L
            app_perf_mark(sched_perf, sprintf("build %d/%d %s", as.integer(next_idx - 1L), as.integer(length(paths)), basename(as.character(p %||% ""))), "AUTO_BG")
            remaining <- as.integer(max_total - length(all_suggestions))
            if (remaining > 0L) {
                ckey <- gene_autocomplete_cache_key(p)
                cached <- if (nzchar(ckey)) cache_map_check[[ckey]] else NULL
                if (is.null(cached)) {
                    suggestion_cap <- as.integer(max(1L, min(per_path_cap, remaining)))
                    # Offload heavy GFF parsing to a future worker to avoid blocking UI
                    local_p <- p
                    local_cap <- suggestion_cap
                    tryCatch(
                        {
                            promises::future_promise({
                                # Only the heavy GFF parse runs in the worker thread
                                build_gff_gene_light_index(local_p)
                            }, seed = FALSE) %...>% (function(idx) {
                                # Extract suggestions on the main thread (fast, uses local closure fns)
                                result <- extract_suggestions_from_index(idx, local_cap)
                                app_perf_mark(sched_perf, sprintf("async build done n=%d %s", as.integer(length(result %||% character(0))), basename(as.character(local_p %||% ""))), "AUTO_BG")
                                continue_after_build(result, local_p, remaining)
                            }) %...!% (function(err) {
                                app_perf_mark(sched_perf, sprintf("async build error: %s", as.character(err$message %||% "unknown")), "AUTO_BG")
                                continue_after_build(character(0), local_p, remaining)
                            })
                        },
                        error = function(e) {
                            # Fallback to synchronous if future_promise fails to launch
                            app_perf_mark(sched_perf, sprintf("future_promise fallback: %s", as.character(e$message %||% "unknown")), "AUTO_BG")
                            cached_sync <- tryCatch(
                                {
                                    if (is.function(warm_annotation_cache_fn)) {
                                        warm_annotation_cache_fn(annotation_path = p, status_rv = NULL, context_label = NULL)
                                    }
                                    cached_local <- get_gene_suggestions_for_annotation(p, max_suggestions = suggestion_cap)
                                    cache_map_check <<- geneAutocompleteCache_rv()
                                    cached_local
                                },
                                error = function(e2) character(0)
                            )
                            continue_after_build(cached_sync, p, remaining)
                        }
                    )
                    return(invisible(TRUE))
                }
                cached <- sanitize_autocomplete_choices(cached, max_total = remaining)
                if (length(cached) > 0) {
                    all_suggestions <<- unique(c(all_suggestions, cached))
                }
            }
            later::later(run_next, delay = 0.04)
            invisible(TRUE)
        }
        later::later(run_next, delay = delay_val)
        invisible(TRUE)
    }

    list(
        gene_autocomplete_cache_key = gene_autocomplete_cache_key,
        trim_autocomplete_cache_map = trim_autocomplete_cache_map,
        extract_autocomplete_name_lists = extract_autocomplete_name_lists,
        sanitize_autocomplete_choices = sanitize_autocomplete_choices,
        get_gene_suggestions_for_annotation = get_gene_suggestions_for_annotation,
        get_gene_suggestions_from_disk_index = get_gene_suggestions_from_disk_index,
        get_cached_quick_gene_suggestions = get_cached_quick_gene_suggestions,
        store_cached_quick_gene_suggestions = store_cached_quick_gene_suggestions,
        init_quick_gene_scan_state = init_quick_gene_scan_state,
        close_quick_gene_scan_state = close_quick_gene_scan_state,
        step_quick_gene_scan_state = step_quick_gene_scan_state,
        extract_quick_gene_suggestions = extract_quick_gene_suggestions,
        schedule_quick_gene_autocomplete_scan = schedule_quick_gene_autocomplete_scan,
        publish_gene_autocomplete = publish_gene_autocomplete,
        update_gene_autocomplete = update_gene_autocomplete,
        schedule_gene_autocomplete_build = schedule_gene_autocomplete_build
    )
}
