#!/usr/bin/env Rscript

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

assert <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
}

nas_shinyproxy <- read_text(file.path("deploy", "deploy-nas-shinyproxy.sh"))
nas_direct <- read_text(file.path("deploy", "deploy-nas.sh"))
shinyproxy_application <- read_text(file.path("deploy", "shinyproxy", "application.yml"))
shinyproxy_compose <- read_text(file.path("deploy", "docker-compose.shinyproxy.yml"))

build_pos <- regexpr("compose build", nas_shinyproxy, fixed = TRUE)[1]
image_env_positions <- gregexpr(
  "upsert_env CGV_IMAGE '${CGV_IMAGE}'", nas_shinyproxy, fixed = TRUE
)[[1]]
image_env_positions <- image_env_positions[image_env_positions > 0]
inspect_pos <- regexpr("image inspect --format '{{.Id}}' '${CGV_IMAGE}'", nas_shinyproxy, fixed = TRUE)[1]
prewarm_pos <- regexpr("bash deploy/docker/setup-prewarm.sh", nas_shinyproxy, fixed = TRUE)[1]
compose_up_pos <- regexpr("compose --project-directory . -f deploy/docker-compose.shinyproxy.yml up -d", nas_shinyproxy, fixed = TRUE)[1]
asset_env_pos <- regexpr("upsert_env APP_ASSET_VERSION", nas_shinyproxy, fixed = TRUE)[1]
base_env_pos <- regexpr("upsert_env APP_STATIC_BASE_URL", nas_shinyproxy, fixed = TRUE)[1]
tunnel_pos <- regexpr("# --- Paso 7: Lanzar Cloudflare tunnel ---", nas_shinyproxy, fixed = TRUE)[1]
smoke_pos <- regexpr("Static smoke OK", nas_shinyproxy, fixed = TRUE)[1]

assert(all(c(build_pos, image_env_positions, inspect_pos, prewarm_pos, compose_up_pos, asset_env_pos,
             base_env_pos, tunnel_pos, smoke_pos) > 0),
       "The NAS ShinyProxy static-release sequence is incomplete.")
assert(length(image_env_positions) >= 2L,
       "CGV_IMAGE must be pinned both for build and with the static release environment.")
assert(min(image_env_positions) < build_pos,
       "The exact application image tag must be persisted before compose build.")
assert(max(image_env_positions) < compose_up_pos,
       "The exact application image tag must be persisted again before compose up.")
assert(build_pos < inspect_pos && inspect_pos < prewarm_pos,
       "The exact image Id must be derived after build and before prewarm.")
assert(asset_env_pos < compose_up_pos && base_env_pos < compose_up_pos,
       "Static revision variables must be persisted before compose up.")
assert(smoke_pos < tunnel_pos,
       "The internal static smoke must finish before the public tunnel starts.")

required_contracts <- c(
  "static_revision=\\${static_image_id#sha256:}",
  "grep -Eq '^[a-f0-9]{64}$'",
  "CGV_PUBLISH_STATIC_ASSETS=1",
  "CGV_STATIC_REVISION=\\\"\\$static_revision\\\"",
  "CGV_IMAGE='${CGV_IMAGE}' CGV_DEPS_IMAGE='${CGV_DEPS_IMAGE}'",
  "CGV_IMAGE='${CGV_IMAGE}' ${REMOTE_DOCKER} compose --project-directory . -f deploy/docker-compose.shinyproxy.yml up -d",
  "cache/static_assets/releases/",
  "$static_release/healthz.txt",
  "upsert_env APP_ASSET_VERSION \\\"\\$static_revision\\\"",
  "upsert_env APP_STATIC_BASE_URL \\\"/cgv-static/\\$static_revision\\\"",
  "curl -sS -I --max-time 10 \\\"\\$static_url/healthz.txt\\\"",
  "Cache-Control:[[:space:]]*public",
  "find \\\"\\$static_release\\\" -type f",
  "-iname '*.mp4' -o -iname '*.pdf'",
  "Range: bytes=0-1",
  "Content-Range:[[:space:]]*bytes",
  "HTTP/[0-9.]+ 206"
)
assert(all(vapply(required_contracts, grepl, logical(1), x = nas_shinyproxy, fixed = TRUE)),
       "One or more immutable-static guards are missing from the NAS ShinyProxy deploy.")

assert(!grepl("CGV_PUBLISH_STATIC_ASSETS=1", nas_direct, fixed = TRUE),
       "The direct NAS deployment must not activate immutable static publication.")
assert(!grepl("APP_STATIC_BASE_URL=/cgv-static/", nas_direct, fixed = TRUE),
       "The direct NAS deployment must not opt into the ShinyProxy static route.")
assert(grepl("inspect --format '{{.Image}}' \\\"\\$delegate\\\"", nas_shinyproxy, fixed = TRUE),
       "The running ShinyProxy delegate must be tied back to the static image Id.")
assert(grepl("ps -aq --filter name=sp-container-", nas_shinyproxy, fixed = TRUE),
       "All delegates from the prior release must be removed regardless of image tag.")
assert(!grepl("ps -aq --filter ancestor=${CGV_IMAGE}", nas_shinyproxy, fixed = TRUE),
       "Delegate cleanup must not depend on the new mutable image tag.")

eager_profile <- c(
  ORTHO_SUSPEND_HIDDEN = "1",
  HOMO_DEFER_SEQUENCE = "0",
  ORTHO_DEFER_SEQUENCE = "0",
  FOOTER_DEFER_SEQUENCE = "0",
  DEFER_FEATURE_GC = "0",
  ORTHO_RENDER_CHUNK_SIZE = "64",
  ORTHO_AUTO_RENDER_MORE = "0",
  ORTHO_AUTO_RENDER_DELAY_MS = "0",
  HOMO_INITIAL_VISIBLE = "64",
  ORTHO_INITIAL_VISIBLE = "64",
  ORTHO_SERVER_RENDER_NUDGE = "0"
)
compose_fallback_profile <- c(
  ORTHO_SUSPEND_HIDDEN = "1",
  HOMO_DEFER_SEQUENCE = "0",
  ORTHO_DEFER_SEQUENCE = "0",
  FOOTER_DEFER_SEQUENCE = "0",
  DEFER_FEATURE_GC = "0",
  ORTHO_RENDER_CHUNK_SIZE = "1",
  ORTHO_AUTO_RENDER_MORE = "1",
  ORTHO_AUTO_RENDER_DELAY_MS = "120",
  HOMO_INITIAL_VISIBLE = "1",
  ORTHO_INITIAL_VISIBLE = "1",
  ORTHO_SERVER_RENDER_NUDGE = "0"
)
for (profile_key in names(eager_profile)) {
  profile_value <- eager_profile[[profile_key]]
  fallback_value <- compose_fallback_profile[[profile_key]]
  assert(
    grepl(
      sprintf("upsert_env SP_%s '${NAS_%s}'", profile_key, profile_key),
      nas_shinyproxy,
      fixed = TRUE
    ),
    sprintf("NAS deploy does not persist SP_%s.", profile_key)
  )
  assert(
    grepl(
      sprintf("APP_%s: \"${SP_%s:%s}\"", profile_key, profile_key, fallback_value),
      shinyproxy_application,
      fixed = TRUE
    ),
    sprintf("ShinyProxy does not map SP_%s to APP_%s.", profile_key, profile_key)
  )
  assert(
    grepl(
      sprintf("SP_%s: \"${SP_%s:-%s}\"", profile_key, profile_key, fallback_value),
      shinyproxy_compose,
      fixed = TRUE
    ),
    sprintf("Compose does not propagate SP_%s.", profile_key)
  )
}
assert(grepl("NAS_PERF_TIMING=\"${NAS_PERF_TIMING:-0}\"", nas_shinyproxy, fixed = TRUE),
       "NAS performance telemetry must be off by default.")
assert(grepl("upsert_env SP_APP_PERF_TIMING '${NAS_PERF_TIMING}'", nas_shinyproxy, fixed = TRUE),
       "NAS deploy must persist its explicit telemetry mode.")
assert(grepl("APP_PERF_TIMING: \"${SP_APP_PERF_TIMING:0}\"", shinyproxy_application, fixed = TRUE),
       "ShinyProxy telemetry must be off by default.")
assert(grepl("SP_APP_PERF_TIMING: \"${SP_APP_PERF_TIMING:-0}\"", shinyproxy_compose, fixed = TRUE),
       "Compose telemetry must be off by default.")

message("NAS ShinyProxy static-release and eager-render contracts are guarded.")
