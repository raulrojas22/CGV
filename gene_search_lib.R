# ==============================================================================
# gene_search_lib.R
# Librería para búsqueda de alias de genes.
# Optimización de memoria para evitar errores de serialización en Future.
# Nota: los paquetes ya están cargados en global.R; no se repiten aquí.
# ==============================================================================

# Configuración de URLs
NCBI_EUTILS <- "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"
ENSEMBL_REST <- "https://rest.ensembl.org"
UNIPROT_REST <- "https://rest.uniprot.org/uniprotkb/search"

# Caché en memoria para evitar repetir búsquedas de red idénticas
.alias_memory_cache <- new.env(parent = emptyenv())
.alias_memory_cache_version <- "v3"
.alias_memory_cache_max_entries <- 120L
.alias_memory_cache_access_order <- character(0)

trim_alias_memory_cache <- function() {
    n <- length(.alias_memory_cache_access_order)
    if (n <= .alias_memory_cache_max_entries) return(invisible(NULL))
    to_remove <- head(.alias_memory_cache_access_order, n - .alias_memory_cache_max_entries)
    for (k in to_remove) {
        if (exists(k, envir = .alias_memory_cache, inherits = FALSE)) {
            rm(list = k, envir = .alias_memory_cache)
        }
    }
    .alias_memory_cache_access_order <<- tail(.alias_memory_cache_access_order, .alias_memory_cache_max_entries)
    invisible(NULL)
}

touch_alias_cache_key <- function(key) {
    .alias_memory_cache_access_order <<- c(
        .alias_memory_cache_access_order[.alias_memory_cache_access_order != key],
        key
    )
    invisible(NULL)
}

# ------------------------------------------------------------------------------
# 1. Funciones Auxiliares (Internas)
# ------------------------------------------------------------------------------

expand_gene_queries <- function(q) {
    # q <- str_trim(q)
    q <- trimws(q)
    variants <- c(q)
    if (stringr::str_detect(q, ";"))
        variants <- c(variants, stringr::str_replace(q, ";", c(".", "-", " ", "")))
    if (stringr::str_detect(q, "\\."))
        variants <- c(variants, stringr::str_replace(q, "\\.", c(";", "-", " ", "")))

    if (!stringr::str_starts(tolower(q), "os")) {
        variants <- c(variants, paste0("Os", q))
        if (stringr::str_detect(q, ";")) {
            variants <- c(variants, stringr::str_replace(paste0("Os", q), ";", c(".", "-",
                " ", "")))
        }
    }
    return(unique(variants))
}

build_gene_query_plan <- function(q) {
    q_txt <- trimws(as.character(q %||% ""))
    if (!nzchar(q_txt)) {
        return(list(primary = character(0), relaxed = character(0)))
    }
    expanded <- expand_gene_queries(q_txt)
    primary <- unique(c(
        q_txt,
        if (stringr::str_detect(q_txt, ";")) c(stringr::str_replace_all(q_txt, ";", "."), stringr::str_replace_all(q_txt, ";", "-")) else character(0),
        if (stringr::str_detect(q_txt, "\\.")) c(stringr::str_replace_all(q_txt, "\\.", ";"), stringr::str_replace_all(q_txt, "\\.", "-")) else character(0),
        if (stringr::str_detect(q_txt, stringr::fixed("-"))) c(stringr::str_replace_all(q_txt, "-", ";"), stringr::str_replace_all(q_txt, "-", ".")) else character(0)
    ))
    primary <- primary[nzchar(primary)]
    relaxed <- setdiff(expanded, primary)
    list(primary = primary, relaxed = relaxed)
}

is_strong_alias_score <- function(score, cutoff = 20) {
    score_num <- suppressWarnings(as.numeric(score %||% NA_real_))
    is.finite(score_num) && score_num >= cutoff
}

collect_top_scored_matches <- function(candidates, score_fn, min_score = 3,
    strong_score = 20, max_hits = 3, score_margin = 4) {
    if (length(candidates) == 0) {
        return(list(values = list(), scores = numeric(0), best_score = -Inf, strong = FALSE))
    }

    scored <- vector("list", length(candidates))
    keep_n <- 0L
    for (i in seq_along(candidates)) {
        score <- suppressWarnings(as.numeric(score_fn(candidates[[i]]) %||% NA_real_))
        if (!is.finite(score)) {
            next
        }
        keep_n <- keep_n + 1L
        scored[[keep_n]] <- list(value = candidates[[i]], score = score)
    }
    if (keep_n == 0L) {
        return(list(values = list(), scores = numeric(0), best_score = -Inf, strong = FALSE))
    }

    scored <- scored[seq_len(keep_n)]
    ord <- order(vapply(scored, function(x) x$score, numeric(1)), decreasing = TRUE)
    scored <- scored[ord]
    best_value <- scored[[1]]$value
    best_score <- scored[[1]]$score
    keep_cutoff <- max(min_score, best_score - score_margin)
    scored <- scored[vapply(scored, function(x) x$score >= keep_cutoff, logical(1))]
    if (length(scored) == 0 && is.finite(best_score) && best_score >= min_score) {
        scored <- list(list(value = best_value, score = best_score))
    }
    if (length(scored) > max_hits) {
        scored <- scored[seq_len(max_hits)]
    }

    list(
        values = lapply(scored, function(x) x$value),
        scores = vapply(scored, function(x) x$score, numeric(1)),
        best_score = best_score,
        strong = is_strong_alias_score(best_score, cutoff = strong_score)
    )
}

flatten_alias_bundle <- function(values) {
    vals <- unique(trimws(as.character(unlist(values, use.names = FALSE))))
    vals[!is.na(vals) & nzchar(vals)]
}

flatten_condition_messages <- function(err) {
    seen <- new.env(parent = emptyenv())
    out <- character(0)
    walk_err <- function(cond) {
        if (is.null(cond)) {
            return(invisible(NULL))
        }
        key <- paste(paste(class(cond), collapse = "|"), conditionMessage(cond), sep = "::")
        if (exists(key, envir = seen, inherits = FALSE)) {
            return(invisible(NULL))
        }
        assign(key, TRUE, envir = seen)
        msg <- trimws(as.character(conditionMessage(cond) %||% ""))
        if (nzchar(msg)) {
            out <<- c(out, msg)
        }
        for (field in c("parent", "cause")) {
            child <- cond[[field]]
            if (inherits(child, "condition")) {
                walk_err(child)
            }
        }
    }
    walk_err(err)
    unique(out[nzchar(out)])
}

format_lookup_error_message <- function(err, source = NULL) {
    parts <- flatten_condition_messages(err)
    msg <- paste(parts, collapse = " | ")
    if (!nzchar(msg)) {
        msg <- trimws(as.character(conditionMessage(err) %||% "Unknown external lookup error"))
    }
    src <- trimws(as.character(source %||% ""))
    if (nzchar(src)) {
        sprintf("[%s] %s", src, msg)
    } else {
        msg
    }
}

pick_best_scored_values <- function(candidates, score_fn, min_score = 8, strong_score = 20) {
    best_score <- -Inf
    best_value <- NULL
    for (candidate in candidates) {
        score <- suppressWarnings(as.numeric(score_fn(candidate) %||% NA_real_))
        if (!is.finite(score)) {
            next
        }
        if (is.null(best_value) || score > best_score) {
            best_value <- candidate
            best_score <- score
        }
        if (is_strong_alias_score(score, cutoff = strong_score)) {
            return(list(value = candidate, score = score, strong = TRUE))
        }
    }
    if (!is.null(best_value) && is.finite(best_score) && best_score >= min_score) {
        return(list(value = best_value, score = best_score, strong = FALSE))
    }
    list(value = NULL, score = -Inf, strong = FALSE)
}

safe_get_json <- function(req, timeout_sec = 10) {
    tryCatch({
        resp <- httr2::req_perform(httr2::req_retry(httr2::req_timeout(req, timeout_sec), max_tries = 4, max_seconds = 5))
        httr2::resp_body_json(resp)
    }, error = function(e) {
        return(NULL)
    })
}

# Normalizers and lightweight relevance scoring to avoid cross-gene false
# positives.
normalize_match_token <- function(x) {
    x <- as.character(x %||% "")
    x <- trimws(utils::URLdecode(x))
    x <- tolower(gsub("[\"']", "", x))
    if (is.na(x))
        "" else x
}

compact_match_token <- function(x) {
    y <- normalize_match_token(x)
    gsub("[^a-z0-9]+", "", y)
}

extract_query_alpha_core <- function(q) {
    a <- gsub("[^a-z]+", "", compact_match_token(q))
    if (startsWith(a, "os") && nchar(a) > 4)
        a <- sub("^os", "", a)
    a
}

extract_query_digit_core <- function(q) {
    gsub("[^0-9]+", "", compact_match_token(q))
}

is_stable_gene_identifier <- function(x) {
    v <- normalize_match_token(x)
    grepl("^(gene:|transcript:|cds:)?bgiosga\\d+([_-][tp]a)?$", v) || grepl("^loc_os\\d{2}g\\d{5,}$",
        v) || grepl("^os\\d{2}g\\d{5,}$", v) || grepl("^ens[a-z]{0,6}g\\d+$", v)
}

build_query_score_context <- function(query_gene) {
    q_txt <- as.character(query_gene %||% "")
    q_vars <- expand_gene_queries(q_txt)
    q_comp <- unique(vapply(q_vars, compact_match_token, character(1)))
    q_comp <- q_comp[nzchar(q_comp)]
    list(
        query_gene = q_txt,
        q_comp = q_comp,
        q_alpha = extract_query_alpha_core(q_txt),
        q_digits = extract_query_digit_core(q_txt)
    )
}

as_query_score_context <- function(query_gene) {
    if (is.list(query_gene) &&
        !is.null(query_gene$q_comp) &&
        !is.null(query_gene$q_alpha) &&
        !is.null(query_gene$q_digits)) {
        return(query_gene)
    }
    build_query_score_context(query_gene)
}

score_text_against_query <- function(txt, query_gene) {
    query_ctx <- as_query_score_context(query_gene)
    t_norm <- normalize_match_token(txt)
    if (!nzchar(t_norm) || t_norm %in% c("na", "n/a")) {
        return(-Inf)
    }
    t_comp <- compact_match_token(t_norm)

    score <- 0
    if (length(query_ctx$q_comp) > 0 && t_comp %in% query_ctx$q_comp)
        score <- score + 20
    if (length(query_ctx$q_comp) > 0 && any(vapply(query_ctx$q_comp, function(qc) nzchar(qc) && grepl(qc,
        t_comp, fixed = TRUE), logical(1))))
        score <- score + 8
    if (nzchar(query_ctx$q_alpha) && grepl(query_ctx$q_alpha, t_norm, fixed = TRUE))
        score <- score + 6
    if (nzchar(query_ctx$q_digits) && grepl(query_ctx$q_digits, t_comp, fixed = TRUE))
        score <- score + 3

    t_alpha <- gsub("[^a-z]+", "", t_comp)
    t_digits <- gsub("[^0-9]+", "", t_comp)
    if (nzchar(query_ctx$q_alpha) && nzchar(query_ctx$q_digits) && identical(t_alpha, query_ctx$q_alpha) && nzchar(t_digits) &&
        !identical(t_digits, query_ctx$q_digits)) {
        score <- score - 10
    }
    if (nchar(t_norm) > 80)
        score <- score - 3
    score
}

score_alias_set <- function(values, query_gene) {
    query_ctx <- as_query_score_context(query_gene)
    vals <- as.character(values %||% character(0))
    if (length(vals) == 0) {
        return(-Inf)
    }
    s <- vapply(vals, function(v) score_text_against_query(v, query_ctx), numeric(1))
    max(s, na.rm = TRUE)
}

# ------------------------------------------------------------------------------
# 2. Resolvers
# ------------------------------------------------------------------------------

query_mygene <- function(gene, taxid) {
    query_ctx <- build_query_score_context(gene)
    mg_url <- "https://mygene.info/v3/query"
    query_plan <- build_gene_query_plan(gene)
    best_aliases <- character(0)
    best_score <- -Inf
    for (variants in Filter(length, list(query_plan$primary, query_plan$relaxed))) {
        phase_aliases <- character(0)
        phase_best_score <- -Inf
        for (q in variants) {
            req <- httr2::req_url_query(
                httr2::request(mg_url),
                q = q,
                species = as.character(taxid),
                fields = "symbol,name,alias,other_names",
                size = 20
            )
            res <- safe_get_json(req, timeout_sec = 5)
            if (is.null(res$hits) || length(res$hits) == 0) {
                next
            }
            hit_pick <- collect_top_scored_matches(
                res$hits,
                function(h) score_alias_set(c(h$symbol, h$name, unlist(h$alias), unlist(h$other_names)), query_ctx)
            )
            if (length(hit_pick$values) == 0) {
                next
            }
            aliases <- flatten_alias_bundle(lapply(hit_pick$values, function(h) {
                c(h$symbol, h$name, unlist(h$alias), unlist(h$other_names))
            }))
            if (length(aliases) == 0) {
                next
            }
            if (hit_pick$best_score > phase_best_score) {
                phase_aliases <- aliases
                phase_best_score <- hit_pick$best_score
            } else if (is.finite(hit_pick$best_score) && hit_pick$best_score >= max(3, phase_best_score - 2)) {
                phase_aliases <- unique(c(phase_aliases, aliases))
            }
            if (isTRUE(hit_pick$strong) && length(phase_aliases) > 0) {
                return(phase_aliases)
            }
        }
        if (length(phase_aliases) > 0 && is.finite(phase_best_score) && phase_best_score >= 3) {
            return(unique(phase_aliases))
        }
        if (length(phase_aliases) > 0 && phase_best_score > best_score) {
            best_aliases <- unique(phase_aliases)
            best_score <- phase_best_score
        }
    }
    if (length(best_aliases) > 0 && is.finite(best_score) && best_score >= 3) {
        return(best_aliases)
    }
    return(character(0))
}

query_ncbi <- function(gene, taxid) {
    query_ctx <- build_query_score_context(gene)
    query_plan <- build_gene_query_plan(gene)
    best_aliases <- character(0)
    best_score <- -Inf
    for (variants in Filter(length, list(query_plan$primary, query_plan$relaxed))) {
        phase_best_aliases <- character(0)
        phase_best_score <- -Inf
        for (v in variants) {
            term <- sprintf("(%s[All Fields]) AND txid%s[Organism:exp]", v, taxid)
            req <- httr2::req_url_query(httr2::request(paste0(NCBI_EUTILS, "esearch.fcgi")), db = "gene", term = term, retmode = "json")
            res <- safe_get_json(req, timeout_sec = 8)
            ids <- if (!is.null(res$esearchresult$idlist) && length(res$esearchresult$idlist) > 0) unlist(res$esearchresult$idlist) else character(0)
            if (length(ids) == 0) {
                next
            }

            ids <- ids[seq_len(min(length(ids), 10))]
            req_sum <- httr2::req_url_query(httr2::request(paste0(NCBI_EUTILS, "esummary.fcgi")), db = "gene", id = paste(ids, collapse = ","), retmode = "json")
            doc <- safe_get_json(req_sum, timeout_sec = 8)
            if (is.null(doc$result)) {
                next
            }

            uids <- as.character(doc$result$uids %||% ids)
            uids <- uids[nzchar(uids)]
            if (length(uids) == 0) {
                next
            }

            uid_pick <- collect_top_scored_matches(
                uids,
                function(uid) {
                    r <- doc$result[[uid]]
                    if (is.null(r)) {
                        return(-Inf)
                    }
                    vals <- c(r$nomenclaturesymbol, r$name, unlist(stringr::str_split(r$otheraliases %||% "", ",")), r$description)
                    score_alias_set(vals, query_ctx)
                }
            )
            if (length(uid_pick$values) == 0) {
                next
            }

            aliases <- flatten_alias_bundle(lapply(uid_pick$values, function(uid) {
                result <- doc$result[[uid]]
                if (is.null(result)) {
                    return(character(0))
                }
                vals <- c(result$nomenclaturesymbol, result$name)
                if (!is.null(result$otheraliases) && result$otheraliases != "") {
                    vals <- c(vals, stringr::str_split(result$otheraliases, ",")[[1]])
                }
                vals
            }))
            if (length(aliases) == 0) {
                next
            }

            if (uid_pick$best_score > phase_best_score) {
                phase_best_aliases <- aliases
                phase_best_score <- uid_pick$best_score
            } else if (is.finite(uid_pick$best_score) && uid_pick$best_score >= max(3, phase_best_score - 2)) {
                phase_best_aliases <- unique(c(phase_best_aliases, aliases))
            }
            if (isTRUE(uid_pick$strong) && length(phase_best_aliases) > 0) {
                return(unique(phase_best_aliases))
            }
        }
        if (length(phase_best_aliases) > 0 && is.finite(phase_best_score) && phase_best_score >= 3) {
            return(unique(phase_best_aliases))
        }
        if (length(phase_best_aliases) > 0 && phase_best_score > best_score) {
            best_aliases <- unique(phase_best_aliases)
            best_score <- phase_best_score
        }
    }
    if (length(best_aliases) > 0 && is.finite(best_score) && best_score >= 3) {
        return(unique(best_aliases))
    }
    character(0)
}

query_uniprot <- function(gene, taxid) {
    query_ctx <- build_query_score_context(gene)
    query_plan <- build_gene_query_plan(gene)
    best_aliases <- character(0)
    best_score <- -Inf
    for (variants in Filter(length, list(query_plan$primary, query_plan$relaxed))) {
        phase_aliases <- character(0)
        phase_best_score <- -Inf
        for (v in variants) {
            q_str <- sprintf("(gene:\"%s\") AND (organism_id:%s)", v, taxid)
            req <- httr2::req_url_query(httr2::request(UNIPROT_REST), query = q_str, format = "json", size = 20, fields = "accession,gene_names")
            res <- safe_get_json(req, timeout_sec = 5)
            if (is.null(res$results) || length(res$results) == 0) {
                next
            }
            result_pick <- collect_top_scored_matches(
                res$results,
                function(r) {
                    vals <- c(r$primaryAccession)
                    purrr::walk(r$genes, function(g) {
                      if (!is.null(g$geneName$value))
                        vals <<- c(vals, g$geneName$value)
                      if (!is.null(g$synonyms))
                        vals <<- c(vals, purrr::map_chr(g$synonyms, "value"))
                      if (!is.null(g$orderedLocusNames))
                        vals <<- c(vals, purrr::map_chr(g$orderedLocusNames, "value"))
                    })
                    score_alias_set(vals, query_ctx)
                }
            )
            if (length(result_pick$values) == 0) {
                next
            }
            aliases <- flatten_alias_bundle(lapply(result_pick$values, function(result_obj) {
                names <- character(0)
                purrr::walk(result_obj$genes, function(g) {
                    if (!is.null(g$geneName$value))
                      names <<- c(names, g$geneName$value)
                    if (!is.null(g$synonyms))
                      names <<- c(names, purrr::map_chr(g$synonyms, "value"))
                    if (!is.null(g$orderedLocusNames))
                      names <<- c(names, purrr::map_chr(g$orderedLocusNames, "value"))
                })
                c(result_obj$primaryAccession, names)
            }))
            if (length(aliases) == 0) {
                next
            }
            if (result_pick$best_score > phase_best_score) {
                phase_aliases <- aliases
                phase_best_score <- result_pick$best_score
            } else if (is.finite(result_pick$best_score) && result_pick$best_score >= max(3, phase_best_score - 2)) {
                phase_aliases <- unique(c(phase_aliases, aliases))
            }
            if (isTRUE(result_pick$strong) && length(phase_aliases) > 0) {
                return(unique(phase_aliases))
            }
        }
        if (length(phase_aliases) > 0 && is.finite(phase_best_score) && phase_best_score >= 3) {
            return(unique(phase_aliases))
        }
        if (length(phase_aliases) > 0 && phase_best_score > best_score) {
            best_aliases <- unique(phase_aliases)
            best_score <- phase_best_score
        }
    }
    if (length(best_aliases) > 0 && is.finite(best_score) && best_score >= 3) {
        return(best_aliases)
    }
    return(character(0))
}

collect_ensembl_aliases <- function(gene_id, meta = NULL, xrefs = NULL) {
    if (!nzchar(as.character(gene_id %||% ""))) {
        return(character(0))
    }
    re_osg <- "\\bOs\\d{2}g\\d{5,}\\b"
    re_locos <- "\\bLOC_Os\\d{2}g\\d{5,}\\b"
    aliases <- character(0)
    add_a <- function(a) {
        if (!is.null(a) && is.character(a) && length(a) == 1 && nchar(trimws(a)) > 0) {
            aliases <<- c(aliases, trimws(a))
        }
    }
    add_a(gene_id)
    add_a(meta$display_name)
    desc <- meta$description
    if (!is.null(desc) && is.character(desc) && nchar(trimws(desc)) > 0) {
        add_a(desc)
        for (m in regmatches(desc, gregexpr(re_osg, desc))[[1]]) add_a(m)
        for (m in regmatches(desc, gregexpr(re_locos, desc))[[1]]) add_a(m)
        parens <- regmatches(desc, gregexpr("\\(([^\\s)]+)\\)", desc))[[1]]
        for (p in gsub("[()]", "", parens)) add_a(p)
    }
    if (is.list(xrefs)) {
        for (xr in xrefs) {
            for (field in c("display_id", "primary_id", "description")) {
                val <- xr[[field]]
                if (!is.null(val) && is.character(val) && length(val) == 1 && nchar(trimws(val)) > 0) {
                    add_a(val)
                    for (m in regmatches(val, gregexpr(re_osg, val))[[1]]) add_a(m)
                    for (m in regmatches(val, gregexpr(re_locos, val))[[1]]) add_a(m)
                }
            }
        }
    }
    unique(aliases)
}

query_ensembl_with_species <- function(gene, species_name) {
    if (is.null(species_name)) {
        return(character(0))
    }
    query_ctx <- build_query_score_context(gene)

    # Build list of species to try: primary + related species fallback Many
    # subspecies share gene symbols only under the main species in Ensembl
    related_species_map <- list(oryza_indica = c("oryza_sativa", "oryza_rufipogon"),
        oryza_sativa = c("oryza_indica", "oryza_rufipogon"), oryza_rufipogon = c("oryza_sativa",
            "oryza_indica"), triticum_dicoccoides = c("triticum_aestivum"), triticum_turgidum = c("triticum_aestivum"),
        mus_spretus = c("mus_musculus"), mus_caroli = c("mus_musculus"), pan_paniscus = c("pan_troglodytes",
            "homo_sapiens"), pan_troglodytes = c("pan_paniscus", "homo_sapiens"),
        bos_indicus = c("bos_taurus"))
    species_to_try <- unique(c(species_name, related_species_map[[species_name]] %||%
        character(0)))

    query_plan <- build_gene_query_plan(gene)
    query_stages <- list(
        list(
            species = species_to_try[seq_len(1L)],
            endpoints = c("symbol"),
            variants = query_plan$primary
        ),
        list(
            species = species_to_try[seq_len(1L)],
            endpoints = c("symbol", "name"),
            variants = unique(c(query_plan$primary, query_plan$relaxed))
        ),
        list(
            species = species_to_try,
            endpoints = c("symbol", "name"),
            variants = unique(c(query_plan$primary, query_plan$relaxed))
        )
    )

    # Cache resolved gene IDs to avoid duplicate HTTP calls across variants
    resolved_id_cache <- new.env(parent = emptyenv(), hash = TRUE)

    resolve_candidate_aliases <- function(candidate) {
        id <- as.character(candidate$gene$id %||% "")
        if (!nzchar(id)) {
            return(character(0))
        }
        # Return cached result if this gene ID was already resolved
        if (exists(id, envir = resolved_id_cache, inherits = FALSE)) {
            return(get(id, envir = resolved_id_cache, inherits = FALSE))
        }
        req_id <- httr2::req_headers(
            httr2::req_url_query(httr2::request(paste(ENSEMBL_REST, "lookup/id", id, sep = "/")), expand = 1),
            Accept = "application/json"
        )
        meta <- safe_get_json(req_id)
        req_xref <- httr2::req_headers(
            httr2::req_url_query(httr2::request(paste(ENSEMBL_REST, "xrefs/id", id, sep = "/")), all_levels = 1),
            Accept = "application/json"
        )
        xrefs <- safe_get_json(req_xref)
        result <- collect_ensembl_aliases(id, meta = meta, xrefs = xrefs)
        assign(id, result, envir = resolved_id_cache)
        result
    }

    best_aliases <- character(0)
    best_score <- -Inf
    for (stage in query_stages) {
        species_stage <- unique(as.character(stage$species %||% character(0)))
        variants_stage <- unique(as.character(stage$variants %||% character(0)))
        endpoints_stage <- unique(as.character(stage$endpoints %||% character(0)))
        if (length(species_stage) == 0 || length(variants_stage) == 0 || length(endpoints_stage) == 0) {
            next
        }
        stage_best_aliases <- character(0)
        stage_best_score <- -Inf
        for (sp in species_stage) {
            for (endpoint in endpoints_stage) {
                for (v in variants_stage) {
                    url <- paste(ENSEMBL_REST, "xrefs", endpoint, sp, v, sep = "/")
                    req <- httr2::req_headers(httr2::request(url), Accept = "application/json")
                    res <- safe_get_json(req, timeout_sec = 6)
                    if (!is.list(res)) {
                        next
                    }
                    genes <- purrr::keep(res, ~.x$type == "gene")
                    if (length(genes) == 0) {
                        next
                    }
                    gene_pick <- collect_top_scored_matches(
                        genes,
                        function(g) score_alias_set(c(g$display_id, g$description, g$db_display_name, g$id), query_ctx)
                    )
                    if (length(gene_pick$values) == 0) {
                        next
                    }
                    candidates <- lapply(gene_pick$values, function(gene_obj) {
                        list(
                            gene = gene_obj,
                            species = sp,
                            endpoint = endpoint,
                            variant = v
                        )
                    })
                    aliases <- flatten_alias_bundle(lapply(candidates, resolve_candidate_aliases))
                    if (length(aliases) == 0) {
                        next
                    }
                    if (gene_pick$best_score > stage_best_score) {
                        stage_best_aliases <- aliases
                        stage_best_score <- gene_pick$best_score
                    } else if (is.finite(gene_pick$best_score) && gene_pick$best_score >= max(3, stage_best_score - 2)) {
                        stage_best_aliases <- unique(c(stage_best_aliases, aliases))
                    }
                    if (isTRUE(gene_pick$strong) && length(stage_best_aliases) > 0) {
                        return(unique(stage_best_aliases))
                    }
                }
            }
        }
        if (length(stage_best_aliases) > 0 && is.finite(stage_best_score) && stage_best_score >= 3) {
            return(unique(stage_best_aliases))
        }
        if (length(stage_best_aliases) > 0 && stage_best_score > best_score) {
            best_aliases <- unique(stage_best_aliases)
            best_score <- stage_best_score
        }
    }
    if (length(best_aliases) > 0 && is.finite(best_score) && best_score >= 3) {
        return(unique(best_aliases))
    }
    return(character(0))
}

# ------------------------------------------------------------------------------
# 3. FUNCI\303\223N PRINCIPAL (Optimizaci\303\263n de Memoria)
# ------------------------------------------------------------------------------

get_gene_aliases <- function(gene, taxid = NULL, organism = NULL, ensembl_species = NULL,
    use_parallel = TRUE, status_callback = NULL, sources = c("mygene", "ncbi", "uniprot",
        "ensembl")) {
    lookup_perf <- app_perf_new_run("EXT_ALIAS")
    with_lookup_meta <- function(aliases, had_errors = FALSE, source_errors = character(0),
                                 source_summaries = character(0), skipped = FALSE,
                                 skip_reason = "", success_sources = 0L,
                                 failed_sources = 0L) {
        structure(
            as.character(aliases %||% character(0)),
            lookup_meta = list(
                had_errors = isTRUE(had_errors),
                source_errors = unique(as.character(source_errors %||% character(0))),
                source_summaries = as.character(source_summaries %||% character(0)),
                skipped = isTRUE(skipped),
                skip_reason = as.character(skip_reason %||% ""),
                success_sources = as.integer(success_sources %||% 0L),
                failed_sources = as.integer(failed_sources %||% 0L),
                sources = as.character(sources %||% character(0))
            )
        )
    }
    emit_status <- function(msg) {
        if (is.null(status_callback)) {
            return(invisible(NULL))
        }
        try(status_callback(as.character(msg %||% "")), silent = TRUE)
        invisible(NULL)
    }

    valid_sources <- c("mygene", "ncbi", "uniprot", "ensembl")
    source_labels <- c(mygene = "MyGene", ncbi = "NCBI", uniprot = "UniProt", ensembl = "Ensembl")
    sources <- unique(tolower(trimws(as.character(sources %||% valid_sources))))
    sources <- sources[sources %in% valid_sources]
    app_perf_mark(
        lookup_perf,
        sprintf("start gene=%s mode=%s sources=%s", as.character(gene %||% ""), ifelse(isTRUE(use_parallel), "parallel", "sequential"), paste(sources, collapse = ",")),
        "EXT_ALIAS"
    )
    if (length(sources) == 0) {
        app_perf_mark(lookup_perf, "skip no sources", "EXT_ALIAS")
        emit_status("\u2022 External DBs: Skipped (no sources enabled).")
        return(with_lookup_meta(character(0), skipped = TRUE, skip_reason = "sources_disabled"))
    }

    # NUEVO: Crear llave \303\272nica de b\303\272squeda
    cache_key <- paste(.alias_memory_cache_version, gene, taxid %||% "NA",
        organism %||% "NA", ensembl_species %||% "NA",
        paste(sort(sources), collapse = ","), sep = "|")

    # NUEVO: Si ya lo busc\303\263 antes en esta sesi\303\263n, lo devuelve al
    # instante (0.001 segundos)
    if (exists(cache_key, envir = .alias_memory_cache, inherits = FALSE)) {
        cached_aliases <- get(cache_key, envir = .alias_memory_cache, inherits = FALSE)
        touch_alias_cache_key(cache_key)
        app_perf_mark(lookup_perf, sprintf("cache hit aliases=%d", as.integer(length(cached_aliases %||% character(0)))), "EXT_ALIAS")
        emit_status("\u2022 External stage: Aliases loaded from cache.")
        return(cached_aliases)
    }

    # Auto-derive ensembl_species from organism if not provided
    if (is.null(ensembl_species) && !is.null(organism)) {
        # Ensembl expects lowercase species with underscores, e.g.
        # 'oryza_sativa' Handle subspecies: 'Oryza sativa ssp. indica' -> try
        # 'oryza_indica' first
        org_clean <- tolower(trimws(organism))
        # Remove common subspecies markers to extract the subspecies name
        ssp_match <- regmatches(org_clean, regexec("\\b(?:ssp\\.?|subsp\\.?|var\\.?)\\s+(\\w+)",
            org_clean))[[1]]
        if (length(ssp_match) >= 2 && nzchar(ssp_match[2])) {
            # Extract genus + subspecies (e.g. 'oryza_indica')
            genus <- strsplit(org_clean, "\\s+")[[1]][1]
            ensembl_species <- paste0(genus, "_", ssp_match[2])
        } else {
            # Simple binomial: 'Homo sapiens' -> 'homo_sapiens'
            parts <- strsplit(org_clean, "\\s+")[[1]]
            if (length(parts) >= 2) {
                ensembl_species <- paste(parts[1], parts[2], sep = "_")
            }
        }
    }

    # 1. Resolver TaxID
    if (is.null(taxid)) {
        if (is.null(organism)) {
            return(with_lookup_meta(character(0), skipped = TRUE, skip_reason = "organism_missing"))
        }
        tryCatch({
            req <- httr2::req_url_query(httr2::request(paste0(NCBI_EUTILS, "esearch.fcgi")), db = "taxonomy", term = organism, retmode = "json")
            res <- safe_get_json(req)
            if (!is.null(res$esearchresult$idlist) && length(res$esearchresult$idlist) >
                0) {
                taxid <- unlist(res$esearchresult$idlist)[[1]]
            }
        }, error = function(e) NULL)
        if (is.null(taxid)) {
            app_perf_mark(lookup_perf, "taxid unresolved", "EXT_ALIAS")
            return(with_lookup_meta(character(0), skipped = TRUE, skip_reason = "taxid_unresolved"))
        }
    }

    # 2. Definir NOMBRES de tareas (Texto simple, no funciones pesadas)
    run_source <- function(src, announce = FALSE) {
        if (isTRUE(announce)) {
            emit_status(sprintf("\u2022 External DB: Querying %s...", as.character(source_labels[[src]] %||%
                src)))
        }
        if (src == "mygene") {
            return(query_mygene(gene, taxid))
        }
        if (src == "ncbi") {
            return(query_ncbi(gene, taxid))
        }
        if (src == "uniprot") {
            return(query_uniprot(gene, taxid))
        }
        if (src == "ensembl") {
            return(query_ensembl_with_species(gene, ensembl_species))
        }
        character(0)
    }

    run_source_safe <- function(src, announce = FALSE) {
        src_perf <- app_perf_new_run(sprintf("EXT_ALIAS_%s", toupper(as.character(src %||% "SRC"))))
        t0 <- as.numeric(proc.time()[["elapsed"]])
        app_perf_mark(src_perf, sprintf("start source=%s", as.character(src %||% "")), "EXT_ALIAS")
        tryCatch(
            {
                aliases <- as.character(run_source(src, announce = announce) %||% character(0))
                elapsed_ms <- round((as.numeric(proc.time()[["elapsed"]]) - t0) * 1000, 1)
                app_perf_mark(
                    src_perf,
                    sprintf("done source=%s aliases=%d elapsed_ms=%.1f", as.character(src %||% ""), as.integer(length(aliases[!is.na(aliases)])), elapsed_ms),
                    "EXT_ALIAS"
                )
                list(
                    source = as.character(src),
                    aliases = aliases[!is.na(aliases)],
                    error = "",
                    ok = TRUE,
                    elapsed_ms = elapsed_ms
                )
            },
            error = function(e) {
                err_msg <- format_lookup_error_message(e, source = source_labels[[src]] %||% src)
                elapsed_ms <- round((as.numeric(proc.time()[["elapsed"]]) - t0) * 1000, 1)
                message("[External Search Error] ", err_msg)
                app_perf_mark(src_perf, sprintf("error source=%s elapsed_ms=%.1f msg=%s", as.character(src %||% ""), elapsed_ms, err_msg), "EXT_ALIAS")
                emit_status(sprintf("\u2022 External DB %s failed; continuing with remaining sources.", as.character(source_labels[[src]] %||%
                    src)))
                list(
                    source = as.character(src),
                    aliases = character(0),
                    error = err_msg,
                    ok = FALSE,
                    elapsed_ms = elapsed_ms
                )
            }
        )
    }

    # 3. Ejecutar
    results <- list()
    selected_sources_text <- paste(unname(source_labels[sources]), collapse = ", ")

    if (isTRUE(use_parallel)) {
        emit_status(sprintf("\u2022 External DBs: Running in parallel (%s).", selected_sources_text))
        # MODO PARALELO LIGERO Enviamos solo strings ('ncbi', etc) y datos
        # simples (gene, taxid).  Esto evita que 'future' intente copiar toda
        # la memoria de la App.

        needed_globals <- c("query_mygene", "query_ncbi", "query_uniprot", "query_ensembl_with_species",
            "expand_gene_queries", "safe_get_json", "build_query_score_context",
            "as_query_score_context", "score_text_against_query", "score_alias_set",
            "normalize_match_token", "compact_match_token", "extract_query_alpha_core",
            "extract_query_digit_core", "is_stable_gene_identifier", "NCBI_EUTILS",
            "ENSEMBL_REST", "UNIPROT_REST", "collect_top_scored_matches",
            "flatten_alias_bundle", "collect_ensembl_aliases", "build_gene_query_plan",
            "is_strong_alias_score", "flatten_condition_messages",
            "format_lookup_error_message", "source_labels", "gene", "taxid", "ensembl_species")

        results <- tryCatch({
            future_map(sources, function(src) {
                t0 <- as.numeric(proc.time()[["elapsed"]])
                tryCatch(
                    {
                        aliases <- if (src == "mygene") {
                            query_mygene(gene, taxid)
                        } else if (src == "ncbi") {
                            query_ncbi(gene, taxid)
                        } else if (src == "uniprot") {
                            query_uniprot(gene, taxid)
                        } else if (src == "ensembl") {
                            query_ensembl_with_species(gene, ensembl_species)
                        } else {
                            character(0)
                        }
                        list(
                            source = as.character(src),
                            aliases = as.character(aliases %||% character(0)),
                            error = "",
                            ok = TRUE,
                            elapsed_ms = round((as.numeric(proc.time()[["elapsed"]]) - t0) * 1000, 1)
                        )
                    },
                    error = function(e) {
                        list(
                            source = as.character(src),
                            aliases = character(0),
                            error = format_lookup_error_message(e, source = source_labels[[src]] %||% src),
                            ok = FALSE,
                            elapsed_ms = round((as.numeric(proc.time()[["elapsed"]]) - t0) * 1000, 1)
                        )
                    }
                )
            }, .options = furrr_options(
                seed = FALSE,
                globals = needed_globals,
                packages = c("httr2", "jsonlite", "stringr", "dplyr", "purrr")
            ))
        }, error = function(e) {
            err_msg <- format_lookup_error_message(e)
            message("[External Search Error - Parallel] ", err_msg)
            app_perf_mark(lookup_perf, sprintf("parallel_fallback msg=%s", err_msg), "EXT_ALIAS")
            emit_status("\u2022 External DBs: Parallel run failed; retrying sequentially.")
            # Fallback secuencial
            purrr::map(sources, function(src) {
                run_source_safe(src, announce = TRUE)
            })
        })
    } else {
        emit_status(sprintf("\u2022 External DBs: Running sequentially (%s).",
            selected_sources_text))
        # MODO SECUENCIAL
        results <- tryCatch({
            purrr::map(sources, function(src) {
                run_source_safe(src, announce = TRUE)
            })
        }, error = function(e) {
            message("[External Search Error - Sequential] ", format_lookup_error_message(e))
            app_perf_mark(lookup_perf, sprintf("sequential_error msg=%s", format_lookup_error_message(e)), "EXT_ALIAS")
            emit_status("\u2022 External DBs: Lookup failed.")
            list()
        })
    }

    source_errors <- unlist(lapply(results, function(x) as.character(x$error %||% "")), use.names = FALSE)
    source_errors <- unique(trimws(source_errors[nzchar(source_errors)]))
    source_summaries <- vapply(results, function(x) {
        src <- as.character(x$source %||% "unknown")
        elapsed_ms <- suppressWarnings(as.numeric(x$elapsed_ms %||% NA_real_))
        alias_n <- length(as.character(x$aliases %||% character(0)))
        ok <- isTRUE(x$ok)
        sprintf(
            "%s:%s aliases=%d elapsed_ms=%s",
            src,
            ifelse(ok, "ok", "err"),
            as.integer(alias_n),
            ifelse(is.finite(elapsed_ms), sprintf("%.1f", elapsed_ms), "NA")
        )
    }, character(1))
    if (length(source_summaries) > 0) {
        summary_txt <- paste(source_summaries, collapse = " | ")
        app_perf_mark(lookup_perf, sprintf("source_summary %s", summary_txt), "EXT_ALIAS")
        app_debug_log("[EXT_ALIAS] ", summary_txt)
    }
    if (length(source_errors) > 0) {
        app_perf_mark(lookup_perf, sprintf("source_errors=%d", as.integer(length(source_errors))), "EXT_ALIAS")
        emit_status(sprintf("\u2022 External DBs: %d source(s) returned errors; continuing with successful matches.", length(source_errors)))
    }

    # 4. Limpiar + STRICT quality filter to prevent false-positive matches
    all_aliases <- unlist(lapply(results, function(x) as.character(x$aliases %||% character(0))), use.names = FALSE)
    all_aliases <- all_aliases[!is.na(all_aliases)]
    all_aliases <- trimws(all_aliases)
    all_aliases <- unique(all_aliases[all_aliases != ""])
    all_aliases <- all_aliases[tolower(all_aliases) != tolower(gene)]
    # all_aliases <- all_aliases[str_to_lower(all_aliases) !=
    # str_to_lower(gene)]

    # Blocklist: common noise tokens that appear in xref metadata but are NOT
    # gene identifiers
    noise_blocklist <- c("gene", "transcript", "protein", "mrna", "cdna", "uncharacterized protein",
        "hypothetical protein", "putative", "probable", "predicted", "unknown", "formerly entrezgene",
        "complete", "partial", "isoform", "protein_coding", "pseudogene")

    q_alpha <- extract_query_alpha_core(gene)
    q_digits <- extract_query_digit_core(gene)

    is_valid_alias <- function(a) {
        a_lower <- tolower(a)
        # Reject exact blocklist matches
        if (a_lower %in% noise_blocklist) {
            return(FALSE)
        }
        # Reject GO terms
        if (grepl("^GO:\\d+$", a)) {
            return(FALSE)
        }
        # Reject pure biological terms (multi-word phrases without gene-like
        # tokens)
        if (grepl("^[a-z ]+$", a_lower) && nchar(a) > 15) {
            return(FALSE)
        }
        # Reject long description-like strings (sentences with spaces)
        if (nchar(a) > 60) {
            return(FALSE)
        }
        # Reject chromosome accession-like patterns (CM000129, AP008210,
        # AL606691, etc.)
        if (grepl("^[A-Z]{2}\\d{6,}$", a)) {
            return(FALSE)
        }
        # Reject bare species names
        if (grepl("^[a-z]+_[a-z]+$", a_lower) && grepl("oryza|arabidopsis|homo|mus|drosophila|zea|triticum|solanum",
            a_lower)) {
            return(FALSE)
        }
        # Reject very short (<=2 chars) tokens
        if (nchar(a) <= 2) {
            return(FALSE)
        }
        # Reject pure integers
        if (grepl("^\\d+$", a)) {
            return(FALSE)
        }
        # If query is a specific gene-family member (e.g. hkt1;4), reject other
        # members of the same family (e.g. hkt7) unless they are stable gene
        # identifiers.
        a_comp <- compact_match_token(a)
        if (nzchar(q_alpha) && nzchar(q_digits) && !is_stable_gene_identifier(a)) {
            a_alpha <- gsub("[^a-z]+", "", a_comp)
            a_digits <- gsub("[^0-9]+", "", a_comp)
            if (identical(a_alpha, q_alpha) && nzchar(a_digits) && !identical(a_digits,
                q_digits)) {
                return(FALSE)
            }
        }
        TRUE
    }

    all_aliases <- Filter(is_valid_alias, all_aliases)

    # NUEVO: Guardar el resultado limpio en la cach\303\251 antes de retornar
    success_sources_n <- as.integer(sum(vapply(results, function(x) isTRUE(x$ok), logical(1)), na.rm = TRUE))
    failed_sources_n <- as.integer(sum(!vapply(results, function(x) isTRUE(x$ok), logical(1)), na.rm = TRUE))
    resultado_final <- with_lookup_meta(
        sort(all_aliases),
        had_errors = length(source_errors) > 0,
        source_errors = source_errors,
        source_summaries = source_summaries,
        skipped = FALSE,
        success_sources = success_sources_n,
        failed_sources = failed_sources_n
    )
    assign(cache_key, resultado_final, envir = .alias_memory_cache)
    touch_alias_cache_key(cache_key)
    trim_alias_memory_cache()
    app_perf_mark(
        lookup_perf,
        sprintf(
            "done aliases=%d success_sources=%d failed_sources=%d",
            as.integer(length(resultado_final)),
            success_sources_n,
            failed_sources_n
        ),
        "EXT_ALIAS"
    )

    return(resultado_final)
}
