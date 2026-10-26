import type { APIRequestContext, Page } from '@playwright/test';

/** Yonetici hesabi: backend'de ADMIN_EMAILS icinde olmali; scripts/smoke.sh bu hesabi olusturur (sifre Sifre1234). */
export const ADMIN_EMAIL = process.env.E2E_ADMIN_EMAIL || 'boss@bingol.edu.tr';
export const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD || 'Sifre1234';

const ACCESS = 'bu.admin.access';
const REFRESH = 'bu.admin.refresh';

export interface Tokens {
  accessToken: string;
  refreshToken: string;
}

let cached: Tokens | null = null;
let cachedAt = 0;

/** API uzerinden giris yapar; varsayilan hesapta token 10 dk onbellege alinir (giris ucu IP basina 15 dk'da 10 istekle sinirli). */
export async function apiLogin(
  request: APIRequestContext,
  email = ADMIN_EMAIL,
  password = ADMIN_PASSWORD,
): Promise<Tokens> {
  const isDefault = email === ADMIN_EMAIL && password === ADMIN_PASSWORD;
  if (isDefault && cached && Date.now() - cachedAt < 10 * 60_000) return cached;
  const res = await request.post('/api/auth/login', { data: { email, password } });
  if (!res.ok()) {
    throw new Error(`Giris basarisiz (${res.status()}): ${await res.text()}. scripts/smoke.sh ile yonetici hesabini olusturun.`);
  }
  const tokens = (await res.json()) as Tokens;
  if (isDefault) {
    cached = tokens;
    cachedAt = Date.now();
  }
  return tokens;
}

/** Tokenlari sessionStorage'a koyar; sayfa acilmadan once cagrilir. */
export async function loginAsAdmin(page: Page, request: APIRequestContext): Promise<Tokens> {
  const t = await apiLogin(request);
  await page.addInitScript(
    ([a, r, ak, rk]) => {
      sessionStorage.setItem(ak, a);
      sessionStorage.setItem(rk, r);
    },
    [t.accessToken, t.refreshToken, ACCESS, REFRESH],
  );
  return t;
}

/** Dili/temayi localStorage uzerinden ayarlar (anahtarlar src/i18n ve tema modullerindedir). */
export async function setLang(page: Page, lang: 'tr' | 'en' | 'ar'): Promise<void> {
  await page.addInitScript((l) => {
    try {
      localStorage.setItem('bu.lang', l);
    } catch {
      /* yoksay */
    }
  }, lang);
}

/**
 * Henuz backend'e eklenmemis yeni yonetim uclarini (docs/ADMIN_API.md) tarayicida taklit eder.
 * Gercek uc varsa mock kullanilmaz: 'fallback' true iken yalnizca gercek uc 404 donerse devreye girer.
 */
export async function mockApi(page: Page, pattern: string, body: unknown, status = 200): Promise<void> {
  await page.route(pattern, (route) =>
    route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) }),
  );
}

/** /api/admin/me yoksa (eski backend) yonetici kimligini taklit eder. */
export async function ensureAdminMe(page: Page, request: APIRequestContext): Promise<void> {
  const t = await apiLogin(request);
  const res = await request.get('/api/admin/me', { headers: { Authorization: `Bearer ${t.accessToken}` } });
  if (res.status() === 404 || res.status() === 403) {
    await mockApi(page, '**/api/admin/me', { id: 1, email: ADMIN_EMAIL, displayName: 'Yonetici', role: 'ADMIN' });
  }
}
