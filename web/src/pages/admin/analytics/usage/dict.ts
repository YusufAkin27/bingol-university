// Kullanım sekmesi metinleri sekmenin tembel parçasında yüklenir (admin.tr bütçesini şişirmemek için, bkz. dashboard/dict.ts).
import { useI18n, type I18n } from '../../../../i18n/I18nProvider';
import { registerExtraEntries, type TParams } from '../../../../i18n/registry';
import dict from '../../../../i18n/tr/admin-usage';

registerExtraEntries(dict);

export type UT = (key: string, params?: TParams) => string;

/** Sekme çevirisi: anahtar yoksa anahtarın kendisini döndürür. */
export const ut =
  (i18n: I18n): UT =>
  (key, params) =>
    i18n.td(key, key, params);

export function useUt(): UT {
  return ut(useI18n());
}

/** Ekran/eylem/özellik anahtarının Türkçe adı; bilinmeyen anahtar olduğu gibi (teknik ad) döner. */
export function keyLabel(i18n: I18n, kind: 'screen' | 'action' | 'feature', key: string): string {
  return i18n.td(`admin.usage.${kind}.${key}`, key);
}

export function useKeyLabel(): (kind: 'screen' | 'action' | 'feature', key: string) => string {
  const i18n = useI18n();
  return (kind, key) => keyLabel(i18n, kind, key);
}
