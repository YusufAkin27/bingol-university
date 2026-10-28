import { expect, test, type Page } from '@playwright/test';

/**
 * Mobil öncelikli yerleşim denetimi (backend gerekmez; /api 500 dönse de sayfalar kendi durumunu çizer):
 * 360/768/1280 px x tr/en/ar x açık/koyu: yatay taşma yok, üst çubuk (hamburger dahil) ekran içinde,
 * çerez bandı kompakt ve ilk ekranın düğmelerini örtmüyor, Inter yüklenir, CLS < 0,1.
 */

type Lang = 'tr' | 'en' | 'ar';
const LANGS: Lang[] = ['tr', 'en', 'ar'];
const THEMES = ['light', 'dark'] as const;
const WIDTHS = [360, 768, 1280] as const;

const ALL_PAGES = [
  '/', '/about', '/features', '/download', '/faq', '/contact', '/data-request', '/legal', '/privacy', '/terms',
  '/cookies', '/delete-account', '/accessibility', '/sitemap', '/security', '/community-guidelines', '/help',
  '/news', '/menu', '/support/track', '/brand', '/changelog',
];
const CORE_PAGES = ['/', '/features', '/download', '/faq', '/contact', '/menu'];

async function prepare(page: Page, lang: Lang, theme: 'light' | 'dark', cookiesAcked: boolean) {
  await page.addInitScript(
    ([l, t, ack]) => {
      try {
        localStorage.setItem('bu.lang', l as string);
        localStorage.setItem('bu.theme', t as string);
        if (ack) localStorage.setItem('bu.cookies', 'ack:v1');
      } catch {
        /* yoksay */
      }
    },
    [lang, theme, cookiesAcked],
  );
}

/** Görünür alanın dışına taşan ilk birkaç öğeyi yazar (hata mesajı için). */
async function offenders(page: Page): Promise<string[]> {
  return page.evaluate(() => {
    const vw = document.documentElement.clientWidth;
    const out: string[] = [];
    for (const el of Array.from(document.body.querySelectorAll('*'))) {
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) continue;
      if (r.right > vw + 1 || r.left < -1) {
        // kendi kaydırma kabuğu içindeki öğeler sorun değildir
        let p: Element | null = el.parentElement;
        let scrolls = false;
        while (p && p !== document.body) {
          const o = getComputedStyle(p).overflowX;
          if (o === 'auto' || o === 'scroll' || o === 'hidden') {
            scrolls = true;
            break;
          }
          p = p.parentElement;
        }
        if (!scrolls) {
          out.push(
            `${el.tagName.toLowerCase()}.${String((el as HTMLElement).className).slice(0, 40)} [${Math.round(r.left)}..${Math.round(r.right)}] vw=${vw}`,
          );
        }
      }
      if (out.length >= 5) break;
    }
    return out;
  });
}

for (const width of WIDTHS) {
  for (const lang of LANGS) {
    for (const theme of THEMES) {
      test(`yatay taşma yok: ${width}px ${lang} ${theme}`, async ({ page }) => {
        test.setTimeout(300_000);
        await page.setViewportSize({ width, height: width === 360 ? 740 : 900 });
        await prepare(page, lang, theme, true);
        const pages = width === 360 ? ALL_PAGES : CORE_PAGES;
        const failures: string[] = [];
        for (const route of pages) {
          await page.goto(route, { waitUntil: 'domcontentloaded' });
          await page.waitForSelector('main h1, main h2, main p', { timeout: 15_000 }).catch(() => undefined);
          await page.waitForTimeout(250);
          const m = await page.evaluate(() => ({
            sw: document.documentElement.scrollWidth,
            cw: document.documentElement.clientWidth,
            bar: (() => {
              const b = document.querySelector('header > div');
              return b ? { sw: b.scrollWidth, cw: b.clientWidth } : null;
            })(),
          }));
          if (m.sw > m.cw) {
            failures.push(`${route}: scrollWidth ${m.sw} > clientWidth ${m.cw} :: ${(await offenders(page)).join(' | ')}`);
          }
          if (m.bar && m.bar.sw > m.bar.cw) failures.push(`${route}: üst çubuk taşıyor ${m.bar.sw} > ${m.bar.cw}`);
          // hamburger (görünürse) ekran içinde
          const burger = page.locator('header button[aria-controls="site-nav"]');
          if (await burger.isVisible()) {
            const box = (await burger.boundingBox())!;
            if (box.x < 0 || box.x + box.width > width) failures.push(`${route}: hamburger ekran dışında x=${box.x} w=${box.width}`);
          }
        }
        expect(failures, failures.join('\n')).toEqual([]);
      });
    }
  }
}

for (const lang of LANGS) {
  test(`çerez bandı kompakt ve hero düğmelerini örtmüyor: 360px ${lang}`, async ({ page }) => {
    await page.setViewportSize({ width: 360, height: 740 });
    await prepare(page, lang, 'light', false);
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    const banner = page.locator('section[aria-label][class*="banner"]').last();
    await banner.waitFor({ state: 'visible', timeout: 15_000 });
    await page.waitForTimeout(300);
    const box = (await banner.boundingBox())!;
    // ekranın en fazla ~%14'ü (kısa metin + 2 düğme), tam genişlik, altta
    expect(box.height, `bant yüksekliği ${box.height}`).toBeLessThanOrEqual(740 * 0.14);
    expect(box.x).toBeLessThanOrEqual(1);
    expect(box.width).toBeGreaterThanOrEqual(358);
    expect(Math.round(box.y + box.height)).toBeGreaterThanOrEqual(738);
    // ilk ekrandaki hero düğmeleri bandın üstünde kalır
    const buttons = page.locator('main a[class*="btn"]');
    const n = await buttons.count();
    expect(n).toBeGreaterThan(0);
    for (let i = 0; i < Math.min(n, 2); i++) {
      const b = (await buttons.nth(i).boundingBox())!;
      expect(b.y + b.height, `hero düğmesi #${i} bantla örtüşüyor`).toBeLessThanOrEqual(box.y);
    }
    const sw = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    expect(sw).toBeLessThanOrEqual(0);
  });
}

test('Inter 400-800 yüklenir ve CLS < 0,1', async ({ page }) => {
  await page.setViewportSize({ width: 360, height: 740 });
  await prepare(page, 'tr', 'light', true);
  await page.addInitScript(() => {
    (window as unknown as { __cls: number }).__cls = 0;
    new PerformanceObserver((list) => {
      for (const e of list.getEntries() as unknown as { value: number; hadRecentInput: boolean }[]) {
        if (!e.hadRecentInput) (window as unknown as { __cls: number }).__cls += e.value;
      }
    }).observe({ type: 'layout-shift', buffered: true });
  });
  await page.goto('/', { waitUntil: 'load' });
  await page.waitForTimeout(1500);
  const res = await page.evaluate(async () => {
    await document.fonts.ready;
    const ok = await Promise.all(
      [400, 500, 600, 700, 800].map((w) =>
        document.fonts.load(`${w} 16px Inter`, 'Bingöl ığşİ').then((r) => r.length > 0),
      ),
    );
    return {
      ok,
      cls: (window as unknown as { __cls: number }).__cls,
      family: getComputedStyle(document.body).fontFamily,
    };
  });
  expect(res.family).toContain('Inter');
  expect(res.ok.every(Boolean)).toBe(true);
  expect(res.cls).toBeLessThan(0.1);
});
