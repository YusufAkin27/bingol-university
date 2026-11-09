import { test, expect } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { json, stubPanel } from './mockPanel';
import { userDetailFixture, usersFixture } from '../src/pages/admin/analytics/behavior/fixtures';

const shots = resolve('../docs/qa/admin-insights-20261109');
mkdirSync(shots, { recursive: true });

for (const width of [1440, 390]) {
  for (const theme of ['light', 'dark'] as const) {
    test(`kullanıcı sayfa analizi ${width} ${theme}`, async ({ page }) => {
      test.setTimeout(90_000);
      await page.setViewportSize({ width, height: 940 });
      await stubPanel(page);
      await page.addInitScript((value) => localStorage.setItem('bu.theme', value), theme);
      const requests: string[] = [];
      await page.route('**/api/admin/analytics/behavior/**', (route) => {
        const url = new URL(route.request().url());
        requests.push(url.search);
        return json(route, /\/users\/1$/.test(url.pathname) ? userDetailFixture : usersFixture());
      });
      await page.goto('/admin/analytics?tab=behavior&sub=users&uid=1&from=2026-11-01&to=2026-11-03', { waitUntil: 'domcontentloaded' });
      const drawer = page.getByRole('dialog');
      await expect(
        drawer.getByRole('heading', { name: 'Bu kullanıcı hangi sayfalarda vakit geçiriyor?' }),
      ).toBeVisible({ timeout: 30_000 });
      expect(requests.some((q) => q.includes('from=2026-11-01') && q.includes('to=2026-11-03'))).toBe(true);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
      const bounds = await drawer.boundingBox();
      expect(bounds!.width).toBeLessThanOrEqual(width);
      await drawer.getByRole('heading', { name: 'Bu kullanıcı hangi sayfalarda vakit geçiriyor?' }).scrollIntoViewIfNeeded();
      await page.screenshot({ path: resolve(shots, `${width}-${theme}-pages.png`) });
      await drawer.getByRole('heading', { name: 'Hangi saatlerde kullanıyor?' }).scrollIntoViewIfNeeded();
      await expect(
        drawer.getByRole('list', { name: 'Hangi saatlerde kullanıyor?' }).getByRole('listitem'),
      ).toHaveCount(24);
      await page.screenshot({ path: resolve(shots, `${width}-${theme}-hours.png`) });
    });
  }
}
