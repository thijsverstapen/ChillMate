/* ChillMate site behaviour.

   Everything here is an enhancement. The pages are complete and readable with
   this file blocked: the walk falls back to one phone per step, and the
   helpline list falls back to every country rendered in the markup. */

(function () {
  'use strict';

  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

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
    // Scoped to the substance chips: the timing control reuses the same class
    // for its look, and picking those up put `undefined` in the selection and
    // threw the moment a deep link tried to lowercase it.
    var chips = Array.prototype.slice.call(root.querySelectorAll('.demo-chip[data-substance]'));
    var meds = root.querySelector('[data-demo-meds]');
    var medsOut = root.querySelector('[data-demo-meds-out]');
    var timingButtons = Array.prototype.slice.call(root.querySelectorAll('[data-timing]'));
    var reset = root.querySelector('[data-demo-reset]');
    var shortcut = root.querySelector('[data-demo-try]');
    var share = root.querySelector('[data-demo-share]');

    var picked = new Set();
    var timing = 'sameSession';

    var ORDER = { critical: 3, serious: 2, caution: 1 };
    var RANK = { lower: 0, caution: 1, high: 2 };
    var SEROTONERGIC = ['MDMA', '3MMC', 'Cocaine', 'Psychedelics'];
    var STIMULANTS = ['MDMA', '3MMC', 'Cocaine'];

    function countIn(list) {
      return list.filter(function (s) { return picked.has(s); }).length;
    }

    // The same normalisation the app uses: diacritics folded, lowercased, then
    // a plain substring test against every alias in the group.
    function normalise(value) {
      return value.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
    }

    function medicationMatches() {
      var typed = normalise(meds ? meds.value : '').trim();
      if (!typed) return [];
      return data.medication.filter(function (group) {
        return group.aliases.some(function (alias) {
          return typed.indexOf(normalise(alias)) !== -1;
        });
      });
    }

    function hasGroup(matched, key) {
      return matched.some(function (g) { return g.key === key; });
    }

    // Mirrors CombinationAssessment in CombinationRiskCheckerView.swift.
    function assess(matched) {
      var sero = countIn(SEROTONERGIC);
      var stim = countIn(STIMULANTS);

      var serotonin;
      if (hasGroup(matched, 'maoi') && sero > 0) serotonin = 'high';
      else if (hasGroup(matched, 'serotonergic') && sero >= 2) serotonin = 'high';
      else if (hasGroup(matched, 'serotonergic') && sero > 0) serotonin = 'caution';
      else serotonin = sero >= 2 ? 'high' : (sero > 0 ? 'caution' : 'lower');

      var byStimulant = stim === 0 ? 'lower' : (timing === 'withinDay' ? 'caution' : 'high');
      var byAlcohol = picked.has('Alcohol') ? 'caution' : 'lower';
      var byBoth = picked.has('Alcohol') && stim > 0 ? 'high' : 'lower';
      var dehydration = [byStimulant, byAlcohol, byBoth].reduce(function (a, b) {
        return RANK[a] >= RANK[b] ? a : b;
      });

      var total = stim + (hasGroup(matched, 'stimulantMedication') ? 1 : 0);
      var stimulant = total >= 2 ? 'high'
        : (total === 1 ? (timing === 'sameSession' ? 'caution' : 'lower') : 'lower');

      return { serotonin: serotonin, dehydration: dehydration, stimulant: stimulant };
    }

    function warnings() {
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

    function renderAssessments(levels) {
      var wrap = document.createElement('div');
      wrap.className = 'assessments';
      Object.keys(data.assessments).forEach(function (key) {
        var spec = data.assessments[key];
        var level = levels[key];
        // Built node by node rather than innerHTML plus queries. An earlier
        // version used row.querySelector('div span'), which matches any span
        // with any div ancestor, including ancestors outside the row: it
        // re-selected the tag and overwrote the label with the detail text.
        var row = document.createElement('div');
        row.className = 'assess assess--' + level;

        var tag = document.createElement('span');
        tag.className = 'assess-tag';
        tag.textContent = data.riskLabels[level];

        var title = document.createElement('b');
        title.textContent = spec.title;

        var detail = document.createElement('span');
        detail.textContent = spec.levels[level];

        var body = document.createElement('div');
        body.appendChild(title);
        body.appendChild(detail);

        row.appendChild(tag);
        row.appendChild(body);
        wrap.appendChild(row);
      });
      return wrap;
    }

    function render() {
      var matched = medicationMatches();

      if (medsOut) {
        medsOut.textContent = '';
        if (meds && meds.value.trim()) {
          medsOut.textContent = matched.length
            ? data.copy.medsHit + ': ' + matched.map(function (g) { return g.label; }).join(', ')
            : data.copy.medsNone;
          medsOut.className = 'meds-out' + (matched.length ? ' is-hit' : '');
        }
      }

      out.textContent = '';
      // One substance is enough, the same as the app: the standing checks have
      // something to say about a single stimulant, and a typed medication has
      // something to say on its own.
      if (!picked.size && !matched.length) {
        out.appendChild(card('empty', '', data.copy.empty));
        return;
      }

      var found = warnings();
      if (found.length) {
        found.forEach(function (rule) {
          out.appendChild(card(rule.level, data.levels[rule.level], rule.warning));
        });
      } else if (picked.size >= 2) {
        out.appendChild(card('none', data.copy.noneTitle, data.copy.noneBody));
      }
      out.appendChild(renderAssessments(assess(matched)));
    }

    function syncHash() {
      var parts = chips
        .filter(function (c) { return picked.has(c.dataset.substance); })
        .map(function (c) { return c.dataset.substance.toLowerCase(); });
      var next = parts.length ? '#try=' + parts.join('+') : ' ';
      if (history.replaceState) history.replaceState(null, '', next);
    }

    function setChip(chip, on) {
      chip.setAttribute('aria-pressed', String(on));
      if (on) picked.add(chip.dataset.substance);
      else picked.delete(chip.dataset.substance);
    }

    function update() { render(); syncHash(); }

    chips.forEach(function (chip) {
      chip.addEventListener('click', function () {
        setChip(chip, chip.getAttribute('aria-pressed') !== 'true');
        update();
      });
    });

    timingButtons.forEach(function (button) {
      button.addEventListener('click', function () {
        timing = button.dataset.timing;
        timingButtons.forEach(function (b) {
          b.setAttribute('aria-pressed', String(b === button));
        });
        render();
      });
    });

    if (meds) meds.addEventListener('input', render);

    if (reset) {
      reset.addEventListener('click', function () {
        chips.forEach(function (chip) { setChip(chip, false); });
        if (meds) meds.value = '';
        update();
      });
    }

    if (shortcut) {
      shortcut.addEventListener('click', function () {
        chips.forEach(function (chip) {
          setChip(chip, chip.dataset.substance === 'GHB' || chip.dataset.substance === 'Alcohol');
        });
        update();
        out.scrollIntoView({ block: 'nearest', behavior: reduceMotion ? 'auto' : 'smooth' });
      });
    }

    // A specific warning you can send to someone is worth more than a page
    // about warnings, so the selection lives in the URL.
    if (share && navigator.clipboard) {
      share.hidden = false;
      share.addEventListener('click', function () {
        navigator.clipboard.writeText(location.href).then(function () {
          var note = root.querySelector('.copy-done');
          if (!note) return;
          note.textContent = share.dataset.copiedLabel || '';
          setTimeout(function () { note.textContent = ''; }, 2200);
        });
      });
    }

    function fromHash() {
      var match = /(?:^|[#&])try=([a-z0-9+%]+)/i.exec(location.hash);
      if (!match) return false;
      var wanted = decodeURIComponent(match[1]).toLowerCase().split('+');
      chips.forEach(function (chip) {
        setChip(chip, wanted.indexOf(chip.dataset.substance.toLowerCase()) !== -1);
      });
      return picked.size > 0;
    }

    if (fromHash()) {
      render();
      root.scrollIntoView({ block: 'start' });
    } else {
      render();
    }
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
