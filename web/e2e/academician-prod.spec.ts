/**
 * Uretim derlemesi denetimi (tercihen `E2E_BASE_URL` ile `vite preview` / nginx'e karsi calistirilir; gelistirme sunucusunda
 * yalniz derleme-bagimsiz kisimlar anlamlidir). BACKEND'SIZ.
 *   npm run build && npx vite preview --port 4180   # baska terminalde
 *   E2E_BASE_URL=http://localhost:4180 npx playwright test academician-prod.spec.ts
 */
import { expect, test, type Page } from '@playwright/test';
import { guardConsole, installAcademicianFake, newState, seedAcadSession } from './academician-fake';
import { boot, fresh } from './admin-academicians-fake';

const isDevServer = (page: Page) => page.evaluate(() => !!document.querySelector('script[src*="/@vite/client"]') || !!document.querySelector('script[type=module][src*="/src/"]'));

function watchAssets(page: Page) {
  const bad: string[] = [];
  const scripts: string[] = [];
  page.on('response', (r) => {
    const u = new URL(r.url());
    if (u.pathname.startsWith('/api/')) return;
    if (r.status() >= 400) bad.push(`${r.status()} ${u.pathname}`);
    if (u.pathname.endsWith('.js')) scripts.push(u.pathname);
  });
  return { bad, scripts };
}

test('giris sayfasi, panel ve yonetim sayfasi: tembel parcalar yuklenir, varlik 404 yok, derin baglanti yenilemesi calisir', async ({ page }) => {
  const st = newState();
  const g = guardConsole(page, st);
  const w = watchAssets(page);
  await seedAcadSession(page);
  await installAcademicianFake(page, st);
  await page.goto('/akademisyen/giris');
  // oturum var ve onayli: giris sayfasi panele yollar ya da giris formunu gosterir; ikisi de hatasiz yuklenmeli
  await expect(page.getByRole('heading', { name: /Akademisyen girişi|Merhaba/ })).toBeVisible();
  await page.goto('/akademisyen');
  await expect(page.getByRole('heading', { name: /Merhaba/ })).toBeVisible();
  await page.reload(); // derin baglanti yenileme
  await expect(page.getByRole('heading', { name: /Merhaba/ })).toBeVisible();
  await page.goto('/akademisyen/yoklama/5');
  await expect(page.locator('svg[data-qr]')).toBeVisible();
  await page.reload();
  await expect(page.locator('svg[data-qr]')).toBeVisible();
  expect(w.bad, 'varlik hatalari').toEqual([]);
  if (!(await isDevServer(page))) {
    // yalniz canli sayfa parcasi QR kutuphanesini ceker: ilk girisin JS'i `qrcode` icermez (ayri tembel parca)
    expect(w.scripts.some((s) => /LivePage/.test(s))).toBe(true);
  }
  g.assertClean();
});

test('yonetim: /admin/academicians derin baglanti yenilemesi ve tembel parca', async ({ page }) => {
  const st = fresh();
  const w = watchAssets(page);
  const problems = await boot(page, st);
  await page.goto('/admin/academicians');
  await expect(page.getByRole('heading', { level: 1, name: 'Akademisyenler' })).toBeVisible();
  await page.reload();
  await expect(page.getByRole('heading', { level: 1, name: 'Akademisyenler' })).toBeVisible();
  expect(w.bad).toEqual([]);
  expect(problems).toEqual([]);
});

test('uretim derlemesinde "Kodu kopyala (gelistirme)" dugmesi YOK; gelistirmede var', async ({ page }) => {
  const st = newState();
  await seedAcadSession(page);
  await installAcademicianFake(page, st);
  await page.goto('/akademisyen/yoklama/5');
  await expect(page.locator('svg[data-qr]')).toBeVisible();
  const dev = await isDevServer(page);
  await expect(page.getByRole('button', { name: /Kodu kopyala/ })).toHaveCount(dev ? 1 : 0);
});

test('uretimde kaynak haritasi (.map) yok ve JS govdesi sourceMappingURL icermez', async ({ page, request }) => {
  const st = newState();
  await seedAcadSession(page);
  await installAcademicianFake(page, st);
  const w = watchAssets(page);
  await page.goto('/akademisyen/yoklama/5');
  await expect(page.locator('svg[data-qr]')).toBeVisible();
  test.skip(await isDevServer(page), 'gelistirme sunucusu: kaynak haritasi beklenir');
  const own = w.scripts.filter((s) => s.startsWith('/assets/'));
  expect(own.length).toBeGreaterThan(0);
  for (const s of own) {
    const body = await (await request.get(s)).text();
    expect(body, s).not.toMatch(/sourceMappingURL=/);
    const map = await request.get(`${s}.map`);
    const ct = map.headers()['content-type'] ?? '';
    // SPA geri dusurme (index.html) ya da 404 kabul; gercek harita (json) kabul degil
    expect(map.status() === 404 || /text\/html/.test(ct), `${s}.map ${map.status()} ${ct}`).toBe(true);
  }
});
