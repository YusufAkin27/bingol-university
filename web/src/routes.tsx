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
import { AdminScope } from './layouts/AdminScope';
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

// --- yönetim paneli ---
const LoginPage = lazy(() => import('./pages/admin/LoginPage'));
const DashboardPage = lazy(() => import('./pages/admin/DashboardPage'));
const UsersPage = lazy(() => import('./pages/admin/UsersPage'));
const UserDetailPage = lazy(() => import('./pages/admin/UserDetailPage'));
const UserMessagesPage = lazy(() => import('./pages/admin/UserMessagesPage'));
const LegacyMessageRedirect = lazy(() => import('./pages/admin/chat/LegacyMessageRedirect'));
const ChatFeedPage = lazy(() => import('./pages/admin/ChatFeedPage'));
const PostsAdminPage = lazy(() => import('./pages/admin/PostsAdminPage'));
const MenuAdminPage = lazy(() => import('./pages/admin/MenuAdminPage'));
const PollsAdminPage = lazy(() => import('./pages/admin/PollsAdminPage'));
const AnalyticsPage = lazy(() => import('./pages/admin/AnalyticsPage'));
const ReportsPage = lazy(() => import('./pages/admin/ReportsPage'));
const TicketsPage = lazy(() => import('./pages/admin/TicketsPage'));
const TicketDetailPage = lazy(() => import('./pages/admin/TicketDetailPage'));
const FeedbackPage = lazy(() => import('./pages/admin/FeedbackPage'));
const LegalAdminPage = lazy(() => import('./pages/admin/LegalAdminPage'));
const FaqAdminPage = lazy(() => import('./pages/admin/FaqAdminPage'));
const NewsAdminPage = lazy(() => import('./pages/admin/NewsAdminPage'));
const ClubsManagePage = lazy(() => import('./pages/admin/ClubsManagePage'));
const ContentReviewPage = lazy(() => import('./pages/admin/ContentReviewPage'));
const EventsAdminPage = lazy(() => import('./pages/admin/EventsAdminPage'));
const CampaignsPage = lazy(() => import('./pages/admin/CampaignsPage'));
const CampaignComposePage = lazy(() => import('./pages/admin/CampaignComposePage'));
const AppealsPage = lazy(() => import('./pages/admin/AppealsPage'));
const SuspendRecommendationsPage = lazy(() => import('./pages/admin/SuspendRecommendationsPage'));
const BlocklistPage = lazy(() => import('./pages/admin/BlocklistPage'));
const StrikesPage = lazy(() => import('./pages/admin/StrikesPage'));
const HiddenContentPage = lazy(() => import('./pages/admin/HiddenContentPage'));
const ReasonTemplatesPage = lazy(() => import('./pages/admin/ReasonTemplatesPage'));
const AccessBansPage = lazy(() => import('./pages/admin/AccessBansPage'));
const ProfanityPage = lazy(() => import('./pages/admin/ProfanityPage'));
const CommunityCategoriesPage = lazy(() => import('./pages/admin/CommunityCategoriesPage'));
const AcademicCalendarPage = lazy(() => import('./pages/admin/academic/AcademicCalendarPage'));
const AcademicExamsPage = lazy(() => import('./pages/admin/academic/AcademicExamsPage'));
const AcademicAnnouncementsPage = lazy(() => import('./pages/admin/academic/AcademicAnnouncementsPage'));
const PendingUsersPage = lazy(() => import('./pages/admin/PendingUsersPage'));
const CryptoPage = lazy(() => import('./pages/admin/CryptoPage'));
const OpsPage = lazy(() => import('./pages/admin/OpsPage'));
const SystemStatusPage = lazy(() => import('./pages/admin/SystemStatusPage'));
const MailTemplatesPage = lazy(() => import('./pages/admin/MailTemplatesPage'));
const MailCampaignsPage = lazy(() => import('./pages/admin/MailCampaignsPage'));
const MailSuppressionPage = lazy(() => import('./pages/admin/MailSuppressionPage'));
const MailQueuePage = lazy(() => import('./pages/admin/MailQueuePage'));
const EventApplicationsPage = lazy(() => import('./pages/admin/EventApplicationsPage'));
const ClubAuditPage = lazy(() => import('./pages/admin/ClubAuditPage'));
const SettingsPage = lazy(() => import('./pages/admin/SettingsPage'));
const AuditPage = lazy(() => import('./pages/admin/AuditPage'));
const MessageAccessPage = lazy(() => import('./pages/admin/MessageAccessPage'));
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
        <Route element={<AdminScope />}>
          <Route path={`${ADMIN_BASE.slice(1)}/login`} element={<LoginPage />} />
          <Route
            path={ADMIN_BASE.slice(1)}
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
            <Route path="users/:id/message" element={<LegacyMessageRedirect />} />
            <Route path="chat-feed" element={<ChatFeedPage />} />
            <Route path="posts" element={<PostsAdminPage />} />
            <Route path="polls" element={<PollsAdminPage />} />
            <Route path="content/menu" element={<MenuAdminPage />} />
            <Route path="analytics/:tab?" element={<AnalyticsPage />} />
            <Route path="reports" element={<ReportsPage />} />
            <Route path="support/tickets" element={<TicketsPage />} />
            <Route path="support/tickets/:id" element={<TicketDetailPage />} />
            <Route path="support/feedback" element={<FeedbackPage />} />
            <Route path="content/legal" element={<LegalAdminPage />} />
            <Route path="content/faq" element={<FaqAdminPage />} />
            <Route path="content/news" element={<NewsAdminPage />} />
            <Route path="communities" element={<ClubsManagePage />} />
            <Route path="content-review" element={<ContentReviewPage />} />
            <Route path="events" element={<EventsAdminPage />} />
            <Route path="campaigns" element={<CampaignsPage />} />
            <Route path="campaigns/new" element={<CampaignComposePage />} />
            <Route path="moderation/appeals" element={<AppealsPage />} />
            <Route path="moderation/suspensions" element={<SuspendRecommendationsPage />} />
            <Route path="moderation/blocklist" element={<BlocklistPage />} />
            <Route path="moderation/strikes" element={<StrikesPage />} />
            <Route path="moderation/hidden" element={<HiddenContentPage />} />
            <Route path="moderation/reason-templates" element={<ReasonTemplatesPage />} />
            <Route path="security/access-bans" element={<AccessBansPage />} />
            <Route path="profanity" element={<ProfanityPage />} />
            <Route path="community-categories" element={<CommunityCategoriesPage />} />
            <Route path="academic/calendar" element={<AcademicCalendarPage />} />
            <Route path="academic/exams" element={<AcademicExamsPage />} />
            <Route path="academic/announcements" element={<AcademicAnnouncementsPage />} />
            <Route path="pending-users" element={<PendingUsersPage />} />
            <Route path="crypto" element={<CryptoPage />} />
            <Route path="ops" element={<OpsPage />} />
            <Route path="system" element={<SystemStatusPage />} />
            <Route path="mail/templates" element={<MailTemplatesPage />} />
            <Route path="mail/templates/:id" element={<MailTemplatesPage />} />
            <Route path="mail/campaigns" element={<MailCampaignsPage />} />
            <Route path="mail/campaigns/:id" element={<MailCampaignsPage />} />
            <Route path="mail/suppressions" element={<MailSuppressionPage />} />
            <Route path="mail/queue" element={<MailQueuePage />} />
            <Route path="events/applications" element={<EventApplicationsPage />} />
            <Route path="communities/audit" element={<ClubAuditPage />} />
            <Route path="settings" element={<SettingsPage />} />
            <Route path="audit" element={<AuditPage />} />
            <Route path="audit/message-access" element={<MessageAccessPage />} />
            <Route path="*" element={<AdminNotFoundPage />} />
          </Route>
        </Route>
      </Routes>
    </Suspense>
  );
}
