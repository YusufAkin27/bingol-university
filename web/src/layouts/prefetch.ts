/**
 * Rota önyükleme: menü bağlantısının üzerine gelinince (fare/odak/dokunma) sayfa parçası arka planda indirilir, tıklayınca
 * beklenmez. Yükleyiciler `routes.admin.tsx` içindeki `lazy(() => import(...))` ile AYNI modülleri gösterir (aynı parça paylaşılır,
 * ek indirme olmaz). Menüye yeni sayfa eklenince buraya da satır yazılır; `prefetch.test.ts` eksiği yakalar.
 */
type Loader = () => Promise<unknown>;

export const PAGE_LOADERS: Record<string, Loader> = {
  dashboard: () => import('../pages/admin/DashboardPage'),
  analytics: () => import('../pages/admin/AnalyticsPage'),
  users: () => import('../pages/admin/UsersPage'),
  twoFactor: () => import('../pages/admin/TwoFactorPage'),
  pendingUsers: () => import('../pages/admin/PendingUsersPage'),
  suspensions: () => import('../pages/admin/SuspendRecommendationsPage'),
  appeals: () => import('../pages/admin/AppealsPage'),
  accessBans: () => import('../pages/admin/AccessBansPage'),
  reports: () => import('../pages/admin/ReportsPage'),
  chatFeed: () => import('../pages/admin/ChatFeedPage'),
  posts: () => import('../pages/admin/PostsAdminPage'),
  polls: () => import('../pages/admin/PollsAdminPage'),
  blocklist: () => import('../pages/admin/BlocklistPage'),
  strikes: () => import('../pages/admin/StrikesPage'),
  hiddenContent: () => import('../pages/admin/HiddenContentPage'),
  reasonTemplates: () => import('../pages/admin/ReasonTemplatesPage'),
  profanity: () => import('../pages/admin/ProfanityPage'),
  communities: () => import('../pages/admin/ClubsManagePage'),
  communityCategories: () => import('../pages/admin/CommunityCategoriesPage'),
  clubAudit: () => import('../pages/admin/ClubAuditPage'),
  contentReview: () => import('../pages/admin/ContentReviewPage'),
  events: () => import('../pages/admin/EventsAdminPage'),
  eventApplications: () => import('../pages/admin/EventApplicationsPage'),
  acdCalendar: () => import('../pages/admin/academic/AcademicCalendarPage'),
  acdExams: () => import('../pages/admin/academic/AcademicExamsPage'),
  acdAnnouncements: () => import('../pages/admin/academic/AcademicAnnouncementsPage'),
  tickets: () => import('../pages/admin/TicketsPage'),
  feedback: () => import('../pages/admin/FeedbackPage'),
  legal: () => import('../pages/admin/LegalAdminPage'),
  faq: () => import('../pages/admin/FaqAdminPage'),
  news: () => import('../pages/admin/NewsAdminPage'),
  unitNews: () => import('../pages/admin/UnitNewsAdminPage'),
  menu: () => import('../pages/admin/MenuAdminPage'),
  campaigns: () => import('../pages/admin/CampaignsPage'),
  mailTemplates: () => import('../pages/admin/MailTemplatesPage'),
  mailCampaigns: () => import('../pages/admin/MailCampaignsPage'),
  mailQueue: () => import('../pages/admin/MailQueuePage'),
  mailSuppressions: () => import('../pages/admin/MailSuppressionPage'),
  pushOps: () => import('../pages/admin/PushOpsPage'),
  system: () => import('../pages/admin/SystemStatusPage'),
  sources: () => import('../pages/admin/SourcesPage'),
  ops: () => import('../pages/admin/OpsPage'),
  crashes: () => import('../pages/admin/CrashesPage'),
  dataRetention: () => import('../pages/admin/DataRetentionPage'),
  backup: () => import('../pages/admin/BackupPage'),
  appVersions: () => import('../pages/admin/AppVersionsPage'),
  settings: () => import('../pages/admin/SettingsPage'),
  roles: () => import('../pages/admin/RolesPage'),
  audit: () => import('../pages/admin/AuditPage'),
  messageAccess: () => import('../pages/admin/MessageAccessPage'),
  crypto: () => import('../pages/admin/CryptoPage'),
};

const started = new Set<string>();

/** Sayfa parçasını arka planda indirir (kimlik başına bir kez; hata sessizce yok sayılır, tıklayınca normal yükleme dener). */
export function prefetchPage(id: string): void {
  if (started.has(id)) return;
  const load = PAGE_LOADERS[id];
  if (!load) return;
  started.add(id);
  // yavaş/kısıtlı bağlantıda (veri tasarrufu) önyükleme yapılmaz
  const conn = (navigator as Navigator & { connection?: { saveData?: boolean } }).connection;
  if (conn?.saveData) {
    started.delete(id);
    return;
  }
  load().catch(() => started.delete(id));
}
