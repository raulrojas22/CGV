(function () {
  "use strict";

  var RELEASE_SOURCE = {
    api: "https://api.github.com/repos/raulrojas22/CGV-Desktop-Releases/releases?per_page=20",
    center: "https://github.com/raulrojas22/CGV-Desktop-Releases/releases"
  };
  var MIN_ASSET_BYTES = 5 * 1024 * 1024;

  function ready(callback) {
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", callback, { once: true });
    else callback();
  }

  function setText(root, selector, value) {
    var node = root.querySelector(selector);
    if (node) node.textContent = value;
  }

  function formatBytes(bytes) {
    var value = Number(bytes || 0);
    if (!Number.isFinite(value) || value <= 0) return "";
    if (value >= 1073741824) return (value / 1073741824).toFixed(1) + " GB";
    return Math.round(value / 1048576) + " MB";
  }

  function formatDate(value) {
    if (!value) return "—";
    var date = new Date(value);
    if (Number.isNaN(date.getTime())) return "—";
    try {
      return new Intl.DateTimeFormat(undefined, { year: "numeric", month: "short", day: "numeric" }).format(date);
    } catch (_) {
      return date.toISOString().slice(0, 10);
    }
  }

  function assetKind(asset) {
    var name = String((asset && asset.name) || "").toLowerCase();
    var size = Number((asset && asset.size) || 0);
    if (!name || (size > 0 && size < MIN_ASSET_BYTES)) return "";
    if (/arm64.*\.dmg$/.test(name) || /aarch64.*\.dmg$/.test(name)) return "mac-arm64";
    if (/(x64|x86_64|intel).*\.dmg$/.test(name)) return "mac-x64";
    if (/\.appimage$/.test(name)) return "linux-appimage";
    if (/\.deb$/.test(name)) return "linux-deb";
    if (/\.(exe|msi)$/.test(name) && /(win|windows|setup|installer|cgv)/.test(name)) return "windows-x64";
    return "";
  }

  function platformForKind(kind) {
    if (kind.indexOf("mac-") === 0) return "mac";
    if (kind.indexOf("linux-") === 0) return "linux";
    if (kind.indexOf("windows-") === 0) return "windows";
    return "other";
  }

  function mapRelease(release) {
    var mapped = {};
    var assets = Array.isArray(release && release.assets) ? release.assets : [];
    assets.forEach(function (asset) {
      var kind = assetKind(asset);
      if (kind && !mapped[kind] && asset.browser_download_url) mapped[kind] = asset;
    });
    return mapped;
  }

  function fetchJson(url) {
    return fetch(url, { headers: { Accept: "application/vnd.github+json" } }).then(function (response) {
      if (!response.ok) throw new Error("GitHub release service returned " + response.status);
      return response.json();
    });
  }

  function findPublicRelease() {
    return fetchJson(RELEASE_SOURCE.api).then(function (releases) {
      var list = Array.isArray(releases) ? releases.filter(function (release) {
        return release && !release.draft && !release.prerelease;
      }) : [];
      for (var index = 0; index < list.length; index += 1) {
        var assets = mapRelease(list[index]);
        if (Object.keys(assets).length) return { release: list[index], assets: assets, source: RELEASE_SOURCE };
      }
      return null;
    }).catch(function () {
      return null;
    });
  }

  function normalizePlatform(value) {
    var platform = String(value || "").toLowerCase();
    if (/darwin|mac|macos/.test(platform)) return "mac";
    if (/win/.test(platform)) return "windows";
    if (/linux|x11/.test(platform)) return "linux";
    return "other";
  }

  function normalizeArch(value) {
    var arch = String(value || "").toLowerCase();
    if (/arm|aarch64/.test(arch)) return "arm64";
    if (/x86|x64|amd64|intel/.test(arch)) return "x64";
    return "unknown";
  }

  function browserPlatform() {
    return normalizePlatform(
      (navigator.userAgentData && navigator.userAgentData.platform) ||
      navigator.platform ||
      navigator.userAgent
    );
  }

  function browserArch(platform) {
    var userAgent = String(navigator.userAgent || "").toLowerCase();
    if (/arm64|aarch64/.test(userAgent)) return "arm64";
    // Apple intentionally reports many Apple Silicon browsers as "Intel".
    // Keep the choice open unless User-Agent Client Hints or Electron provides
    // an architecture that can be trusted.
    if (platform === "mac") return "unknown";
    return normalizeArch(userAgent);
  }

  function resolveContext() {
    var detectedPlatform = browserPlatform();
    var base = {
      isDesktop: Boolean(window.cgvDesktop && typeof window.cgvDesktop.getRuntime === "function"),
      platform: detectedPlatform,
      arch: browserArch(detectedPlatform),
      appVersion: ""
    };
    if (!base.isDesktop) return Promise.resolve(base);
    return window.cgvDesktop.getRuntime().then(function (runtime) {
      runtime = runtime || {};
      base.platform = normalizePlatform(runtime.platform) !== "other" ? normalizePlatform(runtime.platform) : base.platform;
      base.arch = normalizeArch(runtime.arch) !== "unknown" ? normalizeArch(runtime.arch) : base.arch;
      base.appVersion = String(runtime.appVersion || "");
      return base;
    }).catch(function () {
      return base;
    });
  }

  function refineBrowserArchitecture(context) {
    if (context.isDesktop || context.platform !== "mac" || context.arch !== "unknown") return Promise.resolve(context);
    if (!navigator.userAgentData || typeof navigator.userAgentData.getHighEntropyValues !== "function") return Promise.resolve(context);
    return navigator.userAgentData.getHighEntropyValues(["architecture", "bitness"]).then(function (values) {
      context.arch = normalizeArch(values && values.architecture);
      return context;
    }).catch(function () {
      return context;
    });
  }

  function recommendedKind(context) {
    if (context.platform === "mac") {
      if (context.arch === "arm64") return "mac-arm64";
      if (context.arch === "x64") return "mac-x64";
      return "";
    }
    if (context.platform === "linux") return "linux-appimage";
    if (context.platform === "windows") return "windows-x64";
    return "";
  }

  function platformLabel(context) {
    if (context.platform === "mac") return context.arch === "arm64" ? "macOS · Apple Silicon" : (context.arch === "x64" ? "macOS · Intel" : "macOS");
    if (context.platform === "linux") return "Linux";
    if (context.platform === "windows") return "Windows";
    return "this device";
  }

  function setReleaseState(root, kind, iconClass, copy) {
    var node = root.querySelector("#cgv-download-release-status");
    if (!node) return;
    node.className = "cgv-download-release-status " + kind;
    var icon = document.createElement("i");
    var text = document.createElement("span");
    icon.className = "fas " + iconClass;
    text.textContent = copy;
    node.replaceChildren(icon, text);
  }

  function markPlatform(root, context) {
    root.querySelectorAll("[data-cgv-platform-card]").forEach(function (card) {
      var matches = card.getAttribute("data-cgv-platform-card") === context.platform;
      card.classList.toggle("is-recommended", matches && !context.isDesktop);
      card.classList.toggle("is-current-platform", matches && context.isDesktop);
      var badge = card.querySelector(".cgv-download-recommended-badge span");
      if (badge && context.isDesktop && matches) badge.textContent = "Current Desktop platform";
    });
  }

  function applyContext(root, context) {
    root.setAttribute("data-cgv-runtime", context.isDesktop ? "desktop" : "web");
    root.setAttribute("data-cgv-platform", context.platform);
    root.setAttribute("data-cgv-architecture", context.arch);
    markPlatform(root, context);

    var contextIcon = root.querySelector("[data-cgv-context-icon]");
    var primary = root.querySelector("#cgv-download-primary-action");
    if (context.isDesktop) {
      if (contextIcon) contextIcon.className = "fas fa-laptop";
      setText(root, "[data-cgv-runtime-label]", "CGV Desktop" + (context.appVersion ? " " + context.appVersion : ""));
      setText(root, "[data-cgv-hero-copy]", "You are already using the private local CGV workspace on " + platformLabel(context) + ". Continue here, open CGV Web, or download an installer for another operating system.");
      if (primary) {
        primary.href = root.getAttribute("data-cgv-web-url") || "https://cgv.mobilomics.org";
        primary.target = "_blank";
        primary.rel = "noopener noreferrer";
        var icon = primary.querySelector("i");
        if (icon) icon.className = "fas fa-arrow-up-right-from-square";
      }
      setText(root, "[data-cgv-primary-label]", "Open CGV Web");
      setText(root, "[data-cgv-web-title]", "Need the hosted CGV workspace?");
      setText(root, "[data-cgv-web-copy]", "Use CGV Web when you want server-managed references, or share the browser version with collaborators who do not have Desktop installed.");
    } else {
      setText(root, "[data-cgv-runtime-label]", "CGV Web · " + platformLabel(context) + " detected");
    }
  }

  function connectAsset(root, kind, asset) {
    var action = root.querySelector('[data-cgv-desktop-asset="' + kind + '"]');
    if (!action || !asset || !asset.browser_download_url) return false;
    action.href = asset.browser_download_url;
    action.target = "_blank";
    action.rel = "noopener noreferrer";
    action.removeAttribute("aria-disabled");
    action.removeAttribute("tabindex");
    var label = action.querySelector("span");
    if (label) label.textContent = "Download" + (formatBytes(asset.size) ? " · " + formatBytes(asset.size) : "");
    return true;
  }

  function updatePlatformStates(root, assets) {
    ["mac", "linux", "windows"].forEach(function (platform) {
      var card = root.querySelector('[data-cgv-platform-card="' + platform + '"]');
      if (!card) return;
      var count = Object.keys(assets).filter(function (kind) { return platformForKind(kind) === platform; }).length;
      card.classList.toggle("has-assets", count > 0);
      var state = card.querySelector(".cgv-download-platform-state");
      if (!state) return;
      if (count > 0) state.textContent = count === 1 ? "Available now" : count + " builds available";
      else if (platform === "windows") state.textContent = "In development";
      else state.textContent = "Installer pending";
    });
  }

  function updateReleaseDetails(root, result) {
    var release = result.release || {};
    var assets = result.assets || {};
    var version = String(release.name || release.tag_name || "Public release");
    var platforms = Array.from(new Set(Object.keys(assets).map(platformForKind))).filter(function (value) { return value !== "other"; });
    var labels = { mac: "macOS", linux: "Linux", windows: "Windows" };

    setText(root, "[data-cgv-release-title]", version);
    setText(root, "[data-cgv-release-copy]", "This release contains public Desktop installers. Each download below links directly to its official GitHub release asset.");
    setText(root, "[data-cgv-release-version]", String(release.tag_name || version));
    setText(root, "[data-cgv-release-date]", formatDate(release.published_at));
    setText(root, "[data-cgv-release-platforms]", platforms.map(function (platform) { return labels[platform] || platform; }).join(" · ") || "Waiting for assets");

    var notesNode = root.querySelector("[data-cgv-release-notes]");
    if (notesNode) {
      var noteLines = String(release.body || "").split(/\r?\n/).map(function (line) {
        return line.replace(/^\s*[-*#>]+\s*/, "").replace(/\[([^\]]+)\]\([^\)]+\)/g, "$1").replace(/[*_`]/g, "").trim();
      }).filter(function (line) {
        return line.length >= 8;
      }).slice(0, 4);
      if (!noteLines.length) noteLines = ["Open the official GitHub release for the complete notes and checksums."];
      notesNode.replaceChildren();
      noteLines.forEach(function (line) {
        var item = document.createElement("li");
        item.textContent = line;
        notesNode.appendChild(item);
      });
    }

    var center = root.querySelector("[data-cgv-release-center]");
    if (center) center.href = result.source.center;
  }

  function applyRelease(root, context, result) {
    if (!result) {
      setReleaseState(root, "is-pending", "fa-clock", "No public Desktop installer is attached yet. Buttons will activate automatically after an official release is published.");
      setText(root, "[data-cgv-release-title]", "Public installers pending");
      setText(root, "[data-cgv-release-copy]", "Builds are still being prepared and verified. No local or unpublished artifact is exposed from this page.");
      return;
    }

    var connected = 0;
    Object.keys(result.assets).forEach(function (kind) {
      if (connectAsset(root, kind, result.assets[kind])) connected += 1;
    });
    updatePlatformStates(root, result.assets);
    updateReleaseDetails(root, result);
    setReleaseState(root, "is-ready", "fa-circle-check", connected + (connected === 1 ? " verified installer is" : " verified installers are") + " available from the official release.");

    if (context.isDesktop) return;
    var kind = recommendedKind(context);
    var asset = kind ? result.assets[kind] : null;
    var primary = root.querySelector("#cgv-download-primary-action");
    if (!primary || !asset) return;
    primary.href = asset.browser_download_url;
    primary.target = "_blank";
    primary.rel = "noopener noreferrer";
    setText(root, "[data-cgv-primary-label]", "Download for " + platformLabel(context));
  }

  function bindDisabledAssets(root) {
    root.addEventListener("click", function (event) {
      var disabled = event.target.closest('[data-cgv-desktop-asset][aria-disabled="true"]');
      if (disabled) event.preventDefault();
    });
  }

  function init() {
    var root = document.getElementById("cgv-desktop-downloads-page");
    if (!root || root.dataset.cgvInitialized === "true") return;
    root.dataset.cgvInitialized = "true";
    bindDisabledAssets(root);

    resolveContext()
      .then(refineBrowserArchitecture)
      .then(function (context) {
        applyContext(root, context);
        return findPublicRelease().then(function (result) {
          applyRelease(root, context, result);
        });
      })
      .catch(function () {
        setReleaseState(root, "is-error", "fa-triangle-exclamation", "Installer availability could not be verified. Try the official release center again shortly.");
      });
  }

  ready(init);
})();
