/**
 * Backendsiz yonetim paneli taklidi (W2-K): /api istekleri page.route ile yanitlanir. Profil izinleri backend
 * `PermissionMatrix` ile birebir aynidir (degisirse src/layouts/navPolicy.test.ts de uyarir).
 */
import type { Page, Route } from '@playwright/test';

export type Profile = 'FULL' | 'MODERATOR' | 'SUPPORT' | 'EDITOR' | 'VIEWER';

const GRANTS: Record<string, Profile[]> = {
  'dashboard.read': ['FULL', 'MODERATOR', 'SUPPORT', 'EDITOR', 'VIEWER'],
  'analytics.read': ['FULL', 'MODERATOR', 'SUPPORT', 'EDITOR', 'VIEWER'],
  'users.read': ['FULL', 'MODERATOR', 'SUPPORT', 'VIEWER'],
  'users.pii': ['FULL', 'MODERATOR'],
  'users.write': ['FULL', 'MODERATOR'],
  'users.role': ['FULL'],
  'users.delete': ['FULL'],
  'users.export': ['FULL'],
  'users.verify': ['FULL'],
  'moderation.read': ['FULL', 'MODERATOR', 'VIEWER'],
  'moderation.write': ['FULL', 'MODERATOR'],
  'chat.read': ['FULL', 'MODERATOR'],
  'chat.write': ['FULL', 'MODERATOR'],
  'content.read': ['FULL', 'MODERATOR', 'SUPPORT', 'EDITOR', 'VIEWER'],
  'content.write': ['FULL', 'EDITOR'],
  'content.hide': ['FULL', 'EDITOR', 'MODERATOR'],
  'support.read': ['FULL', 'SUPPORT', 'VIEWER'],
  'support.write': ['FULL', 'SUPPORT'],
  'comms.read': ['FULL', 'SUPPORT', 'EDITOR', 'VIEWER'],
  'comms.write': ['FULL', 'EDITOR'],
  'comms.send': ['FULL'],
  'comms.single': ['FULL', 'SUPPORT'],
  'comms.announce': ['FULL', 'EDITOR'],
  'legal.read': ['FULL', 'MODERATOR', 'SUPPORT', 'EDITOR', 'VIEWER'],
  'legal.publish': ['FULL'],
  'settings.read': ['FULL', 'VIEWER'],
  'settings.write': ['FULL'],
  'system.read': ['FULL', 'VIEWER'],
  'system.write': ['FULL'],
  'audit.read': ['FULL', 'VIEWER'],
  'rbac.manage': ['FULL'],
  'data.retention.read': ['FULL', 'VIEWER'],
  'data.retention.export': ['FULL'],
  'data.retention.purge': ['FULL'],
  'admin.full': ['FULL'],
};

export const permsOf = (p: Profile): string[] =>
  Object.entries(GRANTS)
    .filter(([, ps]) => ps.includes(p))
    .map(([k]) => k);

export const json = (route: Route, body: unknown, status = 200) =>
  route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

const page0 = <T>(items: T[]) => ({
  items,
  page: 0,
  size: 20,
  total: items.length,
  totalPages: 1,
  totalItems: items.length,
});

const LONG_PATH = '/api/admin/academic/exams/999999999/publish-with-a-very-long-segment-name/and/more/segments/to/force/overflow';
const LONG_ERR = 'java.net.SocketTimeoutException: Read timed out while talking to smtp.example.invalid:587 after 30000 ms';

/** Her profil icin /api taklidi. Taklit edilmeyen /api istekleri 404; istekler `calls` listesine yazilir. */
export async function stubPanel(page: Page, profile: Profile = 'FULL', calls: string[] = []) {
  const perms = permsOf(profile);
  await page.addInitScript(() => {
    sessionStorage.setItem('bu.admin.access', 'a.b.c');
    sessionStorage.setItem('bu.admin.refresh', 'r1');
    localStorage.setItem('bu.lang', 'tr');
  });
  await page.route(
    (u) => u.pathname.startsWith('/api/'),
    (r) => {
      const u = new URL(r.request().url());
      const m = r.request().method();
      const p = u.pathname.replace(/^\/api/, '');
      calls.push(`${m} ${p}`);
      const deny = (perm: string) => !perms.includes(perm);
      const forbid = () => json(r, { code: 'ADMIN_PERMISSION_DENIED', message: 'Yetkiniz yok' }, 403);
      if (p === '/admin/me') return json(r, { id: 1, email: 'boss@bingol.edu.tr', displayName: 'Yonetici', role: 'ADMIN' });
      if (p === '/admin/rbac/me')
        return json(r, {
          userId: 1, email: 'boss@bingol.edu.tr', displayName: 'Yonetici', profile, pinned: profile === 'FULL', permissions: perms,
        });
      if (p === '/admin/rbac/matrix')
        return json(r, {
          profiles: ['FULL', 'MODERATOR', 'SUPPORT', 'EDITOR', 'VIEWER'],
          entries: Object.entries(GRANTS).map(([permission, profiles]) => ({ permission, profiles })),
        });
      if (p === '/admin/rbac/admins')
        return json(r, [
          { id: 1, email: 'boss.with.a.very.long.address.for.overflow.test@bingol.edu.tr', displayName: 'Yonetici', profile: 'FULL', pinned: true, status: 'ACTIVE', lastSeenAt: null },
        ]);
      if (p === '/admin/rbac/changes') return json(r, []);
      if (p === '/admin/audit') {
        if (deny('audit.read')) return forbid();
        return json(
          r,
          page0([
            { id: 1, adminId: 1, adminEmail: 'boss@bingol.edu.tr', method: 'POST', path: LONG_PATH, status: 403, at: '2026-10-30T10:00:00Z', ip: '10.0.0.1', targetType: 'EXAM', targetId: '999999999', reason: 'Gerekce metni uzun uzun uzun', summary: 'Ozet', requestId: 'req-1' },
            { id: 2, adminId: 1, adminEmail: 'boss@bingol.edu.tr', method: 'GET', path: '/api/admin/users', status: 200, at: '2026-10-30T10:01:00Z', ip: '10.0.0.1' },
          ]),
        );
      }
      if (p === '/admin/mail/outbox')
        return json(
          r,
          { ...page0([
            { id: 1, status: 'DEAD', template: 'VERIFICATION_CODE', category: 'TRANSACTIONAL', toMasked: 'a***@bingol.edu.tr', lang: 'tr', attempts: 6, nextAttemptAt: null, createdAt: '2026-10-30T10:00:00Z', sentAt: null, lastError: LONG_ERR, retryable: true, cancellable: false },
          ]) },
        );
      if (p === '/admin/mail/quota')
        return json(r, {
          mailEnabled: true, enabled: true, limit: 500, reserve: 50, announcementCap: 100, used: 120, remaining: 380, announcementRemaining: 100, percent: 24, level: 'OK',
          resetHourUtc: 0, dayStart: '2026-10-30T00:00:00Z', nextReset: '2026-10-31T00:00:00Z', publicCodeUsed: 3, publicCodeCapRegistration: 100, publicCodeCapReset: 100,
          maxCodesPerEmailPerDay: 5, maxCodeRequestsPerIpPerDay: 20, history: [{ date: '2026-10-29', used: 100 }], historyNote: '', queue: { pending: 1, failed: 0, dead: 1, skipped: 0, oldestPendingAt: null },
        });
      if (p === '/admin/access-bans/stats') return json(r, { activeBans: { IP: 12, DEVICE: 3, CIDR: 1 }, blockedAttemptsLast24h: 1234567, anonymizerRanges: 98765 });
      if (p === '/admin/access-bans')
        return json(r, { items: [{ id: 1, kind: 'IP', value: '203.0.113.7', valueShort: '203.0.113.7', note: 'n'.repeat(120), reasonCode: 'ABUSE', createdAt: '2026-10-30T10:00:00Z', active: true, hitCount: 3 }], nextCursor: null });
      if (p === '/admin/access-bans/anonymizers') return json(r, { enforced: true, total: 10, bySource: { tor: 5, vpn: 5 } });
      if (p === '/admin/push/fcm/status')
        return json(r, { enabled: false, validated: false, projectId: 'bingol-kampus-very-long-firebase-project-id-0123456789', error: 'INIT_FAILED:com.google.auth.oauth2.ServiceAccountCredentialsReadException' });
      if (p === '/admin/push/outbox/stats') return json(r, { enabled: true, holdWhenDisabled: false, pending: 1, sending: 0, failed: 2, dead: 3, sentLast24h: 1000, oldestPendingAgeSeconds: 10, oldestPendingAt: null });
      if (p === '/admin/push/outbox')
        return json(r, page0([
          { id: 1, status: 'DEAD', type: 'ANNOUNCEMENT', campaignId: 4, targetRef: 'a1b2c3d4...', userRef: '1***5', attempts: 5, errorCode: 'THIRD_PARTY_AUTH_ERROR', nextAttemptAt: null, createdAt: '2026-10-30T10:00:00Z', sentAt: null },
          { id: 2, status: 'DEAD', type: 'MESSAGE', campaignId: null, targetRef: 'a1b2c3d5...', userRef: '1***6', attempts: 5, errorCode: 'UNREGISTERED', nextAttemptAt: null, createdAt: '2026-10-30T10:00:00Z', sentAt: null },
        ]));
      if (p === '/admin/push/devices/summary')
        return json(r, { totalTokens: 100, usersWithDevice: 80, byPlatform: { android: 60, ios: 30, web: 5, other: 5 }, byAppVersion: [{ version: '2.0.3+20003', count: 50 }], activeLast7d: 70, staleOver30d: 10 });
      if (p === '/admin/notifications/stats') return json(r, { days: 14, series: [], readRate: 0.5, created: 10, read: 5, byType: [], totalRows: 10, unreadRows: 5 });
      if (/^\/admin\/users\/\d+$/.test(p) && m === 'GET') return json(r, null, 404);
      return json(r, { code: 'NOT_FOUND', message: 'yok' }, 404);
    },
  );
}

/** Sayfa gorunur alandan tasiyor mu (kendi kaydirma kabugu icindekiler sayilmaz). */
export async function pageOverflow(page: Page): Promise<{ sw: number; cw: number; offenders: string[] }> {
  return page.evaluate(() => {
    const de = document.documentElement;
    const cw = de.clientWidth;
    const out: string[] = [];
    for (const el of Array.from(document.body.querySelectorAll('*'))) {
      const rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) continue;
      if (rect.right > cw + 1) {
        let p: Element | null = el.parentElement;
        let clipped = false;
        while (p && p !== document.body) {
          const o = getComputedStyle(p).overflowX;
          if (o === 'auto' || o === 'scroll' || o === 'hidden') {
            clipped = true;
            break;
          }
          p = p.parentElement;
        }
        if (!clipped && out.length < 8)
          out.push(`${el.tagName.toLowerCase()}.${String((el as HTMLElement).className).slice(0, 50)} [${Math.round(rect.left)}..${Math.round(rect.right)}]`);
      }
    }
    return { sw: Math.max(de.scrollWidth, document.body.scrollWidth), cw, offenders: out };
  });
}
