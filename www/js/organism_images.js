(function () {
  'use strict';
  if (window.__organismImagesInitialized) return;
  window.__organismImagesInitialized = true;

  var MODAL_ID = 'organism-images-modal-overlay';
  var LOADING_TIMEOUT_MS = 20000;
  var loadingTimer = null;
  var currentOrganism = '';

  /* -- Helpers -------------------------------------------------- */
  function esc(v) {
    return String(v == null ? '' : v)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  /* -- Modal Shell ---------------------------------------------- */
  function ensureModal() {
    var overlay = document.getElementById(MODAL_ID);
    if (overlay) return overlay;

    overlay = document.createElement('div');
    overlay.id = MODAL_ID;
    overlay.className = 'orgimg-modal-overlay';
    overlay.setAttribute('aria-hidden', 'true');
    overlay.innerHTML =
      '<div class="orgimg-modal">' +
        '<div class="orgimg-modal-header">' +
          '<div class="orgimg-modal-title-wrap">' +
            '<div class="orgimg-modal-title"><i class="fa fa-camera"></i> Organism Images</div>' +
            '<div class="orgimg-modal-subtitle">Organism: N/A</div>' +
          '</div>' +
          '<button type="button" class="orgimg-modal-close" aria-label="Close">&times;</button>' +
        '</div>' +
        '<div class="orgimg-modal-body">' +
          '<div class="orgimg-modal-loader" aria-hidden="true">' +
            '<div class="orgimg-spinner"></div>' +
            '<div class="orgimg-loader-text">Searching images on iNaturalist...</div>' +
          '</div>' +
          '<div class="orgimg-modal-error" aria-hidden="true"></div>' +
          '<div class="orgimg-grid-container" aria-hidden="true"></div>' +
          '<div class="orgimg-modal-attribution" aria-hidden="true">' +
            'Images from <a href="https://www.inaturalist.org" target="_blank" rel="noopener">iNaturalist</a> ' +
            '&mdash; community-verified research-grade observations. Click an image to enlarge.' +
          '</div>' +
        '</div>' +
      '</div>';
    document.body.appendChild(overlay);

    /* Close on overlay click */
    overlay.addEventListener('click', function (e) {
      if (e.target === overlay) closeModal();
    });
    /* Close button */
    overlay.querySelector('.orgimg-modal-close').addEventListener('click', closeModal);

    return overlay;
  }

  /* -- Open / Close --------------------------------------------- */
  function openModal(organism, aliases) {
    var overlay = ensureModal();
    currentOrganism = organism;

    /* Update subtitle */
    var sub = overlay.querySelector('.orgimg-modal-subtitle');
    sub.innerHTML = 'Organism: <em>' + esc(organism) + '</em>';

    /* Reset state */
    showLoader(overlay);
    overlay.classList.add('open');
    overlay.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';

    /* Ask R server for images */
    if (window.Shiny && Shiny.setInputValue) {
      Shiny.setInputValue('organism_images_request', {
        organism: organism,
        aliases: aliases || '',
        ts: Date.now()
      }, { priority: 'event' });
    }

    /* Timeout fallback */
    clearTimeout(loadingTimer);
    loadingTimer = setTimeout(function () {
      showError(overlay, 'The request timed out. Please try again later.');
    }, LOADING_TIMEOUT_MS);
  }

  window.openOrganismImages = openModal;

  function closeModal() {
    var overlay = document.getElementById(MODAL_ID);
    if (!overlay) return;
    overlay.classList.remove('open');
    overlay.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
    clearTimeout(loadingTimer);
    /* Uncheck any expanded image */
    var checked = overlay.querySelectorAll('input[type="checkbox"]:checked');
    for (var i = 0; i < checked.length; i++) checked[i].checked = false;
  }

  /* -- State views ---------------------------------------------- */
  function showLoader(overlay) {
    overlay.querySelector('.orgimg-modal-loader').setAttribute('aria-hidden', 'false');
    overlay.querySelector('.orgimg-modal-error').setAttribute('aria-hidden', 'true');
    overlay.querySelector('.orgimg-grid-container').setAttribute('aria-hidden', 'true');
    overlay.querySelector('.orgimg-modal-attribution').setAttribute('aria-hidden', 'true');
  }

  function showError(overlay, msg) {
    clearTimeout(loadingTimer);
    overlay.querySelector('.orgimg-modal-loader').setAttribute('aria-hidden', 'true');
    overlay.querySelector('.orgimg-grid-container').setAttribute('aria-hidden', 'true');
    overlay.querySelector('.orgimg-modal-attribution').setAttribute('aria-hidden', 'true');
    var errEl = overlay.querySelector('.orgimg-modal-error');
    errEl.innerHTML = '<i class="fa fa-exclamation-circle"></i> ' + esc(msg);
    errEl.setAttribute('aria-hidden', 'false');
  }

  function showGrid(overlay, photos) {
    clearTimeout(loadingTimer);
    overlay.querySelector('.orgimg-modal-loader').setAttribute('aria-hidden', 'true');
    overlay.querySelector('.orgimg-modal-error').setAttribute('aria-hidden', 'true');

    var container = overlay.querySelector('.orgimg-grid-container');
    var html = '';
    var count = Math.min(photos.length, 9);

    for (var i = 0; i < count; i++) {
      var p = photos[i];
      var mediumUrl = p.medium || p.url || '';
      var largeUrl = p.large || p.original || mediumUrl;
      var attribution = esc(p.attribution || 'Unknown');
      var license = esc(p.license || '');
      var obsUrl = esc(p.observation_url || '');

      html += '<input type="checkbox" id="orgimg-item-' + i + '" class="orgimg-input" />';
      html += '<label for="orgimg-item-' + i + '" class="orgimg-cell orgimg-cell-' + i + '" ';
      html += 'style="background-image:url(' + esc(mediumUrl) + ');" ';
      html += 'data-large="' + esc(largeUrl) + '" ';
      html += 'title="' + attribution + (license ? ' (' + license + ')' : '') + '">';
      html += '<span class="orgimg-cell-info">';
      html += '<span class="orgimg-cell-attr">' + attribution + '</span>';
      if (obsUrl) {
        html += '<a href="' + obsUrl + '" target="_blank" rel="noopener" class="orgimg-cell-link" onclick="event.stopPropagation();">';
        html += '<i class="fa fa-external-link-alt"></i> iNaturalist</a>';
      }
      html += '</span>';
      html += '</label>';
    }

    container.innerHTML = html;
    container.className = 'orgimg-grid-container orgimg-grid-count-' + count;
    container.setAttribute('aria-hidden', 'false');
    overlay.querySelector('.orgimg-modal-attribution').setAttribute('aria-hidden', 'false');

    /* Swap to large image on expand */
    var inputs = container.querySelectorAll('.orgimg-input');
    for (var j = 0; j < inputs.length; j++) {
      inputs[j].addEventListener('change', (function (idx) {
        return function () {
          var label = container.querySelector('.orgimg-cell-' + idx);
          if (this.checked && label) {
            var lg = label.getAttribute('data-large');
            if (lg) label.style.backgroundImage = 'url(' + lg + ')';
          }
          /* Uncheck others */
          var all = container.querySelectorAll('.orgimg-input');
          for (var k = 0; k < all.length; k++) {
            if (k !== idx) all[k].checked = false;
          }
        };
      })(j));
    }
  }

  /* -- Keyboard ------------------------------------------------- */
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      var overlay = document.getElementById(MODAL_ID);
      if (overlay && overlay.classList.contains('open')) {
        /* If an image is expanded, collapse it first */
        var checked = overlay.querySelector('input[type="checkbox"]:checked');
        if (checked) {
          checked.checked = false;
        } else {
          closeModal();
        }
        e.preventDefault();
      }
    }
  });

  /* -- Button click delegation ---------------------------------- */
  document.addEventListener('click', function (e) {
    var btn = e.target.closest('.footer-orgimg-btn, .summary-organism-images-btn');
    if (!btn) return;

    var organism = (btn.getAttribute('data-orgimg-organism') || '').trim();
    var aliases = (btn.getAttribute('data-orgimg-aliases') || '').trim();
    if (!organism) return;

    openModal(organism, aliases);
  });

  /* -- Shiny message handler ------------------------------------ */
  function registerHandler() {
    if (window.Shiny && Shiny.addCustomMessageHandler) {
      Shiny.addCustomMessageHandler('organism_images_data', function (message) {
        var overlay = document.getElementById(MODAL_ID);
        if (!overlay) return;

        if (message.error) {
          showError(overlay, message.error);
          return;
        }

        var photos = message.photos || [];
        if (photos.length === 0) {
          showError(overlay, 'No images found for this organism on iNaturalist.');
          return;
        }

        /* Update subtitle with common name if available */
        var sub = overlay.querySelector('.orgimg-modal-subtitle');
        var orgName = esc(message.organism || currentOrganism);
        var commonName = message.common_name || '';
        var subtitleHtml = 'Organism: <em>' + orgName + '</em>';
        if (commonName) {
          subtitleHtml += ' &mdash; <strong>' + esc(commonName) + '</strong>';
        }
        subtitleHtml += ' <span class="orgimg-photo-count">(' + photos.length + ' photo' + (photos.length !== 1 ? 's' : '') + ')</span>';
        sub.innerHTML = subtitleHtml;

        showGrid(overlay, photos);
      });
    } else {
      setTimeout(registerHandler, 250);
    }
  }
  registerHandler();

})();
