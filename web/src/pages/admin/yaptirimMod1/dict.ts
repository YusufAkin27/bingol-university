// Yaptırım sayfaları (mod1) metinleri: sayfaların tembel parçasında yüklenir, modül yüklenince kayıt defterine eklenir
// (ana admin.tr parçasını şişirmemek için; bkz. twofactor/dict.ts). Anahtarlar tip dışıdır: `gt` td() üzerinden çevirir.
import { useMemo } from 'react';
import { useI18n, type I18n } from '../../../i18n/I18nProvider';
import { registerExtraEntries, type TParams } from '../../../i18n/registry';
import dict from '../../../i18n/tr/admin-mod1';

registerExtraEntries(dict);

export type GT = (key: string, params?: TParams) => string;

/** Sayfa çevirisi: anahtar yoksa anahtarın kendisini döndürür. */
export const gt =
  (i18n: Pick<I18n, 'td'>): GT =>
  (key, params) =>
    i18n.td(key, key, params);

/** Çeviri kancası: dil değişmedikçe aynı işlevi verir (useMemo/useEffect bağımlılığı olarak güvenle kullanılır). */
export function useGt(): GT {
  const { td } = useI18n();
  return useMemo(() => gt({ td }), [td]);
}
