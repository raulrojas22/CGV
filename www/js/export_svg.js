// Generic helpers --------------------------------------------------------

// Returns a user-friendly search mode label and the searched gene name
function getExportContext(prefix) {
    var modeLabel = prefix === "ortho" ? "cross_species" : "multigene";
    var gene = "";

    // For multi-gene (homo), try batch chips first; for ortho, use the input
    if (prefix === "homo" && typeof globalSearchChips !== "undefined" && globalSearchChips.length > 0) {
        // Summarize: up to 3 genes, then "+N"
        var chips = globalSearchChips.slice(0, 3).join("_");
        if (globalSearchChips.length > 3) chips += "_plus" + (globalSearchChips.length - 3);
        gene = chips;
    } else {
        var geneInput = document.getElementById("gene_name");
        gene = geneInput ? String(geneInput.value || "").trim() : "";
    }

    // Sanitize gene for filenames
    var safeGene = gene.replace(/[^\w.-]+/g, "_").replace(/^_+|_+$/g, "");
    return { mode: modeLabel, gene: safeGene };
}

function sanitizeFilename(name, fallback) {
    var safe = String(name || "")
        .trim()
        .replace(/[^\w.-]+/g, "_")
        .replace(/^_+|_+$/g, "");
    return safe || fallback || "plot.svg";
}

function sanitizeZipFilename(name, fallback, maxLen) {
    var file = sanitizeFilename(name, fallback || "charts_export.zip");
    if (!/\.zip$/i.test(file)) {
        file += ".zip";
    }

    var limit = (typeof maxLen === "number" && maxLen > 12) ? Math.floor(maxLen) : 110;
    if (file.length <= limit) {
        return file;
    }

    var ext = ".zip";
    var base = file.replace(/\.zip$/i, "");
    var keepLen = Math.max(12, limit - ext.length);
    var trimmedBase = base.slice(0, keepLen).replace(/[_\-.]+$/g, "");
    return (trimmedBase || "charts_export") + ext;
}

function ensureZipAvailable() {
    if (typeof JSZip !== "undefined") return Promise.resolve(true);
    if (typeof window.loadJSZip === "function") {
        return window.loadJSZip().then(function() { return true; }).catch(function() {
            alert("Failed to load JSZip library. Please check your internet connection.");
            return false;
        });
    }
    alert("JSZip library is not available.");
    return Promise.resolve(false);
}

function parseAbsoluteSVGLength(value) {
    var raw = String(value || "").trim();
    if (!raw || /%$/.test(raw)) return NaN;
    var parsed = parseFloat(raw);
    return (isFinite(parsed) && parsed > 0) ? parsed : NaN;
}

function parseViewBox(value) {
    var raw = String(value || "").trim();
    if (!raw) return null;
    var parts = raw.split(/[\s,]+/).map(function (x) { return parseFloat(x); });
    if (parts.length !== 4 || parts.some(function (x) { return !isFinite(x); })) return null;
    if (!(parts[2] > 0) || !(parts[3] > 0)) return null;
    return { x: parts[0], y: parts[1], width: parts[2], height: parts[3] };
}

function resolveSVGExportDimensions(svgEl) {
    var width = parseAbsoluteSVGLength(svgEl.getAttribute("width"));
    var height = parseAbsoluteSVGLength(svgEl.getAttribute("height"));
    var viewBox = parseViewBox(svgEl.getAttribute("viewBox"));

    if ((!(width > 0) || !(height > 0)) && viewBox) {
        width = viewBox.width;
        height = viewBox.height;
    }

    if (!(width > 0) || !(height > 0)) {
        try {
            var bbox = svgEl.getBBox();
            if (!(width > 0) && bbox && bbox.width > 0) width = bbox.width;
            if (!(height > 0) && bbox && bbox.height > 0) height = bbox.height;
        } catch (e) {
            // Ignore getBBox errors and fall back to DOM rect below.
        }
    }

    if (!(width > 0) || !(height > 0)) {
        var rect = svgEl.getBoundingClientRect();
        if (!(width > 0) && rect && rect.width > 0) width = rect.width;
        if (!(height > 0) && rect && rect.height > 0) height = rect.height;
    }

    if (!(width > 0)) width = 1200;
    if (!(height > 0)) height = 600;

    if (!viewBox) {
        viewBox = { x: 0, y: 0, width: width, height: height };
    }

    return { width: width, height: height, viewBox: viewBox };
}

function decodeScientificItalicUnicode(text) {
    var raw = String(text || "");
    if (!raw) return raw;

    var out = "";
    for (var i = 0; i < raw.length; i++) {
        var code = raw.codePointAt(i);
        if (code > 0xFFFF) i++;

        if (code >= 0x1D434 && code <= 0x1D44D) {
            out += String.fromCharCode(65 + (code - 0x1D434));
        } else if (code >= 0x1D44E && code <= 0x1D467) {
            out += String.fromCharCode(97 + (code - 0x1D44E));
        } else {
            out += String.fromCodePoint(code);
        }
    }

    return out;
}

function normalizeExportTextNodes(svgClone) {
    if (!svgClone) return;
    var textNodes = svgClone.querySelectorAll("text");
    textNodes.forEach(function (node) {
        if (!node) return;
        var raw = String(node.textContent || "");
        if (!raw) return;
        var decoded = decodeScientificItalicUnicode(raw);
        if (decoded === raw) return;
        node.textContent = decoded;
        node.setAttribute("font-style", "italic");
    });
}

function parseDataIdFields(raw) {
    var txt = String(raw || "").trim();
    var out = {};
    if (!txt) return out;

    txt.split("|").forEach(function (part, index) {
        if (!part) return;
        if (index === 0 && part.indexOf("=") === -1) {
            out.kind = part;
            return;
        }
        var eq = part.indexOf("=");
        if (eq === -1) return;
        var key = part.slice(0, eq);
        var value = part.slice(eq + 1);
        try {
            key = decodeURIComponent(key);
        } catch (e) {}
        try {
            value = decodeURIComponent(value);
        } catch (e) {}
        out[key] = value;
    });

    return out;
}

function isNodeVisible(node) {
    if (!node) return false;
    if (typeof window === "undefined" || !window.getComputedStyle) return true;
    var style = window.getComputedStyle(node);
    if (!style) return true;
    if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity || 1) === 0) {
        return false;
    }
    return node.getClientRects().length > 0;
}

function getPlotSvg(container) {
    if (!container) return null;
    var selectors = [
        ".plot-card-main .promoter-plot-container svg.ggiraph-svg",
        ".promoter-plot-container svg.ggiraph-svg",
        ".plot-card-main .promoter-plot-container svg",
        ".promoter-plot-container svg",
        "svg.ggiraph-svg",
        "svg"
    ];

    for (var i = 0; i < selectors.length; i++) {
        var match = container.querySelector(selectors[i]);
        if (match) return match;
    }

    return null;
}

function parsePlotCardHeaderMeta(card) {
    var meta = { organism: "", gene: "" };
    if (!card) return meta;

    var header = card.querySelector(".card-header");
    if (!header) return meta;

    var geneTxt = "";
    var spans = header.querySelectorAll("span");
    spans.forEach(function (span) {
        if (!span || !span.textContent) return;
        var txt = String(span.textContent || "").trim();
        if (!txt) return;
        if (!meta.gene && /^Gene:\s*/i.test(txt)) {
            geneTxt = txt.replace(/^Gene:\s*/i, "").trim();
            return;
        }
        if (!meta.organism) {
            var fontStyle = "";
            try {
                fontStyle = window.getComputedStyle(span).fontStyle || "";
            } catch (e) {}
            if (fontStyle === "italic") {
                meta.organism = txt;
            }
        }
    });

    if (!meta.gene && geneTxt) meta.gene = geneTxt;

    if (!meta.gene) {
        var headerText = String(header.textContent || "");
        var geneMatch = headerText.match(/Gene:\s*([^|\n\r]+)/i);
        if (geneMatch) meta.gene = geneMatch[1].trim();
    }

    return meta;
}

function extractGeneStructureMeta(svgEl) {
    var meta = { organism: "", gene: "", plotId: "", transcript: "" };
    if (!svgEl) return meta;

    var promoterEl = svgEl.querySelector("[data-id^='promoter_region|']");
    if (promoterEl) {
        var promoterFields = parseDataIdFields(promoterEl.getAttribute("data-id"));
        meta.organism = String(promoterFields.organism || "").trim();
        meta.gene = String(promoterFields.gene || "").trim();
        meta.plotId = String(promoterFields.plot_id || "").trim();
        meta.transcript = String(promoterFields.transcript || "").trim();
    }

    var labelEl = svgEl.querySelector("[data-id='center_gene_label']");
    if (labelEl && !meta.gene) {
        meta.gene = String(labelEl.textContent || "").trim();
    }

    var cardMeta = parsePlotCardHeaderMeta(svgEl.closest(".plot-transcript-card"));
    if (!meta.organism && cardMeta.organism) meta.organism = cardMeta.organism;
    if (!meta.gene && cardMeta.gene) meta.gene = cardMeta.gene;

    return meta;
}

function resolveCenterLabelX(sourceLabel, svgEl) {
    if (sourceLabel && typeof sourceLabel.getBBox === "function") {
        try {
            var bbox = sourceLabel.getBBox();
            if (bbox && isFinite(bbox.x) && isFinite(bbox.width) && bbox.width > 0) {
                return bbox.x + (bbox.width / 2);
            }
        } catch (e) {
            // Fall back below.
        }
    }

    var dims = resolveSVGExportDimensions(svgEl);
    return dims.viewBox.x + (dims.viewBox.width / 2);
}

function applyGeneStructureExportLabel(clone, svgEl, options) {
    if (!clone || !svgEl) return;

    var mode = String((options || {}).mode || "").toLowerCase();
    if (mode !== "ortho") return;

    var meta = extractGeneStructureMeta(svgEl);
    if (!meta.organism || !meta.gene) return;

    var sourceLabel = svgEl.querySelector("[data-id='center_gene_label']");
    var cloneLabel = clone.querySelector("[data-id='center_gene_label']");
    if (!sourceLabel || !cloneLabel) return;

    var svgNs = "http://www.w3.org/2000/svg";
    var centerX = resolveCenterLabelX(sourceLabel, svgEl);
    var y = cloneLabel.getAttribute("y") || sourceLabel.getAttribute("y") || "0";
    var originalWeight = cloneLabel.getAttribute("font-weight") || sourceLabel.getAttribute("font-weight") || "bold";

    while (cloneLabel.firstChild) {
        cloneLabel.removeChild(cloneLabel.firstChild);
    }

    cloneLabel.setAttribute("x", centerX);
    cloneLabel.setAttribute("y", y);
    cloneLabel.setAttribute("text-anchor", "middle");
    cloneLabel.setAttribute("font-weight", "normal");

    var organismTspan = document.createElementNS(svgNs, "tspan");
    organismTspan.textContent = meta.organism;
    organismTspan.setAttribute("font-style", "italic");
    organismTspan.setAttribute("font-weight", "normal");

    var geneTspan = document.createElementNS(svgNs, "tspan");
    geneTspan.textContent = meta.gene;
    geneTspan.setAttribute("dx", "6");
    geneTspan.setAttribute("font-style", "normal");
    geneTspan.setAttribute("font-weight", originalWeight);

    cloneLabel.appendChild(organismTspan);
    cloneLabel.appendChild(geneTspan);
}

function serializeSVGForExport(svgEl, opts) {
    if (!svgEl) return null;
    var options = opts || {};
    var clone = svgEl.cloneNode(true);
    clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
    clone.setAttribute("xmlns:xlink", "http://www.w3.org/1999/xlink");
    var dims = resolveSVGExportDimensions(svgEl);
    var widthOut = dims.width;
    var heightOut = dims.height;

    if (options.minWidth) {
        var targetWidth = Math.max(widthOut, options.minWidth);
        if (targetWidth > widthOut && widthOut > 0) {
            var scale = targetWidth / widthOut;
            widthOut = targetWidth;
            heightOut = heightOut * scale;
        }
    }

    var round3 = function (x) { return Math.round(x * 1000) / 1000; };
    clone.setAttribute("viewBox", [
        dims.viewBox.x,
        dims.viewBox.y,
        round3(dims.viewBox.width),
        round3(dims.viewBox.height)
    ].join(" "));
    clone.setAttribute("width", round3(widthOut));
    clone.setAttribute("height", round3(heightOut));

    // Ensure exported SVG does not keep responsive 100% sizing from the app DOM.
    clone.style.width = round3(widthOut) + "px";
    clone.style.height = round3(heightOut) + "px";
    clone.style.maxWidth = "none";

    var bg = options.backgroundColor;
    if (!bg && typeof window !== "undefined" && window.getComputedStyle) {
        bg = window.getComputedStyle(svgEl).backgroundColor;
    }
    if (bg && bg !== "transparent" && bg !== "rgba(0, 0, 0, 0)") {
        clone.style.backgroundColor = bg;
    } else {
        clone.style.removeProperty("background-color");
    }

    normalizeExportTextNodes(clone);

    if (options.exportType === "gene-structure") {
        applyGeneStructureExportLabel(clone, svgEl, options);
    }

    var serialized = new XMLSerializer().serializeToString(clone);
    var xmlDecl = '<?xml version="1.0" encoding="UTF-8"?>\n';
    var encoded = serialized.replace(/[\u0080-\uFFFF]/g, function (ch) {
        var code = ch.codePointAt(0);
        return "&#x" + code.toString(16).toUpperCase() + ";";
    });
    return xmlDecl + encoded;
}

function downloadBlob(blob, filename) {
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () {
        URL.revokeObjectURL(url);
    }, 1000);
}

function addContainerSVGToZip(zip, containerId, filename, opts) {
    var container = document.getElementById(containerId);
    if (!container) return false;
    var svgEl = getPlotSvg(container);
    if (!svgEl) return false;
    var svgData = serializeSVGForExport(svgEl, opts);
    if (!svgData) return false;
    zip.file(sanitizeFilename(filename, containerId + ".svg"), svgData);
    return true;
}

function exportSVGCollection(entries, zipFilename, opts) {
    var options = opts || {};
    ensureZipAvailable().then(function(ok) {
    if (!ok) {
        if (typeof options.onComplete === "function") options.onComplete(0);
        return;
    }
    var list = Array.isArray(entries) ? entries : [];
    if (!list.length) {
        alert(options.alertOnEmpty || "No SVG sources were configured.");
        if (typeof options.onComplete === "function") options.onComplete(0);
        return;
    }

    var zip = new JSZip();
    var count = 0;

    list.forEach(function (entry) {
        if (!entry || !entry.containerId) return;
        var ok = addContainerSVGToZip(
            zip,
            entry.containerId,
            entry.filename || (entry.containerId + ".svg"),
            { minWidth: options.minWidth || 1050 }
        );
        if (ok) count++;
    });

    if (count === 0) {
        alert(options.alertOnEmpty || "No SVGs were found to include in the ZIP.");
        if (typeof options.onComplete === "function") options.onComplete(0);
        return;
    }

    zip.generateAsync({ type: "blob" }).then(function (content) {
        downloadBlob(
            content,
            sanitizeZipFilename(zipFilename, "charts_export.zip", options.maxZipNameLength || 110)
        );
        if (typeof options.onComplete === "function") options.onComplete(count);
    }).catch(function () {
        if (typeof options.onComplete === "function") options.onComplete(count);
    });
    });
}

function hasAnalyticsDataMarks(svgEl) {
    if (!svgEl) return false;
    return !!svgEl.querySelector("[data-id]");
}

function isAnalyticsEntryExportable(entry) {
    if (!entry || !entry.containerId) return false;
    var container = document.getElementById(entry.containerId);
    if (!container) return false;
    var svgEl = container.querySelector("svg");
    if (!svgEl) return false;
    return hasAnalyticsDataMarks(svgEl);
}

function getAnalyticsTabLinks(mode) {
    var key = String(mode || "").toLowerCase();
    var section = document.getElementById(key + "_analytics_body") ||
                  document.getElementById(key + "_analytics_section");
    if (!section) return [];

    var seen = new Set();
    return Array.prototype.slice.call(
        section.querySelectorAll(
            ".nav.nav-pills li > a, " +
            ".nav.nav-pills li > button, " +
            ".nav-pills .nav-link"
        )
    ).filter(function (node) {
        if (!node || seen.has(node)) return false;
        seen.add(node);
        return true;
    });
}

function activateTabLink(tabLink) {
    if (!tabLink) return false;

    if (typeof bootstrap !== "undefined" && bootstrap && typeof bootstrap.Tab === "function") {
        try {
            bootstrap.Tab.getOrCreateInstance(tabLink).show();
            return true;
        } catch (e) {
            // Fall back to click below.
        }
    }

    try {
        tabLink.click();
        return true;
    } catch (e) {
        return false;
    }
}

function getAnalyticsTabValueFromEntry(entry) {
    var id = String((entry || {}).containerId || "");
    var match = id.match(/^(?:homo|ortho)_(.+)_chart$/);
    return match ? match[1] : "";
}

function getAnalyticsTabValue(tabLink) {
    if (!tabLink) return "";
    var attrs = ["data-value", "value", "aria-controls", "href"];
    for (var i = 0; i < attrs.length; i++) {
        var raw = tabLink.getAttribute(attrs[i]);
        if (!raw) continue;
        var value = String(raw).replace(/^#/, "").trim();
        if (value) {
            value = value.replace(/^(?:tab-|pane-)?(?:homo|ortho)_analytics_tabs-?/, "");
            return value;
        }
    }
    return "";
}

function findAnalyticsTabLink(mode, tabValue) {
    var wanted = String(tabValue || "").toLowerCase();
    if (!wanted) return null;
    var links = getAnalyticsTabLinks(mode);
    for (var i = 0; i < links.length; i++) {
        var linkValue = getAnalyticsTabValue(links[i]).toLowerCase();
        if (linkValue === wanted) return links[i];
    }
    return null;
}

function getActiveAnalyticsTabValue(mode) {
    var key = String(mode || "").toLowerCase();
    var links = getAnalyticsTabLinks(key);
    for (var i = 0; i < links.length; i++) {
        var link = links[i];
        if (!link) continue;
        var cls = String(link.className || "");
        var parentCls = String((link.parentNode && link.parentNode.className) || "");
        if (/\bactive\b/.test(cls) || /\bactive\b/.test(parentCls) || link.getAttribute("aria-selected") === "true") {
            return getAnalyticsTabValue(link);
        }
    }
    return "";
}

function requestAnalyticsExportRender(mode) {
    var key = String(mode || "").toLowerCase();
    if (!key || typeof Shiny === "undefined" || !Shiny || typeof Shiny.setInputValue !== "function") return false;
    Shiny.setInputValue(key + "_analytics_export_all_nonce", Date.now(), { priority: "event" });
    return true;
}

function finishAnalyticsExportRender(mode) {
    var key = String(mode || "").toLowerCase();
    if (!key || typeof Shiny === "undefined" || !Shiny || typeof Shiny.setInputValue !== "function") return;
    Shiny.setInputValue(key + "_analytics_export_done_nonce", Date.now(), { priority: "event" });
}

function waitForAnalyticsEntry(entry, timeoutMs, callback) {
    var maxWait = Math.max(0, Number(timeoutMs || 0));
    var started = Date.now();

    function poll() {
        if (isAnalyticsEntryExportable(entry)) {
            callback();
            return;
        }
        if ((Date.now() - started) >= maxWait) {
            callback();
            return;
        }
        setTimeout(poll, 120);
    }

    poll();
}

function prepareAnalyticsEntriesForExport(mode, entries, timeoutMs, callback) {
    var key = String(mode || "").toLowerCase();
    var list = Array.isArray(entries) ? entries.slice() : [];
    var maxWait = Math.max(0, Number(timeoutMs || 0));
    var index = 0;

    function next() {
        if (index >= list.length) {
            callback();
            return;
        }

        var entry = list[index++];
        if (!entry || !entry.containerId) {
            next();
            return;
        }

        if (isAnalyticsEntryExportable(entry)) {
            next();
            return;
        }

        var tabValue = getAnalyticsTabValueFromEntry(entry);
        var tabLink = findAnalyticsTabLink(key, tabValue);
        if (tabLink) {
            activateTabLink(tabLink);
        }

        waitForAnalyticsEntry(entry, maxWait, next);
    }

    next();
}

function waitForAnalyticsEntries(entries, timeoutMs, callback) {
    var list = Array.isArray(entries) ? entries.slice() : [];
    var maxWait = Math.max(0, Number(timeoutMs || 0));
    var started = Date.now();

    function poll() {
        var readyCount = list.filter(isAnalyticsEntryExportable).length;
        if (readyCount >= list.length) {
            callback();
            return;
        }
        if ((Date.now() - started) >= maxWait) {
            callback();
            return;
        }
        setTimeout(poll, 140);
    }

    poll();
}

function buildAnalyticsEntryFilename(ctx, baseFilename) {
    var rawBase = String(baseFilename || "analytics_chart.svg").trim();
    var baseNoExt = rawBase.replace(/\.svg$/i, "");
    var parts = [String((ctx || {}).mode || "").trim()];
    var genePart = String((ctx || {}).gene || "").trim();
    if (genePart) parts.push(genePart);
    parts.push(baseNoExt);
    return sanitizeFilename(parts.filter(function (x) {
        return x && x.length > 0;
    }).join("_") + ".svg", rawBase || "analytics_chart.svg");
}

function buildStructuredSvgFilename(parts, fallback) {
    var safeParts = (Array.isArray(parts) ? parts : []).map(function (x) {
        return String(x || "").trim();
    }).filter(function (x) {
        return x && x.length > 0;
    });
    return sanitizeFilename(safeParts.join("_") + ".svg", fallback || "plot.svg");
}

// Export single SVG ------------------------------------------------------
function exportSVG(containerId, filename) {
    var container = document.getElementById(containerId);
    if (!container) {
        alert("Plot not found. Please wait for it to load.");
        return;
    }
    var svgEl = getPlotSvg(container);
    if (!svgEl) {
        alert("SVG element not found in the plot.");
        return;
    }
    var inferredMode = /plot_ortho_/i.test(String(containerId || "")) ? "ortho" :
                       (/plot_homo_/i.test(String(containerId || "")) ? "homo" : "");
    var isGeneStructure = /gene_structure\.svg$/i.test(String(filename || ""));
    var meta = isGeneStructure ? extractGeneStructureMeta(svgEl) : { organism: "", gene: "" };
    var exportFilename = filename || "gene_structure.svg";

    if (isGeneStructure && inferredMode === "ortho" && meta.organism && meta.gene) {
        exportFilename = buildStructuredSvgFilename(
            [meta.organism, meta.gene, "gene_structure"],
            exportFilename
        );
    }

    var svgData = serializeSVGForExport(svgEl, {
        exportType: isGeneStructure ? "gene-structure" : "",
        mode: inferredMode
    });
    if (!svgData) {
        alert("Could not export this SVG.");
        return;
    }
    var blob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
    downloadBlob(blob, sanitizeFilename(exportFilename, "gene_structure.svg"));
}

// Export alignment SVG with gene name and search type --------------------
function exportAlignmentSVG(containerId, baseLabel) {
    var ctx = getExportContext("ortho");
    var genePart = ctx.gene ? "_" + ctx.gene : "";
    var filename = ctx.mode + genePart + "_" + baseLabel + ".svg";
    exportSVG(containerId, filename);
}

// Export STRING visNetwork canvas as SVG wrapper -------------------------
function exportStringNetworkSVG(containerId, filename) {
    var container = document.getElementById(containerId);
    if (!container) {
        alert("STRING network not found. Please wait for it to load.");
        return;
    }

    // If an SVG exists, use the regular exporter.
    var nativeSvg = container.querySelector("svg");
    if (nativeSvg) {
        exportSVG(containerId, filename || "string_coexpression_network.svg");
        return;
    }

    var canvases = Array.prototype.slice.call(container.querySelectorAll("canvas"));
    if (!canvases.length) {
        alert("Network canvas not found yet. Please wait for it to render.");
        return;
    }

    var bestCanvas = null;
    var bestArea = 0;
    canvases.forEach(function (cv) {
        if (!cv) return;
        var w = Number(cv.width || 0);
        var h = Number(cv.height || 0);
        if (!(w > 0) || !(h > 0)) {
            var r = cv.getBoundingClientRect();
            w = Number(r.width || 0);
            h = Number(r.height || 0);
        }
        var area = w * h;
        if (area > bestArea) {
            bestArea = area;
            bestCanvas = cv;
        }
    });

    if (!bestCanvas || !(bestArea > 0)) {
        alert("Could not find a renderable STRING canvas.");
        return;
    }

    var width = Number(bestCanvas.width || 0);
    var height = Number(bestCanvas.height || 0);
    if (!(width > 0) || !(height > 0)) {
        var rect = bestCanvas.getBoundingClientRect();
        width = Math.max(1, Math.round(rect.width || 0));
        height = Math.max(1, Math.round(rect.height || 0));
    }

    var dataUrl = "";
    try {
        dataUrl = bestCanvas.toDataURL("image/png");
    } catch (e) {
        alert("Could not export STRING canvas.");
        return;
    }

    var bg = "#FFFFFF";
    if (typeof window !== "undefined" && window.getComputedStyle) {
        var bodyBg = window.getComputedStyle(container).backgroundColor;
        if (bodyBg && bodyBg !== "transparent" && bodyBg !== "rgba(0, 0, 0, 0)") {
            bg = bodyBg;
        }
    }

    var svgData = [
        '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" ',
        'width="', width, '" height="', height, '" viewBox="0 0 ', width, " ", height, '">',
        '<rect x="0" y="0" width="', width, '" height="', height, '" fill="', bg, '"/>',
        '<image x="0" y="0" width="', width, '" height="', height, '" href="', dataUrl, '" xlink:href="', dataUrl, '"/>',
        "</svg>"
    ].join("");

    var blob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
    downloadBlob(blob, sanitizeFilename(filename || "string_coexpression_network.svg", "string_coexpression_network.svg"));
}

// Existing transcript plots ZIP export -----------------------------------
function exportAllSVGs(prefix) {
    ensureZipAvailable().then(function(ok) {
    if (!ok) return;

    var containerRoot = document.getElementById(prefix === "ortho" ? "ortho-plot-cards-container" : "homo-plot-cards-container");
    var cards = containerRoot ? Array.prototype.slice.call(containerRoot.querySelectorAll(".plot-transcript-card")) : [];
    cards = cards.filter(isNodeVisible);

    if (!cards.length) {
        alert("No plots found to download.");
        return;
    }

    var ctx = getExportContext(prefix);
    var zip = new JSZip();
    var count = 0;

    cards.forEach(function (card, index) {
        var svgEl = getPlotSvg(card);
        if (!svgEl) return;

        var containerDiv = svgEl.closest("div[id^='plot_" + prefix + "_']");
        var meta = extractGeneStructureMeta(svgEl);
        var rawId = containerDiv ? containerDiv.id : ("gene_plot_" + (index + 1));
        var idPart = rawId.replace("plot_" + prefix + "_", "").replace("-plot", "");
        var filenameParts = [ctx.mode, ctx.gene];
        var fallbackStem = sanitizeFilename(meta.gene || idPart, idPart);

        if (prefix === "ortho" && meta.organism) {
            filenameParts.push(meta.organism);
            fallbackStem = sanitizeFilename((meta.organism || "") + "_" + (meta.gene || idPart), fallbackStem);
        }
        if (meta.gene) {
            filenameParts.push(meta.gene);
        } else {
            filenameParts.push(idPart);
        }
        filenameParts.push("gene_structure");

        var filename = buildStructuredSvgFilename(
            filenameParts,
            fallbackStem + "_gene_structure.svg"
        );

        var svgData = serializeSVGForExport(svgEl, {
            minWidth: 1050,
            exportType: "gene-structure",
            mode: prefix
        });
        if (svgData) {
            zip.file(sanitizeFilename(filename, "gene_plot_" + (index + 1) + ".svg"), svgData);
            count++;
        }
    });

    if (count === 0) {
        alert("Could not extract any SVG data.");
        return;
    }

    var geneSuffix = ctx.gene ? "_" + ctx.gene : "";
    var zipName = ctx.mode + geneSuffix + "_all_gene_plots.zip";
    zip.generateAsync({ type: "blob" }).then(function (content) {
        downloadBlob(
            content,
            sanitizeZipFilename(zipName, "all_gene_plots.zip", 110)
        );
    });
    });
}

// Analytics ZIP exports ---------------------------------------------------
var ANALYTICS_EXPORT_MAP = {
    homo: [
        { containerId: "homo_arch_chart", filename: "architecture.svg" },
        { containerId: "homo_exon_chart", filename: "exons_introns.svg" },
        { containerId: "homo_seq_chart", filename: "sequence.svg" },
        { containerId: "homo_context_chart", filename: "genomic_context.svg" },
        { containerId: "homo_exon_dist_chart", filename: "exon_lengths.svg" },
        { containerId: "homo_intron_dist_chart", filename: "intron_lengths.svg" },
        { containerId: "homo_scatter_chart", filename: "scatter.svg" },
        { containerId: "homo_heatmap_chart", filename: "heatmap.svg" },
        { containerId: "homo_radar_chart", filename: "radar.svg" },
        { containerId: "homo_corr_chart", filename: "correlations.svg" }
    ],
    ortho: [
        { containerId: "ortho_arch_chart", filename: "architecture.svg" },
        { containerId: "ortho_exon_chart", filename: "exons_introns.svg" },
        { containerId: "ortho_seq_chart", filename: "sequence.svg" },
        { containerId: "ortho_context_chart", filename: "genomic_context.svg" },
        { containerId: "ortho_exon_dist_chart", filename: "exon_lengths.svg" },
        { containerId: "ortho_intron_dist_chart", filename: "intron_lengths.svg" },
        { containerId: "ortho_scatter_chart", filename: "scatter.svg" },
        { containerId: "ortho_heatmap_chart", filename: "heatmap.svg" },
        { containerId: "ortho_radar_chart", filename: "radar.svg" },
        { containerId: "ortho_corr_chart", filename: "correlations.svg" }
    ]
};

function exportAnalyticsSVGs(mode) {
    var key = String(mode || "").toLowerCase();
    var ctx = getExportContext(key);
    var entries = ANALYTICS_EXPORT_MAP[key] || [];
    var namedEntries = entries.map(function (entry) {
        if (!entry || !entry.containerId) return entry;
        return {
            containerId: entry.containerId + "_export",
            filename: buildAnalyticsEntryFilename(ctx, entry.filename)
        };
    });
    var geneSuffix = ctx.gene ? "_" + ctx.gene : "";
    var zipName = ctx.mode + geneSuffix + "_analytics_charts.zip";
    var ENTRY_TIMEOUT_MS = 18000;
    var originalTabValue = getActiveAnalyticsTabValue(key);
    requestAnalyticsExportRender(key);

    setTimeout(function () {
        waitForAnalyticsEntries(namedEntries, ENTRY_TIMEOUT_MS, function () {
            var exportableEntries = namedEntries.filter(isAnalyticsEntryExportable);
            exportSVGCollection(exportableEntries, zipName, {
                minWidth: 1050,
                alertOnEmpty: "No analytics charts are renderable yet. Charts with insufficient data are skipped.",
                onComplete: function () {
                    if (originalTabValue) {
                        var originalTab = findAnalyticsTabLink(key, originalTabValue);
                        if (originalTab) activateTabLink(originalTab);
                    }
                    setTimeout(function () {
                        finishAnalyticsExportRender(key);
                    }, 150);
                }
            });
        });
    }, 250);
}

// Chart modal ZIP exports -------------------------------------------------
var CHART_MODAL_EXPORT_LIST = [
    { containerId: "chart_modal_structure", filename: "chart_structure.svg" },
    { containerId: "chart_modal_exons", filename: "chart_exon_map.svg" },
    { containerId: "chart_modal_introns", filename: "chart_intron_map.svg" },
    { containerId: "chart_modal_seq", filename: "chart_sequence.svg" },
    { containerId: "chart_modal_isoforms_girafe", filename: "chart_isoforms.svg" },
    { containerId: "chart_modal_gene_intron_dist", filename: "chart_intron_lengths.svg" }
];

function getChartModalExportContext() {
    var modal = document.querySelector(".chart-plots-modal");
    if (!modal) {
        return { org: "", gene: "", tx: "" };
    }

    var orgEl = modal.querySelector(".chart-modal-title-org");
    var geneEl = modal.querySelector(".chart-modal-title-gene");
    var txEl = modal.querySelector(".chart-modal-title-transcript");

    var org = orgEl ? orgEl.textContent.trim() : "";
    var gene = geneEl ? geneEl.textContent.trim() : "";
    var txRaw = txEl ? txEl.textContent.trim() : "";
    var tx = txRaw.replace(/^Transcript:\s*/i, "").trim();

    return { org: org, gene: gene, tx: tx };
}

function getChartModalZipName() {
    var ctx = getChartModalExportContext();
    var parts = [ctx.org, ctx.gene, ctx.tx].filter(function (x) {
        return x && x.length > 0;
    });

    if (!parts.length) return "chart_modal_all_charts.zip";
    return sanitizeFilename("chart_modal_" + parts.join("_") + ".zip", "chart_modal_all_charts.zip");
}

function exportChartModalSVGs() {
    var ctx = getChartModalExportContext();
    var namedEntries = CHART_MODAL_EXPORT_LIST.map(function (entry) {
        if (!entry || !entry.containerId) return entry;
        var baseNoExt = String(entry.filename || "chart.svg").replace(/\.svg$/i, "");
        return {
            containerId: entry.containerId,
            filename: buildStructuredSvgFilename(
                ["chart_modal", ctx.org, ctx.gene, ctx.tx, baseNoExt],
                entry.filename || "chart.svg"
            )
        };
    });

    exportSVGCollection(namedEntries, getChartModalZipName(), {
        minWidth: 1050,
        maxZipNameLength: 100,
        alertOnEmpty: "No chart SVGs are available in this modal yet."
    });
}
