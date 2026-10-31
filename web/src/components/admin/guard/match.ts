import { hasControlChars } from '../../../api/guard';

/**
 * Yazarak onay karşılaştırması. Türkçe İ/ı duyarlıdır: `tr` yerel ayarıyla küçültülür (İ→i, I→ı) ve ı→i
 * katlanır; böylece "SİL", "sil", "SIL" ve "Sıl" aynı sayılır, ama ş/ğ/ü/ö/ç ayrımı korunur.
 * Baş/son boşluk kırpılır, ardışık boşluklar tek boşluğa iner (yapıştırılan metin için).
 */
export function foldForMatch(s: string): string {
  return s.normalize('NFC').trim().replace(/\s+/g, ' ').toLocaleLowerCase('tr').replace(/ı/g, 'i');
}

/** `typed`, `target` ile eşleşiyor mu (boş hedef asla eşleşmez). */
export function matchesTarget(typed: string, target: string): boolean {
  const t = foldForMatch(target);
  return t.length > 0 && foldForMatch(typed) === t;
}

/** Sebep metni en az `min` karakter mi (boşluklar kırpılarak sayılır) ve kontrol karakteri içermiyor mu? */
export function isReasonValid(reason: string, min: number): boolean {
  return reason.trim().length >= min && !hasControlChars(reason.trim());
}

/** Toplu işlemde yazarak onay gerekir mi (N > eşik). */
export function bulkNeedsConfirm(count: number, threshold: number): boolean {
  return count > threshold;
}

export const DEFAULT_REASON_MIN = 10;
/** W1-B (T-013): ayar, kullanıcı, gönderi, kampanya, engel... işlemlerinde sunucunun en az sebep uzunluğu. */
export const ADMIN_REASON_MIN = 5;
/** W1-B (T-015): sohbet içeriği açan uçlarda en az sebep uzunluğu. */
export const CHAT_CONTENT_REASON_MIN = 20;
export const REASON_MAX = 300;
export const DEFAULT_BULK_THRESHOLD = 50;
