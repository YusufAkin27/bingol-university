/**
 * Akademisyen paneli ana yolculuk (BACKEND'SIZ; /api page.route ile taklit): giriş yapılmış onaylı akademisyen -> pano -> ders ->
 * canlı yoklama (QR görünür, yatay kayma yok) -> bağlantı kopunca QR gizlenir. 1440 ve 390 px, açık ve koyu tema.
 *   cd web && npx playwright test academician.spec.ts
 */
import { expect, test, type Page, type Route } from '@playwright/test';

const json = (route: Route, body: unknown, status = 200) =>
  route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

const ME = { status: 'APPROVED', approvalMode: 'AUTO', title: 'Dr.', firstName: 'Deneme', lastName: 'Hoca', unit: null, rejectReason: null };
const COURSE = {
  id: 7, code: 'BIL101', name: 'Veri Yapıları', term: '2026-2027 Güz', faculty: null, department: 'Bilgisayar Mühendisliği', grade: '2',
  limit: { type: null, value: null }, absenceLimitType: null, absenceLimitValue: null, status: 'ACTIVE',
  slots: [{ id: 1, dayOfWeek: 1, startTime: '09:00', endTime: '09:50', room: 'A-101' }], enrolledCount: 2, sessionCount: 1, createdAt: '2026-09-20T08:00:00Z',
};

async function stub(page: Page, state: { offline: boolean }) {
  await page.route((u) => u.pathname.startsWith('/api/'), (r) => {
    const p = new URL(r.request().url()).pathname.replace(/^\/api/, '');
    if (p === '/academician/me') return json(r, ME);
    if (p === '/academician/courses') return json(r, [COURSE]);
    if (p === '/academician/courses/7') return json(r, COURSE);
    if (p === '/academician/courses/7/sessions') return json(r, []);
    if (p === '/academician/courses/7/attendance') return json(r, { sessions: [], students: [], limit: { type: null, value: null } });
    if (p === '/academician/courses/7/notices') return json(r, { items: [], nextCursor: null });
    if (p === '/academician/courses/7/enrollments') return json(r, []);
    if (p === '/academician/sessions/5') return json(r, { id: 5, courseId: 7, slotId: null, lessonDate: '2026-11-14', openedAt: '2026-11-14T08:00:00Z', expiresAt: '2026-11-14T11:00:00Z', closedAt: null, status: 'OPEN', presentCount: 1, enrolledCount: 2, pendingScans: [] });
    if (p === '/academician/sessions/5/live') {
      if (state.offline) return r.abort('connectionrefused');
      const now = Date.now();
      const step = Math.floor(now / 5000);
      const w = (s: number) => ({ code: `bingol-lesson:5.${s}.abcDEF123_-`, fromMs: s * 5000, untilMs: (s + 1) * 5000 });
      return json(r, {
        status: 'OPEN', serverNowMs: now, stepSeconds: 5, codes: [w(step), w(step + 1), w(step + 2)], presentCount: 1, enrolledCount: 2,
        newRecords: [{ id: 1, studentId: 11, displayName: 'Ayşe Örnek', studentNo: '2024000011', method: 'QR', markedAt: new Date().toISOString(), revoked: false }],
        pendingScans: [{ studentId: 41, displayName: 'Kayıtsız Kişi', studentNo: null, faculty: null, department: null, grade: null, scannedAt: new Date().toISOString() }],
      });
    }
    return json(r, { code: 'NOT_FOUND', message: 'yok' }, 404);
  });
}

for (const [width, height] of [[1440, 900], [390, 844]] as const) {
  for (const theme of ['light', 'dark'] as const) {
    test(`akademisyen yolculuğu ${width}px ${theme}`, async ({ page }) => {
      const state = { offline: false };
      await page.setViewportSize({ width, height });
      await page.addInitScript((t) => {
        sessionStorage.setItem('bu.acad.access', 'a.b.c');
        sessionStorage.setItem('bu.acad.refresh', 'r1');
        localStorage.setItem('bu.theme', t);
        localStorage.setItem('bu.cookies', 'ack:v1');
      }, theme);
      await stub(page, state);

      await page.goto('/akademisyen');
      await expect(page.getByRole('heading', { name: /Merhaba/ })).toBeVisible();
      await page.getByRole('link', { name: /Derslerim/ }).first().click();
      await page.getByRole('link', { name: /Veri Yapıları/ }).click();
      await expect(page.getByRole('tab', { name: 'Program' })).toBeVisible();
      await page.getByRole('tab', { name: 'Duyurular' }).click();
      await expect(page.getByLabel('Duyuru türü')).toBeVisible();

      await page.goto('/akademisyen/yoklama/5');
      const qr = page.locator('svg[data-qr]');
      await expect(qr).toBeVisible();
      await expect(page.getByRole('heading', { name: /Kayıtlı değil/ })).toBeVisible();
      await expect(page.getByText('Ayşe Örnek').first()).toBeVisible();
      // QR açık plaka üstünde: koyu modül rengi ile plaka rengi farklı (her iki temada taranabilir)
      const colors = await qr.evaluate((el) => ({ fg: getComputedStyle(el).color, bg: getComputedStyle(el.parentElement!).backgroundColor }));
      expect(colors.bg).toBe('rgb(255, 255, 255)');
      expect(colors.fg).not.toBe(colors.bg);
      // yatay kayma yok
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);

      // bağlantı kopar: 10 sn sonra QR gizlenir
      state.offline = true;
      await expect(qr).toBeHidden({ timeout: 16_000 });
      await expect(page.getByText('Bağlantı bekleniyor')).toBeVisible();
      state.offline = false;
      await expect(qr).toBeVisible({ timeout: 8_000 });
    });
  }
}
