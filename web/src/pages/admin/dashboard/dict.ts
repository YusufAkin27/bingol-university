// Genel bakış + Analitik iyileştirme metinleri, kullanıldıkları sayfaların tembel parçasında yüklenir (ana admin.tr parçası bütçesini
// şişirmemek için, bkz. twofactor/dict.ts); modül yüklenince kayıt defterine eklenir. Anahtarlar tip dışıdır: `g` td() üzerinden çevirir.
import type { I18n } from '../../../i18n/I18nProvider';
import { useI18n } from '../../../i18n/I18nProvider';
import { registerExtraEntries, type TParams } from '../../../i18n/registry';
import dict from '../../../i18n/tr/admin-genel';

registerExtraEntries(dict);

export type GT = (key: string, params?: TParams) => string;

/** Sayfa çevirisi: anahtar yoksa anahtarın kendisini döndürür. */
export const gt =
  (i18n: I18n): GT =>
  (key, params) =>
    i18n.td(key, key, params);

export function useGt(): GT {
  return gt(useI18n());
}
