// Ayarlar ve yetki sayfaları (sistem2) metinleri: kullanıldığı sayfaların tembel parçasında yüklenir (ana admin.tr
// parçası bütçesini şişirmemek için); modül yüklenince kayıt defterine eklenir. Anahtarlar tip dışıdır: `useGt` td() üzerinden çevirir.
import { useMemo } from 'react';
import { useI18n, type I18n } from '../../i18n/I18nProvider';
import { registerExtraEntries, type TParams } from '../../i18n/registry';
import dict from '../../i18n/tr/admin-sys2';

registerExtraEntries(dict);

export type GT = (key: string, params?: TParams) => string;

/** Sayfa çevirisi: anahtar yoksa anahtarın kendisini döndürür. */
export const gt =
  (i18n: I18n): GT =>
  (key, params) =>
    i18n.td(key, key, params);

/** Bileşen kancası: `const gt = useGt(); gt('admin.sys2.audit.summary')`. */
export function useGt(): GT {
  const i18n = useI18n();
  return useMemo(() => gt(i18n), [i18n]);
}
