# ==============================================================================
# R/utils.R
# Funciones auxiliares para manejo de secuencias, GFF, FASTA y búsqueda de genes.
# Actualizado para integración con gene_search_lib.R y control de paralelismo.
# ==============================================================================

# Operador null-coalescing simple: devuelve `a` si no es NULL, sino `b`.
# ATENCION: no protege contra vectores vacíos, NA ni strings "".
# Usar para argumentos de función donde solo importa distinguir NULL vs. valor.
# Ver también %|||% para una validación más estricta.
`%||%` <- function(a, b) if (!is.null(a)) a else b

# Lightweight debug/performance toggles.
# Disabled by default. Enable explicitly with:
# Sys.setenv(APP_DEBUG_LOGS = "1", APP_PERF_TIMING = "1")
app_debug_enabled <- function() {
    raw <- tolower(trimws(as.character(Sys.getenv("APP_DEBUG_LOGS", "0") %||% "0")))
    !raw %in% c("", "0", "false", "no", "off")
}

app_perf_enabled <- function() {
    raw <- tolower(trimws(as.character(Sys.getenv("APP_PERF_TIMING", Sys.getenv("APP_DEBUG_LOGS", "0")) %||% "0")))
    !raw %in% c("", "0", "false", "no", "off")
}

app_debug_log <- function(..., .sep = "") {
    if (!isTRUE(app_debug_enabled())) {
        return(invisible(FALSE))
    }
    message(paste0(..., collapse = .sep))
    invisible(TRUE)
}

app_perf_new_run <- function(prefix = "RUN") {
    ts <- format(Sys.time(), "%H%M%OS3")
    ts <- gsub("[^0-9]", "", ts)
    list(
        id = paste0(as.character(prefix %||% "RUN"), "-", ts),
        t0 = as.numeric(proc.time()[["elapsed"]])
    )
}

app_perf_mark <- function(run = NULL, step = "", context = "APP") {
    if (!isTRUE(app_perf_enabled())) {
        return(invisible(NA_real_))
    }
    now <- as.numeric(proc.time()[["elapsed"]])
    run_id <- "-"
    elapsed <- NA_real_
    if (is.list(run)) {
        if (!is.null(run$id)) {
            run_id <- as.character(run$id)
        }
        t0 <- suppressWarnings(as.numeric(run$t0 %||% NA_real_))
        if (is.finite(t0)) {
            elapsed <- now - t0
        }
    }
    head <- sprintf("[PERF][%s][%s]", as.character(context %||% "APP"), run_id)
    if (is.finite(elapsed)) {
        head <- sprintf("%s[+%.3fs]", head, elapsed)
    }
    msg <- trimws(as.character(step %||% ""))
    if (!nzchar(msg)) {
        msg <- "tick"
    }
    app_debug_log(head, " ", msg)
    invisible(elapsed)
}

# --- 1. ANÁLISIS DE SECUENCIAS ---

calculate_sequence_composition <- function(gen_sequence) {
    if (is.null(gen_sequence) || length(gen_sequence) == 0 || is.na(gen_sequence) || gen_sequence == "") {
        return(list(composition = "Sequence Composition: N/A (Sequence empty)", length = 0))
    }
    gen_sequence <- toupper(as.character(gen_sequence[[1]] %||% ""))
    longitud_total <- nchar(gen_sequence)
    conteo_A <- nchar(gsub("[^A]", "", gen_sequence))
    conteo_T <- nchar(gsub("[^T]", "", gen_sequence))
    conteo_C <- nchar(gsub("[^C]", "", gen_sequence))
    conteo_G <- nchar(gsub("[^G]", "", gen_sequence))

    list(
        composition = sprintf(
            "Sequence Composition: A = %.2f%%\tT = %.2f%%  C = %.2f%%  G = %.2f%%",
            (conteo_A / longitud_total) * 100, (conteo_T / longitud_total) * 100,
            (conteo_C / longitud_total) * 100, (conteo_G / longitud_total) * 100
        ),
        length = longitud_total
    )
}

# --- 2. DETECCIÓN DE ORGANISMO Y GESTIÓN DE GENOMAS ---

detect_organism_from_gff <- function(file_path, original_name = NULL) {
    lines <- tryCatch(readLines(file_path, n = 200, warn = FALSE), error = function(e) character())
    text <- paste(lines, collapse = "\n")

    organism_name <- NULL
    taxid_val <- NULL

    taxid_match <- str_match(text, regex("taxon:(\\d+)|taxid\\s*[:=]\\s*(\\d+)", ignore_case = TRUE))
    if (!all(is.na(taxid_match))) {
        taxid_val <- as.integer(na.omit(c(taxid_match[1, 2], taxid_match[1, 3]))[1])
    }

    header_patterns <- c("##species\\s*[:= ]\\s*([^\\n]+)", "##organism\\s*[:= ]\\s*([^\\n]+)", "organism=([^;\\n]+)", "species=([^;\\n]+)")
    for (pat in header_patterns) {
        m <- str_match(text, regex(pat, ignore_case = TRUE))
        if (!all(is.na(m)) && nzchar(stringr::str_trim(stringr::str_remove_all(m[1, 2], '["\']')))) {
            raw_value <- stringr::str_trim(stringr::str_remove_all(m[1, 2], '["\']'))
            url_taxid <- stringr::str_match(raw_value, "[?&]id=(\\d+)")
            if (!is.na(url_taxid[1, 2])) {
                if (is.null(taxid_val)) taxid_val <- as.integer(url_taxid[1, 2])
            } else if (!grepl("^https?://", raw_value)) {
                organism_name <- raw_value
            }
            break
        }
    }

    if (!is.null(organism_name) || !is.null(taxid_val)) {
        return(list(organism = organism_name, taxid = taxid_val, source = "header"))
    }

    fname <- tolower(original_name %||% basename(file_path))
    patterns <- list(
        list("Oryza sativa ssp. japonica", c("japonica", "irgsp", "nipponbare")),
        list("Oryza sativa ssp. indica", c("indica")),
        list("Oryza sativa", c("rice", "oryza", "osativa")),
        list("Arabidopsis thaliana", c("arabidopsis", "thaliana", "athaliana")),
        list("Zea mays", c("maize", "corn", "zea", "zmays")),
        list("Triticum aestivum", c("wheat", "triticum", "taestivum")),
        list("Hordeum vulgare", c("barley", "hordeum", "vulgare")),
        list("Sorghum bicolor", c("sorghum", "sbicolor")),
        list("Homo sapiens", c("human", "homo", "hsapiens")),
        list("Mus musculus", c("mouse", "musculus", "mmusculus")),
        list("Saccharomyces cerevisiae", c("yeast", "saccharomyces", "scerevisiae")),
        list("Drosophila melanogaster", c("drosophila", "melanogaster")),
        list("Caenorhabditis elegans", c("elegans", "celegans", "c_elegans")),
        list("Danio rerio", c("zebrafish", "danio", "drerio")),
        list("Candida albicans", c("candida", "albicans")),
        list("Sus scrofa", c("pig", "scrofa", "sscrofa")),
        list("Canis lupus familiaris", c("canine", "dog", "canis")),
        list("Equus caballus", c("horse", "equus", "ecaballus")),
        list("Pan troglodytes", c("chimpanzee", "chimp", "pantroglodytes")),
        list("Vitis vinifera", c("grape", "vitis", "vvinifera")),
        list("Solanum lycopersicum", c("tomato", "solanum", "lycopersicum")),
        list("Phaseolus vulgaris", c("bean", "phaseolus", "pvulgaris")),
        list("Malus domestica", c("apple", "malus", "mdomestica")),
        list("Fragaria vesca", c("strawberry", "fragaria", "fvesca")),
        list("Botrytis cinerea", c("botrytis", "bcinerea")),
        list("Neurospora crassa", c("neurospora", "ncrassa")),
        list("Xenopus laevis", c("xenopus", "xlaevis")),
        list("Desmodus rotundus", c("vampire", "desmodus")),
        list("Gallus gallus", c("chicken", "gallus")),
        list("Rattus norvegicus", c("rat", "rattus", "rnorvegicus")),
        list("Bos taurus", c("cow", "cattle", "bovine", "bos", "btaurus")),
        list("Glycine max", c("soybean", "glycine", "gmax")),
        list("Nicotiana tabacum", c("tobacco", "nicotiana", "ntabacum")),
        list("Gossypium hirsutum", c("cotton", "gossypium")),
        list("Capsicum annuum", c("pepper", "capsicum", "cannuum")),
        list("Citrus sinensis", c("orange", "citrus", "csinensis")),
        list("Ovis aries", c("sheep", "ovis", "oaries")),
        list("Apis mellifera", c("honeybee", "bee", "apis", "amellifera"))
    )
    for (p in patterns) {
        if (any(stringr::str_detect(fname, paste(p[[2]], collapse = "|")))) {
            return(list(organism = p[[1]], taxid = NULL, source = "filename"))
        }
    }

    gcf_pattern <- "GC[FA]_\\d{9}\\.\\d+"
    gcf_match <- stringr::str_extract(fname, stringr::regex(gcf_pattern, ignore_case = TRUE))
    if (!is.na(gcf_match)) {
        return(list(organism = NULL, taxid = NULL, source = "none", assembly_accession = gcf_match))
    }

    list(organism = NULL, taxid = NULL, source = "none")
}

resolve_organism_name_ncbi <- function(taxid) {
    if (is.null(taxid) || is.na(taxid)) return(NULL)
    url <- sprintf(
        "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&id=%d&retmode=xml",
        as.integer(taxid)
    )
    result <- tryCatch({
        resp <- httr::GET(url, httr::timeout(8))
        if (httr::status_code(resp) != 200) return(NULL)
        body <- httr::content(resp, as = "text", encoding = "UTF-8")
        sci_match <- stringr::str_match(body, "<ScientificName>([^<]+)</ScientificName>")
        if (!is.na(sci_match[1, 2])) {
            trimws(sci_match[1, 2])
        } else {
            NULL
        }
    }, error = function(e) NULL)
    result
}

parse_organism_from_assembly_report <- function(report_path) {
    if (is.null(report_path) || !nzchar(report_path) || !file.exists(report_path)) return(NULL)
    lines <- tryCatch(readLines(report_path, n = 50, warn = FALSE), error = function(e) character())
    org_name <- NULL
    org_taxid <- NULL
    for (ln in lines) {
        if (is.null(org_name) && grepl("^#\\s*Organism name:", ln, ignore.case = TRUE)) {
            name <- sub("^#\\s*Organism name:\\s*", "", ln, ignore.case = TRUE)
            name <- sub("\\s*\\(.*\\)\\s*$", "", name)
            name <- trimws(name)
            if (nzchar(name)) org_name <- name
        }
        if (is.null(org_taxid) && grepl("^#\\s*Taxid:", ln, ignore.case = TRUE)) {
            tid <- sub("^#\\s*Taxid:\\s*", "", ln, ignore.case = TRUE)
            tid <- trimws(tid)
            if (grepl("^\\d+$", tid)) org_taxid <- as.integer(tid)
        }
        if (!is.null(org_name)) break
    }
    if (!is.null(org_name)) {
        result <- org_name
        if (!is.null(org_taxid)) attr(result, "taxid") <- org_taxid
        return(result)
    }
    NULL
}

resolve_organism_cascade <- function(det, assembly_report_path = NULL) {
    org_name <- det$organism
    taxid <- det$taxid
    source <- det$source %||% "none"
    confidence <- "none"

    if (!is.null(assembly_report_path) && nzchar(assembly_report_path) && file.exists(assembly_report_path)) {
        report_name <- parse_organism_from_assembly_report(assembly_report_path)
        if (!is.null(report_name) && nzchar(report_name)) {
            org_name <- report_name
            source <- "assembly_report"
            confidence <- "high"
            return(list(organism = org_name, taxid = taxid, source = source, confidence = confidence))
        }
    }

    if (!is.null(org_name) && nzchar(org_name)) {
        confidence <- if (identical(source, "header")) "high" else "medium"
        return(list(organism = org_name, taxid = taxid, source = source, confidence = confidence))
    }

    if (!is.null(taxid) && !is.na(taxid)) {
        ncbi_name <- resolve_organism_name_ncbi(taxid)
        if (!is.null(ncbi_name) && nzchar(ncbi_name)) {
            return(list(organism = ncbi_name, taxid = taxid, source = "ncbi_taxonomy", confidence = "high"))
        }
    }

    list(organism = org_name, taxid = taxid, source = source, confidence = confidence)
}

normalize_org_key <- function(x) {
    x <- tolower(x %||% "")
    x <- gsub("[^a-z0-9]+", " ", x)
    trimws(x)
}

get_genome_registry <- function(genomes_dir = "genomes") {
    registry_path <- file.path(genomes_dir, "registry.tsv")
    if (!file.exists(registry_path)) {
        return(data.frame())
    }
    out <- tryCatch(read.delim(registry_path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE), error = function(e) data.frame())
    if (nrow(out) == 0) {
        return(data.frame())
    }
    for (mc in setdiff(c("organism", "taxid", "fasta", "aliases"), colnames(out))) out[[mc]] <- NA_character_
    out
}

resolve_genome_fasta <- function(det_info = NULL, uploaded_fasta_path = NULL, genomes_dir = "genomes") {
    if (!is.null(uploaded_fasta_path) && nzchar(uploaded_fasta_path) && file.exists(uploaded_fasta_path)) {
        return(list(path = uploaded_fasta_path, source = "uploaded", found = TRUE, organism = NULL))
    }

    reg <- get_genome_registry(genomes_dir)
    if (nrow(reg) == 0) {
        return(list(path = NULL, source = "registry_missing", found = FALSE, organism = NULL))
    }

    org <- if (!is.null(det_info)) det_info$organism else NULL
    taxid <- if (!is.null(det_info)) det_info$taxid else NULL
    org_key <- normalize_org_key(org)

    if (!is.null(taxid) && !all(is.na(reg$taxid))) {
        hit <- reg[as.character(reg$taxid) == as.character(taxid), , drop = FALSE]
        if (nrow(hit) > 0) {
            p <- hit$fasta[1]
            p2 <- if (grepl("^/", p) || grepl("^[a-zA-Z]:", p)) p else file.path(genomes_dir, p)
            if (file.exists(p2)) {
                return(list(path = p2, source = "registry_taxid", found = TRUE, organism = hit$organism[1]))
            }
        }
    }

    if (!is.null(org) && nzchar(org_key)) {
        for (i in seq_len(nrow(reg))) {
            keys <- c(reg$organism[i], unlist(strsplit(reg$aliases[i] %||% "", "\\|")))
            norm_keys <- unique(vapply(keys, normalize_org_key, character(1)))[nzchar(unique(vapply(keys, normalize_org_key, character(1))))]
            if (org_key %in% norm_keys || any(stringr::str_detect(org_key, stringr::fixed(norm_keys))) || any(stringr::str_detect(norm_keys, stringr::fixed(org_key)))) {
                p <- reg$fasta[i]
                p2 <- if (grepl("^/", p) || grepl("^[a-zA-Z]:", p)) p else file.path(genomes_dir, p)
                if (file.exists(p2)) {
                    app_debug_log("[Genome Resolve] Match by Name found: ", p2)
                    return(list(path = p2, source = "registry_organism", found = TRUE, organism = reg$organism[i]))
                }
            }
        }
    }
    list(path = NULL, source = "not_found", found = FALSE, organism = NULL)
}

# Operador null-coalescing estricto: devuelve `a` solo si no es NULL,
# tiene longitud > 0, no es todo-NA y el primer elemento no es string vacío.
# Usar cuando se necesita garantizar un valor realmente utilizable (no solo no-NULL).
`%|||%` <- function(a, b) if (!is.null(a) && length(a) > 0 && !all(is.na(a)) && nzchar(as.character(a[1]))) a else b

# --- 3. CACHÉ Y PARSEO DE GFF ---

.fasta_header_cache <- new.env(parent = emptyenv())
.fasta_seqnames_cache <- new.env(parent = emptyenv())
.fasta_resolved_seqname_cache <- new.env(parent = emptyenv())
.fafile_handle_cache <- new.env(parent = emptyenv())
.fasta_fallback_seq_cache <- new.env(parent = emptyenv())
.spliced_seq_cache <- new.env(parent = emptyenv())
.gff_cache <- new.env(parent = emptyenv())
.seq_extract_cache <- new.env(parent = emptyenv())
.gff_gene_index_cache <- new.env(parent = emptyenv())
.gff_gene_light_index_cache <- new.env(parent = emptyenv())
.gff_genes_table_cache <- new.env(parent = emptyenv())
.gff_genes_chr_index_cache <- new.env(parent = emptyenv())
.gff_chr_length_cache <- new.env(parent = emptyenv())
.preloaded_registry_cache <- new.env(parent = emptyenv())
.twobit_seqinfo_cache <- new.env(parent = emptyenv())
.twobit_handle_cache <- new.env(parent = emptyenv())
.tabix_index_override_cache <- new.env(parent = emptyenv())
.assembly_report_cache <- new.env(parent = emptyenv())
.assembly_stats_cache <- new.env(parent = emptyenv())
.annotation_report_path_cache <- new.env(parent = emptyenv())
.neighbor_context_cache <- new.env(parent = emptyenv())
.annotation_disk_cache_maintenance <- new.env(parent = emptyenv())
.gff_index_cache_version <- "desc-clean-v2"

.cache_meta_hidden_key <- ".__cache_meta__"

parse_positive_int_env <- function(var_name, default_value) {
    raw <- trimws(as.character(Sys.getenv(as.character(var_name %||% ""), as.character(default_value)) %||% as.character(default_value)))
    val <- suppressWarnings(as.integer(raw))
    if (!is.finite(val) || is.na(val) || val < 1L) {
        val <- as.integer(default_value %||% 1L)
    }
    val
}

parse_positive_bytes_env_mb <- function(var_name, default_mb) {
    raw <- trimws(as.character(Sys.getenv(as.character(var_name %||% ""), as.character(default_mb)) %||% as.character(default_mb)))
    val <- suppressWarnings(as.numeric(raw))
    if (!is.finite(val) || is.na(val) || val <= 0) {
        val <- as.numeric(default_mb %||% 1)
    }
    as.numeric(val) * 1024^2
}

sanitize_cache_key <- function(x) {
    y <- as.character(x %||% "")
    y <- gsub("[^A-Za-z0-9._-]", "_", y)
    y <- gsub("_+", "_", y)
    if (!nzchar(y)) y <- "cache_key"
    y
}

cache_env_entry_keys <- function(env) {
    setdiff(ls(env, all.names = TRUE), .cache_meta_hidden_key)
}

cache_env_meta_get <- function(env) {
    meta <- get0(.cache_meta_hidden_key, envir = env, inherits = FALSE, ifnotfound = NULL)
    if (!is.list(meta)) {
        meta <- list(access = numeric(0), bytes = numeric(0))
    }
    if (!is.numeric(meta$access)) {
        meta$access <- numeric(0)
    }
    if (!is.numeric(meta$bytes)) {
        meta$bytes <- numeric(0)
    }
    meta
}

cache_env_meta_set <- function(env, meta) {
    assign(.cache_meta_hidden_key, meta, envir = env)
    invisible(meta)
}

cache_env_drop <- function(env, key) {
    key_txt <- as.character(key %||% "")
    if (!nzchar(key_txt)) {
        return(invisible(FALSE))
    }
    if (exists(key_txt, envir = env, inherits = FALSE)) {
        rm(list = key_txt, envir = env)
    }
    meta <- cache_env_meta_get(env)
    meta$access <- meta$access[setdiff(names(meta$access), key_txt)]
    meta$bytes <- meta$bytes[setdiff(names(meta$bytes), key_txt)]
    cache_env_meta_set(env, meta)
    invisible(TRUE)
}

cache_env_touch <- function(env, key, bytes = NA_real_) {
    key_txt <- as.character(key %||% "")
    if (!nzchar(key_txt)) {
        return(invisible(NULL))
    }
    meta <- cache_env_meta_get(env)
    access <- meta$access
    bytes_map <- meta$bytes
    access[key_txt] <- as.numeric(proc.time()[["elapsed"]])
    if (is.finite(bytes)) {
        bytes_map[key_txt] <- as.numeric(bytes)
    } else if (!key_txt %in% names(bytes_map) && exists(key_txt, envir = env, inherits = FALSE)) {
        bytes_map[key_txt] <- as.numeric(utils::object.size(get(key_txt, envir = env, inherits = FALSE)))
    }
    meta$access <- access
    meta$bytes <- bytes_map
    cache_env_meta_set(env, meta)
    invisible(NULL)
}

cache_env_get <- function(env, key, default = NULL) {
    key_txt <- as.character(key %||% "")
    if (!nzchar(key_txt) || !exists(key_txt, envir = env, inherits = FALSE)) {
        return(default)
    }
    value <- get(key_txt, envir = env, inherits = FALSE)
    cache_env_touch(env, key_txt)
    value
}

cache_env_set <- function(env, key, value, max_size = NULL, max_bytes = NULL) {
    key_txt <- as.character(key %||% "")
    if (!nzchar(key_txt)) {
        return(invisible(value))
    }
    assign(key_txt, value, envir = env)
    cache_env_touch(env, key_txt, bytes = as.numeric(utils::object.size(value)))
    trim_cache_env(env, max_size = max_size %||% Inf, max_bytes = max_bytes)
    invisible(value)
}

# Poda un cache de entorno cuando supera max_size o max_bytes.
# Cuando el entorno mantiene metadatos de acceso, elimina primero las entradas menos usadas recientemente.
trim_cache_env <- function(env, max_size = 1000L, max_bytes = NULL) {
    entries <- cache_env_entry_keys(env)
    n <- length(entries)
    max_size_int <- suppressWarnings(as.integer(max_size %||% 1000L))
    if (!is.finite(max_size_int) || is.na(max_size_int) || max_size_int < 1L) {
        max_size_int <- Inf
    }
    max_bytes_num <- suppressWarnings(as.numeric(max_bytes %||% NA_real_))
    if (!is.finite(max_bytes_num) || is.na(max_bytes_num) || max_bytes_num <= 0) {
        max_bytes_num <- NA_real_
    }

    if (n == 0L) {
        cache_env_meta_set(env, list(access = numeric(0), bytes = numeric(0)))
        return(invisible(NULL))
    }

    meta <- cache_env_meta_get(env)
    access <- meta$access
    bytes_map <- meta$bytes
    missing_access <- setdiff(entries, names(access))
    if (length(missing_access) > 0L) {
        seed_vals <- seq_len(length(missing_access))
        names(seed_vals) <- missing_access
        access <- c(access, seed_vals)
    }
    missing_bytes <- setdiff(entries, names(bytes_map))
    if (length(missing_bytes) > 0L) {
        computed <- vapply(missing_bytes, function(k) {
            if (!exists(k, envir = env, inherits = FALSE)) {
                return(0)
            }
            as.numeric(utils::object.size(get(k, envir = env, inherits = FALSE)))
        }, numeric(1))
        bytes_map <- c(bytes_map, computed)
    }
    access <- access[entries]
    bytes_map <- bytes_map[entries]

    total_bytes <- sum(as.numeric(bytes_map), na.rm = TRUE)
    over_size <- is.finite(max_size_int) && n > max_size_int
    over_bytes <- is.finite(max_bytes_num) && total_bytes > max_bytes_num
    if (over_size || over_bytes) {
        order_access <- order(as.numeric(access), na.last = TRUE)
        drop_keys <- character(0)
        keep_n <- n
        keep_bytes <- total_bytes
        for (idx in order_access) {
            if (!(is.finite(max_size_int) && keep_n > max_size_int) && !(is.finite(max_bytes_num) && keep_bytes > max_bytes_num)) {
                break
            }
            key_drop <- entries[[idx]]
            drop_keys <- c(drop_keys, key_drop)
            keep_n <- keep_n - 1L
            keep_bytes <- keep_bytes - as.numeric(bytes_map[[idx]] %||% 0)
        }
        if (length(drop_keys) > 0L) {
            rm(list = drop_keys, envir = env)
            entries <- setdiff(entries, drop_keys)
            access <- access[setdiff(names(access), drop_keys)]
            bytes_map <- bytes_map[setdiff(names(bytes_map), drop_keys)]
        }
    }

    access <- access[entries]
    bytes_map <- bytes_map[entries]
    cache_env_meta_set(env, list(access = access, bytes = bytes_map))
    invisible(NULL)
}

annotation_memory_cache_limits <- list(
    gff_max_entries = parse_positive_int_env("APP_GFF_CACHE_MAX_ENTRIES", 2L),
    gff_max_bytes = parse_positive_bytes_env_mb("APP_GFF_CACHE_MAX_MB", 900),
    gene_index_max_entries = parse_positive_int_env("APP_GFF_GENE_INDEX_CACHE_MAX_ENTRIES", 6L),
    gene_index_max_bytes = parse_positive_bytes_env_mb("APP_GFF_GENE_INDEX_CACHE_MAX_MB", 1200),
    gene_light_max_entries = parse_positive_int_env("APP_GFF_GENE_LIGHT_CACHE_MAX_ENTRIES", 24L),
    gene_light_max_bytes = parse_positive_bytes_env_mb("APP_GFF_GENE_LIGHT_CACHE_MAX_MB", 650),
    genes_table_max_entries = parse_positive_int_env("APP_GFF_GENES_TABLE_CACHE_MAX_ENTRIES", 24L),
    genes_table_max_bytes = parse_positive_bytes_env_mb("APP_GFF_GENES_TABLE_CACHE_MAX_MB", 300),
    genes_chr_index_max_entries = parse_positive_int_env("APP_GFF_GENES_CHR_INDEX_CACHE_MAX_ENTRIES", 48L),
    genes_chr_index_max_bytes = parse_positive_bytes_env_mb("APP_GFF_GENES_CHR_INDEX_CACHE_MAX_MB", 160),
    fasta_fallback_seq_max_entries = parse_positive_int_env("APP_FASTA_FALLBACK_SEQ_CACHE_MAX_ENTRIES", 8L),
    fasta_fallback_seq_max_bytes = parse_positive_bytes_env_mb("APP_FASTA_FALLBACK_SEQ_CACHE_MAX_MB", 96),
    fasta_fallback_seq_max_bp = parse_positive_int_env("APP_FASTA_FALLBACK_SEQ_CACHE_MAX_BP", 5000000L)
)

# Convert genomic feature coordinates into transcript-order display coordinates.
# Plus-strand transcripts stay left-to-right by genomic start.
# Minus-strand transcripts are mirrored so exon 1 is displayed on the left.
compute_transcript_relative_coords <- function(df, strand = "+", anchor_df = NULL) {
    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
        return(list(rel_start = numeric(0), rel_end = numeric(0), origin = NA_real_))
    }

    base_df <- if (!is.null(anchor_df) && is.data.frame(anchor_df) && nrow(anchor_df) > 0L) {
        anchor_df
    } else {
        df
    }

    xs <- suppressWarnings(as.numeric(df$xstart))
    xe <- suppressWarnings(as.numeric(df$xend))
    base_xs <- suppressWarnings(as.numeric(base_df$xstart))
    base_xe <- suppressWarnings(as.numeric(base_df$xend))

    base_min <- suppressWarnings(min(base_xs, na.rm = TRUE))
    base_max <- suppressWarnings(max(base_xe, na.rm = TRUE))
    strand_one <- trimws(as.character(strand %||% "+"))[1L]
    if (!strand_one %in% c("+", "-")) strand_one <- "+"

    if (identical(strand_one, "-") && is.finite(base_max)) {
        rel_start <- base_max - xe
        rel_end <- base_max - xs
        origin <- base_max
    } else {
        if (!is.finite(base_min)) base_min <- suppressWarnings(min(xs, na.rm = TRUE))
        if (!is.finite(base_min)) base_min <- 0
        rel_start <- xs - base_min
        rel_end <- xe - base_min
        origin <- base_min
    }

    list(
        rel_start = pmin(rel_start, rel_end),
        rel_end = pmax(rel_start, rel_end),
        origin = origin
    )
}

get_transcript_feature_palette <- function(is_dark_theme = FALSE, is_colorblind_mode = FALSE) {
    is_dark_theme <- isTRUE(is_dark_theme)
    is_colorblind_mode <- isTRUE(is_colorblind_mode)

    if (is_colorblind_mode) {
        if (is_dark_theme) {
            return(c(
                "compact" = "#56B4E9",
                "gene" = "#56B4E9",
                "exon" = "#56B4E9",
                "cds" = "#009E73",
                "utr" = "#CC79A7",
                "codon" = "#F0E442",
                "other" = "#D55E00"
            ))
        }
        return(c(
            "compact" = "#0072B2",
            "gene" = "#0072B2",
            "exon" = "#0072B2",
            "cds" = "#009E73",
            "utr" = "#CC79A7",
            "codon" = "#E69F00",
            "other" = "#56B4E9"
        ))
    }

    if (is_dark_theme) {
        return(c(
            "compact" = "#FF7B8F",
            "gene" = "#FF9DAF",
            "exon" = "#FF6881",
            "cds" = "#F4B36A",
            "utr" = "#55C7E8",
            "codon" = "#B89CFF",
            "other" = "#8297AC"
        ))
    }

    c(
        "compact" = "#F7687C",
        "gene" = "#FFB7BF",
        "exon" = "#F45D75",
        "cds" = "#E8A44F",
        "utr" = "#5BC0EB",
        "codon" = "#7CCFB8",
        "other" = "#B9C1C9"
    )
}

compute_spliced_feature_relative_coords <- function(df, strand = "+", gap = 14) {
    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
        return(list(rel_start = numeric(0), rel_end = numeric(0)))
    }

    xs <- suppressWarnings(as.numeric(df$xstart))
    xe <- suppressWarnings(as.numeric(df$xend))
    strand_one <- trimws(as.character(strand %||% "+"))[1L]
    if (!strand_one %in% c("+", "-")) strand_one <- "+"

    ord <- if (identical(strand_one, "-")) order(-xs, -xe, na.last = TRUE) else order(xs, xe, na.last = TRUE)
    rel_start <- rep(NA_real_, nrow(df))
    rel_end <- rep(NA_real_, nrow(df))
    cursor <- 0
    gap_val <- max(0, suppressWarnings(as.numeric(gap %||% 0)))

    for (idx in ord) {
        if (!is.finite(xs[idx]) || !is.finite(xe[idx])) next
        width_val <- abs(xe[idx] - xs[idx])
        if (!is.finite(width_val) || width_val <= 0) width_val <- 1
        rel_start[idx] <- cursor
        rel_end[idx] <- cursor + width_val
        cursor <- rel_end[idx] + gap_val
    }

    list(
        rel_start = pmin(rel_start, rel_end),
        rel_end = pmax(rel_start, rel_end)
    )
}

get_annotation_disk_cache_dir <- function(base_dir = ".") {
    normalizePath(file.path(base_dir, "cache", "annotation_index"), winslash = "/", mustWork = FALSE)
}

normalize_cache_filename_family <- function(fname) {
    nm <- basename(as.character(fname %||% ""))
    nm <- sub("\\.rds$", "", nm, ignore.case = TRUE)
    nm <- sub("^gene_light__[^_]+__", "", nm)
    nm <- sub("_desc-clean-v[0-9]+$", "", nm)
    nm <- gsub("_[0-9]+(?:\\.[0-9]+)?$", "", nm, perl = TRUE)
    nm <- gsub("_[0-9]+_[0-9]+$", "", nm, perl = TRUE)
    nm
}

detect_annotation_cache_family <- function(fname, known_annotation_basenames = character(0)) {
    nm <- basename(as.character(fname %||% ""))
    stem <- sub("\\.rds$", "", nm, ignore.case = TRUE)
    kind <- sub("__.*$", "", stem)
    sanitized_known <- vapply(as.character(known_annotation_basenames %||% character(0)), sanitize_cache_key, character(1))
    sanitized_known <- unique(sanitized_known[nzchar(sanitized_known)])
    if (length(sanitized_known) > 0L) {
        hits <- sanitized_known[vapply(sanitized_known, function(tok) grepl(tok, stem, fixed = TRUE), logical(1))]
        if (length(hits) > 0L) {
            hits <- hits[order(nchar(hits), decreasing = TRUE)]
            return(paste(kind, hits[[1]], sep = "::"))
        }
    }
    paste(kind, normalize_cache_filename_family(fname), sep = "::")
}

maintain_annotation_disk_cache <- function(base_dir = ".") {
    cdir <- get_annotation_disk_cache_dir(base_dir = base_dir)
    if (!dir.exists(cdir)) {
        return(invisible(NULL))
    }

    maintain_key <- normalizePath(cdir, winslash = "/", mustWork = FALSE)
    if (isTRUE(get0(maintain_key, envir = .annotation_disk_cache_maintenance, inherits = FALSE, ifnotfound = FALSE))) {
        return(invisible(NULL))
    }

    files <- list.files(cdir, pattern = "\\.rds$", full.names = TRUE)
    if (length(files) == 0L) {
        assign(maintain_key, TRUE, envir = .annotation_disk_cache_maintenance)
        return(invisible(NULL))
    }

    annotation_dir <- file.path(base_dir, "annotations")
    known_basenames <- if (dir.exists(annotation_dir)) {
        basename(list.files(annotation_dir, pattern = "\\.gff(?:3)?(?:\\.gz)?$", full.names = TRUE, recursive = TRUE, ignore.case = TRUE))
    } else {
        character(0)
    }
    fam_keys <- vapply(files, detect_annotation_cache_family, character(1), known_annotation_basenames = known_basenames)
    groups <- split(files, fam_keys)
    removed <- 0L
    repaired <- 0L
    for (grp in groups) {
        grp <- grp[file.exists(grp)]
        if (length(grp) <= 1L) {
            next
        }
        info <- file.info(grp)
        # Prefer the newer canonical cache filenames, which are typically longer
        # because they include more identity information (for example file size).
        ord <- order(-nchar(basename(grp)), -as.numeric(info$mtime), na.last = TRUE)
        keep <- grp[[ord[[1]]]]
        drop <- setdiff(grp, keep)
        if (!file.exists(keep) || length(drop) == 0L) {
            next
        }
        unlink(drop, force = TRUE)
        removed <- removed + length(drop)
        repaired <- repaired + 1L
    }

    max_files <- parse_positive_int_env("APP_ANNOTATION_DISK_CACHE_MAX_FILES", 96L)
    files_after <- list.files(cdir, pattern = "\\.rds$", full.names = TRUE)
    if (length(files_after) > max_files) {
        info_after <- file.info(files_after)
        ord_oldest <- order(as.numeric(info_after$mtime), na.last = TRUE)
        drop_extra <- files_after[ord_oldest[seq_len(length(files_after) - max_files)]]
        unlink(drop_extra, force = TRUE)
        removed <- removed + length(drop_extra)
    }

    if (removed > 0L || repaired > 0L) {
        app_debug_log(sprintf("[Cache] Annotation disk cache maintenance: removed %d stale file(s) across %d duplicate family(ies).", removed, repaired))
    }
    assign(maintain_key, TRUE, envir = .annotation_disk_cache_maintenance)
    invisible(NULL)
}

can_use_persistent_cache_for_path <- function(file_path, base_dir = ".") {
    p <- normalizePath(as.character(file_path %||% ""), winslash = "/", mustWork = FALSE)
    b <- normalizePath(base_dir, winslash = "/", mustWork = FALSE)
    if (!nzchar(p) || !nzchar(b)) {
        return(FALSE)
    }
    startsWith(p, paste0(b, "/")) || identical(p, b)
}

canonical_cache_identity_path <- function(file_path, base_dir = ".") {
    p <- normalizePath(as.character(file_path %||% ""), winslash = "/", mustWork = FALSE)
    if (!nzchar(p)) {
        return("")
    }

    known_roots <- unique(c(
        normalizePath(base_dir, winslash = "/", mustWork = FALSE),
        "/app"
    ))
    known_roots <- known_roots[nzchar(known_roots)]

    for (root in known_roots) {
        prefix <- paste0(root, "/")
        if (identical(p, root)) {
            return(".")
        }
        if (startsWith(p, prefix)) {
            return(substr(p, nchar(prefix) + 1L, nchar(p)))
        }
    }

    for (seg in c("annotations", "genomes", "go_annotations", "cache")) {
        marker <- paste0("/", seg, "/")
        hit <- regexpr(marker, p, fixed = TRUE)[1]
        if (is.finite(hit) && hit > 0L) {
            return(substr(p, hit + 1L, nchar(p)))
        }
    }

    p
}

get_gff_disk_index_path <- function(file_path, cache_kind = "gene_light", base_dir = ".") {
    cdir <- get_annotation_disk_cache_dir(base_dir = base_dir)
    key <- gff_cache_key(file_path)
    file.path(cdir, paste0(cache_kind, "__", .gff_index_cache_version, "__", sanitize_cache_key(key), ".rds"))
}

find_existing_gff_disk_index_path <- function(file_path, cache_kind = "gene_light", base_dir = ".") {
    cpath <- get_gff_disk_index_path(file_path, cache_kind = cache_kind, base_dir = base_dir)
    if (file.exists(cpath)) {
        return(cpath)
    }

    cdir <- get_annotation_disk_cache_dir(base_dir = base_dir)
    if (!dir.exists(cdir)) {
        return("")
    }

    files <- list.files(cdir, pattern = "\\.rds$", full.names = TRUE)
    if (length(files) == 0L) {
        return("")
    }

    target_family <- detect_annotation_cache_family(cpath, known_annotation_basenames = basename(as.character(file_path %||% "")))
    file_families <- vapply(
        files,
        detect_annotation_cache_family,
        character(1),
        known_annotation_basenames = basename(as.character(file_path %||% ""))
    )
    candidates <- files[file_families == target_family]
    if (length(candidates) == 0L) {
        return("")
    }

    info <- file.info(candidates)
    ord <- order(-nchar(basename(candidates)), -as.numeric(info$mtime), na.last = TRUE)
    candidates[[ord[[1]]]]
}

load_gff_index_from_disk <- function(file_path, cache_kind = "gene_light", base_dir = ".") {
    maintain_annotation_disk_cache(base_dir = base_dir)
    cpath <- find_existing_gff_disk_index_path(file_path, cache_kind = cache_kind, base_dir = base_dir)
    if (!file.exists(cpath)) {
        return(NULL)
    }
    idx_obj <- tryCatch(readRDS(cpath), error = function(e) NULL)
    if (is.null(idx_obj)) {
        return(NULL)
    }

    expected_path <- get_gff_disk_index_path(file_path, cache_kind = cache_kind, base_dir = base_dir)
    if (nzchar(expected_path) && !identical(cpath, expected_path) && !file.exists(expected_path)) {
        try(saveRDS(idx_obj, expected_path, compress = "gzip"), silent = TRUE)
    }
    idx_obj
}

save_gff_index_to_disk <- function(file_path, idx_obj, cache_kind = "gene_light", base_dir = ".") {
    if (!can_use_persistent_cache_for_path(file_path, base_dir = base_dir)) {
        return(invisible(FALSE))
    }
    maintain_annotation_disk_cache(base_dir = base_dir)
    cpath <- get_gff_disk_index_path(file_path, cache_kind = cache_kind, base_dir = base_dir)
    cdir <- dirname(cpath)
    if (!dir.exists(cdir)) dir.create(cdir, recursive = TRUE, showWarnings = FALSE)
    ok <- tryCatch(
        {
            saveRDS(idx_obj, cpath, compress = "gzip")
            TRUE
        },
        error = function(e) FALSE
    )
    invisible(ok)
}

precompute_annotation_index_cache <- function(annotation_file_path, base_dir = ".") {
    p <- as.character(annotation_file_path %||% "")
    if (!nzchar(p) || !file.exists(p)) {
        return(NULL)
    }
    idx <- build_gff_gene_light_index(p)
    save_gff_index_to_disk(p, idx, cache_kind = "gene_light", base_dir = base_dir)
    # Pre-warm the genes table so the first plot doesn't have to build it
    tryCatch(get_genes_table_from_annotation(p), error = function(e) NULL)
    idx
}

clear_annotation_index_cache <- function(base_dir = ".") {
    cdir <- get_annotation_disk_cache_dir(base_dir = base_dir)
    if (dir.exists(cdir)) unlink(cdir, recursive = TRUE, force = TRUE)
    invisible(TRUE)
}

set_tabix_index_override <- function(annotation_path, index_path) {
    ap <- as.character(annotation_path %||% "")
    ip <- as.character(index_path %||% "")
    if (!nzchar(ap) || !nzchar(ip)) {
        return(invisible(NULL))
    }
    key <- normalizePath(ap, winslash = "/", mustWork = FALSE)
    assign(key, normalizePath(ip, winslash = "/", mustWork = FALSE), envir = .tabix_index_override_cache)
    invisible(NULL)
}

get_tabix_index_override <- function(annotation_path) {
    ap <- as.character(annotation_path %||% "")
    if (!nzchar(ap)) {
        return("")
    }
    key <- normalizePath(ap, winslash = "/", mustWork = FALSE)
    if (!exists(key, envir = .tabix_index_override_cache, inherits = FALSE)) {
        return("")
    }
    as.character(get(key, envir = .tabix_index_override_cache, inherits = FALSE) %||% "")
}

is_twobit_file <- function(path_value) {
    p <- as.character(path_value %||% "")
    nzchar(p) && grepl("\\.2bit$", p, ignore.case = TRUE)
}

find_existing_tabix_index <- function(annotation_path) {
    p <- as.character(annotation_path %||% "")
    if (!nzchar(p)) {
        return("")
    }
    candidates <- c(paste0(p, ".tbi"), paste0(p, ".csi"))
    hit <- candidates[file.exists(candidates)]
    if (length(hit) == 0) "" else hit[1]
}

is_tabix_annotation_file <- function(path_value, index_path = NULL) {
    p <- as.character(path_value %||% "")
    if (!nzchar(p) || !file.exists(p)) {
        return(FALSE)
    }
    if (!grepl("\\.(gff3?|gtf)\\.(gz|bgz)$", p, ignore.case = TRUE)) {
        return(FALSE)
    }
    idx <- as.character(index_path %||% "")
    if (!nzchar(idx)) idx <- get_tabix_index_override(p)
    if (!nzchar(idx) || !file.exists(idx)) idx <- find_existing_tabix_index(p)
    file.exists(idx)
}

resolve_catalog_path <- function(path_value, base_dir = ".") {
    p <- as.character(path_value %||% "")
    if (!nzchar(p)) {
        return(NA_character_)
    }
    if (grepl("^/", p) || grepl("^[A-Za-z]:", p)) {
        return(normalizePath(p, winslash = "/", mustWork = FALSE))
    }
    normalizePath(file.path(base_dir, p), winslash = "/", mustWork = FALSE)
}

strip_data_extensions <- function(x) {
    out <- as.character(x %||% "")
    if (!nzchar(out)) {
        return("")
    }
    repeat {
        prev <- out
        out <- sub("\\.(gz|bgz)$", "", out, ignore.case = TRUE)
        out <- sub("\\.(gff3?|gtf|txt|fa|fasta|fna|2bit)$", "", out, ignore.case = TRUE)
        if (identical(prev, out)) break
    }
    out
}

build_stats_stem_candidates <- function(annotation_path = "", annotation_tabix_path = "", genome_path = "", genome_2bit_path = "") {
    raw <- c(
        basename(as.character(genome_2bit_path %||% "")),
        basename(as.character(genome_path %||% "")),
        basename(as.character(annotation_tabix_path %||% "")),
        basename(as.character(annotation_path %||% ""))
    )
    raw <- raw[nzchar(raw)]
    if (length(raw) == 0) {
        return(character(0))
    }
    stem <- unique(vapply(raw, strip_data_extensions, character(1)))
    stem <- stem[nzchar(stem)]
    stem_no_genomic <- unique(c(
        stem,
        sub("_genomic$", "", stem, ignore.case = TRUE),
        sub("\\.genomic$", "", stem, ignore.case = TRUE)
    ))
    stem_no_genomic[nzchar(stem_no_genomic)]
}

resolve_stats_files_for_entry <- function(annotation_path = "", annotation_tabix_path = "", genome_path = "", genome_2bit_path = "", base_dir = ".") {
    stats_dir <- resolve_catalog_path(file.path("genomes", "stats"), base_dir = base_dir)
    if (is.na(stats_dir) || !dir.exists(stats_dir)) {
        return(list(report = "", stats = ""))
    }
    cands <- build_stats_stem_candidates(
        annotation_path = annotation_path,
        annotation_tabix_path = annotation_tabix_path,
        genome_path = genome_path,
        genome_2bit_path = genome_2bit_path
    )
    if (length(cands) == 0) {
        return(list(report = "", stats = ""))
    }

    report <- ""
    stats <- ""
    for (s in cands) {
        rp <- file.path(stats_dir, paste0(s, "_assembly_report.txt"))
        sp <- file.path(stats_dir, paste0(s, "_assembly_stats.txt"))
        if (!nzchar(report) && file.exists(rp)) report <- normalizePath(rp, winslash = "/", mustWork = FALSE)
        if (!nzchar(stats) && file.exists(sp)) stats <- normalizePath(sp, winslash = "/", mustWork = FALSE)
        if (nzchar(report) && nzchar(stats)) break
    }
    list(report = report, stats = stats)
}

parse_assembly_report_file <- function(report_path) {
    rp <- as.character(report_path %||% "")
    if (!nzchar(rp) || !file.exists(rp)) {
        return(list(meta = list(), chr_map = list()))
    }
    key <- normalizePath(rp, winslash = "/", mustWork = FALSE)
    if (exists(key, envir = .assembly_report_cache, inherits = FALSE)) {
        return(get(key, envir = .assembly_report_cache, inherits = FALSE))
    }

    out <- list(meta = list(), chr_map = list())
    lines <- tryCatch(readLines(rp, warn = FALSE), error = function(e) character(0))
    if (length(lines) == 0) {
        assign(key, out, envir = .assembly_report_cache)
        return(out)
    }

    meta_pat <- "^#\\s*([^#][^:]+):\\s*(.*)$"
    for (ln in lines) {
        m <- stringr::str_match(ln, meta_pat)
        if (!all(is.na(m))) {
            k <- tolower(trimws(as.character(m[1, 2] %||% "")))
            v <- trimws(as.character(m[1, 3] %||% ""))
            if (nzchar(k) && nzchar(v) && is.null(out$meta[[k]])) {
                out$meta[[k]] <- v
            }
        }
    }

    add_chr_map <- function(map_obj, id_value, label_value) {
        idv <- trimws(as.character(id_value %||% ""))
        lbl <- trimws(as.character(label_value %||% ""))
        if (!nzchar(idv) || !nzchar(lbl)) {
            return(map_obj)
        }
        if (tolower(idv) %in% c("na", "all", ".")) {
            return(map_obj)
        }
        if (tolower(lbl) %in% c("na", "all", ".")) {
            return(map_obj)
        }
        keys <- unique(c(idv, sub("\\.\\d+$", "", idv)))
        keys <- keys[nzchar(keys)]
        for (kk in keys) {
            k_norm <- tolower(kk)
            if (is.null(map_obj[[k_norm]])) map_obj[[k_norm]] <- lbl
        }
        map_obj
    }

    tbl_idx <- grep("^#\\s*Sequence-Name\\t", lines)
    if (length(tbl_idx) > 0) {
        data_lines <- lines[seq.int(tbl_idx[1] + 1L, length(lines))]
        data_lines <- data_lines[!startsWith(data_lines, "#") & nzchar(trimws(data_lines))]
        if (length(data_lines) > 0) {
            for (ln in data_lines) {
                tok <- strsplit(ln, "\t", fixed = TRUE)[[1]]
                if (length(tok) < 7) next
                seq_name <- trimws(tok[1])
                assigned <- trimws(tok[3])
                genbank <- trimws(tok[5])
                refseq <- trimws(tok[7])
                ucsc <- if (length(tok) >= 10) trimws(tok[10]) else ""
                label <- if (nzchar(assigned) && !tolower(assigned) %in% c("na", ".")) assigned else seq_name
                out$chr_map <- add_chr_map(out$chr_map, seq_name, label)
                out$chr_map <- add_chr_map(out$chr_map, genbank, label)
                out$chr_map <- add_chr_map(out$chr_map, refseq, label)
                out$chr_map <- add_chr_map(out$chr_map, ucsc, label)
            }
        }
    }

    assign(key, out, envir = .assembly_report_cache)
    out
}

parse_assembly_stats_file <- function(stats_path) {
    sp <- as.character(stats_path %||% "")
    if (!nzchar(sp) || !file.exists(sp)) {
        return(list(meta = list(), metrics = data.frame(statistic = character(0), value = character(0), stringsAsFactors = FALSE)))
    }
    key <- normalizePath(sp, winslash = "/", mustWork = FALSE)
    if (exists(key, envir = .assembly_stats_cache, inherits = FALSE)) {
        return(get(key, envir = .assembly_stats_cache, inherits = FALSE))
    }

    out <- list(meta = list(), metrics = data.frame(statistic = character(0), value = character(0), stringsAsFactors = FALSE))
    lines <- tryCatch(readLines(sp, warn = FALSE), error = function(e) character(0))
    if (length(lines) == 0) {
        assign(key, out, envir = .assembly_stats_cache)
        return(out)
    }

    meta_pat <- "^#\\s*([^#][^:]+):\\s*(.*)$"
    for (ln in lines) {
        m <- stringr::str_match(ln, meta_pat)
        if (!all(is.na(m))) {
            k <- tolower(trimws(as.character(m[1, 2] %||% "")))
            v <- trimws(as.character(m[1, 3] %||% ""))
            if (nzchar(k) && nzchar(v) && is.null(out$meta[[k]])) {
                out$meta[[k]] <- v
            }
        }
    }

    hdr_idx <- grep("^#\\s*unit-name\\t", lines)
    if (length(hdr_idx) > 0) {
        data_lines <- lines[seq.int(hdr_idx[1] + 1L, length(lines))]
        data_lines <- data_lines[!startsWith(data_lines, "#") & nzchar(trimws(data_lines))]
        if (length(data_lines) > 0) {
            rows <- lapply(data_lines, function(ln) {
                tok <- strsplit(ln, "\t", fixed = TRUE)[[1]]
                if (length(tok) < 6) {
                    return(NULL)
                }
                data.frame(
                    unit_name = as.character(tok[1]),
                    statistic = as.character(tok[5]),
                    value = as.character(tok[6]),
                    stringsAsFactors = FALSE
                )
            })
            rows <- rows[!vapply(rows, is.null, logical(1))]
            if (length(rows) > 0) {
                df <- do.call(rbind, rows)
                df <- df[tolower(trimws(df$unit_name)) == "all", c("statistic", "value"), drop = FALSE]
                if (nrow(df) > 0) {
                    df$statistic <- trimws(as.character(df$statistic))
                    df$value <- trimws(as.character(df$value))
                    df <- df[nzchar(df$statistic), , drop = FALSE]
                    df <- df[!duplicated(df$statistic), , drop = FALSE]
                    out$metrics <- df
                }
            }
        }
    }

    assign(key, out, envir = .assembly_stats_cache)
    out
}

get_assembly_info_bundle <- function(report_path = "", stats_path = "") {
    rep_info <- parse_assembly_report_file(report_path)
    st_info <- parse_assembly_stats_file(stats_path)
    meta <- st_info$meta
    rep_meta <- rep_info$meta
    if (length(rep_meta) > 0) {
        for (k in names(rep_meta)) {
            if (is.null(meta[[k]]) || !nzchar(as.character(meta[[k]] %||% ""))) {
                meta[[k]] <- rep_meta[[k]]
            }
        }
    }
    list(
        meta = meta,
        metrics = st_info$metrics,
        chr_map = rep_info$chr_map
    )
}

get_assembly_report_path_for_annotation <- function(annotation_file_path, base_dir = ".") {
    ap <- as.character(annotation_file_path %||% "")
    if (!nzchar(ap) || !file.exists(ap)) {
        return("")
    }
    key <- normalizePath(ap, winslash = "/", mustWork = FALSE)
    if (exists(key, envir = .annotation_report_path_cache, inherits = FALSE)) {
        return(as.character(get(key, envir = .annotation_report_path_cache, inherits = FALSE) %||% ""))
    }

    reg <- get_preloaded_species_registry(registry_path = file.path("annotations", "registry.tsv"), base_dir = base_dir)
    if (nrow(reg) == 0) {
        assign(key, "", envir = .annotation_report_path_cache)
        return("")
    }
    ann_norm <- normalizePath(as.character(reg$annotation_path %||% ""), winslash = "/", mustWork = FALSE)
    hit_idx <- which(ann_norm == key)
    if (length(hit_idx) == 0) {
        assign(key, "", envir = .annotation_report_path_cache)
        return("")
    }
    rp <- as.character(reg$assembly_report_path[hit_idx[1]] %||% "")
    if (!nzchar(rp) || !file.exists(rp)) rp <- ""
    assign(key, rp, envir = .annotation_report_path_cache)
    rp
}

resolve_icon_web_path <- function(icon_value, base_dir = ".") {
    default_icon <- if (file.exists(normalizePath(file.path(base_dir, "www", "icons", "DNA.ico"), winslash = "/", mustWork = FALSE))) "/icons/DNA.ico" else "/icons/dna.ico"
    p <- trimws(as.character(icon_value %||% ""))
    if (!nzchar(p)) {
        return(default_icon)
    }
    if (grepl("^https?://", p, ignore.case = TRUE)) {
        return(p)
    }
    if (startsWith(p, "/")) {
        return(p)
    }

    p_abs <- if (grepl("^[A-Za-z]:", p) || startsWith(p, "/")) {
        normalizePath(p, winslash = "/", mustWork = FALSE)
    } else {
        normalizePath(file.path(base_dir, p), winslash = "/", mustWork = FALSE)
    }
    www_dir <- normalizePath(file.path(base_dir, "www"), winslash = "/", mustWork = FALSE)
    if (file.exists(p_abs) && startsWith(p_abs, paste0(www_dir, "/"))) {
        rel <- substring(p_abs, nchar(www_dir) + 2)
        return(paste0("/", rel))
    }

    p2 <- sub("^www/", "", p)
    if (file.exists(normalizePath(file.path(base_dir, "www", p2), winslash = "/", mustWork = FALSE))) {
        return(paste0("/", p2))
    }
    default_icon
}

get_preloaded_species_registry <- function(registry_path = file.path("annotations", "registry.tsv"), base_dir = ".") {
    reg_abs <- resolve_catalog_path(registry_path, base_dir = base_dir)
    if (is.na(reg_abs) || !file.exists(reg_abs)) {
        return(data.frame())
    }

    finfo <- file.info(reg_abs)
    cache_key <- paste0(reg_abs, "::", as.numeric(finfo$mtime[1] %||% 0))
    if (exists(cache_key, envir = .preloaded_registry_cache, inherits = FALSE)) {
        return(get(cache_key, envir = .preloaded_registry_cache, inherits = FALSE))
    }

    reg <- tryCatch(
        read.delim(reg_abs, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE),
        error = function(e) data.frame()
    )
    if (nrow(reg) == 0) {
        return(data.frame())
    }

    required_cols <- c(
        "species_id", "label", "organism", "taxid",
        "annotation", "annotation_tabix", "annotation_index",
        "genome", "genome_2bit", "aliases", "icon"
    )
    for (nm in setdiff(required_cols, colnames(reg))) reg[[nm]] <- NA_character_

    reg$species_id <- ifelse(
        nzchar(trimws(as.character(reg$species_id))),
        trimws(as.character(reg$species_id)),
        make.names(trimws(as.character(reg$organism %||% reg$label)), unique = TRUE)
    )
    reg$label <- ifelse(
        nzchar(trimws(as.character(reg$label))),
        trimws(as.character(reg$label)),
        trimws(as.character(reg$organism))
    )
    reg$organism <- trimws(as.character(reg$organism))
    reg$taxid <- suppressWarnings(as.integer(reg$taxid))

    if ("genome_fasta" %in% colnames(reg)) {
        missing_genome <- !nzchar(trimws(as.character(reg$genome %||% "")))
        reg$genome[missing_genome] <- as.character(reg$genome_fasta[missing_genome] %||% "")
    }

    reg$annotation_rel <- trimws(as.character(reg$annotation))
    reg$annotation_tabix_rel <- trimws(as.character(reg$annotation_tabix))
    reg$annotation_index_rel <- trimws(as.character(reg$annotation_index))
    reg$genome_rel <- trimws(as.character(reg$genome))
    reg$genome_2bit_rel <- trimws(as.character(reg$genome_2bit))

    reg$annotation_plain_path <- vapply(reg$annotation_rel, resolve_catalog_path, character(1), base_dir = base_dir)
    reg$annotation_tabix_path <- vapply(reg$annotation_tabix_rel, resolve_catalog_path, character(1), base_dir = base_dir)
    reg$annotation_index_path <- vapply(reg$annotation_index_rel, resolve_catalog_path, character(1), base_dir = base_dir)
    reg$genome_plain_path <- vapply(reg$genome_rel, resolve_catalog_path, character(1), base_dir = base_dir)
    reg$genome_2bit_path <- vapply(reg$genome_2bit_rel, resolve_catalog_path, character(1), base_dir = base_dir)

    reg$annotation_tabix_ready <- vapply(seq_len(nrow(reg)), function(i) {
        tabix_path <- as.character(reg$annotation_tabix_path[i] %||% "")
        index_path <- as.character(reg$annotation_index_path[i] %||% "")
        if (is.na(tabix_path)) tabix_path <- ""
        if (is.na(index_path) || !nzchar(index_path) || !file.exists(index_path)) index_path <- find_existing_tabix_index(tabix_path)
        ok <- is_tabix_annotation_file(tabix_path, index_path = index_path)
        if (ok) set_tabix_index_override(tabix_path, index_path)
        ok
    }, logical(1))
    reg$annotation_mode <- ifelse(reg$annotation_tabix_ready, "tabix", "plain")
    reg$annotation_path <- ifelse(reg$annotation_tabix_ready, reg$annotation_tabix_path, reg$annotation_plain_path)

    reg$genome_2bit_exists <- vapply(reg$genome_2bit_path, function(p) {
        p <- as.character(p %||% "")
        !is.na(p) && nzchar(p) && file.exists(p)
    }, logical(1))
    reg$genome_mode <- ifelse(reg$genome_2bit_exists, "2bit", "fasta")
    reg$genome_path <- ifelse(reg$genome_2bit_exists, reg$genome_2bit_path, reg$genome_plain_path)

    stats_files <- lapply(seq_len(nrow(reg)), function(i) {
        resolve_stats_files_for_entry(
            annotation_path = as.character(reg$annotation_rel[i] %||% ""),
            annotation_tabix_path = as.character(reg$annotation_tabix_rel[i] %||% ""),
            genome_path = as.character(reg$genome_rel[i] %||% ""),
            genome_2bit_path = as.character(reg$genome_2bit_rel[i] %||% ""),
            base_dir = base_dir
        )
    })
    reg$assembly_report_path <- vapply(stats_files, function(x) as.character(x$report %||% ""), character(1))
    reg$assembly_stats_path <- vapply(stats_files, function(x) as.character(x$stats %||% ""), character(1))
    reg$assembly_report_exists <- vapply(reg$assembly_report_path, function(p) {
        p <- as.character(p %||% "")
        nzchar(p) && file.exists(p)
    }, logical(1))
    reg$assembly_stats_exists <- vapply(reg$assembly_stats_path, function(p) {
        p <- as.character(p %||% "")
        nzchar(p) && file.exists(p)
    }, logical(1))

    reg$annotation_exists <- vapply(reg$annotation_path, function(p) {
        p <- as.character(p %||% "")
        !is.na(p) && nzchar(p) && file.exists(p)
    }, logical(1))
    reg$genome_exists <- vapply(reg$genome_path, function(p) {
        p <- as.character(p %||% "")
        !is.na(p) && nzchar(p) && file.exists(p)
    }, logical(1))
    reg$icon_url <- vapply(as.character(reg$icon %||% ""), resolve_icon_web_path, character(1), base_dir = base_dir)
    reg$ready <- reg$annotation_exists

    out <- reg
    assign(cache_key, out, envir = .preloaded_registry_cache)
    out
}

gff_cache_key <- function(file_path) {
    finfo <- file.info(file_path)
    cache_id_path <- canonical_cache_identity_path(file_path, base_dir = ".")
    if (nrow(finfo) == 0 || is.na(finfo$mtime[1])) {
        return(paste0(cache_id_path %||% as.character(file_path %||% ""), "::unknown::", .gff_index_cache_version))
    }
    size_num <- suppressWarnings(as.numeric(finfo$size[1] %||% NA_real_))
    mtime_num <- suppressWarnings(as.numeric(finfo$mtime[1] %||% NA_real_))
    size_key <- if (is.finite(size_num) && !is.na(size_num)) as.character(as.integer(round(size_num))) else "unknown_size"
    mtime_key <- if (is.finite(mtime_num) && !is.na(mtime_num)) as.character(as.integer(round(mtime_num))) else "unknown_mtime"
    paste0(
        cache_id_path,
        "::",
        size_key,
        "::",
        mtime_key,
        "::",
        .gff_index_cache_version
    )
}

parse_gff_attributes <- function(attr) {
    parts <- unlist(strsplit(attr, ";", fixed = TRUE))
    kv <- lapply(parts, function(p) {
        p <- trimws(p)
        if (!nzchar(p)) {
            return(NULL)
        }
        if (grepl("=", p, fixed = TRUE)) {
            kvp <- strsplit(p, "=", fixed = TRUE)[[1]]
            list(key = safe_url_decode(kvp[1]), value = safe_url_decode(paste(kvp[-1], collapse = "=")))
        } else {
            m <- str_match(p, '^([^\\s]+)\\s+"([^"]+)"')
            if (!all(is.na(m))) list(key = safe_url_decode(m[1, 2]), value = safe_url_decode(m[1, 3])) else list(key = NA_character_, value = safe_url_decode(p))
        }
    })
    kv <- kv[!vapply(kv, is.null, logical(1))]
    if (length(kv) == 0) {
        return(list())
    }
    keys <- tolower(vapply(kv, function(x) x$key, character(1)))
    vals <- vapply(kv, function(x) x$value, character(1))
    split(vals, keys)
}

safe_url_decode <- function(x) {
    x_chr <- as.character(x)
    if (length(x_chr) == 0) {
        return(character(0))
    }
    na_mask <- is.na(x_chr)
    x_tmp <- x_chr
    x_tmp[na_mask] <- ""
    # Protect stray '%' that are not valid hex escapes.
    x_tmp <- gsub("%(?![0-9A-Fa-f]{2})", "%25", x_tmp, perl = TRUE)
    out <- tryCatch(
        suppressWarnings(utils::URLdecode(x_tmp)),
        error = function(e) x_tmp
    )
    out <- as.character(out)
    out[na_mask] <- NA_character_
    out
}

normalize_gene_token <- function(x) {
    x <- tolower(safe_url_decode(x))
    x <- gsub("[\"']", "", x)
    trimws(x)
}
normalize_gene_compact <- function(x) {
    x <- normalize_gene_token(x)
    gsub("[;._\\-\\s]", "", x)
}

is_known_gene_stable_id <- function(x) {
    v <- tolower(trimws(as.character(x %||% "")))
    v <- gsub("[\"']", "", safe_url_decode(v))
    grepl("^(gene:|transcript:|cds:)?bgiosga\\d+([_-][tp]a)?$", v) ||
        grepl("^loc_os\\d{2}g\\d{5,}$", v) ||
        grepl("^os\\d{2}g\\d{5,}$", v) ||
        grepl("^ens[a-z]{0,6}g\\d+$", v)
}

extract_gene_query_alpha_core <- function(q) {
    comp <- gsub("[^a-z0-9]+", "", normalize_gene_token(q))
    a <- gsub("[^a-z]+", "", comp)
    if (startsWith(a, "os") && nchar(a) > 4) a <- sub("^os", "", a)
    a
}

extract_gene_query_digit_core <- function(q) {
    comp <- gsub("[^a-z0-9]+", "", normalize_gene_token(q))
    gsub("[^0-9]+", "", comp)
}

extract_gene_query_digit_chunks <- function(q) {
    qn <- normalize_gene_token(q)
    unlist(regmatches(qn, gregexpr("[0-9]+", qn, perl = TRUE)))
}

extract_token_digit_chunks <- function(tok) {
    tc <- gsub("[^a-z0-9]+", "", tolower(as.character(tok %||% "")))
    unlist(regmatches(tc, gregexpr("[0-9]+", tc, perl = TRUE)))
}

digit_chunks_compatible <- function(query_chunks, token_chunks) {
    q <- as.character(query_chunks %||% character(0))
    t <- as.character(token_chunks %||% character(0))
    q <- q[nzchar(q)]
    t <- t[nzchar(t)]
    if (length(q) == 0 || length(t) == 0) {
        return(FALSE)
    }
    if (identical(q, t)) {
        return(TRUE)
    }
    if (identical(paste0(q, collapse = ""), paste0(t, collapse = ""))) {
        return(TRUE)
    }
    # Common notation compatibility: HKT1;1 can map to HKT1.
    if (length(q) >= 2 && length(t) == 1 && all(q == q[1]) && identical(q[1], t[1])) {
        return(TRUE)
    }
    FALSE
}

is_symbol_like_gene_query <- function(q) {
    comp <- gsub("[^a-z0-9]+", "", normalize_gene_token(q))
    if (!nzchar(comp)) {
        return(FALSE)
    }
    grepl("[a-z]", comp) && grepl("[0-9]", comp) && !is_known_gene_stable_id(comp)
}

collect_result_evidence_tokens <- function(res_obj, alias_candidate = NULL) {
    txt <- c(
        alias_candidate,
        as.character(res_obj$matched_gene_name %||% ""),
        as.character(res_obj$matched_gene_id %||% "")
    )

    if (!is.null(res_obj$data) && nrow(res_obj$data) > 0 && "V9" %in% colnames(res_obj$data)) {
        attrs <- parse_gff_attributes(as.character(res_obj$data$V9[1] %||% ""))
        keys <- c("name", "gene", "gene_name", "description", "product", "note", "gene_synonym", "id", "gene_id", "locus_tag")
        for (k in keys) {
            v <- attrs[[k]]
            if (!is.null(v) && length(v) > 0) {
                txt <- c(txt, as.character(v))
            }
        }
    }

    txt <- as.character(txt %||% character(0))
    txt <- trimws(safe_url_decode(txt))
    txt <- txt[!is.na(txt) & nzchar(txt)]
    txt <- txt[tolower(txt) != "na"]
    unique(tolower(txt))
}

is_alias_result_compatible <- function(input_gene, alias_candidate, res_obj,
                                      organism = NULL, taxid = NULL) {
    if (is.null(res_obj) || is.null(res_obj$data) || nrow(res_obj$data) == 0) {
        return(FALSE)
    }
    if (!is_symbol_like_gene_query(input_gene)) {
        return(TRUE)
    }

    # Collect local evidence tokens from the GFF annotation
    evidence <- collect_result_evidence_tokens(res_obj, alias_candidate)
    if (length(evidence) == 0) {
        return(FALSE)
    }

    input_clean <- tolower(trimws(input_gene))
    evidence_clean <- tolower(trimws(evidence))

    # Compact versions to ignore punctuation (hkt1;5 -> hkt15)
    # while preserving STRICT matching (hkt1 != hkt15)
    input_compact <- gsub("[^a-z0-9]", "", input_clean)
    evidence_compact <- gsub("[^a-z0-9]", "", evidence_clean)

    # EXACT match: input gene name found directly in annotation tokens
    if (input_clean %in% evidence_clean || input_compact %in% evidence_compact) {
        return(TRUE)
    }

    # If we reach here, the input gene name (e.g. "nhx2") is NOT directly
    # in the annotation, but the external API returned alias_candidate
    # (e.g. "LOC4337811") which WAS found via exact match in the annotation.
    # Trust the external API's alias relationship — the alias_candidate
    # bridged the gap between the user's query and the annotation file.
    # The downstream scoring system (alias_quality_score, classify_result_rank,
    # result_name_penalty) handles ranking and false-positive filtering.
    return(TRUE)
}

normalize_lookup_alias <- function(x) {
    v <- as.character(x %||% "")
    v <- trimws(utils::URLdecode(v))
    if (is.na(v)) "" else v
}

is_low_specific_lookup_alias <- function(x) {
    a <- tolower(normalize_lookup_alias(x))
    if (!nzchar(a)) {
        return(TRUE)
    }
    if (grepl("(^|[-_.])e\\d+$", a)) {
        return(TRUE)
    }
    if (grepl("^cds[:._-]", a)) {
        return(TRUE)
    }
    if (grepl("^transcript[:._-]", a)) {
        return(TRUE)
    }
    if (grepl("^mrna[:._-]", a)) {
        return(TRUE)
    }
    FALSE
}

lookup_alias_quality_score <- function(alias_txt, input_gene) {
    a <- normalize_lookup_alias(alias_txt)
    if (!nzchar(a)) {
        return(-999)
    }
    al <- tolower(a)
    input_norm <- tolower(normalize_lookup_alias(input_gene))
    score <- 0
    if (grepl("^[A-Za-z0-9;._:+-]+$", a)) score <- score + 2 else score <- score - 2
    if (grepl("\\s", a)) score <- score - 3
    if (nchar(a) > 40) score <- score - 2
    if (is_low_specific_lookup_alias(a)) score <- score - 8
    if (nzchar(input_norm) && identical(al, input_norm)) score <- score + 4

    in_comp <- gsub("[^a-z0-9]+", "", tolower(as.character(input_gene %||% "")))
    al_comp <- gsub("[^a-z0-9]+", "", al)
    if (nzchar(in_comp) && identical(al_comp, in_comp)) score <- score + 9

    in_alpha <- gsub("[^a-z]+", "", tolower(as.character(input_gene %||% "")))
    if (nzchar(in_alpha) && grepl(in_alpha, al, fixed = TRUE)) score <- score + 5
    score
}

is_internal_gene_display_label <- function(x) {
    txt <- normalize_lookup_alias(x)
    if (!nzchar(txt)) {
        return(TRUE)
    }
    low <- tolower(txt)
    comp <- gsub("[^a-z0-9]+", "", low)
    if (!nzchar(comp)) {
        return(TRUE)
    }
    if (isTRUE(is_known_gene_stable_id(txt))) {
        return(TRUE)
    }
    if (grepl("^(gene|transcript|mrna|cds|rna)[:._-]", low)) {
        return(TRUE)
    }
    if (grepl("^loc[_:-]?[a-z0-9]+$", low) && grepl("[0-9]", low)) {
        return(TRUE)
    }
    if (grepl("^[a-z][0-9][a-z0-9]{4,9}$", low) && !grepl("[;._-]", txt)) {
        return(TRUE)
    }
    FALSE
}

lookup_display_gene_score <- function(label, input_gene = "", matched_gene_name = "", matched_gene_id = "") {
    txt <- normalize_lookup_alias(label)
    if (!nzchar(txt)) {
        return(-Inf)
    }

    low <- tolower(txt)
    score <- 0

    if (grepl("^[A-Za-z0-9;._:+-]+$", txt)) {
        score <- score + 10
    } else {
        score <- score - 4
    }
    if (grepl("\\s", txt)) {
        score <- score - 10
    }
    if (nchar(txt) <= 20) {
        score <- score + 4
    }
    if (grepl("[A-Za-z]", txt)) {
        score <- score + 3
    }
    if (grepl("[A-Z]", txt)) {
        score <- score + 8
    }
    if (grepl("[0-9]", txt)) {
        score <- score + 3
    }
    if (is_symbol_like_gene_query(txt)) {
        score <- score + 14
    }
    if (is_low_specific_lookup_alias(txt)) {
        score <- score - 12
    }
    if (is_internal_gene_display_label(txt)) {
        score <- score - 120
    }

    input_norm <- normalize_lookup_alias(input_gene)
    input_comp <- normalize_gene_compact(input_norm)
    txt_comp <- normalize_gene_compact(txt)
    if (nzchar(input_norm) && identical(low, tolower(input_norm))) {
        score <- score + 10
    }
    if (nzchar(input_comp) && identical(txt_comp, input_comp)) {
        score <- score + 24
    }

    input_alpha <- extract_gene_query_alpha_core(input_norm)
    input_digit <- extract_gene_query_digit_core(input_norm)
    txt_alpha <- extract_gene_query_alpha_core(txt)
    txt_digit <- extract_gene_query_digit_core(txt)
    if (nzchar(input_alpha) && identical(txt_alpha, input_alpha)) {
        score <- score + 8
    }
    if (nzchar(input_digit) && identical(txt_digit, input_digit)) {
        score <- score + 8
    }
    if (digit_chunks_compatible(extract_gene_query_digit_chunks(input_norm), extract_token_digit_chunks(txt))) {
        score <- score + 6
    }

    matched_name_norm <- normalize_lookup_alias(matched_gene_name)
    matched_id_norm <- normalize_lookup_alias(matched_gene_id)
    if (nzchar(matched_name_norm) && identical(low, tolower(matched_name_norm))) {
        score <- score + 6
    }
    if (nzchar(matched_id_norm) && identical(low, tolower(matched_id_norm))) {
        score <- score - 20
    }

    score
}

choose_lookup_display_gene_name <- function(res_obj, query_candidates = character(0), best_alias_used = "", input_gene = "") {
    res_list <- if (is.list(res_obj)) res_obj else list()
    query_vec <- normalize_lookup_query_candidates(query_candidates)
    input_label <- normalize_lookup_alias(input_gene)
    if (!nzchar(input_label) && length(query_vec) > 0) {
        input_label <- query_vec[1]
    }

    matched_name <- normalize_lookup_alias(res_list$matched_gene_name %||% "")
    matched_id <- normalize_lookup_alias(res_list$matched_gene_id %||% "")
    candidates <- normalize_lookup_query_candidates(c(
        best_alias_used,
        matched_name,
        query_vec,
        input_label,
        matched_id
    ))
    if (length(candidates) == 0) {
        return("")
    }

    scores <- vapply(
        candidates,
        lookup_display_gene_score,
        numeric(1),
        input_gene = input_label,
        matched_gene_name = matched_name,
        matched_gene_id = matched_id
    )
    ord <- order(-scores, nchar(candidates), seq_along(candidates))
    best <- candidates[ord][1]
    if (!nzchar(best) || !is.finite(scores[ord][1])) {
        return("")
    }
    best
}

lookup_result_name_penalty <- function(res_obj) {
    nm <- tolower(trimws(as.character(res_obj$matched_gene_name %||% "")))
    if (!nzchar(nm)) {
        return(-2L)
    }
    if (grepl("(^|[-_.])e\\d+$", nm)) {
        return(-6L)
    }
    if (grepl("^transcript[:._-]", nm)) {
        return(-5L)
    }
    if (grepl("^mrna[:._-]", nm)) {
        return(-5L)
    }
    if (grepl("^cds[:._-]", nm)) {
        return(-5L)
    }
    0L
}

classify_lookup_result_rank <- function(res_obj) {
    if (is.null(res_obj) || is.null(res_obj$data) || nrow(res_obj$data) == 0) {
        return(0L)
    }
    feat <- tolower(trimws(as.character(res_obj$data$V3 %||% character(0))))
    if (length(feat) == 0) {
        return(0L)
    }
    has_gene <- any(feat == "gene")
    tx_level_types <- c(
        "mrna", "transcript", "lnc_rna", "trna", "rrna", "snorna", "snrna", "mirna",
        "ncrna", "primary_transcript", "pre_mirna", "guide_rna", "rnase_p_rna",
        "rnase_mrp_rna", "telomerase_rna", "antisense_rna", "srp_rna", "scarna",
        "vault_rna", "y_rna", "antisense_lncrna", "lncrna"
    )
    has_tx <- any(feat %in% tx_level_types)
    has_struct <- any(feat %in% c("exon", "cds", "start_codon", "stop_codon") | grepl("utr", feat))
    if (has_gene) {
        return(3L)
    }
    if (has_tx) {
        return(2L)
    }
    if (has_struct) {
        return(1L)
    }
    0L
}

normalize_lookup_query_candidates <- function(vals) {
    x <- as.character(vals %||% character(0))
    x <- unique(vapply(x, normalize_lookup_alias, character(1)))
    x <- x[nzchar(x)]
    x
}

attach_lookup_result_meta <- function(res_obj, query_candidates = character(0), best_alias_used = "", input_gene = "") {
    out <- if (is.list(res_obj)) {
        res_obj
    } else {
        list(
            data = NULL,
            matched_gene_id = NA_character_,
            matched_gene_name = NA_character_
        )
    }
    out$query_candidates <- normalize_lookup_query_candidates(query_candidates)
    out$best_alias_used <- normalize_lookup_alias(best_alias_used)
    out$display_gene_name <- choose_lookup_display_gene_name(
        out,
        query_candidates = out$query_candidates,
        best_alias_used = out$best_alias_used,
        input_gene = input_gene
    )
    out
}

resolve_external_alias_bridge <- function(input_gene, query_candidates, file_path,
                                          organism = NULL, taxid = NULL,
                                          search_fun = search_gene_in_file) {
    bridge_perf <- app_perf_new_run("ALIAS_BRIDGE")
    app_perf_mark(
        bridge_perf,
        sprintf(
            "start gene=%s candidates=%d file=%s",
            as.character(input_gene %||% ""),
            as.integer(length(query_candidates %||% character(0))),
            basename(as.character(file_path %||% ""))
        ),
        "ALIAS_BRIDGE"
    )
    query_candidates_used <- normalize_lookup_query_candidates(query_candidates)
    if (length(query_candidates_used) == 0) {
        query_candidates_used <- normalize_lookup_query_candidates(c(input_gene))
    }

    alias_candidates <- as.character(query_candidates_used)
    alias_candidates <- unique(vapply(alias_candidates, normalize_lookup_alias, character(1)))
    alias_candidates <- alias_candidates[nzchar(alias_candidates)]
    if (length(alias_candidates) == 0) {
        app_perf_mark(bridge_perf, "no alias candidates", "ALIAS_BRIDGE")
        return(list(
            found = FALSE,
            result = NULL,
            best_alias_used = "",
            query_candidates = query_candidates_used,
            alias_candidates = character(0),
            alias_scores = numeric(0)
        ))
    }

    alias_scores <- vapply(alias_candidates, lookup_alias_quality_score, numeric(1), input_gene = input_gene)
    ord <- order(-alias_scores, nchar(alias_candidates), tolower(alias_candidates))
    alias_candidates <- alias_candidates[ord]
    alias_scores <- alias_scores[ord]
    app_perf_mark(
        bridge_perf,
        sprintf("ranked alias candidates=%d top=%s", as.integer(length(alias_candidates)), as.character(alias_candidates[1] %||% "")),
        "ALIAS_BRIDGE"
    )

    best_res <- NULL
    best_total <- -Inf
    best_alias_used <- ""
    local_hits <- 0L
    for (k in seq_along(alias_candidates)) {
        cand <- alias_candidates[k]
        cand_res <- search_fun(
            file_path,
            cand,
            show_diagnostics = FALSE,
            match_mode = "exact",
            return_meta = TRUE,
            include_bridge_tokens = TRUE
        )
        if (is.null(cand_res$data) || nrow(cand_res$data) == 0) {
            next
        }
        local_hits <- local_hits + 1L
        if (!is_alias_result_compatible(input_gene, cand, cand_res, organism = organism, taxid = taxid)) {
            next
        }

        cand_rank <- classify_lookup_result_rank(cand_res)
        cand_total <- cand_rank * 100 + alias_scores[k] + lookup_result_name_penalty(cand_res)
        if (is.null(best_res) || cand_total > best_total) {
            best_res <- cand_res
            best_total <- cand_total
            best_alias_used <- cand
        }

        if (cand_rank >= 3L && alias_scores[k] >= 2 && lookup_result_name_penalty(cand_res) >= 0) {
            break
        }
    }

    if (!is.null(best_res) && !is.null(best_res$data) && nrow(best_res$data) > 0) {
        app_perf_mark(
            bridge_perf,
            sprintf(
                "resolved alias=%s local_hits=%d matched=%s",
                as.character(best_alias_used %||% ""),
                as.integer(local_hits),
                as.character(best_res$matched_gene_name %||% "")
            ),
            "ALIAS_BRIDGE"
        )
    } else {
        app_perf_mark(
            bridge_perf,
            sprintf("no exact local alias match local_hits=%d", as.integer(local_hits)),
            "ALIAS_BRIDGE"
        )
    }

    list(
        found = !is.null(best_res) && !is.null(best_res$data) && nrow(best_res$data) > 0,
        result = best_res,
        best_alias_used = best_alias_used,
        query_candidates = query_candidates_used,
        alias_candidates = alias_candidates,
        alias_scores = alias_scores
    )
}

extract_gene_candidates_from_attr <- function(attr) {
    attrs <- parse_gff_attributes(attr)
    if (length(attrs) == 0) {
        return(character())
    }
    keys <- c("id", "name", "gene_id", "gene", "gene_synonym", "dbxref", "alias", "locus", "locus_tag", "transcript_id", "transcript", "protein_id", "description", "product", "note")
    keys_present <- intersect(keys, names(attrs))
    vals <- character()
    for (k in keys_present) {
        raw_vals <- attrs[[k]]
        split_pattern <- if (k %in% c("description", "product", "note")) "[,|]" else "[,| ]"
        split_vals <- unlist(strsplit(raw_vals, split_pattern))
        if (k %in% c("description", "product", "note")) {
            # For description fields: only add raw value + specific gene-like tokens
            # Do NOT add arbitrary split fragments as they cause false matches
            vals <- c(vals, raw_vals)

            # Also add the description text STRIPPED of [Source:...] / [...] metadata
            # suffixes. This is critical for matching aliases like
            # "Sodium transporter HKT1;5" against descriptions like
            # "Sodium transporter HKT1%3B5 [Source:UniProtKB/TrEMBL%3BAcc:B8A6S2]"
            cleaned <- trimws(sub("\\s*\\[.*\\]\\s*$", "", raw_vals))
            if (nzchar(cleaned) && cleaned != raw_vals) {
                vals <- c(vals, cleaned)
            }

            # Extract specific gene-identifier patterns
            os_g <- unlist(regmatches(raw_vals, gregexpr("\\bOs\\d{2}g\\d{5,}\\b", raw_vals, ignore.case = TRUE)))
            loc_os <- unlist(regmatches(raw_vals, gregexpr("\\bLOC_Os\\d{2}g\\d{5,}\\b", raw_vals, ignore.case = TRUE)))
            vals <- c(vals, os_g, loc_os)

            # Extract parenthesized content, but ONLY if it looks like a gene/accession ID
            parens <- unlist(regmatches(raw_vals, gregexpr("\\(([^\\s)]+)\\)", raw_vals)))
            parens <- gsub("[()]", "", parens)
            # Only keep tokens that look like identifiers (alphanumeric with at least one letter and one digit, or Os-like)
            is_gene_like <- grepl("^[A-Za-z]+[0-9]", parens) | grepl("^[0-9]+[A-Za-z]", parens) | grepl("^Os\\d{2}g", parens, ignore.case = TRUE)
            vals <- c(vals, parens[is_gene_like])
        } else {
            vals <- c(vals, raw_vals, split_vals[nzchar(split_vals)])
        }
    }
    if (length(vals) == 0) vals <- safe_url_decode(attr)
    unique(vals[nzchar(trimws(vals))])
}

extract_bridge_gene_like_tokens_from_attr <- function(attr) {
    attrs <- parse_gff_attributes(attr)
    if (length(attrs) == 0) {
        return(character(0))
    }

    desc_keys <- intersect(c("description", "product", "note"), names(attrs))
    if (length(desc_keys) == 0) {
        return(character(0))
    }

    out <- character(0)
    token_pattern <- "\\b[A-Za-z][A-Za-z0-9]*(?:[;._-][A-Za-z0-9]+)*\\b"
    for (k in desc_keys) {
        raw_vals <- as.character(attrs[[k]] %||% character(0))
        raw_vals <- raw_vals[nzchar(trimws(raw_vals))]
        if (length(raw_vals) == 0) {
            next
        }

        cleaned_vals <- trimws(sub("\\s*\\[.*\\]\\s*$", "", safe_url_decode(raw_vals)))
        cleaned_vals <- cleaned_vals[nzchar(cleaned_vals)]
        if (length(cleaned_vals) == 0) {
            next
        }

        for (txt in cleaned_vals) {
            matches <- unlist(regmatches(txt, gregexpr(token_pattern, txt, perl = TRUE)))
            if (length(matches) == 0) {
                next
            }
            keep <- vapply(matches, function(tok) {
                tok_trim <- trimws(as.character(tok %||% ""))
                if (!nzchar(tok_trim)) {
                    return(FALSE)
                }
                if (nchar(tok_trim) < 3 || nchar(tok_trim) > 40) {
                    return(FALSE)
                }
                grepl("[A-Za-z]", tok_trim) && grepl("[0-9]", tok_trim)
            }, logical(1))
            out <- c(out, matches[keep])
        }
    }

    unique(out[nzchar(trimws(out))])
}

search_gene_rows_via_bridge_descriptions <- function(attr_vec, gene_names) {
    attrs <- as.character(attr_vec %||% character(0))
    genes <- unique(as.character(gene_names %||% character(0)))
    genes <- genes[nzchar(trimws(genes))]
    if (length(attrs) == 0 || length(genes) == 0) {
        return(integer(0))
    }

    attrs_dec <- safe_url_decode(attrs)
    hits <- rep(FALSE, length(attrs_dec))
    for (gene_txt in genes) {
        gene_dec <- trimws(safe_url_decode(gene_txt))
        if (!nzchar(gene_dec)) {
            next
        }
        pat <- paste0("(^|[^A-Za-z0-9])", escape_regex(gene_dec), "([^A-Za-z0-9]|$)")
        hits <- hits | grepl(pat, attrs_dec, perl = TRUE, ignore.case = TRUE)
    }
    which(hits)
}

escape_regex <- function(string) gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", string)

empty_gff_df <- function() {
    data.frame(
        seqid = character(),
        source = character(),
        type = character(),
        start = numeric(),
        end = numeric(),
        score = character(),
        strand = character(),
        phase = character(),
        attributes = character(),
        stringsAsFactors = FALSE
    )
}

parse_gff_lines_to_df <- function(lines) {
    if (length(lines) == 0) {
        return(empty_gff_df())
    }
    keep <- !startsWith(lines, "#") & nzchar(trimws(lines))
    if (!any(keep)) {
        return(empty_gff_df())
    }
    data_lines <- lines[keep]
    fields <- strsplit(data_lines, "\t", fixed = TRUE)
    ncols <- lengths(fields)
    valid <- ncols >= 9
    if (!any(valid)) {
        return(empty_gff_df())
    }
    fields <- fields[valid]
    ncols <- ncols[valid]

    # Vectorized: build matrix for first 8 columns, handle col 9+ separately
    mat <- do.call(rbind, lapply(fields, function(x) x[1:8]))
    # Column 9+: paste remaining columns (handles embedded tabs in attributes)
    attr_col <- vapply(seq_along(fields), function(i) {
        paste(fields[[i]][9:ncols[i]], collapse = "\t")
    }, character(1))

    data.frame(
        seqid = mat[, 1],
        source = mat[, 2],
        type = mat[, 3],
        start = suppressWarnings(as.numeric(mat[, 4])),
        end = suppressWarnings(as.numeric(mat[, 5])),
        score = mat[, 6],
        strand = mat[, 7],
        phase = mat[, 8],
        attributes = attr_col,
        stringsAsFactors = FALSE
    )
}

stream_gff_gene_rows <- function(file_path, chunk_size = 50000L) {
    if (is.null(file_path) || !nzchar(file_path) || !file.exists(file_path)) {
        return(empty_gff_df())
    }
    con <- if (grepl("\\.(gz|bgz)$", file_path, ignore.case = TRUE)) gzfile(file_path, open = "rt") else file(file_path, open = "r")
    on.exit(close(con), add = TRUE)

    gene_pieces <- list()
    cds_pieces <- list()
    gene_idx <- 0L
    cds_idx <- 0L
    # Regex to match the 3rd tab-delimited column being "gene" or "CDS"
    gene_pattern <- "^[^\t]+\t[^\t]+\tgene\t"
    cds_pattern <- "^[^\t]+\t[^\t]+\t[Cc][Dd][Ss]\t"
    repeat {
        lines <- readLines(con, n = as.integer(chunk_size), warn = FALSE)
        if (length(lines) == 0) break
        # Pre-filter with vectorized grep — skip parsing non-gene lines entirely
        gene_mask <- grepl(gene_pattern, lines, perl = TRUE)
        if (any(gene_mask)) {
            parsed <- parse_gff_lines_to_df(lines[gene_mask])
            if (nrow(parsed) > 0) {
                gene_idx <- gene_idx + 1L
                gene_pieces[[gene_idx]] <- parsed
            }
        } else {
            cds_mask <- grepl(cds_pattern, lines, perl = TRUE)
            if (any(cds_mask)) {
                parsed <- parse_gff_lines_to_df(lines[cds_mask])
                if (nrow(parsed) > 0) {
                    cds_idx <- cds_idx + 1L
                    cds_pieces[[cds_idx]] <- parsed
                }
            }
        }
    }
    if (length(gene_pieces) > 0) {
        return(bind_rows(gene_pieces))
    }
    if (length(cds_pieces) > 0) {
        return(bind_rows(cds_pieces))
    }
    empty_gff_df()
}

build_gene_lookup_maps <- function(gene_attrs) {
    norm_list <- vector("list", length(gene_attrs))
    comp_list <- vector("list", length(gene_attrs))
    for (i in seq_along(gene_attrs)) {
        cands <- extract_gene_candidates_from_attr(gene_attrs[[i]])
        n <- unique(normalize_gene_token(cands))
        c <- unique(normalize_gene_compact(cands))
        norm_list[[i]] <- n[nzchar(n)]
        comp_list[[i]] <- c[nzchar(c)]
    }
    norm_tokens <- unlist(norm_list, use.names = FALSE)
    comp_tokens <- unlist(comp_list, use.names = FALSE)
    norm_rows <- if (length(norm_tokens) > 0) rep(seq_along(gene_attrs), lengths(norm_list)) else integer(0)
    comp_rows <- if (length(comp_tokens) > 0) rep(seq_along(gene_attrs), lengths(comp_list)) else integer(0)
    norm_map <- if (length(norm_tokens) > 0) lapply(split(norm_rows, norm_tokens), unique) else list()
    comp_map <- if (length(comp_tokens) > 0) lapply(split(comp_rows, comp_tokens), unique) else list()
    list(norm_list = norm_list, comp_list = comp_list, norm_map = norm_map, comp_map = comp_map, all_norm_tokens = unique(norm_tokens))
}

build_gff_gene_light_index <- function(file_path) {
    key <- gff_cache_key(file_path)
    cached_idx <- cache_env_get(.gff_gene_light_index_cache, key, default = NULL)
    if (!is.null(cached_idx)) {
        return(cached_idx)
    }

    idx_disk <- load_gff_index_from_disk(file_path, cache_kind = "gene_light", base_dir = ".")
    if (!is.null(idx_disk) && is.list(idx_disk) && !is.null(idx_disk$genes_df) && !is.null(idx_disk$norm_map)) {
        cache_env_set(
            .gff_gene_light_index_cache,
            key,
            idx_disk,
            max_size = annotation_memory_cache_limits$gene_light_max_entries,
            max_bytes = annotation_memory_cache_limits$gene_light_max_bytes
        )
        return(idx_disk)
    }

    genes_df <- stream_gff_gene_rows(file_path)
    attrs <- as.character(genes_df$attributes %||% rep("", nrow(genes_df)))
    maps <- build_gene_lookup_maps(attrs)
    idx <- c(
        list(
            genes_df = genes_df,
            gene_rows = seq_len(nrow(genes_df))
        ),
        maps
    )
    save_gff_index_to_disk(file_path, idx, cache_kind = "gene_light", base_dir = ".")
    cache_env_set(
        .gff_gene_light_index_cache,
        key,
        idx,
        max_size = annotation_memory_cache_limits$gene_light_max_entries,
        max_bytes = annotation_memory_cache_limits$gene_light_max_bytes
    )
    idx
}

resolve_seqname_in_vector <- function(seqid, seq_names = character(0)) {
    seqid <- as.character(seqid %||% "")
    if (!nzchar(seqid) || length(seq_names) == 0) {
        return(NULL)
    }
    candidates <- unique(c(
        seqid,
        paste0("chr", seqid),
        sub("^chr", "", seqid, ignore.case = TRUE),
        paste0("Chr", seqid),
        paste0("chromosome:IRGSP-1.0:", seqid),
        paste0("chromosome:IRGSP:", seqid)
    ))
    hit <- seq_names[seq_names %in% candidates]
    if (length(hit) > 0) {
        return(hit[1])
    }
    for (cand in candidates) {
        matches <- grep(paste0("(^|:)\\Q", cand, "\\E($|:|\\s)"), seq_names, value = TRUE)
        if (length(matches) > 0) {
            return(matches[1])
        }
    }
    NULL
}

scan_tabix_region_gff <- function(file_path, seqid, start_pos, end_pos) {
    if (!is_tabix_annotation_file(file_path) || !requireNamespace("Rsamtools", quietly = TRUE)) {
        return(empty_gff_df())
    }
    seqid <- as.character(seqid %||% "")
    if (!nzchar(seqid)) {
        return(empty_gff_df())
    }
    st <- max(1L, as.integer(start_pos %||% 1L))
    en <- max(st, as.integer(end_pos %||% st))

    idx_override <- get_tabix_index_override(file_path)
    tbx <- if (nzchar(idx_override) && file.exists(idx_override)) {
        Rsamtools::TabixFile(file_path, index = idx_override)
    } else {
        Rsamtools::TabixFile(file_path)
    }
    seq_names <- tryCatch(as.character(Rsamtools::seqnamesTabix(tbx)), error = function(e) character(0))
    resolved_seqname <- resolve_seqname_in_vector(seqid, seq_names = seq_names) %||% seqid
    region <- GenomicRanges::GRanges(
        seqnames = resolved_seqname,
        ranges = IRanges::IRanges(start = st, end = en)
    )

    lines <- tryCatch(
        {
            raw <- Rsamtools::scanTabix(tbx, param = region)
            if (length(raw) == 0) character(0) else raw[[1]]
        },
        error = function(e) character(0)
    )
    parse_gff_lines_to_df(lines)
}

extract_gene_block_from_df <- function(df, gene_id) {
    if (is.null(df) || nrow(df) == 0 || is.null(gene_id) || !nzchar(gene_id)) {
        return(data.frame())
    }

    # Build variant list: decoded form, URL-encoded form, and original as-is
    gene_id_decoded <- tryCatch(safe_url_decode(gene_id), error = function(e) gene_id)
    gene_id_encoded <- tryCatch(utils::URLencode(gene_id_decoded, reserved = TRUE), error = function(e) gene_id)
    # Also try encoding only the semicolon which is the most common case
    gene_id_semi_enc <- gsub(";", "%3B", gene_id, fixed = TRUE)

    variants <- unique(c(gene_id, gene_id_decoded, gene_id_encoded, gene_id_semi_enc))
    variants <- variants[nzchar(variants)]

    # Build a single regex pattern that matches any variant
    variants_esc <- vapply(variants, escape_regex, character(1))
    id_pattern <- paste0("(", paste(variants_esc, collapse = "|"), ")")

    direct_children <- df %>%
        filter(grepl(paste0("ID=", id_pattern, "(;|$)"), attributes) |
            grepl(paste0("Parent=", id_pattern, "(;|$)"), attributes))

    child_ids <- str_extract(direct_children$attributes, "ID=[^;]+") %>%
        str_remove("ID=") %>%
        na.omit()
    grandchildren <- if (length(child_ids) > 0) {
        # Child IDs may also be URL-encoded, build variants for each
        child_variants <- unique(c(child_ids, tryCatch(safe_url_decode(child_ids), error = function(e) character(0))))
        child_variants <- child_variants[!is.na(child_variants) & nzchar(child_variants)]
        child_pattern <- paste0("(", paste(escape_regex(child_variants), collapse = "|"), ")")
        df %>% filter(grepl(paste0("Parent=", child_pattern, "(;|$)"), attributes))
    } else {
        data.frame()
    }
    result_df <- as.data.frame(distinct(bind_rows(direct_children, grandchildren)))
    if (nrow(result_df) == 0) {
        return(result_df)
    }
    colnames(result_df) <- paste0("V", 1:9)
    result_df
}

build_gff_gene_index <- function(file_path) {
    key <- gff_cache_key(file_path)
    cached_idx <- cache_env_get(.gff_gene_index_cache, key, default = NULL)
    if (!is.null(cached_idx)) {
        return(cached_idx)
    }

    df <- load_gff_cached(file_path)
    gene_rows <- which(tolower(df$type) == "gene")
    if (length(gene_rows) == 0L) {
        # Fallback for annotations that only define CDS-level features.
        gene_rows <- which(tolower(df$type) == "cds")
    }
    attrs <- as.character(df$attributes[gene_rows] %||% rep("", length(gene_rows)))
    maps <- build_gene_lookup_maps(attrs)
    idx <- c(
        list(df = df, gene_rows = gene_rows),
        maps
    )
    cache_env_set(
        .gff_gene_index_cache,
        key,
        idx,
        max_size = annotation_memory_cache_limits$gene_index_max_entries,
        max_bytes = annotation_memory_cache_limits$gene_index_max_bytes
    )
    idx
}

search_gene_rows_with_index <- function(idx, gene_names, match_mode = c("flex", "exact")) {
    match_mode <- match.arg(match_mode)
    gene_names <- unique(as.character(gene_names))[nzchar(unique(as.character(gene_names)))]
    if (length(gene_names) == 0) {
        return(integer(0))
    }
    gene_norms <- normalize_gene_token(gene_names)
    gene_compacts <- normalize_gene_compact(gene_names)

    if (match_mode == "exact") {
        rel <- unique(c(unlist(idx$norm_map[gene_norms], use.names = FALSE), unlist(idx$comp_map[gene_compacts], use.names = FALSE)))
        rel <- rel[rel >= 1L & rel <= length(idx$gene_rows)]
        return(idx$gene_rows[rel])
    }

    hit_rel <- which(vapply(seq_along(idx$gene_rows), function(i) {
        any(idx$norm_list[[i]] %in% gene_norms) || any(idx$comp_list[[i]] %in% gene_compacts)
    }, logical(1)))
    idx$gene_rows[hit_rel]
}

load_gff_cached <- function(file_path) {
    key <- gff_cache_key(file_path)
    cached_df <- cache_env_get(.gff_cache, key, default = NULL)
    if (!is.null(cached_df)) {
        return(cached_df)
    }
    col_names <- c("seqid", "source", "type", "start", "end", "score", "strand", "phase", "attributes")
    df <- vroom::vroom(file_path, comment = "#", col_names = col_names, show_col_types = FALSE, delim = "\t", quote = "", altrep = FALSE)
    cache_env_set(
        .gff_cache,
        key,
        df,
        max_size = annotation_memory_cache_limits$gff_max_entries,
        max_bytes = annotation_memory_cache_limits$gff_max_bytes
    )
    df
}

normalize_chr_id <- function(x) {
    x <- tolower(trimws(as.character(x %||% "")))
    x <- str_remove(x, "^chromosome[:_ ]*")
    x <- str_remove(x, "^chr")
    trimws(x)
}

.gff_chr_name_map_cache <- new.env(parent = emptyenv())

get_chromosome_name_map <- function(annotation_file_path) {
    if (is.null(annotation_file_path) || !nzchar(annotation_file_path) || !file.exists(annotation_file_path)) {
        return(list())
    }

    key <- gff_cache_key(annotation_file_path)
    if (exists(key, envir = .gff_chr_name_map_cache, inherits = FALSE)) {
        return(get(key, envir = .gff_chr_name_map_cache, inherits = FALSE))
    }

    name_map <- list()

    # Read the top of the GFF where region declarations are typically located
    tryCatch(
        {
            con <- if (grepl("\\.gz$", annotation_file_path)) gzfile(annotation_file_path, "r") else file(annotation_file_path, "r")
            lines <- readLines(con, n = 20000, warn = FALSE)
            close(con)

            region_lines <- grep("\\tregion\\t", lines, value = TRUE, ignore.case = TRUE)
            if (length(region_lines) > 0) {
                for (ln in region_lines) {
                    tok <- strsplit(ln, "\\t")[[1]]
                    if (length(tok) < 9) next
                    chr_id <- trimws(tok[1])
                    attrs <- tok[9]

                    # Check for chromosome=*
                    m_chr <- stringr::str_match(attrs, "(?:^|;)chromosome=([^;]+)")[, 2]
                    if (!is.na(m_chr) && nzchar(trimws(m_chr))) {
                        name_map[[chr_id]] <- paste("Chr", trimws(m_chr))
                        next
                    }

                    # Check for Name=*
                    m_name <- stringr::str_match(attrs, "(?:^|;)Name=([^;]+)")[, 2]
                    if (!is.na(m_name) && nzchar(trimws(m_name))) {
                        val <- trimws(m_name)
                        # Exclude non-chromosomal names like Pltd, MT, etc if they don't look intuitive
                        # Although user might like MT or Pltd. Let's just use it if it's short.
                        if (nchar(val) <= 5 || grepl("^[0-9]+$", val)) {
                            name_map[[chr_id]] <- if (grepl("^[0-9]+$", val)) paste("Chr", val) else val
                        }
                    }
                }
            }
        },
        error = function(e) {
            app_debug_log("Error reading chromosome names: ", e$message)
        }
    )

    assign(key, name_map, envir = .gff_chr_name_map_cache)
    return(name_map)
}

get_short_chromosome_name <- function(chr_id, annotation_file_path, use_report_map = FALSE, report_path = "") {
    chr_id <- as.character(chr_id %||% "")
    if (!nzchar(chr_id) || is.na(chr_id) || is.null(annotation_file_path)) {
        return(chr_id)
    }

    if (isTRUE(use_report_map)) {
        rp <- as.character(report_path %||% "")
        if (!nzchar(rp)) {
            rp <- get_assembly_report_path_for_annotation(annotation_file_path, base_dir = ".")
        }
        if (nzchar(rp) && file.exists(rp)) {
            rep_info <- parse_assembly_report_file(rp)
            rep_map <- rep_info$chr_map
            if (is.list(rep_map) && length(rep_map) > 0) {
                lookup_keys <- unique(c(
                    tolower(trimws(chr_id)),
                    tolower(trimws(sub("\\.\\d+$", "", chr_id))),
                    normalize_chr_id(chr_id)
                ))
                for (kk in lookup_keys) {
                    if (!nzchar(kk)) next
                    hit <- rep_map[[kk]]
                    if (!is.null(hit)) {
                        hit_txt <- trimws(as.character(hit %||% ""))
                        if (nzchar(hit_txt)) {
                            return(hit_txt)
                        }
                    }
                }
            }
        }
    }

    name_map <- get_chromosome_name_map(annotation_file_path)
    if (!is.null(name_map[[chr_id]])) {
        return(as.character(name_map[[chr_id]]))
    }

    # Simple regex fallback if mapping not found, but it has NC_ format
    if (grepl("^NC_0+(\\d+)\\.\\d+$", chr_id)) {
        num <- sub("^NC_0+(\\d+)\\.\\d+$", "\\1", chr_id)
        return(paste("Chr", num))
    }

    return(chr_id)
}

get_chromosome_length_map <- function(annotation_file_path) {
    if (is.null(annotation_file_path) || !nzchar(annotation_file_path) || !file.exists(annotation_file_path)) {
        return(list(raw = numeric(0), norm = numeric(0), source = "missing"))
    }

    key <- gff_cache_key(annotation_file_path)
    if (exists(key, envir = .gff_chr_length_cache, inherits = FALSE)) {
        return(get(key, envir = .gff_chr_length_cache, inherits = FALSE))
    }

    raw_map <- numeric(0)

    # First try explicit sequence-region declarations.
    hdr <- tryCatch(readLines(annotation_file_path, n = 5000, warn = FALSE), error = function(e) character())
    seq_lines <- grep("^##sequence-region\\s+", hdr, value = TRUE)
    if (length(seq_lines) > 0) {
        for (ln in seq_lines) {
            tok <- strsplit(trimws(ln), "\\s+")[[1]]
            if (length(tok) < 4) next
            chr_id <- tok[2]
            st <- suppressWarnings(as.numeric(tok[3]))
            en <- suppressWarnings(as.numeric(tok[4]))
            if (!is.finite(st) || !is.finite(en)) next
            chr_len <- abs(en - st) + 1
            if (!is.na(chr_len) && chr_len > 0) {
                prev <- suppressWarnings(as.numeric(raw_map[chr_id]))
                if (!length(prev) || !is.finite(prev)) prev <- 0
                raw_map[chr_id] <- max(prev, chr_len)
            }
        }
    }

    # Fallback/inference: max coordinate per seqid.
    if (length(raw_map) == 0) {
        if (is_tabix_annotation_file(annotation_file_path)) {
            genes_df <- get_genes_table_from_annotation(annotation_file_path)
            if (!is.null(genes_df) && nrow(genes_df) > 0) {
                inferred <- genes_df %>%
                    transmute(seqid = as.character(chr), end = as.numeric(end)) %>%
                    filter(is.finite(end), !is.na(seqid), nzchar(seqid)) %>%
                    group_by(seqid) %>%
                    summarise(chr_len = max(end, na.rm = TRUE), .groups = "drop")
                if (nrow(inferred) > 0) raw_map <- stats::setNames(as.numeric(inferred$chr_len), inferred$seqid)
            }
        } else {
            df <- load_gff_cached(annotation_file_path)
            if (!is.null(df) && nrow(df) > 0) {
                inferred <- df %>%
                    transmute(seqid = as.character(seqid), end = as.numeric(end)) %>%
                    filter(is.finite(end), !is.na(seqid), nzchar(seqid)) %>%
                    group_by(seqid) %>%
                    summarise(chr_len = max(end, na.rm = TRUE), .groups = "drop")
                if (nrow(inferred) > 0) {
                    raw_map <- stats::setNames(as.numeric(inferred$chr_len), inferred$seqid)
                }
            }
        }
    }

    norm_map <- numeric(0)
    if (length(raw_map) > 0) {
        norm_names <- normalize_chr_id(names(raw_map))
        keep <- nzchar(norm_names)
        if (any(keep)) {
            tmp <- data.frame(norm = norm_names[keep], len = as.numeric(raw_map[keep]), stringsAsFactors = FALSE) %>%
                group_by(norm) %>%
                summarise(len = max(len, na.rm = TRUE), .groups = "drop")
            norm_map <- stats::setNames(as.numeric(tmp$len), tmp$norm)
        }
    }

    out <- list(
        raw = raw_map,
        norm = norm_map,
        source = if (length(seq_lines) > 0) "seq-region" else "inferred"
    )
    assign(key, out, envir = .gff_chr_length_cache)
    out
}

get_chromosome_length_for_chr <- function(annotation_file_path, chr_id) {
    if (is.null(chr_id) || !nzchar(as.character(chr_id %||% ""))) {
        return(NA_real_)
    }
    cmap <- get_chromosome_length_map(annotation_file_path)
    chr_raw <- as.character(chr_id)
    if (chr_raw %in% names(cmap$raw)) {
        return(as.numeric(cmap$raw[[chr_raw]]))
    }
    chr_norm <- normalize_chr_id(chr_raw)
    if (nzchar(chr_norm) && chr_norm %in% names(cmap$norm)) {
        return(as.numeric(cmap$norm[[chr_norm]]))
    }
    NA_real_
}

parse_locus_window_flank_bp <- function(span_mode = "10kb", default_bp = 10000L) {
    mode_txt <- tolower(trimws(as.character(span_mode %||% "10kb")))
    out <- switch(
        mode_txt,
        "gene" = 0L,
        "5kb" = 5000L,
        "10kb" = 10000L,
        "25kb" = 25000L,
        "50kb" = 50000L,
        suppressWarnings(as.integer(default_bp))
    )
    if (!is.finite(out) || is.na(out) || out < 0L) {
        out <- suppressWarnings(as.integer(default_bp))
    }
    as.integer(out)
}

compute_feature_block_span <- function(block_data, preferred_types = character(0), fallback_types = character(0)) {
    if (is.null(block_data)) {
        return(list(start = NA_real_, end = NA_real_, seqid = "", strand = ""))
    }
    df <- as.data.frame(block_data, stringsAsFactors = FALSE)
    if (nrow(df) == 0L) {
        return(list(start = NA_real_, end = NA_real_, seqid = "", strand = ""))
    }
    row_types <- tolower(trimws(as.character(df$V3 %||% rep("", nrow(df)))))
    choose_rows <- function(types) {
        if (length(types) == 0L) return(df[0, , drop = FALSE])
        df[row_types %in% tolower(types), , drop = FALSE]
    }
    span_df <- choose_rows(preferred_types)
    if (nrow(span_df) == 0L) {
        span_df <- choose_rows(fallback_types)
    }
    if (nrow(span_df) == 0L) {
        span_df <- df
    }
    starts <- suppressWarnings(as.numeric(span_df$V4))
    ends <- suppressWarnings(as.numeric(span_df$V5))
    start_val <- suppressWarnings(min(starts, na.rm = TRUE))
    end_val <- suppressWarnings(max(ends, na.rm = TRUE))
    if (!is.finite(start_val) || !is.finite(end_val) || end_val < start_val) {
        start_val <- NA_real_
        end_val <- NA_real_
    }
    seqid_candidates <- c(as.character(span_df$V1 %||% ""), as.character(df$V1 %||% ""))
    seqid_txt <- ""
    for (val in seqid_candidates) {
        if (!is.na(val) && nzchar(trimws(val))) {
            seqid_txt <- trimws(val)
            break
        }
    }
    strand_candidates <- c(as.character(span_df$V7 %||% ""), as.character(df$V7 %||% ""))
    strand_txt <- ""
    for (val in strand_candidates) {
        txt <- trimws(as.character(val %||% ""))
        if (txt %in% c("+", "-")) {
            strand_txt <- txt
            break
        }
    }
    list(start = start_val, end = end_val, seqid = seqid_txt, strand = strand_txt)
}

extract_plot_locus_context <- function(plot_data,
                                       annotation_path = "",
                                       genome_path = "",
                                       flank_bp = 10000L,
                                       plot_id = "",
                                       title_txt = "",
                                       organism_info = NULL,
                                       gene_meta = NULL) {
    if (is.null(plot_data)) {
        return(NULL)
    }
    df <- as.data.frame(plot_data, stringsAsFactors = FALSE)
    if (nrow(df) == 0L) {
        return(NULL)
    }

    tx_types <- c(
        "mrna", "transcript", "lnc_rna", "trna", "rrna", "snorna", "snrna", "mirna",
        "ncrna", "primary_transcript", "pre_mirna", "guide_rna", "rnase_p_rna",
        "rnase_mrp_rna", "telomerase_rna", "antisense_rna", "srp_rna", "scarna",
        "vault_rna", "y_rna", "antisense_lncrna", "lncrna"
    )
    feature_types <- c("exon", "cds", "start_codon", "stop_codon")
    gene_span <- compute_feature_block_span(df, preferred_types = "gene", fallback_types = c(tx_types, feature_types))
    tx_span <- compute_feature_block_span(df, preferred_types = tx_types, fallback_types = c(feature_types, "gene"))

    seqid_txt <- trimws(as.character(gene_span$seqid %||% tx_span$seqid %||% ""))
    if (!nzchar(seqid_txt)) {
        return(NULL)
    }
    strand_txt <- trimws(as.character(tx_span$strand %||% gene_span$strand %||% ""))
    if (!strand_txt %in% c("+", "-")) {
        strand_txt <- "+"
    }
    gene_start <- suppressWarnings(as.numeric(gene_span$start))
    gene_end <- suppressWarnings(as.numeric(gene_span$end))
    tx_start <- suppressWarnings(as.numeric(tx_span$start))
    tx_end <- suppressWarnings(as.numeric(tx_span$end))
    if (!is.finite(gene_start) || !is.finite(gene_end)) {
        gene_start <- tx_start
        gene_end <- tx_end
    }
    if (!is.finite(tx_start) || !is.finite(tx_end)) {
        tx_start <- gene_start
        tx_end <- gene_end
    }
    if (!is.finite(gene_start) || !is.finite(gene_end)) {
        return(NULL)
    }

    flank_int <- parse_locus_window_flank_bp(flank_bp, default_bp = 10000L)
    chr_len <- suppressWarnings(as.numeric(get_chromosome_length_for_chr(annotation_path, seqid_txt)))
    window_start <- max(1L, as.integer(round(gene_start - flank_int)))
    window_end <- as.integer(round(gene_end + flank_int))
    if (is.finite(chr_len) && chr_len > 0) {
        window_end <- min(as.integer(round(chr_len)), window_end)
    }
    if (!is.finite(window_end) || window_end < window_start) {
        return(NULL)
    }

    org_name <- trimws(as.character((organism_info %||% list())$name %||% (gene_meta %||% list())$organism_scientific %||% ""))
    gene_label <- trimws(as.character((gene_meta %||% list())$display_gene_name %||% (gene_meta %||% list())$matched_gene_name %||% ""))
    matched_gene_id <- trimws(as.character((gene_meta %||% list())$matched_gene_id %||% ""))

    list(
        plot_id = trimws(as.character(plot_id %||% "")),
        title = trimws(as.character(title_txt %||% "")),
        organism_name = org_name,
        gene_label = gene_label,
        matched_gene_id = matched_gene_id,
        annotation_path = trimws(as.character(annotation_path %||% "")),
        genome_path = trimws(as.character(genome_path %||% "")),
        seqid = seqid_txt,
        strand = strand_txt,
        gene_start = as.integer(round(gene_start)),
        gene_end = as.integer(round(gene_end)),
        tx_start = if (is.finite(tx_start)) as.integer(round(tx_start)) else NA_integer_,
        tx_end = if (is.finite(tx_end)) as.integer(round(tx_end)) else NA_integer_,
        flank_bp = flank_int,
        window_start = as.integer(window_start),
        window_end = as.integer(window_end),
        chr_len = if (is.finite(chr_len)) as.integer(round(chr_len)) else NA_integer_,
        has_genome = nzchar(trimws(as.character(genome_path %||% ""))) && file.exists(as.character(genome_path %||% ""))
    )
}

extract_locus_window_sequence <- function(locus_ctx) {
    if (is.null(locus_ctx) || !is.list(locus_ctx)) {
        return("")
    }
    fasta_path <- trimws(as.character(locus_ctx$genome_path %||% ""))
    seqid_txt <- trimws(as.character(locus_ctx$seqid %||% ""))
    raw_s <- locus_ctx$window_start %||% NA_integer_
    raw_e <- locus_ctx$window_end %||% NA_integer_
    s <- suppressWarnings(as.integer(raw_s[1L]))
    e <- suppressWarnings(as.integer(raw_e[1L]))
    if (!nzchar(fasta_path) || !file.exists(fasta_path) || !nzchar(seqid_txt) ||
        length(s) == 0L || !is.finite(s) || length(e) == 0L || !is.finite(e) || e < s) {
        return("")
    }
    seq_txt <- tryCatch(
        extract_sequence_from_fasta(fasta_path, seqid_txt, s, e),
        error = function(e) ""
    )
    toupper(gsub("[^ACGTN]", "", as.character(seq_txt %||% "")))
}

build_lastz_job_spec <- function(reference_ctx,
                                 query_ctx,
                                 out_path = "",
                                 format_name = "general",
                                 extra_args = character(0)) {
    ref_ctx <- reference_ctx %||% NULL
    qry_ctx <- query_ctx %||% NULL
    if (is.null(ref_ctx) || is.null(qry_ctx)) {
        return(NULL)
    }
    list(
        engine = "lastz",
        binary = trimws(as.character(Sys.getenv("APP_LASTZ_BIN", "lastz") %||% "lastz")),
        reference = ref_ctx,
        query = qry_ctx,
        format = trimws(as.character(format_name %||% "general")),
        out_path = trimws(as.character(out_path %||% "")),
        extra_args = as.character(extra_args %||% character(0))
    )
}

resolve_lastz_binary <- function(candidate = Sys.getenv("APP_LASTZ_BIN", "lastz")) {
    candidate_txt <- trimws(as.character(candidate %||% "lastz"))
    if (!nzchar(candidate_txt)) {
        candidate_txt <- "lastz"
    }

    if (grepl("/", candidate_txt, fixed = TRUE)) {
        if (file.exists(candidate_txt)) {
            return(list(
                available = TRUE,
                path = normalizePath(candidate_txt, winslash = "/", mustWork = FALSE),
                source = "explicit_path",
                requested = candidate_txt
            ))
        }
    }

    path_hit <- Sys.which(candidate_txt)
    if (nzchar(path_hit)) {
        return(list(
            available = TRUE,
            path = normalizePath(path_hit, winslash = "/", mustWork = FALSE),
            source = if (identical(candidate_txt, "lastz")) "path" else "named_binary",
            requested = candidate_txt
        ))
    }

    common_paths <- c(
        "/opt/homebrew/bin/lastz",
        "/usr/local/bin/lastz",
        "/usr/bin/lastz"
    )
    common_hit <- common_paths[file.exists(common_paths)][1]
    if (length(common_hit) == 1L && nzchar(common_hit)) {
        return(list(
            available = TRUE,
            path = normalizePath(common_hit, winslash = "/", mustWork = FALSE),
            source = "common_path",
            requested = candidate_txt
        ))
    }

    list(
        available = FALSE,
        path = "",
        source = "missing",
        requested = candidate_txt
    )
}

wrap_fasta_sequence_lines <- function(seq_txt, width = 80L) {
    seq_txt <- gsub("\\s+", "", as.character(seq_txt %||% ""))
    if (!nzchar(seq_txt)) {
        return(character(0))
    }
    width <- suppressWarnings(as.integer(width))
    if (!is.finite(width) || width < 1L) {
        width <- 80L
    }
    starts <- seq.int(1L, nchar(seq_txt), by = width)
    substring(seq_txt, starts, pmin(starts + width - 1L, nchar(seq_txt)))
}

write_locus_temp_fasta <- function(seq_txt, record_name = "sequence", dir_path = tempdir()) {
    seq_clean <- toupper(gsub("[^ACGTN]", "", as.character(seq_txt %||% "")))
    if (!nzchar(seq_clean)) {
        return("")
    }
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    record_txt <- trimws(gsub("[^A-Za-z0-9._:-]+", "_", as.character(record_name %||% "sequence")))
    if (!nzchar(record_txt)) {
        record_txt <- "sequence"
    }
    out_path <- tempfile(pattern = paste0("ctv_", record_txt, "_"), fileext = ".fa", tmpdir = dir_path)
    writeLines(c(paste0(">", record_txt), wrap_fasta_sequence_lines(seq_clean, width = 80L)), out_path, useBytes = TRUE)
    out_path
}

parse_lastz_general_output <- function(raw_lines,
                                       reference_ctx = NULL,
                                       query_ctx = NULL) {
    if (is.null(raw_lines) || length(raw_lines) == 0L) {
        return(data.frame(stringsAsFactors = FALSE))
    }
    txt <- paste(as.character(raw_lines), collapse = "\n")
    txt <- trimws(txt)
    if (!nzchar(txt)) {
        return(data.frame(stringsAsFactors = FALSE))
    }
    con <- textConnection(txt)
    on.exit(close(con), add = TRUE)
    fields <- c(
        "name1", "start1", "end1",
        "name2", "strand2", "start2_pos", "end2_pos",
        "identity_pct", "coverage_pct",
        "length1", "length2",
        "nmatch", "nmismatch", "ncolumn", "score"
    )
    df <- tryCatch(
        utils::read.table(
            con,
            sep = "\t",
            quote = "",
            comment.char = "",
            header = FALSE,
            stringsAsFactors = FALSE,
            fill = TRUE,
            col.names = fields
        ),
        error = function(e) data.frame(stringsAsFactors = FALSE)
    )
    if (!is.data.frame(df) || nrow(df) == 0L) {
        return(data.frame(stringsAsFactors = FALSE))
    }
    num_cols <- c(
        "start1", "end1", "start2_pos", "end2_pos",
        "identity_pct", "coverage_pct",
        "length1", "length2",
        "nmatch", "nmismatch", "ncolumn", "score"
    )
    for (nm in intersect(num_cols, names(df))) {
        raw_num <- as.character(df[[nm]] %||% "")
        raw_num <- gsub("%", "", raw_num, fixed = TRUE)
        df[[nm]] <- suppressWarnings(as.numeric(raw_num))
    }
    df$strand2 <- trimws(as.character(df$strand2 %||% ""))
    df$ref_start <- suppressWarnings(as.integer(round(df$start1)))
    df$ref_end <- suppressWarnings(as.integer(round(df$end1)))
    df$qry_start <- suppressWarnings(as.integer(round(pmin(df$start2_pos, df$end2_pos, na.rm = TRUE))))
    df$qry_end <- suppressWarnings(as.integer(round(pmax(df$start2_pos, df$end2_pos, na.rm = TRUE))))
    df$align_len <- suppressWarnings(as.integer(round(pmax(df$length1, df$length2, df$ncolumn, na.rm = TRUE))))
    df$ref_plot_id <- as.character((reference_ctx %||% list())$plot_id %||% "")
    df$query_plot_id <- as.character((query_ctx %||% list())$plot_id %||% "")
    df$ref_seqid <- as.character((reference_ctx %||% list())$seqid %||% "")
    df$query_seqid <- as.character((query_ctx %||% list())$seqid %||% "")
    raw_ref_ws <- (reference_ctx %||% list())$window_start %||% NA_integer_
    raw_qry_ws <- (query_ctx %||% list())$window_start %||% NA_integer_
    df$ref_window_start <- suppressWarnings(as.integer(raw_ref_ws[1L]))
    df$query_window_start <- suppressWarnings(as.integer(raw_qry_ws[1L]))
    if (nrow(df) > 0L && length(df$ref_window_start) > 0L && all(is.finite(df$ref_window_start))) {
        df$ref_genomic_start <- df$ref_window_start + df$ref_start - 1L
        df$ref_genomic_end <- df$ref_window_start + df$ref_end - 1L
    } else {
        df$ref_genomic_start <- df$ref_start
        df$ref_genomic_end <- df$ref_end
    }
    if (nrow(df) > 0L && length(df$query_window_start) > 0L && all(is.finite(df$query_window_start))) {
        df$query_genomic_start <- df$query_window_start + df$qry_start - 1L
        df$query_genomic_end <- df$query_window_start + df$qry_end - 1L
    } else {
        df$query_genomic_start <- df$qry_start
        df$query_genomic_end <- df$qry_end
    }
    df
}

run_local_locus_alignment <- function(reference_ctx,
                                      query_ctx,
                                      engine = "lastz",
                                      out_path = "",
                                      format_name = "general",
                                      extra_args = character(0)) {
    engine_txt <- tolower(trimws(as.character(engine %||% "lastz")))
    if (!engine_txt %in% c("lastz")) {
        return(list(
            status = "unsupported_engine",
            engine = engine_txt,
            blocks = data.frame(stringsAsFactors = FALSE)
        ))
    }
    job <- build_lastz_job_spec(reference_ctx, query_ctx, out_path = out_path, format_name = format_name, extra_args = extra_args)
    if (is.null(job)) {
        return(list(
            status = "invalid_input",
            engine = engine_txt,
            blocks = data.frame(stringsAsFactors = FALSE)
        ))
    }
    bin_info <- resolve_lastz_binary(job$binary %||% "lastz")
    bin_path <- trimws(as.character(bin_info$path %||% ""))
    if (!isTRUE(bin_info$available) || !nzchar(bin_path)) {
        return(list(
            status = "engine_unavailable",
            engine = engine_txt,
            binary = as.character(bin_info$requested %||% job$binary %||% "lastz"),
            binary_path = "",
            binary_source = as.character(bin_info$source %||% "missing"),
            setup_hint = "Install LASTZ locally or set APP_LASTZ_BIN to the binary path.",
            job = job,
            blocks = data.frame(stringsAsFactors = FALSE)
        ))
    }
    ref_seq <- extract_locus_window_sequence(reference_ctx)
    qry_seq <- extract_locus_window_sequence(query_ctx)
    if (!nzchar(ref_seq) || !nzchar(qry_seq)) {
        return(list(
            status = "missing_sequence",
            engine = engine_txt,
            binary = bin_path,
            binary_path = bin_path,
            binary_source = as.character(bin_info$source %||% ""),
            job = job,
            blocks = data.frame(stringsAsFactors = FALSE)
        ))
    }
    run_dir <- tempfile(pattern = "ctv_lastz_")
    dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
    ref_name <- paste0("ref_", sanitize_cache_key((reference_ctx %||% list())$plot_id %||% "reference"))
    qry_name <- paste0("qry_", sanitize_cache_key((query_ctx %||% list())$plot_id %||% "query"))
    ref_fa <- write_locus_temp_fasta(ref_seq, record_name = ref_name, dir_path = run_dir)
    qry_fa <- write_locus_temp_fasta(qry_seq, record_name = qry_name, dir_path = run_dir)
    if (!nzchar(ref_fa) || !nzchar(qry_fa)) {
        unlink(run_dir, recursive = TRUE, force = TRUE)
        return(list(
            status = "temp_fasta_failed",
            engine = engine_txt,
            binary = bin_path,
            binary_path = bin_path,
            binary_source = as.character(bin_info$source %||% ""),
            job = job,
            blocks = data.frame(stringsAsFactors = FALSE)
        ))
    }
    out_fields <- paste(
        c(
            "name1", "start1", "end1",
            "name2", "strand2", "start2+", "end2+",
            "id%", "cov%",
            "length1", "length2",
            "nmatch", "nmismatch", "ncolumn", "score"
        ),
        collapse = ","
    )
    out_file <- if (nzchar(trimws(as.character(out_path %||% "")))) {
        as.character(out_path)
    } else {
        file.path(run_dir, "lastz_general.tsv")
    }
    args <- c(
        ref_fa,
        qry_fa,
        paste0("--format=general-:", out_fields),
        "--ambiguous=iupac",
        paste0("--output=", out_file)
    )
    if (length(extra_args) > 0L) {
        args <- c(args, as.character(extra_args))
    }
    run_res <- tryCatch(
        if (requireNamespace("processx", quietly = TRUE)) {
            processx::run(bin_path, args = args, echo = FALSE, error_on_status = FALSE)
        } else {
            {
                sys2_out <- system2(bin_path, args = args, stdout = TRUE, stderr = TRUE)
                sys2_status <- attr(sys2_out, "status")
                list(
                    status = if (is.null(sys2_status) || length(sys2_status) == 0L) 0L else suppressWarnings(as.integer(sys2_status[1L])),
                    stdout = if (is.character(sys2_out)) sys2_out else character(0),
                    stderr = character(0)
                )
            }
        },
        error = function(e) list(status = 1L, stdout = character(0), stderr = as.character(e$message %||% "unknown error"))
    )
    exit_status <- suppressWarnings(as.integer(run_res$status[1L] %||% 1L))
    if (length(exit_status) == 0L || is.na(exit_status)) exit_status <- 1L
    raw_lines <- character(0)
    if (file.exists(out_file)) {
        raw_lines <- tryCatch(readLines(out_file, warn = FALSE), error = function(e) character(0))
    }
    parsed_blocks <- parse_lastz_general_output(raw_lines, reference_ctx = reference_ctx, query_ctx = query_ctx)
    unlink(run_dir, recursive = TRUE, force = TRUE)
    if (length(exit_status) == 0L || !is.finite(exit_status)) {
        exit_status <- 1L
    }
    status_txt <- if (exit_status == 0L) "ok" else "engine_error"
    list(
        status = status_txt,
        engine = engine_txt,
        binary = bin_path,
        binary_path = bin_path,
        binary_source = as.character(bin_info$source %||% ""),
        job = job,
        reference_width = nchar(ref_seq),
        query_width = nchar(qry_seq),
        exit_status = exit_status,
        stderr = as.character(run_res$stderr %||% character(0)),
        stdout = as.character(run_res$stdout %||% character(0)),
        blocks = parsed_blocks
    )
}

build_lastz_multipip_job_spec <- function(reference_ctx,
                                          query_ctx,
                                          out_path = "",
                                          format_name = "lav",
                                          extra_args = character(0)) {
    build_lastz_job_spec(
        reference_ctx = reference_ctx,
        query_ctx = query_ctx,
        out_path = out_path,
        format_name = format_name,
        extra_args = extra_args
    )
}

parse_lastz_lav_output <- function(raw_lines,
                                   reference_ctx = NULL,
                                   query_ctx = NULL) {
    if (is.null(raw_lines) || length(raw_lines) == 0L) {
        return(data.frame(stringsAsFactors = FALSE))
    }
    txt <- paste(as.character(raw_lines), collapse = "\n")
    txt <- trimws(txt)
    if (!nzchar(txt)) {
        return(data.frame(stringsAsFactors = FALSE))
    }

    raw_ref_end <- (reference_ctx %||% list())$window_end %||% NA_integer_
    raw_ref_start <- (reference_ctx %||% list())$window_start %||% NA_integer_
    raw_qry_end <- (query_ctx %||% list())$window_end %||% NA_integer_
    raw_qry_start <- (query_ctx %||% list())$window_start %||% NA_integer_
    ref_width <- suppressWarnings(as.integer(raw_ref_end[1L])) -
        suppressWarnings(as.integer(raw_ref_start[1L])) + 1L
    qry_width <- suppressWarnings(as.integer(raw_qry_end[1L])) -
        suppressWarnings(as.integer(raw_qry_start[1L])) + 1L
    if (length(ref_width) == 0L || !is.finite(ref_width) || ref_width <= 0L) ref_width <- NA_integer_
    if (length(qry_width) == 0L || !is.finite(qry_width) || qry_width <= 0L) qry_width <- NA_integer_

    lines <- unlist(strsplit(txt, "\n", fixed = TRUE), use.names = FALSE)
    in_s_block <- FALSE
    in_a_block <- FALSE
    s_line_idx <- 0L
    current_strand <- "+"
    current_alignment_id <- 0L
    current_score <- NA_real_
    segment_rank <- 0L
    out_rows <- list()

    lav_plus_to_genomic <- function(qry_start_plus, qry_end_plus, strand_txt, query_width, window_start) {
        if (!is.finite(query_width) || !is.finite(window_start)) {
            return(c(NA_real_, NA_real_))
        }
        if (identical(strand_txt, "-")) {
            plus_start <- query_width - max(qry_start_plus, qry_end_plus) + 1L
            plus_end <- query_width - min(qry_start_plus, qry_end_plus) + 1L
        } else {
            plus_start <- min(qry_start_plus, qry_end_plus)
            plus_end <- max(qry_start_plus, qry_end_plus)
        }
        c(
            as.numeric(window_start) + as.numeric(plus_start) - 1,
            as.numeric(window_start) + as.numeric(plus_end) - 1
        )
    }

    for (ln in lines) {
        line_txt <- trimws(as.character(ln %||% ""))
        if (!nzchar(line_txt)) next

        if (identical(line_txt, "s {")) {
            in_s_block <- TRUE
            s_line_idx <- 0L
            next
        }
        if (in_s_block) {
            if (identical(line_txt, "}")) {
                in_s_block <- FALSE
                next
            }
            if (startsWith(line_txt, "\"")) {
                s_line_idx <- s_line_idx + 1L
                path_txt <- gsub("^\"|\"$", "", line_txt)
                if (s_line_idx >= 2L) {
                    current_strand <- if (endsWith(path_txt, "-")) "-" else "+"
                }
            }
            next
        }

        if (identical(line_txt, "a {")) {
            in_a_block <- TRUE
            current_alignment_id <- current_alignment_id + 1L
            current_score <- NA_real_
            segment_rank <- 0L
            next
        }
        if (in_a_block && identical(line_txt, "}")) {
            in_a_block <- FALSE
            next
        }
        if (!in_a_block) {
            next
        }

        if (grepl("^s\\s+", line_txt)) {
            parts <- strsplit(line_txt, "\\s+")[[1]]
            if (length(parts) >= 2L) {
                current_score <- suppressWarnings(as.numeric(parts[[2]]))
            }
            next
        }

        if (grepl("^l\\s+", line_txt)) {
            parts <- strsplit(line_txt, "\\s+")[[1]]
            if (length(parts) < 6L) {
                next
            }
            ref_s <- suppressWarnings(as.integer(parts[[2]]))
            qry_s_lav <- suppressWarnings(as.integer(parts[[3]]))
            ref_e <- suppressWarnings(as.integer(parts[[4]]))
            qry_e_lav <- suppressWarnings(as.integer(parts[[5]]))
            identity_pct <- suppressWarnings(as.numeric(parts[[6]]))
            if (!all(is.finite(c(ref_s, qry_s_lav, ref_e, qry_e_lav, identity_pct)))) {
                next
            }
            segment_rank <- segment_rank + 1L
            ref_bp <- abs(ref_e - ref_s) + 1L
            qry_bp <- abs(qry_e_lav - qry_s_lav) + 1L
            ref_genomic <- c(
                as.numeric((reference_ctx %||% list())$window_start %||% 1L) + min(ref_s, ref_e) - 1,
                as.numeric((reference_ctx %||% list())$window_start %||% 1L) + max(ref_s, ref_e) - 1
            )
            qry_genomic <- lav_plus_to_genomic(
                qry_start_plus = qry_s_lav,
                qry_end_plus = qry_e_lav,
                strand_txt = current_strand,
                query_width = qry_width,
                window_start = as.numeric((query_ctx %||% list())$window_start %||% 1L)
            )
            out_rows[[length(out_rows) + 1L]] <- data.frame(
                ref_plot_id = as.character((reference_ctx %||% list())$plot_id %||% ""),
                query_plot_id = as.character((query_ctx %||% list())$plot_id %||% ""),
                ref_seqid = as.character((reference_ctx %||% list())$seqid %||% ""),
                query_seqid = as.character((query_ctx %||% list())$seqid %||% ""),
                ref_start = min(ref_genomic, na.rm = TRUE),
                ref_end = max(ref_genomic, na.rm = TRUE),
                qry_start = min(qry_genomic, na.rm = TRUE),
                qry_end = max(qry_genomic, na.rm = TRUE),
                ref_local_start = min(ref_s, ref_e),
                ref_local_end = max(ref_s, ref_e),
                qry_lav_start = qry_s_lav,
                qry_lav_end = qry_e_lav,
                strand = current_strand,
                identity_pct = as.numeric(identity_pct),
                segment_bp = as.integer(max(ref_bp, qry_bp)),
                alignment_id = as.integer(current_alignment_id),
                segment_rank = as.integer(segment_rank),
                score = as.numeric(current_score),
                ref_width = ref_width,
                qry_width = qry_width,
                ref_window_start = suppressWarnings(as.integer((reference_ctx %||% list())$window_start %||% NA_integer_)),
                query_window_start = suppressWarnings(as.integer((query_ctx %||% list())$window_start %||% NA_integer_)),
                source_engine = "lastz",
                stringsAsFactors = FALSE
            )
        }
    }

    out_df <- do.call(rbind, out_rows)
    if (!is.data.frame(out_df) || nrow(out_df) == 0L) {
        return(data.frame(stringsAsFactors = FALSE))
    }
    out_df
}

extract_gap_free_segments_from_alignment <- function(df_segments) {
    if (!is.data.frame(df_segments) || nrow(df_segments) == 0L) {
        return(data.frame(stringsAsFactors = FALSE))
    }
    out <- df_segments
    out$identity_pct <- suppressWarnings(as.numeric(out$identity_pct))
    out$segment_bp <- suppressWarnings(as.integer(out$segment_bp))
    out$alignment_id <- suppressWarnings(as.integer(out$alignment_id))
    out$segment_rank <- suppressWarnings(as.integer(out$segment_rank))
    out <- out[
        is.finite(out$identity_pct) &
            is.finite(out$segment_bp) &
            out$segment_bp > 0L &
            is.finite(out$ref_start) &
            is.finite(out$ref_end) &
            is.finite(out$qry_start) &
            is.finite(out$qry_end),
        ,
        drop = FALSE
    ]
    if (nrow(out) == 0L) {
        return(data.frame(stringsAsFactors = FALSE))
    }
    out[order(out$query_plot_id, out$strand, out$alignment_id, out$segment_rank, out$ref_start, out$qry_start), , drop = FALSE]
}

compute_gap_free_segment_identity <- function(df_segments) {
    if (!is.data.frame(df_segments) || nrow(df_segments) == 0L) {
        return(data.frame(stringsAsFactors = FALSE))
    }
    out <- df_segments
    out$identity_weighted_bp <- suppressWarnings(as.numeric(out$identity_pct)) * suppressWarnings(as.numeric(out$segment_bp))
    out
}

prune_reference_overlaps_per_query <- function(df_segments) {
    if (!is.data.frame(df_segments) || nrow(df_segments) == 0L) {
        return(data.frame(stringsAsFactors = FALSE))
    }

    subtract_interval_set <- function(start_bp, end_bp, covered_ranges) {
        pending <- data.frame(start = start_bp, end = end_bp, stringsAsFactors = FALSE)
        if (!is.data.frame(covered_ranges) || nrow(covered_ranges) == 0L) {
            return(pending)
        }
        for (ii in seq_len(nrow(covered_ranges))) {
            if (nrow(pending) == 0L) break
            cov_s <- covered_ranges$start[[ii]]
            cov_e <- covered_ranges$end[[ii]]
            next_pending <- list()
            for (jj in seq_len(nrow(pending))) {
                cur_s <- pending$start[[jj]]
                cur_e <- pending$end[[jj]]
                if (cov_e < cur_s || cov_s > cur_e) {
                    next_pending[[length(next_pending) + 1L]] <- data.frame(start = cur_s, end = cur_e, stringsAsFactors = FALSE)
                } else {
                    if (cov_s > cur_s) {
                        next_pending[[length(next_pending) + 1L]] <- data.frame(start = cur_s, end = cov_s - 1L, stringsAsFactors = FALSE)
                    }
                    if (cov_e < cur_e) {
                        next_pending[[length(next_pending) + 1L]] <- data.frame(start = cov_e + 1L, end = cur_e, stringsAsFactors = FALSE)
                    }
                }
            }
            pending <- if (length(next_pending) > 0L) do.call(rbind, next_pending) else data.frame(start = numeric(0), end = numeric(0))
        }
        pending
    }

    split_segment_piece <- function(seg_row, piece_ref_start, piece_ref_end) {
        delta_start <- as.integer(piece_ref_start - seg_row$ref_start)
        piece_len <- as.integer(piece_ref_end - piece_ref_start + 1L)
        piece_qry_lav_start <- as.integer(seg_row$qry_lav_start + delta_start)
        piece_qry_lav_end <- as.integer(piece_qry_lav_start + piece_len - 1L)
        if (identical(as.character(seg_row$strand %||% "+"), "-")) {
            qry_plus_start <- as.integer(seg_row$qry_width - piece_qry_lav_end + 1L)
            qry_plus_end <- as.integer(seg_row$qry_width - piece_qry_lav_start + 1L)
        } else {
            qry_plus_start <- piece_qry_lav_start
            qry_plus_end <- piece_qry_lav_end
        }
        qry_window_start <- suppressWarnings(as.integer(seg_row$query_window_start %||% NA_integer_))
        seg_row$ref_start <- as.numeric(piece_ref_start)
        seg_row$ref_end <- as.numeric(piece_ref_end)
        seg_row$qry_lav_start <- as.integer(piece_qry_lav_start)
        seg_row$qry_lav_end <- as.integer(piece_qry_lav_end)
        seg_row$qry_start <- as.numeric(qry_window_start + min(qry_plus_start, qry_plus_end) - 1L)
        seg_row$qry_end <- as.numeric(qry_window_start + max(qry_plus_start, qry_plus_end) - 1L)
        seg_row$segment_bp <- as.integer(piece_len)
        seg_row
    }

    iranges_ok <- requireNamespace("IRanges", quietly = TRUE)
    out_rows <- list()
    out_idx <- 0L
    split(df_segments, interaction(df_segments$query_plot_id, df_segments$strand, drop = TRUE)) |>
        lapply(function(df_group) {
            df_ord <- df_group[order(
                -ifelse(is.finite(df_group$identity_pct), df_group$identity_pct, -Inf),
                -ifelse(is.finite(df_group$score), df_group$score, -Inf),
                -ifelse(is.finite(df_group$segment_bp), df_group$segment_bp, -Inf),
                df_group$ref_start,
                df_group$qry_start
            ), , drop = FALSE]
            covered <- if (iranges_ok) IRanges::IRanges() else data.frame(start = numeric(0), end = numeric(0), stringsAsFactors = FALSE)
            for (ii in seq_len(nrow(df_ord))) {
                seg <- df_ord[ii, , drop = FALSE]
                uncovered <- if (iranges_ok) {
                    seg_ir <- IRanges::IRanges(
                        start = as.integer(seg$ref_start[[1]]),
                        end = as.integer(seg$ref_end[[1]])
                    )
                    uncovered_ir <- suppressWarnings(IRanges::setdiff(seg_ir, covered))
                    if (length(uncovered_ir) == 0L) {
                        data.frame(start = numeric(0), end = numeric(0), stringsAsFactors = FALSE)
                    } else {
                        data.frame(
                            start = IRanges::start(uncovered_ir),
                            end = IRanges::end(uncovered_ir),
                            stringsAsFactors = FALSE
                        )
                    }
                } else {
                    subtract_interval_set(
                        start_bp = as.integer(seg$ref_start[[1]]),
                        end_bp = as.integer(seg$ref_end[[1]]),
                        covered_ranges = covered
                    )
                }
                if (!is.data.frame(uncovered) || nrow(uncovered) == 0L) {
                    next
                }
                for (jj in seq_len(nrow(uncovered))) {
                    piece <- split_segment_piece(seg, uncovered$start[[jj]], uncovered$end[[jj]])
                    piece$is_pruned <- as.logical(
                        uncovered$start[[jj]] != as.integer(seg$ref_start[[1]]) ||
                            uncovered$end[[jj]] != as.integer(seg$ref_end[[1]])
                    )
                    out_idx <<- out_idx + 1L
                    out_rows[[out_idx]] <<- piece
                }
                if (iranges_ok) {
                    covered <- suppressWarnings(IRanges::reduce(c(
                        covered,
                        IRanges::IRanges(start = uncovered$start, end = uncovered$end)
                    )))
                } else {
                    covered <- rbind(
                        covered,
                        data.frame(
                            start = uncovered$start,
                            end = uncovered$end,
                            stringsAsFactors = FALSE
                        )
                    )
                    covered <- covered[order(covered$start, covered$end), , drop = FALSE]
                }
            }
            NULL
        })

    out_df <- do.call(rbind, out_rows)
    if (!is.data.frame(out_df) || nrow(out_df) == 0L) {
        return(data.frame(stringsAsFactors = FALSE))
    }
    out_df[order(out_df$query_plot_id, out_df$strand, out_df$ref_start, out_df$qry_start), , drop = FALSE]
}

classify_reference_underlay_context <- function(df_segments, ref_feature_df = NULL) {
    if (!is.data.frame(df_segments) || nrow(df_segments) == 0L) {
        return(data.frame(stringsAsFactors = FALSE))
    }
    out <- df_segments
    out$underlay_context <- "outside_gene"
    if (!is.data.frame(ref_feature_df) || nrow(ref_feature_df) == 0L) {
        return(out)
    }
    if (!requireNamespace("IRanges", quietly = TRUE)) {
        ov_len <- function(seg_s, seg_e, feat_s, feat_e) {
            max(0, min(seg_e, feat_e) - max(seg_s, feat_s) + 1)
        }
        cds_df <- ref_feature_df[ref_feature_df$feature_group == "cds", , drop = FALSE]
        utr_df <- ref_feature_df[ref_feature_df$feature_group == "utr", , drop = FALSE]
        exon_df <- ref_feature_df[ref_feature_df$feature_group == "exon", , drop = FALSE]
        for (ii in seq_len(nrow(out))) {
            seg_s <- out$ref_start[[ii]]
            seg_e <- out$ref_end[[ii]]
            cds_bp <- if (nrow(cds_df) > 0L) sum(mapply(ov_len, seg_s, seg_e, cds_df$xstart_clip, cds_df$xend_clip)) else 0
            utr_bp <- if (nrow(utr_df) > 0L) sum(mapply(ov_len, seg_s, seg_e, utr_df$xstart_clip, utr_df$xend_clip)) else 0
            exon_bp <- if (nrow(exon_df) > 0L) sum(mapply(ov_len, seg_s, seg_e, exon_df$xstart_clip, exon_df$xend_clip)) else 0
            out$underlay_context[[ii]] <- if (cds_bp > 0) {
                "cds"
            } else if (utr_bp > 0 || exon_bp > 0) {
                "noncoding_exon"
            } else {
                "intron_or_flank"
            }
        }
        return(out)
    }

    seg_ir <- IRanges::IRanges(
        start = suppressWarnings(as.integer(pmin(out$ref_start, out$ref_end))),
        end = suppressWarnings(as.integer(pmax(out$ref_start, out$ref_end)))
    )
    cds_df <- ref_feature_df[ref_feature_df$feature_group == "cds", , drop = FALSE]
    utr_exon_df <- ref_feature_df[ref_feature_df$feature_group %in% c("utr", "exon"), , drop = FALSE]
    has_cds <- rep(FALSE, nrow(out))
    has_noncoding_exon <- rep(FALSE, nrow(out))

    if (nrow(cds_df) > 0L) {
        cds_hits <- IRanges::findOverlaps(
            seg_ir,
            IRanges::IRanges(start = cds_df$xstart_clip, end = cds_df$xend_clip)
        )
        has_cds[unique(S4Vectors::queryHits(cds_hits))] <- TRUE
    }
    if (nrow(utr_exon_df) > 0L) {
        utr_hits <- IRanges::findOverlaps(
            seg_ir,
            IRanges::IRanges(start = utr_exon_df$xstart_clip, end = utr_exon_df$xend_clip)
        )
        has_noncoding_exon[unique(S4Vectors::queryHits(utr_hits))] <- TRUE
    }
    out$underlay_context[has_cds] <- "cds"
    out$underlay_context[!has_cds & has_noncoding_exon] <- "noncoding_exon"
    out$underlay_context[!has_cds & !has_noncoding_exon] <- "intron_or_flank"
    out
}

run_local_locus_alignment_multipip <- function(reference_ctx,
                                               query_ctx,
                                               engine = "lastz",
                                               out_path = "",
                                               format_name = "lav",
                                               extra_args = character(0)) {
    engine_txt <- tolower(trimws(as.character(engine %||% "lastz")))
    if (!engine_txt %in% c("lastz")) {
        return(list(
            status = "unsupported_engine",
            engine = engine_txt,
            segments = data.frame(stringsAsFactors = FALSE)
        ))
    }
    job <- build_lastz_multipip_job_spec(reference_ctx, query_ctx, out_path = out_path, format_name = format_name, extra_args = extra_args)
    if (is.null(job)) {
        return(list(
            status = "invalid_input",
            engine = engine_txt,
            segments = data.frame(stringsAsFactors = FALSE)
        ))
    }
    bin_info <- resolve_lastz_binary(job$binary %||% "lastz")
    bin_path <- trimws(as.character(bin_info$path %||% ""))
    if (!isTRUE(bin_info$available) || !nzchar(bin_path)) {
        return(list(
            status = "engine_unavailable",
            engine = engine_txt,
            binary = as.character(bin_info$requested %||% job$binary %||% "lastz"),
            binary_path = "",
            binary_source = as.character(bin_info$source %||% "missing"),
            setup_hint = "Install LASTZ locally or set APP_LASTZ_BIN to the binary path.",
            job = job,
            segments = data.frame(stringsAsFactors = FALSE)
        ))
    }
    ref_seq <- extract_locus_window_sequence(reference_ctx)
    qry_seq <- extract_locus_window_sequence(query_ctx)
    if (!nzchar(ref_seq) || !nzchar(qry_seq)) {
        return(list(
            status = "missing_sequence",
            engine = engine_txt,
            binary = bin_path,
            binary_path = bin_path,
            binary_source = as.character(bin_info$source %||% ""),
            job = job,
            segments = data.frame(stringsAsFactors = FALSE)
        ))
    }
    run_dir <- tempfile(pattern = "ctv_lastz_multipip_")
    dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
    ref_name <- paste0("ref_", sanitize_cache_key((reference_ctx %||% list())$plot_id %||% "reference"))
    qry_name <- paste0("qry_", sanitize_cache_key((query_ctx %||% list())$plot_id %||% "query"))
    ref_fa <- write_locus_temp_fasta(ref_seq, record_name = ref_name, dir_path = run_dir)
    qry_fa <- write_locus_temp_fasta(qry_seq, record_name = qry_name, dir_path = run_dir)
    if (!nzchar(ref_fa) || !nzchar(qry_fa)) {
        unlink(run_dir, recursive = TRUE, force = TRUE)
        return(list(
            status = "temp_fasta_failed",
            engine = engine_txt,
            binary = bin_path,
            binary_path = bin_path,
            binary_source = as.character(bin_info$source %||% ""),
            job = job,
            segments = data.frame(stringsAsFactors = FALSE)
        ))
    }
    out_file <- if (nzchar(trimws(as.character(out_path %||% "")))) {
        as.character(out_path)
    } else {
        file.path(run_dir, "lastz_multipip.lav")
    }
    args <- c(
        ref_fa,
        qry_fa,
        "--format=lav",
        "--ambiguous=iupac",
        paste0("--output=", out_file)
    )
    if (length(extra_args) > 0L) {
        args <- c(args, as.character(extra_args))
    }
    run_res <- tryCatch(
        if (requireNamespace("processx", quietly = TRUE)) {
            processx::run(bin_path, args = args, echo = FALSE, error_on_status = FALSE)
        } else {
            {
                sys2_out <- system2(bin_path, args = args, stdout = TRUE, stderr = TRUE)
                sys2_status <- attr(sys2_out, "status")
                list(
                    status = if (is.null(sys2_status) || length(sys2_status) == 0L) 0L else suppressWarnings(as.integer(sys2_status[1L])),
                    stdout = if (is.character(sys2_out)) sys2_out else character(0),
                    stderr = character(0)
                )
            }
        },
        error = function(e) list(status = 1L, stdout = character(0), stderr = as.character(e$message %||% "unknown error"))
    )
    exit_status <- suppressWarnings(as.integer(run_res$status[1L] %||% 1L))
    if (length(exit_status) == 0L || is.na(exit_status)) exit_status <- 1L
    raw_lines <- character(0)
    if (file.exists(out_file)) {
        raw_lines <- tryCatch(readLines(out_file, warn = FALSE), error = function(e) character(0))
    }
    parsed_segments <- parse_lastz_lav_output(raw_lines, reference_ctx = reference_ctx, query_ctx = query_ctx)
    parsed_segments <- extract_gap_free_segments_from_alignment(parsed_segments)
    parsed_segments <- compute_gap_free_segment_identity(parsed_segments)
    unlink(run_dir, recursive = TRUE, force = TRUE)
    if (length(exit_status) == 0L || !is.finite(exit_status)) {
        exit_status <- 1L
    }
    status_txt <- if (exit_status == 0L) "ok" else "engine_error"
    list(
        status = status_txt,
        engine = engine_txt,
        binary = bin_path,
        binary_path = bin_path,
        binary_source = as.character(bin_info$source %||% ""),
        job = job,
        reference_width = nchar(ref_seq),
        query_width = nchar(qry_seq),
        exit_status = exit_status,
        stderr = as.character(run_res$stderr %||% character(0)),
        stdout = as.character(run_res$stdout %||% character(0)),
        segments = parsed_segments
    )
}

# --- 4. FASTA Y SECUENCIAS ---

get_fasta_header_map <- function(fasta_path) {
    key <- normalizePath(fasta_path, winslash = "/", mustWork = FALSE)
    if (exists(key, envir = .fasta_header_cache, inherits = FALSE)) {
        return(get(key, envir = .fasta_header_cache, inherits = FALSE))
    }

    con <- if (grepl("\\.gz$", fasta_path, ignore.case = TRUE)) gzfile(fasta_path, open = "rt") else file(fasta_path, open = "r")
    on.exit(close(con), add = TRUE)
    seqname_to_header <- list()
    chrom_to_seqname <- list()
    header_count <- 0
    while (length(line <- readLines(con, n = 1, warn = FALSE)) > 0) {
        if (!startsWith(line, ">")) next
        header <- sub("^>", "", line)
        token <- strsplit(header, "\\s+")[[1]][1]
        seqname_to_header[[token]] <- header
        if (header_count < 3) {
            header_count <- header_count + 1
        }
        chr_m <- str_match(header, regex("chromosome\\s+([0-9a-z]+)", ignore_case = TRUE))
        if (!all(is.na(chr_m))) {
            chrk <- tolower(chr_m[1, 2])
            if (nzchar(chrk) && is.null(chrom_to_seqname[[chrk]])) chrom_to_seqname[[chrk]] <- token
        }
    }
    out <- list(seqname_to_header = seqname_to_header, chrom_to_seqname = chrom_to_seqname)
    assign(key, out, envir = .fasta_header_cache)
    trim_cache_env(.fasta_header_cache, max_size = 200L)
    out
}

get_fasta_index_seqnames <- function(fasta_path) {
    key <- normalizePath(fasta_path, winslash = "/", mustWork = FALSE)
    if (exists(key, envir = .fasta_seqnames_cache, inherits = FALSE)) {
        return(get(key, envir = .fasta_seqnames_cache, inherits = FALSE))
    }

    fai_path <- paste0(fasta_path, ".fai")
    seq_names <- character(0)
    if (file.exists(fai_path)) {
        seq_names <- tryCatch(
            {
                idx <- utils::read.delim(
                    fai_path,
                    header = FALSE,
                    sep = "\t",
                    quote = "",
                    comment.char = "",
                    stringsAsFactors = FALSE
                )
                if (ncol(idx) >= 1) as.character(idx[[1]]) else character(0)
            },
            error = function(e) character(0)
        )
    }
    seq_names <- unique(seq_names[!is.na(seq_names) & nzchar(trimws(seq_names))])
    assign(key, seq_names, envir = .fasta_seqnames_cache)
    trim_cache_env(.fasta_seqnames_cache, max_size = 200L)
    seq_names
}

get_cached_fafile <- function(fasta_path) {
    if (!requireNamespace("Rsamtools", quietly = TRUE)) {
        return(NULL)
    }
    key <- normalizePath(fasta_path, winslash = "/", mustWork = FALSE)
    if (exists(key, envir = .fafile_handle_cache, inherits = FALSE)) {
        fa_cached <- get(key, envir = .fafile_handle_cache, inherits = FALSE)
        return(fa_cached)
    }
    fai_path <- paste0(fasta_path, ".fai")
    if (!file.exists(fai_path) && file.access(dirname(fasta_path), 2) == 0) {
        try(Rsamtools::indexFa(fasta_path), silent = TRUE)
    }
    fa <- tryCatch(Rsamtools::FaFile(fasta_path), error = function(e) NULL)
    if (is.null(fa)) {
        return(NULL)
    }
    assign(key, fa, envir = .fafile_handle_cache)
    trim_cache_env(.fafile_handle_cache, max_size = 40L)
    fa
}

resolve_seqname_in_fasta <- function(fasta_path, seqid, seq_names = NULL) {
    seqid <- as.character(seqid %||% "")
    if (!nzchar(seqid)) {
        return(NULL)
    }
    if (!is.null(seq_names)) {
        return(resolve_seqname_in_vector(seqid, seq_names = seq_names))
    }
    cache_key <- paste(
        normalizePath(fasta_path, winslash = "/", mustWork = FALSE),
        seqid,
        sep = "::"
    )
    if (exists(cache_key, envir = .fasta_resolved_seqname_cache, inherits = FALSE)) {
        cached <- as.character(get(cache_key, envir = .fasta_resolved_seqname_cache, inherits = FALSE) %||% "")
        if (!nzchar(cached)) {
            return(NULL)
        }
        return(cached)
    }

    seq_names_fast <- get_fasta_index_seqnames(fasta_path)
    if (length(seq_names_fast) > 0) {
        hit_fast <- resolve_seqname_in_vector(seqid, seq_names = seq_names_fast)
        if (!is.null(hit_fast)) {
            assign(cache_key, hit_fast, envir = .fasta_resolved_seqname_cache)
            trim_cache_env(.fasta_resolved_seqname_cache, max_size = 5000L)
            return(hit_fast)
        }
    }

    hmap <- get_fasta_header_map(fasta_path)
    known_seqnames <- names(hmap$seqname_to_header)
    hit <- resolve_seqname_in_vector(seqid, seq_names = known_seqnames)
    if (!is.null(hit)) {
        assign(cache_key, hit, envir = .fasta_resolved_seqname_cache)
        trim_cache_env(.fasta_resolved_seqname_cache, max_size = 5000L)
        return(hit)
    }
    s_num <- tolower(gsub("^chr", "", seqid, ignore.case = TRUE))
    if (s_num %in% names(hmap$chrom_to_seqname)) {
        out <- hmap$chrom_to_seqname[[s_num]]
        assign(cache_key, out, envir = .fasta_resolved_seqname_cache)
        trim_cache_env(.fasta_resolved_seqname_cache, max_size = 5000L)
        return(out)
    }
    assign(cache_key, "", envir = .fasta_resolved_seqname_cache)
    trim_cache_env(.fasta_resolved_seqname_cache, max_size = 5000L)
    NULL
}

get_fasta_fallback_seq_cache_key <- function(fasta_path, resolved_seqname) {
    paste(
        normalizePath(as.character(fasta_path %||% ""), winslash = "/", mustWork = FALSE),
        as.character(resolved_seqname %||% ""),
        sep = "::"
    )
}

get_seq_extract_cache_key <- function(fasta_path, seqid, start_pos, end_pos) {
    paste(
        normalizePath(as.character(fasta_path %||% ""), winslash = "/", mustWork = FALSE),
        as.character(seqid %||% ""),
        as.integer(start_pos %||% NA_integer_),
        as.integer(end_pos %||% NA_integer_),
        sep = "::"
    )
}

cache_sequence_extract_result <- function(fasta_path, seqid, start_pos, end_pos, seq_txt, resolved_seqname = NULL) {
    seq_val <- as.character(seq_txt %||% "")
    raw_key <- get_seq_extract_cache_key(fasta_path, seqid, start_pos, end_pos)
    assign(raw_key, seq_val, envir = .seq_extract_cache)
    resolved_txt <- trimws(as.character(resolved_seqname %||% ""))
    raw_seqid <- trimws(as.character(seqid %||% ""))
    if (nzchar(resolved_txt) && !identical(resolved_txt, raw_seqid)) {
        resolved_key <- get_seq_extract_cache_key(fasta_path, resolved_txt, start_pos, end_pos)
        assign(resolved_key, seq_val, envir = .seq_extract_cache)
    }
    trim_cache_env(.seq_extract_cache, max_size = 1000L)
    invisible(seq_val)
}

get_twobit_seqnames <- function(two_bit_path) {
    if (is.null(two_bit_path) || !nzchar(two_bit_path) || !file.exists(two_bit_path)) {
        return(character(0))
    }
    key <- normalizePath(two_bit_path, winslash = "/", mustWork = FALSE)
    if (exists(key, envir = .twobit_seqinfo_cache, inherits = FALSE)) {
        return(get(key, envir = .twobit_seqinfo_cache, inherits = FALSE))
    }

    out <- tryCatch(
        {
            if (!requireNamespace("rtracklayer", quietly = TRUE) || !requireNamespace("GenomeInfoDb", quietly = TRUE)) {
                return(character(0))
            }
            tbf <- if (exists(key, envir = .twobit_handle_cache, inherits = FALSE)) {
                get(key, envir = .twobit_handle_cache, inherits = FALSE)
            } else {
                obj <- rtracklayer::TwoBitFile(two_bit_path)
                assign(key, obj, envir = .twobit_handle_cache)
                trim_cache_env(.twobit_handle_cache, max_size = 40L)
                obj
            }
            si <- GenomeInfoDb::seqinfo(tbf)
            as.character(names(si))
        },
        error = function(e) character(0)
    )
    assign(key, out, envir = .twobit_seqinfo_cache)
    out
}

extract_sequence_from_2bit <- function(two_bit_path, seqid, start_pos, end_pos) {
    if (is.null(two_bit_path) || !nzchar(two_bit_path) || !file.exists(two_bit_path)) {
        return("")
    }
    start_pos <- max(1L, as.integer(start_pos %||% 1L))
    end_pos <- max(start_pos, as.integer(end_pos %||% start_pos))
    seq_names <- get_twobit_seqnames(two_bit_path)
    resolved_seqname <- resolve_seqname_in_vector(seqid, seq_names = seq_names) %||% as.character(seqid %||% "")
    if (!nzchar(resolved_seqname)) {
        return("")
    }

    res <- tryCatch(
        {
            if (!requireNamespace("rtracklayer", quietly = TRUE)) {
                return("")
            }
            key <- normalizePath(two_bit_path, winslash = "/", mustWork = FALSE)
            tbf <- if (exists(key, envir = .twobit_handle_cache, inherits = FALSE)) {
                get(key, envir = .twobit_handle_cache, inherits = FALSE)
            } else {
                obj <- rtracklayer::TwoBitFile(two_bit_path)
                assign(key, obj, envir = .twobit_handle_cache)
                trim_cache_env(.twobit_handle_cache, max_size = 40L)
                obj
            }
            gr <- GenomicRanges::GRanges(
                seqnames = resolved_seqname,
                ranges = IRanges::IRanges(start = start_pos, end = end_pos)
            )
            seq_set <- rtracklayer::import(
                con = tbf,
                format = "2bit",
                which = gr
            )
            if (length(seq_set) == 0) "" else as.character(seq_set[[1]])
        },
        error = function(e) ""
    )
    if (nzchar(res)) {
        return(res)
    }

    bin <- Sys.which("twoBitToFa")
    if (nzchar(bin)) {
        cli_start <- max(0L, start_pos - 1L)
        cli_end <- end_pos
        args <- c(
            paste0("-seq=", resolved_seqname),
            paste0("-start=", cli_start),
            paste0("-end=", cli_end),
            two_bit_path,
            "stdout"
        )
        cmd_out <- tryCatch(system2(bin, args = args, stdout = TRUE, stderr = FALSE), error = function(e) character(0))
        if (length(cmd_out) > 1) {
            seq_txt <- paste(cmd_out[!startsWith(cmd_out, ">")], collapse = "")
            if (nzchar(seq_txt)) {
                return(seq_txt)
            }
        }
    }
    ""
}

extract_sequence_from_fasta <- function(fasta_path, seqid, start_pos, end_pos) {
    if (is.null(fasta_path) || !file.exists(fasta_path)) {
        return("")
    }
    start_pos <- as.integer(start_pos)
    end_pos <- as.integer(end_pos)
    seq_cache_key <- get_seq_extract_cache_key(fasta_path, seqid, start_pos, end_pos)
    if (exists(seq_cache_key, envir = .seq_extract_cache, inherits = FALSE)) {
        return(get(seq_cache_key, envir = .seq_extract_cache, inherits = FALSE))
    }

    if (is_twobit_file(fasta_path)) {
        seq_2bit <- extract_sequence_from_2bit(fasta_path, seqid, start_pos, end_pos)
        if (nzchar(seq_2bit)) {
            cache_sequence_extract_result(fasta_path, seqid, start_pos, end_pos, seq_2bit, resolved_seqname = NULL)
            return(seq_2bit)
        }
        cache_sequence_extract_result(fasta_path, seqid, start_pos, end_pos, "", resolved_seqname = NULL)
        return("")
    }

    resolved_seqname <- NULL
    if (requireNamespace("Rsamtools", quietly = TRUE)) {
        res_rsam <- tryCatch(
            {
                fa <- get_cached_fafile(fasta_path)
                if (is.null(fa)) {
                    return(NULL)
                }
                seqid_direct <- trimws(as.character(seqid %||% ""))
                if (nzchar(seqid_direct)) {
                    gr_direct <- GenomicRanges::GRanges(
                        seqnames = seqid_direct,
                        ranges = IRanges::IRanges(start = start_pos, end = end_pos)
                    )
                    direct_res <- tryCatch(
                        as.character(Rsamtools::scanFa(fa, param = gr_direct)[[1]]),
                        error = function(e) NULL
                    )
                    if (!is.null(direct_res) && nzchar(direct_res)) {
                        return(direct_res)
                    }
                }
                resolved_seqname <<- resolve_seqname_in_fasta(fasta_path, seqid, seq_names = NULL)
                if (is.null(resolved_seqname)) {
                    return(NULL)
                }
                gr <- GenomicRanges::GRanges(
                    seqnames = resolved_seqname,
                    ranges = IRanges::IRanges(start = start_pos, end = end_pos)
                )
                as.character(Rsamtools::scanFa(fa, param = gr)[[1]])
            },
            error = function(e) {
                app_debug_log("[Extract Seq] Rsamtools error: ", e$message)
                NULL
            }
        )
        if (!is.null(res_rsam) && nzchar(res_rsam)) {
            cache_sequence_extract_result(fasta_path, seqid, start_pos, end_pos, res_rsam, resolved_seqname = resolved_seqname)
            return(res_rsam)
        }
    }

    resolved_seqname <- resolved_seqname %||% resolve_seqname_in_fasta(fasta_path, seqid, seq_names = NULL)
    if (is.null(resolved_seqname)) {
        cache_sequence_extract_result(fasta_path, seqid, start_pos, end_pos, "", resolved_seqname = NULL)
        return("")
    }
    resolved_cache_key <- get_seq_extract_cache_key(fasta_path, resolved_seqname, start_pos, end_pos)
    if (!identical(resolved_cache_key, seq_cache_key) && exists(resolved_cache_key, envir = .seq_extract_cache, inherits = FALSE)) {
        cached_resolved <- get(resolved_cache_key, envir = .seq_extract_cache, inherits = FALSE)
        assign(seq_cache_key, cached_resolved, envir = .seq_extract_cache)
        trim_cache_env(.seq_extract_cache, max_size = 1000L)
        return(cached_resolved)
    }
    fallback_seq_key <- get_fasta_fallback_seq_cache_key(fasta_path, resolved_seqname)
    fallback_full_seq <- cache_env_get(.fasta_fallback_seq_cache, fallback_seq_key, default = NULL)
    if (is.character(fallback_full_seq) && length(fallback_full_seq) > 0L && nzchar(fallback_full_seq[1])) {
        cached_full_seq <- as.character(fallback_full_seq[1] %||% "")
        if (nchar(cached_full_seq) >= end_pos) {
            out_cached <- substr(cached_full_seq, start_pos, end_pos)
            cache_sequence_extract_result(fasta_path, seqid, start_pos, end_pos, out_cached, resolved_seqname = resolved_seqname)
            return(out_cached)
        }
    }
    con <- if (grepl("\\.gz$", fasta_path, ignore.case = TRUE)) gzfile(fasta_path, open = "rt") else file(fasta_path, open = "r")
    on.exit(close(con), add = TRUE)
    in_target <- FALSE
    seq_chunks <- character()
    while (length(line <- readLines(con, n = 1, warn = FALSE)) > 0) {
        if (startsWith(line, ">")) {
            header <- sub("^>", "", line)
            token <- strsplit(header, "\\s+")[[1]][1]
            in_target <- identical(token, resolved_seqname)
            next
        }
        if (in_target) seq_chunks <- c(seq_chunks, gsub("\\s+", "", line))
    }
    if (length(seq_chunks) == 0) {
        cache_sequence_extract_result(fasta_path, seqid, start_pos, end_pos, "", resolved_seqname = resolved_seqname)
        return("")
    }
    full_seq <- paste(seq_chunks, collapse = "")
    if (nchar(full_seq) < end_pos) {
        cache_sequence_extract_result(fasta_path, seqid, start_pos, end_pos, "", resolved_seqname = resolved_seqname)
        return("")
    }
    if (nchar(full_seq) <= annotation_memory_cache_limits$fasta_fallback_seq_max_bp) {
        cache_env_set(
            .fasta_fallback_seq_cache,
            fallback_seq_key,
            full_seq,
            max_size = annotation_memory_cache_limits$fasta_fallback_seq_max_entries,
            max_bytes = annotation_memory_cache_limits$fasta_fallback_seq_max_bytes
        )
    }
    out <- substr(full_seq, start_pos, end_pos)
    cache_sequence_extract_result(fasta_path, seqid, start_pos, end_pos, out, resolved_seqname = resolved_seqname)
    out
}

reverse_complement_dna <- function(seq_txt) {
    s <- toupper(gsub("\\s+", "", as.character(seq_txt %||% "")))
    if (!nzchar(s)) {
        return("")
    }
    chars <- strsplit(s, "", fixed = TRUE)[[1]]
    comp_map <- c(
        A = "T", T = "A", C = "G", G = "C", N = "N",
        R = "Y", Y = "R", S = "S", W = "W", K = "M", M = "K",
        B = "V", V = "B", D = "H", H = "D"
    )
    comp <- unname(comp_map[chars])
    comp[is.na(comp)] <- "N"
    paste(rev(comp), collapse = "")
}

normalize_exon_ranges <- function(exon_ranges) {
    if (is.null(exon_ranges)) {
        return(data.frame(start = numeric(0), end = numeric(0)))
    }
    ex <- as.data.frame(exon_ranges, stringsAsFactors = FALSE)
    if (nrow(ex) == 0) {
        return(data.frame(start = numeric(0), end = numeric(0)))
    }

    pick_col <- function(nms, candidates) {
        hit <- intersect(tolower(as.character(nms)), tolower(candidates))
        if (length(hit) == 0) {
            return(NA_character_)
        }
        nms[match(hit[1], tolower(nms))]
    }
    c_start <- pick_col(colnames(ex), c("start", "xstart", "v4"))
    c_end <- pick_col(colnames(ex), c("end", "xend", "v5"))
    if (is.na(c_start) || is.na(c_end)) {
        return(data.frame(start = numeric(0), end = numeric(0)))
    }

    out <- data.frame(
        start = suppressWarnings(as.numeric(ex[[c_start]])),
        end = suppressWarnings(as.numeric(ex[[c_end]])),
        stringsAsFactors = FALSE
    )
    out <- out[is.finite(out$start) & is.finite(out$end), , drop = FALSE]
    out <- out[out$end >= out$start, , drop = FALSE]
    if (nrow(out) == 0) {
        return(data.frame(start = numeric(0), end = numeric(0)))
    }

    ord <- order(out$start, out$end)
    out <- out[ord, , drop = FALSE]

    merged <- data.frame(start = out$start[1], end = out$end[1], stringsAsFactors = FALSE)
    if (nrow(out) > 1) {
        for (i in 2:nrow(out)) {
            if (out$start[i] <= merged$end[nrow(merged)] + 1) {
                merged$end[nrow(merged)] <- max(merged$end[nrow(merged)], out$end[i])
            } else {
                merged <- rbind(merged, data.frame(start = out$start[i], end = out$end[i], stringsAsFactors = FALSE))
            }
        }
    }
    merged
}

extract_spliced_exon_sequence <- function(fasta_path, seqid, exon_ranges, strand = "+") {
    ex <- normalize_exon_ranges(exon_ranges)
    if (nrow(ex) == 0) {
        return("")
    }

    span_start <- suppressWarnings(as.integer(round(min(ex$start, na.rm = TRUE))))
    span_end <- suppressWarnings(as.integer(round(max(ex$end, na.rm = TRUE))))
    span_width <- suppressWarnings(as.integer(span_end - span_start + 1L))
    splice_key <- paste(
        normalizePath(as.character(fasta_path %||% ""), winslash = "/", mustWork = FALSE),
        as.character(seqid %||% ""),
        as.character(strand %||% "+"),
        paste0(ex$start, "-", ex$end, collapse = ";"),
        sep = "::"
    )
    if (exists(splice_key, envir = .spliced_seq_cache, inherits = FALSE)) {
        return(as.character(get(splice_key, envir = .spliced_seq_cache, inherits = FALSE) %||% ""))
    }

    sp_perf <- app_perf_new_run("SEQ_SPLICE")
    app_perf_mark(
        sp_perf,
        sprintf(
            "start exons=%d span=%s twobit=%s",
            as.integer(nrow(ex)),
            ifelse(is.finite(span_width), as.character(as.integer(span_width)), "NA"),
            ifelse(isTRUE(is_twobit_file(fasta_path)), "yes", "no")
        ),
        "SEQ_SPLICE"
    )

    # Fastest path for single-exon transcripts.
    if (nrow(ex) == 1) {
        seq_one <- extract_sequence_from_fasta(fasta_path, seqid, ex$start[1], ex$end[1])
        if (!nzchar(seq_one)) {
            app_perf_mark(sp_perf, "single-exon empty", "SEQ_SPLICE")
            return("")
        }
        strand_one <- toupper(trimws(as.character(strand %||% "+")))
        if (identical(strand_one, "-")) {
            seq_one <- reverse_complement_dna(seq_one)
        }
        assign(splice_key, seq_one, envir = .spliced_seq_cache)
        trim_cache_env(.spliced_seq_cache, max_size = 1200L)
        app_perf_mark(sp_perf, sprintf("single-exon done len=%d", as.integer(nchar(seq_one))), "SEQ_SPLICE")
        return(seq_one)
    }

    # Fast path: fetch one continuous span and splice exons locally.
    # This is much faster than random-access per exon for compact transcripts.
    if (is.finite(span_start) && is.finite(span_end) && is.finite(span_width) &&
        span_start >= 1L && span_end >= span_start && span_width > 0L && span_width <= 300000L) {
        span_seq <- extract_sequence_from_fasta(fasta_path, seqid, span_start, span_end)
        if (nzchar(span_seq) && nchar(span_seq) >= span_width) {
            rel_starts <- as.integer(round(ex$start)) - span_start + 1L
            rel_ends <- as.integer(round(ex$end)) - span_start + 1L
            keep <- is.finite(rel_starts) & is.finite(rel_ends) &
                rel_starts >= 1L & rel_ends <= nchar(span_seq) & rel_ends >= rel_starts
            if (any(keep)) {
                parts_local <- vapply(which(keep), function(i) {
                    substr(span_seq, rel_starts[i], rel_ends[i])
                }, character(1))
                parts_local <- parts_local[nzchar(parts_local)]
                if (length(parts_local) > 0) {
                    seq_spliced_local <- paste0(parts_local, collapse = "")
                    strand_local <- toupper(trimws(as.character(strand %||% "+")))
                    seq_cache_key <- paste(
                        normalizePath(fasta_path, winslash = "/", mustWork = FALSE),
                        as.character(seqid %||% ""),
                        as.integer(span_start),
                        as.integer(span_end),
                        sep = "::"
                    )
                    # Reuse single-span genomic extraction in later feature-level GC computations.
                    assign(seq_cache_key, span_seq, envir = .seq_extract_cache)
                    trim_cache_env(.seq_extract_cache, max_size = 1000L)
                    if (identical(strand_local, "-")) seq_spliced_local <- reverse_complement_dna(seq_spliced_local)
                    assign(splice_key, seq_spliced_local, envir = .spliced_seq_cache)
                    trim_cache_env(.spliced_seq_cache, max_size = 1200L)
                    app_perf_mark(
                        sp_perf,
                        sprintf("single-span done len=%d span=%d", as.integer(nchar(seq_spliced_local)), as.integer(span_width)),
                        "SEQ_SPLICE"
                    )
                    return(seq_spliced_local)
                }
            }
        }
    }

    parts <- character(0)

    # Fast path for 2bit: fetch all exon ranges in a single import call.
    if (is_twobit_file(fasta_path) && requireNamespace("rtracklayer", quietly = TRUE)) {
        parts <- tryCatch(
            {
                seq_names <- get_twobit_seqnames(fasta_path)
                resolved_seqname <- resolve_seqname_in_vector(seqid, seq_names = seq_names) %||% as.character(seqid %||% "")
                if (!nzchar(resolved_seqname)) {
                    return(character(0))
                }
                tbf_key <- normalizePath(fasta_path, winslash = "/", mustWork = FALSE)
                tbf <- if (exists(tbf_key, envir = .twobit_handle_cache, inherits = FALSE)) {
                    get(tbf_key, envir = .twobit_handle_cache, inherits = FALSE)
                } else {
                    obj <- rtracklayer::TwoBitFile(fasta_path)
                    assign(tbf_key, obj, envir = .twobit_handle_cache)
                    trim_cache_env(.twobit_handle_cache, max_size = 40L)
                    obj
                }
                gr <- GenomicRanges::GRanges(
                    seqnames = rep(resolved_seqname, nrow(ex)),
                    ranges = IRanges::IRanges(
                        start = as.integer(round(as.numeric(ex$start))),
                        end = as.integer(round(as.numeric(ex$end)))
                    )
                )
                seq_set <- rtracklayer::import(
                    con = tbf,
                    format = "2bit",
                    which = gr
                )
                as.character(seq_set)
            },
            error = function(e) {
                character(0)
            }
        )
        if (length(parts) > 0) {
            app_perf_mark(sp_perf, sprintf("2bit batch parts=%d", as.integer(length(parts))), "SEQ_SPLICE")
        }
    }

    # Fast path: one FASTA handle + one batched scan for all exons.
    # This preserves exon-by-exon splicing semantics but avoids repeated
    # open/index/close overhead per exon.
    if (length(parts) == 0 && !is_twobit_file(fasta_path) && requireNamespace("Rsamtools", quietly = TRUE)) {
        parts <- tryCatch(
            {
                fa <- get_cached_fafile(fasta_path)
                if (is.null(fa)) {
                    return(character(0))
                }
                seqid_direct <- trimws(as.character(seqid %||% ""))
                if (nzchar(seqid_direct)) {
                    gr_direct <- GenomicRanges::GRanges(
                        seqnames = rep(seqid_direct, nrow(ex)),
                        ranges = IRanges::IRanges(
                            start = as.integer(round(as.numeric(ex$start))),
                            end = as.integer(round(as.numeric(ex$end)))
                        )
                    )
                    direct_parts <- tryCatch(
                        as.character(Rsamtools::scanFa(fa, param = gr_direct)),
                        error = function(e) character(0)
                    )
                    if (length(direct_parts) > 0) {
                        app_perf_mark(sp_perf, sprintf("fa direct parts=%d", as.integer(length(direct_parts))), "SEQ_SPLICE")
                        return(direct_parts)
                    }
                }
                resolved_seqname <- resolve_seqname_in_fasta(fasta_path, seqid, seq_names = NULL)
                if (is.null(resolved_seqname)) {
                    return(character(0))
                }

                gr <- GenomicRanges::GRanges(
                    seqnames = rep(resolved_seqname, nrow(ex)),
                    ranges = IRanges::IRanges(
                        start = as.integer(round(as.numeric(ex$start))),
                        end = as.integer(round(as.numeric(ex$end)))
                    )
                )
                out_parts <- as.character(Rsamtools::scanFa(fa, param = gr))
                app_perf_mark(sp_perf, sprintf("fa resolved parts=%d", as.integer(length(out_parts))), "SEQ_SPLICE")
                out_parts
            },
            error = function(e) {
                character(0)
            }
        )
    }

    if (length(parts) == 0) {
        parts <- vapply(seq_len(nrow(ex)), function(i) {
            extract_sequence_from_fasta(fasta_path, seqid, ex$start[i], ex$end[i])
        }, character(1))
        app_perf_mark(sp_perf, sprintf("per-exon fallback parts=%d", as.integer(length(parts))), "SEQ_SPLICE")
    }
    parts <- parts[nzchar(parts)]
    if (length(parts) == 0) {
        app_perf_mark(sp_perf, "done empty", "SEQ_SPLICE")
        return("")
    }

    seq_spliced <- paste0(parts, collapse = "")
    strand <- toupper(trimws(as.character(strand %||% "+")))
    if (identical(strand, "-")) seq_spliced <- reverse_complement_dna(seq_spliced)
    assign(splice_key, seq_spliced, envir = .spliced_seq_cache)
    trim_cache_env(.spliced_seq_cache, max_size = 1200L)
    app_perf_mark(sp_perf, sprintf("done len=%d", as.integer(nchar(seq_spliced))), "SEQ_SPLICE")
    seq_spliced
}

extract_plot_labels <- function(data_df) {
    if (is.null(data_df) || nrow(data_df) == 0) {
        return(list(transcript = "N/A", chromosome = "N/A"))
    }
    chromosome <- as.character(data_df$V1[1] %||% "N/A")
    tx_level_types <- c(
        "mrna", "transcript", "lnc_rna", "trna", "rrna", "snorna", "snrna", "mirna",
        "ncrna", "primary_transcript", "pre_mirna", "guide_rna", "rnase_p_rna",
        "rnase_mrp_rna", "telomerase_rna", "antisense_rna", "srp_rna", "scarna",
        "vault_rna", "y_rna", "antisense_lncrna", "lncrna"
    )
    tx_rows <- data_df %>% filter(tolower(V3) %in% tx_level_types)
    tx <- NA_character_
    if (nrow(tx_rows) > 0) {
        attr <- safe_url_decode(tx_rows$V9[1])
        tx <- str_extract(attr, "(^|;)ID=[^;]+") %>% str_remove("(^|;)ID=")
        if (is.na(tx)) tx <- str_extract(attr, "(^|;)transcript_id=[^;]+") %>% str_remove("(^|;)transcript_id=")
        if (is.na(tx)) {
            tx <- str_extract(attr, 'transcript_id "[^"]+"') %>%
                str_remove('transcript_id "') %>%
                str_remove('"')
        }
    }
    tx <- as.character(tx)
    if (is.na(tx) || !nzchar(tx)) tx <- ""
    tx <- trimws(safe_url_decode(tx))
    tx <- str_remove(tx, regex("^(transcript|gene)\\s*:\\s*", ignore_case = TRUE))
    tx <- trimws(tx)
    if (is.na(tx) || !nzchar(tx)) {
        fallback_rows <- data_df %>%
            filter(tolower(V3) %in% c("gene", "cds")) %>%
            head(1)
        if (nrow(fallback_rows) > 0) {
            attr <- as.character(fallback_rows$V9[1] %||% "")
            tx_candidates <- c(
                extract_primary_gene_name(attr),
                extract_primary_gene_id(attr)
            )
            tx_candidates <- tx_candidates[!is.na(tx_candidates) & nzchar(trimws(tx_candidates))]
            tx <- if (length(tx_candidates) > 0) tx_candidates[1] else NA_character_
            tx <- as.character(tx)
            if (is.na(tx) || !nzchar(tx)) tx <- ""
            tx <- trimws(safe_url_decode(tx))
            tx <- str_remove(tx, regex("^(transcript|gene)\\s*:\\s*", ignore_case = TRUE))
            tx <- trimws(tx)
        }
    }
    list(transcript = if (is.na(tx) || !nzchar(tx)) "N/A" else tx, chromosome = chromosome)
}

split_gene_data_by_transcript <- function(data_df) {
    if (is.null(data_df) || nrow(data_df) == 0) {
        return(list())
    }

    df <- as.data.frame(data_df, stringsAsFactors = FALSE)
    if (!all(c("V3", "V9") %in% colnames(df))) {
        return(list(df))
    }

    normalize_link_tokens <- function(x) {
        x <- as.character(x %||% "")
        x <- trimws(safe_url_decode(x))
        x <- gsub('["\\\']', "", x)
        x <- x[nzchar(x)]
        if (length(x) == 0) {
            return(character(0))
        }
        clean <- trimws(str_remove(x, regex("^(transcript|gene)\\s*:\\s*", ignore_case = TRUE)))
        clean <- clean[nzchar(clean)]
        unique(c(x, clean, paste0("transcript:", clean), paste0("gene:", clean)))
    }

    n <- nrow(df)
    row_types <- tolower(trimws(as.character(df$V3 %||% rep("", n))))
    gene_rows <- which(row_types == "gene")
    # Recognise all RNA-level feature types used as transcript-level entries
    tx_level_types <- c(
        "mrna", "transcript", "lnc_rna", "trna", "rrna", "snorna", "snrna", "mirna",
        "ncrna", "primary_transcript", "pre_mirna", "guide_rna", "rnase_p_rna",
        "rnase_mrp_rna", "telomerase_rna", "antisense_rna", "srp_rna", "scarna",
        "vault_rna", "y_rna", "antisense_lncrna", "lncrna"
    )
    tx_rows <- which(row_types %in% tx_level_types)
    if (length(tx_rows) == 0) {
        return(list(df))
    }

    attrs_raw <- as.character(df$V9 %||% rep("", n))
    attrs_parsed <- lapply(attrs_raw, parse_gff_attributes)

    ids <- vapply(seq_len(n), function(i) {
        a <- attrs_parsed[[i]]
        id <- a[["id"]][1] %||% a[["transcript_id"]][1]
        if (is.null(id) || is.na(id) || !nzchar(id)) "" else as.character(id)
    }, character(1))

    parents <- lapply(seq_len(n), function(i) {
        a <- attrs_parsed[[i]]
        p <- a[["parent"]]
        if (is.null(p) || length(p) == 0) {
            return(character(0))
        }
        pv <- trimws(unlist(strsplit(paste(p, collapse = ","), ",", fixed = TRUE)))
        unique(pv[nzchar(pv)])
    })
    parent_tokens <- lapply(parents, normalize_link_tokens)

    tx_ids_raw <- vapply(tx_rows, function(i) {
        tid <- ids[i]
        if (!nzchar(tid)) {
            raw <- safe_url_decode(attrs_raw[i] %||% "")
            tid <- str_extract(raw, "(^|;)ID=[^;]+") %>% str_remove("(^|;)ID=")
        }
        as.character(tid %||% "")
    }, character(1))
    tx_ids_display <- vapply(tx_ids_raw, function(tid) {
        t <- trimws(safe_url_decode(tid %||% ""))
        t <- str_remove(t, regex("^(transcript|gene)\\s*:\\s*", ignore_case = TRUE))
        trimws(t)
    }, character(1))

    valid_tx <- nzchar(tx_ids_raw) | nzchar(tx_ids_display)
    if (!any(valid_tx)) {
        return(list(df))
    }

    tx_rows_valid <- tx_rows[valid_tx]
    tx_raw_valid <- tx_ids_raw[valid_tx]
    tx_disp_valid <- tx_ids_display[valid_tx]
    tx_base <- str_remove(tolower(tx_disp_valid), "(?:[-_.]|\\b)\\d+$")
    tx_num <- suppressWarnings(as.numeric(str_match(tx_disp_valid, "(?:[-_.]|\\b)(\\d+)$")[, 2]))
    tx_num_ord <- ifelse(is.na(tx_num), Inf, tx_num)
    ord <- order(tx_base, tx_num_ord, tolower(tx_disp_valid), tx_rows_valid)

    out <- list()
    for (k in ord) {
        tx_row <- tx_rows_valid[k]
        tx_id_raw <- tx_raw_valid[k]
        tx_id_display <- tx_disp_valid[k]
        selected <- rep(FALSE, n)
        if (length(gene_rows) > 0) selected[gene_rows] <- TRUE
        selected[tx_row] <- TRUE

        frontier <- normalize_link_tokens(tx_id_raw)
        if (length(frontier) == 0) frontier <- normalize_link_tokens(tx_id_display)
        repeat {
            hits <- which(!selected & vapply(parent_tokens, function(ps) length(ps) > 0 && any(ps %in% frontier), logical(1)))
            if (length(hits) == 0) break
            selected[hits] <- TRUE
            new_ids <- unique(ids[hits])
            new_ids <- new_ids[nzchar(new_ids)]
            frontier <- unique(c(frontier, normalize_link_tokens(new_ids)))
        }

        sub_df <- df[selected, , drop = FALSE]
        if (nrow(sub_df) == 0) next

        key <- tx_id_display
        if (!nzchar(key)) key <- tx_id_raw
        if (!nzchar(key)) key <- paste0("transcript_", tx_row)
        key_i <- key
        i <- 1
        while (key_i %in% names(out)) {
            i <- i + 1
            key_i <- paste0(key, "_", i)
        }
        out[[key_i]] <- sub_df
    }

    if (length(out) == 0) {
        return(list(df))
    }
    out
}

# --- 5. BÚSQUEDA DE GENES (ACTUALIZADA: CONTROL PARALELO) ---

build_gene_query_candidates <- function(gene_name, organism = NULL, taxid = NULL, status_callback = NULL, max_aliases = 40, alias_lookup_timeout_sec = 0, use_parallel = TRUE, alias_sources = c("mygene", "ncbi", "uniprot", "ensembl")) {
    expand_local <- function(q) {
        out <- c(q)
        if (grepl(";", q, fixed = TRUE)) out <- c(out, gsub(";", ".", q), gsub(";", "-", q), gsub(";", "", q))
        if (grepl("\\.", q)) out <- c(out, gsub("\\.", ";", q), gsub("\\.", "-", q), gsub("\\.", "", q))
        if (grepl("-", q, fixed = TRUE)) out <- c(out, gsub("-", ";", q), gsub("-", ".", q), gsub("-", "", q))
        unique(out[nzchar(out)])
    }
    local_variants <- expand_local(gene_name)
    external_aliases <- character(0)
    emit_status <- function(msg) {
        if (is.null(status_callback)) {
            return(invisible(NULL))
        }
        try(status_callback(as.character(msg %||% "")), silent = TRUE)
        invisible(NULL)
    }
    allowed_sources <- c("mygene", "ncbi", "uniprot", "ensembl")
    source_labels <- c(mygene = "MyGene", ncbi = "NCBI", uniprot = "UniProt", ensembl = "Ensembl")
    alias_sources <- unique(tolower(trimws(as.character(alias_sources %||% allowed_sources))))
    alias_sources <- alias_sources[alias_sources %in% allowed_sources]
    external_lookup_meta <- list(
        had_errors = FALSE,
        source_errors = character(0),
        skipped = FALSE,
        source_names = alias_sources
    )
    format_source_names <- function(src) {
        if (length(src) == 0) {
            return("none")
        }
        out <- unname(source_labels[src])
        out[is.na(out) | !nzchar(out)] <- src[is.na(out) | !nzchar(out)]
        paste(out, collapse = ", ")
    }

    if (length(alias_sources) == 0) {
        emit_status("\u2022 External stage: Skipped (all external sources disabled in Settings).")
        external_lookup_meta$skipped <- TRUE
        external_lookup_meta$skip_reason <- "sources_disabled"
    } else if (!is.null(taxid) || !is.null(organism)) {
        emit_status(sprintf("\u2022 External stage: Preparing alias lookup (%s)...", format_source_names(alias_sources)))
        tryCatch(
            {
                mode_msg <- if (use_parallel) "Parallel" else "Sequential"
                app_debug_log(sprintf("[DEBUG] Searching aliases for '%s' (Mode: %s)...", gene_name, mode_msg))

                # Pasamos use_parallel y fuentes activas a la librería externa
                alias_fun <- get("get_gene_aliases", mode = "function")
                alias_args <- list(
                    gene = gene_name,
                    taxid = taxid,
                    organism = organism,
                    use_parallel = use_parallel,
                    status_callback = emit_status
                )
                if ("sources" %in% names(formals(alias_fun))) {
                    alias_args$sources <- alias_sources
                }
                external_aliases <- do.call(alias_fun, alias_args)
                external_lookup_meta <- modifyList(
                    external_lookup_meta,
                    attr(external_aliases, "lookup_meta", exact = TRUE) %||% list()
                )

                if (length(external_aliases) > 0) {
                    app_debug_log(sprintf("[DEBUG] Found aliases: %s", paste(external_aliases, collapse = ", ")))
                    emit_status(sprintf("\u2022 External stage: Found %d alias candidate(s).", length(external_aliases)))
                } else {
                    app_debug_log("[DEBUG] No external aliases found.")
                    emit_status("\u2022 External stage: No aliases found.")
                }
            },
            error = function(e) {
                app_debug_log("[DEBUG] Error in external search: ", e$message)
                emit_status("\u2022 External stage: Query failed; using local variants only.")
                external_lookup_meta$had_errors <- TRUE
                external_lookup_meta$source_errors <- unique(c(
                    as.character(external_lookup_meta$source_errors %||% character(0)),
                    trimws(as.character(e$message %||% "external lookup failed"))
                ))
            }
        )
    } else {
        emit_status("\u2022 External stage: Skipped (organism metadata unavailable).")
        external_lookup_meta$skipped <- TRUE
        external_lookup_meta$skip_reason <- "organism_metadata_unavailable"
    }

    all_candidates <- unique(c(local_variants, external_aliases))
    if (length(all_candidates) > max_aliases) {
        all_candidates <- all_candidates[seq_len(max_aliases)]
    }
    attr(all_candidates, "external_lookup_meta") <- external_lookup_meta
    return(all_candidates)
}

search_gene_in_file <- function(file_path, gene_names, show_diagnostics = TRUE, match_mode = c("flex", "exact"), return_meta = FALSE, include_bridge_tokens = FALSE) {
    tryCatch(
        {
            match_mode <- match.arg(match_mode)
            use_tabix <- is_tabix_annotation_file(file_path)
            if (use_tabix) {
                idx <- build_gff_gene_light_index(file_path)
                genes_df <- idx$genes_df
                if (nrow(genes_df) == 0) {
                    if (isTRUE(return_meta)) {
                        return(list(data = NULL, matched_gene_id = NA_character_, matched_gene_name = NA_character_))
                    }
                    return(NULL)
                }
                target_row_ids <- search_gene_rows_with_index(idx, gene_names, match_mode = match_mode)
                if (length(target_row_ids) == 0 && identical(match_mode, "exact") && isTRUE(include_bridge_tokens)) {
                    target_row_ids <- search_gene_rows_via_bridge_descriptions(genes_df$attributes, gene_names)
                }
                target_gene_rows <- if (length(target_row_ids) > 0) genes_df[target_row_ids, , drop = FALSE] else genes_df[0, , drop = FALSE]
            } else {
                idx <- build_gff_gene_index(file_path)
                df <- idx$df
                if (nrow(df) == 0) {
                    if (isTRUE(return_meta)) {
                        return(list(data = NULL, matched_gene_id = NA_character_, matched_gene_name = NA_character_))
                    }
                    return(NULL)
                }
                target_row_ids <- search_gene_rows_with_index(idx, gene_names, match_mode = match_mode)
                if (length(target_row_ids) == 0 && identical(match_mode, "exact") && isTRUE(include_bridge_tokens)) {
                    attr_subset <- df$attributes[idx$gene_rows]
                    bridge_rel <- search_gene_rows_via_bridge_descriptions(attr_subset, gene_names)
                    if (length(bridge_rel) > 0) {
                        target_row_ids <- idx$gene_rows[bridge_rel]
                    }
                }
                target_gene_rows <- if (length(target_row_ids) > 0) df[target_row_ids, , drop = FALSE] else df[0, , drop = FALSE]
            }

            if (nrow(target_gene_rows) == 0) {
                if (isTRUE(return_meta)) {
                    return(list(data = NULL, matched_gene_id = NA_character_, matched_gene_name = NA_character_))
                }
                return(NULL)
            }

            first_attrs <- parse_gff_attributes(target_gene_rows$attributes[1])
            first_type <- tolower(as.character(target_gene_rows$type[1] %||% ""))
            if (first_type %in% c("gene", "pseudogene")) {
                gene_id_candidates <- c(first_attrs[["id"]][1], first_attrs[["gene_id"]][1], first_attrs[["locus_tag"]][1])
            } else {
                # For CDS-only/prokaryotic annotations, Parent often points to the gene-like anchor.
                gene_id_candidates <- c(
                    first_attrs[["parent"]][1],
                    first_attrs[["gene_id"]][1],
                    first_attrs[["locus_tag"]][1],
                    first_attrs[["id"]][1]
                )
            }
            gene_id_candidates <- as.character(gene_id_candidates %||% character(0))
            gene_id_candidates <- trimws(safe_url_decode(gene_id_candidates))
            gene_id_candidates <- trimws(vapply(strsplit(gene_id_candidates, ",", fixed = TRUE), `[`, character(1), 1))
            gene_id_candidates <- gene_id_candidates[!is.na(gene_id_candidates) & nzchar(gene_id_candidates)]
            gene_id <- if (length(gene_id_candidates) > 0) gene_id_candidates[1] else NA_character_

            matched_name_candidates <- c(
                first_attrs[["gene_name"]][1],
                first_attrs[["gene"]][1],
                first_attrs[["name"]][1],
                first_attrs[["locus_tag"]][1],
                gene_id
            )
            matched_name_candidates <- as.character(matched_name_candidates %||% character(0))
            matched_name_candidates <- trimws(safe_url_decode(matched_name_candidates))
            matched_name_candidates <- matched_name_candidates[!is.na(matched_name_candidates) & nzchar(matched_name_candidates)]
            matched_name <- if (length(matched_name_candidates) > 0) matched_name_candidates[1] else gene_id

            if (is.na(gene_id) || !nzchar(gene_id)) {
                gene_id <- str_extract(safe_url_decode(target_gene_rows$attributes[1]), 'gene_id "[^"]+"') %>%
                    str_remove('gene_id "') %>%
                    str_remove('"')
            }
            can_extract_block <- !is.na(gene_id) && nzchar(gene_id)
            if (!can_extract_block) {
                # Some minimalist annotations omit stable gene IDs; keep the matched row as fallback instead of returning NULL.
                gene_id <- if (!is.na(matched_name) && nzchar(matched_name)) matched_name else NA_character_
            }

            if (use_tabix) {
                target_chr <- as.character(target_gene_rows$seqid[1] %||% "")
                target_start <- as.numeric(target_gene_rows$start[1] %||% NA_real_)
                target_end <- as.numeric(target_gene_rows$end[1] %||% NA_real_)
                region_df <- if (nzchar(target_chr) && is.finite(target_start) && is.finite(target_end)) {
                    scan_tabix_region_gff(file_path, target_chr, target_start, target_end)
                } else {
                    empty_gff_df()
                }
                result_df <- if (can_extract_block) extract_gene_block_from_df(region_df, gene_id) else data.frame()
                if (nrow(result_df) == 0) {
                    fallback_gene <- target_gene_rows[, c("seqid", "source", "type", "start", "end", "score", "strand", "phase", "attributes"), drop = FALSE]
                    result_df <- fallback_gene
                    colnames(result_df) <- paste0("V", 1:9)
                }
            } else {
                result_df <- if (can_extract_block) extract_gene_block_from_df(df, gene_id) else data.frame()
                if (nrow(result_df) == 0) {
                    fallback_gene <- target_gene_rows[, c("seqid", "source", "type", "start", "end", "score", "strand", "phase", "attributes"), drop = FALSE]
                    result_df <- fallback_gene
                    colnames(result_df) <- paste0("V", 1:9)
                }
            }
            if (isTRUE(return_meta)) {
                return(list(data = result_df, matched_gene_id = gene_id, matched_gene_name = ifelse(is.na(matched_name), gene_id, matched_name)))
            }
            return(result_df)
        },
        error = function(e) {
            if (isTRUE(return_meta)) list(data = NULL, matched_gene_id = NA_character_, matched_gene_name = NA_character_) else NULL
        }
    )
}

fetch_gene_data_sync <- function(chr_name, gene_coords, fasta_path = NULL, fasta_id = NULL, exon_ranges = NULL, strand = "+") {
    fetch_perf <- app_perf_new_run("SEQ_FETCH")
    app_perf_mark(fetch_perf, "start", "SEQ")
    out <- tryCatch(
        {
            chr_name <- as.character(chr_name %||% "")
            start_pos <- suppressWarnings(as.numeric(gene_coords$start %||% NA_real_))
            end_pos <- suppressWarnings(as.numeric(gene_coords$end %||% NA_real_))
            seq_str <- extract_spliced_exon_sequence(fasta_path, chr_name, exon_ranges = exon_ranges, strand = strand)
            app_perf_mark(fetch_perf, sprintf("after spliced len=%d", as.integer(nchar(seq_str %||% ""))), "SEQ")
            if (!nzchar(seq_str) && is.finite(start_pos) && is.finite(end_pos)) {
                seq_str <- extract_sequence_from_fasta(fasta_path, chr_name, start_pos, end_pos)
                app_perf_mark(fetch_perf, sprintf("after fallback len=%d", as.integer(nchar(seq_str %||% ""))), "SEQ")
            }

            fasta_id <- safe_url_decode(as.character(fasta_id %||% ""))
            fasta_id <- trimws(fasta_id)
            if (!nzchar(fasta_id)) {
                if (nzchar(chr_name) && is.finite(start_pos) && is.finite(end_pos)) {
                    fasta_id <- sprintf("%s:%s-%s", chr_name, as.integer(round(start_pos)), as.integer(round(end_pos)))
                } else {
                    fasta_id <- "transcript"
                }
            }

            header <- if (nzchar(chr_name) && is.finite(start_pos) && is.finite(end_pos)) {
                sprintf(">%s | chr=%s | start=%s | end=%s", fasta_id, chr_name, as.integer(round(start_pos)), as.integer(round(end_pos)))
            } else {
                sprintf(">%s", fasta_id)
            }

            file_content <- if (nzchar(seq_str)) paste0(header, "\n", seq_str) else ""
            app_perf_mark(fetch_perf, "done", "SEQ")
            list(title = chr_name, sequence = seq_str, file_content = file_content, fasta_id = fasta_id)
        },
        error = function(e) {
            app_perf_mark(fetch_perf, sprintf("error: %s", as.character(e$message %||% "unknown")), "SEQ")
            list(title = as.character(chr_name %||% "Error"), sequence = "", file_content = "", fasta_id = as.character(fasta_id %||% "transcript"))
        }
    )
    out
}

fetch_gene_data_async <- function(chr_name, gene_coords, fasta_path = NULL, fasta_id = NULL, exon_ranges = NULL, strand = "+") {
    # Compatibility wrapper: return a resolved promise.
    promises::promise_resolve(
        fetch_gene_data_sync(
            chr_name = chr_name,
            gene_coords = gene_coords,
            fasta_path = fasta_path,
            fasta_id = fasta_id,
            exon_ranges = exon_ranges,
            strand = strand
        )
    )
}

# --- 6. CONTEXTO GENÓMICO: GENES VECINOS ---

extract_primary_gene_id <- function(attr) {
    attrs <- parse_gff_attributes(attr %||% "")
    parent_raw <- attrs[["parent"]][1] %||% ""
    parent_first <- trimws(strsplit(as.character(parent_raw), ",", fixed = TRUE)[[1]][1] %||% "")
    gid <- attrs[["gene_id"]][1] %||%
        attrs[["locus_tag"]][1] %||%
        if (nzchar(parent_first)) {
            parent_first
        } else {
            NULL %||%
                attrs[["id"]][1] %||%
                attrs[["gene"]][1]
        }
    if (is.null(gid) || is.na(gid) || !nzchar(gid)) {
        raw <- safe_url_decode(attr %||% "")
        gid <- str_extract(raw, "(^|;)ID=[^;]+") %>% str_remove("(^|;)ID=")
    }
    gid %||% NA_character_
}

sanitize_gene_display_name <- function(x) {
    y <- as.character(x %||% NA_character_)
    if (length(y) == 0 || is.na(y) || !nzchar(trimws(y))) {
        return(NA_character_)
    }
    y <- safe_url_decode(y)
    y <- trimws(y)
    y <- str_remove(y, regex("^(gene|transcript|mrna)\\s*:\\s*", ignore_case = TRUE))
    if (length(y) == 0 || !nzchar(y)) {
        return(NA_character_)
    }
    y
}

extract_primary_gene_name <- function(attr) {
    attrs <- parse_gff_attributes(attr %||% "")
    gname <- attrs[["gene_name"]][1] %||%
        attrs[["gene"]][1] %||%
        attrs[["name"]][1] %||%
        attrs[["gene_symbol"]][1] %||%
        attrs[["symbol"]][1] %||%
        attrs[["locus_tag"]][1] %||%
        attrs[["locus"]][1] %||%
        attrs[["preferred_name"]][1]
    sanitize_gene_display_name(gname %||% NA_character_)
}

extract_primary_gene_id_batch <- function(attrs) {
    attrs <- as.character(attrs %||% "")
    # Try GFF3 ID= first
    gid <- str_match(attrs, "(?:^|;)\\s*ID=([^;]+)")[, 2]
    # Try GTF gene_id
    miss <- is.na(gid)
    if (any(miss)) {
        gid2 <- str_match(attrs[miss], '(?:^|;|\\t)\\s*gene_id\\s*[= ]\\s*"?([^;"\\t]+)')[, 2]
        gid[miss] <- gid2
    }
    # Try locus_tag
    miss <- is.na(gid)
    if (any(miss)) {
        gid3 <- str_match(attrs[miss], "(?:^|;)\\s*locus_tag=([^;]+)")[, 2]
        gid[miss] <- gid3
    }
    # Only decode non-NA values.
    valid_gid <- !is.na(gid)
    if (any(valid_gid)) gid[valid_gid] <- safe_url_decode(gid[valid_gid])
    gid
}

extract_primary_gene_name_batch <- function(attrs) {
    attrs <- as.character(attrs %||% "")
    # Priority order: gene_name, gene, Name, gene_symbol, symbol, locus_tag, locus, preferred_name
    patterns <- c(
        '(?:^|;|\\t)\\s*gene_name\\s*[= ]\\s*"?([^;"\\t]+)',
        '(?:^|;|\\t)\\s*gene\\s*[= ]\\s*"?([^;"\\t]+)',
        "(?:^|;)\\s*Name=([^;]+)",
        '(?:^|;|\\t)\\s*gene_symbol\\s*[= ]\\s*"?([^;"\\t]+)',
        '(?:^|;|\\t)\\s*symbol\\s*[= ]\\s*"?([^;"\\t]+)',
        "(?:^|;)\\s*locus_tag=([^;]+)",
        "(?:^|;)\\s*locus=([^;]+)",
        '(?:^|;|\\t)\\s*preferred_name\\s*[= ]\\s*"?([^;"\\t]+)'
    )
    gname <- rep(NA_character_, length(attrs))
    miss <- rep(TRUE, length(attrs))
    for (pat in patterns) {
        if (!any(miss)) break
        m <- str_match(attrs[miss], pat)
        found <- !is.na(m[, 2])
        idx_miss <- which(miss)
        gname[idx_miss[found]] <- m[found, 2]
        miss[idx_miss[found]] <- FALSE
    }
    # Only decode non-NA values.
    valid_gname <- !is.na(gname)
    if (any(valid_gname)) gname[valid_gname] <- safe_url_decode(gname[valid_gname])
    gname
}

sanitize_gene_display_name_batch <- function(x) {
    y <- as.character(x %||% NA_character_)
    y <- ifelse(is.na(y) | !nzchar(trimws(y)), NA_character_, y)
    valid <- !is.na(y)
    if (any(valid)) {
        y[valid] <- safe_url_decode(y[valid])
        y[valid] <- trimws(y[valid])
        y[valid] <- str_remove(y[valid], regex("^(gene|transcript|mrna)\\s*:\\s*", ignore_case = TRUE))
        y[valid] <- ifelse(nzchar(y[valid]), y[valid], NA_character_)
    }
    y
}

get_genes_table_from_annotation <- function(file_path) {
    key <- gff_cache_key(file_path)
    cached <- cache_env_get(.gff_genes_table_cache, key, default = NULL)
    if (!is.null(cached)) {
        required_cols <- c("gene_id", "neighbor_id", "neighbor_name", "neighbor_label", "chr", "start", "end", "strand")
        if (is.data.frame(cached) && all(required_cols %in% colnames(cached))) {
            return(cached)
        }
        cache_env_drop(.gff_genes_table_cache, key)
    }

    # Always prefer the light gene index for neighbor context:
    # it only streams gene/CDS rows and avoids parsing the full annotation.
    idx_light <- build_gff_gene_light_index(file_path)
    genes_raw <- idx_light$genes_df

    if (nrow(genes_raw) == 0) {
        out <- data.frame()
        cache_env_set(
            .gff_genes_table_cache,
            key,
            out,
            max_size = annotation_memory_cache_limits$genes_table_max_entries,
            max_bytes = annotation_memory_cache_limits$genes_table_max_bytes
        )
        return(out)
    }

    chr_col <- if ("seqid" %in% colnames(genes_raw)) "seqid" else "V1"
    start_col <- if ("start" %in% colnames(genes_raw)) "start" else "V4"
    end_col <- if ("end" %in% colnames(genes_raw)) "end" else "V5"
    strand_col <- if ("strand" %in% colnames(genes_raw)) "strand" else "V7"
    type_col <- if ("type" %in% colnames(genes_raw)) "type" else "V3"
    attrs_col <- if ("attributes" %in% colnames(genes_raw)) "attributes" else "V9"

    attrs <- genes_raw[[attrs_col]] %||% rep("", nrow(genes_raw))
    # Vectorized batch extraction — much faster than per-row vapply
    gene_ids <- sanitize_gene_display_name_batch(extract_primary_gene_id_batch(attrs))
    gene_names <- sanitize_gene_display_name_batch(extract_primary_gene_name_batch(attrs))
    neighbor_name <- ifelse(!is.na(gene_names) & nzchar(trimws(gene_names)), gene_names, NA_character_)
    neighbor_id <- ifelse(!is.na(gene_ids) & nzchar(trimws(gene_ids)), gene_ids, NA_character_)
    # Fallback chain: name → id → gene_id → "Unknown" — never NA
    neighbor_label <- ifelse(!is.na(neighbor_name) & nzchar(trimws(neighbor_name)), neighbor_name,
        ifelse(!is.na(neighbor_id) & nzchar(trimws(neighbor_id)), neighbor_id,
            ifelse(!is.na(gene_ids) & nzchar(trimws(gene_ids)), gene_ids, "Unknown")
        )
    )

    out <- data.frame(
        gene_id = gene_ids,
        neighbor_id = neighbor_id,
        neighbor_name = neighbor_name,
        neighbor_label = neighbor_label,
        chr = as.character(genes_raw[[chr_col]]),
        start = as.numeric(genes_raw[[start_col]]),
        end = as.numeric(genes_raw[[end_col]]),
        strand = as.character(genes_raw[[strand_col]]),
        type = as.character(genes_raw[[type_col]]),
        stringsAsFactors = FALSE
    ) %>%
        filter(is.finite(start), is.finite(end), !is.na(chr), nzchar(chr)) %>%
        arrange(chr, start, end)

    cache_env_set(
        .gff_genes_table_cache,
        key,
        out,
        max_size = annotation_memory_cache_limits$genes_table_max_entries,
        max_bytes = annotation_memory_cache_limits$genes_table_max_bytes
    )
    out
}

get_genes_chr_index_from_annotation <- function(file_path, genes_df = NULL) {
    key <- gff_cache_key(file_path)
    cached <- cache_env_get(.gff_genes_chr_index_cache, key, default = NULL)
    if (!is.null(cached)) {
        if (is.list(cached) && !is.null(cached$rows) && !is.null(cached$start) && !is.null(cached$end)) {
            return(cached)
        }
        cache_env_drop(.gff_genes_chr_index_cache, key)
    }

    if (is.null(genes_df)) {
        genes_df <- get_genes_table_from_annotation(file_path)
    }

    if (!is.data.frame(genes_df) || nrow(genes_df) == 0) {
        out <- list(rows = list(), start = list(), end = list())
        cache_env_set(
            .gff_genes_chr_index_cache,
            key,
            out,
            max_size = annotation_memory_cache_limits$genes_chr_index_max_entries,
            max_bytes = annotation_memory_cache_limits$genes_chr_index_max_bytes
        )
        return(out)
    }

    chr_vec <- as.character(genes_df$chr %||% rep("", nrow(genes_df)))
    start_vec <- suppressWarnings(as.numeric(genes_df$start))
    end_vec <- suppressWarnings(as.numeric(genes_df$end))
    valid <- is.finite(start_vec) & is.finite(end_vec) & !is.na(chr_vec) & nzchar(chr_vec)
    idx_valid <- which(valid)
    if (length(idx_valid) == 0) {
        out <- list(rows = list(), start = list(), end = list())
        cache_env_set(
            .gff_genes_chr_index_cache,
            key,
            out,
            max_size = annotation_memory_cache_limits$genes_chr_index_max_entries,
            max_bytes = annotation_memory_cache_limits$genes_chr_index_max_bytes
        )
        return(out)
    }

    chr_valid <- chr_vec[idx_valid]
    rows_by_chr <- split(idx_valid, chr_valid, drop = TRUE)
    starts_by_chr <- lapply(rows_by_chr, function(ix) start_vec[ix])
    ends_by_chr <- lapply(rows_by_chr, function(ix) end_vec[ix])

    out <- list(
        rows = rows_by_chr,
        start = starts_by_chr,
        end = ends_by_chr
    )
    cache_env_set(
        .gff_genes_chr_index_cache,
        key,
        out,
        max_size = annotation_memory_cache_limits$genes_chr_index_max_entries,
        max_bytes = annotation_memory_cache_limits$genes_chr_index_max_bytes
    )
    out
}

get_nearest_neighbors <- function(gene_target, genes_df, chr_index = NULL) {
    empty_neighbor <- list(
        neighbor_id = NA_character_,
        neighbor_name = NA_character_,
        neighbor_label = NA_character_,
        neighbor_start = NA_real_,
        neighbor_end = NA_real_,
        neighbor_chr = NA_character_,
        neighbor_strand = NA_character_,
        dist_bp = NA_real_
    )

    if (is.null(gene_target) || nrow(genes_df) == 0) {
        return(list(
            upstream = empty_neighbor,
            downstream = empty_neighbor,
            flags = list(has_up = FALSE, has_down = FALSE, overlap_up = FALSE, overlap_down = FALSE)
        ))
    }

    target_chr <- as.character(gene_target$chr[1] %||% "")
    target_start <- as.numeric(gene_target$start[1] %||% NA_real_)
    target_end <- as.numeric(gene_target$end[1] %||% NA_real_)
    if (!nzchar(target_chr) || !is.finite(target_start) || !is.finite(target_end)) {
        return(list(
            upstream = empty_neighbor,
            downstream = empty_neighbor,
            flags = list(has_up = FALSE, has_down = FALSE, overlap_up = FALSE, overlap_down = FALSE)
        ))
    }
    chr_vec <- as.character(genes_df$chr %||% rep("", nrow(genes_df)))
    start_vec_full <- suppressWarnings(as.numeric(genes_df$start))
    end_vec_full <- suppressWarnings(as.numeric(genes_df$end))

    idx_chr <- integer(0)
    start_vec_chr <- numeric(0)
    end_vec_chr <- numeric(0)
    if (is.list(chr_index) && !is.null(chr_index$rows) && target_chr %in% names(chr_index$rows)) {
        idx_chr <- as.integer(chr_index$rows[[target_chr]])
        start_vec_chr <- suppressWarnings(as.numeric(chr_index$start[[target_chr]]))
        end_vec_chr <- suppressWarnings(as.numeric(chr_index$end[[target_chr]]))
        keep_local <- is.finite(idx_chr) & idx_chr >= 1L & idx_chr <= nrow(genes_df) &
            is.finite(start_vec_chr) & is.finite(end_vec_chr)
        idx_chr <- idx_chr[keep_local]
        start_vec_chr <- start_vec_chr[keep_local]
        end_vec_chr <- end_vec_chr[keep_local]
    } else {
        valid <- is.finite(start_vec_full) & is.finite(end_vec_full) & !is.na(chr_vec) & nzchar(chr_vec)
        idx_chr <- which(valid & chr_vec == target_chr)
        if (length(idx_chr) > 0) {
            start_vec_chr <- start_vec_full[idx_chr]
            end_vec_chr <- end_vec_full[idx_chr]
        }
    }
    if (length(idx_chr) > 0) {
        keep_non_self <- !(start_vec_chr == target_start & end_vec_chr == target_end)
        idx_chr <- idx_chr[keep_non_self]
        start_vec_chr <- start_vec_chr[keep_non_self]
        end_vec_chr <- end_vec_chr[keep_non_self]
    }
    if (length(idx_chr) == 0) {
        return(list(
            upstream = empty_neighbor,
            downstream = empty_neighbor,
            flags = list(has_up = FALSE, has_down = FALSE, overlap_up = FALSE, overlap_down = FALSE)
        ))
    }

    idx_up_overlap <- which(start_vec_chr < target_start & end_vec_chr >= target_start)
    idx_up_non_overlap <- which(end_vec_chr < target_start)
    up_idx <- if (length(idx_up_overlap) > 0) {
        idx_chr[idx_up_overlap[which.max(end_vec_chr[idx_up_overlap])]]
    } else if (length(idx_up_non_overlap) > 0) {
        idx_chr[idx_up_non_overlap[which.max(end_vec_chr[idx_up_non_overlap])]]
    } else {
        NA_integer_
    }

    idx_down_overlap <- which(start_vec_chr <= target_end & end_vec_chr > target_end)
    idx_down_non_overlap <- which(start_vec_chr > target_end)
    down_idx <- if (length(idx_down_overlap) > 0) {
        idx_chr[idx_down_overlap[which.min(start_vec_chr[idx_down_overlap])]]
    } else if (length(idx_down_non_overlap) > 0) {
        idx_chr[idx_down_non_overlap[which.min(start_vec_chr[idx_down_non_overlap])]]
    } else {
        NA_integer_
    }

    build_neighbor <- function(idx_one, target_start_local, target_end_local) {
        if (!is.finite(idx_one) || is.na(idx_one) || idx_one < 1L || idx_one > nrow(genes_df)) {
            return(empty_neighbor)
        }
        nb_name <- as.character(genes_df$neighbor_name[idx_one] %||% "")
        nb_id <- as.character(genes_df$neighbor_id[idx_one] %||% "")
        nb_gene_id <- as.character(genes_df$gene_id[idx_one] %||% "")
        nb_label <- as.character(genes_df$neighbor_label[idx_one] %||% "")
        if (!nzchar(trimws(nb_label))) nb_label <- nb_name
        if (!nzchar(trimws(nb_label))) nb_label <- nb_id
        if (!nzchar(trimws(nb_label))) nb_label <- nb_gene_id
        if (!nzchar(trimws(nb_label))) nb_label <- "Unknown"
        if (!nzchar(trimws(nb_id))) nb_id <- nb_gene_id
        if (!nzchar(trimws(nb_name))) nb_name <- nb_label
        nb_start <- as.numeric(start_vec_full[idx_one])
        nb_end <- as.numeric(end_vec_full[idx_one])
        dist_val <- if (nb_end < target_start_local) {
            as.numeric(target_start_local - nb_end - 1)
        } else if (nb_start > target_end_local) {
            as.numeric(nb_start - target_end_local - 1)
        } else {
            as.numeric(min(target_start_local - nb_end - 1, nb_start - target_end_local - 1))
        }
        list(
            neighbor_id = nb_id,
            neighbor_name = nb_name,
            neighbor_label = nb_label,
            neighbor_start = nb_start,
            neighbor_end = nb_end,
            neighbor_chr = as.character(chr_vec[idx_one]),
            neighbor_strand = as.character(genes_df$strand[idx_one] %||% ""),
            dist_bp = dist_val
        )
    }

    upstream <- build_neighbor(up_idx, target_start, target_end)
    downstream <- build_neighbor(down_idx, target_start, target_end)

    list(
        upstream = upstream,
        downstream = downstream,
        flags = list(
            has_up = !is.na(upstream$dist_bp),
            has_down = !is.na(downstream$dist_bp),
            overlap_up = !is.na(upstream$dist_bp) && upstream$dist_bp < 0,
            overlap_down = !is.na(downstream$dist_bp) && downstream$dist_bp < 0
        )
    )
}

format_distance <- function(d_bp) {
    if (is.null(d_bp) || is.na(d_bp) || !is.finite(d_bp)) {
        return(list(label_short = "N/A", label_exact = "N/A"))
    }

    d_num <- as.numeric(d_bp)
    d_abs <- abs(d_num)

    human <- if (d_abs >= 1e6) {
        sprintf("%.1f Mb", d_abs / 1e6)
    } else if (d_abs >= 1e3) {
        sprintf("%.1f kb", d_abs / 1e3)
    } else {
        sprintf("%d bp", as.integer(round(d_abs)))
    }
    human <- sub("\\.0\\s", " ", human)

    short <- if (d_num < 0) sprintf("overlap (%s)", human) else human
    exact <- sprintf("%d bp", as.integer(round(d_num)))

    list(label_short = short, label_exact = exact)
}

log_scale_position <- function(d_bp, d_min = 10, d_max = 1e6) {
    if (is.null(d_bp) || is.na(d_bp) || !is.finite(d_bp)) {
        return(NA_real_)
    }
    d_min <- max(1, as.numeric(d_min))
    d_max <- max(d_min + 1, as.numeric(d_max))
    d_abs <- abs(as.numeric(d_bp))
    d_clamped <- min(max(d_abs, d_min), d_max)
    s <- (log10(d_clamped) - log10(d_min)) / (log10(d_max) - log10(d_min))
    min(max(s, 0), 1)
}

get_neighbor_context_for_target <- function(annotation_file_path, gene_target) {
    if (is.null(annotation_file_path) || !nzchar(annotation_file_path) || is.null(gene_target)) {
        return(NULL)
    }

    chr_txt <- trimws(as.character(gene_target$chr[1] %||% ""))
    start_num <- suppressWarnings(as.numeric(gene_target$start[1] %||% NA_real_))
    end_num <- suppressWarnings(as.numeric(gene_target$end[1] %||% NA_real_))
    gid_txt <- trimws(as.character(gene_target$gene_id[1] %||% ""))
    if (!nzchar(chr_txt) || !is.finite(start_num) || !is.finite(end_num)) {
        return(NULL)
    }
    key <- paste(
        normalizePath(as.character(annotation_file_path), winslash = "/", mustWork = FALSE),
        chr_txt,
        as.integer(round(start_num)),
        as.integer(round(end_num)),
        gid_txt,
        sep = "::"
    )
    if (exists(key, envir = .neighbor_context_cache, inherits = FALSE)) {
        return(get(key, envir = .neighbor_context_cache, inherits = FALSE))
    }

    genes_df <- get_genes_table_from_annotation(annotation_file_path)
    if (nrow(genes_df) == 0) {
        return(NULL)
    }
    chr_index <- get_genes_chr_index_from_annotation(annotation_file_path, genes_df = genes_df)
    out <- get_nearest_neighbors(gene_target, genes_df, chr_index = chr_index)
    assign(key, out, envir = .neighbor_context_cache)
    trim_cache_env(.neighbor_context_cache, max_size = 5000L)
    out
}

# ═══════════════════════════════════════════════════════════════════════════════
# Protein-guided exon correspondence for "Comparative Aligned" view
# ─────────────────────────────────────────────────────────────────────────────
# Replaces the naive index-based ribbon pairing with biologically correct
# homology blocks derived from pairwise protein alignment (BLOSUM62).
# Pipeline: CDS extraction → translation → NW alignment (protein) →
#           codon→CDS-feature mapping → visual exon overlap → event classification
# ═══════════════════════════════════════════════════════════════════════════════

get_aligned_dna_substitution_matrix <- function() {
    # pwalign does not resolve "EDNAFULL" by name; use an explicit
    # IUPAC-aware nucleotide matrix with the same match/mismatch backbone.
    pwalign::nucleotideSubstitutionMatrix(match = 5, mismatch = -4, baseOnly = FALSE)
}

# Build a position-to-CDS-feature-index map.
# Returns an integer vector where element i = CDS-feature index (1-based)
# that owns nucleotide position i of the concatenated CDS.
# starts / ends: numeric vectors in transcription order (5'→3').
build_pos_to_exon_map <- function(starts, ends) {
    lens <- as.integer(round(ends - starts + 1L))
    lens[lens < 1L] <- 0L
    total_len <- sum(lens)
    if (total_len <= 0L) return(integer(0L))
    pos_map <- integer(total_len)
    cursor <- 1L
    for (i in seq_along(lens)) {
        if (lens[i] == 0L) next
        seg_end <- cursor + lens[i] - 1L
        pos_map[cursor:seg_end] <- i
        cursor <- seg_end + 1L
    }
    pos_map
}

# Compute protein-guided exon correspondence between two transcripts.
#
# Parameters:
#   df1, df2   – full track data.frames (aligned-view format, with columns:
#                plot_group, feature_type, xstart, xend, strand_val, genome_path, seqid)
#   df1e, df2e – visual exon rows of df1/df2 (sorted by rel_start, left-to-right)
#   min_codons – minimum aligned codons to call a correspondence (default 15)
#
# Returns a data.frame with columns:
#   vis_exon_A, vis_exon_B  – 1-based row indices into df1e / df2e
#   n_codons                 – number of aligned codons in this block
#   identity_pct             – % identical amino acids within block
#   overall_pid              – overall protein % identity for the pair
#   event_type               – "1:1", "1:n", "n:1", "partial"
# Returns NULL on any failure (no CDS, no FASTA, alignment error).
compute_protein_guided_correspondence <- function(df1, df2, df1e, df2e,
                                                  min_codons = 15L,
                                                  mode = "protein") {
    # mode: "protein" (BLOSUM62, recommended), "cds" (DNA NW on CDS),
    #       "exon" (DNA NW on full spliced exon, includes UTRs)
    mode <- tolower(trimws(mode %||% "protein"))
    if (!mode %in% c("protein", "cds", "exon")) mode <- "protein"

    # ── safety checks ────────────────────────────────────────────────────────
    if (is.null(df1) || is.null(df2) || is.null(df1e) || is.null(df2e)) return(NULL)
    if (nrow(df1e) == 0L || nrow(df2e) == 0L) return(NULL)
    if (!requireNamespace("Biostrings", quietly = TRUE)) return(NULL)
    if (!requireNamespace("pwalign",    quietly = TRUE)) return(NULL)

    # ── internal helpers ──────────────────────────────────────────────────────
    first_val <- function(df, ...) {
        for (nm in c(...)) {
            if (nm %in% names(df)) {
                v <- as.character(df[[nm]])
                v <- v[!is.na(v) & nzchar(v)]
                if (length(v) > 0L) return(v[1L])
            }
        }
        NULL
    }

    get_cds_rows <- function(df) {
        pg <- tolower(trimws(as.character(df$plot_group   %||% "")))
        ft <- tolower(trimws(as.character(df$feature_type %||% "")))
        cds <- df[(pg == "cds" | ft == "cds"), , drop = FALSE]
        if (nrow(cds) == 0L) return(NULL)
        cds$xstart <- suppressWarnings(as.numeric(cds$xstart))
        cds$xend   <- suppressWarnings(as.numeric(cds$xend))
        cds <- cds[is.finite(cds$xstart) & is.finite(cds$xend) &
                       cds$xend > cds$xstart, , drop = FALSE]
        if (nrow(cds) == 0L) NULL else cds
    }

    apply_phase <- function(seq_txt, cds_sorted) {
        # Remove non-coding prefix indicated by phase of first CDS feature
        ph_raw <- suppressWarnings(as.integer(
            (cds_sorted$phase %||% cds_sorted$V8 %||% 0L)[1L]
        ))
        ph <- if (!is.na(ph_raw) && ph_raw %in% c(1L, 2L)) ph_raw else 0L
        if (ph > 0L && nchar(seq_txt) > ph) substring(seq_txt, ph + 1L) else seq_txt
    }

    trim_to_codon <- function(s) {
        r <- nchar(s) %% 3L
        if (r > 0L) substr(s, 1L, nchar(s) - r) else s
    }

    translate_safe <- function(s) {
        tryCatch({
            dna <- Biostrings::DNAString(toupper(s))
            aa  <- as.character(Biostrings::translate(dna, if.fuzzy.codon = "solve"))
            sub("\\*$", "", aa)          # strip terminal stop
        }, error = function(e) NULL)
    }

    # ── genome paths & seqids (needed by all modes) ──────────────────────────
    str1 <- first_val(df1, "strand_val", "strand") %||% "+"
    str2 <- first_val(df2, "strand_val", "strand") %||% "+"
    gp1  <- first_val(df1, "genome_path")
    gp2  <- first_val(df2, "genome_path")
    sid1 <- first_val(df1, "seqid", "V1")
    sid2 <- first_val(df2, "seqid", "V1")
    if (is.null(gp1) || is.null(gp2) || is.null(sid1) || is.null(sid2)) return(NULL)

    # ── feature-index → visual exon index (by genomic overlap) ───────────────
    map_cds_to_visual <- function(feat_sorted, df_vis) {
        vis_xs <- suppressWarnings(as.numeric(df_vis$xstart))
        vis_xe <- suppressWarnings(as.numeric(df_vis$xend))
        f_xs   <- as.numeric(feat_sorted$xstart)
        f_xe   <- as.numeric(feat_sorted$xend)
        mapping <- integer(nrow(feat_sorted))
        for (i in seq_len(nrow(feat_sorted))) {
            ov <- which(is.finite(vis_xs) & vis_xs <= f_xe[i] &
                            is.finite(vis_xe) & vis_xe >= f_xs[i])
            mapping[i] <- if (length(ov) > 0L) ov[1L] else NA_integer_
        }
        mapping
    }

    compute_feature_units_by_visual <- function(feature_df, vis_map, n_vis, aligned_stride = 1L) {
        out_units <- rep(NA_real_, as.integer(n_vis %||% 0L))
        if (is.null(feature_df) || !is.data.frame(feature_df) || nrow(feature_df) == 0L ||
            length(vis_map) == 0L || length(out_units) == 0L) {
            return(out_units)
        }
        feat_start <- suppressWarnings(as.numeric(feature_df$xstart))
        feat_end <- suppressWarnings(as.numeric(feature_df$xend))
        feat_len_nt <- pmax(0, abs(feat_end - feat_start) + 1)
        accum_nt <- rep(0, length(out_units))
        seen <- rep(FALSE, length(out_units))
        for (i in seq_len(min(length(vis_map), length(feat_len_nt)))) {
            vi <- suppressWarnings(as.integer(vis_map[[i]]))
            if (!is.finite(vi) || vi < 1L || vi > length(accum_nt)) next
            if (!is.finite(feat_len_nt[[i]]) || feat_len_nt[[i]] <= 0) next
            accum_nt[[vi]] <- accum_nt[[vi]] + feat_len_nt[[i]]
            seen[[vi]] <- TRUE
        }
        divisor <- if (isTRUE(as.integer(aligned_stride %||% 1L) == 3L)) 3 else 1
        out_units[seen] <- accum_nt[seen] / divisor
        out_units
    }

    # ── MODE DISPATCH: sequence extraction + alignment ────────────────────────
    # Sets: aln, overall_pid, pm1, pm2, n_src1, n_src2, vis_map1, vis_map2, stride
    aln <- NULL; overall_pid <- NA_real_
    pm1 <- integer(0L); pm2 <- integer(0L)
    n_src1 <- 0L; n_src2 <- 0L
    vis_map1 <- integer(0L); vis_map2 <- integer(0L)
    stride <- 1L   # nucleotides per alignment column (1 for DNA, 3 for protein)

    if (mode %in% c("protein", "cds")) {
        # ── CDS-based modes: extract coding sequences ─────────────────────────
        cds1 <- get_cds_rows(df1); cds2 <- get_cds_rows(df2)
        if (is.null(cds1) || is.null(cds2)) return(NULL)
        cds1 <- if (str1 == "-") cds1[order(-cds1$xstart), , drop = FALSE] else
                                  cds1[order( cds1$xstart), , drop = FALSE]
        cds2 <- if (str2 == "-") cds2[order(-cds2$xstart), , drop = FALSE] else
                                  cds2[order( cds2$xstart), , drop = FALSE]

        seq1 <- tryCatch(extract_spliced_exon_sequence(gp1, sid1, cds1, strand = str1), error = function(e) NULL)
        seq2 <- tryCatch(extract_spliced_exon_sequence(gp2, sid2, cds2, strand = str2), error = function(e) NULL)
        if (is.null(seq1) || is.null(seq2) || !nzchar(seq1) || !nzchar(seq2)) return(NULL)

        seq1 <- trim_to_codon(apply_phase(seq1, cds1))
        seq2 <- trim_to_codon(apply_phase(seq2, cds2))
        if (nchar(seq1) < 3L || nchar(seq2) < 3L) return(NULL)

        if (mode == "protein") {
            # ── Protein alignment (BLOSUM62, NW global) ───────────────────────
            aa1 <- translate_safe(seq1); aa2 <- translate_safe(seq2)
            if (is.null(aa1) || is.null(aa2) || !nzchar(aa1) || !nzchar(aa2)) return(NULL)
            aln <- tryCatch(
                pwalign::pairwiseAlignment(
                    Biostrings::AAString(aa1), Biostrings::AAString(aa2),
                    type = "global", substitutionMatrix = "BLOSUM62",
                    gapOpening = -10, gapExtension = -0.5),
                error = function(e) NULL)
            stride <- 3L  # 1 amino acid = 3 CDS nucleotides
        } else {
            # ── CDS nucleotide alignment (IUPAC-aware DNA NW global) ─────────
            # Uses the same match/mismatch backbone as EDNAFULL (+5 / -4).
            aln <- tryCatch(
                pwalign::pairwiseAlignment(
                    Biostrings::DNAString(toupper(seq1)),
                    Biostrings::DNAString(toupper(seq2)),
                    type = "global", substitutionMatrix = get_aligned_dna_substitution_matrix(),
                    gapOpening = -10, gapExtension = -0.5),
                error = function(e) NULL)
            stride <- 1L  # 1 nucleotide per alignment column
        }
        if (is.null(aln)) return(NULL)
        pm1      <- build_pos_to_exon_map(cds1$xstart, cds1$xend)
        pm2      <- build_pos_to_exon_map(cds2$xstart, cds2$xend)
        n_src1   <- nrow(cds1)
        n_src2   <- nrow(cds2)
        vis_map1 <- map_cds_to_visual(cds1, df1e)
        vis_map2 <- map_cds_to_visual(cds2, df2e)
        feature_units1 <- compute_feature_units_by_visual(cds1, vis_map1, nrow(df1e), aligned_stride = stride)
        feature_units2 <- compute_feature_units_by_visual(cds2, vis_map2, nrow(df2e), aligned_stride = stride)

    } else {
        # ── Exon mode: full spliced exon sequences (CDS + UTRs, DNA NW) ───────
        # Scientific note: useful for studying UTR conservation and regulatory elements.
        # Signal-to-noise decreases for divergent species (> ~100 Mya).
        sort_vis <- function(df, strand) {
            xs <- suppressWarnings(as.numeric(df$xstart))
            if (strand == "-") df[order(-xs), , drop = FALSE] else df[order(xs), , drop = FALSE]
        }
        exs1 <- sort_vis(df1e, str1); exs2 <- sort_vis(df2e, str2)

        seq1 <- tryCatch(extract_spliced_exon_sequence(gp1, sid1, exs1, strand = str1), error = function(e) NULL)
        seq2 <- tryCatch(extract_spliced_exon_sequence(gp2, sid2, exs2, strand = str2), error = function(e) NULL)
        if (is.null(seq1) || is.null(seq2) || !nzchar(seq1) || !nzchar(seq2)) return(NULL)
        if (nchar(seq1) < 10L || nchar(seq2) < 10L) return(NULL)

        aln <- tryCatch(
            pwalign::pairwiseAlignment(
                Biostrings::DNAString(toupper(seq1)),
                Biostrings::DNAString(toupper(seq2)),
                type = "global", substitutionMatrix = get_aligned_dna_substitution_matrix(),
                gapOpening = -10, gapExtension = -0.5),
            error = function(e) NULL)
        if (is.null(aln)) return(NULL)
        stride   <- 1L
        pm1      <- build_pos_to_exon_map(exs1$xstart, exs1$xend)
        pm2      <- build_pos_to_exon_map(exs2$xstart, exs2$xend)
        n_src1   <- nrow(exs1)
        n_src2   <- nrow(exs2)
        vis_map1 <- map_cds_to_visual(exs1, df1e)
        vis_map2 <- map_cds_to_visual(exs2, df2e)
        feature_units1 <- compute_feature_units_by_visual(exs1, vis_map1, nrow(df1e), aligned_stride = stride)
        feature_units2 <- compute_feature_units_by_visual(exs2, vis_map2, nrow(df2e), aligned_stride = stride)
    }

    overall_pid <- tryCatch(pwalign::pid(aln), error = function(e) NA_real_)

    # ── walk alignment columns: accumulate match counts per visual exon pair ──
    aln1_chars <- strsplit(as.character(pwalign::alignedPattern(aln)), "")[[1L]]
    aln2_chars <- strsplit(as.character(pwalign::alignedSubject(aln)),  "")[[1L]]
    n_cols <- length(aln1_chars)

    n_vis1 <- nrow(df1e); n_vis2 <- nrow(df2e)
    M_count <- matrix(0L, nrow = n_vis1, ncol = n_vis2)  # aligned units
    M_match <- matrix(0L, nrow = n_vis1, ncol = n_vis2)  # identical units

    pos1 <- 0L; pos2 <- 0L
    for (col_i in seq_len(n_cols)) {
        ch1 <- aln1_chars[col_i]; ch2 <- aln2_chars[col_i]
        if (ch1 != "-") pos1 <- pos1 + 1L
        if (ch2 != "-") pos2 <- pos2 + 1L
        if (ch1 == "-" || ch2 == "-") next

        nt1 <- (pos1 - 1L) * stride + 1L   # nucleotide position in source sequence
        nt2 <- (pos2 - 1L) * stride + 1L

        cds_i1 <- if (nt1 <= length(pm1)) pm1[nt1] else n_src1
        cds_i2 <- if (nt2 <= length(pm2)) pm2[nt2] else n_src2

        vi1 <- if (cds_i1 >= 1L && cds_i1 <= length(vis_map1)) vis_map1[cds_i1] else NA_integer_
        vi2 <- if (cds_i2 >= 1L && cds_i2 <= length(vis_map2)) vis_map2[cds_i2] else NA_integer_

        if (!is.na(vi1) && !is.na(vi2) &&
                vi1 >= 1L && vi1 <= n_vis1 &&
                vi2 >= 1L && vi2 <= n_vis2) {
            M_count[vi1, vi2] <- M_count[vi1, vi2] + 1L
            if (ch1 == ch2) M_match[vi1, vi2] <- M_match[vi1, vi2] + 1L
        }
    }

    # ── classify correspondences ──────────────────────────────────────────────
    # min_codons threshold in "residues" (amino acids for protein, nucleotides for DNA).
    # For DNA modes, scale up ×3 to match biological unit (15 codons = 45 nucleotides).
    min_units <- as.integer(min_codons) * if (stride == 3L) 1L else 3L
    mc    <- min_units
    M_sig <- M_count >= mc

    events <- list()
    for (i in seq_len(n_vis1)) {
        j_hits <- which(M_sig[i, ])
        if (length(j_hits) == 0L) next
        for (jj in j_hits) {
            i_hits <- which(M_sig[, jj])
            etype <- if      (length(j_hits) == 1L && length(i_hits) == 1L) "1:1"
                     else if (length(j_hits) >  1L && length(i_hits) == 1L) "1:n"
                     else if (length(j_hits) == 1L && length(i_hits) >  1L) "n:1"
                     else                                                     "partial"
            nc      <- M_count[i, jj]
            nm_     <- M_match[i, jj]
            pid_blk <- if (nc > 0L) round(100 * nm_ / nc, 1) else NA_real_
            events[[length(events) + 1L]] <- data.frame(
                vis_exon_A   = i,
                vis_exon_B   = jj,
                n_codons     = nc,
                aligned_units = nc,
                feature_units_A = suppressWarnings(as.numeric(feature_units1[[i]] %||% NA_real_)),
                feature_units_B = suppressWarnings(as.numeric(feature_units2[[jj]] %||% NA_real_)),
                identity_pct = pid_blk,
                overall_pid  = overall_pid,
                event_type   = etype,
                stringsAsFactors = FALSE
            )
        }
    }

    if (length(events) == 0L) return(NULL)
    do.call(rbind, events)
}

# ─────────────────────────────────────────────────────────────────────────────
# Split ribbon geometry for 1:n and n:1 events
# ─────────────────────────────────────────────────────────────────────────────
# When one exon maps to multiple exons (fusion/fission), we proportionally
# divide the ribbon width on the multi-exon side based on aligned residue counts.
# This converts "one wide ribbon to each B exon" into "each ribbon occupies its
# proportional slice of A's width", making the split visually explicit.
#
# Parameters:
#   ribbon_pairs – data.frame from compute_protein_guided_correspondence()
#   df1e, df2e   – visual exon data frames (sorted by rel_start)
#
# Returns ribbon_pairs with added columns x1L_adj, x1R_adj, x2L_adj, x2R_adj
# (adjusted ribbon edge coordinates for bezier drawing).
add_split_geometry <- function(ribbon_pairs, df1e, df2e) {
    if (is.null(ribbon_pairs) || nrow(ribbon_pairs) == 0L) return(ribbon_pairs)

    ribbon_pairs$x1L_adj <- NA_real_
    ribbon_pairs$x1R_adj <- NA_real_
    ribbon_pairs$x2L_adj <- NA_real_
    ribbon_pairs$x2R_adj <- NA_real_

    # ── split A side (handles 1:n fusion: exon A → multiple exons B) ─────────
    for (ea in unique(ribbon_pairs$vis_exon_A)) {
        rows_a  <- which(ribbon_pairs$vis_exon_A == ea)
        if (ea < 1L || ea > nrow(df1e)) next
        ex      <- df1e[ea, , drop = FALSE]
        x1L_orig <- suppressWarnings(as.numeric(ex$rel_start[1]))
        x1R_orig <- suppressWarnings(as.numeric(ex$rel_end[1]))
        if (!is.finite(x1L_orig) || !is.finite(x1R_orig)) next
        width_a <- x1R_orig - x1L_orig

        feature_units_a <- suppressWarnings(as.numeric(ribbon_pairs$feature_units_A[rows_a][1] %||% NA_real_))
        aligned_units_a <- suppressWarnings(as.numeric(ribbon_pairs$aligned_units[rows_a] %||% ribbon_pairs$n_codons[rows_a]))
        aligned_units_a <- aligned_units_a[is.finite(aligned_units_a) & aligned_units_a > 0]
        occupied_width_a <- width_a
        left_edge_a <- x1L_orig
        if (is.finite(feature_units_a) && feature_units_a > 0 && length(aligned_units_a) > 0L) {
            aligned_total_a <- sum(aligned_units_a, na.rm = TRUE)
            share_a <- max(0, min(1, aligned_total_a / feature_units_a))
            occupied_width_a <- width_a * share_a
            left_edge_a <- x1L_orig
        }

        if (length(rows_a) == 1L) {
            ribbon_pairs$x1L_adj[rows_a] <- left_edge_a
            ribbon_pairs$x1R_adj[rows_a] <- left_edge_a + occupied_width_a
        } else {
            # Proportional split: rows sorted by vis_exon_B (left to right on B)
            rows_a_sorted <- rows_a[order(ribbon_pairs$vis_exon_B[rows_a])]
            nc_vals  <- pmax(as.numeric(ribbon_pairs$aligned_units[rows_a_sorted] %||% ribbon_pairs$n_codons[rows_a_sorted]), 1)
            nc_total <- sum(nc_vals)
            fracs    <- cumsum(nc_vals / nc_total)
            ribbon_pairs$x1L_adj[rows_a_sorted[1]] <- left_edge_a
            ribbon_pairs$x1R_adj[rows_a_sorted[1]] <- left_edge_a + occupied_width_a * fracs[1]
            for (r in seq(2L, length(rows_a_sorted))) {
                ribbon_pairs$x1L_adj[rows_a_sorted[r]] <- left_edge_a + occupied_width_a * fracs[r - 1L]
                ribbon_pairs$x1R_adj[rows_a_sorted[r]] <- left_edge_a + occupied_width_a * fracs[r]
            }
        }
    }

    # ── split B side (handles n:1 fission: multiple exons A → exon B) ────────
    for (eb in unique(ribbon_pairs$vis_exon_B)) {
        rows_b  <- which(ribbon_pairs$vis_exon_B == eb)
        if (eb < 1L || eb > nrow(df2e)) next
        ex      <- df2e[eb, , drop = FALSE]
        x2L_orig <- suppressWarnings(as.numeric(ex$rel_start[1]))
        x2R_orig <- suppressWarnings(as.numeric(ex$rel_end[1]))
        if (!is.finite(x2L_orig) || !is.finite(x2R_orig)) next
        width_b <- x2R_orig - x2L_orig

        feature_units_b <- suppressWarnings(as.numeric(ribbon_pairs$feature_units_B[rows_b][1] %||% NA_real_))
        aligned_units_b <- suppressWarnings(as.numeric(ribbon_pairs$aligned_units[rows_b] %||% ribbon_pairs$n_codons[rows_b]))
        aligned_units_b <- aligned_units_b[is.finite(aligned_units_b) & aligned_units_b > 0]
        occupied_width_b <- width_b
        left_edge_b <- x2L_orig
        if (is.finite(feature_units_b) && feature_units_b > 0 && length(aligned_units_b) > 0L) {
            aligned_total_b <- sum(aligned_units_b, na.rm = TRUE)
            share_b <- max(0, min(1, aligned_total_b / feature_units_b))
            occupied_width_b <- width_b * share_b
            left_edge_b <- x2L_orig
        }

        if (length(rows_b) == 1L) {
            ribbon_pairs$x2L_adj[rows_b] <- left_edge_b
            ribbon_pairs$x2R_adj[rows_b] <- left_edge_b + occupied_width_b
        } else {
            # Proportional split: rows sorted by vis_exon_A (left to right on A)
            rows_b_sorted <- rows_b[order(ribbon_pairs$vis_exon_A[rows_b])]
            nc_vals  <- pmax(as.numeric(ribbon_pairs$aligned_units[rows_b_sorted] %||% ribbon_pairs$n_codons[rows_b_sorted]), 1)
            nc_total <- sum(nc_vals)
            fracs    <- cumsum(nc_vals / nc_total)
            ribbon_pairs$x2L_adj[rows_b_sorted[1]] <- left_edge_b
            ribbon_pairs$x2R_adj[rows_b_sorted[1]] <- left_edge_b + occupied_width_b * fracs[1]
            for (r in seq(2L, length(rows_b_sorted))) {
                ribbon_pairs$x2L_adj[rows_b_sorted[r]] <- left_edge_b + occupied_width_b * fracs[r - 1L]
                ribbon_pairs$x2R_adj[rows_b_sorted[r]] <- left_edge_b + occupied_width_b * fracs[r]
            }
        }
    }

    ribbon_pairs
}

compact_ribbon_span <- function(x_left, x_right, event_type = "1:1", identity_pct = NA_real_, guided = TRUE) {
    xl <- suppressWarnings(as.numeric(x_left))
    xr <- suppressWarnings(as.numeric(x_right))
    if (!is.finite(xl) || !is.finite(xr)) {
        return(c(NA_real_, NA_real_))
    }
    if (xr < xl) {
        tmp <- xl
        xl <- xr
        xr <- tmp
    }
    width <- xr - xl
    if (!is.finite(width) || width <= 0) {
        return(c(xl, xr))
    }

    et <- trimws(as.character(event_type %||% "1:1"))
    frac <- switch(et,
        "1:n" = 0.66,
        "n:1" = 0.66,
        "partial" = 0.44,
        "fallback" = 0.34,
        0.54
    )

    pid <- suppressWarnings(as.numeric(identity_pct))
    if (isTRUE(guided) && is.finite(pid)) {
        frac <- frac + ((pid - 50) / 100) * 0.18
    }
    frac <- max(0.22, min(0.82, frac))
    new_width <- width * frac
    pad <- (width - new_width) / 2
    c(xl + pad, xr - pad)
}

# Build a shared exon-alignment layout across ordered transcript tracks.
# Each exon receives aligned_start/aligned_end coordinates in a common space
# driven by pairwise correspondence between adjacent tracks.
build_aligned_exon_layout <- function(exon_tracks, corr_pairs,
                                      gap_fraction = 0.08,
                                      min_width = 1) {
    if (is.null(exon_tracks) || length(exon_tracks) == 0L) {
        return(list())
    }

    exon_lengths <- function(df) {
        if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
            return(numeric(0))
        }
        len <- suppressWarnings(as.numeric(df$largo %||% NA_real_))
        if (length(len) != nrow(df)) len <- rep(NA_real_, nrow(df))
        bad <- !is.finite(len) | len <= 0
        if (any(bad)) {
            xs <- suppressWarnings(as.numeric(df$xstart))
            xe <- suppressWarnings(as.numeric(df$xend))
            len[bad] <- abs(xe[bad] - xs[bad]) + 1
        }
        len[!is.finite(len) | len <= 0] <- 1
        len
    }

    all_lengths <- unlist(lapply(exon_tracks, exon_lengths), use.names = FALSE)
    valid_lengths <- all_lengths[is.finite(all_lengths) & all_lengths > 0]
    med_len <- suppressWarnings(stats::median(valid_lengths, na.rm = TRUE))
    if (!is.finite(med_len) || med_len <= 0) med_len <- 100
    gap <- med_len * as.numeric(gap_fraction)
    if (!is.finite(gap) || gap < 1) gap <- 1

    scaled_widths <- function(df) {
        len <- exon_lengths(df)
        widths <- len
        widths[!is.finite(widths)] <- min_width
        pmax(min_width, widths)
    }

    layouts <- vector("list", length(exon_tracks))
    first_df <- exon_tracks[[1L]]
    if (is.null(first_df) || !is.data.frame(first_df) || nrow(first_df) == 0L) {
        return(layouts)
    }
    first_w <- scaled_widths(first_df)
    first_start <- c(0, head(cumsum(first_w + gap), -1L))
    first_end <- first_start + first_w
    first_layout <- first_df
    first_layout$aligned_start <- first_start
    first_layout$aligned_end <- first_end
    first_layout$aligned_width <- first_w
    first_layout$aligned_mid <- (first_start + first_end) / 2
    layouts[[1L]] <- first_layout

    if (length(exon_tracks) == 1L) {
        return(layouts)
    }

    for (track_idx in 2:length(exon_tracks)) {
        prev_layout <- layouts[[track_idx - 1L]]
        cur_df <- exon_tracks[[track_idx]]
        if (is.null(cur_df) || !is.data.frame(cur_df) || nrow(cur_df) == 0L) {
            layouts[[track_idx]] <- cur_df
            next
        }
        cur_w <- scaled_widths(cur_df)
        n_cur <- nrow(cur_df)

        corr <- corr_pairs[[track_idx - 1L]]
        if (is.null(corr) || !is.data.frame(corr) || nrow(corr) == 0L) {
            fallback_start <- c(0, head(cumsum(cur_w + gap), -1L))
            fallback_end <- fallback_start + cur_w
            cur_layout <- cur_df
            cur_layout$aligned_start <- fallback_start
            cur_layout$aligned_end <- fallback_end
            cur_layout$aligned_width <- cur_w
            cur_layout$aligned_mid <- (fallback_start + fallback_end) / 2
            layouts[[track_idx]] <- cur_layout
            next
        }

        corr <- corr[
            is.finite(as.numeric(corr$vis_exon_A)) &
                is.finite(as.numeric(corr$vis_exon_B)),
            , drop = FALSE
        ]
        if (nrow(corr) == 0L) {
            fallback_start <- c(0, head(cumsum(cur_w + gap), -1L))
            fallback_end <- fallback_start + cur_w
            cur_layout <- cur_df
            cur_layout$aligned_start <- fallback_start
            cur_layout$aligned_end <- fallback_end
            cur_layout$aligned_width <- cur_w
            cur_layout$aligned_mid <- (fallback_start + fallback_end) / 2
            layouts[[track_idx]] <- cur_layout
            next
        }

        corr$vis_exon_A <- as.integer(corr$vis_exon_A)
        corr$vis_exon_B <- as.integer(corr$vis_exon_B)
        corr <- corr[
            corr$vis_exon_A >= 1L & corr$vis_exon_A <= nrow(prev_layout) &
                corr$vis_exon_B >= 1L & corr$vis_exon_B <= n_cur,
            , drop = FALSE
        ]
        if (nrow(corr) == 0L) {
            fallback_start <- c(0, head(cumsum(cur_w + gap), -1L))
            fallback_end <- fallback_start + cur_w
            cur_layout <- cur_df
            cur_layout$aligned_start <- fallback_start
            cur_layout$aligned_end <- fallback_end
            cur_layout$aligned_width <- cur_w
            cur_layout$aligned_mid <- (fallback_start + fallback_end) / 2
            layouts[[track_idx]] <- cur_layout
            next
        }

        desired_mid <- rep(NA_real_, n_cur)
        desired_start <- rep(NA_real_, n_cur)
        desired_width <- as.numeric(cur_w)
        anchor_start <- rep(NA_real_, n_cur)
        anchor_end <- rep(NA_real_, n_cur)

        for (cur_idx in seq_len(n_cur)) {
            rows_cur <- which(corr$vis_exon_B == cur_idx)
            if (length(rows_cur) == 0L) next
            prev_idx <- sort(unique(corr$vis_exon_A[rows_cur]))
            target_start <- suppressWarnings(min(prev_layout$aligned_start[prev_idx], na.rm = TRUE))
            target_end <- suppressWarnings(max(prev_layout$aligned_end[prev_idx], na.rm = TRUE))
            if (!is.finite(target_start) || !is.finite(target_end) || target_end <= target_start) next
            anchor_start[cur_idx] <- target_start
            anchor_end[cur_idx] <- target_end
            desired_mid[cur_idx] <- (target_start + target_end) / 2
        }

        shared_key <- ifelse(
            is.finite(anchor_start) & is.finite(anchor_end),
            paste(round(anchor_start, 6), round(anchor_end, 6), sep = "|"),
            paste0("no_anchor_", seq_len(n_cur))
        )
        shared_groups <- split(seq_len(n_cur), shared_key)
        for (grp in shared_groups) {
            if (length(grp) <= 1L) next
            if (!all(is.finite(anchor_start[grp])) || !all(is.finite(anchor_end[grp]))) next
            grp <- grp[order(grp)]
            span_start <- anchor_start[grp[1L]]
            span_end <- anchor_end[grp[1L]]
            span_mid <- (span_start + span_end) / 2
            total_width <- sum(desired_width[grp]) + gap * (length(grp) - 1L)
            run_start <- span_mid - total_width / 2
            for (ii in seq_along(grp)) {
                idx_cur <- grp[ii]
                desired_start[idx_cur] <- run_start
                desired_mid[idx_cur] <- run_start + desired_width[idx_cur] / 2
                run_start <- run_start + desired_width[idx_cur] + gap
            }
        }

        anchored_idx <- which(is.finite(desired_mid))
        if (length(anchored_idx) == 0L) {
            run_start <- 0
            for (cur_idx in seq_len(n_cur)) {
                desired_start[cur_idx] <- run_start
                desired_mid[cur_idx] <- run_start + desired_width[cur_idx] / 2
                run_start <- run_start + desired_width[cur_idx] + gap
            }
        } else {
            first_anchor <- anchored_idx[1L]
            if (first_anchor > 1L) {
                run_mid <- desired_mid[first_anchor]
                for (cur_idx in seq(from = first_anchor - 1L, to = 1L, by = -1L)) {
                    run_mid <- run_mid - (desired_width[cur_idx + 1L] / 2) - gap - (desired_width[cur_idx] / 2)
                    desired_mid[cur_idx] <- run_mid
                }
            }
            if (length(anchored_idx) > 1L) {
                for (ii in seq_len(length(anchored_idx) - 1L)) {
                    left_idx <- anchored_idx[ii]
                    right_idx <- anchored_idx[ii + 1L]
                    if (right_idx - left_idx <= 1L) next
                    mids <- seq(
                        from = desired_mid[left_idx],
                        to = desired_mid[right_idx],
                        length.out = right_idx - left_idx + 1L
                    )
                    for (cur_idx in seq.int(left_idx + 1L, right_idx - 1L)) {
                        desired_mid[cur_idx] <- mids[cur_idx - left_idx + 1L]
                    }
                }
            }
            last_anchor <- anchored_idx[length(anchored_idx)]
            if (last_anchor < n_cur) {
                run_mid <- desired_mid[last_anchor]
                for (cur_idx in seq.int(last_anchor + 1L, n_cur)) {
                    run_mid <- run_mid + (desired_width[cur_idx - 1L] / 2) + gap + (desired_width[cur_idx] / 2)
                    desired_mid[cur_idx] <- run_mid
                }
            }
        }

        desired_start[!is.finite(desired_start)] <- desired_mid[!is.finite(desired_start)] - desired_width[!is.finite(desired_start)] / 2
        if (!is.finite(desired_start[1L])) desired_start[1L] <- 0

        aligned_start <- desired_start
        aligned_end <- aligned_start + desired_width
        for (cur_idx in seq_len(n_cur)) {
            if (cur_idx == 1L) next
            min_start <- aligned_end[cur_idx - 1L] + gap
            if (!is.finite(aligned_start[cur_idx]) || aligned_start[cur_idx] < min_start) {
                aligned_start[cur_idx] <- min_start
                aligned_end[cur_idx] <- aligned_start[cur_idx] + desired_width[cur_idx]
            }
        }
        x_shift <- suppressWarnings(min(aligned_start, na.rm = TRUE))
        if (is.finite(x_shift) && x_shift < 0) {
            aligned_start <- aligned_start - x_shift
            aligned_end <- aligned_end - x_shift
        }

        cur_layout <- cur_df
        cur_layout$aligned_start <- aligned_start
        cur_layout$aligned_end <- aligned_end
        cur_layout$aligned_width <- desired_width
        cur_layout$aligned_mid <- (aligned_start + aligned_end) / 2
        layouts[[track_idx]] <- cur_layout
    }

    layouts
}

# Project arbitrary transcript features into aligned exon space.
# Features overlapping aligned exons are interpolated proportionally within
# the exon's aligned interval while preserving the exon order layout.
project_features_to_aligned_exon_layout <- function(track_df, exon_layout_df) {
    if (is.null(track_df) || !is.data.frame(track_df) || nrow(track_df) == 0L) {
        return(track_df)
    }
    out <- track_df
    if (is.null(exon_layout_df) || !is.data.frame(exon_layout_df) || nrow(exon_layout_df) == 0L) {
        out$disp_start <- suppressWarnings(as.numeric(out$rel_start))
        out$disp_end <- suppressWarnings(as.numeric(out$rel_end))
        return(out)
    }

    ex_xs <- suppressWarnings(as.numeric(exon_layout_df$xstart))
    ex_xe <- suppressWarnings(as.numeric(exon_layout_df$xend))
    ex_ds <- suppressWarnings(as.numeric(exon_layout_df$aligned_start))
    ex_de <- suppressWarnings(as.numeric(exon_layout_df$aligned_end))

    map_feature <- function(xs, xe) {
        x1 <- suppressWarnings(as.numeric(xs))
        x2 <- suppressWarnings(as.numeric(xe))
        if (!is.finite(x1) || !is.finite(x2)) {
            return(c(NA_real_, NA_real_))
        }
        f_start <- min(x1, x2)
        f_end <- max(x1, x2)
        ov_idx <- which(is.finite(ex_xs) & is.finite(ex_xe) & ex_xs <= f_end & ex_xe >= f_start)
        if (length(ov_idx) == 0L) {
            return(c(NA_real_, NA_real_))
        }

        mapped_start <- numeric(0)
        mapped_end <- numeric(0)
        for (ov in ov_idx) {
            ov_start <- max(f_start, ex_xs[ov])
            ov_end <- min(f_end, ex_xe[ov])
            exon_span <- ex_xe[ov] - ex_xs[ov]
            disp_span <- ex_de[ov] - ex_ds[ov]
            if (!is.finite(exon_span) || exon_span <= 0 || !is.finite(disp_span)) {
                mapped_start <- c(mapped_start, ex_ds[ov])
                mapped_end <- c(mapped_end, ex_de[ov])
            } else {
                frac_start <- (ov_start - ex_xs[ov]) / exon_span
                frac_end <- (ov_end - ex_xs[ov]) / exon_span
                mapped_start <- c(mapped_start, ex_ds[ov] + frac_start * disp_span)
                mapped_end <- c(mapped_end, ex_ds[ov] + frac_end * disp_span)
            }
        }
        c(min(mapped_start, na.rm = TRUE), max(mapped_end, na.rm = TRUE))
    }

    mapped <- t(vapply(seq_len(nrow(out)), function(i) map_feature(out$xstart[i], out$xend[i]), numeric(2)))
    out$disp_start <- mapped[, 1]
    out$disp_end <- mapped[, 2]

    fallback <- !is.finite(out$disp_start) | !is.finite(out$disp_end)
    if (any(fallback)) {
        out$disp_start[fallback] <- suppressWarnings(as.numeric(out$rel_start[fallback]))
        out$disp_end[fallback] <- suppressWarnings(as.numeric(out$rel_end[fallback]))
    }
    out$disp_start <- pmin(out$disp_start, out$disp_end)
    out$disp_end <- pmax(out$disp_start, out$disp_end)
    out
}

# Build a pairwise-aligned display without changing exon widths.
# Each track keeps its native rel_start/rel_end span; only a horizontal offset
# is estimated from the exon correspondences against the previous track.
build_pairwise_aligned_offsets <- function(exon_tracks, corr_pairs) {
    n_tracks <- length(exon_tracks %||% list())
    if (n_tracks == 0L) {
        return(list(offsets = numeric(0), layouts = list()))
    }

    offsets <- rep(0, n_tracks)
    layouts <- vector("list", n_tracks)

    make_layout <- function(df, offset = 0) {
        if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
            return(df)
        }
        out <- df
        rs <- suppressWarnings(as.numeric(out$rel_start))
        re <- suppressWarnings(as.numeric(out$rel_end))
        out$aligned_start <- rs + offset
        out$aligned_end <- re + offset
        out$aligned_width <- abs(out$aligned_end - out$aligned_start)
        out$aligned_mid <- (out$aligned_start + out$aligned_end) / 2
        out
    }

    layouts[[1L]] <- make_layout(exon_tracks[[1L]], 0)

    if (n_tracks == 1L) {
        return(list(offsets = offsets, layouts = layouts))
    }

    for (track_idx in 2:n_tracks) {
        prev_df <- exon_tracks[[track_idx - 1L]]
        cur_df <- exon_tracks[[track_idx]]
        corr <- corr_pairs[[track_idx - 1L]]

        shift_val <- offsets[track_idx - 1L]
        if (!is.null(prev_df) && is.data.frame(prev_df) && nrow(prev_df) > 0L &&
            !is.null(cur_df) && is.data.frame(cur_df) && nrow(cur_df) > 0L &&
            !is.null(corr) && is.data.frame(corr) && nrow(corr) > 0L) {

            corr$vis_exon_A <- suppressWarnings(as.integer(corr$vis_exon_A))
            corr$vis_exon_B <- suppressWarnings(as.integer(corr$vis_exon_B))
            corr <- corr[
                is.finite(corr$vis_exon_A) & is.finite(corr$vis_exon_B) &
                    corr$vis_exon_A >= 1L & corr$vis_exon_A <= nrow(prev_df) &
                    corr$vis_exon_B >= 1L & corr$vis_exon_B <= nrow(cur_df),
                , drop = FALSE
            ]

            if (nrow(corr) > 0L) {
                prev_mid <- (suppressWarnings(as.numeric(prev_df$rel_start)) +
                    suppressWarnings(as.numeric(prev_df$rel_end))) / 2 + offsets[track_idx - 1L]
                cur_mid <- (suppressWarnings(as.numeric(cur_df$rel_start)) +
                    suppressWarnings(as.numeric(cur_df$rel_end))) / 2
                deltas <- prev_mid[corr$vis_exon_A] - cur_mid[corr$vis_exon_B]
                deltas <- deltas[is.finite(deltas)]
                if (length(deltas) > 0L) {
                    shift_val <- stats::median(deltas, na.rm = TRUE)
                }
            }
        }

        offsets[track_idx] <- shift_val
        layouts[[track_idx]] <- make_layout(cur_df, shift_val)
    }

    list(offsets = offsets, layouts = layouts)
}

normalize_aligned_track_for_mode <- function(track_df, mode = "protein") {
    if (is.null(track_df) || !is.data.frame(track_df) || nrow(track_df) == 0L) {
        return(list(track_df = track_df, anchor_df = NULL, geometry_mode = "exon"))
    }

    mode_txt <- tolower(trimws(as.character(mode %||% "protein")))
    if (!mode_txt %in% c("protein", "cds", "exon")) mode_txt <- "protein"

    out <- track_df
    get_num_col <- function(df, primary, fallback = NULL) {
        if (!is.null(primary) && primary %in% names(df)) {
            return(suppressWarnings(as.numeric(df[[primary]])))
        }
        if (!is.null(fallback) && fallback %in% names(df)) {
            return(suppressWarnings(as.numeric(df[[fallback]])))
        }
        rep(NA_real_, nrow(df))
    }
    plot_group <- if ("plot_group" %in% names(out)) {
        tolower(trimws(as.character(out$plot_group)))
    } else if ("feature_type" %in% names(out)) {
        feature_type_norm <- tolower(trimws(as.character(out$feature_type)))
        ifelse(feature_type_norm == "gene", "gene",
            ifelse(feature_type_norm == "exon", "exon",
                ifelse(feature_type_norm == "cds", "cds",
                    ifelse(grepl("utr", feature_type_norm), "utr",
                        ifelse(feature_type_norm %in% c("start_codon", "stop_codon"), "codon", "other")
                    )
                )
            )
        )
    } else {
        rep("other", nrow(out))
    }
    out$plot_group <- plot_group
    wants_cds <- mode_txt %in% c("protein", "cds")
    has_cds <- any(plot_group == "cds", na.rm = TRUE)
    geometry_mode <- if (isTRUE(wants_cds) && isTRUE(has_cds)) "cds" else "exon"

    start_col <- if (identical(geometry_mode, "cds") && "rel_start_cds" %in% names(out)) "rel_start_cds" else
        if ("rel_start_exon" %in% names(out)) "rel_start_exon" else "rel_start"
    end_col <- if (identical(geometry_mode, "cds") && "rel_end_cds" %in% names(out)) "rel_end_cds" else
        if ("rel_end_exon" %in% names(out)) "rel_end_exon" else "rel_end"

    out$rel_start <- get_num_col(out, start_col, "rel_start")
    out$rel_end <- get_num_col(out, end_col, "rel_end")

    fallback <- !is.finite(out$rel_start) | !is.finite(out$rel_end)
    if (any(fallback)) {
        base_start <- get_num_col(out, "rel_start_exon", "rel_start")
        base_end <- get_num_col(out, "rel_end_exon", "rel_end")
        out$rel_start[fallback] <- base_start[fallback]
        out$rel_end[fallback] <- base_end[fallback]
    }
    second_fallback <- !is.finite(out$rel_start) | !is.finite(out$rel_end)
    if (any(second_fallback)) {
        raw_start <- get_num_col(out, "xstart", NULL)
        raw_end <- get_num_col(out, "xend", NULL)
        out$rel_start[second_fallback] <- raw_start[second_fallback]
        out$rel_end[second_fallback] <- raw_end[second_fallback]
    }
    out$rel_start <- pmin(out$rel_start, out$rel_end)
    out$rel_end <- pmax(out$rel_start, out$rel_end)

    anchor_group <- if (identical(geometry_mode, "cds")) "cds" else "exon"
    anchor_df <- out[plot_group == anchor_group, , drop = FALSE]
    if (nrow(anchor_df) == 0L && identical(anchor_group, "cds")) {
        geometry_mode <- "exon"
        out$rel_start <- get_num_col(out, "rel_start_exon", "rel_start")
        out$rel_end <- get_num_col(out, "rel_end_exon", "rel_end")
        anchor_df <- out[plot_group == "exon", , drop = FALSE]
    }
    if (nrow(anchor_df) == 0L) {
        anchor_df <- out[plot_group %in% c("exon", "cds"), , drop = FALSE]
    }
    if (nrow(anchor_df) == 0L) {
        anchor_df <- out[is.finite(out$rel_start) & is.finite(out$rel_end), , drop = FALSE]
    }
    if (nrow(anchor_df) > 0L) {
        anchor_df <- anchor_df[order(anchor_df$rel_start), , drop = FALSE]
    } else {
        anchor_df <- NULL
    }

    out$aligned_geometry_mode <- rep(geometry_mode, nrow(out))
    out$aligned_anchor_label <- rep(if (identical(geometry_mode, "cds")) "CDS block" else "exon", nrow(out))

    list(
        track_df = out,
        anchor_df = anchor_df,
        geometry_mode = geometry_mode
    )
}

project_features_with_track_offset <- function(track_df, x_offset = 0, rel_start_col = "rel_start", rel_end_col = "rel_end") {
    if (is.null(track_df) || !is.data.frame(track_df) || nrow(track_df) == 0L) {
        return(track_df)
    }
    out <- track_df
    rs <- suppressWarnings(as.numeric(out[[rel_start_col]]))
    re <- suppressWarnings(as.numeric(out[[rel_end_col]]))
    out$disp_start <- rs + as.numeric(x_offset %||% 0)
    out$disp_end <- re + as.numeric(x_offset %||% 0)
    out$track_offset <- rep(as.numeric(x_offset %||% 0), nrow(out))
    out
}
