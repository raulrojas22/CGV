testthat::test_that("card registration defaults to progressive one-card batches", {
    server_path <- testthat::test_path("..", "..", "server.R")
    env_path <- testthat::test_path("..", "..", ".env.example")
    server_txt <- paste(readLines(server_path, warn = FALSE), collapse = "\n")
    env_txt <- readLines(env_path, warn = FALSE)

    testthat::expect_match(
        server_txt,
        "cardRegistrationSafetyCap <- 256L",
        fixed = TRUE
    )
    testthat::expect_match(
        server_txt,
        'parse_positive_int_env("APP_HOMO_INITIAL_VISIBLE", 1L)',
        fixed = TRUE
    )
    testthat::expect_match(
        server_txt,
        'parse_positive_int_env("APP_ORTHO_RENDER_CHUNK_SIZE", 1L)',
        fixed = TRUE
    )
    testthat::expect_match(
        server_txt,
        'Sys.getenv("APP_ORTHO_AUTO_RENDER_MORE", "1") %||% "1"',
        fixed = TRUE
    )
    testthat::expect_match(
        server_txt,
        'Sys.getenv("APP_ORTHO_AUTO_RENDER_DELAY_MS", "120")',
        fixed = TRUE
    )
    testthat::expect_match(
        server_txt,
        'parse_positive_int_env("APP_ORTHO_INITIAL_VISIBLE", 1L)',
        fixed = TRUE
    )
    testthat::expect_match(
        server_txt,
        'parse_positive_int_env("APP_HOMO_RENDER_CHUNK_SIZE", 1L)',
        fixed = TRUE
    )
    testthat::expect_false(grepl(
        'min(orthoRenderChunkSize, parse_positive_int_env("APP_ORTHO_INITIAL_VISIBLE"',
        server_txt,
        fixed = TRUE
    ))

    for (expected in c(
        "APP_HOMO_RENDER_CHUNK_SIZE=1",
        "APP_HOMO_AUTO_RENDER_DELAY_MS=120",
        "APP_ORTHO_RENDER_CHUNK_SIZE=1",
        "APP_ORTHO_AUTO_RENDER_MORE=1",
        "APP_ORTHO_AUTO_RENDER_DELAY_MS=120",
        "APP_ORTHO_SERVER_RENDER_NUDGE=0",
        "APP_HOMO_DEFER_SEQUENCE=0",
        "APP_ORTHO_DEFER_SEQUENCE=0",
        "APP_FOOTER_DEFER_SEQUENCE=0",
        "APP_DEFER_FEATURE_GC=0",
        "APP_HOMO_INITIAL_VISIBLE=1",
        "APP_ORTHO_INITIAL_VISIBLE=1",
        "APP_ISOFORM_RENDER_BATCH_SIZE=1",
        "APP_ISOFORM_RENDER_BATCH_DELAY_MS=2500"
    )) {
        testthat::expect_true(expected %in% env_txt, info = expected)
    }
})

testthat::test_that("hidden Alignment work remains lazy in compact mode", {
    server_path <- testthat::test_path("..", "..", "server.R")
    server_txt <- paste(readLines(server_path, warn = FALSE), collapse = "\n")

    representative_start <- regexpr(
        "alignedRepresentativePlotIdsOrthologous <- reactive({",
        server_txt,
        fixed = TRUE
    )[[1L]]
    auto_start <- regexpr(
        "autoAlignedOrderedPlotIdsOrthologous <- reactive({",
        server_txt,
        fixed = TRUE
    )[[1L]]
    ordered_start <- regexpr(
        "alignedOrderedPlotIdsOrthologous <- reactive({",
        server_txt,
        fixed = TRUE
    )[[1L]]
    pip_start <- regexpr("pipReferencePlotIdOrthologous <- reactive({", server_txt, fixed = TRUE)[[1L]]

    testthat::expect_gt(representative_start, 0L)
    testthat::expect_gt(auto_start, representative_start)
    testthat::expect_gt(ordered_start, auto_start)
    testthat::expect_gt(pip_start, ordered_start)

    representative_scope <- substr(server_txt, representative_start, auto_start - 1L)
    auto_scope <- substr(server_txt, auto_start, ordered_start - 1L)
    ordered_scope <- substr(server_txt, ordered_start, pip_start - 1L)

    for (scope in list(representative_scope, auto_scope, ordered_scope)) {
        testthat::expect_match(scope, 'input$ortho_visual_mode %||% "compact"', fixed = TRUE)
        testthat::expect_match(scope, 'if (!identical(current_mode, "aligned"))', fixed = TRUE)
        testthat::expect_match(scope, "return(ids)", fixed = TRUE)
    }

    guard_pos <- regexpr('if (!identical(current_mode, "aligned"))', auto_scope, fixed = TRUE)[[1L]]
    payload_pos <- regexpr("get_cached_aligned_track_payload", auto_scope, fixed = TRUE)[[1L]]
    correspondence_pos <- regexpr("compute_protein_guided_correspondence", auto_scope, fixed = TRUE)[[1L]]
    testthat::expect_gt(payload_pos, guard_pos)
    testthat::expect_gt(correspondence_pos, guard_pos)

    footer_start <- regexpr("output$ortho_aligned_footer <-", server_txt, fixed = TRUE)[[1L]]
    footer_end <- regexpr(
        'outputOptions(output, "ortho_aligned_footer"',
        server_txt,
        fixed = TRUE
    )[[1L]]
    testthat::expect_gt(footer_start, 0L)
    testthat::expect_gt(footer_end, footer_start)
    footer_scope <- substr(server_txt, footer_start, footer_end - 1L)
    mode_pos <- regexpr("input$ortho_visual_mode", footer_scope, fixed = TRUE)[[1L]]
    ids_pos <- regexpr("alignedOrderedPlotIdsOrthologous()", footer_scope, fixed = TRUE)[[1L]]
    testthat::expect_gt(mode_pos, 0L)
    testthat::expect_gt(ids_pos, mode_pos)

    testthat::expect_match(
        server_txt,
        'Sys.getenv("APP_ORTHO_SUSPEND_HIDDEN", "1") %||% "1"',
        fixed = TRUE
    )
})
