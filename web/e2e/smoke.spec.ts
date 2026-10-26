import { expect, test } from '@playwright/test';
import { ensureAdminMe, loginAsAdmin, setLang } from './helpers';

test.describe('temel akis', () => {
  test('ana sayfa acilir ve dil Arapcaya gecince RTL olur', async ({ page }) => {
    await setLang(page, 'ar');
    await page.goto('/');
    await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
    await expect(page.locator('html')).toHaveAttribute('lang', 'ar');
  });

  test('yonetici giris sayfasi gorunur', async ({ page }) => {
    await page.goto('/admin/login');
    await expect(page.getByRole('button').first()).toBeVisible();
  });

  test('yonetici oturumu ile panel acilir', async ({ page, request }) => {
    await loginAsAdmin(page, request);
    await ensureAdminMe(page, request);
    await page.goto('/admin');
    await expect(page).toHaveURL(/\/admin/);
    await expect(page.getByRole('navigation').first()).toBeVisible();
  });

  // Gercek form girisi: tarayici Origin basligi gonderir (nginx Host/CORS regresyonunu yakalar)
  test('yonetici formdan giris yapabilir', async ({ page }) => {
    await page.goto('/admin/login');
    await page.getByLabel(/E-posta/).fill(process.env.E2E_ADMIN_EMAIL || 'boss@bingol.edu.tr');
    await page.locator('input[type=password]').fill(process.env.E2E_ADMIN_PASSWORD || 'Sifre1234');
    await page.getByRole('button', { name: /Giriş yap/ }).click();
    await expect(page).toHaveURL(/\/admin\/?$/);
    await expect(page.getByRole('heading', { name: 'Genel bakış' })).toBeVisible();
  });

  test('kullanici detayi tum bolumleri gosterir', async ({ page, request }) => {
    const t = await loginAsAdmin(page, request);
    const h = { Authorization: `Bearer ${t.accessToken}` };
    const list = await (await request.get('/api/admin/users?size=1&sort=createdAt,asc', { headers: h })).json();
    await page.goto(`/admin/users/${list.items[0].id}`);
    for (const title of ['Profil', 'Sayaçlar', 'Hesap bilgileri', 'Bildirim tercihleri', 'Üye olduğu topluluklar',
      'Oluşturduğu etkinlikler', 'Geri bildirimleri', 'Destek talepleri', 'Hakkındaki raporlar', 'Cihaz kayıtları']) {
      await expect(page.getByRole('heading', { name: title }).first()).toBeVisible();
    }
  });

  test('yetkisiz kullanici panele giremez', async ({ page }) => {
    await page.goto('/admin/users');
    await expect(page).toHaveURL(/\/admin\/login/);
  });
});
