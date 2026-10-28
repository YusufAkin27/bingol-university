/** Moderasyon ve mesaj çözme sayfalarının saf mantığı (sunucu kurallarıyla uyumlu doğrulamalar). */
import type {
  BulkResultRow,
  ReportReasonCode,
  ReportResolution,
  ReportTargetType,
} from '../../../api/types';

export const REASON_CODES: ReportReasonCode[] = [
  'SPAM',
  'HARASSMENT',
  'SEXUAL',
  'VIOLENCE',
  'HATE',
  'PRIVACY',
  'COPYRIGHT',
  'IMPERSONATION',
  'OTHER',
];

export const TARGET_TYPES: ReportTargetType[] = [
  'USER',
  'MESSAGE',
  'POST',
  'COMMUNITY',
  'EVENT',
  'MESSAGE_IMAGE',
  'USER_AVATAR',
  'COMMUNITY_COVER',
  'EVENT_COVER',
  'FEED_POST',
];

/** Toplu karar en çok 100 rapor kabul eder. */
export const BULK_MAX = 100;

export function isReasonCode(v: string): v is ReportReasonCode {
  return (REASON_CODES as string[]).includes(v);
}

/** Karar nedeni: geçersiz/boş kod gönderilmez (sunucu geçersizi 400 REASON_CODE_INVALID ile reddeder). */
export function cleanReasonCode(v: string | null | undefined): ReportReasonCode | undefined {
  return v && isReasonCode(v) ? v : undefined;
}

/** Seçimi ekler/çıkarır; 100 sınırını aşan ekleme yok sayılır. */
export function toggleSelected(selected: number[], id: number): number[] {
  if (selected.includes(id)) return selected.filter((x) => x !== id);
  return selected.length >= BULK_MAX ? selected : [...selected, id];
}

export interface BulkSummary {
  ok: number;
  failed: number;
  errors: { id: number; error: string }[];
}

export function summarizeBulk(rows: BulkResultRow[]): BulkSummary {
  const errors = rows.filter((r) => !r.ok).map((r) => ({ id: r.id, error: r.error ?? 'UNKNOWN' }));
  return { ok: rows.length - errors.length, failed: errors.length, errors };
}

/** Toplu gönderimde yalnızca mesaj kullanan kararlar (WARN, SUSPEND_USER) mesaj taşır. */
export function usesMessage(action: ReportResolution): boolean {
  return action === 'WARN' || action === 'SUSPEND_USER';
}

/**
 * Önizleme görseli kimlik doğrulama gerektiren `/api/...` adresindeyse Bearer başlığıyla çekilmelidir;
 * bu durumda `/api` öneki atılmış yolu döndürür (API istemcisi ekler). `/files/...` ve https adresleri doğrudan kullanılır.
 */
export function previewApiPath(url: string | null | undefined): string | null {
  if (!url) return null;
  return url.startsWith('/api/') ? url.slice(4) : null;
}

/** Görsel adresi güvenle `<img src>` olabilir mi (yalnız aynı kök yol ya da https). */
export function isSafeImageUrl(url: string | null | undefined): boolean {
  if (!url) return false;
  return (url.startsWith('/') && !url.startsWith('//')) || /^https:\/\//i.test(url);
}

const SHA256 = /^[0-9a-f]{64}$/i;
export function isValidSha256(v: string): boolean {
  return SHA256.test(v.trim());
}
export function normalizeSha256(v: string): string {
  return v.trim().toLowerCase();
}
/** Tabloda göstermek için kısaltır: ilk 12 + … + son 6. */
export function shortHash(v: string): string {
  return v.length > 20 ? `${v.slice(0, 12)}…${v.slice(-6)}` : v;
}

/** Kimlik girdisi: yalnızca pozitif tam sayı (aksi null). */
export function parseId(v: string): number | null {
  const s = v.trim();
  if (!/^\d{1,15}$/.test(s)) return null;
  const n = Number(s);
  return n >= 1 ? n : null;
}

/** Sayım gösterimi: sonraki sayfa varsa "50+" gibi. */
export function countLabel(count: number, hasMore: boolean): string {
  return hasMore ? `${count}+` : String(count);
}

