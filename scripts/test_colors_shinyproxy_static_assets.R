#!/usr/bin/env Rscript

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}
assert <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
}

deploy <- read_text("deploy-colors-shinyproxy.sh")

check_pos <- regexpr('if [[ "$MODE" == "check" ]]; then', deploy, fixed = TRUE)[1]
tests_pos <- regexpr('if [[ "$SKIP_TESTS" == "0" ]]; then', deploy, fixed = TRUE)[1]
assert(check_pos > 0 && tests_pos > check_pos,
       "Colors check-mode guard block is missing or out of order.")
check_text <- substr(deploy, check_pos, tests_pos - 1L)
check_revision_pos <- regexpr(
  'if [[ "$ACTIVE_IMAGE_REVISION" != "$SOURCE_REV" ]]; then',
  check_text,
  fixed = TRUE
)[1]
check_delegate_pos <- regexpr('CHECK_DELEGATE="$(', check_text, fixed = TRUE)[1]
check_policy_pos <- regexpr('BROKER_POLICY="$(', check_text, fixed = TRUE)[1]
check_success_pos <- regexpr("CHECK OK:", check_text, fixed = TRUE)[1]
assert(all(c(check_revision_pos, check_delegate_pos, check_policy_pos, check_success_pos) > 0) &&
         check_revision_pos < check_delegate_pos &&
         check_delegate_pos < check_policy_pos &&
         check_policy_pos < check_success_pos,
       "Colors check must reject revision drift before delegate and policy validation.")
assert(grepl(
  "podman image inspect '${CURRENT_IMAGE}' --format '{{ index .Labels \\\"org.opencontainers.image.revision\\\" }}'",
  check_text,
  fixed = TRUE
), "Colors check must read the immutable image revision label.")
assert(grepl("Colors saludable pero no ejecuta el commit local", check_text, fixed = TRUE),
       "Colors check must clearly distinguish health from running the local commit.")
assert(grepl("--filter name=sp-container- --filter status=running", check_text, fixed = TRUE) &&
         grepl("[ \\\"\\$candidate_image\\\" = '${CURRENT_IMAGE}' ]", check_text, fixed = TRUE),
       "Colors check must wait for a running delegate carrying the active image exactly.")
assert(grepl('[[ "$BROKER_POLICY" == "0" || "$BROKER_POLICY" == "1" ]]', check_text, fixed = TRUE) &&
         grepl('[[ "$DELEGATE_POLICY" == "0" || "$DELEGATE_POLICY" == "1" ]]', check_text, fixed = TRUE) &&
         grepl('[[ "$DELEGATE_POLICY" == "$BROKER_POLICY" ]]', check_text, fixed = TRUE),
       "Colors check must require valid and identical broker/delegate orthology policy.")

wait_pos <- regexpr("wait_for_release() {", deploy, fixed = TRUE)[1]
verify_pos <- regexpr("verify_static_release() {", deploy, fixed = TRUE)[1]
rollback_pos <- regexpr("rollback_release() {", deploy, fixed = TRUE)[1]
assert(all(c(wait_pos, verify_pos, rollback_pos) > 0) && wait_pos < verify_pos && verify_pos < rollback_pos,
       "Colors release readiness functions are incomplete or out of order.")
wait_text <- substr(deploy, wait_pos, verify_pos - 1L)
verify_text <- substr(deploy, verify_pos, rollback_pos - 1L)

assert(grepl("--filter name=sp-container- --filter status=running", wait_text, fixed = TRUE),
       "Colors readiness must search for a running ShinyProxy delegate.")
assert(grepl("candidate_image=\\$(podman inspect \\\"\\$candidate\\\" --format '{{.ImageName}}'", wait_text, fixed = TRUE),
       "Colors readiness must inspect the delegate image exactly.")
assert(grepl("[ \\\"\\$candidate_image\\\" = '${expected_image}' ]", wait_text, fixed = TRUE),
       "Colors readiness must require the expected image on the delegate.")
assert(!grepl("podman ps --filter ancestor='${expected_image}' -q | wc -l", wait_text, fixed = TRUE),
       "A background worker must not satisfy public-app readiness.")
assert(grepl("READINESS_GUARD_FAILED:", wait_text, fixed = TRUE),
       "Colors readiness failures must identify the failed guard.")
assert(grepl("for i in \\$(seq 1 15)", verify_text, fixed = TRUE) &&
         grepl("STATIC_GUARD_FAILED: delegate-missing", verify_text, fixed = TRUE),
       "Static verification must coalesce delegate startup and report a missing delegate explicitly.")
assert(grepl('verify_static_release "$STATIC_REVISION" "$NEW_IMAGE"', deploy, fixed = TRUE),
       "Static verification must select a delegate from the new image only.")

select_expected_delegate <- function(container_names, container_images, expected_image) {
  matches <- container_names[
    startsWith(container_names, "sp-container-") & container_images == expected_image
  ]
  if (length(matches)) matches[[1L]] else NA_character_
}
expected_image_fixture <- "localhost/cgv:release-new"
worker_only_name <- "cgv-background-report-worker"
worker_only_image <- expected_image_fixture
assert(is.na(select_expected_delegate(worker_only_name, worker_only_image, expected_image_fixture)),
       "Regression: a ready worker without a delegate must remain not-ready.")
assert(identical(
  select_expected_delegate(
    c(worker_only_name, "sp-container-old", "sp-container-new"),
    c(worker_only_image, "localhost/cgv:release-old", expected_image_fixture),
    expected_image_fixture
  ),
  "sp-container-new"
), "Regression: readiness must select only the delegate carrying the expected image.")

build_pos <- regexpr("podman build --pull=never", deploy, fixed = TRUE)[1]
digest_pos <- regexpr("podman image inspect --format '{{.Id}}' '${NEW_IMAGE}'", deploy, fixed = TRUE)[1]
publish_pos <- regexpr("CGV_PUBLISH_STATIC_ASSETS=1", deploy, fixed = TRUE)[1]
candidate_pos <- regexpr("build_nginx_static_candidate.py", deploy, fixed = TRUE)[1]
broker_candidate_pos <- regexpr("build_colors_shinyproxy_candidates.py", deploy, fixed = TRUE)[1]
nginx_test_pos <- regexpr("--entrypoint /usr/sbin/nginx", deploy, fixed = TRUE)[1]
compose_syntax_pos <- regexpr("podman-compose -f '${COLORS_COMPOSE_CANDIDATE}' config", deploy, fixed = TRUE)[1]
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
             compose_syntax_pos, compose_move_pos, nginx_move_pos,
             cutover_teardown_pos) > 0),
       "Colors immutable-static deployment sequence is incomplete.")
assert(build_pos < digest_pos && digest_pos < publish_pos,
       "Colors must derive the exact image Id after build and before publication.")
assert(broker_candidate_pos < compose_syntax_pos && compose_syntax_pos < candidate_pos &&
         candidate_pos < nginx_test_pos &&
         nginx_test_pos < build_pos,
       "Server-owned candidates and nginx -t must complete before the expensive image build.")
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
  "APP_ORTHO_REQUIRE_VERIFIED_ORTHOLOGY: \\\"\\${APP_ORTHO_REQUIRE_VERIFIED_ORTHOLOGY:0}\\\"",
  "APP_ASSET_VERSION: \\\"\\${APP_ASSET_VERSION:-}\\\"",
  "APP_STATIC_BASE_URL: \\\"\\${APP_STATIC_BASE_URL:-}\\\"",
  "APP_ORTHO_REQUIRE_VERIFIED_ORTHOLOGY: \\\"\\${APP_ORTHO_REQUIRE_VERIFIED_ORTHOLOGY:-0}\\\"",
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
  "POLICY_GUARD_FAILED: env-duplicate-orthology-policy",
  "POLICY_GUARD_FAILED: env-invalid-orthology-policy",
  "STATIC_GUARD_FAILED: broker-orthology-policy",
  "STATIC_GUARD_FAILED: delegate-orthology-policy",
  "STATIC_GUARD_FAILED: orthology-policy-mismatch",
  "fail_guard broker-orthology-policy",
  "fail_guard delegate-orthology-policy",
  "fail_guard orthology-policy-mismatch",
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
  "--tmpfs /var/cache/nginx:rw,nosuid,nodev,noexec,size=32m,mode=1777",
  "--tmpfs /run:rw,nosuid,nodev,noexec,size=8m,mode=1777",
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
assert(!grepl("--tmpfs /var/run:", deploy, fixed = TRUE),
       "The nginx syntax check must mount /run, where nginx.pid is created.")

message("Colors ShinyProxy immutable-static deployment contract is guarded.")
