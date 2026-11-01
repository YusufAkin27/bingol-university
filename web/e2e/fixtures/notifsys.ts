/**
 * NOTIF: Bildirimler + Sistem sayfalari icin backendsiz /api taklidi (gorsel dogrulama).
 * Yalniz `import type` + saf TS (node --experimental-strip-types ile de calisir). Senaryo: full | empty | error.
 */
import type { Page, Route } from '@playwright/test';

export type Scenario = 'full' | 'empty' | 'error';

const json = (r: Route, body: unknown, status = 200) =>
  r.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

const PERMS = [
  'dashboard.read', 'analytics.read', 'users.read', 'users.pii', 'users.write', 'moderation.read', 'moderation.write',
  'chat.read', 'content.read', 'content.write', 'support.read', 'support.write', 'comms.read', 'comms.write', 'comms.send',
  'legal.read', 'settings.read', 'settings.write', 'system.read', 'system.write', 'audit.read', 'rbac.manage',
  'data.retention.read', 'data.retention.export', 'data.retention.purge', 'admin.full',
];

const OVERVIEW_FULL = {
  generatedAt: '2026-11-01T10:00:00Z',
  overall: 'CRIT',
  indicators: {
    'mail.dead': { status: 'WARN', value: 3, threshold: { warn: 1, crit: 20 }, message: '3 e-posta gönderilemedi' },
    'mail.pending': { status: 'OK', value: 12, threshold: null, message: null },
    'mail.oldestPendingAge': { status: 'OK', value: 0, threshold: { warn: 600, crit: 1800 }, message: null },
    'mail.dailyQuota': { status: 'WARN', value: 82, threshold: { warn: 80, crit: 95 }, message: 'Günlük e-posta kotası %82 doldu' },
    'push.dead': { status: 'OK', value: 0, threshold: { warn: 1, crit: 20 }, message: null },
    'push.pending': { status: 'OK', value: 4, threshold: null, message: null },
    'push.oldestPendingAge': { status: 'CRIT', value: 4200, threshold: { warn: 600, crit: 1800 }, message: 'Push bildirimleri 70 dakikadır gecikiyor' },
    'campaign.overdue': { status: 'OK', value: 0, threshold: { warn: 600, crit: 1800 }, message: null },
    'campaign.counts': { status: 'OK', value: { SCHEDULED: 2, SENDING: 1, SENT: 40, FAILED: 1 }, threshold: null, message: null },
    'websocket.sessions': { status: 'OK', value: 128, threshold: null, message: null },
    db: { status: 'OK', value: 7, threshold: null, message: null },
    redis: { status: 'OK', value: 2, threshold: null, message: null },
    fcm: { status: 'UNKNOWN', value: null, threshold: null, message: 'Push sağlayıcı kapalı (kimlik girilmemiş)' },
    'disk.storage': { status: 'WARN', value: 83.4, threshold: { warn: 80, crit: 90 }, message: 'Disk %83,4 dolu' },
    storage: { status: 'WARN', value: 83.4, threshold: { warn: 80, crit: 90 }, message: 'Depolama %83,4 dolu' },
    'backup.age': { status: 'OK', value: 6.5, threshold: { warn: 26, crit: 50 }, message: null },
    'jobs.news-sync': { status: 'OK', value: 36000, threshold: { warn: 129600, crit: 259200 }, message: null },
    'jobs.menu-sync': { status: 'OK', value: 864000, threshold: { warn: 3000000, crit: 4000000 }, message: null },
    'jobs.mail-queue': { status: 'OK', value: 5, threshold: { warn: 120, crit: 360 }, message: null },
    'jobs.push-queue': { status: 'OK', value: 4, threshold: { warn: 120, crit: 360 }, message: null },
    'jobs.storage-alert': { status: 'OK', value: 600, threshold: { warn: 3600, crit: 7200 }, message: null },
    'jobs.mail-purge': { status: 'OK', value: 40000, threshold: { warn: 129600, crit: 259200 }, message: null },
  },
};

const OVERVIEW_OK = {
  generatedAt: '2026-11-01T10:00:00Z',
  overall: 'OK',
  indicators: Object.fromEntries(
    Object.entries(OVERVIEW_FULL.indicators).map(([k, v]) => [k, { ...v, status: v.status === 'UNKNOWN' ? 'OK' : 'OK', message: null }]),
  ),
};

const LONG_ERR =
  'java.net.SocketTimeoutException: Read timed out while talking to smtp.example.invalid:587 after 30000 ms (connect timeout 10000) at com.sun.mail.smtp.SMTPTransport.readServerResponse';

export async function stubNotifsys(page: Page, scenario: Scenario = 'full', calls: string[] = []) {
  await page.addInitScript(() => {
    sessionStorage.setItem('bu.admin.access', 'a.b.c');
    sessionStorage.setItem('bu.admin.refresh', 'r1');
    localStorage.setItem('bu.lang', 'tr');
  });
  await page.route(
    (u) => u.pathname.startsWith('/api/'),
    (r) => {
      const u = new URL(r.request().url());
      const p = u.pathname.replace(/^\/api/, '');
      calls.push(`${r.request().method()} ${p}`);
      if (p === '/admin/me') return json(r, { id: 1, email: 'boss@bingol.edu.tr', displayName: 'Yonetici', role: 'ADMIN' });
      if (p === '/admin/rbac/me')
        return json(r, { userId: 1, email: 'boss@bingol.edu.tr', displayName: 'Yonetici', profile: 'FULL', pinned: true, permissions: PERMS });
      if (p === '/admin/system/overview') {
        if (scenario === 'error') return json(r, { code: 'INTERNAL', message: 'x' }, 500);
        return json(r, scenario === 'empty' ? OVERVIEW_OK : OVERVIEW_FULL);
      }
      if (p === '/admin/system/dead-letters/mail') {
        if (scenario === 'error') return json(r, { code: 'INTERNAL', message: 'x' }, 500);
        return json(
          r,
          scenario === 'empty'
            ? []
            : [
                { id: 7, template: 'VERIFICATION_CODE', to: 'a***@bingol.edu.tr', attempts: 8, lastError: LONG_ERR, createdAt: '2026-10-31T10:00:00Z' },
                { id: 8, template: 'PASSWORD_RESET', to: 'b***@bingol.edu.tr', attempts: 8, lastError: 'SMTP 550', createdAt: '2026-10-31T11:00:00Z' },
              ],
        );
      }
      if (p === '/admin/system/dead-letters/push') return json(r, []);
      return json(r, { code: "NOT_FOUND", message: "yok" }, 404);
    },
  );
}
