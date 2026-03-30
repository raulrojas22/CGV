#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(shiny))

`%||%` <- function(a, b) if (!is.null(a)) a else b

script_file <- NULL
for (arg in commandArgs(trailingOnly = FALSE)) {
    if (startsWith(arg, "--file=")) {
        script_file <- sub("^--file=", "", arg)
        break
    }
}

root_dir <- if (!is.null(script_file)) {
    normalizePath(file.path(dirname(script_file), ".."), winslash = "/", mustWork = FALSE)
} else {
    getwd()
}
if (!file.exists(file.path(root_dir, "global.R"))) {
    root_dir <- getwd()
}
if (!file.exists(file.path(root_dir, "global.R"))) {
    stop("Could not locate project root (global.R). Run from project root or scripts/.")
}

setwd(root_dir)

snapshot_files <- list.files(file.path(root_dir, "cache", "work_sessions"), pattern = "\\.rds$", full.names = TRUE)
snapshot_files <- snapshot_files[!grepl("index\\.rds$", basename(snapshot_files))]
if (length(snapshot_files) == 0L) {
    stop("No session snapshots found in cache/work_sessions.")
}
snapshot_files <- snapshot_files[order(file.info(snapshot_files)$mtime, decreasing = TRUE)]
snapshot_path <- snapshot_files[[1]]
snapshot_obj <- readRDS(snapshot_path)

homo_plots <- snapshot_obj$homologous$plots %||% list()
if (length(homo_plots) == 0L || is.null(homo_plots[[1]]$plot_data)) {
    stop("Latest snapshot has no homologous plot data to benchmark.")
}
plot_data <- homo_plots[[1]]$plot_data
if (!is.data.frame(plot_data) || nrow(plot_data) == 0L) {
    stop("Selected plot_data is empty or invalid.")
}

source(file.path(root_dir, "global.R"), local = .GlobalEnv)
if (!("app_libraries" %in% search())) {
    stop("Expected app_libraries environment after sourcing global.R.")
}
app_env <- as.environment("app_libraries")

run_module_cache_smoke <- function(module_fun_name, label, data_df) {
    if (!exists(module_fun_name, envir = app_env, inherits = FALSE)) {
        stop(sprintf("Module '%s' not found in app_libraries.", module_fun_name))
    }
    module_fun <- get(module_fun_name, envir = app_env, inherits = FALSE)

    if (!exists("create_gene_plot", envir = app_env, inherits = FALSE)) {
        stop("create_gene_plot not found in app_libraries.")
    }
    original_create_gene_plot <- get("create_gene_plot", envir = app_env, inherits = FALSE)
    create_calls <- 0L
    assign("create_gene_plot", function(...) {
        create_calls <<- create_calls + 1L
        original_create_gene_plot(...)
    }, envir = app_env)
    on.exit(assign("create_gene_plot", original_create_gene_plot, envir = app_env), add = TRUE)

    max_gene_length_rv <- reactiveVal(1000)
    min_gene_coord_rv <- reactiveVal(1)
    max_gene_coord_rv <- reactiveVal(1000)
    gen_sequences_rv <- reactiveVal(list())
    visual_mode_rv <- reactiveVal("compact")
    theme_mode_rv <- reactiveVal("light")
    colorblind_rv <- reactiveVal(FALSE)
    pulse_rv <- reactiveVal(0L)

    step_labels <- character(0)
    elapsed_sec <- numeric(0)
    calls_after_step <- integer(0)

    shiny::testServer(
        module_fun,
        args = list(
            id = paste0("mod_", tolower(label)),
            data = data_df,
            max_gene_length = max_gene_length_rv,
            min_gene_coord = min_gene_coord_rv,
            max_gene_coord = max_gene_coord_rv,
            genSequences = gen_sequences_rv,
            plotIndex = "1",
            gene_name = "benchmark_gene",
            genome_fasta_path = NULL,
            annotation_file_path = "",
            visual_mode = reactive({
                pulse_rv()
                visual_mode_rv()
            }),
            organism_name = "benchmark_org",
            use_report_map = FALSE,
            report_path = "",
            app_theme = reactive({
                pulse_rv()
                theme_mode_rv()
            }),
            app_colorblind = reactive({
                pulse_rv()
                colorblind_rv()
            }),
            precomputed_neighbor_context = NULL,
            prefetch_sequence = FALSE
        ),
        expr = {
            outputOptions(output, "plot", suspendWhenHidden = FALSE)
            session$setInputs(.clientdata_output_plot_hidden = FALSE)
            session$setInputs(.clientdata_output_plot_width = 1200)
            session$setInputs(.clientdata_output_plot_height = 180)
            run_step <- function(step_name, mutator = NULL) {
                if (is.function(mutator)) {
                    mutator()
                }
                session$flushReact()
                t_elapsed <- system.time({
                    out_obj <- output$plot
                    invisible(out_obj)
                })[["elapsed"]]
                step_labels <<- c(step_labels, step_name)
                elapsed_sec <<- c(elapsed_sec, as.numeric(t_elapsed))
                calls_after_step <<- c(calls_after_step, as.integer(create_calls))
            }

            run_step("initial_render")
            run_step("same_key_rerender_1", function() pulse_rv(pulse_rv() + 1L))
            run_step("theme_change", function() {
                theme_mode_rv("dark")
                pulse_rv(pulse_rv() + 1L)
            })
            run_step("same_key_rerender_2", function() pulse_rv(pulse_rv() + 1L))
            run_step("visual_mode_change", function() {
                visual_mode_rv("detailed")
                pulse_rv(pulse_rv() + 1L)
            })
            run_step("same_key_rerender_3", function() pulse_rv(pulse_rv() + 1L))
        }
    )

    out <- data.frame(
        module = label,
        step = step_labels,
        elapsed_sec = round(elapsed_sec, 4),
        create_calls = calls_after_step,
        stringsAsFactors = FALSE
    )
    out$delta_calls <- c(out$create_calls[1], diff(out$create_calls))
    out
}

homo_res <- run_module_cache_smoke("plotServerHomologous", "HOMO", plot_data)
ortho_res <- run_module_cache_smoke("plotServerOrtologous", "ORTHO", plot_data)
results <- rbind(homo_res, ortho_res)

cat(sprintf("Snapshot used: %s\n", snapshot_path))
print(results, row.names = FALSE)

if (all(results$create_calls == 0L)) {
    cat("\nWARNING: create_gene_plot was never invoked in this headless run.\n")
    cat("This indicates renderGirafe did not execute under testServer in the current environment.\n")
    cat("Use interactive app logs (APP_PERF_TIMING=1) plus scripts/summarize_perf_log.R for real measurements.\n")
    quit(status = 3L)
}

cat("\nCache sanity checks (same_key steps should have delta_calls = 0):\n")
same_key <- grepl("^same_key_", results$step)
check_tbl <- results[same_key, c("module", "step", "delta_calls")]
print(check_tbl, row.names = FALSE)

bad <- check_tbl[check_tbl$delta_calls != 0L, , drop = FALSE]
if (nrow(bad) > 0L) {
    cat("\nWARNING: unexpected recomputation on same-key steps detected.\n")
    print(bad, row.names = FALSE)
    quit(status = 2L)
}

cat("\nOK: no recomputation on same-key rerenders in either module.\n")
