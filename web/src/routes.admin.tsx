/**
 * Yönetim paneli rotaları: site paketinden TAMAMEN ayrı parça (routes.tsx bunu React.lazy ile yükler; /admin dışı
 * ziyaretçi AdminLayout, izin matrisi, grafik kütüphanesi vb. hiçbirini indirmez). Yeni yönetim sayfası: buraya lazy satır + <Route>,
 * menüde görünecekse layouts/adminNav.ts'e öğe, yolu paths.ts'e. Yollar ADMIN_BASE altına göre GÖRELİdir.
 */
import { lazy } from 'react';
import { Route, Routes } from 'react-router-dom';
import { RequireAdmin } from './auth/RequireAdmin';
import { RequirePerm } from './auth/permissions';
import { AdminLayout } from './layouts/AdminLayout';
import { AdminScope } from './layouts/AdminScope';

const LoginPage = lazy(() => import('./pages/admin/LoginPage'));
const AdminRegisterPage = lazy(() => import('./pages/admin/AdminRegisterPage'));
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
const CrashesPage = lazy(() => import('./pages/admin/CrashesPage'));
const DataRetentionPage = lazy(() => import('./pages/admin/DataRetentionPage'));
const SystemStatusPage = lazy(() => import('./pages/admin/SystemStatusPage'));
const SourcesPage = lazy(() => import('./pages/admin/SourcesPage'));
const MailTemplatesPage = lazy(() => import('./pages/admin/MailTemplatesPage'));
const MailCampaignsPage = lazy(() => import('./pages/admin/MailCampaignsPage'));
const MailSuppressionPage = lazy(() => import('./pages/admin/MailSuppressionPage'));
const MailQueuePage = lazy(() => import('./pages/admin/MailQueuePage'));
const PushOpsPage = lazy(() => import('./pages/admin/PushOpsPage'));
const EventApplicationsPage = lazy(() => import('./pages/admin/EventApplicationsPage'));
const ClubAuditPage = lazy(() => import('./pages/admin/ClubAuditPage'));
const SettingsPage = lazy(() => import('./pages/admin/SettingsPage'));
const AuditPage = lazy(() => import('./pages/admin/AuditPage'));
const MessageAccessPage = lazy(() => import('./pages/admin/MessageAccessPage'));
const RolesPage = lazy(() => import('./pages/admin/RolesPage'));
const AdminNotFoundPage = lazy(() => import('./pages/admin/AdminNotFoundPage'));

export default function AdminRoutes() {
  return (
    <Routes>
      <Route element={<AdminScope />}>
        <Route path="login" element={<LoginPage />} />
        <Route path="register" element={<AdminRegisterPage />} />
        <Route
          element={
            <RequireAdmin>
              <AdminLayout />
            </RequireAdmin>
          }
        >
          <Route index element={<DashboardPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="users/:id" element={<UserDetailPage />} />
          <Route path="users/:id/messages" element={<RequirePerm perm="chat.read"><UserMessagesPage /></RequirePerm>} />
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
          <Route path="crashes" element={<CrashesPage />} />
          <Route path="data-retention" element={<DataRetentionPage />} />
          <Route path="system" element={<SystemStatusPage />} />
          <Route path="sources" element={<SourcesPage />} />
          <Route path="mail/templates" element={<MailTemplatesPage />} />
          <Route path="mail/templates/:id" element={<MailTemplatesPage />} />
          <Route path="mail/campaigns" element={<MailCampaignsPage />} />
          <Route path="mail/campaigns/:id" element={<MailCampaignsPage />} />
          <Route path="mail/suppressions" element={<MailSuppressionPage />} />
          <Route path="mail/queue" element={<MailQueuePage />} />
          <Route path="push/ops" element={<PushOpsPage />} />
          <Route path="events/applications" element={<EventApplicationsPage />} />
          <Route path="communities/audit" element={<ClubAuditPage />} />
          <Route path="settings" element={<SettingsPage />} />
          <Route path="audit" element={<AuditPage />} />
          <Route path="audit/message-access" element={<MessageAccessPage />} />
          <Route path="roles" element={<RolesPage />} />
          <Route path="*" element={<AdminNotFoundPage />} />
        </Route>
      </Route>
    </Routes>
  );
}
