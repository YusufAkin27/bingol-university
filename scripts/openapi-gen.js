#!/usr/bin/env node
// Canli sunucudan docs/openapi.json uretir (yonetici Basic auth ile /v3/api-docs).
// Kullanim: BASE=http://localhost:8107 ADMIN_PASSWORD=adminpw123 node scripts/openapi-gen.js
// Cikti: anahtarlar sirali (kararli diff), servers sabit. Gruplu belgeler: docs/openapi-<grup>.json uretilmez; /v3/api-docs/<grup> canli okunur.
const fs = require('fs');
const path = require('path');

const BASE = process.env.BASE || 'http://localhost:8080';
const PASS = process.env.ADMIN_PASSWORD || 'adminpw123';
const OUT = process.env.OUT || path.join(__dirname, '..', 'docs', 'openapi.json');

function sortKeys(v) {
  if (Array.isArray(v)) return v.map(sortKeys);
  if (v && typeof v === 'object') {
    const o = {};
    for (const k of Object.keys(v).sort()) o[k] = sortKeys(v[k]);
    return o;
  }
  return v;
}

(async () => {
  const res = await fetch(BASE + '/v3/api-docs', {
    headers: { Authorization: 'Basic ' + Buffer.from('admin:' + PASS).toString('base64') },
  });
  if (!res.ok) {
    console.error('openapi-gen: HTTP ' + res.status);
    process.exit(1);
  }
  const doc = await res.json();
  doc.servers = [{ url: 'http://localhost:8080', description: 'Yerel gelistirme (docker compose)' }];
  // Operasyonlari yol+yontem sirasiyla kararli yazmak icin anahtarlar siralanir
  fs.writeFileSync(OUT, JSON.stringify(sortKeys(doc), null, 2) + '\n');
  let ops = 0;
  for (const p of Object.values(doc.paths)) ops += Object.keys(p).filter((k) => ['get', 'post', 'put', 'patch', 'delete'].includes(k)).length;
  console.log(`openapi-gen: ${Object.keys(doc.paths).length} yol, ${ops} islem -> ${OUT}`);
})();
