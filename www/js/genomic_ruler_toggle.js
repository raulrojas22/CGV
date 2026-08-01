(function () {
  'use strict';

  if (window.__cgvGenomicRulerToggleInitialized) return;
  window.__cgvGenomicRulerToggleInitialized = true;

  var STORAGE_KEY = 'cgv.genomicRulerVisible';
  var CONTEXT_STORAGE_KEY = 'cgv.genomicContextVisible';
  var scheduled = false;
  var rulerVisible = true;
  var contextVisible = {
    neighbors: true,
    overlaps: true
  };

  try {
    var stored = window.sessionStorage.getItem(STORAGE_KEY);
    if (stored === 'false') rulerVisible = false;
  } catch (err) {}

  try {
    var storedContext = JSON.parse(
      window.sessionStorage.getItem(CONTEXT_STORAGE_KEY) || '{}'
    );
    if (typeof storedContext.neighbors === 'boolean') {
      contextVisible.neighbors = storedContext.neighbors;
    }
    if (typeof storedContext.overlaps === 'boolean') {
      contextVisible.overlaps = storedContext.overlaps;
    }
  } catch (err) {}

  function persistContextVisible() {
    try {
      window.sessionStorage.setItem(
        CONTEXT_STORAGE_KEY,
        JSON.stringify(contextVisible)
      );
    } catch (err) {}
  }

  var NODE_SELECTORS = {
    ruler: [
      '.promoter-plot-container svg [data-id="genomic_ruler_line"]',
      '.promoter-plot-container svg [data-id^="genomic_ruler_tick_"]',
      '.promoter-plot-container svg [data-id^="genomic_ruler_label_"]',
      '.promoter-plot-container svg [data-id^="genomic_ruler_context_"]'
    ].join(','),
    neighbors: [
      '.promoter-plot-container svg [data-id^="genomic_ruler_neighbor|"]',
      '.promoter-plot-container svg [data-id^="genomic_ruler_lower_context_"]'
    ].join(','),
    overlaps: [
      '.promoter-plot-container svg [data-id^="genomic_ruler_overlap|"]',
      '.promoter-plot-container svg [data-id="genomic_ruler_overlap_summary"]'
    ].join(',')
  };

  function nodesFor(kind, root) {
    var scope = root && root.querySelectorAll ? root : document;
    return scope.querySelectorAll(NODE_SELECTORS[kind] || '');
  }

  function applyNodeVisibility(kind, visible, root) {
    var nodes = nodesFor(kind, root);
    for (var i = 0; i < nodes.length; i += 1) {
      if (visible) {
        nodes[i].style.removeProperty('display');
        nodes[i].removeAttribute('aria-hidden');
      } else {
        nodes[i].style.setProperty('display', 'none');
        nodes[i].setAttribute('aria-hidden', 'true');
      }
    }
  }

  function syncRulerButtons() {
    var buttons = document.querySelectorAll('[data-genomic-ruler-toggle="true"]');
    for (var i = 0; i < buttons.length; i += 1) {
      buttons[i].classList.toggle('is-active', rulerVisible);
      buttons[i].setAttribute('aria-pressed', rulerVisible ? 'true' : 'false');
      buttons[i].setAttribute(
        'aria-label',
        rulerVisible ? 'Hide genomic context scale' : 'Show genomic context scale'
      );
      buttons[i].title = rulerVisible
        ? 'Hide genomic coordinates and compressed distance scale'
        : 'Show genomic coordinates and compressed distance scale';
    }
  }

  function contextCopy(kind) {
    return kind === 'overlaps' ? 'overlapping genes' : 'neighboring genes';
  }

  function contextShortCopy(kind) {
    return kind === 'overlaps' ? 'overlaps' : 'neighbors';
  }

  function syncContextButtons() {
    var buttons = document.querySelectorAll('[data-genomic-context-toggle]');
    for (var i = 0; i < buttons.length; i += 1) {
      var kind = String(buttons[i].getAttribute('data-genomic-context-toggle') || '');
      if (!Object.prototype.hasOwnProperty.call(contextVisible, kind)) continue;
      var active = !!contextVisible[kind];
      var copy = contextCopy(kind);
      buttons[i].classList.toggle('is-active', active);
      buttons[i].setAttribute('aria-pressed', active ? 'true' : 'false');
      buttons[i].setAttribute('aria-label', (active ? 'Hide ' : 'Show ') + copy);
      buttons[i].title = (active ? 'Hide ' : 'Show ') + copy + ' on gene cards';
      var label = buttons[i].querySelector('.summary-genomic-context-toggle-label');
      if (label) {
        label.textContent = (active ? 'Hide ' : 'Show ') + contextShortCopy(kind);
      }
    }
  }

  function applyState(root) {
    document.documentElement.setAttribute(
      'data-genomic-ruler-visible',
      rulerVisible ? 'true' : 'false'
    );
    document.documentElement.setAttribute(
      'data-genomic-neighbors-visible',
      contextVisible.neighbors ? 'true' : 'false'
    );
    document.documentElement.setAttribute(
      'data-genomic-overlaps-visible',
      contextVisible.overlaps ? 'true' : 'false'
    );
    applyNodeVisibility('ruler', rulerVisible, root || document);
    applyNodeVisibility('neighbors', contextVisible.neighbors, root || document);
    applyNodeVisibility('overlaps', contextVisible.overlaps, root || document);
    syncRulerButtons();
    syncContextButtons();
  }

  function scheduleApply() {
    if (scheduled) return;
    scheduled = true;
    window.requestAnimationFrame(function () {
      scheduled = false;
      applyState(document);
    });
  }

  function setRulerVisible(nextVisible) {
    rulerVisible = !!nextVisible;
    try {
      window.sessionStorage.setItem(STORAGE_KEY, rulerVisible ? 'true' : 'false');
    } catch (err) {}
    applyState(document);
    return rulerVisible;
  }

  function setContextVisible(kind, nextVisible) {
    var key = String(kind || '').toLowerCase();
    if (!Object.prototype.hasOwnProperty.call(contextVisible, key)) return false;
    contextVisible[key] = !!nextVisible;
    persistContextVisible();
    applyState(document);
    return contextVisible[key];
  }

  window.cgvSetGenomicRulerVisible = setRulerVisible;
  window.cgvToggleGenomicRuler = function () {
    return setRulerVisible(!rulerVisible);
  };
  window.cgvIsGenomicRulerVisible = function () {
    return rulerVisible;
  };
  window.cgvSetGenomicContextVisible = setContextVisible;
  window.cgvIsGenomicContextVisible = function (kind) {
    var key = String(kind || '').toLowerCase();
    return !!contextVisible[key];
  };

  document.addEventListener('click', function (event) {
    var rulerButton = event.target && event.target.closest
      ? event.target.closest('[data-genomic-ruler-toggle="true"]')
      : null;
    if (rulerButton) {
      event.preventDefault();
      setRulerVisible(!rulerVisible);
      return;
    }

    var contextButton = event.target && event.target.closest
      ? event.target.closest('[data-genomic-context-toggle]')
      : null;
    if (!contextButton) return;
    var kind = String(contextButton.getAttribute('data-genomic-context-toggle') || '');
    if (!Object.prototype.hasOwnProperty.call(contextVisible, kind)) return;
    event.preventDefault();
    setContextVisible(kind, !contextVisible[kind]);
  });

  if (window.MutationObserver) {
    var observer = new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i += 1) {
        if (mutations[i].addedNodes && mutations[i].addedNodes.length > 0) {
          scheduleApply();
          return;
        }
      }
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', scheduleApply, { once: true });
  } else {
    scheduleApply();
  }
})();
