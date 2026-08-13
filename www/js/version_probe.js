/* version_probe.js — Verifica si hay una nueva versión de la app y recarga si es necesario. */
(function() {
  'use strict';

  function normalizeVersion(value) {
    return String(value || '').trim();
  }

  function buildProbeUrl() {
    var configuredUrl = String(window.__cgvVersionProbeUrl || 'cgv-meta/version.json');
    return new URL(configuredUrl, document.baseURI || window.location.href).toString();
  }

  function buildReloadUrl(nextVersion) {
    var reloadUrl = new URL(window.location.href);
    reloadUrl.searchParams.delete('__cgv_probe__');
    reloadUrl.searchParams.set('v', nextVersion);
    return reloadUrl.toString();
  }

  function maybeReloadForNewVersion() {
    // Read configuration at execution time. The script may be downloaded before
    // the rest of the page has finished parsing in older cached documents.
    var currentVersion = normalizeVersion(window.__cgvAppVersion);
    if (!currentVersion || !window.fetch) return;

    window.fetch(buildProbeUrl(), {
      cache: 'no-cache',
      credentials: 'same-origin'
    })
      .then(function(resp) {
        if (!resp.ok) throw new Error('version probe failed');
        return resp.json();
      })
      .then(function(payload) {
        var latestVersion = normalizeVersion(payload && payload.version);
        if (latestVersion && latestVersion !== currentVersion) {
          window.location.replace(buildReloadUrl(latestVersion));
        }
      })
      .catch(function() {});
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', maybeReloadForNewVersion, { once: true });
  } else {
    maybeReloadForNewVersion();
  }
})();
