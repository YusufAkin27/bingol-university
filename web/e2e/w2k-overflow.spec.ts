/**
 * W2-K / T-155: yonetim paneli yatay tasma taramasi (backendsiz, page.route ile). 1280/768/390 px.
 *   cd web && npx playwright test w2k-overflow.spec.ts
 */
import { expect, test } from '@playwright/test';
import { pageOverflow, stubPanel } from './mockPanel';

const ROUTES = [
  '/admin/audit',
  '/admin/mail/queue',
  '/admin/roles',
  '/admin/security/access-bans',
  '/admin/push/ops',
  '/admin/push/ops?tab=queue',
  '/admin/push/ops?tab=devices',
];
const WIDTHS = [1280, 768, 390];

test.describe('Panel yatay tasma (T-155)', () => {
  for (const w of WIDTHS) {
    for (const route of ROUTES) {
      test(`${route} @${w}`, async ({ page }) => {
        await page.setViewportSize({ width: w, height: 900 });
        await stubPanel(page, 'FULL');
        await page.goto(route);
        await page.waitForSelector('main h1');
        await page.waitForLoadState('networkidle');
        const o = await pageOverflow(page);
        expect(o.sw, `scrollWidth ${o.sw} > clientWidth ${o.cw}; ${o.offenders.join(' | ')}`).toBeLessThanOrEqual(o.cw);
      });
    }
  }
});
