/* Built by tools/build_site.py. Do not edit here.

   The crisis numbers on the support page are needed exactly when a network is
   least dependable, so that page is precached on first visit. */

const CACHE = 'chillmate-4.2.1-422-1b42e0e6';
const CORE = [
  '/ChillMate/',
  '/ChillMate/support/',
  '/ChillMate/risk-checker/',
  '/ChillMate/assets/style.1b42e0e6.css',
  '/ChillMate/assets/chapters.b548d5ae.css',
  '/ChillMate/assets/site.acbb3c08.js',
  '/ChillMate/assets/mark.svg',
];

/* A fingerprinted name carries an eight-character hex digest, so its contents
   can never change under the same URL. Those are safe to serve from the cache
   without asking. */
// Anything with a content hash in its name can never change under that name,
// so it is safe to serve from the cache forever. `svg` is on the list for the
// App Store badges; the unhashed `mark.svg` does not match this and keeps
// going through the normal path.
const IMMUTABLE = /\.[0-9a-f]{8}\.(css|js|avif|jpg|png|svg|woff2)$/;

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
