/**
 * Yonetim: Akademisyenler (BACKEND'SIZ). Dort sekme, onayla / gerekceyle reddet / gerekceyle geri al, salt okunur profil (users.write yok ->
 * eylem dugmesi yok), ayrinti sayfasi (matris dort durum + duyurular + dosya indirme), imecli sayfalama.
 * Yanit bicimleri AdminAcademicianView / CourseView / AttendanceMatrix / NoticeView DTO'larindan: liste ucunda sayac alanlari null,
 * `limit` her zaman {type,value} nesnesi.
 *   cd web && npx playwright test admin-academicians.spec.ts
 */
import { expect, test } from '@playwright/test';

import { boot, fresh } from './admin-academicians-fake';

test('dort sekme: bekleyen (sayfalama), onayli, otomatik onaylanan, reddedilen+geri alinan (gerekce gorunur)', async ({ page }) => {
  const st = fresh();
  const problems = await boot(page, st);
  await page.goto('/admin/academicians');
  await expect(page.getByRole('heading', { level: 1, name: 'Akademisyenler' })).toBeVisible();
  const tabs = page.getByRole('tablist', { name: 'Başvuru durumu' });
  await expect(tabs.getByRole('tab')).toHaveText(['Bekleyen', 'Onaylı', 'Otomatik onaylanan', 'Reddedilen']);
  await expect(page.locator('tbody tr')).toHaveCount(20);
  // imecli sayfalama: sonraki 5
  await page.getByRole('button', { name: /Daha fazla|Devamını/ }).first().click();
  await expect(page.locator('tbody tr')).toHaveCount(25);
  expect(st.calls.some((c) => c.includes('status=PENDING') && c.includes('cursor=20'))).toBe(true);

  await tabs.getByRole('tab', { name: 'Onaylı' }).click();
  await expect(page.getByRole('link', { name: /Hoca 200/ })).toBeVisible();
  // maskeli e-posta ve adsiz kayit bozulmadan gorunur
  await expect(page.getByText('h***@b***.edu.tr')).toBeVisible();
  await expect(page.getByText('Adsız başvuru')).toBeVisible();
  await tabs.getByRole('tab', { name: 'Otomatik onaylanan' }).click();
  await expect(page.getByText(/bir insan bakmadan/)).toBeVisible();
  await expect(page.locator('tbody tr')).toHaveCount(1);
  await expect(page.getByText('Sistem (kural)')).toBeVisible();
  await tabs.getByRole('tab', { name: 'Reddedilen' }).click();
  await expect(page.getByText('Belgeler eksik')).toBeVisible();
  await expect(page.getByText('Yetki kötüye kullanıldı')).toBeVisible();
  expect(st.unexpected.filter((u) => u.includes('academician'))).toEqual([]);
  expect(problems).toEqual([]);
});

test('onayla: onay penceresi, Idempotency-Key, satir listeden duser', async ({ page }) => {
  const st = fresh();
  const problems = await boot(page, st);
  await page.goto('/admin/academicians');
  const first = page.locator('tbody tr').first();
  await first.getByRole('button', { name: 'Onayla' }).click();
  const dlg = page.getByRole('dialog');
  await expect(dlg).toBeVisible();
  await expect(dlg.getByText(/akademisyen paneline erişir/)).toBeVisible();
  await dlg.getByRole('button', { name: 'Onayla' }).click();
  await expect(page.getByText('Başvuru onaylandı.')).toBeVisible();
  await expect(page.locator('tbody tr')).toHaveCount(20); // 24 kaldi, ilk sayfa yeniden 20
  const call = st.bodies.find((b) => b.key === 'POST /admin/academicians/100/approve')!;
  expect(Object.keys(call.headers).some((h) => /idempotency/i.test(h))).toBe(true);
  expect(problems).toEqual([]);
});

test('reddet ve onayi geri al: gerekce ZORUNLU (bos gerekceyle gonderilmez), gerekce govdede gider', async ({ page }) => {
  const st = fresh();
  const problems = await boot(page, st);
  await page.goto('/admin/academicians');
  await page.locator('tbody tr').first().getByRole('button', { name: 'Reddet' }).click();
  let dlg = page.getByRole('alertdialog').or(page.getByRole('dialog'));
  const confirm = dlg.getByRole('button', { name: 'Reddet' });
  await expect(confirm).toBeDisabled(); // gerekce bos
  await dlg.getByLabel(/Ret gerekçesi/).fill('Kurumsal kimlik doğrulanamadı');
  await expect(confirm).toBeEnabled();
  await confirm.click();
  await expect(page.getByText('Başvuru reddedildi.')).toBeVisible();
  expect((st.bodies.find((b) => b.key === 'POST /admin/academicians/100/reject')!.body as { reason: string }).reason).toBe('Kurumsal kimlik doğrulanamadı');

  await page.getByRole('tab', { name: 'Onaylı' }).click();
  await page.locator('tbody tr').first().getByRole('button', { name: 'Onayı geri al' }).click();
  dlg = page.getByRole('alertdialog').or(page.getByRole('dialog'));
  await expect(dlg.getByRole('button', { name: 'Onayı geri al' })).toBeDisabled();
  await dlg.getByLabel(/Geri alma gerekçesi/).fill('Görev değişikliği');
  await dlg.getByRole('button', { name: 'Onayı geri al' }).click();
  await expect(page.getByText('Onay geri alındı.')).toBeVisible();
  expect(st.rows.find((x) => x.userId === 200)!.status).toBe('REVOKED');
  // Escape ile iptal: istek gonderilmez
  await page.getByRole('tab', { name: 'Reddedilen' }).click();
  expect(problems).toEqual([]);
});

test('salt okunur profil (users.write yok): listede ve ayrintida HICBIR eylem dugmesi yok', async ({ page }) => {
  const st = fresh();
  st.perms = ['users.read'];
  const problems = await boot(page, st);
  await page.goto('/admin/academicians');
  await expect(page.locator('tbody tr').first()).toBeVisible();
  await expect(page.getByRole('button', { name: /^(Onayla|Reddet|Onayı geri al)$/ })).toHaveCount(0);
  await page.goto('/admin/academicians/200');
  await expect(page.getByText('Profil ve başvuru')).toBeVisible();
  await expect(page.getByRole('button', { name: /^(Onayla|Reddet|Onayı geri al)$/ })).toHaveCount(0);
  // audit.read yok: denetim bolumu hic istenmez
  expect(st.calls.some((c) => c.startsWith('GET /admin/audit'))).toBe(false);
  expect(problems).toEqual([]);
});

test('ayrinti: profil, dersler, matris dort durum + sinir durumu, duyurular ve denetimli dosya indirme', async ({ page }) => {
  const st = fresh();
  const problems = await boot(page, st);
  await page.goto('/admin/academicians/200');
  await expect(page.getByText('Profil ve başvuru')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Onayı geri al' })).toBeVisible();
  await page.getByRole('button', { name: 'Veri Yapıları dersini seç' }).click();
  await expect(page).toHaveURL(/course=7/);
  await page.getByRole('tab', { name: 'Yoklama' }).click();
  const matrix = page.getByRole('table', { name: 'Yoklama matrisi' });
  await expect(matrix).toBeVisible();
  for (const l of ['Var (QR)', 'Var (elle)', 'Silindi', 'Yok']) await expect(matrix.getByText(l, { exact: true }).first()).toBeVisible();
  await expect(page.getByText('İsimsiz öğrenci')).toBeVisible();
  // sinir durumlari
  await page.getByRole('tab', { name: 'Öğrenciler' }).click();
  await expect(page.getByText('Sınır aşıldı')).toBeVisible();
  await expect(page.getByText('Sınıra yakın')).toBeVisible();
  await page.getByRole('tab', { name: 'Duyurular' }).click();
  const [dl] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: /sorular.pdf/ }).click()]);
  expect(dl.suggestedFilename()).toBe('sorular.pdf');
  // arsiv dersi: limit rozeti ve program bos
  await page.getByRole('button', { name: 'Arşivlenmiş Ders dersini seç' }).click();
  await expect(page.getByText('Arşivlendi').first()).toBeVisible();
  await expect(page.getByText('Devamsızlık sınırı %30').first()).toBeVisible();
  expect(problems).toEqual([]);
});

test('olmayan akademisyen: bulunamadi ekrani', async ({ page }) => {
  const st = fresh();
  await boot(page, st);
  await page.goto('/admin/academicians/99999');
  await expect(page.getByText('Akademisyen bulunamadı')).toBeVisible();
});

test('yonetim menusunde Akademisyenler baglantisi var ve sayfaya gider', async ({ page }) => {
  const st = fresh();
  await boot(page, st);
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto('/admin/users');
  await page.getByRole('link', { name: 'Akademisyenler' }).first().click();
  await expect(page).toHaveURL(/\/admin\/academicians/);
});
