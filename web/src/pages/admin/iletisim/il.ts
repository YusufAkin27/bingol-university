// İletişim grubu sayfalarının Türkçe metinleri sayfaların kendi tembel parçasında yüklenir (ana admin.tr parçası
// bütçesini şişirmemek için). Modül yüklenince kayıt defterine eklenir; anahtarlar tip dışıdır: `useIl` td() ile çevirir.
import { useMemo } from 'react';
import { useI18n } from '../../../i18n/I18nProvider';
import { registerExtraEntries, type TParams } from '../../../i18n/registry';
import dict from './dict';

registerExtraEntries(dict);

export type IL = (key: string, params?: TParams) => string;

/** Sayfa çevirisi: anahtar yoksa anahtarın kendisini döndürür (test bunu yakalar). */
export function useIl(): IL {
  const { td } = useI18n();
  return useMemo<IL>(() => (key, params) => td(key, key, params), [td]);
}
