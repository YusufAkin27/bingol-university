/**
 * T17 yonetim sayfalari: moderasyon (itiraz, aski onerisi, yasakli ozet), mesaj cozme, etkinlik ayarlari ve yeni menu ogeleri.
 * Gercek backend gerekir (yigin acikken calistirilir):
 *
 *   cd web && E2E_PORT=5195 npx playwright test admin-safety.spec.ts
 *
 * Kurallar: mesaj cozme yalnizca gerekce ve onay kutusuyla denenir; degisen ayar test sonunda eski degerine doner.
 */
import { expect, test } from '@playwright/test';
import { apiLogin, ensureAdminMe, loginAsAdmin, setLang } from './helpers';

const NEW_ROUTES: [string, RegExp][] = [
  ['/admin/moderation/appeals', /İtirazlar/],
  ['/admin/moderation/suspensions', /Askı önerileri/],
  ['/admin/moderation/blocklist', /Yasaklı görseller/],
  ['/admin/events/applications', /Etkinlik başvuruları/],
  ['/admin/communities/audit', /Kulüp yetki ve denetim kaydı/],
  ['/admin/crypto', /Sohbetler ve şifreleme/],
];

test.describe('Yeni yonetim sayfalari', () => {
  test.beforeEach(async ({ page, request }) => {
    await setLang(page, 'tr');
    await loginAsAdmin(page, request);
    await ensureAdminMe(page, request);
  });

  for (const [path, title] of NEW_ROUTES) {
    test(`${path} acilir`, async ({ page }) => {
      await page.goto(path);
      await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible();
    });
  }

  test('mesaj cozme: uyari gorunur, gerekcesiz gonderilemez', async ({ page }) => {
    await page.goto('/admin/crypto');
    await expect(page.getByTestId('decrypt-warning')).toContainText('değiştirilemez denetim kaydına yazılır');
    await expect(page.getByRole('button', { name: 'Mesajları çöz' })).toBeDisabled();
    await expect(page.getByText('Şifreleme durumu')).toBeVisible();
  });

  test('yasakli ozet ekle ve kaldir', async ({ page }) => {
    const sha = Array.from({ length: 64 }, () => Math.floor(Math.random() * 16).toString(16)).join('');
    await page.goto('/admin/moderation/blocklist');
    await page.getByRole('textbox', { name: /SHA-256 özeti/ }).fill(sha.toUpperCase());
    await page.getByRole('button', { name: 'Listeye ekle' }).click();
    await expect(page.getByText(sha)).toBeVisible();
    await page.getByRole('button', { name: 'Kaldır' }).first().click();
    await page.getByRole('dialog').getByRole('button', { name: 'Kaldır' }).click();
    await expect(page.getByText(sha)).toHaveCount(0);
  });

  test('ayarlar: etkinlik limiti degisir ve geri alinir', async ({ page, request }) => {
    const t = await apiLogin(request);
    const headers = { Authorization: `Bearer ${t.accessToken}` };
    const before = (await (await request.get('/api/admin/settings', { headers })).json()) as Record<string, string>;
    const old = before.event_daily_create_limit ?? '5';
    try {
      await page.goto('/admin/settings');
      await page.getByRole('tab', { name: /Etkinlikler/ }).click();
      const field = page.getByRole('textbox', { name: /günlük etkinlik açma sınırı/ });
      await field.fill('7');
      await page.getByTestId('save-event_daily_create_limit').click();
      await expect(page.getByText(/kaydedildi/)).toBeVisible();
      const after = (await (await request.get('/api/admin/settings', { headers })).json()) as Record<string, string>;
      expect(after.event_daily_create_limit).toBe('7');
    } finally {
      await request.put('/api/admin/settings/event_daily_create_limit', { headers, data: { value: old } });
    }
  });
});

test.describe('Arapca ve RTL', () => {
  test('yeni sayfalar sagdan sola yonlenir', async ({ page, request }) => {
    await setLang(page, 'ar');
    await loginAsAdmin(page, request);
    await ensureAdminMe(page, request);
    await page.goto('/admin/crypto');
    await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
    await expect(page.getByTestId('decrypt-warning')).toHaveCount(0);
  });
});
