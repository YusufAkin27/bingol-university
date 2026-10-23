import { useEffect, useState } from 'react';
import { useI18n } from '../i18n/I18nProvider';

/** Değer değişimini `delay` ms geciktirir (arama kutuları için). */
export function useDebouncedValue<T>(value: T, delay = 300): T {
  const [v, setV] = useState(value);
  useEffect(() => {
    const id = setTimeout(() => setV(value), delay);
    return () => clearTimeout(id);
  }, [value, delay]);
  return v;
}

/** Sayfa başlığını ayarlar: "Başlık · Bingöl Üniversitesi" (ek, seçili dile göre). */
export function usePageTitle(title: string) {
  const { t } = useI18n();
  const suffix = t('common.appName');
  useEffect(() => {
    const prev = document.title;
    document.title = title ? `${title} · ${suffix}` : suffix;
    return () => {
      document.title = prev;
    };
  }, [title, suffix]);
}
