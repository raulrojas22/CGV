(function () {
  'use strict';
  if (window.__summaryContextLayoutInitialized) return;
  window.__summaryContextLayoutInitialized = true;

  var rafId = null;
  var observer = null;
  var observedTargets = [];

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

  function measureReservedTop(pane) {
    if (!pane || !pane.style) return null;

    if (window.matchMedia && window.matchMedia('(max-width: 980px)').matches) {
      return '';
    }

    var section = pane.querySelector('.summary-context-section');
    if (!section || !isVisible(section)) {
      return '16px';
    }

    var sectionRect = section.getBoundingClientRect();
    var paneRect = pane.getBoundingClientRect();
    var reserve = Math.ceil(Math.max(16, (sectionRect.bottom - paneRect.top) + 12));
    return String(reserve) + 'px';
  }

  function updateAllPanes() {
    var panes = document.querySelectorAll('.app-main-pane-search-results');
    var measurements = [];
    for (var i = 0; i < panes.length; i += 1) {
      measurements.push({ pane: panes[i], value: measureReservedTop(panes[i]) });
    }
    for (var j = 0; j < measurements.length; j += 1) {
      if (measurements[j].value === '') {
        measurements[j].pane.style.removeProperty('--summary-context-reserved-top');
      } else if (measurements[j].value !== null) {
        measurements[j].pane.style.setProperty('--summary-context-reserved-top', measurements[j].value);
      }
    }
  }

  function scheduleUpdate() {
    if (rafId !== null) return;
    rafId = window.requestAnimationFrame(function () {
      rafId = null;
      updateAllPanes();
    });
  }

  function closeScopeDisclosures(except) {
    var openDisclosures = document.querySelectorAll('.summary-cross-species-scope[open]');
    for (var i = 0; i < openDisclosures.length; i += 1) {
      if (openDisclosures[i] !== except) {
        openDisclosures[i].removeAttribute('open');
      }
    }
  }

  function bindScopeDisclosures() {
    document.addEventListener('click', function (event) {
      var target = event && event.target ? event.target : null;
      var activeDisclosure = target && target.closest
        ? target.closest('.summary-cross-species-scope')
        : null;
      closeScopeDisclosures(activeDisclosure);
    });

    document.addEventListener('toggle', function (event) {
      var disclosure = event && event.target ? event.target : null;
      if (
        disclosure &&
        disclosure.matches &&
        disclosure.matches('.summary-cross-species-scope[open]')
      ) {
        closeScopeDisclosures(disclosure);
      }
    }, true);

    document.addEventListener('keydown', function (event) {
      if (!event || event.key !== 'Escape') return;
      var openDisclosure = document.querySelector('.summary-cross-species-scope[open]');
      if (!openDisclosure) return;
      openDisclosure.removeAttribute('open');
      var trigger = openDisclosure.querySelector('summary');
      if (trigger && trigger.focus) trigger.focus();
      event.preventDefault();
    });
  }

  function bindObservers() {
    if (observer || typeof MutationObserver !== 'function') return;

    observedTargets = [
      document.getElementById('plot-container'),
      document.getElementById('ortho-plot-container'),
      document.getElementById('homo_context_section'),
      document.getElementById('ortho_context_section')
    ].filter(function (target) {
      return !!(target && target.nodeType === 1);
    });
    if (observedTargets.length === 0) return;

    observer = new MutationObserver(function () {
      scheduleUpdate();
    });

    observedTargets.forEach(function (target) {
      try {
        observer.observe(target, {
          childList: true,
          subtree: true
        });
      } catch (err) {}
    });
  }

  function boot() {
    updateAllPanes();
    bindObservers();
    bindScopeDisclosures();

    window.addEventListener('resize', scheduleUpdate, { passive: true });
    window.addEventListener('orientationchange', scheduleUpdate, { passive: true });
    document.addEventListener('shown.bs.tab', scheduleUpdate);
    document.addEventListener('shiny:value', function (e) {
      var target = e && e.target ? e.target : null;
      if (!target || !target.closest) return;
      if (target.closest('#plot-container, #ortho-plot-container, #homo_context_section, #ortho_context_section')) scheduleUpdate();
    });

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
        observedTargets = [];
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
