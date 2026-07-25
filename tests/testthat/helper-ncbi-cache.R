if (!exists("%||%", mode = "function")) {
    `%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
}

ncbi_domain_path <- file.path("R", "server_ncbi_download_domain.R")
if (!file.exists(ncbi_domain_path)) {
    ncbi_domain_path <- file.path("..", "..", "R", "server_ncbi_download_domain.R")
}
sys.source(ncbi_domain_path, envir = globalenv())
