(function () {
  'use strict';
  if (window.__papersPopupInitialized) return;
  window.__papersPopupInitialized = true;

  var MODAL_ID = 'papers-modal-overlay';
  var LOADING_TIMEOUT_MS = 45000;
  var loadingTimer = null;
  var currentState = {
    gene: '',
    geneSynonyms: '',
    organism: '',
    organismAliases: '',
    page: 1,
    pageSize: 10,
    sortBy: 'CITED desc',
    requestId: ''
  };

  /* ── Helpers ───────────────────────────────────────────────── */
  function esc(v) {
    return String(v == null ? '' : v)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function txt(v) { return String(v == null ? '' : v); }

  function truncate(s, max) {
    s = String(s || '');
    if (s.length <= max) return s;
    return s.substring(0, max) + '…';
  }

  function formatNumber(n) {
    var num = parseInt(n, 10);
    if (isNaN(num)) return '0';
    return num.toLocaleString();
  }

  /* ── Modal Creation ────────────────────────────────────────── */
  function ensureModal() {
    var overlay = document.getElementById(MODAL_ID);
    if (overlay) return overlay;

    overlay = document.createElement('div');
    overlay.id = MODAL_ID;
    overlay.className = 'papers-modal-overlay';
    overlay.setAttribute('aria-hidden', 'true');
    overlay.innerHTML =
      '<div class="papers-modal">' +
        '<div class="papers-modal-header">' +
          '<div class="papers-modal-title-wrap">' +
            '<div class="papers-modal-title"><i class="fa fa-file-alt"></i> Scientific Literature</div>' +
            '<div class="papers-modal-subtitle">Gene: N/A | Organism: N/A</div>' +
          '</div>' +
          '<button type="button" class="papers-modal-close" aria-label="Close">&times;</button>' +
        '</div>' +
        '<div class="papers-modal-toolbar">' +
          '<div class="papers-toolbar-left">' +
            '<div class="papers-search-wrap">' +
              '<i class="fa fa-search papers-search-icon"></i>' +
              '<input type="text" class="papers-search-input" placeholder="Filter by author, title, journal..." />' +
            '</div>' +
          '</div>' +
          '<div class="papers-toolbar-right">' +
            '<label class="papers-sort-label">Sort:</label>' +
            '<select class="papers-sort-select">' +
              '<option value="CITED desc">Most cited</option>' +
              '<option value="DATE desc">Newest first</option>' +
              '<option value="DATE asc">Oldest first</option>' +
              '<option value="RELEVANCE">Relevance</option>' +
            '</select>' +
          '</div>' +
        '</div>' +
        '<div class="papers-modal-body">' +
          '<div class="papers-modal-loader" aria-hidden="true">' +
            '<div class="app-dna-loader app-dna-loader--popup">' +
              '<div class="app-dna-wave app-dna-wave-top">' +
                Array.from({length: 16}, function(_, i) {
                  return '<span class="app-dna-node" style="--i:' + i + ';"></span>';
                }).join('') +
              '</div>' +
              '<div class="app-dna-wave app-dna-wave-bottom">' +
                Array.from({length: 16}, function(_, i) {
                  return '<span class="app-dna-node" style="--i:' + i + ';"></span>';
                }).join('') +
              '</div>' +
            '</div>' +
            '<p class="papers-loader-text">Searching papers in Europe PMC...</p>' +
          '</div>' +
          '<div class="papers-summary"></div>' +
          '<div class="papers-list"></div>' +
          '<div class="papers-empty" style="display:none;"></div>' +
        '</div>' +
        '<div class="papers-modal-footer">' +
          '<div class="papers-pagination"></div>' +
          '<div class="papers-page-info"></div>' +
        '</div>' +
      '</div>';

    document.body.appendChild(overlay);
    bindModalEvents(overlay);
    return overlay;
  }

  function getModal() { return document.getElementById(MODAL_ID); }
  function isOpen() {
    var m = getModal();
    return !!(m && m.classList.contains('open'));
  }

  /* ── Events ────────────────────────────────────────────────── */
  function bindModalEvents(overlay) {
    // Close button
    overlay.querySelector('.papers-modal-close').addEventListener('click', function (e) {
      e.stopPropagation();
      closeModal();
    });

    // Click backdrop
    overlay.addEventListener('click', function (e) {
      if (e.target === overlay) closeModal();
    });

    // Sort change
    overlay.querySelector('.papers-sort-select').addEventListener('change', function () {
      currentState.sortBy = this.value;
      currentState.page = 1;
      sendSearchRequest();
    });

    // Client-side filter
    var searchInput = overlay.querySelector('.papers-search-input');
    var filterTimer = null;
    searchInput.addEventListener('input', function () {
      if (filterTimer) clearTimeout(filterTimer);
      filterTimer = setTimeout(function () {
        applyClientFilter(searchInput.value);
      }, 300);
    });
  }

  function applyClientFilter(query) {
    var modal = getModal();
    if (!modal) return;
    var cards = modal.querySelectorAll('.papers-card');
    var q = query.toLowerCase().trim();
    var visibleCount = 0;
    cards.forEach(function (card) {
      var text = (card.getAttribute('data-filter-text') || '').toLowerCase();
      var match = !q || text.indexOf(q) >= 0;
      card.style.display = match ? '' : 'none';
      if (match) visibleCount++;
    });
    var emptyEl = modal.querySelector('.papers-empty');
    if (visibleCount === 0 && cards.length > 0 && q) {
      emptyEl.style.display = '';
      emptyEl.innerHTML = '<div class="papers-empty-icon"><i class="fa fa-filter"></i></div>' +
        '<p>No papers match your filter "<strong>' + esc(q) + '</strong>" on this page.</p>' +
        '<p class="papers-empty-hint">Try a different term or go to another page.</p>';
    } else {
      emptyEl.style.display = 'none';
    }
  }

  /* ── Open / Close ──────────────────────────────────────────── */
  function openModal(button) {
    if (!button) return;
    clearLoadingTimer();

    var gene = txt(button.getAttribute('data-papers-gene')).trim();
    var synonyms = txt(button.getAttribute('data-papers-gene-synonyms')).trim();
    var organism = txt(button.getAttribute('data-papers-organism')).trim();
    var aliases = txt(button.getAttribute('data-papers-organism-aliases')).trim();

    currentState.gene = gene;
    currentState.geneSynonyms = synonyms;
    currentState.organism = organism;
    currentState.organismAliases = aliases;
    currentState.page = 1;
    currentState.requestId = String(Date.now()) + '_' + String(Math.floor(Math.random() * 1e6));

    var overlay = ensureModal();
    var sortSelect = overlay.querySelector('.papers-sort-select');
    if (sortSelect) sortSelect.value = currentState.sortBy;
    var searchInput = overlay.querySelector('.papers-search-input');
    if (searchInput) searchInput.value = '';

    renderLoading(overlay);

    overlay.classList.add('open');
    overlay.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';

    sendSearchRequest();

    loadingTimer = setTimeout(function () {
      var m = getModal();
      if (m && m.classList.contains('loading')) {
        m.classList.remove('loading');
        var summary = m.querySelector('.papers-summary');
        if (summary) summary.textContent = 'Search timed out. Please try again.';
      }
    }, LOADING_TIMEOUT_MS);
  }

  function closeModal() {
    clearLoadingTimer();
    var overlay = getModal();
    if (!overlay) return;
    overlay.classList.remove('open', 'loading');
    overlay.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
  }

  function clearLoadingTimer() {
    if (loadingTimer) { clearTimeout(loadingTimer); loadingTimer = null; }
  }

  /* ── Rendering ─────────────────────────────────────────────── */
  function renderLoading(overlay) {
    overlay.classList.add('loading');
    var titleEl = overlay.querySelector('.papers-modal-title');
    var subtitleEl = overlay.querySelector('.papers-modal-subtitle');
    var summaryEl = overlay.querySelector('.papers-summary');
    var listEl = overlay.querySelector('.papers-list');
    var emptyEl = overlay.querySelector('.papers-empty');
    var paginationEl = overlay.querySelector('.papers-pagination');
    var pageInfoEl = overlay.querySelector('.papers-page-info');
    var loaderText = overlay.querySelector('.papers-loader-text');

    if (titleEl) titleEl.innerHTML = '<i class="fa fa-file-alt"></i> Scientific Literature';
    if (subtitleEl) {
      var orgDisplay = currentState.organism || 'N/A';
      subtitleEl.innerHTML = 'Gene: <strong>' + esc(currentState.gene || 'N/A') + '</strong> | Organism: <em>' + esc(orgDisplay) + '</em>';
    }
    if (summaryEl) summaryEl.textContent = '';
    if (listEl) listEl.innerHTML = '';
    if (emptyEl) emptyEl.style.display = 'none';
    if (paginationEl) paginationEl.innerHTML = '';
    if (pageInfoEl) pageInfoEl.textContent = '';
    if (loaderText) loaderText.textContent = 'Searching papers in Europe PMC...';
  }

  function renderResults(data) {
    clearLoadingTimer();
    var overlay = ensureModal();
    overlay.classList.remove('loading');

    var reqId = String(data.request_id || '');
    if (reqId && currentState.requestId && reqId !== currentState.requestId) return;

    var summaryEl = overlay.querySelector('.papers-summary');
    var listEl = overlay.querySelector('.papers-list');
    var emptyEl = overlay.querySelector('.papers-empty');
    var subtitleEl = overlay.querySelector('.papers-modal-subtitle');

    // Update subtitle
    if (subtitleEl) {
      var org = data.organism || currentState.organism || 'N/A';
      var g = data.gene || currentState.gene || 'N/A';
      subtitleEl.innerHTML = 'Gene: <strong>' + esc(g) + '</strong> | Organism: <em>' + esc(org) + '</em>';
    }

    // Error?
    if (data.error) {
      if (summaryEl) summaryEl.textContent = '';
      if (listEl) listEl.innerHTML = '';
      if (emptyEl) {
        emptyEl.style.display = '';
        emptyEl.innerHTML = '<div class="papers-empty-icon"><i class="fa fa-exclamation-triangle"></i></div>' +
          '<p>' + esc(data.error) + '</p>';
      }
      renderPagination(data);
      return;
    }

    var hits = parseInt(data.hits || 0, 10);
    var papers = Array.isArray(data.papers) ? data.papers : [];
    var page = parseInt(data.page || 1, 10);
    var pageSize = parseInt(data.page_size || 10, 10);

    // Update summary
    if (summaryEl) {
      if (hits > 0) {
        summaryEl.innerHTML = '<span class="papers-hit-count">' + formatNumber(hits) + '</span> paper' + (hits === 1 ? '' : 's') + ' found';
      } else {
        summaryEl.textContent = '';
      }
    }

    // Render papers
    if (papers.length === 0) {
      if (listEl) listEl.innerHTML = '';
      if (emptyEl) {
        emptyEl.style.display = '';
        emptyEl.innerHTML =
          '<div class="papers-empty-icon"><i class="fa fa-book-open"></i></div>' +
          '<p>No scientific papers found for this gene and organism combination.</p>' +
          '<p class="papers-empty-hint">Try searching with different gene aliases or check the organism name.</p>';
      }
    } else {
      if (emptyEl) emptyEl.style.display = 'none';
      var html = '';
      for (var i = 0; i < papers.length; i++) {
        html += renderPaperCard(papers[i], (page - 1) * pageSize + i + 1);
      }
      if (listEl) listEl.innerHTML = html;
      // Bind expand/collapse buttons
      bindAbstractToggles(listEl);
    }

    renderPagination(data);
  }

  function renderPaperCard(paper, idx) {
    var title = txt(paper.title || 'Untitled');
    var authors = txt(paper.authors || 'Unknown');
    var year = txt(paper.year || '');
    var journal = txt(paper.journal || '');
    var abstract = txt(paper.abstract || 'Abstract not available.');
    var doi = txt(paper.doi || '');
    var link = txt(paper.link || '');
    var citedBy = parseInt(paper.cited_by || 0, 10);

    var abstractShort = abstract.length > 250 ? abstract.substring(0, 250) + '…' : abstract;
    var hasLongAbstract = abstract.length > 250 && abstract !== 'Abstract not available.';

    var filterText = (title + ' ' + authors + ' ' + journal + ' ' + year).toLowerCase();

    var metaParts = [];
    if (year) metaParts.push('<span class="papers-card-year"><i class="fa fa-calendar-alt"></i> ' + esc(year) + '</span>');
    if (journal) metaParts.push('<span class="papers-card-journal"><i class="fa fa-book"></i> ' + esc(journal) + '</span>');
    if (citedBy > 0) metaParts.push('<span class="papers-card-cited"><i class="fa fa-quote-right"></i> Cited: ' + formatNumber(citedBy) + '</span>');

    var out = '<div class="papers-card" data-filter-text="' + esc(filterText) + '">';
    out += '<div class="papers-card-number">' + idx + '</div>';
    out += '<div class="papers-card-content">';

    // Title
    if (link) {
      out += '<a class="papers-card-title" href="' + esc(link) + '" target="_blank" rel="noopener noreferrer">' + esc(title) + '</a>';
    } else {
      out += '<div class="papers-card-title">' + esc(title) + '</div>';
    }

    // Authors
    out += '<div class="papers-card-authors"><i class="fa fa-users"></i> ' + esc(truncate(authors, 200)) + '</div>';

    // Meta (year, journal, cited)
    if (metaParts.length > 0) {
      out += '<div class="papers-card-meta">' + metaParts.join('<span class="papers-meta-sep">•</span>') + '</div>';
    }

    // Abstract
    out += '<div class="papers-card-abstract">';
    out += '<div class="papers-abstract-text" data-full="' + esc(abstract) + '" data-short="' + esc(abstractShort) + '">' + esc(abstractShort) + '</div>';
    if (hasLongAbstract) {
      out += '<button class="papers-abstract-toggle" data-expanded="false">Show more <i class="fa fa-chevron-down"></i></button>';
    }
    out += '</div>';

    // Links
    out += '<div class="papers-card-links">';
    if (doi) {
      out += '<a class="papers-link-doi" href="https://doi.org/' + esc(doi) + '" target="_blank" rel="noopener noreferrer"><i class="fa fa-fingerprint"></i> DOI: ' + esc(doi) + '</a>';
    }
    if (link) {
      out += '<a class="papers-link-view" href="' + esc(link) + '" target="_blank" rel="noopener noreferrer"><i class="fa fa-external-link-alt"></i> View Paper</a>';
    }
    out += '</div>';

    out += '</div></div>';
    return out;
  }

  function bindAbstractToggles(container) {
    if (!container) return;
    var toggles = container.querySelectorAll('.papers-abstract-toggle');
    toggles.forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        e.stopPropagation();
        var textEl = btn.parentElement.querySelector('.papers-abstract-text');
        if (!textEl) return;
        var expanded = btn.getAttribute('data-expanded') === 'true';
        if (expanded) {
          textEl.textContent = textEl.getAttribute('data-short');
          btn.innerHTML = 'Show more <i class="fa fa-chevron-down"></i>';
          btn.setAttribute('data-expanded', 'false');
        } else {
          textEl.textContent = textEl.getAttribute('data-full');
          btn.innerHTML = 'Show less <i class="fa fa-chevron-up"></i>';
          btn.setAttribute('data-expanded', 'true');
        }
      });
    });
  }

  function renderPagination(data) {
    var overlay = getModal();
    if (!overlay) return;
    var paginationEl = overlay.querySelector('.papers-pagination');
    var pageInfoEl = overlay.querySelector('.papers-page-info');

    var hits = parseInt(data.hits || 0, 10);
    var page = parseInt(data.page || 1, 10);
    var pageSize = parseInt(data.page_size || 10, 10);
    var totalPages = parseInt(data.total_pages || 0, 10);

    currentState.page = page;

    if (totalPages <= 1) {
      if (paginationEl) paginationEl.innerHTML = '';
      if (pageInfoEl) {
        if (hits > 0) {
          pageInfoEl.textContent = 'Showing ' + Math.min(hits, pageSize) + ' of ' + formatNumber(hits);
        } else {
          pageInfoEl.textContent = '';
        }
      }
      return;
    }

    // Page info
    var startItem = (page - 1) * pageSize + 1;
    var endItem = Math.min(page * pageSize, hits);
    if (pageInfoEl) {
      pageInfoEl.textContent = 'Showing ' + formatNumber(startItem) + '-' + formatNumber(endItem) + ' of ' + formatNumber(hits);
    }

    // Build page buttons
    var html = '';

    // Prev
    html += '<button class="papers-page-btn' + (page <= 1 ? ' disabled' : '') + '" data-page="' + (page - 1) + '"' +
      (page <= 1 ? ' disabled' : '') + '><i class="fa fa-chevron-left"></i></button>';

    // Page numbers (show max 7 pages)
    var startPage = Math.max(1, page - 3);
    var endPage = Math.min(totalPages, startPage + 6);
    if (endPage - startPage < 6) startPage = Math.max(1, endPage - 6);

    if (startPage > 1) {
      html += '<button class="papers-page-btn" data-page="1">1</button>';
      if (startPage > 2) html += '<span class="papers-page-dots">…</span>';
    }

    for (var p = startPage; p <= endPage; p++) {
      html += '<button class="papers-page-btn' + (p === page ? ' active' : '') + '" data-page="' + p + '">' + p + '</button>';
    }

    if (endPage < totalPages) {
      if (endPage < totalPages - 1) html += '<span class="papers-page-dots">…</span>';
      html += '<button class="papers-page-btn" data-page="' + totalPages + '">' + totalPages + '</button>';
    }

    // Next
    html += '<button class="papers-page-btn' + (page >= totalPages ? ' disabled' : '') + '" data-page="' + (page + 1) + '"' +
      (page >= totalPages ? ' disabled' : '') + '><i class="fa fa-chevron-right"></i></button>';

    if (paginationEl) paginationEl.innerHTML = html;

    // Bind page button clicks
    paginationEl.querySelectorAll('.papers-page-btn:not(.disabled)').forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        e.stopPropagation();
        var pg = parseInt(btn.getAttribute('data-page'), 10);
        if (isNaN(pg) || pg < 1) return;
        currentState.page = pg;
        sendSearchRequest();
        // Scroll body to top
        var body = overlay.querySelector('.papers-modal-body');
        if (body) body.scrollTop = 0;
      });
    });
  }

  /* ── Shiny Communication ───────────────────────────────────── */
  function sendSearchRequest() {
    if (!window.Shiny || typeof window.Shiny.setInputValue !== 'function') return;
    var overlay = ensureModal();
    renderLoading(overlay);

    currentState.requestId = String(Date.now()) + '_' + String(Math.floor(Math.random() * 1e6));

    window.Shiny.setInputValue('papers_search_request', {
      request_id: currentState.requestId,
      gene: currentState.gene,
      gene_synonyms: currentState.geneSynonyms,
      organism: currentState.organism,
      organism_aliases: currentState.organismAliases,
      page: currentState.page,
      page_size: currentState.pageSize,
      sort_by: currentState.sortBy,
      triggered_at: Date.now()
    }, { priority: 'event' });
  }

  /* ── Global Event Handlers ──────────────────────────────────── */
  document.addEventListener('click', function (e) {
    var btn = e.target.closest ? e.target.closest('.footer-papers-btn') : null;
    if (btn) {
      e.preventDefault();
      e.stopPropagation();
      openModal(btn);
      return;
    }
  }, true);

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && isOpen()) {
      closeModal();
    }
  }, true);

  /* ── Shiny Message Handler ──────────────────────────────────── */
  if (window.Shiny) {
    Shiny.addCustomMessageHandler('papers_popup_data', function (message) {
      renderResults(message || {});
    });
  } else {
    document.addEventListener('shiny:connected', function () {
      Shiny.addCustomMessageHandler('papers_popup_data', function (message) {
        renderResults(message || {});
      });
    });
  }

})();
