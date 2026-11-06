// Service worker : l'appli s'ouvre même sans réseau.
const CACHE = "labo-techno-v6";
const SHELL = ["./", "./index.html", "./config.js", "./manifest.webmanifest", "./icon-192.png", "./icon-512.png"];
self.addEventListener("install", e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())); });
self.addEventListener("activate", e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener("fetch", e => {
  const r = e.request, u = new URL(r.url);
  if(r.method !== "GET") return;
  // Données en direct (Supabase, Google Sheets) : jamais mises en cache ici.
  if(/supabase\.co$/.test(u.hostname) || u.hostname === "docs.google.com") return;
  if(u.origin === location.origin){
    // Fichiers de l'appli : réseau d'abord (mises à jour), sinon cache.
    e.respondWith(fetch(r).then(res => { const c = res.clone(); caches.open(CACHE).then(k => k.put(r, c)); return res; }).catch(() => caches.match(r).then(m => m || caches.match("./index.html"))));
  } else if(/cdn\.jsdelivr\.net|fonts\.(googleapis|gstatic)\.com/.test(u.hostname)){
    // Bibliothèques et polices : cache d'abord.
    e.respondWith(caches.match(r).then(m => m || fetch(r).then(res => { const c = res.clone(); caches.open(CACHE).then(k => k.put(r, c)); return res; })));
  }
});
