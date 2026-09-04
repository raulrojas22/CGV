test_that("runtime library caches use the writable CGV cache mount", {
  script_path <- file.path("deploy", "docker", "run-app.sh")
  if (!file.exists(script_path)) {
    script_path <- file.path("..", "..", "deploy", "docker", "run-app.sh")
  }
  expect_true(file.exists(script_path))

  script <- paste(readLines(script_path, warn = FALSE), collapse = "\n")

  expect_match(
    script,
    'GDTOOLS_CACHE_DIR="${GDTOOLS_CACHE_DIR:-${CGV_CACHE_DIR}/gdtools}"',
    fixed = TRUE
  )
  expect_match(
    script,
    'XDG_CACHE_HOME="${XDG_CACHE_HOME:-${CGV_CACHE_DIR}/xdg-cache}"',
    fixed = TRUE
  )
  expect_match(
    script,
    'XDG_DATA_HOME="${XDG_DATA_HOME:-${CGV_CACHE_DIR}/xdg-data}"',
    fixed = TRUE
  )

  for (env_name in c("GDTOOLS_CACHE_DIR", "XDG_CACHE_HOME", "XDG_DATA_HOME")) {
    expect_match(
      script,
      paste0("  ", env_name, " \\"),
      fixed = TRUE,
      info = paste(env_name, "must be exported to R")
    )
    expect_match(
      script,
      paste0('  "${', env_name, '}"'),
      fixed = TRUE,
      info = paste(env_name, "must be created before R starts")
    )
  }
})
