(function () {
  'use strict';

  var INTERSECTION_TARGETS = [
    { sentinelId: 'ortho-load-more-sentinel', buttonId: 'ortho_load_more' },
    { sentinelId: 'homo-load-more-sentinel', buttonId: 'homo_load_more' }
  ];
  var ioMap = {};
  var bindTimer = null;
  var hasUserScrolled = false;
  var pendingByButton = {};
  var CLICK_COOLDOWN_MS = 900;

  function markUserScrolled() {
    hasUserScrolled = true;
  }

  function clearIntersectionObserver(buttonId) {
    var io = ioMap[buttonId];
    if (io && typeof io.disconnect === 'function') {
      io.disconnect();
    }
    ioMap[buttonId] = null;
  }

  function scheduleBind() {
    if (bindTimer) {
      clearTimeout(bindTimer);
    }
    bindTimer = setTimeout(function () {
      bindTimer = null;
      bindIntersectionObservers();
    }, 80);
  }

  function safeAutoClick(buttonId) {
    var btn = document.getElementById(buttonId);
    if ((btn && btn.disabled) || pendingByButton[buttonId] || !hasUserScrolled) return;
    pendingByButton[buttonId] = true;
    if (window.Shiny && typeof Shiny.setInputValue === 'function') {
      Shiny.setInputValue(buttonId, Date.now(), { priority: 'event' });
    } else if (btn) {
      btn.click();
    } else {
      pendingByButton[buttonId] = false;
      return;
    }
    setTimeout(function () {
      pendingByButton[buttonId] = false;
      scheduleBind();
    }, CLICK_COOLDOWN_MS);
  }

  function bindIntersectionObservers() {
    for (var i = 0; i < INTERSECTION_TARGETS.length; i += 1) {
      var cfg = INTERSECTION_TARGETS[i];
      clearIntersectionObserver(cfg.buttonId);
    }
    if (typeof IntersectionObserver !== 'function') return;

    for (var j = 0; j < INTERSECTION_TARGETS.length; j += 1) {
      var targetCfg = INTERSECTION_TARGETS[j];
      var sentinel = document.getElementById(targetCfg.sentinelId);
      if (!sentinel) continue;

      ioMap[targetCfg.buttonId] = new IntersectionObserver((function (buttonId) {
        return function (entries) {
          if (!entries || !entries.length) return;
          for (var k = 0; k < entries.length; k += 1) {
            if (entries[k] && entries[k].isIntersecting) {
              safeAutoClick(buttonId);
              break;
            }
          }
        };
      })(targetCfg.buttonId), {
        root: null,
        rootMargin: '0px 0px 240px 0px',
        threshold: 0.01
      });

      ioMap[targetCfg.buttonId].observe(sentinel);
    }
  }

  function bindLifecycleSignals() {
    window.addEventListener('resize', scheduleBind, { passive: true });
    document.addEventListener('shown.bs.tab', scheduleBind);
    document.addEventListener('shiny:value', scheduleBind);
  }

  function bindUserSignals() {
    window.addEventListener('scroll', markUserScrolled, { passive: true });
    window.addEventListener('wheel', markUserScrolled, { passive: true });
    window.addEventListener('touchmove', markUserScrolled, { passive: true });

    document.addEventListener('click', function (ev) {
      var target = ev && ev.target;
      if (!target || !target.closest) return;
      var btn = target.closest('#ortho_load_more, #homo_load_more');
      if (!btn || !btn.id) return;
      hasUserScrolled = true;
      pendingByButton[btn.id] = true;
      setTimeout(function () {
        pendingByButton[btn.id] = false;
      }, CLICK_COOLDOWN_MS);
    });
  }

  function boot() {
    bindUserSignals();
    bindLifecycleSignals();
    bindIntersectionObservers();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot, { once: true });
  } else {
    boot();
  }
})();
