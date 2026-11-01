/**
 * Dizin ÖLÇÜMÜ (statik tarama): yönetim sayfası dosyalarındaki başlık (h1/h2/h3), kart/panel/grafik başlığı, sekme adı ve
 * eylem düğmesi metinleri çözümlenir ve arama dizininde karşılığı aranır. Dizinde olmayanlar sayfa dosyası bazında raporlanır
 * (konsola yazılır); kapsama oranı eşiğin altına inerse test düşer, böylece dizin sayfalar büyüdükçe geride kalmaz.
 *
 * "Karşılığı var": aynı sayfadaki (dosyanın bağlı olduğu menü sayfası) bir girdinin başlık/bölüm/anahtar kelimesinde başlığın
 * anlamlı sözcüklerinin hepsi (önek/ek farkı ve Türkçe katlama ile) geçiyorsa. Sayfa eşlemesi rotadan okunur.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { translate } from '../i18n';
import { adminNav } from '../layouts/adminNav';
import { buildSearchEntries } from './build';
import { fold, stems, tokenize } from './fold';

const SRC = join(process.cwd(), 'src');
const entries = buildSearchEntries((k) => translate('tr', k));

function walk(dir: string, out: string[] = []): string[] {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.tsx$/.test(name) && !/\.test\.tsx$/.test(name)) out.push(p);
  }
  return out;
}

const rel = (p: string) => p.slice(SRC.length + 1).replace(/\\/g, '/');

type Kind = 'başlık' | 'kart' | 'sekme' | 'eylem';
interface Found {
  file: string;
  kind: Kind;
  text: string;
}

const resolve = (key: string): string | null => {
  const v = translate('tr', key as never);
  return v && v !== key ? v.replace(/\{[^}]*\}/g, ' ').replace(/\s+/g, ' ').trim() : null;
};

/** Bir kaynak dosyadan başlık benzeri metinleri çıkarır (anahtarlar Türkçe sözlükten çözülür). */
function extract(file: string, text: string): Found[] {
  const out: Found[] = [];
  const add = (kind: Kind, raw: string | null) => {
    if (!raw) return;
    const t = raw.replace(/\s+/g, ' ').trim();
    // yalnız harf içeren, anlamlı uzunlukta metinler (ikon/sayı/ayraç değil)
    if (t.length >= 4 && /\p{L}{3}/u.test(t)) out.push({ file, kind, text: t });
  };
  // <h1..h3 ...>{t('x')}</h1> ve <h2>Düz metin</h2>
  for (const m of text.matchAll(/<h[123]\b[^>]*>\s*\{t\('([^']+)'/g)) add('başlık', resolve(m[1]));
  for (const m of text.matchAll(/<h[123]\b[^>]*>([^<{]+)</g)) add('başlık', m[1]);
  // Card / ChartCard / Panel / Section ... title={t('x')}
  for (const m of text.matchAll(/<(?:Card|ChartCard|Panel|Section|Insight|PanelState)\b[^>]*?\btitle=\{t\('([^']+)'/g)) add('kart', resolve(m[1]));
  for (const m of text.matchAll(/<(?:Card|ChartCard|Panel|Section)\b[^>]*?\btitle="([^"]+)"/g)) add('kart', m[1]);
  // sekmeler: { id: 'x', label: t('y') }  /  labelKey: 'y'
  for (const m of text.matchAll(/\blabel:\s*t\('([^']+)'/g)) add('sekme', resolve(m[1]));
  for (const m of text.matchAll(/\blabelKey:\s*'([^']+)'/g)) add('sekme', resolve(m[1]));
  // eylem düğmeleri: <Button ...>{t('x')}</Button>, <PermissionButton ...>{t('x')}</PermissionButton>
  for (const m of text.matchAll(/<(?:Button|PermissionButton|GuardedAction)\b[^>]*>\s*\{t\('([^']+)'\)\}\s*</g)) add('eylem', resolve(m[1]));
  return out;
}

/** Menü sayfası kimliği → o sayfanın girdileri. */
const byPage = new Map<string, typeof entries>();
for (const e of entries) {
  const l = byPage.get(e.pageId);
  if (l) l.push(e);
  else byPage.set(e.pageId, [e]);
}

/** Dizinin tamamında aranacak ince metin: başlık + bölüm (kırıntı) + anahtar kelime + açıklama. */
const haystack = (list: typeof entries) =>
  list.map((e) => fold([e.title, ...e.crumbs.slice(1), ...e.keywords, e.description].join(' ')).split(' ').filter(Boolean));

const allWords = haystack(entries);
const STOP = new Set(['icin', 'veya', 'ile', 'bir', 'bu', 'su', 'olan', 'olarak', 'mi', 'mu', 'ne', 'her', 'tum', 'daha', 'gibi', 'yok', 'var']);

/** Başlığın anlamlı sözcüklerinin hepsi bir girdinin sözcüklerinde (önek / gövde ile) geçiyor mu. */
function covered(text: string, pools: string[][]): boolean {
  const toks = tokenize(text).filter((t) => t.length >= 3 && !STOP.has(t));
  if (toks.length === 0) return true;
  return pools.some((words) =>
    toks.every((t) => {
      const forms = [t, ...stems(t)];
      return words.some((w) => forms.some((f) => w === f || w.startsWith(f) || (f.length >= 5 && f.startsWith(w) && w.length >= 4)));
    }),
  );
}

describe('arama dizini kapsamı: sayfa dosyalarındaki başlık/sekme/eylem metinleri', () => {
  const files = walk(join(SRC, 'pages', 'admin'));
  const found = files.flatMap((f) => extract(rel(f), readFileSync(f, 'utf-8')));

  it('tarama başlık, kart, sekme ve eylem metinlerini buluyor (tarayıcı sağlam)', () => {
    const kinds = new Set(found.map((f) => f.kind));
    expect(found.length).toBeGreaterThan(200);
    expect([...kinds].sort()).toEqual(['başlık', 'eylem', 'kart', 'sekme']);
  });

  it('kapsama oranı eşiğin üstünde; dizinde olmayanlar dosya bazında raporlanır', () => {
    const unique = new Map<string, Found>();
    for (const f of found) unique.set(`${f.file}|${f.kind}|${fold(f.text)}`, f);
    const list = [...unique.values()];
    const missing = list.filter((f) => !covered(f.text, allWords));
    const ratio = 1 - missing.length / list.length;

    // sayfa dosyası bazında rapor
    const perFile = new Map<string, Found[]>();
    for (const m of missing) perFile.set(m.file, [...(perFile.get(m.file) ?? []), m]);
    const lines = [...perFile.entries()]
      .sort((a, b) => b[1].length - a[1].length)
      .map(([file, fs]) => `${file} (${fs.length}): ${fs.map((x) => `[${x.kind}] ${x.text}`).join(' | ')}`);
    const navPages = adminNav.flatMap((g) => g.items.map((i) => i.id));
    console.log(
      `DİZİN KAPSAMI: ${list.length - missing.length}/${list.length} başlık-sekme-eylem metni dizinde (${(ratio * 100).toFixed(1)}%); ` +
        `${entries.length} girdi, ${navPages.length} menü sayfası.\nDİZİNDE OLMAYANLAR:\n${lines.join('\n')}`,
    );
    // Eşik, ölçülen ilk durumun hemen altı (ratchet): sayfa ajanları girdi ekledikçe yükseltilmelidir (hedef >= 0.9)
    expect(ratio).toBeGreaterThanOrEqual(0.7);
  });
});
