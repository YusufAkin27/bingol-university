import { isApiError } from '../api/client';
import type { I18n } from '../i18n/I18nProvider';

/**
 * Hatayı kullanıcıya gösterilecek çevrilmiş metne çevirir. Önce `common.error.<KOD>` aranır;
 * yoksa sunucunun (Accept-Language ile yerelleştirilmiş) mesajı, o da yoksa genel mesaj.
 */
export function errorMessage(i18n: Pick<I18n, 't' | 'td'>, e: unknown): string {
  if (isApiError(e)) {
    const known = i18n.td(`common.error.${e.code}`, '');
    if (known) return known;
    if (e.status === 0) return i18n.t('common.error.NETWORK_ERROR');
    if (e.status >= 500) return i18n.t('common.error.SERVER_ERROR');
    if (e.message && e.message !== e.code && !/^HTTP_/.test(e.code)) return e.message;
  }
  return i18n.t('common.error.UNKNOWN');
}

/**
 * Yönetim paneli için tek hata yardımcısı: önce verilen kapsamlarda (varsayılan `admin.err`) `<kapsam>.<KOD>`
 * çevirisi aranır, yoksa `errorMessage` (ortak `common.error.*` + sunucu mesajı) kullanılır.
 * Eski `adminErrorMessage` (campaigns/shared) bunun ince bir takma adıdır.
 */
export function adminError(i18n: Pick<I18n, 't' | 'td'>, e: unknown, ...scopes: string[]): string {
  if (isApiError(e)) {
    for (const scope of scopes.length ? scopes : ['admin.err']) {
      const own = i18n.td(`${scope}.${e.code}`, '');
      if (own) return own;
    }
  }
  return errorMessage(i18n, e);
}
