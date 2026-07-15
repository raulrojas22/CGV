args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("Usage: verify-r-package.R <package> <required|optional>", call. = FALSE)
}

package_name <- args[[1L]]
package_mode <- args[[2L]]
if (!package_mode %in% c("required", "optional")) {
  stop("Unexpected package mode: ", package_mode, call. = FALSE)
}

if (!requireNamespace(package_name, quietly = TRUE)) {
  if (identical(package_mode, "optional")) {
    cat("Optional R package missing: ", package_name, "\n", sep = "")
    quit(save = "no", status = 10L, runLast = FALSE)
  }
  stop("Missing R package: ", package_name, call. = FALSE)
}

cat("R package ok: ", package_name, "\n", sep = "")
