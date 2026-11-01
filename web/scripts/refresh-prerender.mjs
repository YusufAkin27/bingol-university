#!/usr/bin/env node
// Gece yenilemesi: /menu ve /news sayfalarının <noscript> gövdesini (JS çalıştırmayan botlar ve sosyal önizleme için)
// kendi API'mizden çekilen güncel veriyle yeniden yazar; sitemap.xml'de bu iki sayfanın lastmod'unu GERÇEK veri değişimine
// göre günceller. Tam derleme/dağıtım gerekmez. Kaynak siteye (bingol.edu.tr) ASLA istek atılmaz; yalnız kendi backend'imize.
//
//   Üretim (docker ağında):  node refresh-prerender.mjs --base http://web:80 --api http://backend:8080 --out /out
//   Yerel/derleme çıktısı:   node scripts/refresh-prerender.mjs --dir dist --api http://localhost:8080
//
// Çıkış kodu: 0 = tamam (değişiklik olsun olmasın), 2 = API ya da web ulaşılamadı (hiçbir şeye dokunulmadı; eski içerik sunulur).
// Tekrar çalıştırılabilir (idempotent): yeniden yazılan blok <!--dyn:start hash=…--> … <!--dyn:end--> işaretleriyle sınırlıdır;
// veri değişmediyse dosya ve lastmod değişmez. Zamanlama ve işletme adımları: docs/SEO_TECHNICAL.md bölüm 6.
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
};
const dir = opt('--dir', 'dist');
const base = opt('--base', '').replace(/\/+$/, ''); // doluysa sayfalar HTTP ile okunur, çıktı --out altına gider
const outDir = opt('--out', 'out');
let buildId = '';
const api = opt('--api', 'http://localhost:8080').replace(/\/+$/, '');
const origin = opt('--origin', process.env.PUBLIC_WEB_URL || 'https://bukampus.com.tr').replace(/\/+$/, '');
const LANGS = ['tr', 'en', 'ar'];

const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const nowIst = new Date();
const today = nowIst.toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
const stamp = `${today} ${nowIst.toLocaleTimeString('sv-SE', { timeZone: 'Europe/Istanbul', hour: '2-digit', minute: '2-digit' })}`;

const L = {
  tr: {
    menuToday: 'Bugünün yemek listesi',
    menuMonth: 'Bu ayın yemek listesi',
    date: 'Tarih',
    dishes: 'Yemekler',
    kcal: 'Toplam kalori',
    kcalAtLeast: 'en az',
    updated: 'Son güncelleme',
    source: 'Kaynak',
    news: 'Son haber ve duyurular',
    noMenu: 'Bugün için yayımlanmış bir yemek listesi yok.',
    sourceNote: 'Duyuru ve haber metinleri Bingöl Üniversitesi resmî sitesindedir; bağlantılar kaynağa gider.',
  },
  en: {
    menuToday: "Today's menu",
    menuMonth: "This month's menu",
    date: 'Date',
    dishes: 'Dishes',
    kcal: 'Total calories',
    kcalAtLeast: 'at least',
    updated: 'Last updated',
    source: 'Source',
    news: 'Latest news and announcements',
    noMenu: 'No menu has been published for today.',
    sourceNote: 'News and announcement texts are on the Bingöl University official website; the links go to the source.',
  },
  ar: {
    menuToday: 'قائمة طعام اليوم',
    menuMonth: 'قائمة طعام هذا الشهر',
    date: 'التاريخ',
    dishes: 'الأطباق',
    kcal: 'إجمالي السعرات',
    kcalAtLeast: 'على الأقل',
    updated: 'آخر تحديث',
    source: 'المصدر',
    news: 'آخر الأخبار والإعلانات',
    noMenu: 'لم تُنشر قائمة طعام لهذا اليوم.',
    sourceNote: 'نصوص الأخبار والإعلانات في الموقع الرسمي لجامعة بينغول؛ الروابط تنقلك إلى المصدر.',
  },
};

// ---- veri (yalnız kendi API'miz; zaman aşımı + tek deneme) ----
async function getJson(path, allow404 = false) {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 15000);
  try {
    const res = await fetch(`${api}${path}`, { signal: ctl.signal, headers: { accept: 'application/json', 'user-agent': 'bu-refresh-prerender/1' } });
    if (allow404 && res.status === 404) return null;
    if (!res.ok) throw new Error(`${path} -> HTTP ${res.status}`);
    return await res.json();
  } finally {
    clearTimeout(timer);
  }
}

let todayMenu;
let month;
let newsPage;
try {
  todayMenu = await getJson('/api/menu/today', true);
  month = await getJson('/api/menu');
  newsPage = await getJson('/api/news?size=20&page=0');
} catch (e) {
  console.error(`refresh-prerender: API okunamadı (${e.message}); dosyalara dokunulmadı`);
  process.exit(2);
}
if (!Array.isArray(month) || !Array.isArray(newsPage?.items)) {
  console.error('refresh-prerender: beklenmeyen API yanıtı; dosyalara dokunulmadı');
  process.exit(2);
}

// ---- blok üretimi ----
const kcalText = (day, t) => {
  if (day.totalKcal == null) return '-';
  return `${day.kcalComplete ? '' : `${t.kcalAtLeast} `}${day.totalKcal} kcal`;
};
const dishName = (d) => `<span lang="tr">${esc(d.name)}</span>${d.kcal != null ? ` (${esc(d.kcal)} kcal)` : ''}`;

function menuBlock(lang) {
  const t = L[lang];
  const parts = [];
  parts.push(`<h2>${esc(t.menuToday)}</h2>`);
  if (todayMenu && Array.isArray(todayMenu.dishes ?? todayMenu.items)) {
    const dishes = todayMenu.dishes ?? todayMenu.items.map((name) => ({ name, kcal: null }));
    parts.push(`<p>${esc(todayMenu.date)}</p>`);
    parts.push(`<ul>${dishes.map((d) => `<li>${dishName(d)}</li>`).join('')}</ul>`);
    parts.push(`<p>${esc(t.kcal)}: ${esc(kcalText(todayMenu, t))}</p>`);
  } else {
    parts.push(`<p>${esc(t.noMenu)}</p>`);
  }
  if (month.length) {
    parts.push(`<h2>${esc(t.menuMonth)}</h2>`);
    const rows = month
      .map((d) => `<tr><th scope="row">${esc(d.date)}</th><td>${(d.dishes ?? (d.items ?? []).map((name) => ({ name, kcal: null }))).map(dishName).join(', ')}</td><td>${esc(kcalText(d, t))}</td></tr>`)
      .join('');
    parts.push(
      `<table border="1" cellpadding="6"><thead><tr><th scope="col">${esc(t.date)}</th><th scope="col">${esc(t.dishes)}</th><th scope="col">${esc(t.kcal)}</th></tr></thead><tbody>${rows}</tbody></table>`,
    );
  }
  return parts.join('\n');
}

/** Kaynak bağlantısı yalnız http(s); http -> https (CLAUDE.md bölüm 5). Geçersizse null. */
function safeUrl(u) {
  try {
    const x = new URL(String(u));
    if (x.protocol !== 'https:' && x.protocol !== 'http:') return null;
    x.protocol = 'https:';
    return x.toString();
  } catch {
    return null;
  }
}

function newsBlock(lang) {
  const t = L[lang];
  const items = newsPage.items
    .map((n) => {
      const url = safeUrl(n.url);
      const title = url ? `<a href="${esc(url)}" rel="noopener nofollow" lang="tr">${esc(n.title)}</a>` : `<span lang="tr">${esc(n.title)}</span>`;
      return `<li>${esc(n.publishedDate ?? '')} ${title}</li>`;
    })
    .join('');
  return `<h2>${esc(t.news)}</h2>\n<ul>${items}</ul>\n<p>${esc(t.sourceNote)}</p>`;
}

// ---- yaz ----
// Basit, bağımlılıksız özet (cyrb53); yalnız "veri değişti mi" algısı için
function hash(text) {
  let h1 = 0xdeadbeef;
  let h2 = 0x41c6ce57;
  for (let i = 0; i < text.length; i++) {
    const ch = text.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  return (4294967296 * (2097151 & h2) + (h1 >>> 0)).toString(36);
}

const MARK = /<!--dyn:start(?: hash=([a-z0-9]+))?-->[\s\S]*?<!--dyn:end-->/;
const changedRoutes = new Map(); // "/tr/menu" -> true

// ---- G/Ç: iki kip ----
// --dir  : dosyayı yerinde okur/yazar (yerel deneme, derleme çıktısı).
// --base : sayfayı çalışan web konteynerinden HTTP ile okur (katman varsa katmanı, yoksa derleme çıktısını), sonucu
//          --out/<derleme-kimliği>/ altına yazar; nginx bu dizini okur ($dyn_root). Kimlik her dağıtımda değişir, eski katman
//          kendiliğinden devre dışı kalır ve burada silinir.
async function fetchText(url) {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 15000);
  try {
    const res = await fetch(url, { signal: ctl.signal, headers: { 'user-agent': 'bu-refresh-prerender/1' } });
    if (!res.ok) throw new Error(`${url} -> HTTP ${res.status}`);
    return await res.text();
  } finally {
    clearTimeout(timer);
  }
}

let outRoot = dir;
if (base) {
  try {
    buildId = (await fetchText(`${base}/build-id.txt`)).trim();
  } catch (e) {
    console.error(`refresh-prerender: derleme kimliği okunamadı (${e.message}); dosyalara dokunulmadı`);
    process.exit(2);
  }
  if (!/^[0-9a-f]{10}$/.test(buildId)) {
    console.error(`refresh-prerender: geçersiz derleme kimliği "${buildId}"`);
    process.exit(2);
  }
  outRoot = join(outDir, buildId);
}

async function readSource(rel) {
  if (base) return fetchText(`${base}/${rel}`);
  const file = rel === 'sitemap.xml' ? join(dir, rel) : join(dir, rel, 'index.html');
  return existsSync(file) ? readFileSync(file, 'utf8') : null;
}

function writeOut(rel, text) {
  const file = rel === 'sitemap.xml' ? join(outRoot, rel) : join(outRoot, rel, 'index.html');
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, text, 'utf8');
}

async function rewrite(route, lang, body) {
  const rel = `${lang}/${route}`;
  let html;
  try {
    html = await readSource(rel);
  } catch (e) {
    console.warn(`refresh-prerender: ${rel} okunamadı (${e.message}), atlandı`);
    return;
  }
  if (html == null) {
    console.warn(`refresh-prerender: ${rel} yok, atlandı`);
    return;
  }
  const h = hash(body);
  const old = MARK.exec(html);
  const updated = `${L[lang].updated}: ${stamp}`;
  const block = `<!--dyn:start hash=${h}-->\n${body}\n<p><small>${esc(updated)}</small></p>\n<!--dyn:end-->`;
  let next;
  if (old) {
    if (old[1] === h) {
      // veri değişmedi; yine de katman dizini boşsa (yeni dağıtım) mevcut içerik oraya yazılır
      if (base && !existsSync(join(outRoot, rel, 'index.html'))) writeOut(rel, html);
      return;
    }
    next = html.replace(MARK, () => block);
  } else {
    const ns = html.search(/<noscript>/i);
    if (ns < 0) {
      console.warn(`refresh-prerender: ${rel} içinde <noscript> yok, atlandı`);
      return;
    }
    const navAt = html.indexOf('<nav aria-label=', ns);
    const endAt = html.indexOf('</main></noscript>', ns);
    const at = navAt >= 0 && (endAt < 0 || navAt < endAt) ? navAt : endAt;
    if (at < 0) {
      console.warn(`refresh-prerender: ${rel} noscript yapısı tanınmadı, atlandı`);
      return;
    }
    next = `${html.slice(0, at)}${block}\n${html.slice(at)}`;
  }
  writeOut(rel, next);
  changedRoutes.set(`/${rel}`, true);
  console.log(`refresh-prerender: ${rel} güncellendi`);
}

for (const lang of LANGS) {
  await rewrite('menu', lang, menuBlock(lang));
  await rewrite('news', lang, newsBlock(lang));
}

// sitemap lastmod: yalnız verisi gerçekten değişen sayfalar bugünün tarihini alır
let xml = null;
try {
  xml = await readSource('sitemap.xml');
} catch (e) {
  console.warn(`refresh-prerender: sitemap.xml okunamadı (${e.message}); lastmod güncellenmedi`);
}
if (xml) {
  if (changedRoutes.size) {
    for (const route of changedRoutes.keys()) {
      const loc = `<loc>${origin}${route}</loc>`;
      const i = xml.indexOf(loc);
      if (i < 0) continue;
      const j = xml.indexOf('</url>', i);
      const seg = xml.slice(i, j).replace(/<lastmod>[^<]*<\/lastmod>/, `<lastmod>${today}</lastmod>`);
      xml = xml.slice(0, i) + seg + xml.slice(j);
    }
    writeOut('sitemap.xml', xml);
    console.log(`refresh-prerender: sitemap.xml lastmod güncellendi (${[...changedRoutes.keys()].join(', ')})`);
  } else if (base && !existsSync(join(outRoot, 'sitemap.xml'))) {
    writeOut('sitemap.xml', xml);
  }
}

// eski derlemelerin katman dizinlerini temizle (yalnız kimlik biçimindeki adlar)
if (base && existsSync(outDir)) {
  for (const name of readdirSync(outDir)) {
    if (/^[0-9a-f]{10}$/.test(name) && name !== buildId) rmSync(join(outDir, name), { recursive: true, force: true });
  }
}
if (!changedRoutes.size) console.log('refresh-prerender: veri değişmedi, dosyalar aynı kaldı');
