(function () {
  'use strict';
  if (window.__promoterPopupInitialized) return;
  window.__promoterPopupInitialized = true;

  var TARGET_PREFIX = 'promoter_region';
  var POPUP_ID = 'promoter-region-popup';
  var VIEWPORT_PAD = 10;
  var GAP = 10;
  var IGNORE_CLICK_AFTER_POINTER_MS = 360;
  var HOVER_TARGET_TTL_MS = 900;

  var PROMOTER_MIN_BP = 100;
  var PROMOTER_MAX_BP = 5000;
  var PROMOTER_DEFAULT_BP = 1000;
  var PROMOTER_STEP_BP = 10;
  var lastPromoterBp = PROMOTER_DEFAULT_BP;

  var lastPointerOpenAt = 0;
  var lastHoverPromoterTarget = null;
  var lastHoverPromoterAt = 0;

  function txt(value) {
    return String(value == null ? '' : value);
  }

  function escapeHtml(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  var knownOrganisms = [
    'Arabidopsis thaliana',
    'Chlamydomonas reinhardtii',
    'Glycine max',
    'Hordeum vulgare',
    'Marchantia polymorpha',
    'Medicago truncatula',
    'Oryza sativa',
    'Physcomitrium patens',
    'Populus trichocarpa',
    'Setaria italica',
    'Solanum lycopersicum',
    'Sorghum bicolor',
    'Vitis vinifera',
    'Zea mays'
  ];

  function escapeAndFormatHtml(value) {
    var str = escapeHtml(value)
      .replace(/&lt;em&gt;/g, '<em>')
      .replace(/&lt;\/em&gt;/g, '</em>')
      .replace(/&lt;i&gt;/g, '<i>')
      .replace(/&lt;\/i&gt;/g, '</i>');

    knownOrganisms.forEach(function (org) {
      var escapedOrg = escapeHtml(org);
      var r = new RegExp('(' + escapedOrg + ')(?![^<]*>|[^<>]*<\/i>)', 'gi');
      str = str.replace(r, '<i>$1</i>');
    });

    return str;
  }

  function getDataId(node) {
    if (!node || !node.getAttribute) return '';
    return String(node.getAttribute('data-id') || node.getAttribute('data_id') || '');
  }

  function findPromoterTarget(node) {
    var current = node;
    while (current && current !== document) {
      var dataId = getDataId(current);
      if (dataId.indexOf(TARGET_PREFIX) === 0) {
        return current;
      }
      current = current.parentNode;
    }
    return null;
  }

  function findClosestPlotContainer(node) {
    if (!node || !node.closest) return null;
    return node.closest('.promoter-plot-container');
  }

  function findHoveredPromoterTarget(container) {
    if (!container || !container.querySelector) return null;
    var selectors = [
      '[data-id^="' + TARGET_PREFIX + '"].hover_data_id',
      '[data_id^="' + TARGET_PREFIX + '"].hover_data_id',
      '[data-id^="' + TARGET_PREFIX + '"][class*="hover"]',
      '[data_id^="' + TARGET_PREFIX + '"][class*="hover"]'
    ];
    for (var i = 0; i < selectors.length; i += 1) {
      var found = container.querySelector(selectors[i]);
      if (found) return found;
    }
    return null;
  }

  function resolvePromoterTarget(event) {
    if (event.target && event.target.closest && event.target.closest('#' + POPUP_ID)) {
      return null;
    }

    var direct = findPromoterTarget(event.target);
    if (direct) return direct;

    var container = findClosestPlotContainer(event.target);
    if (!container) return null;

    var fromSvg = event.target && event.target.closest &&
      event.target.closest('.ggiraph-container, .ggiraph-svg, .ggiraph-svg-0, svg');
    if (!fromSvg) return null;

    var hovered = findHoveredPromoterTarget(container);
    if (hovered) return hovered;

    if (lastHoverPromoterTarget && (Date.now() - lastHoverPromoterAt) <= HOVER_TARGET_TTL_MS) {
      if (container.contains(lastHoverPromoterTarget)) {
        return lastHoverPromoterTarget;
      }
    }

    return null;
  }

  function parsePromoterMeta(dataId) {
    var raw = String(dataId || '');
    if (raw.indexOf(TARGET_PREFIX) !== 0) return null;
    var out = {};
    var parts = raw.split('|');
    for (var i = 1; i < parts.length; i += 1) {
      var chunk = parts[i] || '';
      var eqIdx = chunk.indexOf('=');
      if (eqIdx <= 0) continue;
      var key = chunk.slice(0, eqIdx);
      var val = chunk.slice(eqIdx + 1);
      try {
        out[key] = decodeURIComponent(val);
      } catch (_e) {
        out[key] = val;
      }
    }
    return out;
  }

  function setPopupMeta(popup, meta) {
    if (!popup) return;
    var safeMeta = meta && typeof meta === 'object' ? meta : {};
    try {
      popup.setAttribute('data-promoter-meta', JSON.stringify(safeMeta));
    } catch (_e) {
      popup.setAttribute('data-promoter-meta', '{}');
    }
  }

  function getPopupMeta(popup) {
    if (!popup) return {};
    var raw = String(popup.getAttribute('data-promoter-meta') || '{}');
    try {
      var parsed = JSON.parse(raw);
      return parsed && typeof parsed === 'object' ? parsed : {};
    } catch (_e) {
      return {};
    }
  }

  function toDisplay(value, fallback) {
    var txtVal = String(value == null ? '' : value).trim();
    return txtVal ? txtVal : String(fallback == null ? txt('N/A') : txt(fallback));
  }

  function formatOrg(value, fallback) {
    var txtVal = String(value == null ? '' : value).trim();
    if (!txtVal || txtVal === 'N/A' || txtVal.toLowerCase() === 'organism' || txtVal.toLowerCase() === 'selected organism') {
      return txtVal ? txtVal : String(fallback == null ? 'N/A' : fallback);
    }
    return '<em>' + txtVal + '</em>';
  }

  function clampPromoterBp(value) {
    var n = Number(value);
    if (!isFinite(n)) return PROMOTER_DEFAULT_BP;
    n = Math.round(n);
    if (n < PROMOTER_MIN_BP) n = PROMOTER_MIN_BP;
    if (n > PROMOTER_MAX_BP) n = PROMOTER_MAX_BP;
    return n;
  }

  function parsePromoterBp(raw) {
    var txt = String(raw == null ? '' : raw).trim();
    if (!txt) return null;
    var clean = txt.replace(/[^\d]/g, '');
    if (!clean) return null;
    return clampPromoterBp(parseInt(clean, 10));
  }

  function ensurePopup() {
    var popup = document.getElementById(POPUP_ID);
    if (popup) return popup;

    popup = document.createElement('div');
    popup.id = POPUP_ID;
    popup.className = 'promoter-region-popup';
    popup.setAttribute('role', 'dialog');
    popup.setAttribute('aria-live', 'polite');
    popup.setAttribute('aria-hidden', 'true');
    popup.innerHTML =
      '<div class="promoter-region-popup-header">' +
      '<div class="promoter-region-popup-title-wrap">' +
      '<p class="promoter-region-popup-title">' + txt('Promoter region') + '</p>' +
      '<p class="promoter-region-popup-subtitle">' + txt('Gene') + ': ' + txt('N/A') + '</p>' +
      '</div>' +
      '<button type="button" class="promoter-region-popup-close" aria-label="Close">&times;</button>' +
      '</div>' +
      '<div class="promoter-region-popup-body">' +
      '<label class="promoter-len-label">' + txt('Promoter region length (bp)') + '</label>' +
      '<input class="promoter-len-input" type="text" inputmode="numeric" value="' + PROMOTER_DEFAULT_BP + '" />' +
      '<input class="promoter-len-slider" type="range" min="' + PROMOTER_MIN_BP + '" max="' + PROMOTER_MAX_BP + '" step="' + PROMOTER_STEP_BP + '" value="' + PROMOTER_DEFAULT_BP + '" />' +
      '<p class="promoter-len-hint">' + txt('Range') + ': ' + PROMOTER_MIN_BP + ' - ' + PROMOTER_MAX_BP + ' bp</p>' +
      '<button type="button" class="promoter-download-btn">' + txt('Download promoter region') + '</button>' +
      '</div>';
    document.body.appendChild(popup);
    return popup;
  }

  function isPopupOpen() {
    var popup = document.getElementById(POPUP_ID);
    return !!(popup && popup.classList.contains('open'));
  }

  function closePopup() {
    var popup = document.getElementById(POPUP_ID);
    if (!popup) return;
    popup.classList.remove('open');
    popup.classList.remove('place-top');
    popup.classList.remove('place-bottom');
    popup.setAttribute('aria-hidden', 'true');
  }

  function syncPromoterControls(popup, bpValue) {
    var bp = clampPromoterBp(bpValue);
    lastPromoterBp = bp;
    popup.setAttribute('data-promoter-bp', String(bp));
    var input = popup.querySelector('.promoter-len-input');
    var slider = popup.querySelector('.promoter-len-slider');
    if (input) input.value = String(bp);
    if (slider) slider.value = String(bp);
  }

  function getCurrentPromoterBp(popup) {
    if (!popup) return clampPromoterBp(lastPromoterBp);
    var input = popup.querySelector('.promoter-len-input');
    var parsedFromInput = parsePromoterBp(input ? input.value : '');
    if (parsedFromInput !== null) return parsedFromInput;
    var parsedFromAttr = parsePromoterBp(popup.getAttribute('data-promoter-bp'));
    if (parsedFromAttr !== null) return parsedFromAttr;
    return clampPromoterBp(lastPromoterBp);
  }

  function renderPopupContent(popup, meta) {
    var subtitle = txt('Gene') + ': ' + toDisplay(meta && meta.gene) +
      ' | ' + txt('Organism') + ': ' + formatOrg(meta && meta.organism, 'N/A') +
      ' | ' + txt('Chr') + ': ' + toDisplay(meta && meta.chromosome);
    var subtitleEl = popup.querySelector('.promoter-region-popup-subtitle');
    if (subtitleEl) subtitleEl.innerHTML = escapeAndFormatHtml(subtitle);
    syncPromoterControls(popup, lastPromoterBp);
  }

  function positionPopup(popup, target) {
    var targetRect = target.getBoundingClientRect();
    var vw = window.innerWidth || document.documentElement.clientWidth || 1200;
    var vh = window.innerHeight || document.documentElement.clientHeight || 800;

    popup.classList.remove('place-top');
    popup.classList.remove('place-bottom');
    popup.style.left = '-9999px';
    popup.style.top = '-9999px';
    popup.classList.add('open');
    popup.style.visibility = 'hidden';

    var popupWidth = popup.offsetWidth || 390;
    var popupHeight = popup.offsetHeight || 250;
    var left = targetRect.left + (targetRect.width / 2) - (popupWidth / 2);
    left = Math.max(VIEWPORT_PAD, Math.min(vw - popupWidth - VIEWPORT_PAD, left));

    var top = targetRect.top - popupHeight - GAP;
    if (top < VIEWPORT_PAD) {
      top = targetRect.bottom + GAP;
      popup.classList.add('place-bottom');
      if (top + popupHeight > vh - VIEWPORT_PAD) {
        top = Math.max(VIEWPORT_PAD, vh - popupHeight - VIEWPORT_PAD);
      }
    } else {
      popup.classList.add('place-top');
    }

    popup.style.left = Math.round(left) + 'px';
    popup.style.top = Math.round(top) + 'px';
    popup.style.visibility = 'visible';
    popup.setAttribute('aria-hidden', 'false');
  }

  function showPopup(target) {
    var popup = ensurePopup();
    var dataId = getDataId(target);
    var meta = parsePromoterMeta(dataId || '');
    setPopupMeta(popup, meta || {});
    renderPopupContent(popup, meta || {});
    positionPopup(popup, target);
  }

  function handlePromoterPopupOpen(event) {
    var promoterTarget = resolvePromoterTarget(event);
    if (promoterTarget) {
      event.preventDefault();
      event.stopPropagation();
      showPopup(promoterTarget);
      return true;
    }
    return false;
  }

  document.addEventListener('pointermove', function (event) {
    var promoterTarget = findPromoterTarget(event.target);
    if (promoterTarget) {
      lastHoverPromoterTarget = promoterTarget;
      lastHoverPromoterAt = Date.now();
    }
  }, true);

  document.addEventListener('pointerdown', function (event) {
    if (event.target && event.target.closest && event.target.closest('#' + POPUP_ID)) {
      return;
    }
    if (handlePromoterPopupOpen(event)) {
      lastPointerOpenAt = Date.now();
      return;
    }
  }, true);

  document.addEventListener('input', function (event) {
    var target = event.target;
    if (!target || !target.classList) return;

    if (target.classList.contains('promoter-len-slider')) {
      var popupFromSlider = target.closest('#' + POPUP_ID);
      if (!popupFromSlider) return;
      syncPromoterControls(popupFromSlider, target.value);
      event.stopPropagation();
      return;
    }

    if (target.classList.contains('promoter-len-input')) {
      var popupFromInput = target.closest('#' + POPUP_ID);
      if (!popupFromInput) return;
      var parsedInput = parsePromoterBp(target.value);
      if (parsedInput !== null) {
        lastPromoterBp = parsedInput;
        popupFromInput.setAttribute('data-promoter-bp', String(parsedInput));
        var sliderFromInput = popupFromInput.querySelector('.promoter-len-slider');
        if (sliderFromInput) sliderFromInput.value = String(parsedInput);
      }
      event.stopPropagation();
    }
  }, true);

  document.addEventListener('change', function (event) {
    var target = event.target;
    if (!target || !target.classList || !target.classList.contains('promoter-len-input')) return;
    var popup = target.closest('#' + POPUP_ID);
    if (!popup) return;
    var parsed = parsePromoterBp(target.value);
    syncPromoterControls(popup, parsed === null ? PROMOTER_DEFAULT_BP : parsed);
    event.stopPropagation();
  }, true);

  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target) return;

    if (target.closest && target.closest('.promoter-region-popup-close')) {
      event.preventDefault();
      event.stopPropagation();
      closePopup();
      return;
    }

    if (target.classList && target.classList.contains('promoter-download-btn')) {
      event.preventDefault();
      event.stopPropagation();
      var popupForDownload = target.closest('#' + POPUP_ID);
      if (!popupForDownload) return;
      var payload = getPopupMeta(popupForDownload);
      payload = payload && typeof payload === 'object' ? payload : {};
      var bpForDownload = getCurrentPromoterBp(popupForDownload);
      syncPromoterControls(popupForDownload, bpForDownload);
      payload.bp = bpForDownload;
      payload.triggered_at = Date.now();
      if (window.Shiny && typeof window.Shiny.setInputValue === 'function') {
        window.Shiny.setInputValue('promoter_region_download_request', payload, { priority: 'event' });
      }
      return;
    }

    if (target.closest && target.closest('#' + POPUP_ID)) {
      return;
    }

    if ((Date.now() - lastPointerOpenAt) <= IGNORE_CLICK_AFTER_POINTER_MS) {
      return;
    }

    if (handlePromoterPopupOpen(event)) {
      return;
    }

    closePopup();
  }, true);

  function registerDownloadMessageHandler() {
    if (window.__promoterRegionDownloadHandlerRegistered) return;
    if (!window.Shiny || typeof window.Shiny.addCustomMessageHandler !== 'function') {
      window.setTimeout(registerDownloadMessageHandler, 120);
      return;
    }
    window.__promoterRegionDownloadHandlerRegistered = true;
    window.Shiny.addCustomMessageHandler('download_promoter_region_fasta', function (message) {
      if (!message) return;
      var content = String(message.content || '');
      if (!content) return;
      var filename = String(message.filename || 'promoter_region.fasta');
      var blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
      var url = URL.createObjectURL(blob);
      var anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = filename;
      document.body.appendChild(anchor);
      anchor.click();
      document.body.removeChild(anchor);
      URL.revokeObjectURL(url);
    });
  }

  registerDownloadMessageHandler();

})();
