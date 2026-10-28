import { useEffect } from 'react';
import { Navigate, Outlet, useLocation, useParams } from 'react-router-dom';
import { I18nProvider, useI18n } from '../i18n/I18nProvider';
import { detectPreferredLang, isLang } from '../i18n/lang';

/**
 * Tanıtım sitesinin dil kapsamı: `/:lang/*` (tr | en | ar). Etkin dil URL'den okunur ve `bu.lang`a yazılır.
 * Geçersiz ilk parça (eski adresler: /privacy, /delete-account…) tercih edilen dilin önekiyle yönlendirilir;
 * kalıcı 301 karşılığı nginx'te (web/nginx.conf). Yönetim paneli bu kapsamın dışındadır (AdminScope: yalnız tr).
 */
export function LangScope() {
  const { lang } = useParams();
  const location = useLocation();
  const outer = useI18n();
  const valid = isLang(lang);

  // Üstteki sağlayıcıyı (toast, hata sınırı) ve kayıtlı tercihi URL diliyle eşitle
  useEffect(() => {
    if (valid && outer.lang !== lang) outer.setLang(lang);
  }, [valid, lang, outer]);

  if (!valid) {
    const tail = `${location.search}${location.hash}`;
    // /TR/privacy gibi büyük harfli önek: küçültülmüş hâline düş
    if (lang && isLang(lang.toLowerCase())) {
      return <Navigate replace to={`${location.pathname.replace(/^\/[^/]+/, `/${lang.toLowerCase()}`)}${tail}`} />;
    }
    return <Navigate replace to={`/${detectPreferredLang()}${location.pathname}${tail}`} />;
  }
  return (
    <I18nProvider forcedLang={lang}>
      <Outlet />
    </I18nProvider>
  );
}

/** `/` → tercih edilen dilin ana sayfası (replace: geri tuşu kök adreste takılmaz). */
export function RootRedirect() {
  const location = useLocation();
  return <Navigate replace to={`/${detectPreferredLang()}${location.search}${location.hash}`} />;
}
