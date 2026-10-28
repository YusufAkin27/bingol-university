import { Outlet } from 'react-router-dom';
import { I18nProvider } from '../i18n/I18nProvider';

/**
 * Yönetim paneli (giriş sayfası dahil) YALNIZ Türkçedir: bu yerleşim dili `tr`ye sabitler.
 * Sitenin dil tercihi (localStorage) ve site sayfaları etkilenmez; panelden çıkınca eski dil geri gelir.
 * (Bildirim kutusu uygulama düzeyindeki tek ToastProvider'dır; ikinci bir bölge landmark-unique ihlali olur.)
 */
export function AdminScope() {
  return (
    <I18nProvider forcedLang="tr">
      <Outlet />
    </I18nProvider>
  );
}
