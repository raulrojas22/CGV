(function () {
  'use strict';
  if (window.__assemblyInfoPopupInitialized) return;
  window.__assemblyInfoPopupInitialized = true;

  var POPUP_ID = 'assembly-info-popup';
  var OPTIONS_ID = 'organism-options-popup';
  var VIEWPORT_PAD = 10;
  var GAP = 10;
  var SIDE_Y_OFFSET = 16;
  var activeAnchor = null;
  var activeOptionsAnchor = null;

  function txt(value) {
    return String(value == null ? '' : value);
  }

  function toDisplay(value, fallback) {
    var raw = String(value == null ? '' : value).trim();
    return raw ? raw : String(fallback == null ? txt('N/A') : fallback);
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

  function formatOrg(value, fallback) {
    var txtVal = String(value == null ? '' : value).trim();
    if (!txtVal || txtVal === 'N/A' || txtVal.toLowerCase() === 'organism' || txtVal.toLowerCase() === 'selected organism(s)' || txtVal.toLowerCase() === 'selected organism') {
      return txtVal ? txtVal : String(fallback == null ? 'N/A' : fallback);
    }
    return '<em>' + txtVal + '</em>';
  }

  function getPopup() {
    return document.getElementById(POPUP_ID);
  }

  function getOptionsPopup() {
    return document.getElementById(OPTIONS_ID);
  }

  function isOpen() {
    var popup = getPopup();
    return !!(popup && popup.classList.contains('open'));
  }

  function ensurePopup() {
    var popup = getPopup();
    if (popup) return popup;

    popup = document.createElement('div');
    popup.id = POPUP_ID;
    popup.className = 'assembly-info-popup';
    popup.setAttribute('role', 'dialog');
    popup.setAttribute('aria-live', 'polite');
    popup.setAttribute('aria-hidden', 'true');
    popup.innerHTML =
      '<div class="assembly-info-popup-header">' +
      '<div class="assembly-info-popup-title-wrap">' +
      '<p class="assembly-info-popup-title">' + txt('Assembly details') + '</p>' +
      '<p class="assembly-info-popup-subtitle">' + txt('Selected organism') + '</p>' +
      '</div>' +
      '<button type="button" class="assembly-info-popup-close" aria-label="Close">&times;</button>' +
      '</div>' +
      '<div class="assembly-info-popup-body"></div>';

    document.body.appendChild(popup);
    return popup;
  }

  function ensureOptionsPopup() {
    var popup = getOptionsPopup();
    if (popup) return popup;

    popup = document.createElement('div');
    popup.id = OPTIONS_ID;
    popup.className = 'organism-options-popup';
    popup.setAttribute('role', 'dialog');
    popup.setAttribute('aria-hidden', 'true');
    popup.innerHTML =
      '<div class="organism-options-header">' +
      '<div class="organism-options-title">Organism</div>' +
      '<button type="button" class="organism-options-close" aria-label="Close">&times;</button>' +
      '</div>' +
      '<div class="organism-options-body">' +
      '<button type="button" class="organism-options-action organism-options-assembly">' +
      '<i class="fa fa-database" aria-hidden="true"></i>' +
      '<span><strong>Assembly details</strong><small>Genome assembly metadata and statistics</small></span>' +
      '</button>' +
      '<button type="button" class="organism-options-action organism-options-images">' +
      '<i class="fa fa-camera" aria-hidden="true"></i>' +
      '<span><strong>Organism images</strong><small>Photos from iNaturalist observations</small></span>' +
      '</button>' +
      '</div>';

    document.body.appendChild(popup);
    return popup;
  }

  function closePopup() {
    var popup = getPopup();
    if (!popup) return;
    popup.classList.remove('open', 'place-top', 'place-bottom');
    popup.setAttribute('aria-hidden', 'true');
    popup.removeAttribute('data-request-id');
    activeAnchor = null;
  }

  function closeOptionsPopup() {
    var popup = getOptionsPopup();
    if (!popup) return;
    popup.classList.remove('open');
    popup.setAttribute('aria-hidden', 'true');
    activeOptionsAnchor = null;
  }

  function positionPopup(popup, target) {
    if (!popup || !target) return;

    var rect = target.getBoundingClientRect();
    var vw = window.innerWidth || document.documentElement.clientWidth || 1200;
    var vh = window.innerHeight || document.documentElement.clientHeight || 800;

    popup.classList.remove('place-top', 'place-bottom', 'place-right', 'place-left');
    popup.style.left = '-9999px';
    popup.style.top = '-9999px';
    popup.classList.add('open');
    popup.style.visibility = 'hidden';

    var w = popup.offsetWidth || 460;
    var h = popup.offsetHeight || 320;

    var left = rect.right + GAP;
    var side = 'right';
    if (left + w > vw - VIEWPORT_PAD) {
      left = rect.left - w - GAP;
      side = 'left';
    }
    if (left < VIEWPORT_PAD) {
      var spaceRight = vw - rect.right - GAP - VIEWPORT_PAD;
      var spaceLeft = rect.left - GAP - VIEWPORT_PAD;
      if (spaceRight >= spaceLeft) {
        side = 'right';
        left = Math.min(vw - w - VIEWPORT_PAD, rect.right + GAP);
      } else {
        side = 'left';
        left = Math.max(VIEWPORT_PAD, rect.left - w - GAP);
      }
    }

    var top = rect.top + (rect.height / 2) - (h / 2) + SIDE_Y_OFFSET;
    top = Math.max(VIEWPORT_PAD, Math.min(vh - h - VIEWPORT_PAD, top));

    popup.classList.add(side === 'right' ? 'place-right' : 'place-left');
    popup.style.left = Math.round(left) + 'px';
    popup.style.top = Math.round(top) + 'px';
    popup.style.visibility = 'visible';
    popup.setAttribute('aria-hidden', 'false');
  }

  function renderLoading(popup, title, subtitle) {
    if (!popup) return;
    var titleEl = popup.querySelector('.assembly-info-popup-title');
    var subtitleEl = popup.querySelector('.assembly-info-popup-subtitle');
    var bodyEl = popup.querySelector('.assembly-info-popup-body');
    if (titleEl) titleEl.textContent = toDisplay(title, txt('Assembly details'));
    if (subtitleEl) subtitleEl.innerHTML = escapeAndFormatHtml(formatOrg(subtitle, txt('Selected organism(s)')));
    if (bodyEl) {
      var dnaLoaderHtml = (typeof window.appBuildDnaLoader === 'function')
        ? window.appBuildDnaLoader('app-dna-loader--popup')
        : '';
      bodyEl.innerHTML =
        '<div class="assembly-popup-loader">' +
        (dnaLoaderHtml ? ('<div class="assembly-popup-loader-anim">' + dnaLoaderHtml + '</div>') : '') +
        '<div class="assembly-tip-empty">' + txt('Loading assembly details...') + '</div>' +
        '</div>';
    }
  }

  function renderPayload(message) {
    var popup = ensurePopup();
    var msg = message && typeof message === 'object' ? message : {};
    var incomingReq = String(msg.request_id || '');
    var activeReq = String(popup.getAttribute('data-request-id') || '');
    if (incomingReq && activeReq && incomingReq !== activeReq) {
      return;
    }

    var titleEl = popup.querySelector('.assembly-info-popup-title');
    var subtitleEl = popup.querySelector('.assembly-info-popup-subtitle');
    var bodyEl = popup.querySelector('.assembly-info-popup-body');

    if (titleEl) titleEl.textContent = toDisplay(msg.title, txt('Assembly details'));
    if (subtitleEl) subtitleEl.innerHTML = escapeAndFormatHtml(formatOrg(msg.subtitle, txt('Selected organism(s)')));
    if (bodyEl) {
      var html = String(msg.html || '').trim();
      bodyEl.innerHTML = html || '<div class="assembly-tip-empty">' + txt('Assembly details are not available for this selection.') + '</div>';
    }
    if (isOpen()) {
      repositionIfNeeded();
    }
  }

  function openFromButton(button) {
    if (!button) return;

    var popup = ensurePopup();
    var title = toDisplay(button.getAttribute('data-assembly-title'), txt('Assembly details'));
    var subtitle = toDisplay(button.getAttribute('data-assembly-subtitle'), txt('Selected organism(s)'));
    var context = toDisplay(button.getAttribute('data-assembly-context'), 'homo');
    var idsRaw = String(button.getAttribute('data-assembly-species-ids') || '');
    var speciesIds = idsRaw ? idsRaw.split('|').map(function (x) { return String(x || '').trim(); }).filter(Boolean) : [];

    var requestId = String(Date.now()) + '_' + String(Math.floor(Math.random() * 1e6));
    popup.setAttribute('data-request-id', requestId);

    renderLoading(popup, title, subtitle);
    activeAnchor = button;
    positionPopup(popup, button);

    if (window.Shiny && typeof window.Shiny.setInputValue === 'function') {
      window.Shiny.setInputValue('assembly_info_request', {
        request_id: requestId,
        context: context,
        species_ids: speciesIds,
        subtitle: subtitle,
        triggered_at: Date.now()
      }, { priority: 'event' });
      return;
    }

    var fallbackHtml = String(button.getAttribute('data-assembly-html') || '').trim();
    if (fallbackHtml) {
      try {
        fallbackHtml = decodeURIComponent(fallbackHtml);
      } catch (_e) { }
      renderPayload({ request_id: requestId, title: title, subtitle: subtitle, html: fallbackHtml });
    }
  }

  function positionOptionsPopup(popup, target) {
    if (!popup || !target) return;

    var rect = target.getBoundingClientRect();
    var vw = window.innerWidth || document.documentElement.clientWidth || 1200;
    var vh = window.innerHeight || document.documentElement.clientHeight || 800;

    popup.style.left = '-9999px';
    popup.style.top = '-9999px';
    popup.classList.add('open');
    popup.style.visibility = 'hidden';

    var w = popup.offsetWidth || 300;
    var h = popup.offsetHeight || 190;
    var left = rect.left;
    if (left + w > vw - VIEWPORT_PAD) left = vw - w - VIEWPORT_PAD;
    left = Math.max(VIEWPORT_PAD, left);

    var top = rect.bottom + GAP;
    if (top + h > vh - VIEWPORT_PAD) top = rect.top - h - GAP;
    top = Math.max(VIEWPORT_PAD, top);

    popup.style.left = Math.round(left) + 'px';
    popup.style.top = Math.round(top) + 'px';
    popup.style.visibility = 'visible';
    popup.setAttribute('aria-hidden', 'false');
  }

  function openOptionsFromPill(pill) {
    if (!pill) return;
    closePopup();
    var popup = ensureOptionsPopup();
    var title = toDisplay(pill.getAttribute('data-assembly-subtitle') || pill.getAttribute('data-orgimg-organism'), 'Organism');
    var titleEl = popup.querySelector('.organism-options-title');
    if (titleEl) titleEl.innerHTML = escapeAndFormatHtml(formatOrg(title, 'Organism'));
    popup.__organismAnchor = pill;
    activeOptionsAnchor = pill;
    positionOptionsPopup(popup, pill);
  }

  function openAssemblyFromPill(pill) {
    if (!pill) return;
    closeOptionsPopup();
    openFromButton(pill);
  }

  function openImagesFromPill(pill) {
    if (!pill) return;
    closeOptionsPopup();
    var organism = String(pill.getAttribute('data-orgimg-organism') || '').trim();
    var aliases = String(pill.getAttribute('data-orgimg-aliases') || '').trim();
    if (!organism) return;
    if (typeof window.openOrganismImages === 'function') {
      window.openOrganismImages(organism, aliases);
    }
  }

  function repositionIfNeeded() {
    if (!isOpen() || !activeAnchor || !document.body.contains(activeAnchor)) return;
    var popup = getPopup();
    if (!popup) return;
    positionPopup(popup, activeAnchor);
  }

  function repositionOptionsIfNeeded() {
    var popup = getOptionsPopup();
    if (!popup || !popup.classList.contains('open') || !activeOptionsAnchor || !document.body.contains(activeOptionsAnchor)) return;
    positionOptionsPopup(popup, activeOptionsAnchor);
  }

  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target) return;

    var infoBtn = target.closest ? target.closest('.preloaded-info-btn') : null;
    if (infoBtn) {
      event.preventDefault();
      event.stopPropagation();
      openFromButton(infoBtn);
      return;
    }

    var organismPill = target.closest ? target.closest('.summary-organism-pill') : null;
    if (organismPill) {
      event.preventDefault();
      event.stopPropagation();
      openOptionsFromPill(organismPill);
      return;
    }

    if (target.closest && target.closest('.assembly-info-popup-close')) {
      event.preventDefault();
      event.stopPropagation();
      closePopup();
      return;
    }

    if (target.closest && target.closest('.organism-options-close')) {
      event.preventDefault();
      event.stopPropagation();
      closeOptionsPopup();
      return;
    }

    var optionsPopup = target.closest ? target.closest('#' + OPTIONS_ID) : null;
    if (optionsPopup) {
      var optionAnchor = optionsPopup.__organismAnchor;
      if (target.closest('.organism-options-assembly')) {
        event.preventDefault();
        event.stopPropagation();
        openAssemblyFromPill(optionAnchor);
        return;
      }
      if (target.closest('.organism-options-images')) {
        event.preventDefault();
        event.stopPropagation();
        openImagesFromPill(optionAnchor);
        return;
      }
      return;
    }

    if (target.closest && target.closest('#' + POPUP_ID)) {
      return;
    }

    if (getOptionsPopup() && getOptionsPopup().classList.contains('open')) {
      closeOptionsPopup();
    }
    if (isOpen()) {
      closePopup();
    }
  }, true);

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && isOpen()) {
      closePopup();
    }
    if (event.key === 'Escape' && getOptionsPopup() && getOptionsPopup().classList.contains('open')) {
      closeOptionsPopup();
    }
  }, true);

  window.addEventListener('resize', function () { repositionIfNeeded(); repositionOptionsIfNeeded(); }, { passive: true });
  window.addEventListener('scroll', function () { repositionIfNeeded(); repositionOptionsIfNeeded(); }, { passive: true, capture: true });

  // Attach scroll listeners to all main panes (for inner scrolling)
  var mainPanes = document.querySelectorAll('.app-main-pane');
  mainPanes.forEach(function (pane) {
    pane.addEventListener('scroll', function () { repositionIfNeeded(); repositionOptionsIfNeeded(); }, { passive: true, capture: true });
  });

  var paneObserver = new MutationObserver(function (mutations) {
    var newPanes = document.querySelectorAll('.app-main-pane:not([data-popup-scroll-bound="assembly"])');
    if (newPanes.length > 0) {
      newPanes.forEach(function (pane) {
        pane.setAttribute('data-popup-scroll-bound', 'assembly');
        pane.addEventListener('scroll', function () { repositionIfNeeded(); repositionOptionsIfNeeded(); }, { passive: true, capture: true });
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
      repositionIfNeeded();
      repositionOptionsIfNeeded();
    }
  });

  Shiny.addCustomMessageHandler('assembly_info_popup_data', function (message) {
    renderPayload(message || {});
  });
})();
