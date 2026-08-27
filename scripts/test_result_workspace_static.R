#!/usr/bin/env Rscript

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

ui_txt <- read_text("ui.R")
server_txt <- read_text("server.R")
scss_txt <- read_text("custom.scss")
css_txt <- read_text(file.path("www", "css", "cgv_compiled.css"))
js_txt <- read_text(file.path("www", "js", "result_workspace.js"))
layout_js_txt <- read_text(file.path("www", "js", "summary_context_layout.js"))

stopifnot(
  grepl('result_workspace_subheader("homo")', ui_txt, fixed = TRUE),
  grepl('result_workspace_subheader("ortho")', ui_txt, fixed = TRUE),
  grepl('data-workspace-view` = "analytics"', ui_txt, fixed = TRUE) ||
    grepl('workspace_nav_button("analytics"', ui_txt, fixed = TRUE),
  grepl('workspace_nav_button("table"', ui_txt, fixed = TRUE),
  grepl('class = "result-workspace-view-back"', ui_txt, fixed = TRUE),
  grepl('`data-workspace-scope` = "homo"', ui_txt, fixed = TRUE),
  grepl('`data-workspace-scope` = "ortho"', ui_txt, fixed = TRUE),
  grepl('result-workspace-menu--download', ui_txt, fixed = TRUE),
  grepl('data-workspace-alignment-method` = "aligned"', ui_txt, fixed = TRUE),
  grepl('data-workspace-alignment-method` = "pip_blocks"', ui_txt, fixed = TRUE),
  grepl('data-workspace-alignment-method` = "pip_multipip"', ui_txt, fixed = TRUE),
  grepl('js/result_workspace.js', ui_txt, fixed = TRUE),
  grepl('observeEvent(input$toggle_homo_analytics', server_txt, fixed = TRUE),
  grepl('observeEvent(input$toggle_ortho_summary', server_txt, fixed = TRUE),
  grepl('observeEvent(input$homo_workspace_analytics', server_txt, fixed = TRUE),
  grepl('observeEvent(input$ortho_workspace_table', server_txt, fixed = TRUE),
  grepl('observeEvent(input$homo_workspace_view', server_txt, fixed = TRUE),
  grepl('observeEvent(input$ortho_workspace_view', server_txt, fixed = TRUE),
  grepl('outputOptions(output, "homo_summary_dt", suspendWhenHidden = FALSE)', server_txt, fixed = TRUE),
  grepl('outputOptions(output, "ortho_summary_dt", suspendWhenHidden = FALSE)', server_txt, fixed = TRUE),
  grepl('outputOptions(output, "download_homo_summary_csv", suspendWhenHidden = FALSE)', server_txt, fixed = TRUE),
  grepl('outputOptions(output, "download_ortho_summary_csv", suspendWhenHidden = FALSE)', server_txt, fixed = TRUE),
  grepl('set_result_workspace_panel', server_txt, fixed = TRUE),
  grepl('.app-work-indicator', scss_txt, fixed = TRUE),
  grepl('bottom: 20px', scss_txt, fixed = TRUE),
  grepl('.result-workspace-subheader', scss_txt, fixed = TRUE),
  grepl('.result-workspace-alignment-methods', scss_txt, fixed = TRUE),
  grepl('width: 320px', scss_txt, fixed = TRUE),
  grepl('flex-direction: row', scss_txt, fixed = TRUE),
  grepl('width: fit-content', scss_txt, fixed = TRUE),
  grepl('width: calc(100% - 28px)', scss_txt, fixed = TRUE),
  grepl('margin: -1px auto 0', scss_txt, fixed = TRUE),
  grepl('border-radius: 0 0 14px 14px', scss_txt, fixed = TRUE),
  grepl('min-height: 56px', scss_txt, fixed = TRUE),
  grepl('height: 48px', scss_txt, fixed = TRUE),
  grepl('max-height: 48px', scss_txt, fixed = TRUE),
  grepl('.result-workspace-subheader', css_txt, fixed = TRUE),
  grepl('.result-workspace-alignment-methods', css_txt, fixed = TRUE),
  grepl('#ortho_result_workspace_subheader[data-active-view="alignment"]', css_txt, fixed = TRUE),
  grepl('result-workspace-view-analytics', css_txt, fixed = TRUE),
  grepl('primaryScrollTop', js_txt, fixed = TRUE),
  grepl('data-workspace-view', js_txt, fixed = TRUE),
  grepl('updatePanelVisibility', js_txt, fixed = TRUE),
  grepl('notifyWorkspaceView', js_txt, fixed = TRUE),
  grepl('notifyAlignmentMethod', js_txt, fixed = TRUE),
  grepl('alignmentMode', js_txt, fixed = TRUE),
  grepl(".result-workspace-view-back[data-workspace-back]", js_txt, fixed = TRUE),
  grepl("setView(scope, 'visualization')", js_txt, fixed = TRUE),
  grepl('(sectionRect.bottom - paneRect.top) + 6', layout_js_txt, fixed = TRUE),
  grepl('data-workspace-back', js_txt, fixed = TRUE)
)

invisible(parse(file = "ui.R"))
invisible(parse(file = "server.R"))

cat("result-workspace-static-ok\n")
