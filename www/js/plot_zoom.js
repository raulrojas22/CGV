(function () {
  'use strict';
  if (window.__plotZoomInitialized) return;
  window.__plotZoomInitialized = true;

  // 1× is the minimum (default). No zoom-out.
  var LEVELS = [1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0];
  var LABELS = ['1\u00d7', '1.25\u00d7', '1.5\u00d7', '2\u00d7',
                '2.5\u00d7', '3\u00d7', '4\u00d7', '5\u00d7'];
  var DEFAULT_IDX = 0;

  var state = {
    homo:  { idx: DEFAULT_IDX },
    ortho: { idx: DEFAULT_IDX }
  };
  var transitionMaskState = {
    homo: { timeout: null, revealRaf: null, lastSignature: '', stableFrames: 0, active: false },
    ortho: { timeout: null, revealRaf: null, lastSignature: '', stableFrames: 0, active: false }
  };
  var COMPACT_PLOT_CONTAINER_HEIGHT = 110;
  var DETAILED_PLOT_CONTAINER_HEIGHT = 110;
  var DETAILED_PLOT_SVG_HEIGHT = 110;
  var fabSyncRaf = null;
  var containerObservers = [];

  function scheduleFabSync() {
    if (fabSyncRaf !== null) return;
    fabSyncRaf = window.requestAnimationFrame(function () {
      fabSyncRaf = null;
      syncQuickFabZoomControls();
    });
  }

  function getContainerId(mode) {
    return mode === 'homo' ? 'plot-container' : 'ortho-plot-container';
  }

  function setTranscriptTransitionMask(mode, masked) {
    var container = document.getElementById(getContainerId(mode));
    if (!container) return;
    var plots = container.querySelectorAll('.promoter-plot-container');
    for (var i = 0; i < plots.length; i++) {
      if (masked) ensureTranscriptTransitionLoader(plots[i]);
      plots[i].classList.toggle('plot-geometry-settling', !!masked);
    }
  }

  function ensureTranscriptTransitionLoader(plotEl) {
    if (!plotEl || !plotEl.querySelector) return;
    if (plotEl.querySelector('.promoter-plot-transition-loader')) return;

    var loader = document.createElement('div');
    loader.className = 'promoter-plot-transition-loader';
    loader.setAttribute('aria-hidden', 'true');
    if (typeof window.appBuildDnaLoader === 'function') {
      loader.innerHTML = window.appBuildDnaLoader('promoter-plot-dna-loader');
    }
    plotEl.appendChild(loader);
  }

  function hasReadyTranscriptPlots(mode) {
    var container = document.getElementById(getContainerId(mode));
    if (!container) return false;
    return !!container.querySelector('.promoter-plot-container svg[viewBox]');
  }

  function cancelModeTransitionReveal(mode) {
    var st = transitionMaskState[mode];
    if (!st) return;
    if (st.timeout !== null) {
      clearTimeout(st.timeout);
      st.timeout = null;
    }
    if (st.revealRaf !== null) {
      cancelAnimationFrame(st.revealRaf);
      st.revealRaf = null;
    }
    st.lastSignature = '';
    st.stableFrames = 0;
  }

  function sampleTranscriptGeometrySignature(mode) {
    var container = document.getElementById(getContainerId(mode));
    if (!container) return '';
    var svgs = container.querySelectorAll('.promoter-plot-container svg[viewBox]');
    if (!svgs.length) return '';

    var parts = [];
    for (var i = 0; i < svgs.length; i++) {
      var svg = svgs[i];
      var plot = svg.closest('.promoter-plot-container');
      var rect = null;
      var plotRect = null;
      try {
        rect = svg.getBoundingClientRect();
        plotRect = plot ? plot.getBoundingClientRect() : null;
      } catch (err) {}
      parts.push([
        Math.round((rect && rect.width ? rect.width : 0) * 10) / 10,
        Math.round((rect && rect.height ? rect.height : 0) * 10) / 10,
        Math.round((plotRect && plotRect.height ? plotRect.height : 0) * 10) / 10,
        svg.getAttribute('preserveAspectRatio') || '',
        svg.style.height || '',
        svg.style.transform || ''
      ].join(':'));
      if (parts.length >= 8) break;
    }
    return parts.join('|');
  }

  function endModeTransitionMask(mode) {
    var st = transitionMaskState[mode];
    if (!st) return;
    cancelModeTransitionReveal(mode);
    st.active = false;
    setTranscriptTransitionMask(mode, false);
  }

  function scheduleStableModeReveal(mode) {
    var st = transitionMaskState[mode];
    if (!st || !st.active) return;
    if (st.revealRaf !== null) {
      cancelAnimationFrame(st.revealRaf);
      st.revealRaf = null;
    }

    var tick = function () {
      if (!st.active) return;
      if (!hasReadyTranscriptPlots(mode)) {
        st.revealRaf = requestAnimationFrame(tick);
        return;
      }

      var signature = sampleTranscriptGeometrySignature(mode);
      if (!signature) {
        st.revealRaf = requestAnimationFrame(tick);
        return;
      }

      if (signature === st.lastSignature) {
        st.stableFrames += 1;
      } else {
        st.lastSignature = signature;
        st.stableFrames = 0;
      }

      if (st.stableFrames >= 2) {
        endModeTransitionMask(mode);
        return;
      }

      st.revealRaf = requestAnimationFrame(tick);
    };

    st.revealRaf = requestAnimationFrame(tick);
  }

  function beginModeTransitionMask(mode) {
    var st = transitionMaskState[mode];
    if (!state[mode] || !st) return;
    cancelModeTransitionReveal(mode);
    st.active = true;
    st.lastSignature = '';
    st.stableFrames = 0;
    setTranscriptTransitionMask(mode, true);
    st.timeout = setTimeout(function () {
      st.timeout = null;
      endModeTransitionMask(mode);
    }, 2200);
  }

  function parseViewBox(svg) {
    if (!svg || !svg.getAttribute) return null;
    var raw = String(svg.getAttribute('viewBox') || '').trim();
    if (!raw) return null;
    var parts = raw.split(/[\s,]+/);
    if (parts.length < 4) return null;
    var width = parseFloat(parts[2]);
    var height = parseFloat(parts[3]);
    if (!(width > 0) || !(height > 0)) return null;
    return { width: width, height: height };
  }

  function isTranscriptPlotItem(item) {
    return !!(item && item.closest && item.closest('.promoter-plot-container'));
  }

  function getWidthFillStretchFactor(svg) {
    var vb = parseViewBox(svg);
    if (!vb) return 1;
    var rect = null;
    try {
      rect = svg.getBoundingClientRect();
    } catch (err) {}
    if (!rect || !(rect.width > 0) || !(rect.height > 0)) return 1;
    var xScale = rect.width / vb.width;
    var yScale = rect.height / vb.height;
    if (!(xScale > 0) || !(yScale > 0)) return 1;
    return xScale / yScale;
  }

  function getTranscriptSvgNaturalSize(svg) {
    var vb = parseViewBox(svg);
    if (!vb) return null;
    return {
      width: vb.width * (96 / 72),
      height: vb.height * (96 / 72)
    };
  }

  function isCompactVisualMode() {
    var shell = document.querySelector('.app-shell');
    return !!(shell && shell.classList.contains('compact-visual-mode'));
  }

  function isSidebarCollapsed() {
    var shell = document.querySelector('.app-shell');
    return !!(shell && shell.classList.contains('sidebar-collapsed'));
  }

  function getTranscriptSvgDisplayHeight(svg) {
    var naturalSize = getTranscriptSvgNaturalSize(svg);
    if (!naturalSize) return 0;
    if (!isCompactVisualMode()) {
      return DETAILED_PLOT_SVG_HEIGHT;
    }
    return naturalSize.height * 0.90;
  }

  function syncTranscriptPlotContainerHeight(item, displayHeight) {
    if (!isTranscriptPlotItem(item)) return;

    var plotContainer = item.closest('.promoter-plot-container');
    if (!plotContainer) return;

    if (isCompactVisualMode()) {
      plotContainer.style.setProperty('height', COMPACT_PLOT_CONTAINER_HEIGHT + 'px', 'important');
      plotContainer.style.setProperty('min-height', COMPACT_PLOT_CONTAINER_HEIGHT + 'px', 'important');
      return;
    }

    plotContainer.style.setProperty('height', DETAILED_PLOT_CONTAINER_HEIGHT + 'px', 'important');
    plotContainer.style.setProperty('min-height', DETAILED_PLOT_CONTAINER_HEIGHT + 'px', 'important');
  }

  function getTranscriptSvgUniformPreserveAspectRatio() {
    if (!isCompactVisualMode()) return 'xMidYMid meet';
    if (isSidebarCollapsed()) return 'xMidYMid meet';
    return 'xMidYMin meet';
  }

  function getTranscriptSvgVerticalOffset() {
    if (!isCompactVisualMode()) return 0;
    if (isSidebarCollapsed()) return -2;
    return 0;
  }

  function fitItemToAvailableWidth(item) {
    if (!isTranscriptPlotItem(item)) return;

    var isCompactMode = isCompactVisualMode();

    var inner = item.querySelector('.girafe_container');
    if (inner) {
      inner.style.paddingBottom = '0';
      inner.style.height = '100%';
      inner.style.display = 'flex';
      inner.style.alignItems = 'center';
    }

    item.style.display = 'flex';
    item.style.alignItems = 'center';

    var svgs = item.querySelectorAll('svg');
    for (var j = 0; j < svgs.length; j++) {
      var svg = svgs[j];
      var naturalSize = getTranscriptSvgNaturalSize(svg);
      var displayHeight = getTranscriptSvgDisplayHeight(svg);
      syncTranscriptPlotContainerHeight(item, displayHeight);
      var hostWidth = 0;
      try {
        hostWidth = item.getBoundingClientRect().width || 0;
      } catch (err) {}
      var shouldUseUniformFit = !!(isCompactMode && naturalSize && hostWidth > 0 && hostWidth < (naturalSize.width - 2));

      if (!svg.hasAttribute('data-orig-pa')) {
        svg.setAttribute('data-orig-pa', svg.getAttribute('preserveAspectRatio') || '');
      }

      if (shouldUseUniformFit) {
        svg.setAttribute('preserveAspectRatio', getTranscriptSvgUniformPreserveAspectRatio());
      } else {
        svg.setAttribute('preserveAspectRatio', 'none');
      }

      svg.style.setProperty('width', '100%', 'important');
      svg.style.setProperty('height', displayHeight > 0 ? (displayHeight + 'px') : '100%', 'important');
      svg.style.setProperty('margin-left', 'auto', 'important');
      svg.style.setProperty('margin-right', 'auto', 'important');
      var verticalOffset = getTranscriptSvgVerticalOffset();
      svg.style.setProperty('transform', verticalOffset !== 0 ? ('translateY(' + verticalOffset + 'px)') : '', 'important');

      if (shouldUseUniformFit) {
        restoreDecorations(svg);
      } else {
        counterScaleDecorations(svg, getWidthFillStretchFactor(svg));
      }
    }
  }

  var responsiveRefitTimer = null;

  function scheduleResponsiveRefit() {
    if (responsiveRefitTimer !== null) clearTimeout(responsiveRefitTimer);
    responsiveRefitTimer = setTimeout(function () {
      responsiveRefitTimer = null;
      applyZoom('homo');
      applyZoom('ortho');
    }, 90);
  }

  // The scroll-wrapper (.plots-zoom-wrap) never changes width — use it as the
  // stable 1× reference width.
  function getWrapWidth(container) {
    var wrap = container.parentElement;
    return (wrap ? wrap.getBoundingClientRect().width : 0) || window.innerWidth;
  }

  function isElementVisible(el) {
    if (!el) return false;
    var st = null;
    try {
      st = window.getComputedStyle(el);
    } catch (err) {}
    if (!st) return true;
    if (st.display === 'none' || st.visibility === 'hidden') return false;
    return true;
  }

  function getActiveZoomMode() {
    var activeNavBtn = document.querySelector('.app-nav-btn.is-active[data-target]');
    var target = activeNavBtn ? String(activeNavBtn.getAttribute('data-target') || '').trim() : '';
    if (target === 'homologous') return 'homo';
    if (target === 'orthologous') return 'ortho';

    if (isElementVisible(document.getElementById('homo-zoom-control'))) return 'homo';
    if (isElementVisible(document.getElementById('ortho-zoom-control'))) return 'ortho';
    return null;
  }

  function syncQuickFabZoomControls() {
    var toggleBtn = document.getElementById('app-fab-zoom-toggle');
    var panel = document.getElementById('app-fab-zoom-panel');
    var outBtn = document.getElementById('fab-zoom-out');
    var inBtn = document.getElementById('fab-zoom-in');
    var label = document.getElementById('fab-zoom-label');
    if (!toggleBtn || !outBtn || !inBtn || !label) return;

    var mode = getActiveZoomMode();
    var modeCtl = mode ? document.getElementById(mode + '-zoom-control') : null;
    var enabled = !!(mode && modeCtl && isElementVisible(modeCtl));

    toggleBtn.style.display = enabled ? '' : 'none';
    toggleBtn.setAttribute('aria-hidden', enabled ? 'false' : 'true');
    toggleBtn.setAttribute('aria-expanded', panel && panel.classList.contains('is-open') ? 'true' : 'false');

    if (!enabled) {
      if (panel) panel.classList.remove('is-open');
      return;
    }

    outBtn.setAttribute('data-zoom-mode', mode);
    inBtn.setAttribute('data-zoom-mode', mode);
    label.textContent = LABELS[state[mode].idx] || '1\u00d7';
    outBtn.disabled = (state[mode].idx === 0);
    inBtn.disabled = (state[mode].idx === LEVELS.length - 1);
  }

  // ── Restore counter-scale transforms ────────────────────────────────────────
  function restoreDecorations(svg) {
    var els = svg.querySelectorAll('[data-zoom-orig-tf]');
    for (var i = 0; i < els.length; i++) {
      var orig = els[i].getAttribute('data-zoom-orig-tf');
      if (orig) els[i].setAttribute('transform', orig);
      else      els[i].removeAttribute('transform');
      els[i].removeAttribute('data-zoom-orig-tf');
    }
    // Safety: clear any CSS leftovers from previous approaches
    var cssEls = svg.querySelectorAll('[data-zoom-css]');
    for (var i = 0; i < cssEls.length; i++) {
      cssEls[i].style.transform       = '';
      cssEls[i].style.transformBox    = '';
      cssEls[i].style.transformOrigin = '';
      cssEls[i].removeAttribute('data-zoom-css');
    }
  }

  // ── Apply inverse-x-scale to elements that must NOT appear stretched ─────────
  // All transforms are SVG transforms (in viewBox space) so every counter-scaled
  // element still moves proportionally with the zoom — it just doesn't stretch.
  function counterScaleDecorations(svg, factor) {
    if (factor <= 1.0) { restoreDecorations(svg); return; }

    // Clear previous counter-scale before re-applying (handles factor change)
    restoreDecorations(svg);

    var inv = 1 / factor;

    function applyCS(els, getCx) {
      for (var i = 0; i < els.length; i++) {
        var el  = els[i];
        var cx  = getCx(el);
        var orig = el.getAttribute('transform') || '';
        el.setAttribute('data-zoom-orig-tf', orig);
        var cs = 'translate(' + cx + ',0) scale(' + inv + ',1) translate(' + (-cx) + ',0)';
        el.setAttribute('transform', orig ? cs + ' ' + orig : cs);
      }
    }

    // ── Text elements ──────────────────────────────────────────────────────────
    // Use the rendered text center as pivot whenever possible. This keeps
    // distance labels and neighbor names pinned to their guide marks at high
    // horizontal zoom levels (3x/4x/5x), while still preventing glyph stretch.
    applyCS(svg.querySelectorAll('text'), function (t) {
      // If this text already has its own transform (e.g., rotated axis label),
      // keep pivot in local coordinates to avoid compounding translations.
      if (t.hasAttribute('transform')) return 0;

      // Preferred pivot: visual center of rendered text box.
      try {
        var bb = t.getBBox();
        if (bb && isFinite(bb.x) && isFinite(bb.width) && bb.width > 0) {
          return bb.x + (bb.width / 2);
        }
      } catch (err) {
        // Fallback to attribute-based pivot below.
      }

      // Fallbacks for cases where bbox is unavailable.
      var x = t.getAttribute('x');
      if (x !== null && x !== '') return parseFloat(x);
      var ts = t.querySelector('tspan[x]');
      return ts ? parseFloat(ts.getAttribute('x') || '0') : 0;
    });

    // ── Circle elements (neighbor gene markers) ────────────────────────────────
    // Prevents circles from becoming horizontal ellipses under x-only stretch.
    applyCS(svg.querySelectorAll('circle'), function (c) {
      return parseFloat(c.getAttribute('cx') || '0');
    });

    // ── Polygon elements (arrow head — geom_polygon filled triangle) ──────────
    applyCS(svg.querySelectorAll('polygon'), function (p) {
      var nums = ((p.getAttribute('points') || '').match(/-?[\d.]+/g) || []);
      var sumX = 0, count = 0;
      for (var j = 0; j < nums.length; j += 2) {
        sumX += parseFloat(nums[j]) || 0;
        count++;
      }
      return count > 0 ? sumX / count : 0;
    });
  }

  // ── Restore a single girafeOutput to its natural state ──────────────────────
  function restoreItem(item) {
    item.style.height = '';
    item.removeAttribute('data-natural-h');

    var inner = item.querySelector('.girafe_container');
    if (inner) {
      var origPB = inner.getAttribute('data-orig-pb');
      if (origPB !== null) {
        inner.style.paddingBottom = origPB || '';
        inner.style.height = '';
        inner.removeAttribute('data-orig-pb');
      }
    }

    var svgs = item.querySelectorAll('svg');
    for (var j = 0; j < svgs.length; j++) {
      var svg = svgs[j];
      restoreDecorations(svg);
      var origPA = svg.getAttribute('data-orig-pa');
      if (origPA !== null) {
        if (origPA) svg.setAttribute('preserveAspectRatio', origPA);
        else        svg.removeAttribute('preserveAspectRatio');
        svg.removeAttribute('data-orig-pa');
      }
      svg.style.width  = '';
      svg.style.height = '';
    }

    fitItemToAvailableWidth(item);
  }

  // ── Fix a single girafeOutput to a specific pixel height ────────────────────
  function stretchItem(item, naturalH, factor) {
    if (!(naturalH > 0)) return;
    syncTranscriptPlotContainerHeight(item, naturalH);
    item.setAttribute('data-natural-h', naturalH);
    item.style.height = naturalH + 'px';

    // Kill padding-bottom on inner div (this is what makes the plot grow tall)
    var inner = item.querySelector('.girafe_container');
    if (inner) {
      if (!inner.hasAttribute('data-orig-pb')) {
        inner.setAttribute('data-orig-pb', inner.style.paddingBottom || '');
      }
      inner.style.paddingBottom = '0';
      inner.style.height = naturalH + 'px';
    }

    // Stretch SVG horizontally only + counter-scale text and arrow head
    var svgs = item.querySelectorAll('svg');
    for (var j = 0; j < svgs.length; j++) {
      var svg = svgs[j];
      if (!svg.hasAttribute('data-orig-pa')) {
        svg.setAttribute('data-orig-pa', svg.getAttribute('preserveAspectRatio') || '');
      }
      svg.setAttribute('preserveAspectRatio', 'none');
      svg.style.width  = '100%';
      svg.style.height = naturalH + 'px';
      counterScaleDecorations(svg, factor);
    }
  }

  // Compute natural height from SVG viewBox + the 1× reference width.
  // Used for plots that render AFTER zoom is already applied (MutationObserver).
  function naturalHFromViewBox(item, wrapWidth) {
    var svg = item.querySelector('svg[viewBox]');
    if (!svg) return 0;
    var parts = (svg.getAttribute('viewBox') || '').trim().split(/[\s,]+/);
    if (parts.length < 4) return 0;
    var vbW = parseFloat(parts[2]);
    var vbH = parseFloat(parts[3]);
    return (vbW > 0 && vbH > 0) ? wrapWidth * (vbH / vbW) : 0;
  }

  function settleContainerItems(mode) {
    var containerId = getContainerId(mode);
    var c = document.getElementById(containerId);
    if (!c) return;

    var factor = LEVELS[state[mode].idx];
    var wrapWidth = getWrapWidth(c);

    if (factor <= 1.0) {
      var baseItems = c.querySelectorAll('.girafe_container_std');
      for (var i = 0; i < baseItems.length; i++) {
        fitItemToAvailableWidth(baseItems[i]);
      }
      if (hasReadyTranscriptPlots(mode)) {
        scheduleStableModeReveal(mode);
      }
      scheduleFabSync();
      return;
    }

    var items = c.querySelectorAll('.girafe_container_std:not([data-natural-h])');
    for (var j = 0; j < items.length; j++) {
      var nh = naturalHFromViewBox(items[j], wrapWidth);
      stretchItem(items[j], nh, factor);
    }
    if (hasReadyTranscriptPlots(mode)) {
      scheduleStableModeReveal(mode);
    }
    scheduleFabSync();
  }

  // ── Main zoom function ───────────────────────────────────────────────────────
  function applyZoom(mode) {
    var s         = state[mode];
    var factor    = LEVELS[s.idx];
    var container = document.getElementById(getContainerId(mode));
    var label     = document.getElementById(mode + '-zoom-label');
    var btnOut    = document.getElementById(mode + '-zoom-out');
    var btnIn     = document.getElementById(mode + '-zoom-in');

    if (container) {
      var items = container.querySelectorAll('.girafe_container_std');

      if (factor <= 1.0) {
        // ── Reset ─────────────────────────────────────────────────────────────
        container.style.width = '';
        for (var i = 0; i < items.length; i++) restoreItem(items[i]);

      } else {
        // ── Zoom in ───────────────────────────────────────────────────────────
        // Capture natural heights BEFORE widening the container.
        var wrapWidth = getWrapWidth(container);
        for (var i = 0; i < items.length; i++) {
          if (!items[i].hasAttribute('data-natural-h')) {
            var h = items[i].getBoundingClientRect().height;
            if (!(h > 0)) h = naturalHFromViewBox(items[i], wrapWidth);
            items[i].setAttribute('data-natural-h', h || 0);
          }
        }
        // Now widen
        container.style.width = (factor * 100) + '%';
        // Fix heights + stretch + counter-scale decorations
        for (var i = 0; i < items.length; i++) {
          var nh = parseFloat(items[i].getAttribute('data-natural-h')) || 0;
          stretchItem(items[i], nh, factor);
        }
      }
    }

    if (label)  label.textContent = LABELS[s.idx];
    if (btnOut) btnOut.disabled   = (s.idx === 0);
    if (btnIn)  btnIn.disabled    = (s.idx === LEVELS.length - 1);
    scheduleFabSync();
  }

  // ── Button clicks ────────────────────────────────────────────────────────────
  document.addEventListener('click', function (e) {
    var btn = e.target && e.target.closest
      ? e.target.closest('[data-zoom-action]')
      : null;
    if (!btn) return;

    var action = btn.getAttribute('data-zoom-action');
    var mode   = btn.getAttribute('data-zoom-mode');
    if (!action || !mode || !state[mode]) return;

    if      (action === 'in'  && state[mode].idx < LEVELS.length - 1) state[mode].idx++;
    else if (action === 'out' && state[mode].idx > 0)                  state[mode].idx--;
    else if (action === 'reset')                                        state[mode].idx = DEFAULT_IDX;
    else return;

    applyZoom(mode);
  });

  document.addEventListener('change', function (e) {
    var target = e && e.target ? e.target : null;
    var name = target && target.name ? String(target.name) : '';
    if (name === 'homo_visual_mode') {
      beginModeTransitionMask('homo');
    } else if (name === 'ortho_visual_mode') {
      beginModeTransitionMask('ortho');
    }
  });

  // ── MutationObserver: handle new plots rendered while already zoomed ─────────
  function watchContainer(mode) {
    var containerId = getContainerId(mode);
    var container   = document.getElementById(containerId);
    if (!container) return;
    if (container.getAttribute('data-zoom-watch-bound') === 'true') return;
    container.setAttribute('data-zoom-watch-bound', 'true');

    var fastTimer = null;
    var settleTimer = null;
    var obs = new MutationObserver(function () {
      clearTimeout(fastTimer);
      clearTimeout(settleTimer);

      // For default 1x rendering, apply the final transcript geometry on the
      // next tick so users do not see the raw ggiraph insertion state first.
      fastTimer = setTimeout(function () {
        fastTimer = null;
        settleContainerItems(mode);
      }, 0);

      // Keep a softer fallback pass for slower Shiny/ggiraph paint bursts.
      settleTimer = setTimeout(function () {
        settleTimer = null;
        settleContainerItems(mode);
      }, 180);
    });

    obs.observe(container, { childList: true, subtree: true });
    containerObservers.push({ container: container, observer: obs });
  }

  // ── Public reset API (called by server.R when results are cleared) ──────────
  window.resetPlotZoom = function (mode) {
    if (!state[mode]) return;
    state[mode].idx = DEFAULT_IDX;
    applyZoom(mode);
  };

  window.syncQuickFabZoomControls = syncQuickFabZoomControls;

  function init() {
    var shell = document.querySelector('.app-shell');
    watchContainer('homo');
    watchContainer('ortho');
    ['homo', 'ortho'].forEach(function (m) {
      var b = document.getElementById(m + '-zoom-out');
      if (b) b.disabled = true;
    });
    scheduleFabSync();

    document.addEventListener('click', function (evt) {
      var node = evt && evt.target && evt.target.closest
        ? evt.target.closest('.app-nav-btn[data-target], #app-fab-main-toggle, #app-fab-mode-toggle, #app-fab-search-toggle, #app-fab-zoom-toggle')
        : null;
      if (!node) return;
      setTimeout(scheduleFabSync, 0);
    });

    window.addEventListener('resize', function () {
      scheduleFabSync();
      scheduleResponsiveRefit();
    }, { passive: true });
    document.addEventListener('shown.bs.tab', function () {
      scheduleFabSync();
      scheduleResponsiveRefit();
    });
    document.addEventListener('shiny:value', function () {
      scheduleFabSync();
      scheduleResponsiveRefit();
    });
    document.addEventListener('visibilitychange', function () {
      if (document.hidden) {
        containerObservers.forEach(function (entry) {
          if (entry && entry.observer) entry.observer.disconnect();
          if (entry && entry.container) entry.container.removeAttribute('data-zoom-watch-bound');
        });
        containerObservers = [];
        // Cancel any pending RAF so it doesn't linger as a stale non-null ID.
        // If we don't do this, scheduleFabSync() will see fabSyncRaf !== null
        // and silently bail every time after returning to the tab.
        if (fabSyncRaf !== null) {
          cancelAnimationFrame(fabSyncRaf);
          fabSyncRaf = null;
        }
        return;
      }
      // Tab is visible again — make sure fabSyncRaf is clean before scheduling
      if (fabSyncRaf !== null) {
        cancelAnimationFrame(fabSyncRaf);
        fabSyncRaf = null;
      }
      watchContainer('homo');
      watchContainer('ortho');
      scheduleResponsiveRefit();
      scheduleFabSync();
    });

    if (window.MutationObserver && shell) {
      var shellObserver = new MutationObserver(function (mutations) {
        for (var i = 0; i < mutations.length; i++) {
          if (mutations[i].type === 'attributes' && mutations[i].attributeName === 'class') {
            scheduleResponsiveRefit();
            scheduleFabSync();
            break;
          }
        }
      });
      shellObserver.observe(shell, { attributes: true, attributeFilter: ['class'] });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
