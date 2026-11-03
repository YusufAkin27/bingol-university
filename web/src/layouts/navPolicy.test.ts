/**
 * T-156 / A3-03: menü izni (adminNav `perm`) ile backend `AdminPermissionPolicy` izni birbirinden kopmasın.
 * Her menü öğesinin sayfasının İLK okuma ucu (GET) politikadan çözülür ve öğenin `perm` değeriyle karşılaştırılır.
 * Backend kaynağı (`../backend/...`) yoksa (yalnız web kopyası) test atlanır; depoda ve CI'da her zaman koşar.
 * Yeni menü öğesi eklenince `NAV_ENDPOINT` tablosuna ucu da eklenmelidir (aşağıdaki "eksik" testi uyarır).
 */
import { describe, expect, it } from 'vitest';
import { haveBackend, loadPolicy, requiredPerm } from '../test/rbacPolicy';
import { adminNav, allAdminNavItems } from './adminNav';

/** Menü öğesi -> sayfanın ilk okuma ucu. */
const NAV_ENDPOINT: Record<string, string> = {
  dashboard: '/api/admin/stats',
  analytics: '/api/admin/analytics/overview',
  users: '/api/admin/users',
  pendingUsers: '/api/admin/pending-registrations',
  suspensions: '/api/admin/moderation/suspend-recommendations',
  appeals: '/api/admin/moderation/appeals',
  accessBans: '/api/admin/access-bans',
  reports: '/api/admin/reports',
  chatFeed: '/api/admin/chat-messages',
  posts: '/api/admin/posts',
  polls: '/api/admin/polls',
  blocklist: '/api/admin/moderation/blocklist',
  strikes: '/api/admin/moderation/strikes',
  hiddenContent: '/api/admin/moderation/hidden',
  reasonTemplates: '/api/admin/moderation/reason-templates',
  profanity: '/api/admin/profanity',
  communities: '/api/admin/communities',
  communityCategories: '/api/admin/community-categories',
  clubAudit: '/api/admin/communities/1/club-audit',
  contentReview: '/api/admin/community-posts',
  events: '/api/admin/events',
  eventApplications: '/api/admin/events/applications',
  acdCalendar: '/api/admin/academic/events',
  acdExams: '/api/admin/academic/exams',
  acdTimetable: '/api/admin/academic/timetable/programs',
  acdAnnouncements: '/api/admin/announcements',
  tickets: '/api/admin/support/tickets',
  feedback: '/api/admin/feedback',
  legal: '/api/admin/legal/acceptance-stats',
  faq: '/api/admin/faq',
  news: '/api/admin/news',
  menu: '/api/admin/menu',
  campaigns: '/api/admin/push/campaigns',
  mailTemplates: '/api/admin/mail/templates',
  mailCampaigns: '/api/admin/mail/campaigns',
  mailQueue: '/api/admin/mail/outbox',
  mailSuppressions: '/api/admin/mail/suppressions',
  pushOps: '/api/admin/push/fcm/status',
  system: '/api/admin/system/overview',
  sources: '/api/admin/sources/status',
  ops: '/api/admin/ops/health',
  crashes: '/api/admin/crashes',
  dataRetention: '/api/admin/data-retention/tables',
  appVersions: '/api/admin/app-versions',
  settings: '/api/admin/settings',
  roles: '/api/admin/rbac/matrix',
  audit: '/api/admin/audit',
  messageAccess: '/api/admin/audit/message-access',
  crypto: '/api/admin/crypto/status',
};

describe('menü izni <-> AdminPermissionPolicy (T-156)', () => {
  it('her menü öğesinin ucu tabloda tanımlı ve tabloda artık öğe yok', () => {
    const ids = allAdminNavItems.map((i) => i.id).sort();
    expect(Object.keys(NAV_ENDPOINT).sort()).toEqual(ids);
  });

  it.skipIf(!haveBackend)('menü `perm` değeri sayfanın ilk okuma ucunun gerektirdiği izinle aynı', () => {
    const { rules } = loadPolicy();
    expect(rules.length).toBeGreaterThan(40); // ayrıştırıcı bozulursa sessizce geçmesin
    const mismatches: string[] = [];
    for (const g of adminNav) {
      for (const it of g.items) {
        const need = requiredPerm(rules, 'GET', NAV_ENDPOINT[it.id]);
        if (it.perm !== need) mismatches.push(`${it.id}: menü=${it.perm} politika(${NAV_ENDPOINT[it.id]})=${need}`);
      }
    }
    expect(mismatches).toEqual([]);
  });

  it.skipIf(!haveBackend)('menüde kullanılan her izin backend izin tablosunda tanımlı', () => {
    const known = new Set(Object.values(loadPolicy().consts));
    for (const it of allAdminNavItems) if (it.perm) expect(known.has(it.perm), `${it.id}: ${it.perm}`).toBe(true);
  });
});

describe.skipIf(!haveBackend)('izin ayrıştırıcı örnekleri (kaynak okuma doğru çalışıyor)', () => {
  it('bilinen uçlar ve profiller', () => {
    const { rules, profilePerms } = loadPolicy();
    expect(requiredPerm(rules, 'GET', '/api/admin/users/5/devices')).toBe('users.pii');
    expect(requiredPerm(rules, 'GET', '/api/admin/reports/12')).toBe('chat.read');
    expect(requiredPerm(rules, 'GET', '/api/admin/reports')).toBe('moderation.read');
    expect(requiredPerm(rules, 'POST', '/api/admin/users/5/verify-email')).toBe('users.verify');
    expect(requiredPerm(rules, 'GET', '/api/admin/announcements')).toBe('comms.read');
    expect(requiredPerm(rules, 'GET', '/api/admin/zzz-yok')).toBe('admin.full');
    expect(profilePerms.VIEWER).toContain('audit.read');
    expect(profilePerms.SUPPORT).not.toContain('audit.read');
    expect(profilePerms.FULL).toContain('admin.full');
  });
});
