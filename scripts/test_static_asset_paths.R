#!/usr/bin/env Rscript

revision <- paste(rep("a", 64L), collapse = "")
base_url <- sprintf("/cgv-static/%s", revision)

Sys.setenv(
  APP_ASSET_VERSION = revision,
  APP_STATIC_BASE_URL = base_url,
  APP_PREWARM_ON_START = "0",
  APP_FUTURE_MODE = "sequential",
  APP_FUTURE_WORKERS = "1"
)
source("global.R", local = .GlobalEnv)

stopifnot(
  identical(app_asset_version, revision),
  identical(app_static_base_url, base_url),
  identical(static_asset_path(""), ""),
  identical(static_asset_path("js/version_probe.js"), paste0(base_url, "/js/version_probe.js")),
  identical(
    versioned_asset_path("js/version_probe.js"),
    paste0(base_url, "/js/version_probe.js?av=", revision)
  ),
  identical(
    versioned_asset_path("favicon2.ico?v=2"),
    paste0(base_url, "/favicon2.ico?v=2&av=", revision)
  ),
  identical(static_asset_path("../secret"), "../secret"),
  identical(static_asset_path("nested/../secret"), "nested/../secret"),
  identical(static_asset_path("%2e%2e/secret"), "%2e%2e/secret"),
  identical(static_asset_path("nested\\secret"), "nested\\secret"),
  identical(static_asset_path("/absolute.js"), "/absolute.js"),
  identical(static_asset_path("https://example.test/a.js"), "https://example.test/a.js"),
  identical(compute_app_static_base_url(revision, ""), ""),
  identical(compute_app_static_base_url(revision, "/cgv-static/not-a-digest"), ""),
  identical(
    compute_app_static_base_url(paste(rep("b", 64L), collapse = ""), base_url),
    ""
  )
)

app_static_base_url <- ""
stopifnot(
  identical(static_asset_path("js/version_probe.js"), "js/version_probe.js"),
  identical(
    versioned_asset_path("js/version_probe.js"),
    paste0("js/version_probe.js?av=", revision)
  )
)

ui_text <- paste(readLines("ui.R", warn = FALSE, encoding = "UTF-8"), collapse = "\n")
stopifnot(grepl("static_asset_path(path)", ui_text, fixed = TRUE))

message("static asset path helpers: OK")
