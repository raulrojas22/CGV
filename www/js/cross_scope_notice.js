(function () {
  'use strict';

  var STORAGE_KEY = 'cgv-cross-species-scope-seen-v1';
  var AUTO_COLLAPSE_MS = 9000;
  var observer = null;

  function wasSeen() {
    try {
      return window.sessionStorage.getItem(STORAGE_KEY) === '1';
    } catch (_) {
      return false;
    }
  }

  function markSeen() {
    try {
      window.sessionStorage.setItem(STORAGE_KEY, '1');
    } catch (_) {}
  }

  function prepareNotice(notice) {
    if (!notice || notice.dataset.crossScopeReady === '1') return;
    notice.dataset.crossScopeReady = '1';

    if (wasSeen()) {
      notice.removeAttribute('open');
    } else {
      notice.setAttribute('open', '');
      window.setTimeout(function () {
        if (!notice.isConnected || notice.dataset.crossScopeInteracted === '1') return;
        notice.removeAttribute('open');
        markSeen();
      }, AUTO_COLLAPSE_MS);
    }

    notice.addEventListener('toggle', function () {
      if (!notice.open) return;
      notice.dataset.crossScopeInteracted = '1';
      markSeen();
    });
  }

  function hydrate(root) {
    var scope = root && root.querySelectorAll ? root : document;
    scope.querySelectorAll('[data-cross-scope-notice]').forEach(prepareNotice);
  }

  function init() {
    hydrate(document);
    observer = new MutationObserver(function (mutations) {
      mutations.forEach(function (mutation) {
        mutation.addedNodes.forEach(function (node) {
          if (!node || node.nodeType !== 1) return;
          if (node.matches && node.matches('[data-cross-scope-notice]')) prepareNotice(node);
          hydrate(node);
        });
      });
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init, { once: true });
  } else {
    init();
  }
})();
