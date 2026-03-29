// 🔴 KILLER SERVICE WORKER: Forces unregistration of any existing SWs
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    self.registration.unregister().then(() => {
      return self.clients.matchAll();
    }).then((clients) => {
      clients.forEach(client => client.navigate(client.url));
    })
  );
});

// Responds with network only to prevent fetches from hanging
self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
});