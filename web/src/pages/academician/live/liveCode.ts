// Canlı yoklama kodu seçimi (saf işlevler). Sunucu `[fromMs, untilMs)` pencereli kodları (şimdiki + sonraki ikisi) ve kendi saatini
// (`serverNowMs`) verir; ekran, yerel saatle sunucu saati arasındaki farkla HANGİ kodun şu an geçerli olduğunu seçer. Yerel saat yanlış
// olsa da (sunucudan ±dakikalar) doğru kod gösterilir. Taze kod yoksa (ağ kopuk, sekme uyudu) kod GÖSTERİLMEZ: bayat QR asla görünmez.
import type { LiveCode } from '../../../api/academician';

/** Bu süre boyunca sunucudan yeni yanıt gelmezse QR gizlenir. */
export const STALE_MS = 10_000;
/** Yoklama aralığı: oturum açıkken 2,5 sn; kapalıyken kod gerekmediğinden 5 sn. */
export const POLL_OPEN_MS = 2_500;
export const POLL_CLOSED_MS = 5_000;

/** Sunucu saati − yerel saat (ms). `receivedLocalMs`: yanıtın yerel alınma anı (istek orta noktası). */
export const clockOffset = (serverNowMs: number, receivedLocalMs: number): number => serverNowMs - receivedLocalMs;

/** `serverNow` anında geçerli kod: fromMs <= serverNow < untilMs. Yoksa null. */
export function pickCode(codes: readonly LiveCode[], serverNowMs: number): LiveCode | null {
  return codes.find((c) => c.fromMs <= serverNowMs && serverNowMs < c.untilMs) ?? null;
}

/** Mevcut kodun hemen ardından gelen kod (önceden çizilir, geçiş anında bekleme olmaz). */
export function pickNext(codes: readonly LiveCode[], current: LiveCode | null): LiveCode | null {
  if (!current) return null;
  return codes.find((c) => c.fromMs === current.untilMs) ?? null;
}

/** Yeni yanıttaki kodları eskilerle birleştirir (kod metnine göre tekil); süresi çoktan geçenleri atar. */
export function mergeCodes(prev: readonly LiveCode[], incoming: readonly LiveCode[], serverNowMs: number): LiveCode[] {
  const byCode = new Map<string, LiveCode>();
  for (const c of [...prev, ...incoming]) byCode.set(c.code, c);
  return [...byCode.values()].filter((c) => c.untilMs > serverNowMs - 15_000).sort((a, b) => a.fromMs - b.fromMs);
}

/** Son başarılı yanıt `STALE_MS`'den eskiyse (ya da hiç gelmediyse) bayattır. */
export const isStale = (nowLocalMs: number, lastFreshLocalMs: number | null): boolean =>
  lastFreshLocalMs === null || nowLocalMs - lastFreshLocalMs > STALE_MS;

export type QrState = 'code' | 'waiting' | 'closed' | 'nocode';

/**
 * QR panelinin durumu: 'closed' oturum kapalı; 'waiting' bağlantı yok/bayat (yeni yanıt bekleniyor); 'nocode' yanıt taze ama
 * şu an için geçerli kod yok; 'code' kodu göster.
 */
export function qrState(args: {
  status: 'OPEN' | 'CLOSED' | null;
  nowLocalMs: number;
  lastFreshLocalMs: number | null;
  offsetMs: number;
  codes: readonly LiveCode[];
}): { state: QrState; code: LiveCode | null; next: LiveCode | null; serverNowMs: number } {
  const serverNowMs = args.nowLocalMs + args.offsetMs;
  if (args.status === 'CLOSED') return { state: 'closed', code: null, next: null, serverNowMs };
  if (args.status === null || isStale(args.nowLocalMs, args.lastFreshLocalMs)) return { state: 'waiting', code: null, next: null, serverNowMs };
  const code = pickCode(args.codes, serverNowMs);
  if (!code) return { state: 'nocode', code: null, next: null, serverNowMs };
  return { state: 'code', code, next: pickNext(args.codes, code), serverNowMs };
}
