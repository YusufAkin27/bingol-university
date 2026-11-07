// İnsanlar grubu ek metinleri: sayfaların tembel parçasında yüklenir, kayıt defterine eklenir (admin.tr'yi şişirmez).
import type { I18n } from '../../../i18n/I18nProvider';
import { registerExtraEntries, type TParams } from '../../../i18n/registry';
import dict from '../../../i18n/tr/admin-insan';

registerExtraEntries(dict);

export type IT = (key: string, params?: TParams) => string;

/** Sayfa çevirisi: anahtar yoksa anahtarın kendisi döner. */
export const it =
  (i18n: I18n): IT =>
  (key, params) =>
    i18n.td(key, key, params);
