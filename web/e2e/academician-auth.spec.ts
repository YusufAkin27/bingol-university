/**
 * Akademisyen oturumu (BACKEND'SIZ, /api page.route ile taklit): kayit -> basvuru -> bekleme ekrani; beklemede -> onayli gecis;
 * oturum dusunce /akademisyen/giris (yonetim girisi DEGIL); yonetim ve akademisyen oturumlarinin gercek tarayicida ayriligi.
 *   cd web && npx playwright test academician-auth.spec.ts
 */
import { expect, test } from '@playwright/test';
import { guardConsole, installAcademicianFake, newState, seedAcadSession, seedTheme } from './academician-fake';

test('kayit: e-posta+parola -> kod -> basvuru -> bekleme ekrani', async ({ page }) => {
  const st = newState();
  const g = guardConsole(page, st);
  await seedTheme(page, 'light');
  await installAcademicianFake(page, st);
  await page.goto('/akademisyen/kayit');
  await expect(page.getByRole('heading', { name: 'Akademisyen kaydı' })).toBeVisible();

  // zorunlu alan hatalari
  await page.getByRole('button', { name: 'Kod gönder' }).click();
  await expect(page.getByText('Bu alan zorunlu.').first()).toBeVisible();
  await expect(page.getByText('Devam etmek için kabul etmelisiniz.')).toBeVisible();

  await page.getByLabel('E-posta').fill('hoca@bingol.edu.tr');
  await page.getByLabel('Parola', { exact: false }).first().fill('Sifre1234');
  await page.getByRole('checkbox').check();
  await page.getByRole('button', { name: 'Kod gönder' }).click();

  await expect(page.getByRole('heading', { name: 'E-postanızı doğrulayın' })).toBeVisible();
  await page.getByLabel('Doğrulama kodu').fill('123456');
  await page.getByRole('button', { name: 'Doğrula ve devam et' }).click();

  await expect(page.getByRole('heading', { name: 'Başvuru bilgileriniz' })).toBeVisible();
  await page.getByLabel(/Unvan/).fill('Doç. Dr.');
  await page.getByLabel(/^Ad/).first().fill('Çağrı');
  await page.getByLabel(/Soyad/).fill('Öztürk');
  await page.getByRole('button', { name: 'Başvuruyu gönder' }).click();

  await expect(page).toHaveURL(/\/akademisyen\/beklemede$/);
  await expect(page.getByRole('heading', { name: 'Başvurunuz inceleniyor' })).toBeVisible();
  await expect(page.getByText('Doç. Dr. Çağrı Öztürk')).toBeVisible();
  // gonderilen govde: faculty/department/grade yok (otomatik onay kurali ogrenci sinyali tasimamali)
  const reg = st.bodies.find((b) => b.key === 'POST /auth/register')!.body as Record<string, unknown>;
  expect(reg).not.toHaveProperty('faculty');
  expect(reg).not.toHaveProperty('department');
  expect(reg.acceptTerms).toBe(true);
  g.assertClean();
});

test('beklemede -> onayli: "Durumu yenile" paneli acar; hala bekliyorsa bilgi verir', async ({ page }) => {
  const st = newState({ me: { status: 'PENDING', approvalMode: null, title: 'Dr.', firstName: 'Deneme', lastName: 'Hoca', unit: null, rejectReason: null } });
  const g = guardConsole(page, st);
  await seedAcadSession(page);
  await installAcademicianFake(page, st);
  // beklemedeyken panel adresi bekleme ekranina yonlendirir
  await page.goto('/akademisyen');
  await expect(page).toHaveURL(/\/akademisyen\/beklemede$/);
  await expect(page.getByRole('heading', { name: 'Başvurunuz inceleniyor' })).toBeVisible();

  await page.getByRole('button', { name: 'Durumu yenile' }).click();
  await expect(page.getByText('Başvurunuz hâlâ inceleniyor.')).toBeVisible();

  st.me = { ...st.me, status: 'APPROVED', approvalMode: 'ADMIN' };
  await page.getByRole('button', { name: 'Durumu yenile' }).click();
  await expect(page).toHaveURL(/\/akademisyen$/);
  await expect(page.getByRole('heading', { name: /Merhaba/ })).toBeVisible();
  g.assertClean();
});

test('reddedilmis ve yetkisi alinmis akademisyen: gerekce gorunur, panel acilmaz', async ({ page }) => {
  for (const status of ['REJECTED', 'REVOKED'] as const) {
    const st = newState({ me: { status, approvalMode: 'ADMIN', title: 'Dr.', firstName: 'D', lastName: 'H', unit: null, rejectReason: 'Belgeler eksik' } });
    await seedAcadSession(page);
    await installAcademicianFake(page, st);
    await page.goto('/akademisyen/dersler');
    await expect(page).toHaveURL(/\/akademisyen\/beklemede$/);
    await expect(page.getByText('Belgeler eksik')).toBeVisible();
    await page.unrouteAll({ behavior: 'ignoreErrors' });
  }
});

test('oturum panelin ortasinda dusunce /akademisyen/giris acilir (yonetim girisine DEGIL)', async ({ page }) => {
  const st = newState();
  const g = guardConsole(page, st);
  await seedAcadSession(page);
  await installAcademicianFake(page, st);
  await page.goto('/akademisyen/dersler');
  await expect(page.getByRole('heading', { name: 'Derslerim' }).first()).toBeVisible();

  st.expired = true;
  await page.getByRole('link', { name: /Veri Yapıları/ }).click(); // yeni sorgu -> 401 -> refresh 401
  await expect(page).toHaveURL(/\/akademisyen\/giris/);
  expect(page.url()).not.toContain('/admin');
  await expect(page.getByRole('heading', { name: 'Akademisyen girişi' })).toBeVisible();
  const keys = await page.evaluate(() => ({ a: sessionStorage.getItem('bu.acad.access'), r: sessionStorage.getItem('bu.acad.refresh') }));
  expect(keys).toEqual({ a: null, r: null });
  g.assertClean();
});

test('oturum canli ekranda dusunce /akademisyen/giris acilir', async ({ page }) => {
  const st = newState();
  await seedAcadSession(page);
  await installAcademicianFake(page, st);
  await page.goto('/akademisyen/yoklama/5');
  await expect(page.locator('svg[data-qr]')).toBeVisible();
  st.expired = true;
  await expect(page).toHaveURL(/\/akademisyen\/giris/, { timeout: 15_000 });
  expect(page.url()).not.toContain('/admin');
});

test('oturum ayrimi: yonetici girisi akademisyen panelini ACMAZ, tersi de gecerli; anahtarlar ayri', async ({ page }) => {
  const st = newState();
  await seedTheme(page, 'light');
  await installAcademicianFake(page, st);
  await page.route('**/api/admin/me', (r) => r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ id: 1, email: 'boss@bingol.edu.tr', displayName: 'Yonetici', role: 'ADMIN' }) }));
  // yonetici oturumu var, akademisyen yok (ayni sekme/baglam)
  await page.goto('/akademisyen/giris');
  await page.evaluate(() => { sessionStorage.setItem('bu.admin.access', 'adm.a.b'); sessionStorage.setItem('bu.admin.refresh', 'adm-r'); });
  await page.goto('/admin');
  await page.waitForLoadState('domcontentloaded');
  expect(await page.evaluate(() => sessionStorage.getItem('bu.admin.access'))).toBe('adm.a.b');
  await page.goto('/akademisyen');
  await expect(page).toHaveURL(/\/akademisyen\/giris/);
  await expect(page.getByRole('heading', { name: 'Akademisyen girişi' })).toBeVisible();
  const s1 = await page.evaluate(() => ({ adm: sessionStorage.getItem('bu.admin.access'), acad: sessionStorage.getItem('bu.acad.access') }));
  expect(s1.acad).toBeNull();
  expect(s1.adm).toBe('adm.a.b'); // akademisyen paneli yonetici token'ina dokunmadi

  // tersi: akademisyen oturumu acinca /admin acilmaz
  await page.evaluate(() => { sessionStorage.setItem('bu.acad.access', 'a.b.c'); sessionStorage.setItem('bu.acad.refresh', 'r1'); sessionStorage.removeItem('bu.admin.access'); sessionStorage.removeItem('bu.admin.refresh'); });
  await page.goto('/akademisyen');
  await expect(page.getByRole('heading', { name: /Merhaba/ })).toBeVisible();
  await page.goto('/admin');
  await expect(page).toHaveURL(/\/admin\/login|\/admin\/giris/);
  const s2 = await page.evaluate(() => ({ adm: sessionStorage.getItem('bu.admin.access'), acad: sessionStorage.getItem('bu.acad.access') }));
  expect(s2.adm).toBeNull();
  expect(s2.acad).toBe('a.b.c');
});
