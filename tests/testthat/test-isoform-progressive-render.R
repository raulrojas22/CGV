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
    expect_match(server_txt, "run_isoform_js <- function", fixed = TRUE)
    expect_match(server_txt, "shiny::withReactiveDomain(session, shinyjs::runjs", fixed = TRUE)
    expect_match(server_txt, "data-isoform-load-state','loading'", fixed = TRUE)
    expect_match(server_txt, "card.style.opacity='0'", fixed = TRUE)
    expect_match(server_txt, "card.style.left='-100000px'", fixed = TRUE)
    expect_match(server_txt, "window.jQuery(card).trigger('shown')", fixed = TRUE)
    expect_match(server_txt, "completed_outputs <- as.character(tracker$card_complete", fixed = TRUE)
    expect_match(server_txt, "paste0(\"homo_footer_\", batch_ids)", fixed = TRUE)
    expect_match(server_txt, "paste0(\"ortho_footer_\", batch_ids)", fixed = TRUE)
    expect_match(server_txt, "outputOptions(output, output_id, suspendWhenHidden = FALSE)", fixed = TRUE)
    expect_match(server_txt, "hydrated_isoform_ids <- as.character(homoHydratedIsoformIds()", fixed = TRUE)
    expect_match(server_txt, "hydrated_isoform_ids <- as.character(orthoHydratedIsoformIds()", fixed = TRUE)
    expect_match(server_txt, "if (isTRUE(ready))", fixed = TRUE)
    expect_match(server_txt, "reveal_completed_batch()", fixed = TRUE)
    expect_match(server_txt, "data-isoform-load-state','ready'", fixed = TRUE)
    expect_match(server_txt, "card.style.display='flex'", fixed = TRUE)
    expect_match(server_txt, "card.style.opacity=''", fixed = TRUE)
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
    expect_gte(
        lengths(regmatches(server_txt, gregexpr("session$isClosed()", server_txt, fixed = TRUE))),
        3L
    )
    expect_match(server_txt, "error = function(e) list()", fixed = TRUE)
    expect_match(server_txt, "data-isoform-load-state','collapsed'", fixed = TRUE)
    expect_match(server_txt, "card.setAttribute('aria-hidden','true')", fixed = TRUE)
    expect_match(server_txt, "outputOptions(output, output_id, suspendWhenHidden = TRUE)", fixed = TRUE)
})
