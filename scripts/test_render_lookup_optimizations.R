#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(dplyr)
    library(stringr)
    library(purrr)
    library(vroom)
})

source(file.path("R", "utils.R"))

assert_true <- function(value, message) {
    if (!isTRUE(value)) stop(message, call. = FALSE)
}

modules_txt <- paste(readLines(file.path("R", "modules.R"), warn = FALSE), collapse = "\n")
server_txt <- paste(readLines("server.R", warn = FALSE), collapse = "\n")
autocomplete_txt <- paste(readLines(file.path("R", "server_autocomplete_domain.R"), warn = FALSE), collapse = "\n")
desktop_txt <- paste(readLines(file.path("desktop", "src", "main.js"), warn = FALSE), collapse = "\n")

assert_true(
    grepl("local_need_gc_span <- !isTRUE\\(defer_feature_gc\\) \\|\\| isTRUE\\(inline_fast\\)", modules_txt),
    "Homologous fast 2bit prefetch must include the GC span before first render."
)
assert_true(
    grepl("if \\(isTRUE\\(prefetch_sequence\\) && !isTRUE\\(defer_sequence\\)\\)", modules_txt),
    "Deferred orthologous sequence mode must not block the first render on gene_info()."
)
assert_true(
    grepl('APP_ORTHO_PREFER_MAIN_CACHE", TRUE', server_txt, fixed = TRUE),
    "Cross-species lookup must prefer warmed indexes in the main process."
)
assert_true(
    grepl('APP_ORTHO_WORKER_PREWARM: process.env.APP_ORTHO_WORKER_PREWARM || "0"', desktop_txt, fixed = TRUE),
    "Desktop worker prewarm must default off so it cannot contend with a user search."
)
assert_true(
    grepl('APP_ORTHO_BACKGROUND_CACHE_WARM: process.env.APP_ORTHO_BACKGROUND_CACHE_WARM || "0"', desktop_txt, fixed = TRUE),
    "Desktop orthologous background cache warming must default off."
)
assert_true(
    grepl('APP_ORTHO_BACKGROUND_CACHE_WARM", FALSE', server_txt, fixed = TRUE),
    "Cross-species background cache warming must be opt-in."
)
assert_true(
    grepl('APP_ORTHO_PREFLIGHT_SUGGESTIONS", FALSE', server_txt, fixed = TRUE),
    "Approximate suggestions must not run before the exact cross-species lookup."
)
assert_true(
    grepl('APP_ORTHO_PREFLIGHT_SUGGESTIONS: process.env.APP_ORTHO_PREFLIGHT_SUGGESTIONS || "0"', desktop_txt, fixed = TRUE),
    "Desktop approximate preflight suggestions must default off."
)
assert_true(
    grepl('APP_ORTHO_PREWARM_LOCAL_HANDLES: process.env.APP_ORTHO_PREWARM_LOCAL_HANDLES || "1"', desktop_txt, fixed = TRUE),
    "Desktop must warm lightweight genome and alias handles during organism preparation."
)
assert_true(
    grepl('APP_ORTHO_PREWARM_LOCAL_HANDLES", TRUE', server_txt, fixed = TRUE),
    "Cross-species organism preparation must support lightweight local handle warming."
)
assert_true(
    grepl('session$onFlushed(function() {', server_txt, fixed = TRUE) &&
        grepl('APP_GENE_PLOT_RENDERER_PREWARM_DELAY_MS', server_txt, fixed = TRUE) &&
        grepl('tryCatch(warm_gene_plot_renderer_once(), error = function(e) NULL)', server_txt, fixed = TRUE),
    "The renderer warm-up must run after the first flush with a configurable delay."
)
assert_true(
    grepl("load_gff_autocomplete_cache\\(p, base_dir = \"\\.\"\\)", autocomplete_txt, perl = TRUE),
    "Autocomplete must prefer the compact sidecar before loading gene_light."
)
assert_true(
    grepl("schedule_fast_search_preparation", server_txt, fixed = TRUE) &&
        grepl("check_search_preparation_gate", server_txt, fixed = TRUE),
    "Fast organism sync must hydrate indexes after flush and gate final search observers."
)
assert_true(
    grepl("APP_ORTHO_SELECTION_DEBOUNCE_MS", server_txt, fixed = TRUE) &&
        grepl("ortho_preloaded_selection_debounced <- shiny::debounce", server_txt, fixed = TRUE),
    "Rapid Cross-Species organism selections must be grouped before expensive preparation starts."
)
assert_true(
    grepl("identical\\(lastPreparedOrthoSelection\\(\\), prep_key\\) && isTRUE\\(selection_is_ready\\)", server_txt, perl = TRUE),
    "Returning to a previous selection must not skip preparation while its search gate is still closed."
)
assert_true(
    grepl("allow_disk_index = TRUE", server_txt, fixed = TRUE),
    "Preloaded organism sync must populate gene autocomplete from the persistent disk sidecar."
)
assert_true(
    grepl("ready <- isTRUE(annotations_ready)", server_txt, fixed = TRUE),
    "Fast organism search readiness must not wait for genome warm-up."
)
assert_true(
    grepl('app_env_flag("APP_TABIX_PROBE_ON_WARM", FALSE)', server_txt, fixed = TRUE) &&
        grepl("run_followup_queue", server_txt, fixed = TRUE),
    "Optional tabix probing must default off and stay in the organism-preparation follow-up queue."
)
assert_true(
    grepl("start_followup_queue <- function", server_txt, fixed = TRUE) &&
        grepl("if \\(ready\\) \\{[\\s\\S]{0,1800}session\\$onFlushed\\(function\\(\\) \\{[\\s\\S]{0,300}start_followup_queue", server_txt, perl = TRUE),
    "Secondary cache warming must start only after annotation readiness has been delivered to the browser."
)
assert_true(
    grepl("refresh_autocomplete <- !isTRUE\\(autocomplete_sync\\$complete\\)", server_txt, perl = TRUE) &&
        grepl("if \\(isTRUE\\(refresh_autocomplete\\)\\)", server_txt, perl = TRUE),
    "Fast organism preparation must retry autocomplete only when the initial disk lookup was incomplete."
)
assert_true(
    grepl("if \\(length\\(cached\\) > 0 && min_shared <= 1L\\)", autocomplete_txt, perl = TRUE),
    "Shared Cross-Species autocomplete must defer publication until every selected organism is aggregated."
)
assert_true(
    grepl("twobit_seqnames_sidecar_path", paste(readLines(file.path("R", "utils.R"), warn = FALSE), collapse = "\n"), fixed = TRUE),
    "2bit seqname lookup must support persistent cache sidecars."
)
assert_true(
    !grepl(
        'still_valid = compose_autocomplete_still_valid\\("gene_name", epoch_token, function\\(\\) \\{\\s*if \\(!\\(\\(as.character\\(isolate\\(input\\$ortho_data_mode',
        server_txt,
        perl = TRUE
    ),
    "Cross-Species cache warming must not be invalidated by autocomplete epochs."
)
alias_timing_guard <- paste0(
    "if (!isTRUE((alias_index_attempt %||% list())$reused)) {\n",
    "                app_perf_mark_ms(lookup_perf, \"lookup_alias_index_ms\""
)
alias_timing_guard_matches <- gregexpr(alias_timing_guard, server_txt, fixed = TRUE)[[1L]]
assert_true(
    identical(sum(alias_timing_guard_matches > 0L), 3L),
    "Session alias lookup timing must retain the real query duration when a later stage reuses its result."
)

tmp_gff <- tempfile(fileext = ".gff3")
writeLines(
    c(
        "##gff-version 3",
        "chr1\tsrc\tgene\t1\t500\t.\t+\t.\tID=gene-TEST1;gene_name=TEST1;Name=TEST1",
        "chr1\tsrc\tmRNA\t1\t500\t.\t+\t.\tID=rna-TEST1;Parent=gene-TEST1",
        "chr1\tsrc\texon\t1\t200\t.\t+\t.\tID=exon-1;Parent=rna-TEST1",
        "chr1\tsrc\texon\t301\t500\t.\t+\t.\tID=exon-2;Parent=rna-TEST1"
    ),
    tmp_gff,
    useBytes = TRUE
)
on.exit(unlink(tmp_gff, force = TRUE), add = TRUE)

job <- list(
    file_idx = 1L,
    file_path = tmp_gff,
    file_label = basename(tmp_gff),
    forced_genome = "",
    det = list(organism = "Test organism", taxid = "1"),
    gene_name = "TEST1",
    enabled_external_sources = character(0),
    allow_partial_suggestions = FALSE
)

first <- run_orthologous_lookup_job_pure(job)
cache_entries_after_first <- setdiff(
    ls(envir = .orthologous_local_lookup_cache, all.names = TRUE),
    .cache_meta_hidden_key
)
second <- run_orthologous_lookup_job_pure(job)
cache_entries_after_second <- setdiff(
    ls(envir = .orthologous_local_lookup_cache, all.names = TRUE),
    .cache_meta_hidden_key
)

assert_true(isTRUE(first$found), "The initial local lookup should find the test gene.")
assert_true(length(cache_entries_after_first) == 1L, "The initial lookup should populate one LRU entry.")
assert_true(identical(first, second), "The repeated lookup should return the cached result unchanged.")
assert_true(
    identical(cache_entries_after_first, cache_entries_after_second),
    "The repeated lookup should reuse, not duplicate, its cache entry."
)

cat("render-lookup-optimizations-ok\n")
