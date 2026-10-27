/**
 * Kritik yol testleri: BACKEND'SIZ calisir (tum /api istekleri page.route ile taklit edilir).
 *   cd web && npx playwright test mocked-critical.spec.ts      (ya da: npm run e2e:mock)
 * Akislar: yonetici girisi, kullanici listesi, gonderi moderasyonu (gizle), kufur listesi (ekle/sil).
 */
import { expect, test, type Page, type Route } from '@playwright/test';

const ME = { id: 1, email: 'boss@bingol.edu.tr', displayName: 'Yonetici', role: 'ADMIN' };
const TOKENS = { accessToken: 'a.b.c', refreshToken: 'r1', expiresInSeconds: 900, tokenType: 'Bearer' };

const json = (route: Route, body: unknown, status = 200) =>
  route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

/** Varsayilan: taklit edilmeyen her /api istegi 404 (gercek sunucuya sizma olmaz). */
async function stubAll(page: Page) {
  await page.route('**/api/**', (r) => json(r, { code: 'NOT_FOUND', message: 'yok' }, 404));
  await page.route('**/api/admin/me', (r) => json(r, ME));
  await page.route('**/api/admin/analytics/**', (r) => json(r, {}, 200));
}

async function asAdmin(page: Page) {
  await page.addInitScript(() => {
    sessionStorage.setItem('bu.admin.access', 'a.b.c');
    sessionStorage.setItem('bu.admin.refresh', 'r1');
    localStorage.setItem('bu.lang', 'tr');
  });
}

const userRow = (id: number, name: string) => ({
  id, email: `${name.toLowerCase()}@bingol.edu.tr`, displayName: name, faculty: null, department: null,
  classYear: null, language: 'tr', role: 'USER', status: 'ACTIVE', emailVerified: true,
  createdAt: '2026-01-02T10:00:00Z', lastSeenAt: null, avatarUrl: null,
});

test.describe('Backendsiz kritik yollar', () => {
  test('yonetici girisi: basarili giris panele gider, hatali giris hata gosterir', async ({ page }) => {
    await stubAll(page);
    let attempts = 0;
    await page.route('**/api/auth/login', (r) => {
      attempts += 1;
      return attempts === 1
        ? json(r, { code: 'INVALID_CREDENTIALS', message: 'E-posta veya sifre hatali' }, 401)
        : json(r, TOKENS);
    });
    await page.goto('/admin/login');
    await expect(page.getByRole('heading', { level: 1, name: 'Yönetim paneli girişi' })).toBeVisible();
    await page.getByLabel('E-posta').fill('boss@bingol.edu.tr');
    await page.locator('input[type=password]').fill('yanlis-sifre');
    await page.getByRole('button', { name: 'Giriş yap' }).click();
    await expect(page.getByRole('alert')).toBeVisible();
    await page.locator('input[type=password]').fill('Sifre1234');
    await page.getByRole('button', { name: 'Giriş yap' }).click();
    await expect(page).not.toHaveURL(/\/admin\/login/);
  });

  test('kullanici listesi: satirlar gorunur ve arama istege q ekler', async ({ page }) => {
    await asAdmin(page);
    await stubAll(page);
    const queries: string[] = [];
    await page.route('**/api/admin/users?**', (r) => {
      queries.push(new URL(r.request().url()).searchParams.get('q') ?? '');
      return json(r, { items: [userRow(11, 'Ayse'), userRow(12, 'Mehmet')], page: 0, totalPages: 1, totalItems: 2 });
    });
    await page.goto('/admin/users');
    await expect(page.getByRole('heading', { level: 1, name: 'Kullanıcılar' })).toBeVisible();
    await expect(page.getByText('ayse@bingol.edu.tr')).toBeVisible();
    await expect(page.getByText('mehmet@bingol.edu.tr')).toBeVisible();
    await page.getByPlaceholder('Ad veya e-posta ara').fill('ayse');
    await expect.poll(() => queries.includes('ayse')).toBe(true);
  });

  test('gonderi moderasyonu: gonderi gerekceyle gizlenir', async ({ page }) => {
    await asAdmin(page);
    await stubAll(page);
    const post = {
      id: 5, author: { id: 11, displayName: 'Ayse', email: 'ayse@bingol.edu.tr', avatarUrl: null },
      text: 'Sorunlu gonderi metni', media: [], likeCount: 1, commentCount: 0, mediaCount: 0,
      hidden: false, deleted: false, hiddenReason: null, createdAt: '2026-10-01T10:00:00Z',
      editedAt: null, hiddenAt: null, deletedAt: null, deletedBy: null,
    };
    const counts = { postCount: 1, commentCount: 0, likeCount: 1, mediaCount: 0, hiddenCount: 0, deletedCount: 0 };
    let hideBody: { reason?: string } | null = null;
    await page.route('**/api/admin/posts/stats', (r) => json(r, { ...counts, last24h: counts }));
    await page.route('**/api/admin/posts?**', (r) => json(r, { items: [post], nextCursor: null }));
    await page.route('**/api/admin/posts/5/hide', (r) => {
      hideBody = r.request().postDataJSON() as { reason?: string };
      return json(r, { ...post, hidden: true, hiddenReason: hideBody.reason ?? null });
    });
    await page.goto('/admin/posts');
    await expect(page.getByText('Sorunlu gonderi metni')).toBeVisible();
    await page.getByTestId('post-row').getByRole('button', { name: 'Gizle' }).click();
    await page.getByRole('dialog').getByRole('textbox').fill('Spam icerik');
    await page.getByTestId('hide-confirm').click();
    await expect.poll(() => hideBody?.reason).toBe('Spam icerik');
  });

  test('kufur listesi: kelime eklenir ve silinir', async ({ page }) => {
    await asAdmin(page);
    await stubAll(page);
    const items: unknown[] = [];
    let addBody: { term?: string } | null = null;
    await page.route('**/api/admin/profanity/info', (r) =>
      json(r, {
        builtIn: { tr: 10, en: 10, ar: 10, allow: 2, source: 'x' }, adminBlock: 0, adminAllow: 0,
        settings: { enabled: true, mode: 'BLOCK' },
      }),
    );
    await page.route('**/api/admin/profanity/stats', (r) =>
      json(r, { last24h: { total: 0, byField: [] }, last7d: { total: 0, byField: [] } }),
    );
    await page.route('**/api/admin/profanity?**', (r) => json(r, { items, nextCursor: null }));
    await page.route('**/api/admin/profanity', (r) => {
      if (r.request().method() !== 'POST') return r.fallback();
      addBody = r.request().postDataJSON() as { term?: string };
      const row = { id: 9, term: addBody.term, kind: 'BLOCK', lang: 'ALL', note: null, createdBy: 1, createdAt: '2026-10-27T10:00:00Z' };
      items.push(row);
      return json(r, row, 201);
    });
    await page.route('**/api/admin/profanity/9', (r) => {
      items.length = 0;
      return r.fulfill({ status: 204 });
    });
    await page.goto('/admin/profanity');
    await expect(page.getByRole('heading', { level: 1, name: 'Uygunsuz ifade filtresi' })).toBeVisible();
    await page.getByRole('textbox', { name: /^Kelime/ }).first().fill('testkelime');
    await page.getByRole('button', { name: 'Ekle', exact: true }).click();
    await expect.poll(() => addBody?.term).toBe('testkelime');
    await expect(page.getByText('testkelime', { exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'Sil', exact: true }).first().click();
    await page.getByRole('dialog').getByRole('button', { name: 'Sil' }).click();
    await expect(page.getByText('testkelime'
, { exact: true })).toHaveCount(0);
  });
});
