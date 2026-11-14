// Akademisyen panelinin Türkçe metinleri kendi tembel parçasındadır (ortak admin.tr parçası bütçesini şişirmemek için);
// bu modül yüklenince kayıt defterine eklenir. Panel yalnız Türkçedir: en/ar karşılığı yazılmaz ve check:i18n kapsamı dışındadır.
import { useCallback } from 'react';
import { useI18n, type I18n } from '../../i18n/I18nProvider';
import { registerExtraEntries, type TParams } from '../../i18n/registry';
import dict from './tr';

registerExtraEntries(dict);

export type T = (key: string, params?: TParams) => string;

export const makeT =
  (i18n: Pick<I18n, 'td'>): T =>
  (key, params) =>
    i18n.td(key, key, params);

/** Sayfa çevirisi: anahtar yoksa anahtarın kendisini döndürür (testler eksik anahtarı yakalar). */
export function useT(): T {
  const i18n = useI18n();
  return useCallback<T>((key, params) => i18n.td(key, key, params), [i18n]);
}
