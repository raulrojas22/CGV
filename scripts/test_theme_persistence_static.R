#!/usr/bin/env Rscript

ui_txt <- paste(readLines("ui.R", warn = FALSE), collapse = "\n")
home_txt <- paste(readLines(file.path("www", "home_preview_cgv.html"), warn = FALSE), collapse = "\n")
snapshot_txt <- paste(readLines(file.path("R", "server_session_snapshot_domain.R"), warn = FALSE), collapse = "\n")

expect_pattern <- function(txt, pattern, label) {
  if (!grepl(pattern, txt, perl = TRUE)) {
    stop(sprintf("Missing expected theme persistence behavior: %s", label), call. = FALSE)
  }
}

expect_pattern(
  ui_txt,
  "function isDesktopRuntime\\(\\)[\\s\\S]*window\\.cgvDesktop",
  "Desktop runtime detection in the main UI"
)
expect_pattern(
  ui_txt,
  "function getStoredTheme\\(\\)[\\s\\S]*if \\(!isDesktopRuntime\\(\\)\\)[\\s\\S]*localStorage\\.removeItem\\('cgv-theme'\\)[\\s\\S]*return 'light'",
  "web sessions clear the legacy preference and start light"
)
expect_pattern(
  ui_txt,
  "function persistTheme\\(themeName\\)[\\s\\S]*if \\(!isDesktopRuntime\\(\\)\\) return;[\\s\\S]*localStorage\\.setItem\\('cgv-theme', themeName\\)",
  "only Desktop writes the theme preference"
)
expect_pattern(
  home_txt,
  "if \\(!theme && isDesktopRuntime\\(\\)\\)[\\s\\S]*localStorage\\.getItem\\('cgv-theme'\\)",
  "home iframe only reads a stored preference in Desktop"
)
expect_pattern(
  home_txt,
  "if \\(isDesktopRuntime\\(\\)\\) \\{[\\s\\S]*localStorage\\.setItem\\('cgv-theme', theme\\)",
  "home iframe only writes a preference in Desktop"
)
expect_pattern(
  snapshot_txt,
  "app_theme = as.character\\(input\\$app_theme %\\|\\|% \"light\"\\)",
  "work-session export retains the theme"
)
expect_pattern(
  snapshot_txt,
  "state\\$app_theme[\\s\\S]*applyTheme",
  "work-session restore reapplies the saved theme"
)

cat("theme-persistence-static-ok\n")
