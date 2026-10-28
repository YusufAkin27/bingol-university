/**
 * Herkese açık site rotaları + yönetim paneli girişi. Sayfalar React.lazy ile bölünür; her sayfa kendi dosyasında yaşar.
 * Yeni site sayfası: (1) pages/site altında dosyayı aç, (2) aşağıya lazy satırı + <Route> ekle, (3) yolu paths.ts'e yaz.
 * Yeni yönetim sayfası: routes.admin.tsx (ayrı parça), menüye layouts/adminNav.ts.
 */
import { lazy, Suspense } from 'react';
import { Route, Routes } from 'react-router-dom';
import { Spinner } from './components/ui/Feedback';
import { LangScope, RootRedirect } from './layouts/LangScope';
import { SiteLayout } from './layouts/SiteLayout';
import { ADMIN_BASE } from './adminBase';

// --- tanıtım sitesi ---
const HomePage = lazy(() => import('./pages/site/HomePage'));
const AboutPage = lazy(() => import('./pages/site/AboutPage'));
const FeaturesPage = lazy(() => import('./pages/site/FeaturesPage'));
const DownloadPage = lazy(() => import('./pages/site/DownloadPage'));
const FaqPage = lazy(() => import('./pages/site/FaqPage'));
const ContactPage = lazy(() => import('./pages/site/ContactPage'));
const SupportTrackPage = lazy(() => import('./pages/site/SupportTrackPage'));
const LegalPage = lazy(() => import('./pages/site/LegalPage'));
const LegalListPage = lazy(() => import('./pages/site/LegalListPage'));
const DataRequestPage = lazy(() => import('./pages/site/DataRequestPage'));
const NotFoundPage = lazy(() => import('./pages/site/NotFoundPage'));
const CookiesPage = lazy(() => import('./pages/site/CookiesPage'));
const DeleteAccountPage = lazy(() => import('./pages/site/DeleteAccountPage'));
const AccessibilityPage = lazy(() => import('./pages/site/AccessibilityPage'));
const SitemapPage = lazy(() => import('./pages/site/SitemapPage'));
const SecurityPage = lazy(() => import('./pages/site/SecurityPage'));
const CommunityGuidelinesPage = lazy(() => import('./pages/site/CommunityGuidelinesPage'));
const HelpPage = lazy(() => import('./pages/site/HelpPage'));
const NewsListPage = lazy(() => import('./pages/site/NewsListPage'));
const NewsDetailPage = lazy(() => import('./pages/site/NewsDetailPage'));
const MenuPage = lazy(() => import('./pages/site/MenuPage'));
const BrandPage = lazy(() => import('./pages/site/BrandPage'));
const ChangelogPage = lazy(() => import('./pages/site/ChangelogPage'));

// --- yönetim paneli: ayrı parça (routes.admin.tsx); site ziyaretçisi hiçbirini indirmez ---
const AdminRoutes = lazy(() => import('./routes.admin'));

function PageFallback() {
  return (
    <div style={{ display: 'grid', placeItems: 'center', minHeight: '50vh' }}>
      <Spinner size="lg" />
    </div>
  );
}

export function AppRoutes() {
  return (
    <Suspense fallback={<PageFallback />}>
      <Routes>
        {/* Herkese açık site: /tr /en /ar önekli (dil URL'den okunur); kök ve eski adresler yönlendirilir */}
        <Route index element={<RootRedirect />} />
        <Route path=":lang" element={<LangScope />}>
          <Route element={<SiteLayout />}>
            <Route index element={<HomePage />} />
            <Route path="about" element={<AboutPage />} />
            <Route path="features" element={<FeaturesPage />} />
            <Route path="download" element={<DownloadPage />} />
            <Route path="faq" element={<FaqPage />} />
            <Route path="contact" element={<ContactPage />} />
            <Route path="support/track" element={<SupportTrackPage />} />
            <Route path="legal" element={<LegalListPage />} />
            <Route path="legal/:type" element={<LegalPage />} />
            <Route path="data-request" element={<DataRequestPage />} />
            <Route path="privacy" element={<LegalPage fixedType="PRIVACY" />} />
            <Route path="terms" element={<LegalPage fixedType="TERMS" />} />
            <Route path="cookies" element={<CookiesPage />} />
            <Route path="delete-account" element={<DeleteAccountPage />} />
            <Route path="accessibility" element={<AccessibilityPage />} />
            <Route path="sitemap" element={<SitemapPage />} />
            <Route path="security" element={<SecurityPage />} />
            <Route path="community-guidelines" element={<CommunityGuidelinesPage />} />
            <Route path="help" element={<HelpPage />} />
            <Route path="news" element={<NewsListPage />} />
            <Route path="news/:id" element={<NewsDetailPage />} />
            <Route path="menu" element={<MenuPage />} />
            <Route path="brand" element={<BrandPage />} />
            <Route path="changelog" element={<ChangelogPage />} />
            <Route path="*" element={<NotFoundPage />} />
          </Route>
        </Route>

        {/* Yönetim: YALNIZ Türkçe (AdminScope dili sabitler); giriş sayfası korumasızdır */}
        <Route path={`${ADMIN_BASE.slice(1)}/*`} element={<AdminRoutes />} />
      </Routes>
    </Suspense>
  );
}
