(function () {
  "use strict";

  if (window.CGVSharedAnalysis) return;

  var STORAGE_KEY = "cgv.sharedReports.v1";
  var latestUrl = "";
  var modeRestoreByRequest = {};
  var preLastzCaptureByRequest = {};
  var preSyntenyCaptureByRequest = {};
  var reportCaptureRequested = false;

  function readReceipts() {
    try {
      var parsed = JSON.parse(window.localStorage.getItem(STORAGE_KEY) || "[]");
      return Array.isArray(parsed) ? parsed : [];
    } catch (err) {
      return [];
    }
  }

  function writeReceipts(items) {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(items.slice(0, 100)));
    } catch (err) {}
  }

  function escapeText(value) {
    return String(value == null ? "" : value);
  }

  function asArray(value) {
    if (Array.isArray(value)) return value;
    if (value === null || value === undefined || value === "") return [];
    return [value];
  }

  function sendReportProgress(requestId, message) {
    if (!window.Shiny || typeof window.Shiny.setInputValue !== "function") return;
    window.Shiny.setInputValue("cgv_report_progress", {
      request_id: String(requestId || ""),
      message: String(message || "").slice(0, 240),
      nonce: Date.now() + Math.random()
    }, { priority: "event" });
  }

  function renderReceipts() {
    var root = document.getElementById("cgv-shared-report-list");
    if (!root) return;
    var items = readReceipts();
    root.textContent = "";
    if (!items.length) {
      var empty = document.createElement("p");
      empty.className = "app-submenu-hint";
      empty.textContent = "No secret reports have been created in this browser.";
      root.appendChild(empty);
      return;
    }
    items.forEach(function (item) {
      var row = document.createElement("div");
      row.className = "cgv-shared-report-row";

      var info = document.createElement("div");
      info.className = "cgv-shared-report-info";
      var link = document.createElement("a");
      link.href = escapeText(item.url);
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.textContent = "Open report";
      info.appendChild(link);
      var meta = document.createElement("span");
      meta.textContent = "Expires " + escapeText(item.expires_at || "automatically");
      info.appendChild(meta);
      row.appendChild(info);

      var actions = document.createElement("div");
      actions.className = "cgv-shared-report-actions";
      var copy = document.createElement("button");
      copy.type = "button";
      copy.className = "btn btn-xs btn-default";
      copy.textContent = "Copy";
      copy.addEventListener("click", function () {
        copyText(item.url);
      });
      actions.appendChild(copy);

      var revoke = document.createElement("button");
      revoke.type = "button";
      revoke.className = "btn btn-xs btn-danger";
      revoke.textContent = "Revoke";
      revoke.addEventListener("click", function () {
        if (!window.confirm("Revoke this secret report now? This cannot be undone.")) return;
        if (window.Shiny && typeof window.Shiny.setInputValue === "function") {
          window.Shiny.setInputValue("revoke_shared_report", {
            token: item.token,
            revoke_secret: item.revoke_secret,
            nonce: Date.now() + Math.random()
          }, { priority: "event" });
        }
      });
      actions.appendChild(revoke);
      row.appendChild(actions);
      root.appendChild(row);
    });
  }

  function copyText(text) {
    var value = escapeText(text);
    if (!value) return Promise.resolve(false);
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(value).then(function () { return true; });
    }
    var input = document.createElement("textarea");
    input.value = value;
    input.setAttribute("readonly", "readonly");
    input.style.position = "fixed";
    input.style.opacity = "0";
    document.body.appendChild(input);
    input.select();
    var ok = false;
    try { ok = document.execCommand("copy"); } catch (err) {}
    input.remove();
    return Promise.resolve(ok);
  }

  function normalizeSvg(svgElement) {
    if (!svgElement) return "";
    var clone = svgElement.cloneNode(true);
    clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
    clone.querySelectorAll("script, foreignObject, iframe, object, embed, .ggiraph-toolbar, .girafe-toolbar").forEach(function (node) {
      node.remove();
    });
    clone.querySelectorAll("*").forEach(function (node) {
      Array.prototype.slice.call(node.attributes || []).forEach(function (attr) {
        if (/^on/i.test(attr.name)) node.removeAttribute(attr.name);
        if (/^(?:href|xlink:href)$/i.test(attr.name) && /^(?:javascript:|https?:|\/\/)/i.test(String(attr.value || "").trim())) {
          node.removeAttribute(attr.name);
        }
      });
      node.removeAttribute("tabindex");
      node.removeAttribute("focusable");
    });
    if (!clone.getAttribute("viewBox")) {
      var width = parseFloat(clone.getAttribute("width")) || 1200;
      var height = parseFloat(clone.getAttribute("height")) || 520;
      clone.setAttribute("viewBox", "0 0 " + width + " " + height);
    }
    clone.removeAttribute("width");
    clone.removeAttribute("height");
    clone.setAttribute("preserveAspectRatio", "xMidYMid meet");
    return new XMLSerializer().serializeToString(clone);
  }

  function sourceContext(node) {
    if (!node || !node.closest) return "analysis";
    if (node.closest("#homo-plot-cards-container, #homologous_plots_ui, [id^='homo_']")) return "multi_gene";
    if (node.closest("#ortho-plot-cards-container, #orthologous_plots_ui, [id^='ortho_']")) return "cross_species";
    if (node.closest(".figure-studio-page")) return "figure_studio";
    return "analysis";
  }

  function sourceGroup(id, node) {
    var value = String(id || "").toLowerCase();
    var contextHint = "";
    if (node) {
      contextHint = [
        node.id || "",
        node.className || "",
        node.parentElement && node.parentElement.id || "",
        node.parentElement && node.parentElement.className || ""
      ].join(" ").toLowerCase();
    }
    value += " " + contextHint + " " + sourceTitle(node, id).toLowerCase();
    if (value.indexOf("figure_studio") >= 0 || (node && node.closest && node.closest(".figure-studio-page"))) return "figure_studio";
    if (/chromosome|ideogram|karyotype|genomic[_ -]?location/.test(value)) return "chromosome_context";
    if (/synteny|aligned[_ -]?plot|aligned synteny/.test(value)) return "synteny";
    if (/multipip|pip_plot|lastz/.test(value)) return "alignment";
    if (/arch|exon|seq_chart|context_chart|dist|scatter|heatmap|radar|corr/.test(value)) return "analytics";
    return "structural";
  }

  function sourceTitle(container, id) {
    var card = container && container.closest ? container.closest(".card, .plot-transcript-card, article") : null;
    var heading = card && card.querySelector ? card.querySelector("h2, h3, h4, .card-title, .plot-card-title") : null;
    var text = heading ? String(heading.textContent || "").replace(/\s+/g, " ").trim() : "";
    if (!text) text = String(id || "CGV visualization").replace(/[_-]+/g, " ");
    return text.slice(0, 180);
  }

  function sourceRecordMeta(container) {
    var card = container && container.closest ?
      container.closest(".plot-transcript-card") : null;
    if (!card) {
      return {
        record_id: "",
        gene: "",
        transcript: "",
        organism: ""
      };
    }
    return {
      record_id: String(card.id || "")
        .replace(/^homo-card-/, "")
        .replace(/^ortho-card-/, "")
        .replace(/_c$/, ""),
      gene: String(card.getAttribute("data-gene-name") || "").trim(),
      transcript: String(card.getAttribute("data-transcript-id") || "").trim(),
      organism: String(card.getAttribute("data-organism-name") || "").trim()
    };
  }

  function sourceContainer(svg) {
    var current = svg && svg.parentElement;
    var fallback = null;
    while (current && current !== document.body) {
      var id = String(current.id || "");
      if (id && !fallback) fallback = current;
      if (id && /(?:_export|_chart|_out|_plot|card|aligned|synteny|multipip|pip)/i.test(id)) {
        return current;
      }
      current = current.parentElement;
    }
    return fallback || (svg && svg.parentElement) || svg;
  }

  function isChromosomeContextSvg(svg, markup) {
    var viewBox = String((svg && svg.getAttribute("viewBox")) || "").trim().split(/\s+/).map(Number);
    var width = viewBox.length === 4 ? viewBox[2] : Number(svg && svg.getAttribute("width"));
    var height = viewBox.length === 4 ? viewBox[3] : Number(svg && svg.getAttribute("height"));
    // Gene diagrams can legitimately contain the word "chromosome" and are
    // usually very wide. Only the dedicated ideogram carries this marker.
    return /chrGrad_|(?:id|class)=["'][^"']*ideogram/i.test(String(markup || "")) &&
      isFinite(width) && isFinite(height) && height > 0 && width / height >= 4;
  }

  function capturePageSvgs(maxTotalBytes, allowedContexts, captureMode) {
    var allowed = asArray(allowedContexts).map(function (context) {
      return String(context || "").toLowerCase();
    }).filter(Boolean);
    var contextAllowed = function (context) {
      return !allowed.length || allowed.indexOf(String(context || "").toLowerCase()) >= 0;
    };
    var selectors = [
      ".girafe_container_std > svg",
      ".ggiraph-svg > svg",
      "svg.ggiraph-svg",
      ".plot-transcript-card svg",
      "#ortho_aligned_plot_out svg",
      "[id*='synteny'] svg",
      "#ortho_pip_plot_out svg",
      "#ortho_multipip_plot_out svg",
      "#homo_aligned_plot_out svg",
      "#homo_pip_plot_out svg",
      "#homo_multipip_plot_out svg"
    ];
    var nodes = Array.prototype.slice.call(document.querySelectorAll(selectors.join(",")));
    var seen = new Set();
    var seenMarkup = new Set();
    var assets = [];
    var missing = [];
    var total = 0;
    nodes.forEach(function (svg, index) {
      if (seen.has(svg)) return;
      if (svg.closest && svg.closest("#cgv-report-capture-curtain")) return;
      seen.add(svg);
      if (captureMode === "fast") {
        var busyOutput = svg.closest && svg.closest(".recalculating");
        if (busyOutput) return;
      }
      var container = sourceContainer(svg);
      var id = String((container && container.id) || svg.id || ("figure_" + (index + 1)));
      if (/figure-studio-(?:canvas|preview)/.test(id)) return;
      var context = sourceContext(container);
      if (!contextAllowed(context)) return;
      var markup = normalizeSvg(svg);
      if (!markup) {
        missing.push(id + ": SVG could not be serialized");
        return;
      }
      if (seenMarkup.has(markup)) return;
      seenMarkup.add(markup);
      var bytes = new Blob([markup]).size;
      if (bytes > 4 * 1024 * 1024) {
        missing.push(id + ": figure exceeds 4 MB");
        return;
      }
      if (total + bytes > maxTotalBytes) {
        missing.push(id + ": total capture limit reached");
        return;
      }
      total += bytes;
      var group = sourceGroup(id, container);
      if (group === "structural" && isChromosomeContextSvg(svg, markup)) {
        group = "chromosome_context";
      }
      var recordMeta = sourceRecordMeta(container);
      assets.push({
        id: id,
        source_id: id,
        title: group === "chromosome_context" ? "Chromosome position" : sourceTitle(container, id),
        group: group,
        context: context,
        record_id: recordMeta.record_id,
        gene: recordMeta.gene,
        transcript: recordMeta.transcript,
        organism: recordMeta.organism,
        svg: markup
      });
    });

    if (contextAllowed("figure_studio") &&
        window.CGVFigureStudio &&
        typeof window.CGVFigureStudio.exportSnapshot === "function") {
      try {
        var studioSvg = window.CGVFigureStudio.exportSnapshot();
        if (studioSvg) {
          var studioBytes = new Blob([studioSvg]).size;
          if (total + studioBytes <= maxTotalBytes) {
            assets.push({
              id: "figure_studio_composition",
              source_id: "figure-studio",
              title: "Figure Studio composition",
              group: "figure_studio",
              context: "figure_studio",
              svg: studioSvg
            });
            total += studioBytes;
          } else {
            missing.push("Figure Studio: total capture limit reached");
          }
        }
      } catch (err) {
        missing.push("Figure Studio: " + (err && err.message ? err.message : "capture failed"));
      }
    }
    return { assets: assets, missing: missing, bytes: total };
  }

  function requestHiddenAnalytics(contexts) {
    if (!window.Shiny || typeof window.Shiny.setInputValue !== "function") return;
    var wanted = asArray(contexts).filter(function (context) {
      return context === "homo" || context === "ortho";
    });
    wanted.forEach(function (context) {
      window.Shiny.setInputValue(context + "_analytics_export_all_nonce", Date.now() + Math.random(), {
        priority: "event"
      });
    });
  }

  function hiddenAnalyticsState(context) {
    var bank = document.getElementById(context + "_analytics_export_bank");
    if (!bank) return { expected: 0, ready: 0, busy: 0 };
    var outputs = bank.querySelectorAll(".shiny-bound-output, [id$='_export']");
    var unique = [];
    Array.prototype.forEach.call(outputs, function (output) {
      if (output.id && unique.indexOf(output) < 0) unique.push(output);
    });
    return {
      expected: unique.length,
      ready: unique.filter(function (output) { return !!output.querySelector("svg"); }).length,
      busy: unique.filter(function (output) { return output.classList.contains("recalculating"); }).length
    };
  }

  function waitForHiddenAnalytics(contexts, callback) {
    var wanted = Array.isArray(contexts) ? contexts.filter(function (context) {
      return context === "homo" || context === "ortho";
    }) : [];
    if (!wanted.length) {
      window.setTimeout(function () { callback([]); }, 350);
      return;
    }
    var started = Date.now();
    var stable = 0;
    var previous = "";
    var timer = window.setInterval(function () {
      var states = wanted.map(function (context) {
        return { context: context, state: hiddenAnalyticsState(context) };
      });
      var signature = states.map(function (item) {
        return [item.context, item.state.expected, item.state.ready, item.state.busy].join(":");
      }).join("|");
      stable = signature === previous ? stable + 1 : 0;
      previous = signature;
      var complete = states.every(function (item) {
        return item.state.expected > 0 &&
          item.state.ready >= item.state.expected &&
          item.state.busy === 0;
      });
      if ((complete && stable >= 2) || Date.now() - started >= 15000) {
        window.clearInterval(timer);
        var missing = [];
        states.forEach(function (item) {
          if (item.state.expected === 0 || item.state.ready < item.state.expected) {
            missing.push(
              (item.context === "homo" ? "Multi-Gene" : "Cross-Species") +
              " analytics: " + item.state.ready + " of " + item.state.expected +
              " charts rendered before capture"
            );
          }
        });
        callback(missing);
      }
    }, 350);
  }

  function captureExternalResults() {
    var selectors = [
      "#go-terms-popup",
      "#papers-modal-overlay",
      ".string-network-modal"
    ];
    var seen = [];
    var results = [];
    document.querySelectorAll(selectors.join(",")).forEach(function (node, index) {
      if (seen.indexOf(node) >= 0) return;
      seen.push(node);
      var text = String(node.textContent || "").replace(/\s+/g, " ").trim();
      if (!text || /loading|searching/i.test(text) && text.length < 180) return;
      var heading = node.querySelector("h1, h2, h3, h4, .modal-title, [class*='title']");
      results.push({
        id: String(node.id || ("external_result_" + (index + 1))).slice(0, 120),
        title: String((heading && heading.textContent) || "External result").replace(/\s+/g, " ").trim().slice(0, 180),
        captured_text: text.slice(0, 100000)
      });
    });
    return results;
  }

  function finishHiddenAnalytics(contexts) {
    if (!window.Shiny || typeof window.Shiny.setInputValue !== "function") return;
    var wanted = asArray(contexts).filter(function (context) {
      return context === "homo" || context === "ortho";
    });
    (wanted.length ? wanted : ["homo", "ortho"]).forEach(function (context) {
      window.Shiny.setInputValue(context + "_analytics_export_done_nonce", Date.now() + Math.random(), {
        priority: "event"
      });
    });
  }

  function structuralTargets(message) {
    var raw = message && message.structural_targets || {};
    return ["homo", "ortho"].map(function (context) {
      return {
        context: context,
        ids: asArray(raw[context]).map(function (id) {
          return String(id || "");
        }).filter(Boolean)
      };
    }).filter(function (target) {
      return target.ids.length > 0;
    });
  }

  function requestStructuralFigures(targets) {
    if (!window.Shiny || typeof window.Shiny.setInputValue !== "function") return;
    targets.forEach(function (target) {
      window.Shiny.setInputValue("figure_studio_plot_render_request", {
        context: target.context,
        ids: target.ids,
        nonce: Date.now() + Math.random()
      }, { priority: "event" });
    });
  }

  function finishStructuralFigures(targets) {
    if (!window.Shiny || typeof window.Shiny.setInputValue !== "function") return;
    targets.forEach(function (target) {
      window.Shiny.setInputValue("figure_studio_plot_render_done", {
        context: target.context,
        ids: target.ids,
        nonce: Date.now() + Math.random()
      }, { priority: "event" });
    });
  }

  function waitForStructuralFigures(message, callback) {
    var targets = structuralTargets(message);
    if (!targets.length) {
      window.setTimeout(function () { callback([], []); }, 0);
      return;
    }
    // Most report figures already exist in the live result cards. Asking
    // Shiny to render every target again needlessly invalidates those cards
    // and can create a large memory spike in Desktop builds. Only request the
    // records that are actually absent after the report restores its mode.
    var pendingTargets = targets.map(function (target) {
      return {
        context: target.context,
        ids: target.ids.filter(function (id) {
          var card = document.getElementById(target.context + "-card-" + id);
          return !(card && card.querySelector("svg")) ||
            !!(card && card.querySelector(".recalculating"));
        })
      };
    }).filter(function (target) {
      return target.ids.length > 0;
    });
    if (!pendingTargets.length) {
      window.setTimeout(function () { callback([], []); }, 350);
      return;
    }
    var missingTargets = pendingTargets.map(function (target) {
      return {
        context: target.context,
        ids: target.ids.filter(function (id) {
          var card = document.getElementById(target.context + "-card-" + id);
          return !(card && card.querySelector("svg"));
        })
      };
    }).filter(function (target) {
      return target.ids.length > 0;
    });
    if (missingTargets.length) requestStructuralFigures(missingTargets);
    var started = Date.now();
    var stable = 0;
    var previous = "";
    var timer = window.setInterval(function () {
      var states = [];
      pendingTargets.forEach(function (target) {
        target.ids.forEach(function (id) {
          var card = document.getElementById(target.context + "-card-" + id);
          states.push({
            context: target.context,
            id: id,
            ready: !!(card && card.querySelector("svg")),
            busy: !!(card && card.querySelector(".recalculating"))
          });
        });
      });
      var signature = states.map(function (state) {
        return [state.context, state.id, state.ready ? 1 : 0, state.busy ? 1 : 0].join(":");
      }).join("|");
      stable = signature === previous ? stable + 1 : 0;
      previous = signature;
      var complete = states.length > 0 && states.every(function (state) {
        return state.ready && !state.busy;
      });
      if ((complete && stable >= 2) || Date.now() - started >= 30000) {
        window.clearInterval(timer);
        var missing = states.filter(function (state) {
          return !state.ready;
        }).map(function (state) {
          return (state.context === "homo" ? "Multi-Gene" : "Cross-Species") +
            " transcript " + state.id + ": structure did not render before capture";
        });
        callback(missing, missingTargets);
      }
    }, 350);
  }

  function captureForServer(message) {
    var captureStartedAt = Date.now();
    var requestId = String((message && message.request_id) || "");
    var limit = Number((message && message.max_total_bytes) || (24 * 1024 * 1024));
    var analyticsContexts = asArray(message && message.analytics_contexts);
    var captureMode = String((message && message.capture_mode) || "complete").toLowerCase();
    if (captureMode !== "fast") captureMode = "complete";

    var completeCapture = function (structuralMissing, analyticsMissing, preparedTargets) {
      sendReportProgress(requestId, "Serializing and transferring the captured report views…");
      var captured = capturePageSvgs(
        limit,
        message && message.capture_contexts,
        captureMode
      );
      var preCaptures = [preSyntenyCaptureByRequest[requestId], preLastzCaptureByRequest[requestId]];
      var preSyntenyMs = Number(preCaptures[0] && preCaptures[0].duration_ms || 0);
      var preLastzMs = Number(preCaptures[1] && preCaptures[1].duration_ms || 0);
      delete preSyntenyCaptureByRequest[requestId];
      delete preLastzCaptureByRequest[requestId];
      var queuedAssets = [];
      preCaptures.forEach(function (preCapture) {
        if (!preCapture) return;
        queuedAssets = queuedAssets.concat(preCapture.assets || []);
        captured.missing = (preCapture.missing || []).concat(captured.missing || []);
      });
      if (queuedAssets.length) {
        var mergedAssets = [];
        var mergedMarkup = new Set();
        var mergedBytes = 0;
        queuedAssets.concat(captured.assets).forEach(function (asset) {
          var markup = String(asset && asset.svg || "");
          if (!markup || mergedMarkup.has(markup)) return;
          var bytes = new Blob([markup]).size;
          if (mergedBytes + bytes > limit) {
            captured.missing.push((asset.title || asset.id || "Figure") + ": total capture limit reached while merging report views");
            return;
          }
          mergedMarkup.add(markup);
          mergedAssets.push(asset);
          mergedBytes += bytes;
        });
        captured.assets = mergedAssets;
        captured.bytes = mergedBytes;
      }
      captured.missing = structuralMissing.concat(analyticsMissing, captured.missing || []);
      if (captureMode === "complete") {
        finishStructuralFigures(preparedTargets);
        finishHiddenAnalytics(analyticsContexts);
      }
      if (window.Shiny && typeof window.Shiny.setInputValue === "function") {
        window.Shiny.setInputValue("cgv_analysis_assets", {
          request_id: requestId,
          capture_mode: captureMode,
          assets: captured.assets,
          missing: captured.missing,
          omitted: captureMode === "fast" ? [
            "Views that were hidden, unfinished or not yet rendered were not generated."
          ] : [],
          external_results: message && message.include_global_assets === false ? [] : captureExternalResults(),
          captured_bytes: captured.bytes,
          timings: {
            client_capture_ms: Date.now() - captureStartedAt,
            synteny_ms: preSyntenyMs,
            alignment_view_ms: preLastzMs
          },
          nonce: Date.now() + Math.random()
        }, { priority: "event" });
      }
    };

    if (captureMode === "fast") {
      window.setTimeout(function () {
        completeCapture([], [], []);
      }, 0);
      return;
    }

    sendReportProgress(requestId, "Preparing missing structural views for the complete report…");
    waitForStructuralFigures(message, function (structuralMissing, preparedTargets) {
      var analyticsToRender = analyticsContexts.filter(function (context) {
        var state = hiddenAnalyticsState(context);
        return state.expected === 0 ||
          state.ready < state.expected ||
          state.busy > 0;
      });
      if (analyticsToRender.length) {
        sendReportProgress(requestId, "Generating missing Analytics charts for the complete report…");
        requestHiddenAnalytics(analyticsToRender);
      }
      waitForHiddenAnalytics(analyticsContexts, function (analyticsMissing) {
        completeCapture(structuralMissing, analyticsMissing, preparedTargets);
      });
    });
  }

  function selectedVisualMode(context) {
    var selected = document.querySelector(
      "#" + context + "_visual_mode input[type='radio']:checked," +
      "input[name='" + context + "_visual_mode']:checked"
    );
    return selected ? String(selected.value || "") : "";
  }

  function selectVisualMode(context, value) {
    var radio = document.querySelector(
      "#" + context + "_visual_mode input[type='radio'][value='" + value + "']," +
      "input[name='" + context + "_visual_mode'][value='" + value + "']"
    );
    if (!radio) return false;
    if (!radio.checked) radio.click();
    return true;
  }

  function restoreReportModes(requestId) {
    var restore = modeRestoreByRequest[requestId] || {};
    delete modeRestoreByRequest[requestId];
    delete preLastzCaptureByRequest[requestId];
    delete preSyntenyCaptureByRequest[requestId];
    Object.keys(restore).forEach(function (context) {
      if (restore[context]) selectVisualMode(context, restore[context]);
    });
  }

  function setReportSelectValue(inputId, value) {
    var input = document.getElementById(inputId);
    if (!input) return false;
    var next = String(value || "");
    if (input.selectize && typeof input.selectize.setValue === "function") {
      input.selectize.setValue(next, false);
    } else {
      input.value = next;
      try {
        input.dispatchEvent(new window.Event("change", { bubbles: true }));
      } catch (err) {}
    }
    // selectize.setValue() and the native change event are already observed
    // by Shiny. Sending the same value again with setInputValue() caused two
    // invalidations and made each report synteny view render more than once.
    return true;
  }

  function normalizeSyntenyGroups(message) {
    return asArray(message && message.homo_groups).map(function (group, index) {
      group = group || {};
      var label = String(group.label || group.gene_label || group.value || ("Gene " + (index + 1)));
      return {
        value: String(group.value || group.key || ""),
        gene: String(group.gene_label || label.split("|")[0] || "").trim(),
        organism: String(group.organism_label || group.org_label || "").trim(),
        label: label
      };
    }).filter(function (group) {
      return !!group.value;
    });
  }

  function captureSyntenyTask(task) {
    var output = document.getElementById(task.outputId);
    var svg = output && output.querySelector("svg");
    if (!svg) return null;
    var markup = normalizeSvg(svg);
    if (!markup) return null;
    var suffix = task.context === "homo" && task.group ?
      "_" + String(task.index + 1) : "";
    var id = task.context + "_aligned_plot_out" + suffix;
    return {
      id: id,
      source_id: id,
      title: task.context === "homo" && task.group ?
        "Aligned synteny · " + task.group.gene :
        "Cross-Species aligned synteny",
      group: "synteny",
      context: task.context === "homo" ? "multi_gene" : "cross_species",
      comparison_gene: task.group ? task.group.gene : "",
      organism: task.group ? task.group.organism : "",
      svg: markup
    };
  }

  function runSyntenyCaptureTasks(tasks, timeoutMs, requestId, callback) {
    var assets = [];
    var missing = [];
    var index = 0;
    var previousHomoSvg = null;

    var runNext = function () {
      if (index >= tasks.length) {
        callback({ assets: assets, missing: missing });
        return;
      }
      var task = tasks[index++];
      sendReportProgress(
        requestId,
        "Rendering aligned synteny view " + index + " of " + tasks.length + "…"
      );
      var started = Date.now();
      var selectionAppliedAt = 0;
      var stableSvg = null;
      var stableCount = 0;
      var timer = window.setInterval(function () {
        if (task.context === "homo" && task.group && !selectionAppliedAt) {
          if (!setReportSelectValue("homo_aligned_gene_group", task.group.value)) return;
          selectionAppliedAt = Date.now();
        }
        if (!selectionAppliedAt) selectionAppliedAt = Date.now();
        var output = document.getElementById(task.outputId);
        var svg = output && output.querySelector("svg");
        var ready = !!(svg && output && !output.classList.contains("recalculating"));
        var changed = task.context !== "homo" || !previousHomoSvg || svg !== previousHomoSvg;
        if (ready && changed && Date.now() - selectionAppliedAt >= 450) {
          if (svg === stableSvg) {
            stableCount += 1;
          } else {
            stableSvg = svg;
            stableCount = 0;
          }
          if (stableCount >= 2) {
            window.clearInterval(timer);
            var asset = captureSyntenyTask(task);
            if (asset) {
              assets.push(asset);
              if (task.context === "homo") previousHomoSvg = svg;
            } else {
              missing.push((task.context === "homo" ? task.group.gene : "Cross-Species") +
                " aligned synteny: SVG could not be serialized");
            }
            runNext();
            return;
          }
        } else {
          stableSvg = null;
          stableCount = 0;
        }
        if (Date.now() - started >= timeoutMs) {
          window.clearInterval(timer);
          missing.push((task.context === "homo" && task.group ? task.group.gene : "Cross-Species") +
            " aligned synteny: view did not render before the report timeout");
          runNext();
        }
      }, 300);
    };
    runNext();
  }

  function prepareSyntenyForReport(message) {
    var phaseStartedAt = Date.now();
    var requestId = String((message && message.request_id) || "");
    var captureLimit = Number((message && message.max_total_bytes) || (24 * 1024 * 1024));
    var taskTimeout = Math.max(15000, Number((message && message.per_view_timeout_ms) || 30000));
    var contexts = asArray(message && message.contexts).filter(function (context) {
      return context === "homo" || context === "ortho";
    });
    // Preserve the currently visible structural results before changing modes.
    // Shiny removes those cards while the aligned view is active.
    var beforeSynteny = capturePageSvgs(captureLimit, message && message.capture_contexts);
    var restore = modeRestoreByRequest[requestId] || {};
    var originalHomoGroup = String((message && message.homo_selected_group) || "");
    var activeContexts = [];
    contexts.forEach(function (context) {
      if (!(context in restore)) restore[context] = selectedVisualMode(context);
      // The aligned option only exists when the current result set supports it
      // (e.g. multi-transcript gene groups in Multi-Gene); skip it silently.
      if (!selectVisualMode(context, "aligned")) return;
      activeContexts.push(context);
    });
    modeRestoreByRequest[requestId] = restore;
    var groups = normalizeSyntenyGroups(message);
    var tasks = [];
    if (activeContexts.indexOf("homo") >= 0) {
      groups.forEach(function (group, index) {
        tasks.push({
          context: "homo",
          outputId: "homo_aligned_plot_out",
          group: group,
          index: index
        });
      });
    }
    if (activeContexts.indexOf("ortho") >= 0) {
      tasks.push({
        context: "ortho",
        outputId: "ortho_aligned_plot_out",
        group: null,
        index: 0
      });
    }
    var finish = function (alignedCapture) {
      alignedCapture = alignedCapture || { assets: [], missing: [] };
      preSyntenyCaptureByRequest[requestId] = {
        assets: (beforeSynteny.assets || []).concat(alignedCapture.assets || []),
        missing: (beforeSynteny.missing || []).concat(alignedCapture.missing || []),
        bytes: Number(beforeSynteny.bytes || 0) + (alignedCapture.assets || []).reduce(function (sum, asset) {
          return sum + new Blob([String(asset && asset.svg || "")]).size;
        }, 0),
        duration_ms: Date.now() - phaseStartedAt
      };
      if (originalHomoGroup) {
        setReportSelectValue("homo_aligned_gene_group", originalHomoGroup);
      }
      Object.keys(restore).forEach(function (context) {
        if (restore[context]) selectVisualMode(context, restore[context]);
      });
      delete modeRestoreByRequest[requestId];
      if (message && message.capture_after_synteny) {
        captureForServer({
          request_id: requestId,
          max_total_bytes: captureLimit,
          analytics_contexts: message.analytics_contexts,
          structural_targets: message.structural_targets,
          capture_contexts: message.capture_contexts,
          include_global_assets: message.include_global_assets
        });
        return;
      }
      if (window.Shiny && typeof window.Shiny.setInputValue === "function") {
        window.Shiny.setInputValue("cgv_report_synteny_ready", {
          request_id: requestId,
          missing: alignedCapture.missing || [],
          nonce: Date.now() + Math.random()
        }, { priority: "event" });
      }
    };
    if (!tasks.length) {
      finish({
        assets: [],
        missing: activeContexts.indexOf("homo") >= 0 && !groups.length ?
          ["Multi-Gene aligned synteny: no eligible gene groups were available for capture"] : []
      });
      return;
    }
    runSyntenyCaptureTasks(tasks, taskTimeout, requestId, finish);
  }

  function prepareLastzForReport(message) {
    var phaseStartedAt = Date.now();
    var requestId = String((message && message.request_id) || "");
    var contexts = asArray(message && message.contexts).filter(function (context) {
      return context === "homo" || context === "ortho";
    });
    var captureLimit = Number((message && message.max_total_bytes) || (24 * 1024 * 1024));
    var runLastz = !(message && message.skip_run);
    var runMultipip = !(message && message.run_multipip === false);
    var capture = capturePageSvgs(captureLimit, message && message.capture_contexts);
    var restore = {};
    contexts.forEach(function (context) {
      restore[context] = selectedVisualMode(context);
    });
    modeRestoreByRequest[requestId] = restore;

    var tasks = [];
    contexts.forEach(function (context) {
      tasks.push({
        context: context,
        mode: "pip_blocks",
        label: "LASTZ blocks",
        buttonId: context + "_pip_run_alignments",
        outputId: context + "_pip_plot_out",
        shouldRun: runLastz
      });
      tasks.push({
        context: context,
        mode: "pip_multipip",
        label: "MultiPIP",
        buttonId: context + "_multipip_run_alignments",
        outputId: context + "_multipip_plot_out",
        shouldRun: runMultipip
      });
    });

    var taskIndex = 0;
    var missing = [];
    var runNext = function () {
      if (taskIndex >= tasks.length) {
        capture.duration_ms = Date.now() - phaseStartedAt;
        preLastzCaptureByRequest[requestId] = capture;
        if (window.Shiny && typeof window.Shiny.setInputValue === "function") {
          window.Shiny.setInputValue("cgv_report_lastz_ready", {
            request_id: requestId,
            missing: missing,
            nonce: Date.now() + Math.random()
          }, { priority: "event" });
        }
        return;
      }
      var target = tasks[taskIndex++];
      if (!selectVisualMode(target.context, target.mode)) {
        missing.push((target.context === "homo" ? "Multi-Gene" : "Cross-Species") +
          " " + target.label + ": view is not available");
        runNext();
        return;
      }
      var started = Date.now();
      var clicked = false;
      var clickedAt = 0;
      var sawDisabled = false;
      var beforeMarkup = "";
      var stableMarkup = "";
      var stableCount = 0;
      var timer = window.setInterval(function () {
        var button = document.getElementById(target.buttonId);
        var output = document.getElementById(target.outputId);
        var svg = output && output.querySelector("svg");
        var markup = svg ? normalizeSvg(svg) : "";
        if (!clicked) {
          if (Date.now() - started < 800) return;
          if (!button) {
            if (Date.now() - started > 8000) {
              window.clearInterval(timer);
              missing.push((target.context === "homo" ? "Multi-Gene" : "Cross-Species") +
                " " + target.label + ": controls did not become available");
              runNext();
            }
            return;
          }
          beforeMarkup = markup;
          if (target.shouldRun) button.click();
          clicked = true;
          clickedAt = Date.now();
          return;
        }
        if (target.shouldRun && button && button.disabled) sawDisabled = true;
        var idle = !!(markup && output && !output.classList.contains("recalculating") &&
          (!target.shouldRun || (button && !button.disabled)));
        var completed = !target.shouldRun ||
          sawDisabled ||
          (markup && markup !== beforeMarkup && Date.now() - clickedAt > 1000);
        if (idle && completed && Date.now() - clickedAt > 500) {
          if (markup === stableMarkup) {
            stableCount += 1;
          } else {
            stableMarkup = markup;
            stableCount = 0;
          }
          if (stableCount >= 2) {
            window.clearInterval(timer);
            var id = target.context + "_" + target.mode + "_report";
            capture.assets.push({
              id: id,
              source_id: id,
              title: target.label,
              group: "alignment",
              context: target.context === "homo" ? "multi_gene" : "cross_species",
              svg: markup
            });
            capture.bytes += new Blob([markup]).size;
            runNext();
            return;
          }
        } else {
          stableMarkup = "";
          stableCount = 0;
        }
        if (Date.now() - clickedAt > 180000) {
          window.clearInterval(timer);
          missing.push((target.context === "homo" ? "Multi-Gene" : "Cross-Species") +
            " " + target.label + ": did not finish within 3 minutes");
          runNext();
        }
      }, 350);
    };
    runNext();
  }

  function rememberReport(message) {
    if (!message || !message.token || !message.url || !message.revoke_secret) return;
    latestUrl = String(message.url);
    var items = readReceipts().filter(function (item) {
      return item && item.token !== message.token;
    });
    items.unshift({
      token: String(message.token),
      revoke_secret: String(message.revoke_secret),
      url: String(message.url),
      expires_at: String(message.expires_at || ""),
      created_at: new Date().toISOString()
    });
    writeReceipts(items);
    renderReceipts();
  }

  function handleRevoked(message) {
    if (!message || !message.ok) return;
    var token = String(message.token || "");
    writeReceipts(readReceipts().filter(function (item) {
      return item && item.token !== token;
    }));
    renderReceipts();
  }

  function bindShiny() {
    if (!window.Shiny || typeof window.Shiny.addCustomMessageHandler !== "function") return;
    window.Shiny.addCustomMessageHandler("cgv:capture-analysis-assets", captureForServer);
    window.Shiny.addCustomMessageHandler("cgv:prepare-lastz-for-report", prepareLastzForReport);
    window.Shiny.addCustomMessageHandler("cgv:prepare-synteny-for-report", prepareSyntenyForReport);
    window.Shiny.addCustomMessageHandler("cgv:restore-report-modes", function (message) {
      restoreReportModes(String((message && message.request_id) || ""));
    });
    window.Shiny.addCustomMessageHandler("cgv:shared-report-created", rememberReport);
    window.Shiny.addCustomMessageHandler("cgv:shared-report-revoked", handleRevoked);
  }

  function scrollShareModalToTop() {
    var shell = document.getElementById("cgv-share-modal-shell");
    var body = shell && shell.closest ? shell.closest(".modal-body") : null;
    if (body) body.scrollTop = 0;
  }

  function freezeReportBackground(modal) {
    var existing = document.getElementById("cgv-report-capture-curtain");
    if (existing) return existing;
    var curtain = document.createElement("div");
    curtain.id = "cgv-report-capture-curtain";
    curtain.className = "cgv-report-capture-curtain";
    curtain.setAttribute("aria-hidden", "true");
    // Keep the live application completely out of sight while report-only
    // modes render. Cloning the app still exposed a graph behind the modal
    // and also duplicated a very large DOM tree in memory.
    document.body.appendChild(curtain);
    var backdrop = document.querySelector(".modal-backdrop");
    var backdropZ = backdrop ? parseInt(window.getComputedStyle(backdrop).zIndex, 10) : NaN;
    var modalZ = modal ? parseInt(window.getComputedStyle(modal).zIndex, 10) : NaN;
    curtain.style.zIndex = String(isFinite(backdropZ) ?
      Math.max(1, backdropZ - 1) :
      Math.max(1, (isFinite(modalZ) ? modalZ : 1050) - 1));
    return curtain;
  }

  function clearFrozenReportBackground() {
    var curtain = document.getElementById("cgv-report-capture-curtain");
    if (curtain) curtain.remove();
    document.body.classList.remove("cgv-report-capture-active");
  }

  function syncReportCaptureCurtain() {
    if (!document.body) return;
    var shell = document.getElementById("cgv-share-modal-shell");
    var modal = shell && shell.closest ? shell.closest(".modal") : null;
    var modalVisible = !!(modal && window.getComputedStyle(modal).display !== "none");
    var busy = !!(shell && shell.querySelector(".cgv-share-progress") && modalVisible);
    var terminal = !!(shell && shell.querySelector(
      ".cgv-share-result, .cgv-share-callout-warning, .cgv-share-callout-error, .cgv-share-callout-success"
    ));
    var curtain = document.getElementById("cgv-report-capture-curtain");
    if (terminal || !modalVisible) {
      reportCaptureRequested = false;
    }
    if (!modalVisible || terminal || (!busy && !reportCaptureRequested)) {
      window.setTimeout(clearFrozenReportBackground, terminal ? 120 : 0);
      return;
    }
    if (!curtain) {
      curtain = freezeReportBackground(modal);
    }
    var backdrop = document.querySelector(".modal-backdrop");
    var backdropZ = backdrop ? parseInt(window.getComputedStyle(backdrop).zIndex, 10) : NaN;
    var modalZ = parseInt(window.getComputedStyle(modal).zIndex, 10);
    if (!isFinite(modalZ)) modalZ = 1050;
    curtain.style.zIndex = String(isFinite(backdropZ) ?
      Math.max(1, backdropZ - 1) :
      Math.max(1, modalZ - 1));
    document.body.classList.add("cgv-report-capture-active");
  }

  // Keep the share modal progress and result blocks in view: they render at
  // the top of the modal body, so make sure the user never has to scroll to
  // notice them after starting a publication or when it finishes.
  document.addEventListener("click", function (event) {
    var target = event.target && event.target.closest ? event.target.closest("#publish_shared_analysis") : null;
    if (target) {
      reportCaptureRequested = true;
      var shell = document.getElementById("cgv-share-modal-shell");
      var modal = shell && shell.closest ? shell.closest(".modal") : null;
      freezeReportBackground(modal);
      document.body.classList.add("cgv-report-capture-active");
      window.setTimeout(function () {
        scrollShareModalToTop();
        syncReportCaptureCurtain();
      }, 80);
    }
  });

  var shareModalObserver = null;
  if (typeof window.MutationObserver === "function") {
    shareModalObserver = new window.MutationObserver(function (mutations) {
      window.requestAnimationFrame(syncReportCaptureCurtain);
      for (var i = 0; i < mutations.length; i++) {
        var added = mutations[i].addedNodes;
        for (var j = 0; j < added.length; j++) {
          var node = added[j];
          if (!node || node.nodeType !== 1) continue;
          var hitsResult = node.id === "cgv-share-result-url" ||
            (node.querySelector && node.querySelector("#cgv-share-result-url"));
          if (hitsResult) {
            scrollShareModalToTop();
            return;
          }
        }
      }
    });
    var observeShareModal = function () {
      if (!document.body || !shareModalObserver) return;
      shareModalObserver.observe(document.body, { childList: true, subtree: true });
    };
    if (document.body) {
      observeShareModal();
      syncReportCaptureCurtain();
    } else {
      document.addEventListener("DOMContentLoaded", function () {
        observeShareModal();
        syncReportCaptureCurtain();
      }, { once: true });
    }
  }

  function notifyZipStart() {
    var shell = document.getElementById("cgv-share-modal-shell");
    if (!shell) return;
    var status = document.getElementById("cgv-zip-generation-status");
    if (!status) {
      status = document.createElement("div");
      status.id = "cgv-zip-generation-status";
      status.className = "cgv-share-progress";
      var result = shell.querySelector(".cgv-share-result, .cgv-share-callout-success");
      if (result && result.parentNode) {
        result.parentNode.insertBefore(status, result.nextSibling);
      } else {
        shell.insertBefore(status, shell.firstChild);
      }
    }
    status.textContent = "Preparing the reproducibility ZIP. This can take several minutes; keep this window open.";
    scrollShareModalToTop();
  }

  window.CGVSharedAnalysis = {
    capture: captureForServer,
    renderReceipts: renderReceipts,
    notifyZipStart: notifyZipStart,
    copyLatestUrl: function () {
      var input = document.getElementById("cgv-share-result-url");
      return copyText(input ? input.value : latestUrl);
    }
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", renderReceipts);
  } else {
    renderReceipts();
  }
  document.addEventListener("shiny:connected", function () {
    bindShiny();
    renderReceipts();
  });
  bindShiny();
})();
