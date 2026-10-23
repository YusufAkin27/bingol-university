import { expect, test, type Page } from '@playwright/test';
import { setLang } from './helpers';

/** Herkese acik tanitim sitesi: gercek backend (VITE_DEV_BACKEND) uzerinde calisir. */

const PAGES = [
  '/',
  '/features',
  '/about',
  '/download',
  '/faq',
  '/contact',
  '/legal',
  '/legal/terms',
  '/legal/privacy',
  '/legal/kvkk',
  '/legal/community-rules',
  '/data-request',
];

function trackConsole(page: Page): string[] {
  const errors: string[] = [];
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(`console: ${m.text()}`);
  });
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
  return errors;
}

async function settle(page: Page) {
  await page.waitForLoadState('networkidle');
  // Yukleniyor iskeletleri bitsin
  await expect(page.locator('[role="status"][aria-label]')).toHaveCount(0, { timeout: 10_000 });
}

test.describe('tanitim sitesi', () => {
  test('SSS gercek backendden gelir, aranir ve akordeon acilir', async ({ page, request }) => {
    const api = await request.get('/api/faq');
    expect(api.ok()).toBeTruthy();
    const groups = (await api.json()) as { category: string; items: { question: string }[] }[];
    const first = groups[0].items[0].question;

    await page.goto('/faq');
    const btn = page.getByRole('button', { name: first });
    await expect(btn).toBeVisible();
    await btn.focus();
    await page.keyboard.press('Enter');
    await expect(btn).toHaveAttribute('aria-expanded', 'true');

    await page.getByRole('searchbox').fill('zzzzqqqq');
    await expect(page.getByText('Aramanızla eşleşen soru yok')).toBeVisible();
    await page.getByRole('searchbox').fill('');
    await expect(page.getByRole('button', { name: first })).toBeVisible();
  });

  test('yasal metinler gercek backendden gelir; icindekiler ve surum bilgisi gorunur', async ({ page, request }) => {
    const list = (await (await request.get('/api/legal')).json()) as { type: string; title: string }[];
    expect(list.length).toBeGreaterThanOrEqual(4);
    await page.goto('/legal');
    await expect(page.getByRole('heading', { level: 1, name: 'Yasal belgeler' })).toBeVisible();
    await expect(page.getByRole('link', { name: new RegExp(list[0].title) })).toBeVisible();

    await page.goto('/legal/privacy');
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Gizlilik');
    await expect(page.getByText(/Sürüm \d+/).first()).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'İçindekiler' })).toBeVisible();
    await expect(page.getByText('Bu metin taslaktır')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Yazdır' })).toBeVisible();

    await page.goto('/legal/yok-boyle-bir-sey');
    await expect(page.getByText('Sayfa bulunamadı')).toBeVisible();
  });

  for (const lang of ['tr', 'en', 'ar'] as const) {
    test(`ana sayfa ve yasal sayfa ${lang} dilinde acilir`, async ({ page }) => {
      const errors = trackConsole(page);
      await setLang(page, lang);
      await page.goto('/');
      await expect(page.locator('html')).toHaveAttribute('lang', lang);
      await expect(page.locator('html')).toHaveAttribute('dir', lang === 'ar' ? 'rtl' : 'ltr');
      const h1 = page.getByRole('heading', { level: 1 });
      await expect(h1).toBeVisible();
      const expected = { tr: 'Kampüs hayatı', en: 'Campus life', ar: 'حياة الحرم' }[lang];
      await expect(h1).toContainText(expected);
      await expect(page).toHaveTitle(/Bingöl|بينغول/);
      // Rota degisiminde odak sayfa basligina tasinir
      await page.locator('header nav a[href="/features"]').click();
      await expect(page).toHaveURL(/\/features$/);
      await expect(page.getByRole('heading', { level: 1 })).toBeFocused();

      await page.goto('/legal/kvkk');
      await settle(page);
      await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
      await expect(page.locator('article')).toContainText(/\S{3}/);
      expect(errors).toEqual([]);
    });
  }

  test('meta etiketleri, canonical ve JSON-LD yazilir', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('meta[name="description"]')).toHaveAttribute('content', /Bingöl/);
    await expect(page.locator('meta[property="og:title"]')).toHaveCount(1);
    await expect(page.locator('link[rel="canonical"]')).toHaveAttribute('href', /\/$/);
    const ld = await page.locator('script[type="application/ld+json"]').allTextContents();
    expect(ld.join('')).toContain('MobileApplication');
    expect(ld.join('')).toContain('EducationalOrganization');
  });

  test('atlama baglantisi klavye ile icerige gider', async ({ page }) => {
    await page.goto('/about');
    const skip = page.getByRole('link', { name: 'İçeriğe geç' });
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await page.keyboard.press('Tab');
    await expect(skip).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/#main$/);
  });

  test('robots.txt ve sitemap.xml sunulur; /admin engelli', async ({ request }) => {
    const robots = await (await request.get('/robots.txt')).text();
    expect(robots).toContain('Disallow: /admin');
    const sm = await request.get('/sitemap.xml');
    expect(sm.ok()).toBeTruthy();
    expect(await sm.text()).toContain('<urlset');
  });

  test.describe('mobil 390x844', () => {
    test.use({ viewport: { width: 390, height: 844 } });
    for (const lang of ['tr', 'ar'] as const) {
      test(`yatay tasma yok (${lang}) ve konsol hatasi yok`, async ({ page }) => {
        const errors = trackConsole(page);
        await setLang(page, lang);
        for (const path of PAGES) {
          await page.goto(path);
          await settle(page);
          const over = await page.evaluate(() => ({
            sw: document.documentElement.scrollWidth,
            cw: document.documentElement.clientWidth,
          }));
          expect(over.sw, `${path} (${lang}) scrollWidth ${over.sw} > ${over.cw}`).toBeLessThanOrEqual(over.cw);
        }
        expect(errors).toEqual([]);
      });
    }
  });
});

/** Gorsel dogrulama: e2e/.results/shots altina tam sayfa goruntuleri (commit'lenmez). */
test.describe('ekran goruntuleri', () => {
  test.skip(process.env.E2E_SHOTS === '0', 'E2E_SHOTS=0');
  test.setTimeout(240_000);
  const shotPages: [string, string][] = [
    ['home', '/'],
    ['features', '/features'],
    ['about', '/about'],
    ['download', '/download'],
    ['faq', '/faq'],
    ['contact', '/contact'],
    ['legal-list', '/legal'],
    ['legal-privacy', '/legal/privacy'],
    ['data-request', '/data-request'],
  ];
  for (const lang of ['tr', 'ar'] as const) {
    for (const theme of ['light', 'dark'] as const) {
      for (const [vp, size] of [
        ['desktop', { width: 1440, height: 900 }],
        ['mobile', { width: 390, height: 844 }],
      ] as const) {
        test(`${lang}-${theme}-${vp}`, async ({ page }) => {
          await page.setViewportSize(size);
          await setLang(page, lang);
          await page.addInitScript((th) => localStorage.setItem('bu.theme', th), theme);
          for (const [name, path] of shotPages) {
            await page.goto(path);
            await settle(page);
            if (name === 'faq') {
              const first = page.locator("#main button[aria-expanded]").first();
              if (await first.count()) await first.click();
            }
            await page.screenshot({
              path: `e2e/.results/shots/${name}-${lang}-${theme}-${vp}.png`,
              fullPage: true,
            });
          }
        });
      }
    }
  }
});
