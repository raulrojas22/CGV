#!/usr/bin/env Rscript

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

args <- commandArgs(trailingOnly = TRUE)
feature_count <- suppressWarnings(as.integer(args[[1]] %||% 240L))
iterations <- suppressWarnings(as.integer(args[[2]] %||% 5L))
feature_count <- if (is.finite(feature_count) && feature_count > 0L) feature_count else 240L
iterations <- if (is.finite(iterations) && iterations > 0L) iterations else 5L

source(file.path(root_dir, "global.R"), local = .GlobalEnv)
app_env <- as.environment("app_libraries")

required <- c("create_gene_plot", "extract_sequence_from_fasta")
missing <- required[!vapply(required, exists, logical(1), envir = app_env, inherits = FALSE)]
if (length(missing) > 0L) {
    stop("Missing app function(s): ", paste(missing, collapse = ", "))
}

starts <- seq(110L, by = 45L, length.out = feature_count)
ends <- starts + rep(c(18L, 28L, 36L), length.out = feature_count)
feature_types <- rep(c("exon", "CDS", "five_prime_UTR", "three_prime_UTR"), length.out = feature_count)
attrs <- sprintf("ID=feature_%04d;Parent=tx1;Name=Feature%04d", seq_len(feature_count), seq_len(feature_count))

df <- data.frame(
    y = rep(1, feature_count),
    xstart = starts,
    xend = ends,
    group = factor(tolower(feature_types)),
    text = attrs,
    feature_type = feature_types,
    seqid = rep("chr1", feature_count),
    source = rep("benchmark", feature_count),
    feature_raw = feature_types,
    score = rep(".", feature_count),
    strand = rep("+", feature_count),
    phase = rep(".", feature_count),
    attributes_raw = attrs,
    largo = ends - starts + 1L,
    stringsAsFactors = FALSE
)

df_gene <- data.frame(
    V1 = "chr1",
    V2 = "benchmark",
    V3 = "gene",
    V4 = min(starts) - 100L,
    V5 = max(ends) + 100L,
    V6 = ".",
    V7 = "+",
    V8 = ".",
    V9 = "ID=gene1;Name=BENCH1",
    largo = max(ends) - min(starts) + 201L,
    stringsAsFactors = FALSE
)

df_tx <- data.frame(
    V1 = "chr1",
    V2 = "benchmark",
    V3 = "mRNA",
    V4 = min(starts) - 100L,
    V5 = max(ends) + 100L,
    V6 = ".",
    V7 = "+",
    V8 = ".",
    V9 = "ID=tx1;Parent=gene1",
    stringsAsFactors = FALSE
)

extract_calls <- 0L
mock_extract_sequence <- function(...) {
    extract_calls <<- extract_calls + 1L
    paste(rep("ATGC", ceiling((max(ends) - min(starts) + 1L) / 4L)), collapse = "")
}

tmp_fasta <- tempfile(fileext = ".fa")
writeLines(c(">chr1", paste(rep("ATGC", ceiling((max(ends) + 200L) / 4L)), collapse = "")), tmp_fasta)
on.exit(unlink(tmp_fasta), add = TRUE)

create_gene_plot <- get("create_gene_plot", envir = app_env, inherits = FALSE)
patch_envs <- list(app_env, environment(create_gene_plot))
patch_envs <- patch_envs[!vapply(patch_envs, is.null, logical(1))]
patch_envs <- patch_envs[!duplicated(vapply(patch_envs, function(env) {
    sprintf("%s:%s", environmentName(env), capture.output(print(env))[1])
}, character(1)))]
original_extracts <- lapply(patch_envs, function(env) {
    if (exists("extract_sequence_from_fasta", envir = env, inherits = FALSE)) {
        get("extract_sequence_from_fasta", envir = env, inherits = FALSE)
    } else {
        NULL
    }
})
for (env in patch_envs) {
    assign("extract_sequence_from_fasta", mock_extract_sequence, envir = env)
}
on.exit({
    for (i in seq_along(patch_envs)) {
        original <- original_extracts[[i]]
        if (is.null(original)) {
            if (exists("extract_sequence_from_fasta", envir = patch_envs[[i]], inherits = FALSE)) {
                rm("extract_sequence_from_fasta", envir = patch_envs[[i]])
            }
        } else {
            assign("extract_sequence_from_fasta", original, envir = patch_envs[[i]])
        }
    }
}, add = TRUE)

run_case <- function(mode, with_fasta) {
    extract_before <- extract_calls
    times <- numeric(iterations)
    for (i in seq_len(iterations)) {
        elapsed <- system.time(invisible(create_gene_plot(
            df = df,
            df_gene = df_gene,
            df_transcript = df_tx,
            current_transcript_length = as.integer(df_gene$V5[1] - df_gene$V4[1] + 1L),
            length_difference = 0,
            composicion_secuencia = "Sequence Composition: N/A",
            gene_length_label = sprintf("Gene Length: %s pb", df_gene$largo[1]),
            transcript_length_label = sprintf("Transcript Length: %s pb", df_gene$largo[1]),
            visual_mode = mode,
            genome_fasta_path = if (with_fasta) tmp_fasta else "",
            plot_id = sprintf("bench_%s_%d", mode, i),
            plot_context = "test"
        )))[["elapsed"]]
        times[[i]] <- as.numeric(elapsed) * 1000
    }
    data.frame(
        mode = mode,
        with_fasta = with_fasta,
        features = feature_count,
        iterations = iterations,
        median_ms = round(stats::median(times), 1),
        min_ms = round(min(times), 1),
        max_ms = round(max(times), 1),
        extract_calls = extract_calls - extract_before,
        stringsAsFactors = FALSE
    )
}

results <- rbind(
    run_case("compact", FALSE),
    run_case("compact", TRUE),
    run_case("detailed", TRUE)
)

print(results, row.names = FALSE)

compact_fasta_calls <- results$extract_calls[results$mode == "compact" & results$with_fasta]
if (length(compact_fasta_calls) != 1L || compact_fasta_calls != iterations) {
    stop("Compact render should extract one genomic span per render so feature GC remains available.")
}

cat("gene-plot-render-benchmark-ok\n")
