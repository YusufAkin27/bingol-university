import { expect, test } from '@playwright/test';

/** Standart site sayfalari (T23): gercek backend uzerinde; yigin ayakta olmadan calistirilmaz. */

const PAGES: [string, string][] = [
  ['/privacy', 'Gizlilik'],
  ['/terms', 'Kullanım'],
  ['/cookies', 'Çerez Politikası'],
  ['/delete-account', 'Hesap silme'],
  ['/accessibility', 'Erişilebilirlik beyanı'],
  ['/sitemap', 'Site haritası'],
  ['/security', 'Güvenlik'],
  ['/community-guidelines', 'Topluluk kuralları'],
  ['/help', 'Yardım merkezi'],
  ['/status', 'Güncel durum'],
  ['/news', 'Haberler ve duyurular'],
  ['/menu', 'Yemek listesi'],
  ['/brand', 'Basın ve marka kiti'],
  ['/changelog', 'Sürüm notları'],
];

test.describe('standart site sayfalari', () => {
  for (const [path, h1] of PAGES) {
    test(`${path} acilir, tek h1 ve konsol hatasi yok`, async ({ page }) => {
      const errors: string[] = [];
      page.on('pageerror', (e) => errors.push(e.message));
      await page.goto(path);
      await expect(page.getByRole('heading', { level: 1 })).toContainText(h1);
      await expect(page.getByRole('heading', { level: 1 })).toHaveCount(1);
      expect(errors).toEqual([]);
    });
  }

  test('cerez bandi bir kez gosterilir ve tercih kalir', async ({ page }) => {
    await page.goto('/about');
    const banner = page.getByRole('region', { name: 'Çerez bilgilendirmesi' });
    await expect(banner).toBeVisible();
    await banner.getByRole('button', { name: 'Anladım' }).click();
    await expect(banner).toBeHidden();
    await page.reload();
    await expect(banner).toBeHidden();
  });

  test('haber listesinden detaya gidilir ve kaynak atfi gorunur', async ({ page }) => {
    await page.goto('/news');
    const first = page.locator('main h2 a').first();
    if ((await first.count()) === 0) test.skip(true, 'veritabaninda haber yok');
    await first.click();
    await expect(page).toHaveURL(/\/news\/\d+$/);
    await expect(page.getByText('Kaynak: Bingöl Üniversitesi')).toBeVisible();
  });

  test('robots.txt yonetim yolunu aciklamaz, security.txt sunulur', async ({ request }) => {
    const robots = await (await request.get('/robots.txt')).text();
    expect(robots).not.toMatch(/admin/i);
    const sec = await request.get('/.well-known/security.txt');
    expect(sec.ok()).toBeTruthy();
    expect(await sec.text()).toContain('Contact:');
  });

  test('alt bilgide yonetim baglantisi yoktur', async ({ page }) => {
    await page.goto('/');
    const hrefs = await page.locator('a').evaluateAll((as) => as.map((a) => a.getAttribute('href') ?? ''));
    expect(hrefs.filter((h) => h.startsWith('/admin'))).toEqual([]);
  });
});
