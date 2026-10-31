/**
 * W2-K / T-062: herkese açık destek formu açılışta GET /api/public/support/form-token çağırır ve gönderimde jetonu
 * `formToken` alanıyla yollar (backendsiz, page.route). Gerçek uçtan uca akış: scripts/public-support-e2e.sh.
 *   cd web && npx playwright test w2k-support-form.spec.ts
 */
import { expect, test } from '@playwright/test';

test('/contact: form-token alınır ve gönderimde formToken gider', async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('bu.lang', 'tr');
    localStorage.setItem('bu.cookies', 'ack:v1');
  });
  const seen: string[] = [];
  let posted: Record<string, unknown> | null = null;
  await page.route(
    (u) => u.pathname.startsWith('/api/'),
    async (r) => {
      const p = new URL(r.request().url()).pathname;
      seen.push(`${r.request().method()} ${p}`);
      const json = (body: unknown, status = 200) =>
        r.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
      if (p === '/api/public/support/form-token') return json({ formToken: 'v1.1700000000000.abcd.sig', minFillSeconds: 1 });
      if (p === '/api/public/support/tickets') {
        posted = JSON.parse(r.request().postData() ?? '{}') as Record<string, unknown>;
        return json({ status: 'CODE_SENT', expiresInMinutes: 10 }, 202);
      }
      return json({ code: 'NOT_FOUND', message: 'yok' }, 404);
    },
  );
  await page.goto('/tr/contact');
  await expect.poll(() => seen.includes('GET /api/public/support/form-token')).toBe(true);
  await page.getByLabel(/Ad soyad/).fill('Ali Veli');
  await page.getByLabel(/E-posta/).fill('ali@example.com');
  await page.getByLabel(/Mesajınız/).fill('Uygulama açılmıyor, yardım eder misiniz?');
  await page.getByRole('button', { name: 'Doğrulama kodu gönder' }).click();
  await expect(page.getByText('E-postanızı doğrulayın')).toBeVisible();
  expect(posted).toMatchObject({ formToken: 'v1.1700000000000.abcd.sig', website: '' });
});
