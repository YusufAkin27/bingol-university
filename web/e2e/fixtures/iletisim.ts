/**
 * İLETİŞİM: Destek + bildirimler sayfaları için backendsiz /api taklidi (görsel doğrulama).
 * `stubPanel` (izin/oturum) ÜSTÜNE kayıt edilir; eşleşmeyen istek `fallback` ile ona geçer.
 * Senaryo: full | empty | error.
 */
import type { Page, Route } from '@playwright/test';

export type Scenario = 'full' | 'empty' | 'error';

const json = (r: Route, body: unknown, status = 200) =>
  r.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

const H = 3_600_000;
const D = 24 * H;
const iso = (agoMs: number) => new Date(Date.now() - agoMs).toISOString();

const ticket = (id: number, status: string, agoMs: number, over: Record<string, unknown> = {}) => ({
  id,
  subject: id === 2 ? 'Uygulamaya giriş yapamıyorum, şifre sıfırlama e-postası da gelmiyor' : `Yardım talebi ${id}`,
  category: ['ACCOUNT', 'TECHNICAL', 'CONTENT', 'OTHER'][id % 4],
  status,
  userId: 40 + id,
  userEmail: `ogr${id}@bingol.edu.tr`,
  publicTicket: id === 4,
  priority: id === 1 ? 'URGENT' : 'NORMAL',
  assigneeId: null,
  createdAt: iso(agoMs + H),
  updatedAt: iso(agoMs),
  ...over,
});

const openTickets = [
  ticket(1, 'OPEN', 30 * 60_000),
  ticket(2, 'OPEN', 3 * H),
  ticket(3, 'OPEN', 9 * H),
  ticket(4, 'OPEN', 20 * H),
  ticket(5, 'OPEN', 2 * D),
  ticket(6, 'OPEN', 5 * D),
  ticket(7, 'OPEN', 8 * D),
];

const fb = (id: number, status: string, category: string) => ({
  id,
  category,
  subject: `Öneri başlığı ${id}`,
  message: 'Yemek listesinde kalori bilgisi de görünürse çok iyi olur.',
  status,
  voteCount: 40 - id * 6,
  publicVisible: id % 2 === 0,
  adminResponse: null,
  userId: 40 + id,
  userEmail: `ogr${id}@bingol.edu.tr`,
  createdAt: iso(id * H),
  platform: 'android',
  appVersion: '2.0.5',
});

const camp = (id: number, title: string, status: string, rec: number | null, aud: number | null, over: Record<string, unknown> = {}) => ({
  id,
  createdBy: 1,
  type: 'ANNOUNCEMENT',
  audience: { type: 'ALL' },
  tr: { title, body: `${title} için kısa açıklama metni.` },
  en: null,
  ar: null,
  target: null,
  status,
  scheduledAt: status === 'SCHEDULED' ? iso(-2 * H) : null,
  startedAt: status === 'SCHEDULED' ? null : iso(id * D),
  finishedAt: status === 'SENT' ? iso(id * D - 300_000) : null,
  recipientCount: rec,
  audienceSize: aud,
  skippedCount: rec !== null && aud !== null ? aud - rec : null,
  source: 'CAMPAIGN',
  error: status === 'FAILED' ? 'FCM_DISABLED' : null,
  createdAt: iso(id * D + H),
  ...over,
});

const counters = (target: number, queued: number, failed = 0, skipped = 0, pending = 0, cancelled = 0) => ({
  target,
  pending,
  queued,
  skipped,
  failed,
  cancelled,
  skippedByReason: { SUPPRESSED: skipped },
  languages: { tr: target - 20, en: 15, ar: 5 },
  languageFallback: 4,
  progressPercent: Math.round((queued / Math.max(1, target)) * 100),
});
const mcamp = (id: number, name: string, status: string, c: ReturnType<typeof counters>) => ({
  id,
  name,
  templateId: 7,
  templateName: 'Duyuru şablonu',
  templateVersion: 2,
  status,
  audience: { type: 'ALL' },
  scheduledAt: null,
  resolvedAt: null,
  startedAt: iso(id * D),
  finishedAt: status === 'DONE' ? iso(id * D - 600_000) : null,
  createdBy: 1,
  createdAt: iso(id * D + H),
  updatedAt: iso(id * D),
  error: null,
  counters: c,
});

const SUPP_TOTALS: Record<string, number> = { UNSUBSCRIBED: 84, BOUNCED: 31, COMPLAINT: 3, MANUAL: 6 };

export async function stubIletisim(page: Page, scenario: Scenario = 'full') {
  const empty = scenario === 'empty';
  const fail = scenario === 'error';
  const err = (r: Route) => json(r, { code: 'INTERNAL', message: 'Sunucu hatası' }, 500);
  await page.route(
    (u) => u.pathname.startsWith('/api/'),
    (r) => {
      const u = new URL(r.request().url());
      const p = u.pathname.replace(/^\/api/, '');
      const q = u.searchParams;
      const m = r.request().method();
      const pageOf = (items: unknown[]) => ({ items, page: 0, size: 20, total: items.length, totalPages: 1, totalItems: items.length });
      const cursor = (items: unknown[]) => ({ items, nextCursor: null });

      if (p === '/admin/analytics/support') {
        if (fail) return err(r);
        return json(r, empty
          ? { tickets: { open: 0, answered: 0, closed: 0 }, avgFirstResponseMinutes: null, feedbackByCategory: [], feedbackByStatus: [] }
          : {
              tickets: { open: 7, answered: 23, closed: 61 },
              avgFirstResponseMinutes: 190,
              feedbackByCategory: [{ key: 'SUGGESTION', count: 41 }, { key: 'BUG', count: 22 }, { key: 'COMPLAINT', count: 9 }, { key: 'PRAISE', count: 6 }],
              feedbackByStatus: [{ key: 'NEW', count: 18 }, { key: 'IN_REVIEW', count: 12 }, { key: 'PLANNED', count: 9 }, { key: 'DONE', count: 33 }, { key: 'REJECTED', count: 6 }],
            });
      }
      if (p === '/admin/analytics/overview') return json(r, { verifiedUsers: 4200, totalUsers: 4800 });
      if (p === '/admin/support/tickets' && m === 'GET') {
        if (fail) return err(r);
        const st = q.get('status');
        if (empty) return json(r, cursor([]));
        if (st === 'OPEN') return json(r, cursor(openTickets));
        return json(r, cursor([...openTickets.slice(0, 3), ticket(8, 'ANSWERED', 6 * H), ticket(9, 'CLOSED', 4 * D)]));
      }
      if (p === '/admin/feedback') {
        if (fail) return err(r);
        if (empty) return json(r, cursor([]));
        return json(r, cursor([fb(1, 'NEW', 'BUG'), fb(2, 'IN_REVIEW', 'SUGGESTION'), fb(3, 'PLANNED', 'SUGGESTION'), fb(4, 'DONE', 'PRAISE')]));
      }
      if (p === '/admin/push/campaigns' && m === 'GET') {
        if (fail) return err(r);
        if (empty) return json(r, cursor([]));
        return json(r, cursor([
          camp(1, 'Final haftası duyurusu', 'SENDING', 2400, 5200),
          camp(2, 'Yeni yemek listesi yayında', 'SENT', 4990, 5200),
          camp(3, 'Kütüphane çalışma saatleri', 'SENT', 4210, 5200),
          camp(4, 'Kayıt yenileme hatırlatması', 'SENT', 3050, 4100),
          camp(5, 'Hata veren kampanya', 'FAILED', 0, 5200),
          camp(6, 'Cuma günü etkinlik', 'SCHEDULED', null, null),
          camp(7, 'Burs başvuruları', 'SENT', 1800, 1900),
          camp(8, 'Eski deneme', 'CANCELLED', null, null),
        ]));
      }
      if (p === '/admin/push/audience-count') return json(r, { count: 1240 });
      if (p === '/admin/push/audience/preview')
        return json(r, { count: 1240, willReceive: 1018, optedOut: 222, byLanguage: { tr: 1100, en: 100, ar: 40 }, sample: [], notFound: [] });
      if (p === '/admin/mail/campaigns' && m === 'GET') {
        if (fail) return err(r);
        if (empty) return json(r, pageOf([]));
        return json(r, pageOf([
          mcamp(5, 'Bahar şenliği duyurusu', 'SENDING', counters(1200, 800, 2, 38, 360)),
          mcamp(4, 'Sınav takvimi', 'DONE', counters(4100, 3980, 12, 108)),
          mcamp(3, 'Kayıt yenileme', 'DONE', counters(3900, 3900)),
          mcamp(2, 'Anket daveti', 'FAILED', counters(900, 0, 900)),
          mcamp(1, 'Taslak bülten', 'DRAFT', counters(0, 0)),
        ]));
      }
      if (/^\/admin\/mail\/campaigns\/\d+$/.test(p)) return json(r, mcamp(5, 'Bahar şenliği duyurusu', 'SENDING', counters(1200, 800, 2, 38, 360)));
      if (/^\/admin\/mail\/campaigns\/\d+\/recipients$/.test(p)) return json(r, pageOf([]));
      if (p === '/admin/mail/templates' && m === 'GET') {
        if (fail) return err(r);
        if (empty) return json(r, pageOf([]));
        const t = (id: number, name: string, status: string, languages: string[]) => ({ id, name, description: null, category: 'ANNOUNCEMENT', status, version: 1, languages, updatedAt: iso(id * D) });
        return json(r, pageOf([t(1, 'Duyuru şablonu', 'PUBLISHED', ['tr', 'en', 'ar']), t(2, 'Sınav bilgilendirme', 'PUBLISHED', ['tr', 'en']), t(3, 'Bülten', 'DRAFT', ['tr']), t(4, 'Eski şablon', 'ARCHIVED', ['tr'])]));
      }
      if (p === '/admin/mail/suppressions' && m === 'GET') {
        if (fail) return err(r);
        const reason = q.get('reason') ?? '';
        const total = empty ? 0 : reason ? (SUPP_TOTALS[reason] ?? 0) : Object.values(SUPP_TOTALS).reduce((a, b) => a + b, 0);
        const rows = empty
          ? []
          : [{ id: 1, emailMasked: 'a***@bingol.edu.tr', hashPrefix: 'ab12', reason: reason || 'UNSUBSCRIBED', category: 'ANNOUNCEMENT', note: null, createdAt: iso(2 * D), createdBy: null, userOptOut: true }];
        return json(r, { items: q.get('size') === '1' ? [] : rows, page: 0, size: 20, total, totalPages: 1 });
      }
      if (p === '/admin/mail/quota') {
        if (fail) return err(r);
        return json(r, {
          mailEnabled: true, enabled: true, limit: 500, reserve: 50, announcementCap: 100, used: empty ? 4 : 410, remaining: empty ? 496 : 90,
          announcementRemaining: 40, percent: empty ? 1 : 82, level: empty ? 'OK' : 'WARN', resetHourUtc: 0, dayStart: iso(10 * H), nextReset: iso(-14 * H),
          publicCodeUsed: 33, publicCodeCapRegistration: 100, publicCodeCapReset: 100, maxCodesPerEmailPerDay: 5, maxCodeRequestsPerIpPerDay: 20,
          history: [{ date: '2026-10-31', used: 120 }, { date: '2026-10-30', used: 300 }, { date: '2026-10-29', used: 480 }],
          historyNote: '',
          queue: empty ? { pending: 0, failed: 0, dead: 0, skipped: 0, oldestPendingAt: null } : { pending: 12, failed: 2, dead: 3, skipped: 1, oldestPendingAt: iso(40 * 60_000) },
        });
      }
      if (p === '/admin/push/outbox/stats') {
        if (fail) return err(r);
        return json(r, empty
          ? { enabled: true, pending: 0, sending: 0, failed: 0, dead: 0, sentLast24h: 0, oldestPendingAgeSeconds: null, oldestPendingAt: null }
          : { enabled: true, pending: 14, sending: 3, failed: 5, dead: 2, sentLast24h: 1840, oldestPendingAgeSeconds: 2400, oldestPendingAt: iso(40 * 60_000) });
      }
      if (p === '/admin/push/devices/summary')
        return json(r, { totalTokens: 3120, usersWithDevice: 2760, byPlatform: { android: 2100, ios: 900, web: 80, other: 40 }, byAppVersion: [{ version: '2.0.5', count: 1800 }, { version: '2.0.4', count: 900 }, { version: 'unknown', count: 120 }], activeLast7d: 2200, staleOver30d: 540 });
      if (p === '/admin/notifications/stats')
        return json(r, {
          days: 14, readRate: 0.46, created: 9800, read: 4510, totalRows: 52000, unreadRows: 21000,
          series: Array.from({ length: 14 }, (_, i) => ({ date: new Date(Date.now() - (13 - i) * D).toISOString().slice(0, 10), created: 500 + i * 30, read: 220 + i * 12 })),
          byType: [{ type: 'ANNOUNCEMENT', count: 4000 }, { type: 'NEWS', count: 3500 }, { type: 'MESSAGE', count: 2300 }],
        });
      return r.fallback();
    },
  );
}
