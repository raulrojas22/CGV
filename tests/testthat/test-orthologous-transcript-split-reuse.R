library(testthat)

utils_path <- file.path("R", "utils.R")
server_path <- "server.R"
if (!file.exists(utils_path)) {
    utils_path <- file.path("..", "..", "R", "utils.R")
    server_path <- file.path("..", "..", "server.R")
}

utils_env <- new.env(parent = globalenv())
sys.source(utils_path, envir = utils_env)

make_transcript_fixture <- function(gene_id) {
    data.frame(
        V1 = rep("chr1", 7L),
        V2 = rep("fixture", 7L),
        V3 = c("gene", "mRNA", "exon", "CDS", "mRNA", "exon", "CDS"),
        V4 = c(1L, 1L, 1L, 50L, 1L, 1L, 300L),
        V5 = c(500L, 200L, 100L, 150L, 500L, 120L, 500L),
        V6 = rep(".", 7L),
        V7 = rep("+", 7L),
        V8 = rep(".", 7L),
        V9 = c(
            sprintf("ID=gene-%s;Name=%s", gene_id, gene_id),
            sprintf("ID=rna-%s-1;Parent=gene-%s", gene_id, gene_id),
            sprintf("ID=exon-%s-1;Parent=rna-%s-1", gene_id, gene_id),
            sprintf("ID=cds-%s-1;Parent=rna-%s-1", gene_id, gene_id),
            sprintf("ID=rna-%s-2;Parent=gene-%s", gene_id, gene_id),
            sprintf("ID=exon-%s-2;Parent=rna-%s-2", gene_id, gene_id),
            sprintf("ID=cds-%s-2;Parent=rna-%s-2", gene_id, gene_id)
        ),
        stringsAsFactors = FALSE
    )
}

test_that("orthologous transcript splits run once per found result and remain identical", {
    data_a <- make_transcript_fixture("GENEA")
    data_b <- make_transcript_fixture("GENEB")
    results <- list(
        list(found = TRUE, data = data_a),
        list(found = FALSE, data = NULL),
        list(found = TRUE, data = data_b)
    )
    found_idx <- c(1L, 3L)
    expected <- lapply(found_idx, function(idx) {
        utils_env$split_gene_data_by_transcript(results[[idx]]$data)
    })

    counter <- new.env(parent = emptyenv())
    counter$n <- 0L
    counting_split <- function(data) {
        counter$n <- counter$n + 1L
        utils_env$split_gene_data_by_transcript(data)
    }
    prepared <- utils_env$prepare_orthologous_transcript_splits_once(
        results,
        split_fun = counting_split
    )

    expect_identical(counter$n, length(found_idx))
    expect_null(prepared[[2L]])
    expect_true(all(vapply(prepared[found_idx], function(item) isTRUE(item$reusable), logical(1))))
    actual <- lapply(found_idx, function(idx) prepared[[idx]]$blocks)
    expect_identical(actual, expected)
})

test_that("orthologous split prepass preserves empty and error fallbacks", {
    data <- make_transcript_fixture("FALLBACK")
    results <- list(list(found = TRUE, data = data))

    empty_split <- utils_env$prepare_orthologous_transcript_splits_once(
        results,
        split_fun = function(data) list()
    )[[1L]]
    expect_true(empty_split$reusable)
    expect_identical(empty_split$blocks, list(data))

    failed_split <- utils_env$prepare_orthologous_transcript_splits_once(
        results,
        split_fun = function(data) stop("fixture split failure")
    )[[1L]]
    expect_false(failed_split$reusable)
    expect_identical(failed_split$blocks, list(data))
})

test_that("the orthologous processor reuses successful prepass blocks", {
    server_txt <- paste(readLines(server_path, warn = FALSE), collapse = "\n")
    start <- regexpr("process_orthologous_lookup_results <- function", server_txt, fixed = TRUE)[[1L]]
    expect_gt(start, 0L)
    tail_txt <- substring(server_txt, start)
    finish_offset <- regexpr("finish_orthologous_local_phase <- function", tail_txt, fixed = TRUE)[[1L]]
    expect_gt(finish_offset, 0L)
    processor_txt <- substring(tail_txt, 1L, finish_offset - 1L)

    expect_match(
        processor_txt,
        "phase_transcript_splits <- prepare_orthologous_transcript_splits_once(results)",
        fixed = TRUE
    )
    expect_match(
        processor_txt,
        "is.list(prepared_split) && isTRUE(prepared_split$reusable)",
        fixed = TRUE
    )
    expect_match(
        processor_txt,
        "phase_transcript_splits[res_idx] <- list(NULL)",
        fixed = TRUE
    )
    direct_calls <- gregexpr(
        "split_gene_data_by_transcript(data)",
        processor_txt,
        fixed = TRUE
    )[[1L]]
    expect_identical(sum(direct_calls > 0L), 1L)
})
