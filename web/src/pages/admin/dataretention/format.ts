// Veri saklama sayfası ortak yardımcıları (saf fonksiyonlar, birim testlidir).
import type { SystemLevel } from '../../../api/system';

/** Bayt → insan okunur metin (1024 tabanlı, en çok 1 ondalık). Boş/geçersiz → "—". */
export function formatBytes(n: number | null | undefined, locale = 'tr-TR'): string {
  if (n === null || n === undefined || !Number.isFinite(n) || n < 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let v = n;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  const f = new Intl.NumberFormat(locale, { maximumFractionDigits: i === 0 ? 0 : 1 }).format(v);
  return `${f} ${units[i]}`;
}

/** Yüzdeyi renk + metin düzeyine çevirir; sunucu durumu bilinmiyorsa eşiklere bakar. */
export function levelOfPercent(pct: number | null | undefined, warn: number, crit: number): SystemLevel {
  if (pct === null || pct === undefined || !Number.isFinite(pct)) return 'UNKNOWN';
  if (pct >= crit) return 'CRIT';
  if (pct >= warn) return 'WARN';
  return 'OK';
}

/** yyyy-MM-dd: yerel saatte bugünden `days` gün önce (tarih seçicinin üst sınırı için yedek). */
export function isoDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/** Aralık geçerli mi: bitiş dolu, başlangıç (varsa) bitişten önce, bitiş izin verilen son tarihi aşmıyor. */
export function rangeValid(from: string, to: string, maxTo: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(to)) return false;
  if (to > maxTo) return false;
  if (from && !/^\d{4}-\d{2}-\d{2}$/.test(from)) return false;
  if (from && from >= to) return false;
  return true;
}

/** SHA-256 (hex) hesaplar; tarayıcıda `crypto.subtle` yoksa null. */
export async function sha256Hex(blob: Blob): Promise<string | null> {
  try {
    const subtle = (globalThis as { crypto?: Crypto }).crypto?.subtle;
    if (!subtle) return null;
    const buf = await blob.arrayBuffer();
    const digest = await subtle.digest('SHA-256', buf);
    return Array.from(new Uint8Array(digest))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
  } catch {
    return null;
  }
}

/** Dosyayı tarayıcıya indirtir (nesne URL'i + gizli bağlantı). */
export function saveBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  try {
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.rel = 'noopener';
    document.body.appendChild(a);
    a.click();
    a.remove();
  } finally {
    setTimeout(() => URL.revokeObjectURL(url), 30_000);
  }
}
