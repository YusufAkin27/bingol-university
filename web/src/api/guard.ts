import type { ExtraOptions } from './client';

/** Yıkıcı yönetici işlemlerinde sebep + `Idempotency-Key`. */
export interface GuardOpts {
  reason?: string;
  idempotencyKey?: string;
}

/**
 * İstek başlıkları: `Idempotency-Key` ve `X-Admin-Reason` (HTTP başlığı ASCII olduğundan yüzde-kodlu; sunucu
 * UTF-8 çözer, bkz. docs/ADMIN_API.md "Sebep"). Hiçbiri yoksa `undefined` (başlık eklenmez).
 */
export function guardHeaders(o?: GuardOpts): ExtraOptions | undefined {
  const headers: Record<string, string> = {};
  if (o?.idempotencyKey) headers['Idempotency-Key'] = o.idempotencyKey;
  const reason = o?.reason?.trim();
  if (reason) headers['X-Admin-Reason'] = encodeURIComponent(reason);
  return Object.keys(headers).length ? { headers } : undefined;
}
