// Web <-> backend sözleşme denetimi: node scripts/check-admin-contract.mjs [--strict] [--openapi ../docs/openapi.json] [--json]
// `web/src/api/**/*.ts` içindeki istek yollarını (api.get/post/put/patch/del, publicApi.*, apiBlob, apiFetch) çıkarır ve
// docs/openapi.json'daki (yöntem + yol şablonu) kümesiyle karşılaştırır. Eşleşmeyen çağrılar LİSTELENİR (varsayılan çıkış
// kodu 0: CI'da uyarıdır); --strict ile eşleşmeyen varsa 1 döner. Basit bir ayrıştırıcıdır: dinamik (değişkenle kurulan)
// yollar "dinamik" olarak sayılır ve atlanır.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const WEB_ROOT = join(HERE, '..');
const API_DIR = join(WEB_ROOT, 'src', 'api');
/** İstemci tabanı (`api/client.ts` BASE): çağrılardaki yol bunun altındadır. */
export const API_PREFIX = '/api';

/** `api.get`/`publicApi.post`/`apiBlob` vb. çağrı adı -> HTTP yöntemi (apiFetch için gövdeden okunur). */
const CALLERS = [
  { re: /\b(?:api|publicApi)\s*\.\s*(get|post|put|patch|del|putForm)\b/g, method: (m) => (m === 'del' ? 'DELETE' : m === 'putForm' ? 'PUT' : m.toUpperCase()) },
  { re: /\bapiBlob\b/g, method: () => null }, // varsayılan GET; `method: 'POST'` seçeneği gövdeden okunur
  { re: /\bapiFetch(?:Meta)?\b/g, method: () => null },
];

/** `s[i]` bir `<` ise eşleşen `>` konumundan sonrasını döner (jenerik tür argümanı); değilse i. */
function skipGenerics(s, i) {
  let j = i;
  while (/\s/.test(s[j] ?? '')) j++;
  if (s[j] !== '<') return i;
  let depth = 0;
  for (; j < s.length; j++) {
    const c = s[j];
    if (c === '<') depth++;
    else if (c === '>' && s[j - 1] !== '=') {
      depth--;
      if (depth === 0) return j + 1;
    }
  }
  return i;
}

/** `s[i]` tırnaklı bir sabitse {text, end, dynamic} döner; değilse null. Şablon ifadeleri `{}` olur. */
function readLiteral(s, i) {
  while (/\s/.test(s[i] ?? '')) i++;
  const q = s[i];
  if (q !== "'" && q !== '"' && q !== '`') return null;
  let out = '';
  let dynamic = false;
  let j = i + 1;
  for (; j < s.length; j++) {
    const c = s[j];
    if (c === '\\') {
      out += s[j + 1] ?? '';
      j++;
    } else if (c === q) {
      j++;
      break;
    } else if (q === '`' && c === '$' && s[j + 1] === '{') {
      let d = 0;
      let k = j + 1;
      for (; k < s.length; k++) {
        if (s[k] === '{') d++;
        else if (s[k] === '}') {
          d--;
          if (d === 0) break;
        }
      }
      out += '{}';
      dynamic = true;
      j = k;
    } else {
      out += c;
    }
  }
  // Yol sabitinden sonra `+` ile birleştirme varsa (örn. '/a/' + id) sabit tam yol değildir.
  let k = j;
  while (/\s/.test(s[k] ?? '')) k++;
  const concat = s[k] === '+';
  return { text: out, end: j, dynamic, concat };
}

/** Çağrı argümanlarındaki `method: 'POST'` değerini (apiFetch için) bulur. */
function methodFromOptions(s, from) {
  // Yalnız bu çağrının argüman listesine bak (sonraki çağrıların `method:` değerine taşma).
  let end = from;
  let depth = 0;
  for (; end < s.length && end < from + 400; end++) {
    if (s[end] === '(') depth++;
    else if (s[end] === ')' && --depth === 0) break;
  }
  const slice = s.slice(from, end);
  const m = /method\s*:\s*['"](GET|POST|PUT|PATCH|DELETE)['"]/.exec(slice);
  return m ? m[1] : null;
}

/** Yolu karşılaştırılabilir hale getirir: sorgu atılır, `{...}` -> `{}`, sondaki sorgu eki (`${qs}`) atılır. */
export function normalizePath(p) {
  let s = p.split('?')[0];
  // `/admin/x${qs}`: yolun sonuna yapışan ifade sorgu ekidir (önünde `/` yok).
  // Ardışık ifadelerde (`/x/${id}${ban ? '?ban=true' : ''}`) sonuncusu sorgu ekidir.
  s = s.replace(/([^/])\{\}$/, '$1');
  s = s.replace(/\{[^}]*\}/g, '{}');
  if (s.length > 1) s = s.replace(/\/+$/, '');
  return s;
}

/** Kaynak metinden istek çağrılarını çıkarır: [{method, path, line, dynamic}] */
export function extractCalls(src) {
  const calls = [];
  const lineAt = (idx) => src.slice(0, idx).split('\n').length;
  for (const { re, method } of CALLERS) {
    re.lastIndex = 0;
    let m;
    while ((m = re.exec(src))) {
      // `export const api = {...}` tanımının kendisi ya da `api.get<T>:` gibi tür konumları çağrı değildir.
      let i = skipGenerics(src, re.lastIndex);
      while (/\s/.test(src[i] ?? '')) i++;
      if (src[i] !== '(') continue;
      const lit = readLiteral(src, i + 1);
      const line = lineAt(m.index);
      const verb = method(m[1]) ?? methodFromOptions(src, i) ?? 'GET';
      if (!lit || lit.concat) {
        calls.push({ method: verb, path: null, line, dynamic: true });
      } else if (lit.text.startsWith('/')) {
        calls.push({ method: verb, path: normalizePath(lit.text), line, dynamic: false });
      }
    }
  }
  return calls.sort((a, b) => a.line - b.line);
}

/** openapi `paths`'ten {METHOD+yol} kümesi kurar. */
export function buildOperations(openapi) {
  const ops = [];
  for (const [p, item] of Object.entries(openapi.paths ?? {})) {
    for (const m of Object.keys(item)) {
      if (['get', 'post', 'put', 'patch', 'delete'].includes(m)) {
        ops.push({ method: m.toUpperCase(), path: p.replace(/\{[^}]*\}/g, '{}') });
      }
    }
  }
  return ops;
}

/** Bir web çağrısı (yol API_PREFIX'siz) openapi işlemlerinden biriyle eşleşiyor mu? */
export function matchCall(call, ops) {
  const full = API_PREFIX + (call.path === '/' ? '' : call.path);
  return ops.some((o) => o.method === call.method && o.path === full);
}

function listTsFiles(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) {
      if (name === 'generated') continue;
      out.push(...listTsFiles(p));
    } else if (/\.ts$/.test(name) && !/\.test\.ts$/.test(name) && !name.endsWith('.d.ts') && name !== 'client.ts') {
      // client.ts istek katmanıdır (api.* tanımları); çağrı değil, tanım içerir.
      out.push(p);
    }
  }
  return out;
}

/** Çıkarılmış kaynaklar ({rel, src}) ile openapi'yi karşılaştırır (dosya sistemi gerektirmez; birim test edilir). */
export function checkSources(openapi, files) {
  const ops = buildOperations(openapi);
  const unmatched = [];
  const dynamic = [];
  let matched = 0;
  for (const { rel, src } of files) {
    for (const c of extractCalls(src)) {
      if (c.dynamic) dynamic.push({ file: rel, line: c.line, method: c.method });
      else if (matchCall(c, ops)) matched++;
      else unmatched.push({ file: rel, line: c.line, method: c.method, path: API_PREFIX + c.path });
    }
  }
  return { matched, unmatched, dynamic, total: matched + unmatched.length + dynamic.length, operations: ops.length };
}

/** Tüm api dosyalarını denetler: {matched, unmatched[], dynamic[], total}. */
export function checkContract({ openapiPath, apiDir = API_DIR }) {
  const openapi = JSON.parse(readFileSync(openapiPath, 'utf8'));
  const files = listTsFiles(apiDir).map((file) => ({
    rel: relative(WEB_ROOT, file).split(sep).join('/'),
    src: readFileSync(file, 'utf8'),
  }));
  return checkSources(openapi, files);
}

function main() {
  const args = process.argv.slice(2);
  const strict = args.includes('--strict');
  const asJson = args.includes('--json');
  const oi = args.indexOf('--openapi');
  const openapiPath = resolve(oi >= 0 ? args[oi + 1] : join(WEB_ROOT, '..', 'docs', 'openapi.json'));
  const r = checkContract({ openapiPath });
  if (asJson) {
    console.log(JSON.stringify(r, null, 2));
  } else {
    console.log(`Sozlesme denetimi: ${r.total} web cagrisi, ${r.matched} eslesti, ${r.unmatched.length} eslesmeyen, ${r.dynamic.length} dinamik (atlandi); openapi islem sayisi ${r.operations}`);
    for (const u of r.unmatched) console.log(`  ESLESMEYEN ${u.method.padEnd(6)} ${u.path}  (${u.file}:${u.line})`);
    if (r.unmatched.length === 0) console.log('  tum web cagrilari docs/openapi.json ile eslesiyor');
  }
  if (strict && r.unmatched.length > 0) process.exit(1);
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) main();
