'use strict';
// PATCHED (tool/patch_service_worker.dart): Flutter's generator keys the cache
// off self.location.origin, which is wrong whenever the app is served from a
// sub-path — see docs/adr/0008-service-worker-subpath.md. This is the worker's
// own directory, which is what the RESOURCES keys are actually relative to.
const SCOPE_BASE = self.location.href.substring(
    0, self.location.href.lastIndexOf('/'));
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "9c2406464dd2c9cb23c4bbd301fe6066",
"index.html": "e8aa053a4bffa126811e67e9bed4cd27",
"/": "e8aa053a4bffa126811e67e9bed4cd27",
"main.dart.js": "e07c6721338652d05d05eb13c9cd794b",
"version.json": "33c5517d6ce947117040d30eedf476c8",
"assets/assets/icon/app_icon.png": "0d1b8d9e152649dfdb079bb58b5f2ece",
"assets/assets/icon/app_icon_foreground.png": "11f824953e0e390785d9302f856aff91",
"assets/assets/audio/sweep_slow.ogg": "4e7fb73df4ac33d90c7b86b02d87c8b7",
"assets/assets/audio/sweep_med.ogg": "06980b6ac9102a69ba66d6c38c26a099",
"assets/assets/audio/sweep_fast.ogg": "8100764f8312e54712ab06453c792584",
"assets/assets/audio/snap.ogg": "0594093bc13a3387827c3f3d02ee214c",
"assets/assets/audio/sew.ogg": "712f61e2651bcde4118d099062af52b9",
"assets/assets/audio/block.ogg": "ccc7f33485748c9bc405477386b0c1d0",
"assets/assets/audio/miss.ogg": "cfa1407ecb73142878263876eaa2426f",
"assets/assets/audio/rotate.ogg": "156a8d07317a1c7a901dbde8aba666a2",
"assets/assets/audio/fold.ogg": "ea67aefecf37a36ebb50d7d658bf426d",
"assets/assets/audio/slice.ogg": "e356cb706afd59a1475f71407be27f64",
"assets/assets/audio/stamp.ogg": "573c1bf35eebc743f18a339578b5b9ff",
"assets/assets/audio/chime.ogg": "9f53bb977b8a7cdd591771c3527f3e32",
"assets/assets/audio/bee_start.ogg": "e4a9c94d81d69ac9e3a6786d66573878",
"assets/assets/audio/plink.ogg": "95072bc3bb52a552a4c92f35ccdf5bcf",
"assets/assets/audio/crack.ogg": "c93e194d25622c75bec24153b6a6cd08",
"assets/assets/audio/hatch.ogg": "a73e5f47fc53aaf8780424ce5b3eedc2",
"assets/assets/audio/chirp_1.ogg": "c9dca8bf212d9a471b077bc995c24c40",
"assets/assets/audio/chirp_2.ogg": "b647482599a1dba0dd0ea2a4d2402b76",
"assets/assets/audio/chirp_3.ogg": "c05478546c1786e76d298b03e682222f",
"assets/assets/fonts/Lora-Regular.ttf": "5016349e9de4b2eeac85fa2ed374f7fe",
"assets/assets/fonts/Lora-Bold.ttf": "0cf62064521fb6e70f3ca2d6e37acab3",
"assets/assets/fonts/Nunito-Regular.ttf": "c15a3de8622bea5de54f467141bc2521",
"assets/assets/fonts/Lora-Italic.ttf": "0670dad11a0ba7369fccb78df6ac4ac5",
"assets/assets/fonts/Nunito-SemiBold.ttf": "33c704d4567fb8a57c7b1acb6fd658c0",
"assets/assets/fonts/Nunito-Medium.ttf": "92de69d6e4bac55d23b48b67ade9c225",
"assets/assets/fonts/Lora-Medium.ttf": "2c51d6c8fcac3ab587d74ec725c35c27",
"assets/assets/fonts/Nunito-Bold.ttf": "fcd0055ad3f85db1b8ce73018ba8b7c6",
"assets/fonts/MaterialIcons-Regular.otf": "42be77c0179d9f5d1993e47b2eb40b8a",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/AssetManifest.bin.json": "6091776bc05e757b1f29b10ea68ba1d1",
"assets/AssetManifest.bin": "bce1193af81366ccd3fec53babcbcab0",
"assets/FontManifest.json": "d295944fb21ed4a287f374bd8888f1c3",
"assets/NOTICES": "b49ad7c0c7534f1c345686fa928e9094",
"favicon.png": "8b97e4c307887702b9c034c5aeacafa0",
"icons/Icon-192.png": "a8eb7515d3f8a07989d91af3660d06ac",
"icons/Icon-512.png": "d5bb85408cc2c88bca3de59b6387882c",
"icons/Icon-maskable-192.png": "f95783d799f43c69bde50e45b7563288",
"icons/Icon-maskable-512.png": "2bbb0166c299b2699764b757511e5e91",
"drift_worker.js": "3a57681b52f6c68292ac63ab80a99eaa",
"sqlite3.wasm": "2e9fc1ccbb9d15199fccf405b0ceee53",
"manifest.json": "0f78c6b903c7a081684cf98ecf11dfc4"};
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
      var origin = SCOPE_BASE;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(SCOPE_BASE.length + 1);
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
  var origin = SCOPE_BASE;
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
    var key = request.url.substring(SCOPE_BASE.length + 1);
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
