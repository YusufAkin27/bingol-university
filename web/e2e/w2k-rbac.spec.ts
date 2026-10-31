/**
 * W2-K / T-156: roller x rotalar taraması (backendsiz). Her profil için menüde görünen TÜM sayfalar gezilir ve sayfaların
 * attığı /api/admin istekleri backend `AdminPermissionPolicy` ile karşılaştırılır: profilin iznine sahip olmadığı uca istek
 * ATILMAMALI (403 gürültüsü/denetim kaydı yok). Ayrıca kullanıcı detayı ve raporlar sayfasında yetkisiz bölümler gizli olmalı.
 *   cd web && npx playwright test w2k-rbac.spec.ts
 */
import { expect, test } from '@playwright/test';
import { haveBackend, loadPolicy, requiredPerm } from '../src/test/rbacPolicy';
import { json, permsOf, stubPanel, type Profile } from './mockPanel';

const PROFILES: Profile[] = ['MODERATOR', 'EDITOR', 'SUPPORT', 'VIEWER'];

/** İzin kapısı dışındaki, her yönetici için serbest kabul edilen uçlar. */
const FREE = (path: string) => path === '/api/admin/me' || path === '/api/admin/rbac/me';

function violations(calls: string[], profile: Profile): string[] {
  const { rules } = loadPolicy();
  const have = new Set(permsOf(profile));
  const out = new Set<string>();
  for (const c of calls) {
    const [method, path] = c.split(' ');
    const full = `/api${path}`;
    if (!full.startsWith('/api/admin/') || FREE(full)) continue;
    const need = requiredPerm(rules, method, full);
    if (!have.has(need)) out.add(`${method} ${full} (gereken: ${need})`);
  }
  return [...out];
}

test.describe('Roller x rotalar (T-156)', () => {
  test.skip(!haveBackend, 'backend kaynağı yok (yalnız web kopyası)');
  test.setTimeout(1_200_000); // VIEWER ~45 sayfa gezer; paylaşımlı makinede sayfa başına ~10 sn

  for (const profile of PROFILES) {
    test(`${profile}: menüdeki her sayfa izinsiz uca istek atmaz`, async ({ page }) => {
      const calls: string[] = [];
      await stubPanel(page, profile, calls);
      await page.goto('/admin');
      await page.waitForSelector('main h1');
      const hrefs = await page.$$eval('nav a[href^="/admin"]', (as) =>
        [...new Set(as.map((a) => (a as HTMLAnchorElement).getAttribute('href') as string))],
      );
      expect(hrefs.length, `${profile} menüsü boş`).toBeGreaterThan(5);
      for (const href of hrefs) {
        await page.goto(href, { waitUntil: 'domcontentloaded' });
        await page.waitForSelector('main h1, main [data-testid="no-permission"]', { timeout: 15_000 }).catch(() => undefined);
        await page.waitForLoadState('networkidle', { timeout: 3_000 }).catch(() => undefined);
      }
      expect(violations(calls, profile), `${profile}: izinsiz istekler`).toEqual([]);
    });
  }

  test('menüde olmayan bir sayfaya elle girilirse "yetkiniz yok" gösterilir ve veri ucu çağrılmaz', async ({ page }) => {
    const calls: string[] = [];
    await stubPanel(page, 'SUPPORT', calls);
    await page.goto('/admin/system');
    await expect(page.getByTestId('no-permission')).toBeVisible();
    expect(calls.some((c) => c.includes('/admin/system/'))).toBe(false);
  });

  test('MODERATOR: Bölüm duyuruları menüde yok (comms.read gerekir) ve elle girişte yetki sayfası', async ({ page }) => {
    const calls: string[] = [];
    await stubPanel(page, 'MODERATOR', calls);
    await page.goto('/admin');
    await page.waitForSelector('main h1');
    expect(await page.locator('nav a[href$="/academic/announcements"]').count()).toBe(0);
    await page.goto('/admin/academic/announcements');
    await expect(page.getByTestId('no-permission')).toBeVisible();
    expect(calls.some((c) => c.includes('/admin/announcements'))).toBe(false);
  });
});

const USER = {
  id: 2, email: 'ogrenci@bingol.edu.tr', displayName: 'Ogrenci', faculty: null, department: null, classYear: null, language: 'tr',
  role: 'USER', status: 'ACTIVE', emailVerified: true, createdAt: '2026-10-01T10:00:00Z', lastSeenAt: null, avatarUrl: null, bio: null,
  suspendedReason: null, deletedAt: null, deviceCount: 0, platforms: [],
  counts: { feedback: 0, tickets: 0, reportsAgainst: 0, reportsFiled: 0, conversations: 0, communities: 0, eventsCreated: 0, bookmarks: 0 },
  consents: [], recentActivity: [],
};

test.describe('Kullanıcı detayı ve raporlar bölümleri (T-156)', () => {
  for (const profile of ['SUPPORT', 'VIEWER'] as Profile[]) {
    test(`${profile}: kullanıcı detayı yetkisiz bölümleri istemez/göstermez`, async ({ page }) => {
      const calls: string[] = [];
      await stubPanel(page, profile, calls);
      await page.route('**/api/admin/users/2', (r) => json(r, USER));
      await page.goto('/admin/users/2');
      await expect(page.getByRole('heading', { level: 1, name: 'Ogrenci' })).toBeVisible();
      await page.waitForLoadState('networkidle');
      // SUPPORT audit.read'e sahip DEGİL, VIEWER sahip: denetim kaydı yalnız SUPPORT için istenmemeli
      const forbidden = ['/devices', '/sessions', '/push-devices', ...(profile === 'SUPPORT' ? ['/admin/audit'] : [])];
      for (const bad of forbidden) {
        expect(calls.filter((c) => c.includes(bad)), `${profile} ${bad}`).toEqual([]);
      }
      await expect(page.getByRole('tab', { name: 'Oturumlar' })).toHaveCount(0);
      await expect(page.getByRole('tab', { name: 'Cihazlar' })).toHaveCount(0);
      await expect(page.getByText(/Bağlantınızı kontrol/)).toHaveCount(0);
      expect(violations(calls, profile)).toEqual([]);
    });
  }

  test('VIEWER: raporlar listelenir, ayrıntı ucu istenmez, toplu seçim kutusu yok', async ({ page }) => {
    const calls: string[] = [];
    await stubPanel(page, 'VIEWER', calls);
    const report = {
      id: 1, targetType: 'MESSAGE', targetId: 55, reason: 'SPAM', reasonCode: 'SPAM', note: null, status: 'OPEN', resolution: null,
      createdAt: '2026-10-30T10:00:00Z', reporterId: 3, reporter: { id: 3, displayName: 'Raporlayan', email: 'r@bingol.edu.tr' },
      priority: 1, hidden: false, openReporters: 1, preview: null,
    };
    await page.route('**/api/admin/reports?**', (r) => json(r, { items: [report], nextCursor: null }));
    await page.route('**/api/admin/reports', (r) => json(r, { items: [report], nextCursor: null }));
    await page.goto('/admin/reports');
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await page.waitForLoadState('networkidle');
    expect(calls.filter((c) => /GET \/admin\/reports\/1(\?|$)/.test(c))).toEqual([]);
    await expect(page.getByRole('checkbox')).toHaveCount(0);
    expect(violations(calls, 'VIEWER')).toEqual([]);
  });
});
