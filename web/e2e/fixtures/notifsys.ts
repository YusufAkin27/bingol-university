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
      if (p === '/admin/mail/quota')
        return json(r, {
          mailEnabled: true, enabled: true, limit: 500, reserve: 50, announcementCap: 100, used: 410, remaining: 90,
          announcementRemaining: 40, percent: 82, level: 'WARN', resetHourUtc: 0, dayStart: '2026-11-01T00:00:00Z',
          nextReset: '2026-11-02T00:00:00Z', publicCodeUsed: 33, publicCodeCapRegistration: 100, publicCodeCapReset: 100,
          maxCodesPerEmailPerDay: 5, maxCodeRequestsPerIpPerDay: 20,
          history: [{ date: '2026-10-31', used: 120 }, { date: '2026-10-30', used: 300 }, { date: '2026-10-29', used: 480 }, { date: '2026-10-28', used: 90 }, { date: '2026-10-27', used: 60 }, { date: '2026-10-26', used: 30 }],
          historyNote: '', queue: { pending: 12, failed: 2, dead: 3, skipped: 0, oldestPendingAt: '2026-11-01T09:15:00Z' },
        });
      if (p === '/admin/mail/outbox')
        return json(r, { items: [
          { id: 1, status: 'DEAD', template: 'VERIFICATION_CODE', category: 'TRANSACTIONAL', toMasked: 'a***@bingol.edu.tr', lang: 'tr', attempts: 6, nextAttemptAt: null, createdAt: '2026-10-31T10:00:00Z', sentAt: null, lastError: LONG_ERR, retryable: true, cancellable: false },
          { id: 2, status: 'PENDING', template: 'PASSWORD_RESET_CODE', category: 'TRANSACTIONAL', toMasked: 'b***@bingol.edu.tr', lang: 'tr', attempts: 0, nextAttemptAt: '2026-11-01T10:05:00Z', createdAt: '2026-11-01T10:00:00Z', sentAt: null, lastError: null, retryable: false, cancellable: true },
        ], page: 0, size: 20, total: 2, totalPages: 1, totalItems: 2 });
      if (p === '/admin/settings')
        return json(r, { app_name: 'BU Kampus', maintenance_mode: 'false', banner_text_tr: 'Final haftası: kütüphane 24 saat açık', min_version_android: '2.0.3', latest_version_android: '2.0.5', events_require_approval: 'true' });
      if (p === '/admin/audit')
        return json(r, { items: [
          { id: 1, adminId: 1, adminEmail: 'boss@bingol.edu.tr', method: 'PUT', path: '/api/admin/settings/maintenance_mode', status: 200, at: '2026-11-01T09:30:00Z', ip: '10.0.0.1', targetType: 'SETTING', targetId: 'maintenance_mode', reason: 'Planlı bakım', summary: 'Ayar değiştirildi', requestId: 'req-1' },
          { id: 2, adminId: 1, adminEmail: 'mod@bingol.edu.tr', method: 'POST', path: '/api/admin/academic/exams/9/publish-with-a-very-long-segment-name', status: 403, at: '2026-11-01T09:31:00Z', ip: '10.0.0.2' },
        ], page: 0, size: 20, total: 2, totalPages: 1, totalItems: 2 });
      if (p === '/admin/rbac/admins') return json(r, []);
      if (p === '/admin/push/campaigns')
        return json(r, { items: [
          { id: 1, createdBy: 1, type: 'ANNOUNCEMENT', audience: { type: 'ALL' }, tr: { title: 'Final haftası duyurusu', body: 'Kütüphane final haftasında 24 saat açık olacak, kartınızı yanınızda bulundurun.' }, en: null, ar: null, target: null, status: 'SENDING', scheduledAt: null, startedAt: '2026-11-01T09:00:00Z', finishedAt: null, recipientCount: 2400, audienceSize: 5200, skippedCount: 0, source: 'CAMPAIGN', error: null, createdAt: '2026-11-01T08:59:00Z' },
          { id: 2, createdBy: 1, type: 'NEWS', audience: { type: 'ALL' }, tr: { title: 'Yeni yemek listesi', body: 'Kasım ayı yemek listesi yayında.' }, en: null, ar: null, target: null, status: 'SENT', scheduledAt: null, startedAt: '2026-10-30T09:00:00Z', finishedAt: '2026-10-30T09:05:00Z', recipientCount: 4990, audienceSize: 5200, skippedCount: 210, source: 'CAMPAIGN', error: null, createdAt: '2026-10-30T08:59:00Z' },
          { id: 3, createdBy: 1, type: 'ANNOUNCEMENT', audience: { type: 'ALL' }, tr: { title: 'Hata veren kampanya', body: 'Gönderilemedi.' }, en: null, ar: null, target: null, status: 'FAILED', scheduledAt: null, startedAt: '2026-10-29T09:00:00Z', finishedAt: null, recipientCount: 0, audienceSize: 5200, skippedCount: 0, source: 'CAMPAIGN', error: 'FCM_DISABLED', createdAt: '2026-10-29T08:59:00Z' },
        ], nextCursor: null });
      if (p === '/admin/crashes/summary') return json(r, { newGroups: 4, ackGroups: 2, resolvedGroups: 9, events24h: 260, reopened: 1 });
      if (p === '/admin/crashes')
        return json(r, { items: [
          { id: 1, errorType: 'RangeError', message: 'Invalid value', topFrame: 'package:bu_kampus/features/menu/menu_page.dart:142', status: 'NEW', eventCount: 241, firstSeenAt: '2026-10-30T10:00:00Z', lastSeenAt: '2026-11-01T09:55:00Z', firstVersion: '2.0.4', lastVersion: '2.0.5', reopenCount: 0, statusReason: null, statusBy: null, statusAt: null, fixedInVersion: null, versions: [{ version: '2.0.5', platform: 'ANDROID', count: 200 }, { version: '2.0.4', platform: 'IOS', count: 41 }] },
        ], page: 0, totalPages: 1, totalItems: 1 });
      if (p === '/admin/rbac/matrix')
        return json(r, { profiles: ['FULL', 'MODERATOR', 'VIEWER'], entries: [
          { permission: 'users.read', profiles: ['FULL', 'MODERATOR', 'VIEWER'] },
          { permission: 'users.pii', profiles: ['FULL', 'MODERATOR'] },
          { permission: 'settings.write', profiles: ['FULL'] },
        ] });
      if (p === '/admin/rbac/changes') return json(r, []);
      if (p === '/admin/push/fcm/status') return json(r, { enabled: false, validated: false, projectId: null, error: 'INIT_FAILED:com.google.auth.oauth2.ServiceAccountCredentialsReadException' });
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
