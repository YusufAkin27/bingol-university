// Sohbet içeriği görüntüleme sebebi (W-P02): özel yazışmaları açan her istek `X-Admin-Reason` ister (>= 10 karakter).
// Sebep yalnız BELLEKTE tutulur (modül değişkeni: sayfa kapanınca/yenilenince silinir; depoya yazılmaz) ve hedef
// (kullanıcı, akış, şikâyet) başına hatırlanır; sunucu 400 REASON_REQUIRED derse silinip yeniden istenir.
import { useCallback, useEffect, useSyncExternalStore } from 'react';
import { isApiError } from '../../../api/client';
import { DEFAULT_REASON_MIN, REASON_MAX } from '../../../components/admin/guard/match';

/** Sunucunun sohbet uçları için en az sebep uzunluğu (`message_access_audit.reason` kısıtı). */
export const CHAT_REASON_MIN = DEFAULT_REASON_MIN;
export const CHAT_REASON_MAX = REASON_MAX;

/** Hedef anahtarları: aynı hedef için sebep yeniden sorulmaz. */
export const chatReasonKey = {
  user: (userId: number | string) => `user:${userId}`,
  feed: () => 'feed',
  report: (reportId: number | string) => `report:${reportId}`,
};

const reasons = new Map<string, string>();
const rejected = new Set<string>();
const listeners = new Set<() => void>();
let version = 0;

function emit() {
  version += 1;
  listeners.forEach((l) => l());
}
function subscribe(l: () => void) {
  listeners.add(l);
  return () => {
    listeners.delete(l);
  };
}

/** Sebebi kırpar; çok kısaysa kaydetmez (false). */
export function setChatReason(key: string, reason: string): boolean {
  const r = reason.trim().slice(0, CHAT_REASON_MAX);
  if (r.length < CHAT_REASON_MIN) return false;
  reasons.set(key, r);
  rejected.delete(key);
  emit();
  return true;
}

export function getChatReason(key: string): string | null {
  return reasons.get(key) ?? null;
}

/** Sebebi unutur (kullanıcı değiştirmek istediğinde). */
export function clearChatReason(key: string): void {
  if (reasons.delete(key) || rejected.delete(key)) emit();
}

/** Sunucu sebebi reddetti: sebep silinir ve diyalog "kabul edilmedi" uyarısıyla yeniden açılır. */
export function rejectChatReason(key: string): void {
  reasons.delete(key);
  rejected.add(key);
  emit();
}

/** Tüm sebepleri siler (oturum kapanışı, testler). */
export function clearAllChatReasons(): void {
  reasons.clear();
  rejected.clear();
  emit();
}

export { reasonHeaders } from '../../../api/adminChat';

/** Sunucu "sebep gerekli/yetersiz" mi dedi (400 REASON_REQUIRED)? */
export function isReasonRequiredError(e: unknown): boolean {
  return isApiError(e) && e.status === 400 && e.code === 'REASON_REQUIRED';
}

/** Hedefe ait sebep + durum (React). */
export function useChatReason(key: string) {
  useSyncExternalStore(subscribe, () => version);
  const reason = reasons.get(key) ?? null;
  const wasRejected = rejected.has(key);
  const set = useCallback((r: string) => setChatReason(key, r), [key]);
  const clear = useCallback(() => clearChatReason(key), [key]);
  const reject = useCallback(() => rejectChatReason(key), [key]);
  return { reason, wasRejected, set, clear, reject };
}

/**
 * Sorgu hatalarından biri REASON_REQUIRED ise sebebi reddet (kapı yeniden sorar). `errors` her render'da verilir;
 * yalnız ilk reddedilen hata için bir kez çalışır.
 */
export function useRejectOnReasonError(key: string, ...errors: unknown[]): void {
  const bad = errors.some(isReasonRequiredError);
  useEffect(() => {
    if (bad) rejectChatReason(key);
  }, [bad, key]);
}
