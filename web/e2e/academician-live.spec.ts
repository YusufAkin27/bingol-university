/**
 * Canli yoklama ekrani (BACKEND'SIZ; `live` ucu GERCEK saatle degisen kodlar dondurur): QR adim sinirinda degisir, sunucu saat farki
 * (istemci saati yanlis) dogru kodu secer, ~10 sn basarisiz yoklamadan sonra QR gizlenir ve toparlanir, sekme gizliyken yoklama durur,
 * "Kayitli degil" kabul/yok say, 400 kayitli buyuk yanit, kapat/yeniden ac, projeksiyon kipi, kullanici eylemleri.
 *   cd web && npx playwright test academician-live.spec.ts
 */
import { expect, test, type Page } from '@playwright/test';
import { codeFor, guardConsole, hOverflow, installAcademicianFake, newState, seedAcadSession, stepOf, type FakeState } from './academician-fake';

async function open(page: Page, over: Partial<FakeState> = {}, width = 1440) {
  const st = newState(over);
  const g = guardConsole(page, st);
  await page.setViewportSize({ width, height: 900 });
  await seedAcadSession(page);
  await installAcademicianFake(page, st);
  await page.goto('/akademisyen/yoklama/5');
  await expect(page.locator('svg[data-qr]')).toBeVisible();
  return { st, g };
}

const qrValue = (page: Page) => page.locator('svg[data-qr]').getAttribute('data-qr', { timeout: 500 }).catch(() => null);

test('QR adim sinirinda (5 sn) degisir ve her zaman o anki sunucu adimina aittir; geri sayim azalir', async ({ page }) => {
  const { g } = await open(page);
  const seen: string[] = [];
  const t0 = Date.now();
  while (Date.now() - t0 < 13_000) {
    const v = await qrValue(page);
    const nowStep = await page.evaluate(() => Math.floor(Date.now() / 5000));
    if (v) {
      // gosterilen kod, yerel saat (== sunucu saati, sapma yok) adimina uyar; +-1 adim: okuma ile sayfa saati arasi
      const shown = Number(v.split('.')[1]);
      expect(Math.abs(shown - nowStep)).toBeLessThanOrEqual(1);
      if (seen[seen.length - 1] !== v) seen.push(v);
    }
    await page.waitForTimeout(150);
  }
  expect(seen.length).toBeGreaterThanOrEqual(2); // 13 sn >= 2 sinir
  expect(seen.length).toBeLessThanOrEqual(4);
  // kodlar ardisik adimlar (atlama yok)
  const steps = seen.map((v) => Number(v.split('.')[1]));
  for (let i = 1; i < steps.length; i++) expect(steps[i] - steps[i - 1]).toBe(1);
  await expect(page.getByText(/Kod \d sn sonra değişir/)).toBeVisible();
  g.assertClean();
});

test('istemci saati 3 dk ileri/geri olsa da sunucu saatine gore dogru kod gosterilir', async ({ page }) => {
  for (const skew of [180_000, -180_000]) {
    const st = newState({ skewMs: skew });
    await seedAcadSession(page);
    await installAcademicianFake(page, st);
    await page.goto('/akademisyen/yoklama/5');
    await expect(page.locator('svg[data-qr]')).toBeVisible();
    const v = (await qrValue(page))!;
    const serverStep = stepOf(Date.now() + skew);
    expect(Math.abs(Number(v.split('.')[1]) - serverStep)).toBeLessThanOrEqual(1);
    expect(v).not.toBe(codeFor(stepOf(Date.now())));
    await page.unrouteAll({ behavior: 'ignoreErrors' });
  }
});

test('baglanti kopunca ~10 sn sonra QR gizlenir, "Baglanti bekleniyor"; baglanti gelince geri doner', async ({ page }) => {
  const { st } = await open(page);
  st.live = 'fail';
  const t0 = Date.now();
  await expect(page.locator('svg[data-qr]')).toBeHidden({ timeout: 16_000 });
  const gone = Date.now() - t0;
  expect(gone).toBeGreaterThan(5_000); // hemen degil (gecici dalgalanmada QR titremesin)
  expect(gone).toBeLessThan(15_000); // ama ~10 sn
  await expect(page.getByText('Bağlantı bekleniyor')).toBeVisible();
  // gizliyken DOM'da eski kod kalmamali
  expect(await page.locator('[data-qr]').count()).toBe(0);
  const r0 = Date.now();
  st.live = 'ok';
  await expect(page.locator('svg[data-qr]')).toBeVisible({ timeout: 8_000 });
  expect(Date.now() - r0).toBeLessThan(6_000); // bir sonraki yoklamada (2,5 sn) doner
});

test('sekme gizliyken yoklama DURUR; gorunur olunca hemen yeniden baslar', async ({ page }) => {
  const { st } = await open(page);
  const hide = (hidden: boolean) =>
    page.evaluate((h) => {
      Object.defineProperty(document, 'hidden', { value: h, configurable: true });
      Object.defineProperty(document, 'visibilityState', { value: h ? 'hidden' : 'visible', configurable: true });
      document.dispatchEvent(new Event('visibilitychange'));
    }, hidden);
  await page.waitForTimeout(300);
  await hide(true);
  await page.waitForTimeout(400); // surmekte olan istek bitsin
  const before = st.livePolls;
  await page.waitForTimeout(7_000);
  expect(st.livePolls - before, 'gizliyken yoklama sayisi').toBeLessThanOrEqual(0);
  await hide(false);
  await expect.poll(() => st.livePolls, { timeout: 1_500 }).toBeGreaterThan(before); // hemen
  await expect(page.locator('svg[data-qr]')).toBeVisible({ timeout: 4_000 });
});

test('"Kayitli degil" listesi: kabul eder (derse ekle + var say) ve yok sayar', async ({ page }) => {
  const second = { studentId: 42, displayName: 'İkinci Kişi', studentNo: null, faculty: null, department: 'Hukuk', grade: '1', scannedAt: new Date().toISOString() };
  const { st, g } = await open(page);
  st.pending.push(second);
  await expect(page.getByRole('heading', { name: /Kayıtlı değil/ })).toBeVisible();
  await expect(page.getByText('İkinci Kişi')).toBeVisible({ timeout: 6_000 });
  await page.getByRole('button', { name: 'Kayıtsız Kişi öğrencisini derse ekle ve var say' }).click();
  await expect(page.getByText('Kayıtsız Kişi derse eklendi ve var sayıldı.')).toBeVisible();
  await expect(page.getByText('Kayıtsız Kişi').first()).toBeHidden({ timeout: 6_000 });
  await page.getByRole('button', { name: 'İkinci Kişi isteğini yok say' }).click();
  await expect(page.getByText('İkinci Kişi isteği yok sayıldı.')).toBeVisible();
  await expect(page.getByRole('heading', { name: /Kayıtlı değil/ })).toBeHidden({ timeout: 6_000 });
  expect(st.calls).toContain('POST /academician/sessions/5/pending/41/accept');
  expect(st.calls).toContain('POST /academician/sessions/5/pending/42/dismiss');
  g.assertClean();
});

test('400 kayitli buyuk canli yanit: sayfa kaymaz, liste ve sayac dogru, yoklama sikligi korunur', async ({ page }) => {
  const { st, g } = await open(page, { liveRecordCount: 400 });
  await expect(page.getByRole('heading', { name: /Katılanlar \(400\)/ })).toBeVisible();
  const o = await hOverflow(page);
  expect(o.sw).toBeLessThanOrEqual(o.cw);
  const p0 = st.livePolls;
  await page.waitForTimeout(6_000);
  expect(st.livePolls - p0).toBeGreaterThanOrEqual(2);
  expect(st.livePolls - p0).toBeLessThanOrEqual(4);
  // QR 400 satirla da akici degisiyor mu: iki farkli deger
  const a = await qrValue(page);
  await page.waitForTimeout(5_200);
  expect(await qrValue(page)).not.toBe(a);
  g.assertClean();
});

test('yoklamayi kapat -> kapali ekran; yeniden ac -> QR geri gelir', async ({ page }) => {
  const { g } = await open(page);
  await page.getByRole('button', { name: 'Yoklamayı kapat' }).click();
  const dlg = page.getByRole('alertdialog').or(page.getByRole('dialog'));
  await expect(dlg.first()).toBeVisible();
  await dlg.first().getByRole('button', { name: 'Yoklamayı kapat' }).click();
  await expect(page.getByText('Yoklama kapalı').first()).toBeVisible({ timeout: 6_000 });
  await expect(page.locator('svg[data-qr]')).toHaveCount(0);
  await page.getByRole('button', { name: 'Yeniden aç' }).first().click();
  await expect(page.locator('svg[data-qr]')).toBeVisible({ timeout: 8_000 });
  g.assertClean();
});

test('elle var say: arama + kayit kaldirma onayi (Escape odagi dugmeye dondurur)', async ({ page }) => {
  const { st, g } = await open(page);
  await page.getByLabel('Öğrenci ara').fill('Zeynep');
  await expect(page.getByRole('list', { name: 'Arama sonuçları' })).toBeVisible();
  await page.getByLabel('Öğrenci ara').fill('zzzzz');
  await expect(page.getByText('Eşleşen, henüz katılmamış öğrenci yok.')).toBeVisible();
  // kayit kaldir: onay penceresi, Escape ile kapanir, odak tetikleyiciye doner
  const trigger = page.getByRole('button', { name: /yoklama kaydını kaldır/ }).first();
  await trigger.focus();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('alertdialog')).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('alertdialog')).toBeHidden();
  await expect(trigger).toBeFocused();
  expect(st.calls.filter((c) => c.startsWith('DELETE'))).toEqual([]);
  g.assertClean();
});

for (const width of [1440, 390]) {
  test(`projeksiyon kipi ${width}px: QR gorunum alanina sigar, Escape ile kapanir`, async ({ page }) => {
    await open(page, {}, width);
    await page.getByRole('button', { name: 'Projeksiyon kipi' }).click();
    const dlg = page.getByRole('dialog', { name: /Projeksiyon kipi/ });
    await expect(dlg).toBeVisible();
    const qr = dlg.locator('svg[data-qr]');
    await expect(qr).toBeVisible();
    const vp = page.viewportSize()!;
    const box = (await qr.boundingBox())!;
    expect(box.x).toBeGreaterThanOrEqual(0);
    expect(box.y).toBeGreaterThanOrEqual(0);
    expect(box.x + box.width).toBeLessThanOrEqual(vp.width + 1);
    expect(box.y + box.height).toBeLessThanOrEqual(vp.height + 1);
    expect(box.width).toBeGreaterThan(Math.min(vp.width, vp.height) * 0.4); // okunur boyutta
    // projeksiyon sirasinda sayfadaki ikinci QR yok (tek QR)
    expect(await page.locator('svg[data-qr]').count()).toBe(1);
    await page.keyboard.press('Escape');
    await expect(dlg).toBeHidden();
    await expect(page.locator('svg[data-qr]')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Projeksiyon kipi' })).toBeFocused();
  });
}
