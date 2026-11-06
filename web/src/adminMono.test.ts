/**
 * Yönetim paneli "Premium Monochrome" kuralları (docs/WEB_DESIGN_SYSTEM.md "Yönetim paneli: monochrome"):
 *  - yönetim kapsamındaki CSS Modules ve bileşenlerde ham renk değeri yok (hex/rgb/hsl/isimli renk; belirteç dosyası ve izinli dosyalar hariç)
 *  - hiçbir yerde sayısal font-weight > 400 yok: ağırlık yalnız var(--fw-*) belirteçleriyle yazılır
 *  - yönetim kapsamı belirteçleri (tokens.css) nötrdür: tehlike dışında kromatik renk yok, tüm --fw-* 400'e bağlı
 *  - gradient yalnız nötr (kaydırma gölgesi/desen); renkli gradient yok
 * Herkese açık site (pages/site, SiteLayout) bilerek kapsam dışıdır.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { describe, expect, it } from 'vitest';

const SRC = join(process.cwd(), 'src');

function walk(dir: string, out: string[] = []): string[] {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}
const rel = (p: string) => relative(SRC, p).split(sep).join('/');
const files = walk(SRC).map((p) => ({ p, r: rel(p) }));

/** Yönetim kapsamı: site sayfaları, site kabuğu ve belirteç/küresel dosyalar hariç tüm CSS Modules. */
const adminCss = files.filter(
  (f) => f.r.endsWith('.css') && !f.r.startsWith('pages/site/') && f.r !== 'layouts/SiteLayout.module.css' && f.r !== 'styles/tokens.css',
);
/** Yönetim kapsamı kaynak kodu: sayfalar, kabuk, UI kiti, grafik bileşenleri (testler hariç). */
const adminCode = files.filter(
  (f) =>
    /\.(tsx|ts)$/.test(f.r) &&
    !/\.test\.tsx?$/.test(f.r) &&
    (f.r.startsWith('pages/admin/') || f.r.startsWith('components/ui/') || f.r.startsWith('components/charts/') || f.r.startsWith('components/admin/') || f.r === 'layouts/AdminLayout.tsx'),
);

const stripComments = (s: string) => s.replace(/\/\*[\s\S]*?\*\//g, '');
const RAW_COLOR = /#[0-9a-fA-F]{3,8}\b|\brgba?\(|\bhsla?\(|\bhwb\(|\blab\(|\blch\(|\boklch\(/;
const NAMED = /:\s*(?:red|blue|green|orange|purple|yellow|pink|teal|navy|gold|crimson|tomato|cyan|magenta)\b/;

/** Ham renge izin verilen dosyalar (neden: ... ); şimdilik yok: her renk tokens.css'tedir. */
const RAW_COLOR_ALLOW = new Set<string>([]);

describe('yönetim monochrome: ham renk yok', () => {
  it('CSS Modules ham renk içermez (renkler tokens.css belirteçlerinden gelir)', () => {
    const bad: string[] = [];
    for (const f of adminCss) {
      if (RAW_COLOR_ALLOW.has(f.r)) continue;
      const lines = stripComments(readFileSync(f.p, 'utf-8')).split('\n');
      // global.css: @font-face unicode-range (U+...) hex değildir; yine de renk aranır
      lines.forEach((l, i) => {
        if (/unicode-range|U\+[0-9A-F]/.test(l)) return;
        if (/data:image\/svg\+xml/.test(l)) return; // maske simgesi: renk 'black' kanalıdır, görünür renk currentColor
        if (RAW_COLOR.test(l) || NAMED.test(l)) bad.push(`${f.r}:${i + 1}: ${l.trim()}`);
      });
    }
    expect(bad, bad.join('\n')).toEqual([]);
  });

  it('bileşen ve sayfa kodunda satır içi ham renk yok', () => {
    const bad: string[] = [];
    for (const f of adminCode) {
      const lines = readFileSync(f.p, 'utf-8').split('\n');
      lines.forEach((l, i) => {
        if (/^\s*(\/\/|\*|\/\*)/.test(l)) return; // yorum
        const code = l.replace(/\/\/.*$/, '');
        if (/#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b(?![\w-])/.test(code) && /['"`]#[0-9a-fA-F]{3,8}['"`]/.test(code)) bad.push(`${f.r}:${i + 1}: ${l.trim()}`);
        if (/\b(?:rgba?|hsla?)\(/.test(code)) bad.push(`${f.r}:${i + 1}: ${l.trim()}`);
      });
    }
    expect(bad, bad.join('\n')).toEqual([]);
  });
});

describe('yönetim monochrome: kalın yazı yok', () => {
  it('CSS font-weight yalnız var(--fw-*) ya da en çok 400 (site hariç)', () => {
    const bad: string[] = [];
    for (const f of [...adminCss.filter((x) => x.r !== 'styles/global.css')]) {
      const lines = stripComments(readFileSync(f.p, 'utf-8')).split('\n');
      lines.forEach((l, i) => {
        for (const m of l.matchAll(/font-weight:\s*([^;}]+)/g)) {
          const v = m[1].trim().replace(/\s*!important$/, '');
          if (/^var\(--fw-[a-z]+\)$/.test(v) || v === 'inherit' || v === 'normal') continue;
          const n = Number(v);
          if (Number.isFinite(n) && n <= 400) continue;
          bad.push(`${f.r}:${i + 1}: ${l.trim()}`);
        }
      });
    }
    expect(bad, bad.join('\n')).toEqual([]);
  });

  it('TSX satır içi fontWeight yalnız belirteç ya da en çok 400', () => {
    const bad: string[] = [];
    for (const f of adminCode) {
      readFileSync(f.p, 'utf-8')
        .split('\n')
        .forEach((l, i) => {
          for (const m of l.matchAll(/fontWeight:\s*([^,}\s]+)/g)) {
            const v = m[1].replace(/['"]/g, '');
            if (/^var\(--fw-[a-z]+\)$/.test(v)) continue;
            if (Number(v) <= 400) continue;
            bad.push(`${f.r}:${i + 1}: ${l.trim()}`);
          }
        });
    }
    expect(bad, bad.join('\n')).toEqual([]);
  });

  it('küresel h3/h4 ve kalın öğeler yönetim kapsamında belirteçle yazılır', () => {
    const g = readFileSync(join(SRC, 'styles/global.css'), 'utf-8');
    expect(g).toMatch(/h3,\s*h4\s*\{\s*font-weight:\s*var\(--fw-bold\)/);
    expect(g).toMatch(/html\[data-area='admin'\] :is\(strong, b, th[^)]*\)\s*\{\s*font-weight:\s*var\(--fw-emphasis\)/);
  });
});

describe('yönetim monochrome: belirteçler', () => {
  const tokens = readFileSync(join(SRC, 'styles/tokens.css'), 'utf-8');
  const cut = tokens.indexOf("html:root[data-area='admin'] {");
  const siteAt = tokens.indexOf('/* site */'); // herkese açık site bloğu (ayrı ajan/karar) yönetim denetiminin dışında
  const admin = tokens.slice(cut, siteAt > cut ? siteAt : undefined);

  it('yönetim bloğunda tüm ağırlık belirteçleri tek --fw-emphasis (400) anahtarına bağlı', () => {
    expect(admin).toMatch(/--fw-emphasis:\s*400;/);
    for (const k of ['regular', 'medium', 'semibold', 'bold', 'black']) {
      expect(admin).toMatch(new RegExp(`--fw-${k}:\\s*var\\(--fw-emphasis\\)`));
    }
    expect(admin).toMatch(/--weight-display:\s*var\(--fw-emphasis\)/);
  });

  it('yönetim bloğundaki hex renkler nötr (R=G=B ±16) ya da yalnız tehlike belirteçleri', () => {
    const bad: string[] = [];
    for (const m of admin.matchAll(/(--[a-z0-9-]+):\s*(#[0-9a-fA-F]{6})\b/g)) {
      const [, name, hex] = m;
      if (/^--danger/.test(name)) continue;
      const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
      if (Math.max(r, g, b) - Math.min(r, g, b) > 16) bad.push(`${name}: ${hex}`);
    }
    expect(bad).toEqual([]);
  });

  it('başarı/uyarı/bilgi renkli değil (nötr belirteçlere bağlı), tehlike korunur', () => {
    for (const k of ['success', 'warning', 'info']) {
      expect(admin).toMatch(new RegExp(`--${k}:\\s*var\\(--(text|text-muted)\\)`));
    }
    expect(admin).toMatch(/--danger:\s*#b3261e/);
    expect(admin).toMatch(/--primary:\s*var\(--text\)/);
    expect(admin).toMatch(/--accent:\s*var\(--text\)/);
    expect(admin).toMatch(/--link:\s*var\(--text\)/);
  });

  it('açık + iki koyu blok birlikte tanımlı (açık, sistem koyu, elle koyu)', () => {
    expect(admin.match(/html:root\[data-area='admin'\]/g)!.length).toBe(3);
    expect(admin).toContain("html:root[data-area='admin']:not([data-theme='light'])");
    expect(admin).toContain("html:root[data-area='admin'][data-theme='dark']");
  });
});

describe('yönetim monochrome: gradient', () => {
  it('gradient yalnız renksiz (nötr belirteç) duraklarla kullanılır', () => {
    const bad: string[] = [];
    for (const f of adminCss) {
      const src = stripComments(readFileSync(f.p, 'utf-8'));
      for (const m of src.matchAll(/(?:repeating-)?(?:linear|radial|conic)-gradient\(([^;]*)\)/g)) {
        const body = m[1];
        if (RAW_COLOR.test(body) || /var\(--(?:primary|accent|info|success|warning|red-\d+|hero[a-z-]*|brand[a-z-]*|chart-[2-6])\b/.test(body))
          bad.push(`${f.r}: ${m[0].slice(0, 80)}`);
      }
    }
    expect(bad, bad.join('\n')).toEqual([]);
  });
});
