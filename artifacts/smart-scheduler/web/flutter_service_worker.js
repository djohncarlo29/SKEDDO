// Kill-switch service worker: immediately evicts any prior SW (Expo or old
// Flutter build), clears all caches, and force-reloads open clients so they
// load the latest Flutter build from the network.

self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.keys()
      .then(function(keys) {
        return Promise.all(keys.map(function(k) { return caches.delete(k); }));
      })
      .then(function() { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    self.clients.claim().then(function() {
      return self.clients.matchAll({ type: 'window' });
    }).then(function(clients) {
      clients.forEach(function(client) {
        client.navigate(client.url);
      });
    })
  );
});

// Pass every fetch straight to the network — no caching.
self.addEventListener('fetch', function(event) {
  event.respondWith(fetch(event.request));
});
