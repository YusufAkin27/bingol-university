import { Suspense, useLayoutEffect } from 'react';
import { Outlet } from 'react-router-dom';
import { I18nProvider } from '../../i18n/I18nProvider';
import { PageSkeleton } from '../../layouts/PageSkeleton';
import { useNoIndex } from '../../lib/useNoIndex';
import { AcadAuthProvider } from './auth/AcadAuth';
import './dict';

/**
 * Akademisyen paneli (giriş/kayıt dahil) YALNIZ Türkçedir ve yönetim paneliyle aynı sade monochrome belirteçleri kullanır
 * (`data-area="admin"` yalnız görünüm belirteçleri içindir; oturum ayrımıyla ilgisi yoktur). Oturum sağlayıcısı buradadır:
 * yönetim AuthProvider'ına dokunmaz.
 */
export default function AcademicianScope() {
  useNoIndex();
  useLayoutEffect(() => {
    const root = document.documentElement;
    const prev = root.getAttribute('data-area');
    root.setAttribute('data-area', 'admin');
    return () => {
      if (prev) root.setAttribute('data-area', prev);
      else root.removeAttribute('data-area');
    };
  }, []);
  return (
    <I18nProvider forcedLang="tr" scope="admin">
      <AcadAuthProvider>
        {/* giriş/kayıt/beklemede sayfaları kabuk dışındadır: kendi yükleme sınırları */}
        <Suspense fallback={<PageSkeleton />}>
          <Outlet />
        </Suspense>
      </AcadAuthProvider>
    </I18nProvider>
  );
}
