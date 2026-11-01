/**
 * PANEL-mod1: Yaptırım sayfaları görsel/taşma taraması (backendsiz, page.route ile gerçekçi sahte veri).
 *   cd web && E2E_BASE_URL=http://localhost:4180 MOD1_TAG=sonra npx playwright test mod1-yaptirim.spec.ts
 * Ekran görüntüleri `.playwright-mcp/mod1/<etiket>-<sayfa>-<genişlik>.png`; ÖNCE/SONRA için MOD1_TAG değiştirilir.
 */
import { expect, test, type Page } from '@playwright/test';
import { json, pageOverflow, stubPanel } from './mockPanel';

const TAG = process.env.MOD1_TAG || 'sonra';
const DAY = 86_400_000;
const ago = (ms: number) => new Date(Date.now() - ms).toISOString();
const paged = <T,>(items: T[]) => ({ items, page: 0, size: 20, total: items.length, totalPages: 1 });

const NAMES = ['Ayşe Demir', 'Mehmet Kaya', 'Zeynep Aydın', 'Ali Yıldız', 'Elif Şahin', 'Can Öztürk', 'Selin Arslan', 'Burak Çelik'];

const appeals = [10, 8, 5, 4, 2, 1.5, 1, 0.3, 0.1].map((d, i) => ({
  id: i + 1,
  userId: 10 + i,
  targetType: ['USER_AVATAR', 'FEED_POST', 'MESSAGE_IMAGE', 'FEED_POST'][i % 4],
  targetId: 200 + i,
  message: ['Fotoğrafım kurallara uygun, yanlışlıkla gizlendi.', 'Bu gönderi sadece kampüs etkinliğini gösteriyordu.', 'İtiraz ediyorum, içerik zararsız.'][i % 3],
  status: 'OPEN',
  adminNote: null,
  createdAt: ago(d * DAY),
  decidedAt: null,
}));
const recs = [6, 5, 4, 3, 3, 3, 3].map((n, i) => ({ id: i + 1, userId: 30 + i, strikeCount: n, status: 'OPEN', createdAt: ago((i % 4 === 0 ? 9 : i + 0.5) * DAY) }));
const strikes = Array.from({ length: 14 }, (_, i) => ({
  id: i + 1,
  userId: 40 + (i % 5),
  userName: NAMES[i % 5],
  userEmail: `kullanici${i % 5}@bingol.edu.tr`,
  reportId: i + 3,
  targetType: ['POST', 'USER_AVATAR', 'MESSAGE'][i % 3],
  targetId: 100 + i,
  resolution: ['HIDE', 'HIDE', 'WARN', 'SUSPEND_USER'][i % 4],
  createdAt: ago((i % 12) * DAY * 1.1),
  revokedAt: null,
  active: true,
  forgiven: false,
  forgivenBy: null,
  forgivenReason: null,
}));
const hidden = Array.from({ length: 12 }, (_, i) => ({
  targetType: ['FEED_POST', 'USER_AVATAR', 'MESSAGE_IMAGE', 'COMMUNITY_COVER'][i % 4],
  targetId: 300 + i,
  hiddenBy: i % 3 === 0 ? 'AUTO' : 'ADMIN',
  hiddenAt: ago([26, 24, 12, 9, 6, 3, 2, 1, 0.5, 0.2, 0.1, 15][i] * DAY),
  reversible: i % 5 !== 4,
  exists: true,
  ownerId: 50 + i,
  ownerName: NAMES[i % 8],
  preview: i % 2 === 0 ? { kind: 'TEXT', text: 'Önizleme metni örnek içerik ' + i } : null,
}));
const templates = [
  { id: 1, kind: 'REPORT_DECISION', code: 'SPAM', textTr: 'Spam içerik olduğu için kaldırıldı.', textEn: 'Removed as spam.', textAr: 'تمت الإزالة', active: true, sortOrder: 1, updatedAt: ago(DAY) },
  { id: 2, kind: 'REPORT_DECISION', code: 'HARASSMENT', textTr: 'Taciz içerdiği için kaldırıldı.', textEn: 'Removed for harassment.', textAr: null, active: true, sortOrder: 2, updatedAt: ago(DAY) },
  { id: 3, kind: 'REPORT_DECISION', code: 'SEXUAL', textTr: 'Uygunsuz içerik nedeniyle kaldırıldı.', textEn: null, textAr: null, active: false, sortOrder: 3, updatedAt: ago(DAY) },
  { id: 4, kind: 'REPORT_DECISION', code: 'OTHER', textTr: 'Topluluk kurallarına aykırı bulundu.', textEn: 'Violated community rules.', textAr: 'مخالف', active: true, sortOrder: 4, updatedAt: ago(DAY) },
];
const terms = Array.from({ length: 8 }, (_, i) => ({
  id: 70 - i,
  term: ['ornekkelime', '=tamkelime', '*icindegecen', 'kotusoz', 'argo ifade', 'hakaretkok', 'testterim', 'deneme'][i],
  kind: 'BLOCK',
  lang: ['TR', 'ALL', 'EN', 'TR'][i % 4],
  note: i % 2 ? 'Yönetici eklemesi' : null,
  createdBy: 1,
  createdAt: ago(i * DAY),
}));
const sha = (n: number) => String(n).repeat(64).slice(0, 64);
const blocklist = Array.from({ length: 9 }, (_, i) => ({ sha256: sha(i + 1), note: i % 2 ? 'Zararlı görsel' : null, createdBy: 1, createdAt: ago([0.5, 1, 2, 4, 6, 9, 20, 30, 45][i] * DAY) }));
const bans = Array.from({ length: 8 }, (_, i) => ({
  id: i + 1,
  kind: ['IP', 'CIDR', 'DEVICE', 'USER'][i % 4],
  value: ['203.0.113.7', '198.51.100.0/24', 'aabbccddeeff0011', '77'][i % 4],
  valueShort: ['203.0.113.7', '198.51.100.0/24', 'aabbcc…0011', '77'][i % 4],
  label: i % 4 === 3 ? 'Burak Çelik' : null,
  userId: i % 4 === 3 ? 77 : null,
  note: i % 2 ? 'Tekrarlayan kötüye kullanım' : null,
  reasonCode: 'ABUSE',
  createdBy: 1,
  createdAt: ago((i + 1) * 12 * DAY),
  expiresAt: [null, ago(2 * DAY), new Date(Date.now() + 3 * DAY).toISOString(), null, ago(1 * DAY), null, null, null][i],
  active: true,
  hitCount: [120, 0, 45, 0, 3, 0, 800, 12][i],
  lastHitAt: i === 1 ? null : ago(DAY),
}));

async function serve(page: Page) {
  await stubPanel(page, 'FULL');
  await page.route(
    (u) => u.pathname.startsWith('/api/admin/'),
    (r) => {
      const u = new URL(r.request().url());
      const p = u.pathname.replace(/^\/api/, '');
      if (r.request().method() !== 'GET') return json(r, null, 204);
      if (p === '/admin/moderation/appeals') return json(r, { items: appeals, nextCursor: null });
      if (p === '/admin/moderation/suspend-recommendations') return json(r, { items: recs, nextCursor: null });
      if (p === '/admin/moderation/strikes') return json(r, paged(strikes));
      if (p === '/admin/moderation/hidden') return json(r, paged(hidden));
      if (p === '/admin/moderation/reason-templates') return json(r, { items: templates, max: 50 });
      if (p === '/admin/moderation/blocklist') return json(r, { items: blocklist, nextCursor: null });
      if (p === '/admin/profanity') return json(r, { items: terms, nextCursor: null });
      if (p === '/admin/profanity/info')
        return json(r, { builtIn: { tr: 320, en: 540, ar: 60, allow: 40, source: 'LDNOOBW' }, adminBlock: 8, adminAllow: 3, settings: { enabled: true, mode: 'BLOCK' } });
      if (p === '/admin/profanity/stats')
        return json(r, {
          last24h: { total: 4, byField: [], byCategory: { PROFANITY: 3, HATE: 1 } },
          last7d: { total: 31, byField: [{ entity: 'FeedPost', field: 'text', count: 20 }, { entity: 'AppUser', field: 'displayName', count: 11 }], byCategory: { PROFANITY: 22, HATE: 6, SELF_HARM: 3 } },
        });
      if (p === '/admin/access-bans/stats') return json(r, { activeByKind: { IP: 12, CIDR: 3, DEVICE: 5, USER: 2 }, blockedLast24h: 87, anonymizerRanges: 4000 });
      if (p === '/admin/access-bans') return json(r, { items: bans, nextCursor: null });
      if (/^\/admin\/users\/\d+$/.test(p)) return json(r, { id: Number(p.split('/').pop()), email: 'k@bingol.edu.tr', displayName: NAMES[Number(p.split('/').pop()) % 8], status: 'ACTIVE' });
      return r.fallback();
    },
  );
}

const PAGES: Array<[string, string]> = [
  ['itirazlar', '/admin/moderation/appeals'],
  ['aski', '/admin/moderation/suspensions'],
  ['erisim-engelleri', '/admin/security/access-bans'],
  ['ihlaller', '/admin/moderation/strikes'],
  ['gizli-icerik', '/admin/moderation/hidden'],
  ['sablonlar', '/admin/moderation/reason-templates'],
  ['yasakli-kelime', '/admin/profanity'],
  ['yasakli-gorsel', '/admin/moderation/blocklist'],
];

test.describe('Yaptırım sayfaları (mod1)', () => {
  for (const w of [1280, 390]) {
    for (const [name, route] of PAGES) {
      test(`${name} @${w}`, async ({ page }) => {
        await page.setViewportSize({ width: w, height: 900 });
        await serve(page);
        await page.goto(route);
        await page.waitForSelector('main h1');
        await page.waitForLoadState('networkidle');
        await page.waitForTimeout(700);
        await page.screenshot({ path: `../.playwright-mcp/mod1/${TAG}-${name}-${w}.png`, fullPage: true });
        const o = await pageOverflow(page);
        expect(o.sw, `scrollWidth ${o.sw} > clientWidth ${o.cw}; ${o.offenders.join(' | ')}`).toBeLessThanOrEqual(o.cw);
      });
    }
  }
});
