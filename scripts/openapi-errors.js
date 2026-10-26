#!/usr/bin/env node
// Hata kodu tablosunu messages*.properties + ApiException kullanimlarindan uretir (tr/en/ar).
// Kullanim: node scripts/openapi-errors.js            -> markdown'i stdout'a yazar
//           node scripts/openapi-errors.js --inject docs/MOBILE_API_GUIDE.md
//             (<!-- ERRORS:BEGIN --> ile <!-- ERRORS:END --> arasini yeniler)
// Ayrica: koddan atilan ama ceviri anahtari olmayan kodlari stderr'e uyari olarak basar.
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const i18nDir = path.join(root, 'backend/src/main/resources/i18n');
const srcDir = path.join(root, 'backend/src/main/java');

function readProps(file) {
  const out = {};
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = /^error\.([A-Z0-9_]+)=(.*)$/.exec(line);
    if (m) out[m[1]] = m[2].replace(/\\u([0-9a-fA-F]{4})/g, (_, h) => String.fromCharCode(parseInt(h, 16)));
  }
  return out;
}

function walk(dir, acc = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, acc);
    else if (e.name.endsWith('.java')) acc.push(p);
  }
  return acc;
}

const tr = readProps(path.join(i18nDir, 'messages.properties'));
const en = readProps(path.join(i18nDir, 'messages_en.properties'));
const ar = readProps(path.join(i18nDir, 'messages_ar.properties'));

// kod -> HTTP durumlari (ApiException(HttpStatus.X, "KOD", ...) ve ResponseEntity/Map.of("code","KOD") kaliplari)
const statuses = {};
const codeNum = { BAD_REQUEST: 400, UNAUTHORIZED: 401, FORBIDDEN: 403, NOT_FOUND: 404, CONFLICT: 409, GONE: 410,
  PAYLOAD_TOO_LARGE: 413, UNSUPPORTED_MEDIA_TYPE: 415, UNPROCESSABLE_ENTITY: 422, TOO_MANY_REQUESTS: 429,
  INTERNAL_SERVER_ERROR: 500, SERVICE_UNAVAILABLE: 503, ACCEPTED: 202, LOCKED: 423, FORBIDDEN_: 403 };
const usedInCode = new Set();
for (const f of walk(srcDir)) {
  const s = fs.readFileSync(f, 'utf8');
  const re = /new\s+ApiException\(\s*HttpStatus\.([A-Z_]+)\s*,\s*"([A-Z0-9_]+)"/g;
  let m;
  while ((m = re.exec(s))) {
    usedInCode.add(m[2]);
    (statuses[m[2]] = statuses[m[2]] || new Set()).add(codeNum[m[1]] || m[1]);
  }
}
// Cercevede (filtre/WS) uretilen kodlar: ApiException disinda
const extra = { UNAUTHORIZED: [401], TOKEN_EXPIRED: ['WS'], ACCOUNT_SUSPENDED: [403] };
for (const [k, v] of Object.entries(extra)) {
  if (tr[k]) (statuses[k] = statuses[k] || new Set()), v.forEach((x) => statuses[k].add(x));
}

const codes = Object.keys(tr).sort();
const esc = (t) => (t || '').replace(/\|/g, '\\|');
let md = '| Kod | HTTP | Turkce (tr) | English (en) | Arabic (ar) |\n|---|---|---|---|---|\n';
for (const c of codes) {
  const st = statuses[c] ? [...statuses[c]].sort().join(', ') : '-';
  md += `| \`${c}\` | ${st} | ${esc(tr[c])} | ${esc(en[c])} | ${esc(ar[c])} |\n`;
}

const missing = [...usedInCode].filter((c) => !tr[c]);
if (missing.length) console.error('UYARI: ceviri anahtari olmayan kodlar: ' + missing.join(', '));
const inconsistent = codes.filter((c) => !en[c] || !ar[c]);
if (inconsistent.length) console.error('UYARI: en/ar eksik: ' + inconsistent.join(', '));

const i = process.argv.indexOf('--inject');
if (i > 0) {
  const target = path.resolve(process.argv[i + 1]);
  const doc = fs.readFileSync(target, 'utf8');
  const b = '<!-- ERRORS:BEGIN -->';
  const e = '<!-- ERRORS:END -->';
  const bi = doc.indexOf(b);
  const ei = doc.indexOf(e);
  if (bi < 0 || ei < bi) {
    console.error('Isaretciler bulunamadi: ' + b + ' / ' + e);
    process.exit(1);
  }
  fs.writeFileSync(target, doc.slice(0, bi + b.length) + '\n\n' + md + '\n' + doc.slice(ei));
  console.log(`${codes.length} hata kodu ${target} dosyasina yazildi`);
} else {
  process.stdout.write(md);
}
