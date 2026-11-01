/**
 * Arama motoru + kabuk (kısayollar, yıldız, yardım, sayfa iskeleti) görsel/işlevsel doğrulama. BACKEND'SIZ: /api, mockPanel ile taklit.
 *   cd web && E2E_PORT=5217 SHOTS_DIR=../.playwright-mcp/arama npx playwright test admin-arama-kabuk.spec.ts
 */
import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { expect, test, type Page } from '@playwright/test';
import { json, stubPanel } from './mockPanel';

const SHOTS = process.env.SHOTS_DIR || path.join('..', '.playwright-mcp', 'arama');
mkdirSync(SHOTS, { recursive: true });

async function open(page: Page, width: number, theme: 'light' | 'dark' = 'light') {
  await page.setViewportSize({ width, height: width === 390 ? 844 : 800 });
  await page.addInitScript((t) => {
    try {
      localStorage.setItem('bu.theme', t);
      localStorage.setItem('bu.cookies', 'ack:v1');
    } catch {
      /* yoksay */
    }
  }, theme);
  await stubPanel(page, 'FULL');
  await page.route('**/api/admin/settings', (r) => json(r, {}));
  await page.goto('/admin/users', { waitUntil: 'domcontentloaded' });
  await expect(page.getByRole('heading', { level: 1, name: 'Kullanıcılar' })).toBeVisible({ timeout: 30_000 });
}

async function openSearch(page: Page, width: number) {
  if (width >= 1100) await page.keyboard.press('Control+k');
  else await page.getByRole('button', { name: 'Panelde ara' }).click();
  return page.getByRole('combobox', { name: 'Panelde sayfa, ayar ya da işlem ara' });
}

const noOverflow = async (page: Page) => {
  const o = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }));
  expect(o.sw).toBeLessThanOrEqual(o.cw + 1);
};

for (const width of [1280, 390] as const) {
  test.describe(`arama ve kabuk @${width}`, () => {
    test('"mesaj" ve yazım hatalı "meaj": ilgili sayfalar, yol ve eşleşen bölüm görünür', async ({ page }) => {
      test.setTimeout(90_000);
      await open(page, width);
      const box = await openSearch(page, width);
      await box.fill('mesaj');
      const list = page.getByRole('listbox');
      await expect(list.getByRole('option').first()).toContainText('Mesaj erişim kayıtları');
      await expect(list).toContainText('Sohbet medyası ve mesajlar');
      await expect(list).toContainText('Sohbetler ve şifreleme');
      await page.screenshot({ path: path.join(SHOTS, `mesaj-${width}.png`) });

      await box.fill('meaj');
      await expect(list.getByRole('option').first()).toContainText(/Mesaj erişim kayıtları|Sohbet medyası ve mesajlar/);
      await page.screenshot({ path: path.join(SHOTS, `meaj-${width}.png`) });

      await box.fill('kulanıcı mesjları');
      await expect(list.getByRole('option').first()).toContainText('Kullanıcı mesajlarını görüntüle');
      await page.screenshot({ path: path.join(SHOTS, `kulanici-mesjlari-${width}.png`) });

      await box.fill('dm');
      await expect(list).toContainText('Sohbet medyası ve mesajlar');
      await noOverflow(page);
    });

    test('yıldız + son ziyaret: boş arama kutusunda listelenir; yardım penceresi açılır', async ({ page }) => {
      test.setTimeout(90_000);
      await open(page, width);
      await page.getByRole('button', { name: 'Sık kullanılanlara ekle' }).click();
      await expect(page.getByRole('button', { name: 'Sık kullanılanlardan çıkar' })).toHaveAttribute('aria-pressed', 'true');
      const box = await openSearch(page, width);
      await expect(page.getByText('Sık kullandığınız sayfalar')).toBeVisible();
      await page.screenshot({ path: path.join(SHOTS, `bos-arama-${width}.png`) });
      await box.press('Escape');

      await page.getByRole('button', { name: 'Yardım ve klavye kısayolları' }).click();
      const dlg = page.getByRole('dialog', { name: 'Yardım ve kısayollar' });
      await expect(dlg).toBeVisible();
      await page.screenshot({ path: path.join(SHOTS, `yardim-${width}.png`) });
      await page.keyboard.press('Escape');
      await expect(dlg).toBeHidden();
      await noOverflow(page);
    });
  });
}

test('masaüstü: g + harf gezinti, ? yardım, / arama; koyu tema yardım penceresi', async ({ page }) => {
  test.setTimeout(90_000);
  await open(page, 1280, 'dark');
  await page.keyboard.press('g');
  await expect(page.getByText('g: gidilecek sayfanın harfine basın…')).toBeVisible();
  await page.keyboard.press('r');
  await expect(page.getByRole('heading', { level: 1, name: 'Raporlar' })).toBeVisible({ timeout: 30_000 });
  await page.keyboard.press('Shift+?');
  const dlg = page.getByRole('dialog', { name: 'Yardım ve kısayollar' });
  await expect(dlg).toBeVisible();
  await page.screenshot({ path: path.join(SHOTS, 'yardim-koyu-1280.png') });
  await page.keyboard.press('Escape');
  await page.keyboard.press('/');
  await expect(page.getByRole('combobox', { name: 'Panelde sayfa, ayar ya da işlem ara' })).toBeVisible();
});
