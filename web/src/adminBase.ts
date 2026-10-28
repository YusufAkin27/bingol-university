/**
 * Yonetim arayuzunun yol on eki (VITE_ADMIN_PATH, ornek /yonetim-k7x2m9); ayar yoksa /admin.
 * DIKKAT: bu bir GUVENLIK onlemi DEGILDIR (yalniz gurultuyu azaltir): yol istemci paketinde acik yazilidir ve
 * /api/admin/** uclari ayni ADMIN yetkisiyle korunur. Panel rotalari (routes.tsx), baglantilar (paths.ts) ve giris
 * sonrasi donus (isAdminPath) bu on eki kullanir; boylece onek degisince panel acilmaya devam eder.
 */
export function normalizeAdminBase(raw: string | undefined): string {
  const v = (raw ?? '').trim().replace(/\/+$/, '');
  if (!v) return '/admin';
  return v.startsWith('/') ? v : `/${v}`;
}

export const ADMIN_BASE = normalizeAdminBase(import.meta.env.VITE_ADMIN_PATH);

/** Yol, yonetim on ekinin altinda mi (`/adminfoo` gibi benzer onekler sayilmaz). */
export function isAdminPath(path: string, base: string = ADMIN_BASE): boolean {
  return path === base || path.startsWith(`${base}/`);
}
