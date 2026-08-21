#!/usr/bin/env Rscript

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}
assert <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
}

deploy <- read_text("deploy-colors-shinyproxy.sh")

build_pos <- regexpr("podman build --pull=never", deploy, fixed = TRUE)[1]
digest_pos <- regexpr("podman image inspect --format '{{.Id}}' '${NEW_IMAGE}'", deploy, fixed = TRUE)[1]
publish_pos <- regexpr("CGV_PUBLISH_STATIC_ASSETS=1", deploy, fixed = TRUE)[1]
candidate_pos <- regexpr("build_nginx_static_candidate.py", deploy, fixed = TRUE)[1]
nginx_test_pos <- regexpr("--entrypoint /usr/sbin/nginx", deploy, fixed = TRUE)[1]
nginx_move_pos <- regexpr("mv '${COLORS_NGINX_CANDIDATE}' '${COLORS_NGINX_CONFIG}'", deploy, fixed = TRUE)[1]
teardown_pos <- regexpr("${teardown_stack_command}", deploy, fixed = TRUE)[1]

assert(all(c(build_pos, digest_pos, publish_pos, candidate_pos, nginx_test_pos,
             nginx_move_pos, teardown_pos) > 0),
       "Colors immutable-static deployment sequence is incomplete.")
assert(build_pos < digest_pos && digest_pos < publish_pos,
       "Colors must derive the exact image Id after build and before publication.")
assert(publish_pos < candidate_pos && candidate_pos < nginx_test_pos,
       "The static snapshot and candidate must exist before nginx -t.")
assert(nginx_test_pos < nginx_move_pos,
       "The server-owned nginx candidate must pass nginx -t before atomic replacement.")

required <- c(
  "CGV_STATIC_REVISION='${STATIC_REVISION}'",
  "APP_ASSET_VERSION=${STATIC_REVISION}",
  "APP_STATIC_BASE_URL=/cgv-static/${STATIC_REVISION}",
  "container-env-file: /opt/shinyproxy/env/cgv.env",
  "/opt/shinyproxy/env/cgv.env",
  "/srv/cgv-cache",
  "static_assets/manifests/${STATIC_REVISION}.sha256",
  "static_assets/releases/${STATIC_REVISION}",
  "cp -p '${BACKUP_DIR}/app.env' .env",
  "cp -p '${BACKUP_DIR}/cgv-shinyproxy-colors.conf' deploy/nginx/cgv-shinyproxy-colors.conf",
  "verify_static_asset_http.py",
  "APP_STATIC_BASE_URL=/cgv-static/${expected_revision}",
  "REPORT_SCRIPT_CSP_HASH",
  "--report-script-hash '${REPORT_SCRIPT_CSP_HASH}'",
  "title: CGeV - Comparative Gene Viewer",
  "display-name: CGeV - Comparative Gene Viewer",
  "CGeV Feedback <feedback@cgvapp.com>",
  "CGeV Reports <reports@cgvapp.com>"
)
assert(all(vapply(required, grepl, logical(1), x = deploy, fixed = TRUE)),
       "One or more Colors static-delivery guards are missing.")

assert(!grepl("rm -rf.*static_assets", deploy, perl = TRUE),
       "Colors must retain old immutable releases for rollback.")
assert(!grepl("sed .*docker-compose.shinyproxy.colors", deploy, perl = TRUE),
       "The application deploy must not mutate the server-owned Colors compose file.")

message("Colors ShinyProxy immutable-static deployment contract is guarded.")
