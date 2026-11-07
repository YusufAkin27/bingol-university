/**
 * Sayfa başına SEO üstverisi sözleşmesi: başlık/açıklama uzunluğu ve benzersizliği, marka kalıbı, hreflang karşılıklılığı,
 * noindex kararları ve JSON-LD yapısı. Kaynak: seo/routeMeta.ts + i18n/<dil>/seo.ts (tek kaynak).
 */
import { describe, expect, it } from 'vitest';
import { LANGS, type Lang } from '../i18n/lang';
import { metaDescription } from '../pages/site/components/newsUtils';
import {
  breadcrumbLd,
  faqLd,
  plainAnswer,
  mobileAppLd,
  newsArticleLd,
  organizationLd,
  websiteLd,
} from '../pages/site/components/jsonLd';
import { buildNewFaq } from '../pages/site/components/newFaq';
import { dictionaries } from '../i18n/all';
import { buildHeadModel, pageUrl } from './headModel';
import { SEO_END, SEO_START, buildSitemap, prerender, routeJsonLd } from './prerender';
import { ROUTE_META, localizedLangs, resolveMeta, routeById } from './routeMeta';

const ORIGIN = 'https://bukampus.com.tr';
const BRAND = 'BÜ Kampüs';
const TEMPLATE = `<!doctype html><html lang="tr" dir="ltr"><head>${SEO_START}<title>x</title>${SEO_END}</head><body><div id="root"></div></body></html>`;
const codes = LANGS.map((l) => l.code);

describe('başlık ve açıklama uzunluğu (her rota × dil)', () => {
  it('<title> en çok 60 karakter ve marka kalıbı "Başlık | BÜ Kampüs" (ana sayfada marka başta)', () => {
    for (const l of codes)
      for (const r of ROUTE_META) {
        const m = resolveMeta(r, l);
        expect(m.fullTitle.length, `${l} ${r.id} ${m.fullTitle}`).toBeLessThanOrEqual(60);
        expect(m.seoTitle.length, `${l} ${r.id} seo başlığı`).toBeGreaterThanOrEqual(8);
        if (r.home) expect(m.fullTitle.startsWith(`${BRAND} | `), `${l} ${r.id}`).toBe(true);
        else expect(m.fullTitle.endsWith(` | ${BRAND}`), `${l} ${r.id} ${m.fullTitle}`).toBe(true);
      }
  });

  it('description 120-158 karakter, anahtar sızıntısı yok', () => {
    for (const l of codes)
      for (const r of ROUTE_META) {
        const d = resolveMeta(r, l).description;
        expect(d.length, `${l} ${r.id} (${d.length}) ${d}`).toBeGreaterThanOrEqual(120);
        expect(d.length, `${l} ${r.id} (${d.length}) ${d}`).toBeLessThanOrEqual(158);
        expect(d).not.toMatch(/^(site|pg|legal|seo)\./);
      }
  });

  it('başlıklar ve açıklamalar dil içinde benzersiz; her SEO anahtarı üç dilde dolu', () => {
    for (const l of codes) {
      const dict = dictionaries[l] as Record<string, string>;
      for (const r of ROUTE_META) {
        expect(dict[r.seoTitleKey], `${l} ${r.seoTitleKey}`).toBeTruthy();
        expect(dict[r.seoDescKey], `${l} ${r.seoDescKey}`).toBeTruthy();
      }
      const titles = ROUTE_META.map((r) => resolveMeta(r, l).fullTitle);
      const descs = ROUTE_META.map((r) => resolveMeta(r, l).description);
      expect(new Set(titles).size, `${l} başlık`).toBe(titles.length);
      expect(new Set(descs).size, `${l} açıklama`).toBe(descs.length);
    }
  });

  it('"Bingöl Üniversitesi" geçen ana sayfa/hakkında/indir/haber/yemek açıklamaları bağımsız-resmî değil ibaresi taşır', () => {
    const flag: Record<Lang, RegExp> = { tr: /bağımsız|resmî/i, en: /independent|unofficial|official/i, ar: /مستقل|غير رسمي|الرسمي/ };
    for (const l of codes)
      for (const id of ['home', 'about', 'download', 'news', 'menu']) {
        const m = resolveMeta(routeById(id), l);
        expect(m.description, `${l} ${id}`).toMatch(flag[l]);
        // resmî uygulama iddiası yok
        expect(m.description + m.fullTitle, `${l} ${id}`).not.toMatch(/resmî uygulama|(?<!un)official app|T\.C\./i);
      }
  });
});

describe('canonical ve hreflang', () => {
  const head = (id: string, lang: Lang) => {
    const r = routeById(id);
    const m = resolveMeta(r, lang);
    return buildHeadModel({
      lang,
      origin: ORIGIN,
      path: r.path,
      title: m.fullTitle,
      description: m.description,
      appName: BRAND,
      langs: localizedLangs(r),
    });
  };

  it('tam yerelleştirilmiş sayfalarda üç dil + x-default karşılıklı; her dil kendini canonical gösterir', () => {
    for (const r of ROUTE_META.filter((x) => localizedLangs(x).length === codes.length)) {
      const sets = codes.map((l) => {
        const h = head(r.id, l);
        expect(h.canonical, `${l} ${r.id}`).toBe(pageUrl(ORIGIN, l, r.path));
        expect(h.canonical.startsWith('https://bukampus.com.tr/')).toBe(true);
        expect(h.canonical.endsWith('/') && h.canonical !== `${ORIGIN}/`).toBe(false);
        return h.links.filter((x) => x.rel === 'alternate').map((x) => `${x.hreflang}=${x.href}`);
      });
      // üç dilin alternatif kümesi aynı (karşılıklılık) ve kendi adresini içerir
      expect(new Set(sets.map((s) => s.join('|'))).size, r.id).toBe(1);
      expect(sets[0]).toEqual(
        expect.arrayContaining([
          `tr=${pageUrl(ORIGIN, 'tr', r.path)}`,
          `en=${pageUrl(ORIGIN, 'en', r.path)}`,
          `ar=${pageUrl(ORIGIN, 'ar', r.path)}`,
          `x-default=${pageUrl(ORIGIN, 'tr', r.path)}`,
        ]),
      );
    }
  });

  it('yerelleştirilmemiş dil (haber: yalnız tr; açık rıza: tr+en): canonical Türkçe, hreflang kümesinde yok', () => {
    expect(localizedLangs(routeById('news'))).toEqual(['tr']);
    expect(localizedLangs(routeById('legalExplicitConsent'))).toEqual(['tr', 'en']);
    for (const l of ['en', 'ar'] as const) {
      const h = head('news', l);
      expect(h.canonical).toBe(pageUrl(ORIGIN, 'tr', '/news'));
      expect(h.links.filter((x) => x.rel === 'alternate')).toEqual([]);
    }
    const trNews = head('news', 'tr').links.filter((x) => x.rel === 'alternate');
    expect(trNews.map((x) => x.hreflang)).toEqual(['tr', 'x-default']);
    const ar = head('legalExplicitConsent', 'ar');
    expect(ar.canonical).toBe(pageUrl(ORIGIN, 'tr', routeById('legalExplicitConsent').path));
    expect(head('legalExplicitConsent', 'en').links.filter((x) => x.rel === 'alternate').map((x) => x.hreflang)).toEqual([
      'tr',
      'en',
      'x-default',
    ]);
  });

  it('sitemap yalnız yerelleştirilmiş dil URL’lerini listeler ve kendi içinde karşılıklıdır', () => {
    const xml = buildSitemap(ORIGIN, '2026-11-01');
    const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
    expect(locs).not.toContain(`${ORIGIN}/en/news`);
    expect(locs).not.toContain(`${ORIGIN}/ar/news`);
    expect(locs).toContain(`${ORIGIN}/tr/news`);
    expect(locs).not.toContain(`${ORIGIN}/ar/legal/EXPLICIT_CONSENT`);
    expect(locs.length).toBe(ROUTE_META.reduce((n, r) => n + localizedLangs(r).length, 0));
    expect(xml).not.toMatch(/\/news\/\d/); // haber ayrıntıları sitemap'te yok
  });

  it('og:locale ve görsel etiketleri', () => {
    const h = head('home', 'ar');
    const get = (k: string) => h.metas.filter((x) => x.key === k).map((x) => x.content);
    expect(get('og:locale')).toEqual(['ar_AR']);
    expect(get('og:image:width')).toEqual(['1200']);
    expect(get('og:image:height')).toEqual(['630']);
    expect(get('og:image')).toEqual([`${ORIGIN}/og.png`]);
    expect(get('twitter:card')).toEqual(['summary_large_image']);
    expect(get('og:type')).toEqual(['website']);
  });
});

describe('robots / noindex kararları', () => {
  const base = { lang: 'tr' as const, origin: ORIGIN, path: '/x', title: 't', appName: BRAND };

  it('noindex: robots "noindex, nofollow", hreflang yok; robots değeri verilirse o kullanılır', () => {
    const a = buildHeadModel({ ...base, noindex: true });
    expect(a.metas.find((m) => m.key === 'robots')?.content).toBe('noindex, nofollow');
    expect(a.links.filter((l) => l.rel === 'alternate')).toEqual([]);
    const b = buildHeadModel({ ...base, robots: 'noindex, follow' });
    expect(b.metas.find((m) => m.key === 'robots')?.content).toBe('noindex, follow');
    expect(b.links.filter((l) => l.rel === 'alternate')).toEqual([]);
  });

  it('dizine girecek sayfada robots etiketi yok', () => {
    expect(buildHeadModel(base).metas.some((m) => m.key === 'robots')).toBe(false);
  });

  it('yönetim, giriş, token’lı takip ve hata sayfaları rota tablosunda (sitemap/önrender) yok', () => {
    const paths = ROUTE_META.map((r) => r.path);
    for (const p of paths) {
      expect(p).not.toMatch(/^\/admin/);
      expect(p).not.toMatch(/support\/track|login/);
    }
    expect(paths.some((p) => p.startsWith('/news/'))).toBe(false);
  });

  it('haber ayrıntısı: article, yayın tarihi ve sayfaya özgü görsel (boyut etiketi yok)', () => {
    const h = buildHeadModel({
      ...base,
      robots: 'noindex, follow',
      ogType: 'article',
      publishedTime: '2026-10-30',
      image: { url: 'https://www.bingol.edu.tr/a.jpg', alt: 'Başlık' },
    });
    const get = (k: string) => h.metas.filter((x) => x.key === k).map((x) => x.content);
    expect(get('og:type')).toEqual(['article']);
    expect(get('article:published_time')).toEqual(['2026-10-30']);
    expect(get('og:image')).toEqual(['https://www.bingol.edu.tr/a.jpg']);
    expect(get('og:image:alt')).toEqual(['Başlık']);
    expect(get('og:image:width')).toEqual([]);
  });
});

/** JSON-LD'yi önrender HTML'inden çıkarır; her blok JSON.parse ile çözülür. */
function ldBlocks(html: string): Record<string, unknown>[] {
  return [...html.matchAll(/<script type="application\/ld\+json" data-pre="1">([\s\S]*?)<\/script>/g)].map(
    (m) => JSON.parse(m[1]) as Record<string, unknown>,
  );
}

describe('JSON-LD (önrender çıktısı)', () => {
  const out = prerender({ template: TEMPLATE, origin: ORIGIN, buildDate: '2026-11-01' });

  it('her sayfadaki her blok geçerli JSON ve @context/@type taşır', () => {
    for (const [file, html] of out.files) {
      if (!file.endsWith('.html')) continue;
      for (const b of ldBlocks(html)) {
        expect(b['@context'], file).toBe('https://schema.org');
        expect(typeof b['@type'], file).toBe('string');
      }
    }
  });

  it('hiçbir blokta EducationalOrganization yok; yayıncı/yazar BÜ Kampüs (üniversite değil)', () => {
    for (const [file, html] of out.files) {
      if (!file.endsWith('.html')) continue;
      const raw = ldBlocks(html).map((b) => JSON.stringify(b)).join('\n');
      expect(raw, file).not.toContain('EducationalOrganization');
      expect(raw, file).not.toMatch(/"(publisher|author)":\{[^}]*Bingöl Üniversitesi/);
    }
    const app = ldBlocks(out.files.get('tr/index.html')!).find((b) => b['@type'] === 'MobileApplication')!;
    expect((app.publisher as { name: string }).name).toBe(BRAND);
    expect((app.author as { name: string }).name).toBe(BRAND);
  });

  it('ana sayfa: Organization + WebSite (SearchAction yok) + MobileApplication', () => {
    for (const l of codes) {
      const blocks = ldBlocks(out.files.get(`${l}/index.html`)!);
      expect(blocks.map((b) => b['@type'])).toEqual(['Organization', 'WebSite', 'MobileApplication']);
      const [org, site, app] = blocks as Record<string, unknown>[];
      expect(org.name).toBe(BRAND);
      expect(org.url).toBe(ORIGIN);
      expect(org.logo).toBe(`${ORIGIN}/icon-512.png`);
      expect(org).not.toHaveProperty('sameAs'); // gerçek hesap yokken uydurulmaz
      expect(site.url).toBe(pageUrl(ORIGIN, l, '/'));
      expect(site.inLanguage).toBe(l);
      expect(JSON.stringify(site)).not.toContain('SearchAction');
      expect(app.applicationCategory).toBe('EducationalApplication');
      expect(app.operatingSystem).toBe('Android, iOS');
      expect(app.offers).toEqual({ '@type': 'Offer', price: '0', priceCurrency: 'TRY' });
      expect(app).not.toHaveProperty('installUrl'); // yayınlanmamış mağaza adresi uydurulmaz
      expect(app).not.toHaveProperty('aggregateRating');
    }
  });

  it('mağaza bağlantısı yalnız verilince installUrl olur', () => {
    const none = mobileAppLd(undefined, { android: null, ios: null }, ORIGIN);
    expect(none).not.toHaveProperty('installUrl');
    const some = mobileAppLd(undefined, { android: 'https://play.google.com/store/apps/details?id=x', ios: null }, ORIGIN);
    expect(some.installUrl).toBe('https://play.google.com/store/apps/details?id=x');
  });

  it('iç sayfalarda BreadcrumbList: ilk öğe ana sayfa, son öğe kendisi, sıra 1..n, mutlak adresler', () => {
    for (const l of codes)
      for (const r of ROUTE_META.filter((x) => !x.home)) {
        const bc = ldBlocks(out.files.get(`${l}${r.path}/index.html`)!).find((b) => b['@type'] === 'BreadcrumbList') as {
          itemListElement: { position: number; item: string; name: string }[];
        };
        expect(bc, `${l} ${r.id}`).toBeTruthy();
        expect(bc.itemListElement.map((i) => i.position)).toEqual([1, 2]);
        expect(bc.itemListElement[0].item).toBe(pageUrl(ORIGIN, l, '/'));
        expect(bc.itemListElement[1].item).toBe(pageUrl(ORIGIN, l, r.path));
        expect(bc.itemListElement.every((i) => i.name.trim() !== '')).toBe(true);
      }
  });

  it('SSS: FAQPage soru/yanıtları sayfada görünen statik bölümle birebir (3 dil)', () => {
    for (const l of codes) {
      const dict = dictionaries[l] as Record<string, string>;
      const faq = ldBlocks(out.files.get(`${l}/faq/index.html`)!).find((b) => b['@type'] === 'FAQPage') as {
        mainEntity: { '@type': string; name: string; acceptedAnswer: { '@type': string; text: string } }[];
      };
      const visible = buildNewFaq((k) => dict[k]);
      expect(faq.mainEntity.length).toBe(visible.length);
      faq.mainEntity.forEach((q, i) => {
        expect(q['@type']).toBe('Question');
        expect(q.name).toBe(visible[i].question);
        expect(q.acceptedAnswer['@type']).toBe('Answer');
        // görünür metin: bağlantılar yalnız bağlantı metni olarak okunur
        expect(q.acceptedAnswer.text).toBe(plainAnswer(visible[i].answer));
        expect(q.acceptedAnswer.text).not.toMatch(/\]\(/);
        expect(q.name.trim()).not.toBe('');
      });
    }
    // çalışma zamanı üreticisi de aynı çıktıyı verir
    expect(faqLd([{ question: 'q', answer: 'a' }])).toMatchObject({ '@type': 'FAQPage' });
  });

  it('yemek listesi ve diğer rotalarda gereksiz şema yok', () => {
    const types = (id: string) => routeJsonLd(routeById(id), 'tr', ORIGIN).map((b) => (b as { '@type': string })['@type']);
    expect(types('menu')).toEqual(['BreadcrumbList']);
    expect(types('download')).toEqual(['MobileApplication', 'BreadcrumbList']);
    expect(types('contact')).toEqual(['Organization', 'BreadcrumbList']);
  });
});

describe('JSON-LD üreticileri', () => {
  it('organizationLd: boş alanlar atlanır, sameAs yalnız verilen hesaplar', () => {
    const o = organizationLd(
      {
        appName: 'BÜ Kampüs',
        social: { instagram: 'https://instagram.com/bukampus', twitter: null, youtube: null },
        contactEmail: 'a@b.c',
      } as never,
      ORIGIN,
    );
    expect(o['@type']).toBe('Organization');
    expect(o.sameAs).toEqual(['https://instagram.com/bukampus']);
    expect(o).not.toHaveProperty('telephone');
    expect(JSON.parse(JSON.stringify(o))).toEqual(o);
  });

  it('websiteLd arama eylemi içermez', () => {
    expect(JSON.stringify(websiteLd(ORIGIN, 'tr', `${ORIGIN}/tr`))).not.toMatch(/SearchAction|potentialAction/);
  });

  it('newsArticleLd: zorunlu alanlar, 110 karakter başlık sınırı, kaynak isBasedOn, yayıncı BÜ Kampüs', () => {
    const long = 'Çok uzun bir haber başlığı '.repeat(10);
    const a = newsArticleLd(
      {
        url: `${ORIGIN}/tr/news/7`,
        headline: long,
        description: 'özet',
        datePublished: '2026-10-30',
        image: 'https://www.bingol.edu.tr/x.jpg',
        lang: 'tr',
        sourceUrl: 'https://www.bingol.edu.tr/haber/7',
      },
      ORIGIN,
    ) as Record<string, unknown>;
    expect(a['@type']).toBe('NewsArticle');
    expect((a.headline as string).length).toBeLessThanOrEqual(110);
    expect(a.datePublished).toBe('2026-10-30');
    expect(a.image).toEqual(['https://www.bingol.edu.tr/x.jpg']);
    expect(a.isBasedOn).toBe('https://www.bingol.edu.tr/haber/7');
    expect((a.publisher as { name: string; logo: { url: string } }).name).toBe(BRAND);
    expect((a.publisher as { logo: { url: string } }).logo.url).toBe(`${ORIGIN}/icon-512.png`);
    expect((a.mainEntityOfPage as { '@id': string })['@id']).toBe(`${ORIGIN}/tr/news/7`);
    const bare = newsArticleLd({ url: 'u', headline: 'h', lang: 'tr' }, ORIGIN);
    expect(bare).not.toHaveProperty('image');
    expect(bare).not.toHaveProperty('datePublished');
    expect(breadcrumbLd([{ name: 'a', url: 'b' }])['@type']).toBe('BreadcrumbList');
  });

  it('metaDescription: sözcük sınırında keser, kısa metinde yedeği kullanır', () => {
    const fb = 'yedek açıklama';
    expect(metaDescription('  ', fb)).toBe(fb);
    expect(metaDescription('kısa', fb)).toBe(fb);
    const text = 'Bingöl Üniversitesi öğrencileri için yeni dönem kayıt yenileme işlemleri başladı. '.repeat(6);
    const d = metaDescription(text, fb);
    expect(d.length).toBeLessThanOrEqual(155);
    expect(d.endsWith('…')).toBe(true);
    expect(d).not.toMatch(/\s{2}/);
  });
});
