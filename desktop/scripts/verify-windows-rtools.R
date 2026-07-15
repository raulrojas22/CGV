args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("Usage: verify-windows-rtools.R <toolchain-root> <build-tools-root> <toolchain-version>")
}

normalize_existing <- function(path) {
  tolower(normalizePath(path, winslash = "/", mustWork = TRUE))
}

toolchain_root <- normalize_existing(args[[1L]])
build_tools_root <- normalize_existing(args[[2L]])
expected_version <- trimws(args[[3L]])
version_file <- file.path(toolchain_root, ".version")
actual_version <- trimws(readLines(version_file, warn = FALSE, n = 1L))
if (!identical(actual_version, expected_version)) {
  stop(sprintf("Unexpected Rtools44 toolchain version: expected %s, found %s", expected_version, actual_version))
}

resolved <- Sys.which(c("gcc", "g++", "make"))
if (any(!nzchar(resolved))) {
  stop(sprintf("Rtools44 commands are missing from PATH: %s", paste(names(resolved)[!nzchar(resolved)], collapse = ", ")))
}

expected_compiler_dir <- normalize_existing(file.path(toolchain_root, "bin"))
expected_make <- normalize_existing(file.path(build_tools_root, "usr", "bin", "make.exe"))
for (compiler in c("gcc", "g++")) {
  actual_dir <- normalize_existing(dirname(unname(resolved[[compiler]])))
  if (!identical(actual_dir, expected_compiler_dir)) {
    stop(sprintf("%s resolved outside the locked Rtools44 toolchain: %s", compiler, resolved[[compiler]]))
  }
}
if (!identical(normalize_existing(unname(resolved[["make"]])), expected_make)) {
  stop(sprintf("make resolved outside the isolated Rtools44 build tools: %s", resolved[["make"]]))
}

gcc_version <- system2(unname(resolved[["gcc"]]), "--version", stdout = TRUE, stderr = TRUE)
if (!any(grepl("13\\.", gcc_version))) {
  stop(sprintf("Rtools44 must provide GCC 13; received: %s", paste(gcc_version, collapse = " ")))
}

message(sprintf(
  "Rtools44 toolchain verified: version=%s gcc=%s make=%s",
  actual_version,
  unname(resolved[["gcc"]]),
  unname(resolved[["make"]])
))
