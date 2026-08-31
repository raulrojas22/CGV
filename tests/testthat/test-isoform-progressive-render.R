library(testthat)

resolve_project_file <- function(...) {
    direct <- file.path(...)
    if (file.exists(direct)) direct else file.path("..", "..", ...)
}

test_that("isoform expansion reveals one scientifically complete batch at a time", {
    server_txt <- paste(
        readLines(resolve_project_file("server.R"), warn = FALSE),
        collapse = "\n"
    )

    expect_match(server_txt, "schedule_isoform_module_batches <- function", fixed = TRUE)
    expect_match(server_txt, "data-isoform-load-state','loading'", fixed = TRUE)
    expect_match(server_txt, "card.style.display='none'", fixed = TRUE)
    expect_match(server_txt, "completed_outputs <- as.character(tracker$card_complete", fixed = TRUE)
    expect_match(server_txt, "if (isTRUE(ready))", fixed = TRUE)
    expect_match(server_txt, "reveal_completed_batch()", fixed = TRUE)
    expect_match(server_txt, "data-isoform-load-state','ready'", fixed = TRUE)
    expect_match(server_txt, "card.style.display='flex'", fixed = TRUE)
    expect_match(server_txt, "later::later(function() render_batch(next_index)", fixed = TRUE)
})

test_that("real alternative transcripts render before canonical copies", {
    server_txt <- paste(
        readLines(resolve_project_file("server.R"), warn = FALSE),
        collapse = "\n"
    )

    expect_match(server_txt, "unique(c(regular_ids, copy_ids))", fixed = TRUE)
    expect_match(server_txt, "unique(c(regular_iso_ids_h, copy_ids_h))", fixed = TRUE)
    expect_match(server_txt, "expanded_ids[order(copy_rank_o, seq_along(expanded_ids))]", fixed = TRUE)
})

test_that("collapsing an isoform group cancels later batches", {
    server_txt <- paste(
        readLines(resolve_project_file("server.R"), warn = FALSE),
        collapse = "\n"
    )

    expect_match(server_txt, "if (!isTRUE(expanded_state[[toggle_key]])) return", fixed = TRUE)
    expect_match(server_txt, "data-isoform-load-state','collapsed'", fixed = TRUE)
    expect_match(server_txt, "card.setAttribute('aria-hidden','true')", fixed = TRUE)
})
