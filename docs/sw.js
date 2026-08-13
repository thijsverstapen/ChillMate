/* Built by tools/build_site.py. Do not edit here.

   The crisis numbers on the support page are needed exactly when a network is
   least dependable, so that page is precached on first visit. */

const CACHE = 'chillmate-4.2.1-422-b24645b9';
const CORE = [
  '/ChillMate/',
  '/ChillMate/support/',
  '/ChillMate/risk-checker/',
  '/ChillMate/assets/style.b24645b9.css',
  '/ChillMate/assets/chapters.4f1b382d.css',
  '/ChillMate/assets/site.7be77180.js',
  '/ChillMate/assets/mark.svg',
];

/* A fingerprinted name carries an eight-character hex digest, so its contents
   can never change under the same URL. Those are safe to serve from the cache
   without asking. */
const IMMUTABLE = /\.[0-9a-f]{8}\.(css|js|avif|jpg|png|woff2)$/;

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => cache.addAll(CORE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  if (IMMUTABLE.test(url.pathname)) {
    event.respondWith(
      caches.match(event.request).then((hit) => hit || fetch(event.request).then((response) => {
        if (response && response.status === 200) {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(event.request, copy));
        }
        return response;
      }))
    );
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        if (response && response.status === 200 && response.type === 'basic') {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(event.request, copy));
        }
        return response;
      })
      .catch(() => caches.match(event.request)
        .then((hit) => hit || caches.match('/ChillMate/support/')))
  );
});
