#!/usr/bin/env Rscript

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

release_version <- "1.1.0"
desktop_release_version <- "1.2.2"
manual_version <- "1.1"

global_txt <- read_text("global.R")
ui_txt <- read_text("ui.R")
studio_js <- read_text(file.path("www", "js", "figure_studio.js"))
studio_css <- read_text(file.path("www", "css", "figure_studio.css"))
desktop_package <- jsonlite::fromJSON(file.path("desktop", "package.json"))
desktop_lock <- jsonlite::fromJSON(file.path("desktop", "package-lock.json"))
desktop_lock_txt <- read_text(file.path("desktop", "package-lock.json"))
manual_config <- jsonlite::fromJSON(file.path("docs", "user_manual", "manual_config.json"))
manual_metadata <- jsonlite::fromJSON(file.path("www", "docs", "manual.json"))
citation_txt <- read_text("CITATION.cff")
zenodo <- jsonlite::fromJSON(".zenodo.json")
dockerfile_txt <- read_text("Dockerfile")
shinyproxy_txt <- read_text("docker-compose.shinyproxy.yml")
compose_txt <- read_text("docker-compose.yml")
compose_deploy_txt <- read_text("docker-compose.deploy.yml")
server_txt <- read_text("server.R")
env_example_txt <- read_text(".env.example")
nas_deploy_txt <- read_text("deploy-nas.sh")
shinyproxy_deploy_txt <- read_text("deploy-nas-shinyproxy.sh")
colors_deploy_txt <- read_text("deploy-colors-shinyproxy.sh")
prewarm_txt <- read_text(file.path("docker", "setup-prewarm.sh"))
alias_verifier_txt <- read_text(file.path("scripts", "verify_preloaded_alias_indexes.R"))
prewarm_mounts <- c(
  CGV_ANNOTATIONS_DIR = "annotations",
  CGV_GENOMES_DIR = "genomes",
  CGV_GO_ANNOTATIONS_DIR = "go_annotations",
  CGV_DATA_DIR = "data",
  CGV_CACHE_DIR = "cache"
)
release_notes <- file.path("docs", "releases", sprintf("RELEASE_NOTES_v%s.md", release_version))
release_checklist <- file.path("docs", "releases", sprintf("RELEASE_CHECKLIST_v%s.md", release_version))
desktop_scripts <- desktop_package$scripts

stopifnot(
  grepl(sprintf('cgv_release_version <- Sys.getenv("CGV_RELEASE_VERSION", unset = "%s")', release_version), global_txt, fixed = TRUE),
  grepl("`data-figure-studio-version` = cgv_release_version", ui_txt, fixed = TRUE),
  grepl('paste0("v", cgv_release_version)', ui_txt, fixed = TRUE),
  identical(desktop_package$version, desktop_release_version),
  identical(desktop_lock$version, desktop_release_version),
  grepl(
    sprintf('"packages"[[:space:]]*:[[:space:]]*\\{[[:space:]]*""[[:space:]]*:[[:space:]]*\\{[[:space:]]*"name"[[:space:]]*:[[:space:]]*"cgv-desktop",[[:space:]]*"version"[[:space:]]*:[[:space:]]*"%s"', desktop_release_version),
    desktop_lock_txt,
    perl = TRUE
  ),
  identical(manual_config$product_version, release_version),
  identical(manual_config$manual_version, manual_version),
  identical(manual_metadata$product_version, release_version),
  identical(manual_metadata$manual_version, manual_version),
  grepl(sprintf("version: %s", release_version), citation_txt, fixed = TRUE),
  identical(zenodo$version, release_version),
  grepl(sprintf('org.opencontainers.image.version="%s"', release_version), dockerfile_txt, fixed = TRUE),
  grepl(sprintf("cgv:%s", release_version), shinyproxy_txt, fixed = TRUE),
  grepl("${CGV_DATA_DIR:-./data}:/app/data:ro", compose_txt, fixed = TRUE),
  grepl("${CGV_DATA_DIR:-./data}:/app/data:ro", compose_deploy_txt, fixed = TRUE),
  grepl(
    "scripts/verify_preloaded_alias_indexes.R --root=/app",
    nas_deploy_txt,
    fixed = TRUE
  ),
  grepl(
    "DOCKER_BIN='${REMOTE_DOCKER}' bash docker/setup-prewarm.sh",
    nas_deploy_txt,
    fixed = TRUE
  ),
  grepl("compose --env-file .env --env-file .env.local create cgv", nas_deploy_txt, fixed = TRUE),
  grepl("inspect --format='{{.Image}}' cgv", nas_deploy_txt, fixed = TRUE),
  all(vapply(
    c("annotations", "genomes", "go_annotations", "data", "cache"),
    function(target) grepl(paste0(".Destination \\\"/app/", target, "\\\""), nas_deploy_txt, fixed = TRUE),
    logical(1)
  )),
  grepl("CGV_IMAGE='${NEW_IMAGE}'", colors_deploy_txt, fixed = TRUE),
  all(vapply(
    names(prewarm_mounts),
    function(variable) {
      grepl(
        paste0(variable, "='${APP_DIR}/", prewarm_mounts[[variable]], "'"),
        colors_deploy_txt,
        fixed = TRUE
      )
    },
    logical(1)
  )),
  all(vapply(
    c("CGV_ANNOTATIONS_DIR", "CGV_GENOMES_DIR", "CGV_GO_ANNOTATIONS_DIR", "CGV_DATA_DIR", "CGV_CACHE_DIR"),
    function(variable) grepl(variable, prewarm_txt, fixed = TRUE),
    logical(1)
  )),
  grepl('for env_file in "${ROOT}/.env" "${ROOT}/.env.local"', prewarm_txt, fixed = TRUE),
  grepl("CGV_IMAGE='${CGV_IMAGE}'", shinyproxy_deploy_txt, fixed = TRUE),
  all(vapply(
    names(prewarm_mounts),
    function(variable) {
      grepl(
        paste0(variable, "='${NAS_APP_DIR}/", prewarm_mounts[[variable]], "'"),
        shinyproxy_deploy_txt,
        fixed = TRUE
      )
    },
    logical(1)
  )),
  !grepl("build_alias_index_sqlite.R --root=/app --all ||", prewarm_txt, fixed = TRUE),
  !grepl("docker_cmd compose build", prewarm_txt, fixed = TRUE),
  grepl('invalid <- species_ids[alias_index_status != "sqlite"]', alias_verifier_txt, fixed = TRUE),
  !grepl(
    "APP_PARTIAL_SUGGESTIONS_STRICT",
    paste(server_txt, dockerfile_txt, env_example_txt),
    fixed = TRUE
  ),
  file.exists(release_notes),
  file.exists(release_checklist),
  identical(desktop_scripts[["runtime:mac:arm64"]], "bash scripts/build-runtime-macos-arm64.sh"),
  identical(desktop_scripts[["runtime:mac:x64"]], "bash scripts/build-runtime-macos-x64.sh"),
  identical(desktop_scripts[["runtime:linux:x64"]], "bash scripts/build-runtime-linux-x64.sh"),
  all(vapply(
    desktop_scripts[c(
      "build", "build:mac", "build:mac:arm64", "build:mac:x64",
      "build:linux", "build:linux:x64", "build:win", "build:store"
    )],
    function(command) grepl("--publish never", command, fixed = TRUE),
    logical(1)
  )),
  grepl('generator: "CGeV Figure Studio " + studioVersion', studio_js, fixed = TRUE),
  !grepl("\\bbeta\\b", paste(ui_txt, studio_js, studio_css), ignore.case = TRUE, perl = TRUE)
)

message(sprintf("CGeV Web v%s and Desktop v%s release metadata are consistent.", release_version, desktop_release_version))
