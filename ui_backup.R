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

get_initial_ready_preloaded_registry <- function() {
  reg <- tryCatch(
    get_preloaded_species_registry(registry_path = file.path("annotations", "registry.tsv"), base_dir = "."),
    error = function(e) data.frame()
  )
  if (is.null(reg) || !is.data.frame(reg) || nrow(reg) == 0) {
    return(data.frame())
  }
  if (!"ready" %in% colnames(reg)) {
    reg$ready <- TRUE
  }
  reg[as.logical(reg$ready), , drop = FALSE]
}

build_initial_species_grouped_grid <- function(df_in, input_id, mode) {
  if (is.null(df_in) || !is.data.frame(df_in) || nrow(df_in) == 0) {
    return(list(div(class = "species-grid-empty", "No organisms available")))
  }
  if (!"kingdom" %in% colnames(df_in)) df_in$kingdom <- ""
  kingdom_order <- c("Animalia", "Plantae", "Fungi")
  df_in$kingdom[!nzchar(as.character(df_in$kingdom))] <- "Other"
  kingdoms_present <- intersect(kingdom_order, unique(as.character(df_in$kingdom)))
  leftover <- setdiff(unique(as.character(df_in$kingdom)), kingdom_order)
  kingdoms_present <- c(kingdoms_present, leftover)

  sections <- lapply(kingdoms_present, function(kg) {
    sub_df <- df_in[as.character(df_in$kingdom) == kg, , drop = FALSE]
    if (nrow(sub_df) == 0) return(NULL)

    cards <- lapply(seq_len(nrow(sub_df)), function(i) {
      sid <- as.character(sub_df$species_id[i] %||% "")
      org <- as.character(sub_df$organism[i] %||% sub_df$label[i] %||% "Unknown")
      icn <- as.character(sub_df$icon_url[i] %||% "/icons/DNA.ico")
      div(
        class = "species-grid-card",
        `data-species-id` = sid,
        role = "button",
        tabindex = "0",
        style = "cursor:pointer;",
        div(
          class = "species-grid-icon-wrap",
          tags$img(class = "species-grid-icon-img", src = icn, alt = org)
        ),
        div(
          class = "species-grid-text",
          span(class = "species-grid-name", org)
        )
      )
    })

    div(
      class = "species-kingdom-group",
      div(class = "species-kingdom-divider"),
      div(class = "species-kingdom-header", kg),
      div(
        class = "species-grid",
        `data-input-id` = input_id,
        `data-mode` = mode,
        cards
      )
    )
  })
  Filter(Negate(is.null), sections)
}

initial_ready_preloaded_registry <- get_initial_ready_preloaded_registry()
initial_homo_species_grid <- tagList(
  div(
    class = "species-grid-shell species-grid-shell-initial",
    build_initial_species_grouped_grid(initial_ready_preloaded_registry, "homo_preloaded_species", "single")
  )
)
initial_ortho_species_grid <- tagList(
  div(
    class = "species-grid-shell species-grid-shell-initial",
    build_initial_species_grouped_grid(initial_ready_preloaded_registry, "ortho_preloaded_species", "multi")
  )
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
      tags$link(rel = "stylesheet", href = versioned_asset_path("css/cross_species_header_status.css")),
      tags$script(HTML(sprintf(
        "window.__cgvTransportTiming = %s; window.__cgvTransportFlushMs = %s;",
        jsonlite::toJSON(app_env_flag("APP_TRANSPORT_TIMING", FALSE), auto_unbox = TRUE),
        jsonlite::toJSON(app_env_int("APP_TRANSPORT_FLUSH_MS", 5000L, min_value = 50L), auto_unbox = TRUE)
      ))),
      tags$script(src = versioned_asset_path("js/transport_metrics.js")),
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

      function setSpeciesInputValue(inputId, value) {
        if (!inputId) return;
        if (window.Shiny && typeof Shiny.setInputValue === 'function') {
          Shiny.setInputValue(inputId, value, {priority: 'event'});
          return;
        }
        window.__pendingSpeciesSelections = window.__pendingSpeciesSelections || {};
        window.__pendingSpeciesSelections[inputId] = value;
      }

      function flushPendingSpeciesSelections() {
        var pending = window.__pendingSpeciesSelections || {};
        Object.keys(pending).forEach(function(inputId) {
          setSpeciesInputValue(inputId, pending[inputId]);
        });
        window.__pendingSpeciesSelections = {};
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
        setSpeciesInputValue(inputId, id);
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
        setSpeciesInputValue(inputId, sel.length ? sel : null);
        updateOrganismSummaryFromGrid($grid);
      });

      $(document).on('shiny:connected', flushPendingSpeciesSelections);

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
      tags$script(src = versioned_asset_path("js/info_button_relocator.js")),
      tags$script(src = versioned_asset_path("js/ortho_lazy_loader.js")),
      tags$script(src = versioned_asset_path("js/summary_context_layout.js")),
      tags$script(src = versioned_asset_path("js/ncbi_search.js")),
      tags$script(src = versioned_asset_path("js/organism_images.js")),
      tags$script(src = versioned_asset_path("js/mobile_enhancements.js"), defer = NA),
      tags$script(HTML("
      (function () {
        var validTargets = ['home', 'homologous', 'orthologous', 'guide', 'settings', 'help', 'feedback'];
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

        function activateNavTabImmediately(target) {
          if (!isValidTarget(target)) return false;
          var link = document.querySelector('#navtabs a[data-value=\"' + target + '\"]');
          if (!link) return false;
          try {
            if (window.jQuery && jQuery.fn && jQuery.fn.tab) {
              jQuery(link).tab('show');
            } else {
              link.click();
            }
            return true;
          } catch (err) {
            try {
              link.click();
              return true;
            } catch (err2) {
              return false;
            }
          }
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
        window.updateOrthoSpecialCardVisibility = updateOrthoSpecialCardVisibility;

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

        function keepSummaryContextOpaque() {
          var sections = document.querySelectorAll('#homo_context_section, #ortho_context_section');
          sections.forEach(function(section) {
            if (section.style.opacity && section.style.opacity !== '1') section.style.opacity = '1';
            if (section.style.filter && section.style.filter !== 'none') section.style.filter = 'none';
            section.classList.remove('recalculating');
            section.querySelectorAll('.shiny-bound-output, .recalculating').forEach(function(el) {
              if (el.style.opacity && el.style.opacity !== '1') el.style.opacity = '1';
              if (el.style.filter && el.style.filter !== 'none') el.style.filter = 'none';
              if (el.classList.contains('recalculating')) el.classList.remove('recalculating');
            });
          });
        }

        function initSummaryContextTooltips(root) {
          if (!window.jQuery || !window.jQuery.fn || !window.jQuery.fn.tooltip) return;
          var scope = root || document;
          window.jQuery(scope).find('.summary-organism-pill').each(function() {
            try { window.jQuery(this).tooltip('destroy'); } catch (e) {}
            this.removeAttribute('data-toggle');
            this.removeAttribute('data-html');
            this.removeAttribute('data-container');
            this.removeAttribute('data-placement');
          });
          window.jQuery('.tooltip').remove();
        }

        function markOrthoHeaderLookupStarted() {
          var section = document.getElementById('ortho_context_section');
          if (!section) return;
          section.style.display = '';
          keepSummaryContextOpaque();
          section.querySelectorAll('.summary-organism-pill').forEach(function(pill) {
            pill.classList.remove(
              'summary-organism-pill-found',
              'summary-organism-pill-found_local',
              'summary-organism-pill-found_external',
              'summary-organism-pill-external_search',
              'summary-organism-pill-not_found'
            );
            pill.classList.add('summary-organism-pill-local_search');
            pill.setAttribute('title', 'Searching local annotation');
            pill.removeAttribute('data-status-tooltip');
          });
          initSummaryContextTooltips(section);
        }

        document.addEventListener('click', function(e) {
          var trigger = e.target && e.target.closest ? e.target.closest('#search_gene') : null;
          if (trigger) {
            markOrthoHeaderLookupStarted();
            setTimeout(keepSummaryContextOpaque, 0);
            setTimeout(keepSummaryContextOpaque, 120);
            setTimeout(keepSummaryContextOpaque, 500);
          }
        }, true);

        if (window.MutationObserver) {
          var summaryOpacityScheduled = false;
          var summaryOpacityObserver = new MutationObserver(function() {
            if (summaryOpacityScheduled) return;
            summaryOpacityScheduled = true;
            window.requestAnimationFrame(function() {
              summaryOpacityScheduled = false;
              keepSummaryContextOpaque();
            });
          });
          document.addEventListener('DOMContentLoaded', function() {
            var root = document.body || document.documentElement;
            if (root) {
              summaryOpacityObserver.observe(root, {
                subtree: true,
                attributes: true,
                attributeFilter: ['class', 'style']
              });
            }
          });
        }

        document.addEventListener('DOMContentLoaded', function() {
          initSummaryContextTooltips(document);
        });
        if (window.jQuery) {
          window.jQuery(document).on('shiny:value shiny:bound shiny:idle', function() {
            initSummaryContextTooltips(document);
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
                if (!activateNavTabImmediately(target) && window.Shiny && Shiny.setInputValue) {
                  Shiny.setInputValue('app_nav_click', target, { priority: 'event' });
                }
              }
            } else {
              setWorkflowPanel(null);
              setActiveNav(target);
              if (!isAlreadyActive && !activateNavTabImmediately(target) && window.Shiny && Shiny.setInputValue) {
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

            Shiny.addCustomMessageHandler('reset_color_palette_ui', function(message) {
              var defaultColors = {
                'color_exon': '#F45D75',
                'color_cds': '#E8A44F',
                'color_utr': '#5BC0EB',
                'color_gene': '#FFB7BF',
                'color_identity_high': '#CC2929',
                'color_identity_mid': '#E07858',
                'color_identity_low': '#5CB85C',
                'color_header_gene': '#2C3E50',
                'color_header_transcript': '#24445B'
              };
              for (var id in defaultColors) {
                var el = document.getElementById(id);
                if (el) el.value = defaultColors[id];
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
                        label = "Annotation file",
                        accept = c(".gff", ".gff3", ".gtf", ".txt")
                      ),
                      fileInput(
                        inputId = "genome_fasta1",
                        label = "Genome FASTA/2bit file",
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
                    class = "app-hidden-query",
                    tags$datalist(id = "filter1_suggestions"),
                    div(
                      htmltools::tagAppendAttributes(
                        textInput(
                          inputId = "filter1",
                          label = "Search gene",
                          placeholder = "Enter gene name"
                        ),
                        list = "filter1_suggestions"
                      )
                    ),
                    uiOutput("homo_visual_mode_ui")
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
                          initial_homo_species_grid
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
                          choices = c("Preloaded organisms" = "preloaded", "NCBI Search" = "ncbi", "Upload files" = "upload", "Mixed sources" = "mixed"),
                          selected = "preloaded",
                          inline = TRUE
                        ),
                        class = "viz-mode-toggle"
                      )
                    ),
                    conditionalPanel(
                      condition = "input.ortho_data_mode == 'upload' || input.ortho_data_mode == 'mixed'",
                      fileInput(
                        inputId = "files",
                        label = "Annotation files",
                        multiple = TRUE,
                        accept = c(".gff", ".gff3", ".gtf", ".txt")
                      ),
                      fileInput(
                        inputId = "genome_fasta_ortho",
                        label = "Genome FASTA/2bit files",
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
                      condition = "input.ortho_data_mode == 'ncbi' || input.ortho_data_mode == 'mixed'",
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
                    class = "app-hidden-query",
                    tags$datalist(id = "gene_name_suggestions"),
                    div(
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
                            "Aligned synteny" = "aligned",
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
                          condition = "input.ortho_data_mode == 'preloaded' || input.ortho_data_mode == 'mixed'",
                          initial_ortho_species_grid
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
        tags$button(type = "button", class = "app-nav-btn", `data-target` = "guide", title = "CGV Guide", icon("route"), span("CGV Guide")),
        tags$button(type = "button", class = "app-nav-btn", `data-target` = "settings", title = "Settings", icon("cog"), span("Settings")),

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
          title = "CGV Guide",
          value = "guide",
          div(
            class = "content-wrapper app-main-pane app-guide-pane",
            div(
              class = "guide-paths",
              div(
                class = "guide-path-card",
                span(class = "guide-path-icon", icon("search")),
                h2("Guide for Multi-Gene Search"),
                p("Use this path when you want to inspect several genes inside one selected organism."),
                tags$button(
                  type = "button",
                  class = "guide-primary-btn",
                  onclick = "document.getElementById('guide-multi-path').scrollIntoView({behavior:'smooth', block:'start'});",
                  icon("list-ol"),
                  "See Multi-Gene steps"
                )
              ),
              div(
                class = "guide-path-card",
                span(class = "guide-path-icon", icon("sitemap")),
                h2("Guide for Cross-Species Search"),
                p("Use this path when you want to compare one gene across multiple organisms or assemblies."),
                tags$button(
                  type = "button",
                  class = "guide-secondary-btn",
                  onclick = "document.getElementById('guide-cross-path').scrollIntoView({behavior:'smooth', block:'start'});",
                  icon("list-ol"),
                  "See Cross-Species steps"
                )
              )
            ),
            div(
              class = "guide-hero",
              div(
                class = "guide-video-shell",
                div(
                  class = "guide-video-topbar",
                  span(class = "guide-kicker", icon("play-circle"), "CGV Guided Tour"),
                  span(class = "guide-duration", "Main screencast")
                ),
                div(
                  class = "guide-video-frame",
                  tags$video(
                    controls = NA,
                    preload = "metadata",
                    tags$source(src = "screencasts/guide-intro.mp4", type = "video/mp4"),
                    "Your browser does not support embedded video."
                  )
                )
              ),
              div(
                class = "guide-intro-panel",
                span(class = "guide-kicker", icon("compass"), "Start here"),
                h1(class = "guide-title", "Run your first comparative gene analysis"),
                p(
                  class = "guide-subtitle",
                  "This guide walks new users through the complete CGV workflow: choose a mode, search genes, select organisms, generate visualizations, interpret results, and export figures."
                ),
                div(
                  class = "guide-actions",
                  tags$button(
                    type = "button",
                    class = "guide-primary-btn",
                    onclick = "document.querySelector('.app-nav-btn[data-target=\"homologous\"]').click();",
                    icon("search"),
                    "Start Multi-Gene"
                  ),
                  tags$button(
                    type = "button",
                    class = "guide-secondary-btn",
                    onclick = "document.querySelector('.app-nav-btn[data-target=\"orthologous\"]').click();",
                    icon("sitemap"),
                    "Start Cross-Species"
                  )
                )
              )
            ),
            div(
              id = "guide-multi-path",
              class = "guide-flow-section",
              h2(class = "guide-flow-title", icon("search"), "Multi-Gene Search path"),
              div(
              class = "guide-flow",
              div(class = "guide-step-card",
                div(class = "guide-step-head", span(class = "guide-step-number", "01"), icon("route")),
                h3("Open Multi-Gene Search"),
                p("Choose this workflow when the analysis is centered on one organism and several genes."),
                tags$button(type = "button", class = "guide-step-link", onclick = "document.querySelector('.app-nav-btn[data-target=\"homologous\"]').click();", "Open workflow")
              ),
              div(class = "guide-step-card",
                div(class = "guide-step-head", span(class = "guide-step-number", "02"), icon("database")),
                h3("Select the data source"),
                p("Start with a preloaded organism, search NCBI, or upload annotation and genome files."),
                tags$button(type = "button", class = "guide-step-link", onclick = "document.querySelector('.app-nav-btn[data-target=\"homologous\"]').click();", "See data options")
              ),
              div(class = "guide-step-card",
                div(class = "guide-step-head", span(class = "guide-step-number", "03"), icon("dna")),
                h3("Pick the organism"),
                p("Select the organism before searching so CGV knows which annotation set to inspect."),
                tags$button(type = "button", class = "guide-step-link", onclick = "document.querySelector('.app-nav-btn[data-target=\"homologous\"]').click();", "Open organism panel")
              ),
              div(class = "guide-step-card",
                div(class = "guide-step-head", span(class = "guide-step-number", "04"), icon("keyboard")),
                h3("Search and add genes"),
                p("Type a gene name, use autocomplete suggestions, and add genes to the batch when working in Multi-Gene mode."),
                tags$button(type = "button", class = "guide-step-link", onclick = "document.querySelector('.app-nav-btn[data-target=\"homologous\"]').click();", "Try a search")
              )
              )
            ),
            div(
              id = "guide-cross-path",
              class = "guide-flow-section",
              h2(class = "guide-flow-title", icon("sitemap"), "Cross-Species Gene Search path"),
              div(
                class = "guide-flow",
              div(class = "guide-step-card",
                div(class = "guide-step-head", span(class = "guide-step-number", "01"), icon("sitemap")),
                h3("Open Cross-Species Search"),
                p("Choose this workflow when you want to compare one selected gene across organisms."),
                tags$button(type = "button", class = "guide-step-link", onclick = "document.querySelector('.app-nav-btn[data-target=\"orthologous\"]').click();", "Open workflow")
              ),
              div(class = "guide-step-card",
                div(class = "guide-step-head", span(class = "guide-step-number", "02"), icon("database")),
                h3("Choose data source"),
                p("Use preloaded organisms, search NCBI, or upload multiple annotation and genome file pairs."),
                tags$button(type = "button", class = "guide-step-link", onclick = "document.querySelector('.app-nav-btn[data-target=\"orthologous\"]').click();", "See data options")
              ),
              div(class = "guide-step-card",
                div(class = "guide-step-head", span(class = "guide-step-number", "03"), icon("dna")),
                h3("Select organisms"),
                p("Build the comparison set so CGV can search the same gene across the selected organisms."),
                tags$button(type = "button", class = "guide-step-link", onclick = "document.querySelector('.app-nav-btn[data-target=\"orthologous\"]').click();", "Open species panel")
              ),
              div(class = "guide-step-card",
                div(class = "guide-step-head", span(class = "guide-step-number", "04"), icon("play")),
                h3("Generate visualization"),
                p("Run the search, inspect aligned or compact outputs, review analytics, and export the final figures."),
                tags$button(type = "button", class = "guide-step-link", onclick = "document.querySelector('.app-nav-btn[data-target=\"orthologous\"]').click();", "Generate")
              )
              )
            )
          )
        ),
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
                    class = "home-cta-btn",
                    onclick = "document.querySelector('.app-nav-btn[data-target=\"guide\"]').click();",
                    span(class = "home-cta-icon-wrap", icon("route")),
                    span(
                      class = "home-cta-copy",
                      span(class = "home-cta-title", "CGV Guide"),
                      span(class = "home-cta-note", "Follow the guided workflow from start to export.")
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

            # ── 2. Search Modes ────────────────────────────────────────────────
            div(
              class = "home-section home-reveal",
              p(class = "home-section-title", icon("random"), "Search Modes"),
              p(
                class = "home-section-sub",
                "Two complementary modes for different research questions. Each offers visualization and alignment modes adapted to its scope."
              ),
              div(
                class = "help-mode-grid home-stagger-parent",
                div(
                  class = "help-mode-card home-stagger-child",
                  div(class = "help-mode-card-icon", icon("search")),
                  tags$h4("Multi-Gene Search"),
                  tags$p("Inspect and compare multiple annotated genes within one organism side by side. Ideal for structural review across isoforms and paralogs."),
                  tags$ul(
                    tags$li("Visualize: Compact and Detailed views for all genes."),
                    tags$li("Align transcripts: when a gene has multiple isoforms, align them with comparative synteny to identify exon correspondence."),
                    tags$li("Access all 10 analytics chart types, plus batch SVG export.")
                  )
                ),
                div(
                  class = "help-mode-card home-stagger-child",
                  div(class = "help-mode-card-icon", icon("dna")),
                  tags$h4("Cross-Species Gene Search"),
                  tags$p("Compare one gene across multiple organisms with representative models aligned side by side. Designed for cross-species structural analysis."),
                  tags$ul(
                    tags$li("Visualize: Compact and Detailed views for all organisms."),
                    tags$li("Align across species: synteny, LASTZ Blocks, and Multi-PIP to compare exon structure and genomic conservation."),
                    tags$li("Exon-level event labeling: conservation, duplication (1:n, n:1), loss, and partial matches.")
                  )
                )
              )
            ),

            # ── 3. Visualization & Alignment ──────────────────────────────────
            div(
              class = "home-section home-reveal",
              p(class = "home-section-title", icon("eye"), "Visualization & Alignment"),
              p(
                class = "home-section-sub",
                "Each search mode has two top-level modes: Visualize (explore gene models) and Alignment (compare structures). Within Alignment, choose a strategy and a sequence type."
              ),

              # ── Visualization mode ─────────────────────────────────────────
              p(style = "margin-top: 18px; font-size: 13px; font-weight: 700; color: #22364a;", icon("eye"), " Visualize mode"),
              tags$p(style = "font-size: 12.5px; color: #566c7f; margin: 4px 0 12px 0;", "Gene structure inspection \u2014 available in both search modes."),
              div(
                class = "help-views-grid home-stagger-parent",
                div(
                  class = "help-view-card home-stagger-child",
                  div(class = "help-view-card-icon", icon("compress-arrows-alt")),
                  tags$h4("Compact"),
                  tags$p("Minimalist gene structure panel. Fits many genes on screen. Ideal for first-pass inspection."),
                  span(class = "help-view-badge help-view-badge-both", "Both modes")
                ),
                div(
                  class = "help-view-card home-stagger-child",
                  div(class = "help-view-card-icon", icon("list-alt")),
                  tags$h4("Detailed"),
                  tags$p("Full annotation with exons, CDS, UTR, strand, coordinates and zoom. Best for thorough single-gene review."),
                  span(class = "help-view-badge help-view-badge-both", "Both modes")
                )
              ),

              # ── Alignment mode ──────────────────────────────────────────
              p(style = "margin-top: 20px; font-size: 13px; font-weight: 700; color: #22364a;", icon("project-diagram"), " Alignment mode"),
              tags$p(style = "font-size: 12.5px; color: #566c7f; margin: 4px 0 12px 0;", "Compare structures across transcripts (Multi-Gene) or across species (Cross-Species). Alignment mode becomes available once the required data is loaded."),

              # ── Multi-Gene alignment ────────────────────────────────────
              div(
                class = "help-split-grid home-stagger-parent",
                div(
                  class = "help-mini-card home-stagger-child",
                  tags$h4(icon("search"), " Multi-Gene: Align Transcripts"),
                  tags$p("When a gene has two or more transcript isoforms, align them with comparative synteny to identify which exon corresponds to which."),
                  tags$ul(
                    tags$li(tags$strong("Synteny"), " \u2014 pairwise representative alignment with exon correspondence ribbons and event labels (conserved, split, fusion, loss, partial).")
                  ),
                  tags$p(style = "font-size: 11px; color: #7a8a9a; margin-top: 6px;", icon("info-circle"), " Available when at least one loaded gene has multiple transcripts.")
                ),
                div(
                  class = "help-mini-card home-stagger-child",
                  tags$h4(icon("dna"), " Cross-Species: Align Across Organisms"),
                  tags$p("Compare one gene\u2019s representative transcript across organisms with three alignment strategies:"),
                  tags$ul(
                    tags$li(tags$strong("Synteny"), " \u2014 representative transcript alignment with annotated exon correspondence ribbons and event-type labels."),
                    tags$li(tags$strong("LASTZ Blocks"), " \u2014 local pairwise alignment blocks showing conserved regions between the query and each reference."),
                    tags$li(tags$strong("Multi-PIP"), " \u2014 Percent Identity Plot across the genomic window for conservation patterns.")
                  ),
                  tags$p(style = "font-size: 11px; color: #7a8a9a; margin-top: 6px;", icon("info-circle"), " Available after loading at least two organism tracks.")
                )
              ),

              # ── Alignment sequence types ────────────────────────────────
              p(style = "margin-top: 18px; font-size: 13px; font-weight: 700; color: #22364a;", icon("align-center"), " Sequence types (Synteny alignment)"),
              tags$p(style = "font-size: 12.5px; color: #566c7f; margin: 4px 0 12px 0;", "All Synteny alignments use Needleman-Wunsch global alignment. Choose the sequence representation that best fits your evolutionary distance:"),
              div(
                class = "help-align-grid home-stagger-parent",
                div(
                  class = "help-align-card home-stagger-child",
                  div(class = "help-align-card-head",
                    div(class = "help-align-card-icon", icon("atom")),
                    tags$strong("Translated CDS")
                  ),
                  tags$p("Aligns protein translations. Best for detecting conserved coding regions across divergent genomes."),
                  span(class = "help-align-matrix", "BLOSUM62")
                ),
                div(
                  class = "help-align-card home-stagger-child",
                  div(class = "help-align-card-head",
                    div(class = "help-align-card-icon", icon("dna")),
                    tags$strong("CDS Nucleotide")
                  ),
                  tags$p("Aligns nucleotide CDS directly. Useful for closely related species where nucleotide identity is high."),
                  span(class = "help-align-matrix", "EDNAFULL")
                ),
                div(
                  class = "help-align-card home-stagger-child",
                  div(class = "help-align-card-head",
                    div(class = "help-align-card-icon", icon("layer-group")),
                    tags$strong("Exon")
                  ),
                  tags$p("Aligns full exon sequences including UTRs. Captures structural variation beyond CDS, suitable for lncRNA comparisons."),
                  span(class = "help-align-matrix", "EDNAFULL")
                )
              ),
              p(style = "margin-top:8px; font-size:12px; color:#566c7f;",
                icon("info-circle"), " Configurable window sizes for LASTZ Blocks and Multi-PIP: gene body, \u00b15 kb, \u00b110 kb, \u00b125 kb, \u00b150 kb.")
            ),

            # ── 4. Understanding Results ──────────────────────────────────────
            div(
              class = "home-section home-reveal",
              p(class = "home-section-title", icon("chart-bar"), "Understanding Results"),
              p(
                class = "home-section-sub",
                "CGV returns multiple output layers. Each adds a different level of depth to your analysis."
              ),
              div(
                class = "help-split-grid home-stagger-parent",
                div(
                  class = "help-mini-card home-stagger-child",
                  tags$h4(icon("th-large"), " Gene cards"),
                  tags$ul(
                    tags$li("One card per gene with structure plot (exons, CDS, UTR, strand, zoom, hoverable coordinates)."),
                    tags$li("Metrics: transcript length, CDS length, protein length (aa), GC%, exon/intron counts, biotype."),
                    tags$li("Quick-action links for alias resolution and direct sequence actions.")
                  )
                ),
                div(
                  class = "help-mini-card home-stagger-child",
                  tags$h4(icon("mouse-pointer"), " Gene card popups"),
                  tags$ul(
                    tags$li(tags$strong("Metrics popup"), " \u2014 nucleotide composition donut, isoform comparison chart, genomic context scatter."),
                    tags$li(tags$strong("GO Annotations"), " \u2014 Gene Ontology terms from local files or live Ensembl lookup."),
                    tags$li(tags$strong("Papers"), " \u2014 recent publications via Europe PMC."),
                    tags$li(tags$strong("Promoter"), " \u2014 upstream region FASTA (100\u20135,000 bp) with coordinate export.")
                  )
                ),
                div(
                  class = "help-mini-card home-stagger-child",
                  tags$h4(icon("table"), " Summary Table"),
                  tags$ul(
                    tags$li("Sortable and filterable. Columns: gene, transcript, chromosome, strand, exon count, lengths, organism."),
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

            # ── 5. Preloaded Reference Genomes ────────────────────────────────
            div(
              class = "home-section home-reveal",
              p(class = "home-section-title", icon("globe"), "Preloaded Reference Genomes"),
              p(
                class = "home-section-sub",
                "CGV ships with reference genome assemblies and NCBI RefSeq annotations covering three kingdoms. You can also upload custom genomes."
              ),
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
                      "A. thaliana, A. lyrata, Z. mays (2 assemblies), O. sativa (2), S. lycopersicum, S. tuberosum, S. pennellii, H. vulgare, P. vulgaris, B. distachyon")
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
                    tags$h4(style = "margin:0 0 5px 0; font-size:13px; font-weight:700; color:#22364a;", "Upload your own genome"),
                    tags$p(style = "margin:0; font-size:12px; color:#566c7f;",
                      "Provide a genome file (", tags$code(".fa"), ", ", tags$code(".fa.gz"), ", ", tags$code(".fna"), ", ", tags$code(".2bit"), ") and a matching annotation (",
                      tags$code(".gff3"), ", ", tags$code(".gtf"), "). You can mix uploaded and preloaded organisms in the same analysis.")
                  )
                )
              )
            ),

            # ── 6. Export & Sessions ──────────────────────────────────────────
            div(
              class = "home-section home-reveal",
              p(class = "home-section-title", icon("download"), "Export & Sessions"),
              p(
                class = "home-section-sub",
                "Multiple output options for publications, data pipelines, and workspace persistence."
              ),
              div(
                class = "help-export-grid home-stagger-parent",
                div(class = "help-export-card home-stagger-child",
                  div(class = "help-export-icon", icon("image")),
                  div(tags$strong("SVG"), tags$small("Individual chart or gene structure vector export"))
                ),
                div(class = "help-export-card home-stagger-child",
                  div(class = "help-export-icon", icon("file-zipper")),
                  div(tags$strong("ZIP"), tags$small("Batch export analytics charts or gene structure plots as SVGs"))
                ),
                div(class = "help-export-card home-stagger-child",
                  div(class = "help-export-icon", icon("table")),
                  div(tags$strong("CSV"), tags$small("Summary table: lengths, exon/intron counts, GC%, coordinates"))
                ),
                div(class = "help-export-card home-stagger-child",
                  div(class = "help-export-icon", icon("dna")),
                  div(tags$strong("FASTA \u2014 promoter"), tags$small("Configurable upstream region (100\u20135,000 bp)"))
                ),
                div(class = "help-export-card home-stagger-child",
                  div(class = "help-export-icon", icon("rotate-left")),
                  div(tags$strong("Session (.rds)"), tags$small("Save and restore the full workspace from Settings"))
                )
              )
            ),

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
            ),

            # ── 10. Troubleshooting & Tips ──────────────────────────────────────
            div(
              class = "home-section home-reveal",
              p(class = "home-section-title", icon("wrench"), "Troubleshooting & Tips"),
              p(
                class = "home-section-sub",
                "Most issues come from query spelling, organism selection, or annotation structure. This section covers the most common checks."
              ),
              div(
                class = "help-split-grid home-stagger-parent",
                div(
                  class = "help-mini-card home-stagger-child",
                  tags$h4(icon("upload"), " Data inputs"),
                  tags$ul(
                    tags$li("Uploads require a genome file in ", tags$code(".fa"), ", ", tags$code(".fa.gz"), ", or ", tags$code(".2bit"), " plus a matching annotation in ", tags$code(".gff3"), " or ", tags$code(".gtf"), "."),
                    tags$li("You can mix preloaded references with uploaded organisms in the same analysis."),
                    tags$li("CGV currently ships with more than two dozen preloaded organism references.")
                  )
                ),
                div(
                  class = "help-mini-card",
                  tags$h4(icon("search"), " If a gene is missing"),
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
                  tags$h4(icon("bolt"), " Performance tips"),
                  tags$ul(
                    tags$li("Start with fewer organisms or genes, then scale up once the first view looks correct."),
                    tags$li("Use the summary table to narrow what you inspect before opening all analytics panels."),
                    tags$li("Reorder charts when the plot count grows so comparisons stay readable.")
                  )
                ),
                div(
                  class = "help-mini-card home-stagger-child",
                  tags$h4(icon("save"), " Sessions and display settings"),
                  tags$ul(
                    tags$li("Export your current work session as ", tags$code(".rds"), " when you want to resume later."),
                    tags$li("Restore a saved session from Settings to recover plots and configuration."),
                    tags$li("Theme, dark mode, and colorblind options can help readability for dense figure review.")
                  )
                )
              )
            ),

            # ── 11. FAQ ──────────────────────────────────────────────────────────
            div(
              class = "home-section home-reveal",
              p(class = "home-section-title", icon("question-circle"), "Frequently Asked Questions"),
              div(
                class = "help-faq-list home-stagger-parent",
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
                      tags$p("CGV is designed for gene-centered structural comparison. It excels at examining exon/intron architecture, comparing representative gene models across species, exploring transcript isoforms, and producing publication-ready figures \u2014 all within a single guided interface, without requiring any scripting.")
                    )
                  )
                ),
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
                        tags$li(tags$strong("1:1"), " \u2014 single conserved exon correspondence."),
                        tags$li(tags$strong("1:n / n:1"), " \u2014 exon split or fusion events."),
                        tags$li(tags$strong("Partial"), " \u2014 partial overlap between exons."),
                        tags$li(tags$strong("Lost"), " \u2014 exon present in one organism, absent in the other.")
                      )
                    )
                  )
                ),
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
                        tags$li(tags$strong("Translated CDS (BLOSUM62)"), " \u2014 recommended for distantly related species where nucleotide identity is low but protein function is conserved."),
                        tags$li(tags$strong("CDS Nucleotide (EDNAFULL)"), " \u2014 best for closely related species where the coding sequence at nucleotide level is still similar."),
                        tags$li(tags$strong("Exon (EDNAFULL)"), " \u2014 aligns the full exon including UTR regions. Useful for lncRNAs or when UTR conservation is of interest.")
                      )
                    )
                  )
                ),
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
                        tags$li(tags$strong("Metrics"), " \u2014 nucleotide composition donut, isoform length comparison, and genomic context scatter."),
                        tags$li(tags$strong("GO Annotations"), " \u2014 Gene Ontology terms sourced from local annotation files, with live fallback to Ensembl."),
                        tags$li(tags$strong("Papers"), " \u2014 recent publications retrieved from Europe PMC for that gene and organism."),
                        tags$li(tags$strong("Promoter"), " \u2014 configurable upstream region (100\u20135,000 bp) shown as FASTA sequence with coordinate export.")
                      )
                    )
                  )
                ),
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
                        tags$li(tags$strong("SVG"), " \u2014 individual chart or gene structure plot export."),
                        tags$li(tags$strong("ZIP"), " \u2014 batch export of analytics chart SVGs or gene structure plot SVGs."),
                        tags$li(tags$strong("CSV"), " \u2014 summary table with lengths, exon/intron counts, GC%, and coordinates."),
                        tags$li(tags$strong("FASTA"), " \u2014 promoter region sequences with configurable window (100\u20135,000 bp)."),
                        tags$li(tags$strong("Session (.rds)"), " \u2014 saves the full workspace. Restore it any time from Settings \u2192 Session Management.")
                      )
                    )
                  )
                ),
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
                        tags$li("No organism is selected for the current search \u2014 at least one must be active."),
                        tags$li("For uploaded data, the annotation file may not contain the expected gene identifier or a matching transcript feature.")
                      ),
                      tags$p("Tip: enable external alias lookup (MyGene, NCBI Gene, UniProt, or Ensembl) in Settings to automatically resolve alternative names and IDs.")
                    )
                  )
                ),
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
                      tags$p("Genome browsers are built for locus navigation and broad genomic context. Plotting packages require scripted figure generation. CGV occupies a different space: guided, gene-first comparison with cross-species alignment, 10 analytics charts, popup information layers (GO, papers, promoter), and multiple export formats \u2014 all without writing code.")
                    )
                  )
                ),
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
                      value = "arch",
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
                      value = "exon",
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
                      value = "seq",
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
                      value = "context",
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
                      value = "exon_dist",
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
                      value = "scatter",
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
                      value = "heatmap",
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
                      value = "radar",
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
                      value = "corr",
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
                uiOutput("homo_special_cards_ui"),
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
                      value = "arch",
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
                      value = "exon",
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
                      value = "seq",
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
                      value = "context",
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
                      value = "exon_dist",
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
                      value = "scatter",
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
                      value = "heatmap",
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
                      value = "radar",
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
                      value = "corr",
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
                        span("MultiPIP-style View")
                      ),
                      div(
                        style = "display:flex; align-items:center; gap:8px;",
                        tags$button(
                          class = "btn btn-sm btn-export-svg",
                          title = "Export plot as SVG",
                          onclick = "exportAlignmentSVG('ortho_multipip_plot_out', 'multipip_style_view')",
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
                ),
                # ── Color Palette Customization ────────────────────────────
                div(
                  class = "color-palette-section",
                  div(
                    class = "palette-group",
                    h4(icon("palette"), span("Transcript Features")),
                    p("Customize colors for gene model elements."),
                    div(
                      class = "palette-row",
                      div(class = "palette-item",
                          tags$label(`for` = "color_exon", "Exon"),
                          tags$input(type = "color", id = "color_exon", class = "color-input", value = "#F45D75")),
                      div(class = "palette-item",
                          tags$label(`for` = "color_cds", "CDS"),
                          tags$input(type = "color", id = "color_cds", class = "color-input", value = "#E8A44F")),
                      div(class = "palette-item",
                          tags$label(`for` = "color_utr", "UTR"),
                          tags$input(type = "color", id = "color_utr", class = "color-input", value = "#5BC0EB")),
                      div(class = "palette-item",
                          tags$label(`for` = "color_gene", "Gene"),
                          tags$input(type = "color", id = "color_gene", class = "color-input", value = "#FFB7BF"))
                    )
                  ),
                  div(
                    class = "palette-group",
                    h4(icon("layer-group"), span("LASTZ Identity")),
                    p("Colors for alignment fragments by identity percentage."),
                    div(
                      class = "palette-row",
                      div(class = "palette-item",
                          tags$label(`for` = "color_identity_high", "High (≥80%)"),
                          tags$input(type = "color", id = "color_identity_high", class = "color-input", value = "#CC2929")),
                      div(class = "palette-item",
                          tags$label(`for` = "color_identity_mid", "Medium (50-79%)"),
                          tags$input(type = "color", id = "color_identity_mid", class = "color-input", value = "#E07858")),
                      div(class = "palette-item",
                          tags$label(`for` = "color_identity_low", "Low (<50%)"),
                          tags$input(type = "color", id = "color_identity_low", class = "color-input", value = "#5CB85C"))
                    )
                  ),
                  div(
                    class = "palette-group",
                    h4(icon("rectangle-wide"), span("Card Headers")),
                    p("Background gradient colors for gene and transcript headers."),
                    div(
                      class = "palette-row",
                      div(class = "palette-item",
                          tags$label(`for` = "color_header_gene", "Gene header"),
                          tags$input(type = "color", id = "color_header_gene", class = "color-input", value = "#2C3E50")),
                      div(class = "palette-item",
                          tags$label(`for` = "color_header_transcript", "Transcript header"),
                          tags$input(type = "color", id = "color_header_transcript", class = "color-input", value = "#24445B"))
                    )
                  ),
                  div(
                    class = "palette-reset-row",
                    actionButton("reset_color_palette", label = span("Reset to defaults"), icon = icon("rotate-left"), class = "btn btn-sm btn-reset-palette")
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
          title = "Feedback",
          value = "feedback",
          div(
            class = "content-wrapper app-main-pane app-settings-pane",
            div(
              class = "help-content settings-content feedback-shell",

              # ── Inline CSS for new animated elements ──────────────────────

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
            `data-label` = "Display mode",
            `aria-label` = "Display mode",
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
          div(class = "app-fab-panel-title", icon("sliders"), span("Display mode")),
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
