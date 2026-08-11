/* ChillMate site behaviour.

   Everything here is an enhancement. The pages are complete and readable with
   this file blocked: the walk falls back to one phone per step, the helpline
   list falls back to every country rendered in the markup, and the theme falls
   back to the reader's system preference. */

(function () {
  'use strict';

  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---------- theme toggle ---------- */

  function initTheme() {
    var btn = document.querySelector('[data-theme-toggle]');
    if (!btn) return;

    function systemIsDark() {
      return !window.matchMedia('(prefers-color-scheme: light)').matches;
    }
    function currentIsDark() {
      var set = document.documentElement.getAttribute('data-theme');
      if (set === 'dark') return true;
      if (set === 'light') return false;
      return systemIsDark();
    }
    function paint() {
      var dark = currentIsDark();
      btn.setAttribute('aria-pressed', String(!dark));
      btn.querySelector('[data-theme-label]').textContent = dark ? 'Light' : 'Dark';
      var use = btn.querySelector('use');
      if (use) use.setAttribute('href', dark ? '#i-sun' : '#i-moon');
    }

    btn.hidden = false;
    paint();

    btn.addEventListener('click', function () {
      var next = currentIsDark() ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      try { localStorage.setItem('cm-theme', next); } catch (e) { /* private mode */ }
      paint();
    });
  }

  /* ---------- reveal on scroll ---------- */

  function initReveal() {
    var items = document.querySelectorAll('.reveal');
    if (!items.length) return;
    if (reduceMotion || !('IntersectionObserver' in window)) {
      items.forEach(function (el) { el.classList.add('is-in'); });
      return;
    }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-in');
        io.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    items.forEach(function (el) { io.observe(el); });
  }

  /* ---------- the guided walk ---------- */

  function initWalk() {
    var walk = document.querySelector('[data-walk]');
    if (!walk || !('IntersectionObserver' in window)) return;

    var wide = window.matchMedia('(min-width: 900px)');
    var steps = Array.prototype.slice.call(walk.querySelectorAll('.walk-step'));
    var frames = Array.prototype.slice.call(walk.querySelectorAll('.walk-stage img'));
    if (steps.length !== frames.length || !frames.length) return;

    var io = null;

    function show(index) {
      frames.forEach(function (img, i) { img.classList.toggle('is-shown', i === index); });
      steps.forEach(function (step, i) { step.classList.toggle('is-active', i === index); });
    }

    function enable() {
      if (io) return;
      walk.classList.add('is-sticky');
      show(0);
      io = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) show(steps.indexOf(entry.target));
        });
      }, { rootMargin: '-45% 0px -45% 0px', threshold: 0 });
      steps.forEach(function (step) { io.observe(step); });
    }

    function disable() {
      if (!io) return;
      io.disconnect();
      io = null;
      walk.classList.remove('is-sticky');
      steps.forEach(function (step) { step.classList.remove('is-active'); });
    }

    function sync() { wide.matches ? enable() : disable(); }

    sync();
    wide.addEventListener('change', sync);
  }

  /* ---------- copy to clipboard ---------- */

  function initCopy() {
    document.querySelectorAll('[data-copy]').forEach(function (btn) {
      if (!navigator.clipboard) { btn.hidden = true; return; }
      btn.hidden = false;
      btn.addEventListener('click', function () {
        navigator.clipboard.writeText(btn.getAttribute('data-copy')).then(function () {
          var note = btn.parentNode.querySelector('.copy-done');
          if (!note) return;
          note.textContent = btn.getAttribute('data-copied-label') || 'Copied';
          setTimeout(function () { note.textContent = ''; }, 2200);
        });
      });
    });
  }

  /* ---------- back to top ---------- */

  function initToTop() {
    var btn = document.querySelector('[data-to-top]');
    if (!btn) return;
    btn.hidden = false;
    var ticking = false;
    function update() {
      btn.classList.toggle('is-shown', window.scrollY > 700);
      ticking = false;
    }
    window.addEventListener('scroll', function () {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(update);
    }, { passive: true });
    btn.addEventListener('click', function () {
      window.scrollTo({ top: 0, behavior: reduceMotion ? 'auto' : 'smooth' });
    });
    update();
  }

  /* ---------- the mark draws itself ---------- */

  function initDraw() {
    if (reduceMotion) return;
    document.querySelectorAll('.draw path').forEach(function (path) {
      if (typeof path.getTotalLength !== 'function') return;
      var len = Math.ceil(path.getTotalLength());
      path.style.setProperty('--len', len);
    });
  }

  /* ---------- language menu ---------- */

  function initLangMenu() {
    var menu = document.querySelector('.lang');
    if (!menu) return;
    document.addEventListener('click', function (event) {
      if (menu.open && !menu.contains(event.target)) menu.open = false;
    });
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && menu.open) {
        menu.open = false;
        menu.querySelector('summary').focus();
      }
    });
  }

  /* ---------- country helplines ---------- */

  function initCountries() {
    var root = document.querySelector('[data-countries]');
    if (!root) return;
    var select = root.querySelector('select');
    var panels = Array.prototype.slice.call(root.querySelectorAll('.country-panel'));
    if (!select || !panels.length) return;

    function show(code) {
      var matched = false;
      panels.forEach(function (panel) {
        var mine = panel.getAttribute('data-country') === code;
        panel.hidden = !mine;
        if (mine) matched = true;
      });
      if (!matched) panels[panels.length - 1].hidden = false;
    }

    // With scripting off every panel is visible, which is verbose but complete.
    // Narrowing to one only happens once we can offer the picker.
    select.addEventListener('change', function () {
      show(select.value);
      try { localStorage.setItem('cm-country', select.value); } catch (e) { /* private mode */ }
    });

    var saved = null;
    try { saved = localStorage.getItem('cm-country'); } catch (e) { /* private mode */ }

    var guess = saved || guessCountry();
    if (guess && select.querySelector('option[value="' + guess + '"]')) select.value = guess;
    show(select.value);
  }

  function guessCountry() {
    // Best effort from the browser's own locale. No network call, no lookup
    // service: guessing wrong just means one extra tap on the picker.
    var tags = (navigator.languages && navigator.languages.length)
      ? navigator.languages
      : [navigator.language || ''];
    for (var i = 0; i < tags.length; i++) {
      var parts = String(tags[i]).split('-');
      if (parts.length > 1) {
        var region = parts[parts.length - 1].toUpperCase();
        if (/^[A-Z]{2}$/.test(region)) return region;
      }
    }
    return null;
  }

  /* ---------- offline support page ---------- */

  function initServiceWorker() {
    if (!('serviceWorker' in navigator)) return;
    if (location.protocol !== 'https:' && location.hostname !== 'localhost') return;
    var scope = document.documentElement.getAttribute('data-sw-scope');
    if (!scope) return;
    navigator.serviceWorker.register(scope + 'sw.js', { scope: scope }).catch(function () {
      // An unregistered worker costs the reader nothing. Stay quiet.
    });
  }

  function boot() {
    initTheme();
    initReveal();
    initWalk();
    initCopy();
    initToTop();
    initDraw();
    initLangMenu();
    initCountries();
    initServiceWorker();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
