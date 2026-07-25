/* version_probe.js — Verifica si hay una nueva versión de la app y recarga si es necesario. */
(function() {
  'use strict';
  var APP_VERSION = window.__cgvAppVersion || '';

  function normalizeVersion(value) {
    return String(value || '').trim();
  }

  function buildProbeUrl() {
    var probeUrl = new URL(window.location.href);
    probeUrl.searchParams.set('__cgv_probe__', String(Date.now()));
    return probeUrl.toString();
  }

  function buildReloadUrl(nextVersion) {
    var reloadUrl = new URL(window.location.href);
    reloadUrl.searchParams.delete('__cgv_probe__');
    reloadUrl.searchParams.set('v', nextVersion);
    return reloadUrl.toString();
  }

  function maybeReloadForNewVersion() {
    var currentVersion = normalizeVersion(APP_VERSION);
    if (!currentVersion || !window.fetch || !window.DOMParser) return;

    fetch(buildProbeUrl(), {
      cache: 'no-store',
      credentials: 'same-origin',
      headers: { 'Cache-Control': 'no-cache' }
    })
      .then(function(resp) {
        if (!resp.ok) throw new Error('version probe failed');
        return resp.text();
      })
      .then(function(html) {
        var doc = new DOMParser().parseFromString(html, 'text/html');
        var meta = doc.querySelector('meta[name="cgv-app-version"]');
        var latestVersion = normalizeVersion(meta && meta.getAttribute('content'));
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
