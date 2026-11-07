/**
 * INSAN: Kullanıcılar grubu görsel doğrulaması (backendsiz). Ekran görüntüleri repoya girmez:
 * SHOTS_DIR (varsayılan ../.playwright-mcp/insan/after). Çalıştırma:
 *   cd web && E2E_PORT=5311 SHOTS_DIR=../.playwright-mcp/insan/before npx playwright test insan-visual.spec.ts
 */
import { expect, test, type Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { stubInsan } from './fixtures/insan';
import { pageOverflow } from './mockPanel';
import type { Scenario } from './fixtures/people';

const DIR = process.env.SHOTS_DIR || '../.playwright-mcp/insan/after';
mkdirSync(DIR, { recursive: true });

const PAGES: [string, string][] = [
  ['users', '/admin/users'],
  ['user-detail', '/admin/users/3'],
  ['user-detail-suspended', '/admin/users/4'],
  ['pending', '/admin/pending-users'],
  ['two-factor', '/admin/two-factor'],
];
const SIZES = [
  [1280, 900],
  [390, 844],
] as const;

async function open(page: Page, url: string, theme: 'light' | 'dark', w: number, h: number, scenario: Scenario) {
  await page.emulateMedia({ colorScheme: theme });
  await page.setViewportSize({ width: w, height: h });
  await stubInsan(page, scenario, theme === 'dark');
  await page.goto(url);
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(2200); // recharts giriş animasyonu bitsin
}

test('users 390 faculty bars (yakın plan)', async ({ page }) => {
  await open(page, '/admin/users', 'light', 390, 844, 'full');
  await page.locator('[data-search-anchor="users-chart-faculty"]').screenshot({ path: join(DIR, 'users-390-faculty-zoom.png') });
});

for (const [name, url] of PAGES) {
  for (const [w, h] of SIZES) {
    test(`${name} ${w}px full`, async ({ page }) => {
      await open(page, url, 'light', w, h, 'full');
      await page.screenshot({ path: join(DIR, `${name}-${w}-light.png`), fullPage: true });
      const o = await pageOverflow(page);
      expect(o.offenders, `${name} ${w}: yatay taşma`).toEqual([]);
    });
  }
  test(`${name} dark 390`, async ({ page }) => {
    await open(page, url, 'dark', 390, 844, 'full');
    await page.screenshot({ path: join(DIR, `${name}-390-dark.png`), fullPage: true });
  });
  for (const sc of ['empty', 'error'] as const) {
    test(`${name} ${sc} 1280`, async ({ page }) => {
      await open(page, url, 'light', 1280, 900, sc);
      await page.screenshot({ path: join(DIR, `${name}-1280-${sc}.png`), fullPage: true });
    });
  }
}
