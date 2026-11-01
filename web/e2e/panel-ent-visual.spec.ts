/**
 * PANEL-ENT: birlestirilmis panelin gorsel denetimi (backendsiz; sayfa basina mevcut fixture + eksikler icin ek katman).
 * Ekran goruntuleri repoya girmez: SHOTS_DIR (varsayilan <repo>/.playwright-mcp/panel-ent). Calistirma:
 *   npm run build && npx vite preview --port 4180 & E2E_BASE_URL=http://localhost:4180 npx playwright test panel-ent-visual.spec.ts
 */
import { test, type Page } from '@playwright/test';
import { appendFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join } from 'node:path';
import { json, pageOverflow } from './mockPanel';
import { stubCommunity } from './fixtures/community';
import { stubIletisim } from './fixtures/iletisim';
import { stubInsan } from './fixtures/insan';
import { stubModeration } from './fixtures/moderation';
import { stubNotifsys } from './fixtures/notifsys';

const AXE = createRequire(import.meta.url).resolve('axe-core/axe.min.js');
const DIR = process.env.SHOTS_DIR || join(process.cwd(), '..', '.playwright-mcp', 'panel-ent');
mkdirSync(DIR, { recursive: true });
const RESULTS = join(DIR, 'RESULTS.jsonl');

const hoursAgo = (h: number) => new Date(Date.now() - h * 3600_000).toISOString();

/** Fixture'da olmayan uclar: yedekleme ve birim haberleri. */
async function extraLayer(page: Page) {
  await page.route(
    (u) => u.pathname === '/api/admin/system/backup',
    (r) =>
      json(r, {
        local: { count: 26, bytes: 3_400_000_000, oldestAt: hoursAgo(24 * 14) },
        remote: { configured: true, kind: 'drive', name: 'bu-kampus-yedek', lastSuccessAt: hoursAgo(9), lastVerifiedAt: hoursAgo(30), lastError: null, bytes: 8_200_000_000, count: 14 },
        lastSuccessAt: hoursAgo(1),
        lastStatus: 'OK',
        schedule: { cron: '0 * * * *', verifyCron: '30 4 * * 0', remoteCron: '15 3 * * *' },
        retention: { localDaily: 7, localWeekly: 4, localMonthly: 3, remoteDaily: 14, remoteWeekly: 8, remoteMonthly: 6 },
      }),
  );
  const sources = ['MUH', 'FEN', 'ILH', 'IIBF', 'SBF', 'MYO'].map((code, i) => ({
    code,
    name: ['Mühendislik-Mimarlık Fakültesi', 'Fen-Edebiyat Fakültesi', 'İlahiyat Fakültesi', 'İktisadi ve İdari Bilimler Fakültesi', 'Sağlık Bilimleri Fakültesi', 'Meslek Yüksekokulu'][i],
    kind: i === 5 ? 'VOCATIONAL' : 'FACULTY',
    baseUrl: `https://${code.toLowerCase()}.bingol.edu.tr`,
    enabled: i !== 4,
    graduate: false,
    facultyKeys: [],
    departmentCount: 4 + i,
    announcementCount: 120 - i * 17,
    lastSuccessAt: i === 3 ? hoursAgo(80) : hoursAgo(2 + i),
    lastAttemptAt: hoursAgo(2 + i),
    lastMessage: i === 3 ? 'Kaynak site yanıt vermedi' : null,
    maintenance: i === 3,
  }));
  await page.route(
    (u) => u.pathname === '/api/admin/unit-news/sources',
    (r) => json(r, sources),
  );
  await page.route(
    (u) => u.pathname === '/api/admin/unit-news/announcements',
    (r) =>
      json(r, {
        content: Array.from({ length: 8 }, (_, i) => ({
          id: i + 1,
          sourceCode: sources[i % 3].code,
          sourceName: sources[i % 3].name,
          unitName: 'Bilgisayar Mühendisliği',
          title: `Bahar dönemi ${i + 1}. ara sınav takvimi ve uygulama esasları duyurusu`,
          url: 'https://muh.bingol.edu.tr/duyuru',
          publishedDate: hoursAgo(20 * (i + 1)),
          attachmentCount: i % 3,
          hidden: i === 5,
        })),
        totalElements: 8,
        totalPages: 1,
        number: 0,
        size: 20,
      }),
  );
}

const PAGES: { id: string; path: string; stub: (p: Page) => Promise<void>; extra?: boolean }[] = [
  { id: 'genel-bakis', path: '/admin', stub: (p) => stubInsan(p) },
  { id: 'analitik', path: '/admin/analytics', stub: (p) => stubInsan(p) },
  { id: 'kullanicilar', path: '/admin/users', stub: (p) => stubInsan(p) },
  { id: 'raporlar', path: '/admin/reports', stub: (p) => stubModeration(p) },
  { id: 'topluluklar', path: '/admin/communities', stub: (p) => stubCommunity(p) },
  { id: 'akademik-takvim', path: '/admin/academic/calendar', stub: (p) => stubCommunity(p) },
  { id: 'menu', path: '/admin/content/menu', stub: (p) => stubCommunity(p) },
  { id: 'destek-talepleri', path: '/admin/support/tickets', stub: (p) => stubIletisim(p) },
  { id: 'sistem-durumu', path: '/admin/system', stub: (p) => stubNotifsys(p) },
  { id: 'yedekleme', path: '/admin/backup', stub: (p) => stubNotifsys(p), extra: true },
  { id: 'birim-haberleri', path: '/admin/content/unit-news', stub: (p) => stubCommunity(p), extra: true },
  { id: 'iki-faktorlu', path: '/admin/two-factor', stub: (p) => stubInsan(p) },
  { id: 'ayarlar', path: '/admin/settings', stub: (p) => stubNotifsys(p) },
  { id: 'denetim-kaydi', path: '/admin/audit', stub: (p) => stubNotifsys(p) },
];

const VIEWPORTS: [number, number][] = [
  [1280, 900],
  [390, 844],
];

for (const theme of ['light', 'dark'] as const) {
  for (const [w, h] of VIEWPORTS) {
    if (theme === 'dark' && w === 390 && process.env.DARK_MOBILE !== '1') continue;
    test.describe(`${theme} ${w}`, () => {
      test.use({ viewport: { width: w, height: h }, reducedMotion: 'reduce' });
      for (const pg of PAGES) {
        test(`${pg.id}`, async ({ page }) => {
          test.setTimeout(60_000);
          const errors: string[] = [];
          page.on('pageerror', (e) => errors.push(String(e).slice(0, 160)));
          await pg.stub(page);
          if (pg.extra) await extraLayer(page);
          await page.addInitScript(([t]) => {
            try {
              localStorage.setItem('bu.theme', t as string);
            } catch {
              /* yok say */
            }
          }, [theme]);
          await page.goto(pg.path);
          await page.waitForLoadState('networkidle');
          await page.waitForTimeout(1200);
          await page.screenshot({ path: join(DIR, `${pg.id}-${w}-${theme}.png`), fullPage: true });
          const ov = await pageOverflow(page);
          await page.addScriptTag({ path: AXE });
          const bad = await page.evaluate(async () => {
            const res = await (window as unknown as { axe: { run: (c: unknown, o: unknown) => Promise<{ violations: { id: string; nodes: { target: unknown[] }[] }[] }> } }).axe.run(document, {
              runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa'] },
            });
            return res.violations.map((v) => `${v.id}(${v.nodes.length}): ${String(v.nodes[0]?.target?.join(' '))}`);
          });
          appendFileSync(
            RESULTS,
            JSON.stringify({ page: pg.id, w, theme, overflow: ov.sw > ov.cw + 1 ? ov : null, axe: bad, errors }) + '\n',
          );
        });
      }
    });
  }
}
