/**
 * Analitik > Davranış sekmesi: backendsiz gerçek tarayıcı doğrulaması (page.route sahte API; sözleşme biçimi).
 * 1440/768/390 px, açık + koyu tema; yatay taşma ve konsol hatası denetimi; ekran görüntüleri BH_SHOTS klasörüne.
 *   cd web && E2E_PORT=5195 BH_SHOTS=C:/bu_dsg/_shots/bh npx playwright test behavior-mocked.spec.ts
 */
import { expect as baseExpect, test, type Page } from '@playwright/test';
import { actionsFixture, flowsFixture, overviewFixture, screensFixture, userDetailFixture, usersFixture } from '../src/pages/admin/analytics/behavior/fixtures';
import { json, pageOverflow, stubPanel } from './mockPanel';

// soğuk Vite derlemesinde tembel yüklenen sayfa yavaş açılabilir
const expect = baseExpect.configure({ timeout: 20_000 });
test.setTimeout(90_000);
const SHOTS = process.env.BH_SHOTS || '';
const WIDTHS = [1440, 768, 390];
const THEMES = ['light', 'dark'] as const;

async function stubBehavior(page: Page) {
  await page.route(
    (u) => u.pathname.startsWith('/api/admin/analytics/behavior/'),
    (r) => {
      const u = new URL(r.request().url());
      const p = u.pathname.replace('/api/admin/analytics/behavior', '');
      const pg = Number(u.searchParams.get('page') ?? 0);
      if (p === '/overview') return json(r, overviewFixture);
      if (p === '/screens') return json(r, screensFixture(pg, 20, 45));
      if (p === '/flows') return json(r, flowsFixture);
      if (p === '/actions') return json(r, actionsFixture);
      if (p === '/users') return json(r, usersFixture(pg, 20, 45));
      if (/^\/users\/\d+$/.test(p)) return json(r, userDetailFixture);
      return json(r, { code: 'NOT_FOUND', message: 'yok' }, 404);
    },
  );
}

for (const theme of THEMES) {
  for (const w of WIDTHS) {
    test(`Davranış sekmesi @${w} ${theme}`, async ({ page }) => {
      const errors: string[] = [];
      page.on('console', (m) => {
        // kabuğun taklit edilmeyen yan uçları 404 döner (stubPanel); davranış uçları aşağıda ayrıca denetlenir
        if (m.type() === 'error' && !m.text().startsWith('Failed to load resource')) errors.push(m.text());
      });
      page.on('response', (r) => {
        if (r.url().includes('/analytics/behavior/') && r.status() >= 400) errors.push(`${r.status()} ${r.url()}`);
      });
      page.on('pageerror', (e) => errors.push(String(e)));
      await page.setViewportSize({ width: w, height: 900 });
      await page.addInitScript((t) => localStorage.setItem('bu.theme', t), theme);
      await stubPanel(page, 'FULL');
      await stubBehavior(page);

      const shot = async (name: string) => {
        if (!SHOTS) return;
        await page.waitForTimeout(900); // grafik animasyonu bitsin
        await page.screenshot({ path: `${SHOTS}/${name}-${w}-${theme}.png`, fullPage: true });
      };
      const noOverflow = async (label: string) => {
        const o = await pageOverflow(page);
        expect(o.sw, `${label}: scrollWidth ${o.sw} > clientWidth ${o.cw}; ${o.offenders.join(' | ')}`).toBeLessThanOrEqual(o.cw);
      };

      // Özet
      await page.goto('/admin/analytics?tab=behavior');
      await expect(page.getByText('Ortalama oturum süresi', { exact: true })).toBeVisible();
      await page.waitForLoadState('networkidle');
      await shot('1-ozet');
      await noOverflow('özet');

      // Ekranlar
      await page.goto('/admin/analytics?tab=behavior&sub=screens');
      await expect(page.getByText('Haber Detayı').first()).toBeVisible();
      await page.waitForLoadState('networkidle');
      await shot('2-ekranlar');
      await noOverflow('ekranlar');

      // Akışlar
      await page.goto('/admin/analytics?tab=behavior&sub=flows');
      await expect(page.getByText('Ana Sayfa → Haber Detayı')).toBeVisible();
      await page.waitForLoadState('networkidle');
      await shot('3-akislar');
      await noOverflow('akışlar');

      // Eylemler
      await page.goto('/admin/analytics?tab=behavior&sub=actions');
      await expect(page.getByText('Mesaj gönderme').first()).toBeVisible();
      await page.waitForLoadState('networkidle');
      await shot('4-eylemler');
      await noOverflow('eylemler');

      // Kullanıcılar + çekmece
      await page.goto('/admin/analytics?tab=behavior&sub=users');
      await expect(page.getByText('Test Kullanıcı 1').first()).toBeVisible();
      await page.waitForLoadState('networkidle');
      await shot('5-kullanicilar');
      await noOverflow('kullanıcılar');
      await page.getByText('Test Kullanıcı 1').first().click();
      const dlg = page.getByRole('dialog');
      await expect(dlg.getByText('Test Kullanıcı 1: davranış')).toBeVisible();
      await expect(dlg.getByText('Haber Detayı').first()).toBeVisible();
      await page.waitForLoadState('networkidle');
      await shot('6-cekmece');
      await noOverflow('çekmece');
      await page.keyboard.press('Escape');
      await expect(dlg).toHaveCount(0);

      expect(errors, `konsol hataları: ${errors.join(' | ')}`).toEqual([]);
    });
  }
}

test('Davranış sekmesi: izinsiz profilde Kullanıcılar bölümü yok', async ({ page }) => {
  await stubPanel(page, 'VIEWER'); // VIEWER: analytics.read var, users.pii yok
  await stubBehavior(page);
  await page.goto('/admin/analytics?tab=behavior&sub=users');
  await expect(page.getByText('Ortalama oturum süresi', { exact: true })).toBeVisible();
  await expect(page.getByRole('tab', { name: 'Kullanıcılar' })).toHaveCount(0);
});
