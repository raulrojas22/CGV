#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x)) y else x
source(file.path("R", "server_source_history_domain.R"))

history <- init_source_history_store(max_entries = 2L)

stopifnot(history$size() == 0L)
stopifnot(is.null(history$get("missing")))

history$put("preloaded::human", list(ids = "1"))
history$put("upload::sample", list(ids = "2"))
stopifnot(identical(history$keys(), c("preloaded::human", "upload::sample")))

# Reading an entry makes it the most recently used one.
stopifnot(identical(history$get("preloaded::human")$ids, "1"))
history$put("ncbi::GCF_001", list(ids = "3"))
stopifnot(is.null(history$get("upload::sample")))
stopifnot(identical(history$keys(), c("preloaded::human", "ncbi::GCF_001")))

# Replacing and removing an entry must not resurrect stale plot state.
history$put("preloaded::human", list(ids = c("1", "4")))
stopifnot(identical(history$get("preloaded::human")$ids, c("1", "4")))
history$put("preloaded::human", NULL)
stopifnot(is.null(history$get("preloaded::human")))
stopifnot(history$size() == 1L)

history$clear()
stopifnot(history$size() == 0L, length(history$keys()) == 0L)

cat("source history store: OK\n")
