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
    grepl('later::later\\(function\\(\\) \\{\\s*tryCatch\\(warm_gene_plot_renderer_once\\(\\)', server_txt, perl = TRUE),
    "The renderer prewarm flag must schedule an actual session prewarm."
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
    grepl("allow_disk_index = TRUE", server_txt, fixed = TRUE),
    "Preloaded organism sync must populate gene autocomplete from the persistent disk sidecar."
)
assert_true(
    grepl("ready <- isTRUE(annotations_ready)", server_txt, fixed = TRUE),
    "Fast organism search readiness must not wait for genome warm-up."
)
assert_true(
    grepl("APP_TABIX_PROBE_ON_WARM", server_txt, fixed = TRUE) &&
        grepl("run_followup_queue", server_txt, fixed = TRUE),
    "Tabix probing must run in the non-blocking organism-preparation follow-up queue."
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
