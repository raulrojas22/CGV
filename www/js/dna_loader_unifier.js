(function () {
  'use strict';
  if (window.__dnaLoaderUnifierInitialized) return;
  window.__dnaLoaderUnifierInitialized = true;

  var hostObserverMap = typeof WeakMap === 'function' ? new WeakMap() : null;
  var bootObserver = null;

  function buildNodes() {
    var out = '';
    for (var i = 0; i < 16; i += 1) {
      out += '<span class="app-dna-node" style="--i:' + i + ';"></span>';
    }
    return out;
  }

  function buildDnaLoader(sizeClass) {
    var cls = 'app-dna-loader';
    if (sizeClass) cls += ' ' + sizeClass;
    var nodes = buildNodes();
    return (
      '<div class="' + cls + '" aria-hidden="true">' +
      '<div class="app-dna-wave app-dna-wave-top">' + nodes + '</div>' +
      '<div class="app-dna-wave app-dna-wave-bottom">' + nodes + '</div>' +
      '</div>'
    );
  }

  function resolveSpinnerSizeClass(host) {
    if (!host || !host.closest) return 'app-dna-loader--spinner-md';
    if (host.closest('.chart-modal-chart-wrap, .analytics-chart-wrap, .string-network-body-wrap, .plot-card-main')) {
      return 'app-dna-loader--spinner-sm';
    }
    return 'app-dna-loader--spinner-md';
  }

  function resolveSpinnerMessage(host) {
    if (!host || !host.closest) return 'Processing data…';
    if (host.closest('.analytics-chart-wrap')) return 'Generating statistical analysis…';
    if (host.closest('.string-network-body-wrap')) return 'Building interaction network…';
    if (host.closest('.plot-card-main, .promoter-plot-container')) return 'Rendering gene visualization…';
    if (host.closest('.chart-modal-chart-wrap')) return 'Preparing chart…';
    return 'Processing data…';
  }

  function hydrateSpinnerHost(loadContainer) {
    if (!loadContainer || loadContainer.getAttribute('data-dna-loader-ready') === 'true') return;
    loadContainer.setAttribute('data-dna-loader-ready', 'true');
    loadContainer.classList.add('app-dna-spinner-host');

    var wrap = document.createElement('div');
    wrap.className = 'app-dna-spinner-wrap';
    wrap.innerHTML = buildDnaLoader(resolveSpinnerSizeClass(loadContainer)) +
      '<span class="app-dna-spinner-message">' + resolveSpinnerMessage(loadContainer) + '</span>';
    loadContainer.appendChild(wrap);
    loadContainer.setAttribute('role', 'status');
    loadContainer.setAttribute('aria-live', 'polite');
    loadContainer.setAttribute('aria-label', resolveSpinnerMessage(loadContainer));
  }

  function syncActiveState(loadContainer) {
    if (!loadContainer || !loadContainer.parentElement) return;
    var parent = loadContainer.parentElement;
    if (!parent.classList || !parent.classList.contains('shiny-spinner-output-container')) return;
    var isActive = !loadContainer.classList.contains('shiny-spinner-hidden');
    parent.classList.toggle('app-dna-spinner-active', isActive);

    // Keep plot cards at a stable width while spinner is active.
    var plotMain = parent.closest ? parent.closest('.plot-card-main') : null;
    if (plotMain && plotMain.classList) {
      plotMain.classList.toggle('app-plot-loading', isActive);
    }
  }

  function attachHostObserver(loadContainer) {
    if (!loadContainer || typeof MutationObserver !== 'function') return;
    if (hostObserverMap && hostObserverMap.has(loadContainer)) return;
    if (!hostObserverMap && loadContainer.__appDnaHostObserverAttached) return;

    var observer = new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i += 1) {
        var m = mutations[i];
        if (!m || m.type !== 'attributes') continue;
        syncActiveState(loadContainer);
      }
    });

    observer.observe(loadContainer, {
      attributes: true,
      attributeFilter: ['class']
    });

    if (hostObserverMap) {
      hostObserverMap.set(loadContainer, observer);
    } else {
      loadContainer.__appDnaHostObserverAttached = true;
    }
  }

  function scanSpinnerHosts(root) {
    var scope = root && root.querySelectorAll ? root : document;
    var hosts = scope.querySelectorAll('.shiny-spinner-output-container > .load-container');
    for (var i = 0; i < hosts.length; i += 1) {
      hydrateSpinnerHost(hosts[i]);
      syncActiveState(hosts[i]);
      attachHostObserver(hosts[i]);
    }
  }

  function syncPlotPlaceholder(container) {
    if (!container || !container.querySelector) return;
    var placeholder = container.querySelector('.plot-loading-placeholder');
    if (!placeholder) return;
    var ready = !!container.querySelector('.shiny-bound-output svg, .ggiraph.html-widget svg');
    placeholder.hidden = ready;
    placeholder.setAttribute('aria-hidden', ready ? 'true' : 'false');
  }

  function scanPlotPlaceholders(root) {
    var scope = root && root.querySelectorAll ? root : document;
    if (scope.matches && scope.matches('.promoter-plot-container')) syncPlotPlaceholder(scope);
    var containers = scope.querySelectorAll('.promoter-plot-container');
    for (var i = 0; i < containers.length; i += 1) syncPlotPlaceholder(containers[i]);
  }

  function boot() {
    scanSpinnerHosts(document);
    scanPlotPlaceholders(document);
    if (typeof MutationObserver !== 'function' || !document.body) return;

    var observer = new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i += 1) {
        var m = mutations[i];
        if (!m || m.type !== 'childList') continue;

        for (var j = 0; j < m.addedNodes.length; j += 1) {
          var node = m.addedNodes[j];
          if (!node || node.nodeType !== 1) continue;
          scanSpinnerHosts(node);
          scanPlotPlaceholders(node);
        }
        var plotContainer = m.target && m.target.closest
          ? m.target.closest('.promoter-plot-container')
          : null;
        if (plotContainer) syncPlotPlaceholder(plotContainer);
      }
    });

    bootObserver = observer;
    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  window.appBuildDnaLoader = buildDnaLoader;
  window.appSyncPlotLoadingPlaceholders = function () {
    scanPlotPlaceholders(document);
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot, { once: true });
  } else {
    boot();
  }

  document.addEventListener('visibilitychange', function () {
    if (document.hidden) {
      if (bootObserver) {
        bootObserver.disconnect();
        bootObserver = null;
      }
      return;
    }
    if (!bootObserver && document.body) {
      boot();
    }
  });
})();
