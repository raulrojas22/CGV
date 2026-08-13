#!/usr/bin/env Rscript

root <- normalizePath(file.path(dirname(sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))])), ".."), mustWork = TRUE)
source(file.path(root, "R", "utils.R"), local = .GlobalEnv)

stopifnot(identical(get_coordinated_memory_cache_total_budget_mb(runtime = "web", raw_value = ""), 384))
stopifnot(identical(get_coordinated_memory_cache_total_budget_mb(runtime = "", raw_value = "bad"), 384))
stopifnot(identical(get_coordinated_memory_cache_budget_mb(
    runtime = "web", raw_value = "", future_mode = "multisession", raw_process_count = "3"
), 128))
stopifnot(identical(get_coordinated_memory_cache_budget_mb(
    runtime = "web", raw_value = "", future_mode = "sequential", raw_process_count = "3"
), 384))
stopifnot(identical(get_coordinated_memory_cache_budget_mb(
    runtime = "web", raw_value = "512", future_mode = "multisession", raw_process_count = "4"
), 128))
stopifnot(isTRUE(all.equal(get_coordinated_memory_cache_budget_mb(
    runtime = "web", raw_value = "1", future_mode = "multisession", raw_process_count = "3"
), 32 / 3)))
stopifnot(identical(get_coordinated_memory_cache_budget_mb(runtime = "desktop", raw_value = ""), 1024))
stopifnot(identical(get_coordinated_memory_cache_budget_mb(runtime = "desktop", raw_value = "bad"), 1024))
stopifnot(identical(get_coordinated_memory_cache_budget_mb(runtime = "desktop", raw_value = "999999"), 8192))
stopifnot(identical(get_coordinated_memory_cache_process_count(
    runtime = "web", future_mode = "multisession", raw_process_count = "", raw_workers = "2"
), 3L))
stopifnot(identical(get_coordinated_memory_cache_process_count(
    runtime = "web", future_mode = "sequential", raw_process_count = "9", raw_workers = "8"
), 1L))
stopifnot(identical(get_coordinated_memory_cache_process_count(
    runtime = "desktop", future_mode = "multisession", raw_process_count = "3", raw_workers = "2"
), 1L))

old_runtime <- Sys.getenv("CGV_RUNTIME", unset = NA_character_)
old_budget <- Sys.getenv("APP_MEMORY_CACHE_BUDGET_MB", unset = NA_character_)
old_future_mode <- Sys.getenv("APP_FUTURE_MODE", unset = NA_character_)
old_process_count <- Sys.getenv("APP_MEMORY_CACHE_PROCESS_COUNT", unset = NA_character_)
old_future_workers <- Sys.getenv("APP_FUTURE_WORKERS", unset = NA_character_)
on.exit({
    if (is.na(old_runtime)) Sys.unsetenv("CGV_RUNTIME") else Sys.setenv(CGV_RUNTIME = old_runtime)
    if (is.na(old_budget)) Sys.unsetenv("APP_MEMORY_CACHE_BUDGET_MB") else Sys.setenv(APP_MEMORY_CACHE_BUDGET_MB = old_budget)
    if (is.na(old_future_mode)) Sys.unsetenv("APP_FUTURE_MODE") else Sys.setenv(APP_FUTURE_MODE = old_future_mode)
    if (is.na(old_process_count)) Sys.unsetenv("APP_MEMORY_CACHE_PROCESS_COUNT") else Sys.setenv(APP_MEMORY_CACHE_PROCESS_COUNT = old_process_count)
    if (is.na(old_future_workers)) Sys.unsetenv("APP_FUTURE_WORKERS") else Sys.setenv(APP_FUTURE_WORKERS = old_future_workers)
}, add = TRUE)
Sys.setenv(
    CGV_RUNTIME = "desktop",
    APP_MEMORY_CACHE_BUDGET_MB = "640",
    APP_FUTURE_MODE = "multisession",
    APP_MEMORY_CACHE_PROCESS_COUNT = "3"
)
stopifnot(identical(get_coordinated_memory_cache_budget_mb(), 640))

registry <- coordinated_memory_cache_envs()
expected_registry <- c(
    "gff", "gene_index", "gene_light", "genes_table", "genes_chr",
    "seq_extract", "spliced_seq", "fasta_fallback", "transcript_composition",
    "orthologous_local"
)
stopifnot(identical(names(registry), expected_registry))
stopifnot(length(registry) == 10L)
stopifnot(all(vapply(registry, is.environment, logical(1))))
stopifnot(is_coordinated_memory_cache_env(.seq_extract_cache))
stopifnot(is_coordinated_memory_cache_env(.spliced_seq_cache))
stopifnot(!is_coordinated_memory_cache_env(.fafile_handle_cache))
stopifnot(identical(annotation_memory_cache_limits$seq_extract_max_entries, 1000L))
stopifnot(identical(annotation_memory_cache_limits$spliced_seq_max_entries, 1200L))

clear_env <- function(env) {
    keys <- ls(envir = env, all.names = TRUE)
    if (length(keys) > 0L) rm(list = keys, envir = env)
    invisible(NULL)
}
assert_tracker_matches_stats <- function() {
    tracked <- coordinated_memory_cache_tracked_bytes()
    measured <- coordinated_memory_cache_stats()$total_bytes
    stopifnot(isTRUE(all.equal(tracked, measured, tolerance = 0)))
    invisible(measured)
}
invisible(lapply(registry, clear_env))
invisible(coordinated_memory_cache_tracked_bytes(recalculate = TRUE))

# Missing metadata is safe for absent keys and direct/legacy assignments. A
# replacement reconciles the tracker instead of under-counting the old value.
stopifnot(isTRUE(cache_env_drop(.gff_cache, "absent")))
cache_env_set(.gff_gene_index_cache, "tracked-peer", raw(4096L), max_bytes = 1024^2)
assign("legacy", raw(1024L), envir = .gff_cache)
stopifnot(length(cache_env_get(.gff_cache, "legacy")) == 1024L)
assert_tracker_matches_stats()
cache_env_set(.gff_cache, "legacy", raw(2048L), max_bytes = 1024^2)
stopifnot(length(cache_env_get(.gff_cache, "legacy")) == 2048L)
assert_tracker_matches_stats()
cache_env_drop(.gff_cache, "legacy")
assert_tracker_matches_stats()
stopifnot(exists("tracked-peer", envir = .gff_gene_index_cache, inherits = FALSE))
cache_env_drop(.gff_gene_index_cache, "tracked-peer")
assert_tracker_matches_stats()

# A web main process configured with two future workers enforces one third of
# the total cgroup allowance, not the full value in every process.
Sys.setenv(
    CGV_RUNTIME = "web",
    APP_FUTURE_MODE = "multisession",
    APP_MEMORY_CACHE_PROCESS_COUNT = "3",
    APP_MEMORY_CACHE_BUDGET_MB = "32"
)
process_chunk <- raw(5L * 1024L^2)
cache_env_set(.gff_cache, "process-a", process_chunk, max_bytes = 64 * 1024^2)
cache_env_set(.gff_gene_index_cache, "process-b", process_chunk, max_bytes = 64 * 1024^2)
cache_env_set(.gff_gene_light_index_cache, "process-c", process_chunk, max_bytes = 64 * 1024^2)
process_stats <- coordinated_memory_cache_stats()
stopifnot(isTRUE(all.equal(process_stats$budget_bytes, (32 / 3) * 1024^2)))
stopifnot(process_stats$total_bytes <= process_stats$budget_bytes)
assert_tracker_matches_stats()
rm(process_chunk)
invisible(lapply(registry, clear_env))
invisible(coordinated_memory_cache_tracked_bytes(recalculate = TRUE))

# A high explicit budget retains all coordinated entries.
Sys.setenv(
    CGV_RUNTIME = "web",
    APP_FUTURE_MODE = "sequential",
    APP_MEMORY_CACHE_PROCESS_COUNT = "1",
    APP_MEMORY_CACHE_BUDGET_MB = "128"
)
chunk_a <- raw(12L * 1024L^2)
chunk_b <- raw(12L * 1024L^2)
chunk_c <- raw(12L * 1024L^2)
cache_env_set(.gff_cache, "a", chunk_a, max_bytes = 64 * 1024^2)
cache_env_set(.gff_gene_index_cache, "b", chunk_b, max_bytes = 64 * 1024^2)
cache_env_set(.gff_gene_light_index_cache, "c", chunk_c, max_bytes = 64 * 1024^2)
high_stats <- coordinated_memory_cache_stats()
stopifnot(high_stats$total_entries == 3L)
stopifnot(high_stats$total_bytes <= high_stats$budget_bytes)
assert_tracker_matches_stats()

# Under a 32 MiB budget, touching `a` makes `b` the global LRU entry even
# though it lives in another cache environment.
invisible(lapply(registry, clear_env))
invisible(coordinated_memory_cache_tracked_bytes(recalculate = TRUE))
Sys.setenv(APP_MEMORY_CACHE_BUDGET_MB = "32")
cache_env_set(.gff_cache, "a", chunk_a, max_bytes = 64 * 1024^2)
cache_env_set(.gff_gene_index_cache, "b", chunk_b, max_bytes = 64 * 1024^2)
stopifnot(identical(cache_env_get(.gff_cache, "a"), chunk_a))
cache_env_set(.gff_gene_light_index_cache, "c", chunk_c, max_bytes = 64 * 1024^2)
stopifnot(exists("a", envir = .gff_cache, inherits = FALSE))
stopifnot(!exists("b", envir = .gff_gene_index_cache, inherits = FALSE))
stopifnot(exists("c", envir = .gff_gene_light_index_cache, inherits = FALSE))
low_stats <- coordinated_memory_cache_stats()
stopifnot(low_stats$total_bytes <= low_stats$budget_bytes)
assert_tracker_matches_stats()

# Replacement, local max_size trimming, and explicit drops keep the O(1) byte
# tracker exactly synchronized with independently measured cache metadata.
invisible(lapply(registry, clear_env))
invisible(coordinated_memory_cache_tracked_bytes(recalculate = TRUE))
Sys.setenv(APP_MEMORY_CACHE_BUDGET_MB = "128")
cache_env_set(.gff_cache, "replace", raw(1024L), max_size = 2L, max_bytes = 1024^2)
assert_tracker_matches_stats()
cache_env_set(.gff_cache, "replace", raw(2048L), max_size = 2L, max_bytes = 1024^2)
assert_tracker_matches_stats()
cache_env_set(.gff_cache, "newest", raw(4096L), max_size = 1L, max_bytes = 1024^2)
stopifnot(!exists("replace", envir = .gff_cache, inherits = FALSE))
stopifnot(exists("newest", envir = .gff_cache, inherits = FALSE))
assert_tracker_matches_stats()
cache_env_drop(.gff_cache, "newest")
stopifnot(!exists("newest", envir = .gff_cache, inherits = FALSE))
assert_tracker_matches_stats()

# An item larger than the entire budget is simply not retained. The caller
# still receives the computed value, preserving cache_env_set semantics.
invisible(lapply(registry, clear_env))
invisible(coordinated_memory_cache_tracked_bytes(recalculate = TRUE))
rm(chunk_a, chunk_b, chunk_c)
invisible(gc())
Sys.setenv(APP_MEMORY_CACHE_BUDGET_MB = "32")
oversize <- raw(33L * 1024L^2)
returned <- cache_env_set(.gff_cache, "oversize", oversize, max_bytes = 64 * 1024^2)
stopifnot(identical(returned, oversize))
stopifnot(!exists("oversize", envir = .gff_cache, inherits = FALSE))
stopifnot(coordinated_memory_cache_stats()$total_entries == 0L)
assert_tracker_matches_stats()
rm(oversize, returned)
invisible(gc())

# Adversarial sequence payloads are now charged to the same 32 MiB allowance.
# Both helpers preserve their returned strings even when global LRU eviction
# decides that a just-produced value should not remain cached.
invisible(lapply(registry, clear_env))
invisible(coordinated_memory_cache_tracked_bytes(recalculate = TRUE))
Sys.setenv(APP_MEMORY_CACHE_BUDGET_MB = "32", APP_FUTURE_MODE = "sequential")
for (i in seq_len(40L)) {
    seq_value <- paste0(strrep("A", 1024L^2), sprintf("%02d", i))
    returned_seq <- cache_sequence_extract_result(
        fasta_path = file.path(tempdir(), "adversarial.fa"),
        seqid = paste0("chr", i),
        start_pos = 1L,
        end_pos = nchar(seq_value),
        seq_txt = seq_value
    )
    stopifnot(identical(returned_seq, seq_value))
    cache_env_set(
        .spliced_seq_cache,
        paste0("tx", i),
        seq_value,
        max_size = annotation_memory_cache_limits$spliced_seq_max_entries,
        max_bytes = annotation_memory_cache_limits$spliced_seq_max_bytes
    )
}
sequence_stats <- coordinated_memory_cache_stats()
stopifnot(sequence_stats$total_bytes <= sequence_stats$budget_bytes)
stopifnot(sequence_stats$by_cache$bytes[sequence_stats$by_cache$cache == "seq_extract"] <= 32 * 1024^2)
stopifnot(sequence_stats$by_cache$bytes[sequence_stats$by_cache$cache == "spliced_seq"] <= 32 * 1024^2)
assert_tracker_matches_stats()
rm(seq_value, returned_seq)
invisible(gc())

# The generic enforcement helper is independently testable with small isolated
# environments; it does not register or retain them globally.
test_a <- new.env(parent = emptyenv())
test_b <- new.env(parent = emptyenv())
cache_env_set(test_a, "old", raw(600L))
cache_env_set(test_b, "new", raw(600L))
manual <- enforce_coordinated_memory_cache_budget(
    budget_bytes = 700,
    cache_envs = list(test_a = test_a, test_b = test_b)
)
stopifnot(nrow(manual$evicted) >= 1L)
stopifnot(manual$after_bytes <= 700)
stopifnot(!exists("old", envir = test_a, inherits = FALSE))

fixture_dir <- tempfile("cgv-memory-fixture-")
dir.create(fixture_dir, recursive = TRUE)
on.exit(unlink(fixture_dir, recursive = TRUE, force = TRUE), add = TRUE)
fixture <- function(name, value) {
    path <- file.path(fixture_dir, name)
    writeLines(as.character(value), path, useBytes = TRUE)
    path
}
missing_path <- file.path(fixture_dir, "missing")

v2_current <- fixture("memory.current", "1048576")
v2_max <- fixture("memory.max", "2097152")
v2 <- read_cgroup_memory_stats(
    v2_current_path = v2_current,
    v2_max_path = v2_max,
    v1_usage_path = missing_path,
    v1_limit_path = missing_path
)
stopifnot(identical(v2$version, "v2"))
stopifnot(identical(v2$current_bytes, 1048576))
stopifnot(identical(v2$limit_bytes, 2097152))
stopifnot(isTRUE(all.equal(v2$usage_ratio, 0.5)))

writeLines("max", v2_max, useBytes = TRUE)
v2_unlimited <- read_cgroup_memory_stats(
    v2_current_path = v2_current,
    v2_max_path = v2_max,
    v1_usage_path = missing_path,
    v1_limit_path = missing_path
)
stopifnot(identical(v2_unlimited$version, "v2"))
stopifnot(isTRUE(v2_unlimited$unlimited))
stopifnot(is.na(v2_unlimited$limit_bytes))

v1_usage <- fixture("memory.usage_in_bytes", "3145728")
v1_limit <- fixture("memory.limit_in_bytes", "6291456")
v1 <- read_cgroup_memory_stats(
    v2_current_path = missing_path,
    v2_max_path = missing_path,
    v1_usage_path = v1_usage,
    v1_limit_path = v1_limit
)
stopifnot(identical(v1$version, "v1"))
stopifnot(identical(v1$current_bytes, 3145728))
stopifnot(identical(v1$limit_bytes, 6291456))

bad_current <- fixture("bad.current", "not-a-number")
bad_limit <- fixture("bad.max", "-1")
malformed <- read_cgroup_memory_stats(
    v2_current_path = bad_current,
    v2_max_path = bad_limit,
    v1_usage_path = bad_current,
    v1_limit_path = bad_limit
)
stopifnot(identical(malformed$version, "none"))
stopifnot(is.na(malformed$current_bytes))
stopifnot(is.na(malformed$limit_bytes))

status_path <- fixture("status", paste(
    "Name:\tR",
    "VmSize:\t9876 kB",
    "VmRSS:\t1234 kB",
    sep = "\n"
))
stopifnot(identical(
    read_process_rss_bytes(status_path = status_path, allow_ps_fallback = FALSE),
    1234 * 1024
))
stopifnot(is.na(read_process_rss_bytes(status_path = bad_current, allow_ps_fallback = FALSE)))

telemetry <- app_memory_telemetry_snapshot(
    cache_envs = list(test_a = test_a, test_b = test_b),
    budget_bytes = 700,
    v2_current_path = v2_current,
    v2_max_path = v2_max,
    v1_usage_path = missing_path,
    v1_limit_path = missing_path
)
stopifnot(all(c(
    "rss_bytes", "cgroup_current_bytes", "cgroup_limit_bytes",
    "cache_bytes", "cache_entries", "cache_budget_bytes",
    "cache_total_budget_bytes", "cache_process_count", "cache_by_name"
) %in% names(telemetry)))

cat(sprintf(
    "coordinated-memory-cache-budget-ok web_total_mb=%d web_process_mb=%d default_desktop_mb=%d caches=%d\n",
    get_coordinated_memory_cache_total_budget_mb(runtime = "web", raw_value = ""),
    get_coordinated_memory_cache_budget_mb(
        runtime = "web", raw_value = "", future_mode = "multisession", raw_process_count = "3"
    ),
    get_coordinated_memory_cache_budget_mb(runtime = "desktop", raw_value = ""),
    length(registry)
))
