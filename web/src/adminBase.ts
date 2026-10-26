/**
 * Yonetim arayuzunun yol on eki. Uretimde gizli bir yola tasinir (VITE_ADMIN_PATH, ornek /yonetim-k7x2m9);
 * ayar yoksa /admin (gelistirme ve testler). Backend API'si (/api/admin/**) bundan bagimsizdir ve ADMIN yetkisiyle korunur.
 */
function normalize(raw: string | undefined): string {
  const v = (raw ?? '').trim().replace(/\/+$/, '');
  if (!v) return '/admin';
  return v.startsWith('/') ? v : `/${v}`;
}

export const ADMIN_BASE = normalize(import.meta.env.VITE_ADMIN_PATH);
