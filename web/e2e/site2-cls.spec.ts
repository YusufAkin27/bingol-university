/**
 * SITE2: bilgi sayfalarında (SSS, Yardım, İletişim, Menü, Haberler, Basın kiti, Sürüm notları, Site haritası, 404) düzen kayması (CLS) < 0,1 ve yatay taşma yok.
 * Telefon görselleri <img width height> ile yer ayırır; Reveal yalnız opacity/transform kullanır. Backendsiz çalışır
 * (API istekleri gecikmeli 404 ile taklit edilir: iletişim/mağaza bağlantıları gelmez, rozetler "Yakında" olur).
 *   cd web && npx playwright test site2-cls.spec.ts
 */
import { expect, test, type Page } from '@playwright/test';

async function measure(page: Page, route: string) {
  await page.addInitScript(() => {
    localStorage.setItem('bu.cookies', 'ack:v1');
    (window as unknown as { __cls: number }).__cls = 0;
    new PerformanceObserver((list) => {
      for (const e of list.getEntries() as unknown as { value: number; hadRecentInput: boolean }[]) {
        if (!e.hadRecentInput) (window as unknown as { __cls: number }).__cls += e.value;
      }
    }).observe({ type: 'layout-shift', buffered: true });
  });
  await page.route((u) => u.pathname.startsWith('/api/'), async (r) => {
    await new Promise((res) => setTimeout(res, 500));
    return r.fulfill({ status: 404, contentType: 'application/json', body: '{"code":"NOT_FOUND","message":"yok"}' });
  });
  await page.goto(route);
  await page.waitForSelector('h1');
  await page.waitForLoadState('networkidle');
  // aşağı kaydır: tembel görseller ve Reveal öğeleri yüklenir/belirir
  const h = await page.evaluate(() => document.documentElement.scrollHeight);
  for (let y = 0; y < h; y += 400) {
    await page.evaluate((v) => window.scrollTo(0, v), y);
    await page.waitForTimeout(120);
  }
  await page.waitForTimeout(700);
  return page.evaluate(() => ({
    cls: (window as unknown as { __cls: number }).__cls,
    sw: document.documentElement.scrollWidth,
    cw: document.documentElement.clientWidth,
  }));
}

for (const width of [390, 1280]) {
  test.describe(`Bilgi sayfaları CLS ve taşma (${width} px)`, () => {
    test.use({ viewport: { width, height: 844 } });
    for (const lang of ['tr', 'en', 'ar']) {
      for (const path of ['/faq', '/help', '/contact', '/menu', '/news', '/changelog', '/sitemap', '/zzz-yok']) {
        const route = `/${lang}${path}`;
        test(`${route} CLS < 0.1, yatay kaydırma yok`, async ({ page }) => {
          const m = await measure(page, route);
          expect(m.cls, `CLS ${m.cls.toFixed(3)}`).toBeLessThan(0.1);
          expect(m.sw, `scrollWidth ${m.sw} > clientWidth ${m.cw}`).toBeLessThanOrEqual(m.cw);
        });
      }
    }
  });
}
