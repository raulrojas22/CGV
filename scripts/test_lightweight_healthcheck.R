#!/usr/bin/env Rscript

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

assert <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
}

health_path <- file.path("www", "healthz.txt")
assert(file.exists(health_path), "The lightweight Shiny health resource is missing.")
assert(identical(readLines(health_path, warn = FALSE, encoding = "UTF-8"), "ok"),
       "The health resource must contain only 'ok'.")
assert(file.info(health_path)$size <= 16L, "The health resource must stay minimal.")

dockerfile <- read_text("Dockerfile")
nas_deploy <- read_text("deploy-nas.sh")
shinyproxy_deploy <- read_text("deploy-nas-shinyproxy.sh")

assert(
  grepl('http://127.0.0.1:${APP_PORT}/healthz.txt', dockerfile, fixed = TRUE),
  "The container healthcheck must use the lightweight resource."
)
assert(
  grepl("grep -qx 'ok'", dockerfile, fixed = TRUE),
  "The container healthcheck must verify the health resource body."
)
assert(
  grepl("http://localhost:3838/healthz.txt", nas_deploy, fixed = TRUE),
  "The direct NAS readiness probe must use the lightweight resource."
)
assert(
  grepl("http://127.0.0.1:3838/healthz.txt", shinyproxy_deploy, fixed = TRUE),
  "The ShinyProxy deployment must probe the running Shiny container directly."
)
assert(
  grepl("curl -sS -I -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:8080", shinyproxy_deploy, fixed = TRUE),
  "The internal ShinyProxy probe must use HEAD instead of downloading the root page."
)
assert(
  grepl("curl -sS -I -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:${CGV_NGINX_PORT}", shinyproxy_deploy, fixed = TRUE),
  "The internal nginx probe must use HEAD instead of downloading the root page."
)
assert(
  grepl("curl -sS -I -o /dev/null -w '%{http_code}' --max-time 10 https://cgev.mobilomics.org/", shinyproxy_deploy, fixed = TRUE),
  "The public readiness probe must use HEAD instead of downloading the root page."
)
assert(
  !grepl('wget -qO- "http://127.0.0.1:${APP_PORT}/"', dockerfile, fixed = TRUE),
  "The Docker healthcheck must not download the full application page."
)
assert(
  !grepl("curl -s -o /dev/null -w '%{http_code}' http://localhost:3838 ", nas_deploy, fixed = TRUE),
  "The direct NAS readiness probe must not download the full application page."
)

message("Lightweight health/readiness probes are configured consistently.")
