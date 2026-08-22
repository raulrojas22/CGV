library(testthat)

server_path <- "server.R"
if (!file.exists(server_path)) {
    server_path <- file.path("..", "..", "server.R")
}

aligned_correlation_block <- function() {
    server_lines <- readLines(server_path, warn = FALSE)
    pass2_start <- grep(
        "# Pass 2: compute uncached pairs in-process.",
        server_lines,
        fixed = TRUE
    )
    pass3_start <- grep(
        "# Pass 3: assemble pair_corrs",
        server_lines,
        fixed = TRUE
    )

    expect_length(pass2_start, 1L)
    expect_length(pass3_start, 1L)
    expect_gt(pass3_start, pass2_start)

    list(
        lines = server_lines[pass2_start:(pass3_start - 1L)],
        all_lines = server_lines,
        start = pass2_start,
        end = pass3_start - 1L
    )
}

test_that("aligned correlations bypass future global export", {
    block <- aligned_correlation_block()
    block_text <- paste(block$lines, collapse = "\n")

    expect_match(block_text, "computed_list <- lapply\\(uncached_indices", perl = TRUE)
    expect_match(block_text, "schedule=in_process", fixed = TRUE)
    expect_false(grepl("future_map|furrr_options|parallel_corr_fallback", block_text))
})

test_that("in-process aligned correlation keeps order, arguments, and failure isolation", {
    block <- aligned_correlation_block()
    assignment_start <- grep(
        "computed_list <- lapply(uncached_indices, function(k)",
        block$lines,
        fixed = TRUE
    )
    timing_start <- grep(
        "corr_compute_ms <-",
        block$lines,
        fixed = TRUE
    )

    expect_length(assignment_start, 1L)
    expect_length(timing_start, 1L)
    expect_gt(timing_start, assignment_start)

    assignment_lines <- block$lines[assignment_start:(timing_start - 1L)]
    assignment_expr <- parse(text = paste(assignment_lines, collapse = "\n"))
    expect_length(assignment_expr, 1L)

    make_task <- function(label) {
        list(
            df1 = paste0(label, "-df1"),
            df2 = paste0(label, "-df2"),
            df1e = paste0(label, "-df1e"),
            df2e = paste0(label, "-df2e")
        )
    }
    eval_env <- new.env(parent = baseenv())
    eval_env$uncached_indices <- c(3L, 2L, 1L)
    eval_env$uncached_tasks <- list(
        make_task("first"),
        make_task("fails"),
        make_task("third")
    )
    eval_env$local_aligned_mode <- "cds"
    eval_env$fn_corr <- function(df1, df2, df1e, df2e, mode) {
        if (identical(df1, "fails-df1")) {
            stop("expected test failure")
        }
        paste(df1, df2, df1e, df2e, mode, sep = "|")
    }

    eval(assignment_expr[[1L]], envir = eval_env)

    expect_length(eval_env$computed_list, 3L)
    expect_identical(
        eval_env$computed_list[[1L]],
        "third-df1|third-df2|third-df1e|third-df2e|cds"
    )
    expect_null(eval_env$computed_list[[2L]])
    expect_identical(
        eval_env$computed_list[[3L]],
        "first-df1|first-df2|first-df1e|first-df2e|cds"
    )
})
