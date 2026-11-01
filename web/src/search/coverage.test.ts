/**
 * Kapsam testi (statik tarama): kayıt defteri ile kaynak kodun tutarlılığı.
 *  1) Her admin rotası (parametresiz) için en az 1 girdi var.
 *  2) Her girdinin `page` kimliği menüde var; kimlikler benzersiz.
 *  3) Her girdinin anchor'u kaynak kodda `SearchAnchor id="..."` / `data-search-anchor` olarak bulunur.
 *  4) Her sayfanın en az bir derin girdisi (bölüm/ayar/alan/eylem) vardır; BEKLENEN_EKSIKLER boştur ve gerçekten sıfır olduğu doğrulanır.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { ADMIN_BASE } from '../adminBase';
import { translate } from '../i18n';
import { adminNav } from '../layouts/adminNav';
import { buildSearchEntries } from './build';
import { registeredEntries } from './registry';

const SRC = join(process.cwd(), 'src');

/** node:path shim'inde dirname yok: klasör adı elle alınır. */
const dirname = (p: string): string => p.slice(0, Math.max(p.lastIndexOf('/'), p.lastIndexOf('\\')));

/**
 * Derin girdisi (bölüm/ayar/alan/eylem) olmayabilecek sayfalar. Tüm sayfalar derin girdi taşıdığı için liste BOŞTUR;
 * yeni menü öğesi derin girdisiz eklenirse test düşer (listeye eklemek bilinçli bir istisna olmalı, gerekçesiyle).
 */
const BEKLENEN_EKSIKLER: string[] = [];

function walk(dir: string, out: string[] = []): string[] {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.(tsx|ts)$/.test(name) && !/\.test\.tsx?$/.test(name)) out.push(p);
  }
  return out;
}

const sources = [...walk(join(SRC, 'pages')), ...walk(join(SRC, 'components')), ...walk(join(SRC, 'layouts'))].map(
  (file) => ({ file, dir: dirname(file), text: readFileSync(file, 'utf-8') }),
);

const escapeRe = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** Anchor kaynak kodda var mı: sabit değer, şablon öneki ya da "anahtar" tabanlı (SettingRow) dinamik işaretleme. */
function anchorFound(anchor: string): boolean {
  const q = escapeRe(anchor);
  const literal = new RegExp(`(data-search-anchor=|SearchAnchor[^>]*\\bid=)(["']|\\{["'\`])${q}["'\`]`);
  if (sources.some((s) => literal.test(s.text))) return true;
  // şablon:  data-search-anchor={`platform-${platform}`}
  const tpl = /data-search-anchor=\{`([^`$]*)\$\{/g;
  for (const s of sources) {
    for (const m of s.text.matchAll(tpl)) if (m[1] && anchor.startsWith(m[1])) return true;
  }
  // anahtar tabanlı:  data-search-anchor={k}  → anahtar, aynı ya da üst klasördeki bir dosyada tırnaklı sabit olarak geçer
  const lit = new RegExp(`["'\`]${q}["'\`]`);
  for (const k of sources.filter((s) => /data-search-anchor=\{[A-Za-z_]+\}/.test(s.text))) {
    const near = sources.filter((s) => s.dir === k.dir || s.dir === dirname(k.dir));
    if (near.some((s) => lit.test(s.text))) return true;
  }
  return false;
}

function adminRoutes(): string[] {
  const text = readFileSync(join(SRC, 'routes.admin.tsx'), 'utf-8');
  const out: string[] = [];
  for (const m of text.matchAll(/<Route\s+(index|path="([^"]*)")/g)) {
    const p = m[1] === 'index' ? '' : m[2];
    if (p === '*' || p === 'login' || p === 'register') continue;
    if (/:\w+(\/|$)/.test(p)) continue; // zorunlu parametreli (users/:id)
    out.push(p.replace(/\/?:\w+\?$/, '')); // isteğe bağlı parametre: analytics/:tab?
  }
  return [...new Set(out)];
}

const entries = buildSearchEntries((k) => translate('tr', k));

describe('arama kayıt defteri kapsamı', () => {
  it('girdi kimlikleri benzersiz ve sayfa kimlikleri menüde var', () => {
    const navIds = new Set(adminNav.flatMap((g) => g.items.map((i) => i.id)));
    const ids = registeredEntries.map((e) => e.id);
    expect(
      ids.filter((id, i) => ids.indexOf(id) !== i),
      'yinelenen kimlik',
    ).toEqual([]);
    expect(
      registeredEntries.filter((e) => !navIds.has(e.page)).map((e) => `${e.id} → ${e.page}`),
      'menüde olmayan sayfa',
    ).toEqual([]);
    expect(entries.length).toBe(registeredEntries.length + navIds.size);
  });

  it('başlık boş değil, anchor biçimi geçerli, ayarın anchor değeri var', () => {
    for (const e of registeredEntries) {
      expect(e.title.trim(), e.id).not.toBe('');
      if (e.anchor) expect(e.anchor, e.id).toMatch(/^[A-Za-z0-9._-]+$/);
      if (e.kind === 'setting') expect(e.anchor, `${e.id}: ayarın anchor değeri olmalı`).toBeTruthy();
    }
  });

  it('her admin rotası için en az 1 girdi var', () => {
    const covered = new Set(entries.map((e) => e.path.split('?')[0].replace(/\/+$/, '')));
    const missing = adminRoutes()
      .map((p) => (p ? `${ADMIN_BASE}/${p}` : ADMIN_BASE))
      .filter((full) => !covered.has(full));
    expect(missing, 'girdisi olmayan admin rotaları').toEqual([]);
  });

  it('her girdinin anchor değeri kaynak kodda bulunur', () => {
    const missing = registeredEntries.filter((e) => e.anchor && !anchorFound(e.anchor)).map((e) => `${e.id} → #${e.anchor}`);
    expect(missing, 'kaynakta karşılığı olmayan anchor değerleri').toEqual([]);
  });

  it('her sayfanın derin girdisi var; BEKLENEN_EKSIKLER boş ve eksik sayısı gerçekten sıfır', () => {
    const deep = new Set(registeredEntries.filter((e) => e.kind !== 'page').map((e) => e.page));
    const shallow = adminNav.flatMap((g) => g.items.map((i) => i.id)).filter((id) => !deep.has(id));
    expect(BEKLENEN_EKSIKLER, 'istisna listesi boş kalmalı').toEqual([]);
    expect(shallow, 'bu sayfalar derin girdi (bölüm/ayar/alan/eylem) eklemeli').toEqual([]);
    expect(deep.size).toBeGreaterThan(0);
  });

  it('SettingRow her ayar alanına anchor koyar (anahtar = anchor)', () => {
    const row = sources.find((s) => /settings[\\/]SettingRow\.tsx$/.test(s.file));
    expect(row?.text).toContain('data-search-anchor={k}');
  });
});
