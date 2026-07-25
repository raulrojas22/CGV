(function () {
  'use strict';
  if (window.__infoButtonRelocatorInitialized) return;
  window.__infoButtonRelocatorInitialized = true;

  function collectCanonicalCards(root) {
    var cards = [];
    var seen = new Set();

    function addCard(node) {
      if (!node || node.nodeType !== 1) return;
      if (!node.matches || !node.matches('.plot-transcript-card.card-canonical')) return;
      var cardId = node.id || node;
      if (seen.has(cardId)) return;
      seen.add(cardId);
      cards.push(node);
    }

    if (root && root.nodeType === 1) {
      addCard(root);
      if (root.closest) addCard(root.closest('.plot-transcript-card.card-canonical'));
      if (root.querySelectorAll) {
        root.querySelectorAll('.plot-transcript-card.card-canonical').forEach(addCard);
      }
    } else {
      document.querySelectorAll('.plot-transcript-card.card-canonical').forEach(addCard);
    }

    return cards;
  }

  function relocateInfoButtons(_root) {
    // Info now belongs in the plot footer alongside Charts and Literature.
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      relocateInfoButtons(document);
    });
  } else {
    relocateInfoButtons(document);
  }

  var observer = new MutationObserver(function (mutations) {
    mutations.forEach(function (mutation) {
      if (!mutation.addedNodes || mutation.addedNodes.length === 0) return;
      mutation.addedNodes.forEach(function (node) {
        if (!node || node.nodeType !== 1) return;
        relocateInfoButtons(node);
      });
    });
  });

  if (document.body) {
    observer.observe(document.body, { childList: true, subtree: true });
  }
})();
