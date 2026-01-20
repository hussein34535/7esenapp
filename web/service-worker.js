const CACHE_NAME = "hesen-tv-cache-v2";
const urlsToCache = [
  "/",
  "main.dart.js",
  "index.html",
  "assets/FontManifest.json",
  "assets/AssetManifest.json",
  "manifest.json"
];

self.addEventListener("install", (event) => {
  self.skipWaiting(); // Force activation for updates
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      // return cache.addAll(urlsToCache); // Optional: Pre-cache core files
    })
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') return;

  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      // Network Fetch to update cache in background
      const fetchPromise = fetch(event.request).then((networkResponse) => {
        // Clone response because it can only be consumed once
        if (networkResponse && networkResponse.status === 200 && networkResponse.type === 'basic') {
          const responseToCache = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });
        }
        return networkResponse;
      }).catch(() => {
        // Network failed, nothing to do
      });

      // Return cached response right away if available, else wait for network
      return cachedResponse || fetchPromise;
    })
  );
}); 