/**
 * Yönetim kabuğu ve giriş sayfası yerleşim/erişilebilirlik denetimi. BACKEND'SIZ çalışır (tüm /api page.route ile taklit).
 *   cd web && npx playwright test admin-shell.spec.ts
 * 1280 / 768 / 360 px x açık/koyu: sayfa yatay kaymaz, yan menü beklenen kipte (264 px / 72 px simge çubuğu / çekmece),
 * üst çubuk ekran içinde, panel dili site tercihine rağmen Türkçe, gerçek tarayıcıda axe (kontrast dahil).
 * Ekran görüntüleri e2e/.results/shell altına yazılır.
 */
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { expect, test, type Page, type Route } from '@playwright/test';

const require = createRequire(import.meta.url);
const AXE = require.resolve('axe-core/axe.min.js');
const SHOTS = path.join('e2e', '.results', 'shell');
mkdirSync(SHOTS, { recursive: true });

const ME = { id: 1, email: 'boss@bingol.edu.tr', displayName: 'Yonetici', role: 'ADMIN' };
const WIDTHS = [1280, 768, 360] as const;
const THEMES = ['light', 'dark'] as const;

const json = (route: Route, body: unknown, status = 200) =>
  route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

const userRow = (id: number) => ({
  id,
  email: `kullanici.${id}.uzun.bir.eposta.adresi@ogr.bingol.edu.tr`,
  displayName: `Kullanıcı ${id} Uzun Bir Görünen Ad`,
  faculty: 'Mühendislik ve Mimarlık Fakültesi',
  department: 'Bilgisayar Mühendisliği',
  classYear: 2,
  language: 'tr',
  role: 'USER',
  status: 'ACTIVE',
  emailVerified: true,
  createdAt: '2026-01-02T10:00:00Z',
  lastSeenAt: null,
  avatarUrl: null,
});

async function stub(page: Page) {
  // yalnız /api/ ile başlayan yollar (Vite'in /src/api/*.ts modülleri taklit edilmemeli)
  await page.route((u) => u.pathname.startsWith('/api/'), (r) => json(r, { code: 'NOT_FOUND', message: 'yok' }, 404));
  await page.route('**/api/admin/me', (r) => json(r, ME));
  await page.route('**/api/admin/users?**', (r) =>
    json(r, { items: Array.from({ length: 12 }, (_, i) => userRow(i + 1)), page: 0, totalPages: 1, totalItems: 12 }),
  );
}

async function prepare(page: Page, theme: 'light' | 'dark', signedIn: boolean) {
  await page.addInitScript(
    ([t, auth]) => {
      try {
        localStorage.setItem('bu.lang', 'ar'); // site dili Arapça: panel yine Türkçe/LTR olmalı
        localStorage.setItem('bu.theme', t as string);
        localStorage.setItem('bu.cookies', 'ack:v1');
        if (auth) {
          sessionStorage.setItem('bu.admin.access', 'a.b.c');
          sessionStorage.setItem('bu.admin.refresh', 'r1');
        }
      } catch {
        /* yoksay */
      }
    },
    [theme, signedIn] as const,
  );
}

async function axeViolations(page: Page, include: string[]): Promise<string[]> {
  await page.addScriptTag({ path: AXE });
  return page.evaluate(async (sel) => {
    const res = await (window as unknown as { axe: { run: (c: unknown, o: unknown) => Promise<{ violations: { id: string; nodes: { target: string[] }[] }[] }> } }).axe.run(
      { include: sel.map((s) => [s]) },
      { rules: { region: { enabled: false } } },
    );
    return res.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(' | ')}`);
  }, include);
}

async function hOverflow(page: Page) {
  return page.evaluate(() => ({
    sw: document.documentElement.scrollWidth,
    cw: document.documentElement.clientWidth,
  }));
}

for (const width of WIDTHS) {
  for (const theme of THEMES) {
    test(`kabuk: ${width}px ${theme}`, async ({ page }) => {
      test.setTimeout(90_000);
      await page.setViewportSize({ width, height: 800 });
      await prepare(page, theme, true);
      await stub(page);
      await page.goto('/admin/users', { waitUntil: 'domcontentloaded' });
      await expect(page.getByRole('heading', { level: 1, name: 'Kullanıcılar' })).toBeVisible();
      await expect(page.locator('tbody tr')).toHaveCount(12);
      await page.waitForTimeout(300);

      // dil: Arapça tercihine rağmen Türkçe ve soldan sağa
      await expect(page.locator('html')).toHaveAttribute('lang', 'tr');
      await expect(page.locator('html')).toHaveAttribute('dir', 'ltr');
      expect(await page.evaluate(() => localStorage.getItem('bu.lang'))).toBe('ar');

      // sayfa yatay kaymaz
      const o = await hOverflow(page);
      expect(o.sw, `scrollWidth ${o.sw} > clientWidth ${o.cw}`).toBeLessThanOrEqual(o.cw);

      // üst çubuk ekran içinde
      const bar = (await page.locator('header').first().boundingBox())!;
      expect(bar.x).toBeGreaterThanOrEqual(0);
      expect(bar.x + bar.width).toBeLessThanOrEqual(width + 1);

      // yan menü kipi
      const aside = page.locator('aside');
      if (width === 1280) {
        expect((await aside.boundingBox())!.width).toBeCloseTo(264, 0);
        await expect(page.getByRole('searchbox', { name: 'Menüde ara' })).toBeVisible();
      } else if (width === 768) {
        expect((await aside.boundingBox())!.width).toBeCloseTo(72, 0);
        await expect(page.getByRole('searchbox', { name: 'Menüde ara' })).toHaveCount(0);
      } else {
        await expect(aside).toBeHidden();
        await expect(page.getByRole('button', { name: 'Menüyü aç' })).toBeVisible();
      }

      // tablo kendi kapsayıcısında kayar, sayfa kaymaz (360'ta tablo kapsayıcıdan geniştir)
      const scroller = page.getByRole('table').locator('xpath=ancestor::div[contains(@class,"scroll")][1]');
      const m = await scroller.evaluate((el) => ({ sw: el.scrollWidth, cw: el.clientWidth, ov: getComputedStyle(el).overflowX }));
      expect(['auto', 'scroll']).toContain(m.ov);
      if (width === 360) expect(m.sw).toBeGreaterThan(m.cw);

      await page.screenshot({ path: path.join(SHOTS, `users.${width}.${theme}.png`) });

      // dar/orta ekranda menüyü aç: çekmece/üstte açılan menü, içerik kaymaz
      if (width !== 1280) {
        const mainLeft = (await page.locator('main').boundingBox())!.x;
        await page.getByRole('button', { name: 'Menüyü aç' }).click();
        await expect(page.getByRole('searchbox', { name: 'Menüde ara' })).toBeVisible();
        // genişlik geçişi (0,2 sn) bitene kadar bekle
        await expect.poll(async () => (await aside.boundingBox())!.width).toBeGreaterThan(200);
        expect((await aside.boundingBox())!.width).toBeLessThanOrEqual(width * 0.9);
        await page.waitForTimeout(400); // kayma geçişi bitsin
        await page.screenshot({ path: path.join(SHOTS, `drawer.${width}.${theme}.png`) });
        // menü araması ve Esc
        await page.getByRole('searchbox', { name: 'Menüde ara' }).fill('rapor');
        await expect(page.getByRole('navigation', { name: 'Yönetim menüsü' }).getByRole('link')).toHaveCount(1);
        await page.keyboard.press('Escape');
        await expect(page.getByRole('searchbox', { name: 'Menüde ara' })).toHaveCount(width === 768 ? 0 : 1);
        if (width === 768) expect((await page.locator('main').boundingBox())!.x).toBeCloseTo(mainLeft, 0);
      }

      // gerçek tarayıcıda axe (kontrast dahil): yan menü + üst çubuk temiz olmalı
      const bad = await axeViolations(page, ['header', 'aside']);
      expect(bad, bad.join('\n')).toEqual([]);
    });

    test(`giriş: ${width}px ${theme}`, async ({ page }) => {
      await page.setViewportSize({ width, height: 800 });
      await prepare(page, theme, false);
      await stub(page);
      await page.goto('/admin/login', { waitUntil: 'domcontentloaded' });
      await expect(page.getByRole('heading', { level: 1, name: 'Yönetim paneli girişi' })).toBeVisible();
      await page.waitForTimeout(200);
      const o = await hOverflow(page);
      expect(o.sw, `scrollWidth ${o.sw} > clientWidth ${o.cw}`).toBeLessThanOrEqual(o.cw);
      await expect(page.locator('html')).toHaveAttribute('lang', 'tr');
      await expect(page.locator('select')).toHaveCount(0);
      await page.screenshot({ path: path.join(SHOTS, `login.${width}.${theme}.png`) });
      // hata durumu
      await page.route('**/api/auth/login', (r) => json(r, { code: 'RATE_LIMITED', message: 'x' }, 429));
      await page.getByLabel('E-posta').fill('boss@bingol.edu.tr');
      await page.locator('input[type=password]').fill('yanlis');
      await page.getByRole('button', { name: 'Giriş yap' }).click();
      await expect(page.getByRole('alert')).toContainText('Çok fazla giriş denemesi');
      await page.screenshot({ path: path.join(SHOTS, `login-error.${width}.${theme}.png`) });
      const bad = await axeViolations(page, ['body']);
      expect(bad, bad.join('\n')).toEqual([]);
    });
  }
}

test('klavye: skip-link ana alana odaklar, Ctrl+K sayfa aramasını açar', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await prepare(page, 'light', true);
  await stub(page);
  await page.goto('/admin/users', { waitUntil: 'domcontentloaded' });
  await expect(page.getByRole('heading', { level: 1, name: 'Kullanıcılar' })).toBeVisible();
  await page.keyboard.press('Tab');
  const skip = page.getByRole('link', { name: 'İçeriğe geç' });
  await expect(skip).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.locator('#admin-main')).toBeFocused();
  await page.keyboard.press('Control+k');
  await expect(page.getByRole('combobox', { name: 'Sayfa ara' })).toBeVisible();
  await page.keyboard.type('anket');
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/admin\/polls/);
});
