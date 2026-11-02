// Kampüs haritası sayfasının Türkçe metinleri sayfanın kendi tembel parçasında yüklenir (ana admin.tr parçası bütçesini
// şişirmemek için); modül yüklenince kayıt defterine eklenir. Anahtarlar tip dışıdır: `gt` td() üzerinden çevirir.
import type { I18n } from '../../../i18n/I18nProvider';
import { registerExtraEntries, type TParams } from '../../../i18n/registry';
import dict from '../../../i18n/tr/admin-campus';

registerExtraEntries(dict);

export type GT = (key: string, params?: TParams) => string;

/** Sayfa çevirisi: anahtar yoksa anahtarın kendisini döndürür. */
export const gt =
  (i18n: I18n): GT =>
  (key, params) =>
    i18n.td(key, key, params);

/** Doğrulama hatası (kod + isteğe bağlı sıra numarası) -> kullanıcı metni. */
export function errText(t: GT, e: { code: string; index?: number }): string {
  if (e.index !== undefined && (e.code === 'poly.format' || e.code === 'poly.range')) {
    return t(`admin.campus.err.${e.code}At`, { index: e.index });
  }
  return t(`admin.campus.err.${e.code}`);
}
