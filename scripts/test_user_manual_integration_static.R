read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

ui_text <- read_text("ui.R")
home_text <- read_text(file.path("www", "home_preview_cgv.html"))
guide_css <- read_text(file.path("www", "css", "cgv_guide.css"))
compiled_css <- read_text(file.path("www", "css", "cgv_compiled.css"))
manual_source <- read_text(file.path("docs", "user_manual", "CGeV_User_Manual_Source.md"))
desktop_downloads <- read_text(file.path("R", "ui_desktop_downloads.R"))
desktop_package <- read_text(file.path("desktop", "package.json"))
deploy_text <- read_text("deploy-nas.sh")
dockerignore <- trimws(readLines(".dockerignore", warn = FALSE, encoding = "UTF-8"))
metadata <- jsonlite::fromJSON(file.path("www", "docs", "manual.json"))
desktop_guide_videos <- c(
  "guide-desktop-downloads-01-open-settings.mp4",
  "guide-desktop-downloads-02-open-organism-catalog.mp4",
  "guide-desktop-downloads-03-search-and-filter.mp4",
  "guide-desktop-downloads-04-download-organism.mp4",
  "guide-desktop-downloads-05-confirm-availability.mp4",
  "guide-desktop-downloads-06-remove-installed-organisms.mp4"
)

latest_pdf <- file.path("www", "docs", "CGeV_User_Manual.pdf")
legacy_pdf <- file.path("www", "docs", "CGV_User_Manual.pdf")
archive_pdf <- file.path(
  "www",
  "docs",
  "archive",
  sprintf("CGeV_User_Manual_Web_and_Desktop_v%s.pdf", metadata$manual_version)
)
authoring_pdf <- file.path(
  "output",
  "pdf",
  sprintf("CGeV_User_Manual_Web_and_Desktop_v%s.pdf", metadata$manual_version)
)

stopifnot(
  file.exists(latest_pdf),
  file.exists(archive_pdf),
  file.exists(authoring_pdf),
  file.exists(legacy_pdf),
  identical(
    unname(tools::md5sum(c(latest_pdf, legacy_pdf, archive_pdf, authoring_pdf))),
    rep(unname(tools::md5sum(latest_pdf)), 4)
  ),
  identical(metadata$latest_url, "docs/CGeV_User_Manual.pdf"),
  identical(metadata$legacy_url, "docs/CGV_User_Manual.pdf"),
  grepl("cgv_manual_path", ui_text, fixed = TRUE),
  grepl("guide-manual-card", ui_text, fixed = TRUE),
  grepl("feedback-manual-prompt", ui_text, fixed = TRUE),
  grepl('versioned_asset_path("home_preview_cgv.html")', ui_text, fixed = TRUE),
  grepl("data-cgv-manual-link", home_text, fixed = TRUE),
  grepl("docs/manual.json", home_text, fixed = TRUE),
  grepl("Interactive report", home_text, fixed = TRUE),
  grepl("self-contained local HTML report", home_text, fixed = TRUE),
  grepl(".guide-manual-card", guide_css, fixed = TRUE),
  grepl("guide-runtime-desktop", guide_css, fixed = TRUE),
  grepl('`data-guide-route` = "figure-studio"', ui_text, fixed = TRUE),
  grepl("guide-common-share-analysis-web.mp4", ui_text, fixed = TRUE),
  grepl("guide-common-export-report-desktop.mp4", ui_text, fixed = TRUE),
  grepl(
    "media: window\\.cgvDesktop\\s*\\? guideVideo\\('guide-common-export-report-desktop\\.mp4'\\)\\s*:\\s*guideVideo\\('guide-common-share-analysis-web\\.mp4'\\)",
    ui_text,
    perl = TRUE
  ),
  grepl("guide-figure-studio-04-preview-and-export.mp4", ui_text, fixed = TRUE),
  all(vapply(
    desktop_guide_videos,
    function(file) grepl(file, ui_text, fixed = TRUE),
    logical(1)
  )),
  all(vapply(
    desktop_guide_videos,
    function(file) grepl(file, deploy_text, fixed = TRUE),
    logical(1)
  )),
  !grepl("guide-cross-04-inspect-visualization.mp4", ui_text, fixed = TRUE),
  !grepl("guide-cross-04-inspect-visualization.mp4", deploy_text, fixed = TRUE),
  grepl("delete routeData['desktop-downloads'];", ui_text, fixed = TRUE),
  grepl("Use Share to create an expiring secret read-only URL", ui_text, fixed = TRUE),
  grepl("CGeV Desktop does not upload the analysis", ui_text, fixed = TRUE),
  grepl("Local interactive reports", desktop_downloads, fixed = TRUE),
  grepl("## 2.7 Share analysis", manual_source, fixed = TRUE),
  grepl("## 6.5 Genomic context scale, neighbors, and overlaps", manual_source, fixed = TRUE),
  grepl("**Complete** or **Fast** report detail", manual_source, fixed = TRUE),
  grepl("## 12.8 Shared analysis reports - Web", manual_source, fixed = TRUE),
  grepl("Select all installed organisms", manual_source, fixed = TRUE),
  grepl("submission reference is sent to the reporter", manual_source, fixed = TRUE),
  grepl("automatic status popup shows LASTZ or MultiPIP", manual_source, fixed = TRUE),
  grepl("CGeV freezes a visual copy", manual_source, fixed = TRUE),
  grepl("**Figure Studio** covers:", manual_source, fixed = TRUE),
  grepl(".feedback-manual-prompt", compiled_css, fixed = TRUE),
  grepl('"www/**"', desktop_package, fixed = TRUE),
  grepl('"!www/screencasts.orig/**"', desktop_package, fixed = TRUE),
  grepl('"!www/ctv_backup/**"', desktop_package, fixed = TRUE),
  grepl("--exclude=www/screencasts.orig", deploy_text, fixed = TRUE),
  grepl("--exclude=www/ctv_backup", deploy_text, fixed = TRUE),
  !"www/screencasts/" %in% dockerignore,
  "www/screencasts.orig/" %in% dockerignore,
  "www/ctv_backup/" %in% dockerignore
)

message("CGeV user manual publishing and UI integration checks passed.")
