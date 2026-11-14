import { isApiError } from '../../api/client';
import type { I18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';

/**
 * Hatayı Türkçe, eyleme yönelik metne çevirir: önce `ac.err.<KOD>`, sonra durum (429/404/ağ), en sonda ortak `errorMessage`.
 * Sunucu mesajı yalnızca bilinen bir koda bağlanamazsa gösterilir.
 */
export function acadError(i18n: Pick<I18n, 't' | 'td'>, e: unknown): string {
  if (isApiError(e)) {
    const own = i18n.td(`ac.err.${e.code}`, '');
    if (own) return own;
    if (e.status === 429) return e.retryAfter ? i18n.td('ac.err.429wait', '', { n: e.retryAfter }) : i18n.td('ac.err.429', '');
    if (e.status === 404) return i18n.td('ac.err.404', '');
    if (e.status === 0) return i18n.td('ac.err.network', '');
  }
  return errorMessage(i18n, e);
}

export const isNotApproved = (e: unknown): boolean => isApiError(e) && e.status === 403 && e.code === 'ACADEMICIAN_NOT_APPROVED';
