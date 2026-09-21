/* Service worker: deja la app entera en el teléfono para que abra sin conexión.
   Sube VERSION al publicar cambios y el móvil se actualizará solo al reabrirla. */
const VERSION = 'notas-fcb-v2';
const SHELL = [
  './',
  './index.html',
  './config.js',
  './manifest.webmanifest',
  './iconos/icono-180.png',
  './iconos/icono-192.png',
  './iconos/icono-512.png'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== VERSION).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;                       // las escrituras al grupo nunca se cachean
  const url = new URL(req.url);
  if (url.origin === self.location.origin) {
    // la app: red primero para recoger versiones nuevas, caché si no hay cobertura
    e.respondWith(
      fetch(req)
        .then(res => {
          const copia = res.clone();
          caches.open(VERSION).then(c => c.put(req, copia)).catch(() => {});
          return res;
        })
        .catch(() => caches.match(req).then(r => r || caches.match('./index.html')))
    );
    return;
  }
  if (/\.(png|jpg|jpeg|webp|avif)$/i.test(url.pathname)) {
    // fotos de los jugadores: caché primero, y si no hay, que la app caiga a las iniciales
    e.respondWith(
      caches.match(req).then(hit => hit || fetch(req).then(res => {
        const copia = res.clone();
        caches.open(VERSION).then(c => c.put(req, copia)).catch(() => {});
        return res;
      }).catch(() => Response.error()))
    );
  }
});
