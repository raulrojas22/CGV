#!/usr/bin/env Rscript

server_txt <- paste(readLines("server.R", warn = FALSE), collapse = "\n")
modules_txt <- paste(readLines(file.path("R", "modules.R"), warn = FALSE), collapse = "\n")
env_txt <- paste(readLines(".env.example", warn = FALSE), collapse = "\n")
desktop_main_txt <- paste(readLines(file.path("desktop", "src", "main.js"), warn = FALSE), collapse = "\n")
perf_runner_txt <- paste(readLines(file.path("scripts", "run_app_perf.sh"), warn = FALSE), collapse = "\n")

expect_pattern <- function(txt, pattern, label) {
    if (!grepl(pattern, txt, perl = TRUE)) {
        stop(sprintf("Missing expected lazy-render default: %s", label))
    }
}

expect_pattern(
    server_txt,
    'parse_positive_int_env\\("APP_HOMO_UPFRONT_ISOFORMS",\\s*0L\\)',
    "homologous hidden isoforms are not instantiated upfront by default"
)
expect_pattern(
    server_txt,
    'parse_positive_int_env\\("APP_ORTHO_UPFRONT_ISOFORMS",\\s*0L\\)',
    "orthologous hidden isoforms are not instantiated upfront by default"
)
expect_pattern(
    server_txt,
    'class = "card-isoform card-isoform-placeholder"',
    "orthologous isoforms use lightweight DOM placeholders before expansion"
)
expect_pattern(
    server_txt,
    'defer_isoform_body = id %in% deferred_isoform_ids',
    "orthologous card insertion defers non-visible isoform bodies"
)
expect_pattern(
    server_txt,
    'primaryPlotIdsHomologous <- reactive\\([\\s\\S]*!identical\\(meta\\$is_canonical, FALSE\\)',
    "Multi-Gene primary pagination excludes hidden isoform cards"
)
expect_pattern(
    server_txt,
    'output\\$homo_load_more_banner <- renderUI\\([\\s\\S]*ids <- primaryPlotIdsHomologous\\(\\)',
    "Multi-Gene progress counts canonical gene cards only"
)
expect_pattern(
    server_txt,
    'pending_hydration <- setdiff\\(ids_chr, hydrated_ids\\)[\\s\\S]*insertUI\\([\\s\\S]*removeUI\\(',
    "orthologous isoform bodies hydrate on the first expand request"
)
expect_pattern(
    server_txt,
    'schedule_isoform_module_batches <- function\\(ids_chr, context\\)[\\s\\S]*ceiling\\(seq_along\\(ids_chr\\) / isoformRenderBatchSize\\)[\\s\\S]*later::later',
    "expanded isoform plots are instantiated in delayed batches"
)
expect_pattern(
    server_txt,
    'homoAutoRenderQueued\\(TRUE\\)[\\s\\S]*release_next_batch <- function\\(\\)[\\s\\S]*later::later[\\s\\S]*session\\$onFlushed\\(release_next_batch, once = TRUE\\)',
    "Multi-Gene flushes the current card before scheduling the next registration"
)
expect_pattern(
    server_txt,
    'figure_studio_plot_render_request[\\s\\S]*pending_hydration <- setdiff\\(ids_chr, hydrated_ids\\)[\\s\\S]*instantiate_orthologous_plot_module',
    "Figure Studio hydrates an orthologous isoform body before background rendering"
)
keepalive_txt <- paste(readLines(file.path("www", "js", "keepalive.js"), warn = FALSE), collapse = "\n")
expect_pattern(
    keepalive_txt,
    'replace\\(\\/\\^ortho-placeholder-\\/[^;]*\\)',
    "orthologous placeholder IDs are normalized before the expand request"
)
expect_pattern(
    keepalive_txt,
    'function syncIsoformToggleButtons\\(\\)[\\s\\S]*document.addEventListener\\(\'shiny:value\'[\\s\\S]*syncIsoformToggleButtons\\(\\)',
    "isoform toggle labels resync after Shiny replaces a footer"
)
expect_pattern(
    server_txt,
    'orthoHydratedIsoformIds\\(character\\(\\)\\)',
    "orthologous lazy hydration state resets when cards are cleared"
)
expect_pattern(
    modules_txt,
    'APP_ORTHO_SUSPEND_HIDDEN",\\s*"1"',
    "orthologous girafe outputs suspend while hidden by default"
)
expect_pattern(
    modules_txt,
    'needs_feature_gc <- isTRUE\\(has_gc_source\\)',
    "gene plots keep per-feature GC enabled when a genome source exists"
)
expect_pattern(
    modules_txt,
    'APP_DEFER_FEATURE_GC",\\s*"0"',
    "feature GC can be deferred without disabling GC support"
)
expect_pattern(
    modules_txt,
    'schedule_gc_span_prefetch\\(df\\)',
    "orthologous plots prefetch feature GC after the first deferred render"
)
expect_pattern(
    modules_txt,
    'schedule_deferred_sequence_prefetch\\(\\)',
    "orthologous plots prefetch sequence composition after the first deferred render"
)
expect_pattern(
    modules_txt,
    '!isTRUE\\(local_need_gc_span\\) && !isTRUE\\(local_need_sequence\\)[\\s\\S]*initial sequence and GC prefetch fully deferred',
    "homologous fully deferred first paint skips an empty future"
)
expect_pattern(
    modules_txt,
    'deferred_plot_enrichment_delay_seconds\\(0\\.5\\)',
    "deferred enrichment waits long enough for the initial widget to flush"
)
for (output_id in c(
    "homo_aligned_plot_out",
    "homo_aligned_footer",
    "homo_pip_plot_out",
    "homo_pip_footer",
    "homo_multipip_plot_out",
    "homo_multipip_footer",
    "ortho_aligned_plot_out",
    "ortho_aligned_footer",
    "ortho_pip_plot_out",
    "ortho_pip_footer",
    "ortho_multipip_plot_out",
    "ortho_multipip_footer"
)) {
    expect_pattern(
        server_txt,
        sprintf(
            'outputOptions\\(output, "%s", suspendWhenHidden = isTRUE\\(should_suspend_hidden_ortho_outputs\\(\\)\\)\\)',
            output_id
        ),
        paste("hidden heavy output suspends:", output_id)
    )
}
expect_pattern(
    server_txt,
    'APP_FOOTER_DEFER_SEQUENCE",\\s*"0"',
    "server web default keeps footer sequence composition unless Desktop overrides it"
)
expect_pattern(
    modules_txt,
    'APP_HOMO_DEFER_SEQUENCE",\\s*"0"',
    "server web default keeps homologous sequence composition unless Desktop overrides it"
)
expect_pattern(
    server_txt,
    '!isTRUE\\(defer_footer_sequence_h\\)\\s*&&\\s*\\n\\s*is_canonical_footer_h',
    "homologous footer avoids canonical gene sequence extraction while deferred"
)
expect_pattern(
    server_txt,
    '!isTRUE\\(defer_footer_sequence_o\\)\\s*&&\\s*\\n\\s*is_canonical_footer_o',
    "orthologous footer avoids canonical gene sequence extraction while deferred"
)
for (env_key in c(
    "APP_HOMO_RENDER_CHUNK_SIZE=1",
    "APP_HOMO_AUTO_RENDER_DELAY_MS=120",
    "APP_ORTHO_RENDER_CHUNK_SIZE=1",
    "APP_ORTHO_AUTO_RENDER_MORE=1",
    "APP_ORTHO_AUTO_RENDER_DELAY_MS=120",
    "APP_ORTHO_FIRST_PAINT_TIMEOUT_MS=30000",
    "APP_ORTHO_SUSPEND_HIDDEN=1",
    "APP_HOMO_DEFER_SEQUENCE=0",
    "APP_ORTHO_DEFER_SEQUENCE=0",
    "APP_FOOTER_DEFER_SEQUENCE=0",
    "APP_DEFER_FEATURE_GC=0",
    "APP_HOMO_UPFRONT_ISOFORMS=0",
    "APP_ORTHO_UPFRONT_ISOFORMS=0",
    "APP_HOMO_INITIAL_VISIBLE=1",
    "APP_ORTHO_INITIAL_VISIBLE=1",
    "APP_ISOFORM_RENDER_BATCH_SIZE=1",
    "APP_ISOFORM_RENDER_BATCH_DELAY_MS=120"
)) {
    expect_pattern(env_txt, env_key, paste("env example uses progressive rendering:", env_key))
}
expect_pattern(
    desktop_main_txt,
    'APP_HOMO_DEFER_SEQUENCE:\\s*process\\.env\\.APP_HOMO_DEFER_SEQUENCE \\|\\| "0"',
    "Desktop computes homologous sequence composition in the initial render"
)
expect_pattern(
    desktop_main_txt,
    'APP_DEFER_FEATURE_GC:\\s*process\\.env\\.APP_DEFER_FEATURE_GC \\|\\| "0"',
    "Desktop computes feature GC in the initial render"
)

for (runner_default in c(
    'APP_HOMO_INITIAL_VISIBLE="${APP_HOMO_INITIAL_VISIBLE:-1}"',
    'APP_ORTHO_INITIAL_VISIBLE="${APP_ORTHO_INITIAL_VISIBLE:-1}"',
    'APP_HOMO_RENDER_CHUNK_SIZE="${APP_HOMO_RENDER_CHUNK_SIZE:-1}"',
    'APP_HOMO_AUTO_RENDER_DELAY_MS="${APP_HOMO_AUTO_RENDER_DELAY_MS:-120}"',
    'APP_ORTHO_RENDER_CHUNK_SIZE="${APP_ORTHO_RENDER_CHUNK_SIZE:-1}"',
    'APP_ORTHO_AUTO_RENDER_MORE="${APP_ORTHO_AUTO_RENDER_MORE:-1}"',
    'APP_ORTHO_AUTO_RENDER_DELAY_MS="${APP_ORTHO_AUTO_RENDER_DELAY_MS:-120}"',
    'APP_ISOFORM_RENDER_BATCH_SIZE="${APP_ISOFORM_RENDER_BATCH_SIZE:-1}"',
    'APP_ISOFORM_RENDER_BATCH_DELAY_MS="${APP_ISOFORM_RENDER_BATCH_DELAY_MS:-120}"',
    'APP_ORTHO_SERVER_RENDER_NUDGE="${APP_ORTHO_SERVER_RENDER_NUDGE:-0}"',
    'APP_HOMO_DEFER_SEQUENCE="${APP_HOMO_DEFER_SEQUENCE:-0}"',
    'APP_ORTHO_DEFER_SEQUENCE="${APP_ORTHO_DEFER_SEQUENCE:-0}"',
    'APP_FOOTER_DEFER_SEQUENCE="${APP_FOOTER_DEFER_SEQUENCE:-0}"',
    'APP_DEFER_FEATURE_GC="${APP_DEFER_FEATURE_GC:-0}"'
)) {
    if (!grepl(runner_default, perf_runner_txt, fixed = TRUE)) {
        stop(sprintf("Performance runner is not using the progressive render default: %s", runner_default))
    }
}
expect_pattern(
    perf_runner_txt,
    'APP_HOMO_DEFER_SEQUENCE="\\$APP_HOMO_DEFER_SEQUENCE"',
    "performance runner forwards the eager homologous sequence setting"
)
expect_pattern(
    perf_runner_txt,
    'APP_ORTHO_SERVER_RENDER_NUDGE="\\$APP_ORTHO_SERVER_RENDER_NUDGE"',
    "performance runner disables the post-flush second render"
)

cat("render-lazy-defaults-ok\n")
