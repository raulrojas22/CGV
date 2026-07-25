#!/usr/bin/env Rscript

ui_txt <- paste(readLines("ui.R", warn = FALSE), collapse = "\n")
server_txt <- paste(readLines("server.R", warn = FALSE), collapse = "\n")
modules_txt <- paste(readLines(file.path("R", "modules.R"), warn = FALSE), collapse = "\n")
snapshot_txt <- paste(readLines(file.path("R", "server_session_snapshot_domain.R"), warn = FALSE), collapse = "\n")
studio_js <- paste(readLines(file.path("www", "js", "figure_studio.js"), warn = FALSE), collapse = "\n")
studio_css <- paste(readLines(file.path("www", "css", "figure_studio.css"), warn = FALSE), collapse = "\n")
export_js <- paste(readLines(file.path("www", "js", "export_svg.js"), warn = FALSE), collapse = "\n")

expect_pattern <- function(txt, pattern, label) {
  if (!grepl(pattern, txt, perl = TRUE)) {
    stop(sprintf("Missing expected Figure Studio behavior: %s", label), call. = FALSE)
  }
}

expect_absent <- function(txt, pattern, label) {
  if (grepl(pattern, txt, perl = TRUE)) {
    stop(sprintf("Unexpected Figure Studio behavior remains: %s", label), call. = FALSE)
  }
}

expect_pattern(
  ui_txt,
  'class = "app-nav-btn app-nav-btn-figure-studio"[\\s\\S]*`data-target` = "figure-studio"',
  "permanent sidebar entry"
)
expect_pattern(
  ui_txt,
  'tabPanel\\([\\s\\S]*title = "Figure Studio"[\\s\\S]*value = "figure-studio"[\\s\\S]*figure_studio_page\\(\\)',
  "dedicated Figure Studio page"
)
expect_absent(
  paste(ui_txt, studio_js, sep = "\n"),
  'Add to figure|figure-add-chart-btn|figure-gene-card-add|figure-studio-open-btn',
  "outside-the-studio add buttons"
)
expect_absent(
  ui_txt,
  'figure-studio-nav-count',
  "sidebar panel counter"
)
expect_pattern(
  ui_txt,
  'tags\\$option\\(value = "gray", "Paper Gray"\\)[\\s\\S]*tags\\$option\\(value = "mono", "Paper Mono"\\)',
  "paper grayscale and monochrome output profiles"
)
expect_pattern(
  server_txt,
  '"figure-studio"',
  "server-side navigation allow-list"
)
expect_pattern(
  snapshot_txt,
  'figure_studio_state = as.character\\(input\\$figure_studio_state %\\|\\|% ""\\)',
  "work-session snapshot persistence"
)
expect_pattern(
  snapshot_txt,
  'sendCustomMessage\\("cgv:figure-studio-restore", studio_state\\)',
  "work-session restore"
)
expect_pattern(
  studio_js,
  'panels: \\[\\]',
  "empty initial canvas"
)
expect_pattern(
  studio_js,
  'state\\.panels\\.push\\(panel\\)',
  "variable-length panel collection"
)
if (grepl("MAX_PANELS|maxPanels|panels\\.length\\s*[>=]+\\s*[0-9]+\\s*\\)\\s*return", studio_js, perl = TRUE)) {
  stop("Figure Studio must not impose a fixed panel-count limit", call. = FALSE)
}
expect_pattern(
  studio_js,
  'function panelLabel\\(index\\)[\\s\\S]*String\\.fromCharCode',
  "automatic A-Z/AA panel labels"
)
expect_pattern(
  studio_js,
  'function reorderPanel\\(sourceId, targetId\\)',
  "panel reordering"
)
expect_pattern(
  studio_js,
  'function buildCompositeSvg\\(\\)',
  "single publication figure assembly"
)
expect_pattern(
  ui_txt,
  'id = "figure-studio-preview"[\\s\\S]*id = "figure-studio-preview-modal"[\\s\\S]*id = "figure-studio-preview-paper"',
  "final export preview interface"
)
expect_pattern(
  ui_txt,
  'id = "figure-studio-guide-toggle"[\\s\\S]*id = "figure-studio-guide"[\\s\\S]*Build a figure in five steps[\\s\\S]*Save the CGV session',
  "step-by-step Figure Studio guide"
)
expect_pattern(
  ui_txt,
  'data-figure-tooltip',
  "contextual Figure Studio tooltips"
)
expect_pattern(
  studio_js,
  'function openExportPreview\\(\\)[\\s\\S]*buildCompositeSvg\\(\\)[\\s\\S]*figure-studio-final-preview-svg[\\s\\S]*function exportSvg\\(\\)',
  "preview is built from the exact export composition"
)
expect_pattern(
  studio_js,
  'function mountPreviewModal\\(\\)[\\s\\S]*document\\.body\\.appendChild\\(modal\\)[\\s\\S]*mountPreviewModal\\(\\)',
  "preview escapes page stacking contexts"
)
expect_pattern(
  studio_js,
  'function setGuideOpen\\(open, anchor\\)[\\s\\S]*data-figure-guide-open[\\s\\S]*function toggleGuide\\(event\\)',
  "interactive help guide behavior"
)
expect_pattern(
  studio_js,
  'function positionGuide\\(anchor\\)[\\s\\S]*trigger\\.getBoundingClientRect\\(\\)[\\s\\S]*guide\\.style\\.left[\\s\\S]*function setGuideOpen\\(open, anchor\\)',
  "help guide stays anchored to the button that opened it"
)
expect_pattern(
  studio_js,
  'function exportSvg\\(\\)[\\s\\S]*function exportPng\\(\\)',
  "SVG and PNG export"
)
expect_pattern(
  studio_js,
  'MAX_PNG_PIXELS',
  "bounded PNG memory use"
)
expect_absent(
  studio_js,
  'sessionStorage\\.(?:getItem|setItem)',
  "automatic browser draft restoration"
)
expect_pattern(
  studio_js,
  'window\\.Shiny\\.setInputValue\\("figure_studio_state"[\\s\\S]*function restoreExternalDraft',
  "Figure Studio remains available to explicit CGV session saving"
)
expect_pattern(
  studio_js,
  'new MutationObserver\\(function \\(mutations\\)[\\s\\S]*closest\\("\\.figure-studio-page"\\)',
  "observer excludes mutations produced by the studio itself"
)
expect_pattern(
  studio_js,
  'figure_studio_plot_render_request[\\s\\S]*pollForSvg\\(\\[dynamic\\.outputId, dynamic\\.rootId\\], 25000\\)',
  "on-demand rendering for unvisited result plots"
)
expect_pattern(
  studio_js,
  'function requestAnalyticsRender\\(context\\)[\\s\\S]*context \\+ "_analytics_export_all_nonce"',
  "Figure Studio requests its hidden Analytics render directly"
)
expect_pattern(
  studio_js,
  'function acquireAlignedSvg\\(definition, context\\)[\\s\\S]*figure_studio_alignment_render_request[\\s\\S]*setVisualMode\\(context, "aligned"\\)[\\s\\S]*pollForSvg\\(sourceCandidates\\(definition, context\\), 30000\\)',
  "eligible aligned views render on demand without a manual visit"
)
expect_pattern(
  studio_js,
  'note: dynamicReady \\? "Ready to add" : "Rendered when added"',
  "unvisited result plots remain actionable"
)
expect_pattern(
  studio_js,
  'category: isTranscript \\? "Transcripts" : "Gene structures"[\\s\\S]*\\["Gene structures", "Transcripts", "Analytics", "Alignment"\\]',
  "separate gene, transcript, Analytics, and alignment library sections"
)
expect_pattern(
  studio_js,
  'function collapseCatalogGroups\\(context\\)[\\s\\S]*catalogGroupExpanded\\[itemContext \\+ ":" \\+ groupName\\] = false[\\s\\S]*collapseCatalogGroups\\(state\\.context\\)',
  "every catalog section is collapsed when Figure Studio opens"
)
expect_pattern(
  server_txt,
  '`data-transcript-id` = tx_title[\\s\\S]*`data-gene-name` = gene_title',
  "transcript identifiers are available before plot rendering"
)
expect_pattern(
  studio_js,
  'var catalogIdentifierTitle = dynamicGroup === "Transcripts"[\\s\\S]*"Transcript ID: " \\+ transcriptLabel[\\s\\S]*figure-catalog-identifier',
  "transcript identifiers are visible and searchable in the panel library"
)
expect_pattern(
  studio_js,
  'dynamic\\.geneName[\\s\\S]*"Gene: " \\+ dynamic\\.geneName[\\s\\S]*dynamic\\.organismName',
  "gene structures show the gene before the organism"
)
expect_pattern(
  studio_js,
  'function clearDynamicSourcesForContext\\(context\\)[\\s\\S]*seenByContext[\\s\\S]*summary\\.style\\.display === "none"',
  "result-source inventory survives navigation but clears with actual results"
)
expect_pattern(
  studio_js,
  'function autoPlotHeight\\(panel, contentWidth, previewMode\\)[\\s\\S]*panelSvgAspect\\(panel\\)[\\s\\S]*function resolvedPanelHeight',
  "adaptive panel geometry based on each source SVG"
)
expect_pattern(
  studio_js,
  'height: validHeightMode\\(opts\\.height\\) \\? opts\\.height : "auto"',
  "automatic height is the new-panel default"
)
expect_pattern(
  studio_js,
  'sourceKind === "alignment" \\|\\| sourceKind === "result"[\\s\\S]*\\? state\\.columns',
  "elongated gene and alignment sources default to full figure width"
)
expect_pattern(
  ui_txt,
  'id = "figure-studio-subtitle"[\\s\\S]*placeholder = "Study, cohort, method, or comparison"',
  "optional publication subtitle control"
)
expect_pattern(
  studio_js,
  'title\\.setAttribute\\("x", String\\(pageWidth / 2\\)\\)[\\s\\S]*title\\.setAttribute\\("text-anchor", "middle"\\)[\\s\\S]*cgv-figure-subtitle',
  "centered publication title and optional subtitle"
)
expect_pattern(
  studio_js,
  'Object\\.prototype\\.hasOwnProperty\\.call\\(next, "title"\\)[\\s\\S]*String\\(next\\.title == null \\? "" : next\\.title\\)[\\s\\S]*var hasTitle = String\\(state\\.title \\|\\| ""\\)\\.trim\\(\\)\\.length > 0[\\s\\S]*hasTitle \\? \\(hasSubtitle \\? 108 : 82\\) : \\(hasSubtitle \\? 74 : 36\\)',
  "an intentionally empty figure title remains empty and removes its export spacing"
)
expect_pattern(
  studio_js,
  'function updateTextEdit\\(target\\)[\\s\\S]*document\\.addEventListener\\("input"[\\s\\S]*updateTextEdit\\(event\\.target\\)',
  "figure title and subtitle state update immediately while typing"
)
expect_pattern(
  studio_css,
  'var\\(--app-text[\\s\\S]*var\\(--app-panel-border[\\s\\S]*figure-studio-guide[\\s\\S]*figure-studio-tooltip-portal[\\s\\S]*html\\[data-app-theme="dark"\\] \\.figure-studio-guide',
  "app-native light/dark theming and contextual help"
)
expect_pattern(
  studio_css,
  '\\.figure-studio-header \\{[\\s\\S]*var\\(--summary-card-border[\\s\\S]*var\\([\\s\\S]*--summary-card-bg[\\s\\S]*var\\([\\s\\S]*--summary-card-shadow',
  "Figure Studio header follows the Multi-Gene and Cross-Species summary-card language"
)
expect_pattern(
  studio_css,
  '\\.figure-studio-guide \\{[\\s\\S]*position: fixed;[\\s\\S]*z-index: 10020;[\\s\\S]*\\.figure-studio-tooltip-portal \\{[\\s\\S]*position: fixed;[\\s\\S]*z-index: 10080;',
  "help overlays render above every Figure Studio stacking context"
)
expect_pattern(
  studio_js,
  'function ensureTooltipPortal\\(\\)[\\s\\S]*document\\.body\\.appendChild\\(tooltipPortal\\)[\\s\\S]*function positionFigureTooltip\\(trigger\\)[\\s\\S]*function bindFigureTooltips\\(\\)[\\s\\S]*bindFigureTooltips\\(\\)',
  "all Figure Studio tooltips use the body-level floating portal"
)
expect_absent(
  studio_css,
  'data-figure-tooltip[^\\{]*::(?:before|after)',
  "legacy pseudo-element tooltips"
)
expect_pattern(
  ui_txt,
  'class = "figure-studio-tooltip-anchor"[\\s\\S]*Undo the latest Figure Studio edit[\\s\\S]*class = "figure-studio-tooltip-anchor"[\\s\\S]*Redo the latest undone edit',
  "disabled history buttons keep hoverable tooltip anchors"
)
expect_pattern(
  studio_css,
  '\\.figure-studio-preview-header \\{[\\s\\S]*padding: 17px 20px 18px;[\\s\\S]*\\.figure-studio-preview-header p \\{[\\s\\S]*line-height: 1\\.45;',
  "preview header spacing keeps its explanatory text clear"
)
expect_pattern(
  studio_js,
  'var gapX = 24;[\\s\\S]*var gapY = 26;',
  "space-efficient export panel gaps"
)
expect_pattern(
  export_js,
  'function beginAnalyticsExportButton\\(mode, totalCount\\)[\\s\\S]*aria-busy[\\s\\S]*function finishAnalyticsExportButton',
  "visible Analytics ZIP busy and completion feedback"
)
expect_pattern(
  export_js,
  'waitForAnalyticsEntries\\(namedEntries, ENTRY_TIMEOUT_MS,[\\s\\S]*updateAnalyticsExportButton',
  "Analytics ZIP progress updates while hidden charts render"
)
expect_pattern(
  server_txt,
  'observeEvent\\(input\\$figure_studio_plot_render_request[\\s\\S]*set_background_render\\)\\) \\{[\\s\\S]*set_background_render\\(TRUE\\)',
  "server-side background materialization route"
)
expect_pattern(
  server_txt,
  'observeEvent\\(input\\$figure_studio_alignment_render_request[\\s\\S]*suspendWhenHidden = FALSE',
  "aligned output can render while Figure Studio is visible"
)
expect_pattern(
  modules_txt,
  'set_background_render = function\\(enabled = TRUE\\)',
  "plot modules can temporarily render while hidden"
)
if (grepl(
  'observeEvent\\(input\\$(?:homo|ortho)_analytics_export_all_nonce, \\{\\s*if \\(!isTRUE\\((?:homo|ortho)AnalyticsVisible\\(\\)\\)\\)',
  server_txt,
  perl = TRUE
)) {
  stop("Analytics export rendering must work outside the visible Analytics page", call. = FALSE)
}
expect_pattern(
  server_txt,
  'homo_export_summary <- reactive\\(\\{[\\s\\S]*get_homo_summary_df\\(perf_context = "HOMO_SUM_EXPORT"\\)[\\s\\S]*ortho_export_summary <- reactive\\(\\{[\\s\\S]*get_ortho_summary_df\\(perf_context = "ORTHO_SUM_EXPORT"\\)',
  "hidden Analytics export summaries bypass visible-tab gating"
)
expect_pattern(
  studio_js,
  'definition\\.key === "pip"[\\s\\S]*Run LASTZ first',
  "explicit LASTZ prerequisite"
)
expect_pattern(
  studio_css,
  'grid-template-columns: repeat\\(var\\(--figure-columns\\), minmax\\(0, 1fr\\)\\)',
  "dynamic one-to-three-column canvas"
)

cat("figure-studio-static-ok\n")
