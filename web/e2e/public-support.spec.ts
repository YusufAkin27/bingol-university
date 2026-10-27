import { expect, test } from '@playwright/test';

/**
 * T27: herkese acik destek formu ve durum sayfasi (gercek backend; yigin ayakta olmadan calistirilmaz).
 * Dogrulama kodu e-postayla gider (MAIL_ENABLED=false iken backend logunda); bu yuzden tam akis scripts/public-support-e2e.sh
 * ile dogrulanir, burada arayuz davranisi (dogrulama, kod adimi, hata, durum sayfasi) denenir.
 */

test.describe('Bize ulasin formu', () => {
  test('/contact formu eksik alanlari engeller, gecerli formda kod adimina gecer', async ({ page }) => {
    await page.goto('/contact');
    await page.getByRole('button', { name: 'Doğrulama kodu gönder' }).click();
    await expect(page.getByText('Adınızı yazın.')).toBeVisible();
    await expect(page.getByText('Geçerli bir e-posta adresi yazın.').or(page.getByText('E-posta adresinizi yazın.'))).toBeVisible();

    await page.getByLabel(/Ad soyad/).fill('Ali Veli');
    await page.getByLabel(/E-posta/).fill(`e2e${Date.now()}@example.com`);
    await page.getByLabel(/Mesajınız/).fill('Uygulama açılmıyor, yardım eder misiniz?');
    // Minimum doldurma suresi (3 sn) dolmadan gonderim sessizce elenir; gercek kullanici bu sureyi gecer
    await page.waitForTimeout(3200);
    await page.getByRole('button', { name: 'Doğrulama kodu gönder' }).click();
    await expect(page.getByRole('heading', { name: 'E-postanızı doğrulayın' })).toBeVisible();

    await page.getByLabel(/Doğrulama kodu/).fill('000000');
    await page.getByRole('button', { name: 'Doğrula ve gönder' }).click();
    await expect(page.getByRole('alert')).toBeVisible();
  });

  test('bal kabagi alani insanlara gorunmez ve odaklanamaz', async ({ page }) => {
    await page.goto('/contact');
    const hp = page.locator('input[name="website"]');
    await expect(hp).toHaveAttribute('tabindex', '-1');
    await expect(hp).not.toBeInViewport();
  });

  test('mobil gorunumde form yatay tasmaz', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 800 });
    await page.goto('/contact');
    await expect(page.getByRole('button', { name: 'Doğrulama kodu gönder' })).toBeVisible();
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    expect(overflow).toBeLessThanOrEqual(1);
  });
});

test.describe('talep durum sayfasi', () => {
  test('anahtar yokken uyari, gecersiz anahtarda bulunamadi gosterir', async ({ page }) => {
    await page.goto('/support/track');
    await expect(page.getByText(/Bağlantı eksik veya geçersiz/)).toBeVisible();
    await page.goto('/support/track?token=gecersiz-anahtar-gecersiz-anahtar-1234');
    await expect(page.getByText('Talep bulunamadı')).toBeVisible();
  });
});

test.describe('yemek listesi', () => {
  test('sayfa acilir, gorunumler degisir ve kaynak satiri yoktur', async ({ page }) => {
    await page.goto('/menu');
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Yemek listesi');
    await page.getByRole('button', { name: 'Haftalık' }).click();
    await page.getByRole('button', { name: 'Aylık' }).click();
    await expect(page.getByText(/sks\.bingol\.edu\.tr/)).toHaveCount(0);
  });
});
