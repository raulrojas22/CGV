/**
 * Mobile Enhancements for CGV App
 * All mobile-specific JavaScript behaviour.
 * Every listener/observer is gated behind matchMedia or touch detection
 * so desktop is completely unaffected.
 */
(function () {
  'use strict';
  if (window.__mobileEnhancementsInit) return;
  window.__mobileEnhancementsInit = true;

  var MOBILE_BP = '(max-width: 960px)';
  var PHONE_BP  = '(max-width: 576px)';
  var isTouchDevice = ('ontouchstart' in window) || (navigator.maxTouchPoints > 0);
  var mobileMediaQuery = window.matchMedia(MOBILE_BP);

  function isMobile()  { return mobileMediaQuery.matches; }
  function isPhone()   { return window.matchMedia(PHONE_BP).matches; }

  // ═══════════════════════════════════════════════════════════════════════════
  // Phase 2A — Bottom-sheet scrim for popups on phones
  // ═══════════════════════════════════════════════════════════════════════════
  var scrimEl = null;

  function ensureScrim() {
    if (scrimEl) return scrimEl;
    scrimEl = document.createElement('div');
    scrimEl.className = 'mobile-popup-scrim';
    scrimEl.style.cssText =
      'display:none;position:fixed;inset:0;z-index:12139;' +
      'background:rgba(0,0,0,0.35);transition:opacity .2s ease;opacity:0;';
    scrimEl.addEventListener('click', closeAllPopups);
    document.body.appendChild(scrimEl);
    return scrimEl;
  }

  function showScrim() {
    if (!isPhone()) return;
    var s = ensureScrim();
    s.style.display = 'block';
    requestAnimationFrame(function () { s.style.opacity = '1'; });
  }

  function hideScrim() {
    if (!scrimEl) return;
    scrimEl.style.opacity = '0';
    setTimeout(function () { scrimEl.style.display = 'none'; }, 220);
  }

  function closeAllPopups() {
    var popups = document.querySelectorAll(
      '.go-terms-popup.open, .assembly-info-popup.open, .metrics-popup.open'
    );
    for (var i = 0; i < popups.length; i++) {
      popups[i].classList.remove('open');
    }
    hideScrim();
  }

  // Watch for popup open/close to manage scrim
  var popupObserver = new MutationObserver(function (mutations) {
    if (!isPhone()) return;
    for (var i = 0; i < mutations.length; i++) {
      var m = mutations[i];
      if (m.type !== 'attributes' || m.attributeName !== 'class') continue;
      var el = m.target;
      if (!el.classList) continue;
      var isPopup = el.classList.contains('go-terms-popup') ||
                    el.classList.contains('assembly-info-popup') ||
                    el.classList.contains('metrics-popup');
      if (!isPopup) continue;

      if (el.classList.contains('open')) {
        showScrim();
      } else {
        // Check if any popup is still open
        var anyOpen = document.querySelector(
          '.go-terms-popup.open, .assembly-info-popup.open, .metrics-popup.open'
        );
        if (!anyOpen) hideScrim();
      }
    }
  });

  // Start observing popup elements once they exist
  function observePopups() {
    var selectors = ['.go-terms-popup', '.assembly-info-popup', '.metrics-popup'];
    for (var i = 0; i < selectors.length; i++) {
      var el = document.querySelector(selectors[i]);
      if (el) {
        popupObserver.observe(el, { attributes: true, attributeFilter: ['class'] });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Phase 3A — Mobile context bar: sync with summary-context-card
  // ═══════════════════════════════════════════════════════════════════════════
  function syncContextBar() {
    if (!isMobile()) return;
    var bar = document.querySelector('.mobile-context-bar');
    if (!bar) return;

    var geneEl = bar.querySelector('.mobile-ctx-gene');
    var workflowEl = bar.querySelector('.mobile-ctx-workflow');
    if (!geneEl || !workflowEl) return;

    // Try to read from the summary context card
    var contextCard = document.querySelector('.summary-context-card');
    if (contextCard) {
      var geneText = '';
      var workflowText = '';

      // Look for gene name in context card
      var geneNode = contextCard.querySelector('.summary-gene-name, .context-gene, [data-gene]');
      if (geneNode) geneText = geneNode.textContent.trim();

      // Look for workflow/organism info
      var workflowNode = contextCard.querySelector('.summary-workflow, .context-workflow, .summary-organism');
      if (workflowNode) workflowText = workflowNode.textContent.trim();

      // Fallback: read the whole card text if specific elements not found
      if (!geneText && !workflowText) {
        var fullText = contextCard.textContent.trim();
        if (fullText.length > 0 && fullText.length < 100) {
          geneText = fullText;
        }
      }

      geneEl.textContent = geneText;
      workflowEl.textContent = workflowText;
    }

    // Also check the active tab to show workflow type
    var activeTabValue = '';
    var activeTab = document.querySelector('#navtabs .tab-pane.active, #navtabs .tab-pane.show');
    if (activeTab && !workflowEl.textContent) {
      var tabValue = activeTab.getAttribute('data-value') || '';
      activeTabValue = tabValue;
      var labels = {
        'home': 'Home',
        'homologous': 'Homologous Search',
        'orthologous': 'Cross-Species Search',
        'settings': 'Settings',
        'help': 'Help',
        'feedback': 'Feedback'
      };
      workflowEl.textContent = labels[tabValue] || '';
    } else if (activeTab) {
      activeTabValue = activeTab.getAttribute('data-value') || '';
    }

    var hasGene = !!String(geneEl.textContent || '').trim();
    var hasWorkflow = !!String(workflowEl.textContent || '').trim();
    var shouldHide = (!hasGene && !hasWorkflow) || activeTabValue === 'home';
    bar.style.display = shouldHide ? 'none' : 'flex';
  }

  // Observe DOM changes to keep context bar updated
  var contextObserver = new MutationObserver(function () {
    syncContextBar();
  });
  var contextObserverTarget = null;

  function syncContextObserverState() {
    if (!isMobile()) {
      contextObserver.disconnect();
      contextObserverTarget = null;
      return;
    }
    var target = document.querySelector('.app-main');
    if (!target || target === contextObserverTarget) return;
    contextObserver.disconnect();
    contextObserver.observe(target, { childList: true, subtree: true, characterData: true });
    contextObserverTarget = target;
    syncContextBar();
  }

  if (mobileMediaQuery.addEventListener) {
    mobileMediaQuery.addEventListener('change', syncContextObserverState);
  } else if (mobileMediaQuery.addListener) {
    mobileMediaQuery.addListener(syncContextObserverState);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Phase 3B — Auto-close sidebar when selecting a workflow on mobile
  // ═══════════════════════════════════════════════════════════════════════════
  // Auto-close sidebar ONLY for non-workflow nav buttons (Home, Settings, Help, Feedback).
  // Workflow buttons (Multi-Gene Search, Cross-Species) need the sidebar to stay open
  // so the inline search panel can be displayed.
  // NOTE: The original ui.R code (line ~3334) already handles auto-close for non-workflow
  // tabs, so this listener is intentionally removed to avoid double-firing.
  // The existing code in ui.R already does:
  //   if (matchMedia('(max-width: 960px)').matches && !isWorkflow) toggleMobileNav();

  // ═══════════════════════════════════════════════════════════════════════════
  // Phase 4A — Pinch-to-zoom on plot containers (touch devices only)
  // ═══════════════════════════════════════════════════════════════════════════
  if (isTouchDevice) {
    var ZOOM_LEVELS = [1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0];

    function getDistance(t1, t2) {
      var dx = t1.clientX - t2.clientX;
      var dy = t1.clientY - t2.clientY;
      return Math.sqrt(dx * dx + dy * dy);
    }

    function closestLevelIdx(factor) {
      var best = 0;
      var bestDist = Math.abs(ZOOM_LEVELS[0] - factor);
      for (var i = 1; i < ZOOM_LEVELS.length; i++) {
        var d = Math.abs(ZOOM_LEVELS[i] - factor);
        if (d < bestDist) { bestDist = d; best = i; }
      }
      return best;
    }

    function findPlotMode(el) {
      var container = el.closest('#plot-container');
      if (container) return 'homo';
      container = el.closest('#ortho-plot-container');
      if (container) return 'ortho';
      return null;
    }

    var pinchState = { active: false, startDist: 0, startIdx: 0, mode: null };

    document.addEventListener('touchstart', function (e) {
      if (e.touches.length !== 2) return;
      var plotMain = e.target.closest ? e.target.closest('.plot-card-main') : null;
      if (!plotMain) return;

      var mode = findPlotMode(plotMain);
      if (!mode) return;

      // Read current zoom index from plot_zoom state if available
      var currentIdx = 0;
      if (window.__plotZoomInitialized) {
        var label = document.getElementById(mode + '-zoom-label');
        if (label) {
          var text = label.textContent.replace('\u00d7', '');
          var val = parseFloat(text);
          if (val > 0) currentIdx = closestLevelIdx(val);
        }
      }

      pinchState.active = true;
      pinchState.startDist = getDistance(e.touches[0], e.touches[1]);
      pinchState.startIdx = currentIdx;
      pinchState.mode = mode;
    }, { passive: true });

    document.addEventListener('touchmove', function (e) {
      if (!pinchState.active || e.touches.length !== 2) return;
      // We don't preventDefault here to avoid blocking scroll
      // The zoom is applied on touchend for better UX
    }, { passive: true });

    document.addEventListener('touchend', function (e) {
      if (!pinchState.active) return;
      // When one finger lifts, calculate final zoom
      if (e.touches.length <= 1 && e.changedTouches.length >= 1) {
        var remaining = e.touches.length === 1 ? e.touches[0] : null;
        var changed = e.changedTouches[0];

        // Reconstruct final 2-finger distance using the last changed touch
        if (remaining && changed) {
          var endDist = getDistance(remaining, changed);
          var ratio = endDist / pinchState.startDist;
          var newFactor = ZOOM_LEVELS[pinchState.startIdx] * ratio;
          var newIdx = closestLevelIdx(newFactor);

          if (newIdx !== pinchState.startIdx) {
            // Trigger zoom via the existing plot_zoom click handler
            var action = newIdx > pinchState.startIdx ? 'in' : 'out';
            var steps = Math.abs(newIdx - pinchState.startIdx);
            var btn = document.querySelector(
              '[data-zoom-action="' + action + '"][data-zoom-mode="' + pinchState.mode + '"]'
            );
            if (btn) {
              for (var s = 0; s < steps; s++) btn.click();
            }
          }
        }
        pinchState.active = false;
      }
    }, { passive: true });

    // ═══════════════════════════════════════════════════════════════════════
    // Phase 4B — Tap-to-show tooltips on ggiraph elements (touch)
    // ═══════════════════════════════════════════════════════════════════════
    var activeTooltipEl = null;

    document.addEventListener('touchstart', function (e) {
      if (e.touches.length !== 1) return;
      var target = e.target;

      // Check if tapping inside a ggiraph SVG element with data-id
      var dataEl = null;
      if (target.closest) {
        dataEl = target.closest('[data-id]');
      }
      var inGgiraph = target.closest && target.closest('.girafe_container_std, .ggiraph-container');

      if (dataEl && inGgiraph) {
        // Simulate mouseover to trigger ggiraph tooltip
        if (activeTooltipEl === dataEl) {
          // Second tap: dismiss
          var outEvt = new MouseEvent('mouseout', { bubbles: true, cancelable: true });
          dataEl.dispatchEvent(outEvt);
          activeTooltipEl = null;
        } else {
          // First tap: show tooltip
          if (activeTooltipEl) {
            var prevOut = new MouseEvent('mouseout', { bubbles: true, cancelable: true });
            activeTooltipEl.dispatchEvent(prevOut);
          }
          var overEvt = new MouseEvent('mouseover', { bubbles: true, cancelable: true });
          dataEl.dispatchEvent(overEvt);
          activeTooltipEl = dataEl;
        }
      } else if (activeTooltipEl) {
        // Tap outside: dismiss active tooltip
        var dismissEvt = new MouseEvent('mouseout', { bubbles: true, cancelable: true });
        activeTooltipEl.dispatchEvent(dismissEvt);
        activeTooltipEl = null;
      }
    }, { passive: true });

    // ═══════════════════════════════════════════════════════════════════════
    // Phase 4C — Double-tap to reset zoom
    // ═══════════════════════════════════════════════════════════════════════
    var lastTapTime = 0;
    var lastTapTarget = null;
    var DOUBLE_TAP_THRESHOLD = 300;

    document.addEventListener('touchend', function (e) {
      if (e.touches.length !== 0) return;
      var plotMain = e.target.closest ? e.target.closest('.plot-card-main') : null;
      if (!plotMain) { lastTapTime = 0; return; }

      var now = Date.now();
      if (lastTapTarget === plotMain && (now - lastTapTime) < DOUBLE_TAP_THRESHOLD) {
        // Double tap detected — reset zoom
        var mode = findPlotMode(plotMain);
        if (mode) {
          var resetBtn = document.querySelector(
            '[data-zoom-action="reset"][data-zoom-mode="' + mode + '"]'
          );
          if (resetBtn) resetBtn.click();
        }
        lastTapTime = 0;
        lastTapTarget = null;
      } else {
        lastTapTime = now;
        lastTapTarget = plotMain;
      }
    }, { passive: true });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Initialization
  // ═══════════════════════════════════════════════════════════════════════════
  function init() {
    observePopups();
    syncContextBar();
    syncContextObserverState();

    // Re-observe popups after Shiny renders new content
    if (window.Shiny) {
      $(document).on('shiny:value', function () {
        setTimeout(observePopups, 500);
        if (isMobile()) setTimeout(syncContextBar, 500);
      });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Also re-init after a short delay to catch late-rendered Shiny elements
  setTimeout(function () {
    observePopups();
    syncContextBar();
  }, 2000);

})();
