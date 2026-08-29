library(testthat)
library(shiny)

`%||%` <- function(x, y) {
    if (is.null(x) || length(x) == 0L) y else x
}

state_helpers_path <- file.path("R", "server_state_helpers_domain.R")
server_path <- "server.R"
if (!file.exists(state_helpers_path)) {
    state_helpers_path <- file.path("..", "..", "R", "server_state_helpers_domain.R")
    server_path <- file.path("..", "..", "server.R")
}
sys.source(state_helpers_path, envir = environment())

make_state_helpers <- function() {
    init_server_state_helpers_domain(
        autocompleteBuildEpochs_rv = reactiveVal(list()),
        searchRunState_rv = reactiveVal(list())
    )
}

test_that("first-paint gate rejects stale and duplicate releases", {
    helpers <- make_state_helpers()
    gate <- helpers$new_ortho_first_paint_gate(
        run_id = "ORTHO_A",
        enabled = TRUE,
        previous_token = 8L
    )

    expect_true(gate$enabled)
    expect_false(gate$armed)
    expect_false(gate$released)
    expect_identical(gate$token, 9L)

    stale_arm <- helpers$arm_ortho_first_paint_gate(gate, "ORTHO_OLD")
    expect_false(stale_arm$changed)

    armed <- helpers$arm_ortho_first_paint_gate(gate, "ORTHO_A")
    expect_true(armed$changed)
    expect_true(armed$state$armed)

    stale_release <- helpers$release_ortho_first_paint_gate(
        armed$state,
        run_id = "ORTHO_OLD",
        reason = "timeout"
    )
    expect_false(stale_release$changed)
    expect_false(stale_release$state$released)

    painted <- helpers$release_ortho_first_paint_gate(
        armed$state,
        run_id = "ORTHO_A",
        reason = "browser_paint",
        output_id = "plot_ortho_1-plot"
    )
    expect_true(painted$changed)
    expect_true(painted$state$released)
    expect_identical(painted$state$release_reason, "browser_paint")
    expect_identical(painted$state$output_id, "plot_ortho_1-plot")

    duplicate <- helpers$release_ortho_first_paint_gate(
        painted$state,
        run_id = "ORTHO_A",
        reason = "timeout"
    )
    expect_false(duplicate$changed)
    expect_identical(duplicate$state$release_reason, "browser_paint")
})

test_that("a run without expected plots never closes the gate", {
    helpers <- make_state_helpers()
    pending <- helpers$new_ortho_first_paint_gate(
        run_id = "ORTHO_EMPTY",
        enabled = FALSE,
        previous_token = 3L
    )

    expect_false(pending$enabled)
    expect_true(pending$released)
    expect_false(helpers$arm_ortho_first_paint_gate(pending, "ORTHO_EMPTY")$changed)

    server_txt <- paste(readLines(server_path, warn = FALSE), collapse = "\n")
    expect_match(server_txt, "enabled = FALSE,\n            previous_token = previous$token", fixed = TRUE)
    expect_match(server_txt, "isTRUE(functional_first_paint) && isTRUE(visible_expected_is_new)", fixed = TRUE)
    expect_match(server_txt, "awaiting_expected_plot", fixed = TRUE)
    expect_match(server_txt, "ortho_search_active", fixed = TRUE)
})

test_that("sorted, rescue, and one-result fixtures follow the gate contract", {
    should_gate <- function(sorted_primary, added_ids, current_visible = 1L) {
        expected <- if (length(added_ids) > 0L) head(sorted_primary, 1L) else character(0)
        length(sorted_primary) > current_visible &&
            length(expected) > 0L &&
            expected[[1L]] %in% added_ids
    }

    expect_true(should_gate(
        sorted_primary = c("new_b", "new_a"),
        added_ids = c("new_a", "new_b")
    ))
    expect_false(should_gate(
        sorted_primary = c("old_1", "new_rescue"),
        added_ids = "new_rescue"
    ))
    expect_false(should_gate(
        sorted_primary = "only_new",
        added_ids = "only_new"
    ))

    server_txt <- paste(readLines(server_path, warn = FALSE), collapse = "\n")
    expect_match(
        server_txt,
        "if (length(added_plot_ids) > 0L) {\n                            isolate(as.character(primaryPlotIdsOrthologous() %||% character(0)))",
        fixed = TRUE
    )
    expect_match(server_txt, "visible_expected_is_new", fixed = TRUE)
    expect_match(server_txt, "gate_expected_ids = initial_plot_timing_ids(", fixed = TRUE)
    expect_match(server_txt, "gate_candidate_ids = added_plot_ids", fixed = TRUE)
})

test_that("functional gate targets stay separate from full performance telemetry", {
    server_txt <- paste(readLines(server_path, warn = FALSE), collapse = "\n")
    expect_match(server_txt, "tr$expected <- ids_chr", fixed = TRUE)
    expect_match(server_txt, "tr$gate_expected <- gate_ids_chr", fixed = TRUE)
    expect_match(
        server_txt,
        "browser_expected_ids <- if (isTRUE(app_perf_enabled()) || isTRUE(functional_progressive)) ids_chr else gate_ids_chr",
        fixed = TRUE
    )
    expect_match(server_txt, "timing_tracker$gate_expected", fixed = TRUE)
    expect_match(server_txt, "orthoPlotTimingTracker()$gate_expected", fixed = TRUE)
})

test_that("a single visible result does not enable a gate with no secondary work", {
    server_txt <- paste(readLines(server_path, warn = FALSE), collapse = "\n")
    expect_match(
        server_txt,
        "if (primary_count <= current_visible) {\n            return(invisible(FALSE))",
        fixed = TRUE
    )
    expect_match(server_txt, "functional_gate_active <- FALSE", fixed = TRUE)
    expect_match(
        server_txt,
        "if (isTRUE(app_perf_enabled()) || isTRUE(functional_gate_active) || isTRUE(functional_progressive))",
        fixed = TRUE
    )
    expect_match(server_txt, 'reason = "activation_timeout"', fixed = TRUE)
    expect_match(server_txt, 'reason = "no_secondary_results"', fixed = TRUE)
    expect_match(server_txt, 'reason = "non_card_visual_mode"', fixed = TRUE)
    expect_match(server_txt, 'visual_mode %in% c("aligned", "pip", "pip_blocks", "pip_multipip")', fixed = TRUE)
    expect_match(server_txt, "orthoPlotTimingTracker()$gate_expected", fixed = TRUE)
    expect_match(server_txt, "primaryPlotIdsOrthologous()", fixed = TRUE)
    expect_match(server_txt, 'reason = "visible_target_changed"', fixed = TRUE)
})

test_that("automatic expansion waits for paint but manual loading remains direct", {
    server_txt <- paste(readLines(server_path, warn = FALSE), collapse = "\n")
    auto_start <- regexpr("observe({\n\t        if (!isTRUE(orthoAutoRenderMore)", server_txt, fixed = TRUE)[[1L]]
    expect_gt(auto_start, 0L)
    auto_tail <- substr(server_txt, auto_start, nchar(server_txt))
    auto_end <- regexpr("output$ortho_aligned_mode_hint", auto_tail, fixed = TRUE)[[1L]]
    expect_gt(auto_end, 0L)
    auto_scope <- substr(auto_tail, 1L, auto_end - 1L)
    expect_match(auto_scope, "!isTRUE(first_paint_gate$released)", fixed = TRUE)
    expect_match(auto_scope, "arm_ortho_first_paint_timeout", fixed = TRUE)
    expect_match(auto_scope, "return(invisible(NULL))", fixed = TRUE)
    expect_match(auto_scope, "scheduled_gate_token", fixed = TRUE)
    expect_match(auto_scope, "scheduled_generation", fixed = TRUE)
    expect_match(auto_scope, "same_ids <- identical", fixed = TRUE)
    expect_match(auto_scope, "same_generation <- identical", fixed = TRUE)
    expect_match(
        server_txt,
        "orthoInitialVisibleCount <- if (isTRUE(orthoAutoRenderMore)) 1L else configuredOrthoInitialVisibleCount",
        fixed = TRUE
    )

    manual_start <- regexpr("observeEvent(input$ortho_load_more", server_txt, fixed = TRUE)[[1L]]
    expect_gt(manual_start, 0L)
    manual_scope <- substr(server_txt, manual_start, manual_start + 700L)
    expect_match(manual_scope, "orthoVisibleCount(min(ids_n, current_n + orthoRenderChunkSize))", fixed = TRUE)
    expect_false(grepl("first_paint_gate", manual_scope, fixed = TRUE))
})

test_that("deferred external rescue IDs keep the standard card binding path", {
    server_txt <- paste(readLines(server_path, warn = FALSE), collapse = "\n")
    append_start <- regexpr("append_orthologous_cards_dom <- function", server_txt, fixed = TRUE)[[1L]]
    expect_gt(append_start, 0L)
    append_tail <- substr(server_txt, append_start, nchar(server_txt))
    append_end <- regexpr("observeEvent(orthoRenderedPlotIds()", append_tail, fixed = TRUE)[[1L]]
    expect_gt(append_end, 0L)
    append_scope <- substr(append_tail, 1L, append_end - 1L)

    expect_match(append_scope, "instantiate_orthologous_plot_module", fixed = TRUE)
    expect_match(append_scope, "bind_orthologous_footer_output", fixed = TRUE)
    expect_match(append_scope, "register_orthologous_download_output", fixed = TRUE)
    expect_match(server_txt, "append_orthologous_cards_dom(append_ids)", fixed = TRUE)
    expect_match(server_txt, "delegated to progressive scheduler", fixed = TRUE)
})
