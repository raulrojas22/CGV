(function () {
  'use strict';
  if (window.__summaryContextLayoutInitialized) return;
  window.__summaryContextLayoutInitialized = true;

  var rafId = null;
  var observer = null;

  function isVisible(el) {
    if (!el) return false;
    if (el.hidden) return false;
    var style;
    try {
      style = window.getComputedStyle(el);
    } catch (err) {
      return true;
    }
    if (!style) return true;
    return style.display !== 'none' && style.visibility !== 'hidden' && style.opacity !== '0';
  }

  function computeReservedTop(pane) {
    if (!pane || !pane.style) return;

    if (window.matchMedia && window.matchMedia('(max-width: 980px)').matches) {
      pane.style.removeProperty('--summary-context-reserved-top');
      return;
    }

    var section = pane.querySelector('.summary-context-section');
    if (!section || !isVisible(section)) {
      pane.style.setProperty('--summary-context-reserved-top', '16px');
      return;
    }

    var sectionRect = section.getBoundingClientRect();
    var paneRect = pane.getBoundingClientRect();
    var reserve = Math.ceil(Math.max(16, (sectionRect.bottom - paneRect.top) + 12));
    pane.style.setProperty('--summary-context-reserved-top', String(reserve) + 'px');
  }

  function updateAllPanes() {
    var panes = document.querySelectorAll('.app-main-pane-search-results');
    for (var i = 0; i < panes.length; i += 1) {
      computeReservedTop(panes[i]);
    }
  }

  function scheduleUpdate() {
    if (rafId !== null) return;
    rafId = window.requestAnimationFrame(function () {
      rafId = null;
      updateAllPanes();
    });
  }

  function bindObservers() {
    if (observer || typeof MutationObserver !== 'function' || !document.body) return;

    observer = new MutationObserver(function () {
      scheduleUpdate();
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  function boot() {
    updateAllPanes();
    bindObservers();

    window.addEventListener('resize', scheduleUpdate, { passive: true });
    window.addEventListener('orientationchange', scheduleUpdate, { passive: true });
    document.addEventListener('shown.bs.tab', scheduleUpdate);
    document.addEventListener('shiny:value', scheduleUpdate);

    // Extra passes after Shiny/UI paint bursts.
    window.setTimeout(scheduleUpdate, 0);
    window.setTimeout(scheduleUpdate, 120);
    window.setTimeout(scheduleUpdate, 300);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot, { once: true });
  } else {
    boot();
  }

  document.addEventListener('visibilitychange', function () {
    if (document.hidden) {
      if (observer) {
        observer.disconnect();
        observer = null;
      }
      if (rafId !== null) {
        cancelAnimationFrame(rafId);
        rafId = null;
      }
      return;
    }
    bindObservers();
    scheduleUpdate();
  });
})();
