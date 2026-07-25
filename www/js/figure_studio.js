(function () {
    "use strict";

    if (window.CGVFigureStudio) return;

    var SVG_NS = "http://www.w3.org/2000/svg";
    var XLINK_NS = "http://www.w3.org/1999/xlink";
    var MAX_HISTORY = 40;
    var MAX_PNG_PIXELS = 70000000;
    var initialized = false;
    var toastTimer = null;
    var persistTimer = null;
    var catalogRefreshTimer = null;
    var previewResizeTimer = null;
    var previewReturnFocus = null;
    var guideAnchor = null;
    var tooltipPortal = null;
    var tooltipTrigger = null;
    var observer = null;
    var dragPanelId = "";
    var historyStack = [];
    var futureStack = [];
    var runtimeSvg = Object.create(null);
    var dynamicSources = Object.create(null);
    var catalogGroupExpanded = Object.create(null);
    var textEditSnapshots = Object.create(null);

    var state = {
        version: 2,
        title: "CGV comparative analysis",
        subtitle: "",
        columns: 2,
        profile: "color",
        resolution: 2,
        context: "homo",
        panels: [],
        selectedId: null,
        lastResultsTarget: "homologous"
    };

    var CATALOG = [
        { key: "arch", title: "Gene architecture", group: "Analytics", icon: "dna", suffix: "arch_chart" },
        { key: "exon", title: "Exons / introns", group: "Analytics", icon: "layer-group", suffix: "exon_chart" },
        { key: "seq", title: "Sequence composition", group: "Analytics", icon: "microscope", suffix: "seq_chart" },
        { key: "context", title: "Genomic context", group: "Analytics", icon: "map-marker-alt", suffix: "context_chart" },
        { key: "exon-dist", title: "Exon lengths", group: "Analytics", icon: "ruler-horizontal", suffix: "exon_dist_chart" },
        { key: "intron-dist", title: "Intron lengths", group: "Analytics", icon: "arrows-alt-h", suffix: "intron_dist_chart" },
        { key: "scatter", title: "GC vs gene length", group: "Analytics", icon: "circle", suffix: "scatter_chart" },
        { key: "heatmap", title: "Comparative heatmap", group: "Analytics", icon: "th", suffix: "heatmap_chart" },
        { key: "radar", title: "Comparative radar", group: "Analytics", icon: "chart-pie", suffix: "radar_chart" },
        { key: "corr", title: "Metric correlations", group: "Analytics", icon: "grip-lines", suffix: "corr_chart" },
        { key: "aligned", title: "Aligned synteny", group: "Alignment", icon: "project-diagram", suffix: "aligned_plot_out", direct: true },
        { key: "pip", title: "LASTZ blocks", group: "Alignment", icon: "stream", suffix: "pip_plot_out", direct: true },
        { key: "multipip", title: "MultiPIP", group: "Alignment", icon: "align-center", suffix: "multipip_plot_out", direct: true }
    ];

    var HEIGHTS = {
        compact: 360,
        standard: 520,
        tall: 680
    };

    function validHeightMode(value) {
        return value === "auto" || Object.prototype.hasOwnProperty.call(HEIGHTS, value);
    }

    function byId(id) {
        return document.getElementById(id);
    }

    function make(tag, className, text) {
        var node = document.createElement(tag);
        if (className) node.className = className;
        if (typeof text === "string") node.textContent = text;
        return node;
    }

    function cloneJson(value) {
        return JSON.parse(JSON.stringify(value));
    }

    function panelLabel(index) {
        var n = Number(index) + 1;
        var label = "";
        while (n > 0) {
            n -= 1;
            label = String.fromCharCode(65 + (n % 26)) + label;
            n = Math.floor(n / 26);
        }
        return label;
    }

    function makePanelId() {
        return "figure-panel-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 8);
    }

    function safeInt(value, fallback, min, max) {
        var n = parseInt(value, 10);
        if (!isFinite(n)) n = fallback;
        return Math.max(min, Math.min(max, n));
    }

    function sanitizeState(raw) {
        var next = raw && typeof raw === "object" ? raw : {};
        var incomingVersion = safeInt(next.version, 1, 1, 999);
        var panels = Array.isArray(next.panels) ? next.panels : [];
        panels = panels.map(function (panel) {
            var context = panel && panel.context === "ortho" ? "ortho" : "homo";
            var height = panel && validHeightMode(panel.height) ? panel.height : "auto";
            if (incomingVersion < 2 && height === "standard") height = "auto";
            return {
                id: String((panel && panel.id) || makePanelId()),
                key: String((panel && panel.key) || "custom"),
                context: context,
                sourceId: String((panel && panel.sourceId) || ""),
                sourceKind: String((panel && panel.sourceKind) || "chart"),
                sourceLabel: String((panel && panel.sourceLabel) || "CGV visualization"),
                title: String((panel && panel.title) || "CGV visualization").slice(0, 120),
                span: safeInt(panel && panel.span, 1, 1, 3),
                height: height,
                showTitle: !panel || panel.showTitle !== false
            };
        });
        var selectedId = String(next.selectedId || "");
        if (!panels.some(function (panel) { return panel.id === selectedId; })) selectedId = null;
        var normalizedTitle = Object.prototype.hasOwnProperty.call(next, "title")
            ? String(next.title == null ? "" : next.title).trim().slice(0, 140)
            : "CGV comparative analysis";
        return {
            version: 2,
            title: normalizedTitle,
            subtitle: String(next.subtitle || "").slice(0, 200),
            columns: safeInt(next.columns, 2, 1, 3),
            profile: ["color", "paper-color", "colorblind", "gray", "mono"].indexOf(next.profile) >= 0 ? next.profile : "color",
            resolution: safeInt(next.resolution, 2, 1, 3),
            context: next.context === "ortho" ? "ortho" : "homo",
            panels: panels,
            selectedId: selectedId,
            lastResultsTarget: next.lastResultsTarget === "orthologous" ? "orthologous" : "homologous"
        };
    }

    function serializableState() {
        return sanitizeState(state);
    }

    function setState(next, options) {
        var opts = options || {};
        state = sanitizeState(next);
        syncControls();
        renderAll();
        if (!opts.skipPersist) persistSoon();
        if (!opts.skipHydrate) rehydratePanels();
    }

    function saveHistory() {
        historyStack.push(serializableState());
        if (historyStack.length > MAX_HISTORY) historyStack.shift();
        futureStack = [];
        updateHistoryButtons();
    }

    function mutate(callback, options) {
        var opts = options || {};
        if (!opts.skipHistory) saveHistory();
        callback(state);
        state = sanitizeState(state);
        renderAll();
        persistSoon();
    }

    function undo() {
        if (!historyStack.length) return;
        futureStack.push(serializableState());
        var previous = historyStack.pop();
        setState(previous, { skipHydrate: false });
        updateHistoryButtons();
    }

    function redo() {
        if (!futureStack.length) return;
        historyStack.push(serializableState());
        var next = futureStack.pop();
        setState(next, { skipHydrate: false });
        updateHistoryButtons();
    }

    function updateHistoryButtons() {
        var undoBtn = byId("figure-studio-undo");
        var redoBtn = byId("figure-studio-redo");
        if (undoBtn) undoBtn.disabled = historyStack.length === 0;
        if (redoBtn) redoBtn.disabled = futureStack.length === 0;
    }

    function persistSoon() {
        clearTimeout(persistTimer);
        var status = byId("figure-studio-save-status");
        if (status) status.textContent = "Updating draft…";
        persistTimer = setTimeout(persistNow, 180);
    }

    function persistNow() {
        var json = JSON.stringify(serializableState());
        var hidden = byId("figure_studio_state");
        if (hidden) hidden.value = json;
        if (window.Shiny && typeof window.Shiny.setInputValue === "function") {
            window.Shiny.setInputValue("figure_studio_state", json, { priority: "event" });
        }
        var status = byId("figure-studio-save-status");
        if (status) status.textContent = "Temporary draft";
    }

    function restoreExternalDraft(payload) {
        try {
            var parsed = typeof payload === "string" ? JSON.parse(payload) : payload;
            historyStack = [];
            futureStack = [];
            runtimeSvg = Object.create(null);
            setState(parsed || {}, { skipPersist: false, skipHydrate: false });
            toast("Figure Studio draft restored with the CGV work session.");
        } catch (err) {
            toast("The saved Figure Studio draft could not be restored.");
        }
    }

    function toast(message) {
        var node = byId("figure-studio-toast");
        if (!node) return;
        clearTimeout(toastTimer);
        node.textContent = String(message || "");
        node.hidden = false;
        toastTimer = setTimeout(function () {
            node.hidden = true;
        }, 4200);
    }

    function getCatalogDefinition(key) {
        for (var i = 0; i < CATALOG.length; i += 1) {
            if (CATALOG[i].key === key) return CATALOG[i];
        }
        return null;
    }

    function sourceCandidates(definition, context) {
        if (!definition) return [];
        var base = context + "_" + definition.suffix;
        if (definition.direct) return [base];
        return [base + "_export", base];
    }

    function findSvg(containerOrId) {
        var container = typeof containerOrId === "string" ? byId(containerOrId) : containerOrId;
        if (!container) return null;
        try {
            if (typeof window.getPlotSvg === "function") {
                var found = window.getPlotSvg(container);
                if (found) return found;
            }
        } catch (err) {}
        if (container.matches && container.matches("svg")) return container;
        return container.querySelector(
            ".girafe_container_std > svg, .ggiraph-svg > svg, svg.ggiraph-svg, .ggiraph-svg svg, svg"
        );
    }

    function hasContextResults(context) {
        var rootId = context === "ortho" ? "ortho-plot-cards-container" : "homo-plot-cards-container";
        var root = byId(rootId);
        if (root && root.querySelector(".plot-transcript-card")) return true;
        var hasRememberedResults = Object.keys(dynamicSources).some(function (key) {
            return dynamicSources[key] && dynamicSources[key].context === context;
        });
        if (hasRememberedResults) return true;
        for (var i = 0; i < CATALOG.length; i += 1) {
            var candidates = sourceCandidates(CATALOG[i], context);
            for (var j = 0; j < candidates.length; j += 1) {
                if (findSvg(candidates[j])) return true;
            }
        }
        return false;
    }

    function numericSvgDimension(value) {
        var parsed = parseFloat(String(value || "").replace(/[^0-9.+-]/g, ""));
        return isFinite(parsed) && parsed > 0 ? parsed : 0;
    }

    function normalizeSourceSvg(svgElement) {
        if (!svgElement) return "";
        var clone = svgElement.cloneNode(true);
        clone.setAttribute("xmlns", SVG_NS);
        clone.setAttribute("xmlns:xlink", XLINK_NS);
        clone.querySelectorAll("script, foreignObject, .ggiraph-toolbar, .girafe-toolbar").forEach(function (node) {
            node.remove();
        });
        clone.querySelectorAll("*").forEach(function (node) {
            Array.prototype.slice.call(node.attributes || []).forEach(function (attr) {
                if (/^on/i.test(attr.name)) node.removeAttribute(attr.name);
            });
            node.removeAttribute("tabindex");
            node.removeAttribute("focusable");
        });
        var viewBox = clone.getAttribute("viewBox");
        if (!viewBox) {
            var width = numericSvgDimension(clone.getAttribute("width"));
            var height = numericSvgDimension(clone.getAttribute("height"));
            if ((!width || !height) && svgElement.getBoundingClientRect) {
                var rect = svgElement.getBoundingClientRect();
                width = width || rect.width;
                height = height || rect.height;
            }
            width = width || 1200;
            height = height || 520;
            clone.setAttribute("viewBox", "0 0 " + width + " " + height);
        }
        clone.removeAttribute("width");
        clone.removeAttribute("height");
        clone.setAttribute("preserveAspectRatio", "xMidYMid meet");
        clone.style.removeProperty("width");
        clone.style.removeProperty("height");
        clone.style.removeProperty("max-width");
        clone.style.overflow = "visible";
        if (typeof window.normalizeExportTextNodes === "function") {
            try { window.normalizeExportTextNodes(clone); } catch (err) {}
        }
        return new XMLSerializer().serializeToString(clone);
    }

    function captureContainer(containerId) {
        var svg = findSvg(containerId);
        return svg ? normalizeSourceSvg(svg) : "";
    }

    function pollForSvg(candidates, timeoutMs) {
        return new Promise(function (resolve, reject) {
            var started = Date.now();
            function check() {
                for (var i = 0; i < candidates.length; i += 1) {
                    var markup = captureContainer(candidates[i]);
                    if (markup) {
                        resolve({ markup: markup, sourceId: candidates[i] });
                        return;
                    }
                }
                if (Date.now() - started >= timeoutMs) {
                    reject(new Error("SVG source did not become available."));
                    return;
                }
                setTimeout(check, 220);
            }
            check();
        });
    }

    function requestAnalyticsRender(context) {
        if (!window.Shiny || typeof window.Shiny.setInputValue !== "function") return false;
        window.Shiny.setInputValue(context + "_analytics_export_all_nonce", Date.now() + Math.random(), {
            priority: "event"
        });
        return true;
    }

    function finishAnalyticsRender(context) {
        if (!window.Shiny || typeof window.Shiny.setInputValue !== "function") return;
        window.Shiny.setInputValue(context + "_analytics_export_done_nonce", Date.now() + Math.random(), {
            priority: "event"
        });
    }

    function visualModeInputName(context) {
        return context === "ortho" ? "ortho_visual_mode" : "homo_visual_mode";
    }

    function visualModeRadio(context, value) {
        var name = visualModeInputName(context);
        return document.querySelector('input[name="' + name + '"][value="' + value + '"]');
    }

    function selectedVisualMode(context) {
        var name = visualModeInputName(context);
        var selected = document.querySelector('input[name="' + name + '"]:checked');
        return selected ? String(selected.value || "") : "";
    }

    function hasAlignedMode(context) {
        var aligned = visualModeRadio(context, "aligned");
        return !!aligned && !aligned.disabled;
    }

    function setVisualMode(context, value) {
        var target = visualModeRadio(context, value);
        if (!target || target.disabled) return false;
        document.querySelectorAll('input[name="' + visualModeInputName(context) + '"]').forEach(function (radio) {
            radio.checked = radio === target;
        });
        target.dispatchEvent(new Event("change", { bubbles: true }));
        if (window.Shiny && typeof window.Shiny.setInputValue === "function") {
            window.Shiny.setInputValue(visualModeInputName(context), value, { priority: "event" });
        }
        return true;
    }

    function acquireAlignedSvg(definition, context) {
        if (!hasContextResults(context) || !hasAlignedMode(context)) {
            var requirement = context === "ortho"
                ? "Generate cross-species results first."
                : "Load a gene with multiple transcripts first.";
            return Promise.reject(new Error(requirement));
        }
        if (!window.Shiny || typeof window.Shiny.setInputValue !== "function") {
            return Promise.reject(new Error("The aligned view cannot be prepared yet."));
        }

        var previousMode = selectedVisualMode(context) || "compact";
        window.Shiny.setInputValue("figure_studio_alignment_render_request", {
            context: context,
            nonce: Date.now() + Math.random()
        }, { priority: "event" });
        if (!setVisualMode(context, "aligned")) {
            return Promise.reject(new Error("The aligned view is not available for these results."));
        }

        return pollForSvg(sourceCandidates(definition, context), 30000).finally(function () {
            if (previousMode !== "aligned") setVisualMode(context, previousMode);
            setTimeout(function () {
                window.Shiny.setInputValue("figure_studio_alignment_render_done", {
                    context: context,
                    nonce: Date.now() + Math.random()
                }, { priority: "event" });
            }, 250);
        });
    }

    function acquireCatalogSvg(definition, context) {
        var candidates = sourceCandidates(definition, context);
        for (var i = 0; i < candidates.length; i += 1) {
            var immediate = captureContainer(candidates[i]);
            if (immediate) return Promise.resolve({ markup: immediate, sourceId: candidates[i] });
        }
        if (definition.direct) {
            if (definition.key === "aligned") {
                return acquireAlignedSvg(definition, context);
            }
            return Promise.reject(new Error("Generate this alignment visualization before adding it."));
        }
        if (!hasContextResults(context)) {
            return Promise.reject(new Error("Generate " + (context === "ortho" ? "cross-species" : "multi-gene") + " results first."));
        }
        requestAnalyticsRender(context);
        return pollForSvg(candidates, 18000).then(function (result) {
            setTimeout(function () { finishAnalyticsRender(context); }, 180);
            return result;
        }).catch(function (err) {
            finishAnalyticsRender(context);
            throw err;
        });
    }

    function selectedPanel() {
        for (var i = 0; i < state.panels.length; i += 1) {
            if (state.panels[i].id === state.selectedId) return state.panels[i];
        }
        return null;
    }

    function addPanelFromMarkup(options) {
        var opts = options || {};
        var id = makePanelId();
        var context = opts.context === "ortho" ? "ortho" : "homo";
        var sourceKind = String(opts.sourceKind || "").toLowerCase();
        var defaultSpan = sourceKind === "alignment" || sourceKind === "result"
            ? state.columns
            : 1;
        var panel = {
            id: id,
            key: String(opts.key || "custom"),
            context: context,
            sourceId: String(opts.sourceId || ""),
            sourceKind: String(opts.sourceKind || "chart"),
            sourceLabel: String(opts.sourceLabel || "CGV visualization"),
            title: String(opts.title || "CGV visualization").slice(0, 120),
            span: Math.min(state.columns, safeInt(opts.span, defaultSpan, 1, 3)),
            height: validHeightMode(opts.height) ? opts.height : "auto",
            showTitle: opts.showTitle !== false
        };
        saveHistory();
        state.panels.push(panel);
        state.selectedId = id;
        state.context = context;
        state.lastResultsTarget = context === "ortho" ? "orthologous" : "homologous";
        runtimeSvg[id] = String(opts.markup || "");
        renderAll();
        persistSoon();
        toast("Added as panel " + panelLabel(state.panels.length - 1) + ": " + panel.title + ".");
        return panel;
    }

    function addFromCatalog(key) {
        if (dynamicSources[key]) {
            var dynamic = dynamicSources[key];
            var dynamicRoot = byId(dynamic.rootId);
            var dynamicSvg = findSvg(dynamicRoot);
            if (dynamicSvg) {
                addPanelFromMarkup({
                    key: key,
                    context: dynamic.context,
                    sourceId: dynamic.rootId,
                    sourceKind: "result",
                    sourceLabel: dynamic.sourceLabel,
                    title: dynamic.title,
                    markup: normalizeSourceSvg(dynamicSvg)
                });
                return Promise.resolve();
            }

            if (!window.Shiny || typeof window.Shiny.setInputValue !== "function" || !dynamic.plotId) {
                toast("This result plot cannot be prepared yet.");
                return Promise.reject(new Error("Result plot unavailable."));
            }

            toast("Rendering only the selected transcript…");
            window.Shiny.setInputValue("figure_studio_plot_render_request", {
                context: dynamic.context,
                ids: [dynamic.plotId],
                nonce: Date.now() + Math.random()
            }, { priority: "event" });
            if (dynamicRoot && window.Shiny && typeof window.Shiny.bindAll === "function") {
                try { window.Shiny.bindAll(dynamicRoot); } catch (err) {}
            }

            return pollForSvg([dynamic.outputId, dynamic.rootId], 25000).then(function (result) {
                addPanelFromMarkup({
                    key: key,
                    context: dynamic.context,
                    sourceId: dynamic.rootId,
                    sourceKind: "result",
                    sourceLabel: dynamic.sourceLabel,
                    title: dynamic.title,
                    markup: result.markup
                });
                return result;
            }).catch(function (err) {
                toast("The selected transcript could not be rendered. Please try again.");
                throw err;
            }).finally(function () {
                window.Shiny.setInputValue("figure_studio_plot_render_done", {
                    context: dynamic.context,
                    ids: [dynamic.plotId],
                    nonce: Date.now() + Math.random()
                }, { priority: "event" });
            });
        }

        var definition = getCatalogDefinition(key);
        if (!definition) return Promise.reject(new Error("Unknown chart."));
        var context = state.context;
        toast("Preparing " + definition.title + "…");
        return acquireCatalogSvg(definition, context).then(function (result) {
            addPanelFromMarkup({
                key: definition.key,
                context: context,
                sourceId: result.sourceId,
                sourceKind: definition.group.toLowerCase(),
                sourceLabel: definition.group,
                title: definition.title,
                markup: result.markup
            });
        }).catch(function (err) {
            toast(err && err.message ? err.message : "This chart is not available yet.");
            throw err;
        });
    }

    function titleFromResultCard(card) {
        if (!card) return "Gene / transcript structure";
        var header = card.querySelector(".card-header");
        var text = header ? String(header.innerText || header.textContent || "") : "";
        text = text.replace(/\s+/g, " ").replace(/(?:SVG|Function|Network|GO|NCBI|Ensembl|UniProt|Download[^|]*)/gi, "").trim();
        if (text.length > 92) text = text.slice(0, 89) + "…";
        return text || "Gene / transcript structure";
    }

    function contextFromResultCard(card) {
        return card && card.id && card.id.indexOf("ortho-card-") === 0 ? "ortho" : "homo";
    }

    function plotIdFromResultCard(card) {
        if (!card || !card.id) return "";
        if (card.id.indexOf("ortho-card-") === 0) return card.id.slice("ortho-card-".length);
        if (card.id.indexOf("homo-card-") === 0) return card.id.slice("homo-card-".length);
        return "";
    }

    function clearDynamicSourcesForContext(context) {
        Object.keys(dynamicSources).forEach(function (key) {
            if (dynamicSources[key] && dynamicSources[key].context === context) {
                delete dynamicSources[key];
            }
        });
    }

    function decorateResultCards() {
        var cards = Array.prototype.slice.call(document.querySelectorAll(".plot-transcript-card"));
        var seenByContext = {
            homo: Object.create(null),
            ortho: Object.create(null)
        };
        cards.forEach(function (card) {
            if (!card.id) return;
            seenByContext[contextFromResultCard(card)]["result-" + card.id] = true;
        });

        ["homo", "ortho"].forEach(function (context) {
            var seenKeys = Object.keys(seenByContext[context]);
            if (seenKeys.length) {
                Object.keys(dynamicSources).forEach(function (key) {
                    if (
                        dynamicSources[key] &&
                        dynamicSources[key].context === context &&
                        !seenByContext[context][key]
                    ) {
                        delete dynamicSources[key];
                    }
                });
                return;
            }
            var summary = byId(context === "ortho" ? "ortho_summary_section" : "homo_summary_section");
            if (summary && summary.style && summary.style.display === "none") {
                clearDynamicSourcesForContext(context);
            }
        });

        cards.forEach(function (card) {
            if (!card.id) return;
            var context = contextFromResultCard(card);
            var key = "result-" + card.id;
            var plotId = plotIdFromResultCard(card);
            var isTranscript = card.classList.contains("card-isoform");
            var transcriptId = String(card.getAttribute("data-transcript-id") || "").trim();
            var geneName = String(card.getAttribute("data-gene-name") || "").trim();
            var organismName = String(card.getAttribute("data-organism-name") || "").trim();
            dynamicSources[key] = {
                rootId: card.id,
                context: context,
                plotId: plotId,
                outputId: "plot_" + context + "_" + plotId + "-plot",
                title: titleFromResultCard(card),
                sourceLabel: isTranscript ? "Transcript structure" : "Gene structure",
                category: isTranscript ? "Transcripts" : "Gene structures",
                transcriptId: transcriptId,
                geneName: geneName,
                organismName: organismName
            };
        });
    }

    function sourceAvailability(definition, context, contextHasResults) {
        var candidates = sourceCandidates(definition, context);
        for (var i = 0; i < candidates.length; i += 1) {
            if (findSvg(candidates[i])) return { available: true, note: "Ready to add" };
        }
        if (definition.direct) {
            if (definition.key === "aligned") {
                if (contextHasResults && hasAlignedMode(context)) {
                    return { available: true, note: "Rendered when added" };
                }
                return {
                    available: false,
                    note: context === "ortho" ? "Needs cross-species results" : "Needs multiple transcripts"
                };
            }
            if (definition.key === "pip") {
                return { available: false, note: "Run LASTZ first" };
            }
            if (definition.key === "multipip") {
                return { available: false, note: "Run MultiPIP first" };
            }
            return { available: false, note: "Generate this view first" };
        }
        if (contextHasResults) {
            return { available: true, note: "Rendered on demand" };
        }
        return { available: false, note: "Generate results first" };
    }

    function renderCatalog() {
        var root = byId("figure-studio-catalog");
        if (!root) return;
        decorateResultCards();
        root.innerHTML = "";
        var queryInput = byId("figure-studio-catalog-search");
        var query = queryInput ? String(queryInput.value || "").trim().toLowerCase() : "";
        var context = state.context;
        var contextHasResults = hasContextResults(context);
        var groups = {};

        CATALOG.forEach(function (definition) {
            if (query && definition.title.toLowerCase().indexOf(query) < 0 && definition.group.toLowerCase().indexOf(query) < 0) return;
            if (!groups[definition.group]) groups[definition.group] = [];
            groups[definition.group].push({
                key: definition.key,
                title: definition.title,
                icon: definition.icon,
                availability: sourceAvailability(definition, context, contextHasResults)
            });
        });

        Object.keys(dynamicSources).forEach(function (key) {
            var dynamic = dynamicSources[key];
            if (dynamic.context !== context) return;
            var dynamicGroup = dynamic.category === "Transcripts" ? "Transcripts" : "Gene structures";
            var dynamicSearch = [
                dynamic.title,
                dynamicGroup,
                dynamic.sourceLabel,
                dynamic.transcriptId,
                dynamic.geneName,
                dynamic.organismName
            ].join(" ").toLowerCase();
            if (query && dynamicSearch.indexOf(query) < 0) return;
            if (!groups[dynamicGroup]) groups[dynamicGroup] = [];
            var dynamicReady = !!findSvg(byId(dynamic.rootId));
            var transcriptLabel = dynamic.transcriptId && dynamic.transcriptId !== "N/A"
                ? dynamic.transcriptId
                : "";
            var catalogTitle = dynamicGroup === "Transcripts"
                ? (dynamic.geneName ? dynamic.geneName + " transcript" : "Transcript")
                : dynamic.geneName
                    ? "Gene: " + dynamic.geneName
                    : dynamic.title;
            var catalogIdentifier = dynamicGroup === "Transcripts" && transcriptLabel
                ? transcriptLabel
                : dynamicGroup === "Gene structures" && dynamic.organismName
                    ? dynamic.organismName
                    : "";
            var catalogIdentifierTitle = dynamicGroup === "Transcripts" && transcriptLabel
                ? "Transcript ID: " + transcriptLabel
                : dynamicGroup === "Gene structures" && dynamic.organismName
                    ? "Organism: " + dynamic.organismName
                    : "";
            groups[dynamicGroup].push({
                key: key,
                title: catalogTitle,
                fullTitle: dynamic.title,
                identifier: catalogIdentifier,
                identifierTitle: catalogIdentifierTitle,
                icon: dynamicGroup === "Transcripts" ? "code-branch" : "dna",
                availability: {
                    available: true,
                    note: dynamicReady ? "Ready to add" : "Rendered when added"
                }
            });
        });

        ["Gene structures", "Transcripts", "Analytics", "Alignment"].forEach(function (groupName) {
            var items = groups[groupName] || [];
            if (!items.length) return;
            var group = make("section", "figure-catalog-group");
            var groupKey = context + ":" + groupName;
            var expanded = query
                ? true
                : Object.prototype.hasOwnProperty.call(catalogGroupExpanded, groupKey)
                    ? catalogGroupExpanded[groupKey]
                    : false;
            var groupHeading = make("button", "figure-catalog-group-heading");
            groupHeading.type = "button";
            groupHeading.setAttribute("aria-expanded", expanded ? "true" : "false");
            groupHeading.appendChild(make(
                "span",
                "figure-catalog-group-title",
                groupName === "Analytics" ? "Analytics / statistics" : groupName
            ));
            groupHeading.appendChild(make("span", "figure-catalog-group-count", String(items.length)));
            var groupChevron = make("i", "fa fa-chevron-down figure-catalog-group-chevron");
            groupChevron.setAttribute("aria-hidden", "true");
            groupHeading.appendChild(groupChevron);
            group.appendChild(groupHeading);
            var groupBody = make("div", "figure-catalog-group-items");
            groupBody.hidden = !expanded;
            items.forEach(function (item) {
                var button = make("button", "figure-catalog-item");
                button.type = "button";
                button.dataset.catalogKey = item.key;
                button.setAttribute("aria-disabled", item.availability.available ? "false" : "true");
                button.title = item.availability.note;

                var icon = make("span", "figure-catalog-icon");
                icon.innerHTML = '<i class="fa fa-' + item.icon + '" aria-hidden="true"></i>';
                var copy = make("span", "figure-catalog-copy");
                var itemTitle = make("strong", "", item.title);
                itemTitle.title = item.fullTitle || item.title;
                copy.appendChild(itemTitle);
                if (item.identifier) {
                    var identifier = make("small", "figure-catalog-identifier", item.identifier);
                    identifier.title = item.identifierTitle || item.identifier;
                    copy.appendChild(identifier);
                }
                copy.appendChild(make("small", "", item.availability.note));
                var add = make("span", "figure-catalog-add", item.availability.available ? "+ Add" : "Why?");
                button.appendChild(icon);
                button.appendChild(copy);
                button.appendChild(add);
                button.addEventListener("click", function () {
                    if (!item.availability.available) {
                        toast(item.availability.note + ".");
                        return;
                    }
                    addFromCatalog(item.key).catch(function () {});
                });
                groupBody.appendChild(button);
            });
            group.appendChild(groupBody);
            groupHeading.addEventListener("click", function () {
                var nextExpanded = groupHeading.getAttribute("aria-expanded") !== "true";
                catalogGroupExpanded[groupKey] = nextExpanded;
                groupHeading.setAttribute("aria-expanded", nextExpanded ? "true" : "false");
                groupBody.hidden = !nextExpanded;
            });
            root.appendChild(group);
        });
    }

    function collapseCatalogGroups(context) {
        var contexts = context === "ortho" || context === "homo"
            ? [context]
            : ["homo", "ortho"];
        contexts.forEach(function (itemContext) {
            ["Gene structures", "Transcripts", "Analytics", "Alignment"].forEach(function (groupName) {
                catalogGroupExpanded[itemContext + ":" + groupName] = false;
            });
        });
    }

    function parseSvgMarkup(markup) {
        if (!markup) return null;
        var doc = new DOMParser().parseFromString(markup, "image/svg+xml");
        if (doc.querySelector("parsererror")) return null;
        return doc.documentElement;
    }

    function parseColor(value) {
        var raw = String(value || "").trim().toLowerCase();
        if (!raw || raw === "none" || raw === "transparent" || raw === "currentcolor" || raw.indexOf("url(") === 0) return null;
        var named = {
            black: "#000000",
            white: "#ffffff",
            red: "#ff0000",
            blue: "#0000ff",
            green: "#008000",
            grey: "#808080",
            gray: "#808080"
        };
        if (named[raw]) raw = named[raw];
        var match;
        if ((match = raw.match(/^#([0-9a-f]{3})$/i))) {
            return {
                r: parseInt(match[1][0] + match[1][0], 16),
                g: parseInt(match[1][1] + match[1][1], 16),
                b: parseInt(match[1][2] + match[1][2], 16),
                a: 1
            };
        }
        if ((match = raw.match(/^#([0-9a-f]{6})([0-9a-f]{2})?$/i))) {
            return {
                r: parseInt(match[1].slice(0, 2), 16),
                g: parseInt(match[1].slice(2, 4), 16),
                b: parseInt(match[1].slice(4, 6), 16),
                a: match[2] ? parseInt(match[2], 16) / 255 : 1
            };
        }
        if ((match = raw.match(/^rgba?\(\s*([0-9.]+)[,\s]+([0-9.]+)[,\s]+([0-9.]+)(?:\s*[,/]\s*([0-9.]+))?\s*\)$/i))) {
            return {
                r: Math.max(0, Math.min(255, Number(match[1]))),
                g: Math.max(0, Math.min(255, Number(match[2]))),
                b: Math.max(0, Math.min(255, Number(match[3]))),
                a: match[4] == null ? 1 : Math.max(0, Math.min(1, Number(match[4])))
            };
        }
        return null;
    }

    function colorKey(value) {
        var color = parseColor(value);
        if (!color) return "";
        return [Math.round(color.r), Math.round(color.g), Math.round(color.b), Math.round(color.a * 100)].join(",");
    }

    function luminance(color) {
        if (!color) return 0;
        return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) / 255;
    }

    function saturation(color) {
        if (!color) return 0;
        var max = Math.max(color.r, color.g, color.b);
        var min = Math.min(color.r, color.g, color.b);
        return max === 0 ? 0 : (max - min) / max;
    }

    function paintValue(node, property) {
        if (!node) return "";
        var attr = node.getAttribute(property);
        if (attr) return attr;
        if (node.style && node.style[property]) return node.style[property];
        return "";
    }

    function setPaint(node, property, value) {
        if (!node) return;
        if (node.hasAttribute(property)) node.setAttribute(property, value);
        if (node.style && node.style[property]) node.style[property] = value;
        if (!node.hasAttribute(property) && (!node.style || !node.style[property])) node.setAttribute(property, value);
    }

    function ensureDefs(svg) {
        var defs = svg.querySelector(":scope > defs");
        if (!defs) {
            defs = document.createElementNS(SVG_NS, "defs");
            svg.insertBefore(defs, svg.firstChild);
        }
        return defs;
    }

    function addMonoPatterns(svg, prefix, count) {
        var defs = ensureDefs(svg);
        var ids = [];
        var types = ["solid", "diagonal", "dots", "cross", "horizontal", "open"];
        for (var i = 0; i < count; i += 1) {
            var type = types[i % types.length];
            var id = prefix + "-pattern-" + i;
            ids.push(id);
            var pattern = document.createElementNS(SVG_NS, "pattern");
            pattern.setAttribute("id", id);
            pattern.setAttribute("patternUnits", "userSpaceOnUse");
            pattern.setAttribute("width", "8");
            pattern.setAttribute("height", "8");
            var background = document.createElementNS(SVG_NS, "rect");
            background.setAttribute("width", "8");
            background.setAttribute("height", "8");
            background.setAttribute("fill", type === "solid" ? "#111111" : "#ffffff");
            pattern.appendChild(background);
            if (type === "diagonal" || type === "cross" || type === "horizontal") {
                var path = document.createElementNS(SVG_NS, "path");
                if (type === "horizontal") path.setAttribute("d", "M0 4 H8");
                else if (type === "cross") path.setAttribute("d", "M-2 2 L2 -2 M0 8 L8 0 M6 10 L10 6 M-2 6 L2 10 M0 0 L8 8 M6 -2 L10 2");
                else path.setAttribute("d", "M-2 2 L2 -2 M0 8 L8 0 M6 10 L10 6");
                path.setAttribute("stroke", "#111111");
                path.setAttribute("stroke-width", "1.15");
                pattern.appendChild(path);
            } else if (type === "dots") {
                var circle = document.createElementNS(SVG_NS, "circle");
                circle.setAttribute("cx", "2");
                circle.setAttribute("cy", "2");
                circle.setAttribute("r", "1.05");
                circle.setAttribute("fill", "#111111");
                pattern.appendChild(circle);
            }
            defs.appendChild(pattern);
        }
        return ids;
    }

    function forcePaperBackground(svg) {
        var viewBox = String(svg.getAttribute("viewBox") || "0 0 1200 520").trim().split(/\s+/).map(Number);
        if (viewBox.length !== 4 || viewBox.some(function (n) { return !isFinite(n); })) viewBox = [0, 0, 1200, 520];
        var background = document.createElementNS(SVG_NS, "rect");
        background.setAttribute("x", String(viewBox[0]));
        background.setAttribute("y", String(viewBox[1]));
        background.setAttribute("width", String(viewBox[2]));
        background.setAttribute("height", String(viewBox[3]));
        background.setAttribute("fill", "#ffffff");
        background.setAttribute("class", "figure-studio-paper-background");
        var defs = svg.querySelector(":scope > defs");
        if (defs && defs.nextSibling) svg.insertBefore(background, defs.nextSibling);
        else if (defs) svg.appendChild(background);
        else svg.insertBefore(background, svg.firstChild);
        svg.style.background = "#ffffff";
    }

    function transformSvg(svg, profile, panelId) {
        if (!svg) return null;
        var mode = String(profile || "color");
        if (mode === "color") return svg;

        forcePaperBackground(svg);
        var paintNodes = Array.prototype.slice.call(svg.querySelectorAll("path, rect, circle, ellipse, polygon, polyline, line, text, tspan"));
        var fillKeys = [];
        var strokeKeys = [];
        paintNodes.forEach(function (node) {
            var fill = paintValue(node, "fill");
            var fillColor = parseColor(fill);
            if (fillColor && fillColor.a > 0.01 && luminance(fillColor) > 0.10 && luminance(fillColor) < 0.94) {
                var fKey = colorKey(fill);
                if (fKey && fillKeys.indexOf(fKey) < 0) fillKeys.push(fKey);
            }
            var stroke = paintValue(node, "stroke");
            var strokeColor = parseColor(stroke);
            if (strokeColor && strokeColor.a > 0.01 && saturation(strokeColor) > 0.08) {
                var sKey = colorKey(stroke);
                if (sKey && strokeKeys.indexOf(sKey) < 0) strokeKeys.push(sKey);
            }
        });

        var grayPalette = ["#202020", "#555555", "#858585", "#b0b0b0", "#dddddd"];
        var cbPalette = ["#0072b2", "#e69f00", "#009e73", "#cc79a7", "#d55e00", "#56b4e9", "#f0e442", "#777777"];
        var monoPatterns = mode === "mono" ? addMonoPatterns(svg, panelId.replace(/[^A-Za-z0-9_-]/g, ""), Math.max(1, fillKeys.length)) : [];
        var dashPalette = ["", "9 4", "2 3", "10 3 2 3", "5 3 1 3"];

        paintNodes.forEach(function (node) {
            var tag = String(node.tagName || "").toLowerCase();
            var fill = paintValue(node, "fill");
            var fillColor = parseColor(fill);
            var fKey = colorKey(fill);
            var fIndex = fillKeys.indexOf(fKey);
            var stroke = paintValue(node, "stroke");
            var strokeColor = parseColor(stroke);
            var sKey = colorKey(stroke);
            var sIndex = strokeKeys.indexOf(sKey);

            if (tag === "text" || tag === "tspan") {
                setPaint(node, "fill", "#111111");
                if (strokeColor) setPaint(node, "stroke", "none");
                return;
            }

            if (fillColor && fillColor.a > 0.01) {
                var lum = luminance(fillColor);
                if (lum >= 0.94) {
                    setPaint(node, "fill", "#ffffff");
                } else if (mode === "paper-color") {
                    if (lum < 0.12 && saturation(fillColor) < 0.08) setPaint(node, "fill", "#111111");
                } else if (mode === "colorblind" && fIndex >= 0) {
                    setPaint(node, "fill", cbPalette[fIndex % cbPalette.length]);
                } else if (mode === "gray" && fIndex >= 0) {
                    setPaint(node, "fill", grayPalette[fIndex % grayPalette.length]);
                } else if (mode === "mono") {
                    if (fIndex >= 0) setPaint(node, "fill", "url(#" + monoPatterns[fIndex % monoPatterns.length] + ")");
                    else if (lum < 0.20) setPaint(node, "fill", "#111111");
                    else setPaint(node, "fill", "#ffffff");
                }
            }

            if (strokeColor && strokeColor.a > 0.01) {
                if (mode === "paper-color") {
                    if (luminance(strokeColor) > 0.82 && saturation(strokeColor) < 0.10) setPaint(node, "stroke", "#41515f");
                } else if (mode === "colorblind" && sIndex >= 0) {
                    setPaint(node, "stroke", cbPalette[sIndex % cbPalette.length]);
                } else if (mode === "gray") {
                    setPaint(node, "stroke", sIndex >= 0 ? grayPalette[sIndex % grayPalette.length] : "#222222");
                    if (sIndex > 0 && (tag === "path" || tag === "line" || tag === "polyline")) {
                        node.setAttribute("stroke-dasharray", dashPalette[sIndex % dashPalette.length]);
                    }
                } else if (mode === "mono") {
                    setPaint(node, "stroke", "#111111");
                    if (sIndex > 0 && (tag === "path" || tag === "line" || tag === "polyline")) {
                        node.setAttribute("stroke-dasharray", dashPalette[sIndex % dashPalette.length]);
                    }
                }
            }
        });

        return svg;
    }

    function panelPreparedSvg(panel) {
        var raw = runtimeSvg[panel.id] || "";
        if (!raw) return null;
        var svg = parseSvgMarkup(raw);
        if (!svg) return null;
        return transformSvg(svg, state.profile, panel.id);
    }

    function finiteSvgLength(value) {
        var match = String(value || "").trim().match(/^([0-9]*\.?[0-9]+)/);
        var number = match ? Number(match[1]) : NaN;
        return isFinite(number) && number > 0 ? number : 0;
    }

    function panelSvgAspect(panel) {
        var svg = parseSvgMarkup(runtimeSvg[panel.id] || "");
        if (!svg) return 1.6;
        var viewBox = String(svg.getAttribute("viewBox") || "").trim().split(/[\s,]+/).map(Number);
        var width = viewBox.length === 4 && isFinite(viewBox[2]) && viewBox[2] > 0
            ? viewBox[2]
            : finiteSvgLength(svg.getAttribute("width"));
        var height = viewBox.length === 4 && isFinite(viewBox[3]) && viewBox[3] > 0
            ? viewBox[3]
            : finiteSvgLength(svg.getAttribute("height"));
        if (!width || !height) return 1.6;
        return Math.max(0.12, Math.min(30, width / height));
    }

    function panelGeometryClass(panel) {
        if (
            panel.sourceKind === "alignment" ||
            panel.key === "aligned" ||
            panel.key === "pip" ||
            panel.key === "multipip"
        ) return "alignment";
        if (panel.sourceKind === "result") return "result";
        if (panel.sourceKind === "analytics") return "analytics";
        return "chart";
    }

    function clampNumber(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function autoPlotHeight(panel, contentWidth, previewMode) {
        var width = Math.max(180, Number(contentWidth || 0) - (previewMode ? 16 : 24));
        var natural = width / panelSvgAspect(panel);
        var kind = panelGeometryClass(panel);
        if (previewMode) {
            if (kind === "alignment") return clampNumber(natural, 180, 2400);
            if (kind === "result") return clampNumber(natural, 80, 380);
            if (kind === "analytics") return clampNumber(natural, 140, 1000);
            return clampNumber(natural, 120, 1000);
        }
        if (kind === "alignment") return clampNumber(natural, 180, 7200);
        if (kind === "result") return clampNumber(natural, 60, 620);
        if (kind === "analytics") return clampNumber(natural, 100, 2400);
        return clampNumber(natural, 100, 2400);
    }

    function resolvedPanelHeight(panel, contentWidth) {
        if (panel.height !== "auto") return HEIGHTS[panel.height] || HEIGHTS.standard;
        var titleHeight = panel.showTitle ? 58 : 16;
        return Math.round(titleHeight + autoPlotHeight(panel, contentWidth, false) + 12);
    }

    function applyPanelPreviewHeight(panel, article, preview) {
        if (panel.height !== "auto") {
            preview.style.removeProperty("--panel-auto-preview-height");
            return;
        }
        var width = article.getBoundingClientRect().width || article.clientWidth || 500;
        preview.style.setProperty(
            "--panel-auto-preview-height",
            Math.round(autoPlotHeight(panel, width, true)) + "px"
        );
        var svg = preview.querySelector("svg");
        if (svg) {
            svg.style.setProperty("aspect-ratio", String(panelSvgAspect(panel)));
            svg.style.setProperty("height", "auto", "important");
        }
    }

    function renderPanelPreview(panel, preview) {
        var svg = panelPreparedSvg(panel);
        if (!svg) {
            preview.innerHTML = "";
            var unavailable = make("div", "figure-panel-unavailable");
            unavailable.innerHTML = '<i class="fa fa-exclamation-circle" aria-hidden="true"></i><strong>Source unavailable</strong><span>Restore or generate the original CGV result, then refresh this panel.</span>';
            preview.appendChild(unavailable);
            return;
        }
        preview.innerHTML = "";
        preview.appendChild(document.importNode(svg, true));
    }

    function renderPanels() {
        var canvas = byId("figure-studio-canvas");
        var empty = byId("figure-studio-empty");
        if (!canvas || !empty) return;
        canvas.style.setProperty("--figure-columns", String(state.columns));
        canvas.innerHTML = "";
        var hasPanels = state.panels.length > 0;
        empty.hidden = hasPanels;
        canvas.classList.toggle("is-empty", !hasPanels);

        state.panels.forEach(function (panel, index) {
            var article = make("article", "figure-panel");
            article.dataset.panelId = panel.id;
            article.dataset.panelHeight = panel.height;
            article.style.setProperty("--panel-span", String(Math.min(panel.span, state.columns)));
            article.classList.toggle("is-selected", panel.id === state.selectedId);
            article.draggable = true;
            article.setAttribute("aria-label", "Panel " + panelLabel(index) + ": " + panel.title);

            var header = make("header", "figure-panel-header");
            if (!panel.showTitle) header.hidden = true;
            header.appendChild(make("span", "figure-panel-label", panelLabel(index)));
            header.appendChild(make("strong", "figure-panel-title", panel.title));
            header.appendChild(make("span", "figure-panel-source-chip", panel.sourceLabel));
            var quick = make("span", "figure-panel-quick-actions");
            var duplicate = make("button", "", "");
            duplicate.type = "button";
            duplicate.title = "Duplicate panel";
            duplicate.setAttribute("aria-label", "Duplicate panel");
            duplicate.innerHTML = '<i class="fa fa-clone" aria-hidden="true"></i>';
            duplicate.addEventListener("click", function (event) {
                event.stopPropagation();
                duplicatePanel(panel.id);
            });
            var remove = make("button", "", "");
            remove.type = "button";
            remove.title = "Remove panel";
            remove.setAttribute("aria-label", "Remove panel");
            remove.innerHTML = '<i class="fa fa-times" aria-hidden="true"></i>';
            remove.addEventListener("click", function (event) {
                event.stopPropagation();
                removePanel(panel.id);
            });
            quick.appendChild(duplicate);
            quick.appendChild(remove);
            header.appendChild(quick);

            var preview = make("div", "figure-panel-preview");
            renderPanelPreview(panel, preview);
            article.appendChild(header);
            article.appendChild(preview);
            article.addEventListener("click", function () {
                selectPanel(panel.id);
            });
            article.addEventListener("dragstart", function (event) {
                dragPanelId = panel.id;
                article.classList.add("is-dragging");
                if (event.dataTransfer) {
                    event.dataTransfer.effectAllowed = "move";
                    event.dataTransfer.setData("text/plain", panel.id);
                }
            });
            article.addEventListener("dragend", function () {
                dragPanelId = "";
                article.classList.remove("is-dragging");
                canvas.querySelectorAll(".is-drop-target").forEach(function (node) {
                    node.classList.remove("is-drop-target");
                });
            });
            article.addEventListener("dragover", function (event) {
                if (!dragPanelId || dragPanelId === panel.id) return;
                event.preventDefault();
                article.classList.add("is-drop-target");
            });
            article.addEventListener("dragleave", function () {
                article.classList.remove("is-drop-target");
            });
            article.addEventListener("drop", function (event) {
                event.preventDefault();
                article.classList.remove("is-drop-target");
                reorderPanel(dragPanelId, panel.id);
            });
            canvas.appendChild(article);
            applyPanelPreviewHeight(panel, article, preview);
        });
    }

    function renderInspector() {
        var panel = selectedPanel();
        var empty = byId("figure-studio-inspector-empty");
        var form = byId("figure-studio-inspector-form");
        var heading = byId("figure-studio-inspector-title");
        if (!empty || !form || !heading) return;
        empty.hidden = !!panel;
        form.hidden = !panel;
        heading.textContent = panel ? "Panel " + panelLabel(state.panels.indexOf(panel)) : "No panel selected";
        if (!panel) return;
        var title = byId("figure-studio-panel-title");
        var source = byId("figure-studio-panel-source");
        var span = byId("figure-studio-panel-span");
        var height = byId("figure-studio-panel-height");
        var showTitle = byId("figure-studio-panel-show-title");
        if (title) title.value = panel.title;
        if (source) source.textContent = panel.sourceLabel + " · " + (panel.context === "ortho" ? "Cross-Species" : "Multi-Gene");
        if (span) {
            span.value = String(Math.min(panel.span, state.columns));
            Array.prototype.forEach.call(span.options, function (option) {
                option.disabled = Number(option.value) > state.columns;
            });
        }
        if (height) height.value = panel.height;
        if (showTitle) showTitle.checked = panel.showTitle !== false;
        var index = state.panels.indexOf(panel);
        var back = byId("figure-studio-move-back");
        var forward = byId("figure-studio-move-forward");
        if (back) back.disabled = index <= 0;
        if (forward) forward.disabled = index < 0 || index >= state.panels.length - 1;
    }

    function updateSizeWarning() {
        var warning = byId("figure-studio-size-warning");
        if (!warning) return;
        var count = state.panels.length;
        var tallCount = state.panels.filter(function (panel) {
            return panel.height === "tall" || (
                panel.height === "auto" &&
                panelGeometryClass(panel) === "alignment" &&
                panelSvgAspect(panel) < 0.9
            );
        }).length;
        var show = count > 8 || (count > 5 && tallCount > 1) || (count > 3 && tallCount > 2);
        warning.hidden = !show;
        var span = warning.querySelector("span");
        if (span) {
            span.textContent = show
                ? "This is becoming a large publication figure. Auto sizing preserves chart detail; use a manual compact height only when you intentionally want a denser layout."
                : "";
        }
    }

    function updateSummary() {
        var count = state.panels.length;
        var summary = byId("figure-studio-panel-summary");
        if (summary) summary.textContent = count + (count === 1 ? " panel" : " panels") + " · one chart per panel";
    }

    function renderAll() {
        renderPanels();
        renderInspector();
        renderCatalog();
        updateSummary();
        updateSizeWarning();
        updateHistoryButtons();
    }

    function syncControls() {
        var title = byId("figure-studio-title");
        var subtitle = byId("figure-studio-subtitle");
        var columns = byId("figure-studio-columns");
        var profile = byId("figure-studio-profile");
        var resolution = byId("figure-studio-resolution");
        var context = byId("figure-studio-context");
        if (title) title.value = state.title;
        if (subtitle) subtitle.value = state.subtitle;
        if (columns) columns.value = String(state.columns);
        if (profile) profile.value = state.profile;
        if (resolution) resolution.value = String(state.resolution);
        if (context) context.value = state.context;
    }

    function selectPanel(id) {
        state.selectedId = String(id || "");
        renderPanels();
        renderInspector();
        persistSoon();
    }

    function removePanel(id) {
        var index = state.panels.findIndex(function (panel) { return panel.id === id; });
        if (index < 0) return;
        saveHistory();
        state.panels.splice(index, 1);
        delete runtimeSvg[id];
        if (state.selectedId === id) {
            state.selectedId = state.panels.length ? state.panels[Math.min(index, state.panels.length - 1)].id : null;
        }
        renderAll();
        persistSoon();
    }

    function duplicatePanel(id) {
        var index = state.panels.findIndex(function (panel) { return panel.id === id; });
        if (index < 0) return;
        saveHistory();
        var source = state.panels[index];
        var copy = cloneJson(source);
        copy.id = makePanelId();
        copy.title = source.title + " copy";
        state.panels.splice(index + 1, 0, copy);
        runtimeSvg[copy.id] = runtimeSvg[source.id] || "";
        state.selectedId = copy.id;
        renderAll();
        persistSoon();
        toast("Panel duplicated as " + panelLabel(index + 1) + ".");
    }

    function reorderPanel(sourceId, targetId) {
        if (!sourceId || !targetId || sourceId === targetId) return;
        var sourceIndex = state.panels.findIndex(function (panel) { return panel.id === sourceId; });
        var targetIndex = state.panels.findIndex(function (panel) { return panel.id === targetId; });
        if (sourceIndex < 0 || targetIndex < 0) return;
        saveHistory();
        var moved = state.panels.splice(sourceIndex, 1)[0];
        if (sourceIndex < targetIndex) targetIndex -= 1;
        state.panels.splice(targetIndex, 0, moved);
        state.selectedId = moved.id;
        renderAll();
        persistSoon();
    }

    function moveSelected(delta) {
        var panel = selectedPanel();
        if (!panel) return;
        var index = state.panels.indexOf(panel);
        var nextIndex = index + Number(delta || 0);
        if (nextIndex < 0 || nextIndex >= state.panels.length) return;
        saveHistory();
        state.panels.splice(index, 1);
        state.panels.splice(nextIndex, 0, panel);
        renderAll();
        persistSoon();
    }

    function updateSelectedPanel(property, value) {
        var panel = selectedPanel();
        if (!panel) return;
        saveHistory();
        if (property === "title") panel.title = String(value || "CGV visualization").slice(0, 120);
        else if (property === "span") panel.span = safeInt(value, 1, 1, state.columns);
        else if (property === "height" && validHeightMode(value)) panel.height = value;
        else if (property === "showTitle") panel.showTitle = !!value;
        renderAll();
        persistSoon();
    }

    function clearFigure(requireConfirmation) {
        if (!state.panels.length) return;
        if (requireConfirmation && !window.confirm("Clear every Figure Studio panel? Your CGV search results will not be removed.")) return;
        saveHistory();
        state.panels = [];
        state.selectedId = null;
        runtimeSvg = Object.create(null);
        renderAll();
        persistSoon();
        toast("Figure Studio canvas cleared. CGV results were preserved.");
    }

    function newFigure() {
        if (state.panels.length && !window.confirm("Start a new figure? Existing CGV search results will remain available.")) return;
        saveHistory();
        var context = state.context;
        var lastTarget = state.lastResultsTarget;
        state = sanitizeState({
            title: "CGV comparative analysis",
            subtitle: "",
            columns: 2,
            profile: "color",
            resolution: 2,
            context: context,
            lastResultsTarget: lastTarget,
            panels: []
        });
        runtimeSvg = Object.create(null);
        syncControls();
        renderAll();
        persistSoon();
    }

    function openStudio(context) {
        if (context === "homo" || context === "ortho") {
            state.context = context;
            state.lastResultsTarget = context === "ortho" ? "orthologous" : "homologous";
            var contextSelect = byId("figure-studio-context");
            if (contextSelect) contextSelect.value = context;
        }
        collapseCatalogGroups(state.context);
        var button = document.querySelector('.app-nav-btn[data-target="figure-studio"]');
        if (button) button.click();
        else {
            var link = document.querySelector('#navtabs a[data-value="figure-studio"]');
            if (link) link.click();
        }
        renderCatalog();
        persistSoon();
    }

    function backToResults() {
        var target = state.lastResultsTarget === "orthologous" ? "orthologous" : "homologous";
        var button = document.querySelector('.app-nav-btn[data-target="' + target + '"]');
        if (button) button.click();
    }

    function rehydratePanel(panel) {
        if (runtimeSvg[panel.id]) return Promise.resolve();
        if (panel.sourceId) {
            var immediate = captureContainer(panel.sourceId);
            if (immediate) {
                runtimeSvg[panel.id] = immediate;
                return Promise.resolve();
            }
        }
        var definition = getCatalogDefinition(panel.key);
        if (!definition) return Promise.resolve();
        return acquireCatalogSvg(definition, panel.context).then(function (result) {
            runtimeSvg[panel.id] = result.markup;
            panel.sourceId = result.sourceId;
        }).catch(function () {});
    }

    function rehydratePanels() {
        if (!state.panels.length) return;
        Promise.all(state.panels.map(rehydratePanel)).then(function () {
            renderPanels();
            renderCatalog();
        });
    }

    function prefixSvgIds(svg, prefix) {
        var idMap = {};
        svg.querySelectorAll("[id]").forEach(function (node) {
            var oldId = node.getAttribute("id");
            var nextId = prefix + "-" + oldId;
            idMap[oldId] = nextId;
            node.setAttribute("id", nextId);
        });
        var refAttrs = ["fill", "stroke", "filter", "clip-path", "mask", "marker-start", "marker-mid", "marker-end", "href", "xlink:href", "aria-labelledby", "aria-describedby"];
        svg.querySelectorAll("*").forEach(function (node) {
            refAttrs.forEach(function (attrName) {
                var value = node.getAttribute(attrName);
                if (!value) return;
                Object.keys(idMap).forEach(function (oldId) {
                    value = value.replace(new RegExp("url\\(#" + oldId.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\)", "g"), "url(#" + idMap[oldId] + ")");
                    if (value === "#" + oldId) value = "#" + idMap[oldId];
                    value = value.replace(new RegExp("(^|\\s)" + oldId.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "(?=\\s|$)", "g"), "$1" + idMap[oldId]);
                });
                node.setAttribute(attrName, value);
            });
            var style = node.getAttribute("style");
            if (style) {
                Object.keys(idMap).forEach(function (oldId) {
                    style = style.replace(new RegExp("url\\(#" + oldId.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\)", "g"), "url(#" + idMap[oldId] + ")");
                });
                node.setAttribute("style", style);
            }
        });
    }

    function buildRows(columnWidth, gapX) {
        var rows = [];
        var current = { panels: [], used: 0, height: 0 };
        state.panels.forEach(function (panel, index) {
            var span = Math.max(1, Math.min(state.columns, panel.span));
            if (current.panels.length && current.used + span > state.columns) {
                rows.push(current);
                current = { panels: [], used: 0, height: 0 };
            }
            var cellWidth = span * columnWidth + (span - 1) * gapX;
            var panelHeight = resolvedPanelHeight(panel, cellWidth);
            current.panels.push({ panel: panel, index: index, span: span, column: current.used, height: panelHeight });
            current.used += span;
            current.height = Math.max(current.height, panelHeight);
        });
        if (current.panels.length) rows.push(current);
        return rows;
    }

    function buildCompositeSvg() {
        if (!state.panels.length) throw new Error("Add at least one chart panel before exporting.");
        var missing = state.panels.filter(function (panel) { return !runtimeSvg[panel.id]; });
        if (missing.length) throw new Error("One or more panel sources are unavailable. Restore or regenerate those CGV results first.");

        var pageWidth = 1800;
        var marginX = 70;
        var hasTitle = String(state.title || "").trim().length > 0;
        var hasSubtitle = String(state.subtitle || "").trim().length > 0;
        var marginTop = hasTitle ? (hasSubtitle ? 108 : 82) : (hasSubtitle ? 74 : 36);
        var marginBottom = 65;
        var gapX = 24;
        var gapY = 26;
        var columns = state.columns;
        var columnWidth = (pageWidth - (2 * marginX) - ((columns - 1) * gapX)) / columns;
        var rows = buildRows(columnWidth, gapX);
        var totalRowsHeight = rows.reduce(function (sum, row) { return sum + row.height; }, 0);
        var pageHeight = marginTop + totalRowsHeight + Math.max(0, rows.length - 1) * gapY + marginBottom;
        var root = document.createElementNS(SVG_NS, "svg");
        root.setAttribute("xmlns", SVG_NS);
        root.setAttribute("xmlns:xlink", XLINK_NS);
        root.setAttribute("viewBox", "0 0 " + pageWidth + " " + pageHeight);
        root.setAttribute("width", String(pageWidth));
        root.setAttribute("height", String(pageHeight));
        root.setAttribute("role", "img");
        root.setAttribute("aria-label", state.title || "CGV publication figure");

        var studioPage = document.querySelector(".figure-studio-page");
        var studioVersion = String(
            (studioPage && studioPage.getAttribute("data-figure-studio-version")) || "stable"
        ).trim();
        var metadata = document.createElementNS(SVG_NS, "metadata");
        metadata.textContent = JSON.stringify({
            generator: "CGV Figure Studio " + studioVersion,
            createdAt: new Date().toISOString(),
            profile: state.profile,
            subtitle: state.subtitle,
            panels: state.panels.map(function (panel, index) {
                return { label: panelLabel(index), title: panel.title, source: panel.sourceLabel };
            })
        });
        root.appendChild(metadata);

        var style = document.createElementNS(SVG_NS, "style");
        style.textContent = [
            "text{font-family:Arial,Helvetica,sans-serif;fill:#111827}",
            ".cgv-figure-title{font-size:30px;font-weight:700}",
            ".cgv-figure-subtitle{font-size:18px;font-weight:400;fill:#526579}",
            ".cgv-panel-label{font-size:25px;font-weight:800}",
            ".cgv-panel-title{font-size:22px;font-weight:700}",
            ".cgv-panel-frame{fill:#fff;stroke:#d1d5db;stroke-width:1}"
        ].join("");
        root.appendChild(style);

        var background = document.createElementNS(SVG_NS, "rect");
        background.setAttribute("width", String(pageWidth));
        background.setAttribute("height", String(pageHeight));
        background.setAttribute("fill", "#ffffff");
        root.appendChild(background);

        if (hasTitle) {
            var title = document.createElementNS(SVG_NS, "text");
            title.setAttribute("x", String(pageWidth / 2));
            title.setAttribute("y", "38");
            title.setAttribute("text-anchor", "middle");
            title.setAttribute("class", "cgv-figure-title");
            title.textContent = state.title;
            root.appendChild(title);
        }
        if (hasSubtitle) {
            var subtitle = document.createElementNS(SVG_NS, "text");
            subtitle.setAttribute("x", String(pageWidth / 2));
            subtitle.setAttribute("y", hasTitle ? "67" : "38");
            subtitle.setAttribute("text-anchor", "middle");
            subtitle.setAttribute("class", "cgv-figure-subtitle");
            subtitle.textContent = state.subtitle;
            root.appendChild(subtitle);
        }

        var y = marginTop;
        rows.forEach(function (row) {
            row.panels.forEach(function (entry) {
                var panel = entry.panel;
                var cellX = marginX + entry.column * (columnWidth + gapX);
                var cellWidth = entry.span * columnWidth + (entry.span - 1) * gapX;
                var group = document.createElementNS(SVG_NS, "g");
                group.setAttribute("data-panel-id", panel.id);
                group.setAttribute("transform", "translate(" + cellX + " " + y + ")");

                var frame = document.createElementNS(SVG_NS, "rect");
                frame.setAttribute("x", "0");
                frame.setAttribute("y", "0");
                frame.setAttribute("width", String(cellWidth));
                frame.setAttribute("height", String(entry.height));
                frame.setAttribute("rx", "4");
                frame.setAttribute("class", "cgv-panel-frame");
                group.appendChild(frame);

                var titleHeight = panel.showTitle ? 58 : 16;
                if (panel.showTitle) {
                    var label = document.createElementNS(SVG_NS, "text");
                    label.setAttribute("x", "18");
                    label.setAttribute("y", "36");
                    label.setAttribute("class", "cgv-panel-label");
                    label.textContent = panelLabel(entry.index);
                    group.appendChild(label);

                    var panelTitle = document.createElementNS(SVG_NS, "text");
                    panelTitle.setAttribute("x", "62");
                    panelTitle.setAttribute("y", "35");
                    panelTitle.setAttribute("class", "cgv-panel-title");
                    panelTitle.textContent = panel.title;
                    group.appendChild(panelTitle);
                }

                var prepared = panelPreparedSvg(panel);
                if (!prepared) throw new Error("Panel " + panelLabel(entry.index) + " could not be prepared.");
                prefixSvgIds(prepared, "cgv-" + panel.id.replace(/[^A-Za-z0-9_-]/g, ""));
                prepared.setAttribute("x", "12");
                prepared.setAttribute("y", String(titleHeight));
                prepared.setAttribute("width", String(cellWidth - 24));
                prepared.setAttribute("height", String(entry.height - titleHeight - 12));
                prepared.setAttribute("preserveAspectRatio", "xMidYMid meet");
                prepared.setAttribute("overflow", "hidden");
                group.appendChild(document.importNode(prepared, true));
                root.appendChild(group);
            });
            y += row.height + gapY;
        });

        return root;
    }

    function serializeCompositeSvg() {
        var svg = buildCompositeSvg();
        var xml = new XMLSerializer().serializeToString(svg);
        return '<?xml version="1.0" encoding="UTF-8"?>\n' + xml;
    }

    function figureFilename(extension) {
        var base = String(state.title || "cgv_publication_figure")
            .trim()
            .replace(/[^A-Za-z0-9._-]+/g, "_")
            .replace(/^_+|_+$/g, "") || "cgv_publication_figure";
        var filename = base + "." + extension;
        if (typeof window.sanitizeFilename === "function") {
            return window.sanitizeFilename(filename, "cgv_publication_figure." + extension);
        }
        return filename;
    }

    function downloadData(blob, filename) {
        if (typeof window.downloadBlob === "function") {
            window.downloadBlob(blob, filename);
            return;
        }
        var url = URL.createObjectURL(blob);
        var anchor = document.createElement("a");
        anchor.href = url;
        anchor.download = filename;
        document.body.appendChild(anchor);
        anchor.click();
        anchor.remove();
        setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
    }

    function profileLabel(profile) {
        var labels = {
            color: "Full Color",
            "paper-color": "Paper Color",
            colorblind: "Colorblind",
            gray: "Paper Gray",
            mono: "Paper Mono"
        };
        return labels[profile] || "Full Color";
    }

    function closeExportPreview() {
        var modal = byId("figure-studio-preview-modal");
        var paper = byId("figure-studio-preview-paper");
        if (!modal || modal.hidden) return;
        modal.hidden = true;
        modal.setAttribute("aria-hidden", "true");
        document.documentElement.classList.remove("figure-studio-preview-open");
        if (paper) paper.innerHTML = "";
        if (previewReturnFocus && typeof previewReturnFocus.focus === "function") {
            previewReturnFocus.focus();
        }
        previewReturnFocus = null;
    }

    function mountPreviewModal() {
        var modal = byId("figure-studio-preview-modal");
        if (modal && modal.parentNode !== document.body) {
            document.body.appendChild(modal);
        }
    }

    function tooltipTarget(node) {
        if (!node || !node.closest) return null;
        var trigger = node.closest("[data-figure-tooltip]");
        if (!trigger) return null;
        if (!trigger.closest(".figure-studio-page") && !trigger.closest(".figure-studio-preview-modal")) {
            return null;
        }
        return trigger;
    }

    function ensureTooltipPortal() {
        if (tooltipPortal && tooltipPortal.isConnected) return tooltipPortal;
        tooltipPortal = document.createElement("div");
        tooltipPortal.id = "figure-studio-tooltip";
        tooltipPortal.className = "figure-studio-tooltip-portal";
        tooltipPortal.setAttribute("role", "tooltip");
        tooltipPortal.hidden = true;
        document.body.appendChild(tooltipPortal);
        return tooltipPortal;
    }

    function hideFigureTooltip() {
        tooltipTrigger = null;
        var tooltip = ensureTooltipPortal();
        tooltip.hidden = true;
        tooltip.removeAttribute("data-placement");
    }

    function positionFigureTooltip(trigger) {
        var tooltip = ensureTooltipPortal();
        if (!trigger || !trigger.isConnected || tooltip.hidden) return;

        var viewportWidth = Math.max(document.documentElement.clientWidth || 0, window.innerWidth || 0);
        var viewportHeight = Math.max(document.documentElement.clientHeight || 0, window.innerHeight || 0);
        var gap = 10;
        var triggerRect = trigger.getBoundingClientRect();
        var tooltipRect = tooltip.getBoundingClientRect();
        var left = triggerRect.left + (triggerRect.width / 2) - (tooltipRect.width / 2);
        var top = triggerRect.bottom + 8;
        var placement = "bottom";

        left = Math.max(gap, Math.min(left, viewportWidth - tooltipRect.width - gap));
        if (top + tooltipRect.height > viewportHeight - gap) {
            top = triggerRect.top - tooltipRect.height - 8;
            placement = "top";
        }
        top = Math.max(gap, Math.min(top, viewportHeight - tooltipRect.height - gap));

        tooltip.style.left = Math.round(left) + "px";
        tooltip.style.top = Math.round(top) + "px";
        tooltip.setAttribute("data-placement", placement);
    }

    function showFigureTooltip(trigger) {
        var message = String((trigger && trigger.getAttribute("data-figure-tooltip")) || "").trim();
        if (!trigger || !message) return;
        var tooltip = ensureTooltipPortal();
        tooltipTrigger = trigger;
        tooltip.textContent = message;
        tooltip.hidden = false;
        positionFigureTooltip(trigger);
    }

    function bindFigureTooltips() {
        ensureTooltipPortal();
        document.addEventListener("mouseover", function (event) {
            var trigger = tooltipTarget(event.target);
            if (trigger && trigger !== tooltipTrigger) showFigureTooltip(trigger);
        }, true);
        document.addEventListener("mouseout", function (event) {
            var trigger = tooltipTarget(event.target);
            if (
                trigger &&
                trigger === tooltipTrigger &&
                (!event.relatedTarget || !trigger.contains(event.relatedTarget))
            ) {
                hideFigureTooltip();
            }
        }, true);
        document.addEventListener("focusin", function (event) {
            var trigger = tooltipTarget(event.target);
            if (trigger) showFigureTooltip(trigger);
        });
        document.addEventListener("focusout", function (event) {
            var trigger = tooltipTarget(event.target);
            if (
                trigger &&
                trigger === tooltipTrigger &&
                (!event.relatedTarget || !trigger.contains(event.relatedTarget))
            ) {
                hideFigureTooltip();
            }
        });
        document.addEventListener("click", hideFigureTooltip, true);
    }

    function positionGuide(anchor) {
        var guide = byId("figure-studio-guide");
        if (!guide || guide.hidden) return;
        var trigger = anchor && anchor.isConnected ? anchor : byId("figure-studio-guide-toggle");
        if (!trigger) return;

        var viewportWidth = Math.max(document.documentElement.clientWidth || 0, window.innerWidth || 0);
        var viewportHeight = Math.max(document.documentElement.clientHeight || 0, window.innerHeight || 0);
        var viewportGap = 12;
        var triggerRect = trigger.getBoundingClientRect();
        var guideRect = guide.getBoundingClientRect();
        var guideWidth = guideRect.width || Math.min(410, viewportWidth - (viewportGap * 2));
        var guideHeight = guideRect.height || 420;
        var left = triggerRect.left;
        var top = triggerRect.bottom + 10;

        if (left + guideWidth > viewportWidth - viewportGap) {
            left = triggerRect.right - guideWidth;
        }
        left = Math.max(viewportGap, Math.min(left, viewportWidth - guideWidth - viewportGap));

        if (top + guideHeight > viewportHeight - viewportGap) {
            top = triggerRect.top - guideHeight - 10;
        }
        top = Math.max(viewportGap, Math.min(top, viewportHeight - guideHeight - viewportGap));

        guide.style.left = Math.round(left) + "px";
        guide.style.top = Math.round(top) + "px";
        guide.style.right = "auto";
    }

    function setGuideOpen(open, anchor) {
        var guide = byId("figure-studio-guide");
        if (!guide) return;
        hideFigureTooltip();
        var shouldOpen = !!open;
        if (shouldOpen && anchor) guideAnchor = anchor;
        guide.hidden = !shouldOpen;
        if (shouldOpen) {
            positionGuide(guideAnchor);
        } else {
            guideAnchor = null;
        }
        document.querySelectorAll("[data-figure-guide-open]").forEach(function (button) {
            button.setAttribute("aria-expanded", shouldOpen && button === guideAnchor ? "true" : "false");
        });
    }

    function toggleGuide(event) {
        var guide = byId("figure-studio-guide");
        var trigger = event && event.currentTarget ? event.currentTarget : null;
        setGuideOpen(guide ? guide.hidden : false, trigger);
    }

    function openExportPreview() {
        var svg;
        try {
            svg = buildCompositeSvg();
        } catch (err) {
            toast(err && err.message ? err.message : "The figure preview could not be prepared.");
            return;
        }

        var modal = byId("figure-studio-preview-modal");
        var paper = byId("figure-studio-preview-paper");
        var meta = byId("figure-studio-preview-meta");
        if (!modal || !paper) return;

        setGuideOpen(false);
        previewReturnFocus = document.activeElement;
        paper.innerHTML = "";
        var previewSvg = document.importNode(svg, true);
        previewSvg.classList.add("figure-studio-final-preview-svg");
        previewSvg.removeAttribute("width");
        previewSvg.removeAttribute("height");
        paper.appendChild(previewSvg);

        var width = Number(svg.getAttribute("width")) || 1800;
        var height = Number(svg.getAttribute("height")) || 1200;
        if (meta) {
            meta.textContent = [
                width + " × " + height + " px",
                profileLabel(state.profile),
                state.panels.length + (state.panels.length === 1 ? " panel" : " panels")
            ].join(" · ");
        }

        modal.hidden = false;
        modal.setAttribute("aria-hidden", "false");
        document.documentElement.classList.add("figure-studio-preview-open");
        var closeButton = byId("figure-studio-preview-close");
        if (closeButton) closeButton.focus();
    }

    function exportSvg() {
        try {
            var serialized = serializeCompositeSvg();
            downloadData(new Blob([serialized], { type: "image/svg+xml;charset=utf-8" }), figureFilename("svg"));
            toast("Publication SVG exported with " + state.panels.length + (state.panels.length === 1 ? " panel." : " panels."));
        } catch (err) {
            toast(err && err.message ? err.message : "The figure could not be exported.");
        }
    }

    function exportPng() {
        var svg;
        try {
            svg = buildCompositeSvg();
        } catch (err) {
            toast(err && err.message ? err.message : "The figure could not be exported.");
            return;
        }
        var width = Number(svg.getAttribute("width")) || 1800;
        var height = Number(svg.getAttribute("height")) || 1200;
        var requestedScale = safeInt(state.resolution, 2, 1, 3);
        var scale = requestedScale;
        var requestedPixels = width * height * scale * scale;
        if (requestedPixels > MAX_PNG_PIXELS) {
            scale = Math.max(1, Math.sqrt(MAX_PNG_PIXELS / (width * height)));
            toast("PNG scale was reduced slightly to keep memory use safe for this large figure.");
        }
        var serialized = new XMLSerializer().serializeToString(svg);
        var blob = new Blob([serialized], { type: "image/svg+xml;charset=utf-8" });
        var url = URL.createObjectURL(blob);
        var image = new Image();
        image.onload = function () {
            try {
                var canvas = document.createElement("canvas");
                canvas.width = Math.max(1, Math.round(width * scale));
                canvas.height = Math.max(1, Math.round(height * scale));
                var context = canvas.getContext("2d");
                context.fillStyle = "#ffffff";
                context.fillRect(0, 0, canvas.width, canvas.height);
                context.drawImage(image, 0, 0, canvas.width, canvas.height);
                canvas.toBlob(function (pngBlob) {
                    URL.revokeObjectURL(url);
                    if (!pngBlob) {
                        toast("PNG conversion failed. SVG export remains available.");
                        return;
                    }
                    downloadData(pngBlob, figureFilename("png"));
                    toast("Publication PNG exported.");
                }, "image/png");
            } catch (err) {
                URL.revokeObjectURL(url);
                toast("PNG conversion failed. SVG export remains available.");
            }
        };
        image.onerror = function () {
            URL.revokeObjectURL(url);
            toast("PNG conversion failed. SVG export remains available.");
        };
        image.src = url;
    }

    function focusLibrary() {
        var input = byId("figure-studio-catalog-search");
        if (input) {
            input.focus();
            input.scrollIntoView({ behavior: "smooth", block: "center" });
        }
        toast("Choose one chart below. It will become one new panel.");
    }

    function bindEvents() {
        var title = byId("figure-studio-title");
        var subtitle = byId("figure-studio-subtitle");
        var columns = byId("figure-studio-columns");
        var profile = byId("figure-studio-profile");
        var resolution = byId("figure-studio-resolution");
        var context = byId("figure-studio-context");
        var catalogSearch = byId("figure-studio-catalog-search");
        var panelTitle = byId("figure-studio-panel-title");
        var panelSpan = byId("figure-studio-panel-span");
        var panelHeight = byId("figure-studio-panel-height");
        var panelShowTitle = byId("figure-studio-panel-show-title");

        function textFieldConfig(target) {
            if (!target) return null;
            if (target.id === "figure-studio-title") return { key: "title", max: 140 };
            if (target.id === "figure-studio-subtitle") return { key: "subtitle", max: 200 };
            return null;
        }

        function beginTextEdit(target) {
            var config = textFieldConfig(target);
            if (!config || textEditSnapshots[target.id]) return;
            textEditSnapshots[target.id] = serializableState();
        }

        function updateTextEdit(target) {
            var config = textFieldConfig(target);
            if (!config) return;
            beginTextEdit(target);
            state[config.key] = String(target.value == null ? "" : target.value).slice(0, config.max);
            state = sanitizeState(state);
            persistSoon();
        }

        function finishTextEdit(target) {
            var config = textFieldConfig(target);
            var before = config && textEditSnapshots[target.id];
            if (!config || !before) return;
            if (String(before[config.key] || "") !== String(state[config.key] || "")) {
                historyStack.push(before);
                if (historyStack.length > MAX_HISTORY) historyStack.shift();
                futureStack = [];
                updateHistoryButtons();
            }
            delete textEditSnapshots[target.id];
        }

        document.addEventListener("focusin", function (event) {
            beginTextEdit(event.target);
        });
        document.addEventListener("input", function (event) {
            updateTextEdit(event.target);
        });
        document.addEventListener("change", function (event) {
            updateTextEdit(event.target);
            finishTextEdit(event.target);
        });
        document.addEventListener("focusout", function (event) {
            finishTextEdit(event.target);
        });
        if (columns) columns.addEventListener("change", function () {
            mutate(function () {
                state.columns = safeInt(columns.value, 2, 1, 3);
                state.panels.forEach(function (panel) {
                    panel.span = Math.min(panel.span, state.columns);
                });
            });
        });
        if (profile) profile.addEventListener("change", function () {
            mutate(function () { state.profile = profile.value; });
        });
        if (resolution) resolution.addEventListener("change", function () {
            mutate(function () { state.resolution = safeInt(resolution.value, 2, 1, 3); });
        });
        if (context) context.addEventListener("change", function () {
            state.context = context.value === "ortho" ? "ortho" : "homo";
            state.lastResultsTarget = state.context === "ortho" ? "orthologous" : "homologous";
            collapseCatalogGroups(state.context);
            renderCatalog();
            persistSoon();
        });
        if (catalogSearch) catalogSearch.addEventListener("input", renderCatalog);
        if (panelTitle) panelTitle.addEventListener("change", function () {
            updateSelectedPanel("title", panelTitle.value);
        });
        if (panelSpan) panelSpan.addEventListener("change", function () {
            updateSelectedPanel("span", panelSpan.value);
        });
        if (panelHeight) panelHeight.addEventListener("change", function () {
            updateSelectedPanel("height", panelHeight.value);
        });
        if (panelShowTitle) panelShowTitle.addEventListener("change", function () {
            updateSelectedPanel("showTitle", panelShowTitle.checked);
        });

        var bindings = [
            ["figure-studio-back", backToResults],
            ["figure-studio-new", newFigure],
            ["figure-studio-undo", undo],
            ["figure-studio-redo", redo],
            ["figure-studio-add-panel", focusLibrary],
            ["figure-studio-clear", function () { clearFigure(true); }],
            ["figure-studio-preview", openExportPreview],
            ["figure-studio-export-svg", exportSvg],
            ["figure-studio-export-png", exportPng],
            ["figure-studio-preview-close", closeExportPreview],
            ["figure-studio-preview-export-svg", exportSvg],
            ["figure-studio-preview-export-png", exportPng],
            ["figure-studio-move-back", function () { moveSelected(-1); }],
            ["figure-studio-move-forward", function () { moveSelected(1); }],
            ["figure-studio-duplicate", function () {
                var panel = selectedPanel();
                if (panel) duplicatePanel(panel.id);
            }],
            ["figure-studio-remove", function () {
                var panel = selectedPanel();
                if (panel) removePanel(panel.id);
            }]
        ];
        bindings.forEach(function (binding) {
            var node = byId(binding[0]);
            if (node) node.addEventListener("click", binding[1]);
        });
        document.querySelectorAll("[data-figure-empty-add]").forEach(function (node) {
            node.addEventListener("click", focusLibrary);
        });
        document.querySelectorAll("[data-figure-guide-open]").forEach(function (node) {
            node.addEventListener("click", toggleGuide);
        });
        document.querySelectorAll("[data-figure-guide-close]").forEach(function (node) {
            node.addEventListener("click", function () { setGuideOpen(false); });
        });
        document.querySelectorAll("[data-figure-preview-close]").forEach(function (node) {
            node.addEventListener("click", closeExportPreview);
        });
        document.addEventListener("click", function (event) {
            var guide = byId("figure-studio-guide");
            if (
                guide &&
                !guide.hidden &&
                !event.target.closest("#figure-studio-guide") &&
                !event.target.closest("[data-figure-guide-open]")
            ) {
                setGuideOpen(false);
            }
        });
        document.addEventListener("keydown", function (event) {
            if (event.key === "Escape") {
                closeExportPreview();
                setGuideOpen(false);
            }
        });
        document.querySelectorAll(
            '.app-nav-btn[data-target="figure-studio"], #navtabs a[data-value="figure-studio"]'
        ).forEach(function (node) {
            node.addEventListener("click", function () {
                collapseCatalogGroups(state.context);
                setTimeout(renderCatalog, 0);
            });
        });
        window.addEventListener("resize", function () {
            clearTimeout(previewResizeTimer);
            previewResizeTimer = setTimeout(function () {
                renderPanels();
                positionGuide(guideAnchor);
                positionFigureTooltip(tooltipTrigger);
            }, 120);
        });
        document.addEventListener("scroll", function () {
            positionGuide(guideAnchor);
            positionFigureTooltip(tooltipTrigger);
        }, true);
    }

    function scheduleCatalogRefresh() {
        clearTimeout(catalogRefreshTimer);
        catalogRefreshTimer = setTimeout(function () {
            decorateResultCards();
            renderCatalog();
            state.panels.forEach(function (panel) {
                if (!runtimeSvg[panel.id] && panel.sourceId) {
                    var markup = captureContainer(panel.sourceId);
                    if (markup) runtimeSvg[panel.id] = markup;
                }
            });
            renderPanels();
        }, 180);
    }

    function bindObserver() {
        if (observer || !document.body) return;
        observer = new MutationObserver(function (mutations) {
            var changedOutsideStudio = mutations.some(function (mutation) {
                var target = mutation.target && mutation.target.nodeType === 1
                    ? mutation.target
                    : mutation.target && mutation.target.parentElement;
                return !target || !target.closest(".figure-studio-page");
            });
            if (changedOutsideStudio) scheduleCatalogRefresh();
        });
        observer.observe(document.body, { childList: true, subtree: true });
        document.addEventListener("shiny:value", function (event) {
            var id = String((event.target && event.target.id) || "");
            if (
                /^(?:homo|ortho)_(?:arch|exon|seq|context|exon_dist|intron_dist|scatter|heatmap|radar|corr)_chart(?:_export)?$/.test(id) ||
                /^(?:homo|ortho)_(?:aligned|pip|multipip)_plot_out$/.test(id) ||
                /^plot_(?:homo|ortho)_/.test(id)
            ) {
                scheduleCatalogRefresh();
            }
        });
    }

    function init() {
        if (initialized) return;
        if (!byId("figure-studio-canvas")) return;
        initialized = true;
        mountPreviewModal();
        bindEvents();
        bindFigureTooltips();
        bindObserver();
        syncControls();
        renderAll();
        persistSoon();
        rehydratePanels();
        if (window.Shiny && typeof window.Shiny.addCustomMessageHandler === "function") {
            window.Shiny.addCustomMessageHandler("cgv:figure-studio-restore", function (message) {
                setTimeout(function () { restoreExternalDraft(message); }, 900);
            });
        }
    }

    window.CGVFigureStudio = {
        init: init,
        open: openStudio,
        addFromCatalog: addFromCatalog,
        preview: openExportPreview,
        exportSvg: exportSvg,
        exportPng: exportPng,
        getState: function () { return serializableState(); },
        restore: restoreExternalDraft
    };

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init();
    }
    document.addEventListener("shiny:connected", init);
})();
