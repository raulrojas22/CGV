/* ── Home Page Animations ─────────────────────────────────────────────────────
   Scroll-reveal, animated counters, floating particles, and staggered entries.
   Pure vanilla JS — no dependencies.
   ────────────────────────────────────────────────────────────────────────── */

(function () {
  "use strict";

  /* ── 1. Scroll-reveal (IntersectionObserver) ───────────────────────────── */
  function initScrollReveal() {
    var els = document.querySelectorAll(".home-reveal:not(.home-revealed)");
    if (!els.length) return;

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("home-revealed");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );

    els.forEach(function (el) {
      observer.observe(el);
    });
  }

  /* ── 2. Staggered children reveal ──────────────────────────────────────── */
  function initStaggerReveal() {
    var containers = document.querySelectorAll(".home-stagger-parent:not(.home-stagger-done)");
    if (!containers.length) return;

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting && !entry.target.classList.contains("home-stagger-done")) {
            entry.target.classList.add("home-stagger-done");
            var children = entry.target.querySelectorAll(".home-stagger-child");
            children.forEach(function (child, i) {
              child.style.transitionDelay = (i * 0.09) + "s";
              child.classList.add("home-revealed");
            });
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.08, rootMargin: "0px 0px -30px 0px" }
    );

    containers.forEach(function (c) { observer.observe(c); });
  }

  /* ── 3. Animated counters ──────────────────────────────────────────────── */
  function animateCounter(el) {
    var target = parseInt(el.getAttribute("data-count"), 10);
    if (isNaN(target)) return;
    var suffix = el.getAttribute("data-suffix") || "";
    var duration = 1600;
    var start = 0;
    var startTime = null;

    function step(ts) {
      if (!startTime) startTime = ts;
      var progress = Math.min((ts - startTime) / duration, 1);
      // ease-out cubic
      var ease = 1 - Math.pow(1 - progress, 3);
      var current = Math.round(start + (target - start) * ease);
      el.textContent = current.toLocaleString() + suffix;
      if (progress < 1) requestAnimationFrame(step);
    }

    requestAnimationFrame(step);
  }

  function initCounters() {
    var counters = document.querySelectorAll(".home-counter-value:not(.home-counter-done)");
    if (!counters.length) return;

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting && !entry.target.classList.contains("home-counter-done")) {
            entry.target.classList.add("home-counter-done");
            animateCounter(entry.target);
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.5 }
    );

    counters.forEach(function (c) { observer.observe(c); });
  }

  /* ── 4. Floating particles (DNA-themed) ────────────────────────────────── */
  function initParticles() {
    var canvas = document.getElementById("home-particles");
    if (!canvas) return;

    var ctx = canvas.getContext("2d");
    var particles = [];
    var NUM = 32;
    var raf;

    function resize() {
      var rect = canvas.parentElement.getBoundingClientRect();
      canvas.width = rect.width;
      canvas.height = rect.height;
    }

    function createParticle() {
      return {
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        r: Math.random() * 2.5 + 1,
        dx: (Math.random() - 0.5) * 0.4,
        dy: (Math.random() - 0.5) * 0.3,
        alpha: Math.random() * 0.35 + 0.08,
        color: Math.random() > 0.5 ? "24,188,156" : "44,62,80"
      };
    }

    function init() {
      resize();
      particles = [];
      for (var i = 0; i < NUM; i++) particles.push(createParticle());
    }

    function draw() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      particles.forEach(function (p) {
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx.fillStyle = "rgba(" + p.color + "," + p.alpha + ")";
        ctx.fill();

        p.x += p.dx;
        p.y += p.dy;

        if (p.x < -10) p.x = canvas.width + 10;
        if (p.x > canvas.width + 10) p.x = -10;
        if (p.y < -10) p.y = canvas.height + 10;
        if (p.y > canvas.height + 10) p.y = -10;
      });

      // Draw faint connecting lines between nearby particles
      for (var i = 0; i < particles.length; i++) {
        for (var j = i + 1; j < particles.length; j++) {
          var dx = particles[i].x - particles[j].x;
          var dy = particles[i].y - particles[j].y;
          var dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < 120) {
            ctx.beginPath();
            ctx.moveTo(particles[i].x, particles[i].y);
            ctx.lineTo(particles[j].x, particles[j].y);
            ctx.strokeStyle = "rgba(24,188,156," + (0.08 * (1 - dist / 120)) + ")";
            ctx.lineWidth = 0.6;
            ctx.stroke();
          }
        }
      }

      raf = requestAnimationFrame(draw);
    }

    init();
    draw();

    var resizeTimer;
    window.addEventListener("resize", function () {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(function () {
        init();
      }, 200);
    });

    // Pause when not visible
    document.addEventListener("visibilitychange", function () {
      if (document.hidden) {
        cancelAnimationFrame(raf);
      } else {
        draw();
      }
    });
  }

  /* ── 5. Typing effect for hero subtitle ────────────────────────────────── */
  var _typingTimer = null;          // guard: only one loop at a time

  function initTypingEffect() {
    var el = document.querySelector(".home-typing-text");
    if (!el) return;
    var words = JSON.parse(el.getAttribute("data-words") || "[]");
    if (!words.length) return;

    // Cancel any previous loop before starting a new one
    if (_typingTimer) { clearTimeout(_typingTimer); _typingTimer = null; }

    var wordIdx = 0;
    var charIdx = 0;
    var deleting = false;

    function tick() {
      var word = words[wordIdx];

      if (!deleting) {
        charIdx++;
        el.textContent = word.substring(0, charIdx);
        if (charIdx === word.length) {
          deleting = true;
          _typingTimer = setTimeout(tick, 3500);   // pause to read
          return;
        }
      } else {
        charIdx--;
        el.textContent = word.substring(0, charIdx);
        if (charIdx === 0) {
          deleting = false;
          wordIdx = (wordIdx + 1) % words.length;
          _typingTimer = setTimeout(tick, 500);     // pause before next word
          return;
        }
      }

      var speed = deleting ? 55 : 110;
      _typingTimer = setTimeout(tick, speed);
    }

    _typingTimer = setTimeout(tick, 500);           // small initial delay
  }

  /* ── 6. Workflow step progress animation ───────────────────────────────── */
  function initWorkflowProgress() {
    var strip = document.querySelector(".home-flow-strip-animated");
    if (!strip) return;

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            strip.classList.add("home-flow-active");
            observer.unobserve(strip);
          }
        });
      },
      { threshold: 0.3 }
    );

    observer.observe(strip);
  }

  /* ── 7. Help FAQ accordion ──────────────────────────────────────────────── */
  function initHelpFAQ() {
    var btns = document.querySelectorAll(".help-faq-question:not([data-faq-bound])");
    if (!btns.length) return;

    btns.forEach(function (btn) {
      btn.setAttribute("data-faq-bound", "1");
      btn.addEventListener("click", function () {
        var item = btn.closest(".help-faq-item");
        var isOpen = item.classList.contains("is-open");

        // Close all open items
        document.querySelectorAll(".help-faq-item.is-open").forEach(function (el) {
          el.classList.remove("is-open");
          var q = el.querySelector(".help-faq-question");
          if (q) q.setAttribute("aria-expanded", "false");
        });

        // Open this one if it was closed
        if (!isOpen) {
          item.classList.add("is-open");
          btn.setAttribute("aria-expanded", "true");
        }
      });
    });
  }

/* ── Boot ──────────────────────────────────────────────────────────────── */

  function boot() {
    initScrollReveal();
    initStaggerReveal();
    initCounters();
    initParticles();
    initTypingEffect();
    initWorkflowProgress();
    initHelpFAQ();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      boot();
    });
  } else {
    boot();
  }

  // Re-init when navigating back to home tab (Shiny)
  document.addEventListener("click", function (evt) {
    var t = evt && evt.target ? evt.target : null;
    if (t && t.closest('.app-nav-btn[data-target="home"]')) {
      setTimeout(boot, 180);
    }
    if (t && t.closest('.app-nav-btn[data-target="feedback"]')) {
      setTimeout(function () {
        initScrollReveal();
        initStaggerReveal();
      }, 180);
    }
  });

  // Re-init animations when Shiny renderUI injects dynamic home content
  // (e.g. home_stats_strip)
  if (typeof Shiny !== "undefined" && Shiny.addCustomMessageHandler == null) {
    // fallback: use MutationObserver
  }
  var _homeDynObserver = new MutationObserver(function (mutations) {
    var dominated = false;
    mutations.forEach(function (m) {
      if (m.addedNodes && m.addedNodes.length) {
        for (var i = 0; i < m.addedNodes.length; i++) {
          var node = m.addedNodes[i];
          if (node.nodeType === 1 && (
            node.classList.contains("home-reveal") ||
            node.classList.contains("home-stats-strip") ||
            node.classList.contains("home-stagger-parent") ||
            node.querySelector && (node.querySelector(".home-reveal") || node.querySelector(".home-counter-value"))
          )) {
            dominated = true;
            break;
          }
        }
      }
    });
    if (dominated) {
      setTimeout(boot, 60);
    }
  });
  var _homePane = document.querySelector(".app-home-pane");
  if (_homePane) {
    _homeDynObserver.observe(_homePane, { childList: true, subtree: true });
  }
})();
