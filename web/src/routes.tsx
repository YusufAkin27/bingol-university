/**
 * TÜM rotalar burada, TEK dosyada. Sayfalar React.lazy ile bölünür; her sayfa kendi dosyasında yaşar.
 * Yeni sayfa: (1) pages/... altında dosyayı aç, (2) aşağıya lazy satırı + <Route> ekle,
 * (3) yönetim menüsünde görünecekse layouts/adminNav.ts'e öğe ekle, (4) yolu paths.ts'e yaz.
 */
import { lazy, Suspense } from 'react';
import { Route, Routes } from 'react-router-dom';
import { RequireAdmin } from './auth/RequireAdmin';
import { Spinner } from './components/ui/Feedback';
import { AdminLayout } from './layouts/AdminLayout';
import { SiteLayout } from './layouts/SiteLayout';
import { ADMIN_BASE } from './adminBase';

// --- tanıtım sitesi ---
const HomePage = lazy(() => import('./pages/site/HomePage'));
const AboutPage = lazy(() => import('./pages/site/AboutPage'));
const FeaturesPage = lazy(() => import('./pages/site/FeaturesPage'));
const DownloadPage = lazy(() => import('./pages/site/DownloadPage'));
const FaqPage = lazy(() => import('./pages/site/FaqPage'));
const ContactPage = lazy(() => import('./pages/site/ContactPage'));
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

// --- yönetim paneli ---
const LoginPage = lazy(() => import('./pages/admin/LoginPage'));
const DashboardPage = lazy(() => import('./pages/admin/DashboardPage'));
const UsersPage = lazy(() => import('./pages/admin/UsersPage'));
const UserDetailPage = lazy(() => import('./pages/admin/UserDetailPage'));
const UserMessagesPage = lazy(() => import('./pages/admin/UserMessagesPage'));
const AnalyticsPage = lazy(() => import('./pages/admin/AnalyticsPage'));
const ReportsPage = lazy(() => import('./pages/admin/ReportsPage'));
const TicketsPage = lazy(() => import('./pages/admin/TicketsPage'));
const TicketDetailPage = lazy(() => import('./pages/admin/TicketDetailPage'));
const FeedbackPage = lazy(() => import('./pages/admin/FeedbackPage'));
const LegalAdminPage = lazy(() => import('./pages/admin/LegalAdminPage'));
const FaqAdminPage = lazy(() => import('./pages/admin/FaqAdminPage'));
const NewsAdminPage = lazy(() => import('./pages/admin/NewsAdminPage'));
const CommunitiesAdminPage = lazy(() => import('./pages/admin/CommunitiesAdminPage'));
const EventsAdminPage = lazy(() => import('./pages/admin/EventsAdminPage'));
const CampaignsPage = lazy(() => import('./pages/admin/CampaignsPage'));
const CampaignComposePage = lazy(() => import('./pages/admin/CampaignComposePage'));
const AppealsPage = lazy(() => import('./pages/admin/AppealsPage'));
const SuspendRecommendationsPage = lazy(() => import('./pages/admin/SuspendRecommendationsPage'));
const BlocklistPage = lazy(() => import('./pages/admin/BlocklistPage'));
const CryptoPage = lazy(() => import('./pages/admin/CryptoPage'));
const EventApplicationsPage = lazy(() => import('./pages/admin/EventApplicationsPage'));
const ClubAuditPage = lazy(() => import('./pages/admin/ClubAuditPage'));
const SettingsPage = lazy(() => import('./pages/admin/SettingsPage'));
const AuditPage = lazy(() => import('./pages/admin/AuditPage'));
const AdminNotFoundPage = lazy(() => import('./pages/admin/AdminNotFoundPage'));

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
        {/* Herkese açık site */}
        <Route element={<SiteLayout />}>
          <Route index element={<HomePage />} />
          <Route path="about" element={<AboutPage />} />
          <Route path="features" element={<FeaturesPage />} />
          <Route path="download" element={<DownloadPage />} />
          <Route path="faq" element={<FaqPage />} />
          <Route path="contact" element={<ContactPage />} />
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

        {/* Yönetim: giriş sayfası korumasızdır */}
        <Route path={`${ADMIN_BASE.slice(1)}/login`} element={<LoginPage />} />
        <Route
          path="admin"
          element={
            <RequireAdmin>
              <AdminLayout />
            </RequireAdmin>
          }
        >
          <Route index element={<DashboardPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="users/:id" element={<UserDetailPage />} />
          <Route path="users/:id/messages" element={<UserMessagesPage />} />
          <Route path="analytics/:tab?" element={<AnalyticsPage />} />
          <Route path="reports" element={<ReportsPage />} />
          <Route path="support/tickets" element={<TicketsPage />} />
          <Route path="support/tickets/:id" element={<TicketDetailPage />} />
          <Route path="support/feedback" element={<FeedbackPage />} />
          <Route path="content/legal" element={<LegalAdminPage />} />
          <Route path="content/faq" element={<FaqAdminPage />} />
          <Route path="content/news" element={<NewsAdminPage />} />
          <Route path="communities" element={<CommunitiesAdminPage />} />
          <Route path="events" element={<EventsAdminPage />} />
          <Route path="campaigns" element={<CampaignsPage />} />
          <Route path="campaigns/new" element={<CampaignComposePage />} />
          <Route path="moderation/appeals" element={<AppealsPage />} />
          <Route path="moderation/suspensions" element={<SuspendRecommendationsPage />} />
          <Route path="moderation/blocklist" element={<BlocklistPage />} />
          <Route path="crypto" element={<CryptoPage />} />
          <Route path="events/applications" element={<EventApplicationsPage />} />
          <Route path="communities/audit" element={<ClubAuditPage />} />
          <Route path="settings" element={<SettingsPage />} />
          <Route path="audit" element={<AuditPage />} />
          <Route path="*" element={<AdminNotFoundPage />} />
        </Route>
      </Routes>
    </Suspense>
  );
}
