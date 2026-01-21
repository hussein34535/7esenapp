const CACHE_VERSION = 'hesen-v4.0.0';
const CACHE_STATIC = `${CACHE_VERSION}-static`;
const CACHE_DYNAMIC = `${CACHE_VERSION}-dynamic`;

// ملفات ضرورية للتطبيق (Cache First)
const STATIC_FILES = [
  '/',
  '/index.html',
  '/manifest.json',
  '/flutter.js',
  '/main.dart.js',
  '/assets/icon/icon.png',
  '/assets/sun.png',
  '/assets/moon.png',
  '/assets/no-image.png',
];

// استراتيجية Cache First للملفات الثابتة
self.addEventListener('install', (event) => {
  console.log('[SW] Installing Service Worker v' + CACHE_VERSION);
  event.waitUntil(
    caches.open(CACHE_STATIC).then((cache) => {
      console.log('[SW] Caching static files');
      return cache.addAll(STATIC_FILES).catch(err => {
        console.error('[SW] Failed to cache some files:', err);
      });
    })
  );
  self.skipWaiting();
});

// تنظيف الكاش القديم
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating Service Worker v' + CACHE_VERSION);
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys
          .filter(key => key !== CACHE_STATIC && key !== CACHE_DYNAMIC)
          .map(key => {
            console.log('[SW] Removing old cache:', key);
            return caches.delete(key);
          })
      );
    })
  );
  return self.clients.claim();
});

// استراتيجية Fetch
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // ❌ Ignore non-http/https requests (e.g. chrome-extension://)
  if (!url.protocol.startsWith('http')) {
    return;
  }

  // ✅ Intercept HEAD requests for Proxies (CodeTabs triggers 400 Bad Request on HEAD)
  if (event.request.method === 'HEAD' &&
    (url.hostname.includes('codetabs.com') ||
      url.hostname.includes('corsproxy.io') ||
      url.hostname.includes('workers.dev'))) {
    event.respondWith(
      new Response(null, {
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, HEAD, POST, OPTIONS'
        }
      })
    );
    return;
  }

  // ✅ Intercept CodeTabs requests to Fix Headers (Content-Type)
  // Must be before other strategies to avoid "respondWith already called"
  if (url.hostname.includes('codetabs.com')) {
    event.respondWith(
      fetch(event.request).then(response => {
        const newHeaders = new Headers(response.headers);

        if (event.request.url.includes('.m3u8')) {
          newHeaders.set('Content-Type', 'application/x-mpegurl');
        } else if (event.request.url.includes('.ts')) {
          newHeaders.set('Content-Type', 'video/mp2t');
        }

        newHeaders.set('Access-Control-Allow-Origin', '*');

        return new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: newHeaders
        });
      }).catch(err => {
        console.error('[SW] CodeTabs Proxy Failed:', err);
        return new Response('Proxy Error', { status: 502 });
      })
    );
    return;
  }

  // ❌ Ignore non-GET requests (Head, Post, etc.) to prevent Cache errors
  if (event.request.method !== 'GET') {
    return;
  }

  // ❌ Ignore requests to Proxies (Streaming should not be cached)
  if (
    url.hostname.includes('corsproxy.io') ||
    url.hostname.includes('allorigins.win') ||
    // CodeTabs removed from ignore list to be handled below
    url.hostname.includes('workers.dev') ||
    url.hostname.includes('freeboard.io')
  ) {
    return;
  }

  // ❌ لا تخزن روابط البث المباشر (M3U8, TS, API)
  if (
    url.pathname.includes('.m3u8') ||
    url.pathname.includes('.ts') ||
    url.pathname.includes('/api/') ||
    url.hostname.includes('okcdn.ru') ||
    url.hostname.includes('youtube.com') ||
    url.hostname.includes('googlevideo.com') ||
    url.hostname.includes('ok.ru') ||
    url.hostname.includes('cdn.vidstack.io')
  ) {
    return; // دعها تمر مباشرة
  }

  // ✅ Cache First للملفات الثابتة
  if (STATIC_FILES.some(file => url.pathname === file || url.pathname.startsWith('/assets/'))) {
    event.respondWith(
      caches.match(event.request).then((response) => {
        return response || fetch(event.request).then((fetchResponse) => {
          return caches.open(CACHE_STATIC).then((cache) => {
            cache.put(event.request, fetchResponse.clone());
            return fetchResponse;
          });
        });
      }).catch(() => {
        // Fallback إذا فشل كل شيء
        return caches.match('/index.html');
      })
    );
    return;
  }

  // ✅ Network First للباقي (مع Fallback للكاش)
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // احفظ في Dynamic Cache
        return caches.open(CACHE_DYNAMIC).then((cache) => {
          cache.put(event.request, response.clone());
          return response;
        });
      })
      .catch(() => {
        // Fallback إلى الكاش إذا فشل الإنترنت
        return caches.match(event.request);
      })
  );

  // ✅ Intercept CodeTabs requests to Fix Headers (Content-Type)
  if (url.hostname.includes('codetabs.com')) {
    event.respondWith(
      fetch(event.request).then(response => {
        // إنشاء Headers جديدة
        const newHeaders = new Headers(response.headers);

        // تصحيح نوع المحتوى بناءً على الامتداد
        if (event.request.url.includes('.m3u8')) {
          newHeaders.set('Content-Type', 'application/x-mpegurl');
        } else if (event.request.url.includes('.ts')) {
          newHeaders.set('Content-Type', 'video/mp2t');
        }

        // ضمان وجود CORS
        newHeaders.set('Access-Control-Allow-Origin', '*');

        return new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: newHeaders
        });
      }).catch(err => {
        console.error('[SW] CodeTabs Proxy Failed:', err);
        return new Response('Proxy Error', { status: 502 });
      })
    );
    return;
  }

});