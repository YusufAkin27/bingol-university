/**
 * Panel araması (üst çubuk + yan menü süzgeci + derin bağlantı) görsel/işlevsel doğrulama. BACKEND'SIZ: /api, mockPanel ile taklit.
 *   cd web && E2E_PORT=5191 npx playwright test admin-search.spec.ts
 * Ekran görüntüleri: SHOTS_DIR (varsayılan C:\bu_qa\shots\adminvisual\search); repoya girmez.
 */
import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { expect, test, type Page } from '@playwright/test';
import { json, stubPanel } from './mockPanel';

const SHOTS = process.env.SHOTS_DIR || 'C:\\bu_qa\\shots\\adminvisual\\search';
mkdirSync(SHOTS, { recursive: true });

const WIDTHS = [390, 768, 1280] as const;
const THEMES = ['light', 'dark'] as const;

const SETTINGS = {
  app_name: 'BÜ Kampüs',
  website: 'https://bukampus.example',
  contact_email: 'info@bingol.edu.tr',
  maintenance_mode: 'false',
  maintenance_message_tr: 'Kısa süreli bakım yapıyoruz.',
  faculties: 'Mühendislik ve Mimarlık Fakültesi;Fen-Edebiyat Fakültesi',
};

async function open(page: Page, theme: 'light' | 'dark', width: number) {
  await page.setViewportSize({ width, height: width === 390 ? 844 : width === 768 ? 1024 : 800 });
  await page.addInitScript((t) => {
    try {
      localStorage.setItem('bu.theme', t);
      localStorage.setItem('bu.cookies', 'ack:v1');
    } catch {
      /* yoksay */
    }
  }, theme);
  await stubPanel(page, 'FULL');
  // sonra kaydedilen yol öncelikli
  await page.route('**/api/admin/settings', (r) => json(r, SETTINGS));
  await page.goto('/admin/users', { waitUntil: 'domcontentloaded' });
  await expect(page.getByRole('heading', { level: 1, name: 'Kullanıcılar' })).toBeVisible();
}

async function openSearch(page: Page, width: number) {
  if (width >= 1100) await page.keyboard.press('Control+k');
  else await page.getByRole('button', { name: 'Panelde ara' }).click();
  await expect(page.getByRole('combobox', { name: 'Panelde sayfa, ayar ya da işlem ara' })).toBeVisible();
}

const noOverflow = async (page: Page) => {
  const o = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }));
  expect(o.sw, `scrollWidth ${o.sw} > clientWidth ${o.cw}`).toBeLessThanOrEqual(o.cw);
};

for (const width of WIDTHS) {
  for (const theme of THEMES) {
    test(`arama: ${width}px ${theme}`, async ({ page }) => {
      await open(page, theme, width);

      // 1) boş durum: son/sık aramalar
      await openSearch(page, width);
      await page.waitForTimeout(250);
      await page.screenshot({ path: path.join(SHOTS, `arama-bos-${width}-${theme}.png`) });

      // 2) "bakım modu" sonuçları (yazım hatalı: bakm modu)
      await page.keyboard.type('bakm modu');
      await expect(page.getByRole('dialog').getByRole('option').first()).toContainText('Bakım modu');
      await page.waitForTimeout(150);
      await page.screenshot({ path: path.join(SHOTS, `arama-sonuc-${width}-${theme}.png`) });

      // 3) sonuçsuz sorgu: "Şunu mu aradınız?"
      await page.getByRole('dialog').getByRole('combobox').fill('bakimm mdoo');
      await expect(page.getByText('Şunu mu aradınız?')).toBeVisible();
      await page.screenshot({ path: path.join(SHOTS, `arama-oneri-${width}-${theme}.png`) });

      // 4) Enter → Ayarlar'da bakım modu alanı vurgulanır
      await page.getByRole('dialog').getByRole('combobox').fill('bakim modu');
      await page.keyboard.press('Enter');
      await expect(page).toHaveURL(/\/admin\/settings#maintenance_mode$/);
      const target = page.locator('[data-search-anchor="maintenance_mode"]');
      await expect(target).toBeVisible();
      await expect(target).toHaveAttribute('data-search-hit', 'true');
      await expect(page.getByRole('tab', { name: /Bakım modu/ })).toHaveAttribute('aria-selected', 'true');
      await page.waitForTimeout(500);
      await page.screenshot({ path: path.join(SHOTS, `vurgu-${width}-${theme}.png`) });
      // vurgu ~2 sn sonra kalkar
      await expect(target).not.toHaveAttribute('data-search-hit', 'true', { timeout: 5000 });
      await noOverflow(page);
    });

    test(`menü süzgeci: ${width}px ${theme}`, async ({ page }) => {
      await open(page, theme, width);
      if (width < 1100) {
        await page.getByRole('button', { name: 'Menüyü aç' }).click();
        await page.waitForTimeout(450);
      }
      const box = page.getByRole('searchbox', { name: 'Menüde ara' });
      await box.fill('bakim modu');
      const menu = page.getByRole('navigation', { name: 'Yönetim menüsü' });
      await expect(menu.getByRole('link', { name: 'Ayarlar', exact: true })).toBeVisible();
      await page.waitForTimeout(200);
      await page.screenshot({ path: path.join(SHOTS, `menu-suzgec-${width}-${theme}.png`) });
      // alt sonuç: derin bağlantı
      const deep = menu.locator('a[href="/admin/settings#maintenance_mode"]');
      await expect(deep).toBeVisible();
      await deep.click();
      await expect(page).toHaveURL(/\/admin\/settings#maintenance_mode$/);
      await expect(page.locator('[data-search-anchor="maintenance_mode"]')).toHaveAttribute('data-search-hit', 'true');
      await noOverflow(page);
    });
  }
}

test('RBAC: görüntüleyici profili ayar girdisini görmez (settings.read var ama eylem izni yok)', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.addInitScript(() => localStorage.setItem('bu.cookies', 'ack:v1'));
  await stubPanel(page, 'SUPPORT');
  await page.goto('/admin/users', { waitUntil: 'domcontentloaded' });
  await expect(page.getByRole('heading', { level: 1, name: 'Kullanıcılar' })).toBeVisible();
  await page.keyboard.press('Control+k');
  await page.keyboard.type('bakım modu');
  await expect(page.getByRole('dialog').getByRole('option', { name: /Bakım modu/ })).toHaveCount(0);
});
