read_text <- function(path) {
    paste(readLines(path, warn = FALSE), collapse = "\n")
}

server_txt <- read_text("server.R")
modules_txt <- read_text(file.path("R", "modules.R"))
popup_txt <- read_text(file.path("www", "js", "genomic_neighbor_popup.js"))

stopifnot(grepl(
    "if \\(identical\\(source_panel, \"orthologous\"\\)\\)[[:space:]]*\\{",
    server_txt,
    perl = TRUE
))
stopifnot(grepl(
    "adding them below is available only in Multi-Gene Search",
    server_txt,
    fixed = TRUE
))
stopifnot(grepl(
    "genomic_neighbor_action_hint <- if \\(tolower\\(plot_context_txt\\)",
    modules_txt,
    perl = TRUE
))
stopifnot(grepl(
    "Adding it below is available only in Multi-Gene Search",
    modules_txt,
    fixed = TRUE
))
stopifnot(grepl("function isMultiGenePanel\\(panel\\)", popup_txt, perl = TRUE))
stopifnot(grepl("button.hidden = !canVisualizeBelow", popup_txt, fixed = TRUE))
stopifnot(grepl("if \\(!isMultiGenePanel\\(payload.panel\\)\\)", popup_txt, perl = TRUE))

cat("genomic-neighbor-multigene-scope-static-ok\n")
