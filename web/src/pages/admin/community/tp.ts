// PANEL-topluluk: topluluk/etkinlik sayfalarının ek metinleri sayfaların kendi tembel parçasında yüklenir
// (ana admin.tr parçası bütçesini şişirmemek için); modül yüklenince kayıt defterine eklenir.
import type { I18n } from '../../../i18n/I18nProvider';
import { registerExtraEntries, type TParams } from '../../../i18n/registry';
import dict from '../../../i18n/tr/admin-topluluk';

registerExtraEntries(dict);

export type TP = (key: string, params?: TParams) => string;

/** Sayfa çevirisi: anahtar yoksa anahtarın son parçasını döndürür (td geri düşüşü). */
export const tp =
  (i18n: I18n): TP =>
  (key, params) =>
    i18n.td(key, key, params);
