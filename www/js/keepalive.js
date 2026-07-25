/**
 * keepalive.js — Session health, tab-visibility recovery, ggiraph tooltip reset.
 *
 * Three problems solved:
 *
 * 1. SHINY SESSION TIMEOUT
 *    When the user is away, the R session on the server times out (default ~300 s
 *    of no activity). We keep sending a lightweight "ping" even while the tab is
 *    hidden, because background tabs are exactly where idle disconnects happen.
 *
 * 2. SILENT DISCONNECT DETECTION
 *    Shiny can disconnect while the page still looks normal — buttons fire but
 *    nothing happens because setInputValue() drops events silently.
 *    We detect `shiny:disconnected` and show a banner + offer a one-click reload.
 *    On `shiny:reconnected` / `shiny:connected` we hide the banner and restart the ping.
 *
 * 3. TAB RETURN RECOVERY
 *    requestAnimationFrame-based loops (e.g. plot_zoom.js fabSyncRaf) can get
 *    stuck when the browser freezes RAF while the tab is hidden.
 *    On tab return we verify the underlying websocket really is alive, then
 *    dispatch a synthetic `resize` + `shiny:value` so that layout helpers and
 *    zoom controls re-synchronise, and we nudge ggiraph to re-evaluate any
 *    hover/tooltip state by dispatching a no-op mousemove.
 */
(function () {
  'use strict';
  if (window.__shinyKeepaliveInitialized) return;
  window.__shinyKeepaliveInitialized = true;

  /* ── Configuration ───────────────────────────────────────────────────────── */
  var PING_INTERVAL_VISIBLE_MS = 90000; // send ping every 90 s while visible
  var PING_INTERVAL_HIDDEN_MS  = 60000; // hidden tabs get timer-throttled; keep this below Shiny idle timeout
  var MIN_PING_GAP_MS          = 30000;
  var RESUME_DELAY_MS          = 1200;
  var LONG_SUSPEND_GAP_MS      = 15 * 60 * 1000;
  var BANNER_ID                = 'shiny-keepalive-banner';
  var DEFAULT_BANNER_MESSAGE   = 'Connection lost — the analysis session is disconnected.';
  var LONG_SUSPEND_MESSAGE     = 'The computer was asleep too long. Reload the page to restore a healthy session.';
  var GIRAFE_OUTPUT_SELECTOR   =
    '[id^="plot_ortho_"].html-widget-output, ' +
    '[id^="plot_homo_"].html-widget-output, ' +
    '#ortho_aligned_plot_out.html-widget-output, ' +
    '#ortho_pip_plot_out.html-widget-output, ' +
    '#ortho_multipip_plot_out.html-widget-output, ' +
    '[id$="_chart"].html-widget-output, ' +
    '[id$="_girafe"].html-widget-output, ' +
    '[id$="_ggiraph"].html-widget-output';

  /* ── Internal state ──────────────────────────────────────────────────────── */
  var pingTimer      = null;
  var resumeTimer    = null;
  var isConnected    = false;
  var lastPingAt     = 0;
  var lastRuntimeTickAt = Date.now();
  var publicNudgeTimer = null;

  function markRuntimeTick() {
    lastRuntimeTickAt = Date.now();
  }

  function wasSuspendedTooLong() {
    return (Date.now() - lastRuntimeTickAt) >= LONG_SUSPEND_GAP_MS;
  }

  function clearResumeTimer() {
    if (resumeTimer !== null) {
      clearTimeout(resumeTimer);
      resumeTimer = null;
    }
  }

  function getPingIntervalMs() {
    return document.hidden ? PING_INTERVAL_HIDDEN_MS : PING_INTERVAL_VISIBLE_MS;
  }

  function getSocketReadyState() {
    try {
      var socket = window.Shiny &&
        window.Shiny.shinyapp &&
        window.Shiny.shinyapp.$socket;
      if (socket && typeof socket.readyState === 'number') {
        return socket.readyState;
      }
    } catch (_e) {}
    return null;
  }

  function hasHealthyConnection() {
    var readyState = getSocketReadyState();
    if (readyState !== null) {
      return readyState === 1;
    }

    try {
      if (window.Shiny &&
          window.Shiny.shinyapp &&
          typeof window.Shiny.shinyapp.isConnected === 'function') {
        return !!window.Shiny.shinyapp.isConnected();
      }
    } catch (_e2) {}

    return isConnected;
  }

  function markDisconnected(message) {
    isConnected = false;
    stopPing();
    showBanner(message);
  }

  function markConnected() {
    isConnected = true;
    hideBanner();
    startPing();
  }

  /* ── Ping helpers ────────────────────────────────────────────────────────── */
  function sendPing() {
    if (!isConnected) return;
    if (!window.Shiny || typeof window.Shiny.setInputValue !== 'function') return;
    var now = Date.now();
    if (now - lastPingAt < MIN_PING_GAP_MS) return;
    lastPingAt = now;
    markRuntimeTick();
    try {
      // Priority "deferred" — does not trigger reactivity, just resets idle timer.
      window.Shiny.setInputValue('.__keepalive__.', now, { priority: 'deferred' });
    } catch (_e) { /* ignore — Shiny not ready */ }
  }

  function startPing() {
    stopPing();
    if (!isConnected) return;
    sendPing();
    pingTimer = setInterval(sendPing, getPingIntervalMs());
  }

  function stopPing() {
    if (pingTimer !== null) {
      clearInterval(pingTimer);
      pingTimer = null;
    }
  }

  function recoverUiAfterResume() {
    var suspendedTooLong = wasSuspendedTooLong();
    markRuntimeTick();

    if (suspendedTooLong) {
      markDisconnected(LONG_SUSPEND_MESSAGE);
      return;
    }

    if (!hasHealthyConnection()) {
      markDisconnected();
      return;
    }

    markConnected();

    try { window.dispatchEvent(new Event('resize')); } catch (_e) {}
    try { document.dispatchEvent(new Event('shiny:value')); } catch (_e2) {}
    try { document.dispatchEvent(new Event('shiny:recalculated')); } catch (_e3) {}

    nudgeGgiraph();
  }

  function scheduleResumeRecovery() {
    clearResumeTimer();
    resumeTimer = setTimeout(function () {
      resumeTimer = null;
      recoverUiAfterResume();
    }, RESUME_DELAY_MS);
  }

  /* ── Disconnect banner ───────────────────────────────────────────────────── */
  function showBanner(message) {
    if (document.getElementById(BANNER_ID)) return;
    var bannerMsg = String(message || DEFAULT_BANNER_MESSAGE);
    var banner = document.createElement('div');
    banner.id = BANNER_ID;
    banner.setAttribute('role', 'alert');
    banner.style.cssText = [
      'position:fixed', 'bottom:16px', 'left:50%', 'transform:translateX(-50%)',
      'z-index:99999', 'background:#1e3a4f', 'color:#e8f4fd',
      'padding:10px 20px', 'border-radius:8px',
      'box-shadow:0 4px 18px rgba(0,0,0,0.35)',
      'font:600 13px/1.45 system-ui,sans-serif',
      'display:flex', 'align-items:center', 'gap:12px',
      'max-width:520px', 'width:calc(100% - 32px)'
    ].join(';');
    banner.innerHTML =
      '<span style="flex:1">⚠\uFE0F  ' + bannerMsg + '</span>' +
      '<button id="' + BANNER_ID + '-reload" style="' +
        'background:#3a8fc7;color:#fff;border:none;border-radius:5px;' +
        'padding:5px 14px;font:inherit;cursor:pointer;white-space:nowrap' +
      '">Reload page</button>';
    document.body.appendChild(banner);
    document.getElementById(BANNER_ID + '-reload').addEventListener('click', function () {
      window.location.reload();
    });
  }

  function hideBanner() {
    var banner = document.getElementById(BANNER_ID);
    if (banner && banner.parentNode) banner.parentNode.removeChild(banner);
  }

  /* ── ggiraph tooltip nudge ───────────────────────────────────────────────── */
  /**
   * Resets ggiraph's interactive state after a tab-return, reconnect,
   * or Shiny output re-render.
   *
   * Analysis of ggiraph 0.9.2 internals:
   *  - The htmlwidget `resize` handler is a no-op (`resize:function(t,n){}`),
   *    so dispatching synthetic `resize` events on containers does nothing.
   *  - ggiraph attaches mouseover/mouseout/mousemove listeners directly to each
   *    SVG element (not to window or document), so dispatching events on
   *    `document` never reaches ggiraph's handlers.
   *  - `getBoundingClientRect` is called fresh on every mouse event, so
   *    coordinate mapping does not go stale by itself.
   *  - The primary causes of broken hover after a tab switch are:
   *      a) Orphaned .tooltip_girafe divs left floating in document.body that
   *         sit on top of content and swallow mouse events (fixed by
   *         flushOrphanedTooltips(), called from onTabShown).
   *      b) A "stuck" hover/tooltip on a just-hidden SVG whose mouseout was
   *         never fired — leaving internal handler state dirty.
   *
   * Two-step strategy:
   *
   * 1. Dispatch a `mouseout` event directly on every ggiraph SVG element.
   *    ggiraph's AM.handleEvent routes `mouseout` to handler.clear(), which
   *    hides the active tooltip and resets hover CSS classes.  This is the
   *    only event that reliably clears ggiraph's internal hover state.
   *
   * 2. Call ggiraph's own public API if it is exposed (varies by version).
   */
  function nudgeGgiraph() {
    // Dispatch mouseout only on visible ggiraph outputs. Hidden or recently
    // detached widgets may retain stale handlers that point to DOM nodes no
    // longer present; touching them can throw inside girafe.js and poison the
    // rest of the Shiny client loop.
    try {
      var outputs = document.querySelectorAll(GIRAFE_OUTPUT_SELECTOR);
      for (var i = 0; i < outputs.length; i++) {
        var output = outputs[i];
        if (!output || output.offsetParent === null) continue;
        var svgs = output.querySelectorAll('svg');
        for (var j = 0; j < svgs.length; j++) {
          try {
            svgs[j].dispatchEvent(new MouseEvent('mouseout', {
              bubbles: true, cancelable: false
            }));
          } catch (_ie) {}
        }
      }
    } catch (_e) {}
  }

  // Scoped variant: only nudges SVGs inside the given element (e.g. the single
  // output that just fired shiny:value). Avoids scanning ALL visible ggiraph
  // outputs on every card render.
  function nudgeGgiraphScope(rootEl) {
    if (!rootEl || !rootEl.querySelectorAll) return;
    try {
      if (rootEl.offsetParent === null && rootEl.id !== document.body.id) return;
      var svgs = rootEl.querySelectorAll('svg');
      for (var j = 0; j < svgs.length; j++) {
        try {
          svgs[j].dispatchEvent(new MouseEvent('mouseout', {
            bubbles: true, cancelable: false
          }));
        } catch (_ie) {}
      }
    } catch (_e) {}
  }

  function scheduleGgiraphNudge(delayMs) {
    var delay = parseInt(delayMs, 10);
    if (!isFinite(delay) || delay < 0) delay = 220;
    if (publicNudgeTimer !== null) {
      clearTimeout(publicNudgeTimer);
      publicNudgeTimer = null;
    }
    publicNudgeTimer = setTimeout(function () {
      publicNudgeTimer = null;
      nudgeGgiraph();
      // Second pass: helps when Shiny rebinds an existing girafe output into
      // a fresh DOM node without immediately triggering a new shiny:value.
      setTimeout(nudgeGgiraph, 240);
    }, delay);
  }

  window.nudgeGgiraph = nudgeGgiraph;
  window.scheduleGgiraphNudge = scheduleGgiraphNudge;

  // ---------------------------------------------------------------------------
  // toggleIsoformCards — expand / collapse isoform transcript cards below a
  // canonical card.  Called by the "▼ N transcripts" button in each canonical footer.
  //
  // btn:      the button element that was clicked
  // groupKey: data-isoform-group value shared by all isoform cards for that gene
  // data-count on btn: TOTAL transcript count (canonical + isoforms)
  // ---------------------------------------------------------------------------
  window.toggleIsoformCards = function (btn, groupKey) {
    if (!groupKey) return;
    // Selects only the isoform cards (canonical card does NOT have data-isoform-group)
    var selector = '[data-isoform-group="' + groupKey + '"]';
    var cards = document.querySelectorAll(selector);
    if (!cards || !cards.length) return;

    var currentlyHidden = (cards[0].style.display === 'none' || cards[0].style.display === '');
    var count = parseInt(btn.dataset.count || '0', 10);
    if (!isFinite(count)) count = cards.length;
    var label = count === 1 ? 'transcript' : 'transcripts';

    if (currentlyHidden) {
      try {
        if (typeof Shiny !== 'undefined' && Shiny.setInputValue) {
          var ids = [];
          for (var k = 0; k < cards.length; k++) {
            var rawId = cards[k].id || '';
            rawId = rawId.replace(/^homo-card-/, '').replace(/^ortho-card-/, '');
            if (rawId) ids.push(rawId);
          }
          Shiny.setInputValue('isoform_expand_request', {
            group: groupKey,
            context: groupKey.indexOf('ortho--') === 0 ? 'orthologous' : 'homologous',
            ids: ids,
            nonce: Date.now()
          }, { priority: 'event' });
        }
      } catch (_e0) {}
    }

    for (var i = 0; i < cards.length; i++) {
      cards[i].style.display = currentlyHidden ? 'flex' : 'none';
    }

    if (currentlyHidden) {
      btn.innerHTML = '&#x25B2; ' + count + ' ' + label;
      // 1. Trigger Shiny to re-evaluate suspended outputs now that cards are visible
      try { $(window).trigger('resize'); } catch (_e) {}
      // 2. Bind any newly visible Shiny outputs inside the expanded cards
      try {
        if (typeof Shiny !== 'undefined' && Shiny.bindAll) {
          setTimeout(function () {
            for (var j = 0; j < cards.length; j++) { Shiny.bindAll(cards[j]); }
          }, 120);
        }
      } catch (_e2) {}
      // 3. Nudge ggiraph so newly visible plots register their hover handlers
      try { if (typeof nudgeGgiraph === 'function') setTimeout(nudgeGgiraph, 300); } catch (_e3) {}
      try { if (typeof nudgeGgiraph === 'function') setTimeout(nudgeGgiraph, 850); } catch (_e4) {}
    } else {
      btn.innerHTML = '&#x25BC; ' + count + ' ' + label;
    }
  };
  var _girafe_repair_timers = Object.create(null);
  function scheduleGirafeRepair(delayMs, rootEl) {
    var delay = parseInt(delayMs, 10);
    if (!isFinite(delay) || delay < 0) delay = 900;
    var key = rootEl && rootEl.id ? String(rootEl.id) : '__global__';
    if (_girafe_repair_timers[key]) clearTimeout(_girafe_repair_timers[key]);
    _girafe_repair_timers[key] = setTimeout(function () {
      delete _girafe_repair_timers[key];
      repairBrokenGirafeOutputs(rootEl);
    }, delay);
  }

  var _diagHandlerInstalled = false;
  var _diagExpectedByOutput = Object.create(null);
  var _diagLogTimer = null;
  var _diagHandlerRetryTimer = null;
  window.__girafeDiagExpected = _diagExpectedByOutput;
  if (typeof window.__ggiraphDiagEnabled === 'undefined') {
    window.__ggiraphDiagEnabled = false;
  }
  window.setGgiraphDiagnosticsEnabled = function (enabled) {
    window.__ggiraphDiagEnabled = !!enabled;
    return window.__ggiraphDiagEnabled;
  };

  function collectGirafeActualCounts(outputId) {
    var root = document.getElementById(String(outputId || ''));
    if (!root) return null;
    var svgs = root.querySelectorAll('svg');
    var container = root.querySelector('.girafe_container_std, .girafe_container, .ggiraph-container');
    var bodyTips = document.querySelectorAll(
      'body > .tooltip_girafe, body > .tooltip_ggint, body > .girafe-tooltip, ' +
      'body > div[id^="tooltip_"], body > div[class^="tooltip_"], body > div[class*=" tooltip_"]'
    );
    var svgDataIdCount = 0;
    var svgTitleCount = 0;
    var hoverTaggedCount = 0;
    for (var i = 0; i < svgs.length; i++) {
      var svg = svgs[i];
      if (!svg) continue;
      svgDataIdCount += svg.querySelectorAll('[data-id], [data_id]').length;
      svgTitleCount += svg.querySelectorAll('[title]').length;
      hoverTaggedCount += svg.querySelectorAll('.hover_data_id').length;
    }
    return {
      hasSvg: svgs.length > 0,
      svgCount: svgs.length,
      hasContainer: !!container,
      svgDataId: svgDataIdCount,
      svgTitle: svgTitleCount,
      hoverTaggedNow: hoverTaggedCount,
      tooltipHostsInContainer: container ? container.querySelectorAll(
        '.tooltip_girafe, .tooltip_ggint, .girafe-tooltip, ' +
        'div[id^="tooltip_"], div[class^="tooltip_"], div[class*=" tooltip_"]'
      ).length : 0,
      bodyTooltipNodes: bodyTips ? bodyTips.length : 0
    };
  }

  function resolveDiagOutputIds() {
    var ids = Object.keys(_diagExpectedByOutput);
    if (!ids.length) {
      var defaults = ['ortho_aligned_plot_out', 'ortho_pip_plot_out', 'ortho_multipip_plot_out'];
      for (var d = 0; d < defaults.length; d++) {
        if (document.getElementById(defaults[d])) ids.push(defaults[d]);
      }
    }
    return ids;
  }

  function runDiagnosticsNow(reason) {
    var report = [];
    var ids = resolveDiagOutputIds();
    if (!ids.length) return report;
    for (var i = 0; i < ids.length; i++) {
      var outputId = ids[i];
      var expected = _diagExpectedByOutput[outputId] || {};
      var actual = collectGirafeActualCounts(outputId);
      if (!actual) continue;
      var entry = {
        outputId: outputId,
        reason: String(reason || 'event'),
        expected: expected,
        actual: actual
      };
      report.push(entry);
      try {
        console.groupCollapsed('[ggiraph-diag] ' + outputId + ' :: ' + entry.reason);
        console.log('expected:', expected);
        console.log('actual:', actual);
        console.groupEnd();
      } catch (_e) {}
    }
    return report;
  }

  function logSingleDiagnostic(outputId, reason) {
    var expected = _diagExpectedByOutput[outputId] || {};
    var actual = collectGirafeActualCounts(outputId);
    if (!actual) return null;
    var entry = {
      outputId: outputId,
      reason: String(reason || 'event'),
      expected: expected,
      actual: actual
    };
    try {
      console.groupCollapsed('[ggiraph-diag] ' + outputId + ' :: ' + entry.reason);
      console.log('expected:', expected);
      console.log('actual:', actual);
      console.groupEnd();
    } catch (_e) {}
    return entry;
  }

  function scheduleSingleDiagnostic(outputId, reason, delayMs) {
    if (!window.__ggiraphDiagEnabled) return;
    var delay = parseInt(delayMs, 10);
    if (!isFinite(delay) || delay < 0) delay = 0;
    window.setTimeout(function () {
      logSingleDiagnostic(outputId, reason);
    }, delay);
  }

  function scheduleDiagnosticsLog(reason) {
    if (!window.__ggiraphDiagEnabled) return;
    if (_diagLogTimer) clearTimeout(_diagLogTimer);
    _diagLogTimer = setTimeout(function () {
      _diagLogTimer = null;
      runDiagnosticsNow(reason || 'event');
    }, 260);
  }

  function installDiagMessageHandler() {
    if (_diagHandlerInstalled) return;
    if (!window.Shiny || typeof window.Shiny.addCustomMessageHandler !== 'function') return;
    window.Shiny.addCustomMessageHandler('ggiraph_diag_expected', function (msg) {
      var outputId = msg && msg.outputId ? String(msg.outputId) : '';
      if (!outputId) return;
      var expected = (msg && msg.expected && typeof msg.expected === 'object') ? msg.expected : {};
      var meta = (msg && msg.meta && typeof msg.meta === 'object') ? msg.meta : {};
      _diagExpectedByOutput[outputId] = { expected: expected, meta: meta, ts: msg && msg.ts ? msg.ts : Date.now() };
      scheduleSingleDiagnostic(outputId, 'expected-update', 260);
    });
    _diagHandlerInstalled = true;
  }

  window.runGgiraphDiagnostics = function (reason) {
    installDiagMessageHandler();
    return runDiagnosticsNow(reason || 'manual');
  };

  function scheduleDiagHandlerInstallRetry() {
    if (_diagHandlerInstalled || _diagHandlerRetryTimer) return;
    _diagHandlerRetryTimer = setTimeout(function () {
      _diagHandlerRetryTimer = null;
      installDiagMessageHandler();
      if (!_diagHandlerInstalled) scheduleDiagHandlerInstallRetry();
    }, 500);
  }

  /* ── Passive repair for ggiraph outputs ──────────────────────────────────── */
  /**
   * After a visual-mode switch or tab-return, some ggiraph outputs may have
   * rendered their SVG but failed to attach mouse/tooltip event listeners.
   *
   * Root cause (ggiraph 0.9.2 internals):
   *   _M.init() checks `if (!t.querySelector("*[title]")) return false`.
   *   When the SVG arrives before its title attributes are stamped in (race
   *   condition during reactive flush), _M.init() returns false → no tooltip
   *   handler is added to r.handlers → AM.init() also returns false → zero
   *   mouse listeners on the SVG → hover completely broken for that plot.
   *
   * Detection heuristic:
   *   After a successful ggiraph init, girafe_container_std has two children:
   *     1. the <svg> element
   *     2. the tooltip <div class="tooltip_svgid">
   *   After a failed init, only the <svg> is present (children.length === 1).
   *
   * Safe fix strategy:
   *   1) detect outputs that still look broken after render settles
   *      (expected interactive > 0 but SVG has no interactive tags),
   *   2) run only passive recovery (mouseout + resize nudge),
   *   3) avoid forcing Shiny input events from JS to prevent output-state races.
   *
   * Called:
   *   - T+1500 ms after a tab becomes visible (catches suspendWhenHidden re-renders)
   *   - T+2500 ms after a visual-mode change  (catches slow multi-species renders)
   *   - window.repairGgiraph() for ad-hoc console use
   */
  var _brokenSeenCountByOutput = Object.create(null);
  function getExpectedInteractiveCount(outputId) {
    var entry = _diagExpectedByOutput[String(outputId || '')];
    if (!entry || !entry.expected || typeof entry.expected !== 'object') return 0;
    var exp = entry.expected;
    var direct = parseInt(exp.interactive_total, 10);
    if (isFinite(direct) && direct > 0) return direct;
    var keys = ['feature_hover', 'ribbon_hover', 'segment_hover', 'block_hover'];
    var total = 0;
    for (var i = 0; i < keys.length; i++) {
      var val = parseInt(exp[keys[i]], 10);
      if (isFinite(val) && val > 0) total += val;
    }
    return total;
  }

  function repairBrokenGirafeOutputs(rootEl) {
    try {
      var root = rootEl && rootEl.querySelectorAll ? rootEl : document;
      var outputs = [];
      if (root.matches && root.matches(GIRAFE_OUTPUT_SELECTOR)) outputs.push(root);
      var descendants = root.querySelectorAll(GIRAFE_OUTPUT_SELECTOR);
      for (var d = 0; d < descendants.length; d++) outputs.push(descendants[d]);
      var brokenOutputIds = [];
      for (var i = 0; i < outputs.length; i++) {
        var output = outputs[i];
        var outputId = String(output && output.id ? output.id : ('idx-' + i));
        // Only attempt repair on visible outputs (hidden ones will re-render
        // themselves via suspendWhenHidden when they become visible).
        if (output.offsetParent === null) continue;
        var container = output.querySelector('.girafe_container_std, .girafe_container');
        if (!container) continue;
        var svgs = container.querySelectorAll('svg');
        if (!svgs || svgs.length === 0) {
          _brokenSeenCountByOutput[outputId] = 0;
          continue;
        }
        var interactiveNow = 0;
        for (var s = 0; s < svgs.length; s++) {
          interactiveNow += svgs[s].querySelectorAll('[data-id], [data_id], [title]').length;
        }
        var expectedInteractive = getExpectedInteractiveCount(outputId);
        // If we don't have an expected non-zero hover budget, skip repair
        // to avoid false positives while UI is legitimately empty/loading.
        if (interactiveNow > 0 || expectedInteractive <= 0) {
          _brokenSeenCountByOutput[outputId] = 0;
          continue;
        }
        _brokenSeenCountByOutput[outputId] = (_brokenSeenCountByOutput[outputId] || 0) + 1;
        // Require two consecutive failed checks to avoid races while render settles.
        if (_brokenSeenCountByOutput[outputId] >= 2) {
          brokenOutputIds.push(outputId);
        }
      }
      if (brokenOutputIds.length > 0) {
        if (root === document) nudgeGgiraph();
        else nudgeGgiraphScope(root);
        try { window.dispatchEvent(new Event('resize')); } catch (_e) {}
        scheduleDiagnosticsLog('soft-repair-nudge');
      }
    } catch (_e) {}
  }

  window.repairGgiraph = repairBrokenGirafeOutputs;

  /* ── Re-nudge ggiraph after each Shiny output update ───────────────────── */
  /**
   * When a ggiraph output is re-rendered by Shiny (e.g. the user switches
   * views, a reactive fires, or the session reconnects), the new SVG has fresh
   * DOM nodes but ggiraph's internal hover state may need resetting.
   * Nudging 180 ms after each `shiny:value` gives Shiny's output binding time
   * to finish inserting the SVG before we dispatch the mouseout flush.
   *
   * Pattern list covers:
   *  - Named special plots  : _plot_out, _girafe, _ggiraph, multipip, aligned, _chart
   *  - Individual gene cards: plot_ortho_N-plot  (Shiny module namespace = "plot_ortho_N", output = "plot")
   *                           plot_homo_N-plot   (Shiny module namespace = "plot_homo_N",  output = "plot")
   *
   * Because plot_ortho_* / plot_homo_* outputs were previously missing from this
   * list, the nudge never fired after individual gene cards re-rendered on a
   * visual-mode change, leaving their hover state uninitialized until the
   * much-earlier 420 ms mode-change nudge (which fired before most renders
   * finished).  Adding them here means the cascading timer approach kicks in:
   * each completed render resets the 180 ms timer, so the final nudge fires
   * 180 ms after the LAST card finishes — regardless of how many species are
   * loaded or how long rendering takes.
   */
  var _girafe_nudge_timer = null;
  document.addEventListener('shiny:value', function (e) {
    var name = (e && e.name) ? String(e.name) : '';
    if (!name) return;
    if (
      name.indexOf('_plot_out')   !== -1 ||
      name.indexOf('_girafe')     !== -1 ||
      name.indexOf('_ggiraph')    !== -1 ||
      name.indexOf('multipip')    !== -1 ||
      name.indexOf('aligned')     !== -1 ||
      name.indexOf('_chart')      !== -1 ||
      name.indexOf('plot_ortho_') !== -1 ||
      name.indexOf('plot_homo_')  !== -1
    ) {
      // Nudge ONLY the output that just updated — avoids scanning every
      // visible ggiraph output on each card render.
      nudgeGgiraphScope(e.target);
      if (_girafe_nudge_timer) clearTimeout(_girafe_nudge_timer);
      _girafe_nudge_timer = setTimeout(function () {
        _girafe_nudge_timer = null;
        scheduleGirafeRepair(950, e.target);
        scheduleDiagnosticsLog('shiny-value:' + name);
      }, 180);
    }
  });

  /* ── Nudge ggiraph when an app tab becomes visible (shown.bs.tab) ────────── */
  /**
   * When the user navigates between tabs inside the app (e.g. Homologous ↔
   * Orthologous), Bootstrap fires `shown.bs.tab` but Shiny does NOT fire
   * `shiny:value` for plots that were already rendered and have not been
   * invalidated.  Without a nudge, ggiraph's internal hit-test coordinate
   * mapping stays stale: hover zones are offset from where they appear, so
   * tooltips stop working on already-rendered plots.
   *
   * Plots configured with `suspendWhenHidden = TRUE` (e.g. ortho_aligned_plot_out,
   * ortho_pip_plot_out, ortho_multipip_plot_out) will re-render and fire their
   * own `shiny:value` → those are handled by the listener above.  The nudge
   * here covers all other already-rendered plots that stay in the DOM.
   *
   * These timers are intentionally SEPARATE from publicNudgeTimer (used by
   * scheduleGgiraphNudge) so that a shiny:value nudge mid-transition does not
   * cancel the tab-switch nudges, and vice-versa.
   *
   * Two-pass strategy:
   *  T+400 ms — first nudge: tab CSS transition has settled, most plots are ready.
   *  T+750 ms — fallback nudge: catches suspendWhenHidden re-renders that finish
   *             after the first nudge, or slow reactive flushes.
   */

  /**
   * Hide any .tooltip_girafe divs that ggiraph left floating in document.body
   * after a tab switch.  These orphaned tooltips can sit on top of the new
   * tab's content and silently swallow mouse events, making hovers appear broken.
   */
  function flushOrphanedTooltips() {
    try {
      var tips = document.querySelectorAll(
        '.tooltip_girafe, .tooltip_ggint, .girafe-tooltip, ' +
        'div[id^="tooltip_"], div[class^="tooltip_"], div[class*=" tooltip_"]'
      );
      for (var i = 0; i < tips.length; i++) {
        var tip = tips[i];
        if (!tip) continue;
        // ggiraph may place tooltip hosts directly under <body>; deleting them
        // breaks later hover because handlers still expect the node to exist.
        // Keep the node in place and only ensure it never captures pointer input.
        tip.style.pointerEvents = 'none';
      }
    } catch (_e) {}
  }

  var _tab_nudge_t1   = null;
  var _tab_nudge_t2   = null;
  var _tab_repair_t   = null;

  function onTabShown() {
    // Immediately remove orphaned tooltips so they don't block hover hit-testing.
    flushOrphanedTooltips();

    // First nudge — tab CSS transition has settled.
    if (_tab_nudge_t1) clearTimeout(_tab_nudge_t1);
    _tab_nudge_t1 = setTimeout(function () {
      _tab_nudge_t1 = null;
      nudgeGgiraph();
    }, 400);

    // Fallback nudge — catches re-renders that finish after the first nudge.
    if (_tab_nudge_t2) clearTimeout(_tab_nudge_t2);
    _tab_nudge_t2 = setTimeout(function () {
      _tab_nudge_t2 = null;
      nudgeGgiraph();
    }, 750);

    // Repair pass — detects and re-binds any ggiraph outputs whose mouse/tooltip
    // listeners failed to attach (failed _M.init → children.length === 1).
    if (_tab_repair_t) clearTimeout(_tab_repair_t);
    _tab_repair_t = setTimeout(function () {
      _tab_repair_t = null;
      repairBrokenGirafeOutputs();
    }, 1500);

    scheduleDiagnosticsLog('tab-shown');
  }

  document.addEventListener('shown.bs.tab', onTabShown);

  /* ── Nudge ggiraph when switching app views via custom nav ─────────────── */
  document.addEventListener('click', function (e) {
    if (e && e.target && e.target.closest && e.target.closest('.app-nav-btn[data-target]')) {
      onTabShown();
    }
  });

  /* ── Visual-mode toggles also swap/rebind girafe outputs ───────────────── */
  /**
   * When the user switches visual mode (compact ↔ detailed ↔ aligned …) every
   * individual gene-card plot re-renders.  With 20+ species this can take
   * 1-3 seconds total.
   *
   * Two-pass strategy (independent timers so shiny:value resets don't cancel):
   *  T+420 ms — early sweep: clears any orphaned tooltips from the previous mode
   *             for plots that were already cached and rendered quickly.
   *  T+1400 ms — late fallback: catches slow-rendering cards that finished after
   *              the shiny:value cascade timer already fired its final nudge.
   *              Harmless if all plots finished earlier.
   */
  var _mode_nudge_t1  = null;
  var _mode_nudge_t2  = null;
  var _mode_nudge_t3  = null;
  var _mode_nudge_t4  = null;
  var _mode_repair_t  = null;
  var _mode_repair_t2 = null;
  function normalizeVisualMode(rawValue) {
    var mode = String(rawValue || '').trim().toLowerCase();
    if (mode === 'pip') mode = 'pip_blocks';
    return mode;
  }
  function isSpecialOrthoMode(modeValue) {
    var mode = normalizeVisualMode(modeValue);
    return mode === 'aligned' || mode === 'pip_blocks' || mode === 'pip_multipip';
  }
  function isSpecialHomoMode(modeValue) {
    var mode = normalizeVisualMode(modeValue);
    return mode === 'aligned' || mode === 'pip_blocks' || mode === 'pip_multipip';
  }
  document.addEventListener('change', function (e) {
    var target = e && e.target ? e.target : null;
    var name = target && target.name ? String(target.name) : '';
    if (name === 'homo_visual_mode' || name === 'ortho_visual_mode') {
      if (_mode_nudge_t1)  clearTimeout(_mode_nudge_t1);
      if (_mode_nudge_t2)  clearTimeout(_mode_nudge_t2);
      if (_mode_nudge_t3)  clearTimeout(_mode_nudge_t3);
      if (_mode_nudge_t4)  clearTimeout(_mode_nudge_t4);
      if (_mode_repair_t)  clearTimeout(_mode_repair_t);
      if (_mode_repair_t2) clearTimeout(_mode_repair_t2);
      flushOrphanedTooltips();
      _brokenSeenCountByOutput = Object.create(null);
      _diagExpectedByOutput = Object.create(null);
      _mode_nudge_t1 = setTimeout(function () { _mode_nudge_t1 = null; nudgeGgiraph(); }, 420);
      _mode_nudge_t2 = setTimeout(function () { _mode_nudge_t2 = null; nudgeGgiraph(); }, 1400);
      // Soft-repair pass — after all gene-card renders should have completed.
      // Detects plots still missing tooltip hosts and performs a safe recovery.
      _mode_repair_t = setTimeout(function () { _mode_repair_t = null; repairBrokenGirafeOutputs(); }, 2500);
      if ((name === 'ortho_visual_mode' && isSpecialOrthoMode(target && target.value)) ||
          (name === 'homo_visual_mode' && isSpecialHomoMode(target && target.value))) {
        _mode_nudge_t3 = setTimeout(function () {
          _mode_nudge_t3 = null;
          flushOrphanedTooltips();
          nudgeGgiraph();
        }, 2600);
        _mode_nudge_t4 = setTimeout(function () {
          _mode_nudge_t4 = null;
          flushOrphanedTooltips();
          nudgeGgiraph();
        }, 4200);
        _mode_repair_t2 = setTimeout(function () {
          _mode_repair_t2 = null;
          flushOrphanedTooltips();
          repairBrokenGirafeOutputs();
          scheduleDiagnosticsLog('mode-change-special-late');
        }, 5200);
      }
      scheduleDiagnosticsLog('mode-change');
    }
  });

  /* ── Tab-visibility recovery ─────────────────────────────────────────────── */
  document.addEventListener('visibilitychange', function () {
    markRuntimeTick();
    if (document.hidden) {
      clearResumeTimer();
      if (isConnected) startPing();
      return;
    }

    scheduleResumeRecovery();
  });

  window.addEventListener('focus', scheduleResumeRecovery, { passive: true });
  window.addEventListener('pageshow', scheduleResumeRecovery, { passive: true });
  window.addEventListener('online', scheduleResumeRecovery, { passive: true });

  /* ── Shiny connection events ─────────────────────────────────────────────── */
  document.addEventListener('shiny:connected', function () {
    markRuntimeTick();
    markConnected();
    installDiagMessageHandler();
    scheduleDiagnosticsLog('shiny-connected');
  });

  document.addEventListener('shiny:reconnected', function () {
    markRuntimeTick();
    markConnected();
    installDiagMessageHandler();
    // After reconnect ggiraph outputs may need a re-render nudge
    scheduleGgiraphNudge(600);
    scheduleDiagnosticsLog('shiny-reconnected');
  });

  document.addEventListener('shiny:disconnected', function () {
    markRuntimeTick();
    markDisconnected();
  });

  installDiagMessageHandler();
  scheduleDiagHandlerInstallRetry();

  /* ── Shiny session idle-timeout override ─────────────────────────────────── */
  // Shiny's client checks session.timeout; we override to a very large value
  // so that our ping loop is the sole keepalive mechanism.
  document.addEventListener('shiny:sessioninitialized', function () {
    try {
      if (window.Shiny && window.Shiny.shinyapp && window.Shiny.shinyapp.$session) {
        // Disable the built-in client-side idle-timeout (set to 24 h)
        window.Shiny.shinyapp.$session.timeout = 86400000;
      }
    } catch (_e) {}
  });

  /* ── Bootstrap ───────────────────────────────────────────────────────────── */
  // If Shiny is already connected when this script loads (script loaded late)
  if (window.Shiny && typeof window.Shiny.setInputValue === 'function') {
    installDiagMessageHandler();
    markRuntimeTick();
    isConnected = hasHealthyConnection();
    if (isConnected) startPing();
    scheduleDiagnosticsLog('bootstrap');
  }

})();
