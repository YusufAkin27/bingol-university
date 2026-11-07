// FORUM yönetimi: sayfa metinleri sayfaların kendi tembel parçasında yüklenir (ana admin.tr parçası bütçesini şişirmemek için);
// modül yüklenince kayıt defterine eklenir. Menü etiketleri (admin.forum.nav.*) ana parçada kalır.
import type { I18n } from '../../../i18n/I18nProvider';
import { registerExtraEntries, type TParams } from '../../../i18n/registry';
import dict from '../../../i18n/tr/admin-forum';
import { adminError } from '../../../lib/errors';

registerExtraEntries(dict);

export type TF = (key: string, params?: TParams) => string;

/** Sayfa çevirisi: anahtar yoksa anahtarın son parçasını döndürür (td geri düşüşü). */
export const tf =
  (i18n: I18n): TF =>
  (key, params) =>
    i18n.td(key, key, params);

/** Forum hata kodları (`admin.forum.err.FORUM_*`) önce, sonra ortak yönetici hataları. */
export const forumError = (i18n: I18n, e: unknown): string => adminError(i18n, e, 'admin.forum.err', 'admin.err');
