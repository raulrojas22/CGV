# ui.R

analytics_chart_order_choices <- c(
  "Load order" = "load",
  "Gene length (longest first)" = "gene_len_desc",
  "Gene length (shortest first)" = "gene_len_asc",
  "Transcript length (longest first)" = "tx_len_desc",
  "Transcript length (shortest first)" = "tx_len_asc",
  "Exon count (high to low)" = "exon_desc",
  "Exon count (low to high)" = "exon_asc",
  "Intron count (high to low)" = "intron_desc",
  "Intron count (low to high)" = "intron_asc",
  "GC% (high to low)" = "gc_desc",
  "GC% (low to high)" = "gc_asc",
  "Label (A-Z)" = "label_asc",
  "Label (Z-A)" = "label_desc"
)

analytics_arch_order_choices <- c(
  "Load order" = "load",
  "Gene length (longest first)" = "gene_len_desc",
  "Gene length (shortest first)" = "gene_len_asc",
  "CDS/Transcript % (high to low)" = "cds_tx_desc",
  "CDS/Transcript % (low to high)" = "cds_tx_asc",
  "Intronic bp (high to low)" = "intron_bp_desc",
  "Intronic bp (low to high)" = "intron_bp_asc",
  "Label (A-Z)" = "label_asc",
  "Label (Z-A)" = "label_desc"
)

analytics_exon_order_choices <- c(
  "Load order" = "load",
  "Exon count (high to low)" = "exon_desc",
  "Exon count (low to high)" = "exon_asc",
  "Intron count (high to low)" = "intron_desc",
  "Intron count (low to high)" = "intron_asc",
  "Exonic bp (high to low)" = "exonic_bp_desc",
  "Exonic bp (low to high)" = "exonic_bp_asc",
  "Intronic bp (high to low)" = "intron_bp_desc",
  "Intronic bp (low to high)" = "intron_bp_asc",
  "Label (A-Z)" = "label_asc",
  "Label (Z-A)" = "label_desc"
)

analytics_seq_order_choices <- c(
  "Load order" = "load",
  "GC% (high to low)" = "gc_desc",
  "GC% (low to high)" = "gc_asc",
  "A% (high to low)" = "a_desc",
  "A% (low to high)" = "a_asc",
  "T% (high to low)" = "t_desc",
  "T% (low to high)" = "t_asc",
  "C% (high to low)" = "c_desc",
  "C% (low to high)" = "c_asc",
  "G% (high to low)" = "g_desc",
  "G% (low to high)" = "g_asc",
  "Label (A-Z)" = "label_asc",
  "Label (Z-A)" = "label_desc"
)

analytics_context_order_choices <- c(
  "Load order" = "load",
  "Upstream distance |bp| (high to low)" = "up_abs_desc",
  "Upstream distance |bp| (low to high)" = "up_abs_asc",
  "Downstream distance |bp| (high to low)" = "down_abs_desc",
  "Downstream distance |bp| (low to high)" = "down_abs_asc",
  "Any overlap first" = "overlap_first",
  "Any overlap last" = "overlap_last",
  "Label (A-Z)" = "label_asc",
  "Label (Z-A)" = "label_desc"
)

analytics_exon_dist_order_choices <- c(
  "Load order" = "load",
  "Exon count (high to low)" = "exon_desc",
  "Exon count (low to high)" = "exon_asc",
  "Transcript length (longest first)" = "tx_len_desc",
  "Transcript length (shortest first)" = "tx_len_asc",
  "Gene length (longest first)" = "gene_len_desc",
  "Gene length (shortest first)" = "gene_len_asc",
  "Label (A-Z)" = "label_asc",
  "Label (Z-A)" = "label_desc"
)

analytics_scatter_order_choices <- c(
  "Load order" = "load",
  "Draw largest genes on top" = "gene_len_desc",
  "Draw smallest genes on top" = "gene_len_asc",
  "Draw high GC% on top" = "gc_desc",
  "Draw low GC% on top" = "gc_asc",
  "Draw high exon-count on top" = "exon_desc",
  "Draw low exon-count on top" = "exon_asc",
  "Label (A-Z)" = "label_asc",
  "Label (Z-A)" = "label_desc"
)

analytics_heatmap_order_choices <- c(
  "Load order" = "load",
  "Gene length (longest first)" = "gene_len_desc",
  "Gene length (shortest first)" = "gene_len_asc",
  "Transcript length (longest first)" = "tx_len_desc",
  "Transcript length (shortest first)" = "tx_len_asc",
  "GC% (high to low)" = "gc_desc",
  "GC% (low to high)" = "gc_asc",
  "Exon count (high to low)" = "exon_desc",
  "Exon count (low to high)" = "exon_asc",
  "Label (A-Z)" = "label_asc",
  "Label (Z-A)" = "label_desc"
)

analytics_radar_order_choices <- c(
  "Load order" = "load",
  "Gene length (longest first)" = "gene_len_desc",
  "Gene length (shortest first)" = "gene_len_asc",
  "Transcript length (longest first)" = "tx_len_desc",
  "Transcript length (shortest first)" = "tx_len_asc",
  "GC% (high to low)" = "gc_desc",
  "GC% (low to high)" = "gc_asc",
  "CDS/Transcript % (high to low)" = "cds_tx_desc",
  "CDS/Transcript % (low to high)" = "cds_tx_asc",
  "Label (A-Z)" = "label_asc",
  "Label (Z-A)" = "label_desc"
)

analytics_corr_order_choices <- c(
  "Default metric order" = "metric_default",
  "Metric name (A-Z)" = "metric_alpha_asc",
  "Metric name (Z-A)" = "metric_alpha_desc",
  "By mean |r| (high to low)" = "mean_abs_corr_desc",
  "By mean |r| (low to high)" = "mean_abs_corr_asc",
  "Clustered (similar together)" = "cluster"
)

analytics_chart_toolbar <- function(container_id, filename, order_input_id, label = "SVG", order_width = "248px", choices = analytics_chart_order_choices) {
  selected_value <- if (length(choices) > 0) unname(as.character(choices[[1]])) else "load"
  if (!nzchar(selected_value)) selected_value <- "load"
  tags$div(
    class = "chart-export-tip chart-export-tip--with-order",
    tags$button(
      type = "button",
      class = "btn btn-sm btn-export-svg chart-export-btn",
      onclick = sprintf("exportSVG('%s', '%s');", container_id, filename),
      icon("download"),
      label
    ),
    div(
      class = "chart-order-inline",
      selectInput(
        inputId = order_input_id,
        label = NULL,
        choices = choices,
        selected = selected_value,
        width = order_width
      )
    )
  )
}

analytics_scatter_tip_html <- paste0(
  "<strong>GC Content vs Gene Length</strong><br/>",
  "Bubble scatter built from the analytics summary table. Each point is one loaded entry.",
  "<div class='ci-axes'><b>X-axis:</b> GC content (%) [0&ndash;100]<br/>",
  "<b>Y-axis:</b> Gene length (bp, >0)<br/>",
  "<b>Bubble size:</b> Exon count (larger = more exons)</div>",
  "<div class='ci-formula'><b>GC formula:</b> GC% = ((G + C) / (A + T + G + C)) &times; 100<br/>",
  "<b>Where:</b> G,C,A,T = counts of each nucleotide in the sequence; denominator = total nucleotide count.</div>",
  "<div class='ci-ranges'><b>How to read:</b> upper-right = long + GC-rich genes; lower-left = compact + low-GC genes. ",
  "<b>Draw order</b> only changes which bubbles are visible on top when points overlap.</div>"
)

analytics_heatmap_tip_html <- paste0(
  "<strong>Gene Metrics Heatmap</strong><br/>",
  "Compares 8 metrics across loaded entries: Gene length, representative transcript length, exons, introns, GC%, CDS/Tx%, exonic bp, and CDS bp.",
  "<div class='ci-axes'><b>X-axis:</b> Loaded entries<br/>",
  "<b>Y-axis:</b> Metrics<br/><b>Color:</b> Blue = lower than group average, White = near average, Red = higher</div>",
  "<div class='ci-formula'><b>Z-score:</b> Z = (x &minus; &mu;) / &sigma;<br/>",
  "<b>Where:</b> x = this gene value; &mu; = mean across loaded genes; &sigma; = standard deviation across loaded genes.</div>",
  "<div class='ci-ranges'><b>Range guide:</b> Z = 0 mean; +1/+2 above mean; &minus;1/&minus;2 below mean.</div>",
  "<div class='ci-tip'>bp metrics (gene length, representative transcript length, exonic bp, CDS bp) are log&#8321;&#8320;-transformed before Z-scoring. Requires &ge;2 genes.</div>"
)

analytics_radar_tip_html <- paste0(
  "<strong>Gene Profile Radar</strong><br/>",
  "Spider plot across 6 metrics: Gene length, representative transcript length, exons, introns, GC%, and CDS/Transcript%.",
  "<div class='ci-axes'><b>Scale:</b> normalized 0&ndash;1 on each axis independently<br/>",
  "<b>Rings:</b> 25%, 50%, 75%, 100%</div>",
  "<div class='ci-formula'><b>Min&ndash;max normalization:</b> value = (x &minus; min) / (max &minus; min)<br/>",
  "<b>Where:</b> x = this gene value in one metric; min/max = smallest/largest value for that same metric across loaded genes.</div>",
  "<div class='ci-ranges'><b>Range guide:</b> 0 = lowest value in the loaded set, 1 = highest, 0.5 = midpoint.</div>",
  "<div class='ci-tip'>Larger and rounder polygons indicate broadly higher values across metrics. Requires &ge;2 genes with complete metrics.</div>"
)

analytics_corr_tip_html <- paste0(
  "<strong>Pairwise Correlation Matrix</strong><br/>",
  "Pearson correlation between the same 8 structural metrics across loaded entries.",
  "<div class='ci-axes'><b>Axes:</b> Metric names on X and Y<br/>",
  "<b>Color:</b> Blue = negative, White = near 0, Red = positive<br/>",
  "<b>Cell value:</b> r from &minus;1 to +1</div>",
  "<div class='ci-formula'><b>Pearson formula:</b> r = cov(X,Y) / (&sigma;<sub>X</sub>&sigma;<sub>Y</sub>)<br/>",
  "<b>Where:</b> X,Y = two metrics being compared; cov(X,Y) = covariance; &sigma;<sub>X</sub>, &sigma;<sub>Y</sub> = standard deviations of X and Y.</div>",
  "<div class='ci-ranges'><b>r bands:</b> 0.9&ndash;1.0 very strong (+), 0.7&ndash;0.9 strong, 0.5&ndash;0.7 moderate, 0.0&ndash;0.3 negligible; ",
  "&minus;0.3&ndash;0.0 negligible (&minus;), &minus;0.7&ndash;&minus;0.3 weak/moderate (&minus;), &minus;1.0&ndash;&minus;0.7 strong/very strong (&minus;).</div>",
  "<div class='ci-tip'>Diagonal cells are always 1.00. bp metrics are log&#8321;&#8320;-transformed before correlation. Requires &ge;3 genes.</div>"
)

fluidPage(
  theme = theme_custom,
  tagList(
    # Configuración general
    tags$head(
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1, viewport-fit=cover"),
      tags$meta(name = "cgv-app-version", content = app_asset_version),
      tags$meta(`http-equiv` = "Cache-Control", content = "no-cache, must-revalidate"),
      tags$meta(`http-equiv` = "Pragma", content = "no-cache"),
      tags$meta(`http-equiv` = "Expires", content = "0"),
      tags$title("CGV | Comparative Gene Viewer"),
      tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"),
      tags$script(HTML(sprintf("
        window.__cgvAppVersion = %s;
        window.__cgvDefaultLightIcon = %s;
        window.__cgvDefaultDarkIcon = %s;
        (function () {
          function normalizeVersion(value) {
            return String(value || '').trim();
          }

          function buildProbeUrl() {
            var probeUrl = new URL(window.location.href);
            probeUrl.searchParams.set('__cgv_probe__', String(Date.now()));
            return probeUrl.toString();
          }

          function buildReloadUrl(nextVersion) {
            var reloadUrl = new URL(window.location.href);
            reloadUrl.searchParams.delete('__cgv_probe__');
            reloadUrl.searchParams.set('v', nextVersion);
            return reloadUrl.toString();
          }

          function maybeReloadForNewVersion() {
            var currentVersion = normalizeVersion(window.__cgvAppVersion);
            if (!currentVersion || !window.fetch || !window.DOMParser) return;

            fetch(buildProbeUrl(), {
              cache: 'no-store',
              credentials: 'same-origin',
              headers: { 'Cache-Control': 'no-cache' }
            })
              .then(function (resp) {
                if (!resp.ok) throw new Error('version probe failed');
                return resp.text();
              })
              .then(function (html) {
                var doc = new DOMParser().parseFromString(html, 'text/html');
                var meta = doc.querySelector('meta[name=\"cgv-app-version\"]');
                var latestVersion = normalizeVersion(meta && meta.getAttribute('content'));
                if (latestVersion && latestVersion !== currentVersion) {
                  window.location.replace(buildReloadUrl(latestVersion));
                }
              })
              .catch(function () {});
          }

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', maybeReloadForNewVersion, { once: true });
          } else {
            maybeReloadForNewVersion();
          }
        })();
      ",
      jsonlite::toJSON(app_asset_version, auto_unbox = TRUE),
      jsonlite::toJSON(versioned_asset_path("favicon2.ico?v=2"), auto_unbox = TRUE),
      jsonlite::toJSON(versioned_asset_path("favicon.ico?v=2"), auto_unbox = TRUE)))),
      tags$script(HTML("
        Shiny.addCustomMessageHandler('lastz_debug', function(msg) {
          var level = msg.level || 'log';
          var prefix = '%c[LASTZ-DEBUG]';
          var style = 'color:#e74c3c;font-weight:bold';
          if (level === 'error') {
            console.error(prefix, style, msg.step, msg.detail || '');
          } else if (level === 'warn') {
            console.warn(prefix, style, msg.step, msg.detail || '');
          } else {
            console.log(prefix, style, msg.step, msg.detail || '');
          }
          if (msg.data) { console.table(msg.data); }
        });
      ")),
      tags$link(rel = "shortcut icon", type = "image/x-icon", href = versioned_asset_path("favicon.ico?v=2")),
      tags$style(HTML("
      :root {
        --app-font-family: 'Roboto', 'Helvetica Neue', Arial, sans-serif;
      }
      .navbar {
        background-color: #2C3E50 !important;
        margin: 0 !important;
        border-radius: 0 !important;
        width: 100%;
        max-width: 100%;
      }
      .navbar-brand {
        padding: 5px 15px !important;
        height: 50px !important;
        display: flex;
        align-items: center;
      }
      .navbar-brand-content {
        display: flex;
        align-items: center;
        height: 100%;
      }
      .navbar-logo {
        height: 38px;
        margin-right: 12px;
        border-radius: 2px;
        object-fit: contain;
      }
      .navbar-text-container {
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
      }
      .navbar-title-main {
        font-family: var(--app-font-family);
        font-size: 34px;
        font-weight: 900;
        letter-spacing: 12px;
        line-height: 0.85;
        margin-bottom: 4px;
        color: #FFFFFF;
        text-align: center;
        -webkit-text-stroke: 2px #FFFFFF;
        margin-left: 12px;
        transform: scaleX(1.15);
      }
      .navbar-title-sub {
        font-size: 9.5px;
        font-weight: 600;
        letter-spacing: 0px;
        line-height: 1;
        color: #FFFFFF;
        white-space: nowrap;
        text-align: center;
      }
      html, body {
        font-family: var(--app-font-family) !important;
        margin: 0 !important;
        padding: 0 !important;
        height: 100%;
        min-height: 100%;
        width: 100%;
        max-width: 100%;
        overflow-x: hidden !important;
        overflow-y: hidden !important;
        overscroll-behavior: none !important;
        overscroll-behavior-x: none !important;
        overscroll-behavior-y: none !important;
        background: var(--app-shell-bg) !important;
      }
      button, input, optgroup, select, textarea {
        font-family: inherit !important;
      }
      input, textarea, select {
        color-scheme: light;
      }
      input[list] {
        color: #2C3E50 !important;
        -webkit-text-fill-color: #2C3E50 !important;
        caret-color: #2C3E50;
      }
      datalist, datalist option {
        color: #2C3E50 !important;
        background-color: #FFFFFF !important;
      }
      .panel-content .selectize-dropdown .option.active,
      .panel-content .selectize-dropdown .option.selected,
      .panel-content .selectize-dropdown .option.active.selected,
      .panel-content .selectize-dropdown [data-selectable].active,
      .panel-content .selectize-dropdown [data-selectable].selected,
      .panel-content .selectize-dropdown .active,
      .panel-content .selectize-dropdown .selected,
      .panel-content .selectize-dropdown-content .active,
      .panel-content .selectize-dropdown-content .selected {
        background: #DDF4EE !important;
        background-color: #DDF4EE !important;
        background-image: none !important;
        color: #2C3E50 !important;
      }
      .panel-content .selectize-dropdown .option.active *,
      .panel-content .selectize-dropdown .option.selected *,
      .panel-content .selectize-dropdown .active *,
      .panel-content .selectize-dropdown .selected * {
        color: #2C3E50 !important;
      }
      .panel-content .dropdown-menu > .active > a,
      .panel-content .dropdown-menu > .active > a:hover,
      .panel-content .dropdown-menu > .active > a:focus,
      .panel-content .bootstrap-select .dropdown-menu li.active > a,
      .panel-content .bootstrap-select .dropdown-menu li.active > a:hover,
      .panel-content .bootstrap-select .dropdown-menu li.selected > a,
      .panel-content .bootstrap-select .dropdown-menu li.selected > a:hover {
        background: #DDF4EE !important;
        background-color: #DDF4EE !important;
        color: #2C3E50 !important;
        background-image: none !important;
      }
      .navbar-brand, .nav-link {
        color: #FFFFFF !important;
      }
      .nav-link.active {
        color: #18BC9C !important;
      }
      .nav-link:hover {
        color: #18BC9C !important;
      }
      .btn-primary {
        background-color: #18BC9C !important;
        border-color: #18BC9C !important;
      }
      .btn-primary:hover {
        background-color: #128F76 !important;
        border-color: #128F76 !important;
      }
      .btn-download {
        position: static !important;
        padding: 2px 5px;
        font-size: 12px;
        background-color: #18BC9C !important;
        border-color: #18BC9C !important;
        margin: 0 !important;
      }
      .btn-clear-plots {
        background-color: #F3F6F9 !important;
        border: 1px solid #C9D3DD !important;
        color: #2C3E50 !important;
        font-weight: 600;
      }
      .btn-clear-plots:hover {
        background-color: #E8EEF4 !important;
        border-color: #B8C6D3 !important;
      }
      .card {
        box-shadow: 0 4px 8px 0 rgba(0,0,0,0.1);
        transition: 0.3s;
        border-radius: 5px;
        margin-bottom: 20px;
        min-height: auto !important;
      }
      .card:hover {
        box-shadow: 0 8px 16px 0 rgba(0,0,0,0.2);
      }
      .card-header {
        background: #2C3E50 !important;
        color: white !important;
        font-weight: bold;
        border-radius: 5px 5px 0 0 !important;
        margin-bottom: 0 !important;
        padding: 8px 15px !important;
        display: flex;
        align-items: center;
        justify-content: space-between;
      }
      .card-isoform .card-header {
        background: #356D75 !important;
      }
      .card-body {
        padding: 0 5px 5px 5px !important;
      }
      .ggiraph-container {
        margin: 0 auto;
        text-align: left;
        width: 100% !important;
        height: 100% !important;
        overflow-x: hidden;
        overflow-y: hidden;
      }
      .ggiraph-svg, .ggiraph-svg-0 {
        display: block !important;
        margin: 0 !important;
        width: 100% !important;
        height: 100% !important;
      }
      .ggiraph-svg svg {
        width: 100% !important;
        height: 100% !important;
        max-width: none !important;
        display: block !important;
      }
      .promoter-plot-container {
        position: relative;
        overflow: visible;
        line-height: 0;
        display: flex;
        align-items: center;
      }
      .promoter-plot-container.plot-geometry-settling {
        pointer-events: none !important;
      }
      .promoter-plot-container.plot-geometry-settling > :not(.promoter-plot-transition-loader) {
        visibility: hidden !important;
      }
      .promoter-plot-transition-loader {
        position: absolute;
        inset: 0;
        display: none;
        align-items: center;
        justify-content: center;
        overflow: hidden;
        pointer-events: none;
        z-index: 3;
      }
      .promoter-plot-container.plot-geometry-settling .promoter-plot-transition-loader {
        display: flex;
      }
      .promoter-plot-transition-loader .promoter-plot-dna-loader {
        width: 132px;
        height: 34px;
        transform: scale(0.5);
        transform-origin: center center;
        opacity: 0.94;
      }
      .promoter-plot-transition-loader .promoter-plot-dna-loader .app-dna-node::before {
        box-shadow: 0 0 0 1px rgba(24, 188, 156, 0.14), 0 0 6px rgba(24, 188, 156, 0.22);
      }
      .promoter-plot-container > .html-widget,
      .promoter-plot-container > .html-widget-output,
      .promoter-plot-container > .girafe,
      .promoter-plot-container .girafe,
      .promoter-plot-container .html-widget,
      .promoter-plot-container .girafe_container_std,
      .promoter-plot-container .ggiraph-container {
        width: 100% !important;
        height: 100% !important;
        min-height: 100% !important;
        max-height: 100% !important;
        margin: 0 !important;
        display: flex !important;
        align-items: center !important;
      }
      .promoter-plot-container .girafe_container_std {
        text-align: left !important;
        justify-content: stretch !important;
      }
      .promoter-plot-container .girafe_container {
        padding-bottom: 0 !important;
        height: 100% !important;
        display: flex !important;
        align-items: center !important;
      }
      .promoter-plot-container svg.ggiraph-svg,
      .promoter-plot-container .girafe_container_std > svg {
        display: block !important;
        width: 100% !important;
        height: 100% !important;
        min-height: 100% !important;
        max-height: 100% !important;
        margin: 0 !important;
        vertical-align: top !important;
      }
      .promoter-region-popup {
        position: fixed;
        left: 0;
        top: 0;
        width: min(430px, calc(100vw - 24px));
        max-height: min(420px, calc(100vh - 24px));
        background: #F8FCFB;
        border: 1px solid #BFDCD4;
        border-radius: 12px;
        box-shadow: 0 14px 30px rgba(27, 58, 72, 0.28);
        z-index: 12120;
        overflow: hidden;
        opacity: 0;
        transform: translateY(10px);
        pointer-events: none;
        transition: opacity 0.2s ease, transform 0.2s ease;
      }
      .promoter-region-popup.open {
        opacity: 1;
        transform: translateY(0);
        pointer-events: auto;
      }
      .promoter-region-popup.place-top::before {
        content: '';
        position: absolute;
        left: 50%;
        bottom: -10px;
        transform: translateX(-50%);
        border-width: 10px 9px 0 9px;
        border-style: solid;
        border-color: #BFDCD4 transparent transparent transparent;
      }
      .promoter-region-popup.place-top::after {
        content: '';
        position: absolute;
        left: 50%;
        bottom: -9px;
        transform: translateX(-50%);
        border-width: 9px 8px 0 8px;
        border-style: solid;
        border-color: #F8FCFB transparent transparent transparent;
      }
      .promoter-region-popup.place-bottom::before {
        content: '';
        position: absolute;
        left: 50%;
        top: -10px;
        transform: translateX(-50%);
        border-width: 0 9px 10px 9px;
        border-style: solid;
        border-color: transparent transparent #BFDCD4 transparent;
      }
      .promoter-region-popup.place-bottom::after {
        content: '';
        position: absolute;
        left: 50%;
        top: -9px;
        transform: translateX(-50%);
        border-width: 0 8px 9px 8px;
        border-style: solid;
        border-color: transparent transparent #2C3E50 transparent;
      }
      .promoter-region-popup-header {
        background: #2C3E50;
        color: #FFFFFF;
        min-height: 48px;
        padding: 10px 12px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        border-bottom: 1px solid rgba(255, 255, 255, 0.12);
        gap: 8px;
      }
      .promoter-region-popup-title-wrap {
        min-width: 0;
        flex: 1 1 auto;
      }
      .promoter-region-popup-title {
        margin: 0;
        font-size: 15px;
        font-weight: 700;
        line-height: 1.1;
      }
      .promoter-region-popup-subtitle {
        margin: 2px 0 0;
        font-size: 11px;
        font-weight: 600;
        line-height: 1.2;
        color: rgba(255, 255, 255, 0.88);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }
      .promoter-region-popup-close {
        border: 1px solid rgba(255, 255, 255, 0.26);
        background: rgba(255, 255, 255, 0.06);
        color: #FFFFFF;
        border-radius: 7px;
        min-width: 28px;
        height: 28px;
        padding: 0 8px;
        line-height: 1;
        font-size: 17px;
        font-weight: 600;
        flex: 0 0 auto;
      }
      .promoter-region-popup-close:hover {
        background: rgba(24, 188, 156, 0.22);
        border-color: rgba(24, 188, 156, 0.6);
      }
      .promoter-region-popup-body {
        background: linear-gradient(180deg, #F8FCFB 0%, #EEF6F4 100%);
        padding: 10px;
        overflow-y: auto;
      }
      .promoter-len-label {
        display: block;
        margin: 0 0 4px;
        font-size: 12px;
        font-weight: 700;
        color: #2C3E50;
      }
      .promoter-len-input {
        width: 100%;
        height: 32px;
        border: 1px solid #BFDCD4;
        border-radius: 7px;
        padding: 5px 8px;
        background: #FFFFFF;
        color: #2C3E50;
        font-size: 12.6px;
        font-weight: 600;
        outline: none;
      }
      .promoter-len-input:focus {
        border-color: #66CCBC;
        box-shadow: 0 0 0 2px rgba(24, 188, 156, 0.18);
      }
      .promoter-len-slider {
        width: 100%;
        margin: 8px 0 4px;
        accent-color: #18BC9C;
        cursor: pointer;
      }
      .promoter-len-hint {
        margin: 0 0 8px;
        color: #5D6D7E;
        font-size: 11px;
        font-weight: 600;
      }
      .promoter-download-btn {
        width: 100%;
        height: 32px;
        border: 1px solid #0F8E79;
        border-radius: 7px;
        background: #18BC9C;
        color: #FFFFFF;
        font-size: 12px;
        font-weight: 700;
        line-height: 1;
        padding: 0 8px;
      }
      .promoter-download-btn:hover {
        background: #149A83;
        border-color: #0D7C6B;
      }
      .alert {
        position: fixed;
        bottom: 20px;
        right: 20px;
        z-index: 9999;
        min-width: 300px;
        animation: slideIn 0.5s ease-in-out;
      }
      .app-status-popup {
        position: fixed;
        right: 18px;
        bottom: 18px;
        width: min(460px, calc(100vw - 24px));
        max-height: 52vh;
        background: #F8FCFB;
        border: 1px solid #BFDCD4;
        border-radius: 12px;
        box-shadow: 0 14px 30px rgba(27, 58, 72, 0.28);
        z-index: 12050;
        overflow: hidden;
        display: flex;
        flex-direction: column;
        opacity: 0;
        transform: translateY(14px);
        pointer-events: none;
        transition: opacity 0.2s ease, transform 0.2s ease;
      }
      .app-status-popup.open {
        opacity: 1;
        transform: translateY(0);
        pointer-events: auto;
      }
      .app-status-popup-header {
        background: #2C3E50;
        color: #FFFFFF;
        min-height: 48px;
        padding: 10px 12px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        border-bottom: 1px solid rgba(255, 255, 255, 0.12);
      }
      .app-status-popup-title {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        font-size: 15px;
        font-weight: 700;
        letter-spacing: 0.1px;
      }
      .app-status-popup-actions {
        display: inline-flex;
        align-items: center;
        gap: 6px;
      }
      .app-status-popup-btn {
        border: 1px solid rgba(255, 255, 255, 0.26);
        background: rgba(255, 255, 255, 0.06);
        color: #FFFFFF;
        border-radius: 7px;
        min-width: 28px;
        height: 28px;
        padding: 0 8px;
        line-height: 1;
        font-size: 12px;
        font-weight: 600;
      }
      .app-status-popup-btn:hover {
        background: rgba(24, 188, 156, 0.22);
        border-color: rgba(24, 188, 156, 0.6);
      }
      .app-status-popup-loader {
        display: none;
        padding: 12px 10px 10px;
        border-bottom: 1px solid #D7E8E3;
        background: linear-gradient(180deg, #F3FBF8 0%, #ECF5FA 100%);
        align-items: center;
        justify-content: center;
        flex-direction: column;
        gap: 8px;
        flex: 1 1 auto;
      }
      .app-status-popup.loading .app-status-popup-loader {
        display: flex;
        border-bottom: none;
        min-height: 210px;
      }
      .app-dna-loader {
        width: 220px;
        height: 56px;
        position: relative;
      }
      .app-dna-wave {
        position: absolute;
        inset: 0;
        display: flex;
        justify-content: space-between;
      }
      .app-dna-wave .app-dna-node {
        position: relative;
        width: 8px;
        height: 8px;
        border-radius: 50%;
        transform: translateY(0);
        animation: app-dna-shift 1.85s ease-in-out infinite;
        animation-delay: calc(var(--i) * -0.09s);
      }
      .app-dna-wave .app-dna-node::before {
        content: '';
        position: absolute;
        inset: 0;
        border-radius: 50%;
        background: #18BC9C;
        box-shadow: 0 0 0 1px rgba(24, 188, 156, 0.18), 0 0 8px rgba(24, 188, 156, 0.32);
        animation: app-dna-scale 1.85s linear infinite;
        animation-delay: calc(var(--i) * -0.09s);
      }
      .app-dna-wave-top .app-dna-node {
        animation-direction: reverse;
      }
      .app-dna-wave-top .app-dna-node::before {
        background: #18BC9C;
      }
      .app-dna-wave-bottom .app-dna-node {
        animation-delay: calc(0.92s + (var(--i) * -0.09s));
      }
      .app-dna-wave-bottom .app-dna-node::before {
        background: #2C3E50;
        box-shadow: 0 0 0 1px rgba(44, 62, 80, 0.18), 0 0 8px rgba(44, 62, 80, 0.28);
        animation-delay: calc(0.92s + (var(--i) * -0.09s));
      }
      html[data-app-theme=\"dark\"] .app-dna-wave .app-dna-node::before {
        background: #18BC9C;
        box-shadow: 0 0 0 1px rgba(24, 188, 156, 0.28), 0 0 10px rgba(24, 188, 156, 0.44);
      }
      html[data-app-theme=\"dark\"] .app-dna-wave-top .app-dna-node::before {
        background: #18BC9C;
        box-shadow: 0 0 0 1px rgba(24, 188, 156, 0.28), 0 0 10px rgba(24, 188, 156, 0.44);
      }
      html[data-app-theme=\"dark\"] .app-dna-wave-bottom .app-dna-node::before {
        background: #FFFFFF;
        box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.28), 0 0 10px rgba(255, 255, 255, 0.44);
      }
      .app-status-popup-loader-text {
        color: #2C3E50;
        font-size: 13px;
        font-weight: 700;
        text-align: center;
        white-space: pre-line;
        line-height: 1.4;
        max-width: 96%;
        margin-top: 16px;
      }
      .app-status-popup-log {
        background: linear-gradient(180deg, #F8FCFB 0%, #EEF6F4 100%);
        padding: 10px;
        overflow-y: auto;
        overflow-x: hidden;
        flex: 1 1 auto;
      }
      .app-status-popup.loading .app-status-popup-log {
        display: none;
      }
      .app-status-popup-entry {
        background: #FFFFFF;
        border: 1px solid #D7E8E3;
        border-left: 4px solid #18BC9C;
        border-radius: 9px;
        padding: 8px 10px 9px;
        margin-bottom: 8px;
        box-shadow: 0 1px 2px rgba(44, 62, 80, 0.06);
      }
      .app-status-popup-entry:last-child {
        margin-bottom: 0;
      }
      .app-status-popup-entry-head {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 4px;
        gap: 8px;
      }
      .app-status-popup-entry-context {
        color: #2C3E50;
        font-size: 11px;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.3px;
      }
      .app-status-popup-entry-time {
        color: #6C8191;
        font-size: 11px;
        font-weight: 600;
      }
      .app-status-popup-entry-text {
        color: #1F2E38;
        font-size: 13px;
        line-height: 1.35;
        white-space: pre-wrap;
        word-break: break-word;
      }
      .app-status-popup.tone-info .app-status-popup-header { background: #2C3E50; }
      .app-status-popup.tone-success .app-status-popup-header { background: #0F8E79; }
      .app-status-popup.tone-warning .app-status-popup-header { background: #A86C18; }
      .app-status-popup.tone-error .app-status-popup-header { background: #9A2F2F; }
      .app-status-popup-entry.tone-info { border-left-color: #18BC9C; }
      .app-status-popup-entry.tone-success { border-left-color: #0F8E79; }
      .app-status-popup-entry.tone-warning { border-left-color: #D08A1E; }
      .app-status-popup-entry.tone-error { border-left-color: #CC4C4C; }
      @keyframes app-dna-shift {
        0%, 100% { transform: translateY(0); }
        50% { transform: translateY(46px); }
      }
      @keyframes app-dna-scale {
        0%, 100% { transform: scale(1); opacity: 0.86; }
        25% { transform: scale(1.65); opacity: 1; }
        50% { transform: scale(0.95); opacity: 0.84; }
        75% { transform: scale(0.55); opacity: 0.52; }
      }
      @media (max-width: 768px) {
        .app-status-popup {
          right: 10px;
          bottom: 10px;
          width: calc(100vw - 20px);
          max-height: 46vh;
        }
      }
      @keyframes slideIn {
        from {
          transform: translateX(100%);
          opacity: 0;
        }
        to {
          transform: translateX(0);
          opacity: 1;
        }
      }
      .waiter-overlay {
        background-color: rgba(255, 255, 255, 0.8);
      }
      .loading-message {
        color: #2C3E50;
        font-size: 1.2em;
        margin-top: 10px;
      }
      .panel-content {
        background-color: white;
        padding: 20px;
        border-radius: 5px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.05);
      }
      .blast-option {
        margin: 10px 0;
        display: flex;
        align-items: center;
        gap: 5px;
      }
      .blast-info-icon {
        color: #18BC9C;
        cursor: help;
        margin-left: 5px;
      }
      .blast-info-icon:hover {
        color: #128F76;
      }
      .viz-mode-wrap {
        margin-top: 0;
        margin-bottom: 0;
      }
      .viz-mode-wrap .control-label {
        display: none;
      }
      .container-fluid, .container, .container-sm, .container-md, .container-lg, .container-xl, .container-xxl {
        max-width: 100% !important;
        width: 100% !important;
        padding-left: 0 !important;
        padding-right: 0 !important;
      }
      .viz-mode-toggle .shiny-options-group {
        --app-switch-bg-clr: linear-gradient(180deg, #E3E7EC 0%, #D8DDE4 100%);
        --app-switch-border-clr: #BCC5CF;
        --app-switch-padding: 3px;
        --app-slider-bg-clr: linear-gradient(135deg, #18BC9C 0%, #2C7FB8 100%);
        --app-slider-bg-clr-on: linear-gradient(135deg, #18BC9C 0%, #2C7FB8 100%);
        --app-slider-txt-clr: #FFFFFF;
        --app-switch-count: 2;
        --app-switch-index: 0;
        position: relative;
        isolation: isolate;
        display: grid;
        grid-template-columns: repeat(var(--app-switch-count), minmax(0, 1fr));
        gap: 0 !important;
        margin: 0 !important;
        padding: 0 !important;
        width: 100%;
        border: 1px solid var(--app-switch-border-clr);
        border-radius: 9999px;
        background: var(--app-switch-bg-clr);
        box-shadow: inset 0 1px 1px rgba(255, 255, 255, 0.38), 0 2px 8px rgba(19, 49, 74, 0.12);
      }
      .viz-mode-toggle .shiny-options-group::before {
        content: '';
        position: absolute;
        top: var(--app-switch-padding);
        bottom: var(--app-switch-padding);
        left: var(--app-switch-padding);
        width: calc((100% - (var(--app-switch-padding) * 2)) / var(--app-switch-count));
        border-radius: 9999px;
        background: var(--app-slider-bg-clr);
        box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.28), 0 1px rgba(255, 255, 255, 0.3);
        transform: translateX(calc(var(--app-switch-index) * 100%));
        transition: transform 220ms ease, background-color 220ms ease;
        z-index: -1;
      }
      .viz-mode-toggle .shiny-options-group:has(.radio-inline input[type='radio']:checked)::before,
      .viz-mode-toggle .shiny-options-group.has-selection::before {
        background: var(--app-slider-bg-clr-on);
      }
      .viz-mode-toggle .shiny-options-group:focus-within {
        box-shadow: 0 0 0 2px rgba(26, 76, 108, 0.22), inset 0 1px 1px rgba(255, 255, 255, 0.35), 0 2px 8px rgba(22, 52, 76, 0.12);
      }
      .app-control-panel .viz-mode-toggle .radio-inline {
        margin: 0 !important;
        min-height: 32px;
        padding: 6px 10px !important;
        cursor: pointer;
        font-weight: 700;
        font-size: 11.2px;
        letter-spacing: 0;
        line-height: 1.1;
        color: #1F425B !important;
        opacity: 0.92;
        background: transparent;
        border: none;
        border-radius: 9999px !important;
        text-align: center;
        white-space: normal;
        word-wrap: break-word;
        display: grid !important;
        place-items: center;
        align-content: center;
        text-indent: 0 !important;
        position: relative;
        z-index: 1;
        transition: color 220ms ease, opacity 220ms ease;
      }
      .app-control-panel .viz-mode-toggle .radio-inline input[type='radio'] {
        position: absolute;
        width: 1px;
        height: 1px;
        padding: 0;
        margin: 0 !important;
        overflow: hidden;
        clip: rect(0, 0, 0, 0);
        white-space: nowrap;
        border-width: 0;
      }
      .app-control-panel .viz-mode-toggle .radio-inline:has(input[type='radio']:checked),
      .app-control-panel .viz-mode-toggle .radio-inline.is-active {
        color: var(--app-slider-txt-clr) !important;
        opacity: 1;
      }
      .app-control-panel .viz-mode-toggle .radio-inline:hover:not(.is-active) {
        opacity: 1;
        color: #17384F !important;
      }
      /* 5-option ortho visual mode toggle: tighter padding + smaller font so labels fit */
      #ortho_visual_mode.viz-mode-toggle .shiny-options-group {
        min-height: 42px;
      }
      #ortho_visual_mode.viz-mode-toggle .radio-inline {
        padding: 5px 2px !important;
        font-size: 9.5px !important;
        min-height: 42px;
        line-height: 1.2;
        white-space: normal;
        word-break: normal;
        overflow-wrap: normal;
        hyphens: none;
      }
      .homo-action-row {
        display: flex;
        gap: 10px;
        margin-top: 6px;
        margin-bottom: 8px;
        flex-wrap: wrap;
      }
      .homo-action-cell {
        flex: 1 1 0;
        min-width: 140px;
      }
      .homo-action-btn {
        width: 100%;
        min-height: 48px !important;
        border-radius: 8px !important;
        padding: 8px 12px !important;
        display: flex !important;
        flex-direction: row;
        align-items: center;
        justify-content: center;
        gap: 8px;
        text-align: center;
        line-height: 1.2;
        font-size: 14px !important;
        font-weight: 600 !important;
        white-space: normal !important;
      }
      .homo-action-btn .fa {
        font-size: 16px;
        margin-bottom: 0;
      }
    ")),
      tags$style(HTML("
      /* ── Plot zoom control ─────────────────────────────────── */
      .plot-zoom-control {
        display: inline-flex;
        align-items: center;
        gap: 3px;
        background: #EEF2F5;
        border: 1px solid #B8C4CE;
        border-radius: 7px;
        padding: 2px 5px;
        flex-shrink: 0;
      }
      .plot-zoom-btn {
        background: none;
        border: none;
        cursor: pointer;
        color: #2C3E50;
        font-size: 15px;
        font-weight: 700;
        width: 22px;
        height: 22px;
        display: flex;
        align-items: center;
        justify-content: center;
        border-radius: 4px;
        padding: 0;
        line-height: 1;
        transition: background 0.12s;
        flex-shrink: 0;
      }
      .plot-zoom-btn:hover:not(:disabled) { background: #C4D4DF; }
      .plot-zoom-btn:disabled { opacity: 0.3; cursor: not-allowed; }
      .plot-zoom-label {
        font-size: 11px;
        font-weight: 600;
        color: #2C3E50;
        min-width: 34px;
        text-align: center;
        cursor: default;
        user-select: none;
      }
      /* Scroll wrapper around plot containers */
      .plots-zoom-wrap {
        width: 100%;
        max-width: none; /* allow transcript plots to use the full pane width; SVG width behavior is stabilized in plot_zoom.js */
        overflow-x: auto;
        overflow-y: visible;
      }
      #plot-container,
      #ortho-plot-container {
        min-width: 100%;
        transition: width 0.2s ease;
      }
      /* Dark mode */
      html[data-app-theme='dark'] .plot-zoom-control {
        background: #223347;
        border-color: #2D4460;
      }
      html[data-app-theme='dark'] .plot-zoom-btn,
      html[data-app-theme='dark'] .plot-zoom-label {
        color: #A8C5DA;
      }
      html[data-app-theme='dark'] .plot-zoom-btn:hover:not(:disabled) {
        background: #2D4460;
      }
      /* ── Analytics pill tabs – light mode ─────────────────── */
      #homo_analytics_tabs .nav-link,
      #ortho_analytics_tabs .nav-link,
      #chart_modal_tabs .nav-link,
      ul#homo_analytics_tabs .nav-link,
      ul#ortho_analytics_tabs .nav-link,
      ul#chart_modal_tabs .nav-link {
        color: #2C3E50 !important;
        background-color: #DDE3E9 !important;
        border: 1px solid #B8C4CE !important;
        border-radius: 20px !important;
        font-size: 12px !important;
        font-weight: 500 !important;
        padding: 4px 13px !important;
        opacity: 1 !important;
        visibility: visible !important;
      }
      #homo_analytics_tabs .nav-link:hover,
      #ortho_analytics_tabs .nav-link:hover,
      #chart_modal_tabs .nav-link:hover,
      ul#homo_analytics_tabs .nav-link:hover,
      ul#ortho_analytics_tabs .nav-link:hover,
      ul#chart_modal_tabs .nav-link:hover {
        background-color: #C4D4DF !important;
        color: #1A2B3C !important;
      }
      #homo_analytics_tabs .nav-link.active,
      #ortho_analytics_tabs .nav-link.active,
      #chart_modal_tabs .nav-link.active,
      ul#homo_analytics_tabs .nav-link.active,
      ul#ortho_analytics_tabs .nav-link.active,
      ul#chart_modal_tabs .nav-link.active {
        background-color: #2C3E50 !important;
        color: #ffffff !important;
        border-color: #2C3E50 !important;
        font-weight: 600 !important;
      }
      /* ── ggiraph tooltip z-index fix ──────────────────────── */
      .tooltip_ggint,
      .girafe-tooltip,
      div[id^='tooltip_'] {
        z-index: 99999 !important;
        pointer-events: none !important;
      }
      /* Prevent analytics chart containers from trapping tooltips */
      .analytics-chart-wrap,
      .analytics-chart-wrap .ggiraph-container,
      .analytics-chart-wrap .ggiraph-svg,
      .analytics-chart-wrap .ggiraph-svg svg,
      .girafe_container_std,
      .girafe_container_std svg {
        overflow: visible !important;
      }
      .analytics-chart-wrap .ggiraph-svg,
      .analytics-chart-wrap .ggiraph-svg svg {
        height: auto !important;
      }
      .chart-modal-chart-wrap .girafe_container_std,
      .chart-modal-chart-wrap .ggiraph-container,
      .chart-modal-chart-wrap .ggiraph-svg,
      .chart-modal-chart-wrap .girafe_container_std svg,
      .chart-modal-chart-wrap .ggiraph-svg svg {
        width: 100% !important;
        max-width: 100% !important;
        height: auto !important;
        overflow: visible !important;
      }
      /* Main transcript structure blocks (exon/CDS/UTR/etc): subtle rounded corners */
      .plot-transcript-card .girafe_container_std svg rect[data-id^='feature_'],
      .plot-transcript-card .girafe_container_std svg rect[data-id^='compact_region_'] {
        rx: 3.4px;
        ry: 3.4px;
      }
      /* ── Dark mode overrides ───────────────────────────────── */
      html[data-app-theme='dark'] #homo_analytics_tabs .nav-link,
      html[data-app-theme='dark'] #ortho_analytics_tabs .nav-link,
      html[data-app-theme='dark'] #chart_modal_tabs .nav-link,
      html[data-app-theme='dark'] ul#homo_analytics_tabs .nav-link,
      html[data-app-theme='dark'] ul#ortho_analytics_tabs .nav-link,
      html[data-app-theme='dark'] ul#chart_modal_tabs .nav-link {
        color: #A8C5DA !important;
        background-color: #223347 !important;
        border-color: #2D4460 !important;
      }
      html[data-app-theme='dark'] #homo_analytics_tabs .nav-link.active,
      html[data-app-theme='dark'] #ortho_analytics_tabs .nav-link.active,
      html[data-app-theme='dark'] #chart_modal_tabs .nav-link.active,
      html[data-app-theme='dark'] ul#homo_analytics_tabs .nav-link.active,
      html[data-app-theme='dark'] ul#ortho_analytics_tabs .nav-link.active,
      html[data-app-theme='dark'] ul#chart_modal_tabs .nav-link.active {
        background-color: #18BC9C !important;
        color: #ffffff !important;
        border-color: #18BC9C !important;
      }
      ")),
      tags$script(HTML("
      Shiny.addCustomMessageHandler('force_refresh_picker', function(message) {
        var ids = (message && message.ids) ? message.ids : [];
        ids.forEach(function(id) {
          var $el = $('#' + id);
          if ($el.length && $el.hasClass('selectpicker')) {
            $el.prop('disabled', false);
            $el.selectpicker('refresh');
            $el.selectpicker('render');
            $el.parent('.bootstrap-select').removeClass('disabled');
          }
        });
      });

      function applyRoundedTranscriptFeatureRects(root) {
        var scope = root && root.querySelectorAll ? root : document;
        var nodes = scope.querySelectorAll(
          '.plot-transcript-card .girafe_container_std svg rect[data-id^=\"feature_\"], ' +
          '.plot-transcript-card .girafe_container_std svg rect[data-id^=\"compact_region_\"]'
        );
        if (!nodes || !nodes.length) return;
        nodes.forEach(function(node) {
          node.setAttribute('rx', '3.4');
          node.setAttribute('ry', '3.4');
        });
      }

      function installRoundedTranscriptFeatureRectObserver() {
        if (window.__cgvRoundedFeatureRectObserverInstalled) return;
        window.__cgvRoundedFeatureRectObserverInstalled = true;

        var rafQueued = false;
        var queueApply = function() {
          if (rafQueued) return;
          rafQueued = true;
          window.requestAnimationFrame(function() {
            rafQueued = false;
            applyRoundedTranscriptFeatureRects(document);
          });
        };

        applyRoundedTranscriptFeatureRects(document);

        if (window.MutationObserver && document.body) {
          var observer = new MutationObserver(function() {
            queueApply();
          });
          observer.observe(document.body, { childList: true, subtree: true });
        }

        document.addEventListener('shiny:value', queueApply, true);
        document.addEventListener('shiny:recalculated', queueApply, true);
      }

      function sanitizeAutocompleteChoices(values, maxItems) {
        var list = Array.isArray(values) ? values : [];
        var limit = Math.max(1, parseInt(maxItems || 8000, 10));
        var seen = Object.create(null);
        var out = [];
        for (var i = 0; i < list.length; i += 1) {
          var vv = (list[i] === null || list[i] === undefined) ? '' : String(list[i]);
          vv = vv.replace(/\\s+/g, ' ').trim();
          if (!vv) continue;
          var key = vv.toLowerCase();
          if (seen[key]) continue;
          seen[key] = true;
          out.push(vv);
          if (out.length >= limit) break;
        }
        return out;
      }

      Shiny.addCustomMessageHandler('update_gene_autocomplete', function(message) {
        var inputId = (message && message.input_id) ? message.input_id : '';
        if (!inputId) return;
        var isGlobalSearch = inputId === 'global_search_query';
        var listId = inputId + '_suggestions';
        var choicesRaw = (message && message.choices) ? message.choices : [];
        var choices = sanitizeAutocompleteChoices(choicesRaw, isGlobalSearch ? 15000 : 3000);
        var dl = document.getElementById(listId);
        var inputEl = document.getElementById(inputId);
        if (inputEl) {
          var useNativeDatalist = !isGlobalSearch;
          if (useNativeDatalist) {
            inputEl.setAttribute('list', listId);
            inputEl.setAttribute('autocomplete', 'off');
          } else {
            inputEl.removeAttribute('list');
            inputEl.setAttribute('autocomplete', 'new-password');
          }
          inputEl.setAttribute('data-form-type', 'other');
          inputEl.setAttribute('data-lpignore', 'true');
          inputEl.setAttribute('data-1p-ignore', 'true');
          inputEl.setAttribute('autocorrect', 'off');
          inputEl.setAttribute('autocapitalize', 'off');
          inputEl.setAttribute('spellcheck', 'false');
          inputEl.style.color = '#2C3E50';
          inputEl.style.backgroundColor = '#F8FCFB';
          inputEl.style.caretColor = '#2C3E50';
          inputEl.style.colorScheme = 'light';
        }

        if (isGlobalSearch) {
          window.__globalGeneSuggestionPool = choices;
          if (dl && dl.replaceChildren) {
            dl.replaceChildren();
          } else if (dl) {
            dl.innerHTML = '';
          }
          var updatedEvt;
          try {
            updatedEvt = new Event('cgv-global-suggestions-updated');
          } catch (err) {
            updatedEvt = document.createEvent('Event');
            updatedEvt.initEvent('cgv-global-suggestions-updated', true, true);
          }
          document.dispatchEvent(updatedEvt);
          return;
        }

        if (!dl) return;
        var frag = document.createDocumentFragment();
        choices.forEach(function(vv) {
          var opt = document.createElement('option');
          opt.value = vv;
          opt.label = vv;
          opt.textContent = vv;
          frag.appendChild(opt);
        });
        // Temporarily disconnect the input from the datalist before updating it.
        // This prevents Chrome/Edge from triggering inline autocomplete during the
        // update, which can silently delete the last 1-3 characters the user typed.
        var savedList = inputEl ? inputEl.getAttribute('list') : null;
        if (inputEl && savedList) inputEl.removeAttribute('list');
        if (dl.replaceChildren) {
          dl.replaceChildren(frag);
        } else {
          dl.innerHTML = '';
          dl.appendChild(frag);
        }
        if (inputEl && savedList) inputEl.setAttribute('list', savedList);
      });

      document.addEventListener('DOMContentLoaded', function() {
        installRoundedTranscriptFeatureRectObserver();

        var syncVizModeToggles = function() {
          var groups = document.querySelectorAll('.viz-mode-toggle .shiny-options-group');
          groups.forEach(function(group) {
            var labels = group.querySelectorAll('.radio-inline');
            var activeIndex = 0;
            var hasActive = false;

            labels.forEach(function(lbl, idx) {
              var radio = lbl.querySelector('input[type=\"radio\"]');
              var isActive = !!(radio && radio.checked);
              lbl.classList.toggle('is-active', isActive);
              if (isActive) {
                activeIndex = idx;
                hasActive = true;
              }
            });

            group.style.setProperty('--app-switch-count', String(Math.max(labels.length, 1)));
            group.style.setProperty('--app-switch-index', String(activeIndex));
            group.classList.toggle('has-selection', hasActive);
          });
        };
        document.addEventListener('change', function(evt) {
          var t = evt && evt.target ? evt.target : null;
          if (t && t.matches('.viz-mode-toggle input[type=\"radio\"]')) {
            syncVizModeToggles();
          }
        });
        $(document).on('shiny:value', syncVizModeToggles);
        syncVizModeToggles();

        var input1 = document.getElementById('filter1');
        if (input1) {
          input1.setAttribute('list', 'filter1_suggestions');
          input1.setAttribute('autocomplete', 'off');
          input1.setAttribute('autocorrect', 'off');
          input1.setAttribute('autocapitalize', 'off');
          input1.setAttribute('spellcheck', 'false');
          input1.style.color = '#2C3E50';
          input1.style.backgroundColor = '#F8FCFB';
          input1.style.caretColor = '#2C3E50';
          input1.style.colorScheme = 'light';
        }
        var input2 = document.getElementById('gene_name');
        if (input2) {
          input2.setAttribute('list', 'gene_name_suggestions');
          input2.setAttribute('autocomplete', 'off');
          input2.setAttribute('autocorrect', 'off');
          input2.setAttribute('autocapitalize', 'off');
          input2.setAttribute('spellcheck', 'false');
          input2.style.color = '#2C3E50';
          input2.style.backgroundColor = '#F8FCFB';
          input2.style.caretColor = '#2C3E50';
          input2.style.colorScheme = 'light';
        }

        function triggerWorkflowEnterSearch(mode, rawValue) {
          if (!window.Shiny || typeof Shiny.setInputValue !== 'function') return false;
          var normalizedMode = String(mode || '').trim();
          if (normalizedMode !== 'homologous' && normalizedMode !== 'orthologous') return false;
          var gene = String(rawValue == null ? '' : rawValue);
          Shiny.setInputValue('workflow_enter_search', {
            mode: normalizedMode,
            gene: gene,
            nonce: Date.now()
          }, { priority: 'event' });
          return true;
        }

        if (input1 && input1.getAttribute('data-enter-search-bound') !== '1') {
          input1.setAttribute('data-enter-search-bound', '1');
          input1.addEventListener('keydown', function(evt) {
            if (!evt || evt.key !== 'Enter' || evt.ctrlKey || evt.metaKey || evt.altKey || evt.shiftKey) return;
            evt.preventDefault();
            evt.stopPropagation();
            triggerWorkflowEnterSearch('homologous', input1.value || '');
          });
        }

        if (input2 && input2.getAttribute('data-enter-search-bound') !== '1') {
          input2.setAttribute('data-enter-search-bound', '1');
          input2.addEventListener('keydown', function(evt) {
            if (!evt || evt.key !== 'Enter' || evt.ctrlKey || evt.metaKey || evt.altKey || evt.shiftKey) return;
            evt.preventDefault();
            evt.stopPropagation();
            triggerWorkflowEnterSearch('orthologous', input2.value || '');
          });
        }
      });

      function getOrganismSummaryTarget(inputId) {
        if (inputId === 'homo_preloaded_species') return $('#homo-organism-summary-text');
        if (inputId === 'ortho_preloaded_species') return $('#ortho-organism-summary-text');
        return $();
      }

      function updateOrganismSummaryFromGrid($grid) {
        if (!$grid || !$grid.length) return;

        var inputId = String($grid.attr('data-input-id') || '');
        if (!inputId) return;
        var $allGrids = $('.species-grid[data-input-id=\"' + inputId + '\"]');
        if (!$allGrids.length) return;
        var mode = String($allGrids.first().attr('data-mode') || 'single');
        var $target = getOrganismSummaryTarget(inputId);
        if (!$target.length) return;

        var defaultLabel = 'Organism selection';
        var selectedManyTemplate = '{n} organisms selected';

        var $selected = $allGrids.find('.species-grid-card.selected');
        if ($selected.length === 0) {
          $target.text(defaultLabel);
          return;
        }

        var $first = $selected.first();
        var name = String($first.find('.species-grid-name').text() || '').trim();
        var iconSrc = String($first.find('.species-grid-icon-img').attr('src') || '').trim();

        if (mode === 'single' || $selected.length === 1) {
          if (iconSrc) {
            $target.html(
              '<span class=\"app-organism-selected\">' +
                '<span class=\"app-organism-selected-icon\"><img class=\"app-organism-selected-img\" src=\"' + $('<span>').text(iconSrc).html() + '\" alt=\"\"/></span>' +
                '<span class=\"app-organism-selected-name\"><em>' + $('<span>').text(name || defaultLabel).html() + '</em></span>' +
              '</span>'
            );
          } else {
            $target.html('<em>' + $('<span>').text(name || defaultLabel).html() + '</em>');
          }
          return;
        }

        var countText = selectedManyTemplate.replace('{n}', String($selected.length));
        $target.text(countText);
      }

      /* ── Species grid: single-select (homologous) ── */
      $(document).on('click', '.species-grid[data-mode=\"single\"] .species-grid-card', function(e) {
        e.stopPropagation();
        var $card = $(this);
        var $grid = $card.closest('.species-grid');
        var inputId = String($grid.attr('data-input-id') || '');
        var id    = $card.attr('data-species-id') || '';
        if (!inputId) return;
        $('.species-grid[data-input-id=\"' + inputId + '\"] .species-grid-card').removeClass('selected');
        $card.addClass('selected');
        Shiny.setInputValue(inputId, id, {priority: 'event'});
        updateOrganismSummaryFromGrid($grid);
        var $details = $grid.closest('details');
        if ($details.length) {
          $details.removeAttr('open').removeProp('open');
        }
      });

      /* ── Species grid: multi-select (orthologous) ── */
      $(document).on('click', '.species-grid[data-mode=\"multi\"] .species-grid-card', function(e) {
        e.stopPropagation();
        var $card = $(this);
        $card.toggleClass('selected');
        var $grid = $card.closest('.species-grid');
        var inputId = String($grid.attr('data-input-id') || '');
        if (!inputId) return;
        var $allGrids = $('.species-grid[data-input-id=\"' + inputId + '\"]');
        var sel   = [];
        $allGrids.find('.species-grid-card.selected').each(function() {
          sel.push($(this).attr('data-species-id'));
        });
        Shiny.setInputValue(inputId, sel.length ? sel : null, {priority: 'event'});
        updateOrganismSummaryFromGrid($grid);
      });

      // Keep organism summary labels consistent after Shiny UI re-renders.
      $(document).on('shiny:value', function() {
        $('.species-grid[data-input-id]').each(function() {
          updateOrganismSummaryFromGrid($(this));
        });
      });

      // Initial sync (for cases where grids are already present).
      setTimeout(function() {
        $('.species-grid[data-input-id]').each(function() {
          updateOrganismSummaryFromGrid($(this));
        });
      }, 0);
    ")),
      tags$script(src = versioned_asset_path("js/keepalive.js")),
      tags$script(src = versioned_asset_path("js/dna_loader_unifier.js")),
      tags$script(src = versioned_asset_path("js/plot_zoom.js")),
      tags$script(src = versioned_asset_path("js/export_svg.js")),
      tags$script(src = versioned_asset_path("js/status_popup.js")),
      tags$script(src = versioned_asset_path("js/promoter_popup.js")),
      tags$script(src = versioned_asset_path("js/go_terms_popup.js")),
      tags$script(src = versioned_asset_path("js/papers_popup.js")),
      tags$script(src = versioned_asset_path("js/preloaded_assembly_popup.js")),
      tags$script(src = versioned_asset_path("js/metrics_popup.js")),
      tags$script(src = versioned_asset_path("js/ortho_lazy_loader.js")),
      tags$script(src = versioned_asset_path("js/summary_context_layout.js")),
      tags$script(src = versioned_asset_path("js/ncbi_search.js")),
      tags$script(src = versioned_asset_path("js/mobile_enhancements.js"), defer = NA),
      tags$script(HTML("
      (function () {
        var validTargets = ['home', 'homologous', 'orthologous', 'settings', 'help', 'feedback'];
        var suggestionState = { items: [], activeIndex: -1 };
        var collapsedSuggestionState = { items: [], activeIndex: -1 };
        var suggestionObserver = null;
        var globalSuggestionPool = Array.isArray(window.__globalGeneSuggestionPool)
          ? window.__globalGeneSuggestionPool.slice()
          : [];
        var globalSearchChips = [];
        var lastWorkflowTarget = 'homologous';
        var quickFabPanel = null;
        var suppressWorkflowPanelOnNextNav = false;

        function isValidTarget(target) {
          return validTargets.indexOf(target) !== -1;
        }

        function updateBatchUiVisibility(target) {
          // Batch UI is exclusive to Homologous Search
          var isHomologous = target === 'homologous';
          var batchGroup       = document.getElementById('sidebar-batch-ui-group');
          var batchCount       = document.getElementById('global-search-batch-count');
          var collapsedPreview = document.getElementById('collapsed-batch-preview');
          var searchHint       = document.getElementById('sidebar-search-hint');
          var searchInput      = document.getElementById('global_search_query');
          var collapsedInput   = document.getElementById('global_search_query_collapsed');
          if (batchGroup)       batchGroup.style.display       = isHomologous ? '' : 'none';
          if (batchCount)       batchCount.style.display       = isHomologous ? '' : 'none';
          if (collapsedPreview) collapsedPreview.style.display = isHomologous ? '' : 'none';
          if (searchHint)       searchHint.style.display       = isHomologous ? '' : 'none';
          // Placeholder reflects mode: batch hint only in homologous
          var ph = isHomologous ? 'Search gene (add to batch)' : 'Search gene';
          if (searchInput)    searchInput.placeholder    = ph;
          if (collapsedInput) collapsedInput.placeholder = ph;
        }

        function setActiveNav(target) {
          if (target === 'homologous' || target === 'orthologous') {
            lastWorkflowTarget = target;
          }
          updateBatchUiVisibility(target);
          var buttons = document.querySelectorAll('.app-nav-btn');
          buttons.forEach(function (btn) {
            btn.classList.toggle('is-active', btn.getAttribute('data-target') === target);
          });
          syncQuickFabModeControls();
          updateCompactModeLayoutState();
          updateQuickFabScrollTopVisibility();
        }

        function getActiveNavTarget() {
          var activeTabLink = document.querySelector('#navtabs li.active > a[data-value]');
          if (activeTabLink) {
            var tabValue = String(activeTabLink.getAttribute('data-value') || '').trim();
            if (isValidTarget(tabValue)) return tabValue;
          }

          var activePane = getActiveTabPane();
          if (activePane && activePane.id) {
            var paneSelector = '.app-main .nav a[data-value][href=\"#' + activePane.id + '\"]';
            var paneLink = document.querySelector(paneSelector);
            if (paneLink) {
              var paneValue = String(paneLink.getAttribute('data-value') || '').trim();
              if (isValidTarget(paneValue)) return paneValue;
            }
          }

          var activeBtn = document.querySelector('.app-nav-btn.is-active[data-target]');
          return activeBtn ? activeBtn.getAttribute('data-target') : null;
        }

        function updateCompactModeLayoutState() {
          var shell = document.querySelector('.app-shell');
          if (!shell) return;
          var target = getActiveNavTarget();
          var mode = '';
          if (target === 'homologous') {
            var homoMode = document.querySelector('input[name=\"homo_visual_mode\"]:checked');
            mode = homoMode ? String(homoMode.value || '').trim().toLowerCase() : '';
          } else if (target === 'orthologous') {
            var orthoMode = document.querySelector('input[name=\"ortho_visual_mode\"]:checked');
            mode = orthoMode ? String(orthoMode.value || '').trim().toLowerCase() : '';
          }
          shell.classList.toggle('compact-visual-mode', mode === 'compact');
        }

        function updateOrthoSpecialCardVisibility() {
          var alignedShell = document.getElementById('ortho-aligned-card-shell');
          var pipShell = document.getElementById('ortho-pip-card-shell');
          var multipipShell = document.getElementById('ortho-multipip-card-shell');
          var regularCards = document.getElementById('ortho-plot-cards-container');
          var orthoMode = document.querySelector('input[name=\"ortho_visual_mode\"]:checked');
          var mode = orthoMode ? String(orthoMode.value || '').trim().toLowerCase() : 'compact';
          if (mode === 'pip') mode = 'pip_blocks';

          if (alignedShell) alignedShell.style.display = mode === 'aligned' ? '' : 'none';
          if (pipShell) pipShell.style.display = mode === 'pip_blocks' ? '' : 'none';
          if (multipipShell) multipipShell.style.display = mode === 'pip_multipip' ? '' : 'none';
          if (regularCards) {
            regularCards.style.display = (mode === 'aligned' || mode === 'pip_blocks' || mode === 'pip_multipip') ? 'none' : '';
          }
        }

        function closeOrganismSubmenus(scope) {
          var root = scope || document;
          var detailsList = root.querySelectorAll('details.app-submenu-organism-inline');
          detailsList.forEach(function (detailsEl) {
            detailsEl.open = false;
            detailsEl.removeAttribute('open');
          });
        }

        function setWorkflowPanel(target) {
          var panels = document.querySelectorAll('.app-nav-inline-panel[data-workflow-panel]');
          panels.forEach(function (panel) {
            var panelTarget = panel.getAttribute('data-workflow-panel');
            var isOpen = panelTarget === target;
            panel.classList.toggle('is-open', isOpen);

            if (isOpen) {
              closeOrganismSubmenus(panel);
            }

            var relatedBtn = document.querySelector('.app-nav-btn[data-target=\"' + panelTarget + '\"]');
            if (relatedBtn) {
              relatedBtn.classList.toggle('is-expanded', isOpen);
              relatedBtn.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
            }
          });
        }

        function suppressWorkflowPanelAutoOpenOnce() {
          suppressWorkflowPanelOnNextNav = true;
        }

        function getStoredTheme() {
          try {
            return localStorage.getItem('cgv-theme') || 'light';
          } catch (err) {
            return 'light';
          }
        }

        function syncThemeWithShiny(themeName, forceSend) {
          if (window.Shiny && Shiny.setInputValue) {
            if (!forceSend && window.__lastShinyThemeSent === themeName) {
              return;
            }
            window.__lastShinyThemeSent = themeName;
            Shiny.setInputValue('app_theme', themeName, { priority: 'event' });
          }
        }

        function applyTheme(theme) {
          var nextTheme = theme === 'dark' ? 'dark' : 'light';
          document.documentElement.setAttribute('data-app-theme', nextTheme);

          try {
            localStorage.setItem('cgv-theme', nextTheme);
          } catch (err) {}

          var themeLogos = document.querySelectorAll('img[data-light-src][data-dark-src]');
          if (themeLogos && themeLogos.length) {
            themeLogos.forEach(function(logo) {
              var lightSrc = logo.getAttribute('data-light-src') || window.__cgvDefaultLightIcon || 'favicon2.ico?v=2';
              var darkSrc = logo.getAttribute('data-dark-src') || window.__cgvDefaultDarkIcon || 'favicon.ico?v=2';
              var nextSrc = nextTheme === 'dark' ? darkSrc : lightSrc;
              if (logo.getAttribute('src') !== nextSrc) {
                logo.setAttribute('src', nextSrc);
              }
            });
          }

          var toggleInput = document.getElementById('theme-toggle-input');
          if (toggleInput) {
            toggleInput.checked = (nextTheme === 'dark');
          }

          syncThemeWithShiny(nextTheme, false);
        }

        function toggleTheme() {
          var current = document.documentElement.getAttribute('data-app-theme') || 'light';
          applyTheme(current === 'dark' ? 'light' : 'dark');
        }

        function getStoredSidebarCollapsed() {
          try {
            return localStorage.getItem('cgv-sidebar-collapsed') === '1';
          } catch (err) {
            return false;
          }
        }

        function isSidebarCollapsed() {
          var shell = document.querySelector('.app-shell');
          return !!(shell && shell.classList.contains('sidebar-collapsed'));
        }

        function getCollapsedSearchPanel() {
          return document.getElementById('app-collapsed-search-panel');
        }

        function getCollapsedSearchToggle() {
          return document.getElementById('global_search_toggle_collapsed');
        }

        function getCollapsedSearchInput() {
          return document.getElementById('global_search_query_collapsed');
        }

        function getBestSearchQuery() {
          var fromGlobal = document.getElementById('global_search_query');
          var fromHomo = document.getElementById('filter1');
          var fromOrtho = document.getElementById('gene_name');
          var q = '';
          if (fromGlobal) q = String(fromGlobal.value || '').trim();
          if (!q && fromHomo) q = String(fromHomo.value || '').trim();
          if (!q && fromOrtho) q = String(fromOrtho.value || '').trim();
          if (!q && globalSearchChips.length) q = globalSearchChips.join(' || ');
          return q;
        }

        function getQuickFabRoot() {
          return document.getElementById('app-quick-fab');
        }

        function getQuickFabMainToggle() {
          return document.getElementById('app-fab-main-toggle');
        }

        function getQuickFabScrollTopToggle() {
          return document.getElementById('app-fab-scroll-top');
        }

        function getFloatingTopButton() {
          return document.getElementById('app-floating-top');
        }

        function getQuickFabSearchToggle() {
          return document.getElementById('app-fab-search-toggle');
        }

        function getQuickFabModeToggle() {
          return document.getElementById('app-fab-mode-toggle');
        }

        function getQuickFabZoomToggle() {
          return document.getElementById('app-fab-zoom-toggle');
        }

        function getQuickFabSearchPanel() {
          return document.getElementById('app-fab-search-panel');
        }

        function getQuickFabModePanel() {
          return document.getElementById('app-fab-mode-panel');
        }

        function getQuickFabZoomPanel() {
          return document.getElementById('app-fab-zoom-panel');
        }

        function getQuickFabSearchInput() {
          return document.getElementById('app-fab-search-query');
        }

        function isQuickFabOpen() {
          var root = getQuickFabRoot();
          return !!(root && root.classList.contains('is-open'));
        }

        function getActiveTabPane() {
          return document.querySelector('.app-main > .tab-content > .tab-pane.active');
        }

        function isElementDisplayed(el) {
          if (!el) return false;
          var style = null;
          try {
            style = window.getComputedStyle(el);
          } catch (err) {}
          if (!style) return true;
          if (style.display === 'none' || style.visibility === 'hidden') return false;
          return true;
        }

        function getWindowScrollY() {
          return window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop || 0;
        }

        function canElementScrollVertically(el) {
          if (!el) return false;
          var style = null;
          try {
            style = window.getComputedStyle(el);
          } catch (err) {}
          var overflowY = style ? String(style.overflowY || '') : '';
          var allowsScroll = overflowY === 'auto' || overflowY === 'scroll' || overflowY === 'overlay';
          return allowsScroll && (el.scrollHeight - el.clientHeight > 4);
        }

        function getWorkflowScrollNodes() {
          var activeTab = getActiveTabPane();

          var seen = [];
          function pushNode(node) {
            if (!node) return;
            if (seen.indexOf(node) !== -1) return;
            seen.push(node);
          }

          var scope = activeTab || document;
          pushNode(activeTab);
          pushNode(scope.querySelector('.app-main-pane-search-results'));
          pushNode(scope.querySelector('.app-main-pane'));
          pushNode(scope.querySelector('.content-wrapper'));
          pushNode(scope.querySelector('.plots-zoom-wrap'));
          pushNode(document.getElementById('plot-container'));
          pushNode(document.getElementById('ortho-plot-container'));

          var dynamicNodes = scope.querySelectorAll('.content-wrapper, .app-main-pane, .app-main-pane-search-results, .plots-zoom-wrap, [data-scroll-container], .tab-pane');
          dynamicNodes.forEach(function (node) {
            pushNode(node);
          });

          return seen.filter(function (node) {
            return !!node && ((node.scrollTop || 0) > 0 || canElementScrollVertically(node));
          });
        }

        function getActiveScrollTopValue() {
          var nodes = getWorkflowScrollNodes();
          var maxTop = 0;
          nodes.forEach(function (node) {
            var topVal = node && node.scrollTop ? node.scrollTop : 0;
            if (topVal > maxTop) maxTop = topVal;
          });
          if (maxTop > 0) return maxTop;
          return getWindowScrollY();
        }

        function isWorkflowTabActive() {
          var target = getActiveNavTarget();
          return target === 'homologous' || target === 'orthologous';
        }

        function updateFloatingTopVisibility(scrollYValue) {
          var floatingBtn = getFloatingTopButton();
          if (!floatingBtn) return;
          var scrollY = isFinite(scrollYValue) ? scrollYValue : getActiveScrollTopValue();
          var shouldShow = scrollY > 120;
          floatingBtn.classList.toggle('is-visible', shouldShow);
          floatingBtn.setAttribute('aria-hidden', shouldShow ? 'false' : 'true');
        }

        function updateQuickFabScrollTopVisibility() {
          var root = getQuickFabRoot();
          var mainToggle = getQuickFabMainToggle();
          var scrollTopBtn = getQuickFabScrollTopToggle();
          var scrollY = getActiveScrollTopValue();
          var isWorkflowActive = isWorkflowTabActive();
          var hasWorkflowScroll = getWorkflowScrollNodes().length > 0;
          var shouldShow = isWorkflowActive && !isQuickFabOpen() && (scrollY > 120 || hasWorkflowScroll);

          if (root) {
            root.classList.toggle('is-hidden', !isWorkflowActive);
            root.setAttribute('aria-hidden', isWorkflowActive ? 'false' : 'true');
            if (isWorkflowActive) {
              root.classList.toggle('show-scroll-top', shouldShow);
            } else {
              root.classList.remove('show-scroll-top');
              if (root.classList.contains('is-open')) {
                setQuickFabPanel(null);
                root.classList.remove('is-open', 'has-open-panel');
              }
              if (mainToggle) {
                mainToggle.setAttribute('aria-expanded', 'false');
              }
            }
          }

          if (scrollTopBtn) {
            scrollTopBtn.setAttribute('aria-hidden', shouldShow ? 'false' : 'true');
          }
          updateFloatingTopVisibility(scrollY);
        }

        function scrollAppToTop() {
          var prefersReducedMotion = false;
          try {
            prefersReducedMotion = !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
          } catch (err) {}

          var nodes = getWorkflowScrollNodes();
          nodes.forEach(function (node) {
            if (!node || typeof node.scrollTo !== 'function') return;
            node.scrollTo({
              top: 0,
              behavior: prefersReducedMotion ? 'auto' : 'smooth'
            });
          });

          try {
            window.scrollTo({
              top: 0,
              behavior: prefersReducedMotion ? 'auto' : 'smooth'
            });
          } catch (err) {
            window.scrollTo(0, 0);
          }
        }

        function bindQuickFabScrollListeners(scope) {
          var rootScope = scope || document;
          if (!rootScope || !rootScope.querySelectorAll) return;

          var scrollTargets = rootScope.querySelectorAll(
            '.app-main, .app-main > .tab-content, .app-main > .tab-content > .tab-pane, .app-main-pane, .app-main-pane-search-results'
          );

          scrollTargets.forEach(function (node) {
            if (!node || node.getAttribute('data-fab-scroll-bound') === '1') return;
            node.setAttribute('data-fab-scroll-bound', '1');
            node.addEventListener('scroll', updateQuickFabScrollTopVisibility, { passive: true });
          });
        }

        function setQuickFabPanel(panelName) {
          var root = getQuickFabRoot();
          var searchPanel = getQuickFabSearchPanel();
          var modePanel = getQuickFabModePanel();
          var zoomPanel = getQuickFabZoomPanel();
          var searchToggle = getQuickFabSearchToggle();
          var modeToggle = getQuickFabModeToggle();
          var zoomToggle = getQuickFabZoomToggle();
          quickFabPanel = panelName || null;

          if (searchPanel) {
            searchPanel.classList.toggle('is-open', quickFabPanel === 'search');
          }
          if (modePanel) {
            modePanel.classList.toggle('is-open', quickFabPanel === 'mode');
          }
          if (zoomPanel) {
            zoomPanel.classList.toggle('is-open', quickFabPanel === 'zoom');
          }
          if (searchToggle) {
            searchToggle.classList.toggle('is-active', quickFabPanel === 'search');
            searchToggle.setAttribute('aria-expanded', quickFabPanel === 'search' ? 'true' : 'false');
          }
          if (modeToggle) {
            modeToggle.classList.toggle('is-active', quickFabPanel === 'mode');
            modeToggle.setAttribute('aria-expanded', quickFabPanel === 'mode' ? 'true' : 'false');
          }
          if (zoomToggle) {
            zoomToggle.classList.toggle('is-active', quickFabPanel === 'zoom');
            zoomToggle.setAttribute('aria-expanded', quickFabPanel === 'zoom' ? 'true' : 'false');
          }
          if (root) {
            root.classList.toggle('has-open-panel', !!quickFabPanel);
          }

          if (quickFabPanel === 'mode') {
            syncQuickFabModeControls();
          }

          if (quickFabPanel === 'zoom') {
            if (window.syncQuickFabZoomControls) window.syncQuickFabZoomControls();
          }

          if (quickFabPanel === 'search') {
            var searchInput = getQuickFabSearchInput();
            if (searchInput) {
              if (!String(searchInput.value || '').trim()) {
                searchInput.value = getBestSearchQuery();
              }
              setTimeout(function () {
                searchInput.focus();
                searchInput.select();
              }, 0);
            }
          }
        }

        function setQuickFabOpen(open) {
          var root = getQuickFabRoot();
          var mainToggle = getQuickFabMainToggle();
          if (!root) return;
          var nextOpen = !!open;
          root.classList.toggle('is-open', nextOpen);
          if (mainToggle) {
            mainToggle.setAttribute('aria-expanded', nextOpen ? 'true' : 'false');
          }
          if (!nextOpen) {
            setQuickFabPanel(null);
          } else {
            syncQuickFabModeControls();
            if (window.syncQuickFabZoomControls) window.syncQuickFabZoomControls();
          }
          updateQuickFabScrollTopVisibility();
        }

        function toggleQuickFab() {
          setQuickFabOpen(!isQuickFabOpen());
        }

        function getQuickFabWorkflowTarget() {
          var current = getActiveNavTarget();
          if (current === 'homologous' || current === 'orthologous') {
            return current;
          }
          return lastWorkflowTarget === 'orthologous' ? 'orthologous' : 'homologous';
        }

        function getQuickFabModeInputId(target) {
          if (target === 'orthologous') return 'ortho_visual_mode';
          return 'homo_visual_mode';
        }

        function getQuickFabModeChoices(target) {
          if (target === 'orthologous') return ['compact', 'detailed', 'aligned', 'pip_blocks', 'pip_multipip'];
          return ['compact', 'detailed'];
        }

        function syncQuickFabModeControls() {
          var root = getQuickFabRoot();
          if (!root) return;

          var target = getQuickFabWorkflowTarget();
          var inputId = getQuickFabModeInputId(target);
          var modeChoices = getQuickFabModeChoices(target);
          var checkedRadio = document.querySelector('input[name=\"' + inputId + '\"]:checked');
          var activeMode = checkedRadio ? String(checkedRadio.value || '').trim() : modeChoices[0];
          if (modeChoices.indexOf(activeMode) === -1) {
            activeMode = modeChoices[0];
          }

          var context = document.getElementById('app-fab-mode-context');
          if (context) {
            context.textContent = target === 'orthologous'
              ? 'Cross-Species mode'
              : 'Multi-Gene mode';
          }

          var modeButtons = root.querySelectorAll('.app-fab-mode-option[data-mode]');
          modeButtons.forEach(function (btn) {
            var mode = String(btn.getAttribute('data-mode') || '');
            var isAllowed = modeChoices.indexOf(mode) !== -1;
            var isActive = isAllowed && mode === activeMode;
            btn.classList.toggle('is-hidden', !isAllowed);
            btn.classList.toggle('is-active', isActive);
            btn.setAttribute('aria-hidden', isAllowed ? 'false' : 'true');
            btn.setAttribute('aria-pressed', isActive ? 'true' : 'false');
            if (isAllowed) {
              btn.removeAttribute('tabindex');
            } else {
              btn.setAttribute('tabindex', '-1');
            }
          });
        }

        function setQuickFabMode(mode) {
          var nextMode = String(mode || '').trim();
          if (!nextMode) return;
          var target = getQuickFabWorkflowTarget();
          var inputId = getQuickFabModeInputId(target);
          var modeChoices = getQuickFabModeChoices(target);
          if (modeChoices.indexOf(nextMode) === -1) return;

          var radio = document.querySelector('input[name=\"' + inputId + '\"][value=\"' + nextMode + '\"]');
          if (!radio) return;

          if (!radio.checked) {
            radio.checked = true;
            try {
              radio.dispatchEvent(new Event('change', { bubbles: true }));
            } catch (err) {
              var ev = document.createEvent('Event');
              ev.initEvent('change', true, true);
              radio.dispatchEvent(ev);
            }
          }

          syncQuickFabModeControls();
          setQuickFabPanel(null);
          setQuickFabOpen(false);
        }

        function runQuickFabSearch() {
          var searchInput = getQuickFabSearchInput();
          if (!searchInput) return;

          var query = String(searchInput.value || '').trim();
          if (!query) {
            query = getBestSearchQuery();
          }
          if (!query && globalSearchChips.length) {
            query = globalSearchChips.join(' || ');
          }
          if (!query) {
            searchInput.focus();
            return;
          }

          searchInput.value = query;

          var globalInput = getGlobalSearchInput();
          var collapsedInput = getCollapsedSearchInput();
          if (globalInput) globalInput.value = query;
          if (collapsedInput) collapsedInput.value = query;

          if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue('global_search_query', query, { priority: 'event' });
            Shiny.setInputValue('global_search_query_collapsed', query, { priority: 'event' });
          }

          hideGlobalSuggestions();
          hideCollapsedSuggestions();

          var runBtn = document.getElementById('global_search_go');
          if (runBtn) runBtn.click();

          setQuickFabPanel(null);
          setQuickFabOpen(false);
        }

        function initializeQuickFab() {
          var root = getQuickFabRoot();
          if (!root || root.getAttribute('data-ready') === '1') return;
          root.setAttribute('data-ready', '1');

          var mainToggle = getQuickFabMainToggle();
          var scrollTopToggle = getQuickFabScrollTopToggle();
          var floatingTopToggle = getFloatingTopButton();
          var searchToggle = getQuickFabSearchToggle();
          var modeToggle = getQuickFabModeToggle();
          var zoomToggle = getQuickFabZoomToggle();
          var searchRunBtn = document.getElementById('app-fab-search-run');
          var searchInput = getQuickFabSearchInput();

          if (mainToggle) {
            mainToggle.addEventListener('click', function (evt) {
              evt.preventDefault();
              evt.stopPropagation();
              toggleQuickFab();
            });
          }

          if (scrollTopToggle) {
            scrollTopToggle.addEventListener('click', function (evt) {
              evt.preventDefault();
              evt.stopPropagation();
              scrollAppToTop();
            });
          }

          if (floatingTopToggle) {
            floatingTopToggle.addEventListener('click', function (evt) {
              evt.preventDefault();
              evt.stopPropagation();
              scrollAppToTop();
            });
          }

          if (searchToggle) {
            searchToggle.addEventListener('click', function (evt) {
              evt.preventDefault();
              evt.stopPropagation();
              if (!isQuickFabOpen()) setQuickFabOpen(true);
              setQuickFabPanel(quickFabPanel === 'search' ? null : 'search');
            });
          }

          if (modeToggle) {
            modeToggle.addEventListener('click', function (evt) {
              evt.preventDefault();
              evt.stopPropagation();
              if (!isQuickFabOpen()) setQuickFabOpen(true);
              setQuickFabPanel(quickFabPanel === 'mode' ? null : 'mode');
            });
          }

          if (zoomToggle) {
            zoomToggle.addEventListener('click', function (evt) {
              evt.preventDefault();
              evt.stopPropagation();
              if (!isQuickFabOpen()) setQuickFabOpen(true);
              setQuickFabPanel(quickFabPanel === 'zoom' ? null : 'zoom');
              if (window.syncQuickFabZoomControls) {
                setTimeout(window.syncQuickFabZoomControls, 0);
              }
            });
          }

          if (searchRunBtn) {
            searchRunBtn.addEventListener('click', function (evt) {
              evt.preventDefault();
              evt.stopPropagation();
              runQuickFabSearch();
            });
          }

          if (searchInput) {
            searchInput.addEventListener('keydown', function (evt) {
              if (isSpaceBatchShortcut(evt)) {
                var quickSpaceChip = String(searchInput.value || '').trim();
                if (quickSpaceChip) {
                  evt.preventDefault();
                  addGlobalSearchChip(quickSpaceChip);
                  searchInput.value = '';
                }
                return;
              }
              if (evt.key === 'Enter' && (evt.ctrlKey || evt.metaKey)) {
                evt.preventDefault();
                var quickChip = String(searchInput.value || '').trim();
                if (quickChip) {
                  addGlobalSearchChip(quickChip);
                  searchInput.value = '';
                }
                return;
              }
              if (evt.key === 'Enter') {
                evt.preventDefault();
                runQuickFabSearch();
                return;
              }
              if (evt.key === 'Escape') {
                evt.preventDefault();
                setQuickFabPanel(null);
              }
            });
          }

          var modeButtons = root.querySelectorAll('.app-fab-mode-option[data-mode]');
          modeButtons.forEach(function (btn) {
            btn.addEventListener('click', function (evt) {
              evt.preventDefault();
              evt.stopPropagation();
              setQuickFabMode(btn.getAttribute('data-mode') || '');
            });
          });

          document.addEventListener('keydown', function (evt) {
            if (evt.key === 'Escape' && isQuickFabOpen()) {
              setQuickFabPanel(null);
              setQuickFabOpen(false);
            }
          });

          document.addEventListener('change', function (evt) {
            var target = evt && evt.target ? evt.target : null;
            if (!target) return;
            var name = String(target.name || '');
            if (name === 'homo_visual_mode' || name === 'ortho_visual_mode') {
              syncQuickFabModeControls();
              updateCompactModeLayoutState();
              updateOrthoSpecialCardVisibility();
            }
          });

          window.addEventListener('scroll', updateQuickFabScrollTopVisibility, { passive: true });
          bindQuickFabScrollListeners(document);

          if (!window.__quickFabTopWatcher) {
            window.__quickFabTopWatcher = window.setInterval(updateQuickFabScrollTopVisibility, 300);
          }

          // Attach listeners to any pane/container added later by Shiny re-renders.
          var paneObserver = new MutationObserver(function() {
            bindQuickFabScrollListeners(document);
            updateQuickFabScrollTopVisibility();
          });
          paneObserver.observe(document.body, { childList: true, subtree: true });

          syncQuickFabModeControls();
          updateCompactModeLayoutState();
          updateOrthoSpecialCardVisibility();
          updateQuickFabScrollTopVisibility();
        }

        function syncCollapsedSearchFromMain() {
          var input = getCollapsedSearchInput();
          if (!input) return;
          input.value = getBestSearchQuery();
        }

        function syncMainSearchFromCollapsed() {
          var collapsedInput = getCollapsedSearchInput();
          if (!collapsedInput) return;
          var query = String(collapsedInput.value || '').trim();
          var globalInput = document.getElementById('global_search_query');
          if (globalInput) globalInput.value = query;
          if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue('global_search_query', query, { priority: 'event' });
            Shiny.setInputValue('global_search_query_collapsed', query, { priority: 'event' });
          }
        }

        function setCollapsedSearchPanelOpen(open) {
          var canOpen = !!open && isSidebarCollapsed();
          var panel = getCollapsedSearchPanel();
          var toggleBtn = getCollapsedSearchToggle();
          if (panel) {
            panel.classList.toggle('is-open', canOpen);
          }
          if (toggleBtn) {
            toggleBtn.classList.toggle('is-expanded', canOpen);
            toggleBtn.setAttribute('aria-expanded', canOpen ? 'true' : 'false');
          }
          if (!canOpen) {
            hideCollapsedSuggestions();
          }
          if (canOpen) {
            syncCollapsedSuggestionDataList();
            syncCollapsedSearchFromMain();
            var input = getCollapsedSearchInput();
            if (input) {
              setTimeout(function () {
                input.focus();
                input.select();
                renderCollapsedSuggestions(input.value || '');
              }, 0);
            }
          }
        }

        function applySidebarCollapsed(collapsed) {
          var shell = document.querySelector('.app-shell');
          var isMobile = window.matchMedia('(max-width: 960px)').matches;
          var desiredCollapsed = !!collapsed;
          var nextCollapsed = isMobile ? false : desiredCollapsed;
          if (shell) {
            shell.classList.toggle('sidebar-collapsed', nextCollapsed);
          }

          var btn = document.getElementById('sidebar-collapse-btn');
          if (btn) {
            btn.setAttribute('aria-expanded', nextCollapsed ? 'false' : 'true');
            var sidebarLabel = nextCollapsed ? 'Expand sidebar' : 'Collapse sidebar';
            btn.setAttribute('title', sidebarLabel);
            btn.setAttribute('aria-label', sidebarLabel);
            var glyph = btn.querySelector('.sidebar-collapse-glyph');
            if (glyph) glyph.textContent = nextCollapsed ? '▶' : '◀';
          }

          setCollapsedSearchPanelOpen(false);

          try {
            localStorage.setItem('cgv-sidebar-collapsed', desiredCollapsed ? '1' : '0');
          } catch (err) {}
        }

        function notifyPlotLayoutResize() {
          if (!window || typeof window.dispatchEvent !== 'function') return;
          window.dispatchEvent(new Event('resize'));
          setTimeout(function () {
            window.dispatchEvent(new Event('resize'));
          }, 320);
        }

        function toggleSidebarCollapsed() {
          var isMobile = window.matchMedia('(max-width: 960px)').matches;
          if (isMobile) {
            toggleMobileNav();
            return;
          }
          applySidebarCollapsed(!getStoredSidebarCollapsed());
          notifyPlotLayoutResize();
        }

        function toggleMobileNav() {
          var shell = document.querySelector('.app-shell');
          if (!shell) return;
          var isOpen = shell.classList.contains('mobile-nav-open');
          shell.classList.toggle('mobile-nav-open', !isOpen);
          var btn = document.getElementById('sidebar-collapse-btn');
          if (btn) {
            var glyph = btn.querySelector('.sidebar-collapse-glyph');
            if (glyph) glyph.textContent = isOpen ? String.fromCharCode(0x2630) : String.fromCharCode(0x2715);
            btn.setAttribute('aria-expanded', isOpen ? 'false' : 'true');
            btn.setAttribute('title', isOpen ? 'Open menu' : 'Close menu');
          }
        }
        window.toggleMobileNav = toggleMobileNav;

        function getGlobalSearchInput() {
          return document.getElementById('global_search_query');
        }

        function getGlobalSuggestionPanel() {
          return document.getElementById('global-search-suggestions');
        }

        function getCollapsedSearchSuggestionPanel() {
          return document.getElementById('global-search-suggestions-collapsed');
        }

        function getGlobalSuggestionDataList() {
          return document.getElementById('global_search_query_suggestions');
        }

        function getGlobalChipPayloadInput() {
          return document.getElementById('global_search_chip_payload');
        }

        function getGlobalChipListNodes() {
          var nodes = document.querySelectorAll('.app-search-chip-list-sync');
          if (!nodes || !nodes.length) return [];
          return Array.prototype.slice.call(nodes);
        }

        function getChipEmptyLabel(node) {
          if (!node) return 'No genes added yet.';
          var custom = String(node.getAttribute('data-empty-label') || '').trim();
          return custom || 'No genes added yet.';
        }

        function getGlobalChipAddBtn() {
          return document.getElementById('global_search_add_chip');
        }

        function getGlobalChipClearBtn() {
          return document.getElementById('global_search_clear_chips');
        }

        function getGlobalChipCountNode() {
          return document.getElementById('global-search-batch-count');
        }

        function formatGlobalBatchCount(countValue) {
          var nn = parseInt(countValue, 10);
          if (!isFinite(nn) || nn < 0) nn = 0;
          return 'Batch: ' + nn + ' gene' + (nn === 1 ? '' : 's');
        }

        function isSpaceBatchShortcut(evt) {
          if (!evt) return false;
          // Space-to-batch is only valid in Homologous Search mode
          if (lastWorkflowTarget !== 'homologous') return false;
          if (evt.ctrlKey || evt.metaKey || evt.altKey) return false;
          var key = String(evt.key || '');
          var code = String(evt.code || '');
          return key === ' ' || key === 'Spacebar' || code === 'Space';
        }

        function normalizeChipGene(value) {
          var vv = (value === null || value === undefined) ? '' : String(value);
          vv = vv.replace(/\\s+/g, ' ').trim();
          return vv;
        }

        function hasGlobalChipGene(gene) {
          var key = normalizeChipGene(gene).toLowerCase();
          if (!key) return false;
          return globalSearchChips.some(function (item) {
            return normalizeChipGene(item).toLowerCase() === key;
          });
        }

        function setGlobalChipActionState() {
          var clearBtn = getGlobalChipClearBtn();
          if (clearBtn) clearBtn.disabled = globalSearchChips.length === 0;
          var root = document.getElementById('global-search-chipbar');
          if (root) root.classList.toggle('has-chips', globalSearchChips.length > 0);
          var countNode = getGlobalChipCountNode();
          if (countNode) {
            countNode.textContent = formatGlobalBatchCount(globalSearchChips.length);
            countNode.classList.toggle('is-empty', globalSearchChips.length === 0);
          }
        }

        function syncGlobalChipPayload() {
          var payloadInput = getGlobalChipPayloadInput();
          if (payloadInput) {
            payloadInput.value = globalSearchChips.join(' || ');
          }
          if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue('global_search_chip_payload', globalSearchChips.slice(), { priority: 'event' });
          }
          setGlobalChipActionState();
        }

        function renderGlobalSearchChips() {
          var nodes = getGlobalChipListNodes();
          if (!nodes.length) {
            syncGlobalChipPayload();
            return;
          }

          nodes.forEach(function (node) {
            node.innerHTML = '';
            if (!globalSearchChips.length) {
              var empty = document.createElement('span');
              empty.className = 'app-search-chip-empty';
              empty.textContent = getChipEmptyLabel(node);
              node.appendChild(empty);
              return;
            }

            globalSearchChips.forEach(function (gene, idx) {
              var chip = document.createElement('span');
              chip.className = 'app-search-chip';

              var label = document.createElement('span');
              label.className = 'app-search-chip-label';
              label.textContent = gene;
              chip.appendChild(label);

              var removeBtn = document.createElement('button');
              removeBtn.type = 'button';
              removeBtn.className = 'app-search-chip-remove';
              removeBtn.setAttribute('data-chip-index', String(idx));
              removeBtn.setAttribute('title', 'Remove from batch');
              removeBtn.setAttribute('aria-label', 'Remove from batch');
              removeBtn.textContent = 'x';
              chip.appendChild(removeBtn);

              node.appendChild(chip);
            });
          });

          syncGlobalChipPayload();
        }

        function addGlobalSearchChip(rawGene, options) {
          var opts = options || {};
          var gene = normalizeChipGene(rawGene);
          if (!gene) return false;
          if (hasGlobalChipGene(gene)) return false;

          globalSearchChips.push(gene);
          renderGlobalSearchChips();

          if (!opts.keepInput) {
            var input = getGlobalSearchInput();
            if (input) input.value = '';
            if (window.Shiny && Shiny.setInputValue) {
              Shiny.setInputValue('global_search_query', '', { priority: 'event' });
            }
          }

          if (!opts.keepCollapsedInput) {
            var collapsedInput = getCollapsedSearchInput();
            if (collapsedInput) collapsedInput.value = '';
            if (window.Shiny && Shiny.setInputValue) {
              Shiny.setInputValue('global_search_query_collapsed', '', { priority: 'event' });
            }
          }

          hideGlobalSuggestions();
          hideCollapsedSuggestions();
          return true;
        }

        function removeGlobalSearchChipAt(index) {
          var idx = parseInt(index, 10);
          if (!isFinite(idx) || idx < 0 || idx >= globalSearchChips.length) return false;
          globalSearchChips.splice(idx, 1);
          renderGlobalSearchChips();
          return true;
        }

        function clearGlobalSearchChips() {
          if (!globalSearchChips.length) return false;
          globalSearchChips = [];
          renderGlobalSearchChips();
          return true;
        }

        function clearAllSearchState() {
          clearGlobalSearchChips();

          var input = getGlobalSearchInput();
          if (input) input.value = '';

          var collapsedInput = getCollapsedSearchInput();
          if (collapsedInput) collapsedInput.value = '';

          var homoInput = document.getElementById('filter1');
          if (homoInput) homoInput.value = '';

          var orthoInput = document.getElementById('gene_name');
          if (orthoInput) orthoInput.value = '';

          var fabInput = getQuickFabSearchInput();
          if (fabInput) fabInput.value = '';

          hideGlobalSuggestions();
          hideCollapsedSuggestions();

          if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue('global_search_query', '', { priority: 'event' });
            Shiny.setInputValue('global_search_query_collapsed', '', { priority: 'event' });
            Shiny.setInputValue('filter1', '', { priority: 'event' });
            Shiny.setInputValue('gene_name', '', { priority: 'event' });
            Shiny.setInputValue('global_search_chip_payload', [], { priority: 'event' });
          }
        }

        if (window.Shiny && typeof Shiny.addCustomMessageHandler === 'function') {
          Shiny.addCustomMessageHandler('clear_global_search_state', function(message) {
            clearAllSearchState();
          });
          // Retrigger homologous search after organism-change confirmation
          Shiny.addCustomMessageHandler('cgv_trigger_homo_search', function(message) {
            var btn = document.getElementById('generate1');
            if (btn) btn.click();
          });
          // Retrigger orthologous search after gene-change confirmation
          Shiny.addCustomMessageHandler('cgv_trigger_ortho_search', function(message) {
            var btn = document.getElementById('search_gene');
            if (btn) btn.click();
          });
        }

        function addChipFromMainSearchInput() {
          var input = getGlobalSearchInput();
          var candidate = input ? String(input.value || '') : '';
          if (!normalizeChipGene(candidate) && suggestionState.activeIndex >= 0 && suggestionState.activeIndex < suggestionState.items.length) {
            candidate = suggestionState.items[suggestionState.activeIndex];
          }
          if (!normalizeChipGene(candidate)) {
            var collapsedInput = getCollapsedSearchInput();
            candidate = collapsedInput ? String(collapsedInput.value || '') : '';
          }
          return addGlobalSearchChip(candidate);
        }

        function initializeGlobalSearchChipControls() {
          var root = document.getElementById('global-search-chipbar');
          if (!root) return;
          if (root.getAttribute('data-ready') === '1') {
            renderGlobalSearchChips();
            return;
          }
          root.setAttribute('data-ready', '1');

          var addBtn = getGlobalChipAddBtn();
          var clearBtn = getGlobalChipClearBtn();
          if (addBtn) {
            addBtn.addEventListener('click', function (evt) {
              evt.preventDefault();
              addChipFromMainSearchInput();
            });
          }
          if (clearBtn) {
            clearBtn.addEventListener('click', function (evt) {
              evt.preventDefault();
              clearGlobalSearchChips();
            });
          }

          renderGlobalSearchChips();
        }

        function syncCollapsedSuggestionDataList() {
          return;
        }

        function escapeHtml(value) {
          return String(value || '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/\"/g, '&quot;')
            .replace(/'/g, '&#39;');
        }

        function readGlobalSuggestionPool() {
          if (Array.isArray(window.__globalGeneSuggestionPool)) {
            globalSuggestionPool = window.__globalGeneSuggestionPool.slice();
          }
          if (globalSuggestionPool.length > 0) {
            return globalSuggestionPool.slice();
          }
          var dl = getGlobalSuggestionDataList();
          if (!dl) return [];
          var options = dl.querySelectorAll('option');
          var values = [];
          options.forEach(function (opt) {
            var value = (opt.value || opt.getAttribute('value') || '').trim();
            if (value) values.push(value);
          });
          return values;
        }

        function hideGlobalSuggestions() {
          var panel = getGlobalSuggestionPanel();
          suggestionState.items = [];
          suggestionState.activeIndex = -1;
          if (!panel) return;
          panel.classList.remove('open');
          panel.innerHTML = '';
        }

        function hideCollapsedSuggestions() {
          var panel = getCollapsedSearchSuggestionPanel();
          collapsedSuggestionState.items = [];
          collapsedSuggestionState.activeIndex = -1;
          if (!panel) return;
          panel.classList.remove('open');
          panel.innerHTML = '';
        }

        function setActiveSuggestion(index) {
          var panel = getGlobalSuggestionPanel();
          if (!panel) return;
          var nodes = panel.querySelectorAll('.app-search-suggestion');
          nodes.forEach(function (node, idx) {
            node.classList.toggle('is-active', idx === index);
          });
          suggestionState.activeIndex = index;
        }

        function setActiveCollapsedSuggestion(index) {
          var panel = getCollapsedSearchSuggestionPanel();
          if (!panel) return;
          var nodes = panel.querySelectorAll('.app-search-suggestion-collapsed');
          nodes.forEach(function (node, idx) {
            node.classList.toggle('is-active', idx === index);
          });
          collapsedSuggestionState.activeIndex = index;
        }

        function commitSuggestion(index) {
          if (index < 0 || index >= suggestionState.items.length) return false;
          var input = getGlobalSearchInput();
          if (!input) return false;
          var picked = suggestionState.items[index];
          input.value = picked;
          if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue('global_search_query', picked, { priority: 'event' });
          }
          hideGlobalSuggestions();
          return true;
        }

        function commitCollapsedSuggestion(index) {
          if (index < 0 || index >= collapsedSuggestionState.items.length) return false;
          var input = getCollapsedSearchInput();
          if (!input) return false;
          var picked = collapsedSuggestionState.items[index];
          input.value = picked;
          if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue('global_search_query_collapsed', picked, { priority: 'event' });
            Shiny.setInputValue('global_search_query', picked, { priority: 'event' });
          }
          hideCollapsedSuggestions();
          return true;
        }

        function renderGlobalSuggestions(rawQuery) {
          var input = getGlobalSearchInput();
          var panel = getGlobalSuggestionPanel();
          if (!input || !panel) return;

          var query = String(rawQuery || '').trim().toLowerCase();
          if (!query) {
            hideGlobalSuggestions();
            return;
          }

          var pool = readGlobalSuggestionPool();
          var filtered = pool.filter(function (value) {
            return value.toLowerCase().indexOf(query) !== -1;
          });

          filtered.sort(function (a, b) {
            var aStarts = a.toLowerCase().indexOf(query) === 0 ? 0 : 1;
            var bStarts = b.toLowerCase().indexOf(query) === 0 ? 0 : 1;
            if (aStarts !== bStarts) return aStarts - bStarts;
            return a.localeCompare(b);
          });

          filtered = filtered.slice(0, 8);
          suggestionState.items = filtered;
          suggestionState.activeIndex = -1;

          if (!filtered.length) {
            hideGlobalSuggestions();
            return;
          }

          panel.innerHTML = filtered.map(function (item, idx) {
            return '<button type=\"button\" class=\"app-search-suggestion\" data-index=\"' + idx + '\">' + escapeHtml(item) + '</button>';
          }).join('');
          panel.classList.add('open');
        }

        function renderCollapsedSuggestions(rawQuery) {
          var input = getCollapsedSearchInput();
          var panel = getCollapsedSearchSuggestionPanel();
          if (!input || !panel) return;

          var query = String(rawQuery || '').trim().toLowerCase();
          if (!query) {
            hideCollapsedSuggestions();
            return;
          }

          var pool = readGlobalSuggestionPool();
          var filtered = pool.filter(function (value) {
            return value.toLowerCase().indexOf(query) !== -1;
          });

          filtered.sort(function (a, b) {
            var aStarts = a.toLowerCase().indexOf(query) === 0 ? 0 : 1;
            var bStarts = b.toLowerCase().indexOf(query) === 0 ? 0 : 1;
            if (aStarts !== bStarts) return aStarts - bStarts;
            return a.localeCompare(b);
          });

          filtered = filtered.slice(0, 8);
          collapsedSuggestionState.items = filtered;
          collapsedSuggestionState.activeIndex = -1;

          if (!filtered.length) {
            hideCollapsedSuggestions();
            return;
          }

          panel.innerHTML = filtered.map(function (item, idx) {
            return '<button type=\"button\" class=\"app-search-suggestion app-search-suggestion-collapsed\" data-index=\"' + idx + '\">' + escapeHtml(item) + '</button>';
          }).join('');
          panel.classList.add('open');
        }

        function bindGlobalSuggestionObserver() {
          if (suggestionObserver) {
            suggestionObserver.disconnect();
            suggestionObserver = null;
          }
        }

        function initializeGlobalSearchInput() {
          var input = getGlobalSearchInput();
          if (!input) return;
          input.removeAttribute('list');
          input.setAttribute('autocomplete', 'new-password');
          input.setAttribute('data-form-type', 'other');
          input.setAttribute('data-lpignore', 'true');
          input.setAttribute('data-1p-ignore', 'true');
          input.setAttribute('autocorrect', 'off');
          input.setAttribute('autocapitalize', 'off');
          input.setAttribute('spellcheck', 'false');

          input.addEventListener('input', function () {
            renderGlobalSuggestions(input.value || '');
          });

          input.addEventListener('focus', function () {
            setWorkflowPanel(null);
            renderGlobalSuggestions(input.value || '');
          });

          input.addEventListener('keydown', function (evt) {
            var panel = getGlobalSuggestionPanel();
            var isOpen = panel && panel.classList.contains('open');
            if (isSpaceBatchShortcut(evt)) {
              var spaceCandidate = '';
              if (isOpen && suggestionState.activeIndex >= 0 && suggestionState.activeIndex < suggestionState.items.length) {
                spaceCandidate = suggestionState.items[suggestionState.activeIndex];
              }
              if (!spaceCandidate) {
                spaceCandidate = input.value || '';
              }
              if (normalizeChipGene(spaceCandidate)) {
                evt.preventDefault();
                addGlobalSearchChip(spaceCandidate);
              }
              return;
            }
            if (evt.key === 'Enter' && (evt.ctrlKey || evt.metaKey)) {
              evt.preventDefault();
              var candidate = '';
              if (isOpen && suggestionState.activeIndex >= 0 && suggestionState.activeIndex < suggestionState.items.length) {
                candidate = suggestionState.items[suggestionState.activeIndex];
              }
              if (!candidate) {
                candidate = input.value || '';
              }
              addGlobalSearchChip(candidate);
              return;
            }
            if (evt.key === 'ArrowDown') {
              if (!isOpen && (input.value || '').trim()) {
                renderGlobalSuggestions(input.value || '');
                panel = getGlobalSuggestionPanel();
                isOpen = panel && panel.classList.contains('open');
              }
              if (!isOpen || !suggestionState.items.length) return;
              evt.preventDefault();
              var downIdx = suggestionState.activeIndex + 1;
              if (downIdx >= suggestionState.items.length) downIdx = 0;
              setActiveSuggestion(downIdx);
              return;
            }
            if (evt.key === 'ArrowUp') {
              if (!isOpen || !suggestionState.items.length) return;
              evt.preventDefault();
              var upIdx = suggestionState.activeIndex - 1;
              if (upIdx < 0) upIdx = suggestionState.items.length - 1;
              setActiveSuggestion(upIdx);
              return;
            }
            if (evt.key === 'Escape') {
              hideGlobalSuggestions();
              return;
            }
            if (evt.key === 'Enter') {
              if (isOpen && suggestionState.activeIndex >= 0) {
                evt.preventDefault();
                if (commitSuggestion(suggestionState.activeIndex)) return;
              }
              evt.preventDefault();
              hideGlobalSuggestions();
              if (window.Shiny && Shiny.setInputValue) {
                Shiny.setInputValue('global_search_query', input.value, { priority: 'event' });
              }
              var btn = document.getElementById('global_search_go');
              if (btn) btn.click();
            }
          });
        }

        document.documentElement.setAttribute('data-app-theme', getStoredTheme());

        document.addEventListener('DOMContentLoaded', function () {
          applyTheme(getStoredTheme());
          applySidebarCollapsed(getStoredSidebarCollapsed());
          /* On mobile: set hamburger glyph and ensure nav is closed */
          (function() {
            var isMobile = window.matchMedia('(max-width: 960px)').matches;
            if (isMobile) {
              var btn = document.getElementById('sidebar-collapse-btn');
              if (btn) {
                var glyph = btn.querySelector('.sidebar-collapse-glyph');
                if (glyph) glyph.textContent = String.fromCharCode(0x2630);
                btn.setAttribute('title', 'Open menu');
              }
            }
          })();
          setActiveNav('home');
          setWorkflowPanel(null);
          initializeGlobalSearchInput();
          initializeGlobalSearchChipControls();
          bindGlobalSuggestionObserver();
          syncCollapsedSuggestionDataList();
          initializeQuickFab();
          /* Close mobile nav when user triggers a search */
          var searchGoBtn = document.getElementById('global_search_go');
          if (searchGoBtn) {
            searchGoBtn.addEventListener('click', function() {
              if (window.matchMedia('(max-width: 960px)').matches) {
                var s = document.querySelector('.app-shell');
                if (s && s.classList.contains('mobile-nav-open')) {
                  toggleMobileNav();
                }
              }
            });
          }
          document.addEventListener('cgv-global-suggestions-updated', function () {
            globalSuggestionPool = Array.isArray(window.__globalGeneSuggestionPool)
              ? window.__globalGeneSuggestionPool.slice()
              : [];
            var activeInput = getGlobalSearchInput();
            if (activeInput && document.activeElement === activeInput) {
              renderGlobalSuggestions(activeInput.value || '');
            }
            var activeCollapsedInput = getCollapsedSearchInput();
            if (activeCollapsedInput && document.activeElement === activeCollapsedInput) {
              renderCollapsedSuggestions(activeCollapsedInput.value || '');
            }
          });

          var collapsedInput = getCollapsedSearchInput();
          if (collapsedInput) {
            collapsedInput.addEventListener('input', function () {
              renderCollapsedSuggestions(collapsedInput.value || '');
            });

            collapsedInput.addEventListener('focus', function () {
              renderCollapsedSuggestions(collapsedInput.value || '');
            });

            collapsedInput.addEventListener('keydown', function (evt) {
              var panel = getCollapsedSearchSuggestionPanel();
              var isOpen = panel && panel.classList.contains('open');
              if (isSpaceBatchShortcut(evt)) {
                var collapsedSpaceChip = '';
                if (isOpen && collapsedSuggestionState.activeIndex >= 0 && collapsedSuggestionState.activeIndex < collapsedSuggestionState.items.length) {
                  collapsedSpaceChip = collapsedSuggestionState.items[collapsedSuggestionState.activeIndex];
                }
                if (!collapsedSpaceChip) {
                  collapsedSpaceChip = collapsedInput.value || '';
                }
                if (normalizeChipGene(collapsedSpaceChip)) {
                  evt.preventDefault();
                  addGlobalSearchChip(collapsedSpaceChip, { keepCollapsedInput: false });
                }
                return;
              }
              if (evt.key === 'Enter' && (evt.ctrlKey || evt.metaKey)) {
                evt.preventDefault();
                var chipCandidate = '';
                if (isOpen && collapsedSuggestionState.activeIndex >= 0 && collapsedSuggestionState.activeIndex < collapsedSuggestionState.items.length) {
                  chipCandidate = collapsedSuggestionState.items[collapsedSuggestionState.activeIndex];
                }
                if (!chipCandidate) {
                  chipCandidate = collapsedInput.value || '';
                }
                addGlobalSearchChip(chipCandidate, { keepCollapsedInput: false });
                return;
              }
              if (evt.key === 'ArrowDown') {
                if (!isOpen && (collapsedInput.value || '').trim()) {
                  renderCollapsedSuggestions(collapsedInput.value || '');
                  panel = getCollapsedSearchSuggestionPanel();
                  isOpen = panel && panel.classList.contains('open');
                }
                if (!isOpen || !collapsedSuggestionState.items.length) return;
                evt.preventDefault();
                var downIdx = collapsedSuggestionState.activeIndex + 1;
                if (downIdx >= collapsedSuggestionState.items.length) downIdx = 0;
                setActiveCollapsedSuggestion(downIdx);
                return;
              }
              if (evt.key === 'ArrowUp') {
                if (!isOpen || !collapsedSuggestionState.items.length) return;
                evt.preventDefault();
                var upIdx = collapsedSuggestionState.activeIndex - 1;
                if (upIdx < 0) upIdx = collapsedSuggestionState.items.length - 1;
                setActiveCollapsedSuggestion(upIdx);
                return;
              }
              if (evt.key === 'Escape') {
                hideCollapsedSuggestions();
                return;
              }
              if (evt.key !== 'Enter') return;
              if (isOpen && collapsedSuggestionState.activeIndex >= 0) {
                evt.preventDefault();
                if (commitCollapsedSuggestion(collapsedSuggestionState.activeIndex)) return;
              }
              evt.preventDefault();
              hideCollapsedSuggestions();
              syncMainSearchFromCollapsed();
              var goBtn = document.getElementById('global_search_go_collapsed');
              if (goBtn) goBtn.click();
            });
          }

          var runBtnMain = document.getElementById('global_search_go');
          if (runBtnMain) {
            runBtnMain.addEventListener('click', function () {
              suppressWorkflowPanelAutoOpenOnce();
            });
          }

          var runBtnCollapsed = document.getElementById('global_search_go_collapsed');
          if (runBtnCollapsed) {
            runBtnCollapsed.addEventListener('click', function () {
              suppressWorkflowPanelAutoOpenOnce();
            });
          }
        });

        window.addEventListener('resize', function () {
          applySidebarCollapsed(getStoredSidebarCollapsed());
          syncQuickFabModeControls();
          updateQuickFabScrollTopVisibility();
        });

        document.addEventListener('click', function (evt) {
          var chipRemoveBtn = evt.target.closest('.app-search-chip-remove');
          if (chipRemoveBtn) {
            evt.preventDefault();
            var chipIndex = parseInt(chipRemoveBtn.getAttribute('data-chip-index') || '-1', 10);
            removeGlobalSearchChipAt(chipIndex);
            return;
          }

          var collapsedSuggestionBtn = evt.target.closest('.app-search-suggestion-collapsed');
          if (collapsedSuggestionBtn) {
            evt.preventDefault();
            var collapsedIndex = parseInt(collapsedSuggestionBtn.getAttribute('data-index') || '-1', 10);
            commitCollapsedSuggestion(collapsedIndex);
            return;
          }

          var suggestionBtn = evt.target.closest('.app-search-suggestion');
          if (suggestionBtn) {
            evt.preventDefault();
            var index = parseInt(suggestionBtn.getAttribute('data-index') || '-1', 10);
            commitSuggestion(index);
            return;
          }

          if (!evt.target.closest('.app-primary-search-input-wrap')) {
            hideGlobalSuggestions();
          }

          if (!evt.target.closest('.app-collapsed-search-input-wrap')) {
            hideCollapsedSuggestions();
          }

          if (!evt.target.closest('#app-quick-fab') && isQuickFabOpen()) {
            setQuickFabPanel(null);
            setQuickFabOpen(false);
          }

          var collapseBtn = evt.target.closest('#sidebar-collapse-btn');
          if (collapseBtn) {
            evt.preventDefault();
            toggleSidebarCollapsed();
            return;
          }

          var collapsedSearchToggle = evt.target.closest('#global_search_toggle_collapsed');
          if (collapsedSearchToggle) {
            evt.preventDefault();
            if (!isSidebarCollapsed()) return;
            var panel = getCollapsedSearchPanel();
            var isOpen = !!(panel && panel.classList.contains('is-open'));
            if (!isOpen) {
              setWorkflowPanel(null);
            }
            setCollapsedSearchPanelOpen(!isOpen);
            return;
          }

          var collapsedSearchSubmit = evt.target.closest('#global_search_go_collapsed');
          if (collapsedSearchSubmit) {
            syncMainSearchFromCollapsed();
            setWorkflowPanel(null);
            setCollapsedSearchPanelOpen(false);
            return;
          }

          var collapsedPanel = getCollapsedSearchPanel();
          if (collapsedPanel && collapsedPanel.classList.contains('is-open')) {
            if (!evt.target.closest('#app-collapsed-search-panel') && !evt.target.closest('#global_search_toggle_collapsed')) {
              setCollapsedSearchPanelOpen(false);
            }
          }

          var openWorkflowPanel = document.querySelector('.app-nav-inline-panel[data-workflow-panel].is-open');
          if (openWorkflowPanel) {
            var clickedInsideWorkflowPanel = !!evt.target.closest('.app-nav-inline-panel[data-workflow-panel]');
            var clickedWorkflowTrigger = !!evt.target.closest('.app-nav-btn-workflow');
            var clickedInsideModal = !!evt.target.closest('#shiny-modal, .modal, .modal-backdrop');
            if (!clickedInsideWorkflowPanel && !clickedWorkflowTrigger && !clickedInsideModal) {
              setWorkflowPanel(null);
            }
          }

          var navBtn = evt.target.closest('.app-nav-btn');
          if (navBtn) {
            evt.preventDefault();
            setCollapsedSearchPanelOpen(false);
            var target = navBtn.getAttribute('data-target');
            if (!isValidTarget(target)) return;
            var isWorkflow = target === 'homologous' || target === 'orthologous';
            var activeNavTarget = getActiveNavTarget();
            var isAlreadyActive = activeNavTarget === target;
            if (isWorkflow) {
              var panel = document.querySelector('.app-nav-inline-panel[data-workflow-panel=\"' + target + '\"]');
              var isOpen = !!(panel && panel.classList.contains('is-open'));
              if (isAlreadyActive) {
                // Toggle compact/expanded state without leaving the active workflow tab.
                setWorkflowPanel(isOpen ? null : target);
                setActiveNav(target);
              } else {
                setWorkflowPanel(target);
                setActiveNav(target);
                if (window.Shiny && Shiny.setInputValue) {
                  Shiny.setInputValue('app_nav_click', target, { priority: 'event' });
                }
              }
            } else {
              setWorkflowPanel(null);
              setActiveNav(target);
              if (!isAlreadyActive && window.Shiny && Shiny.setInputValue) {
                Shiny.setInputValue('app_nav_click', target, { priority: 'event' });
              }
              /* Auto-close mobile nav when navigating to a non-workflow tab */
              if (window.matchMedia('(max-width: 960px)').matches) {
                var shell2 = document.querySelector('.app-shell');
                if (shell2 && shell2.classList.contains('mobile-nav-open')) {
                  toggleMobileNav();
                }
              }
            }
            setTimeout(function () {
              var current = document.documentElement.getAttribute('data-app-theme') || 'light';
              applyTheme(current);
              bindGlobalSuggestionObserver();
            }, 0);
            return;
          }

          var themeBtn = evt.target.closest('#theme-toggle-btn');
          if (themeBtn) {
            evt.preventDefault();
            toggleTheme();
          }
        });

        $(document).on('shiny:connected', function () {
          if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue('app_nav_click', 'home', { priority: 'event' });
          }
          syncThemeWithShiny(document.documentElement.getAttribute('data-app-theme') || getStoredTheme(), true);

          if (window.Shiny) {
            Shiny.addCustomMessageHandler('set_colorblind_mode', function(message) {
              if (message === true) {
                document.documentElement.setAttribute('data-colorblind-mode', 'true');
              } else {
                document.documentElement.setAttribute('data-colorblind-mode', 'false');
              }
            });
          }
        });

        $(document).on('shiny:inputchanged', function (event) {
          if (event.name === 'navtabs' && isValidTarget(event.value)) {
            setActiveNav(event.value);
            if (event.value === 'homologous' || event.value === 'orthologous') {
              if (suppressWorkflowPanelOnNextNav) {
                setWorkflowPanel(null);
                suppressWorkflowPanelOnNextNav = false;
              } else {
                setWorkflowPanel(event.value);
              }
            } else {
              setWorkflowPanel(null);
              suppressWorkflowPanelOnNextNav = false;
            }
            setCollapsedSearchPanelOpen(false);
            setQuickFabPanel(null);
            setQuickFabOpen(false);
            setTimeout(bindGlobalSuggestionObserver, 0);
            setTimeout(syncQuickFabModeControls, 0);
          }
        });
      })();
      "))
    ),
    div(
      id = "app-status-popup",
      class = "app-status-popup",
      div(
        class = "app-status-popup-header",
        div(
          class = "app-status-popup-title",
          icon("bell"),
          span("Notifications")
        ),
        div(
          class = "app-status-popup-actions",
          tags$button(id = "app-status-popup-clear", type = "button", class = "app-status-popup-btn", span("Clear")),
          tags$button(id = "app-status-popup-close", type = "button", class = "app-status-popup-btn", HTML("&times;"))
        )
      ),
      div(
        id = "app-status-popup-loader",
        class = "app-status-popup-loader",
        div(
          class = "app-dna-loader",
          div(
            class = "app-dna-wave app-dna-wave-top",
            lapply(seq_len(16), function(i) span(class = "app-dna-node", style = sprintf("--i:%d;", i - 1)))
          ),
          div(
            class = "app-dna-wave app-dna-wave-bottom",
            lapply(seq_len(16), function(i) span(class = "app-dna-node", style = sprintf("--i:%d;", i - 1)))
          )
        ),
        div(id = "app-status-popup-loader-text", class = "app-status-popup-loader-text", "Working...")
      ),
      div(id = "app-status-popup-log", class = "app-status-popup-log")
    ),
    shinyjs::useShinyjs()
  ),
  div(
    id = "app-top-sentinel",
    class = "app-top-sentinel",
    `aria-hidden` = "true"
  ),
  div(
    class = "app-shell",
    tags$aside(
      class = "app-sidebar",
      div(
        class = "app-sidebar-top",
        div(
          class = "app-brand",
          tags$img(
            src = versioned_asset_path("favicon2.ico?v=2"),
            class = "app-brand-logo",
            `data-light-src` = versioned_asset_path("favicon2.ico?v=2"),
            `data-dark-src` = versioned_asset_path("favicon.ico?v=2"),
            alt = "CGV logo"
          ),
          div(
            class = "app-brand-text",
            div(class = "app-brand-title", "CGV"),
            div(class = "app-brand-divider"),
            div(
              class = "app-brand-descriptor",
              div(class = "app-brand-kicker", "Comparative"),
              div(class = "app-brand-subtitle", "Gene Viewer"),
              div(class = "app-brand-version", "v1.0.0")
            )
          ),
          tags$button(
            id = "sidebar-collapse-btn",
            type = "button",
            class = "sidebar-collapse-btn",
            `aria-label` = "Collapse sidebar",
            `aria-expanded` = "true",
            title = "Collapse sidebar",
            span(class = "sidebar-collapse-glyph", "\u25C0")
          )
        )
      ),
      div(
        class = "app-nav",
        tags$button(type = "button", class = "app-nav-btn is-active", `data-target` = "home", title = "Home", icon("home"), span("Home")),
        div(
          class = "app-nav-group",
          tags$button(
            type = "button",
            class = "app-nav-btn app-nav-btn-workflow",
            `data-target` = "homologous",
            `aria-expanded` = "false",
            `aria-controls` = "app-workflow-panel-homologous",
            title = "Multi-Gene Search",
            icon("dna"),
            span("Multi-Gene Search"),
            span(class = "app-nav-collapsed-label", "Multi")
          ),
          div(
            class = "app-nav-inline-panel",
            id = "app-workflow-panel-homologous",
            `data-workflow-panel` = "homologous",
            div(
              class = "panel-content app-control-panel app-workflow-panel",
              div(
                class = "app-submenu app-submenu-controls",
                div(
                  class = "app-submenu-body app-submenu-controls-body",
                  div(
                    class = "app-workflow-intro",
                    p("Query multiple annotated genes within one organism.")
                  ),
                  div(
                    class = "app-compact-section app-compact-section-tight",
                    div(class = "app-compact-label", icon("database"), span("Data source")),
                    div(
                      class = "viz-mode-wrap",
                      htmltools::tagAppendAttributes(
                        radioButtons(
                          inputId = "homo_data_mode",
                          label = NULL,
                          choices = c("Preloaded organism" = "preloaded", "NCBI Search" = "ncbi", "Upload files" = "upload"),
                          selected = "preloaded",
                          inline = TRUE
                        ),
                        class = "viz-mode-toggle"
                      )
                    ),
                    conditionalPanel(
                      condition = "input.homo_data_mode == 'upload'",
                      fileInput(
                        inputId = "file1",
                        label = "Upload annotation file",
                        accept = c(".gff", ".gff3", ".gtf", ".txt")
                      ),
                      fileInput(
                        inputId = "genome_fasta1",
                        label = "Upload genome FASTA/2bit (required)",
                        accept = c(".fa", ".fasta", ".fna", ".fa.gz", ".fasta.gz", ".fna.gz", ".2bit")
                      ),
                      tags$details(
                        class = "app-optional-uploads-panel",
                        tags$summary(
                          class = "app-optional-uploads-summary",
                          icon("plus-circle"),
                          span("Optional files"),
                          span(class = "app-optional-uploads-hint", "Enhance your analysis")
                        ),
                        div(
                          class = "app-optional-uploads-body",
                          fileInput(
                            inputId = "homo_assembly_report",
                            label = tags$span(icon("file-alt"), "Assembly report (.txt)"),
                            accept = c(".txt")
                          ),
                          fileInput(
                            inputId = "homo_assembly_stats",
                            label = tags$span(icon("chart-bar"), "Assembly stats (.txt)"),
                            accept = c(".txt")
                          ),
                          fileInput(
                            inputId = "homo_go_annotations",
                            label = tags$span(icon("project-diagram"), "GO annotations (.gaf, .gaf.gz)"),
                            accept = c(".gaf", ".gaf.gz", ".gz")
                          )
                        )
                      ),
                      class = "app-upload-inputs"
                    ),
                    conditionalPanel(
                      condition = "input.homo_data_mode == 'ncbi'",
                      class = "app-ncbi-search-panel",
                      div(
                        class = "app-ncbi-search-input-wrap",
                        tags$label(class = "app-ncbi-search-label", icon("globe"), "Search NCBI for an organism"),
                        div(
                          class = "app-ncbi-search-row",
                          textInput(
                            inputId = "homo_ncbi_query",
                            label = NULL,
                            placeholder = "e.g. Drosophila virilis, Coffea arabica..."
                          ),
                          actionButton("homo_ncbi_search_btn", icon("search"),
                                       class = "btn-sm app-ncbi-search-go")
                        )
                      ),
                      uiOutput("homo_ncbi_results"),
                      uiOutput("homo_ncbi_preview"),
                      uiOutput("homo_ncbi_download_status")
                    )
                  ),
                  div(
                    class = "app-compact-section app-compact-section-tight",
                    div(class = "app-compact-label", icon("sliders"), span("Visualization mode")),
                    tags$datalist(id = "filter1_suggestions"),
                    div(
                      class = "app-hidden-query",
                      htmltools::tagAppendAttributes(
                        textInput(
                          inputId = "filter1",
                          label = "Search gene",
                          placeholder = "Enter gene name"
                        ),
                        list = "filter1_suggestions"
                      )
                    ),
                    div(
                      class = "viz-mode-wrap",
                      htmltools::tagAppendAttributes(
                        radioButtons(
                          inputId = "homo_visual_mode",
                          label = NULL,
                          choices = c("Compact" = "compact", "Detailed" = "detailed"),
                          selected = "compact",
                          inline = TRUE
                        ),
                        class = "viz-mode-toggle"
                      )
                    )
                  ),
                  div(
                    class = "app-compact-section app-compact-section-tight app-organism-inline-section",
                    tags$details(
                      class = "app-submenu app-submenu-organism app-submenu-organism-inline",
                      tags$summary(
                        span(
                          class = "app-organism-summary-main",
                          icon("dna"),
                          span(id = "homo-organism-summary-text", class = "app-organism-summary-text", "Organism selection")
                        ),
                        span(class = "app-organism-summary-info", uiOutput("homo_preloaded_info_icon", container = span))
                      ),
                      div(
                        class = "app-submenu-body",
                        conditionalPanel(
                          condition = "input.homo_data_mode == 'preloaded'",
                          uiOutput("homo_species_grid")
                        ),
                        conditionalPanel(
                          condition = "input.homo_data_mode == 'upload'",
                          p(class = "app-submenu-hint", "Organism is inferred from uploaded files.")
                        ),
                        conditionalPanel(
                          condition = "input.homo_data_mode == 'ncbi'",
                          p(class = "app-submenu-hint", "Organism will be loaded from NCBI after download.")
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        ),
        div(
          class = "app-nav-group",
          tags$button(
            type = "button",
            class = "app-nav-btn app-nav-btn-workflow",
            `data-target` = "orthologous",
            `aria-expanded` = "false",
            `aria-controls` = "app-workflow-panel-orthologous",
            title = "Cross-Species Gene Search",
            icon("sitemap"),
            span("Cross-Species Gene Search"),
            span(class = "app-nav-collapsed-label", "Cross")
          ),
          div(
            class = "app-nav-inline-panel",
            id = "app-workflow-panel-orthologous",
            `data-workflow-panel` = "orthologous",
            div(
              class = "panel-content app-control-panel app-workflow-panel",
              div(
                class = "app-submenu app-submenu-controls",
                div(
                  class = "app-submenu-body app-submenu-controls-body",
                  div(
                    class = "app-workflow-intro",
                    p("Query one selected gene across multiple organisms.")
                  ),
                  div(
                    class = "app-compact-section app-compact-section-tight",
                    div(class = "app-compact-label", icon("database"), span("Data source")),
                    div(
                      class = "viz-mode-wrap",
                      htmltools::tagAppendAttributes(
                        radioButtons(
                          inputId = "ortho_data_mode",
                          label = NULL,
                          choices = c("Preloaded organisms" = "preloaded", "NCBI Search" = "ncbi", "Upload files" = "upload"),
                          selected = "preloaded",
                          inline = TRUE
                        ),
                        class = "viz-mode-toggle"
                      )
                    ),
                    conditionalPanel(
                      condition = "input.ortho_data_mode == 'upload'",
                      fileInput(
                        inputId = "files",
                        label = "Upload annotation files",
                        multiple = TRUE,
                        accept = c(".gff", ".gff3", ".gtf", ".txt")
                      ),
                      fileInput(
                        inputId = "genome_fasta_ortho",
                        label = "Upload genome FASTA/2bit files (required, one per annotation)",
                        multiple = TRUE,
                        accept = c(".fa", ".fasta", ".fna", ".fa.gz", ".fasta.gz", ".fna.gz", ".2bit")
                      ),
                      tags$details(
                        class = "app-optional-uploads-panel",
                        tags$summary(
                          class = "app-optional-uploads-summary",
                          icon("plus-circle"),
                          span("Optional files"),
                          span(class = "app-optional-uploads-hint", "Enhance your analysis")
                        ),
                        div(
                          class = "app-optional-uploads-body",
                          fileInput(
                            inputId = "ortho_assembly_reports",
                            label = tags$span(icon("file-alt"), "Assembly reports (.txt)"),
                            multiple = TRUE,
                            accept = c(".txt")
                          ),
                          fileInput(
                            inputId = "ortho_assembly_stats",
                            label = tags$span(icon("chart-bar"), "Assembly stats (.txt)"),
                            multiple = TRUE,
                            accept = c(".txt")
                          ),
                          fileInput(
                            inputId = "ortho_go_annotations",
                            label = tags$span(icon("project-diagram"), "GO annotations (.gaf, .gaf.gz)"),
                            multiple = TRUE,
                            accept = c(".gaf", ".gaf.gz", ".gz")
                          )
                        )
                      ),
                      class = "app-upload-inputs"
                    ),
                    conditionalPanel(
                      condition = "input.ortho_data_mode == 'ncbi'",
                      class = "app-ncbi-search-panel",
                      div(
                        class = "app-ncbi-search-input-wrap",
                        tags$label(class = "app-ncbi-search-label", icon("globe"), "Search NCBI for organisms"),
                        div(
                          class = "app-ncbi-search-row",
                          textInput(
                            inputId = "ortho_ncbi_query",
                            label = NULL,
                            placeholder = "e.g. Drosophila virilis, Coffea arabica..."
                          ),
                          actionButton("ortho_ncbi_search_btn", icon("search"),
                                       class = "btn-sm app-ncbi-search-go")
                        )
                      ),
                      uiOutput("ortho_ncbi_results"),
                      uiOutput("ortho_ncbi_queue"),
                      uiOutput("ortho_ncbi_download_status")
                    )
                  ),
                  div(
                    class = "app-compact-section app-compact-section-tight",
                    div(class = "app-compact-label", icon("sliders"), span("Visualization mode")),
                    tags$datalist(id = "gene_name_suggestions"),
                    div(
                      class = "app-hidden-query",
                      htmltools::tagAppendAttributes(
                        textInput(
                          inputId = "gene_name",
                          label = "Search gene",
                          placeholder = "Enter gene name"
                        ),
                        list = "gene_name_suggestions"
                      )
                    ),
                    div(
                      class = "viz-mode-wrap",
                      htmltools::tagAppendAttributes(
                        radioButtons(
                          inputId = "ortho_visual_mode",
                          label = NULL,
                          choices = c(
                            "Compact" = "compact",
                            "Detailed" = "detailed",
                            "Comparative Aligned" = "aligned",
                            "LASTZ Blocks" = "pip_blocks",
                            "MultiPIP-style" = "pip_multipip"
                          ),
                          selected = "compact",
                          inline = TRUE
                        ),
                        class = "viz-mode-toggle"
                      )
                    )
                  ),
                  div(
                    class = "app-compact-section app-compact-section-tight app-organism-inline-section",
                    tags$details(
                      class = "app-submenu app-submenu-organism app-submenu-organism-inline",
                      tags$summary(
                        span(
                          class = "app-organism-summary-main",
                          icon("dna"),
                          span(id = "ortho-organism-summary-text", class = "app-organism-summary-text", "Organism selection")
                        ),
                        span(class = "app-organism-summary-info", uiOutput("ortho_preloaded_info_icon", container = span))
                      ),
                      div(
                        class = "app-submenu-body",
                        conditionalPanel(
                          condition = "input.ortho_data_mode == 'preloaded'",
                          uiOutput("ortho_species_grid")
                        ),
                        conditionalPanel(
                          condition = "input.ortho_data_mode == 'upload'",
                          p(class = "app-submenu-hint", "Organism list comes from the uploaded set.")
                        ),
                        conditionalPanel(
                          condition = "input.ortho_data_mode == 'ncbi'",
                          p(class = "app-submenu-hint", "Organisms will be loaded from NCBI after download.")
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        ),
        tags$button(type = "button", class = "app-nav-btn", `data-target` = "settings", title = "Settings", icon("cog"), span("Settings")),
        tags$button(type = "button", class = "app-nav-btn", `data-target` = "help", title = "Help", icon("question-circle"), span("Help")),
        tags$button(type = "button", class = "app-nav-btn", `data-target` = "feedback", title = "Feedback", icon("comment-dots"), span("Feedback")),
        div(class = "app-nav-separator"),
        div(
          class = "app-nav-actions",
          div(
            class = "app-primary-search",
            tags$i(class = "fa fa-search app-primary-search-icon"),
            div(
              class = "app-primary-search-input-wrap",
              htmltools::tagAppendAttributes(
                textInput(
                  inputId = "global_search_query",
                  label = NULL,
                  placeholder = "Search gene"
                ),
                autocomplete = "new-password",
                autocorrect = "off",
                autocapitalize = "off",
                spellcheck = "false",
                `data-form-type` = "other",
                `data-lpignore` = "true",
                `data-1p-ignore` = "true"
              ),
              tags$datalist(id = "global_search_query_suggestions"),
              div(id = "global-search-suggestions", class = "app-search-suggestions")
            )
          ),
          # sidebar-batch-ui-group: hidden in orthologous mode (batch not allowed for ortho)
          div(
            id = "sidebar-batch-ui-group",
            div(
              id = "global-search-chipbar",
              class = "app-search-chipbar",
              div(
                id = "global-search-chip-list",
                class = "app-search-chip-list app-search-chip-list-sync",
                span(class = "app-search-chip-empty", "No genes added yet.")
              ),
              div(
                class = "app-search-chip-actions",
                tags$button(
                  id = "global_search_add_chip",
                  type = "button",
                  class = "app-search-chip-btn",
                  icon("plus"),
                  span("Add to batch")
                ),
                tags$button(
                  id = "global_search_clear_chips",
                  type = "button",
                  class = "app-search-chip-btn app-search-chip-btn-clear",
                  icon("times"),
                  span("Clear batch"),
                  disabled = "disabled"
                )
              ),
              tags$input(id = "global_search_chip_payload", type = "hidden", value = "")
            )
          ), # end sidebar-batch-ui-group
          actionButton(
            inputId = "global_search_go",
            label = span("Generate visualization"),
            icon = icon("search"),
            class = "btn-primary app-action-btn app-sidebar-primary-btn"
          ),
          div(
            id = "global-search-batch-count",
            class = "app-search-batch-count is-empty",
            "Batch: 0 genes"
          ),
          tags$button(
            id = "global_search_toggle_collapsed",
            type = "button",
            class = "btn btn-primary app-action-btn app-sidebar-primary-btn app-collapsed-search-toggle",
            `aria-expanded` = "false",
            title = "Search gene",
            icon("search"),
            span("Search gene")
          ),
          div(
            id = "app-collapsed-search-panel",
            class = "app-nav-inline-panel app-collapsed-search-panel",
            div(
              class = "panel-content app-control-panel",
              div(
                class = "app-collapsed-search-control",
                div(
                  class = "app-inline-control-title",
                  icon("search"),
                  span("Gene search")
                ),
                div(
                  class = "app-collapsed-search-input-wrap",
                  htmltools::tagAppendAttributes(
                    textInput(
                      inputId = "global_search_query_collapsed",
                      label = NULL,
                      placeholder = "Enter gene name (add to batch)"
                    ),
                    list = "global_search_query_suggestions_collapsed",
                    autocomplete = "new-password",
                    autocorrect = "off",
                    autocapitalize = "off",
                    spellcheck = "false",
                    `data-form-type` = "other",
                    `data-lpignore` = "true",
                    `data-1p-ignore` = "true"
                  ),
                  div(id = "global-search-suggestions-collapsed", class = "app-search-suggestions app-search-suggestions-collapsed"),
                  tags$datalist(id = "global_search_query_suggestions_collapsed")
                ),
                div(
                  id = "collapsed-batch-preview",
                  class = "app-collapsed-search-chip-preview",
                  div(class = "app-collapsed-search-chip-title", "Batch preview"),
                  div(
                    id = "global-search-chip-list-collapsed",
                    class = "app-search-chip-list app-search-chip-list-sync app-search-chip-list-compact",
                    `data-empty-label` = "No batch genes.",
                    span(class = "app-search-chip-empty", "No batch genes.")
                  )
                ),
                actionButton(
                  inputId = "global_search_go_collapsed",
                  label = span("Generate visualization"),
                  icon = icon("search"),
                  class = "btn-primary app-action-btn app-collapsed-generate-btn"
                )
              )
            )
          ),
          actionButton(
            inputId = "clear_all_visualizations",
            label = span("Clear visualizations"),
            icon = icon("trash"),
            class = "btn-clear-plots app-clear-btn app-sidebar-clear-btn",
            title = "Clear visualizations"
          ),
          p(id = "sidebar-search-hint", class = "app-nav-actions-hint", "Tip: press Space to add a gene to batch (also Ctrl+Enter), then Generate visualization.")
        )
      ),
      div(
        id = "app-hidden-workflow-triggers",
        style = "display:none;",
        actionButton("generate1", span("Generate")),
        actionButton("search_gene", span("Search"))
      )
    ),
    tags$main(
      class = "app-main",
      # ── Mobile context bar: sticky breadcrumb for mobile navigation ──
      div(
        class = "mobile-context-bar",
        tags$button(
          class = "mobile-ctx-hamburger",
          onclick = "if(typeof toggleMobileNav==='function')toggleMobileNav();",
          `aria-label` = "Open menu",
          HTML("&#9776;")
        ),
        span(class = "mobile-ctx-label",
          span(class = "mobile-ctx-gene", ""),
          span(class = "mobile-ctx-workflow", "")
        )
      ),
      tabsetPanel(
        id = "navtabs",
        type = "hidden",
        selected = "home",
        tabPanel(
          title = "Home",
          value = "home",
          div(
            class = "content-wrapper app-main-pane app-home-pane",

            # ── Hero section with particles background ──────────────────────
            div(
              class = "app-home-hero-wrap",
              tags$canvas(id = "home-particles", class = "home-particles-canvas"),
              div(
                class = "app-home-hero-content",
                div(
                  class = "app-home-brand home-reveal",
                  tags$img(
                    src = versioned_asset_path("favicon2.ico?v=2"),
                    class = "app-home-brand-logo home-hero-logo-pulse",
                    `data-light-src` = versioned_asset_path("favicon2.ico?v=2"),
                    `data-dark-src` = versioned_asset_path("favicon.ico?v=2"),
                    alt = "CGV logo"
                  ),
                  div(
                    class = "app-home-brand-copy",
                    h1(class = "app-home-title home-reveal", "Comparative Gene Viewer"),
                    p(class = "app-home-subtitle home-reveal",
                      "Explore, compare, and analyze gene structures across species in one unified workspace.",
                      tags$br(),
                      tags$span(class = "home-typing-wrap",
                        "Built for ",
                        tags$span(class = "home-typing-text", `data-words` = '["researchers.","bioinformaticians.","educators.","students."]', "researchers."),
                        tags$span(class = "home-typing-cursor", "|")
                      )
                    )
                  )
                ),

                # ── CTA buttons ─────────────────────────────────────────────
                div(
                  class = "home-hero-actions home-reveal",
                  tags$button(
                    type = "button",
                    class = "home-cta-btn home-cta-choice-gene",
                    onclick = "document.querySelector('.app-nav-btn[data-target=\"homologous\"]').click();",
                    span(class = "home-cta-icon-wrap", icon("search")),
                    span(
                      class = "home-cta-copy",
                      span(class = "home-cta-title", "Multi-Gene Search"),
                      span(class = "home-cta-note", "Inspect several genes within one organism.")
                    )
                  ),
                  tags$button(
                    type = "button",
                    class = "home-cta-btn home-cta-choice-cross",
                    onclick = "document.querySelector('.app-nav-btn[data-target=\"orthologous\"]').click();",
                    span(class = "home-cta-icon-wrap", icon("dna")),
                    span(
                      class = "home-cta-copy",
                      span(class = "home-cta-title", "Cross-Species Analysis"),
                      span(class = "home-cta-note", "Compare representative gene structures across species.")
                    )
                  )
                ),

                # ── Stats counters (dynamic from registry) ──────────────────
                uiOutput("home_stats_strip")
              )
            ),

            # ── JS for home animations ──────────────────────────────────────
            tags$script(src = versioned_asset_path("js/home_animations.js")),

            # ── CSS for home + help informational content ────────────────────
            tags$style(HTML("
              .home-section {
                margin: 0 0 24px 0;
                padding: 22px 22px;
                background: linear-gradient(180deg, #fbfdff 0%, #f5f9fc 100%);
                border: 1px solid #dbe6ef;
                border-radius: 16px;
                box-shadow: 0 10px 24px rgba(32, 58, 82, 0.07);
              }
              .home-section-title {
                font-size: 22px;
                font-weight: 800;
                color: #1f3246;
                margin: 0 0 8px 0;
                display: flex;
                align-items: center;
                gap: 10px;
                line-height: 1.2;
              }
              .home-section-title .fa,
              .home-section-title .fas {
                color: #18BC9C;
                font-size: 18px;
              }
              .home-section-sub {
                max-width: 860px;
                font-size: 13px;
                color: #5a6f82;
                margin: 0 0 16px 0;
                line-height: 1.6;
              }
              .app-home-pane > .home-section:first-of-type {
                margin-top: 0;
              }
              .app-home-pane > .home-section {
                max-width: 1280px;
                margin-left: auto;
                margin-right: auto;
                margin-bottom: 24px;
              }
              .home-motivation-grid,
              .home-features-grid,
              .home-scope-grid {
                display: grid;
                gap: 12px;
              }
              .home-motivation-grid {
                grid-template-columns: repeat(auto-fit, minmax(230px, 1fr));
              }
              .home-features-grid {
                grid-template-columns: repeat(3, minmax(0, 1fr));
              }
              .home-scope-grid {
                grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
              }
              .home-flow-strip {
                display: flex;
                align-items: center;
                gap: 0;
                margin-bottom: 18px;
                flex-wrap: wrap;
              }
              .home-flow-step {
                display: flex;
                align-items: center;
                gap: 10px;
                padding: 14px 14px;
                border-radius: 14px;
                border: 1px solid #d8e3ec;
                background: #ffffff;
                position: relative;
                transition: all 0.3s cubic-bezier(0.22, 1, 0.36, 1);
              }
              .home-flow-step:hover {
                border-color: rgba(24, 188, 156, 0.3);
                box-shadow: 0 8px 24px rgba(24, 188, 156, 0.1);
                transform: translateY(-2px);
              }
              .home-flow-step-icon {
                width: 38px;
                height: 38px;
                border-radius: 11px;
                background: linear-gradient(135deg, #eff8f5 0%, #e3f4ee 100%);
                color: #18BC9C;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 15px;
                flex-shrink: 0;
                transition: transform 0.3s ease;
              }
              .home-flow-step:hover .home-flow-step-icon {
                transform: scale(1.1);
              }
              .home-flow-step-label {
                font-size: 12.5px;
                font-weight: 800;
                color: #22364a;
                letter-spacing: 0.01em;
                line-height: 1.35;
              }
              .home-motivation-card,
              .home-feature-card,
              .home-scope-yes-card,
              .home-scope-no-card {
                border-radius: 14px;
                border: 1px solid #d8e3ec;
                background: #ffffff;
                padding: 18px;
                min-height: 100%;
                transition: all 0.32s cubic-bezier(0.22, 1, 0.36, 1);
              }
              .home-motivation-card-icon,
              .home-feature-card-icon {
                width: 42px;
                height: 42px;
                border-radius: 12px;
                background: linear-gradient(135deg, #eff8f5 0%, #e3f4ee 100%);
                display: flex;
                align-items: center;
                justify-content: center;
                margin-bottom: 12px;
                font-size: 17px;
                color: #18BC9C;
                transition: transform 0.3s cubic-bezier(0.22, 1, 0.36, 1),
                            box-shadow 0.3s ease;
              }
              .home-card-hover:hover .home-motivation-card-icon,
              .home-card-hover:hover .home-feature-card-icon {
                transform: scale(1.12) rotate(-3deg);
                box-shadow: 0 4px 14px rgba(24, 188, 156, 0.2);
              }
              .home-motivation-card h4,
              .home-feature-card h4,
              .home-scope-yes-card h4,
              .home-scope-no-card h4 {
                font-size: 14px;
                font-weight: 700;
                color: #22364a;
                margin: 0 0 8px 0;
                line-height: 1.3;
              }
              .home-motivation-card p,
              .home-feature-card p {
                font-size: 12.5px;
                color: #566c7f;
                line-height: 1.6;
                margin: 0;
              }
              .home-feature-card {
                position: relative;
                overflow: hidden;
              }
              .home-feature-card::after {
                display: none;
              }
              .home-scope-yes-card {
                border-color: #b7ded2;
                background: linear-gradient(180deg, #fbfffd 0%, #f0faf6 100%);
              }
              .home-scope-no-card {
                border-color: #e6d3c0;
                background: linear-gradient(180deg, #fffdfa 0%, #fbf4ec 100%);
              }
              .home-scope-yes-card h4 { color: #0d6e50; }
              .home-scope-no-card h4 { color: #8b5629; }
              .home-scope-yes-card ul,
              .home-scope-no-card ul {
                margin: 0;
                padding: 0;
              }
              .home-scope-yes-card li,
              .home-scope-no-card li {
                list-style: none;
                display: flex;
                align-items: flex-start;
                gap: 8px;
                padding: 4px 0;
                font-size: 12.5px;
                line-height: 1.55;
                color: #4f6477;
              }
              .home-scope-yes-card li::before,
              .home-scope-no-card li::before {
                font-weight: 900;
                flex-shrink: 0;
                line-height: 1.2;
              }
              .home-scope-yes-card li::before {
                content: '✓';
                color: #18BC9C;
              }
              .home-scope-no-card li::before {
                content: '✗';
                color: #df8350;
              }
              .home-comparison-wrap {
                overflow-x: auto;
                border: 1px solid #d6e2ec;
                border-radius: 14px;
                background: #ffffff;
                transition: box-shadow 0.3s ease;
              }
              .home-comparison-wrap:hover {
                box-shadow: 0 8px 28px rgba(32, 58, 82, 0.08);
              }
              .home-comparison-table tbody tr {
                transition: background 0.2s ease;
              }
              .home-comparison-table tbody tr:hover td {
                background: rgba(24, 188, 156, 0.04) !important;
              }
              .home-comparison-table {
                width: 100%;
                border-collapse: collapse;
                min-width: 640px;
                font-size: 12px;
              }
              .home-comparison-table thead th {
                background: #1f3246;
                color: #e8f2f9;
                font-size: 11px;
                font-weight: 700;
                padding: 10px 11px;
                text-align: center;
                white-space: nowrap;
                letter-spacing: 0.03em;
                border-right: 1px solid #304b63;
              }
              .home-comparison-table thead th:first-child {
                text-align: left;
              }
              .home-comparison-table thead th.ctv-col {
                background: #18BC9C;
                color: #ffffff;
              }
              .home-comparison-table td {
                padding: 9px 11px;
                border-bottom: 1px solid #e6edf3;
                border-right: 1px solid #e6edf3;
                text-align: center;
                vertical-align: middle;
                color: #53697b;
              }
              .home-comparison-table tbody tr:nth-child(odd) td {
                background: #fbfdff;
              }
              .home-comparison-table tbody tr:nth-child(even) td {
                background: #ffffff;
              }
              .home-comparison-table td:first-child {
                text-align: left;
                font-size: 12px;
                font-weight: 600;
                color: #22364a;
                white-space: nowrap;
              }
              .home-comparison-table td.ctv-col {
                background: #f0faf7 !important;
              }
              .ctv-yes,
              .ctv-no,
              .ctv-partial {
                font-weight: 800;
                font-size: 15px;
              }
              .ctv-yes { color: #18BC9C; }
              .ctv-no { color: #a8b7c3; }
              .ctv-partial { color: #f0a234; }
              .home-comparison-note {
                margin: 10px 0 0 0;
                font-size: 12px;
                color: #61778b;
                line-height: 1.55;
              }
              html[data-app-theme='dark'] .home-section {
                background: linear-gradient(180deg, #132a3f 0%, #172f45 100%);
                border-color: #274b66;
                box-shadow: 0 12px 26px rgba(0, 0, 0, 0.24);
              }
              html[data-app-theme='dark'] .home-section-title {
                color: #d5e7f7;
              }
              html[data-app-theme='dark'] .home-section-sub,
              html[data-app-theme='dark'] .home-comparison-note {
                color: #93b2c8;
              }
              html[data-app-theme='dark'] .home-motivation-card,
              html[data-app-theme='dark'] .home-feature-card,
              html[data-app-theme='dark'] .home-scope-yes-card,
              html[data-app-theme='dark'] .home-scope-no-card {
                background: #10263a;
                border-color: #2a4e69;
              }
              html[data-app-theme='dark'] .home-motivation-card-icon,
              html[data-app-theme='dark'] .home-feature-card-icon {
                background: linear-gradient(180deg, #1b3d50 0%, #1c4850 100%);
              }
              html[data-app-theme='dark'] .home-flow-step {
                background: #10263a;
                border-color: #2a4e69;
              }
              html[data-app-theme='dark'] .home-flow-step-icon {
                background: linear-gradient(135deg, #1b3d50 0%, #1c4850 100%);
              }
              html[data-app-theme='dark'] .home-flow-step-label {
                color: #d5e7f7;
              }
              html[data-app-theme='dark'] .home-flow-arrow {
                background: linear-gradient(90deg, #18BC9C, rgba(24, 188, 156, 0.2));
              }
              html[data-app-theme='dark'] .home-flow-step-number {
                box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
              }
              html[data-app-theme='dark'] .home-motivation-card h4,
              html[data-app-theme='dark'] .home-feature-card h4 {
                color: #d5e7f7;
              }
              html[data-app-theme='dark'] .home-motivation-card p,
              html[data-app-theme='dark'] .home-feature-card p,
              html[data-app-theme='dark'] .home-scope-yes-card li,
              html[data-app-theme='dark'] .home-scope-no-card li {
                color: #9ebdd2;
              }
              html[data-app-theme='dark'] .home-scope-yes-card {
                background: linear-gradient(180deg, #102a1f 0%, #163326 100%);
                border-color: #2f6b4f;
              }
              html[data-app-theme='dark'] .home-scope-no-card {
                background: linear-gradient(180deg, #2a1d14 0%, #34231b 100%);
                border-color: #71402a;
              }
              html[data-app-theme='dark'] .home-scope-yes-card h4 {
                color: #77dab7;
              }
              html[data-app-theme='dark'] .home-scope-no-card h4 {
                color: #f0a06a;
              }
              html[data-app-theme='dark'] .home-comparison-wrap {
                border-color: #2a4c67;
                background: #11263a;
              }
              html[data-app-theme='dark'] .home-comparison-table thead th {
                background: #0d2236;
                color: #c7ddef;
                border-right-color: #24425b;
              }
              html[data-app-theme='dark'] .home-comparison-table thead th.ctv-col {
                background: #0e8a70;
                color: #ffffff;
              }
              html[data-app-theme='dark'] .home-comparison-table tbody tr:nth-child(odd) td {
                background: #132a3f;
              }
              html[data-app-theme='dark'] .home-comparison-table tbody tr:nth-child(even) td {
                background: #183247;
              }
              html[data-app-theme='dark'] .home-comparison-table td {
                border-color: #274b66;
                color: #9ebdd2;
              }
              html[data-app-theme='dark'] .home-comparison-table td:first-child {
                color: #d5e7f7;
              }
              html[data-app-theme='dark'] .home-comparison-table td.ctv-col {
                background: #14382f !important;
              }
              @media (max-width: 700px) {
                .home-section {
                  padding: 16px;
                  margin-bottom: 18px;
                }
                .home-section-title {
                  font-size: 18px;
                }
                .home-section-sub {
                  font-size: 12.5px;
                }
                .home-flow-strip {
                  grid-template-columns: 1fr 1fr;
                }
                .home-features-grid {
                  grid-template-columns: 1fr;
                }
                .home-comparison-table {
                  font-size: 11px;
                  min-width: 580px;
                }
              }
              @media (min-width: 701px) and (max-width: 1120px) {
                .home-features-grid {
                  grid-template-columns: repeat(2, minmax(0, 1fr));
                }
              }

              /* ── At a glance section ──────────────────────────── */
              .home-glance-grid {
                display: flex;
                flex-direction: column;
                gap: 14px;
              }
              .home-glance-two-col {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 14px;
                align-items: start;
              }
              .home-glance-col {
                display: flex;
                flex-direction: column;
                gap: 14px;
              }
              .home-glance-card {
                border-radius: 14px;
                border: 1px solid #d8e3ec;
                background: #ffffff;
                padding: 18px;
              }
              .home-glance-card-header {
                display: flex;
                align-items: center;
                gap: 10px;
                margin-bottom: 8px;
              }
              .home-glance-card-icon {
                width: 36px;
                height: 36px;
                border-radius: 10px;
                background: linear-gradient(135deg, #18BC9C, #0fa383);
                color: #ffffff;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 15px;
                flex-shrink: 0;
              }
              .home-glance-card-header h4 {
                font-size: 15px;
                font-weight: 800;
                color: #22364a;
                margin: 0;
                line-height: 1.2;
              }
              .home-glance-card-desc {
                font-size: 12.5px;
                color: #5a6f82;
                line-height: 1.55;
                margin: 0 0 12px 0;
              }

              /* Kingdoms grid (genomes) */
              .home-glance-kingdoms {
                display: grid;
                grid-template-columns: repeat(3, 1fr);
                gap: 10px;
              }
              .home-glance-kingdom { min-width: 0; }
              .home-glance-badge {
                display: inline-block;
                padding: 3px 10px;
                border-radius: 999px;
                font-size: 10.5px;
                font-weight: 700;
                letter-spacing: 0.03em;
                text-transform: uppercase;
                margin-bottom: 5px;
              }
              .home-badge-animals { background: #e8f4fd; color: #2980b9; }
              .home-badge-plants  { background: #e8f9f0; color: #0d6e50; }
              .home-badge-fungi   { background: #fef3e8; color: #b06c2a; }
              .home-badge-other   { background: #f0e8fe; color: #7c3aed; }
              .home-glance-kingdom ul {
                margin: 0; padding: 0; list-style: none;
              }
              .home-glance-kingdom li {
                font-size: 11px;
                color: #566c7f;
                padding: 1.5px 0;
                line-height: 1.4;
                font-style: italic;
              }
              .home-glance-note {
                margin-top: 12px;
                padding: 8px 12px;
                border-radius: 10px;
                background: rgba(24, 188, 156, 0.06);
                border: 1px solid rgba(24, 188, 156, 0.12);
                font-size: 11.5px;
                color: #18BC9C;
                font-weight: 600;
                display: flex;
                align-items: center;
                gap: 6px;
              }

              /* Search modes */
              .home-glance-modes {
                display: flex;
                flex-direction: column;
                gap: 10px;
              }
              .home-glance-mode {
                display: flex;
                gap: 12px;
                padding: 12px 14px;
                border-radius: 12px;
                border: 1px solid #d8e3ec;
                background: rgba(24, 188, 156, 0.02);
                transition: border-color 0.25s ease, box-shadow 0.25s ease;
              }
              .home-glance-mode:hover {
                border-color: rgba(24, 188, 156, 0.25);
                box-shadow: 0 4px 16px rgba(24, 188, 156, 0.08);
              }
              .home-glance-mode-icon {
                width: 32px; height: 32px;
                border-radius: 9px;
                background: linear-gradient(135deg, #18BC9C, #0fa383);
                color: #fff;
                display: flex; align-items: center; justify-content: center;
                font-size: 13px; flex-shrink: 0;
              }
              .home-glance-mode strong {
                font-size: 13px; color: #22364a; display: block; margin-bottom: 3px;
              }
              .home-glance-mode p {
                font-size: 11.5px; color: #566c7f; line-height: 1.5; margin: 0;
              }

              /* Analytics chips */
              .home-glance-chart-list {
                display: flex;
                flex-wrap: wrap;
                gap: 7px;
              }
              .home-glance-chip {
                display: inline-flex;
                align-items: center;
                gap: 6px;
                padding: 6px 12px;
                border-radius: 9px;
                background: rgba(24, 188, 156, 0.06);
                border: 1px solid rgba(24, 188, 156, 0.12);
                font-size: 12px;
                font-weight: 600;
                color: #22364a;
                transition: all 0.22s ease;
              }
              .home-glance-chip:hover {
                background: rgba(24, 188, 156, 0.12);
                border-color: rgba(24, 188, 156, 0.25);
                transform: translateY(-1px);
              }
              .home-glance-chip .fa,
              .home-glance-chip .fas {
                color: #18BC9C; font-size: 11px;
              }

              /* Export list */
              .home-glance-export-list {
                display: flex;
                flex-direction: column;
                gap: 7px;
              }
              .home-glance-export {
                display: flex;
                align-items: center;
                gap: 10px;
                padding: 8px 12px;
                border-radius: 10px;
                border: 1px solid #d8e3ec;
                background: #ffffff;
                transition: all 0.22s ease;
              }
              .home-glance-export:hover {
                border-color: rgba(24, 188, 156, 0.25);
                box-shadow: 0 3px 12px rgba(24, 188, 156, 0.08);
              }
              .home-glance-export-icon {
                width: 28px; height: 28px;
                border-radius: 8px;
                background: linear-gradient(135deg, #eff8f5, #e3f4ee);
                color: #18BC9C;
                display: flex; align-items: center; justify-content: center;
                font-size: 12px; flex-shrink: 0;
              }
              .home-glance-export strong {
                font-size: 12.5px; color: #22364a; display: block; line-height: 1.2;
              }
              .home-glance-export small {
                font-size: 11px; color: #6a7f91; font-weight: 500;
              }

              /* Dark theme for at-a-glance */
              html[data-app-theme='dark'] .home-glance-card {
                background: #10263a; border-color: #2a4e69;
              }
              html[data-app-theme='dark'] .home-glance-card-header h4,
              html[data-app-theme='dark'] .home-glance-mode strong,
              html[data-app-theme='dark'] .home-glance-chip,
              html[data-app-theme='dark'] .home-glance-export strong {
                color: #d5e7f7;
              }
              html[data-app-theme='dark'] .home-glance-card-desc,
              html[data-app-theme='dark'] .home-glance-kingdom li,
              html[data-app-theme='dark'] .home-glance-mode p,
              html[data-app-theme='dark'] .home-glance-export small {
                color: #9ebdd2;
              }
              html[data-app-theme='dark'] .home-glance-mode,
              html[data-app-theme='dark'] .home-glance-export {
                background: #0e1f31; border-color: #2a4e69;
              }
              html[data-app-theme='dark'] .home-glance-chip {
                background: rgba(24, 188, 156, 0.08);
                border-color: rgba(24, 188, 156, 0.15);
              }
              html[data-app-theme='dark'] .home-glance-export-icon {
                background: linear-gradient(135deg, #1b3d50, #1c4850);
              }
              html[data-app-theme='dark'] .home-badge-animals { background: #1a3248; color: #5eb8e8; }
              html[data-app-theme='dark'] .home-badge-plants  { background: #163326; color: #5ed4a0; }
              html[data-app-theme='dark'] .home-badge-fungi   { background: #2a1d14; color: #e8a65e; }
              html[data-app-theme='dark'] .home-badge-other   { background: #261a3e; color: #b28aef; }
              html[data-app-theme='dark'] .home-glance-note {
                background: rgba(24, 188, 156, 0.08);
                border-color: rgba(24, 188, 156, 0.15);
              }

              /* Responsive at-a-glance */
              @media (max-width: 700px) {
                .home-glance-two-col {
                  grid-template-columns: 1fr;
                }
                .home-glance-kingdoms {
                  grid-template-columns: 1fr;
                }
              }
              @media (min-width: 701px) and (max-width: 1120px) {
                .home-glance-two-col {
                  grid-template-columns: 1fr;
                }
              }
            ")),

            # ── 1. How it works (general workflow) ─────────────────────────
            div(
              class = "home-section home-reveal",
              p(class = "home-section-title", icon("star"), "How it works"),
              p(
                class = "home-section-sub",
                "A simple workflow from gene search to publication-ready results."
              ),
              div(
                class = "home-flow-strip home-flow-strip-animated home-stagger-parent",
                div(
                  class = "home-flow-step home-flow-step-anim home-stagger-child",
                  div(class = "home-flow-step-number", "1"),
                  div(class = "home-flow-step-icon", icon("database")),
                  div(class = "home-flow-step-label", "Choose organism & genome")
                ),
                div(class = "home-flow-connector home-stagger-child", tags$span(class = "home-flow-arrow")),
                div(
                  class = "home-flow-step home-flow-step-anim home-stagger-child",
                  div(class = "home-flow-step-number", "2"),
                  div(class = "home-flow-step-icon", icon("search")),
                  div(class = "home-flow-step-label", "Search genes by name or ID")
                ),
                div(class = "home-flow-connector home-stagger-child", tags$span(class = "home-flow-arrow")),
                div(
                  class = "home-flow-step home-flow-step-anim home-stagger-child",
                  div(class = "home-flow-step-number", "3"),
                  div(class = "home-flow-step-icon", icon("eye")),
                  div(class = "home-flow-step-label", "Visualize & compare structures")
                ),
                div(class = "home-flow-connector home-stagger-child", tags$span(class = "home-flow-arrow")),
                div(
                  class = "home-flow-step home-flow-step-anim home-stagger-child",
                  div(class = "home-flow-step-number", "4"),
                  div(class = "home-flow-step-icon", icon("chart-bar")),
                  div(class = "home-flow-step-label", "Analyze with interactive charts")
                ),
                div(class = "home-flow-connector home-stagger-child", tags$span(class = "home-flow-arrow")),
                div(
                  class = "home-flow-step home-flow-step-anim home-stagger-child",
                  div(class = "home-flow-step-number", "5"),
                  div(class = "home-flow-step-icon", icon("download")),
                  div(class = "home-flow-step-label", "Export & share results")
                )
              )
            ),

            # ── 2. Core capabilities ──────────────────────────────────────
            div(
              class = "home-section home-reveal",
              p(class = "home-section-title", icon("cubes"), "Core capabilities"),
              p(
                class = "home-section-sub",
                "Everything you need for comparative gene structure analysis in one place."
              ),
              div(
                class = "home-features-grid home-stagger-parent",
                div(
                  class = "home-feature-card home-card-hover home-stagger-child",
                  div(class = "home-feature-card-icon", icon("search")),
                  tags$h4("Gene search across organisms"),
                  tags$p("Query multiple annotated genes within one organism or compare one gene across species.")
                ),
                div(
                  class = "home-feature-card home-card-hover home-stagger-child",
                  div(class = "home-feature-card-icon", icon("dna")),
                  tags$h4("Comparative aligned view"),
                  tags$p("Compare representative gene models and label exon-level event patterns across organisms.")
                ),
                div(
                  class = "home-feature-card home-card-hover home-stagger-child",
                  div(class = "home-feature-card-icon", icon("chart-bar")),
                  tags$h4("Interactive gene cards"),
                  tags$p("Inspect gene structure, transcripts, genomic context, tooltips, zoom, and linked resources.")
                ),
                div(
                  class = "home-feature-card home-card-hover home-stagger-child",
                  div(class = "home-feature-card-icon", icon("chart-pie")),
                  tags$h4("Built-in analytics"),
                  tags$p("Structural and sequence analytics with 9 chart types \u2014 all without leaving the app.")
                ),
                div(
                  class = "home-feature-card home-card-hover home-stagger-child",
                  div(class = "home-feature-card-icon", icon("upload")),
                  tags$h4("Preloaded & custom data"),
                  tags$p("Work with preloaded references or upload your own genome and annotation pair.")
                ),
                div(
                  class = "home-feature-card home-card-hover home-stagger-child",
                  div(class = "home-feature-card-icon", icon("download")),
                  tags$h4("Export & session reuse"),
                  tags$p("Export figures, tables, sequences. Save or restore full sessions for later.")
                )
              )
            ),

            # ── 3. At a glance (dynamic from registry) ────────────────────
            uiOutput("home_glance_section"),

            # ── 4. Why CGV was built ──────────────────────────────────────
            div(
              class = "home-section home-reveal",
              p(class = "home-section-title", icon("lightbulb"), "Why CGV was built"),
              p(
                class = "home-section-sub",
                "Comparative gene structure analysis made easier to inspect, explain, and share \u2014 without jumping between browsers, scripts, and static plots."
              ),
              div(
                class = "home-motivation-grid home-stagger-parent",
                div(
                  class = "home-motivation-card home-card-hover home-stagger-child",
                  div(class = "home-motivation-card-icon", icon("exclamation-triangle")),
                  tags$h4("The problem"),
                  tags$p("Genome browsers are great for locus inspection, but not for clear side-by-side gene structure comparison across species.")
                ),
                div(
                  class = "home-motivation-card home-card-hover home-stagger-child",
                  div(class = "home-motivation-card-icon", icon("sitemap")),
                  tags$h4("The workflow gap"),
                  tags$p("Search, alignment, inspection, and export are usually spread across several tools. CGV unifies them.")
                ),
                div(
                  class = "home-motivation-card home-card-hover home-stagger-child",
                  div(class = "home-motivation-card-icon", icon("users")),
                  tags$h4("Who CGV is for"),
                  tags$p("Biologists, bioinformaticians, and students who want a guided visual workflow instead of code-heavy pipelines.")
                )
              )
            ),

            # ── 5. Scope ─────────────────────────────────────────────────
            div(
              class = "home-section home-reveal",
              p(class = "home-section-title", icon("info-circle"), "Scope"),
              p(
                class = "home-section-sub",
                "CGV is focused on gene-centered structure interpretation. Clear scope helps pair CGV with the right upstream or downstream tools."
              ),
              div(
                class = "home-scope-grid home-stagger-parent",
                div(
                  class = "home-scope-yes-card home-card-hover home-stagger-child",
                  tags$h4(icon("check-circle"), "Designed for"),
                  tags$ul(
                    tags$li("Comparative gene and exon structure analysis across multiple organisms"),
                    tags$li("Aligned exon-level relationships in a cross-species context"),
                    tags$li("Interactive gene metrics, transcript structure, sequence composition"),
                    tags$li("Preloaded references with custom genome and annotation uploads"),
                    tags$li("Publication-ready exports: plots, tables, and sequences"),
                    tags$li("Session save and restore for reproducible review")
                  )
                ),
                div(
                  class = "home-scope-no-card home-card-hover home-stagger-child",
                  tags$h4(icon("times-circle"), "Not designed for"),
                  tags$ul(
                    tags$li("Differential expression, isoform switching, or abundance testing"),
                    tags$li("Variant calling, SNP/INDEL analysis, RNA-seq quantification"),
                    tags$li("Whole-genome browsing or large region navigation"),
                    tags$li("De novo genome or transcriptome assembly"),
                    tags$li("Phylogenetic inference or protein 3D structure prediction"),
                    tags$li("High-throughput genome-wide batch analysis")
                  )
                )
              )
            ),

            # ── 6. How CGV compares ──────────────────────────────────────
            div(
              class = "home-section home-reveal",
              p(class = "home-section-title", icon("table"), "How CGV compares"),
              p(
                class = "home-section-sub",
                HTML("Compact scope summary: &nbsp; \u2713 native support &nbsp;&nbsp; ~ possible with limits &nbsp;&nbsp; \u2717 not the main purpose")
              ),
              div(
                class = "home-comparison-wrap",
                tags$table(
                  class = "home-comparison-table",
                  tags$thead(
                    tags$tr(
                      tags$th("Capability"),
                      tags$th(class = "ctv-col", icon("star"), " CGV"),
                      tags$th("Ensembl / UCSC"),
                      tags$th("JBrowse2 / Apollo"),
                      tags$th("IsoformSwitchAnalyzeR / FLAIR"),
                      tags$th("gggenomes / gggenes")
                    )
                  ),
                  tags$tbody(
                    tags$tr(
                      tags$td("Cross-species gene structure comparison"),
                      tags$td(class = "ctv-col", span(class = "ctv-yes", "\u2713")),
                      tags$td(span(class = "ctv-partial", "~"), tags$small(" locus browsing")),
                      tags$td(span(class = "ctv-partial", "~"), tags$small(" manual setup")),
                      tags$td(span(class = "ctv-no", "\u2717")),
                      tags$td(span(class = "ctv-partial", "~"), tags$small(" static plots"))
                    ),
                    tags$tr(
                      tags$td("Representative exon alignment with event labels"),
                      tags$td(class = "ctv-col", span(class = "ctv-yes", "\u2713")),
                      tags$td(span(class = "ctv-no", "\u2717")),
                      tags$td(span(class = "ctv-no", "\u2717")),
                      tags$td(span(class = "ctv-no", "\u2717")),
                      tags$td(span(class = "ctv-no", "\u2717"))
                    ),
                    tags$tr(
                      tags$td("Interactive gene cards plus analytics"),
                      tags$td(class = "ctv-col", span(class = "ctv-yes", "\u2713")),
                      tags$td(span(class = "ctv-partial", "~"), tags$small(" limited metrics")),
                      tags$td(span(class = "ctv-partial", "~"), tags$small(" browser focus")),
                      tags$td(span(class = "ctv-partial", "~"), tags$small(" analysis focus")),
                      tags$td(span(class = "ctv-partial", "~"), tags$small(" plot focus"))
                    ),
                    tags$tr(
                      tags$td("Browser-based workflow, no code required"),
                      tags$td(class = "ctv-col", span(class = "ctv-yes", "\u2713")),
                      tags$td(span(class = "ctv-yes", "\u2713")),
                      tags$td(span(class = "ctv-partial", "~"), tags$small(" config driven")),
                      tags$td(span(class = "ctv-no", "\u2717")),
                      tags$td(span(class = "ctv-no", "\u2717"))
                    ),
                    tags$tr(
                      tags$td("Custom genome plus annotation uploads"),
                      tags$td(class = "ctv-col", span(class = "ctv-yes", "\u2713")),
                      tags$td(span(class = "ctv-no", "\u2717")),
                      tags$td(span(class = "ctv-yes", "\u2713")),
                      tags$td(span(class = "ctv-partial", "~")),
                      tags$td(span(class = "ctv-yes", "\u2713"))
                    ),
                    tags$tr(
                      tags$td("Export figures, tables, sequences, sessions"),
                      tags$td(class = "ctv-col", span(class = "ctv-yes", "\u2713")),
                      tags$td(span(class = "ctv-partial", "~"), tags$small(" basic export")),
                      tags$td(span(class = "ctv-partial", "~")),
                      tags$td(span(class = "ctv-partial", "~")),
                      tags$td(span(class = "ctv-partial", "~"), tags$small(" mostly plots"))
                    )
                  )
                )
              ),
              p(
                class = "home-comparison-note",
                "Scope summary, not benchmark. Many of these tools are complementary and can be combined in one analysis workflow."
              )
            )
          )
        ),
        tabPanel(
          title = "Multi-Gene Search",
          value = "homologous",
          div(
            class = "content-wrapper app-main-pane app-main-pane-search-results",
            div(
              id = "homo_context_section",
              class = "summary-context-section",
              style = "display:none;",
              uiOutput("homo_context_header")
            ),
            div(
              id = "homo_summary_section",
              class = "summary-section homo-summary-section",
              style = "display:none;",
              div(
                class = "summary-header",
                div(
                  class = "summary-actions",
                  actionButton(
                    inputId = "toggle_homo_analytics",
                    label   = tagList("\u25B6", icon("chart-bar"), " Show Analytics"),
                    class   = "btn btn-sm btn-analytics-toggle",
                    style   = "display:none;"
                  ),
                  actionButton(
                    inputId = "toggle_homo_summary",
                    label = span("\u25B6 Show Summary Table"),
                    class = "btn btn-sm btn-summary-toggle"
                  ),
                  downloadButton("download_homo_summary_csv", span("Download CSV"), class = "btn-sm btn-download"),
                  actionButton(
                    inputId = "btn_download_all_homo_svg",
                    label = span(icon("file-zipper"), " Download result SVGs (.zip)"),
                    class = "btn btn-sm btn-download-zip",
                    style = "display:none;",
                    onclick = "exportAllSVGs('homo')"
                  ),
                  div(
                    class = "plot-zoom-control",
                    style = "display:none;",
                    id = "homo-zoom-control",
                    tags$button(
                      id = "homo-zoom-out", class = "plot-zoom-btn",
                      `data-zoom-action` = "out", `data-zoom-mode` = "homo",
                      title = "Zoom out", disabled = NA, "−"
                    ),
                    span(id = "homo-zoom-label", class = "plot-zoom-label", "1\u00d7"),
                    tags$button(
                      id = "homo-zoom-in", class = "plot-zoom-btn",
                      `data-zoom-action` = "in", `data-zoom-mode` = "homo",
                      title = "Zoom in", "\u002b"
                    )
                  ),
                  div(
                    class = "plot-sort-toolbar",
                    span(class = "plot-sort-toolbar-label", icon("sort-amount-desc"), span("Sort plots")),
                    selectInput(
                      inputId = "homo_sort_mode",
                      label = NULL,
                      choices = c(
                        "Load order" = "load",
                        "Total exon difference (high to low)" = "exondiff_desc",
                        "Total exon difference (low to high)" = "exondiff_asc",
                        "Transcript length (longest first)" = "tx_len_desc",
                        "Transcript length (shortest first)" = "tx_len_asc",
                        "Exon count (high to low)" = "exon_desc",
                        "Exon count (low to high)" = "exon_asc",
                        "Transcript name (A-Z)" = "tx_asc",
                        "Transcript name (Z-A)" = "tx_desc",
                        "Chromosome (A-Z)" = "chr_asc",
                        "Chromosome (Z-A)" = "chr_desc"
                      ),
                      selected = "load",
                      width = "320px"
                    )
                  )
                )
              ),
              div(
                id = "homo_summary_body",
                style = "display:none; margin-top:8px;",
                DT::dataTableOutput("homo_summary_dt")
              )
            ),
            # ── Sección Analytics Homologous ──────────────────────
            div(
              id = "homo_analytics_section",
              class = "analytics-section",
              style = "display:none;",
              div(
                id = "homo_analytics_body",
                class = "analytics-body",
                style = "display:none; margin-top:12px;",
                div(
                  class = "analytics-tabs-shell",
                  actionButton(
                    inputId = "btn_download_all_homo_analytics_svg",
                    label = span(icon("file-zipper"), " SVG ZIP"),
                    class = "btn btn-sm btn-download-zip btn-analytics-download-all",
                    style = "display:none;",
                    onclick = "exportAnalyticsSVGs('homo')"
                  ),
                  tabsetPanel(
                    id = "homo_analytics_tabs",
                    type = "pills",
                    tabPanel(
                      title = tagList(icon("dna"), " Architecture"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("homo_arch_chart", "homo_architecture.svg", "homo_arch_order", choices = analytics_arch_order_choices),
                        chart_info_tip("<strong>Gene Architecture</strong><br/>Stacked bar showing the base-pair composition of each gene: CDS (coding), UTR, and introns.<div class='ci-axes'><b>Y-axis:</b> Gene entry<br/><b>X-axis:</b> Base pairs (bp)</div><div class='ci-tip'>Longer bars = larger genes. Compare CDS proportion across genes.</div>"),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("homo_arch_chart", height = "auto", width = "100%"),
                          color = "#18BC9C", type = 6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("layer-group"), " Exons / Introns"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("homo_exon_chart", "homo_exons_introns.svg", "homo_exon_order", choices = analytics_exon_order_choices),
                        chart_info_tip("<strong>Exon &amp; Intron Comparison</strong><br/>Left panel: exon vs intron count. Right panel: exonic vs intronic base pairs.<div class='ci-axes'><b>Left Y-axis:</b> Count<br/><b>Right Y-axis:</b> Base pairs (bp)</div><div class='ci-tip'>Compare structural complexity &mdash; more introns often indicate regulatory complexity.</div>"),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("homo_exon_chart", height = "auto", width = "100%"),
                          color = "#18BC9C", type = 6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("microscope"), " Sequence"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("homo_seq_chart", "homo_sequence_composition.svg", "homo_seq_order", choices = analytics_seq_order_choices),
                        chart_info_tip("<strong>Nucleotide Composition</strong><br/>Percentage of each nucleotide (A, T, C, G) per gene. GC% annotated on the right.<div class='ci-axes'><b>Y-axis:</b> Gene entry<br/><b>X-axis:</b> Percentage (0&ndash;50%)</div><div class='ci-tip'>Higher GC% may indicate thermal stability or coding density.</div>"),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("homo_seq_chart", height = "auto", width = "100%"),
                          color = "#18BC9C", type = 6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("map-marker-alt"), " Genomic Context"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("homo_context_chart", "homo_genomic_context.svg", "homo_context_order", choices = analytics_context_order_choices),
                        chart_info_tip("<strong>Genomic Context</strong><br/>Distance to the nearest neighboring gene in separate panels (Upstream and Downstream).<div class='ci-axes'><b>Y-axis:</b> Gene entry<br/><b>X-axis:</b> Signed edge-to-edge distance (bp)</div><div class='ci-tip'>Negative = overlap; zero/positive = gap. The panel defines the biological side (not the sign).</div>"),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("homo_context_chart", height = "auto", width = "100%"),
                          color = "#18BC9C", type = 6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("ruler-horizontal"), " Exon Lengths"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("homo_exon_dist_chart", "homo_exon_lengths.svg", "homo_exon_dist_order", choices = analytics_exon_dist_order_choices),
                        chart_info_tip("<strong>Exon Length Distribution</strong><br/>Violin + box + jitter showing individual exon lengths per gene on a log&#8321;&#8320; scale.<div class='ci-axes'><b>Y-axis:</b> Gene entry<br/><b>X-axis:</b> Exon length in bp (log&#8321;&#8320;)</div><div class='ci-tip'>Box = IQR (25th&ndash;75th percentile). Line = median. Dots = individual exons.</div>"),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("homo_exon_dist_chart",
                            height = "auto", width = "100%"
                          ),
                          type = 4, color = "#2C3E50", size = 0.6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("circle-dot"), " Scatter"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("homo_scatter_chart", "homo_scatter.svg", "homo_scatter_order", choices = analytics_scatter_order_choices),
                        chart_info_tip(analytics_scatter_tip_html),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("homo_scatter_chart",
                            height = "auto", width = "100%"
                          ),
                          type = 4, color = "#2C3E50", size = 0.6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("table-cells"), " Heatmap"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("homo_heatmap_chart", "homo_heatmap.svg", "homo_heatmap_order", choices = analytics_heatmap_order_choices),
                        chart_info_tip(analytics_heatmap_tip_html),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("homo_heatmap_chart",
                            height = "auto", width = "100%"
                          ),
                          type = 4, color = "#2C3E50", size = 0.6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("chart-pie"), " Radar"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("homo_radar_chart", "homo_radar.svg", "homo_radar_order", choices = analytics_radar_order_choices),
                        chart_info_tip(analytics_radar_tip_html),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("homo_radar_chart",
                            height = "auto", width = "100%"
                          ),
                          type = 4, color = "#2C3E50", size = 0.6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("grip-lines"), " Correlations"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar(
                          "homo_corr_chart", "homo_correlations.svg", "homo_corr_order",
                          choices = analytics_corr_order_choices
                        ),
                        chart_info_tip(analytics_corr_tip_html),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("homo_corr_chart",
                            height = "auto", width = "100%"
                          ),
                          type = 4, color = "#2C3E50", size = 0.6
                        )
                      )
                    )
                  )
                )
              )
            ),
            # ──────────────────────────────────────────────────────
            div(
              class = "plots-zoom-wrap",
              div(
                id = "plot-container",
                style = "position: relative;",
                div(id = "homo-plot-cards-container"),
                uiOutput("homo_load_more_banner")
              )
            )
          )
        ),
        tabPanel(
          title = "Cross-Species Gene Search",
          value = "orthologous",
          div(
            class = "content-wrapper app-main-pane app-main-pane-search-results",
            div(
              id = "ortho_context_section",
              class = "summary-context-section",
              style = "display:none;",
              uiOutput("ortho_context_header")
            ),
            div(
              id = "ortho_summary_section",
              class = "summary-section ortho-summary-section",
              style = "display:none;",
              div(
                class = "summary-header",
                div(
                  class = "summary-actions",
                  actionButton(
                    inputId = "toggle_ortho_analytics",
                    label   = tagList("\u25B6", icon("chart-bar"), " Show Analytics"),
                    class   = "btn btn-sm btn-analytics-toggle",
                    style   = "display:none;"
                  ),
                  actionButton(
                    inputId = "toggle_ortho_summary",
                    label = span("\u25B6 Show Summary Table"),
                    class = "btn btn-sm btn-summary-toggle btn-ortho-summary-toggle"
                  ),
                  downloadButton("download_ortho_summary_csv", span("Download CSV"), class = "btn-sm btn-download"),
                  actionButton(
                    inputId = "btn_download_all_ortho_svg",
                    label = span(icon("file-zipper"), " Download result SVGs (.zip)"),
                    class = "btn btn-sm btn-download-zip",
                    style = "display:none;",
                    onclick = "exportAllSVGs('ortho')"
                  ),
                  div(
                    class = "plot-zoom-control",
                    style = "display:none;",
                    id = "ortho-zoom-control",
                    tags$button(
                      id = "ortho-zoom-out", class = "plot-zoom-btn",
                      `data-zoom-action` = "out", `data-zoom-mode` = "ortho",
                      title = "Zoom out", disabled = NA, "−"
                    ),
                    span(id = "ortho-zoom-label", class = "plot-zoom-label", "1\u00d7"),
                    tags$button(
                      id = "ortho-zoom-in", class = "plot-zoom-btn",
                      `data-zoom-action` = "in", `data-zoom-mode` = "ortho",
                      title = "Zoom in", "\u002b"
                    )
                  ),
                  div(
                    class = "plot-sort-toolbar",
                    span(class = "plot-sort-toolbar-label", icon("sort-amount-desc"), span("Sort plots")),
                    selectInput(
                      inputId = "ortho_sort_mode",
                      label = NULL,
                      choices = c(
                        "Load order" = "load",
                        "Total exon difference (high to low)" = "exondiff_desc",
                        "Total exon difference (low to high)" = "exondiff_asc",
                        "Transcript length (longest first)" = "tx_len_desc",
                        "Transcript length (shortest first)" = "tx_len_asc",
                        "Exon count (high to low)" = "exon_desc",
                        "Exon count (low to high)" = "exon_asc",
                        "Organism name (A-Z)" = "organism_asc",
                        "Organism name (Z-A)" = "organism_desc",
                        "Transcript name (A-Z)" = "tx_asc",
                        "Transcript name (Z-A)" = "tx_desc"
                      ),
                      selected = "load",
                      width = "320px"
                    )
                  )
                )
              ),
              div(
                id = "ortho_summary_body",
                style = "display:none; margin-top:8px;",
                DT::dataTableOutput("ortho_summary_dt")
              )
            ),
            # ── Sección Analytics Orthologous ─────────────────────
            div(
              id = "ortho_analytics_section",
              class = "analytics-section",
              style = "display:none;",
              div(
                id = "ortho_analytics_body",
                class = "analytics-body",
                style = "display:none; margin-top:12px;",
                div(
                  class = "analytics-tabs-shell",
                  actionButton(
                    inputId = "btn_download_all_ortho_analytics_svg",
                    label = span(icon("file-zipper"), " SVG ZIP"),
                    class = "btn btn-sm btn-download-zip btn-analytics-download-all",
                    style = "display:none;",
                    onclick = "exportAnalyticsSVGs('ortho')"
                  ),
                  tabsetPanel(
                    id = "ortho_analytics_tabs",
                    type = "pills",
                    tabPanel(
                      title = tagList(icon("dna"), " Architecture"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("ortho_arch_chart", "ortho_architecture.svg", "ortho_arch_order", choices = analytics_arch_order_choices),
                        chart_info_tip("<strong>Gene Architecture</strong><br/>Stacked bar showing the base-pair composition of each gene: CDS (coding), UTR, and introns.<div class='ci-axes'><b>Y-axis:</b> Organism<br/><b>X-axis:</b> Base pairs (bp)</div><div class='ci-tip'>Longer bars = larger genes. Compare CDS proportion across the compared gene models.</div>"),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("ortho_arch_chart", height = "auto", width = "100%"),
                          color = "#18BC9C", type = 6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("layer-group"), " Exons / Introns"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("ortho_exon_chart", "ortho_exons_introns.svg", "ortho_exon_order", choices = analytics_exon_order_choices),
                        chart_info_tip("<strong>Exon &amp; Intron Comparison</strong><br/>Left panel: exon vs intron count. Right panel: exonic vs intronic base pairs.<div class='ci-axes'><b>Left Y-axis:</b> Count<br/><b>Right Y-axis:</b> Base pairs (bp)</div><div class='ci-tip'>Compare structural complexity &mdash; more introns often indicate regulatory complexity.</div>"),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("ortho_exon_chart", height = "auto", width = "100%"),
                          color = "#18BC9C", type = 6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("microscope"), " Sequence"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("ortho_seq_chart", "ortho_sequence_composition.svg", "ortho_seq_order", choices = analytics_seq_order_choices),
                        chart_info_tip("<strong>Nucleotide Composition</strong><br/>Percentage of each nucleotide (A, T, C, G) per gene. GC% annotated on the right.<div class='ci-axes'><b>Y-axis:</b> Organism<br/><b>X-axis:</b> Percentage (0&ndash;50%)</div><div class='ci-tip'>Higher GC% may indicate thermal stability or coding density.</div>"),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("ortho_seq_chart", height = "auto", width = "100%"),
                          color = "#18BC9C", type = 6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("map-marker-alt"), " Genomic Context"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("ortho_context_chart", "ortho_genomic_context.svg", "ortho_context_order", choices = analytics_context_order_choices),
                        chart_info_tip("<strong>Genomic Context</strong><br/>Distance to the nearest neighboring gene in separate panels (Upstream and Downstream).<div class='ci-axes'><b>Y-axis:</b> Organism<br/><b>X-axis:</b> Signed edge-to-edge distance (bp)</div><div class='ci-tip'>Negative = overlap; zero/positive = gap. The panel defines the biological side (not the sign).</div>"),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("ortho_context_chart", height = "auto", width = "100%"),
                          color = "#18BC9C", type = 6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("ruler-horizontal"), " Exon Lengths"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("ortho_exon_dist_chart", "ortho_exon_lengths.svg", "ortho_exon_dist_order", choices = analytics_exon_dist_order_choices),
                        chart_info_tip("<strong>Exon Length Distribution</strong><br/>Violin + box + jitter showing individual exon lengths per gene on a log&#8321;&#8320; scale.<div class='ci-axes'><b>Y-axis:</b> Organism<br/><b>X-axis:</b> Exon length in bp (log&#8321;&#8320;)</div><div class='ci-tip'>Box = IQR (25th&ndash;75th percentile). Line = median. Dots = individual exons.</div>"),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("ortho_exon_dist_chart",
                            height = "auto", width = "100%"
                          ),
                          type = 4, color = "#2C3E50", size = 0.6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("circle-dot"), " Scatter"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("ortho_scatter_chart", "ortho_scatter.svg", "ortho_scatter_order", choices = analytics_scatter_order_choices),
                        chart_info_tip(analytics_scatter_tip_html),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("ortho_scatter_chart",
                            height = "auto", width = "100%"
                          ),
                          type = 4, color = "#2C3E50", size = 0.6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("table-cells"), " Heatmap"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("ortho_heatmap_chart", "ortho_heatmap.svg", "ortho_heatmap_order", choices = analytics_heatmap_order_choices),
                        chart_info_tip(analytics_heatmap_tip_html),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("ortho_heatmap_chart",
                            height = "auto", width = "100%"
                          ),
                          type = 4, color = "#2C3E50", size = 0.6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("chart-pie"), " Radar"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar("ortho_radar_chart", "ortho_radar.svg", "ortho_radar_order", choices = analytics_radar_order_choices),
                        chart_info_tip(analytics_radar_tip_html),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("ortho_radar_chart",
                            height = "auto", width = "100%"
                          ),
                          type = 4, color = "#2C3E50", size = 0.6
                        )
                      )
                    ),
                    tabPanel(
                      title = tagList(icon("grip-lines"), " Correlations"),
                      div(
                        class = "analytics-chart-wrap",
                        analytics_chart_toolbar(
                          "ortho_corr_chart", "ortho_correlations.svg", "ortho_corr_order",
                          choices = analytics_corr_order_choices
                        ),
                        chart_info_tip(analytics_corr_tip_html),
                        shinycssloaders::withSpinner(
                          ggiraph::girafeOutput("ortho_corr_chart",
                            height = "auto", width = "100%"
                          ),
                          type = 4, color = "#2C3E50", size = 0.6
                        )
                      )
                    )
                  )
                )
              )
            ),
            # ──────────────────────────────────────────────────────
            div(
              class = "plots-zoom-wrap",
              div(
                id = "ortho-plot-container",
                style = "position: relative;",
                uiOutput("ortho_special_cards_ui"),
                div(
                  id = "ortho-multipip-card-shell",
                  style = "display:none;",
                  div(
                    class = "card mb-3",
                    style = "width: 100%; display:flex; flex-direction:column; box-shadow: 0 4px 12px rgba(0,0,0,0.12); border-radius: 10px; overflow:hidden;",
                    div(
                      class = "card-header",
                      style = "background: linear-gradient(135deg, #1E3A52, #2A5469); color: white; padding: 12px 18px; font-weight: bold; display:flex; align-items:center; justify-content:space-between;",
                      div(
                        style = "display:flex; align-items:center; gap:10px;",
                        tags$i(class = "fa fa-stream", style = "font-size:16px;"),
                        span("MultiPIP-style View"),
                        span(
                          style = "font-size:11px; font-weight:700; padding:2px 8px; border-radius:999px; background:rgba(255,255,255,0.18); border:1px solid rgba(255,255,255,0.25);",
                          "beta"
                        )
                      ),
                      div(
                        style = "display:flex; align-items:center; gap:8px;",
                        tags$button(
                          class = "btn btn-sm btn-export-svg",
                          title = "Export plot as SVG",
                          onclick = "exportSVG('ortho_multipip_plot_out', 'multipip_style_view.svg')",
                          style = "background:rgba(255,255,255,0.15); border:1px solid rgba(255,255,255,0.3); color:white; border-radius:6px; padding:4px 10px; font-size:12px;",
                          HTML("&#x2913; SVG")
                        ),
                        downloadButton("download_multipip_seq", "Download sequences",
                          class = "btn-download",
                          style = "background:rgba(255,255,255,0.15); border:1px solid rgba(255,255,255,0.3); color:white; border-radius:6px; padding:4px 10px; font-size:12px;"
                        )
                      )
                    ),
                    div(
                      class = "ortho-aligned-toolbar ortho-pip-toolbar ortho-multipip-toolbar",
                      style = "padding: 10px 16px 12px 16px; border-bottom: 1px solid #DDEAF0;",
                      div(
                        class = "ortho-aligned-toolbar-row ortho-pip-toolbar-row--primary",
                        uiOutput("ortho_multipip_reference_ui"),
                        div(
                          class = "ortho-aligned-control ortho-aligned-control--select",
                          tags$label("Alignment window:", `for` = "ortho_multipip_span", class = "ortho-aligned-control-label"),
                          shiny::selectInput(
                            inputId = "ortho_multipip_span",
                            label = NULL,
                            choices = c(
                              "Gene body only" = "gene",
                              "Gene ± 5 kb flanks" = "5kb",
                              "Gene ± 10 kb flanks" = "10kb",
                              "Gene ± 25 kb flanks" = "25kb",
                              "Gene ± 50 kb flanks" = "50kb"
                            ),
                            selected = "gene",
                            width = "100%"
                          )
                        ),
                        div(
                          class = "ortho-aligned-control ortho-aligned-control--select",
                          tags$label("Track order:", `for` = "ortho_multipip_track_order", class = "ortho-aligned-control-label"),
                          shiny::selectInput(
                            inputId = "ortho_multipip_track_order",
                            label = NULL,
                            choices = c(
                              "Loaded order" = "load",
                              "Organism A-Z" = "organism",
                              "Similarity to reference (planned)" = "similarity"
                            ),
                            selected = "load",
                            width = "100%"
                          )
                        ),
                        div(
                          class = "ortho-aligned-control ortho-aligned-control--select",
                          tags$label("Min. segment length:", `for` = "ortho_multipip_min_segment_bp", class = "ortho-aligned-control-label"),
                          shiny::selectInput(
                            inputId = "ortho_multipip_min_segment_bp",
                            label = NULL,
                            choices = c(
                              "10 bp" = "10",
                              "25 bp (recommended)" = "25",
                              "50 bp" = "50",
                              "100 bp" = "100"
                            ),
                            selected = "25",
                            width = "100%"
                          )
                        )
                      ),
                      div(
                        class = "ortho-pip-toolbar-info-row",
                        div(
                          class = "ortho-pip-toolbar-note-row ortho-pip-toolbar-note-row--panel",
                          uiOutput("ortho_multipip_reference_note_ui")
                        ),
                        div(
                          class = "ortho-pip-toolbar-help-card",
                          div(class = "ortho-aligned-mode-hint", uiOutput("ortho_multipip_help"))
                        )
                      ),
                      div(
                        class = "ortho-pip-toolbar-control-row",
                        div(
                          class = "ortho-aligned-control ortho-aligned-control--slider",
                          tags$label("Min. local identity:", `for` = "ortho_multipip_min_identity", class = "ortho-aligned-control-label"),
                          shiny::sliderInput(
                            inputId = "ortho_multipip_min_identity",
                            label = NULL,
                            min = 50, max = 100, value = 70, step = 5,
                            post = "%", width = "100%", ticks = FALSE
                          )
                        ),
                        div(
                          class = "ortho-pip-toolbar-actions-row ortho-pip-toolbar-actions-row--stacked",
                          div(
                            class = "ortho-pip-toolbar-actions-col",
                            div(class = "ortho-pip-toolbar-actions-label", "Local backend:"),
                            div(
                              class = "ortho-pip-toolbar-actions-buttons",
                              actionButton(
                                inputId = "ortho_multipip_run_alignments",
                                label = "Run local alignments",
                                icon = icon("play"),
                                class = "btn btn-sm btn-success",
                                style = "width:100%; height:38px; border-radius:10px; font-weight:700;"
                              ),
                              actionButton(
                                inputId = "ortho_multipip_suggest_reference",
                                label = "Suggest best reference",
                                icon = icon("compass"),
                                class = "btn btn-sm btn-outline-primary",
                                style = "width:100%; height:38px; border-radius:10px; font-weight:700;"
                              )
                            )
                          )
                        )
                      )
                    ),
                    div(
                      style = "padding: 0 16px 8px 16px; border-bottom: 1px solid #DDEAF0;",
                      uiOutput("ortho_multipip_interpretation_help")
                    ),
                    div(
                      class = "card-body",
                      style = "background-color: #FAFBFC; overflow-x: auto; padding: 10px 15px;",
                      ggiraph::girafeOutput("ortho_multipip_plot_out", width = "100%", height = "auto")
                    ),
                    div(
                      class = "card-footer",
                      style = "background-color: #F2F4F6; padding: 10px 18px; border-top: 1px solid #DDE2E8; font-size: 12px; color: #4B6072;",
                      uiOutput("ortho_multipip_legend"),
                      uiOutput("ortho_multipip_footer")
                    )
                  )
                ),
                div(id = "ortho-plot-cards-container"),
                uiOutput("orthologous_plots_ui")
              )
            )
          )
        ),
        tabPanel(
          title = "Settings",
          value = "settings",
          div(
            class = "content-wrapper app-main-pane app-settings-pane",
            div(
              class = "help-content settings-content",
              h2(icon("cog"), span("Settings")),
              div(
                class = "help-section",
                h3(icon("paint-brush"), span("Appearance")),
                # ── Fila: Modo Día / Noche ──────────────────────────────
                div(
                  class = "settings-row",
                  div(
                    class = "settings-row-info",
                    tags$span(
                      class = "settings-row-title",
                      icon("sun"), "Day / Night Mode"
                    ),
                    tags$span(
                      class = "settings-row-desc",
                      "Switch between the light and dark theme."
                    )
                  ),
                  HTML('
                  <label class="switch" id="theme-toggle-btn" style="margin-bottom: 0; flex-shrink: 0;">
                    <span class="sun"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="#ffd43b"><circle r="5" cy="12" cx="12"></circle><path d="m21 13h-1a1 1 0 0 1 0-2h1a1 1 0 0 1 0 2zm-17 0h-1a1 1 0 0 1 0-2h1a1 1 0 0 1 0 2zm13.66-5.66a1 1 0 0 1 -.66-.29 1 1 0 0 1 0-1.41l.71-.71a1 1 0 1 1 1.41 1.41l-.71.71a1 1 0 0 1 -.75.29zm-12.02 12.02a1 1 0 0 1 -.71-.29 1 1 0 0 1 0-1.41l.71-.66a1 1 0 0 1 1.41 1.41l-.71.71a1 1 0 0 1 -.7.24zm6.36-14.36a1 1 0 0 1 -1-1v-1a1 1 0 0 1 2 0v1a1 1 0 0 1 -1 1zm0 17a1 1 0 0 1 -1-1v-1a1 1 0 0 1 2 0v1a1 1 0 0 1 -1 1zm-5.66-14.66a1 1 0 0 1 -.7-.29l-.71-.71a1 1 0 0 1 1.41-1.41l.71.71a1 1 0 0 1 0 1.41 1 1 0 0 1 -.71.29zm12.02 12.02a1 1 0 0 1 -.7-.29l-.66-.71a1 1 0 0 1 1.36-1.36l.71.71a1 1 0 0 1 0 1.41 1 1 0 0 1 -.71.24z"></path></g></svg></span>
                    <span class="moon"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 384 512"><path d="m223.5 32c-123.5 0-223.5 100.3-223.5 224s100 224 223.5 224c60.6 0 115.5-24.2 155.8-63.4 5-4.9 6.3-12.5 3.1-18.7s-10.1-9.7-17-8.5c-9.8 1.7-19.8 2.6-30.1 2.6-96.9 0-175.5-78.8-175.5-176 0-65.8 36-123.1 89.3-153.3 6.1-3.5 9.2-10.5 7.7-17.3s-7.3-11.9-14.3-12.5c-6.3-.5-12.6-.8-19-.8z"></path></svg></span>
                    <input type="checkbox" class="input" id="theme-toggle-input">
                    <span class="slider"></span>
                  </label>
                  ')
                ),
                # ── Fila: Colorblind Palette ────────────────────────────
                div(
                  class = "settings-row",
                  div(
                    class = "settings-row-info",
                    tags$span(
                      class = "settings-row-title",
                      icon("eye"), "Colorblind Palette"
                    ),
                    tags$span(
                      class = "settings-row-desc",
                      "Enables an accessible color scheme for color vision deficiency."
                    )
                  ),
                  shinyWidgets::materialSwitch(
                    inputId = "colorblind_mode",
                    label = NULL,
                    value = FALSE,
                    status = "primary"
                  )
                )
              ),
              div(
                class = "help-section",
                h3(icon("sliders"), span("Interface")),
                # ── Fila: Confirm before delete ─────────────────────────
                div(
                  class = "settings-row",
                  div(
                    class = "settings-row-info",
                    tags$span(
                      class = "settings-row-title",
                      icon("trash-can"), "Confirm before deleting"
                    ),
                    tags$span(
                      class = "settings-row-desc",
                      "Show a confirmation dialog before removing plots or sessions."
                    )
                  ),
                  shinyWidgets::materialSwitch(
                    inputId = "confirm_delete_actions",
                    label = NULL,
                    value = TRUE,
                    status = "primary"
                  )
                )
              ),
              div(
                class = "help-section",
                h3(icon("database"), span("External alias lookup")),
                p("Choose which external databases are used when a gene is not found in the local annotation."),
                div(
                  class = "db-source-grid",
                  div(
                    class = "db-source-item db-source-item-mygene",
                    tags$input(
                      id = "ext_alias_source_mygene",
                      type = "checkbox",
                      class = "db-source-input",
                      checked = "checked"
                    ),
                    tags$label(
                      `for` = "ext_alias_source_mygene",
                      class = "db-source-card",
                      div(
                        class = "db-source-card-icon-wrap",
                        tags$img(
                          src = "icons/databases/mygene.ico",
                          alt = "MyGene",
                          class = "db-source-card-icon",
                          onerror = "this.onerror=null;this.src='icons/DNA.ico';"
                        )
                      ),
                      div(
                        class = "db-source-card-text",
                        span(class = "db-source-card-title", "MyGene")
                      ),
                      span(class = "db-source-card-indicator"),
                      span(class = "db-source-card-bar")
                    )
                  ),
                  div(
                    class = "db-source-item db-source-item-ncbi",
                    tags$input(
                      id = "ext_alias_source_ncbi",
                      type = "checkbox",
                      class = "db-source-input",
                      checked = "checked"
                    ),
                    tags$label(
                      `for` = "ext_alias_source_ncbi",
                      class = "db-source-card",
                      div(
                        class = "db-source-card-icon-wrap",
                        tags$img(
                          src = "icons/databases/ncbi.ico",
                          alt = "NCBI Gene",
                          class = "db-source-card-icon",
                          onerror = "this.onerror=null;this.src='icons/DNA.ico';"
                        )
                      ),
                      div(
                        class = "db-source-card-text",
                        span(class = "db-source-card-title", "NCBI Gene")
                      ),
                      span(class = "db-source-card-indicator"),
                      span(class = "db-source-card-bar")
                    )
                  ),
                  div(
                    class = "db-source-item db-source-item-uniprot",
                    tags$input(
                      id = "ext_alias_source_uniprot",
                      type = "checkbox",
                      class = "db-source-input",
                      checked = "checked"
                    ),
                    tags$label(
                      `for` = "ext_alias_source_uniprot",
                      class = "db-source-card",
                      div(
                        class = "db-source-card-icon-wrap",
                        tags$img(
                          src = "icons/databases/uniprot.ico",
                          alt = "UniProt",
                          class = "db-source-card-icon",
                          onerror = "this.onerror=null;this.src='icons/DNA.ico';"
                        )
                      ),
                      div(
                        class = "db-source-card-text",
                        span(class = "db-source-card-title", "UniProt")
                      ),
                      span(class = "db-source-card-indicator"),
                      span(class = "db-source-card-bar")
                    )
                  ),
                  div(
                    class = "db-source-item db-source-item-ensembl",
                    tags$input(
                      id = "ext_alias_source_ensembl",
                      type = "checkbox",
                      class = "db-source-input",
                      checked = "checked"
                    ),
                    tags$label(
                      `for` = "ext_alias_source_ensembl",
                      class = "db-source-card",
                      div(
                        class = "db-source-card-icon-wrap",
                        tags$img(
                          src = "icons/databases/ensembl.ico",
                          alt = "Ensembl",
                          class = "db-source-card-icon",
                          onerror = "this.onerror=null;this.src='icons/DNA.ico';"
                        )
                      ),
                      div(
                        class = "db-source-card-text",
                        span(class = "db-source-card-title", "Ensembl")
                      ),
                      span(class = "db-source-card-indicator"),
                      span(class = "db-source-card-bar")
                    )
                  )
                )
              ),
              div(
                class = "help-section",
                h3(icon("save"), span("Work sessions")),
                p("Download your current work session (plots and settings) as an .rds file, or upload a previously saved session file to restore it."),
                div(
                  class = "settings-session-controls settings-session-import",
                  downloadButton("download_work_session", span("Export current session (.rds)"), class = "btn-sm btn-download"),
                  hr(style = "margin: 14px 0 10px 0;border-top:1px dashed #ccc;"),
                  fileInput(
                    inputId = "upload_work_session",
                    label = "Restore from session file (.rds)",
                    accept = c(".rds")
                  ),
                  actionButton(
                    inputId = "load_work_session_btn",
                    label = span("Restore session"),
                    icon = icon("folder-open"),
                    class = "btn btn-sm btn-download settings-session-btn"
                  )
                ),
                p(class = "app-submenu-hint", "Loading a session replaces current visualizations.")
              )
            )
          )
        ),
        tabPanel(
          title = "Help",
          value = "help",
          div(
            class = "content-wrapper app-main-pane app-help-pane",
            div(
              class = "help-content",
              tags$style(HTML("
              .help-content {
                display: flex;
                flex-direction: column;
                gap: 22px;
                padding: 0;
                background: transparent !important;
                border: none !important;
                outline: none !important;
                border-radius: 0;
                box-shadow: none !important;
              }
              .help-section {
                padding: 18px 20px;
                background: linear-gradient(180deg, #fbfdff 0%, #f5f9fc 100%);
                border: 1px solid #dbe6ef;
                border-radius: 16px;
                box-shadow: 0 10px 24px rgba(32, 58, 82, 0.07);
              }
              .help-section h3 {
                color: #1f3246;
                margin: 0 0 8px 0;
                font-size: 18px;
                font-weight: 800;
                line-height: 1.2;
                display: flex;
                align-items: center;
                gap: 9px;
              }
              .help-section p,
              .help-section li {
                color: #566c7f;
                font-size: 12.5px;
                line-height: 1.6;
              }
              .help-section > p {
                max-width: 860px;
                margin: 0 0 14px 0;
              }
              .help-section ul,
              .help-section ol {
                margin: 0;
                padding-left: 20px;
              }
              .settings-content {
                font-size: 13px;
              }
              .settings-content h2 {
                margin-top: 0;
                margin-bottom: 14px;
                font-size: 22px;
                font-weight: 700;
                line-height: 1.2;
                color: #2C3E50;
              }
              .settings-content .help-section {
                margin-bottom: 16px;
                padding: 14px 16px;
                border-radius: 8px;
                box-shadow: none;
              }
              .settings-content .help-section h3 {
                margin: 0 0 8px 0;
                font-size: 16px;
                font-weight: 600;
                line-height: 1.25;
              }
              .settings-content .help-section p,
              .settings-content .help-section li {
                font-size: 13px;
                line-height: 1.42;
              }
              .settings-content .help-section ul,
              .settings-content .help-section ol {
                margin-bottom: 6px;
              }
              .settings-content .control-label {
                font-size: 12.5px;
                margin-bottom: 4px;
                font-weight: 600;
              }
              .settings-content .form-control,
              .settings-content .selectize-input {
                font-size: 12.5px;
              }
              .settings-content .btn,
              .settings-content .btn-sm {
                font-size: 12px;
              }
              .settings-content .app-submenu-hint {
                font-size: 11.5px;
                line-height: 1.35;
              }
              .db-source-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(168px, 1fr));
                gap: 10px;
                margin-top: 8px;
              }
              .db-source-item {
                --db-accent: #18bc9c;
                --db-accent-soft: rgba(24, 188, 156, 0.2);
                position: relative;
              }
              .db-source-item-mygene,
              .db-source-item-ncbi,
              .db-source-item-uniprot,
              .db-source-item-ensembl {
                --db-accent: #18bc9c;
                --db-accent-soft: rgba(24, 188, 156, 0.3);
              }
              .db-source-input {
                position: absolute;
                opacity: 0;
                pointer-events: none;
              }
              .db-source-card {
                position: relative;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                gap: 10px;
                min-height: 150px;
                border-radius: 18px;
                border: 1px solid #cfd8e1;
                background: linear-gradient(162deg, #f9fbfd 0%, #edf2f6 56%, #e7edf3 100%);
                padding: 12px 12px 10px;
                box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.78), 0 10px 18px rgba(22, 43, 65, 0.11);
                transition: box-shadow 0.12s ease, border-color 0.12s ease, background 0.12s ease;
                cursor: pointer;
                margin-bottom: 0;
                overflow: hidden;
              }
              .db-source-card::before {
                content: \"\";
                position: absolute;
                inset: 0;
                border-radius: inherit;
                background: linear-gradient(180deg, rgba(255, 255, 255, 0.34) 0%, rgba(255, 255, 255, 0) 55%);
                pointer-events: none;
              }
              .db-source-card:hover {
                border-color: #bcc8d4;
                box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.82), 0 11px 18px rgba(22, 43, 65, 0.12);
              }
              .db-source-input:focus-visible + .db-source-card {
                outline: 2px solid var(--db-accent);
                outline-offset: 2px;
              }
              .db-source-card-icon-wrap {
                width: 60px;
                height: 60px;
                border-radius: 14px;
                border: 1px solid #c6d0da;
                background: linear-gradient(165deg, #e5ecf2 0%, #d8e2ea 100%);
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 8px;
                transition: border-color 0.12s ease, background 0.12s ease;
              }
              .db-source-card-icon {
                width: 100%;
                height: 100%;
                object-fit: contain;
                display: block;
                filter: grayscale(1) saturate(0.1) opacity(0.72);
                transition: filter 0.12s ease;
              }
              .db-source-card-text {
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                line-height: 1.25;
                text-align: center;
              }
              .db-source-card-title {
                font-size: clamp(17px, 1.1vw, 21px);
                font-weight: 800;
                color: #667585;
                letter-spacing: 0.01em;
                line-height: 1.06;
              }
              .db-source-card-indicator {
                position: absolute;
                top: 9px;
                right: 9px;
                width: 8px;
                height: 8px;
                border-radius: 999px;
                background: #9eacb8;
                transition: background 0.12s ease, box-shadow 0.12s ease;
              }
              .db-source-card-bar {
                margin-top: 1px;
                width: 54%;
                height: 4px;
                border-radius: 999px;
                background: #cad3dc;
                transition: width 0.12s ease, background 0.12s ease, box-shadow 0.12s ease;
              }
              .db-source-input:checked + .db-source-card {
                border-color: var(--db-accent);
                background: linear-gradient(162deg, rgba(24, 188, 156, 0.24) 0%, rgba(24, 188, 156, 0.14) 58%, #e8f6f2 100%);
                box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.82), 0 11px 18px rgba(8, 66, 57, 0.18);
              }
              .db-source-input:checked + .db-source-card .db-source-card-icon-wrap {
                border-color: var(--db-accent);
                background: linear-gradient(165deg, rgba(24, 188, 156, 0.28) 0%, rgba(24, 188, 156, 0.16) 100%);
              }
              .db-source-input:checked + .db-source-card .db-source-card-icon {
                filter: none;
              }
              .db-source-input:checked + .db-source-card .db-source-card-title {
                color: var(--db-accent);
              }
              .db-source-input:checked + .db-source-card .db-source-card-indicator,
              .db-source-input:checked + .db-source-card .db-source-card-bar {
                background: var(--db-accent);
              }
              .db-source-input:checked + .db-source-card .db-source-card-bar {
                width: 100%;
                box-shadow: 0 0 0 1px rgba(24, 188, 156, 0.16);
              }
              .settings-session-controls {
                display: flex;
                flex-direction: column;
                gap: 10px;
                max-width: 440px;
              }
              .settings-session-controls #download_work_session,
              .settings-session-controls #load_work_session_btn {
                width: 100%;
                min-height: 40px;
                display: inline-flex;
                align-items: center;
                justify-content: center;
                gap: 8px;
                border-radius: 8px;
                font-size: 12px;
                font-weight: 700;
                padding: 6px 14px;
                background-color: #18BC9C !important;
                border: 1px solid #18BC9C !important;
                color: #FFFFFF !important;
                box-shadow: none !important;
                transform: none !important;
                transition: background-color 0.12s ease, border-color 0.12s ease, color 0.12s ease;
              }
              .settings-session-controls #download_work_session:hover,
              .settings-session-controls #download_work_session:focus,
              .settings-session-controls #load_work_session_btn:hover,
              .settings-session-controls #load_work_session_btn:focus {
                background-color: #128F76 !important;
                border-color: #128F76 !important;
                color: #FFFFFF !important;
                box-shadow: none !important;
                transform: none !important;
              }
              .settings-session-controls .form-group {
                margin-bottom: 0;
              }
              .settings-session-actions {
                display: flex;
                gap: 8px;
                flex-wrap: wrap;
                align-items: center;
              }
              .settings-session-actions .btn {
                min-width: 170px;
              }
              .settings-session-manager .selectize-control {
                margin-bottom: 0;
              }
              .help-icon {
                font-size: 20px;
                color: #18BC9C;
                display: inline-flex;
                align-items: center;
                justify-content: center;
                width: 1.05em;
                line-height: 1;
                vertical-align: middle;
              }
              .help-hero {
                background: linear-gradient(180deg, #f6fbf9 0%, #eef6f4 100%);
                border-color: #d2e5df;
              }
              .help-hero-head {
                display: flex;
                align-items: flex-start;
                gap: 14px;
                margin-bottom: 12px;
              }
              .help-hero-logo {
                width: 52px;
                height: 52px;
                border-radius: 14px;
                border: 1px solid #c8ddd7;
                background: #ffffff;
                object-fit: contain;
                padding: 7px;
                box-shadow: 0 8px 18px rgba(17, 64, 56, 0.1);
                flex-shrink: 0;
              }
              .help-hero-title {
                margin: 0;
                color: #1f3246;
                font-size: 22px;
                font-weight: 800;
                line-height: 1.15;
              }
              .help-hero-subtitle {
                margin: 4px 0 0 0;
                color: #566c7f;
                font-size: 13px;
                line-height: 1.6;
                max-width: 780px;
              }
              .help-pill-row {
                display: flex;
                flex-wrap: wrap;
                gap: 8px;
              }
              .help-pill {
                display: inline-flex;
                align-items: center;
                gap: 6px;
                padding: 5px 11px;
                border-radius: 999px;
                border: 1px solid #cddbe7;
                background: #eef5fb;
                color: #244865;
                font-size: 11px;
                font-weight: 700;
              }
              .help-process-grid,
              .help-mode-grid,
              .help-split-grid {
                display: grid;
                gap: 12px;
                margin-top: 12px;
              }
              .help-process-grid {
                grid-template-columns: repeat(auto-fit, minmax(185px, 1fr));
              }
              .help-mode-grid {
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
              }
              .help-split-grid {
                grid-template-columns: repeat(auto-fit, minmax(235px, 1fr));
              }
              .help-process-card,
              .help-mode-card,
              .help-mini-card,
              .help-db-logo-item {
                border: 1px solid #d8e3ec;
                border-radius: 14px;
                background: #ffffff;
              }
              .help-process-card,
              .help-mode-card,
              .help-mini-card {
                padding: 14px;
              }
              .help-process-step {
                font-size: 11px;
                font-weight: 800;
                color: #688095;
                text-transform: uppercase;
                letter-spacing: 0.05em;
                margin-bottom: 6px;
              }
              .help-process-title,
              .help-mode-card h4,
              .help-mini-card h4 {
                margin: 0 0 8px 0;
                color: #22364a;
                font-size: 14px;
                font-weight: 700;
                display: flex;
                align-items: center;
                gap: 7px;
              }
              .help-process-desc,
              .help-mode-card p,
              .help-mini-card p {
                margin: 0;
                color: #566c7f;
                font-size: 12.5px;
                line-height: 1.6;
              }
              .help-mode-card ul,
              .help-mini-card ul {
                margin-top: 10px;
                padding-left: 18px;
              }
              .help-mode-card li,
              .help-mini-card li {
                margin-bottom: 4px;
              }
              .help-kbd {
                display: inline-block;
                padding: 1px 6px;
                border-radius: 6px;
                border: 1px solid #c8d5e2;
                background: #f4f8fc;
                color: #28435a;
                font-size: 11px;
                font-weight: 700;
              }
              .help-flow-list {
                margin-top: 14px !important;
              }
              .help-flow-list li {
                margin-bottom: 6px;
              }
              .help-db-logo-row {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
                gap: 8px;
                margin-top: 10px;
              }
              .help-db-logo-item {
                padding: 9px 10px;
                display: flex;
                align-items: center;
                gap: 8px;
              }
              .help-db-logo-item img {
                width: 28px;
                height: 28px;
                object-fit: contain;
                border-radius: 8px;
                border: 1px solid #d3dee8;
                background: #f7fafc;
                padding: 3px;
                flex-shrink: 0;
              }
              .help-db-logo-item span {
                font-size: 12px;
                font-weight: 700;
                color: #2a445b;
              }
              .help-faq-list {
                display: flex;
                flex-direction: column;
                gap: 8px;
                margin-top: 4px;
              }
              .help-faq-item {
                background: #ffffff;
                border: 1px solid #d9e4ed;
                border-radius: 14px;
                overflow: hidden;
              }
              .help-faq-item[open] {
                border-color: #18BC9C66;
                box-shadow: 0 10px 22px rgba(24, 188, 156, 0.09);
              }
              .help-faq-question {
                cursor: pointer;
                padding: 13px 16px;
                font-size: 13px;
                font-weight: 700;
                color: #22364a;
                display: flex;
                align-items: center;
                gap: 8px;
                list-style: none;
                user-select: none;
              }
              .help-faq-question::before {
                display: none;
              }
              .help-faq-answer {
                padding: 0 16px 14px 40px;
              }
              .help-faq-answer p,
              .help-faq-answer li {
                font-size: 12.5px;
                line-height: 1.6;
              }
              .help-faq-answer p {
                margin: 0 0 6px 0;
              }
              .help-faq-answer ul {
                margin-top: 6px;
                padding-left: 18px;
              }
              .help-faq-answer code {
                background: #eef4fb;
                border: 1px solid #cdd9e5;
                border-radius: 4px;
                padding: 1px 5px;
                font-size: 11px;
                font-family: 'Courier New', monospace;
                color: #2a445b;
              }
              html[data-app-theme=\"dark\"] .db-source-card {
                border-color: #405365;
                background: linear-gradient(162deg, #1d2c3a 0%, #182634 56%, #152230 100%);
                box-shadow: inset 0 1px 0 rgba(211, 229, 246, 0.06), 0 12px 24px rgba(0, 0, 0, 0.3);
              }
              html[data-app-theme=\"dark\"] .db-source-card:hover {
                border-color: #5a6f84;
              }
              html[data-app-theme=\"dark\"] .db-source-card-icon-wrap {
                border-color: #596e82;
                background: linear-gradient(165deg, #2e4051 0%, #253646 100%);
              }
              html[data-app-theme=\"dark\"] .db-source-card-title {
                color: #99acbf;
              }
              html[data-app-theme=\"dark\"] .db-source-card-indicator {
                background: #8294a6;
              }
              html[data-app-theme=\"dark\"] .db-source-card-bar {
                background: #73879b;
              }
              html[data-app-theme=\"dark\"] .db-source-input:checked + .db-source-card {
                background: linear-gradient(162deg, rgba(24, 108, 92, 0.72) 0%, rgba(20, 82, 72, 0.84) 58%, #13352f 100%);
              }
              html[data-app-theme=\"dark\"] .help-section {
                background: linear-gradient(180deg, #132a3f 0%, #172f45 100%);
                border-color: #274b66;
                box-shadow: 0 12px 26px rgba(0, 0, 0, 0.24);
              }
              html[data-app-theme=\"dark\"] .help-section h3,
              html[data-app-theme=\"dark\"] .help-hero-title,
              html[data-app-theme=\"dark\"] .help-process-title,
              html[data-app-theme=\"dark\"] .help-mode-card h4,
              html[data-app-theme=\"dark\"] .help-mini-card h4,
              html[data-app-theme=\"dark\"] .help-faq-question {
                color: #d5e7f7;
              }
              html[data-app-theme=\"dark\"] .help-section p,
              html[data-app-theme=\"dark\"] .help-section li,
              html[data-app-theme=\"dark\"] .help-hero-subtitle,
              html[data-app-theme=\"dark\"] .help-process-desc,
              html[data-app-theme=\"dark\"] .help-mode-card p,
              html[data-app-theme=\"dark\"] .help-mini-card p,
              html[data-app-theme=\"dark\"] .help-faq-answer p,
              html[data-app-theme=\"dark\"] .help-faq-answer li {
                color: #9ebdd2;
              }
              html[data-app-theme=\"dark\"] .help-hero {
                background: linear-gradient(180deg, #11322a 0%, #122d26 100%);
                border-color: #2d6758;
              }
              html[data-app-theme=\"dark\"] .help-hero-logo {
                border-color: #3d6d62;
                background: #0f2b23;
              }
              html[data-app-theme=\"dark\"] .help-pill {
                border-color: #3b617d;
                background: #183149;
                color: #d3e6f7;
              }
              html[data-app-theme=\"dark\"] .help-process-card,
              html[data-app-theme=\"dark\"] .help-mode-card,
              html[data-app-theme=\"dark\"] .help-mini-card,
              html[data-app-theme=\"dark\"] .help-db-logo-item,
              html[data-app-theme=\"dark\"] .help-faq-item {
                border-color: #2a4e69;
                background: #10263a;
              }
              html[data-app-theme=\"dark\"] .help-process-step {
                color: #9ab2c8;
              }
              html[data-app-theme=\"dark\"] .help-kbd {
                border-color: #406482;
                background: #1a354c;
                color: #d6e8f7;
              }
              html[data-app-theme=\"dark\"] .help-db-logo-item img {
                border-color: #45647f;
                background: #183249;
              }
              html[data-app-theme=\"dark\"] .help-db-logo-item span {
                color: #d2e6f8;
              }
              html[data-app-theme=\"dark\"] .help-faq-item[open] {
                border-color: #18BC9Caa;
              }
              html[data-app-theme=\"dark\"] .help-faq-answer code {
                background: #1b3349;
                border-color: #34516b;
                color: #9dd0e8;
              }
              /* ── Step number badges ──────────────────────────────────── */
              .help-process-card {
                transition: transform 0.22s ease, box-shadow 0.22s ease;
              }
              .help-process-card:hover {
                transform: translateY(-3px);
                box-shadow: 0 12px 28px rgba(24, 188, 156, 0.12);
                border-color: rgba(24, 188, 156, 0.3);
              }
              .help-process-step {
                display: inline-flex;
                align-items: center;
                justify-content: center;
                width: 26px;
                height: 26px;
                border-radius: 8px;
                background: linear-gradient(135deg, #18BC9C, #0fa383);
                color: #ffffff;
                font-size: 12px;
                font-weight: 900;
                margin-bottom: 10px;
                letter-spacing: 0;
                text-transform: none;
              }
              .help-mode-card,
              .help-mini-card {
                transition: transform 0.22s ease, box-shadow 0.22s ease;
              }
              .help-mode-card:hover,
              .help-mini-card:hover {
                transform: translateY(-3px);
                box-shadow: 0 10px 24px rgba(24, 188, 156, 0.1);
                border-color: rgba(24, 188, 156, 0.28);
              }
              /* ── Mode card accent bar ────────────────────────────────── */
              .help-mode-card-icon {
                width: 38px;
                height: 38px;
                border-radius: 11px;
                background: linear-gradient(135deg, #18BC9C, #0fa383);
                color: #ffffff;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 16px;
                margin-bottom: 10px;
              }
              /* ── FAQ accordion (JS-powered) ──────────────────────────── */
              .help-faq-item {
                background: #ffffff;
                border: 1px solid #d9e4ed;
                border-radius: 14px;
                overflow: hidden;
                transition: border-color 0.25s ease, box-shadow 0.25s ease;
              }
              .help-faq-item.is-open {
                border-color: rgba(24, 188, 156, 0.4);
                box-shadow: 0 8px 22px rgba(24, 188, 156, 0.09);
              }
              .help-faq-question {
                width: 100%;
                background: none;
                border: none;
                cursor: pointer;
                padding: 14px 16px;
                font-size: 13px;
                font-weight: 700;
                color: #22364a;
                display: flex;
                align-items: center;
                gap: 10px;
                text-align: left;
                user-select: none;
                transition: background 0.18s ease;
              }
              .help-faq-question:hover {
                background: rgba(24, 188, 156, 0.03);
              }
              .help-faq-icon {
                width: 22px;
                height: 22px;
                border-radius: 7px;
                background: rgba(24, 188, 156, 0.1);
                color: #18BC9C;
                font-size: 14px;
                font-weight: 900;
                display: flex;
                align-items: center;
                justify-content: center;
                flex-shrink: 0;
                transition: transform 0.3s cubic-bezier(0.22, 1, 0.36, 1),
                            background 0.25s ease;
                line-height: 1;
              }
              .help-faq-item.is-open .help-faq-icon {
                transform: rotate(45deg);
                background: rgba(24, 188, 156, 0.18);
              }
              .help-faq-body {
                max-height: 0;
                overflow: hidden;
                transition: max-height 0.38s cubic-bezier(0.22, 1, 0.36, 1);
              }
              .help-faq-item.is-open .help-faq-body {
                max-height: 600px;
              }
              .help-faq-answer {
                padding: 2px 16px 16px 48px;
              }
              .help-faq-answer p,
              .help-faq-answer li {
                font-size: 12.5px;
                line-height: 1.65;
                color: #566c7f;
              }
              .help-faq-answer p { margin: 0 0 6px 0; }
              .help-faq-answer ul { margin-top: 6px; padding-left: 18px; }
              .help-faq-answer code {
                background: #eef4fb;
                border: 1px solid #cdd9e5;
                border-radius: 4px;
                padding: 1px 5px;
                font-size: 11px;
                font-family: 'Courier New', monospace;
                color: #2a445b;
              }
              /* ── Section title accent ────────────────────────────────── */
              .help-section-label {
                display: inline-flex;
                align-items: center;
                gap: 6px;
                font-size: 10.5px;
                font-weight: 800;
                letter-spacing: 0.07em;
                text-transform: uppercase;
                color: #18BC9C;
                background: rgba(24, 188, 156, 0.08);
                border: 1px solid rgba(24, 188, 156, 0.15);
                border-radius: 999px;
                padding: 3px 10px;
                margin-bottom: 8px;
                width: fit-content;
              }
              /* ── Dark theme additions ────────────────────────────────── */
              html[data-app-theme=\"dark\"] .help-faq-item {
                background: #10263a;
                border-color: #2a4e69;
              }
              html[data-app-theme=\"dark\"] .help-faq-item.is-open {
                border-color: rgba(24, 188, 156, 0.5);
              }
              html[data-app-theme=\"dark\"] .help-faq-question {
                color: #d5e7f7;
              }
              html[data-app-theme=\"dark\"] .help-faq-question:hover {
                background: rgba(24, 188, 156, 0.05);
              }
              html[data-app-theme=\"dark\"] .help-faq-icon {
                background: rgba(24, 188, 156, 0.12);
              }
              html[data-app-theme=\"dark\"] .help-faq-answer p,
              html[data-app-theme=\"dark\"] .help-faq-answer li {
                color: #9ebdd2;
              }
              html[data-app-theme=\"dark\"] .help-faq-answer code {
                background: #1b3349;
                border-color: #34516b;
                color: #9dd0e8;
              }
              html[data-app-theme=\"dark\"] .help-section-label {
                background: rgba(24, 188, 156, 0.1);
                border-color: rgba(24, 188, 156, 0.2);
              }
              html[data-app-theme=\"dark\"] .help-mode-card-icon {
                background: linear-gradient(135deg, #1a9e86, #127a67);
              }
              /* ── Hero mini-stats ─────────────────────────────────────── */
              .help-hero-stats {
                display: flex;
                flex-wrap: wrap;
                gap: 10px;
                margin-top: 14px;
              }
              .help-hero-stat {
                display: flex;
                align-items: center;
                gap: 8px;
                padding: 7px 14px;
                border-radius: 12px;
                background: rgba(24, 188, 156, 0.07);
                border: 1px solid rgba(24, 188, 156, 0.15);
                transition: background 0.2s ease, transform 0.2s ease;
              }
              .help-hero-stat:hover {
                background: rgba(24, 188, 156, 0.12);
                transform: translateY(-2px);
              }
              .help-hero-stat-num {
                font-size: 18px;
                font-weight: 900;
                color: #18BC9C;
                line-height: 1;
              }
              .help-hero-stat-label {
                font-size: 11.5px;
                font-weight: 600;
                color: #3a5568;
              }
              html[data-app-theme=\"dark\"] .help-hero-stat {
                background: rgba(24, 188, 156, 0.08);
                border-color: rgba(24, 188, 156, 0.18);
              }
              html[data-app-theme=\"dark\"] .help-hero-stat-label { color: #9ebdd2; }
              /* ── View cards (5 viz modes) ────────────────────────────── */
              .help-views-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 10px;
                margin-top: 12px;
              }
              .help-view-card {
                border: 1px solid #d8e3ec;
                border-radius: 14px;
                background: #ffffff;
                padding: 14px;
                transition: transform 0.22s ease, box-shadow 0.22s ease, border-color 0.22s ease;
                position: relative;
                overflow: hidden;
              }
              .help-view-card::before {
                content: '';
                position: absolute;
                top: 0; left: 0; right: 0;
                height: 3px;
                background: linear-gradient(90deg, #18BC9C, #44B0FF);
                opacity: 0;
                transition: opacity 0.25s ease;
                border-radius: 14px 14px 0 0;
              }
              .help-view-card:hover {
                transform: translateY(-4px);
                box-shadow: 0 14px 32px rgba(24, 188, 156, 0.13);
                border-color: rgba(24, 188, 156, 0.3);
              }
              .help-view-card:hover::before { opacity: 1; }
              .help-view-card-icon {
                width: 36px; height: 36px;
                border-radius: 10px;
                background: linear-gradient(135deg, #18BC9C, #0fa383);
                color: #ffffff;
                display: flex; align-items: center; justify-content: center;
                font-size: 15px;
                margin-bottom: 10px;
                transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
              }
              .help-view-card:hover .help-view-card-icon {
                transform: scale(1.15) rotate(-5deg);
              }
              .help-view-card h4 {
                margin: 0 0 6px 0;
                font-size: 13px;
                font-weight: 800;
                color: #22364a;
              }
              .help-view-card p {
                margin: 0;
                font-size: 11.5px;
                color: #566c7f;
                line-height: 1.55;
              }
              .help-view-badge {
                display: inline-block;
                margin-top: 8px;
                padding: 2px 8px;
                border-radius: 999px;
                font-size: 9.5px;
                font-weight: 800;
                letter-spacing: 0.04em;
                text-transform: uppercase;
              }
              .help-view-badge-both {
                background: rgba(24, 188, 156, 0.1);
                color: #18BC9C;
                border: 1px solid rgba(24, 188, 156, 0.2);
              }
              .help-view-badge-cross {
                background: rgba(68, 176, 255, 0.1);
                color: #2980b9;
                border: 1px solid rgba(68, 176, 255, 0.2);
              }
              html[data-app-theme=\"dark\"] .help-view-card {
                background: #10263a; border-color: #2a4e69;
              }
              html[data-app-theme=\"dark\"] .help-view-card h4 { color: #d5e7f7; }
              html[data-app-theme=\"dark\"] .help-view-card p { color: #9ebdd2; }
              /* ── Popup features grid ─────────────────────────────────── */
              .help-popup-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 10px;
                margin-top: 12px;
              }
              .help-popup-card {
                border: 1px solid #d8e3ec;
                border-radius: 12px;
                background: #ffffff;
                padding: 12px 14px;
                display: flex;
                gap: 10px;
                align-items: flex-start;
                transition: transform 0.2s ease, box-shadow 0.2s ease;
              }
              .help-popup-card:hover {
                transform: translateY(-2px);
                box-shadow: 0 8px 20px rgba(24, 188, 156, 0.09);
                border-color: rgba(24, 188, 156, 0.25);
              }
              .help-popup-card-icon {
                width: 30px; height: 30px; flex-shrink: 0;
                border-radius: 9px;
                background: linear-gradient(135deg, #18BC9C, #0fa383);
                color: #fff;
                display: flex; align-items: center; justify-content: center;
                font-size: 13px;
              }
              .help-popup-card strong {
                display: block;
                font-size: 12.5px;
                color: #22364a;
                margin-bottom: 3px;
              }
              .help-popup-card p {
                margin: 0;
                font-size: 11.5px;
                color: #566c7f;
                line-height: 1.5;
              }
              /* ── Export cards ────────────────────────────────────────── */
              .help-export-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
                gap: 9px;
                margin-top: 12px;
              }
              .help-export-card {
                border: 1px solid #d8e3ec;
                border-radius: 12px;
                background: #ffffff;
                padding: 11px 13px;
                display: flex;
                align-items: center;
                gap: 10px;
                transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;
              }
              .help-export-card:hover {
                transform: translateY(-2px);
                box-shadow: 0 8px 18px rgba(24, 188, 156, 0.1);
                border-color: rgba(24, 188, 156, 0.28);
              }
              .help-export-icon {
                width: 32px; height: 32px; flex-shrink: 0;
                border-radius: 9px;
                background: linear-gradient(135deg, #eff8f5, #e3f4ee);
                color: #18BC9C;
                display: flex; align-items: center; justify-content: center;
                font-size: 14px;
                border: 1px solid rgba(24, 188, 156, 0.15);
                transition: background 0.2s ease, transform 0.2s ease;
              }
              .help-export-card:hover .help-export-icon {
                background: linear-gradient(135deg, #18BC9C, #0fa383);
                color: #ffffff;
                transform: scale(1.1);
              }
              .help-export-card strong {
                font-size: 12.5px;
                color: #22364a;
                display: block;
              }
              .help-export-card small {
                font-size: 11px;
                color: #6a7f91;
              }
              /* ── Alignment mode detail cards ─────────────────────────── */
              .help-align-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
                gap: 10px;
                margin-top: 12px;
              }
              .help-align-card {
                border: 1px solid #d8e3ec;
                border-radius: 13px;
                background: #ffffff;
                padding: 14px;
                transition: all 0.22s ease;
              }
              .help-align-card:hover {
                transform: translateY(-3px);
                border-color: rgba(24, 188, 156, 0.3);
                box-shadow: 0 10px 24px rgba(24, 188, 156, 0.1);
              }
              .help-align-card-head {
                display: flex;
                align-items: center;
                gap: 9px;
                margin-bottom: 7px;
              }
              .help-align-card-icon {
                width: 30px; height: 30px;
                border-radius: 8px;
                background: linear-gradient(135deg, #18BC9C, #0fa383);
                color: #fff;
                display: flex; align-items: center; justify-content: center;
                font-size: 13px;
                flex-shrink: 0;
              }
              .help-align-card strong {
                font-size: 13px;
                font-weight: 800;
                color: #22364a;
              }
              .help-align-card p {
                font-size: 11.5px;
                color: #566c7f;
                line-height: 1.55;
                margin: 0 0 7px 0;
              }
              .help-align-matrix {
                display: inline-flex;
                align-items: center;
                gap: 5px;
                padding: 3px 9px;
                border-radius: 7px;
                background: rgba(24, 188, 156, 0.06);
                border: 1px solid rgba(24, 188, 156, 0.12);
                font-size: 10.5px;
                font-weight: 700;
                color: #18BC9C;
                font-family: 'Courier New', monospace;
              }
              /* ── Chart chips animated ────────────────────────────────── */
              @keyframes helpChipIn {
                from { opacity: 0; transform: scale(0.8) translateY(6px); }
                to   { opacity: 1; transform: scale(1) translateY(0); }
              }
              .help-chart-chips {
                display: flex;
                flex-wrap: wrap;
                gap: 7px;
                margin-top: 12px;
              }
              .help-chart-chip {
                display: inline-flex;
                align-items: center;
                gap: 6px;
                padding: 6px 12px;
                border-radius: 9px;
                background: rgba(24, 188, 156, 0.06);
                border: 1px solid rgba(24, 188, 156, 0.12);
                font-size: 12px;
                font-weight: 600;
                color: #22364a;
                cursor: default;
                transition: all 0.22s ease;
              }
              .help-chart-chip:hover {
                background: rgba(24, 188, 156, 0.12);
                border-color: rgba(24, 188, 156, 0.28);
                transform: translateY(-2px);
                box-shadow: 0 4px 12px rgba(24, 188, 156, 0.12);
              }
              .help-chart-chip .fa,
              .help-chart-chip .fas { color: #18BC9C; font-size: 11px; }
              /* ── Organism kingdom tags ───────────────────────────────── */
              .help-kingdoms-row {
                display: flex;
                flex-wrap: wrap;
                gap: 8px;
                margin-top: 12px;
              }
              .help-kingdom-pill {
                display: flex;
                align-items: center;
                gap: 8px;
                padding: 7px 14px;
                border-radius: 12px;
                font-size: 12px;
                font-weight: 700;
                transition: transform 0.2s ease;
              }
              .help-kingdom-pill:hover { transform: translateY(-2px); }
              .help-kingdom-animals { background: #e8f4fd; color: #2980b9; border: 1px solid #b8d8f0; }
              .help-kingdom-plants  { background: #e8f9f0; color: #0d6e50; border: 1px solid #9ed9be; }
              .help-kingdom-fungi   { background: #fef3e8; color: #b06c2a; border: 1px solid #f0c99e; }
              html[data-app-theme=\"dark\"] .help-kingdom-animals { background: #1a3248; color: #5eb8e8; border-color: #2a4e69; }
              html[data-app-theme=\"dark\"] .help-kingdom-plants  { background: #163326; color: #5ed4a0; border-color: #2a5040; }
              html[data-app-theme=\"dark\"] .help-kingdom-fungi   { background: #2a1d14; color: #e8a65e; border-color: #503322; }
              /* ── Dark for new elements ───────────────────────────────── */
              html[data-app-theme=\"dark\"] .help-popup-card,
              html[data-app-theme=\"dark\"] .help-export-card,
              html[data-app-theme=\"dark\"] .help-align-card,
              html[data-app-theme=\"dark\"] .help-view-card {
                background: #10263a; border-color: #2a4e69;
              }
              html[data-app-theme=\"dark\"] .help-popup-card strong,
              html[data-app-theme=\"dark\"] .help-align-card strong,
              html[data-app-theme=\"dark\"] .help-export-card strong { color: #d5e7f7; }
              html[data-app-theme=\"dark\"] .help-popup-card p,
              html[data-app-theme=\"dark\"] .help-align-card p,
              html[data-app-theme=\"dark\"] .help-export-card small { color: #9ebdd2; }
              html[data-app-theme=\"dark\"] .help-export-icon {
                background: linear-gradient(135deg, #1b3d50, #1c4850);
                border-color: rgba(24, 188, 156, 0.2);
              }
              html[data-app-theme=\"dark\"] .help-chart-chip {
                color: #d5e7f7;
                background: rgba(24, 188, 156, 0.07);
                border-color: rgba(24, 188, 156, 0.15);
              }
              html[data-app-theme=\"dark\"] .help-align-matrix {
                background: rgba(24, 188, 156, 0.09);
                border-color: rgba(24, 188, 156, 0.18);
              }
              @media (max-width: 700px) {
                .db-source-grid {
                  grid-template-columns: repeat(auto-fit, minmax(136px, 1fr));
                  gap: 10px;
                }
                .db-source-card {
                  min-height: 136px;
                  padding: 10px 9px;
                  gap: 8px;
                }
                .db-source-card-title {
                  font-size: 15px;
                }
                .db-source-card-icon-wrap {
                  width: 50px;
                  height: 50px;
                }
                .help-section {
                  padding: 16px;
                }
                .help-section h3 {
                  font-size: 17px;
                }
                .help-hero-head {
                  flex-direction: column;
                }
                .help-hero-logo {
                  width: 46px;
                  height: 46px;
                }
              }
            ")),
              # ── Hero ────────────────────────────────────────────────────────
              div(
                class = "help-section help-hero home-reveal",
                div(
                  class = "help-hero-head",
                  tags$img(
                    src = versioned_asset_path("favicon2.ico?v=2"),
                    class = "help-hero-logo",
                    `data-light-src` = versioned_asset_path("favicon2.ico?v=2"),
                    `data-dark-src` = versioned_asset_path("favicon.ico?v=2"),
                    alt = "CGV logo"
                  ),
                  div(
                    div(class = "help-section-label", icon("book"), "User Guide"),
                    h3(class = "help-hero-title", "CGV User Guide"),
                    p(class = "help-hero-subtitle", "Everything you need to move from query setup to interpretation. Covers search modes, alignment views, analytics, exports, and troubleshooting.")
                  )
                ),
                div(
                  class = "help-hero-stats home-stagger-parent",
                  div(class = "help-hero-stat home-stagger-child",
                    span(class = "help-hero-stat-num", "2"), span(class = "help-hero-stat-label", "Search modes")),
                  div(class = "help-hero-stat home-stagger-child",
                    span(class = "help-hero-stat-num", "5"), span(class = "help-hero-stat-label", "Visualization views")),
                  div(class = "help-hero-stat home-stagger-child",
                    span(class = "help-hero-stat-num", "10"), span(class = "help-hero-stat-label", "Analytics charts")),
                  div(class = "help-hero-stat home-stagger-child",
                    span(class = "help-hero-stat-num", "3"), span(class = "help-hero-stat-label", "Alignment modes")),
                  div(class = "help-hero-stat home-stagger-child",
                    span(class = "help-hero-stat-num", "5+"), span(class = "help-hero-stat-label", "Export formats"))
                )
              ),
              # ── Quick Start ─────────────────────────────────────────────────
              div(
                class = "help-section home-reveal",
                div(class = "help-section-label", icon("sitemap"), "Quick Start"),
                h3(icon("sitemap", class = "help-icon"), "Quick Start Workflow"),
                p("A practical order for most analyses: pick the right search mode first, then build organisms and gene queries, generate the view, and explore results."),
                div(
                  class = "help-process-grid home-stagger-parent",
                  div(
                    class = "help-process-card home-stagger-child",
                    div(class = "help-process-step", "1"),
                    h4(class = "help-process-title", icon("random"), "Pick a search mode"),
                    p(class = "help-process-desc", "Choose ", tags$strong("Multi-Gene Search"), " to compare several genes in one organism, or ", tags$strong("Cross-Species Gene Search"), " to trace one gene across multiple species.")
                  ),
                  div(
                    class = "help-process-card home-stagger-child",
                    div(class = "help-process-step", "2"),
                    h4(class = "help-process-title", icon("globe"), "Select organisms"),
                    p(class = "help-process-desc", "Pick from the preloaded reference genomes or upload your own genome + annotation pair. You can mix preloaded and custom organisms.")
                  ),
                  div(
                    class = "help-process-card home-stagger-child",
                    div(class = "help-process-step", "3"),
                    h4(class = "help-process-title", icon("search"), "Enter gene names"),
                    p(class = "help-process-desc", "Type gene identifiers in the search box. CGV resolves aliases automatically via MyGene, NCBI, UniProt, and Ensembl. In Multi-Gene mode, add all genes before running.")
                  ),
                  div(
                    class = "help-process-card home-stagger-child",
                    div(class = "help-process-step", "4"),
                    h4(class = "help-process-title", icon("play"), "Generate the view"),
                    p(class = "help-process-desc", "Run the visualization. Gene cards load with structure plots, transcript metrics, and quick-action links. Summary table and analytics become available immediately.")
                  ),
                  div(
                    class = "help-process-card home-stagger-child",
                    div(class = "help-process-step", "5"),
                    h4(class = "help-process-title", icon("chart-bar"), "Explore and export"),
                    p(class = "help-process-desc", "Use the Summary Table, open the 10 analytics chart panels, click genes for popups (metrics, GO terms, papers, promoter), and export SVG, CSV, FASTA, or a full session.")
                  )
                )
              ),
              # ── Search Modes ────────────────────────────────────────────────
              div(
                class = "help-section home-reveal",
                div(class = "help-section-label", icon("random"), "Search Modes"),
                h3(icon("random", class = "help-icon"), "Search Modes"),
                p("Two complementary modes. Both share the same interface but unlock different views and comparison frameworks."),
                div(
                  class = "help-mode-grid home-stagger-parent",
                  div(
                    class = "help-mode-card home-stagger-child",
                    div(class = "help-mode-card-icon", icon("search")),
                    h4("Multi-Gene Search"),
                    p("Inspect and compare multiple annotated genes within one organism side by side. Ideal for structural review across isoforms and paralogs."),
                    tags$ul(
                      tags$li("Compare gene architecture, exon/intron metrics, and sequence composition for multiple genes at once."),
                      tags$li("Examine all transcript isoforms per gene with individual structure plots."),
                      tags$li("Access all 10 analytics chart types. Visualize available in: Compact and Detailed views.")
                    )
                  ),
                  div(
                    class = "help-mode-card home-stagger-child",
                    div(class = "help-mode-card-icon", icon("dna")),
                    h4("Cross-Species Gene Search"),
                    p("Compare one gene across multiple organisms with representative models aligned side by side. Designed for cross-species structural analysis."),
                    tags$ul(
                      tags$li("One gene queried simultaneously in each selected organism."),
                      tags$li("Unlocks the Comparative Aligned View, LASTZ Blocks, and Multi-PIP in addition to Compact and Detailed."),
                      tags$li("Exon-level event labeling: conservation, duplication (1:n, n:1), loss, and partial matches.")
                    )
                  )
                )
              ),

              # ── Visualization Views ──────────────────────────────────────────
              div(
                class = "help-section home-reveal",
                div(class = "help-section-label", icon("eye"), "Visualization Views"),
                h3(icon("eye", class = "help-icon"), "Visualization Views"),
                p("CGV offers five view modes. Compact and Detailed are available in both search modes. The three alignment views are exclusive to Cross-Species search."),
                div(
                  class = "help-views-grid home-stagger-parent",
                  div(
                    class = "help-view-card home-stagger-child",
                    div(class = "help-view-card-icon", icon("compress-arrows-alt")),
                    h4("Compact"),
                    p("Minimalist gene structure panel. Fits many genes on screen. Ideal for first-pass inspection."),
                    span(class = "help-view-badge help-view-badge-both", "Both modes")
                  ),
                  div(
                    class = "help-view-card home-stagger-child",
                    div(class = "help-view-card-icon", icon("list-alt")),
                    h4("Detailed"),
                    p("Full annotation with exons, CDS, UTR, strand, coordinates and zoom. Best for thorough single-gene review."),
                    span(class = "help-view-badge help-view-badge-both", "Both modes")
                  ),
                  div(
                    class = "help-view-card home-stagger-child",
                    div(class = "help-view-card-icon", icon("dna")),
                    h4("Comparative Aligned"),
                    p("Selects one representative transcript per organism, aligns them, and displays exon correspondence as ribbons with event-type labels."),
                    span(class = "help-view-badge help-view-badge-cross", "Cross-species only")
                  ),
                  div(
                    class = "help-view-card home-stagger-child",
                    div(class = "help-view-card-icon", icon("grip-lines")),
                    h4("LASTZ Blocks"),
                    p("Local pairwise alignment blocks across the genomic locus showing conserved regions between the query and each reference species."),
                    span(class = "help-view-badge help-view-badge-cross", "Cross-species only")
                  ),
                  div(
                    class = "help-view-card home-stagger-child",
                    div(class = "help-view-card-icon", icon("chart-line")),
                    h4("Multi-PIP"),
                    p("Percent Identity Plot across the genomic window. Visualizes conservation patterns of the query locus against multiple references."),
                    span(class = "help-view-badge help-view-badge-cross", "Cross-species only")
                  )
                )
              ),

              # ── Alignment modes ─────────────────────────────────────────────
              div(
                class = "help-section home-reveal",
                div(class = "help-section-label", icon("align-center"), "Alignment Modes"),
                h3(icon("align-center", class = "help-icon"), "Alignment Modes (Comparative Aligned View)"),
                p("The Comparative Aligned View supports three alignment strategies. Each uses a different sequence representation and scoring matrix."),
                div(
                  class = "help-align-grid home-stagger-parent",
                  div(
                    class = "help-align-card home-stagger-child",
                    div(class = "help-align-card-head",
                      div(class = "help-align-card-icon", icon("atom")),
                      tags$strong("Translated CDS")
                    ),
                    tags$p("Aligns the protein translations of each representative CDS. Best for detecting conserved coding regions even across divergent genomes."),
                    span(class = "help-align-matrix", "BLOSUM62")
                  ),
                  div(
                    class = "help-align-card home-stagger-child",
                    div(class = "help-align-card-head",
                      div(class = "help-align-card-icon", icon("dna")),
                      tags$strong("CDS Nucleotide")
                    ),
                    tags$p("Aligns the nucleotide CDS sequences directly. Useful when comparing closely related species where nucleotide identity is high."),
                    span(class = "help-align-matrix", "EDNAFULL")
                  ),
                  div(
                    class = "help-align-card home-stagger-child",
                    div(class = "help-align-card-head",
                      div(class = "help-align-card-icon", icon("layer-group")),
                      tags$strong("Exon")
                    ),
                    tags$p("Aligns full exon sequences including UTRs. Captures structural variation beyond the CDS and is suitable for lncRNA comparisons."),
                    span(class = "help-align-matrix", "EDNAFULL")
                  )
                ),
                p(style = "margin-top:10px; font-size:12px; color:#566c7f;",
                  icon("info-circle"), " All three modes use Needleman-Wunsch global alignment. Configurable window sizes: gene body, \u00b15 kb, \u00b110 kb, \u00b125 kb, \u00b150 kb apply to LASTZ Blocks and Multi-PIP.")
              ),
              # ── Understanding Results ────────────────────────────────────────
              div(
                class = "help-section home-reveal",
                div(class = "help-section-label", icon("chart-bar"), "Results"),
                h3(icon("chart-bar", class = "help-icon"), "Understanding Results"),
                p("CGV returns multiple output layers. Each adds a different level of depth to your analysis."),
                div(
                  class = "help-split-grid home-stagger-parent",
                  div(
                    class = "help-mini-card home-stagger-child",
                    h4(icon("th-large"), "Gene cards"),
                    tags$ul(
                      tags$li("One card per gene with structure plot (exons, CDS, UTR, strand, zoom, hoverable coordinates)."),
                      tags$li("Metrics: transcript length, CDS length, protein length (aa), GC%, exon/intron counts, biotype."),
                      tags$li("Quick-action links for alias resolution and direct sequence actions.")
                    )
                  ),
                  div(
                    class = "help-mini-card home-stagger-child",
                    h4(icon("mouse-pointer"), "Gene card popups"),
                    tags$ul(
                      tags$li(tags$strong("Metrics popup"), " — nucleotide composition donut, isoform comparison chart, genomic context scatter."),
                      tags$li(tags$strong("GO Annotations"), " — Gene Ontology terms from local files or live Ensembl lookup."),
                      tags$li(tags$strong("Papers"), " — recent publications via Europe PMC."),
                      tags$li(tags$strong("Promoter"), " — upstream region FASTA (100–5,000 bp) with coordinate export.")
                    )
                  ),
                  div(
                    class = "help-mini-card home-stagger-child",
                    h4(icon("table"), "Summary Table"),
                    tags$ul(
                      tags$li("Sortable and filterable. Columns: gene, transcript, chromosome, strand, exon count, lengths, organism (cross-species mode)."),
                      tags$li("Filter or rank results quickly before opening chart panels."),
                      tags$li("Export as CSV for downstream analysis.")
                    )
                  )
                ),
                div(style = "margin-top: 14px;",
                  p(style = "margin: 0 0 8px 0; font-size: 13px; font-weight: 700; color: #22364a;", icon("chart-bar"), " 10 analytics chart types:"),
                  div(
                    class = "help-chart-chips home-stagger-parent",
                    div(class = "help-chart-chip home-stagger-child", icon("dna"), "Architecture"),
                    div(class = "help-chart-chip home-stagger-child", icon("layer-group"), "Exons & Introns"),
                    div(class = "help-chart-chip home-stagger-child", icon("microscope"), "Sequence"),
                    div(class = "help-chart-chip home-stagger-child", icon("map-marker-alt"), "Genomic Context"),
                    div(class = "help-chart-chip home-stagger-child", icon("ruler-horizontal"), "Exon Lengths"),
                    div(class = "help-chart-chip home-stagger-child", icon("circle-dot"), "Scatter"),
                    div(class = "help-chart-chip home-stagger-child", icon("table-cells"), "Heatmap"),
                    div(class = "help-chart-chip home-stagger-child", icon("chart-pie"), "Radar"),
                    div(class = "help-chart-chip home-stagger-child", icon("grip-lines"), "Correlations"),
                    div(class = "help-chart-chip home-stagger-child", icon("align-left"), "Transcript Isoforms")
                  )
                )
              ),
              # ── Organisms ───────────────────────────────────────────────────
              div(
                class = "help-section home-reveal",
                div(class = "help-section-label", icon("globe"), "Organisms"),
                h3(icon("globe", class = "help-icon"), "Preloaded Reference Genomes"),
                p("CGV ships with reference genome assemblies and NCBI RefSeq annotations covering three kingdoms. You can also upload custom genomes."),
                div(
                  class = "help-kingdoms-row home-stagger-parent",
                  div(class = "help-kingdom-pill help-kingdom-animals home-stagger-child",
                    icon("paw"),
                    div(
                      tags$strong("Animalia (11)"),
                      tags$small(style="display:block; font-weight:500; font-size:10.5px; margin-top:2px;",
                        "H. sapiens, M. musculus, P. troglodytes, S. scrofa, C. lupus, D. rerio, X. laevis, D. melanogaster, C. elegans, D. rotundus, E. caballus")
                    )
                  ),
                  div(class = "help-kingdom-pill help-kingdom-plants home-stagger-child",
                    icon("leaf"),
                    div(
                      tags$strong("Plantae (11)"),
                      tags$small(style="display:block; font-weight:500; font-size:10.5px; margin-top:2px;",
                        "A. thaliana, A. lyrata, Z. mays (2 assemblies), O. sativa (2), S. lycopersicum, S. tuberosum, S. pennellii, H. vulgare, P. vulgaris, T. aestivum")
                    )
                  ),
                  div(class = "help-kingdom-pill help-kingdom-fungi home-stagger-child",
                    icon("bacteria"),
                    div(
                      tags$strong("Fungi (4)"),
                      tags$small(style="display:block; font-weight:500; font-size:10.5px; margin-top:2px;",
                        "S. cerevisiae, S. pombe, N. crassa, C. albicans")
                    )
                  )
                ),
                div(style = "margin-top: 12px;",
                  div(class = "help-mini-card",
                    style = "display:flex; gap:10px; align-items:flex-start;",
                    div(style = "font-size:20px; color:#18BC9C; flex-shrink:0; margin-top:2px;", icon("upload")),
                    div(
                      h4(style = "margin:0 0 5px 0; font-size:13px; font-weight:700; color:#22364a;", "Upload your own genome"),
                      p(style = "margin:0; font-size:12px; color:#566c7f;",
                        "Provide a genome file (", tags$code(".fa"), ", ", tags$code(".fa.gz"), ", ", tags$code(".fna"), ", ", tags$code(".2bit"), ") and a matching annotation (",
                        tags$code(".gff3"), ", ", tags$code(".gtf"), "). You can mix uploaded and preloaded organisms in the same analysis.")
                    )
                  )
                )
              ),

              # ── Exports & Sessions ──────────────────────────────────────────
              div(
                class = "help-section home-reveal",
                div(class = "help-section-label", icon("download"), "Exports & Sessions"),
                h3(icon("download", class = "help-icon"), "Export Formats & Session Management"),
                p("Multiple output options for publications, data pipelines, and workspace persistence."),
                div(
                  class = "help-export-grid home-stagger-parent",
                  div(class = "help-export-card home-stagger-child",
                    div(class = "help-export-icon", icon("image")),
                    div(tags$strong("SVG"), tags$small("Individual chart or gene structure vector export"))
                  ),
                  div(class = "help-export-card home-stagger-child",
                    div(class = "help-export-icon", icon("file-zipper")),
                    div(tags$strong("ZIP — charts"), tags$small("Batch export all analytics panels as SVGs"))
                  ),
                  div(class = "help-export-card home-stagger-child",
                    div(class = "help-export-icon", icon("file-zipper")),
                    div(tags$strong("ZIP — structures"), tags$small("Batch export all gene structure plots as SVGs"))
                  ),
                  div(class = "help-export-card home-stagger-child",
                    div(class = "help-export-icon", icon("table")),
                    div(tags$strong("CSV"), tags$small("Summary table: lengths, exon/intron counts, GC%, coordinates"))
                  ),
                  div(class = "help-export-card home-stagger-child",
                    div(class = "help-export-icon", icon("dna")),
                    div(tags$strong("FASTA — promoter"), tags$small("Configurable upstream region (100–5,000 bp)"))
                  ),
                  div(class = "help-export-card home-stagger-child",
                    div(class = "help-export-icon", icon("rotate-left")),
                    div(tags$strong("Session (.rds)"), tags$small("Save and restore the full workspace from Settings"))
                  )
                )
              ),

              # ── Troubleshooting ─────────────────────────────────────────────
              div(
                class = "help-section home-reveal",
                div(class = "help-section-label", icon("wrench"), "Troubleshooting"),
                h3(icon("wrench", class = "help-icon"), "Troubleshooting & Tips"),
                p("Most issues come from query spelling, organism selection, or annotation structure. This section covers the most common checks."),
                div(
                  class = "help-split-grid home-stagger-parent",
                  div(
                    class = "help-mini-card home-stagger-child",
                    h4(icon("upload"), "Data inputs"),
                    tags$ul(
                      tags$li("Uploads require a genome file in ", tags$code(".fa"), ", ", tags$code(".fa.gz"), ", or ", tags$code(".2bit"), " plus a matching annotation in ", tags$code(".gff3"), " or ", tags$code(".gtf"), "."),
                      tags$li("You can mix preloaded references with uploaded organisms in the same analysis."),
                      tags$li("CGV currently ships with more than two dozen preloaded organism references.")
                    )
                  ),
                  div(
                    class = "help-mini-card",
                    h4(icon("search"), "If a gene is missing"),
                    tags$ul(
                      tags$li("Check gene symbol spelling and letter case."),
                      tags$li("Confirm that at least one organism is selected before running the search."),
                      tags$li("For uploaded data, verify that the annotation contains the expected gene identifiers and associated transcript features.")
                    ),
                    div(
                      class = "help-db-logo-row",
                      div(
                        class = "help-db-logo-item",
                        tags$img(src = "icons/databases/mygene.ico", alt = "MyGene"),
                        span("MyGene")
                      ),
                      div(
                        class = "help-db-logo-item",
                        tags$img(src = "icons/databases/ncbi.ico", alt = "NCBI Gene"),
                        span("NCBI Gene")
                      ),
                      div(
                        class = "help-db-logo-item",
                        tags$img(src = "icons/databases/uniprot.ico", alt = "UniProt"),
                        span("UniProt")
                      ),
                      div(
                        class = "help-db-logo-item",
                        tags$img(src = "icons/databases/ensembl.ico", alt = "Ensembl"),
                        span("Ensembl")
                      )
                    )
                  ),
                  div(
                    class = "help-mini-card home-stagger-child",
                    h4(icon("bolt"), "Performance tips"),
                    tags$ul(
                      tags$li("Start with fewer organisms or genes, then scale up once the first view looks correct."),
                      tags$li("Use the summary table to narrow what you inspect before opening all analytics panels."),
                      tags$li("Reorder charts when the plot count grows so comparisons stay readable.")
                    )
                  ),
                  div(
                    class = "help-mini-card home-stagger-child",
                    h4(icon("save"), "Sessions and display settings"),
                    tags$ul(
                      tags$li("Export your current work session as ", tags$code(".rds"), " when you want to resume later."),
                      tags$li("Restore a saved session from Settings to recover plots and configuration."),
                      tags$li("Theme, dark mode, and colorblind options can help readability for dense figure review.")
                    )
                  )
                )
              ),
              div(
                class = "help-section help-faq-section home-reveal",
                div(class = "help-section-label", icon("question-circle"), "FAQ"),
                h3(icon("question-circle", class = "help-icon"), "Frequently Asked Questions"),
                div(
                  class = "help-faq-list home-stagger-parent",

                  # ── FAQ 1 ─────────────────────────────────────────────────
                  div(
                    class = "help-faq-item home-stagger-child",
                    tags$button(
                      class = "help-faq-question",
                      `aria-expanded` = "false",
                      span(class = "help-faq-icon", "+"),
                      "What is CGV best used for?"
                    ),
                    div(
                      class = "help-faq-body",
                      div(class = "help-faq-answer",
                        tags$p("CGV is designed for gene-centered structural comparison. It excels at examining exon/intron architecture, comparing representative gene models across species, exploring transcript isoforms, and producing publication-ready figures — all within a single guided interface, without requiring any scripting.")
                      )
                    )
                  ),

                  # ── FAQ 2 ─────────────────────────────────────────────────
                  div(
                    class = "help-faq-item home-stagger-child",
                    tags$button(
                      class = "help-faq-question",
                      `aria-expanded` = "false",
                      span(class = "help-faq-icon", "+"),
                      "Do I need to install anything before using CGV?"
                    ),
                    div(
                      class = "help-faq-body",
                      div(class = "help-faq-answer",
                        tags$p("No. CGV runs entirely in the browser. There is no local installation, package setup, or command-line workflow required to start exploring results.")
                      )
                    )
                  ),

                  # ── FAQ 3 ─────────────────────────────────────────────────
                  div(
                    class = "help-faq-item home-stagger-child",
                    tags$button(
                      class = "help-faq-question",
                      `aria-expanded` = "false",
                      span(class = "help-faq-icon", "+"),
                      "When should I choose Multi-Gene versus Cross-Species Gene Search?"
                    ),
                    div(
                      class = "help-faq-body",
                      div(class = "help-faq-answer",
                        tags$p(tags$strong("Multi-Gene Search"), " is the better choice when you want to inspect several genes within one organism. ", tags$strong("Cross-Species Gene Search"), " is the better choice when you want to compare one gene across multiple organisms and use the Comparative Aligned view.")
                      )
                    )
                  ),

                  # ── FAQ 4 ─────────────────────────────────────────────────
                  div(
                    class = "help-faq-item home-stagger-child",
                    tags$button(
                      class = "help-faq-question",
                      `aria-expanded` = "false",
                      span(class = "help-faq-icon", "+"),
                      "What does the Comparative Aligned View show?"
                    ),
                    div(
                      class = "help-faq-body",
                      div(class = "help-faq-answer",
                        tags$p("It selects one representative transcript per organism and aligns them globally using Needleman-Wunsch. The result is displayed as aligned exon blocks connected by ribbons, with each exon-pair labeled by event type:"),
                        tags$ul(
                          tags$li(tags$strong("1:1"), " — single conserved exon correspondence."),
                          tags$li(tags$strong("1:n / n:1"), " — exon split or fusion events."),
                          tags$li(tags$strong("Partial"), " — partial overlap between exons."),
                          tags$li(tags$strong("Lost"), " — exon present in one organism, absent in the other.")
                        )
                      )
                    )
                  ),

                  # ── FAQ 5 ─────────────────────────────────────────────────
                  div(
                    class = "help-faq-item home-stagger-child",
                    tags$button(
                      class = "help-faq-question",
                      `aria-expanded` = "false",
                      span(class = "help-faq-icon", "+"),
                      "What are the three alignment modes and when should I use each?"
                    ),
                    div(
                      class = "help-faq-body",
                      div(class = "help-faq-answer",
                        tags$ul(
                          tags$li(tags$strong("Translated CDS (BLOSUM62)"), " — recommended for distantly related species where nucleotide identity is low but protein function is conserved."),
                          tags$li(tags$strong("CDS Nucleotide (EDNAFULL)"), " — best for closely related species where the coding sequence at nucleotide level is still similar."),
                          tags$li(tags$strong("Exon (EDNAFULL)"), " — aligns the full exon including UTR regions. Useful for lncRNAs or when UTR conservation is of interest.")
                        )
                      )
                    )
                  ),

                  # ── FAQ 6 ─────────────────────────────────────────────────
                  div(
                    class = "help-faq-item home-stagger-child",
                    tags$button(
                      class = "help-faq-question",
                      `aria-expanded` = "false",
                      span(class = "help-faq-icon", "+"),
                      "What information can I access by clicking on a gene card?"
                    ),
                    div(
                      class = "help-faq-body",
                      div(class = "help-faq-answer",
                        tags$p("Clicking a gene opens a set of popup panels:"),
                        tags$ul(
                          tags$li(tags$strong("Metrics"), " — nucleotide composition donut, isoform length comparison, and genomic context scatter."),
                          tags$li(tags$strong("GO Annotations"), " — Gene Ontology terms sourced from local annotation files, with live fallback to Ensembl."),
                          tags$li(tags$strong("Papers"), " — recent publications retrieved from Europe PMC for that gene and organism."),
                          tags$li(tags$strong("Promoter"), " — configurable upstream region (100–5,000 bp) shown as FASTA sequence with coordinate export.")
                        )
                      )
                    )
                  ),

                  # ── FAQ 7 ─────────────────────────────────────────────────
                  div(
                    class = "help-faq-item home-stagger-child",
                    tags$button(
                      class = "help-faq-question",
                      `aria-expanded` = "false",
                      span(class = "help-faq-icon", "+"),
                      "What files can I upload?"
                    ),
                    div(
                      class = "help-faq-body",
                      div(class = "help-faq-answer",
                        tags$p("Genome formats: ", tags$code(".fa"), ", ", tags$code(".fasta"), ", ", tags$code(".fna"), " (plain or gzip-compressed), or ", tags$code(".2bit"), "."),
                        tags$p("Annotation formats: ", tags$code(".gff3"), " or ", tags$code(".gtf"), "."),
                        tags$p("The genome and annotation files must correspond to the same organism. You can mix uploaded organisms with preloaded references in the same analysis session.")
                      )
                    )
                  ),

                  # ── FAQ 8 ─────────────────────────────────────────────────
                  div(
                    class = "help-faq-item home-stagger-child",
                    tags$button(
                      class = "help-faq-question",
                      `aria-expanded` = "false",
                      span(class = "help-faq-icon", "+"),
                      "How do I export or save my work?"
                    ),
                    div(
                      class = "help-faq-body",
                      div(class = "help-faq-answer",
                        tags$ul(
                          tags$li(tags$strong("SVG"), " — individual chart or gene structure plot export."),
                          tags$li(tags$strong("ZIP"), " — batch export of all analytics chart SVGs, or all gene structure SVGs."),
                          tags$li(tags$strong("CSV"), " — summary table with lengths, exon/intron counts, GC%, and coordinates."),
                          tags$li(tags$strong("FASTA"), " — promoter region sequences with configurable window (100–5,000 bp)."),
                          tags$li(tags$strong("Session (.rds)"), " — saves the full workspace. Restore it any time from Settings \u2192 Session Management.")
                        )
                      )
                    )
                  ),

                  # ── FAQ 9 ─────────────────────────────────────────────────
                  div(
                    class = "help-faq-item home-stagger-child",
                    tags$button(
                      class = "help-faq-question",
                      `aria-expanded` = "false",
                      span(class = "help-faq-icon", "+"),
                      "Why might a gene not appear in the results?"
                    ),
                    div(
                      class = "help-faq-body",
                      div(class = "help-faq-answer",
                        tags$ul(
                          tags$li("The gene symbol may be misspelled or use an alternative alias not present in the selected annotation."),
                          tags$li("No organism is selected for the current search — at least one must be active."),
                          tags$li("For uploaded data, the annotation file may not contain the expected gene identifier or a matching transcript feature.")
                        ),
                        tags$p("Tip: enable external alias lookup (MyGene, NCBI Gene, UniProt, or Ensembl) in Settings to automatically resolve alternative names and IDs.")
                      )
                    )
                  ),

                  # ── FAQ 10 ────────────────────────────────────────────────
                  div(
                    class = "help-faq-item home-stagger-child",
                    tags$button(
                      class = "help-faq-question",
                      `aria-expanded` = "false",
                      span(class = "help-faq-icon", "+"),
                      "How is CGV different from genome browsers or plotting packages?"
                    ),
                    div(
                      class = "help-faq-body",
                      div(class = "help-faq-answer",
                        tags$p("Genome browsers are built for locus navigation and broad genomic context. Plotting packages require scripted figure generation. CGV occupies a different space: guided, gene-first comparison with cross-species alignment, 10 analytics charts, popup information layers (GO, papers, promoter), and multiple export formats — all without writing code.")
                      )
                    )
                  ),

                  # ── FAQ 11 ────────────────────────────────────────────────
                  div(
                    class = "help-faq-item home-stagger-child",
                    tags$button(
                      class = "help-faq-question",
                      `aria-expanded` = "false",
                      span(class = "help-faq-icon", "+"),
                      "What does CGV not do?"
                    ),
                    div(
                      class = "help-faq-body",
                      div(class = "help-faq-answer",
                        tags$p("CGV is focused on gene structure visualization and comparative analysis. It does not perform: RNA-seq quantification, differential expression testing, variant calling, genome assembly, phylogenetic tree construction, or protein structure prediction. For those workflows, use dedicated tools and bring the results back to CGV for structural context.")
                      )
                    )
                  )
                )
              )
            )
          )
        ),
        tabPanel(
          title = "Feedback",
          value = "feedback",
          div(
            class = "content-wrapper app-main-pane app-settings-pane",
            div(
              class = "help-content settings-content feedback-shell",

              # ── Inline CSS for new animated elements ──────────────────────
              tags$style(HTML("
                /* Info strip */
                .feedback-info-strip {
                  display: grid;
                  grid-template-columns: repeat(3, minmax(0, 1fr));
                  gap: 12px;
                  margin-bottom: 0;
                }
                .feedback-info-card {
                  border: 1px solid #d8e3ec;
                  border-radius: 14px;
                  background: #ffffff;
                  padding: 16px;
                  transition: transform 0.22s ease, box-shadow 0.22s ease, border-color 0.22s ease;
                  position: relative;
                  overflow: hidden;
                }
                .feedback-info-card::before {
                  content: '';
                  position: absolute;
                  top: 0; left: 0; right: 0;
                  height: 3px;
                  background: linear-gradient(90deg, #18BC9C, #44B0FF);
                  opacity: 0;
                  transition: opacity 0.25s ease;
                  border-radius: 14px 14px 0 0;
                }
                .feedback-info-card:hover {
                  transform: translateY(-3px);
                  box-shadow: 0 12px 28px rgba(24, 188, 156, 0.11);
                  border-color: rgba(24, 188, 156, 0.28);
                }
                .feedback-info-card:hover::before { opacity: 1; }
                .feedback-info-card-icon {
                  width: 36px; height: 36px;
                  border-radius: 10px;
                  background: linear-gradient(135deg, #18BC9C, #0fa383);
                  color: #ffffff;
                  display: flex; align-items: center; justify-content: center;
                  font-size: 15px;
                  margin-bottom: 10px;
                  transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
                }
                .feedback-info-card:hover .feedback-info-card-icon {
                  transform: scale(1.15) rotate(-6deg);
                }
                .feedback-info-card h4 {
                  font-size: 13px;
                  font-weight: 800;
                  color: #22364a;
                  margin: 0 0 8px 0;
                }
                .feedback-info-card p,
                .feedback-info-card li {
                  font-size: 12px;
                  color: #566c7f;
                  line-height: 1.55;
                }
                .feedback-info-card ul,
                .feedback-info-card ol {
                  margin: 0;
                  padding-left: 16px;
                }
                .feedback-info-card li { margin-bottom: 4px; }
                /* Numbered steps inside info card */
                .feedback-step-list {
                  display: flex;
                  flex-direction: column;
                  gap: 7px;
                  list-style: none;
                  padding: 0; margin: 0;
                }
                .feedback-step-list li {
                  display: flex;
                  align-items: flex-start;
                  gap: 9px;
                  font-size: 12px;
                  color: #566c7f;
                  line-height: 1.5;
                }
                .feedback-step-num {
                  width: 20px; height: 20px;
                  border-radius: 6px;
                  background: linear-gradient(135deg, #18BC9C, #0fa383);
                  color: #fff;
                  font-size: 10px;
                  font-weight: 900;
                  display: flex; align-items: center; justify-content: center;
                  flex-shrink: 0;
                  margin-top: 1px;
                }
                /* Form section */
                .feedback-form-section {
                  border: 1px solid #d8e3ec;
                  border-radius: 16px;
                  background: linear-gradient(180deg, #fbfdff 0%, #f5f9fc 100%);
                  box-shadow: 0 10px 24px rgba(32, 58, 82, 0.07);
                  overflow: hidden;
                }
                .feedback-form-section-header {
                  padding: 18px 22px 14px;
                  border-bottom: 1px solid #e8eef4;
                  display: flex;
                  align-items: center;
                  gap: 10px;
                }
                .feedback-form-section-header-icon {
                  width: 36px; height: 36px;
                  border-radius: 10px;
                  background: linear-gradient(135deg, #18BC9C, #0fa383);
                  color: #fff;
                  display: flex; align-items: center; justify-content: center;
                  font-size: 15px;
                  flex-shrink: 0;
                }
                .feedback-form-section-header h3 {
                  margin: 0;
                  font-size: 16px;
                  font-weight: 800;
                  color: #1f3246;
                }
                .feedback-form-section-header p {
                  margin: 2px 0 0;
                  font-size: 12px;
                  color: #6a7f91;
                }
                .feedback-form-body {
                  padding: 18px 22px;
                  display: flex;
                  flex-direction: column;
                  gap: 14px;
                }
                /* Compact contact grid inside form */
                .feedback-contact-grid {
                  display: grid;
                  grid-template-columns: 1fr 1fr;
                  gap: 0 14px;
                }
                /* Dark mode */
                html[data-app-theme='dark'] .feedback-info-card {
                  background: #10263a; border-color: #2a4e69;
                }
                html[data-app-theme='dark'] .feedback-info-card h4 { color: #d5e7f7; }
                html[data-app-theme='dark'] .feedback-info-card p,
                html[data-app-theme='dark'] .feedback-info-card li,
                html[data-app-theme='dark'] .feedback-step-list li { color: #9ebdd2; }
                html[data-app-theme='dark'] .feedback-form-section {
                  background: linear-gradient(180deg, #132a3f 0%, #172f45 100%);
                  border-color: #274b66;
                }
                html[data-app-theme='dark'] .feedback-form-section-header {
                  border-color: #2a4e69;
                }
                html[data-app-theme='dark'] .feedback-form-section-header h3 { color: #d5e7f7; }
                html[data-app-theme='dark'] .feedback-form-section-header p { color: #9ebdd2; }
                @media (max-width: 860px) {
                  .feedback-info-strip {
                    grid-template-columns: 1fr;
                  }
                  .feedback-contact-grid {
                    grid-template-columns: 1fr;
                  }
                }
              ")),

              # ── Hero ──────────────────────────────────────────────────────
              div(
                class = "feedback-hero home-reveal",
                div(
                  class = "feedback-hero-copy",
                  div(class = "feedback-kicker", icon("comment-dots"), span("Community Feedback")),
                  h2("Feedback & Support"),
                  p("Help us improve CGV. Report bugs, suggest features, or flag rough edges in the workflow."),
                  div(
                    class = "feedback-pill-row home-stagger-parent",
                    span(class = "feedback-pill home-stagger-child", icon("flask"), span("Scientific workflows")),
                    span(class = "feedback-pill home-stagger-child", icon("shield-alt"), span("Anti-spam protected")),
                    span(class = "feedback-pill home-stagger-child", icon("envelope"), span("Replies to your email"))
                  )
                )
              ),

              # ── Info strip ─────────────────────────────────────────────────
              div(
                class = "feedback-info-strip home-stagger-parent",

                # Card 1 — What we capture
                div(
                  class = "feedback-info-card home-stagger-child",
                  div(class = "feedback-info-card-icon", icon("circle-info")),
                  h4("What we capture automatically"),
                  tags$ul(
                    tags$li("The CGV section active when you submitted."),
                    tags$li("Submission timestamp and page context."),
                    tags$li("Your contact details for follow-up.")
                  )
                ),

                # Card 2 — What happens next
                div(
                  class = "feedback-info-card home-stagger-child",
                  div(class = "feedback-info-card-icon", icon("route")),
                  h4("What happens after you send it?"),
                  tags$ul(
                    class = "feedback-step-list",
                    tags$li(span(class = "feedback-step-num", "1"), "Your report is delivered to the CGV inbox."),
                    tags$li(span(class = "feedback-step-num", "2"), "Bug reports blocking analysis get reviewed first."),
                    tags$li(span(class = "feedback-step-num", "3"), "Suggestions shape community-facing improvements.")
                  )
                ),

                # Card 3 — Tips
                div(
                  class = "feedback-info-card home-stagger-child",
                  div(class = "feedback-info-card-icon", icon("wand-magic-sparkles")),
                  h4("Tips for a useful report"),
                  tags$ul(
                    tags$li("Describe what you were trying to do, not only what broke."),
                    tags$li("For bugs: organism, gene, view mode, and browser help a lot."),
                    tags$li("For suggestions: explain how the change fits your workflow.")
                  )
                )
              ),

              # ── Form (bottom, most important) ──────────────────────────────
              div(
                class = "feedback-form-section home-reveal",

                # Header
                div(
                  class = "feedback-form-section-header",
                  div(class = "feedback-form-section-header-icon", icon("paper-plane")),
                  div(
                    h3("Send Feedback"),
                    p("Fields marked * are required. They help us reproduce issues faster.")
                  )
                ),

                # Body
                div(
                  class = "feedback-form-body",

                  # Type selector
                  div(
                    class = "help-section feedback-type-section",
                    h3(icon("clipboard-list"), span("What would you like to do?")),
                    div(
                      class = "viz-mode-wrap feedback-type-switch-wrap",
                      htmltools::tagAppendAttributes(
                        radioButtons(
                          "feedback_type",
                          NULL,
                          choices = c("Report a Bug" = "bug", "Suggest a Feature" = "suggestion"),
                          selected = "bug",
                          inline = TRUE
                        ),
                        class = "viz-mode-toggle feedback-type-switch"
                      )
                    )
                  ),

                  # Contact info (compact 2-col grid)
                  div(
                    class = "help-section feedback-contact-card",
                    h3(icon("id-card"), span("Your information")),
                    p(class = "feedback-field-note", "Use the email where you'd like to receive our reply."),
                    div(
                      class = "feedback-contact-grid",
                      textInput("feedback_name", HTML('Full Name <span class="field-required">*</span>'), placeholder = "Your full name", width = "100%"),
                      textInput("feedback_email", HTML('Email Address <span class="field-required">*</span>'), placeholder = "name@example.org", width = "100%")
                    ),
                    div(
                      class = "feedback-honeypot",
                      textInput("feedback_website", "Leave this field empty", width = "100%")
                    )
                  ),

                  # Bug form (conditional — ID and condition UNCHANGED)
                  conditionalPanel(
                    condition = "input.feedback_type == 'bug'",
                    div(
                      class = "help-section feedback-detail-card",
                      h3(icon("bug"), span("Bug report")),
                      textInput("bug_title", HTML('Short Title <span class="field-required">*</span>'), placeholder = "Example: Comparative plot gets cut off after export", width = "100%"),
                      textAreaInput("bug_steps", HTML('What happened? Include steps to reproduce <span class="field-required">*</span>'), placeholder = "1. Opened Cross-Species Gene Search...\n2. Generated the aligned view...\n3. Exported SVG...\n4. The right side of the plot was missing.", width = "100%", rows = 7),
                      textAreaInput("bug_expected", "What did you expect to happen? (Optional)", placeholder = "Example: The full plot should export without clipping.", width = "100%", rows = 3)
                    )
                  ),

                  # Suggestion form (conditional — ID and condition UNCHANGED)
                  conditionalPanel(
                    condition = "input.feedback_type == 'suggestion'",
                    div(
                      class = "help-section feedback-detail-card",
                      h3(icon("lightbulb"), span("Feature suggestion")),
                      textInput("sugg_title", HTML('Short Title <span class="field-required">*</span>'), placeholder = "Example: Add PDF export for publication-ready figures", width = "100%"),
                      textAreaInput("sugg_problem", HTML('What is missing or difficult today? <span class="field-required">*</span>'), placeholder = "Describe the gap in the current workflow.", width = "100%", rows = 4),
                      textAreaInput("sugg_idea", "What would you like CGV to do? (Optional)", placeholder = "Explain the feature or improvement you would like to see.", width = "100%", rows = 4)
                    )
                  ),

                  # Submit row (UNCHANGED)
                  div(
                    class = "feedback-submit-row",
                    div(
                      class = "feedback-submit-meta",
                      p(class = "feedback-submit-note", "By submitting, you agree that we may use your email only to follow up on this report.")
                    ),
                    actionButton("submit_feedback_btn", "Send Feedback", icon = icon("paper-plane"), class = "btn-primary feedback-submit-btn")
                  )
                )
              )
            )
          )
        )
      ),
      div(
        id = "app-quick-fab",
        class = "app-quick-fab",
        tags$div(
          class = "app-quick-fab-actions",
          tags$button(
            id = "app-fab-search-toggle",
            type = "button",
            class = "app-fab-action-btn",
            `data-label` = "Search gene",
            `aria-label` = "Search gene",
            `aria-expanded` = "false",
            icon("search")
          ),
          tags$button(
            id = "app-fab-mode-toggle",
            type = "button",
            class = "app-fab-action-btn",
            `data-label` = "Visualization mode",
            `aria-label` = "Visualization mode",
            `aria-expanded` = "false",
            icon("sliders")
          ),
          tags$button(
            id = "app-fab-zoom-toggle",
            type = "button",
            class = "app-fab-action-btn",
            `data-label` = "Plot zoom",
            `aria-label` = "Plot zoom",
            `aria-expanded` = "false",
            icon("search-plus")
          )
        ),
        div(
          id = "app-fab-search-panel",
          class = "app-fab-panel app-fab-search-panel",
          div(class = "app-fab-panel-title", icon("search"), span("Search gene")),
          tags$input(
            id = "app-fab-search-query",
            type = "text",
            class = "app-fab-search-input",
            placeholder = "Enter gene name (add to batch)",
            autocomplete = "off",
            autocorrect = "off",
            autocapitalize = "off",
            spellcheck = "false"
          ),
          div(
            class = "app-fab-chip-preview",
            div(
              id = "global-search-chip-list-fab",
              class = "app-search-chip-list app-search-chip-list-sync app-search-chip-list-compact",
              `data-empty-label` = "No batch genes.",
              span(class = "app-search-chip-empty", "No batch genes.")
            )
          ),
          tags$button(
            id = "app-fab-search-run",
            type = "button",
            class = "app-fab-panel-btn",
            icon("search"),
            span("Generate visualization")
          )
        ),
        div(
          id = "app-fab-mode-panel",
          class = "app-fab-panel app-fab-mode-panel",
          div(class = "app-fab-panel-title", icon("sliders"), span("Visualization mode")),
          div(
            class = "app-fab-mode-options",
            tags$button(type = "button", class = "app-fab-mode-option", `data-mode` = "compact", `aria-pressed` = "false", "Compact"),
            tags$button(type = "button", class = "app-fab-mode-option", `data-mode` = "detailed", `aria-pressed` = "false", "Detailed"),
            tags$button(type = "button", class = "app-fab-mode-option", `data-mode` = "aligned", `aria-pressed` = "false", "Aligned"),
            tags$button(type = "button", class = "app-fab-mode-option", `data-mode` = "pip_blocks", `aria-pressed` = "false", "LASTZ Blocks"),
            tags$button(type = "button", class = "app-fab-mode-option", `data-mode` = "pip_multipip", `aria-pressed` = "false", "MultiPIP")
          ),
          div(id = "app-fab-mode-context", class = "app-fab-mode-context", "Multi-Gene mode")
        ),
        div(
          id = "app-fab-zoom-panel",
          class = "app-fab-panel app-fab-zoom-panel",
          div(class = "app-fab-panel-title", icon("search-plus"), span("Plot zoom")),
          div(
            class = "app-fab-zoom-control",
            tags$button(
              id = "fab-zoom-in",
              type = "button",
              class = "app-fab-zoom-btn",
              `data-zoom-action` = "in",
              `data-zoom-mode` = "homo",
              title = "Zoom in",
              "\u002b"
            ),
            span(
              id = "fab-zoom-label",
              class = "app-fab-zoom-label",
              "1\u00d7"
            ),
            tags$button(
              id = "fab-zoom-out",
              type = "button",
              class = "app-fab-zoom-btn",
              `data-zoom-action` = "out",
              `data-zoom-mode` = "homo",
              title = "Zoom out",
              disabled = NA,
              "−"
            )
          )
        ),
        tags$button(
          id = "app-fab-main-toggle",
          type = "button",
          class = "app-fab-main-btn",
          `aria-label` = "Quick actions",
          `aria-expanded` = "false",
          icon("plus", class = "app-fab-main-icon")
        )
      ),
      tags$button(
        id = "app-floating-top",
        type = "button",
        class = "app-floating-top-btn",
        `aria-label` = "Scroll to top",
        `aria-hidden` = "true",
        icon("chevron-up")
      )
    )
  )
)
