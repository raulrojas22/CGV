source(file.path("R", "utils.R"), local = TRUE)

assert_true <- function(value, message) {
    if (!isTRUE(value)) stop(message, call. = FALSE)
}

old_value <- Sys.getenv("APP_GENE_CATALOG_ENABLED", unset = NA_character_)
on.exit({
    if (is.na(old_value)) {
        Sys.unsetenv("APP_GENE_CATALOG_ENABLED")
    } else {
        Sys.setenv(APP_GENE_CATALOG_ENABLED = old_value)
    }
}, add = TRUE)

Sys.unsetenv("APP_GENE_CATALOG_ENABLED")
assert_true(!gene_catalog_enabled(), "Gene Catalog must be disabled when the flag is absent.")
Sys.setenv(APP_GENE_CATALOG_ENABLED = "0")
assert_true(!gene_catalog_enabled(), "Gene Catalog must be disabled for APP_GENE_CATALOG_ENABLED=0.")
Sys.setenv(APP_GENE_CATALOG_ENABLED = "1")
assert_true(gene_catalog_enabled(), "Gene Catalog must be available for an explicit future-release opt-in.")

ui_source <- paste(readLines("ui.R", warn = FALSE), collapse = "\n")
server_source <- paste(readLines("server.R", warn = FALSE), collapse = "\n")

assert_true(
    length(gregexpr("if (isTRUE(cgv_gene_catalog_enabled))", ui_source, fixed = TRUE)[[1]]) >= 3L,
    "The primary UI must guard the Gene Catalog script, navigation button, and tab."
)
assert_true(
    grepl("if (isTRUE(catalogFeatureEnabled))", server_source, fixed = TRUE),
    "Gene Catalog server observers must only register when the feature is enabled."
)

expected_defaults <- c(
    ".env.example" = "APP_GENE_CATALOG_ENABLED=0",
    "docker-compose.yml" = "APP_GENE_CATALOG_ENABLED: \"${APP_GENE_CATALOG_ENABLED:-0}\"",
    "docker-compose.deploy.yml" = "APP_GENE_CATALOG_ENABLED: \"${APP_GENE_CATALOG_ENABLED:-0}\"",
    "docker-compose.shinyproxy.yml" = "SP_GENE_CATALOG_ENABLED: \"${SP_GENE_CATALOG_ENABLED:-0}\"",
    "shinyproxy/application.yml" = "APP_GENE_CATALOG_ENABLED: \"${SP_GENE_CATALOG_ENABLED:0}\"",
    "desktop/src/main.js" = "APP_GENE_CATALOG_ENABLED: process.env.APP_GENE_CATALOG_ENABLED || \"0\""
)
for (path in names(expected_defaults)) {
    source_text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    assert_true(
        grepl(expected_defaults[[path]], source_text, fixed = TRUE),
        sprintf("%s must keep Gene Catalog disabled by default.", path)
    )
}

assert_true(file.exists(file.path("www", "js", "gene_catalog.js")), "Future Gene Catalog code must remain preserved.")
cat("gene-catalog-feature-flag-ok\n")
