#!/usr/bin/env Rscript
# build_css.R — Pre-compila custom.scss a CSS para evitar compilación en cada arranque.
# Uso: Rscript scripts/build_css.R
# Solo re-compila si custom.scss es más nuevo que el CSS generado.

scss_path <- normalizePath(file.path(".", "custom.scss"), winslash = "/", mustWork = FALSE)
css_path  <- normalizePath(file.path(".", "www", "css", "cgv_compiled.css"), winslash = "/", mustWork = FALSE)

if (!file.exists(scss_path)) {
    message("[build_css] custom.scss no encontrado, saltando.")
    quit(save = "no", status = 0)
}

needs_rebuild <- TRUE
if (file.exists(css_path)) {
    scss_mtime <- file.info(scss_path)$mtime
    css_mtime  <- file.info(css_path)$mtime
    if (!is.na(scss_mtime) && !is.na(css_mtime) && css_mtime >= scss_mtime) {
        needs_rebuild <- FALSE
    }
}

if (!needs_rebuild) {
    message(sprintf("[build_css] CSS ya está al día: %s", css_path))
    quit(save = "no", status = 0)
}

if (!requireNamespace("sass", quietly = TRUE)) {
    message("[build_css] Paquete 'sass' no disponible, saltando pre-compilación.")
    quit(save = "no", status = 1)
}

dir.create(dirname(css_path), showWarnings = FALSE, recursive = TRUE)

message(sprintf("[build_css] Compilando %s -> %s ...", scss_path, css_path))
t0 <- Sys.time()
result <- tryCatch({
    css_content <- sass::sass(sass::sass_file(scss_path))
    writeLines(css_content, css_path)
    TRUE
}, error = function(e) {
    message(sprintf("[build_css] Error: %s", conditionMessage(e)))
    FALSE
})

elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
if (isTRUE(result)) {
    css_size <- file.info(css_path)$size
    message(sprintf("[build_css] Listo en %.1fs (%d bytes)", elapsed, as.integer(css_size)))
} else {
    message("[build_css] Falló la compilación.")
    quit(save = "no", status = 1)
}
