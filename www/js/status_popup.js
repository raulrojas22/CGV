(function () {
  if (window.__statusPopupInitialized) return;
  window.__statusPopupInitialized = true;
  var AUTO_CLOSE_MS = 4000;
  var MAX_HISTORY = 80;
  var autoCloseTimer = null;
  var historyEntries = [];
  var unreadCount = 0;
  var manualOpen = false;
  var loadingContext = '';
  var loadingStartedAt = null;
  var loadingTimer = null;
  var loadingAutoOpened = false;

  function escapeHtml(v) {
    return String(v)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  // Common model organisms — explicit list for high-confidence matching.
  // This is a fallback: the R layer (format_org_name) already sends <em> tags
  // for organism names, so this list only fires when the raw name reaches JS
  // without prior wrapping.
  var knownOrganisms = [
    // Plants
    'Arabidopsis thaliana', 'Chlamydomonas reinhardtii', 'Glycine max',
    'Hordeum vulgare', 'Marchantia polymorpha', 'Medicago truncatula',
    'Oryza sativa', 'Oryza sativa Japonica', 'Oryza sativa Indica',
    'Physcomitrium patens', 'Populus trichocarpa', 'Setaria italica',
    'Solanum lycopersicum', 'Solanum tuberosum', 'Sorghum bicolor',
    'Vitis vinifera', 'Zea mays', 'Beta vulgaris', 'Brassica napus',
    'Brassica oleracea', 'Brassica rapa', 'Capsicum annuum',
    'Cucumis sativus', 'Fragaria vesca', 'Lotus japonicus',
    'Nicotiana benthamiana', 'Nicotiana tabacum', 'Phaseolus vulgaris',
    'Pisum sativum', 'Selaginella moellendorffii', 'Spinacia oleracea',
    'Brachypodium distachyon', 'Triticum urartu', 'Manihot esculenta',
    // Mammals
    'Homo sapiens', 'Mus musculus', 'Rattus norvegicus',
    'Canis lupus familiaris', 'Canis lupus', 'Felis catus',
    'Sus scrofa', 'Bos taurus', 'Equus caballus', 'Ovis aries',
    'Oryctolagus cuniculus', 'Macaca mulatta', 'Pan troglodytes',
    'Gorilla gorilla', 'Pongo abelii', 'Monodelphis domestica',
    'Ornithorhynchus anatinus', 'Gallus gallus', 'Danio rerio',
    // Other vertebrates
    'Xenopus tropicalis', 'Xenopus laevis', 'Takifugu rubripes',
    'Tetraodon nigroviridis', 'Oryzias latipes', 'Gasterosteus aculeatus',
    'Petromyzon marinus', 'Latimeria chalumnae',
    // Invertebrates
    'Drosophila melanogaster', 'Drosophila simulans', 'Drosophila virilis',
    'Caenorhabditis elegans', 'Caenorhabditis briggsae',
    'Anopheles gambiae', 'Apis mellifera', 'Bombyx mori',
    'Strongylocentrotus purpuratus', 'Ciona intestinalis',
    // Fungi & yeast
    'Saccharomyces cerevisiae', 'Schizosaccharomyces pombe',
    'Neurospora crassa', 'Aspergillus nidulans', 'Aspergillus niger',
    'Fusarium graminearum', 'Magnaporthe oryzae',
    // Bacteria & other
    'Escherichia coli', 'Bacillus subtilis', 'Pseudomonas aeruginosa',
    'Dictyostelium discoideum', 'Plasmodium falciparum'
  ];

  // Words that start a sentence / clause but are NOT genus names.
  // Used to filter out false positives from the regex-based fallback below.
  var _notGenus = /^(Searching|Plotting|Querying|Loading|Initializing|Starting|Preparing|Running|Resolving|Connecting|Checking|Reading|Writing|Sending|Generating|Building|Rendering|Fetching|Parsing|Computing|Analyzing|Processing|Scanning|Matching|Filtering|Sorting|Merging|Splitting|Combining|Waiting|Retrying|Reloading|External|Internal|Parallel|Sequential|Selected|Available|Connected|Completed|Generated|Warmed|Ready|Failed|Error|Warning|Success|Already|Partial|Enabled|Disabled|Skipped|Cached|Found|Missing|Local|Remote|Default|Optional|Required|Invalid|Lookup|Stage|Source|Alias|Result|Match|Entry|Block|Track|Signal|Panel|Window|Dialog|Modal|Status|Message|Context|Session|Output|Input|Value|Label|Index|Count|Total|Limit|Offset|Range|Scale|Width|Height|Margin|Padding|Border|Color|Style)$/;

  function _escapeRegexStr(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  // Apply fn() only to plain-text segments — never inside existing italic/em tags.
  // Splits the string into alternating [text, tag, text, tag, ...] segments;
  // skips text nodes that are directly inside an <i> or <em> element.
  function _applyToTextNodes(str, fn) {
    var parts = str.split(/(<[^>]+>)/);
    for (var k = 0; k < parts.length; k += 2) {   // even indices = text nodes
      var prevTag = (k > 0) ? parts[k - 1] : '';
      // Skip if the preceding tag is an opening <i> or <em> — content is already italic.
      if (/^<(i|em)(\s[^>]*)?>$/i.test(prevTag)) continue;
      parts[k] = fn(parts[k]);
    }
    return parts.join('');
  }

  function escapeAndFormatHtml(v) {
    var str = escapeHtml(v)
      // Restore <em>/<i> tags that format_org_name() already sent from R.
      .replace(/&lt;em&gt;/g, '<em>')
      .replace(/&lt;\/em&gt;/g, '</em>')
      .replace(/&lt;i&gt;/g, '<i>')
      .replace(/&lt;\/i&gt;/g, '</i>');

    // 1. Explicit list — longest-first so subspecies (e.g. "Canis lupus familiaris")
    //    match before the shorter binomial ("Canis lupus").
    var sorted = knownOrganisms.slice().sort(function(a, b) { return b.length - a.length; });
    for (var j = 0; j < sorted.length; j++) {
      var org = sorted[j];
      var orgPat = new RegExp(_escapeRegexStr(org), 'g');
      str = _applyToTextNodes(str, function(txt) {
        return txt.replace(orgPat, '<i>' + org + '</i>');
      });
    }

    // 2. Regex fallback: catch any binomial/trinomial not in the explicit list.
    // Requires: Capital(1) + lower(3-14) + space + lower(5-14) [ + space + lower(4-14) ]
    // The genus word is checked against _notGenus to exclude common English verbs/nouns.
    var sciPat = /\b([A-Z][a-z]{3,14})\s+([a-z]{5,14})(?:\s+([a-z]{4,14}))?\b/g;
    str = _applyToTextNodes(str, function(txt) {
      return txt.replace(sciPat, function(match, genus) {
        return _notGenus.test(genus) ? match : '<i>' + match + '</i>';
      });
    });

    return str;
  }

  function pad2(n) {
    return String(n).padStart(2, '0');
  }

  function formatClock(date) {
    return pad2(date.getHours()) + ':' + pad2(date.getMinutes()) + ':' + pad2(date.getSeconds());
  }

  function formatElapsed(ms) {
    var total = Math.max(0, Math.round(Number(ms || 0) / 1000));
    if (total < 60) {
      return total + 's';
    }
    var mins = Math.floor(total / 60);
    var secs = total % 60;
    if (mins < 60) {
      return mins + 'm ' + pad2(secs) + 's';
    }
    var hrs = Math.floor(mins / 60);
    mins = mins % 60;
    return hrs + 'h ' + pad2(mins) + 'm';
  }

  function getLoadingElapsedText() {
    if (!loadingStartedAt) return '';
    return formatElapsed(Date.now() - loadingStartedAt.getTime());
  }

  function clearAutoCloseTimer() {
    if (autoCloseTimer) {
      clearTimeout(autoCloseTimer);
      autoCloseTimer = null;
    }
  }

  function txt(value) {
    return String(value == null ? '' : value);
  }

  function hasVisibleRect(el) {
    if (!el || !el.getBoundingClientRect) {
      return false;
    }
    var rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  function getActiveMainPane() {
    var scoped = document.querySelector('.app-main > .tab-content > .tab-pane.active .app-main-pane');
    if (scoped && hasVisibleRect(scoped)) {
      return scoped;
    }
    var panes = document.querySelectorAll('.app-main-pane');
    for (var i = 0; i < panes.length; i++) {
      if (hasVisibleRect(panes[i])) {
        return panes[i];
      }
    }
    return null;
  }

  function clearPopupBounds(popup) {
    if (!popup) return;
    popup.style.right = '';
    popup.style.bottom = '';
    popup.style.width = '';
    popup.style.maxWidth = '';
    popup.style.maxHeight = '';
  }

  function syncPopupBounds(popup) {
    if (!popup) return;
    var pane = getActiveMainPane();
    if (!pane) {
      clearPopupBounds(popup);
      return;
    }

    var rect = pane.getBoundingClientRect();
    if (!rect || !isFinite(rect.width) || !isFinite(rect.height) || rect.width <= 0 || rect.height <= 0) {
      clearPopupBounds(popup);
      return;
    }

    var gutter = 14;
    var rightInset = Math.max(10, Math.round(window.innerWidth - rect.right + gutter));
    var bottomInset = Math.max(10, Math.round(window.innerHeight - rect.bottom + gutter));
    var maxWidth = Math.max(120, Math.round(rect.width - (gutter * 2)));
    var targetWidth = Math.max(120, Math.min(460, maxWidth));
    var maxHeight = Math.max(200, Math.round(rect.height - (gutter * 2)));

    popup.style.right = rightInset + 'px';
    popup.style.bottom = bottomInset + 'px';
    popup.style.width = targetWidth + 'px';
    popup.style.maxWidth = maxWidth + 'px';
    popup.style.maxHeight = maxHeight + 'px';
  }

  function resetPopupState(popup, logEl, loaderTextEl) {
    clearAutoCloseTimer();
    if (loaderTextEl) {
      loaderTextEl.textContent = txt('Working...');
    }
    if (popup) {
      popup.classList.remove('tone-info', 'tone-success', 'tone-warning', 'tone-error');
    }
  }

  function getNotificationToggles() {
    return Array.prototype.slice.call(document.querySelectorAll('.app-notification-center-toggle'));
  }

  function getNotificationBadges() {
    return Array.prototype.slice.call(document.querySelectorAll('.app-notification-center-badge'));
  }

  function setUnreadCount(count) {
    unreadCount = Math.max(0, Number(count || 0));
    getNotificationBadges().forEach(function (badge) {
      badge.textContent = unreadCount > 99 ? '99+' : String(unreadCount);
      badge.classList.toggle('is-visible', unreadCount > 0);
    });
    getNotificationToggles().forEach(function (toggle) {
      toggle.classList.toggle('has-unread', unreadCount > 0);
    });
  }

  function markNotificationsRead() {
    setUnreadCount(0);
  }

  function setToggleExpanded(open) {
    getNotificationToggles().forEach(function (toggle) {
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      toggle.classList.toggle('is-active', !!open);
    });
  }

  function setLoadingActive(active) {
    getNotificationToggles().forEach(function (toggle) {
      toggle.classList.toggle('is-loading', !!active);
    });
  }

  function renderLatestNotice(entry, logEl) {
    var target = logEl || document.getElementById('app-status-popup-log');
    if (!target || !entry) return;
    var durationHtml = entry.duration
      ? '<span class="app-status-popup-entry-duration">' + escapeHtml(entry.duration) + '</span>'
      : '';
    target.innerHTML =
      '<div class="app-status-popup-entry tone-' + escapeHtml(entry.tone || 'info') + '">' +
      '<div class="app-status-popup-entry-head">' +
      '<span class="app-status-popup-entry-context">' + escapeHtml(entry.context || 'Status') + '</span>' +
      '<span class="app-status-popup-entry-meta">' +
      durationHtml +
      '<span class="app-status-popup-entry-time">' + escapeHtml(entry.time || '') + '</span>' +
      '</span>' +
      '</div>' +
      '<div class="app-status-popup-entry-text">' + escapeAndFormatHtml(entry.text || '') + '</div>' +
      '</div>';
  }

  function renderHistory(logEl) {
    var target = logEl || document.getElementById('app-status-popup-log');
    if (!target) return;

    if (!historyEntries.length) {
      target.innerHTML =
        '<div class="app-status-popup-empty">' +
        '<span class="app-status-popup-empty-icon">i</span>' +
        '<span>No notification history yet.</span>' +
        '</div>';
      return;
    }

    var html = '';
    for (var i = 0; i < historyEntries.length; i++) {
      var item = historyEntries[i] || {};
      var durationHtml = item.duration
        ? '<span class="app-status-popup-entry-duration">' + escapeHtml(item.duration) + '</span>'
        : '';
      html +=
        '<div class="app-status-popup-entry tone-' + escapeHtml(item.tone || 'info') + '">' +
        '<div class="app-status-popup-entry-head">' +
        '<span class="app-status-popup-entry-context">' + escapeHtml(item.context || 'Status') + '</span>' +
        '<span class="app-status-popup-entry-meta">' +
        durationHtml +
        '<span class="app-status-popup-entry-time">' + escapeHtml(item.time || '') + '</span>' +
        '</span>' +
        '</div>' +
        '<div class="app-status-popup-entry-text">' + escapeAndFormatHtml(item.text || '') + '</div>' +
        '</div>';
    }
    target.innerHTML = html;
  }

  function pushHistory(entry) {
    historyEntries.unshift(entry);
    if (historyEntries.length > MAX_HISTORY) {
      historyEntries.length = MAX_HISTORY;
    }
    if (manualOpen) {
      renderHistory();
    }
  }

  function openPopup(popup, options) {
    if (!popup) return;
    var opts = options || {};
    if (opts.manual) {
      manualOpen = true;
      markNotificationsRead();
    }
    popup.classList.add('open');
    syncPopupBounds(popup);
    setToggleExpanded(true);
  }

  function closePopup(popup) {
    var target = popup || document.getElementById('app-status-popup');
    clearAutoCloseTimer();
    manualOpen = false;
    if (target) {
      target.classList.remove('open');
    }
    setToggleExpanded(false);
  }

  function scheduleAutoClose(popup) {
    clearAutoCloseTimer();
    autoCloseTimer = setTimeout(function () {
      if (popup && !manualOpen) {
        popup.classList.remove('open');
        setToggleExpanded(false);
      }
    }, AUTO_CLOSE_MS);
  }

  function activitySource(context) {
    return 'server:' + txt(context || 'Status').toLowerCase().replace(/[^a-z0-9]+/g, '-');
  }

  function beginGlobalActivity(context, headline, detail) {
    if (!window.cgvActivity) return;
    window.cgvActivity.begin(activitySource(context), {
      headline: txt(headline || context || 'CGV is working'),
      detail: txt(detail || 'Processing data…'),
      priority: 60,
      delay: 140
    });
  }

  function endGlobalActivity(context) {
    if (window.cgvActivity) window.cgvActivity.end(activitySource(context));
  }

  Shiny.addCustomMessageHandler('app_status_popup', function (message) {
    var popup = document.getElementById('app-status-popup');
    var logEl = document.getElementById('app-status-popup-log');
    if (!popup || !logEl) return;

    var context = (message && message.context) ? String(message.context) : 'Status';
    var tone = (message && message.tone) ? String(message.tone) : 'info';
    var text = (message && message.text) ? String(message.text) : '';
    var lines = String(text)
      .split(/\n+/)
      .map(function (line) { return line.trim(); })
      .filter(function (line) { return line.length > 0; });
    if (!lines.length) return;
    var line = txt(lines[lines.length - 1]);
    var contextTxt = txt(context);
    endGlobalActivity(contextTxt);

    var now = new Date();
    var durationText = '';
    if (loadingStartedAt && (!loadingContext || loadingContext === contextTxt)) {
      durationText = formatElapsed(now.getTime() - loadingStartedAt.getTime());
      loadingStartedAt = null;
      loadingContext = '';
    }
    var entry = {
      context: contextTxt,
      tone: tone,
      text: line,
      time: formatClock(now),
      duration: durationText
    };
    pushHistory(entry);
    if (!manualOpen) {
      setUnreadCount(unreadCount + 1);
    }

    popup.classList.remove('tone-info', 'tone-success', 'tone-warning', 'tone-error');
    popup.classList.add('tone-' + tone);
    if (manualOpen) {
      renderHistory(logEl);
      syncPopupBounds(popup);
    } else {
      popup.classList.remove('loading');
      renderLatestNotice(entry, logEl);
      openPopup(popup, { manual: false });
      scheduleAutoClose(popup);
    }
  });

  Shiny.addCustomMessageHandler('app_status_popup_loading', function (message) {
    var popup = document.getElementById('app-status-popup');
    var loaderTextEl = document.getElementById('app-status-popup-loader-text');
    var logEl = document.getElementById('app-status-popup-log');
    if (!popup) return;

    var active = !!(message && message.active);
    var autoOpen = !!(message && message.auto_open);
    var text = (message && message.text !== undefined && message.text !== null) ? String(message.text) : '';
    var headline = (message && message.headline !== undefined && message.headline !== null) ? String(message.headline).trim() : '';
    var textTranslated = txt(text);
    var headlineTranslated = txt(headline);
    var isStartingNewRun = active && !popup.classList.contains('loading');
    if (isStartingNewRun) {
      resetPopupState(popup, logEl, loaderTextEl);
      loadingStartedAt = new Date();
      loadingAutoOpened = false;
    }
    if (active) {
      loadingContext = (message && message.context) ? String(message.context) : 'Status';
      beginGlobalActivity(loadingContext, headlineTranslated || loadingContext, textTranslated);
    } else {
      endGlobalActivity((message && message.context) ? String(message.context) : loadingContext);
    }

    if (loaderTextEl && (headlineTranslated.length || textTranslated.length)) {
      var elapsed = active ? getLoadingElapsedText() : '';
      var elapsedHtml = elapsed
        ? '<span class="app-status-popup-loader-elapsed">' + escapeHtml(elapsed) + '</span>'
        : '';
      if (headlineTranslated.length && textTranslated.length) {
        loaderTextEl.innerHTML = escapeAndFormatHtml(headlineTranslated) + '<br>' + escapeAndFormatHtml(textTranslated) + elapsedHtml;
      } else if (headlineTranslated.length) {
        loaderTextEl.innerHTML = escapeAndFormatHtml(headlineTranslated) + elapsedHtml;
      } else {
        loaderTextEl.innerHTML = escapeAndFormatHtml(textTranslated) + elapsedHtml;
      }
    }

    if (active) {
      clearAutoCloseTimer();
      popup.classList.add('loading');
      if (manualOpen) {
        popup.classList.add('open');
        syncPopupBounds(popup);
      } else if (autoOpen && isStartingNewRun) {
        openPopup(popup, { manual: false });
        loadingAutoOpened = true;
      }
      setLoadingActive(true);
      if (loadingTimer) clearInterval(loadingTimer);
      loadingTimer = setInterval(function () {
        if (!loaderTextEl) return;
        var elapsed = getLoadingElapsedText();
        var existing = loaderTextEl.querySelector('.app-status-popup-loader-elapsed');
        if (existing) {
          existing.textContent = elapsed;
        }
      }, 1000);
    } else {
      var closeTransientPopup = loadingAutoOpened &&
        popup.classList.contains('loading') &&
        !manualOpen;
      popup.classList.remove('loading');
      setLoadingActive(false);
      if (closeTransientPopup) {
        closePopup(popup);
      }
      loadingAutoOpened = false;
      if (loadingTimer) {
        clearInterval(loadingTimer);
        loadingTimer = null;
      }
      if (window.cgvEndSearchFeedback) {
        window.cgvEndSearchFeedback();
      }
    }
  });

  Shiny.addCustomMessageHandler('app_status_popup_close', function (message) {
    var popup = document.getElementById('app-status-popup');
    var logEl = document.getElementById('app-status-popup-log');
    var loaderTextEl = document.getElementById('app-status-popup-loader-text');
    if (!popup) return;
    var closingLoadingContext = loadingContext;

    closePopup(popup);
    popup.classList.remove('loading', 'tone-info', 'tone-success', 'tone-warning', 'tone-error');
    setLoadingActive(false);
    loadingStartedAt = null;
    loadingContext = '';
    loadingAutoOpened = false;
    if (loadingTimer) {
      clearInterval(loadingTimer);
      loadingTimer = null;
    }

    if (message && message.clear) {
      if (loaderTextEl) {
        loaderTextEl.textContent = txt('Working...');
      }
    }
    endGlobalActivity(closingLoadingContext);
    if (window.cgvEndSearchFeedback) window.cgvEndSearchFeedback();
  });

  $(document).on('click', '#app-status-popup-close', function () {
    closePopup(document.getElementById('app-status-popup'));
  });

  $(document).on('click', '#app-status-popup-clear', function () {
    var logEl = document.getElementById('app-status-popup-log');
    var popup = document.getElementById('app-status-popup');
    historyEntries = [];
    renderHistory(logEl);
    setUnreadCount(0);
    if (popup) {
      popup.classList.remove('tone-info', 'tone-success', 'tone-warning', 'tone-error');
    }
    clearAutoCloseTimer();
  });

  $(document).on('click', '.app-notification-center-toggle', function (evt) {
    evt.preventDefault();
    evt.stopPropagation();
    var popup = document.getElementById('app-status-popup');
    if (!popup) return;
    if (popup.classList.contains('open') && manualOpen) {
      closePopup(popup);
      return;
    }
    renderHistory();
    openPopup(popup, { manual: true });
  });

  function initPopupBounds() {
    var popup = document.getElementById('app-status-popup');
    if (popup) syncPopupBounds(popup);
    renderHistory();
    setUnreadCount(0);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initPopupBounds);
  } else {
    initPopupBounds();
  }

  window.addEventListener('resize', function () {
    var popup = document.getElementById('app-status-popup');
    if (!popup) return;
    syncPopupBounds(popup);
  });
  document.addEventListener('shown.bs.tab', function () {
    var popup = document.getElementById('app-status-popup');
    if (!popup || !popup.classList.contains('open')) return;
    syncPopupBounds(popup);
  });
})();
