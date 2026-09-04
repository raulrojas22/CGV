#!/usr/bin/env Rscript

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

server_txt <- read_text("server.R")
utils_txt <- read_text(file.path("R", "utils.R"))
env_txt <- read_text(".env.example")
scss_txt <- read_text(file.path("www", "css", "custom.scss"))
compiled_css_txt <- read_text(file.path("www", "css", "cgv_compiled.css"))
layout_js_txt <- read_text(file.path("www", "js", "summary_context_layout.js"))

stopifnot(
  grepl('class = "summary-cross-species-scope"', server_txt, fixed = TRUE),
  grepl('class = "summary-cross-species-scope-trigger"', server_txt, fixed = TRUE),
  grepl('"About results"', server_txt, fixed = TRUE),
  grepl("APP_ORTHO_REQUIRE_VERIFIED_ORTHOLOGY", utils_txt, fixed = TRUE),
  grepl("APP_ORTHO_REQUIRE_VERIFIED_ORTHOLOGY=0", env_txt, fixed = TRUE),
  grepl("cross_species_requires_verified_orthology", server_txt, fixed = TRUE),
  grepl("shows only a group supported by explicit one-to-one Ensembl Compara orthology", server_txt, fixed = TRUE),
  grepl("these local matches are not a claim of verified one-to-one orthology", server_txt, fixed = TRUE),
  grepl(
    'if \\(isTRUE\\(cross_species_requires_verified_orthology\\(\\)\\)\\) \\{[\\s\\S]{0,300}Cross-Species first resolves local loci[\\s\\S]{0,500}these local matches are not a claim',
    server_txt,
    perl = TRUE
  ),
  grepl("There may be additional family members in each organism.", server_txt, fixed = TRUE),
  !grepl("summary-cross-species-scope-notice", server_txt, fixed = TRUE),
  !grepl("summary-cross-species-scope-notice", scss_txt, fixed = TRUE),
  !grepl("summary-cross-species-scope-notice", compiled_css_txt, fixed = TRUE),
  grepl(".summary-cross-species-scope-panel {", scss_txt, fixed = TRUE),
  grepl(".summary-cross-species-scope-panel {", compiled_css_txt, fixed = TRUE),
  grepl("isolation: isolate;", scss_txt, fixed = TRUE),
  grepl("isolation: isolate;", compiled_css_txt, fixed = TRUE),
  grepl(".summary-context-section:has(.summary-cross-species-scope[open]) > .shiny-html-output {", scss_txt, fixed = TRUE),
  grepl(".summary-context-section:has(.summary-cross-species-scope[open]) > .shiny-html-output {", compiled_css_txt, fixed = TRUE),
  grepl(".summary-context-section:has(.summary-cross-species-scope[open]) > .result-workspace-subheader {", scss_txt, fixed = TRUE),
  grepl(".summary-context-section:has(.summary-cross-species-scope[open]) > .result-workspace-subheader {", compiled_css_txt, fixed = TRUE),
  grepl("closeScopeDisclosures", layout_js_txt, fixed = TRUE),
  grepl("event.key !== 'Escape'", layout_js_txt, fixed = TRUE)
)

message("Cross-Species result scope uses the compact disclosure UI.")
