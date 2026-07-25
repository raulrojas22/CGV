(function () {
  'use strict';

  if (window.__cgvSearchSubmitFeedbackInitialized) return;
  window.__cgvSearchSubmitFeedbackInitialized = true;

  var BUTTON_SELECTOR = [
    '#global_search_go',
    '#global_search_go_collapsed',
    '#app-fab-search-run'
  ].join(',');
  var busy = false;
  var releaseTimer = null;

  function visibleButtons() {
    return Array.prototype.slice.call(document.querySelectorAll(BUTTON_SELECTOR));
  }

  function setButtonBusy(button, active) {
    if (!button) return;

    if (active) {
      if (!button.hasAttribute('data-cgv-idle-html')) {
        button.setAttribute('data-cgv-idle-html', button.innerHTML);
      }
      button.classList.add('is-search-submitting');
      button.setAttribute('aria-busy', 'true');
      button.innerHTML =
        '<i class="fas fa-circle-notch fa-spin" aria-hidden="true"></i>' +
        '<span>Generating...</span>';
      return;
    }

    var idleHtml = button.getAttribute('data-cgv-idle-html');
    if (idleHtml !== null) {
      button.innerHTML = idleHtml;
      button.removeAttribute('data-cgv-idle-html');
    }
    button.classList.remove('is-search-submitting');
    button.removeAttribute('aria-busy');
    button.disabled = false;
  }

  function showImmediatePopup(mode, query) {
    var popup = document.getElementById('app-status-popup');
    var loaderText = document.getElementById('app-status-popup-loader-text');
    if (!popup) return;

    var workflow = mode === 'orthologous' ? 'Cross-species search' : 'Gene search';
    var gene = String(query == null ? '' : query).trim();
    var detail = gene ? 'Preparing visualization for ' + gene + '...' : 'Preparing visualization...';

    if (loaderText) {
      loaderText.textContent = workflow + '\n' + detail;
    }
    popup.classList.add('open', 'loading');
  }

  function inferMode() {
    var activePane = document.querySelector('.app-main > .tab-content > .tab-pane.active');
    var paneId = activePane ? String(activePane.id || '') : '';
    if (/ortho/i.test(paneId)) return 'orthologous';

    var activeNav = document.querySelector(
      '[data-value="orthologous"].active, [data-value="orthologous"][aria-selected="true"]'
    );
    return activeNav ? 'orthologous' : 'homologous';
  }

  function bestQuery(mode) {
    var ids = mode === 'orthologous'
      ? ['gene_name', 'global_search_query', 'global_search_query_collapsed', 'app-fab-search-query']
      : ['filter1', 'global_search_query', 'global_search_query_collapsed', 'app-fab-search-query'];

    for (var i = 0; i < ids.length; i += 1) {
      var input = document.getElementById(ids[i]);
      var value = input ? String(input.value || '').trim() : '';
      if (value) return value;
    }
    return '';
  }

  window.cgvBeginSearchFeedback = function (mode, query) {
    if (busy) return false;
    busy = true;

    var normalizedMode = mode === 'orthologous' ? 'orthologous' : 'homologous';
    showImmediatePopup(normalizedMode, query);

    // Allow the original click and Shiny's input binding to finish before
    // replacing button contents or applying native disabled state.
    window.setTimeout(function () {
      if (!busy) return;
      visibleButtons().forEach(function (button) {
        setButtonBusy(button, true);
        button.disabled = true;
      });
    }, 0);

    window.clearTimeout(releaseTimer);
    releaseTimer = window.setTimeout(function () {
      window.cgvEndSearchFeedback();
    }, 90000);
    return true;
  };

  window.cgvEndSearchFeedback = function () {
    busy = false;
    window.clearTimeout(releaseTimer);
    releaseTimer = null;
    visibleButtons().forEach(function (button) {
      setButtonBusy(button, false);
    });
  };

  document.addEventListener('click', function (event) {
    var button = event.target && event.target.closest
      ? event.target.closest(BUTTON_SELECTOR)
      : null;
    if (!button) return;

    // The quick FAB forwards to global_search_go in the same event turn.
    // Let that canonical button start feedback so the forwarded click is not blocked.
    if (button.id === 'app-fab-search-run' && !busy) return;

    if (busy) {
      event.preventDefault();
      event.stopImmediatePropagation();
      return;
    }

    var mode = inferMode();
    window.cgvBeginSearchFeedback(mode, bestQuery(mode));
  }, true);

  document.addEventListener('shiny:disconnected', function () {
    window.cgvEndSearchFeedback();
  });
})();
