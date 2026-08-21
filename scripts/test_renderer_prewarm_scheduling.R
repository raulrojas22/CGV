#!/usr/bin/env Rscript

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

server_text <- read_text("server.R")
env_text <- read_text(".env.example")

warm_start <- regexpr("warm_gene_plot_renderer_once <- function", server_text, fixed = TRUE)[[1L]]
warm_end <- regexpr("sanitize_girafe_tooltip_text <- function", server_text, fixed = TRUE)[[1L]]
stopifnot(warm_start > 0L, warm_end > warm_start)
warm_block <- substr(server_text, warm_start, warm_end - 1L)

stopifnot(
  grepl('session$onFlushed(function() {', warm_block, fixed = TRUE),
  grepl('once = TRUE', warm_block, fixed = TRUE),
  grepl('APP_GENE_PLOT_RENDERER_PREWARM_DELAY_MS', warm_block, fixed = TRUE),
  grepl('delay = renderer_prewarm_delay_ms / 1000', warm_block, fixed = TRUE),
  grepl('warm_gene_plot_renderer_once()', warm_block, fixed = TRUE),
  !grepl('}, delay = 0.15)', warm_block, fixed = TRUE),
  grepl('APP_GENE_PLOT_RENDERER_PREWARM=1', env_text, fixed = TRUE),
  grepl('APP_GENE_PLOT_RENDERER_PREWARM_DELAY_MS=1000', env_text, fixed = TRUE)
)

message("renderer-prewarm-scheduling-ok")
