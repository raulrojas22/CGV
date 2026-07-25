library(testthat)
library(shiny)

`%||%` <- function(x, y) {
    if (is.null(x) || length(x) == 0L) y else x
}

state_helpers_path <- file.path("R", "server_state_helpers_domain.R")
if (!file.exists(state_helpers_path)) {
    state_helpers_path <- file.path("..", "..", "R", "server_state_helpers_domain.R")
}
sys.source(state_helpers_path, envir = environment())

make_state_helpers <- function() {
    init_server_state_helpers_domain(
        autocompleteBuildEpochs_rv = reactiveVal(list()),
        searchRunState_rv = reactiveVal(list())
    )
}

test_that("session restore suppresses intermediate source changes", {
    helpers <- make_state_helpers()

    isolate(helpers$begin_session_source_restore("homologous", "preloaded::human"))

    expect_identical(
        isolate(helpers$consume_session_source_restore("homologous", "preloaded::mouse")),
        "pending"
    )
    expect_identical(
        isolate(helpers$consume_session_source_restore("homologous", "preloaded::human")),
        "complete"
    )
    expect_identical(
        isolate(helpers$consume_session_source_restore("homologous", "preloaded::mouse")),
        "none"
    )
})

test_that("source restore guards are independent per workflow", {
    helpers <- make_state_helpers()

    isolate({
        helpers$begin_session_source_restore("homologous", "preloaded::human")
        helpers$begin_session_source_restore("orthologous", "preloaded::human|mouse")
    })

    expect_identical(
        isolate(helpers$consume_session_source_restore("homologous", "preloaded::human")),
        "complete"
    )
    expect_identical(
        isolate(helpers$consume_session_source_restore("orthologous", "preloaded::human")),
        "pending"
    )
    expect_identical(
        isolate(helpers$consume_session_source_restore("orthologous", "preloaded::human|mouse")),
        "complete"
    )
})

test_that("client acknowledgement releases a source guard with a non-restorable key", {
    helpers <- make_state_helpers()

    isolate(helpers$begin_session_source_restore("homologous", "upload::"))
    expect_identical(
        isolate(helpers$consume_session_source_restore("homologous", "upload::temporary-file")),
        "pending"
    )
    expect_true(isolate(helpers$finish_session_source_restore("homologous")))
    expect_identical(
        isolate(helpers$consume_session_source_restore("homologous", "upload::temporary-file")),
        "none"
    )
})
