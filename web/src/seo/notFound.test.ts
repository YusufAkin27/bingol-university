/**
 * T-158 / A3-12: bilinmeyen site yolları HTTP 404 dönmeli (soft 404 değil). 404.html üretimi, nginx kural sırası ve
 * "gerçek rotalar 404'e düşmesin" korumaları.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { LEGAL_TYPES } from '../api/legal';
import { paths } from '../paths';
import { SEO_END, SEO_START, prerender, render404 } from './prerender';
import { ROUTE_META } from './routeMeta';

const TEMPLATE = `<!doctype html>
<html lang="tr" dir="ltr">
  <head>
    <meta charset="UTF-8" />
    ${SEO_START}
    <title>BÜ Kampüs</title>
    ${SEO_END}
    <script type="module" src="/assets/index-abc.js"></script>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>`;

const NGINX = readFileSync(join(process.cwd(), 'nginx.conf'), 'utf-8');

describe('404.html (prerender)', () => {
  const html = render404(TEMPLATE);

  it('noindex + açıklama + h1 içerir, canonical/hreflang içermez', () => {
    expect(html).toContain('<meta name="robots" content="noindex, nofollow"');
    expect(html).toContain('<meta name="description"');
    expect(html).toContain('<title>Sayfa bulunamadı | BÜ Kampüs</title>');
    expect(html).toMatch(/<h1>Sayfa bulunamadı<\/h1>/);
    expect(html).not.toContain('rel="canonical"');
    expect(html).not.toContain('hreflang');
    expect(html).toContain('<script type="module" src="/assets/index-abc.js">');
  });

  it('üç dilde başlık ve ana sayfa bağlantısı verir (Arapça RTL)', () => {
    expect(html).toContain('<h1>Page not found</h1>');
    expect(html).toContain('<section lang="ar" dir="rtl"><h1>');
    expect(html).toContain('<a href="/tr">');
    expect(html).toContain('<a href="/en">');
    expect(html).toContain('<a href="/ar">');
  });

  it('prerender() çıktısına 404.html eklenir ama sitemap/sayfa sayısına girmez', () => {
    const r = prerender({ template: TEMPLATE, buildDate: '2026-10-31' });
    expect(r.files.has('404.html')).toBe(true);
    expect(r.files.get('sitemap.xml')).not.toContain('404');
  });

  it('şablon işaretleri yoksa hata verir', () => {
    expect(() => render404('<html><body><div id="root"></div></body></html>')).toThrow();
  });
});

describe('nginx.conf soft 404 kuralları', () => {
  const idx = (needle: string) => NGINX.indexOf(needle);

  it('error_page 404 -> /404.html ve 404.html noindex başlığı', () => {
    expect(NGINX).toMatch(/error_page 404 \/404\.html;/);
    const block = NGINX.slice(idx('location = /404.html'), idx('location = /404.html') + 400);
    expect(block).toContain('internal;');
    expect(block).toContain('X-Robots-Tag "noindex, nofollow"');
  });

  it('dil önekli genel kural =404 ile biter ve özel (dinamik) kurallardan SONRA gelir', () => {
    const general = idx('location ~ ^/(tr|en|ar)(/|$) {');
    expect(general).toBeGreaterThan(0);
    expect(NGINX.slice(general, general + 300)).toContain('try_files $uri/index.html $uri =404;');
    for (const special of ['/news/[0-9]+', '/legal/(terms', '/support/track']) {
      const at = idx(special);
      expect(at, special).toBeGreaterThan(0);
      expect(at, `${special} genel kuraldan önce olmalı`).toBeLessThan(general);
    }
  });

  it('/support/track noindex başlığı taşır', () => {
    const at = idx('location ~ ^/(tr|en|ar)/support/track');
    expect(NGINX.slice(at, at + 300)).toContain('X-Robots-Tag "noindex, nofollow"');
  });

  it('hukuki metin kuralı her LegalType için paths.site.legal çıktısını (ve büyük harfli yazımı) kapsar', () => {
    const m = /location ~\* (\^\/\(tr\|en\|ar\)\/legal\/[^ ]+) \{/.exec(NGINX);
    expect(m).not.toBeNull();
    const re = new RegExp(m![1], 'i');
    for (const type of LEGAL_TYPES) {
      for (const lang of ['tr', 'en', 'ar']) {
        expect(re.test(`/${lang}${paths.site.legal(type)}`), `${lang} ${type}`).toBe(true);
        expect(re.test(`/${lang}/legal/${type}`), `${lang} ${type} büyük harf`).toBe(true);
      }
    }
    expect(re.test('/tr/legal/zzz')).toBe(false);
  });

  it('haber kimliği kuralı yalnız sayısal kimlik kabul eder', () => {
    const m = /location ~ (\^\/\(tr\|en\|ar\)\/news\/\[0-9\]\+\/\?\$) \{/.exec(NGINX);
    expect(m).not.toBeNull();
    const re = new RegExp(m![1]);
    expect(re.test('/tr/news/123')).toBe(true);
    expect(re.test('/ar/news/9/')).toBe(true);
    expect(re.test('/tr/news/abc')).toBe(false);
  });
});

describe('gerçek site rotaları 404\'e düşmez', () => {
  // routes.tsx'teki `<Route path="..."` satırlarından site rotaları (":lang" kapsamı)
  const src = readFileSync(join(process.cwd(), 'src', 'routes.tsx'), 'utf-8');
  const start = src.indexOf('path=":lang"');
  const end = src.indexOf('path="*"', start);
  const staticPaths = [...src.slice(start, end).matchAll(/<Route path="([^"]+)"/g)]
    .map((m) => m[1])
    .filter((p) => !p.includes(':') && p !== '*');

  const prerendered = new Set(ROUTE_META.map((r) => r.path.replace(/^\//, '')));
  /** Önrender dosyası olmayan ama nginx'te özel kuralı olan statik rotalar. */
  const SHELL_RULES = new Set(['support/track']);

  it('routes.tsx statik site rotaları ya önrenderlıdır ya da nginx özel kuralı vardır', () => {
    expect(staticPaths.length).toBeGreaterThan(15);
    const missing = staticPaths.filter((p) => !prerendered.has(p) && !SHELL_RULES.has(p));
    expect(missing).toEqual([]);
  });

  it('SHELL_RULES her rotası nginx.conf içinde geçer', () => {
    for (const p of SHELL_RULES) expect(NGINX).toContain(p);
  });
});
