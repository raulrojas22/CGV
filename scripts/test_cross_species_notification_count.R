#!/usr/bin/env Rscript

server_txt <- paste(
  readLines("server.R", warn = FALSE, encoding = "UTF-8"),
  collapse = "\n"
)

stopifnot(
  grepl("plotted_count_before_result <- plotted_count", server_txt, fixed = TRUE),
  grepl("plotted_count > plotted_count_before_result", server_txt, fixed = TRUE),
  !grepl("file_plotted_this_result", server_txt, fixed = TRUE),
  grepl("plotted_organism_count <- length(unique(plotted_file_indices))", server_txt, fixed = TRUE)
)

# Regression model: mirror the nested function plus shiny::isolate() scope from
# the real workflow. Transcript totals may vary, but the notification threshold
# must count every organism that contributed at least one new plot.
count_plotted_organisms <- function(plots_added_by_organism) {
  plotted_file_indices <- integer(0L)
  plotted_count <- 0L

  process_results <- function() {
    for (j in seq_along(plots_added_by_organism)) {
      plotted_count_before_result <- plotted_count
      shiny::isolate({
        for (plot_idx in seq_len(plots_added_by_organism[[j]])) {
          plotted_count <<- plotted_count + 1L
        }
      })
      if (plotted_count > plotted_count_before_result) {
        plotted_file_indices <<- unique(c(plotted_file_indices, j))
      }
    }
  }
  process_results()

  list(
    plotted_count = plotted_count,
    plotted_file_indices = plotted_file_indices
  )
}

result <- count_plotted_organisms(c(5L, 4L, 5L, 4L))

stopifnot(
  identical(result$plotted_count, 18L),
  identical(length(result$plotted_file_indices), 4L),
  length(result$plotted_file_indices) >= 2L
)

message("Cross-Species completion notifications count plotted organisms correctly.")
