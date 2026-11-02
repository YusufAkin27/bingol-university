// Doğrulama kodu "yeniden iste" geri sayımı. Sunucu TEK DOĞRU KAYNAKTIR (yanıttaki `resendAfterSeconds` ya da 429
// `Retry-After`); 180 yalnız sunucudan süre gelmediğinde varsayılandır. Bitiş anı tutulur (sekme arka planda
// kısılsa da sayaç şaşmaz).
import { useCallback, useEffect, useRef, useState } from 'react';

/** Sunucudaki `app.auth.code-resend-cooldown-seconds` ile aynı varsayılan (3 dakika). */
export const CODE_RESEND_SECONDS = 180;

/** Kalan saniyeyi "d:ss" (örn. 2:59) yazar. */
export function formatClock(sec: number): string {
  const s = Math.max(0, Math.floor(sec));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

/** Sunucu yanıtından bekleme süresi (geçersizse varsayılan). */
export function resendSecondsOf(r: unknown): number {
  const v = (r as { resendAfterSeconds?: unknown } | null | undefined)?.resendAfterSeconds;
  return typeof v === 'number' && Number.isFinite(v) && v > 0 ? Math.ceil(v) : CODE_RESEND_SECONDS;
}

/** Ekran okuyucu özeti: kalan süre dakikada bir değişir (her saniye okunmaz). */
export function minutesLeft(sec: number): number {
  return Math.ceil(Math.max(0, sec) / 60);
}

/**
 * `left`: kalan saniye (0 = yeniden gönderilebilir). `restart(sn?)`: sayacı başlatır (verilmezse 180).
 * `initial`: ilk değer (0 = hemen hazır).
 */
export function useResendCountdown(initial: number = CODE_RESEND_SECONDS) {
  const deadline = useRef(Date.now() + initial * 1000);
  const [left, setLeft] = useState(initial);

  const calc = useCallback(() => Math.max(0, Math.ceil((deadline.current - Date.now()) / 1000)), []);

  useEffect(() => {
    if (left <= 0) return undefined;
    const id = window.setInterval(() => {
      const next = calc();
      setLeft(next);
      if (next <= 0) window.clearInterval(id);
    }, 1000);
    return () => window.clearInterval(id);
    // yeniden başlatma `left` 0'dan büyüğe geçince efekti tazeler; saniyelik güncellemeler efekti yenilemez
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [left > 0]);

  const restart = useCallback((seconds?: number) => {
    const s = seconds && seconds > 0 ? Math.ceil(seconds) : CODE_RESEND_SECONDS;
    deadline.current = Date.now() + s * 1000;
    setLeft(s);
  }, []);

  return { left, restart };
}
