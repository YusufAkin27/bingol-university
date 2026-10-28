import fs from 'node:fs';
import { expect, test, type APIRequestContext, type Page } from '@playwright/test';
import { ADMIN_EMAIL, apiLogin, setLang, type Tokens } from './helpers';

/**
 * Her yonetim sayfasi 3 gorunum boyutunda (telefon, tablet, masaustu) acilir:
 * konsol/sayfa hatasi yok, yatay tasma yok, ana baslik gorunur. Arapca + RTL ve koyu tema ayrica taranir.
 * Eski derlenmis backend'in tasimadigi yeni uclar (404/5xx) bos yanitla taklit edilir; bu durumlar rapora not dusulur.
 *
 *   E2E_BASE_URL=http://localhost:5260 npx playwright test e2e/admin-pages.spec.ts
 */

const VIEWPORTS = [
  { name: 'phone-360', width: 360, height: 800 },
  { name: 'tablet-768', width: 768, height: 1024 },
  { name: 'desktop-1440', width: 1440, height: 900 },
] as const;

interface RouteCase {
  name: string;
  path: string;
  /** Giris sayfasi gibi AdminLayout disinda olanlar */
  bare?: boolean;
  /** Ana baslik (h1) beklenmez (404 gibi) */
  noHeading?: boolean;
}

const STATIC_ROUTES: RouteCase[] = [
  { name: 'login', path: '/admin/login', bare: true },
  { name: 'dashboard', path: '/admin' },
  { name: 'users', path: '/admin/users' },
  { name: 'analytics-overview', path: '/admin/analytics' },
  { name: 'analytics-growth', path: '/admin/analytics/growth' },
  { name: 'analytics-engagement', path: '/admin/analytics/engagement' },
  { name: 'analytics-retention', path: '/admin/analytics/retention' },
  { name: 'analytics-demographics', path: '/admin/analytics/demographics' },
  { name: 'reports', path: '/admin/reports' },
  { name: 'tickets', path: '/admin/support/tickets' },
  { name: 'feedback', path: '/admin/support/feedback' },
  { name: 'legal', path: '/admin/content/legal' },
  { name: 'faq', path: '/admin/content/faq' },
  { name: 'news', path: '/admin/content/news' },
  { name: 'communities', path: '/admin/communities' },
  { name: 'events', path: '/admin/events' },
  { name: 'campaigns', path: '/admin/campaigns' },
  { name: 'campaign-new', path: '/admin/campaigns/new' },
  { name: 'appeals', path: '/admin/moderation/appeals' },
  { name: 'suspensions', path: '/admin/moderation/suspensions' },
  { name: 'blocklist', path: '/admin/moderation/blocklist' },
  { name: 'crypto', path: '/admin/crypto' },
  { name: 'event-applications', path: '/admin/events/applications' },
  { name: 'club-audit', path: '/admin/communities/audit' },
  { name: 'settings', path: '/admin/settings' },
  { name: 'audit', path: '/admin/audit' },
  { name: '404', path: '/admin/boyle-bir-sayfa-yok' },
];

/** Eski backend'de bulunmayan uclar icin bos ama gecerli bicimli yanit. */
const EMPTY_BODY = {
  items: [],
  content: [],
  page: 0,
  size: 20,
  totalPages: 0,
  totalItems: 0,
  nextCursor: null,
  user: { id: 1, displayName: 'Test', email: 'test@bingol.edu.tr' },
  pending: 0,
  total: 0,
};

const mocked = new Set<string>();

/** Giris ucu IP/e-posta basina sinirli (10/15 dk): tek sefer giris yapilir, tum testler ayni tokenlari kullanir. */
let shared: Tokens | undefined;
const TOKEN_FILE = 'e2e/.results/admin-pages-token.json';

/** Calisan degisince (hata sonrasi yeniden baslatma) tekrar giris yapilmasin diye tokenlar 10 dk dosyada tutulur. */
async function getTokens(request: APIRequestContext): Promise<Tokens> {
  if (shared) return shared;
  try {
    const c = JSON.parse(fs.readFileSync(TOKEN_FILE, 'utf8')) as { at: number; t: Tokens };
    if (Date.now() - c.at < 10 * 60_000) return (shared = c.t);
  } catch {
    /* onbellek yok */
  }
  shared = await apiLogin(request);
  fs.mkdirSync('e2e/.results', { recursive: true });
  fs.writeFileSync(TOKEN_FILE, JSON.stringify({ at: Date.now(), t: shared }));
  return shared;
}

async function loginAsAdmin(page: Page): Promise<void> {
  if (!shared) throw new Error('token yok');
  await page.addInitScript(
    ([a, r]) => {
      sessionStorage.setItem('bu.admin.access', a);
      sessionStorage.setItem('bu.admin.refresh', r);
    },
    [shared.accessToken, shared.refreshToken],
  );
}

/** Konsolda "Failed to load resource" olarak gorunen ag hatalari sayfa hatasi sayilmaz (eski derleme / mock'lanan uclar). */
function isNetworkNoise(text: string): boolean {
  return /Failed to load resource/i.test(text);
}

async function installApiFallback(page: Page): Promise<void> {
  await page.route('**/api/admin/**', async (route) => {
    const req = route.request();
    if (req.method() !== 'GET' || req.url().includes('/999999999')) return route.continue();
    let res;
    try {
      res = await route.fetch();
    } catch {
      return route.continue();
    }
    if (res.status() === 404 || res.status() >= 500) {
      const url = new URL(req.url());
      mocked.add(`${res.status()} ${url.pathname}`);
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(EMPTY_BODY) });
    }
    return route.fulfill({ response: res });
  });
}

async function overflowOffenders(page: Page): Promise<string[]> {
  return page.evaluate(() => {
    const vw = window.innerWidth;
    const out: string[] = [];
    for (const el of Array.from(document.body.querySelectorAll('*'))) {
      const r = (el as HTMLElement).getBoundingClientRect();
      if (r.width === 0 || r.height === 0) continue;
      if (r.right > vw + 1 || r.left < -1) {
        // kendi kaydirma kabi icinde olanlari say(ma)
        let p = el.parentElement;
        let clipped = false;
        while (p && p !== document.body) {
          const o = getComputedStyle(p).overflowX;
          if (o === 'auto' || o === 'scroll' || o === 'hidden' || o === 'clip') {
            clipped = true;
            break;
          }
          p = p.parentElement;
        }
        if (!clipped) out.push(`${el.tagName.toLowerCase()}.${(el as HTMLElement).className?.toString().slice(0, 40)} ${Math.round(r.left)}..${Math.round(r.right)}`);
      }
      if (out.length >= 6) break;
    }
    return out;
  });
}

async function visit(page: Page, rc: RouteCase) {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
  page.on('console', (m) => {
    if (m.type() === 'error' && !isNetworkNoise(m.text())) errors.push(`console: ${m.text()}`);
  });
  await page.goto(rc.path, { waitUntil: 'domcontentloaded' });
  await page.waitForLoadState('networkidle').catch(() => undefined);
  // lazy sayfa + veri yuklenmesi
  if (!rc.noHeading) await page.waitForSelector('h1', { timeout: 10_000 }).catch(() => undefined);
  await page.waitForTimeout(400);
  return errors;
}

async function assertPage(page: Page, rc: RouteCase, errors: string[], lang: 'tr' | 'ar') {
  expect(errors, 'konsol/sayfa hatasi').toEqual([]);
  if (!rc.noHeading) {
    await expect(page.locator('h1').first()).toBeVisible();
  } else {
    await expect(page.locator('main, [role=main], body').first()).toBeVisible();
  }
  const dims = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: window.innerWidth }));
  if (dims.sw > dims.iw) {
    const offenders = await overflowOffenders(page);
    expect(dims.sw, `yatay tasma (${dims.sw} > ${dims.iw}): ${offenders.join(' | ')}`).toBeLessThanOrEqual(dims.iw);
  }
  // yönetim paneli YALNIZ Türkçe: site dili Arapça olsa da yön soldan sağadır
  await expect(page.locator('html')).toHaveAttribute('dir', 'ltr');
  void lang;
  // dokunma hedefleri: telefon genisliginde gorunen dugme ve alanlar >= 40px yuksek olmali
  if (dims.iw <= 768) {
    const small = await page.evaluate(() =>
      Array.from(document.querySelectorAll<HTMLElement>('button, select, input:not([type=checkbox]):not([type=radio]):not([type=hidden]):not([type=file])'))
        .filter((el) => {
          const r = el.getBoundingClientRect();
          const cs = getComputedStyle(el);
          return r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.position !== 'absolute' && (r.height < 39.5 || r.width < 39.5);
        })
        .slice(0, 5)
        .map((el) => `${el.tagName.toLowerCase()}[${el.getAttribute('aria-label') ?? el.textContent?.trim().slice(0, 20) ?? ''}] ${Math.round(el.getBoundingClientRect().width)}x${Math.round(el.getBoundingClientRect().height)}`),
    );
    expect(small, 'dokunma hedefi < 40px').toEqual([]);
  }
}

test.describe('yonetim sayfalari', () => {
  test.setTimeout(60_000);
  const dynamic: RouteCase[] = [];

  test.beforeAll(async ({ request }) => {
    const t = await getTokens(request);
    const h = { Authorization: `Bearer ${t.accessToken}` };
    const users = await request.get('/api/admin/users?size=1', { headers: h });
    if (users.ok()) {
      const j = await users.json();
      const id = j.items?.[0]?.id;
      if (id) {
        dynamic.push({ name: 'user-detail', path: `/admin/users/${id}` });
        dynamic.push({ name: 'user-messages', path: `/admin/users/${id}/messages` });
      }
    }
    const tickets = await request.get('/api/admin/support/tickets?size=1', { headers: h });
    if (tickets.ok()) {
      const j = await tickets.json();
      const id = (j.items ?? j.content)?.[0]?.id;
      if (id) dynamic.push({ name: 'ticket-detail', path: `/admin/support/tickets/${id}` });
    }
    dynamic.push({ name: 'user-detail-missing', path: '/admin/users/999999999' });
  });

  for (const vp of VIEWPORTS) {
    test.describe(vp.name, () => {
      test.use({ viewport: { width: vp.width, height: vp.height } });

      for (const rc of STATIC_ROUTES) {
        test(`${rc.name} (tr, acik)`, async ({ page }) => {
          if (!rc.bare) await loginAsAdmin(page);
          await setLang(page, 'tr');
          await installApiFallback(page);
          const errors = await visit(page, rc);
          await assertPage(page, rc, errors, 'tr');
        });
      }

      test('dinamik rotalar (detay sayfalari)', async ({ page }) => {
        test.setTimeout(90_000);
        await loginAsAdmin(page);
        await setLang(page, 'tr');
        await installApiFallback(page);
        for (const rc of dynamic) {
          const errors = await visit(page, rc);
          await assertPage(page, { ...rc, noHeading: rc.name === 'user-detail-missing' }, errors, 'tr');
        }
      });
    });
  }

  // Arapca (RTL) + koyu tema: telefon ve masaustu
  for (const vp of [VIEWPORTS[0], VIEWPORTS[2]]) {
    test.describe(`${vp.name} arapca-rtl-koyu`, () => {
      test.use({ viewport: { width: vp.width, height: vp.height }, colorScheme: 'dark' });
      for (const rc of STATIC_ROUTES) {
        test(`${rc.name} (ar, koyu)`, async ({ page }) => {
          if (!rc.bare) await loginAsAdmin(page);
          await setLang(page, 'ar');
          await installApiFallback(page);
          const errors = await visit(page, rc);
          await assertPage(page, rc, errors, 'ar');
        });
      }
    });
  }

  test.afterAll(() => {
    if (mocked.size) {
      console.log(`[eski backend derlemesi nedeniyle mock'lanan uclar] ${ADMIN_EMAIL}\n  ${Array.from(mocked).sort().join('\n  ')}`);
    }
  });

  test('dinamik rotalar arapca (RTL) telefon', async ({ page }) => {
    test.setTimeout(90_000);
    await page.setViewportSize({ width: 360, height: 800 });
    await loginAsAdmin(page);
    await setLang(page, 'ar');
    await installApiFallback(page);
    for (const rc of dynamic.filter((d) => d.name !== 'user-detail-missing')) {
      const errors = await visit(page, rc);
      await assertPage(page, rc, errors, 'ar');
    }
  });

  test('mobilde yan menu cekmece olarak acilir/kapanir', async ({ page }) => {
    await page.setViewportSize({ width: 360, height: 800 });
    await loginAsAdmin(page);
    await setLang(page, 'tr');
    await installApiFallback(page);
    await page.goto('/admin', { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('h1');
    const burger = page.getByRole('button', { name: /menü|menu|القائمة/i }).first();
    await expect(burger).toBeVisible();
    const box = await burger.boundingBox();
    expect(box && box.width >= 40 && box.height >= 40, 'hamburger dokunma hedefi >= 40px').toBeTruthy();
  });
});
