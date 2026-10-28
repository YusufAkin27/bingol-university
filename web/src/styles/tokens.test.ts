import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { isolateLatinIdentifiers } from '../i18n/bidi';

/** Ortak tasarim dili (mobil BuTokens ile ayni): tokens.css/global.css sozlesmesi. Testler web/ klasorunden calisir. */

const root = process.cwd();
const read = (p: string) => readFileSync(join(root, p), 'utf-8');
const tokens = read('src/styles/tokens.css').toLowerCase();
const global = read('src/styles/global.css');
const indexHtml = read('index.html');
const cardCss = read('src/components/ui/Card.module.css');

function cssFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((n: string) => {
    const p = join(dir, n);
    if (statSync(p).isDirectory()) return cssFiles(p);
    return p.endsWith('.css') ? [p] : [];
  });
}
const allCss: Record<string, string> = Object.fromEntries(
  cssFiles(join(root, 'src')).map((f) => [f, readFileSync(f, 'utf-8')]),
);

function luminance(hex: string): number {
  const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
  const [r, g, b] = c.map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
const contrast = (a: string, b: string) => {
  const [x, y] = [luminance(a), luminance(b)].sort((m, n) => n - m);
  return (x + 0.05) / (y + 0.05);
};

describe('tasarım belirteçleri', () => {
  it('mobil BuTokens renkleriyle aynı', () => {
    for (const c of ['#faf6f3', '#171e33', '#c62a20', '#e8dfd8', '#dc3125', '#f3ece7', '#fde7e4']) {
      expect(tokens, c).toContain(c);
    }
  });

  it('yarıçap ölçeği: 20 kart, 14 girdi/düğme, 10 çip', () => {
    expect(tokens).toMatch(/--radius-lg:\s*20px/);
    expect(tokens).toMatch(/--radius-md:\s*14px/);
    expect(tokens).toMatch(/--radius-sm:\s*10px/);
  });

  it('kartlar gölgesiz (mobil gibi ince kenarlık)', () => {
    expect(tokens).not.toMatch(/--shadow-1:\s*0/);
    expect(cardCss).not.toContain('--shadow-1');
    expect(cardCss).toContain('border: 1px solid var(--border)');
  });

  it('hero üzerindeki beyaz yazı AA (>= 4,5:1) ve çerçeve >= 3:1', () => {
    const hero = /--hero:\s*(#[0-9a-f]{6})/.exec(tokens)![1];
    const end = /--hero-end:\s*(#[0-9a-f]{6})/.exec(tokens)![1];
    expect(contrast('#ffffff', hero)).toBeGreaterThanOrEqual(4.5);
    expect(contrast('#ffffff', end)).toBeGreaterThanOrEqual(4.5);
    // rgba(255,255,255,a) karışımı: hero zemini üzerinde bileşik renk
    const a = Number(/--hero-line:\s*rgba\(255,\s*255,\s*255,\s*([\d.]+)\)/.exec(tokens)![1]);
    const mix = '#' + [1, 3, 5].map((i) => Math.round(parseInt(hero.slice(i, i + 2), 16) * (1 - a) + 255 * a).toString(16).padStart(2, '0')).join('');
    expect(contrast(mix, hero)).toBeGreaterThanOrEqual(3);
  });

  it('Inter: serif yok, 400-800 değişken, yerel woff2 dosyaları var', () => {
    expect(tokens).toMatch(/--font-sans:\s*'inter'/);
    expect(tokens).not.toMatch(/georgia|palatino|iowan|(?<!sans-)serif/);
    expect(global).toMatch(/font-family:\s*'Inter'/);
    expect(global).toMatch(/font-weight:\s*400 800/);
    expect(global).toContain('font-display: swap');
    for (const f of ['inter-latin.woff2', 'inter-latin-ext.woff2', 'INTER-LICENSE.txt']) {
      expect(existsSync(join(root, 'public/fonts', f)), f).toBe(true);
    }
    expect(indexHtml).toMatch(/rel="preload"[^>]*inter-latin\.woff2[^>]*crossorigin/);
  });

  it('hiçbir CSS dosyasında literal px border-radius yok (token kullanılır)', () => {
    const bad: string[] = [];
    for (const [f, text] of Object.entries(allCss)) {
      text.split('\n').forEach((line: string, i: number) => {
        if (/border-[a-z-]*radius:\s*[^;]*\b\d+px/.test(line) && !line.includes('var(--radius')) bad.push(`${f}:${i + 1}: ${line.trim()}`);
        if (/var\(--radius-[a-z]+,\s*\d/.test(line)) bad.push(`${f}:${i + 1}: yedek px: ${line.trim()}`);
      });
    }
    expect(bad).toEqual([]);
  });
});

describe('Arapça bidi yalıtımı', () => {
  it('alan adı, e-posta ve URL LRI/PDI ile sarılır', () => {
    const out = isolateLatinIdentifiers('سجّل ببريدك bingol.edu.tr أو info@bingol.edu.tr أو https://www.bingol.edu.tr/x.');
    expect(out).toContain('⁦bingol.edu.tr⁩');
    expect(out).toContain('⁦info@bingol.edu.tr⁩');
    expect(out).toContain('⁦https://www.bingol.edu.tr/x⁩.');
  });
  it('Latin kimlik yoksa metin değişmez', () => {
    expect(isolateLatinIdentifiers('مرحبا بكم')).toBe('مرحبا بكم');
    expect(isolateLatinIdentifiers('BÜ Kampüs 1.5')).toBe('BÜ Kampüs 1.5');
  });
});
