(function () {
  'use strict';

  if (window.__cgvPlotPaintTimingInitialized) return;
  window.__cgvPlotPaintTimingInitialized = true;
  var perfTimingEnabled = !!window.__cgvPlotPaintTiming;

  var runs = Object.create(null);
  var recentClicks = [];
  var observer = null;
  var observerRoot = null;
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

  if (perfTimingEnabled) {
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
  }

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
    stopObserverIfIdle();
  }

  function stopObserverIfIdle() {
    if (Object.keys(runs).length || !observer) return;
    observer.disconnect();
    observer = null;
    observerRoot = null;
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

  function cardReadiness(outputId) {
    var output = document.getElementById(outputId);
    var card = output && typeof output.closest === 'function'
      ? output.closest('.plot-transcript-card')
      : null;
    if (!card || typeof card.querySelector !== 'function') return null;
    var composition = card.querySelector('.footer-composition-inline');
    var metricsButton = card.querySelector('[data-metrics-payload]');
    var metricsPayload = metricsButton
      ? String(metricsButton.getAttribute('data-metrics-payload') || '').trim()
      : '';
    var metricsComplete = metricsButton
      ? String(metricsButton.getAttribute('data-metrics-complete') || '').toLowerCase() === 'true'
      : false;
    if (!composition || !metricsPayload || !metricsComplete) return null;
    return {
      hasSequenceComposition: true,
      hasMetrics: true,
      metricsBytes: metricsPayload.length
    };
  }

  function reportCardComplete(run, outputId, readiness) {
    if (!run || runs[run.runId] !== run || run.completed || run.reportedComplete[outputId] ||
        run.outputIds.indexOf(outputId) === -1 || !readiness) return;
    run.reportedComplete[outputId] = true;
    var completedAt = nowMs();
    var payload = {
      run_id: run.runId,
      context: run.context,
      output_id: outputId,
      click_to_complete_ms: run.clickAt != null ? Math.max(0, completedAt - run.clickAt) : null,
      start_message_to_complete_ms: Math.max(0, completedAt - run.receivedAt),
      has_sequence_composition: !!readiness.hasSequenceComposition,
      has_metrics: !!readiness.hasMetrics,
      metrics_bytes: readiness.metricsBytes || 0,
      client_epoch_ms: Date.now()
    };
    if (window.Shiny && typeof window.Shiny.setInputValue === 'function') {
      window.Shiny.setInputValue('cgv_card_complete', payload, { priority: 'event' });
    }
  }

  function reportPaint(run, outputId, svg) {
    if (!run || runs[run.runId] !== run || run.completed || run.reported[outputId] ||
        run.outputIds.indexOf(outputId) === -1) return;
    run.reported[outputId] = true;
    if (run.firstPaintOnly) run.completed = true;
    var paintedAt = nowMs();
    var collectMetrics = perfTimingEnabled && !run.firstPaintOnly;
    var payload = {
      run_id: run.runId,
      context: run.context,
      output_id: outputId,
      click_to_paint_ms: collectMetrics && run.clickAt != null ? Math.max(0, paintedAt - run.clickAt) : null,
      start_message_to_paint_ms: collectMetrics ? Math.max(0, paintedAt - run.receivedAt) : null,
      expect_message_to_paint_ms: collectMetrics && run.expectedAt != null ? Math.max(0, paintedAt - run.expectedAt) : null,
      svg_bytes: collectMetrics ? svgByteLength(svg) : null,
      svg_nodes: collectMetrics && svg && svg.querySelectorAll ? svg.querySelectorAll('*').length : null,
      client_epoch_ms: collectMetrics ? Date.now() : null
    };
    if (window.Shiny && typeof window.Shiny.setInputValue === 'function') {
      window.Shiny.setInputValue('cgv_plot_painted', payload, { priority: 'event' });
    }
    if (run.firstPaintOnly) {
      delete runs[run.runId];
      stopObserverIfIdle();
    }
  }

  function inspectRun(run) {
    if (!run || !run.outputIds || !run.outputIds.length) return;
    var expectGeneration = run.expectGeneration;
    run.outputIds.forEach(function (outputId) {
      var output = document.getElementById(outputId);
      var svg = output && output.querySelector ? output.querySelector('svg') : null;
      if (svg && !run.reported[outputId] &&
          !(run.baselineSvgs && run.baselineSvgs[outputId] === svg && !run.firstPaintOnly)) {
        window.requestAnimationFrame(function () {
          window.requestAnimationFrame(function () {
            if (runs[run.runId] !== run || run.expectGeneration !== expectGeneration ||
                run.outputIds.indexOf(outputId) === -1) return;
            if (!document.documentElement.contains(svg)) return;
            reportPaint(run, outputId, svg);
          });
        });
      }
      if ((perfTimingEnabled || run.functionalOnly) && !run.firstPaintOnly && !run.reportedComplete[outputId]) {
        var readiness = cardReadiness(outputId);
        if (readiness) {
          window.requestAnimationFrame(function () {
            window.requestAnimationFrame(function () {
              if (runs[run.runId] !== run || run.expectGeneration !== expectGeneration ||
                  run.outputIds.indexOf(outputId) === -1) return;
              reportCardComplete(run, outputId, cardReadiness(outputId));
            });
          });
        }
      }
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
    if (!window.MutationObserver || !document.documentElement) return;
    var runIds = Object.keys(runs);
    var functionalOnly = runIds.length > 0 && runIds.every(function (runId) {
      return !!(runs[runId] && runs[runId].functionalOnly);
    });
    var functionalContexts = runIds.map(function (runId) {
      return runs[runId] && runs[runId].context;
    }).filter(Boolean);
    var oneFunctionalContext = functionalContexts.length > 0 && functionalContexts.every(function (context) {
      return context === functionalContexts[0];
    });
    var functionalRootId = functionalContexts[0] === 'homologous'
      ? 'homo-plot-cards-container'
      : 'ortho-plot-cards-container';
    var nextRoot = functionalOnly && oneFunctionalContext
      ? document.getElementById(functionalRootId)
      : document.documentElement;
    // Both result containers are part of the static UI before a search can
    // run. If one is unexpectedly absent, the server fail-safe prevents a stall
    // without installing an expensive document-wide functional watch.
    if (!nextRoot) return;
    if (observer && observerRoot === nextRoot) return;
    if (observer) observer.disconnect();
    observer = new MutationObserver(scheduleInspect);
    observerRoot = nextRoot;
    observer.observe(observerRoot, { childList: true, subtree: true });
  }

  function installHandlers() {
    if (!window.Shiny || typeof window.Shiny.addCustomMessageHandler !== 'function') return false;
    window.Shiny.addCustomMessageHandler('cgv_plot_timing_start', function (message) {
      var runId = String(message && message.run_id || '');
      if (!runId) return;
      var receivedAt = nowMs();
      var context = normalizeContext(message && message.context);
      var click = claimRecentClick(context, receivedAt);
      var firstPaintOnly = !!(message && message.first_paint_only);
      var functionalOnly = !!(message && (message.functional_only || message.first_paint_only));
      if (firstPaintOnly) {
        Object.keys(runs).forEach(function (existingRunId) {
          var existing = runs[existingRunId];
          if (existing && existing.firstPaintOnly && existing.context === context) delete runs[existingRunId];
        });
        if (observer) {
          observer.disconnect();
          observer = null;
          observerRoot = null;
        }
      }
      runs[runId] = {
        runId: runId,
        context: context,
        receivedAt: receivedAt,
        clickAt: click ? click.at : null,
        expectedAt: null,
        outputIds: [],
        baselineSvgs: snapshotVisibleSvgs(context),
        reported: Object.create(null),
        reportedComplete: Object.create(null),
        firstPaintOnly: firstPaintOnly,
        functionalOnly: functionalOnly,
        completed: false,
        expectGeneration: 0
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
          reported: Object.create(null),
          reportedComplete: Object.create(null),
          firstPaintOnly: !!(message && message.first_paint_only),
          functionalOnly: !!(message && (message.functional_only || message.first_paint_only)),
          completed: false,
          expectGeneration: 0
        };
        runs[runId] = run;
      }
      // Progressive transcript admission can run for longer than a single
      // timing window. Each new expected batch proves the run is active.
      run.receivedAt = receivedAt;
      run.firstPaintOnly = run.firstPaintOnly || !!(message && message.first_paint_only);
      run.functionalOnly = run.functionalOnly || !!(message && (message.functional_only || message.first_paint_only));
      run.expectGeneration += 1;
      run.expectedAt = receivedAt;
      var rawOutputIds = message && message.output_ids;
      // Shiny serializes a length-one character vector as a scalar in some
      // message paths, while multiple output ids arrive as an array.
      run.outputIds = (Array.isArray(rawOutputIds)
        ? rawOutputIds
        : (rawOutputIds == null ? [] : [rawOutputIds]))
        .map(String)
        .filter(Boolean);
      if (run.outputIds.length) {
        ensureObserver();
        scheduleInspect();
      }
    });
    window.Shiny.addCustomMessageHandler('cgv_plot_timing_stop', function (message) {
      var runId = String(message && message.run_id || '');
      if (!runId) return;
      delete runs[runId];
      stopObserverIfIdle();
    });
    return true;
  }

  function installWithRetry(attempt) {
    if (installHandlers()) return;
    if (attempt >= 40) return;
    window.setTimeout(function () { installWithRetry(attempt + 1); }, 250);
  }

  installWithRetry(0);
})();
