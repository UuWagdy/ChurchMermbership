const CACHE_NAME = 'church-membership-v1';
const ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './public/logo.png',
  './public/favicon.ico',
  './public/images/icons/icon-72x72.png',
  './public/images/icons/icon-96x96.png',
  './public/images/icons/icon-128x128.png',
  './public/images/icons/icon-144x144.png',
  './public/images/icons/icon-152x152.png',
  './public/images/icons/icon-192x192.png',
  './public/images/icons/icon-384x384.png',
  './public/images/icons/icon-512x512.png',
  './public/images/icons/apple-touch-icon.png',
  './public/images/icons/icon-192x192-maskable.png',
  './public/images/icons/icon-512x512-maskable.png'
];

// Install Event - Caching Assets
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      console.log('[Service Worker] Caching static assets');
      return cache.addAll(ASSETS);
    })
  );
});

// Activate Event - Clean old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => {
      return Promise.all(
        keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))
      );
    })
  );
});

// Fetch Event - Cache-First Strategy
self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request).then(cachedResponse => {
      if (cachedResponse) {
        return cachedResponse;
      }
      return fetch(event.request).then(networkResponse => {
        return caches.open(CACHE_NAME).then(cache => {
          if (event.request.url.startsWith(self.location.origin) && event.request.method === 'GET') {
            cache.put(event.request, networkResponse.clone());
          }
          return networkResponse;
        });
      });
    }).catch(() => {
      // Offline fallback if needed
    })
  );
});
