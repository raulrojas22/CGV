init_go_domain <- function(
    goRegistry_rv,
    goRegistryStamp_rv,
    goQueryCache_env,
    goOnlineQueryCache_env,
    goSectionsPayloadCache_env,
    goTermNameMap_rv,
    goTermNameMapStamp_rv,
    preloadedRegistry_rv,
    normalize_annotation_key_fn
) {
    go_registry_file <- file.path("go_annotations", "registry.tsv")
    go_ontology_candidates <- c(
        file.path("go_annotations", "go-basic.obo"),
        file.path("go_annotations", "go-basic.obo.gz"),
        file.path("go_annotations", "go.obo"),
        file.path("go_annotations", "go.obo.gz"),
        file.path("go_annotations", "go-plus.obo"),
        file.path("go_annotations", "go-plus.obo.gz")
    )
    go_term_map_cache_file <- file.path("cache", "go_term_map.rds")
    go_term_map_cache_file_legacy <- file.path("go_annotations", "go_term_map.rds")

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

    normalize_go_text <- function(x) {
        y <- tolower(trimws(as.character(x %||% "")))
        y <- gsub("[^a-z0-9]+", " ", y)
        y <- gsub("\\s+", " ", y)
        trimws(y)
    }

    build_go_cache_key <- function(prefix, ...) {
        parts <- list(...)
        hash_txt <- if (requireNamespace("digest", quietly = TRUE)) {
            digest::digest(parts, algo = "xxhash64")
        } else {
            raw_txt <- paste(vapply(parts, function(part) {
                paste(as.character(part %||% ""), collapse = "\r")
            }, character(1)), collapse = "\n")
            raw_int <- utf8ToInt(enc2utf8(raw_txt))
            paste0(
                "fallback-",
                nchar(raw_txt, type = "bytes"),
                "-",
                sprintf("%.0f", sum(raw_int * seq_along(raw_int)))
            )
        }
        paste0(as.character(prefix %||% "go-cache"), "::", hash_txt)
    }

    extract_gcf_accession_from_text <- function(x) {
        txt <- as.character(x %||% "")
        m <- regexpr("GCF_[0-9]+\\.[0-9]+", txt, perl = TRUE, ignore.case = TRUE)
        if (length(m) == 0 || is.na(m[1]) || m[1] <= 0) {
            return("")
        }
        toupper(substr(txt, m[1], m[1] + attr(m, "match.length")[1] - 1))
    }

    load_go_registry_cached <- function(force = FALSE) {
        reg_path <- normalizePath(go_registry_file, winslash = "/", mustWork = FALSE)
        if (!file.exists(reg_path)) {
            goRegistry_rv(data.frame())
            goRegistryStamp_rv(NA_real_)
            return(data.frame())
        }

        finfo <- file.info(reg_path)
        stamp <- suppressWarnings(as.numeric(finfo$mtime[1]))
        old_stamp <- suppressWarnings(as.numeric(goRegistryStamp_rv()))
        if (!isTRUE(force) && is.finite(old_stamp) && is.finite(stamp) && identical(old_stamp, stamp) && nrow(goRegistry_rv()) > 0) {
            return(goRegistry_rv())
        }

        reg <- tryCatch(
            read.delim(reg_path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE),
            error = function(e) data.frame(stringsAsFactors = FALSE)
        )
        if (nrow(reg) == 0) {
            goRegistry_rv(data.frame())
            goRegistryStamp_rv(stamp)
            return(data.frame())
        }

        required_cols <- c(
            "species_id", "organism", "taxid", "source", "db_namespace",
            "gaf_file", "file_name", "gcf_accession", "priority", "is_primary"
        )
        for (nm in setdiff(required_cols, colnames(reg))) {
            reg[[nm]] <- NA_character_
        }

        reg$species_id <- trimws(as.character(reg$species_id %||% ""))
        reg$organism <- trimws(as.character(reg$organism %||% ""))
        reg$taxid <- suppressWarnings(as.integer(reg$taxid))
        reg$source <- trimws(as.character(reg$source %||% ""))
        reg$db_namespace <- trimws(as.character(reg$db_namespace %||% ""))
        reg$gcf_accession <- toupper(trimws(as.character(reg$gcf_accession %||% "")))
        reg$priority <- suppressWarnings(as.integer(reg$priority))
        reg$priority[!is.finite(reg$priority)] <- 999L
        reg$is_primary <- tolower(trimws(as.character(reg$is_primary %||% ""))) %in% c("true", "t", "1", "yes", "y")

        reg$gaf_abs_path <- vapply(as.character(reg$gaf_file %||% ""), function(p) {
            p <- trimws(as.character(p %||% ""))
            if (!nzchar(p)) {
                return("")
            }
            if (grepl("^/", p) || grepl("^[A-Za-z]:[/\\\\]", p)) {
                return(normalizePath(p, winslash = "/", mustWork = FALSE))
            }
            normalizePath(file.path(".", p), winslash = "/", mustWork = FALSE)
        }, character(1))
        reg$available <- vapply(reg$gaf_abs_path, function(p) {
            p <- as.character(p %||% "")
            nzchar(p) && file.exists(p)
        }, logical(1))

        reg <- reg[order(!reg$is_primary, reg$priority, reg$file_name), , drop = FALSE]
        row.names(reg) <- NULL
        goRegistry_rv(reg)
        goRegistryStamp_rv(stamp)
        reg
    }

    get_go_registry_current <- function() {
        load_go_registry_cached(force = FALSE)
    }

    resolve_go_ontology_path <- function() {
        for (p in go_ontology_candidates) {
            p_abs <- normalizePath(p, winslash = "/", mustWork = FALSE)
            if (file.exists(p_abs)) {
                return(p_abs)
            }
        }
        ""
    }

    parse_go_ontology_map <- function(obo_path) {
        if (!nzchar(as.character(obo_path %||% "")) || !file.exists(obo_path)) {
            return(character(0))
        }
        con <- if (grepl("\\.gz$", obo_path, ignore.case = TRUE)) gzfile(obo_path, open = "rt") else file(obo_path, open = "rt")
        on.exit(close(con), add = TRUE)

        env_map <- new.env(hash = TRUE, parent = emptyenv(), size = 60000L)
        current_id <- ""
        current_name <- ""
        current_obsolete <- FALSE
        in_term <- FALSE

        flush_term <- function() {
            if (isTRUE(in_term) && nzchar(current_id) && nzchar(current_name) && !isTRUE(current_obsolete)) {
                env_map[[current_id]] <- current_name
            }
            current_id <<- ""
            current_name <<- ""
            current_obsolete <<- FALSE
            in_term <<- FALSE
        }

        repeat {
            lines <- readLines(con, n = 60000L, warn = FALSE)
            if (length(lines) == 0) {
                break
            }
            for (ln in lines) {
                line <- trimws(as.character(ln %||% ""))
                if (!nzchar(line) || startsWith(line, "!")) next
                if (identical(line, "[Term]")) {
                    flush_term()
                    in_term <- TRUE
                    next
                }
                if (startsWith(line, "[")) {
                    flush_term()
                    next
                }
                if (!isTRUE(in_term)) next

                if (startsWith(line, "id: GO:")) {
                    current_id <- trimws(sub("^id:\\s*", "", line, perl = TRUE))
                } else if (startsWith(line, "name:")) {
                    if (!nzchar(current_name)) {
                        current_name <- trimws(sub("^name:\\s*", "", line, perl = TRUE))
                    }
                } else if (startsWith(line, "is_obsolete:")) {
                    val <- tolower(trimws(sub("^is_obsolete:\\s*", "", line, perl = TRUE)))
                    current_obsolete <- identical(val, "true")
                }
            }
        }
        flush_term()

        out_names <- ls(env_map, all.names = TRUE)
        if (length(out_names) == 0) {
            return(character(0))
        }
        out_vals <- unlist(mget(out_names, envir = env_map), use.names = FALSE)
        setNames(out_vals, out_names)
    }

    load_go_term_name_map_cached <- function(force = FALSE) {
        obo_path <- resolve_go_ontology_path()
        if (!nzchar(obo_path)) {
            goTermNameMap_rv(character(0))
            goTermNameMapStamp_rv("")
            return(character(0))
        }

        obo_mtime <- suppressWarnings(as.numeric(file.info(obo_path)$mtime[1]))
        stamp <- paste0(obo_path, "::", obo_mtime)
        old_stamp <- as.character(goTermNameMapStamp_rv() %||% "")
        if (!isTRUE(force) && identical(old_stamp, stamp)) {
            return(goTermNameMap_rv())
        }

        loaded_from_rds <- FALSE
        map <- character(0)
        cache_candidates <- unique(c(
            normalizePath(go_term_map_cache_file, winslash = "/", mustWork = FALSE),
            normalizePath(go_term_map_cache_file_legacy, winslash = "/", mustWork = FALSE)
        ))
        for (rds_path in cache_candidates) {
            if (!file.exists(rds_path)) {
                next
            }
            rds_obj <- tryCatch(readRDS(rds_path), error = function(e) NULL)
            if (is.list(rds_obj) && !is.null(rds_obj$map)) {
                src_file <- normalizePath(as.character(rds_obj$source_file %||% ""), winslash = "/", mustWork = FALSE)
                src_mtime <- suppressWarnings(as.numeric(rds_obj$source_mtime %||% NA_real_))
                if (identical(src_file, obo_path) && is.finite(src_mtime) && is.finite(obo_mtime) && identical(src_mtime, obo_mtime)) {
                    map <- as.character(rds_obj$map %||% character(0))
                    loaded_from_rds <- TRUE
                    break
                }
            }
        }

        if (!loaded_from_rds) {
            map <- parse_go_ontology_map(obo_path)
            rds_path <- normalizePath(go_term_map_cache_file, winslash = "/", mustWork = FALSE)
            cache_dir <- dirname(rds_path)
            dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
            if (dir.exists(cache_dir) && file.access(cache_dir, mode = 2) == 0) {
                suppressWarnings(tryCatch(
                    saveRDS(
                        list(
                            source_file = obo_path,
                            source_mtime = obo_mtime,
                            map = map
                        ),
                        file = rds_path,
                        compress = "gzip"
                    ),
                    error = function(e) NULL
                ))
            }
        }

        goTermNameMap_rv(map)
        goTermNameMapStamp_rv(stamp)
        map
    }

    get_go_term_name_map_current <- function() {
        load_go_term_name_map_cached(force = FALSE)
    }

    attach_go_term_names <- function(term_df) {
        td <- term_df
        if (is.null(td) || nrow(td) == 0) {
            return(td)
        }
        td$go_name <- rep("", nrow(td))
        term_map <- get_go_term_name_map_current()
        if (length(term_map) == 0) {
            return(td)
        }
        idx <- match(as.character(td$go_id %||% ""), names(term_map))
        valid <- is.finite(idx) & !is.na(idx)
        if (any(valid)) {
            td$go_name[valid] <- as.character(term_map[idx[valid]] %||% "")
        }
        td
    }

    resolve_go_registry_entry <- function(annotation_path = "", organism_name = "") {
        reg <- get_go_registry_current()
        if (nrow(reg) == 0) {
            return(NULL)
        }
        reg <- reg[as.logical(reg$available), , drop = FALSE]
        if (nrow(reg) == 0) {
            return(NULL)
        }

        ann_key <- normalize_annotation_key_safe(annotation_path)
        species_id <- ""
        if (nzchar(ann_key)) {
            pre <- preloadedRegistry_rv()
            if (!is.null(pre) && nrow(pre) > 0 && "annotation_path" %in% colnames(pre) && "species_id" %in% colnames(pre)) {
                pre_ann <- vapply(as.character(pre$annotation_path %||% ""), normalize_annotation_key_safe, character(1))
                hit <- which(pre_ann == ann_key)
                if (length(hit) > 0) {
                    species_id <- as.character(pre$species_id[hit[1]] %||% "")
                }
            }
        }

        gcf <- extract_gcf_accession_from_text(annotation_path)
        org_norm <- normalize_go_text(organism_name)
        org_norm <- as.character(org_norm[1] %||% "")
        rows <- reg
        if (nzchar(species_id)) {
            rows <- rows[as.character(rows$species_id) == species_id, , drop = FALSE]
        }
        if (nrow(rows) == 0 && nzchar(gcf)) {
            rows <- reg[toupper(as.character(reg$gcf_accession %||% "")) == gcf, , drop = FALSE]
        }
        if (nrow(rows) == 0 && nzchar(org_norm)) {
            org_vec <- normalize_go_text(as.character(reg$organism %||% ""))
            org_in_vec <- grepl(org_norm, org_vec, fixed = TRUE)
            vec_in_org <- vapply(org_vec, function(v) {
                v <- as.character(v %||% "")
                nzchar(v) && grepl(v, org_norm, fixed = TRUE)
            }, logical(1))
            hit <- which(nzchar(org_vec) & (org_vec == org_norm | org_in_vec | vec_in_org))
            if (length(hit) > 0) {
                rows <- reg[hit, , drop = FALSE]
            }
        }
        if (nrow(rows) == 0) {
            return(NULL)
        }
        rows <- rows[order(!rows$is_primary, rows$priority, rows$file_name), , drop = FALSE]
        rows[1, , drop = FALSE]
    }

    resolve_taxid_for_go_lookup <- function(annotation_path = "", organism_name = "") {
        ann_key <- normalize_annotation_key_safe(annotation_path)
        if (nzchar(ann_key)) {
            pre <- preloadedRegistry_rv()
            if (!is.null(pre) && nrow(pre) > 0 && "annotation_path" %in% colnames(pre) && "taxid" %in% colnames(pre)) {
                pre_ann <- vapply(as.character(pre$annotation_path %||% ""), normalize_annotation_key_safe, character(1))
                hit <- which(pre_ann == ann_key)
                if (length(hit) > 0) {
                    tid <- suppressWarnings(as.integer(pre$taxid[hit[1]] %||% NA_integer_))
                    if (is.finite(tid) && !is.na(tid) && tid > 0) {
                        return(tid)
                    }
                }
            }
        }

        det <- tryCatch(
            detect_organism_from_gff(
                file_path = as.character(annotation_path %||% ""),
                original_name = as.character(organism_name %||% basename(annotation_path %||% ""))
            ),
            error = function(e) NULL
        )
        tid <- suppressWarnings(as.integer(det$taxid %||% NA_integer_))
        if (is.finite(tid) && !is.na(tid) && tid > 0) {
            return(tid)
        }
        NA_integer_
    }

    safe_mygene_query <- function(q, species = "", size = 6L, timeout_sec = 5L) {
        query_txt <- trimws(as.character(q %||% ""))
        if (!nzchar(query_txt)) {
            return(NULL)
        }
        req <- httr2::request("https://mygene.info/v3/query") %>%
            httr2::req_user_agent("CGV-GO-Fallback/1.0")

        query_params <- list(
            q = query_txt,
            fields = "symbol,name,taxid,entrezgene,go.BP,go.MF,go.CC",
            size = as.integer(size)
        )
        species_txt <- trimws(as.character(species %||% ""))
        if (nzchar(species_txt)) {
            query_params$species <- species_txt
        }

        req <- httr2::req_url_query(req, !!!query_params)
        req <- httr2::req_timeout(req, as.numeric(timeout_sec))

        resp <- tryCatch(httr2::req_perform(req), error = function(e) NULL)
        if (is.null(resp)) {
            return(NULL)
        }
        if (httr2::resp_status(resp) >= 400) {
            return(NULL)
        }
        txt <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")
        if (!nzchar(txt)) {
            return(NULL)
        }
        tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE), error = function(e) NULL)
    }

    normalize_mygene_go_entries <- function(x) {
        if (is.null(x)) {
            return(list())
        }
        if (is.list(x) && !is.null(x$id)) {
            return(list(x))
        }
        if (is.list(x) && length(x) > 0 && is.list(x[[1]])) {
            return(x)
        }
        list()
    }

    extract_go_rows_from_mygene_hit <- function(hit) {
        out <- data.frame(
            db = character(),
            object_id = character(),
            symbol = character(),
            qualifier = character(),
            go_id = character(),
            go_name = character(),
            reference = character(),
            evidence = character(),
            aspect = character(),
            assigned_by = character(),
            date = character(),
            stringsAsFactors = FALSE
        )
        if (is.null(hit) || !is.list(hit)) {
            return(out)
        }
        go_block <- hit$go
        if (is.null(go_block) || !is.list(go_block)) {
            return(out)
        }

        object_id <- as.character(hit$entrezgene %||% hit$`_id` %||% "")
        symbol <- as.character(hit$symbol %||% "")
        source <- as.character(hit$taxid %||% "")
        assigned_by <- "MyGene.info"
        if (nzchar(source)) {
            assigned_by <- sprintf("MyGene.info taxid=%s", source)
        }

        aspect_map <- c("BP" = "P", "MF" = "F", "CC" = "C")
        rows <- list()
        idx <- 0L

        for (src_aspect in names(aspect_map)) {
            entries <- normalize_mygene_go_entries(go_block[[src_aspect]])
            if (length(entries) == 0) next
            for (ent in entries) {
                go_id <- trimws(as.character(ent$id %||% ""))
                if (!grepl("^GO:[0-9]+$", go_id)) next

                term_name <- trimws(as.character(ent$term %||% ""))
                evidence <- trimws(as.character(ent$evidence %||% ""))
                ref <- ""
                if (!is.null(ent$pubmed)) {
                    pm <- unlist(ent$pubmed, use.names = FALSE)
                    pm <- unique(trimws(as.character(pm %||% character(0))))
                    pm <- pm[nzchar(pm)]
                    if (length(pm) > 0) {
                        ref <- paste(paste0("PMID:", pm), collapse = ", ")
                    }
                }

                idx <- idx + 1L
                rows[[idx]] <- data.frame(
                    db = "MyGene.info",
                    object_id = object_id,
                    symbol = symbol,
                    qualifier = "",
                    go_id = go_id,
                    go_name = term_name,
                    reference = ref,
                    evidence = evidence,
                    aspect = aspect_map[[src_aspect]],
                    assigned_by = assigned_by,
                    date = "",
                    stringsAsFactors = FALSE
                )
            }
        }

        if (length(rows) == 0) {
            return(out)
        }
        dplyr::bind_rows(rows) %>%
            dplyr::distinct(aspect, go_id, go_name, evidence, reference, .keep_all = TRUE)
    }

    fetch_online_go_terms_with_cache <- function(candidates, gene_hint = "", organism_name = "", taxid = NA_integer_) {
        empty_df <- data.frame(
            db = character(),
            object_id = character(),
            symbol = character(),
            qualifier = character(),
            go_id = character(),
            go_name = character(),
            reference = character(),
            evidence = character(),
            aspect = character(),
            assigned_by = character(),
            date = character(),
            stringsAsFactors = FALSE
        )

        ids <- unique(trimws(as.character(candidates$object_ids %||% character(0))))
        ids <- ids[nzchar(ids)]
        syms <- unique(trimws(as.character(candidates$symbols %||% character(0))))
        syms <- syms[nzchar(syms)]
        gene_txt <- trimws(as.character(gene_hint %||% ""))
        org_txt <- trimws(as.character(organism_name %||% ""))
        tid <- suppressWarnings(as.integer(taxid %||% NA_integer_))

        if (length(ids) == 0 && length(syms) == 0 && !nzchar(gene_txt)) {
            return(empty_df)
        }

        cache_key <- paste(
            "mygene",
            if (is.finite(tid) && !is.na(tid) && tid > 0) as.character(tid) else normalize_go_text(org_txt),
            paste(sort(ids), collapse = "|"),
            paste(sort(tolower(syms)), collapse = "|"),
            tolower(gene_txt),
            sep = "||"
        )

        cached_online <- cache_env_get(goOnlineQueryCache_env, cache_key, default = NULL)
        if (!is.null(cached_online)) {
            return(cached_online)
        }

        species_param <- if (is.finite(tid) && !is.na(tid) && tid > 0) {
            as.character(tid)
        } else if (nzchar(org_txt)) {
            org_txt
        } else {
            ""
        }

        numeric_ids <- ids[grepl("^[0-9]+$", ids)]
        symbol_queries <- unique(c(
            if (nzchar(gene_txt)) gene_txt else character(0),
            syms
        ))
        symbol_queries <- symbol_queries[nzchar(symbol_queries)]

        query_list <- character(0)
        if (length(numeric_ids) > 0) {
            query_list <- c(query_list, paste0("entrezgene:", numeric_ids))
        }
        if (length(symbol_queries) > 0) {
            query_list <- c(query_list, paste0("symbol:", symbol_queries))
        }
        query_list <- unique(query_list)
        if (length(query_list) > 8L) {
            query_list <- query_list[seq_len(8L)]
        }

        collected <- list()
        idx <- 0L
        for (q in query_list) {
            payload <- safe_mygene_query(q = q, species = species_param, size = 6L, timeout_sec = 5L)
            if (is.null(payload) || is.null(payload$hits) || !is.list(payload$hits) || length(payload$hits) == 0) {
                next
            }
            for (hit in payload$hits) {
                rows <- extract_go_rows_from_mygene_hit(hit)
                if (nrow(rows) == 0) next
                idx <- idx + 1L
                collected[[idx]] <- rows
            }
            if (idx >= 6L) break
        }

        out <- if (length(collected) == 0) {
            empty_df
        } else {
            dplyr::bind_rows(collected) %>%
                dplyr::filter(grepl("^GO:[0-9]+$", go_id)) %>%
                dplyr::distinct(aspect, go_id, go_name, evidence, reference, .keep_all = TRUE)
        }

        # Bounded env cache: max_size keeps long sessions from growing without limit.
        cache_env_set(goOnlineQueryCache_env, cache_key, out, max_size = 240L)
        out
    }

    extract_go_candidates_from_plot_data <- function(plot_data, gene_label = "") {
        empty_out <- list(
            object_ids = character(0),
            symbols = character(0),
            gene_ids = character(0)
        )
        if (is.null(plot_data) || nrow(plot_data) == 0 || !("V9" %in% colnames(plot_data))) {
            return(empty_out)
        }

        clean_token <- function(x) {
            y <- trimws(as.character(x %||% ""))
            if (length(y) == 0 || !nzchar(y)) {
                return("")
            }
            y <- safe_url_decode(y)
            y <- trimws(gsub("[\"']", "", y))
            y <- sub("^(gene|transcript|mrna)\\s*:\\s*", "", y, ignore.case = TRUE, perl = TRUE)
            trimws(y)
        }

        split_tokens <- function(values) {
            vals <- as.character(values %||% character(0))
            if (length(vals) == 0) {
                return(character(0))
            }
            vals <- vals[!is.na(vals) & nzchar(trimws(vals))]
            if (length(vals) == 0) {
                return(character(0))
            }
            raw <- unique(c(vals, unlist(strsplit(vals, "[,|]", perl = TRUE), use.names = FALSE)))
            raw <- trimws(raw)
            raw[nzchar(raw)]
        }

        row_types <- tolower(trimws(as.character(plot_data$V3 %||% rep("", nrow(plot_data)))))
        tx_types <- c(
            "mrna", "transcript", "lnc_rna", "trna", "rrna", "snorna", "snrna", "mirna",
            "ncrna", "primary_transcript", "pre_mirna", "guide_rna", "rnase_p_rna",
            "rnase_mrp_rna", "telomerase_rna", "antisense_rna", "srp_rna", "scarna",
            "vault_rna", "y_rna", "antisense_lncrna", "lncrna"
        )
        idx <- unique(c(which(row_types == "gene"), which(row_types %in% tx_types)))
        if (length(idx) == 0) idx <- seq_len(min(8L, nrow(plot_data)))
        idx <- idx[seq_len(min(length(idx), 12L))]

        candidate_values <- c(gene_label)
        for (j in idx) {
            attr <- as.character(plot_data$V9[j] %||% "")
            attrs <- parse_gff_attributes(attr)
            keys <- c("id", "name", "gene", "gene_name", "gene_id", "gene_symbol", "symbol", "locus_tag", "transcript_id", "protein_id", "gene_synonym", "alias")
            for (k in keys) {
                vals <- attrs[[k]]
                if (!is.null(vals) && length(vals) > 0) candidate_values <- c(candidate_values, vals)
            }
            dbx <- attrs[["dbxref"]]
            if (!is.null(dbx) && length(dbx) > 0) {
                dbx_toks <- split_tokens(dbx)
                candidate_values <- c(candidate_values, dbx_toks)
                for (tok in dbx_toks) {
                    if (grepl(":", tok, fixed = TRUE)) {
                        rhs <- sub("^[^:]+:", "", tok)
                        candidate_values <- c(candidate_values, rhs)
                    }
                }
            }
            candidate_values <- c(candidate_values, extract_primary_gene_id(attr), extract_primary_gene_name(attr))
        }

        candidate_values <- vapply(candidate_values, clean_token, character(1))
        candidate_values <- unique(candidate_values[nzchar(candidate_values)])
        if (length(candidate_values) == 0) {
            return(empty_out)
        }

        gene_id_hits <- unique(unlist(regmatches(candidate_values, gregexpr("(?i)(?:GeneID|NCBIGeneID):[0-9]+", candidate_values, perl = TRUE)), use.names = FALSE))
        gene_id_hits <- sub("(?i)^(?:GeneID|NCBIGeneID):", "", gene_id_hits, perl = TRUE)
        gene_id_hits <- unique(gene_id_hits[grepl("^[0-9]+$", gene_id_hits)])

        token_from_colon <- candidate_values[grepl(":", candidate_values, fixed = TRUE)]
        token_from_colon <- sub("^[^:]+:", "", token_from_colon)
        raw_ids <- unique(c(candidate_values, token_from_colon, gene_id_hits))
        raw_ids <- trimws(raw_ids)
        raw_ids <- raw_ids[nzchar(raw_ids)]
        raw_ids <- raw_ids[nchar(raw_ids) <= 80]
        raw_ids <- raw_ids[grepl("^[A-Za-z0-9][A-Za-z0-9._:-]*$", raw_ids)]

        stop_ids <- c("gene", "transcript", "mrna", "rna", "na", "n/a", "unknown")
        keep_ids <- !(tolower(raw_ids) %in% stop_ids)
        object_ids <- unique(raw_ids[keep_ids])
        object_ids <- unique(c(gene_id_hits, object_ids))

        raw_symbols <- c(gene_label, candidate_values)
        raw_symbols <- trimws(raw_symbols)
        raw_symbols <- raw_symbols[nzchar(raw_symbols)]
        raw_symbols <- raw_symbols[nchar(raw_symbols) <= 60]
        raw_symbols <- raw_symbols[grepl("[A-Za-z]", raw_symbols)]
        raw_symbols <- raw_symbols[!grepl("\\s{2,}", raw_symbols)]
        symbols <- unique(raw_symbols)

        list(
            object_ids = object_ids,
            symbols = symbols,
            gene_ids = gene_id_hits
        )
    }

    scan_gaf_for_candidates <- function(gaf_path, db_namespace = "", candidate_object_ids = character(0), candidate_symbols = character(0), max_hits = 1200L) {
        out <- data.frame(
            db = character(),
            object_id = character(),
            symbol = character(),
            qualifier = character(),
            go_id = character(),
            reference = character(),
            evidence = character(),
            aspect = character(),
            assigned_by = character(),
            date = character(),
            stringsAsFactors = FALSE
        )
        if (!nzchar(as.character(gaf_path %||% "")) || !file.exists(gaf_path)) {
            return(out)
        }

        object_ids <- unique(trimws(as.character(candidate_object_ids %||% character(0))))
        object_ids <- object_ids[nzchar(object_ids)]
        symbols_lc <- unique(tolower(trimws(as.character(candidate_symbols %||% character(0)))))
        symbols_lc <- symbols_lc[nzchar(symbols_lc)]
        if (length(object_ids) == 0 && length(symbols_lc) == 0) {
            return(out)
        }

        ns_filter <- tolower(trimws(as.character(db_namespace %||% "")))
        max_hits <- max(50L, as.integer(max_hits))

        search_terms <- unique(c(object_ids, symbols_lc))
        search_terms <- gsub("([.\\^$*+?()[{\\\\|])", "\\\\\\1", search_terms)
        fast_pattern <- paste0("(?i)\\b(?:", paste(search_terms, collapse = "|"), ")\\b")

        con <- if (grepl("\\.gz$", gaf_path, ignore.case = TRUE)) gzfile(gaf_path, open = "rt") else file(gaf_path, open = "rt")
        on.exit(close(con), add = TRUE)

        chunks <- list()
        idx_chunk <- 0L
        hit_count <- 0L
        repeat {
            lines <- readLines(con, n = 50000L, warn = FALSE)
            if (length(lines) == 0) break
            lines <- lines[nzchar(lines) & !startsWith(lines, "!")]
            if (length(lines) == 0) next

            keep_idx <- grepl(fast_pattern, lines, perl = TRUE)
            lines <- lines[keep_idx]
            if (length(lines) == 0) next

            for (ln in lines) {
                fields <- strsplit(ln, "\t", fixed = TRUE)[[1]]
                if (length(fields) < 9L) next
                db <- trimws(as.character(fields[1] %||% ""))
                if (nzchar(ns_filter) && tolower(db) != ns_filter) next

                obj_id <- trimws(as.character(fields[2] %||% ""))
                sym <- trimws(as.character(fields[3] %||% ""))
                match_obj <- nzchar(obj_id) && obj_id %in% object_ids
                match_sym <- nzchar(sym) && tolower(sym) %in% symbols_lc
                if (!match_obj && !match_sym) next

                idx_chunk <- idx_chunk + 1L
                chunks[[idx_chunk]] <- data.frame(
                    db = db,
                    object_id = obj_id,
                    symbol = sym,
                    qualifier = trimws(as.character(fields[4] %||% "")),
                    go_id = trimws(as.character(fields[5] %||% "")),
                    reference = trimws(as.character(fields[6] %||% "")),
                    evidence = trimws(as.character(fields[7] %||% "")),
                    aspect = toupper(trimws(as.character(fields[9] %||% ""))),
                    assigned_by = trimws(as.character(if (length(fields) >= 15L) fields[15] else "")),
                    date = trimws(as.character(if (length(fields) >= 14L) fields[14] else "")),
                    stringsAsFactors = FALSE
                )
                hit_count <- hit_count + 1L
                if (hit_count >= max_hits) break
            }
            if (hit_count >= max_hits) break
        }

        if (length(chunks) == 0) {
            return(out)
        }
        out <- dplyr::bind_rows(chunks)
        out %>%
            dplyr::filter(grepl("^GO:[0-9]+$", go_id)) %>%
            dplyr::distinct(db, object_id, symbol, qualifier, go_id, reference, evidence, aspect, assigned_by, date, .keep_all = TRUE)
    }

    get_go_terms_with_cache <- function(go_entry_row, candidates) {
        empty_df <- data.frame(
            db = character(),
            object_id = character(),
            symbol = character(),
            qualifier = character(),
            go_id = character(),
            reference = character(),
            evidence = character(),
            aspect = character(),
            assigned_by = character(),
            date = character(),
            stringsAsFactors = FALSE
        )
        if (is.null(go_entry_row) || nrow(go_entry_row) == 0) {
            return(empty_df)
        }

        gaf_path <- as.character(go_entry_row$gaf_abs_path[1] %||% "")
        if (!nzchar(gaf_path) || !file.exists(gaf_path)) {
            return(empty_df)
        }

        obj_ids <- unique(as.character(candidates$object_ids %||% character(0)))
        symbols <- unique(as.character(candidates$symbols %||% character(0)))
        if (length(obj_ids) == 0 && length(symbols) == 0) {
            return(empty_df)
        }

        mtime <- suppressWarnings(as.numeric(file.info(gaf_path)$mtime[1]))
        db_ns <- as.character(go_entry_row$db_namespace[1] %||% "")
        cache_key <- build_go_cache_key(
            "go-query-v1",
            gaf_path,
            mtime,
            tolower(db_ns),
            sort(obj_ids),
            sort(tolower(symbols))
        )

        cached_terms <- cache_env_get(goQueryCache_env, cache_key, default = NULL)
        if (!is.null(cached_terms)) {
            return(cached_terms)
        }

        terms <- scan_gaf_for_candidates(
            gaf_path = gaf_path,
            db_namespace = db_ns,
            candidate_object_ids = obj_ids,
            candidate_symbols = symbols
        )
        if (nrow(terms) == 0 && nzchar(db_ns)) {
            terms <- scan_gaf_for_candidates(
                gaf_path = gaf_path,
                db_namespace = "",
                candidate_object_ids = obj_ids,
                candidate_symbols = symbols
            )
        }

        cache_env_set(goQueryCache_env, cache_key, terms, max_size = 240L)
        terms
    }

    build_go_sections_payload <- function(term_df, per_aspect_limit = 30L) {
        empty_out <- list(total = 0L, truncated = FALSE, sections = I(list()))
        if (is.null(term_df) || nrow(term_df) == 0) {
            return(empty_out)
        }

        go_term_df_fingerprint <- function(df) {
            if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
                return("0::empty")
            }
            key_cols <- intersect(
                c("db", "object_id", "symbol", "qualifier", "go_id", "go_name", "reference", "evidence", "aspect", "assigned_by", "date"),
                names(df)
            )
            if (length(key_cols) == 0L) {
                key_cols <- names(df)
            }
            compact_df <- df[, key_cols, drop = FALSE]
            paste0(
                nrow(df),
                "::",
                build_go_cache_key("go-sections-fingerprint-v1", compact_df)
            )
        }

        lim <- max(5L, as.integer(per_aspect_limit))
        payload_cache_key <- build_go_cache_key(
            "go-sections-v1",
            as.character(goTermNameMapStamp_rv() %||% ""),
            as.integer(lim),
            go_term_df_fingerprint(term_df)
        )
        cached_payload <- cache_env_get(goSectionsPayloadCache_env, payload_cache_key, default = NULL)
        if (is.list(cached_payload) && !is.null(cached_payload$sections)) {
            return(cached_payload)
        }

        td <- attach_go_term_names(term_df) %>%
            dplyr::mutate(
                go_id = trimws(as.character(go_id %||% "")),
                go_name = trimws(as.character(go_name %||% "")),
                aspect = toupper(trimws(as.character(aspect %||% ""))),
                qualifier = trimws(as.character(qualifier %||% "")),
                evidence = trimws(as.character(evidence %||% "")),
                assigned_by = trimws(as.character(assigned_by %||% "")),
                reference = trimws(as.character(reference %||% ""))
            ) %>%
            dplyr::filter(grepl("^GO:[0-9]+$", go_id)) %>%
            dplyr::distinct(aspect, go_id, go_name, qualifier, evidence, assigned_by, reference, .keep_all = TRUE)

        if (nrow(td) == 0) {
            return(empty_out)
        }
        raw_total <- as.integer(nrow(td))

        aspect_labels <- c(
            "P" = "Biological Process",
            "F" = "Molecular Function",
            "C" = "Cellular Component"
        )
        code_order <- c("P", "F", "C")
        extra_codes <- setdiff(unique(td$aspect), code_order)
        all_codes <- c(code_order, sort(extra_codes))

        sections <- list()
        any_truncated <- FALSE

        for (code in all_codes) {
            sub <- td[td$aspect == code, , drop = FALSE]
            if (nrow(sub) == 0) next

            agg <- sub %>%
                dplyr::group_by(go_id) %>%
                dplyr::summarise(
                    go_name = {
                        vals <- unique(go_name[nzchar(go_name)])
                        if (length(vals) > 0) vals[1] else ""
                    },
                    qualifier = paste(unique(qualifier[nzchar(qualifier)]), collapse = ", "),
                    evidence = paste(unique(evidence[nzchar(evidence)]), collapse = ", "),
                    assigned_by = paste(unique(assigned_by[nzchar(assigned_by)]), collapse = ", "),
                    reference = paste(unique(reference[nzchar(reference)]), collapse = ", "),
                    .groups = "drop"
                ) %>%
                dplyr::arrange(go_id)

            total <- nrow(agg)
            shown <- min(total, lim)
            if (total > shown) any_truncated <- TRUE

            idx_all <- seq_len(total)
            items_list <- I(lapply(idx_all, function(k) {
                list(
                    go_id = as.character(agg$go_id[k] %||% ""),
                    go_name = as.character(agg$go_name[k] %||% ""),
                    go_url = paste0("https://amigo.geneontology.org/amigo/term/", as.character(agg$go_id[k] %||% "")),
                    qualifier = as.character(agg$qualifier[k] %||% ""),
                    evidence = as.character(agg$evidence[k] %||% ""),
                    assigned_by = as.character(agg$assigned_by[k] %||% ""),
                    reference = as.character(agg$reference[k] %||% "")
                )
            }))

            sections[[length(sections) + 1L]] <- list(
                code = as.character(code),
                label = as.character(aspect_labels[[code]] %||% paste0("Aspect ", code)),
                total = as.integer(total),
                shown = as.integer(shown),
                step = as.integer(lim),
                truncated = isTRUE(total > shown),
                items = items_list
            )
        }

        unique_total <- if (length(sections) == 0L) {
            0L
        } else {
            as.integer(sum(vapply(sections, function(sec) {
                as.integer(sec$total %||% 0L)
            }, integer(1)), na.rm = TRUE))
        }

        out_payload <- list(
            total = unique_total,
            raw_total = raw_total,
            truncated = isTRUE(any_truncated),
            sections = I(unname(sections))
        )
        # Payload cache is also bounded; this avoids reopening already-resolved GO sections work.
        cache_env_set(goSectionsPayloadCache_env, payload_cache_key, out_payload, max_size = 128L)
        out_payload
    }

    list(
        normalize_go_text = normalize_go_text,
        extract_gcf_accession_from_text = extract_gcf_accession_from_text,
        load_go_registry_cached = load_go_registry_cached,
        get_go_registry_current = get_go_registry_current,
        resolve_go_ontology_path = resolve_go_ontology_path,
        parse_go_ontology_map = parse_go_ontology_map,
        load_go_term_name_map_cached = load_go_term_name_map_cached,
        get_go_term_name_map_current = get_go_term_name_map_current,
        attach_go_term_names = attach_go_term_names,
        resolve_go_registry_entry = resolve_go_registry_entry,
        resolve_taxid_for_go_lookup = resolve_taxid_for_go_lookup,
        safe_mygene_query = safe_mygene_query,
        normalize_mygene_go_entries = normalize_mygene_go_entries,
        extract_go_rows_from_mygene_hit = extract_go_rows_from_mygene_hit,
        fetch_online_go_terms_with_cache = fetch_online_go_terms_with_cache,
        extract_go_candidates_from_plot_data = extract_go_candidates_from_plot_data,
        scan_gaf_for_candidates = scan_gaf_for_candidates,
        get_go_terms_with_cache = get_go_terms_with_cache,
        build_go_sections_payload = build_go_sections_payload
    )
}
