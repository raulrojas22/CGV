(function () {
  'use strict';

  if (window.CGVResultWorkspace) return;

  var PRIMARY_VIEWS = ['visualization', 'alignment'];
  var ALIGNMENT_MODES = ['aligned', 'pip_blocks', 'pip_multipip'];
  var VALID_VIEWS = PRIMARY_VIEWS.concat(['analytics', 'table']);
  var states = {
    homo: { view: 'visualization', lastPrimary: 'visualization', primaryScrollTop: 0, alignmentMode: 'aligned' },
    ortho: { view: 'visualization', lastPrimary: 'visualization', primaryScrollTop: 0, alignmentMode: 'aligned' }
  };

  function normalizeScope(scope) {
    return String(scope || '').toLowerCase() === 'ortho' ? 'ortho' : 'homo';
  }

  function normalizeView(view) {
    var next = String(view || '').toLowerCase();
    return VALID_VIEWS.indexOf(next) === -1 ? 'visualization' : next;
  }

  function rootFor(scope) {
    return document.getElementById(normalizeScope(scope) + '_result_workspace_subheader');
  }

  function paneFor(scope) {
    var root = rootFor(scope);
    return root && root.closest ? root.closest('.app-main-pane-search-results') : null;
  }

  function isPrimary(view) {
    return PRIMARY_VIEWS.indexOf(view) !== -1;
  }

  function normalizeAlignmentMode(mode) {
    var next = String(mode || '').toLowerCase();
    return ALIGNMENT_MODES.indexOf(next) === -1 ? 'aligned' : next;
  }

  function updateAlignmentMethodChrome(scope) {
    var root = rootFor(scope);
    var state = states[normalizeScope(scope)];
    if (!root || !state) return;
    var activeMode = normalizeAlignmentMode(state.alignmentMode);
    root.querySelectorAll('[data-workspace-alignment-method]').forEach(function (button) {
      var active = String(button.getAttribute('data-workspace-alignment-method') || '') === activeMode;
      button.classList.toggle('is-active', active);
      button.setAttribute('aria-pressed', active ? 'true' : 'false');
    });
  }

  function closeMenus(scope, exceptName) {
    var root = rootFor(scope);
    if (!root) return;
    root.querySelectorAll('[data-workspace-menu]').forEach(function (menu) {
      var name = String(menu.getAttribute('data-workspace-menu') || '');
      var keepOpen = !!exceptName && name === exceptName;
      menu.classList.toggle('is-open', keepOpen);
    });
    root.querySelectorAll('[data-workspace-menu-trigger]').forEach(function (trigger) {
      var name = String(trigger.getAttribute('data-workspace-menu-trigger') || '');
      trigger.classList.toggle('is-active', !!exceptName && name === exceptName);
      trigger.setAttribute('aria-expanded', !!exceptName && name === exceptName ? 'true' : 'false');
    });
  }

  function updateChrome(scope, view) {
    var root = rootFor(scope);
    var pane = paneFor(scope);
    if (!root || !pane) return;

    VALID_VIEWS.forEach(function (name) {
      pane.classList.toggle('result-workspace-view-' + name, name === view);
    });
    pane.setAttribute('data-result-workspace-view', view);

    root.querySelectorAll('[data-workspace-view]').forEach(function (button) {
      var active = String(button.getAttribute('data-workspace-view') || '') === view;
      button.classList.toggle('is-active', active);
      button.setAttribute('aria-pressed', active ? 'true' : 'false');
      button.setAttribute('aria-selected', active ? 'true' : 'false');
    });

    var derived = !isPrimary(view);
    root.classList.toggle('is-derived-view', derived);
    root.classList.toggle('is-primary-view', !derived);
    root.setAttribute('data-active-view', view);
    updateAlignmentMethodChrome(scope);
  }

  function updatePanelVisibility(scope, view) {
    var analyticsBody = document.getElementById(scope + '_analytics_body');
    var tableBody = document.getElementById(scope + '_summary_body');
    if (analyticsBody) analyticsBody.style.display = view === 'analytics' ? 'block' : 'none';
    if (tableBody) tableBody.style.display = view === 'table' ? 'block' : 'none';
  }

  function notifyPrimaryMode(scope, view) {
    if (!window.Shiny || typeof window.Shiny.setInputValue !== 'function') return;
    var pick = view === 'alignment' ? normalizeAlignmentMode(states[scope].alignmentMode) : 'visualize';
    window.Shiny.setInputValue(scope + '_header_mode_pick', pick, { priority: 'event' });
  }

  function notifyAlignmentMethod(scope, method) {
    if (!window.Shiny || typeof window.Shiny.setInputValue !== 'function') return;
    window.Shiny.setInputValue(scope + '_header_mode_pick', normalizeAlignmentMode(method), { priority: 'event' });
  }

  function notifyWorkspaceView(scope, view) {
    if (!window.Shiny || typeof window.Shiny.setInputValue !== 'function') return;
    window.Shiny.setInputValue(scope + '_workspace_view', view, { priority: 'event' });
  }

  function scheduleReflow(scope, view) {
    window.setTimeout(function () {
      try {
        window.dispatchEvent(new Event('resize'));
      } catch (err) {}
      try {
        document.dispatchEvent(new CustomEvent('cgv:workspace-view', {
          detail: { scope: scope, view: view }
        }));
      } catch (err) {}
    }, 80);
  }

  function setView(scope, requestedView, options) {
    scope = normalizeScope(scope);
    var view = normalizeView(requestedView);
    var opts = options || {};
    var state = states[scope];
    var pane = paneFor(scope);
    var root = rootFor(scope);
    if (!state || !pane || !root) return false;

    var targetButton = root.querySelector('[data-workspace-view="' + view + '"]');
    if (targetButton && targetButton.disabled && opts.force !== true) return false;

    var previous = state.view;
    if (isPrimary(previous)) {
      state.lastPrimary = previous;
      if (!isPrimary(view)) state.primaryScrollTop = pane.scrollTop || 0;
    }
    if (isPrimary(view)) state.lastPrimary = view;
    state.view = view;

    closeMenus(scope);
    updateChrome(scope, view);
    updatePanelVisibility(scope, view);

    if (opts.notify !== false) notifyWorkspaceView(scope, view);

    if (isPrimary(view) && opts.syncMode !== false) notifyPrimaryMode(scope, view);

    if (!isPrimary(view)) {
      if (opts.restoreScroll !== false) pane.scrollTop = 0;
    } else if (opts.restoreScroll !== false && !isPrimary(previous)) {
      window.requestAnimationFrame(function () {
        pane.scrollTop = Math.max(0, state.primaryScrollTop || 0);
      });
    }

    scheduleReflow(scope, view);
    return true;
  }

  function bindRoot(root) {
    if (!root || root.getAttribute('data-workspace-ready') === '1') return;
    root.setAttribute('data-workspace-ready', '1');
    var scope = normalizeScope(root.getAttribute('data-workspace-scope'));

    root.addEventListener('click', function (event) {
      var target = event.target && event.target.closest ? event.target.closest('button') : null;
      if (!target || !root.contains(target)) return;

      var alignmentMethod = target.getAttribute('data-workspace-alignment-method');
      if (alignmentMethod) {
        alignmentMethod = normalizeAlignmentMode(alignmentMethod);
        states[scope].alignmentMode = alignmentMethod;
        setView(scope, 'alignment', { syncMode: false, restoreScroll: false });
        updateAlignmentMethodChrome(scope);
        notifyAlignmentMethod(scope, alignmentMethod);
        return;
      }

      var view = target.getAttribute('data-workspace-view');
      if (view) {
        if (!target.disabled) setView(scope, view);
        return;
      }

      if (target.hasAttribute('data-workspace-back')) {
        setView(scope, 'visualization');
        return;
      }

      var menuName = target.getAttribute('data-workspace-menu-trigger');
      if (menuName) {
        event.preventDefault();
        if (target.disabled) return;
        var menu = root.querySelector('[data-workspace-menu="' + menuName + '"]');
        closeMenus(scope, menu && menu.classList.contains('is-open') ? null : menuName);
        return;
      }

      if (target.classList.contains('result-workspace-menu-close')) {
        event.preventDefault();
        closeMenus(scope);
      }
    });

    updateChrome(scope, states[scope].view);
  }

  function bindAll() {
    document.querySelectorAll('.result-workspace-subheader[data-workspace-scope]').forEach(bindRoot);
  }

  document.addEventListener('click', function (event) {
    var viewBack = event.target && event.target.closest
      ? event.target.closest('.result-workspace-view-back[data-workspace-back]')
      : null;
    if (viewBack) {
      event.preventDefault();
      setView(viewBack.getAttribute('data-workspace-scope'), 'visualization');
      return;
    }

    var openMenu = document.querySelector('.result-workspace-menu.is-open');
    if (!openMenu) return;
    var root = openMenu.closest('.result-workspace-subheader');
    if (!root || root.contains(event.target)) return;
    closeMenus(root.getAttribute('data-workspace-scope'));
  });

  document.addEventListener('keydown', function (event) {
    if (event.key !== 'Escape') return;
    document.querySelectorAll('.result-workspace-subheader').forEach(function (root) {
      closeMenus(root.getAttribute('data-workspace-scope'));
    });
  });

  document.addEventListener('change', function (event) {
    var target = event && event.target ? event.target : null;
    if (!target) return;
    var name = String(target.name || '');
    if (name !== 'homo_visual_mode' && name !== 'ortho_visual_mode') return;
    var scope = name.indexOf('ortho_') === 0 ? 'ortho' : 'homo';
    var targetMode = String(target.value || '');
    var nextPrimary = ALIGNMENT_MODES.indexOf(targetMode) !== -1
      ? 'alignment'
      : 'visualization';
    if (nextPrimary === 'alignment') {
      states[scope].alignmentMode = normalizeAlignmentMode(targetMode);
      updateAlignmentMethodChrome(scope);
    }
    states[scope].lastPrimary = nextPrimary;
    if (isPrimary(states[scope].view)) {
      setView(scope, nextPrimary, { syncMode: false, restoreScroll: false });
    }
  }, true);

  function boot() {
    bindAll();
    ['homo', 'ortho'].forEach(function (scope) {
      setView(scope, states[scope].view, { syncMode: false, restoreScroll: false });
    });

    if (typeof MutationObserver === 'function' && document.body) {
      var observer = new MutationObserver(bindAll);
      observer.observe(document.body, { childList: true, subtree: true });
    }
  }

  window.CGVResultWorkspace = {
    setView: setView,
    closeMenus: closeMenus,
    getState: function (scope) {
      scope = normalizeScope(scope);
      return Object.assign({}, states[scope]);
    }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot, { once: true });
  } else {
    boot();
  }

})();
