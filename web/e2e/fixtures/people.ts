/**
 * PEOPLE: Pano, Analitik ve Kullanıcılar grubu için backendsiz /api taklidi (görsel doğrulama).
 * Yalnız `import type` + saf TS (node --experimental-strip-types ile de çalışır). Senaryo: full | empty | error.
 */
import type { Page, Route } from '@playwright/test';

export type Scenario = 'full' | 'empty' | 'error';

const json = (r: Route, body: unknown, status = 200) =>
  r.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

const PERMS = [
  'dashboard.read', 'analytics.read', 'users.read', 'users.pii', 'users.write', 'users.role', 'users.delete', 'users.verify',
  'users.export', 'moderation.read', 'moderation.write', 'chat.read', 'content.read', 'support.read', 'comms.read', 'comms.single',
  'system.read', 'audit.read',
];

const day = (back: number) => {
  const d = new Date();
  d.setDate(d.getDate() - back);
  return d.toISOString().slice(0, 10);
};
const iso = (backDays: number) => new Date(Date.now() - backDays * 86_400_000).toISOString();

const LONG_MAIL = 'ayse.cok.uzun.bir.isim.ve.soyisim.ogrenci@onlisans.bingol.edu.tr';

const user = (id: number, name: string, over: Record<string, unknown> = {}) => ({
  id,
  email: id === 3 ? LONG_MAIL : `ogrenci${id}@bingol.edu.tr`,
  displayName: name,
  faculty: id % 2 ? 'Mühendislik ve Mimarlık Fakültesi' : 'İktisadi ve İdari Bilimler Fakültesi',
  department: id % 2 ? 'Bilgisayar Mühendisliği' : null,
  classYear: (id % 4) + 1,
  language: id % 5 === 0 ? 'ar' : 'tr',
  role: id === 1 ? 'ADMIN' : 'USER',
  status: id === 4 ? 'SUSPENDED' : id === 6 ? 'DELETED' : 'ACTIVE',
  emailVerified: id !== 5,
  createdAt: iso(id * 4),
  lastSeenAt: id === 7 ? null : iso(id === 1 ? 0.02 : id * 3),
  avatarUrl: null,
  ...over,
});

const NAMES = ['Yönetici Bir', 'Mehmet Can Öztürk', 'Ayşe Yılmaz', 'Zeynep Kaya', 'Ali Demir', 'Silinmiş Hesap', 'Hiç Girmemiş', 'محمد علي'];
const USERS = NAMES.map((n, i) => user(i + 1, n));

const OVERVIEW = {
  totalUsers: 12840,
  verifiedUsers: 11200,
  suspendedUsers: 37,
  newUsers: { today: 42, last7d: 310, last30d: 1180 },
  activeUsers: { dau: 2150, wau: 6100, mau: 9400 },
  stickiness: 0.23,
  messages: { total: 482000, last24h: 5231 },
  communities: { active: 41, pending: 2 },
  events: { upcoming: 12, pending: 3 },
  openReports: 9,
  openTickets: 14,
  newFeedback: 6,
  pushCampaignsSent30d: 5,
  bookmarks: 3300,
  devices: { android: 8100, ios: 3900, web: 840 },
};

const series = (n: number, f: (i: number) => number, key: string) =>
  Array.from({ length: n }, (_, i) => ({ date: day(n - 1 - i), [key]: f(i) }));

function detail(id: number, kind: 'full' | 'suspended' | 'deleted') {
  const u = user(id, id === 3 ? 'Ayşe Yılmaz' : 'Mehmet Can Öztürk', {
    status: kind === 'suspended' ? 'SUSPENDED' : kind === 'deleted' ? 'DELETED' : 'ACTIVE',
    emailVerified: kind !== 'full' ? true : false,
  });
  return {
    ...u,
    bio: 'Bilgisayar mühendisliği öğrencisiyim; robotik kulübünde aktifim.',
    suspendedReason: kind === 'suspended' ? 'Tekrarlanan uygunsuz içerik paylaşımı (3 ihlal)' : null,
    deletedAt: kind === 'deleted' ? iso(3) : null,
    deviceCount: 2,
    platforms: ['ANDROID', 'IOS'],
    counts: { feedback: 2, tickets: 1, reportsAgainst: 3, reportsFiled: 0, conversations: 14, communities: 3, eventsCreated: 1, bookmarks: 9 },
    consents: [
      { type: 'TERMS', version: 2, acceptedAt: iso(120) },
      { type: 'PRIVACY', version: 2, acceptedAt: iso(120) },
    ],
    recentActivity: Array.from({ length: 14 }, (_, i) => ({ day: day(13 - i), opens: i % 3 === 0 ? 0 : (i * 7) % 11 })),
    follow: { followerCount: 41, followingCount: 18 },
    extras: {
      showEmail: false,
      notificationPrefs: { news: true, announcements: true, events: false, messages: true, communities: true },
      notificationsTotal: 120,
      notificationsUnread: 9,
      messagesSent: 1420,
      blocking: 1,
      blockedBy: 0,
      devices: [{ platform: 'android', registeredAt: iso(60) }, { platform: 'ios', registeredAt: iso(10) }],
      communities: [{ id: 1, name: 'Robotik Kulübü', role: 'ADMIN', status: 'ACTIVE', joinedAt: iso(200) }],
      eventsCreated: [{ id: 1, title: 'Robot yarışması', startsAt: iso(-5), status: 'ACTIVE', rsvp: null }],
      eventsAttending: [{ id: 2, title: 'Kariyer günleri', startsAt: iso(-9), status: 'ACTIVE', rsvp: 'GOING' }],
      feedback: [{ id: 1, category: 'BUG', subject: 'Yemek listesi açılmıyor', status: 'NEW', createdAt: iso(8) }],
      tickets: [{ id: 1, category: 'ACCOUNT', subject: 'Şifremi sıfırlayamıyorum', status: 'OPEN', createdAt: iso(4) }],
      reportsAgainst: [{ id: 11, targetType: 'USER', targetId: id, reason: 'HARASSMENT', status: 'OPEN', createdAt: iso(2) }],
      reportsFiled: [],
    },
  };
}

export async function stubPeople(page: Page, scenario: Scenario = 'full', dark = false) {
  await page.addInitScript(
    ([theme]) => {
      sessionStorage.setItem('bu.admin.access', 'a.b.c');
      sessionStorage.setItem('bu.admin.refresh', 'r1');
      localStorage.setItem('bu.lang', 'tr');
      try {
        localStorage.setItem('bu.theme', theme as string);
      } catch {
        /* yok say */
      }
    },
    [dark ? 'dark' : 'light'],
  );
  await page.route(
    (u) => u.pathname.startsWith('/api/'),
    (r) => {
      const u = new URL(r.request().url());
      const m = r.request().method();
      const p = u.pathname.replace(/^\/api/, '');
      const fail = scenario === 'error';
      const empty = scenario === 'empty';
      const err = () => json(r, { code: 'SERVER_ERROR', message: 'x' }, 500);
      if (p === '/admin/me') return json(r, { id: 1, email: 'boss@bingol.edu.tr', displayName: 'Yonetici', role: 'ADMIN' });
      if (p === '/admin/rbac/me')
        return json(r, { userId: 1, email: 'boss@bingol.edu.tr', displayName: 'Yonetici', profile: 'FULL', pinned: true, permissions: PERMS });
      if (p === '/admin/analytics/overview')
        return fail ? err() : json(r, empty ? { ...OVERVIEW, totalUsers: 0, verifiedUsers: 0, suspendedUsers: 0, newUsers: { today: 0, last7d: 0, last30d: 0 }, activeUsers: { dau: 0, wau: 0, mau: 0 }, stickiness: 0, openReports: 0, openTickets: 0, newFeedback: 0, communities: { active: 0, pending: 0 }, events: { upcoming: 0, pending: 0 }, devices: { android: 0, ios: 0, web: 0 } } : OVERVIEW);
      if (p === '/admin/analytics/registrations')
        return fail ? err() : json(r, { points: empty ? [] : series(30, (i) => 20 + ((i * 7) % 23), 'count').map((x, i, a) => ({ ...x, cumulative: 11000 + a.slice(0, i + 1).reduce((s, y) => s + (y.count as number), 0) })) });
      if (p === '/admin/analytics/active-users')
        return fail ? err() : json(r, { points: empty ? [] : series(30, (i) => 1700 + ((i * 53) % 600), 'dau'), wau: 6100, mau: 9400 });
      if (p === '/admin/analytics/retention')
        return fail ? err() : json(r, { cohorts: empty ? [] : [0, 1, 2, 3, 4].map((w) => ({ weekStart: day(60 - w * 7), size: 300 - w * 20, d1: 55 - w, d7: 32 - w, d30: 18 })) });
      if (p === '/admin/analytics/engagement')
        return fail ? err() : json(r, {
          funnel: [{ step: 'registered', count: 1000 }, { step: 'verified', count: 830 }, { step: 'firstMessage', count: 580 }, { step: 'eventRsvp', count: 210 }],
          topEvents: [{ name: 'screen_view', count: 90000, uniqueUsers: 4000 }, { name: 'message_sent', count: 41000, uniqueUsers: 2300 }, { name: 'event_rsvp', count: 900, uniqueUsers: 410 }],
          daily: series(30, (i) => 1200 + i * 9, 'messages').map((x, i) => ({ ...x, posts: 20 + (i % 5), rsvps: 12, searches: 80 })),
          screens: [{ screen: 'home', views: 30000 }, { screen: 'menu', views: 21000 }, { screen: 'chat', views: 12000 }],
        });
      if (p === '/admin/analytics/breakdown')
        return fail ? err() : json(r, { dimension: 'faculty', total: 12840, items: [{ key: 'm', label: 'Mühendislik', count: 2500, percent: 19.5 }, { key: 'i', label: 'İktisadi', count: 2100, percent: 16.4 }, { key: 'unknown', label: '', count: 800, percent: 6.2 }] });
      if (p === '/admin/analytics/support') return json(r, { tickets: { open: 14, answered: 22, closed: 190 }, avgFirstResponseMinutes: 186, feedbackByCategory: [], feedbackByStatus: [] });
      if (p === '/admin/analytics/push') return json(r, { totals: { campaigns: 5, recipients: 5400 }, recent: [] });
      if (p === '/admin/analytics/content') return json(r, { daily: series(10, (i) => i, 'news').map((x) => ({ ...x, announcements: 1, events: 2 })) });
      if (p === '/faculties') return json(r, ['Mühendislik ve Mimarlık Fakültesi', 'İktisadi ve İdari Bilimler Fakültesi']);
      if (p === '/status') return json(r, { NEWS: { maintenance: false, lastSuccessAt: iso(0.5) }, MENU: { maintenance: true, lastSuccessAt: iso(20) } });
      if (p === '/admin/audit')
        return json(r, {
          items: [
            { id: 1, adminId: 1, adminEmail: 'ayse.admin@bingol.edu.tr', method: 'POST', path: '/api/admin/users/102/suspend', status: 200, at: iso(0.01), ip: null },
            { id: 2, adminId: 1, adminEmail: 'mehmet@bingol.edu.tr', method: 'PATCH', path: '/api/admin/settings/maintenance_mode', status: 403, at: iso(0.2), ip: null },
          ],
          page: 0, size: 5, totalItems: 2, total: 2, totalPages: 1,
        });
      if (p === '/admin/moderation/appeals' || p === '/admin/moderation/suspend-recommendations')
        return fail ? err() : json(r, {
          items: empty ? [] : p.includes('appeals')
            ? [{ id: 1, userId: 3, targetType: 'POST', targetId: 55, status: u.searchParams.get('status') ?? 'OPEN', message: 'Gönderim kurallara aykırı değildi, lütfen tekrar bakar mısınız?', createdAt: iso(2), decidedAt: null, adminNote: null }]
            : [{ id: 1, userId: 3, strikeCount: 3, status: u.searchParams.get('status') ?? 'OPEN', createdAt: iso(2) }, { id: 2, userId: 4, strikeCount: 5, status: 'OPEN', createdAt: iso(5) }],
          nextCursor: null,
        });
      if (p === '/admin/pending-registrations')
        return fail ? err() : json(r, {
          items: empty ? [] : [
            { email: LONG_MAIL, displayName: 'Ayşe Yılmaz', faculty: 'Mühendislik', department: 'Bilgisayar', grade: '2', createdAtEpochSec: 0, remainingSeconds: 2 * 86400, resendCount: 1 },
            { email: 'zeynep@bingol.edu.tr', displayName: 'Zeynep Kaya', faculty: null, department: null, grade: null, createdAtEpochSec: 0, remainingSeconds: 1200, resendCount: 5 },
            { email: '226051015', displayName: null, faculty: null, department: null, grade: null, createdAtEpochSec: 0, remainingSeconds: 5 * 3600, resendCount: 0 },
          ],
          nextCursor: null,
        });
      if (p === '/admin/access-bans/stats') return fail ? err() : json(r, { activeBans: { IP: 12, CIDR: 3, DEVICE: 5, USER: 1 }, blockedAttemptsLast24h: empty ? 0 : 1234, anonymizerRanges: 98765, anonymizersEnforced: true, topBans: [] });
      if (p === '/admin/access-bans/anonymizers') return json(r, { enforced: true, total: 10, bySource: { tor: 5, vpn: 5 }, items: [{ source: 'tor-exit-2026-10', count: 98765 }], nextCursor: null });
      if (p === '/admin/access-bans')
        return fail ? err() : json(r, { items: empty ? [] : [
          { id: 1, kind: 'IP', value: '203.0.113.7', valueShort: '203.0.113.7', note: 'n'.repeat(120), reasonCode: 'ABUSE', createdBy: 1, createdAt: iso(3), expiresAt: null, active: true, effective: true, hitCount: 3, lastHitAt: iso(0.1) },
          { id: 2, kind: 'CIDR', value: '198.51.100.0/24', valueShort: '198.51.100.0/24', note: null, reasonCode: 'SPAM', createdBy: 1, createdAt: iso(9), expiresAt: iso(-12), active: true, effective: true, hitCount: 0, lastHitAt: null },
          { id: 3, kind: 'USER', value: '3', valueShort: '3', label: 'Mehmet Can Öztürk', userId: 3, note: 'taciz', reasonCode: 'ABUSE', createdBy: 1, createdAt: iso(9), expiresAt: iso(1), active: true, effective: false, hitCount: 0, lastHitAt: null },
        ], nextCursor: null });
      if (/^\/admin\/users\/\d+$/.test(p) && m === 'GET') {
        if (fail) return err();
        const id = Number(p.split('/').pop());
        if (id === 999) return json(r, { code: 'USER_NOT_FOUND', message: 'Kullanıcı bulunamadı' }, 404);
        return json(r, detail(id, id === 4 ? 'suspended' : id === 6 ? 'deleted' : 'full'));
      }
      if (p === '/admin/users' && m === 'GET')
        return fail ? err() : json(r, { items: empty ? [] : USERS, page: 0, size: 20, totalItems: empty ? 0 : 52, total: empty ? 0 : 52, totalPages: empty ? 0 : 3 });
      if (/^\/admin\/users\/\d+\/(devices|sessions|push-devices|notifications)$/.test(p)) return json(r, []);
      return json(r, { items: [], page: 0, size: 20, totalItems: 0, totalPages: 0, nextCursor: null }, 200);
    },
  );
}
