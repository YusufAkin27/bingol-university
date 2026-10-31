// Push altyapısı sayfasının saf yardımcıları (test edilebilir, bileşen içermez).
import type { Tone } from '../../../components/ui/Badge';
import type { OutboxStatus } from '../../../api/adminPushOps';

export const STATUS_TONE: Record<OutboxStatus, Tone> = {
  PENDING: 'info',
  SENDING: 'primary',
  SENT: 'success',
  FAILED: 'warning',
  DEAD: 'danger',
  CANCELLED: 'neutral',
};

/** Açıklaması çevirilen hata kodları (admin.p14.code.<KOD>); diğerleri ham kodla gösterilir. */
export const KNOWN_CODES = new Set([
  'UNREGISTERED',
  'INVALID_ARGUMENT',
  'QUOTA_EXCEEDED',
  'UNAVAILABLE',
  'INTERNAL',
  'SENDER_ID_MISMATCH',
  'THIRD_PARTY_AUTH_ERROR',
  'EXPIRED',
  'DEVICE_MISSING',
  'PAYLOAD_UNREADABLE',
  'SEND_ERROR',
  'ADMIN_CANCELLED',
  'UNKNOWN',
]);

/** Kodu çeviri anahtarına çevirir; bilinmiyorsa null (çağıran ham kodu yazar). */
export function codeKey(code: string | null | undefined): string | null {
  return code && KNOWN_CODES.has(code) ? `admin.p14.code.${code}` : null;
}

/** DEAD (vazgeçilmiş) kayıtları hata koduna göre gruplar; çoktan aza, eşitlikte koda göre. Kodsuz kayıtlar UNKNOWN sayılır. */
export function groupByErrorCode(rows: { errorCode: string | null }[]): { code: string; count: number }[] {
  const m = new Map<string, number>();
  for (const r of rows) {
    const c = r.errorCode?.trim() || 'UNKNOWN';
    m.set(c, (m.get(c) ?? 0) + 1);
  }
  return [...m.entries()]
    .map(([code, count]) => ({ code, count }))
    .sort((a, b) => b.count - a.count || a.code.localeCompare(b.code));
}

export type FcmOffKind = 'NO_CREDENTIALS' | 'INIT_FAILED' | 'OTHER';

/**
 * FCM kapalı nedeni (sunucu `error` alanı): NO_CREDENTIALS | INIT_FAILED:<hata sınıfı> | başka. Sınıf adı sır içermez;
 * ham metin yine de gösterilir.
 */
export function fcmOffReason(error: string | null | undefined): { kind: FcmOffKind; detail: string | null } | null {
  const e = error?.trim();
  if (!e) return null;
  if (e === 'NO_CREDENTIALS') return { kind: 'NO_CREDENTIALS', detail: null };
  if (e.startsWith('INIT_FAILED')) return { kind: 'INIT_FAILED', detail: e.includes(':') ? e.slice(e.indexOf(':') + 1) : null };
  return { kind: 'OTHER', detail: e };
}

export const PLATFORM_ORDER =['android', 'ios', 'web', 'other'] as const;

/** 0..1 oranı "% 42" biçiminde yüzdeye çevirir; null ise null. */
export function percent(r: number | null | undefined): number | null {
  return r === null || r === undefined ? null : Math.round(r * 1000) / 10;
}

/** Günlük okunma oranı (yüzde); o gün bildirim yoksa null. */
export function dayRate(created: number, read: number): number | null {
  return created > 0 ? Math.round((read / created) * 1000) / 10 : null;
}

/** Tarih girdisi YYYY-MM-DD mi (boş izinli). */
export function validDate(s: string): boolean {
  return s === '' || /^\d{4}-\d{2}-\d{2}$/.test(s);
}

/** Kampanya kimliği alanı: yalnız pozitif tamsayı; geçersizse null. */
export function parseCampaignId(s: string): number | null {
  const v = s.trim().replace(/^#/, '');
  return /^\d{1,12}$/.test(v) && Number(v) > 0 ? Number(v) : null;
}

/** Hata kodu gruplarındaki toplam kayıt sayısı. */
export function sumGroups(groups: { count: number }[]): number {
  return groups.reduce((s, g) => s + g.count, 0);
}

/** Toplu işlem sonucunu "N/M" özetine çevirmek için başarısız kodlarının sayımı. */
export function failureCounts(failed: { code: string }[]): Record<string, number> {
  const out: Record<string, number> = {};
  for (const f of failed) out[f.code] = (out[f.code] ?? 0) + 1;
  return out;
}
