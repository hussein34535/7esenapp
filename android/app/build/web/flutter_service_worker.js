'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"apple-touch-icon.png": "0c6668da09b844a2e37af6ec6316b5e8",
"assets/AssetManifest.bin": "81b8a8eaec171308b90e11cadcc2f2ad",
"assets/AssetManifest.bin.json": "d74b4ab90f74efdab0e5cfe21b76735b",
"assets/AssetManifest.json": "543566f2291e2df9bf02dbdcc3b4cdd0",
"assets/assets/goal.png": "ff51cee9738ee9ea1dd556c429b2f768",
"assets/assets/icon/icon.png": "0c6668da09b844a2e37af6ec6316b5e8",
"assets/assets/maximize.png": "498a49e0883b9e281f660f03dddee103",
"assets/assets/moon.png": "d03b9f65277bfc3a5ef8a2762882caf1",
"assets/assets/no-image.png": "95190dd56db26e2c9019327c5477155e",
"assets/assets/replay.png": "365479d966c20286fb64ca85bf3c597f",
"assets/assets/sun.png": "677aaf8f3adfe8fbaaf0a7eae6c9551d",
"assets/assets/table.png": "0e25c5ed3b99db114ec6d1c4444be7f4",
"assets/assets/tv.png": "9d1f5f69c8e3dccc5d162c6ca4a395b5",
"assets/FontManifest.json": "97c2528ecc2fbf4093965257fdba1854",
"assets/fonts/MaterialIcons-Regular.otf": "52cbe8adf02d437beb344b3751f864d8",
"assets/NOTICES": "9988f183f5649b84dccbfd4a07bec5a8",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "d7d83bd9ee909f8a9b348f56ca7b68c6",
"assets/packages/flex_color_picker/assets/opacity.png": "49c4f3bcb1b25364bb4c255edcaaf5b2",
"assets/packages/flutter_inappwebview/assets/t_rex_runner/t-rex.css": "5a8d0222407e388155d7d1395a75d5b9",
"assets/packages/flutter_inappwebview/assets/t_rex_runner/t-rex.html": "16911fcc170c8af1c5457940bd0bf055",
"assets/packages/flutter_inappwebview_web/assets/web/web_support.js": "509ae636cfdd93e49b5a6eaf0f06d79f",
"assets/packages/font_awesome_flutter/lib/fonts/Font%2520Awesome%25207%2520Brands-Regular-400.otf": "382a4ead06c49675da34f2d13f928860",
"assets/packages/font_awesome_flutter/lib/fonts/Font%2520Awesome%25207%2520Free-Regular-400.otf": "df86a1976d76bd04cf3fcaf5add2dd0f",
"assets/packages/font_awesome_flutter/lib/fonts/Font%2520Awesome%25207%2520Free-Solid-900.otf": "e151d7a6f42f17e9ea335c91d07b3739",
"assets/packages/wakelock_plus/assets/no_sleep.js": "7748a45cd593f33280669b29c2c8919a",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"favicon.png": "fd14da7debd62b16de83b58818ab31c3",
"firebase-config.js": "7215ee9c7d9dc229d2921a40e899ec5f",
"firebase-messaging-sw.js": "4e2707e9e0f547dcedbb91fb6b6f3e70",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "ec9e98b96419defa429d0c293d4e1fdb",
"icons/icon-192.png": "415828d2f4afe514ab76cb125e4a3520",
"icons/icon-512.png": "ced3014cd194fcbe38ba6b32d8f24893",
"icons/Icon-maskable-192.png": "415828d2f4afe514ab76cb125e4a3520",
"icons/Icon-maskable-512.png": "ced3014cd194fcbe38ba6b32d8f24893",
"index.html": "6640558d61dbb5c8660b04a8f4cdacba",
"/": "6640558d61dbb5c8660b04a8f4cdacba",
"install_prompt.js": "9455fecd642fb2ed5a6b3040039d601a",
"main.dart.js": "1e37fe809da8c9ce4f9bb1e61f5bef3e",
"manifest.json": "70096757eea03097bb78e98ff73d0b9a",
"service-worker.js": "717ec3f1394aff7bb6d2df41b482da47",
"splash/img/dark-1x.png": "67ff58516563fecdcbfd6863af951173",
"splash/img/dark-2x.png": "14b2a33bd896bce5fa8ddd7044d73f80",
"splash/img/dark-3x.png": "21f7071909452423ddd9b6c11a6a49a1",
"splash/img/dark-4x.png": "ff39be0857406c419aad8d4d629de27b",
"splash/img/light-1x.png": "67ff58516563fecdcbfd6863af951173",
"splash/img/light-2x.png": "14b2a33bd896bce5fa8ddd7044d73f80",
"splash/img/light-3x.png": "21f7071909452423ddd9b6c11a6a49a1",
"splash/img/light-4x.png": "ff39be0857406c419aad8d4d629de27b",
"splash.html": "2f75f5b3dff17dbaa3b422d7fa660895",
"version.json": "2e346b4046834586bb12a476feaf35cb"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
