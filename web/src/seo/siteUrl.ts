import { DEFAULT_PUBLIC_URL, normalizeOrigin } from './headModel';

/**
 * Sitenin herkese açık kökeni (kanonik adres, OG, JSON-LD). Derlemede `VITE_PUBLIC_URL` (Docker'da PUBLIC_WEB_URL'den)
 * verildiyse o, yoksa tarayıcıdaki köken kullanılır; böylece önrender çıktısıyla çalışma zamanı aynı kökeni yazar.
 */
export function siteOrigin(): string {
  const env = (import.meta.env.VITE_PUBLIC_URL as string | undefined)?.trim();
  if (env) return normalizeOrigin(env);
  return typeof window !== 'undefined' && window.location.origin ? window.location.origin : DEFAULT_PUBLIC_URL;
}
