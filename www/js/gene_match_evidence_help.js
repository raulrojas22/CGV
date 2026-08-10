(function () {
  'use strict';

  if (window.__cgvGeneMatchEvidenceHelpInitialized) return;
  window.__cgvGeneMatchEvidenceHelpInitialized = true;

  var SELECTOR = '.gene-match-help[data-evidence-help="true"]';
  var tooltip = null;
  var activeTrigger = null;
  var hideTimer = null;

  function buildTooltip() {
    if (tooltip && tooltip.isConnected) return tooltip;
    tooltip = document.createElement('div');
    tooltip.id = 'gene-match-evidence-tooltip';
    tooltip.className = 'gene-match-evidence-tooltip';
    tooltip.setAttribute('role', 'tooltip');
    tooltip.setAttribute('aria-hidden', 'true');
    tooltip.innerHTML = [
      '<div class="gene-match-evidence-tooltip-header">',
      '<span class="gene-match-evidence-tooltip-header-icon" aria-hidden="true"><i class="fas fa-link"></i></span>',
      '<span>Evidence confidence</span>',
      '</div>',
      '<p class="gene-match-evidence-tooltip-summary">How closely this name maps to the annotation.</p>',
      '<div class="gene-match-evidence-levels">',
      '<div class="gene-match-evidence-level"><span class="gene-match-evidence-badge gene-match-evidence-badge--high">High</span><span class="gene-match-evidence-level-copy">Stable gene, transcript or protein ID</span></div>',
      '<div class="gene-match-evidence-level"><span class="gene-match-evidence-badge gene-match-evidence-badge--medium">Medium</span><span class="gene-match-evidence-level-copy">Name, alias, synonym or database link</span></div>',
      '<div class="gene-match-evidence-level"><span class="gene-match-evidence-badge gene-match-evidence-badge--low">Low</span><span class="gene-match-evidence-level-copy">Descriptive term; verify before plotting</span></div>',
      '</div>',
      '<p class="gene-match-evidence-tooltip-note">This is identifier confidence, not experimental evidence.</p>'
    ].join('');
    document.body.appendChild(tooltip);
    return tooltip;
  }

  function positionTooltip() {
    if (!activeTrigger || !tooltip || !tooltip.classList.contains('is-visible')) return;
    var triggerRect = activeTrigger.getBoundingClientRect();
    var tipRect = tooltip.getBoundingClientRect();
    var margin = 10;
    var gap = 9;
    var left = triggerRect.left + triggerRect.width / 2 - tipRect.width / 2;
    left = Math.max(margin, Math.min(left, window.innerWidth - tipRect.width - margin));

    var spaceAbove = triggerRect.top - gap;
    var placeBelow = spaceAbove < tipRect.height + margin;
    var top = placeBelow
      ? triggerRect.bottom + gap
      : triggerRect.top - tipRect.height - gap;
    top = Math.max(margin, Math.min(top, window.innerHeight - tipRect.height - margin));

    tooltip.dataset.placement = placeBelow ? 'bottom' : 'top';
    tooltip.style.left = Math.round(left) + 'px';
    tooltip.style.top = Math.round(top) + 'px';
  }

  function show(trigger) {
    window.clearTimeout(hideTimer);
    var node = buildTooltip();
    if (activeTrigger && activeTrigger !== trigger) {
      activeTrigger.setAttribute('aria-expanded', 'false');
      activeTrigger.removeAttribute('aria-describedby');
    }
    activeTrigger = trigger;
    activeTrigger.setAttribute('aria-expanded', 'true');
    activeTrigger.setAttribute('aria-describedby', node.id);
    node.setAttribute('aria-hidden', 'false');
    node.classList.add('is-visible');
    positionTooltip();
  }

  function hide(immediate) {
    window.clearTimeout(hideTimer);
    var close = function () {
      if (activeTrigger) {
        activeTrigger.setAttribute('aria-expanded', 'false');
        activeTrigger.removeAttribute('aria-describedby');
      }
      activeTrigger = null;
      if (tooltip) {
        tooltip.classList.remove('is-visible');
        tooltip.setAttribute('aria-hidden', 'true');
      }
    };
    if (immediate) close();
    else hideTimer = window.setTimeout(close, 80);
  }

  document.addEventListener('pointerover', function (event) {
    var trigger = event.target && event.target.closest ? event.target.closest(SELECTOR) : null;
    if (trigger) show(trigger);
  });

  document.addEventListener('pointerout', function (event) {
    var trigger = event.target && event.target.closest ? event.target.closest(SELECTOR) : null;
    if (trigger && !trigger.contains(event.relatedTarget)) hide(false);
  });

  document.addEventListener('focusin', function (event) {
    var trigger = event.target && event.target.closest ? event.target.closest(SELECTOR) : null;
    if (trigger) show(trigger);
  });

  document.addEventListener('focusout', function (event) {
    var trigger = event.target && event.target.closest ? event.target.closest(SELECTOR) : null;
    if (trigger) hide(false);
  });

  document.addEventListener('click', function (event) {
    var trigger = event.target && event.target.closest ? event.target.closest(SELECTOR) : null;
    if (trigger) {
      event.preventDefault();
      event.stopPropagation();
      if (activeTrigger === trigger && tooltip && tooltip.classList.contains('is-visible')) hide(true);
      else show(trigger);
      return;
    }
    if (activeTrigger) hide(true);
  }, true);

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && activeTrigger) hide(true);
  });

  window.addEventListener('resize', positionTooltip);
  document.addEventListener('scroll', positionTooltip, true);
})();
