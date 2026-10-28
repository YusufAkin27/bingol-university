/**
 * Yonetim paneli: genel bakis, kullanicilar, analitik, denetim kaydi.
 * On kosul: backend :8080 (docker) + `scripts/seed-demo.sh` ile demo veri + yonetici hesabi (E2E_ADMIN_EMAIL, parola Sifre1234).
 *   cd web && E2E_PORT=5192 E2E_ADMIN_EMAIL=admin2@bingol.edu.tr npx playwright test admin-analytics.spec.ts
 * Gorsel inceleme ekran goruntuleri icin E2E_SHOTS=1 (e2e/.results/shots/).
 * Giris hiz siniri nedeniyle token bir kez alinir ve (10 dk tazeyse) gecici dosyada tekrar kullanilir.
 */
import { expect, test, type Page } from '@playwright/test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { ADMIN_EMAIL, ADMIN_PASSWORD, type Tokens } from './helpers';

const BACKEND = process.env.VITE_DEV_BACKEND || 'http://localhost:8080';
const CACHE = path.join(os.tmpdir(), `bu-e2e-${ADMIN_EMAIL.replace(/[^a-z0-9]/gi, '_')}.json`);

let tokens: Tokens;
let me: { id: number; email: string };

async function getTokens(): Promise<Tokens> {
  try {
    const c = JSON.parse(fs.readFileSync(CACHE, 'utf8')) as { at: number; tokens: Tokens };
    if (Date.now() - c.at < 12 * 60_000) return c.tokens;
    // eski oturum: giris hiz sinirina takilmamak icin once refresh denenir
    const r = await fetch(`${BACKEND}/api/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: c.tokens.refreshToken }),
    });
    if (r.ok) {
      const t = (await r.json()) as Tokens;
      fs.writeFileSync(CACHE, JSON.stringify({ at: Date.now(), tokens: t }));
      return t;
    }
  } catch {
    /* onbellek yok */
  }
  const res = await fetch(`${BACKEND}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: ADMIN_EMAIL, password: ADMIN_PASSWORD }),
  });
  if (!res.ok) throw new Error(`Giris basarisiz: ${res.status} ${await res.text()}`);
  const t = (await res.json()) as Tokens;
  fs.writeFileSync(CACHE, JSON.stringify({ at: Date.now(), tokens: t }));
  return t;
}

async function api<T>(p: string): Promise<T> {
  const res = await fetch(`${BACKEND}/api${p}`, { headers: { Authorization: `Bearer ${tokens.accessToken}` } });
  if (!res.ok) throw new Error(`${p}: ${res.status}`);
  return res.json() as Promise<T>;
}

type Lang = 'tr' | 'en' | 'ar';

async function prepare(page: Page, opts: { lang?: Lang; theme?: 'light' | 'dark' } = {}) {
  await page.addInitScript(
    ([a, r, lang, theme]) => {
      sessionStorage.setItem('bu.admin.access', a);
      sessionStorage.setItem('bu.admin.refresh', r);
      localStorage.setItem('bu.lang', lang);
      localStorage.setItem('bu.theme', theme);
    },
    [tokens.accessToken, tokens.refreshToken, opts.lang ?? 'tr', opts.theme ?? 'light'] as const,
  );
  // Backend CORS yalnizca 5173/3000 kokenlerine izin verir; vite proxy Origin'i oldugu gibi iletir ve
  // POST/PATCH/DELETE "Invalid CORS request" (403) alir. Test portu icin Origin basligi kaldirilir (ayni-koken gibi).
  await page.route('**/api/**', async (route) => {
    const { origin: _o, ...headers } = route.request().headers();
    void _o;
    await route.continue({ headers });
  });
}

test.describe.configure({ mode: 'serial' });

test.beforeAll(async () => {
  tokens = await getTokens();
  me = await api<{ id: number; email: string }>('/admin/me');
});

test.describe('genel bakis', () => {
  test('KPI kartlari, dikkat paneli, kaynak durumu ve son islemler dolu gelir', async ({ page }) => {
    await prepare(page);
    const overviewP = page.waitForResponse((r) => r.url().includes('/analytics/overview') && r.ok());
    await page.goto('/admin');
    const overview = (await (await overviewP).json()) as { totalUsers: number; verifiedUsers: number };
    expect(overview.totalUsers).toBeGreaterThanOrEqual(300);
    await expect(page.getByRole('heading', { name: 'Genel bakış', level: 1 })).toBeVisible();
    const total = new Intl.NumberFormat('tr-TR').format(overview.totalUsers);
    await expect(page.getByText('Toplam kullanıcı').locator('..').getByText(total, { exact: true })).toBeVisible();
    await expect(page.getByTestId('attention-panel')).toBeVisible();
    await expect(page.getByTestId('sources-panel').getByText('Haber ve duyurular')).toBeVisible();
    await expect(page.getByTestId('recent-audit').locator('li').first()).toBeVisible();
    await expect(page.getByTestId('device-panel').getByText('Android')).toBeVisible();
    // mini grafikler (recharts) yuklenir
    await expect(page.locator('.recharts-surface').first()).toBeVisible();
  });

  test('bir kart hata verse de sayfa calisir', async ({ page }) => {
    await prepare(page);
    await page.route('**/api/admin/audit**', (route) => route.fulfill({ status: 500, body: '{"code":"X","message":"x"}', contentType: 'application/json' }));
    await page.goto('/admin');
    await expect(page.getByTestId('recent-audit').getByRole('alert')).toBeVisible();
    await expect(page.getByText('Toplam kullanıcı')).toBeVisible();
    await expect(page.getByTestId('sources-panel').getByText('Haber ve duyurular')).toBeVisible();
  });
});

test.describe('kullanicilar', () => {
  test('arama, filtre, siralama ve URL durumu', async ({ page }) => {
    await prepare(page);
    await page.goto('/admin/users');
    const rows = page.locator('tbody tr');
    await expect(rows.first()).toBeVisible();
    await expect(page.getByText(/\d+ kullanıcı/)).toBeVisible();

    await page.getByRole('searchbox').fill('demo.001@');
    await expect(page).toHaveURL(/q=demo\.001%40|q=demo\.001@/);
    await expect(rows).toHaveCount(1);
    await expect(rows.first()).toContainText('demo.001@bingol.edu.tr');

    await page.getByRole('button', { name: 'Filtreleri temizle' }).click();
    await expect(page).not.toHaveURL(/q=/);

    await page.getByLabel('Durum', { exact: true }).selectOption('SUSPENDED');
    await expect(page).toHaveURL(/status=SUSPENDED/);
    await expect(rows.first()).toContainText('Askıda');
    const n = await rows.count();
    for (let i = 0; i < n; i++) await expect(rows.nth(i)).toContainText('Askıda');

    await page.getByRole('button', { name: 'Filtreleri temizle' }).click();
    await page.getByLabel('Dil', { exact: true }).selectOption('en');
    await expect(page).toHaveURL(/language=en/);
    await page.getByLabel('Fakülte', { exact: true }).fill('Ornek Fakulte A');
    await expect(page).toHaveURL(/faculty=Ornek/);
    await expect(page.locator('tbody tr[tabindex="0"]').first()).toContainText('Ornek Fakulte A');

    // siralama: ada gore
    await page.getByRole('columnheader', { name: 'Ad' }).getByRole('button').click();
    await expect(page).toHaveURL(/sort=displayName%2Casc|sort=displayName,asc/);

    // paylasilabilir baglanti: URL ile dogrudan acilis ayni durumu yukler
    await page.goto('/admin/users?status=ACTIVE&classYear=2&sort=createdAt,asc');
    await expect(page.getByLabel('Sınıf', { exact: true })).toHaveValue('2');
    await expect(page.getByLabel('Durum', { exact: true })).toHaveValue('ACTIVE');
  });

  test('CSV disa aktarimi ayni filtrelerle indirilir', async ({ page }) => {
    await prepare(page);
    await page.goto('/admin/users?status=SUSPENDED');
    await expect(page.locator('tbody tr').first()).toBeVisible();
    const req = page.waitForRequest((r) => r.url().includes('/users/export.csv'));
    const dl = page.waitForEvent('download');
    await page.getByRole('button', { name: 'CSV olarak indir' }).click();
    expect((await req).url()).toContain('status=SUSPENDED');
    const d = await dl;
    expect(d.suggestedFilename()).toBe('users.csv');
    const text = fs.readFileSync((await d.path()) as string, 'utf8');
    expect(text).toContain('id,email');
    expect(text).toContain('demo.');
  });

  test('detaydan demo kullaniciyi askiya alip geri acma + denetim kaydi', async ({ page }) => {
    await prepare(page);
    await page.goto('/admin/users?q=demo.002@');
    await page.locator('tbody tr[tabindex="0"]').first().click();
    await expect(page).toHaveURL(/\/admin\/users\/\d+/);
    const id = Number(page.url().split('/').pop());
    await expect(page.getByRole('heading', { name: 'Profil' })).toBeVisible();
    await expect(page.getByText('Sayaçlar')).toBeVisible();

    await page.getByRole('button', { name: 'Askıya al', exact: true }).click();
    const dialog = page.getByRole('dialog');
    await dialog.getByRole('button', { name: 'Askıya al' }).click(); // neden bos
    await expect(dialog.getByText('Askı nedenini yazın.')).toBeVisible();
    await dialog.getByRole('textbox').fill('E2E testi');
    await dialog.getByRole('button', { name: 'Askıya al' }).click();
    await expect(page.getByText('Hesap askıya alındı.')).toBeVisible();
    await expect(page.getByText('E2E testi')).toBeVisible();

    await page.getByRole('button', { name: 'Askıyı kaldır' }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'Askıyı kaldır' }).click();
    await expect(page.getByText('Hesap yeniden etkinleştirildi.')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Askıya al', exact: true })).toBeVisible();

    // denetim kaydinda gorunur
    await page.goto(`/admin/audit?q=${id}%2Fsuspend`);
    await expect(page.locator('tbody tr').first()).toContainText(`/api/admin/users/${id}/suspend`);
    await page.goto(`/admin/audit?q=${id}%2Funsuspend`);
    await expect(page.locator('tbody tr').first()).toContainText(`/api/admin/users/${id}/unsuspend`);
  });

  test('rol degistirme (demo kullanici) ve kendi hesabinda devre disi', async ({ page }) => {
    await prepare(page);
    await page.goto('/admin/users?q=demo.003@');
    await page.locator('tbody tr[tabindex="0"]').first().click();
    const id = Number(page.url().split('/').pop());
    await page.getByLabel('Rol', { exact: true }).selectOption('ADMIN');
    await page.getByRole('button', { name: 'Rolü değiştir' }).click();
    const refetched = page.waitForResponse(
      (r) => r.request().method() === 'GET' && new RegExp(`/api/admin/users/${id}$`).test(r.url()),
    );
    await page.getByRole('dialog').getByRole('button', { name: 'Onayla' }).click();
    await expect(page.getByText('Rol güncellendi.')).toBeVisible();
    await refetched; // liste/ayrinti yenilenir
    await expect(page.getByLabel('Rol', { exact: true })).toHaveValue('ADMIN');
    // geri al
    await page.getByLabel('Rol', { exact: true }).selectOption('USER');
    await page.getByRole('button', { name: 'Rolü değiştir' }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'Onayla' }).click();
    await expect(page.getByText('Rol güncellendi.').last()).toBeVisible();
    await expect(page.getByLabel('Rol', { exact: true })).toHaveValue('USER');
    await page.goto(`/admin/audit?q=${id}%2Frole`);
    await expect(page.locator('tbody tr').first()).toContainText(`/api/admin/users/${id}/role`);

    // kendi hesabi
    await page.goto(`/admin/users/${me.id}`);
    await expect(page.getByLabel('Rol', { exact: true })).toBeDisabled();
    await expect(page.getByRole('button', { name: 'Hesabı sil' })).toBeDisabled();
  });

  test('hesap silme iki adimli onay ister (iptal edilir, silinmez)', async ({ page }) => {
    await prepare(page);
    await page.goto('/admin/users?q=demo.004@');
    await page.locator('tbody tr[tabindex="0"]').first().click();
    await page.getByRole('button', { name: 'Hesabı sil' }).click();
    const dialog = page.getByRole('dialog');
    const confirm = dialog.getByRole('button', { name: 'Hesabı sil' });
    await expect(confirm).toBeDisabled();
    await dialog.getByRole('textbox').fill('demo.004@bingol.edu.tr');
    await expect(confirm).toBeEnabled();
    await dialog.getByRole('button', { name: 'Vazgeç' }).click();
    await expect(page.getByRole('dialog')).toHaveCount(0);
  });
});

test.describe('analitik', () => {
  test('bes sekme grafik ve tablolarla acilir, sekme URLde', async ({ page }) => {
    await prepare(page);
    await page.goto('/admin/analytics');
    await expect(page.getByRole('tab', { name: 'Genel' })).toHaveAttribute('aria-selected', 'true');
    await expect(page.getByText('KVKK:')).toBeVisible();
    await expect(page.locator('.recharts-surface').first()).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Destek ve geri bildirim' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Bildirim kampanyaları' })).toBeVisible();
    // tablo olarak goster
    await page.getByRole('button', { name: 'Tablo olarak göster' }).first().click();
    await expect(page.locator('table').first().locator('tbody tr').first()).toBeVisible();

    await page.getByRole('tab', { name: 'Büyüme' }).click();
    await expect(page).toHaveURL(/tab=growth/);
    await expect(page.getByRole('heading', { name: 'Dönem karşılaştırması' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'E-posta doğrulama oranı' })).toBeVisible();
    await expect(page.locator('.recharts-surface').first()).toBeVisible();

    await page.getByRole('tab', { name: 'Etkileşim' }).click();
    await expect(page).toHaveURL(/tab=engagement/);
    await expect(page.getByTestId('funnel-table')).toContainText('Kayıt oldu');
    await expect(page.getByTestId('funnel-table')).toContainText('%');
    await expect(page.getByRole('heading', { name: 'En çok gerçekleşen olaylar' })).toBeVisible();
    await expect(page.getByRole('cell', { name: 'screen_view' })).toBeVisible();

    await page.getByRole('tab', { name: 'Tutundurma' }).click();
    await expect(page).toHaveURL(/tab=retention/);
    const cohort = page.getByRole('table', { name: 'Kohort tutundurma' });
    await expect(cohort).toBeVisible();
    await expect(cohort.locator('tbody tr')).not.toHaveCount(0);
    await expect(cohort.locator('tbody td', { hasText: '%' }).first()).toBeVisible();

    await page.getByRole('tab', { name: 'Demografi' }).click();
    await expect(page).toHaveURL(/tab=demographics/);
    await expect(page.getByTestId('demo-table')).toContainText('Ornek Fakulte A');
    await expect(page.getByTestId('demo-table')).toContainText('Bilinmiyor');
    await page.getByRole('button', { name: 'Dil', exact: true }).click();
    await expect(page).toHaveURL(/dim=language/);
    await expect(page.getByTestId('demo-table')).toContainText('Türkçe');
  });

  test('tarih araligi degisince istek from/to ile gider; dogrudan URL ile sekme acilir', async ({ page }) => {
    await prepare(page);
    await page.goto('/admin/analytics?tab=growth');
    const req = page.waitForRequest((r) => r.url().includes('/analytics/registrations') && r.url().includes('from='));
    await page.getByRole('button', { name: 'Son 7 gün' }).click();
    const url = new URL((await req).url());
    expect(url.searchParams.get('from')).toBeTruthy();
    await expect(page).toHaveURL(/from=/);
    await expect(page.getByRole('tab', { name: 'Büyüme' })).toHaveAttribute('aria-selected', 'true');
  });

  test('hata durumu tekrar dene ile toparlanir', async ({ page }) => {
    await prepare(page);
    let fail = true;
    await page.route('**/api/admin/analytics/retention', (route) => {
      if (fail) return route.fulfill({ status: 500, body: '{"code":"X","message":"x"}', contentType: 'application/json' });
      return route.continue();
    });
    await page.goto('/admin/analytics?tab=retention');
    await expect(page.getByRole('alert')).toBeVisible();
    fail = false;
    await page.getByRole('button', { name: 'Tekrar dene' }).click();
    await expect(page.getByRole('table', { name: 'Kohort tutundurma' })).toBeVisible();
  });
});

test.describe('denetim kaydi', () => {
  test('tablo, filtreler ve durum rozetleri', async ({ page }) => {
    await prepare(page);
    await page.goto('/admin/audit');
    await expect(page.getByRole('heading', { name: 'Denetim kaydı', level: 1 })).toBeVisible();
    await expect(page.locator('tbody tr').first()).toBeVisible();
    await page.getByLabel('Yöntem', { exact: true }).selectOption('POST');
    await expect(page).toHaveURL(/method=POST/);
    const rows = page.locator('tbody tr');
    const n = await rows.count();
    for (let i = 0; i < Math.min(n, 5); i++) await expect(rows.nth(i)).toContainText('POST');
    await page.getByLabel('Yönetici', { exact: true }).selectOption({ index: 1 });
    await expect(page).toHaveURL(/adminId=\d+/);
  });
});

test.describe('diller', () => {
  for (const [lang, title, dir] of [
    // yönetim paneli YALNIZ Türkçe: site dili tercihi ne olursa olsun Türkçe ve soldan sağa
    ['tr', 'Genel bakış', 'ltr'],
    ['en', 'Genel bakış', 'ltr'],
    ['ar', 'Genel bakış', 'ltr'],
  ] as const) {
    test(`${lang}: genel bakis acilir (dir=${dir})`, async ({ page }) => {
      await prepare(page, { lang });
      await page.goto('/admin');
      await expect(page.locator('html')).toHaveAttribute('dir', dir);
      await expect(page.getByRole('heading', { name: title, level: 1 })).toBeVisible();
      await page.goto('/admin/analytics?tab=retention');
      await expect(page.locator('table').first()).toBeVisible();
    });
  }
});

// ---- gorsel dogrulama ekran goruntuleri ----
const SHOTS = process.env.E2E_SHOTS === '1';
const PAGES: [string, string][] = [
  ['dashboard', '/admin'],
  ['users', '/admin/users'],
  ['user-detail', '/admin/users?q=demo.005@'],
  ['analytics-overview', '/admin/analytics?tab=overview'],
  ['analytics-growth', '/admin/analytics?tab=growth'],
  ['analytics-engagement', '/admin/analytics?tab=engagement'],
  ['analytics-retention', '/admin/analytics?tab=retention'],
  ['analytics-demographics', '/admin/analytics?tab=demographics&dim=faculty'],
  ['analytics-demographics-dept', '/admin/analytics?tab=demographics&dim=department'],
  ['audit', '/admin/audit'],
];

test.describe('ekran goruntuleri', () => {
  test.skip(!SHOTS, 'E2E_SHOTS=1 ile calisir');
  test.setTimeout(240_000);
  const langs = (process.env.E2E_SHOT_LANGS || 'tr,ar').split(',') as Lang[];
  for (const lang of langs) {
    for (const theme of ['light', 'dark'] as const) {
      for (const [w, h] of [
        [1440, 900],
        [390, 844],
      ] as const) {
        test(`${lang}-${theme}-${w}`, async ({ page }) => {
          await page.setViewportSize({ width: w, height: h });
          await prepare(page, { lang, theme });
          const dir = path.join('e2e', '.results', 'shots');
          fs.mkdirSync(dir, { recursive: true });
          for (const [name, url] of PAGES) {
            await page.goto(url);
            if (name === 'user-detail') {
              await page.locator('tbody tr[tabindex="0"]').first().click();
              await page.waitForURL(/\/admin\/users\/\d+/);
              await expect(page.locator('dl').first()).toBeVisible();
            }
            await page.waitForLoadState('networkidle');
            await page.waitForTimeout(700); // grafik animasyonlari
            await page.screenshot({ path: path.join(dir, `${name}.${lang}.${theme}.${w}.png`), fullPage: true });
          }
        });
      }
    }
  }
});
