import { ApiError, type ExtraOptions } from './client';

/** Yıkıcı yönetici işlemlerinde sebep + `Idempotency-Key`. */
export interface GuardOpts {
  reason?: string;
  idempotencyKey?: string;
}

/** Kontrol karakteri mi: C0 (NUL, sekme, CR, LF...), DEL, C1 ve satır/paragraf ayırıcıları. */
function isControl(code: number): boolean {
  return code <= 0x1f || (code >= 0x7f && code <= 0x9f) || code === 0x2028 || code === 0x2029;
}

/** CR/LF/sekme/NUL ve diğer kontrol karakterleri: sunucu `X-Admin-Reason` içinde bunları 400 REASON_INVALID sayar. */
export function hasControlChars(text: string): boolean {
  for (let i = 0; i < text.length; i++) if (isControl(text.charCodeAt(i))) return true;
  return false;
}

/** Sebebi başlığa uygun hâle getirir: kontrol karakterleri (satır sonu, sekme...) boşluğa çevrilir, kırpılır. */
export function cleanReason(reason: string | undefined | null): string {
  let out = '';
  for (const ch of reason ?? '') out += isControl(ch.charCodeAt(0)) ? ' ' : ch;
  return out.trim();
}

/**
 * İstek başlıkları: `Idempotency-Key` ve `X-Admin-Reason` (HTTP başlığı ASCII olduğundan yüzde-kodlu; sunucu
 * UTF-8 çözer, bkz. docs/ADMIN_API.md "Sebep"). Hiçbiri yoksa `undefined` (başlık eklenmez).
 * Sebepteki kontrol karakterleri boşluğa çevrilir (aksi halde sunucu 400 REASON_INVALID verir).
 */
export function guardHeaders(o?: GuardOpts): ExtraOptions | undefined {
  const headers: Record<string, string> = {};
  if (o?.idempotencyKey) headers['Idempotency-Key'] = o.idempotencyKey;
  const reason = cleanReason(o?.reason);
  if (reason) headers['X-Admin-Reason'] = encodeURIComponent(reason);
  return Object.keys(headers).length ? { headers } : undefined;
}

/**
 * `/api/admin/**` yoluna konan tek bir parça (anahtar, e-posta, tablo adı...). Sunucu `AdminPathGuardFilter` yalnız
 * `%40` (e-postadaki `@`) kabul eder; başka `%xx` (örn. kodlanmış `/` ya da boşluk) 400 ADMIN_PATH_INVALID verir.
 * Böyle bir parça üretecek değer sunucuya hiç gönderilmeden aynı kodla reddedilir.
 */
export function adminSeg(value: string | number): string {
  const enc = encodeURIComponent(String(value));
  if (/%(?!40)/i.test(enc)) {
    throw new ApiError(400, 'ADMIN_PATH_INVALID', 'Invalid admin path segment');
  }
  return enc;
}
