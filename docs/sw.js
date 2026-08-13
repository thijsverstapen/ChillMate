/* Keeps the support page reachable with no signal.

   The crisis numbers on that page are needed exactly when a network is least
   dependable, so they are cached on first visit and served from the cache when
   a fetch fails. Everything else is network-first and simply falls back. */

const CACHE = 'chillmate-4.2.1-422-151c9a6f';
const CORE = [
  '/ChillMate/',
  '/ChillMate/support/',
  '/ChillMate/assets/site.7be77180.js',
  '/ChillMate/assets/style.151c9a6f.css',
  '/ChillMate/assets/mark.svg',
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(CORE)).then(() => self.skipWaiting()));
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
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        if (response && response.status === 200 && response.type === 'basic') {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(event.request, copy));
        }
        return response;
      })
      .catch(() => caches.match(event.request).then((hit) => hit || caches.match('/ChillMate/support/')))
  );
});
