import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { dictionaries } from '../i18n/all';
import { LANGS } from '../i18n/lang';
import { isAdminPath, localizePath, splitLangPath, switchLangPath } from '../i18n/langPath';
import { buildHeadModel, normalizeOrigin, pageUrl } from './headModel';
import {
  SEO_END,
  SEO_START,
  buildRobots,
  buildSitemap,
  pageFile,
  prerender,
  renderNoscript,
  renderSecurityTxt,
  routeJsonLd,
} from './prerender';
import { ROUTE_META, infoRouteId, legalRouteId, matchRouteMeta, resolveMeta, routeById } from './routeMeta';

const ORIGIN = 'https://example.org';
const TEMPLATE = `<!doctype html>
<html lang="tr" dir="ltr">
  <head>
    <meta charset="UTF-8" />
    ${SEO_START}
    <title>BÜ Kampüs</title>
    <meta property="og:image" content="/og.png" />
    ${SEO_END}
    <script type="module" src="/assets/index-abc.js"></script>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>`;

describe('routeMeta (tek kaynak)', () => {
  it('her rota × dil için başlık ve açıklama dolu (anahtar sızıntısı yok)', () => {
    for (const l of LANGS) {
      for (const r of ROUTE_META) {
        const m = resolveMeta(r, l.code);
        expect(m.title.trim(), `${l.code} ${r.id} başlık`).not.toBe('');
        expect(m.description.trim(), `${l.code} ${r.id} açıklama`).not.toBe('');
        expect(m.title, `${l.code} ${r.id}`).not.toMatch(/^(site|pg|legal|seo)\./);
        expect(m.description, `${l.code} ${r.id}`).not.toMatch(/^(site|pg|legal|seo)\./);
        const d = dictionaries[l.code] as Record<string, string>;
        expect(d[r.titleKey], `${l.code} ${r.titleKey}`).toBeTruthy();
        expect(d[r.descKey], `${l.code} ${r.descKey}`).toBeTruthy();
      }
    }
  });

  it('dil içinde başlıklar ve açıklamalar tekrar etmez', () => {
    for (const l of LANGS) {
      const titles = ROUTE_META.map((r) => resolveMeta(r, l.code).fullTitle);
      const descs = ROUTE_META.map((r) => resolveMeta(r, l.code).description);
      expect(new Set(titles).size, `${l.code} başlık`).toBe(titles.length);
      expect(new Set(descs).size, `${l.code} açıklama`).toBe(descs.length);
    }
  });

  it('kimlikler ve yollar benzersiz; yollar paths ile uyumlu mantıksal yollar (öneksiz, yönetimsiz)', () => {
    expect(new Set(ROUTE_META.map((r) => r.id)).size).toBe(ROUTE_META.length);
    expect(new Set(ROUTE_META.map((r) => r.path)).size).toBe(ROUTE_META.length);
    for (const r of ROUTE_META) {
      expect(r.path.startsWith('/')).toBe(true);
      expect(splitLangPath(r.path).lang).toBeNull();
      expect(isAdminPath(r.path)).toBe(false);
    }
  });

  it('ana sayfa başlığı "BÜ Kampüs · slogan", diğerleri "Başlık · BÜ Kampüs"', () => {
    expect(resolveMeta(routeById('home'), 'tr').fullTitle).toBe('BÜ Kampüs · Kampüs hayatı tek uygulamada');
    expect(resolveMeta(routeById('privacy'), 'tr').fullTitle).toBe('Gizlilik politikası · BÜ Kampüs');
  });

  it('eş adlar ve arama', () => {
    expect(matchRouteMeta('/privacy')?.id).toBe('privacy');
    expect(matchRouteMeta('/legal/privacy')?.id).toBe('privacy');
    expect(matchRouteMeta('/legal/cookies')?.id).toBe('cookies');
    expect(matchRouteMeta('/delete-account/')?.id).toBe('deleteAccount');
    expect(matchRouteMeta('/news/7')).toBeUndefined();
    expect(legalRouteId('KVKK')).toBe('legalKvkk');
    expect(legalRouteId('COOKIES')).toBe('cookies');
    expect(infoRouteId('delete')).toBe('deleteAccount');
  });

  it('mağaza sayfaları (gizlilik, hesap silme, iletişim) üç dilde rota tablosunda', () => {
    for (const id of ['privacy', 'deleteAccount', 'contact']) expect(ROUTE_META.some((r) => r.id === id)).toBe(true);
  });
});

describe('dil yolu yardımcıları', () => {
  it('splitLangPath', () => {
    expect(splitLangPath('/en/news/3')).toEqual({ lang: 'en', rest: '/news/3' });
    expect(splitLangPath('/ar')).toEqual({ lang: 'ar', rest: '/' });
    expect(splitLangPath('/privacy')).toEqual({ lang: null, rest: '/privacy' });
    expect(splitLangPath('/de/x').lang).toBeNull();
    expect(splitLangPath('/tray').lang).toBeNull();
  });

  it('localizePath: önek ekler; yönetim, dış bağlantı, çapa ve önekli yol değişmez', () => {
    expect(localizePath('/privacy', 'tr')).toBe('/tr/privacy');
    expect(localizePath('/', 'en')).toBe('/en');
    expect(localizePath('/news/3?x=1#a', 'ar')).toBe('/ar/news/3?x=1#a');
    expect(localizePath('/admin/users', 'tr')).toBe('/admin/users');
    expect(localizePath('/admin', 'en')).toBe('/admin');
    expect(localizePath('/en/about', 'tr')).toBe('/en/about');
    expect(localizePath('https://x.org/a', 'tr')).toBe('https://x.org/a');
    expect(localizePath('//cdn.x.org/a', 'tr')).toBe('//cdn.x.org/a');
    expect(localizePath('#main', 'tr')).toBe('#main');
    expect(localizePath('mailto:a@b.c', 'tr')).toBe('mailto:a@b.c');
  });

  it('switchLangPath', () => {
    expect(switchLangPath('/tr/news/3?x=1', 'en')).toBe('/en/news/3?x=1');
    expect(switchLangPath('/tr', 'ar')).toBe('/ar');
    expect(switchLangPath('/privacy', 'en')).toBe('/en/privacy');
  });
});

describe('headModel', () => {
  it('canonical, hreflang (karşılıklı + x-default), OG ve Twitter etiketleri mutlak URL ile', () => {
    const m = buildHeadModel({
      lang: 'en',
      origin: ORIGIN,
      path: '/privacy',
      title: 'Privacy · BÜ Kampüs',
      description: 'd',
      appName: 'BÜ Kampüs',
    });
    expect(m.canonical).toBe(`${ORIGIN}/en/privacy`);
    const alt = m.links.filter((l) => l.rel === 'alternate');
    expect(alt.map((l) => l.hreflang)).toEqual(['tr', 'en', 'ar', 'x-default']);
    expect(alt.find((l) => l.hreflang === 'ar')?.href).toBe(`${ORIGIN}/ar/privacy`);
    expect(alt.find((l) => l.hreflang === 'x-default')?.href).toBe(`${ORIGIN}/tr/privacy`);
    const get = (k: string) => m.metas.filter((x) => x.key === k).map((x) => x.content);
    expect(get('og:image')).toEqual([`${ORIGIN}/og.png`]);
    expect(get('twitter:image')).toEqual([`${ORIGIN}/og.png`]);
    expect(get('og:image:alt')[0]).toBeTruthy();
    expect(get('og:url')).toEqual([`${ORIGIN}/en/privacy`]);
    expect(get('og:locale')).toEqual(['en_US']);
    expect(get('og:locale:alternate').sort()).toEqual(['ar_AR', 'tr_TR']);
    expect(get('twitter:title')).toEqual(['Privacy · BÜ Kampüs']);
    expect(get('twitter:description')).toEqual(['d']);
    expect(get('twitter:card')).toEqual(['summary_large_image']);
  });

  it('noindex sayfada alternatif/hreflang yok, robots var', () => {
    const m = buildHeadModel({ lang: 'tr', origin: ORIGIN, path: '/x', title: 't', appName: 'a', noindex: true });
    expect(m.links.filter((l) => l.rel === 'alternate')).toEqual([]);
    expect(m.metas.find((x) => x.key === 'robots')?.content).toBe('noindex');
  });

  it('pageUrl ve normalizeOrigin', () => {
    expect(pageUrl(ORIGIN, 'tr', '/')).toBe(`${ORIGIN}/tr`);
    expect(pageUrl(ORIGIN, 'ar', '/news/')).toBe(`${ORIGIN}/ar/news`);
    expect(normalizeOrigin('https://a.b///')).toBe('https://a.b');
    expect(normalizeOrigin('')).toBe('https://bukampus.com.tr');
    expect(normalizeOrigin(undefined)).toBe('https://bukampus.com.tr');
  });
});

describe('sitemap.xml', () => {
  const xml = buildSitemap(ORIGIN, '2026-10-28');

  it('yer tutucu yok, hepsi mutlak https adres', () => {
    expect(xml).not.toContain('ALAN-ADI');
    const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
    expect(locs.length).toBe(ROUTE_META.length * LANGS.length);
    for (const l of locs) expect(l).toMatch(/^https:\/\/example\.org\/(tr|en|ar)(\/|$)/);
    expect(new Set(locs).size).toBe(locs.length);
    expect(xml).toContain('<lastmod>2026-10-28</lastmod>');
  });

  it('hreflang karşılıklı: her url kendi dahil üç dili ve x-default listeler', () => {
    const blocks = xml.split('<url>').slice(1);
    const hrefsOf = (b: string) => [...b.matchAll(/hreflang="([^"]+)" href="([^"]+)"/g)].map((m) => [m[1], m[2]]);
    const byLoc = new Map<string, string[][]>();
    for (const b of blocks) byLoc.set(/<loc>([^<]+)<\/loc>/.exec(b)![1], hrefsOf(b));
    for (const [loc, alts] of byLoc) {
      expect(alts.map((a) => a[0])).toEqual(['tr', 'en', 'ar', 'x-default']);
      // kendisi alternatiflerde var
      expect(alts.map((a) => a[1])).toContain(loc);
      // alternatifin kendi bloğu da bu url'yi listeler (karşılıklılık)
      for (const [, href] of alts) {
        expect(byLoc.has(href), `${href} sitemap'te var`).toBe(true);
        expect(byLoc.get(href)!.map((a) => a[1])).toContain(loc);
      }
    }
  });

  it('yönetim yolu sitemap/robots içinde yok; robots Sitemap satırı mutlak', () => {
    expect(xml).not.toMatch(/\/admin/);
    const robots = buildRobots(ORIGIN);
    expect(robots).not.toContain('ALAN-ADI');
    expect(robots).toContain('Disallow: /admin');
    expect(robots).toContain('Disallow: /api/');
    expect(robots).toMatch(/^Sitemap: https:\/\/example\.org\/sitemap\.xml$/m);
    expect(robots).not.toMatch(/^#\s*Sitemap/m);
  });
});

describe('security.txt', () => {
  it('kaynak dosyadaki {{ORIGIN}} doldurulur, ALAN-ADI kalmaz', () => {
    const src = readFileSync(join(process.cwd(), 'public', '.well-known', 'security.txt'), 'utf-8');
    expect(src).not.toContain('ALAN-ADI');
    const out = renderSecurityTxt(src, ORIGIN);
    expect(out).not.toContain('{{');
    expect(out).toContain(`Contact: ${ORIGIN}/tr/security`);
    expect(out).toContain(`Canonical: ${ORIGIN}/.well-known/security.txt`);
  });
});

describe('önrender çıktısı', () => {
  const out = prerender({ template: TEMPLATE, origin: ORIGIN, buildDate: '2026-10-28' });

  it('her rota × dil için dosya + kök + sitemap + robots; dosya yolları dil önekli', () => {
    expect(out.pageCount).toBe(ROUTE_META.length * 3);
    for (const l of LANGS) for (const r of ROUTE_META) expect(out.files.has(pageFile(l.code, r.path))).toBe(true);
    expect(out.files.has('tr/privacy/index.html')).toBe(true);
    expect(out.files.has('en/delete-account/index.html')).toBe(true);
    expect(out.files.has('ar/index.html')).toBe(true);
    expect(out.files.has('index.html')).toBe(true);
    expect(out.files.has('sitemap.xml')).toBe(true);
    expect(out.files.has('robots.txt')).toBe(true);
  });

  it('tr/privacy: title, description, canonical, hreflang, OG, noscript, html lang/dir', () => {
    const html = out.files.get('tr/privacy/index.html')!;
    expect(html).toContain('<html lang="tr" dir="ltr">');
    expect(html).toContain('<title>Gizlilik politikası · BÜ Kampüs</title>');
    expect(html).toContain('<meta name="description" content="BÜ Kampüs gizlilik politikası');
    expect(html).toContain(`<link rel="canonical" href="${ORIGIN}/tr/privacy" data-pre="1" />`);
    for (const l of ['tr', 'en', 'ar'])
      expect(html).toContain(`hreflang="${l}" href="${ORIGIN}/${l}/privacy"`);
    expect(html).toContain(`hreflang="x-default" href="${ORIGIN}/tr/privacy"`);
    expect(html).toContain(`<meta property="og:image" content="${ORIGIN}/og.png"`);
    expect(html).toContain('property="og:image:alt"');
    expect(html).toContain('property="og:locale" content="tr_TR"');
    expect(html).toContain('property="og:locale:alternate" content="en_US"');
    expect(html).toContain('name="twitter:title" content="Gizlilik politikası · BÜ Kampüs"');
    expect(html).toContain('name="twitter:card" content="summary_large_image"');
    expect(html).toContain('<noscript>');
    expect(html).toContain('<h1>Gizlilik politikası</h1>');
    expect(html).toContain('bingol.edu.tr uzantılı e-posta');
    expect(html).toContain('<div id="root"><noscript>');
    expect(html).toContain('/assets/index-abc.js');
    expect(html).not.toContain('<title>BÜ Kampüs</title>');
    expect(html).not.toContain('content="/og.png"');
  });

  it('ar sayfası rtl ve Arapça metin; en sayfası İngilizce', () => {
    const ar = out.files.get('ar/privacy/index.html')!;
    expect(ar).toContain('<html lang="ar" dir="rtl">');
    expect(ar).toContain('property="og:locale" content="ar_AR"');
    expect(ar).toContain('سياسة');
    const en = out.files.get('en/privacy/index.html')!;
    expect(en).toContain('<html lang="en" dir="ltr">');
    expect(en).toContain('Privacy');
  });

  it('hesap silme: noscript JavaScript olmadan adımları, silinen veri tablosunu ve süreleri verir', () => {
    const html = out.files.get('tr/delete-account/index.html')!;
    const ns = /<noscript>([\s\S]*?)<\/noscript>/.exec(html)![1];
    expect(ns).toContain('<h1>Hesap silme</h1>');
    expect(ns).toContain('Hesabımı sil');
    expect(ns).toContain('<table');
    expect(ns).toContain('Profil bilgileri');
    expect(ns).toContain('Anonimleştirilir');
    expect(ns).toContain('Bildirim kutusu');
    expect(ns).toContain('/tr/data-request');
    expect(ns.replace(/<[^>]+>/g, ' ').length).toBeGreaterThan(1500);
  });

  it('iletişim sayfası noscript metni ve doğru başlık', () => {
    const html = out.files.get('en/contact/index.html')!;
    expect(html).toContain('<title>Contact · BÜ Kampüs</title>');
    expect(html).toMatch(/<noscript>[\s\S]*<h1>Contact<\/h1>/);
    expect(html).toContain(`rel="canonical" href="${ORIGIN}/en/contact"`);
  });

  it('tüm çıktıda yer tutucu ve bozuk işaret yok; her sayfa tam bir <title> ve canonical içerir', () => {
    for (const [file, body] of out.files) {
      expect(body, file).not.toContain('ALAN-ADI');
      expect(body, file).not.toContain('{{');
      if (!file.endsWith('.html')) continue;
      expect(body.match(/<title>/g)?.length, file).toBe(1);
      expect(body.match(/rel="canonical"/g)?.length, file).toBe(1);
      expect(body.match(/<noscript>/g)?.length, file).toBe(1);
      expect(body.match(/<html /g)?.length, file).toBe(1);
      expect(body, file).toContain(SEO_START);
    }
  });

  it('kök index.html Türkçe ana sayfa üstverisi ve dil bağlantıları taşır; yeniden çalıştırılabilir (idempotent)', () => {
    const root = out.files.get('index.html')!;
    expect(root).toContain(`rel="canonical" href="${ORIGIN}/tr"`);
    expect(root).toContain('href="/en"');
    expect(root).toContain('href="/ar"');
    const again = prerender({ template: root, origin: ORIGIN, buildDate: '2026-10-28' });
    expect(again.files.get('tr/privacy/index.html')).toBe(out.files.get('tr/privacy/index.html'));
  });

  it('işaretsiz şablon hata verir', () => {
    expect(() => prerender({ template: '<div id="root"></div>', origin: ORIGIN, buildDate: 'x' })).toThrow();
  });

  it('HTML kaçışı: sözlük metni etiket sızdırmaz', () => {
    for (const [file, body] of out.files) {
      if (!file.endsWith('.html')) continue;
      const ns = /<noscript>([\s\S]*?)<\/noscript>/.exec(body)![1];
      expect(ns, file).not.toMatch(/&amp;amp;|<script/);
    }
  });
});

describe('JSON-LD (önrender)', () => {
  const types = (id: string, lang: 'tr' | 'en' | 'ar' = 'tr') =>
    routeJsonLd(routeById(id), lang, ORIGIN).map((b) => (b as { '@type': string })['@type']);

  it('ana sayfa: kuruluş + mobil uygulama; diğer sayfalar BreadcrumbList', () => {
    expect(types('home')).toEqual(['EducationalOrganization', 'MobileApplication']);
    expect(types('download')).toEqual(['MobileApplication', 'BreadcrumbList']);
    expect(types('about')).toEqual(['EducationalOrganization', 'BreadcrumbList']);
    expect(types('privacy')).toEqual(['BreadcrumbList']);
  });

  it('SSS sayfası FAQPage içerir', () => {
    const blocks = routeJsonLd(routeById('faq'), 'en', ORIGIN) as Record<string, unknown>[];
    const faq = blocks.find((b) => b['@type'] === 'FAQPage') as { mainEntity: { name: string }[] };
    expect(faq.mainEntity.length).toBeGreaterThan(3);
    expect(faq.mainEntity[0].name).toBeTruthy();
  });

  it('breadcrumb adresleri dil önekli ve mutlak; çıktı JSON olarak çözülür', () => {
    const html = prerender({ template: TEMPLATE, origin: ORIGIN, buildDate: 'x' }).files.get('ar/privacy/index.html')!;
    const scripts = [...html.matchAll(/<script type="application\/ld\+json" data-pre="1">([\s\S]*?)<\/script>/g)].map(
      (m) => JSON.parse(m[1]) as { itemListElement: { item: string }[] },
    );
    expect(scripts.length).toBe(1);
    expect(scripts[0].itemListElement.map((i) => i.item)).toEqual([`${ORIGIN}/ar`, `${ORIGIN}/ar/privacy`]);
  });
});

describe('noscript', () => {
  it('her rota için başlık (h1) ve JavaScript uyarısı içerir', () => {
    for (const l of LANGS)
      for (const r of ROUTE_META) {
        const html = renderNoscript(r, l.code);
        expect(html, `${l.code} ${r.id}`).toContain('<h1>');
        expect(html, `${l.code} ${r.id}`).toContain('JavaScript');
      }
  });
});
