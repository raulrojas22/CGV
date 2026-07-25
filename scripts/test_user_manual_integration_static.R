read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

ui_text <- read_text("ui.R")
home_text <- read_text(file.path("www", "home_preview_cgv.html"))
guide_css <- read_text(file.path("www", "css", "cgv_guide.css"))
compiled_css <- read_text(file.path("www", "css", "cgv_compiled.css"))
desktop_package <- read_text(file.path("desktop", "package.json"))
metadata <- jsonlite::fromJSON(file.path("www", "docs", "manual.json"))

latest_pdf <- file.path("www", "docs", "CGV_User_Manual.pdf")
archive_pdf <- file.path(
  "www",
  "docs",
  "archive",
  sprintf("CGV_User_Manual_Web_and_Desktop_v%s.pdf", metadata$manual_version)
)
authoring_pdf <- file.path(
  "output",
  "pdf",
  sprintf("CGV_User_Manual_Web_and_Desktop_v%s.pdf", metadata$manual_version)
)

stopifnot(
  file.exists(latest_pdf),
  file.exists(archive_pdf),
  file.exists(authoring_pdf),
  identical(
    unname(tools::md5sum(c(latest_pdf, archive_pdf, authoring_pdf))),
    rep(unname(tools::md5sum(latest_pdf)), 3)
  ),
  identical(metadata$latest_url, "docs/CGV_User_Manual.pdf"),
  grepl("cgv_manual_path", ui_text, fixed = TRUE),
  grepl("guide-manual-card", ui_text, fixed = TRUE),
  grepl("feedback-manual-prompt", ui_text, fixed = TRUE),
  grepl('versioned_asset_path("home_preview_cgv.html")', ui_text, fixed = TRUE),
  grepl("data-cgv-manual-link", home_text, fixed = TRUE),
  grepl("docs/manual.json", home_text, fixed = TRUE),
  grepl(".guide-manual-card", guide_css, fixed = TRUE),
  grepl(".feedback-manual-prompt", compiled_css, fixed = TRUE),
  grepl('"www/**"', desktop_package, fixed = TRUE)
)

message("CGV user manual publishing and UI integration checks passed.")
