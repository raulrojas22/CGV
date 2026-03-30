/* ──────────────────────────────────────────────────────────────
   NCBI Search — keyboard helpers, debounce, and button guards
   ────────────────────────────────────────────────────────────── */
(function () {
  'use strict';

  /* Allow Enter key to trigger the search button */
  function bindEnterSearch(inputId, btnId) {
    $(document).on('keydown', '#' + inputId, function (e) {
      if (e.key === 'Enter' || e.keyCode === 13) {
        e.preventDefault();
        var btn = document.getElementById(btnId);
        if (btn && !btn.disabled) btn.click();
      }
    });
  }

  /* Disable a button while Shiny is busy (prevents double-clicks) */
  function guardDownloadButton(btnId) {
    $(document).on('click', '#' + btnId, function () {
      var btn = this;
      if (btn.dataset.ncbiLocked === 'true') return false;
      btn.dataset.ncbiLocked = 'true';
      btn.disabled = true;
      var origText = btn.innerHTML;
      btn.innerHTML = '<i class="fa fa-spinner fa-spin"></i> Working...';

      /* Re-enable when Shiny becomes idle again */
      var handler = function (e) {
        btn.disabled = false;
        btn.dataset.ncbiLocked = 'false';
        btn.innerHTML = origText;
        $(document).off('shiny:idle', handler);
      };
      $(document).on('shiny:idle', handler);

      /* Safety: re-enable after 10 minutes max */
      setTimeout(function () {
        btn.disabled = false;
        btn.dataset.ncbiLocked = 'false';
        btn.innerHTML = origText;
        $(document).off('shiny:idle', handler);
      }, 600000);
    });
  }

  $(document).on('shiny:connected', function () {

    /* ── Custom message handlers for preloaded redirect ─────── */

    /**
     * ncbi_select_preloaded: switch homo preloaded grid to a specific species.
     * Waits briefly for the conditionalPanel to render, then triggers the
     * species-grid tile click via Shiny.setInputValue.
     */
    Shiny.addCustomMessageHandler('ncbi_select_preloaded', function (msg) {
      setTimeout(function () {
        Shiny.setInputValue(msg.input_id, msg.species_id, { priority: 'event' });
        /* Also try to visually click the tile if it exists */
        var tile = document.querySelector(
          '[data-species-id="' + msg.species_id + '"]'
        );
        if (tile) tile.click();
      }, 300);
    });


    /* Homologous */
    bindEnterSearch('homo_ncbi_query', 'homo_ncbi_search_btn');
    guardDownloadButton('homo_ncbi_download_btn');
    /* Orthologous */
    bindEnterSearch('ortho_ncbi_query', 'ortho_ncbi_search_btn');
    guardDownloadButton('ortho_ncbi_download_all_btn');
  });
})();
