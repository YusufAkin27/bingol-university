/**
 * W2-K / T-158: SSS ve Hukuki metinler sayfalarında düzen kayması (CLS) < 0,1 (390 px; backendsiz, API gecikmeli taklit).
 *   cd web && npx playwright test w2k-cls.spec.ts
 */
import { expect, test, type Page } from '@playwright/test';

const json = (body: unknown) => ({ status: 200, contentType: 'application/json', body: JSON.stringify(body) });

const FAQ = Array.from({ length: 4 }, (_, g) => ({
  category: `Kategori ${g + 1}`,
  items: Array.from({ length: 5 }, (_, i) => ({ id: g * 10 + i, question: `Soru ${g + 1}.${i + 1} nasıl çalışır?`, answer: 'Cevap metni. '.repeat(6) })),
}));
const LEGAL = ['TERMS', 'PRIVACY', 'KVKK', 'COMMUNITY_RULES', 'EXPLICIT_CONSENT', 'CONTENT_REMOVAL', 'RETENTION'].map((type, i) => ({
  type, title: `Belge ${i + 1} başlığı`, version: 2, publishedAt: '2026-10-01T10:00:00Z',
}));

async function measureCls(page: Page, route: string): Promise<number> {
  await page.addInitScript(() => {
    localStorage.setItem('bu.lang', 'tr');
    localStorage.setItem('bu.cookies', 'ack:v1');
    (window as unknown as { __cls: number }).__cls = 0;
    new PerformanceObserver((list) => {
      for (const e of list.getEntries() as unknown as { value: number; hadRecentInput: boolean }[]) {
        if (!e.hadRecentInput) (window as unknown as { __cls: number }).__cls += e.value;
      }
    }).observe({ type: 'layout-shift', buffered: true });
  });
  // gerçek ağ gecikmesini taklit et: iskelet bir süre görünür, sonra veri gelir
  await page.route((u) => u.pathname.startsWith('/api/'), async (r) => {
    const p = new URL(r.request().url()).pathname;
    await new Promise((res) => setTimeout(res, 600));
    if (p === '/api/faq') return r.fulfill(json(FAQ));
    if (p === '/api/legal') return r.fulfill(json(LEGAL));
    return r.fulfill({ status: 404, contentType: 'application/json', body: '{"code":"NOT_FOUND","message":"yok"}' });
  });
  await page.goto(route);
  await page.waitForSelector('h1');
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(900);
  return page.evaluate(() => (window as unknown as { __cls: number }).__cls);
}

test.describe('Site CLS (T-158)', () => {
  test.use({ viewport: { width: 390, height: 844 } });
  for (const route of ['/tr/faq', '/tr/legal', '/en/faq']) {
    test(`${route} CLS < 0.1`, async ({ page }) => {
      const cls = await measureCls(page, route);
      expect(cls, `CLS ${cls.toFixed(3)}`).toBeLessThan(0.1);
    });
  }
});
