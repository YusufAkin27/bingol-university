import type { I18n } from '../../../i18n/I18nProvider';
import { isApiError } from '../../../api/client';
import { errorMessage } from '../../../lib/errors';
import { adminErrorMessage } from '../campaigns/shared';

/** Etkinlik moderasyonu hataları: önce `admin.events.err.<KOD>`, sonra ortak yönetici/genel çeviriler.
 *  RATE_LIMITED kampanya sınırını anlattığından burada genel metne düşer. */
export function eventErrorMessage(i18n: Pick<I18n, 't' | 'td'>, e: unknown): string {
  if (isApiError(e)) {
    const own = i18n.td(`admin.events.err.${e.code}`, '');
    if (own) return own;
    if (e.code === 'RATE_LIMITED') return errorMessage(i18n, e);
  }
  return adminErrorMessage(i18n, e);
}
