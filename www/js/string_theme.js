(function () {
  'use strict';
  if (window.__cgvStringThemeInitialized) return;
  window.__cgvStringThemeInitialized = true;

  function clearNetworkOutput(outputId, attempt) {
    var id = outputId || 'string_network_plot';
    var container = document.getElementById(id);
    if (!container) {
      if ((attempt || 0) < 8) {
        window.setTimeout(function () { clearNetworkOutput(id, (attempt || 0) + 1); }, 80);
      }
      return;
    }
    try {
      container.innerHTML = '';
      container.setAttribute('data-string-network-reset-at', String(Date.now()));
    } catch (err) {}
    var graph = document.getElementById('graph' + id);
    if (graph) {
      try { graph.innerHTML = ''; } catch (err2) {}
    }
  }

  function applyTheme(dark, attempt) {
    var container = document.getElementById('string_network_plot');
    if (!container) {
      if ((attempt || 0) < 8) {
        window.setTimeout(function () { applyTheme(dark, (attempt || 0) + 1); }, 80);
      }
      return;
    }
    container.style.backgroundColor = dark ? '#0F1D2B' : '#FFFFFF';
    var graph = document.getElementById('graphstring_network_plot');
    if (graph) graph.style.backgroundColor = dark ? '#0F1D2B' : '#FFFFFF';
  }

  function notifyClosed() {
    clearNetworkOutput('string_network_plot', 0);
    if (window.Shiny && typeof window.Shiny.setInputValue === 'function') {
      window.Shiny.setInputValue('string_network_closed', { at: Date.now() }, { priority: 'event' });
    }
  }

  function bindCloseHandler() {
    if (window.jQuery && window.jQuery.fn && window.jQuery.fn.on) {
      window.jQuery(document)
        .off('hidden.bs.modal.cgvStringNetwork')
        .on('hidden.bs.modal.cgvStringNetwork', '.modal', function () {
          if (
            (this.classList && this.classList.contains('string-network-modal')) ||
            (this.querySelector && this.querySelector('.string-network-body-wrap'))
          ) {
            notifyClosed();
          }
        });
    }
  }

  if (window.Shiny && typeof window.Shiny.addCustomMessageHandler === 'function') {
    window.Shiny.addCustomMessageHandler('string_network_theme', function (message) {
      applyTheme(!!(message && message.dark), 0);
    });
    window.Shiny.addCustomMessageHandler('string_network_reset', function (message) {
      clearNetworkOutput(message && message.outputId ? message.outputId : 'string_network_plot', 0);
    });
  }

  bindCloseHandler();
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bindCloseHandler);
  }
})();
