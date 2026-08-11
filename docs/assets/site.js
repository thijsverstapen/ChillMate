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

  /* ---------- the scroll-driven walk ---------- */

  function initWalk() {
    var walk = document.querySelector('[data-walk]');
    if (!walk) return;

    var wide = window.matchMedia('(min-width: 940px)');
    var steps = Array.prototype.slice.call(walk.querySelectorAll('.walk-step'));
    var frames = Array.prototype.slice.call(walk.querySelectorAll('.stage-phone img'));
    var device = walk.querySelector('.stage-phone');
    // data-walk is on the track element itself, so do not go looking
    // for a descendant that will never be there.
    var track = walk.classList.contains('track') ? walk : walk.querySelector('.track');
    if (!device || !track || steps.length !== frames.length || !frames.length) return;

    var ticking = false;
    var shown = -1;

    function show(index) {
      if (index === shown) return;
      shown = index;
      frames.forEach(function (img, i) { img.classList.toggle('is-shown', i === index); });
      steps.forEach(function (step, i) { step.classList.toggle('is-active', i === index); });
    }

    // Progress of the track through the viewport, 0 to 1. Everything the stage
    // does is a function of this one number, which is what makes the rotation
    // and the screen changes feel like one movement rather than two effects.
    function progress() {
      var box = track.getBoundingClientRect();
      var travel = box.height - window.innerHeight;
      if (travel <= 0) return 0;
      return Math.min(1, Math.max(0, -box.top / travel));
    }

    function frame() {
      ticking = false;
      var p = progress();

      show(Math.min(steps.length - 1, Math.floor(p * steps.length + 0.0001)));

      if (reduceMotion) return;
      // A slow turn across the whole chapter, plus a shallow tilt and a breath
      // of scale. Small numbers on purpose: past about 16 degrees the screen
      // starts to read as a photograph of a phone rather than a phone.
      var swing = (p - 0.5) * 2;
      device.style.setProperty('--ry', (swing * 13).toFixed(2) + 'deg');
      device.style.setProperty('--rx', (Math.cos(p * Math.PI) * 3.5).toFixed(2) + 'deg');
      device.style.setProperty('--ty', (Math.sin(p * Math.PI) * -14).toFixed(2) + 'px');
      device.style.setProperty('--sc', (1 + Math.sin(p * Math.PI) * 0.03).toFixed(4));
    }

    function onScroll() {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(frame);
    }

    function enable() {
      walk.classList.add('is-sticky');
      window.addEventListener('scroll', onScroll, { passive: true });
      window.addEventListener('resize', onScroll, { passive: true });
      frame();
    }

    function disable() {
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onScroll);
      walk.classList.remove('is-sticky');
      steps.forEach(function (step) { step.classList.remove('is-active'); });
      shown = -1;
    }

    function sync() { wide.matches ? enable() : disable(); }

    sync();
    wide.addEventListener('change', sync);
  }

  /* ---------- sticky sub-nav ---------- */

  function initSubnav() {
    var nav = document.querySelector('[data-subnav]');
    if (!nav) return;
    var links = Array.prototype.slice.call(nav.querySelectorAll('a[href^="#"]'));
    var targets = links
      .map(function (a) { return document.getElementById(a.getAttribute('href').slice(1)); })
      .filter(Boolean);

    var hero = document.querySelector('.hero-full');
    var ticking = false;

    function frame() {
      ticking = false;
      var past = hero ? window.scrollY > hero.offsetHeight * 0.7 : window.scrollY > 400;
      nav.classList.toggle('is-shown', past);

      // Whichever chapter owns the middle of the screen.
      var middle = window.innerHeight * 0.45;
      var current = -1;
      targets.forEach(function (el, i) {
        if (el.getBoundingClientRect().top <= middle) current = i;
      });
      links.forEach(function (a, i) { a.classList.toggle('is-current', i === current); });
    }

    window.addEventListener('scroll', function () {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(frame);
    }, { passive: true });
    frame();
  }

  /* ---------- staggered entrances ---------- */

  function initStagger() {
    var groups = document.querySelectorAll('.stagger');
    if (!groups.length) return;
    if (reduceMotion || !('IntersectionObserver' in window)) {
      groups.forEach(function (g) { g.classList.add('is-in'); });
      return;
    }
    groups.forEach(function (group) {
      Array.prototype.slice.call(group.children).forEach(function (child, i) {
        child.style.setProperty('--i', i);
      });
    });
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-in');
        io.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -12% 0px', threshold: 0.05 });
    groups.forEach(function (g) { io.observe(g); });
  }

  /* ---------- the playable risk checker ---------- */

  function initDemo() {
    var root = document.querySelector('[data-demo]');
    if (!root) return;
    var source = document.getElementById('cm-interactions');
    if (!source) return;

    var data;
    try { data = JSON.parse(source.textContent); } catch (e) { return; }

    var out = root.querySelector('[data-demo-out]');
    var chips = Array.prototype.slice.call(root.querySelectorAll('.demo-chip'));
    var reset = root.querySelector('[data-demo-reset]');
    var shortcut = root.querySelector('[data-demo-try]');
    var picked = new Set();

    var ORDER = { critical: 3, serious: 2, caution: 1 };

    // Mirrors SubstanceInteractionChecker.warnings(for:): a rule fires when
    // every substance it names is selected, then severity descending, then by
    // the rule's own identity so equal severities never swap around.
    function matches() {
      return data.rules
        .filter(function (rule) {
          return rule.substances.every(function (s) { return picked.has(s); });
        })
        .sort(function (a, b) {
          if (ORDER[a.level] !== ORDER[b.level]) return ORDER[b.level] - ORDER[a.level];
          return a.substances.join('+') < b.substances.join('+') ? -1 : 1;
        });
    }

    function card(cls, tag, body) {
      var el = document.createElement('div');
      el.className = 'verdict verdict--' + cls;
      if (tag) {
        var t = document.createElement('span');
        t.className = 'tag';
        t.textContent = tag;
        el.appendChild(t);
      }
      var p = document.createElement('p');
      p.textContent = body;
      el.appendChild(p);
      return el;
    }

    function render() {
      out.textContent = '';
      if (picked.size < 2) {
        out.appendChild(card('empty', '', data.copy.empty));
        return;
      }
      var found = matches();
      if (!found.length) {
        out.appendChild(card('none', data.copy.noneTitle, data.copy.noneBody));
        return;
      }
      found.forEach(function (rule) {
        out.appendChild(card(rule.level, data.levels[rule.level], rule.warning));
      });
    }

    function setChip(chip, on) {
      chip.setAttribute('aria-pressed', String(on));
      if (on) picked.add(chip.dataset.substance);
      else picked.delete(chip.dataset.substance);
    }

    chips.forEach(function (chip) {
      chip.addEventListener('click', function () {
        setChip(chip, chip.getAttribute('aria-pressed') !== 'true');
        render();
      });
    });

    if (reset) {
      reset.addEventListener('click', function () {
        chips.forEach(function (chip) { setChip(chip, false); });
        render();
      });
    }

    if (shortcut) {
      shortcut.addEventListener('click', function () {
        chips.forEach(function (chip) {
          setChip(chip, chip.dataset.substance === 'GHB' || chip.dataset.substance === 'Alcohol');
        });
        render();
        out.scrollIntoView({ block: 'nearest', behavior: reduceMotion ? 'auto' : 'smooth' });
      });
    }

    render();
  }

  /* ---------- inert video, played only if motion is welcome ---------- */

  function initVideo() {
    document.querySelectorAll('video[data-autoplay]').forEach(function (video) {
      video.preload = 'metadata';
      if (reduceMotion) {
        video.controls = true;
        return;
      }
      video.autoplay = true;
      video.play().catch(function () { video.controls = true; });
    });
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
    initStagger();
    initWalk();
    initSubnav();
    initDemo();
    initVideo();
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
