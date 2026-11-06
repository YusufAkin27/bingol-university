import { useLayoutEffect } from 'react';
import { Outlet } from 'react-router-dom';
import { I18nProvider } from '../i18n/I18nProvider';

/**
 * Yönetim paneli (giriş sayfası dahil) YALNIZ Türkçedir: bu yerleşim dili `tr`ye sabitler.
 * Sitenin dil tercihi (localStorage) ve site sayfaları etkilenmez; panelden çıkınca eski dil geri gelir.
 * (Bildirim kutusu uygulama düzeyindeki tek ToastProvider'dır; ikinci bir bölge landmark-unique ihlali olur.)
 */
export function AdminScope() {
  // Yönetim alanı işareti giriş/kayıt sayfalarını da kapsar: monochrome belirteçler (tokens.css) buna bağlıdır
  useLayoutEffect(() => {
    const root = document.documentElement;
    root.setAttribute('data-area', 'admin');
    return () => root.removeAttribute('data-area');
  }, []);
  return (
    <I18nProvider forcedLang="tr" scope="admin">
      <Outlet />
    </I18nProvider>
  );
}
