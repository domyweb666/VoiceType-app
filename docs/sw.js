// VoiceType 網頁版離線快取。改了 index.html 之後把版本號 +1，手機才會拿到新版。
const CACHE = 'voicetype-v4';
const SHELL = ['./', './index.html', './manifest.webmanifest', './icons/apple-touch-icon.png', './icons/icon-192.png', './icons/icon-512.png',
  './img/face-calm.webp', './img/face-listen.webp', './img/face-think.webp', './img/face-happy.webp', './img/face-confused.webp',
  './img/pot.webp', './img/kernel.webp', './img/sleep.webp', './img/crate.webp', './img/search.webp', './img/barn.webp',
  './img/corn-young.webp', './img/corn-normal.webp', './img/corn-gold.webp'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const req = e.request;
  // 只管自己網域的 GET；送到 OpenAI 的請求完全不碰
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  if (req.mode === 'navigate') {
    // 頁面：先上網拿新版，離線才用快取
    e.respondWith(fetch(req).then(res => {
      const copy = res.clone(); caches.open(CACHE).then(c => c.put('./index.html', copy));
      return res;
    }).catch(() => caches.match('./index.html')));
    return;
  }
  e.respondWith(caches.match(req, { ignoreSearch: true }).then(hit => hit || fetch(req)));
});
