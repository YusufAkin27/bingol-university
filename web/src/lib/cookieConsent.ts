import { useCallback, useSyncExternalStore } from 'react';
import { readStorage, removeStorage, writeStorage } from './storage';

/**
 * Çerez bilgilendirme tercihi. Site yalnızca zorunlu depolama kullandığı için burada "onay" değil
 * "bilgilendirmeyi gördüm" kaydedilir (localStorage, hata toleranslı). Analitik/izleme eklenirse
 * kategori bazlı onay buraya genişletilmelidir.
 */
export const COOKIE_KEY = 'bu.cookies';
const CURRENT = 'ack:v1';

const listeners = new Set<() => void>();
const emit = () => listeners.forEach((l) => l());

export function hasAcknowledgedCookies(): boolean {
  return readStorage('local', COOKIE_KEY) === CURRENT;
}

export function acknowledgeCookies(): void {
  writeStorage('local', COOKIE_KEY, CURRENT);
  emit();
}

export function resetCookieChoice(): void {
  removeStorage('local', COOKIE_KEY);
  emit();
}

/** Bileşenlerin tercih değişimini canlı izlemesi için. */
export function useCookieChoice() {
  const acknowledged = useSyncExternalStore(
    (cb) => {
      listeners.add(cb);
      return () => listeners.delete(cb);
    },
    hasAcknowledgedCookies,
    () => true,
  );
  const acknowledge = useCallback(acknowledgeCookies, []);
  const reset = useCallback(resetCookieChoice, []);
  return { acknowledged, acknowledge, reset };
}

/**
 * Dil ve tema tercihinin kalıcı saklanması (isteğe bağlı). Varsayılan açık; kapatılırsa `bu.lang` ve `bu.theme`
 * yazılmaz/silinir ve her ziyarette varsayılanlara dönülür. Zorunlu kayıt (`bu.cookies`) bundan etkilenmez.
 */
export const PREFS_KEY = 'bu.cookies.prefs';

export function isPrefStorageAllowed(): boolean {
  return readStorage('local', PREFS_KEY) !== 'off';
}

export function setPrefStorageAllowed(allowed: boolean): void {
  if (allowed) {
    removeStorage('local', PREFS_KEY);
  } else {
    writeStorage('local', PREFS_KEY, 'off');
    removeStorage('local', 'bu.lang');
    removeStorage('local', 'bu.theme');
  }
  emit();
}

/** Tercih saklama anahtarının canlı değeri (modal açıkken). */
export function usePrefStorage() {
  const allowed = useSyncExternalStore(
    (cb) => {
      listeners.add(cb);
      return () => listeners.delete(cb);
    },
    isPrefStorageAllowed,
    () => true,
  );
  return { allowed, setAllowed: setPrefStorageAllowed };
}
