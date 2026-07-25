/* rounded_rects.js — Aplica border-radius a rects SVG de features de transcritos.
   Se ejecuta en shiny:value y shiny:recalculated (sin MutationObserver en body). */
(function() {
  'use strict';

  function applyRoundedTranscriptFeatureRects(root) {
    var scope = root && root.querySelectorAll ? root : document;
    var nodes = scope.querySelectorAll(
      '.plot-transcript-card .girafe_container_std svg rect[data-id^="feature_"], ' +
      '.plot-transcript-card .girafe_container_std svg rect[data-id^="compact_region_"]'
    );
    if (!nodes || !nodes.length) return;
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].setAttribute('rx', '3.4');
      nodes[i].setAttribute('ry', '3.4');
    }
  }

  function install() {
    if (window.__cgvRoundedFeatureRectObserverInstalled) return;
    window.__cgvRoundedFeatureRectObserverInstalled = true;

    var rafQueued = false;
    var pendingRoots = [];
    var queueApply = function(root) {
      if (root && root.querySelectorAll) pendingRoots.push(root);
      if (rafQueued) return;
      rafQueued = true;
      window.requestAnimationFrame(function() {
        rafQueued = false;
        var roots = pendingRoots;
        pendingRoots = [];
        if (roots.length === 0) {
          applyRoundedTranscriptFeatureRects(document);
        } else {
          for (var i = 0; i < roots.length; i++) {
            applyRoundedTranscriptFeatureRects(roots[i]);
          }
        }
      });
    };

    applyRoundedTranscriptFeatureRects(document);

    document.addEventListener('shiny:value', function(e) { queueApply(e.target); }, true);
    document.addEventListener('shiny:recalculated', function(e) { queueApply(e.target); }, true);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', install, { once: true });
  } else {
    install();
  }

  window.applyRoundedTranscriptFeatureRects = applyRoundedTranscriptFeatureRects;
})();
