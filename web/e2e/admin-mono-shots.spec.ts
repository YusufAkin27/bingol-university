/**
 * Yönetim paneli "Premium Monochrome" görsel doğrulaması (BACKENDSİZ: tüm /api page.route ile sahte, gerçekçi örnek veri).
 * Her yönetim sayfası x açık/koyu tema x 1440 ve 390 px (768 örneklemeli) tam sayfa ekran görüntüsü alır; yatay taşma
 * (scrollWidth <= innerWidth), konsol hataları ve renkli piksel (gri olmayan arayüz rengi) sayımını raporlar.
 * Çıktı: SHOTS_DIR (varsayılan C:\bu_dsg\_shots_admin_mono) altında <sayfa>_<tema>_<genişlik>.png + INDEX.md + report.json.
 *
 *   cd web && E2E_PORT=5311 npx playwright test admin-mono-shots.spec.ts --workers=3
 *   ONLY=dashboard,users  (virgüllü sayfa adı süzgeci)
 */
import { test, type Page } from '@playwright/test';
import { mkdirSync, writeFileSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { pageOverflow, stubPanel } from './mockPanel';
import { stubCommunity } from './fixtures/community';
import { stubModeration } from './fixtures/moderation';
import { stubNotifsys } from './fixtures/notifsys';
import { stubPeople } from './fixtures/people';

const DIR = process.env.SHOTS_DIR || 'C:\\bu_dsg\\_shots_admin_mono';
mkdirSync(DIR, { recursive: true });
const REPORT_DIR = join(DIR, '_report');
mkdirSync(REPORT_DIR, { recursive: true });

type Stub = 'people' | 'community' | 'moderation' | 'notifsys' | 'none';
interface Spec {
  name: string;
  path: string;
  stub: Stub;
  /** 768 px örneklemesi */
  mid?: boolean;
}

const PAGES: Spec[] = [
  { name: 'dashboard', path: '/admin', stub: 'people', mid: true },
  { name: 'users', path: '/admin/users', stub: 'people', mid: true },
  { name: 'user-detail', path: '/admin/users/9', stub: 'people' },
  { name: 'user-messages', path: '/admin/users/9/messages', stub: 'people' },
  { name: 'chat-feed', path: '/admin/chat-feed', stub: 'moderation' },
  { name: 'posts', path: '/admin/posts', stub: 'moderation' },
  { name: 'polls', path: '/admin/polls', stub: 'moderation' },
  { name: 'menu', path: '/admin/content/menu', stub: 'community' },
  { name: 'analytics', path: '/admin/analytics', stub: 'people', mid: true },
  { name: 'analytics-growth', path: '/admin/analytics/growth', stub: 'people' },
  { name: 'analytics-engagement', path: '/admin/analytics/engagement', stub: 'people' },
  { name: 'reports', path: '/admin/reports', stub: 'moderation' },
  { name: 'tickets', path: '/admin/support/tickets', stub: 'moderation' },
  { name: 'ticket-detail', path: '/admin/support/tickets/2', stub: 'moderation' },
  { name: 'feedback', path: '/admin/support/feedback', stub: 'moderation' },
  { name: 'legal', path: '/admin/content/legal', stub: 'community' },
  { name: 'faq', path: '/admin/content/faq', stub: 'community' },
  { name: 'news', path: '/admin/content/news', stub: 'community' },
  { name: 'communities', path: '/admin/communities', stub: 'community' },
  { name: 'content-review', path: '/admin/content-review', stub: 'community' },
  { name: 'events', path: '/admin/events', stub: 'community' },
  { name: 'campaigns', path: '/admin/campaigns', stub: 'notifsys' },
  { name: 'campaign-new', path: '/admin/campaigns/new', stub: 'notifsys' },
  { name: 'appeals', path: '/admin/moderation/appeals', stub: 'people' },
  { name: 'suspensions', path: '/admin/moderation/suspensions', stub: 'people' },
  { name: 'blocklist', path: '/admin/moderation/blocklist', stub: 'moderation' },
  { name: 'strikes', path: '/admin/moderation/strikes', stub: 'moderation' },
  { name: 'hidden', path: '/admin/moderation/hidden', stub: 'moderation' },
  { name: 'reason-templates', path: '/admin/moderation/reason-templates', stub: 'moderation' },
  { name: 'access-bans', path: '/admin/security/access-bans', stub: 'people' },
  { name: 'profanity', path: '/admin/profanity', stub: 'moderation' },
  { name: 'community-categories', path: '/admin/community-categories', stub: 'community' },
  { name: 'academic-calendar', path: '/admin/academic/calendar', stub: 'community' },
  { name: 'academic-exams', path: '/admin/academic/exams', stub: 'community' },
  { name: 'academic-timetable', path: '/admin/academic/timetable', stub: 'community' },
  { name: 'academic-announcements', path: '/admin/academic/announcements', stub: 'community' },
  { name: 'pending-users', path: '/admin/pending-users', stub: 'people' },
  { name: 'crypto', path: '/admin/crypto', stub: 'notifsys' },
  { name: 'ops', path: '/admin/ops', stub: 'notifsys' },
  { name: 'crashes', path: '/admin/crashes', stub: 'notifsys' },
  { name: 'app-versions', path: '/admin/app-versions', stub: 'notifsys' },
  { name: 'data-retention', path: '/admin/data-retention', stub: 'notifsys' },
  { name: 'system', path: '/admin/system', stub: 'notifsys', mid: true },
  { name: 'sources', path: '/admin/sources', stub: 'community' },
  { name: 'mail-templates', path: '/admin/mail/templates', stub: 'notifsys' },
  { name: 'mail-campaigns', path: '/admin/mail/campaigns', stub: 'notifsys' },
  { name: 'mail-suppressions', path: '/admin/mail/suppressions', stub: 'notifsys' },
  { name: 'mail-queue', path: '/admin/mail/queue', stub: 'notifsys' },
  { name: 'push-ops', path: '/admin/push/ops', stub: 'notifsys' },
  { name: 'event-applications', path: '/admin/events/applications', stub: 'community' },
  { name: 'club-audit', path: '/admin/communities/audit', stub: 'community' },
  { name: 'settings', path: '/admin/settings', stub: 'notifsys', mid: true },
  { name: 'audit', path: '/admin/audit', stub: 'people' },
  { name: 'message-access', path: '/admin/audit/message-access', stub: 'people' },
  { name: 'roles', path: '/admin/roles', stub: 'notifsys' },
  { name: 'not-found', path: '/admin/olmayan-sayfa', stub: 'none' },
  // oturumsuz sayfalar
  { name: 'login', path: '/admin/login', stub: 'none', mid: true },
  { name: 'register', path: '/admin/register', stub: 'none' },
];

test.setTimeout(120_000);
const ONLY = (process.env.ONLY || '').split(',').filter(Boolean);
const THEMES = ['light', 'dark'] as const;
const WIDTHS: [number, number][] = [
  [1440, 900],
  [390, 844],
];

interface Row {
  name: string;
  theme: string;
  width: number;
  file: string;
  overflow: number;
  colorful: number;
  danger: number;
  consoleErrors: string[];
  errorState: string;
}

async function prepare(page: Page, spec: Spec, theme: 'light' | 'dark') {
  await page.emulateMedia({ colorScheme: theme });
  await page.addInitScript((t) => {
    try {
      localStorage.setItem('bu.theme', t);
      localStorage.setItem('bu.cookie-consent', 'essential');
    } catch {
      /* yok say */
    }
  }, theme);
  if (spec.name === 'login' || spec.name === 'register' || spec.name === 'not-found') {
    if (spec.name === 'not-found') await stubPanel(page, 'FULL');
    else
      await page.route(
        (u) => u.pathname.startsWith('/api/'),
        (r) => r.fulfill({ status: 404, contentType: 'application/json', body: '{"code":"NOT_FOUND","message":"yok"}' }),
      );
    return;
  }
  await stubPanel(page, 'FULL');
  if (spec.stub === 'people') await stubPeople(page, 'full', theme === 'dark');
  else if (spec.stub === 'community') await stubCommunity(page, 'full');
  else if (spec.stub === 'moderation') await stubModeration(page, 'full');
  else if (spec.stub === 'notifsys') await stubNotifsys(page, 'full');
  await stubExtras(page);
}


const iso = (d: number) => new Date(Date.UTC(2026, 10, 6, 10, 0) - d * 86_400_000).toISOString();
const pg = <T,>(items: T[]) => ({ items, page: 0, size: 20, total: items.length, totalPages: 1, totalItems: items.length });
const camp = (id: number, status: string, name: string) => ({
  id, name, templateId: 1, templateName: 'Dönem açılış duyurusu', templateVersion: 3, status,
  audience: { type: 'ALL', userCount: 5200 }, scheduledAt: iso(-1), resolvedAt: iso(2), startedAt: iso(1), finishedAt: status === 'DONE' ? iso(0) : null,
  createdBy: 1, createdAt: iso(5), updatedAt: iso(1), error: status === 'FAILED' ? 'SMTP bağlantısı kurulamadı' : null,
  counters: { target: 5200, pending: status === 'SENDING' ? 1800 : 0, queued: 3300, skipped: 40, failed: status === 'FAILED' ? 120 : 3, cancelled: 0, skippedByReason: { UNSUBSCRIBED: 30, BOUNCED: 10 }, languages: { tr: 5000, en: 200 }, languageFallback: 12 },
});
/** Panelde ayrı fixture'ı olmayan sayfalar için ek sahte yanıtlar (en son kayıtlı = en önce denenir; diğerleri fallback). */
async function stubExtras(page: Page) {
  await page.route(
    (u) => u.pathname.startsWith('/api/admin/'),
    (r) => {
      const p = new URL(r.request().url()).pathname.replace(/^\/api/, '');
      const ok = (b: unknown) => r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(b) });
      if (r.request().method() !== 'GET') return r.fallback();
      if (p === '/admin/crypto/status') return ok({ activeKeyId: 'k2026-2', keyIds: ['k2026-1', 'k2026-2'], devKey: false, adminDecryptEnabled: false, dekCountsByMasterKey: { 'k2026-1': 1240, 'k2026-2': 8830 } });
      if (p === '/admin/app-versions')
        return ok({ distribution: [{ platform: 'android', version: '2.2.0+22004', devices: 5120 }, { platform: 'android', version: '2.1.0+21003', devices: 980 }, { platform: 'ios', version: '2.2.0+22004', devices: 2410 }, { platform: 'ios', version: null, devices: 140 }],
          platforms: [{ platform: 'android', minVersion: '2.0.0', latestVersion: '2.2.0', state: 'SOFT', total: 6100, unknownVersion: 0, belowMin: 0, belowLatest: 980 }, { platform: 'ios', minVersion: '2.0.0', latestVersion: '2.2.0', state: 'OFF', total: 2550, unknownVersion: 140, belowMin: 0, belowLatest: 0 }],
          total: 8650, belowMin: 0, belowLatest: 980, source: 'device-tokens', sourceNote: 'Son 30 günde görülen cihaz kayıtlarından sayılır.', windowDays: 30 });
      if (p === '/admin/mail/templates')
        return ok(pg([1, 2, 3].map((i) => ({ id: i, name: ['Dönem açılış duyurusu', 'Hesap doğrulama', 'Etkinlik hatırlatma'][i - 1], description: 'Örnek şablon açıklaması', category: i === 2 ? 'TRANSACTIONAL' : 'ANNOUNCEMENT', status: ['PUBLISHED', 'PUBLISHED', 'DRAFT'][i - 1], version: 4 - i, languages: ['tr', 'en'], updatedAt: iso(i) }))));
      if (p === '/admin/mail/campaigns') return ok(pg([camp(1, 'SENDING', 'Dönem açılışı'), camp(2, 'DONE', 'Yemek listesi duyurusu'), camp(3, 'FAILED', 'Anket daveti'), camp(4, 'SCHEDULED', 'Final haftası')]));
      if (p === '/admin/mail/suppressions')
        return ok(pg([1, 2, 3].map((i) => ({ id: i, emailMasked: 'k***' + i + '@ornek.test', hashPrefix: 'a1b2c3d' + i, reason: ['UNSUBSCRIBED', 'BOUNCED', 'COMPLAINT'][i - 1], category: 'ANNOUNCEMENT', note: i === 2 ? 'Kalıcı geri dönüş' : null, createdAt: iso(i * 3), createdBy: null, userOptOut: i !== 2 }))));
      if (p === '/admin/data-retention/tables')
        return ok([{ name: 'analytics_event', label: 'Analitik olaylar', description: 'Ham uygulama olayları (45 gün)', estimatedRows: 4_200_000, sizeBytes: 912_000_000, oldestAt: iso(60), minRetentionDays: 45, maxTo: '2026-09-22', deletable: true, notDeletableReason: null, personalData: false },
          { name: 'admin_audit', label: 'Denetim kaydı', description: 'Yönetici işlemleri', estimatedRows: 310_000, sizeBytes: 88_000_000, oldestAt: iso(200), minRetentionDays: 180, maxTo: '2026-05-10', deletable: true, notDeletableReason: null, personalData: true }]);
      if (p === '/admin/data-retention/exports') return ok([{ id: 1, table: 'analytics_event', from: '2026-08-01', to: '2026-09-01', format: 'csv.gz', status: 'COMPLETED', rowCount: 1_200_000, byteCount: 54_000_000, sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', adminId: 1, adminEmail: 'boss@bingol.edu.tr', reason: 'Aylık arşiv', createdAt: iso(5), finishedAt: iso(5) }]);
      if (p === '/admin/data-retention/purges') return ok([]);
      return r.fallback();
    },
  );
}

/** Ekrandaki "renkli" (doygunluğu belirgin) arayüz öğelerini sayar: img/video/canvas içerik sayılmaz. */
async function colorfulCount(page: Page) {
  return page.evaluate(() => {
    const parse = (c: string): [number, number, number, number] | null => {
      const m = c.match(/rgba?\(([^)]+)\)/) || c.match(/color\(srgb ([^)]+)\)/);
      if (!m) return null;
      const p = m[1].split(/[ ,/]+/).filter(Boolean).map(Number);
      if (c.startsWith('color(srgb')) return [p[0] * 255, p[1] * 255, p[2] * 255, p[3] ?? 1];
      return [p[0], p[1], p[2], p[3] ?? 1];
    };
    const sat = (c: [number, number, number, number] | null) => {
      if (!c || c[3] < 0.3) return 0;
      return Math.max(c[0], c[1], c[2]) - Math.min(c[0], c[1], c[2]);
    };
    const out: string[] = [];
    for (const el of Array.from(document.body.querySelectorAll<HTMLElement>('*'))) {
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) continue;
      if (['IMG', 'VIDEO', 'CANVAS', 'PICTURE', 'IFRAME'].includes(el.tagName)) continue;
      const cs = getComputedStyle(el);
      if (cs.visibility === 'hidden' || cs.display === 'none') continue;
      const own = el.childNodes.length > 0 && Array.from(el.childNodes).some((n) => n.nodeType === 3 && n.textContent?.trim());
      const bad: string[] = [];
      if (sat(parse(cs.backgroundColor)) > 24) bad.push('bg ' + cs.backgroundColor);
      if (own && sat(parse(cs.color)) > 24) bad.push('fg ' + cs.color);
      if (sat(parse(cs.borderTopColor)) > 24 && parseFloat(cs.borderTopWidth) > 0) bad.push('bd ' + cs.borderTopColor);
      if (cs.backgroundImage.includes('gradient') && /rgb\((?!\s*(\d+),\s*\1,\s*\1)/.test(cs.backgroundImage)) bad.push('grad');
      if (bad.length) out.push(`${el.tagName.toLowerCase()}.${String(el.className).slice(0, 40)} ${bad.join(' ')}`);
    }
    (window as unknown as { __colorful: string[] }).__colorful = out;
    return out.length;
  });
}

for (const spec of PAGES) {
  if (ONLY.length && !ONLY.includes(spec.name)) continue;
  for (const theme of THEMES) {
    for (const [w, h] of [...WIDTHS, ...(spec.mid ? ([[768, 1024]] as [number, number][]) : [])]) {
      test(`${spec.name} ${theme} ${w}`, async ({ page }) => {
        const errors: string[] = [];
        page.on('pageerror', (e) => errors.push('pageerror: ' + e.message.slice(0, 160)));
        page.on('console', (m) => {
          if (m.type() !== 'error') return;
          const t = m.text();
          if (/Failed to load resource|404|ECONNREFUSED|net::ERR/.test(t)) return; // sahte API'nin tanımadığı uçlar
          errors.push(t.slice(0, 200));
        });
        await page.setViewportSize({ width: w, height: h });
        await prepare(page, spec, theme);
        await page.goto(spec.path, { waitUntil: 'domcontentloaded' });
        await page.waitForSelector('main h1, main h2, form, [role="alert"]', { timeout: 15000 }).catch(() => undefined);
        await page.waitForLoadState('networkidle').catch(() => undefined);
        await page.waitForTimeout(500);
        const file = `${spec.name}_${theme}_${w}.png`;
        await page.screenshot({ path: join(DIR, file), fullPage: true });
        const o = await pageOverflow(page);
        await colorfulCount(page);
        const errorState = await page.evaluate(() => (document.querySelector('main')?.textContent ?? '').match(/yüklenemedi|alınamadı|yapılamadı|Bir sorun oluştu|bulunamadı/i)?.[0] ?? '');
        const list = await page.evaluate(() => (window as unknown as { __colorful?: string[] }).__colorful ?? []);
        const nonDanger = list.filter((x) => !/255, 138, 130|179, 38, 30|srgb 1 0.54|srgb 0.7/.test(x));
        const row: Row & { colorfulSamples: string[] } = {
          name: spec.name,
          theme,
          width: w,
          file,
          overflow: o.sw - o.cw,
          colorful: nonDanger.length,
          danger: list.length - nonDanger.length,
          colorfulSamples: nonDanger.slice(0, 12),
          consoleErrors: errors,
          errorState,
        };
        writeFileSync(join(REPORT_DIR, `${spec.name}_${theme}_${w}.json`), JSON.stringify(row, null, 1));
      });
    }
  }
}

test.afterAll(async () => {
  const rows: (Row & { colorfulSamples: string[] })[] = readdirSync(REPORT_DIR)
    .filter((f) => f.endsWith('.json'))
    .map((f) => JSON.parse(readFileSync(join(REPORT_DIR, f), 'utf8')));
  rows.sort((a, b) => a.name.localeCompare(b.name) || a.theme.localeCompare(b.theme) || b.width - a.width);
  const lines = [
    '# Yönetim paneli: Premium Monochrome ekran görüntüleri',
    '',
    `Toplam ${rows.length} ekran görüntüsü. Sahte (backendsiz) API; açık/koyu tema x 1440 / 390 px (768 örneklemeli).`,
    'Sütunlar: taşma = scrollWidth - innerWidth (<= 0 olmalı); renkli = tehlike kırmızısı DIŞINDA gri olmayan arayüz öğesi sayısı (0 olmalı); konsol = sahte API dışı hata sayısı; Not = sayfada hata/boş durum metni var (çoğu: sahte API ilgili ucu tanımıyor; not-found kasıtlı).',
    '',
    '| Sayfa | Tema | Genişlik | Dosya | Taşma | Renkli (tehlike dışı) | Tehlike kırmızısı | Konsol | Not |',
    '|---|---|---|---|---|---|---|---|---|',
    ...rows.map(
      (r) => `| ${r.name} | ${r.theme} | ${r.width} | [${r.file}](${r.file}) | ${r.overflow} | ${r.colorful} | ${r.danger} | ${r.consoleErrors.length} | ${r.errorState ? 'sahte API yanıtı yok: ' + r.errorState : ''} |`,
    ),
  ];
  writeFileSync(join(DIR, 'INDEX.md'), lines.join('\n') + '\n');
});
