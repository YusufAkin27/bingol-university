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

  test('yetkisiz kullanici panele giremez', async ({ page }) => {
    await page.goto('/admin/users');
    await expect(page).toHaveURL(/\/admin\/login/);
  });
});
