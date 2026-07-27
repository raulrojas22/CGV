(function () {
  'use strict';
  if (window.__genomicNeighborPopupInitialized) return;
  window.__genomicNeighborPopupInitialized = true;

  var TARGET_PREFIXES = ['genomic_ruler_neighbor|', 'genomic_ruler_overlap|'];
  var POPUP_ID = 'genomic-neighbor-popup';
  var VIEWPORT_PAD = 10;
  var GAP = 10;
  var lastPointerOpenAt = 0;
  var lastHoveredTarget = null;
  var lastHoveredAt = 0;

  function escapeHtml(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function getDataId(node) {
    if (!node || !node.getAttribute) return '';
    return String(node.getAttribute('data-id') || node.getAttribute('data_id') || '');
  }

  function isNeighborDataId(dataId) {
    var raw = String(dataId || '');
    return TARGET_PREFIXES.some(function (prefix) {
      return raw.indexOf(prefix) === 0;
    });
  }

  function findTarget(node) {
    var current = node;
    while (current && current !== document) {
      if (isNeighborDataId(getDataId(current))) return current;
      current = current.parentNode;
    }
    return null;
  }

  function findHoveredTarget(container) {
    if (!container || !container.querySelector) return null;
    var selectors = [];
    TARGET_PREFIXES.forEach(function (prefix) {
      selectors.push('[data-id^="' + prefix + '"].hover_data_id');
      selectors.push('[data_id^="' + prefix + '"].hover_data_id');
      selectors.push('[data-id^="' + prefix + '"][class*="hover"]');
      selectors.push('[data_id^="' + prefix + '"][class*="hover"]');
    });
    for (var i = 0; i < selectors.length; i += 1) {
      var found = container.querySelector(selectors[i]);
      if (found) return found;
    }
    return null;
  }

  function resolveTarget(event) {
    if (event.target && event.target.closest && event.target.closest('#' + POPUP_ID)) {
      return null;
    }
    var direct = findTarget(event.target);
    if (direct) return direct;

    var container = event.target && event.target.closest
      ? event.target.closest('.promoter-plot-container')
      : null;
    if (!container) return null;

    var hovered = findHoveredTarget(container);
    if (hovered) return hovered;
    if (lastHoveredTarget && Date.now() - lastHoveredAt <= 900 && container.contains(lastHoveredTarget)) {
      return lastHoveredTarget;
    }
    return null;
  }

  function parseMeta(dataId) {
    var raw = String(dataId || '');
    if (!isNeighborDataId(raw)) return null;
    var out = {};
    raw.split('|').slice(1).forEach(function (chunk) {
      var eqIndex = chunk.indexOf('=');
      if (eqIndex <= 0) return;
      var key = chunk.slice(0, eqIndex);
      var value = chunk.slice(eqIndex + 1);
      try {
        out[key] = decodeURIComponent(value);
      } catch (_error) {
        out[key] = value;
      }
    });
    out.kind = raw.indexOf('genomic_ruler_overlap|') === 0 ? 'overlap' : 'neighbor';
    return out;
  }

  function display(value, fallback) {
    var text = String(value == null ? '' : value).trim();
    return text && text !== 'N/A' ? text : String(fallback == null ? 'N/A' : fallback);
  }

  function ensurePopup() {
    var popup = document.getElementById(POPUP_ID);
    if (popup) return popup;

    popup = document.createElement('div');
    popup.id = POPUP_ID;
    popup.className = 'promoter-region-popup genomic-neighbor-popup';
    popup.setAttribute('role', 'dialog');
    popup.setAttribute('aria-live', 'polite');
    popup.setAttribute('aria-hidden', 'true');
    popup.innerHTML =
      '<div class="promoter-region-popup-header">' +
      '<div class="promoter-region-popup-title-wrap">' +
      '<p class="promoter-region-popup-title genomic-neighbor-popup-title">Genomic neighbor</p>' +
      '<p class="promoter-region-popup-subtitle genomic-neighbor-popup-subtitle">Select a neighboring gene</p>' +
      '</div>' +
      '<button type="button" class="promoter-region-popup-close genomic-neighbor-popup-close" aria-label="Close">&times;</button>' +
      '</div>' +
      '<div class="promoter-region-popup-body genomic-neighbor-popup-body">' +
      '<dl class="genomic-neighbor-details">' +
      '<div><dt>Relation</dt><dd data-field="relation">N/A</dd></div>' +
      '<div><dt>Coordinates</dt><dd data-field="coordinates">N/A</dd></div>' +
      '<div><dt>Strand</dt><dd data-field="strand">N/A</dd></div>' +
      '</dl>' +
      '<p class="genomic-neighbor-popup-hint">Add this gene as a new card below the current results.</p>' +
      '<button type="button" class="genomic-neighbor-visualize-btn">Visualize gene below</button>' +
      '</div>';
    document.body.appendChild(popup);
    return popup;
  }

  function setPopupMeta(popup, meta) {
    try {
      popup.setAttribute('data-neighbor-meta', JSON.stringify(meta || {}));
    } catch (_error) {
      popup.setAttribute('data-neighbor-meta', '{}');
    }
  }

  function getPopupMeta(popup) {
    try {
      return JSON.parse(popup.getAttribute('data-neighbor-meta') || '{}');
    } catch (_error) {
      return {};
    }
  }

  function setField(popup, field, value) {
    var node = popup.querySelector('[data-field="' + field + '"]');
    if (node) node.textContent = value;
  }

  function renderPopup(popup, meta) {
    var neighborName = display(meta.neighbor_name, display(meta.neighbor_id, 'Neighbor gene'));
    var sourceGene = display(meta.source_gene, 'query gene');
    var subtitle = popup.querySelector('.genomic-neighbor-popup-subtitle');
    var title = popup.querySelector('.genomic-neighbor-popup-title');
    if (title) title.textContent = meta.kind === 'overlap' ? 'Overlapping gene' : 'Neighboring gene';
    if (subtitle) subtitle.innerHTML = escapeHtml(sourceGene) + ' &rarr; <strong>' + escapeHtml(neighborName) + '</strong>';

    var relation = display(meta.detail, display(meta.relation));
    var chromosome = display(meta.chromosome, display(meta.seqid));
    var start = display(meta.start);
    var end = display(meta.end);
    setField(popup, 'relation', relation);
    setField(popup, 'coordinates', chromosome + ':' + start + '–' + end);
    setField(popup, 'strand', display(meta.strand));

    var button = popup.querySelector('.genomic-neighbor-visualize-btn');
    if (button) {
      button.textContent = 'Visualize ' + neighborName + ' below';
      button.setAttribute('aria-label', 'Visualize ' + neighborName + ' below');
    }
  }

  function positionPopup(popup, target) {
    var targetRect = target.getBoundingClientRect();
    var viewportWidth = window.innerWidth || document.documentElement.clientWidth || 1200;
    var viewportHeight = window.innerHeight || document.documentElement.clientHeight || 800;

    popup.classList.remove('place-top', 'place-bottom');
    popup.style.left = '-9999px';
    popup.style.top = '-9999px';
    popup.classList.add('open');
    popup.style.visibility = 'hidden';

    var popupWidth = popup.offsetWidth || 390;
    var popupHeight = popup.offsetHeight || 235;
    var left = targetRect.left + targetRect.width / 2 - popupWidth / 2;
    left = Math.max(VIEWPORT_PAD, Math.min(viewportWidth - popupWidth - VIEWPORT_PAD, left));

    var top = targetRect.bottom + GAP;
    if (top + popupHeight > viewportHeight - VIEWPORT_PAD) {
      top = targetRect.top - popupHeight - GAP;
      popup.classList.add('place-top');
      if (top < VIEWPORT_PAD) top = Math.max(VIEWPORT_PAD, viewportHeight - popupHeight - VIEWPORT_PAD);
    } else {
      popup.classList.add('place-bottom');
    }

    popup.style.left = Math.round(left) + 'px';
    popup.style.top = Math.round(top) + 'px';
    popup.style.visibility = 'visible';
    popup.setAttribute('aria-hidden', 'false');
  }

  function showPopup(target) {
    var meta = parseMeta(getDataId(target));
    if (!meta) return;
    var popup = ensurePopup();
    setPopupMeta(popup, meta);
    renderPopup(popup, meta);
    positionPopup(popup, target);
    var button = popup.querySelector('.genomic-neighbor-visualize-btn');
    if (button) window.setTimeout(function () { button.focus(); }, 0);
  }

  function closePopup() {
    var popup = document.getElementById(POPUP_ID);
    if (!popup) return;
    popup.classList.remove('open', 'place-top', 'place-bottom');
    popup.setAttribute('aria-hidden', 'true');
  }

  function openFromEvent(event) {
    var target = resolveTarget(event);
    if (!target) return false;
    event.preventDefault();
    event.stopPropagation();
    showPopup(target);
    return true;
  }

  document.addEventListener('pointermove', function (event) {
    var target = findTarget(event.target);
    if (!target) return;
    lastHoveredTarget = target;
    lastHoveredAt = Date.now();
  }, true);

  document.addEventListener('pointerdown', function (event) {
    if (event.target && event.target.closest && event.target.closest('#' + POPUP_ID)) return;
    if (openFromEvent(event)) lastPointerOpenAt = Date.now();
  }, true);

  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target) return;

    if (target.closest && target.closest('.genomic-neighbor-popup-close')) {
      event.preventDefault();
      event.stopPropagation();
      closePopup();
      return;
    }

    if (target.classList && target.classList.contains('genomic-neighbor-visualize-btn')) {
      event.preventDefault();
      event.stopPropagation();
      var popup = target.closest('#' + POPUP_ID);
      if (!popup) return;
      var payload = getPopupMeta(popup);
      payload.triggered_at = Date.now();
      if (window.Shiny && typeof window.Shiny.setInputValue === 'function') {
        window.Shiny.setInputValue('neighbor_gene_visualize_request', payload, { priority: 'event' });
      }
      closePopup();
      return;
    }

    if (target.closest && target.closest('#' + POPUP_ID)) return;
    if (Date.now() - lastPointerOpenAt <= 360) return;
    if (openFromEvent(event)) return;
    closePopup();
  }, true);

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape') closePopup();
  }, true);
})();
