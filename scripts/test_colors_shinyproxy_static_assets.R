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
broker_candidate_pos <- regexpr("build_colors_shinyproxy_candidates.py", deploy, fixed = TRUE)[1]
nginx_test_pos <- regexpr("--entrypoint /usr/sbin/nginx", deploy, fixed = TRUE)[1]
compose_validate_pos <- regexpr("podman-compose --env-file", deploy, fixed = TRUE)[1]
application_move_pos <- regexpr("mv '${COLORS_APPLICATION_CANDIDATE}' '${APP_DIR}/shinyproxy/application.yml'", deploy, fixed = TRUE)[1]
compose_move_pos <- regexpr("mv '${COLORS_COMPOSE_CANDIDATE}' '${COMPOSE_FILE}'", deploy, fixed = TRUE)[1]
nginx_move_pos <- regexpr("mv '${COLORS_NGINX_CANDIDATE}' '${COLORS_NGINX_CONFIG}'", deploy, fixed = TRUE)[1]
cutover_search_pos <- min(application_move_pos, compose_move_pos, nginx_move_pos)
cutover_teardown_relative <- regexpr(
  "${teardown_stack_command}",
  substring(deploy, cutover_search_pos),
  fixed = TRUE
)[1]
cutover_teardown_pos <- if (cutover_teardown_relative > 0) {
  cutover_search_pos + cutover_teardown_relative - 1
} else {
  -1
}

assert(all(c(build_pos, digest_pos, publish_pos, candidate_pos, nginx_test_pos,
             broker_candidate_pos, compose_validate_pos, application_move_pos,
             compose_move_pos, nginx_move_pos, cutover_teardown_pos) > 0),
       "Colors immutable-static deployment sequence is incomplete.")
assert(build_pos < digest_pos && digest_pos < publish_pos,
       "Colors must derive the exact image Id after build and before publication.")
assert(publish_pos < candidate_pos && candidate_pos < nginx_test_pos,
       "The static snapshot and candidate must exist before nginx -t.")
assert(nginx_test_pos < nginx_move_pos,
       "The server-owned nginx candidate must pass nginx -t before atomic replacement.")
assert(broker_candidate_pos < compose_validate_pos &&
         compose_validate_pos < application_move_pos &&
         compose_validate_pos < compose_move_pos,
       "ShinyProxy candidates must be built and validated before atomic replacement.")
assert(application_move_pos < cutover_teardown_pos && compose_move_pos < cutover_teardown_pos,
       "Server-owned ShinyProxy candidates must move immediately before cutover.")

required <- c(
  "CGV_STATIC_REVISION='${STATIC_REVISION}'",
  "APP_ASSET_VERSION=${STATIC_REVISION}",
  "APP_STATIC_BASE_URL=/cgv-static/${STATIC_REVISION}",
  "APP_ASSET_VERSION: \\\"\\${APP_ASSET_VERSION:}\\\"",
  "APP_STATIC_BASE_URL: \\\"\\${APP_STATIC_BASE_URL:}\\\"",
  "APP_ASSET_VERSION: \\\"\\${APP_ASSET_VERSION:-}\\\"",
  "APP_STATIC_BASE_URL: \\\"\\${APP_STATIC_BASE_URL:-}\\\"",
  "COLORS_ENV_CANDIDATE",
  "rm -f '${COLORS_APPLICATION_CANDIDATE}' '${COLORS_COMPOSE_CANDIDATE}' '${COLORS_NGINX_CANDIDATE}' '${COLORS_ENV_CANDIDATE}'",
  "Colors no debe usar container-env-file",
  "no se pudieron generar los candidatos server-owned seguros",
  "falló la preparación del application.yml server-owned",
  "falló la configuración de first-paint en application.yml",
  "los candidatos server-owned no superaron la validación final",
  "no se pudo completar el respaldo previo al deploy",
  "falló el prewarm o la publicación del snapshot estático",
  "el candidato nginx no superó la validación",
  "broker-feedback-secret",
  "la sesión pública recibió FEEDBACK_RESEND_API_KEY",
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
  "display-name: CGeV - Comparative Gene Viewer"
)
assert(all(vapply(required, grepl, logical(1), x = deploy, fixed = TRUE)),
       "One or more Colors static-delivery guards are missing.")

assert(!grepl("rm -rf.*static_assets", deploy, perl = TRUE),
       "Colors must retain old immutable releases for rollback.")
assert(!grepl("sed .*docker-compose.shinyproxy.colors", deploy, perl = TRUE),
       "The application deploy must not edit the server-owned Colors compose file in place.")
assert(!grepl(":/opt/shinyproxy/env/cgv.env", deploy, fixed = TRUE),
       "Colors must never mount the full .env file into ShinyProxy.")
assert(!grepl("FEEDBACK_FROM_EMAIL:", deploy, fixed = TRUE),
       "Public app sessions must not receive feedback sender configuration.")
assert(!grepl("REPORT_FROM_EMAIL:", deploy, fixed = TRUE),
       "Public app sessions must not receive report sender configuration.")

message("Colors ShinyProxy immutable-static deployment contract is guarded.")
