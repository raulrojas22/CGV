(function () {
  'use strict';

  if (window.__cgvActivityFeedbackInitialized) return;
  window.__cgvActivityFeedbackInitialized = true;

  var DEFAULT_DELAY_MS = 280;
  var MIN_VISIBLE_MS = 420;
  var MAX_SOURCE_AGE_MS = 10 * 60 * 1000;
  var sources = Object.create(null);
  var showTimer = null;
  var hideTimer = null;
  var visibleSince = 0;

  function clean(value, fallback) {
    var text = String(value == null ? '' : value).replace(/\s+/g, ' ').trim();
    return text || String(fallback || '');
  }

  function indicator() {
    return document.getElementById('app-work-indicator');
  }

  function clearTimer(name) {
    if (name === 'show' && showTimer) {
      window.clearTimeout(showTimer);
      showTimer = null;
    }
    if (name === 'hide' && hideTimer) {
      window.clearTimeout(hideTimer);
      hideTimer = null;
    }
  }

  function activeSources() {
    var now = Date.now();
    Object.keys(sources).forEach(function (key) {
      if (now - sources[key].updatedAt > MAX_SOURCE_AGE_MS) delete sources[key];
    });
    return Object.keys(sources).map(function (key) { return sources[key]; });
  }

  function bestSource() {
    var active = activeSources();
    if (!active.length) return null;
    active.sort(function (a, b) {
      if (a.priority !== b.priority) return b.priority - a.priority;
      return b.updatedAt - a.updatedAt;
    });
    return active[0];
  }

  function updateCopy(source) {
    var headline = document.getElementById('app-work-indicator-headline');
    var detail = document.getElementById('app-work-indicator-detail');
    if (headline) headline.textContent = source.headline;
    if (detail) detail.textContent = source.detail;
  }

  function show(source) {
    var node = indicator();
    if (!node || !source) return;
    clearTimer('show');
    clearTimer('hide');
    updateCopy(source);
    node.hidden = false;
    node.setAttribute('aria-hidden', 'false');
    node.classList.add('is-visible');
    document.documentElement.setAttribute('data-app-working', 'true');
    if (!visibleSince) visibleSince = Date.now();
  }

  function hideNow() {
    var node = indicator();
    clearTimer('show');
    clearTimer('hide');
    if (node) {
      node.classList.remove('is-visible');
      node.hidden = true;
      node.setAttribute('aria-hidden', 'true');
    }
    document.documentElement.removeAttribute('data-app-working');
    visibleSince = 0;
  }

  function render() {
    var source = bestSource();
    var node = indicator();
    if (!source) {
      clearTimer('show');
      if (!node || node.hidden || !visibleSince) {
        hideNow();
        return;
      }
      var remaining = Math.max(0, MIN_VISIBLE_MS - (Date.now() - visibleSince));
      clearTimer('hide');
      hideTimer = window.setTimeout(hideNow, remaining);
      return;
    }

    clearTimer('hide');
    updateCopy(source);
    if (node && !node.hidden) return;

    var wait = Math.max(0, source.showAfter - Date.now());
    clearTimer('show');
    showTimer = window.setTimeout(function () {
      var current = bestSource();
      if (current) show(current);
    }, wait);
  }

  function begin(sourceId, options) {
    var id = clean(sourceId, 'activity');
    var opts = options || {};
    var now = Date.now();
    var existing = sources[id];
    var delay = Math.max(0, Number(opts.delay == null ? DEFAULT_DELAY_MS : opts.delay) || 0);
    sources[id] = {
      id: id,
      headline: clean(opts.headline, existing ? existing.headline : 'CGV is working'),
      detail: clean(opts.detail, existing ? existing.detail : 'Processing data…'),
      priority: Number(opts.priority == null ? (existing ? existing.priority : 20) : opts.priority) || 0,
      startedAt: existing ? existing.startedAt : now,
      updatedAt: now,
      showAfter: existing ? existing.showAfter : now + delay
    };
    render();
    return id;
  }

  function end(sourceId) {
    var id = clean(sourceId, 'activity');
    if (Object.prototype.hasOwnProperty.call(sources, id)) delete sources[id];
    render();
  }

  function clearAll() {
    sources = Object.create(null);
    hideNow();
  }

  function inferBusyDetail() {
    var activePane = document.querySelector('.app-main > .tab-content > .tab-pane.active');
    var paneText = activePane ? String(activePane.id || '') : '';
    var studio = document.querySelector('.figure-studio-page');
    if (/figure.?studio/i.test(paneText) || (studio && studio.offsetParent !== null)) {
      return 'Updating Figure Studio…';
    }
    var analyticsBody = activePane && activePane.querySelector('.analytics-body');
    if (
      activePane &&
      (
        activePane.querySelector('.analytics-chart-wrap .recalculating') ||
        (analyticsBody && analyticsBody.style.display !== 'none')
      )
    ) {
      return 'Generating statistical analysis…';
    }
    if (activePane && activePane.querySelector('.promoter-plot-container, .plot-transcript-card')) {
      return 'Rendering gene visualization…';
    }
    return 'Processing data and updating the interface…';
  }

  window.cgvActivity = {
    begin: begin,
    update: begin,
    end: end,
    clear: clearAll,
    isActive: function (sourceId) {
      return Object.prototype.hasOwnProperty.call(sources, clean(sourceId, 'activity'));
    }
  };

  document.addEventListener('cgv:activity', function (event) {
    var detail = event && event.detail ? event.detail : {};
    if (detail.action === 'end') end(detail.source);
    else if (detail.action === 'clear') clearAll();
    else begin(detail.source, detail);
  });

  function shinyBusy() {
    begin('shiny', {
      headline: 'CGV is working',
      detail: inferBusyDetail(),
      priority: 5,
      delay: 360
    });
  }

  function shinyIdle() {
    end('shiny');
  }

  if (window.jQuery) {
    window.jQuery(document).on('shiny:busy', shinyBusy);
    window.jQuery(document).on('shiny:idle', shinyIdle);
    window.jQuery(document).on('shiny:disconnected', clearAll);
  } else {
    document.addEventListener('shiny:busy', shinyBusy);
    document.addEventListener('shiny:idle', shinyIdle);
    document.addEventListener('shiny:disconnected', clearAll);
  }

  window.addEventListener('pagehide', clearAll);
  if (document.readyState !== 'loading') render();
  else document.addEventListener('DOMContentLoaded', render, { once: true });
})();
