(function () {
  "use strict";

  if (window.CGVFigureStudioLoader) return;

  var bootstrap = document.currentScript;
  var scriptSrc = bootstrap ? bootstrap.getAttribute("data-module-src") : "";
  var styleHref = bootstrap ? bootstrap.getAttribute("data-style-href") : "";
  var triggerSelector = '.app-nav-btn[data-target="figure-studio"], #navtabs a[data-value="figure-studio"]';
  var scriptId = "cgv-figure-studio-module";
  var styleId = "cgv-figure-studio-style";
  var loadPromise = null;
  var restorePromise = Promise.resolve();
  var restoreQueue = [];
  var pendingRestoreJobs = 0;
  var restoreDrainScheduled = false;
  var shinyRestoreBound = false;
  var jqueryEventsBound = false;

  function moduleApi() {
    return window.CGVFigureStudio && typeof window.CGVFigureStudio.init === "function"
      ? window.CGVFigureStudio
      : null;
  }

  function headNode() {
    return document.head || document.getElementsByTagName("head")[0] || document.documentElement;
  }

  function removeNode(node) {
    if (node && node.parentNode) node.parentNode.removeChild(node);
  }

  function loadStyle() {
    if (!styleHref) return Promise.reject(new Error("Figure Studio stylesheet route is missing."));
    var existing = document.getElementById(styleId);
    if (existing && (existing.sheet || existing.getAttribute("data-loaded") === "true")) {
      return Promise.resolve(existing);
    }

    return new Promise(function (resolve, reject) {
      var link = existing || document.createElement("link");
      function loaded() {
        link.setAttribute("data-loaded", "true");
        resolve(link);
      }
      function failed() {
        reject(new Error("Figure Studio stylesheet could not be loaded."));
      }
      link.addEventListener("load", loaded, { once: true });
      link.addEventListener("error", failed, { once: true });
      if (!existing) {
        link.id = styleId;
        link.rel = "stylesheet";
        link.href = styleHref;
        headNode().appendChild(link);
      }
    });
  }

  function loadScript() {
    var ready = moduleApi();
    if (ready) return Promise.resolve(ready);
    if (!scriptSrc) return Promise.reject(new Error("Figure Studio script route is missing."));
    var existing = document.getElementById(scriptId);

    return new Promise(function (resolve, reject) {
      var script = existing || document.createElement("script");
      function loaded() {
        var api = moduleApi();
        if (api) resolve(api);
        else reject(new Error("Figure Studio script loaded without exposing its API."));
      }
      function failed() {
        reject(new Error("Figure Studio script could not be loaded."));
      }
      script.addEventListener("load", loaded, { once: true });
      script.addEventListener("error", failed, { once: true });
      if (!existing) {
        script.id = scriptId;
        script.async = true;
        script.src = scriptSrc;
        headNode().appendChild(script);
      }
    });
  }

  function flushRestoreQueue(api) {
    if (!api || typeof api.restore !== "function") return restorePromise;
    if (!restoreQueue.length || restoreDrainScheduled) return restorePromise;
    restoreDrainScheduled = true;
    restorePromise = restorePromise.then(function () {
      return new Promise(function (resolve) {
        setTimeout(function () {
          var queued = restoreQueue.splice(0, restoreQueue.length);
          pendingRestoreJobs = queued.length;
          try {
            queued.forEach(function (message) { api.restore(message); });
          } finally {
            pendingRestoreJobs = 0;
            restoreDrainScheduled = false;
            resolve();
          }
        }, 900);
      });
    });
    return restorePromise;
  }

  function announceReady() {
    if (typeof window.CustomEvent !== "function") return;
    document.dispatchEvent(new window.CustomEvent("cgv:figure-studio-ready"));
  }

  function ensureLoaded() {
    if (loadPromise) return loadPromise;

    loadPromise = Promise.all([loadStyle(), loadScript()]).then(function () {
      var api = moduleApi();
      if (!api) throw new Error("Figure Studio API is unavailable after loading.");
      api.init();
      return flushRestoreQueue(api).then(function () {
        announceReady();
        return api;
      });
    }).catch(function (error) {
      loadPromise = null;
      var api = moduleApi();
      var style = document.getElementById(styleId);
      var script = document.getElementById(scriptId);
      if (!style || !style.sheet) removeNode(style);
      if (!api) removeNode(script);
      throw error;
    });

    return loadPromise;
  }

  function requestLoad() {
    ensureLoaded().catch(function (error) {
      if (window.console && typeof window.console.warn === "function") {
        window.console.warn("Figure Studio lazy load failed; a later interaction will retry.", error);
      }
    });
  }

  function triggerFromEvent(event) {
    var target = event && event.target;
    return target && typeof target.closest === "function" ? target.closest(triggerSelector) : null;
  }

  function warmFromInteraction(event) {
    if (triggerFromEvent(event)) requestLoad();
  }

  function studioIsActive() {
    if (document.querySelector('#navtabs li.active > a[data-value="figure-studio"], #navtabs a.active[data-value="figure-studio"]')) {
      return true;
    }
    var page = document.querySelector(".figure-studio-page");
    var pane = page && typeof page.closest === "function" ? page.closest(".tab-pane") : null;
    return !!(pane && pane.classList && (pane.classList.contains("active") || pane.classList.contains("show")));
  }

  function bindShinyRestore() {
    if (shinyRestoreBound || !window.Shiny || typeof window.Shiny.addCustomMessageHandler !== "function") return;
    window.Shiny.addCustomMessageHandler("cgv:figure-studio-restore", function (message) {
      restoreQueue.push(message);
      ensureLoaded().then(function (api) {
        return flushRestoreQueue(api);
      }).catch(function (error) {
        if (window.console && typeof window.console.warn === "function") {
          window.console.warn("Figure Studio restore is waiting for a later load retry.", error);
        }
      });
    });
    shinyRestoreBound = true;
  }

  function bindJqueryEvents() {
    if (jqueryEventsBound || !window.jQuery) return;
    jqueryEventsBound = true;
    window.jQuery(document).on(
      "shown.bs.tab.cgvFigureStudioLoader",
      triggerSelector,
      requestLoad
    );
    window.jQuery(document).on("shiny:inputchanged.cgvFigureStudioLoader", function (event) {
      if (event.name === "navtabs" && event.value === "figure-studio") requestLoad();
    });
  }

  function ready() {
    bindShinyRestore();
    bindJqueryEvents();
    if (studioIsActive()) requestLoad();
  }

  document.addEventListener("pointerdown", warmFromInteraction, true);
  document.addEventListener("focusin", warmFromInteraction, true);
  document.addEventListener("click", warmFromInteraction, true);
  document.addEventListener("shown.bs.tab", warmFromInteraction, true);
  document.addEventListener("shiny:connected", function () {
    bindShinyRestore();
    bindJqueryEvents();
    if (studioIsActive()) requestLoad();
  });

  window.CGVFigureStudioLoader = {
    load: ensureLoaded,
    whenReady: function () {
      return ensureLoaded().then(function (api) {
        return flushRestoreQueue(api).then(function () { return api; });
      });
    },
    isLoaded: function () { return !!moduleApi(); },
    pendingRestoreCount: function () { return restoreQueue.length + pendingRestoreJobs; }
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", ready, { once: true });
  else ready();
})();
