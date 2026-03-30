(function () {
  'use strict';
  if (window.__goTermsPopupInitialized) return;
  window.__goTermsPopupInitialized = true;

  var POPUP_ID = 'go-terms-popup';
  var VIEWPORT_PAD = 10;
  var GAP = 10;
  var activeAnchor = null;
  var loadingTimer = null;
  var LOADING_TIMEOUT_MS = 30000;

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
    var v = String(value == null ? '' : value).trim();
    return v ? v : (fallback == null ? 'N/A' : String(fallback));
  }

  function formatOrg(value, fallback) {
    var txtVal = String(value == null ? '' : value).trim();
    if (!txtVal || txtVal === 'N/A' || txtVal.toLowerCase() === 'organism' || txtVal.toLowerCase() === 'selected organism') {
      return txtVal ? txtVal : String(fallback == null ? 'N/A' : fallback);
    }
    return '<em>' + txtVal + '</em>';
  }

  function ensurePopup() {
    var popup = document.getElementById(POPUP_ID);
    if (popup) return popup;

    popup = document.createElement('div');
    popup.id = POPUP_ID;
    popup.className = 'go-terms-popup tone-info';
    popup.setAttribute('role', 'dialog');
    popup.setAttribute('aria-live', 'polite');
    popup.setAttribute('aria-hidden', 'true');
    popup.innerHTML =
      '<div class="go-terms-popup-header">' +
      '<div class="go-terms-popup-title-wrap">' +
      '<p class="go-terms-popup-title">' + txt('GO annotations') + '</p>' +
      '<p class="go-terms-popup-subtitle">' + txt('Gene') + ': ' + txt('N/A') + ' | ' + txt('Organism') + ': ' + txt('N/A') + ' | ' + txt('Chr') + ': ' + txt('N/A') + '</p>' +
      '</div>' +
      '<button type="button" class="go-terms-popup-close" aria-label="Close">&times;</button>' +
      '</div>' +
      '<div class="go-terms-popup-body">' +
      '<div class="go-terms-popup-loader" aria-hidden="true">' +
      '<div class="app-dna-loader app-dna-loader--popup">' +
      '<div class="app-dna-wave app-dna-wave-top">' +
      '<span class="app-dna-node" style="--i:0;"></span>' +
      '<span class="app-dna-node" style="--i:1;"></span>' +
      '<span class="app-dna-node" style="--i:2;"></span>' +
      '<span class="app-dna-node" style="--i:3;"></span>' +
      '<span class="app-dna-node" style="--i:4;"></span>' +
      '<span class="app-dna-node" style="--i:5;"></span>' +
      '<span class="app-dna-node" style="--i:6;"></span>' +
      '<span class="app-dna-node" style="--i:7;"></span>' +
      '<span class="app-dna-node" style="--i:8;"></span>' +
      '<span class="app-dna-node" style="--i:9;"></span>' +
      '<span class="app-dna-node" style="--i:10;"></span>' +
      '<span class="app-dna-node" style="--i:11;"></span>' +
      '<span class="app-dna-node" style="--i:12;"></span>' +
      '<span class="app-dna-node" style="--i:13;"></span>' +
      '<span class="app-dna-node" style="--i:14;"></span>' +
      '<span class="app-dna-node" style="--i:15;"></span>' +
      '</div>' +
      '<div class="app-dna-wave app-dna-wave-bottom">' +
      '<span class="app-dna-node" style="--i:0;"></span>' +
      '<span class="app-dna-node" style="--i:1;"></span>' +
      '<span class="app-dna-node" style="--i:2;"></span>' +
      '<span class="app-dna-node" style="--i:3;"></span>' +
      '<span class="app-dna-node" style="--i:4;"></span>' +
      '<span class="app-dna-node" style="--i:5;"></span>' +
      '<span class="app-dna-node" style="--i:6;"></span>' +
      '<span class="app-dna-node" style="--i:7;"></span>' +
      '<span class="app-dna-node" style="--i:8;"></span>' +
      '<span class="app-dna-node" style="--i:9;"></span>' +
      '<span class="app-dna-node" style="--i:10;"></span>' +
      '<span class="app-dna-node" style="--i:11;"></span>' +
      '<span class="app-dna-node" style="--i:12;"></span>' +
      '<span class="app-dna-node" style="--i:13;"></span>' +
      '<span class="app-dna-node" style="--i:14;"></span>' +
      '<span class="app-dna-node" style="--i:15;"></span>' +
      '</div>' +
      '</div>' +
      '<p class="go-terms-popup-loader-text">' + txt('Searching GO annotations...') + '</p>' +
      '</div>' +
      '<p class="go-terms-popup-summary">' + txt('Loading GO annotations...') + '</p>' +
      '<p class="go-terms-popup-source"></p>' +
      '<div class="go-terms-popup-actions" hidden><button type="button" class="go-terms-online-btn" hidden>' + txt('Try online GO lookup') + '</button></div>' +
      '<div class="go-terms-popup-sections"></div>' +
      '</div>';
    document.body.appendChild(popup);
    return popup;
  }

  function getPopup() {
    return document.getElementById(POPUP_ID);
  }

  function isPopupOpen() {
    var popup = getPopup();
    return !!(popup && popup.classList.contains('open'));
  }

  function clearLoadingTimer() {
    if (loadingTimer) {
      clearTimeout(loadingTimer);
      loadingTimer = null;
    }
  }

  function closePopup() {
    clearLoadingTimer();
    var popup = getPopup();
    if (!popup) return;
    popup.classList.remove('open', 'place-top', 'place-bottom', 'loading');
    popup.setAttribute('aria-hidden', 'true');
    activeAnchor = null;
  }

  function setTone(popup, tone) {
    if (!popup) return;
    popup.classList.remove('tone-info', 'tone-success', 'tone-warning', 'tone-error');
    var safeTone = String(tone || 'info').toLowerCase();
    if (['info', 'success', 'warning', 'error'].indexOf(safeTone) < 0) safeTone = 'info';
    popup.classList.add('tone-' + safeTone);
  }

  function setOnlineFallbackState(popup, enabled, payload) {
    if (!popup) return;
    var wrap = popup.querySelector('.go-terms-popup-actions');
    var btn = popup.querySelector('.go-terms-online-btn');
    if (!btn) return;
    var ok = !!enabled;
    if (ok) {
      if (wrap) wrap.hidden = false;
      btn.hidden = false;
      try {
        popup.setAttribute('data-online-payload', JSON.stringify(payload && typeof payload === 'object' ? payload : {}));
      } catch (_e) {
        popup.setAttribute('data-online-payload', '{}');
      }
    } else {
      if (wrap) wrap.hidden = true;
      btn.hidden = true;
      popup.setAttribute('data-online-payload', '{}');
    }
  }

  function getOnlinePayload(popup) {
    if (!popup) return {};
    var raw = String(popup.getAttribute('data-online-payload') || '{}');
    try {
      var parsed = JSON.parse(raw);
      return parsed && typeof parsed === 'object' ? parsed : {};
    } catch (_e) {
      return {};
    }
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

    var w = popup.offsetWidth || 440;
    var h = popup.offsetHeight || 320;
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

  function renderLoading(buttonMeta, requestId) {
    var popup = ensurePopup();
    popup.setAttribute('data-request-id', String(requestId || ''));
    popup.classList.add('loading');
    popup.__goSections = [];
    popup.__goShownMap = {};
    setTone(popup, 'info');

    var subtitle = txt('Gene') + ': ' + toDisplay(buttonMeta.gene, 'N/A') +
      ' | ' + txt('Organism') + ': ' + formatOrg(buttonMeta.organism, 'N/A') +
      ' | ' + txt('Chr') + ': ' + toDisplay(buttonMeta.chromosome, 'N/A');

    var titleEl = popup.querySelector('.go-terms-popup-title');
    var subtitleEl = popup.querySelector('.go-terms-popup-subtitle');
    var summaryEl = popup.querySelector('.go-terms-popup-summary');
    var loaderTextEl = popup.querySelector('.go-terms-popup-loader-text');
    var sourceEl = popup.querySelector('.go-terms-popup-source');
    var sectionsEl = popup.querySelector('.go-terms-popup-sections');

    if (titleEl) titleEl.textContent = txt('GO annotations');
    if (subtitleEl) subtitleEl.innerHTML = escapeAndFormatHtml(subtitle);
    if (summaryEl) summaryEl.textContent = txt('Loading GO annotations...');
    if (loaderTextEl) loaderTextEl.textContent = txt('Searching GO annotations...');
    if (sourceEl) sourceEl.textContent = '';
    if (sectionsEl) sectionsEl.innerHTML = '';
    setOnlineFallbackState(popup, false, {});
  }

  function toPositiveInt(value, fallback) {
    var n = Number(value);
    if (!isFinite(n) || n <= 0) return Number(fallback || 0);
    return Math.floor(n);
  }

  function sectionKey(sec, idx) {
    var code = String((sec && sec.code) || '').trim();
    return code ? ('code_' + code) : ('idx_' + String(idx));
  }

  function renderSections(sections, shownMap) {
    var out = '';
    if (!Array.isArray(sections) || sections.length === 0) return out;
    var map = shownMap && typeof shownMap === 'object' ? shownMap : {};

    for (var i = 0; i < sections.length; i += 1) {
      var sec = sections[i] || {};
      var secKey = sectionKey(sec, i);
      var secLabel = toDisplay(sec.label, 'GO aspect');
      var items = Array.isArray(sec.items) ? sec.items : [];
      var secTotal = Math.max(toPositiveInt(sec.total, 0), items.length);
      var secStep = Math.max(1, toPositiveInt(sec.step, 25));
      var initialShown = toPositiveInt(sec.shown, Math.min(secTotal, secStep));
      var secShown = toPositiveInt(map[secKey], initialShown);
      secShown = Math.max(0, Math.min(secShown, secTotal));
      var secMeta = secTotal > 0 ? ('(' + secShown + '/' + secTotal + ')') : '';

      out += '<section class="go-terms-section">';
      out += '<div class="go-terms-section-head">' + escapeHtml(secLabel + ' ' + secMeta) + '</div>';
      if (items.length === 0) {
        out += '<div class="go-terms-empty-inline">' + escapeHtml(txt('No items in this aspect.')) + '</div>';
      } else {
        out += '<ul class="go-terms-list">';
        var visibleItems = Math.min(secShown, items.length);
        for (var j = 0; j < visibleItems; j += 1) {
          var it = items[j] || {};
          var goId = toDisplay(it.go_id, 'GO:unknown');
          var goName = String(it.go_name || '').trim();
          var goUrl = String(it.go_url || '').trim();
          var qf = String(it.qualifier || '').trim();
          var ev = String(it.evidence || '').trim();
          var asg = String(it.assigned_by || '').trim();
          var ref = String(it.reference || '').trim();

          var metaParts = [];
          if (qf) metaParts.push(txt('Qualifier') + ': ' + qf);
          if (ev) metaParts.push(txt('Evidence') + ': ' + ev);
          if (asg) metaParts.push(txt('Assigned by') + ': ' + asg);
          if (ref) metaParts.push(txt('Ref') + ': ' + ref);
          var metaLine = metaParts.join(' | ');

          out += '<li class="go-terms-item">';
          if (goUrl) {
            out += '<a class="go-terms-id" href="' + escapeHtml(goUrl) + '" target="_blank" rel="noopener noreferrer">' + escapeHtml(goId) + '</a>';
          } else {
            out += '<span class="go-terms-id">' + escapeHtml(goId) + '</span>';
          }
          if (goName) {
            out += '<div class="go-terms-name">' + escapeHtml(goName) + '</div>';
          }
          if (metaLine) {
            out += '<div class="go-terms-meta">' + escapeHtml(metaLine) + '</div>';
          }
          out += '</li>';
        }
        out += '</ul>';
        if (secShown < secTotal) {
          var remaining = secTotal - secShown;
          var nextStep = Math.min(secStep, remaining);
          out += '<div class="go-terms-more-wrap">';
          out += '<button type="button" class="go-terms-more-btn" data-go-sec="' + escapeHtml(secKey) + '" data-go-step="' + secStep + '" data-go-total="' + secTotal + '">' +
            escapeHtml(txt('Show more') + ' (+' + nextStep + ')') +
            '</button>';
          out += '</div>';
        }
      }
      out += '</section>';
    }
    return out;
  }

  function renderPayload(message) {
    clearLoadingTimer();
    var popup = ensurePopup();
    var msg = message && typeof message === 'object' ? message : {};
    var reqId = String(msg.request_id || '');
    var currentReq = String(popup.getAttribute('data-request-id') || '');
    if (reqId && currentReq && reqId !== currentReq) {
      return;
    }

    popup.classList.remove('loading');
    setTone(popup, msg.tone || 'info');

    var titleEl = popup.querySelector('.go-terms-popup-title');
    var subtitleEl = popup.querySelector('.go-terms-popup-subtitle');
    var summaryEl = popup.querySelector('.go-terms-popup-summary');
    var sourceEl = popup.querySelector('.go-terms-popup-source');
    var sectionsEl = popup.querySelector('.go-terms-popup-sections');

    if (titleEl) titleEl.textContent = toDisplay(msg.title, txt('GO annotations'));
    if (subtitleEl) subtitleEl.innerHTML = escapeAndFormatHtml(toDisplay(msg.subtitle, txt('Gene') + ': ' + txt('N/A') + ' | ' + txt('Organism') + ': ' + txt('N/A') + ' | ' + txt('Chr') + ': ' + txt('N/A')));
    if (summaryEl) summaryEl.textContent = toDisplay(msg.summary, txt('No GO annotations available.'));

    var sourceText = String(msg.source || '').trim();
    if (sourceEl) {
      sourceEl.textContent = sourceText ? (txt('Source') + ': ' + sourceText) : '';
    }

    var sections = Array.isArray(msg.sections) ? msg.sections : [];
    if (sectionsEl) {
      if (sections.length > 0) {
        popup.__goSections = sections;
        popup.__goShownMap = {};
        for (var i = 0; i < sections.length; i += 1) {
          var sec = sections[i] || {};
          var key = sectionKey(sec, i);
          var items = Array.isArray(sec.items) ? sec.items : [];
          var total = Math.max(toPositiveInt(sec.total, 0), items.length);
          var step = Math.max(1, toPositiveInt(sec.step, 25));
          var initialShown = toPositiveInt(sec.shown, Math.min(total, step));
          popup.__goShownMap[key] = Math.max(0, Math.min(initialShown, total));
        }
        sectionsEl.innerHTML = renderSections(sections, popup.__goShownMap);
      } else {
        popup.__goSections = [];
        popup.__goShownMap = {};
        var emptyText = toDisplay(msg.empty_message, txt('No GO annotations available for this gene.'));
        sectionsEl.innerHTML = '<div class="go-terms-empty">' + escapeHtml(emptyText) + '</div>';
      }
    }

    setOnlineFallbackState(
      popup,
      !!msg.allow_online_fallback,
      msg.online_payload && typeof msg.online_payload === 'object' ? msg.online_payload : {}
    );
  }

  function extractButtonMeta(button) {
    return {
      context: String(button.getAttribute('data-go-context') || '').trim(),
      plot_id: String(button.getAttribute('data-go-plot-id') || '').trim(),
      gene: String(button.getAttribute('data-go-gene') || '').trim(),
      organism: String(button.getAttribute('data-go-organism') || '').trim(),
      chromosome: String(button.getAttribute('data-go-chromosome') || '').trim(),
      annotation: String(button.getAttribute('data-go-annotation') || '').trim()
    };
  }

  function sendRequest(meta, requestId) {
    if (!window.Shiny || typeof window.Shiny.setInputValue !== 'function') return;
    var payload = {
      request_id: String(requestId || ''),
      context: meta.context || '',
      plot_id: meta.plot_id || '',
      gene: meta.gene || '',
      organism: meta.organism || '',
      chromosome: meta.chromosome || '',
      annotation_path: meta.annotation || '',
      triggered_at: Date.now()
    };
    window.Shiny.setInputValue('go_terms_request', payload, { priority: 'event' });
  }

  function openFromButton(button) {
    if (!button) return;
    clearLoadingTimer();
    var popup = ensurePopup();
    var requestId = String(Date.now()) + '_' + String(Math.floor(Math.random() * 1e6));
    var meta = extractButtonMeta(button);
    activeAnchor = button;
    renderLoading(meta, requestId);
    positionPopup(popup, button);
    sendRequest(meta, requestId);

    // Safety net: if no response arrives within LOADING_TIMEOUT_MS, unstick the popup
    loadingTimer = setTimeout(function () {
      var p = getPopup();
      if (p && p.classList.contains('loading') &&
          String(p.getAttribute('data-request-id') || '') === requestId) {
        // loading timed out
        p.classList.remove('loading');
        var summaryEl = p.querySelector('.go-terms-popup-summary');
        if (summaryEl) summaryEl.textContent = 'GO lookup timed out. Try again.';
      }
    }, LOADING_TIMEOUT_MS);
  }

  function repositionIfOpen() {
    if (!isPopupOpen() || !activeAnchor || !document.body.contains(activeAnchor)) return;
    var popup = getPopup();
    if (!popup) return;
    positionPopup(popup, activeAnchor);
  }

  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target) return;

    var goBtn = target.closest ? target.closest('.db-link-go') : null;
    if (goBtn) {
      event.preventDefault();
      event.stopPropagation();
      openFromButton(goBtn);
      return;
    }

    if (target.closest && target.closest('.go-terms-popup-close')) {
      event.preventDefault();
      event.stopPropagation();
      closePopup();
      return;
    }

    if (target.closest && target.closest('.go-terms-online-btn')) {
      event.preventDefault();
      event.stopPropagation();
      var popup = ensurePopup();
      var payload = getOnlinePayload(popup);
      payload = payload && typeof payload === 'object' ? payload : {};
      payload.request_id = String(popup.getAttribute('data-request-id') || '');
      payload.triggered_at = Date.now();
      if (window.Shiny && typeof window.Shiny.setInputValue === 'function') {
        window.Shiny.setInputValue('go_terms_online_request', payload, { priority: 'event' });
      }
      popup.classList.add('loading');
      setTone(popup, 'info');
      var summaryEl = popup.querySelector('.go-terms-popup-summary');
      var loaderTextEl = popup.querySelector('.go-terms-popup-loader-text');
      var sourceEl = popup.querySelector('.go-terms-popup-source');
      var sectionsEl = popup.querySelector('.go-terms-popup-sections');
      if (summaryEl) summaryEl.textContent = 'Searching online GO annotations...';
      if (loaderTextEl) loaderTextEl.textContent = 'Searching online GO annotations...';
      if (sourceEl) sourceEl.textContent = '';
      if (sectionsEl) sectionsEl.innerHTML = '';
      popup.__goSections = [];
      popup.__goShownMap = {};
      setOnlineFallbackState(popup, false, {});
      return;
    }

    if (target.closest && target.closest('.go-terms-more-btn')) {
      event.preventDefault();
      event.stopPropagation();
      var btn = target.closest('.go-terms-more-btn');
      var popupMore = ensurePopup();
      var keyMore = String(btn.getAttribute('data-go-sec') || '').trim();
      var totalMore = toPositiveInt(btn.getAttribute('data-go-total'), 0);
      var stepMore = Math.max(1, toPositiveInt(btn.getAttribute('data-go-step'), 25));
      if (!keyMore || totalMore <= 0) return;
      var shownMapMore = popupMore.__goShownMap && typeof popupMore.__goShownMap === 'object' ? popupMore.__goShownMap : {};
      var currentShown = toPositiveInt(shownMapMore[keyMore], 0);
      shownMapMore[keyMore] = Math.min(totalMore, currentShown + stepMore);
      popupMore.__goShownMap = shownMapMore;
      var sectionsMore = Array.isArray(popupMore.__goSections) ? popupMore.__goSections : [];
      var sectionsElMore = popupMore.querySelector('.go-terms-popup-sections');
      if (sectionsElMore) {
        sectionsElMore.innerHTML = renderSections(sectionsMore, shownMapMore);
      }
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

  // Register Shiny handler BEFORE any code that could throw
  Shiny.addCustomMessageHandler('go_terms_popup_data', function (message) {
    renderPayload(message || {});
    repositionIfOpen();
  });

  var paneObserver = new MutationObserver(function (mutations) {
    var newPanes = document.querySelectorAll('.app-main-pane:not([data-popup-scroll-bound="goterms"])');
    if (newPanes.length > 0) {
      newPanes.forEach(function (pane) {
        pane.setAttribute('data-popup-scroll-bound', 'goterms');
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
