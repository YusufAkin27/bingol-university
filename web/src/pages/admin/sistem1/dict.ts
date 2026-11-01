// Sistem sağlığı sayfalarının (sistem1) Türkçe metinleri sayfaların kendi tembel parçasında yüklenir (ana admin.tr
// parçasını şişirmemek için); modül yüklenince kayıt defterine eklenir. Anahtarlar tip dışıdır: `s1` td() üzerinden çevirir.
import type { I18n } from '../../../i18n/I18nProvider';
import { registerExtraEntries, type TParams } from '../../../i18n/registry';
import dict from './strings';

registerExtraEntries(dict);

export type S1 = (key: string, params?: TParams) => string;

/** Sayfa çevirisi: anahtar yoksa anahtarın kendisini döndürür. */
export const s1 =
  (i18n: I18n): S1 =>
  (key, params) =>
    i18n.td(key, key, params);
