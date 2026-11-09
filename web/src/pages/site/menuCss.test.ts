// Yemek listesi CSS'i: koyu temada okunabilirlik için ham renk/kalın yazı/gradient yok, seçili çip ters yüzey token'ıdır.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const files = ['MenuPage.module.css', 'components/MenuAppBand.module.css'].map((f) =>
  readFileSync(join(process.cwd(), 'src/pages/site', f), 'utf-8'),
);

describe('Menü sayfası CSS (token temelli)', () => {
  it.each(files.map((c, i) => [i, c] as const))('dosya %i: ham renk, sayısal font-weight, gradient yok', (_i, css) => {
    expect(css).not.toMatch(/#[0-9a-f]{3,8}\b/i);
    expect(css).not.toMatch(/rgba?\(/i);
    expect(css).not.toMatch(/font-weight:\s*\d/);
    expect(css).not.toMatch(/gradient\(/);
    expect(css).not.toMatch(/--(chrome|primary|red-\d+)\b/);
  });
  it('seçili gün çipi ve puanla kartı yüzey/yazı token çiftidir', () => {
    const css = files[0];
    expect(css).toMatch(/\.chipOn,\s*\.chipOn:hover\s*\{[^}]*background: var\(--text\);[^}]*color: var\(--bg\)/);
    expect(css).toMatch(/\.rate\s*\{[^}]*background: var\(--surface\);[^}]*color: var\(--text\)/);
  });
});
