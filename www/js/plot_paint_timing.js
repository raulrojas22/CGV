(function () {
  'use strict';

  if (window.__cgvPlotPaintTimingInitialized) return;
  window.__cgvPlotPaintTimingInitialized = true;
  if (!window.__cgvPlotPaintTiming) return;

  var runs = Object.create(null);
  var recentClicks = [];
  var observer = null;
  var inspectScheduled = false;
  var maxRunAgeMs = 120000;

  function nowMs() {
    return window.performance && typeof window.performance.now === 'function'
      ? window.performance.now()
      : Date.now();
  }

  function normalizeContext(value) {
    var context = String(value || '').toLowerCase();
    if (context.indexOf('ortho') === 0 || context === 'cross-species') return 'orthologous';
    if (context.indexOf('homo') === 0 || context === 'multi-gene') return 'homologous';
    return '';
  }

  function rememberClick(context, elementId) {
    var at = nowMs();
    recentClicks.push({ context: normalizeContext(context), elementId: String(elementId || ''), at: at });
    recentClicks = recentClicks.filter(function (entry) { return at - entry.at <= 15000; }).slice(-12);
  }

  document.addEventListener('click', function (event) {
    var target = event && event.target && event.target.closest
      ? event.target.closest('button, a, [role="button"]')
      : null;
    if (!target) return;
    var id = String(target.id || '');
    if (/^generate\d+$/.test(id)) {
      rememberClick('homologous', id);
    } else if (id === 'search_gene') {
      rememberClick('orthologous', id);
    } else if (id === 'global_search_go' || id === 'global_search_go_collapsed' || id === 'partial-gene-suggestion-search-selected') {
      rememberClick('', id);
    }
  }, true);

  function claimRecentClick(context, receivedAt) {
    var normalized = normalizeContext(context);
    for (var i = recentClicks.length - 1; i >= 0; i -= 1) {
      var entry = recentClicks[i];
      if (receivedAt - entry.at > 15000) continue;
      if (entry.context && entry.context !== normalized) continue;
      recentClicks.splice(i, 1);
      return entry;
    }
    return null;
  }

  function cleanupRuns() {
    var now = nowMs();
    Object.keys(runs).forEach(function (runId) {
      if (now - runs[runId].receivedAt > maxRunAgeMs) delete runs[runId];
    });
  }

  function snapshotVisibleSvgs(context) {
    var normalized = normalizeContext(context);
    var prefix = normalized === 'orthologous' ? 'plot_ortho_' : 'plot_homo_';
    var snapshot = Object.create(null);
    Array.prototype.forEach.call(document.querySelectorAll('[id^="' + prefix + '"][id$="-plot"]'), function (output) {
      var svg = output && output.querySelector ? output.querySelector('svg') : null;
      if (svg) snapshot[output.id] = svg;
    });
    return snapshot;
  }

  function svgByteLength(svg) {
    try {
      var html = svg && svg.outerHTML ? svg.outerHTML : '';
      if (window.TextEncoder) return new TextEncoder().encode(html).length;
      return unescape(encodeURIComponent(html)).length;
    } catch (_error) {
      return 0;
    }
  }

  function reportPaint(run, outputId, svg) {
    if (!run || run.reported[outputId]) return;
    run.reported[outputId] = true;
    var paintedAt = nowMs();
    var payload = {
      run_id: run.runId,
      context: run.context,
      output_id: outputId,
      click_to_paint_ms: run.clickAt == null ? null : Math.max(0, paintedAt - run.clickAt),
      start_message_to_paint_ms: Math.max(0, paintedAt - run.receivedAt),
      expect_message_to_paint_ms: run.expectedAt == null ? null : Math.max(0, paintedAt - run.expectedAt),
      svg_bytes: svgByteLength(svg),
      svg_nodes: svg && svg.querySelectorAll ? svg.querySelectorAll('*').length : 0,
      client_epoch_ms: Date.now()
    };
    if (window.Shiny && typeof window.Shiny.setInputValue === 'function') {
      window.Shiny.setInputValue('cgv_plot_painted', payload, { priority: 'event' });
    }
  }

  function inspectRun(run) {
    if (!run || !run.outputIds || !run.outputIds.length) return;
    run.outputIds.forEach(function (outputId) {
      if (run.reported[outputId]) return;
      var output = document.getElementById(outputId);
      var svg = output && output.querySelector ? output.querySelector('svg') : null;
      if (!svg) return;
      if (run.baselineSvgs && run.baselineSvgs[outputId] === svg) return;
      window.requestAnimationFrame(function () {
        window.requestAnimationFrame(function () {
          if (!document.documentElement.contains(svg)) return;
          reportPaint(run, outputId, svg);
        });
      });
    });
  }

  function inspectAllRuns() {
    inspectScheduled = false;
    cleanupRuns();
    Object.keys(runs).forEach(function (runId) { inspectRun(runs[runId]); });
  }

  function scheduleInspect() {
    if (inspectScheduled) return;
    inspectScheduled = true;
    window.requestAnimationFrame(inspectAllRuns);
  }

  function ensureObserver() {
    if (observer || !window.MutationObserver || !document.documentElement) return;
    observer = new MutationObserver(scheduleInspect);
    observer.observe(document.documentElement, { childList: true, subtree: true });
  }

  function installHandlers() {
    if (!window.Shiny || typeof window.Shiny.addCustomMessageHandler !== 'function') return false;
    window.Shiny.addCustomMessageHandler('cgv_plot_timing_start', function (message) {
      var runId = String(message && message.run_id || '');
      if (!runId) return;
      var receivedAt = nowMs();
      var context = normalizeContext(message && message.context);
      var click = claimRecentClick(context, receivedAt);
      runs[runId] = {
        runId: runId,
        context: context,
        receivedAt: receivedAt,
        clickAt: click ? click.at : null,
        expectedAt: null,
        outputIds: [],
        baselineSvgs: snapshotVisibleSvgs(context),
        reported: Object.create(null)
      };
      cleanupRuns();
    });
    window.Shiny.addCustomMessageHandler('cgv_plot_timing_expect', function (message) {
      var runId = String(message && message.run_id || '');
      if (!runId) return;
      var receivedAt = nowMs();
      var run = runs[runId];
      if (!run) {
        run = {
          runId: runId,
          context: normalizeContext(message && message.context),
          receivedAt: receivedAt,
          clickAt: null,
          expectedAt: null,
          outputIds: [],
          baselineSvgs: snapshotVisibleSvgs(message && message.context),
          reported: Object.create(null)
        };
        runs[runId] = run;
      }
      run.expectedAt = receivedAt;
      run.outputIds = Array.isArray(message && message.output_ids)
        ? message.output_ids.map(String).filter(Boolean)
        : [];
      ensureObserver();
      scheduleInspect();
    });
    ensureObserver();
    return true;
  }

  function installWithRetry(attempt) {
    if (installHandlers()) return;
    if (attempt >= 40) return;
    window.setTimeout(function () { installWithRetry(attempt + 1); }, 250);
  }

  installWithRetry(0);
})();
