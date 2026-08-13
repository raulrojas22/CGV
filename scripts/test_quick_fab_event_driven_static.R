#!/usr/bin/env Rscript

ui_txt <- paste(readLines("ui.R", warn = FALSE, encoding = "UTF-8"), collapse = "\n")

stopifnot(
    grepl("function scheduleQuickFabVisibilityUpdate()", ui_txt, fixed = TRUE),
    grepl("new window.ResizeObserver(scheduleQuickFabVisibilityUpdate)", ui_txt, fixed = TRUE),
    grepl("document.addEventListener('shown.bs.tab', scheduleQuickFabVisibilityUpdate)", ui_txt, fixed = TRUE),
    grepl("document.addEventListener('shiny:value', scheduleQuickFabVisibilityUpdate)", ui_txt, fixed = TRUE),
    !grepl("__quickFabTopWatcher", ui_txt, fixed = TRUE),
    !grepl("setInterval(updateQuickFabScrollTopVisibility, 300)", ui_txt, fixed = TRUE)
)

cat("quick-fab-event-driven-static-ok\n")
