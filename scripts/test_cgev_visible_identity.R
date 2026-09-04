read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

ui_text <- read_text("ui.R")
home_text <- read_text(file.path("www", "home_preview_cgv.html"))
desktop_main <- read_text(file.path("desktop", "src", "main.js"))
desktop_legacy_user_data <- read_text(file.path("desktop", "src", "legacy-user-data.js"))
desktop_package <- jsonlite::fromJSON(file.path("desktop", "package.json"), simplifyVector = FALSE)
citation_text <- read_text("CITATION.cff")
zenodo_text <- read_text(".zenodo.json")
manual_source <- read_text(file.path("docs", "user_manual", "CGeV_User_Manual_Source.md"))
manual_metadata <- jsonlite::fromJSON(file.path("www", "docs", "manual.json"))
env_example <- read_text(".env.example")
dataset_manifest_files <- list.files(
  file.path("desktop", "dataset-packages"),
  pattern = "\\.manifest\\.json$",
  full.names = TRUE
)
dataset_manifest_text <- paste(
  vapply(dataset_manifest_files, read_text, character(1)),
  collapse = "\n"
)

visible_sources <- c(
  "ui.R",
  file.path("www", "home_preview_cgv.html"),
  file.path("R", "ui_desktop_downloads.R"),
  file.path("R", "feedback_delivery.R"),
  file.path("R", "background_report_jobs.R"),
  file.path("R", "server_shared_analysis_domain.R"),
  file.path("desktop", "src", "launcher.html"),
  file.path("www", "js", "activity_feedback.js"),
  file.path("www", "js", "cgv_desktop_downloads.js"),
  file.path("www", "js", "figure_studio.js"),
  file.path("www", "js", "reproducible_report.js"),
  file.path("www", "js", "status_popup.js")
)
visible_text <- paste(vapply(visible_sources, read_text, character(1)), collapse = "\n")
visible_text_without_legacy_urls <- gsub("CGV-Desktop-Releases", "", visible_text, fixed = TRUE)

stopifnot(
  grepl('tags$title("CGeV | Comparative Gene Viewer")', ui_text, fixed = TRUE),
  grepl('div(class = "app-brand-title", "CGeV")', ui_text, fixed = TRUE),
  grepl("Comparative Gene Viewer (CGeV)", home_text, fixed = TRUE),
  grepl("CGeV Guide", ui_text, fixed = TRUE),
  grepl("CGeV Desktop", ui_text, fixed = TRUE),
  grepl("CGeV_User_Manual.pdf", ui_text, fixed = TRUE),
  !grepl("\\bCGV\\b", visible_text_without_legacy_urls, perl = TRUE),
  grepl('title: "CGeV: Comparative Gene Viewer"', citation_text, fixed = TRUE),
  grepl('"title": "CGeV: Comparative Gene Viewer"', zenodo_text, fixed = TRUE),
  grepl("Comparative Gene Viewer (CGeV)", manual_source, fixed = TRUE),
  identical(manual_metadata$title, "CGeV User Manual"),
  identical(manual_metadata$latest_url, "docs/CGeV_User_Manual.pdf"),
  identical(manual_metadata$legacy_url, "docs/CGV_User_Manual.pdf"),
  length(dataset_manifest_files) == 25L,
  !grepl("CGV Desktop dataset package", dataset_manifest_text, fixed = TRUE),
  grepl("CGeV Desktop dataset package", dataset_manifest_text, fixed = TRUE),
  grepl('FEEDBACK_FROM_EMAIL="CGeV Feedback <feedback@cgvapp.com>"', env_example, fixed = TRUE),
  grepl('REPORT_FROM_EMAIL="CGeV Reports <reports@cgvapp.com>"', env_example, fixed = TRUE),

  # Phase 2 contract: OS identity is CGeV; technical identity and data paths stay CGV/cgv.
  identical(desktop_package$build$appId, "org.cgv.desktop"),
  identical(desktop_package$build$productName, "CGeV Desktop"),
  numeric_version(desktop_package$version) >= numeric_version("1.2.0"),
  identical(desktop_package$name, "cgv-desktop"),
    identical(desktop_package$repository$url, "https://github.com/raulrojas22/CGeV"),
  grepl('electronApp.setPath("userData", legacyUserDataPath({', desktop_main, fixed = TRUE),
  grepl('LEGACY_USER_DATA_DIRECTORY = "CGV Desktop"', desktop_legacy_user_data, fixed = TRUE),
  grepl("CGV_DATA_ROOT", desktop_main, fixed = TRUE),
  grepl("CGV_CACHE_DIR", desktop_main, fixed = TRUE),
  grepl('mainWindow.webContents.send("cgv:status"', desktop_main, fixed = TRUE),
  grepl("cgv-download-button", read_text(file.path("R", "ui_desktop_downloads.R")), fixed = TRUE),
  file.exists(file.path("www", "docs", "CGV_User_Manual.pdf")),
  file.exists(file.path("www", "docs", "archive", "CGeV_User_Manual_Web_and_Desktop_v1.1.pdf"))
)

message("CGeV visible identity and CGV/cgv compatibility checks passed.")
