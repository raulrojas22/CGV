(function () {
  'use strict';
  if (window.__metricsPopupInitialized) return;
  window.__metricsPopupInitialized = true;

  var POPUP_ID = 'metrics-popup';
  var VIEWPORT_PAD = 10;
  var GAP = 10;
  var activeAnchor = null;

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

  function toDisplay(value, fallback) {
    var raw = String(value == null ? '' : value).trim();
    return raw ? raw : String(fallback == null ? txt('N/A') : fallback);
  }

  function formatOrg(value, fallback) {
    var txtVal = String(value == null ? '' : value).trim();
    if (!txtVal || txtVal === 'N/A' || txtVal.toLowerCase() === 'organism' || txtVal.toLowerCase() === 'selected organism') {
      return txtVal ? txtVal : String(fallback == null ? 'N/A' : fallback);
    }
    return '<em>' + txtVal + '</em>';
  }

  function getPopup() {
    return document.getElementById(POPUP_ID);
  }

  function isPopupOpen() {
    var popup = getPopup();
    return !!(popup && popup.classList.contains('open'));
  }

  function ensurePopup() {
    var popup = getPopup();
    if (popup) return popup;

    popup = document.createElement('div');
    popup.id = POPUP_ID;
    popup.className = 'metrics-popup';
    popup.setAttribute('role', 'dialog');
    popup.setAttribute('aria-live', 'polite');
    popup.setAttribute('aria-hidden', 'true');
    popup.innerHTML =
      '<div class="metrics-popup-header">' +
      '<div class="metrics-popup-title-wrap">' +
      '<p class="metrics-popup-title">' + txt('Transcript info') + '</p>' +
      '<p class="metrics-popup-subtitle">' + txt('Gene') + ': ' + txt('N/A') + ' | ' + txt('Transcript') + ': ' + txt('N/A') + ' | ' + txt('Organism') + ': ' + txt('N/A') + ' | ' + txt('Chr') + ': ' + txt('N/A') + '</p>' +
      '</div>' +
      '<button type="button" class="metrics-popup-close" aria-label="Close">&times;</button>' +
      '</div>' +
      '<div class="metrics-popup-body">' +
      '<div class="metrics-popup-sections"></div>' +
      '<p class="metrics-popup-note"></p>' +
      '</div>';

    document.body.appendChild(popup);
    return popup;
  }

  function applyPopupVariant(popup, variant) {
    if (!popup) return;
    var nextVariant = String(variant == null ? '' : variant).trim().toLowerCase();
    popup.classList.toggle('metrics-popup--transcript', nextVariant === 'transcript');
  }

  function closePopup() {
    var popup = getPopup();
    if (!popup) return;
    popup.classList.remove('open', 'place-top', 'place-bottom');
    popup.setAttribute('aria-hidden', 'true');
    activeAnchor = null;
  }

  function parsePayload(button) {
    if (!button) return null;
    var raw = String(button.getAttribute('data-metrics-payload') || '').trim();
    if (!raw) return null;

    var decoded = '';
    try {
      decoded = decodeURIComponent(raw);
    } catch (_e) {
      decoded = raw;
    }

    try {
      var parsed = JSON.parse(decoded);
      if (parsed && typeof parsed === 'object') {
        return parsed;
      }
    } catch (_e2) {
      return null;
    }

    return null;
  }

  function renderRows(rows) {
    if (!Array.isArray(rows) || rows.length === 0) {
      return '<div class="metrics-popup-empty">' + escapeHtml(txt('No metrics available.')) + '</div>';
    }

    var out = '';
    for (var i = 0; i < rows.length; i += 1) {
      var row = rows[i] || {};
      var label = toDisplay(row.label, txt('Metric'));
      var value = toDisplay(row.value, 'N/A');
      out += '<div class="metrics-popup-row">';
      out += '<span class="metrics-popup-row-label">' + escapeHtml(label) + '</span>';
      out += '<span class="metrics-popup-row-value">' + escapeHtml(value) + '</span>';
      out += '</div>';
    }
    return out;
  }

  function renderSections(sections) {
    if (!Array.isArray(sections) || sections.length === 0) {
      return '<div class="metrics-popup-empty">' + escapeHtml(txt('No metrics available for this transcript.')) + '</div>';
    }

    var out = '';
    for (var i = 0; i < sections.length; i += 1) {
      var sec = sections[i] || {};
      var title = toDisplay(sec.title, txt('Section'));
      out += '<section class="metrics-popup-section">';
      out += '<div class="metrics-popup-section-head">' + escapeHtml(title) + '</div>';
      out += renderRows(sec.rows);
      out += '</section>';
    }
    return out;
  }

  function renderPayload(payload) {
    var popup = ensurePopup();
    var p = payload && typeof payload === 'object' ? payload : {};

    var titleEl = popup.querySelector('.metrics-popup-title');
    var subtitleEl = popup.querySelector('.metrics-popup-subtitle');
    var sectionsEl = popup.querySelector('.metrics-popup-sections');
    var noteEl = popup.querySelector('.metrics-popup-note');

    if (titleEl) {
      titleEl.textContent = toDisplay(p.title, txt('Transcript info'));
    }
    if (subtitleEl) {
      subtitleEl.innerHTML = escapeAndFormatHtml(toDisplay(p.subtitle, txt('Gene') + ': ' + txt('N/A') + ' | ' + txt('Transcript') + ': ' + txt('N/A') + ' | ' + txt('Organism') + ': ' + txt('N/A') + ' | ' + txt('Chr') + ': ' + txt('N/A')));
    }
    if (sectionsEl) {
      sectionsEl.innerHTML = renderSections(p.sections);
    }
    if (noteEl) {
      var noteText = String(p.note || '').trim();
      noteEl.textContent = noteText;
      noteEl.style.display = noteText ? 'block' : 'none';
    }
    applyPopupVariant(popup, p.panel_variant);
  }

  function positionPopup(popup, target) {
    if (!popup || !target) return;

    var rect = target.getBoundingClientRect();
    var vw = window.innerWidth || document.documentElement.clientWidth || 1200;
    var vh = window.innerHeight || document.documentElement.clientHeight || 800;

    popup.classList.remove('place-top', 'place-bottom');
    popup.style.left = '-9999px';
    popup.style.top = '-9999px';
    popup.classList.add('open');
    popup.style.visibility = 'hidden';

    var w = popup.offsetWidth || 460;
    var h = popup.offsetHeight || 360;

    var left = rect.left + (rect.width / 2) - (w / 2);
    left = Math.max(VIEWPORT_PAD, Math.min(vw - w - VIEWPORT_PAD, left));

    var top = rect.top - h - GAP;
    if (top < VIEWPORT_PAD) {
      top = rect.bottom + GAP;
      popup.classList.add('place-bottom');
      if (top + h > vh - VIEWPORT_PAD) {
        top = Math.max(VIEWPORT_PAD, vh - h - VIEWPORT_PAD);
      }
    } else {
      popup.classList.add('place-top');
    }

    popup.style.left = Math.round(left) + 'px';
    popup.style.top = Math.round(top) + 'px';
    popup.style.visibility = 'visible';
    popup.setAttribute('aria-hidden', 'false');
  }

  function openFromButton(button) {
    if (!button) return;

    var payload = parsePayload(button);
    if (!payload) {
      return;
    }

    var popup = ensurePopup();
    activeAnchor = button;
    renderPayload(payload);
    if (!payload || !payload.panel_variant) {
      applyPopupVariant(popup, button.getAttribute('data-panel-variant'));
    }
    positionPopup(popup, button);
  }

  function repositionIfOpen() {
    if (!isPopupOpen() || !activeAnchor || !document.body.contains(activeAnchor)) {
      return;
    }
    var popup = getPopup();
    if (!popup) return;
    positionPopup(popup, activeAnchor);
  }

  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target) return;

    var infoBtn = target.closest ? target.closest('.footer-info-btn, .metrics-info-btn') : null;
    if (infoBtn) {
      event.preventDefault();
      event.stopPropagation();
      openFromButton(infoBtn);
      return;
    }

    if (target.closest && target.closest('.metrics-popup-close')) {
      event.preventDefault();
      event.stopPropagation();
      closePopup();
      return;
    }

    if (target.closest && target.closest('#' + POPUP_ID)) {
      return;
    }

    if (isPopupOpen()) {
      closePopup();
    }
  }, true);

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && isPopupOpen()) {
      closePopup();
    }
  }, true);

  window.addEventListener('resize', repositionIfOpen, { passive: true });
  window.addEventListener('scroll', repositionIfOpen, { passive: true, capture: true });

  // Attach scroll listeners to all main panes (for inner scrolling)
  var mainPanes = document.querySelectorAll('.app-main-pane');
  mainPanes.forEach(function (pane) {
    pane.addEventListener('scroll', repositionIfOpen, { passive: true, capture: true });
  });

  var paneObserver = new MutationObserver(function (mutations) {
    var newPanes = document.querySelectorAll('.app-main-pane:not([data-popup-scroll-bound="metrics"])');
    if (newPanes.length > 0) {
      newPanes.forEach(function (pane) {
        pane.setAttribute('data-popup-scroll-bound', 'metrics');
        pane.addEventListener('scroll', repositionIfOpen, { passive: true, capture: true });
      });
    }
  });
  if (document.body) {
    paneObserver.observe(document.body, { childList: true, subtree: true });
  } else {
    document.addEventListener('DOMContentLoaded', function () {
      paneObserver.observe(document.body, { childList: true, subtree: true });
    });
  }

  document.addEventListener('visibilitychange', function () {
    if (document.hidden) {
      closePopup();
      paneObserver.disconnect();
      return;
    }
    if (document.body) {
      paneObserver.observe(document.body, { childList: true, subtree: true });
      repositionIfOpen();
    }
  });
})();
