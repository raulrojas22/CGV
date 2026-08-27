library(testthat)

server_path <- "server.R"
if (!file.exists(server_path)) {
    server_path <- file.path("..", "..", "server.R")
}

test_that("aligned fast path updates geometry modes in its render scope", {
    server_lines <- readLines(server_path, warn = FALSE)
    fast_scope_start <- grep(
        'track_geometry_modes <- rep("exon", length(ids_chr))',
        server_lines,
        fixed = TRUE
    )
    expect_length(fast_scope_start, 1L)

    fast_scope_idx <- fast_scope_start:min(
        length(server_lines),
        fast_scope_start + 100L
    )
    assignment_idx <- fast_scope_idx[grep(
        "track_geometry_modes[i] <- geom_mode_i",
        server_lines[fast_scope_idx],
        fixed = TRUE
    )]

    expect_length(assignment_idx, 1L)
    expect_false(any(grepl(
        "track_geometry_modes[i] <<- geom_mode_i",
        server_lines[fast_scope_idx],
        fixed = TRUE
    )))

    assignment <- trimws(server_lines[[assignment_idx]])
    render_scope <- new.env(parent = baseenv())
    render_scope$track_geometry_modes <- rep("exon", 2L)
    render_scope$i <- 2L
    render_scope$geom_mode_i <- "cds"

    eval(parse(text = assignment), envir = render_scope)

    expect_identical(render_scope$track_geometry_modes, c("exon", "cds"))

    scene_tail <- server_lines[
        assignment_idx:min(length(server_lines), assignment_idx + 500L)
    ]
    expect_true(any(grepl(
        "track_geometry_modes = track_geometry_modes",
        scene_tail,
        fixed = TRUE
    )))
})
