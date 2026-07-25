.string_cache_schema_version <- 1L
.string_resolution_memory_cache <- new.env(parent = emptyenv())
.string_network_memory_cache <- new.env(parent = emptyenv())

string_cache_root <- function(base_dir = ".") {
    root <- get_cgv_cache_root(base_dir = base_dir)
    path <- file.path(root, "string")
    if (!dir.exists(path)) {
        dir.create(path, recursive = TRUE, showWarnings = FALSE)
    }
    normalizePath(path, winslash = "/", mustWork = FALSE)
}

string_cache_hash <- function(...) {
    parts <- list(...)
    if (requireNamespace("digest", quietly = TRUE)) {
        return(digest::digest(parts, algo = "xxhash64"))
    }
    sanitize_cache_key(paste(unlist(parts, recursive = TRUE, use.names = FALSE), collapse = "\001"))
}

normalize_string_candidate <- function(x) {
    trimws(as.character(x %||% ""))
}

string_resolution_cache_key <- function(taxid, candidate) {
    string_cache_hash(
        "string-resolution",
        .string_cache_schema_version,
        as.integer(taxid),
        normalize_string_candidate(candidate)
    )
}

string_network_cache_key <- function(taxid, string_id, required_score = 600L, add_nodes = 8L) {
    string_cache_hash(
        "string-network",
        .string_cache_schema_version,
        as.integer(taxid),
        trimws(as.character(string_id %||% "")),
        as.integer(required_score),
        as.integer(add_nodes)
    )
}

string_cache_file <- function(kind, key, base_dir = ".") {
    dir_path <- file.path(string_cache_root(base_dir), as.character(kind %||% "misc"))
    if (!dir.exists(dir_path)) {
        dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    }
    file.path(dir_path, paste0(sanitize_cache_key(key), ".rds"))
}

string_cache_read <- function(kind, key, ttl_sec, memory_env, base_dir = ".") {
    cached <- cache_env_get(memory_env, key, default = NULL)
    if (is.list(cached) && is.finite(as.numeric(cached$stored_at %||% NA_real_))) {
        age <- as.numeric(Sys.time()) - as.numeric(cached$stored_at)
        if (is.finite(age) && age <= as.numeric(ttl_sec)) {
            return(cached$value)
        }
        cache_env_drop(memory_env, key)
    }

    path <- string_cache_file(kind, key, base_dir = base_dir)
    if (!file.exists(path)) {
        return(NULL)
    }
    obj <- tryCatch(readRDS(path), error = function(e) NULL)
    valid <- is.list(obj) &&
        identical(as.integer(obj$schema_version %||% NA_integer_), .string_cache_schema_version) &&
        identical(as.character(obj$key %||% ""), as.character(key)) &&
        is.finite(as.numeric(obj$stored_at %||% NA_real_))
    if (!isTRUE(valid)) {
        unlink(path, force = TRUE)
        return(NULL)
    }
    age <- as.numeric(Sys.time()) - as.numeric(obj$stored_at)
    if (!is.finite(age) || age > as.numeric(ttl_sec)) {
        unlink(path, force = TRUE)
        return(NULL)
    }
    cache_env_set(memory_env, key, obj, max_size = 128L)
    obj$value
}

string_cache_write <- function(kind, key, value, memory_env, base_dir = ".") {
    obj <- list(
        schema_version = .string_cache_schema_version,
        key = as.character(key),
        stored_at = as.numeric(Sys.time()),
        value = value
    )
    cache_env_set(memory_env, key, obj, max_size = 128L)
    atomic_save_rds(obj, string_cache_file(kind, key, base_dir = base_dir), compress = "gzip")
    invisible(value)
}

string_resolution_cache_get <- function(taxid, candidate, base_dir = ".") {
    key <- string_resolution_cache_key(taxid, candidate)
    value <- string_cache_read(
        "resolved",
        key,
        ttl_sec = 7 * 24 * 60 * 60,
        memory_env = .string_resolution_memory_cache,
        base_dir = base_dir
    )
    if (is.list(value) && isFALSE(value$found)) {
        stored_at <- suppressWarnings(as.numeric(value$resolved_at %||% NA_real_))
        if (!is.finite(stored_at) || (as.numeric(Sys.time()) - stored_at) > 24 * 60 * 60) {
            return(NULL)
        }
    }
    value
}

string_resolution_cache_set <- function(taxid, candidate, value, base_dir = ".") {
    payload <- value
    if (!is.list(payload)) {
        payload <- list(found = FALSE)
    }
    payload$resolved_at <- as.numeric(Sys.time())
    key <- string_resolution_cache_key(taxid, candidate)
    string_cache_write("resolved", key, payload, .string_resolution_memory_cache, base_dir = base_dir)
}

string_network_cache_get <- function(taxid, string_id, required_score = 600L, add_nodes = 8L, base_dir = ".") {
    key <- string_network_cache_key(taxid, string_id, required_score, add_nodes)
    string_cache_read(
        "network",
        key,
        ttl_sec = 7 * 24 * 60 * 60,
        memory_env = .string_network_memory_cache,
        base_dir = base_dir
    )
}

string_network_cache_set <- function(taxid, string_id, required_score, add_nodes, value, base_dir = ".") {
    key <- string_network_cache_key(taxid, string_id, required_score, add_nodes)
    string_cache_write("network", key, value, .string_network_memory_cache, base_dir = base_dir)
}

prune_string_disk_cache <- function(base_dir = ".", max_files_per_kind = 128L) {
    root <- string_cache_root(base_dir)
    for (kind in c("resolved", "network")) {
        dir_path <- file.path(root, kind)
        if (!dir.exists(dir_path)) next
        files <- list.files(dir_path, pattern = "\\.rds$", full.names = TRUE)
        if (length(files) <= max_files_per_kind) next
        info <- file.info(files)
        ord <- order(as.numeric(info$mtime), na.last = TRUE)
        unlink(files[ord[seq_len(length(files) - max_files_per_kind)]], force = TRUE)
    }
    invisible(NULL)
}
