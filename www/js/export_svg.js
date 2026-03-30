// Generic helpers --------------------------------------------------------
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
    if (typeof JSZip === "undefined") {
        alert("JSZip library has not loaded yet. Please wait a moment and try again.");
        return false;
    }
    return true;
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

    return new XMLSerializer().serializeToString(clone);
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
    var svgEl = container.querySelector("svg");
    if (!svgEl) return false;
    var svgData = serializeSVGForExport(svgEl, opts);
    if (!svgData) return false;
    zip.file(sanitizeFilename(filename, containerId + ".svg"), svgData);
    return true;
}

function exportSVGCollection(entries, zipFilename, opts) {
    if (!ensureZipAvailable()) return;
    var options = opts || {};
    var list = Array.isArray(entries) ? entries : [];
    if (!list.length) {
        alert(options.alertOnEmpty || "No SVG sources were configured.");
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
        return;
    }

    zip.generateAsync({ type: "blob" }).then(function (content) {
        downloadBlob(
            content,
            sanitizeZipFilename(zipFilename, "charts_export.zip", options.maxZipNameLength || 110)
        );
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

// Export single SVG ------------------------------------------------------
function exportSVG(containerId, filename) {
    var container = document.getElementById(containerId);
    if (!container) {
        alert("Plot not found. Please wait for it to load.");
        return;
    }
    var svgEl = container.querySelector("svg");
    if (!svgEl) {
        alert("SVG element not found in the plot.");
        return;
    }
    var svgData = serializeSVGForExport(svgEl, {});
    if (!svgData) {
        alert("Could not export this SVG.");
        return;
    }
    var blob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
    downloadBlob(blob, sanitizeFilename(filename || "gene_structure.svg", "gene_structure.svg"));
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
    if (!ensureZipAvailable()) return;

    var svgEls = document.querySelectorAll("div[id^='plot_" + prefix + "'] svg");
    if (!svgEls || svgEls.length === 0) {
        alert("No plots found to download.");
        return;
    }

    var zip = new JSZip();
    var count = 0;

    svgEls.forEach(function (svgEl, index) {
        var containerDiv = svgEl.closest("div[id^='plot_" + prefix + "']");
        var filename = "gene_plot_" + (index + 1) + ".svg";
        if (containerDiv) {
            var rawId = containerDiv.id;
            filename = rawId.replace("plot_" + prefix + "_", "").replace("-plot", "") + "_gene_structure.svg";
        }
        var svgData = serializeSVGForExport(svgEl, { minWidth: 1050 });
        if (svgData) {
            zip.file(sanitizeFilename(filename, "gene_plot_" + (index + 1) + ".svg"), svgData);
            count++;
        }
    });

    if (count === 0) {
        alert("Could not extract any SVG data.");
        return;
    }

    zip.generateAsync({ type: "blob" }).then(function (content) {
        downloadBlob(
            content,
            sanitizeZipFilename(prefix + "_all_gene_plots.zip", "all_gene_plots.zip", 110)
        );
    });
}

// Analytics ZIP exports ---------------------------------------------------
var ANALYTICS_EXPORT_MAP = {
    homo: [
        { containerId: "homo_arch_chart", filename: "homo_architecture.svg" },
        { containerId: "homo_exon_chart", filename: "homo_exons_introns.svg" },
        { containerId: "homo_seq_chart", filename: "homo_sequence.svg" },
        { containerId: "homo_context_chart", filename: "homo_genomic_context.svg" },
        { containerId: "homo_exon_dist_chart", filename: "homo_exon_lengths.svg" },
        { containerId: "homo_scatter_chart", filename: "homo_scatter.svg" },
        { containerId: "homo_heatmap_chart", filename: "homo_heatmap.svg" },
        { containerId: "homo_radar_chart", filename: "homo_radar.svg" },
        { containerId: "homo_corr_chart", filename: "homo_correlations.svg" }
    ],
    ortho: [
        { containerId: "ortho_arch_chart", filename: "ortho_architecture.svg" },
        { containerId: "ortho_exon_chart", filename: "ortho_exons_introns.svg" },
        { containerId: "ortho_seq_chart", filename: "ortho_sequence.svg" },
        { containerId: "ortho_context_chart", filename: "ortho_genomic_context.svg" },
        { containerId: "ortho_exon_dist_chart", filename: "ortho_exon_lengths.svg" },
        { containerId: "ortho_scatter_chart", filename: "ortho_scatter.svg" },
        { containerId: "ortho_heatmap_chart", filename: "ortho_heatmap.svg" },
        { containerId: "ortho_radar_chart", filename: "ortho_radar.svg" },
        { containerId: "ortho_corr_chart", filename: "ortho_correlations.svg" }
    ]
};

function exportAnalyticsSVGs(mode) {
    var key = String(mode || "").toLowerCase();
    var entries = ANALYTICS_EXPORT_MAP[key] || [];
    var exportableEntries = entries.filter(isAnalyticsEntryExportable);
    exportSVGCollection(exportableEntries, key + "_analytics_charts.zip", {
        minWidth: 1050,
        alertOnEmpty: "No analytics charts are renderable yet. Charts with insufficient data are skipped."
    });
}

// Chart modal ZIP exports -------------------------------------------------
var CHART_MODAL_EXPORT_LIST = [
    { containerId: "chart_modal_structure", filename: "chart_structure.svg" },
    { containerId: "chart_modal_exons", filename: "chart_exon_map.svg" },
    { containerId: "chart_modal_seq", filename: "chart_sequence.svg" },
    { containerId: "chart_modal_isoforms_girafe", filename: "chart_isoforms.svg" }
];

function getChartModalZipName() {
    var modal = document.querySelector(".chart-plots-modal");
    if (!modal) return "chart_modal_all_charts.zip";

    var orgEl = modal.querySelector(".chart-modal-title-org");
    var geneEl = modal.querySelector(".chart-modal-title-gene");
    var txEl = modal.querySelector(".chart-modal-title-transcript");

    var org = orgEl ? orgEl.textContent.trim() : "";
    var gene = geneEl ? geneEl.textContent.trim() : "";
    var txRaw = txEl ? txEl.textContent.trim() : "";
    var tx = txRaw.replace(/^Transcript:\s*/i, "").trim();

    var parts = [org, gene, tx].filter(function (x) {
        return x && x.length > 0;
    });

    if (!parts.length) return "chart_modal_all_charts.zip";
    return sanitizeFilename("charts_" + parts.join("_") + ".zip", "chart_modal_all_charts.zip");
}

function exportChartModalSVGs() {
    exportSVGCollection(CHART_MODAL_EXPORT_LIST, getChartModalZipName(), {
        minWidth: 1050,
        maxZipNameLength: 100,
        alertOnEmpty: "No chart SVGs are available in this modal yet."
    });
}
