/* autocomplete_core.js — Lógica de autocomplete de genes: sanitize, datalist update.
   Incluye throttling por chunks para no bloquear la UI con grandes datalists. */
(function() {
  'use strict';

  var CHUNK_SIZE = 600;
  var CHUNK_DELAY_MS = 8;

  function sanitizeAutocompleteChoices(values, maxItems) {
    var list = Array.isArray(values) ? values : [];
    var limit = Math.max(1, parseInt(maxItems || 8000, 10));
    var seen = Object.create(null);
    var out = [];
    for (var i = 0; i < list.length; i += 1) {
      var vv = (list[i] === null || list[i] === undefined) ? '' : String(list[i]);
      vv = vv.replace(/\s+/g, ' ').trim();
      if (!vv) continue;
      var key = vv.toLowerCase();
      if (seen[key]) continue;
      seen[key] = true;
      out.push(vv);
      if (out.length >= limit) break;
    }
    return out;
  }

  function updateDatalistChunked(dl, inputEl, choices) {
    var savedList = inputEl ? inputEl.getAttribute('list') : null;
    if (inputEl && savedList) inputEl.removeAttribute('list');
    if (dl.replaceChildren) {
      dl.replaceChildren();
    } else {
      dl.innerHTML = '';
    }

    var idx = 0;
    function appendChunk() {
      var end = Math.min(idx + CHUNK_SIZE, choices.length);
      var frag = document.createDocumentFragment();
      for (var i = idx; i < end; i++) {
        var opt = document.createElement('option');
        opt.value = choices[i];
        opt.label = choices[i];
        opt.textContent = choices[i];
        frag.appendChild(opt);
      }
      dl.appendChild(frag);
      idx = end;
      if (idx < choices.length) {
        setTimeout(appendChunk, CHUNK_DELAY_MS);
      } else {
        if (inputEl && savedList) inputEl.setAttribute('list', savedList);
      }
    }
    appendChunk();
  }

  function updateGeneAutocomplete(message) {
    var inputId = (message && message.input_id) ? message.input_id : '';
    if (!inputId) return;
    var isGlobalSearch = inputId === 'global_search_query';
    var listId = inputId + '_suggestions';
    var choicesRaw = (message && message.choices) ? message.choices : [];
    var choices = sanitizeAutocompleteChoices(choicesRaw, isGlobalSearch ? 15000 : 3000);
    var dl = document.getElementById(listId);
    var inputEl = document.getElementById(inputId);
    if (inputEl) {
      var useNativeDatalist = !isGlobalSearch;
      if (useNativeDatalist) {
        inputEl.setAttribute('list', listId);
        inputEl.setAttribute('autocomplete', 'off');
      } else {
        inputEl.removeAttribute('list');
        inputEl.setAttribute('autocomplete', 'new-password');
      }
      inputEl.setAttribute('data-form-type', 'other');
      inputEl.setAttribute('data-lpignore', 'true');
      inputEl.setAttribute('data-1p-ignore', 'true');
      inputEl.setAttribute('autocorrect', 'off');
      inputEl.setAttribute('autocapitalize', 'off');
      inputEl.setAttribute('spellcheck', 'false');
      inputEl.style.color = '#2C3E50';
      inputEl.style.backgroundColor = '#F8FCFB';
      inputEl.style.caretColor = '#2C3E50';
      inputEl.style.colorScheme = 'light';
    }

    if (isGlobalSearch) {
      window.__globalGeneSuggestionPool = choices;
      if (dl && dl.replaceChildren) {
        dl.replaceChildren();
      } else if (dl) {
        dl.innerHTML = '';
      }
      var updatedEvt;
      try {
        updatedEvt = new Event('cgv-global-suggestions-updated');
      } catch (err) {
        updatedEvt = document.createEvent('Event');
        updatedEvt.initEvent('cgv-global-suggestions-updated', true, true);
      }
      document.dispatchEvent(updatedEvt);
      return;
    }

    if (!dl) return;
    if (choices.length > CHUNK_SIZE) {
      updateDatalistChunked(dl, inputEl, choices);
    } else {
      var frag = document.createDocumentFragment();
      for (var i = 0; i < choices.length; i++) {
        var opt = document.createElement('option');
        opt.value = choices[i];
        opt.label = choices[i];
        opt.textContent = choices[i];
        frag.appendChild(opt);
      }
      var savedList = inputEl ? inputEl.getAttribute('list') : null;
      if (inputEl && savedList) inputEl.removeAttribute('list');
      if (dl.replaceChildren) {
        dl.replaceChildren(frag);
      } else {
        dl.innerHTML = '';
        dl.appendChild(frag);
      }
      if (inputEl && savedList) inputEl.setAttribute('list', savedList);
    }
  }

  window.sanitizeAutocompleteChoices = sanitizeAutocompleteChoices;

  if (window.Shiny && Shiny.addCustomMessageHandler) {
    Shiny.addCustomMessageHandler('update_gene_autocomplete', updateGeneAutocomplete);
  }
})();
