(function () {
  "use strict";

  var FOOTER_SELECTOR = ".plot-card-footer";
  var MOBILE_WRAP_QUERY = "(max-width: 576px)";
  var EDGE_TOLERANCE_PX = 2;
  var MIN_SCROLL_STEP_PX = 180;
  var initializedFooters = new WeakSet();
  var refreshFrame = null;
  var resizeObserver = null;

  function prefersReducedMotion() {
    return window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  function isMobileWrapMode() {
    return window.matchMedia && window.matchMedia(MOBILE_WRAP_QUERY).matches;
  }

  function footerParts(footer) {
    return {
      viewport: footer.querySelector(".plot-card-footer-scroll"),
      row: footer.querySelector(".footer-row"),
      previous: footer.querySelector(".plot-card-footer-nav-prev"),
      next: footer.querySelector(".plot-card-footer-nav-next")
    };
  }

  function setControlVisible(button, visible) {
    if (!button) return;
    button.classList.toggle("is-visible", visible);
    button.disabled = !visible;
    button.tabIndex = visible ? 0 : -1;
    button.setAttribute("aria-hidden", visible ? "false" : "true");
  }

  function naturalContentWidth(row) {
    if (!row) return 0;

    var children = Array.prototype.slice.call(row.children);
    if (!children.length) return 0;

    return children.reduce(function (total, child) {
      return total + child.getBoundingClientRect().width;
    }, 0);
  }

  function updateDirectionalControls(footer) {
    var parts = footerParts(footer);
    if (!parts.viewport) return;

    var maxScrollLeft = Math.max(0, parts.viewport.scrollWidth - parts.viewport.clientWidth);
    var hasOverflow = footer.classList.contains("has-footer-overflow") &&
      maxScrollLeft > EDGE_TOLERANCE_PX;
    var currentScrollLeft = Math.max(0, parts.viewport.scrollLeft);

    setControlVisible(
      parts.previous,
      hasOverflow && currentScrollLeft > EDGE_TOLERANCE_PX
    );
    setControlVisible(
      parts.next,
      hasOverflow && currentScrollLeft < maxScrollLeft - EDGE_TOLERANCE_PX
    );
  }

  function refreshFooter(footer) {
    if (!footer || !footer.isConnected) return;

    var parts = footerParts(footer);
    if (!parts.viewport) return;

    if (isMobileWrapMode()) {
      footer.classList.remove("has-footer-overflow");
      parts.viewport.scrollLeft = 0;
      parts.viewport.tabIndex = -1;
      setControlVisible(parts.previous, false);
      setControlVisible(parts.next, false);
      return;
    }

    var footerStyle = window.getComputedStyle(footer);
    var horizontalPadding =
      parseFloat(footerStyle.paddingLeft || "0") +
      parseFloat(footerStyle.paddingRight || "0");
    var contentWidth = naturalContentWidth(parts.row);
    var availableWidth = Math.max(0, footer.clientWidth - horizontalPadding);
    var hasOverflow = contentWidth > availableWidth + EDGE_TOLERANCE_PX;

    footer.classList.toggle("has-footer-overflow", hasOverflow);
    parts.viewport.tabIndex = hasOverflow ? 0 : -1;
    if (!hasOverflow) parts.viewport.scrollLeft = 0;

    updateDirectionalControls(footer);
  }

  function scrollFooter(footer, direction) {
    var parts = footerParts(footer);
    if (!parts.viewport || !footer.classList.contains("has-footer-overflow")) return;

    var step = Math.max(
      MIN_SCROLL_STEP_PX,
      Math.round(parts.viewport.clientWidth * 0.68)
    );
    parts.viewport.scrollBy({
      left: direction * step,
      behavior: prefersReducedMotion() ? "auto" : "smooth"
    });
  }

  function handleViewportKeydown(event, footer) {
    if (!footer.classList.contains("has-footer-overflow")) return;

    if (event.key === "ArrowLeft") {
      event.preventDefault();
      scrollFooter(footer, -1);
    } else if (event.key === "ArrowRight") {
      event.preventDefault();
      scrollFooter(footer, 1);
    } else if (event.key === "Home") {
      event.preventDefault();
      footerParts(footer).viewport.scrollTo({
        left: 0,
        behavior: prefersReducedMotion() ? "auto" : "smooth"
      });
    } else if (event.key === "End") {
      event.preventDefault();
      var viewport = footerParts(footer).viewport;
      viewport.scrollTo({
        left: viewport.scrollWidth,
        behavior: prefersReducedMotion() ? "auto" : "smooth"
      });
    }
  }

  function initializeFooter(footer) {
    if (!footer || initializedFooters.has(footer)) return;

    var parts = footerParts(footer);
    if (!parts.viewport) return;

    initializedFooters.add(footer);
    parts.viewport.addEventListener("scroll", function () {
      updateDirectionalControls(footer);
    }, { passive: true });
    parts.viewport.addEventListener("keydown", function (event) {
      handleViewportKeydown(event, footer);
    });

    if (parts.previous) {
      parts.previous.addEventListener("click", function () {
        scrollFooter(footer, -1);
      });
    }
    if (parts.next) {
      parts.next.addEventListener("click", function () {
        scrollFooter(footer, 1);
      });
    }

    if (resizeObserver) {
      resizeObserver.observe(footer);
      resizeObserver.observe(parts.viewport);
    }

    refreshFooter(footer);
  }

  function scanFooters(root) {
    var scope = root && root.querySelectorAll ? root : document;
    var footers = [];

    if (scope.matches && scope.matches(FOOTER_SELECTOR)) footers.push(scope);
    Array.prototype.push.apply(
      footers,
      Array.prototype.slice.call(scope.querySelectorAll(FOOTER_SELECTOR))
    );

    footers.forEach(function (footer) {
      initializeFooter(footer);
      refreshFooter(footer);
    });
  }

  function scheduleRefresh() {
    if (refreshFrame !== null) return;
    refreshFrame = window.requestAnimationFrame(function () {
      refreshFrame = null;
      scanFooters(document);
    });
  }

  function boot() {
    if ("ResizeObserver" in window) {
      resizeObserver = new ResizeObserver(function (entries) {
        entries.forEach(function (entry) {
          var footer = entry.target.closest
            ? entry.target.closest(FOOTER_SELECTOR)
            : null;
          if (footer) refreshFooter(footer);
        });
      });
    }

    scanFooters(document);

    if (window.jQuery) {
      window.jQuery(document)
        .off("shiny:idle.cgvFooterScrollControls")
        .on("shiny:idle.cgvFooterScrollControls", scheduleRefresh);
    }

    window.addEventListener("resize", function () {
      scheduleRefresh();
    }, { passive: true });

    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function () {
        scheduleRefresh();
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot, { once: true });
  } else {
    boot();
  }
})();
