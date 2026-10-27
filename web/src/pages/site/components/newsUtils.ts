import type { NewsKind } from '../../../api/publicContent';
import type { Tone } from '../../../components/ui';

/** Yalnızca http(s) bağlantıları açılır; kaynak http ise https'e çevrilir. */
export function safeSourceUrl(url: string | null | undefined): string | null {
  if (!url) return null;
  if (!/^https?:\/\//i.test(url)) return null;
  return url.replace(/^http:\/\//i, 'https://');
}

/** Görsel yalnızca bingol.edu.tr (ve alt alanları) ise yüklenir; CSP img-src ile aynı küme. */
export function safeImageUrl(url: string | null | undefined): string | null {
  const u = safeSourceUrl(url);
  if (!u) return null;
  try {
    const host = new URL(u).hostname.toLowerCase();
    return host === 'bingol.edu.tr' || host.endsWith('.bingol.edu.tr') ? u : null;
  } catch {
    return null;
  }
}

/** Kaynak etiketi: bağlantının alan adı ("www." olmadan); yoksa null. */
export function sourceHost(url: string | null | undefined): string | null {
  const u = safeSourceUrl(url);
  if (!u) return null;
  try {
    return new URL(u).hostname.replace(/^www\./, '');
  } catch {
    return null;
  }
}

export function kindTone(kind: NewsKind): Tone {
  return kind === 'DUYURU' ? 'warning' : kind === 'ETKINLIK' ? 'info' : 'primary';
}
