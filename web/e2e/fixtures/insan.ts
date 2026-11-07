/**
 * INSAN: Kullanıcılar grubu (liste, ayrıntı, bekleyen kayıtlar, 2FA) için backendsiz /api taklidi.
 * `stubPeople` üstüne bindirilir (Playwright'ta sonradan kaydedilen yol önceliklidir): kırılım, 2FA özeti/listesi ve
 * "dikkat gerektirenler" sayıları burada.
 */
import type { Page, Route } from '@playwright/test';
import { stubPeople, type Scenario } from './people';

const json = (r: Route, body: unknown, status = 200) =>
  r.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
const iso = (backDays: number) => new Date(Date.now() - backDays * 86_400_000).toISOString();

const BREAKDOWNS: Record<string, { key: string; label: string; count: number }[]> = {
  status: [
    { key: 'ACTIVE', label: 'ACTIVE', count: 12400 },
    { key: 'SUSPENDED', label: 'SUSPENDED', count: 37 },
    { key: 'DELETED', label: 'DELETED', count: 403 },
  ],
  role: [
    { key: 'USER', label: 'USER', count: 12828 },
    { key: 'ADMIN', label: 'ADMIN', count: 12 },
  ],
  faculty: [
    { key: 'm', label: 'Mühendislik ve Mimarlık Fakültesi', count: 2500 },
    { key: 'i', label: 'İktisadi ve İdari Bilimler Fakültesi', count: 2100 },
    { key: 'e', label: 'Eğitim Fakültesi', count: 1900 },
    { key: 'f', label: 'Fen-Edebiyat Fakültesi', count: 1500 },
    { key: 'h', label: 'Sağlık Bilimleri Fakültesi', count: 900 },
    { key: 'unknown', label: '', count: 800 },
  ],
};

const tfRow = (id: number, name: string, daysAgo: number, devices: number) => ({
  userId: id,
  displayName: name,
  email: `ogrenci${id}@bingol.edu.tr`,
  role: id === 1 ? 'ADMIN' : 'USER',
  enabledAt: iso(daysAgo),
  trustedDeviceCount: devices,
  lastLoginAt: iso(daysAgo / 2),
});

export async function stubInsan(page: Page, scenario: Scenario = 'full', dark = false) {
  await stubPeople(page, scenario, dark);
  const empty = scenario === 'empty';
  const fail = scenario === 'error';
  await page.route(
    (u) => u.pathname.startsWith('/api/admin/analytics/breakdown'),
    (r) => {
      const dim = new URL(r.request().url()).searchParams.get('dimension') ?? 'faculty';
      if (fail) return json(r, { code: 'SERVER_ERROR', message: 'x' }, 500);
      const items = empty ? [] : BREAKDOWNS[dim] ?? [];
      const total = items.reduce((s, i) => s + i.count, 0);
      return json(r, { dimension: dim, total, items: items.map((i) => ({ ...i, percent: total ? (i.count * 100) / total : 0 })) });
    },
  );
  await page.route(
    (u) => u.pathname === '/api/admin/two-factor/summary',
    (r) =>
      fail
        ? json(r, { code: 'SERVER_ERROR', message: 'x' }, 500)
        : json(r, empty
            ? { enabledCount: 0, totalActiveUsers: 12400, enabledPercent: 0, enabledLast7Days: 0, trustedDeviceTotal: 0 }
            : { enabledCount: 1860, totalActiveUsers: 12400, enabledPercent: 15, enabledLast7Days: 142, trustedDeviceTotal: 2410 }),
  );
  await page.route(
    (u) => u.pathname === '/api/admin/two-factor/users',
    (r) => {
      if (fail) return json(r, { code: 'SERVER_ERROR', message: 'x' }, 500);
      const rows = empty
        ? []
        : [
            tfRow(1, 'Yönetici Bir', 0.5, 2),
            tfRow(3, 'Ayşe Yılmaz', 2, 1),
            tfRow(2, 'Mehmet Can Öztürk', 5, 3),
            tfRow(8, 'محمد علي', 9, 1),
            tfRow(9, 'Zeynep Kaya', 12, 2),
            tfRow(10, 'Ali Demir', 20, 1),
            tfRow(11, 'Elif Şahin', 27, 1),
            tfRow(12, 'Burak Aydın', 36, 2),
            tfRow(13, 'Selin Arslan', 44, 1),
          ];
      return json(r, { content: rows, totalElements: rows.length, totalPages: rows.length ? 1 : 0, number: 0, size: 100 });
    },
  );
  // "Yönetici + 2FA kapalı" sayacı: size=1 sorgusu totalItems taşır
  await page.route(
    (u) => u.pathname === '/api/admin/users',
    (r) => {
      const sp = new URL(r.request().url()).searchParams;
      if (sp.get('size') === '1' && !fail)
        return json(r, { items: [], page: 0, size: 1, totalItems: empty ? 0 : 3, total: empty ? 0 : 3, totalPages: empty ? 0 : 3 });
      return r.fallback();
    },
  );
}
