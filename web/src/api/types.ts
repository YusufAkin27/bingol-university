/**
 * API tipleri. Kaynak: docs/ADMIN_API.md ve backend DTO'ları.
 * Tarihler ISO-8601 metin; tarih-yalnız alanlar `yyyy-MM-dd`.
 */

// ---------- Ortak ----------
export interface ApiErrorBody {
  code: string;
  message: string;
}

/** Sayfa tabanlı liste (page 0 tabanlı). */
export interface Page<T> {
  items: T[];
  page: number;
  totalPages: number;
  totalItems: number;
}

/** İmeç tabanlı liste: nextCursor null ise son sayfa. */
export interface CursorPage<T> {
  items: T[];
  nextCursor: number | null;
}

export type Lang = 'tr' | 'en' | 'ar';
export type Platform = 'ANDROID' | 'IOS' | 'WEB';

// ---------- Kimlik ----------
export interface LoginRequest {
  email: string;
  password: string;
}
export interface TokenResponse {
  accessToken: string;
  refreshToken: string;
  expiresInSeconds: number;
  tokenType: string;
}
export interface UserView {
  id: number;
  email: string;
  displayName: string;
}
export type Role = 'USER' | 'ADMIN';
export interface AdminMe {
  id: number;
  email: string;
  displayName: string;
  role: Role;
}

// ---------- Uygulama bilgisi / ayarlar ----------
export interface AppInfo {
  appName: string | null;
  website: string | null;
  contactEmail: string | null;
  supportEmail: string | null;
  phone: string | null;
  address: string | null;
  social: { instagram: string | null; twitter: string | null; youtube: string | null };
  banner: { text: string; url: string | null } | null;
  maintenance: { enabled: boolean; message: string | null };
  languages: Lang[];
  /** Sözleşmede mağaza bağlantıları; mevcut backend bunları `GET /app/version` ile verir. */
  stores?: { android?: string | null; ios?: string | null };
}
export interface VersionCheck {
  updateRequired: boolean;
  updateAvailable: boolean;
  latestVersion: string;
  storeUrl: string | null;
}
/** Anahtar-değer ayarlar (store_url_android, maintenance_mode, banner_text_tr, faculties, ...). */
export type Settings = Record<string, string>;

// ---------- Sözleşmeler ----------
export type LegalType = 'TERMS' | 'PRIVACY' | 'KVKK' | 'COMMUNITY_RULES';
export interface LegalSummary {
  type: LegalType;
  version: number;
  title: string;
  lang: Lang;
  publishedAt: string;
}
export interface LegalContent extends LegalSummary {
  content: string;
}
export interface LegalTranslation {
  title: string;
  content: string;
}
export interface PublishLegalRequest {
  tr: LegalTranslation;
  en?: LegalTranslation;
  ar?: LegalTranslation;
  requireReaccept?: boolean;
}
export interface LegalVersionRow {
  version: number;
  lang: Lang;
  title: string;
  content: string;
  requireReaccept: boolean;
  active: boolean;
  publishedAt: string;
}
export interface LegalAcceptanceStat {
  type: LegalType;
  version: number;
  accepted: number;
  totalActiveUsers: number;
}

// ---------- SSS ----------
export interface FaqEntry {
  id: number;
  question: string;
  answer: string;
}
export interface FaqGroup {
  category: string;
  items: FaqEntry[];
}
export interface FaqAdminView {
  id: number;
  lang: Lang;
  category: string;
  question: string;
  answer: string;
  sortOrder: number;
  published: boolean;
}
export interface FaqRequest {
  lang: Lang;
  category: string;
  question: string;
  answer: string;
  sortOrder?: number;
  published?: boolean;
}

// ---------- Kullanıcılar ----------
export type UserStatus = 'ACTIVE' | 'SUSPENDED' | 'DELETED';
export interface AdminUserRow {
  id: number;
  email: string;
  displayName: string;
  faculty: string | null;
  department: string | null;
  classYear: number | null;
  language: Lang | null;
  role: Role;
  status: UserStatus;
  emailVerified: boolean;
  createdAt: string;
  lastSeenAt: string | null;
  avatarUrl: string | null;
}
export interface AdminUserDetail extends AdminUserRow {
  bio: string | null;
  suspendedReason: string | null;
  deletedAt: string | null;
  deviceCount: number;
  platforms: Platform[];
  counts: {
    feedback: number;
    tickets: number;
    reportsAgainst: number;
    reportsFiled: number;
    conversations: number;
    communities: number;
    eventsCreated: number;
    bookmarks: number;
  };
  consents: { type: LegalType; version: number; acceptedAt: string }[];
  recentActivity: { day: string; opens: number }[];
  extras?: UserExtras;
}
export interface UserExtras {
  showEmail: boolean;
  notificationPrefs: { news: boolean; announcements: boolean; events: boolean; messages: boolean; communities: boolean };
  notificationsTotal: number;
  notificationsUnread: number;
  messagesSent: number;
  blocking: number;
  blockedBy: number;
  devices: { platform: string; registeredAt: string }[];
  communities: { id: number; name: string; role: string; status: string; joinedAt: string | null }[];
  eventsCreated: { id: number; title: string; startsAt: string; status: string; rsvp: string | null }[];
  eventsAttending: { id: number; title: string; startsAt: string; status: string; rsvp: string | null }[];
  feedback: { id: number; category: string; subject: string; status: string; createdAt: string }[];
  tickets: { id: number; category: string; subject: string; status: string; createdAt: string }[];
  reportsAgainst: { id: number; targetType: string; targetId: number; reason: string; status: string; createdAt: string }[];
  reportsFiled: { id: number; targetType: string; targetId: number; reason: string; status: string; createdAt: string }[];
}
export interface UserListParams {
  q?: string;
  status?: UserStatus;
  role?: Role;
  faculty?: string;
  department?: string;
  classYear?: number;
  language?: Lang;
  verified?: boolean;
  page?: number;
  size?: number;
  /** örn. `createdAt,desc` (createdAt | lastSeenAt | displayName) */
  sort?: string;
}
export interface BasicStats {
  users: number;
  activeUsers: number;
  suspendedUsers: number;
  openReports: number;
  newsItems: number;
}

// ---------- Analitik ----------
export interface DateRange {
  from?: string;
  to?: string;
}
export interface AnalyticsOverview {
  totalUsers: number;
  verifiedUsers: number;
  suspendedUsers: number;
  newUsers: { today: number; last7d: number; last30d: number };
  activeUsers: { dau: number; wau: number; mau: number };
  /** dau/mau, 0-1 */
  stickiness: number;
  messages: { total: number; last24h: number };
  communities: { active: number; pending: number };
  events: { upcoming: number; pending: number };
  openReports: number;
  openTickets: number;
  newFeedback: number;
  pushCampaignsSent30d: number;
  bookmarks: number;
  devices: { android: number; ios: number; web: number };
}
export interface RegistrationsResponse {
  points: { date: string; count: number; cumulative: number }[];
}
export interface ActiveUsersResponse {
  points: { date: string; dau: number }[];
  wau: number;
  mau: number;
}
export type BreakdownDimension =
  'faculty' | 'department' | 'classYear' | 'language' | 'role' | 'status' | 'platform';
export interface BreakdownResponse {
  dimension: BreakdownDimension;
  total: number;
  items: { key: string; label: string; count: number; percent: number }[];
}
export interface EngagementResponse {
  topEvents: { name: string; count: number; uniqueUsers: number }[];
  screens: { screen: string; views: number }[];
  daily: { date: string; messages: number; posts: number; rsvps: number; searches: number }[];
  funnel: { step: FunnelStep; count: number }[];
}
export type FunnelStep = 'registered' | 'verified' | 'profileCompleted' | 'joinedCommunity' | 'sentMessage';
export interface RetentionResponse {
  /** d1/d7/d30: yüzde 0-100 */
  cohorts: { weekStart: string; size: number; d1: number; d7: number; d30: number }[];
}
export interface SupportAnalytics {
  tickets: { open: number; answered: number; closed: number };
  avgFirstResponseMinutes: number | null;
  feedbackByCategory: { key: string; count: number }[];
  feedbackByStatus: { key: string; count: number }[];
}
export interface PushAnalytics {
  totals: { campaigns: number; recipients: number };
  recent: CampaignView[];
}
export interface SyncSourceStatus {
  maintenance: boolean;
  lastSuccessAt: string | null;
  lastAttemptAt?: string | null;
  message?: string | null;
}
export interface ContentAnalytics {
  daily: { date: string; news: number; announcements: number; events: number }[];
  sources: Record<string, SyncSourceStatus>;
}
export interface SyncStatus {
  [source: string]: SyncSourceStatus;
}

// ---------- Raporlar / moderasyon ----------
export type ReportStatus = 'OPEN' | 'RESOLVED';
export type ReportResolution = 'DISMISS' | 'HIDE' | 'WARN' | 'SUSPEND_USER';
export type ReportReason = 'SPAM' | 'HARASSMENT' | 'INAPPROPRIATE' | 'IMPERSONATION' | 'OTHER';
export type ReportTargetType =
  | 'USER'
  | 'MESSAGE'
  | 'POST'
  | 'COMMUNITY'
  | 'EVENT'
  | 'MESSAGE_IMAGE'
  | 'USER_AVATAR'
  | 'COMMUNITY_COVER'
  | 'EVENT_COVER';
export type ReportReasonCode =
  | 'SPAM'
  | 'HARASSMENT'
  | 'SEXUAL'
  | 'VIOLENCE'
  | 'HATE'
  | 'PRIVACY'
  | 'COPYRIGHT'
  | 'IMPERSONATION'
  | 'OTHER';
/** Kuyrukta yöneticiye gösterilen içerik önizlemesi (görsel adresi yetkili uçtan servis edilir). */
export interface MediaPreview {
  kind: 'IMAGE' | 'TEXT';
  url: string | null;
  thumbnailUrl: string | null;
  mime: string | null;
  text: string | null;
}
export interface ReportView {
  id: number;
  reporterId: number;
  targetType: ReportTargetType;
  targetId: number;
  reason: ReportReason;
  note: string | null;
  status: ReportStatus;
  resolution: ReportResolution | null;
  createdAt: string;
  /** Açık farklı raporlayıcı sayısı x 10 (+100 gizliyse). */
  priority: number;
  reasonCode: string | null;
  preview: MediaPreview | null;
  hidden: boolean;
  hiddenBy: 'AUTO' | 'ADMIN' | null;
  openReporters: number;
}
export interface ResolveReportRequest {
  action: ReportResolution;
  message?: string;
  reasonCode?: ReportReasonCode;
}
export type ReportOrder = 'asc' | 'desc' | 'priority';
export interface BulkResolveRequest extends ResolveReportRequest {
  ids: number[];
}
export interface BulkResultRow {
  id: number;
  ok: boolean;
  error: string | null;
}
export interface ReasonTemplate {
  code: ReportReasonCode;
  text: string;
  texts: Record<Lang, string>;
}

// ---------- İtirazlar, askı önerileri, yasaklı özetler ----------
export type AppealStatus = 'OPEN' | 'ACCEPTED' | 'REJECTED';
export interface AppealView {
  id: number;
  userId: number;
  targetType: ReportTargetType;
  targetId: number;
  message: string;
  status: AppealStatus;
  adminNote: string | null;
  createdAt: string;
  decidedAt: string | null;
}
export interface SuspendRecommendation {
  id: number;
  userId: number;
  strikeCount: number;
  status: 'OPEN' | 'ACCEPTED' | 'DISMISSED';
  createdAt: string;
}
export interface BlocklistEntry {
  sha256: string;
  note: string | null;
  createdBy: number | null;
  createdAt: string;
}
/** Blocklist sayfalaması: imleç son sha256'dır (sayı değil). */
export interface HashCursorPage<T> {
  items: T[];
  nextCursor: string | null;
}

// ---------- Yönetici sohbet görüntüleyici (kullanıcı bazlı) / şifreleme durumu ----------
export interface ChatPerson {
  id: number | null;
  displayName: string | null;
  avatarUrl: string | null;
}
export interface ChatLastMessage {
  id: number;
  senderId: number;
  mine: boolean;
  text: string | null;
  error: string | null;
  deleted: boolean;
  hidden: boolean;
  createdAt: string;
}
export interface AdminChatConversation {
  id: number;
  type: 'DIRECT' | 'GROUP';
  title: string | null;
  peer: ChatPerson | null;
  memberCount: number;
  /** Toplam mesaj sayısı (okunmamış değil; silinenler dahil). */
  totalMessages: number;
  lastActivityAt: string | null;
  left: boolean;
  lastMessage: ChatLastMessage | null;
}
export interface AdminChatConversationPage {
  user: ChatPerson;
  items: AdminChatConversation[];
  nextCursor: number | null;
}
export interface AdminChatAttachment {
  id: number;
  kind: string;
  contentType: string | null;
  width: number;
  height: number;
  bytes: number;
  hidden: boolean;
  /** Yönetici önizleme ucu (Bearer ile istenir): /api/admin/media/attachments/{id}/preview */
  previewUrl: string;
  thumbUrl: string;
}
export interface AdminChatRevision {
  text: string | null;
  error: string | null;
  revisedAt: string;
}
export interface AdminChatReply {
  id: number;
  senderId: number | null;
  text: string | null;
  error: string | null;
  deleted: boolean;
}
export interface AdminChatMessage {
  id: number;
  senderId: number;
  senderName: string | null;
  /** Açılan kullanıcının kendi mesajı mı (balon yönü). */
  mine: boolean;
  createdAt: string;
  text: string | null;
  error: string | null;
  edited: boolean;
  editedAt: string | null;
  revisions: AdminChatRevision[];
  deleted: boolean;
  deletedAt: string | null;
  deletedBy: number | null;
  deletedByName: string | null;
  hidden: boolean;
  replyTo: AdminChatReply | null;
  reactions: { emoji: string; userId: number }[];
  attachments: AdminChatAttachment[];
}
export interface AdminChatMessagePage {
  user: ChatPerson;
  conversation: { id: number; type: 'DIRECT' | 'GROUP'; title: string | null; peer: ChatPerson | null; left: boolean };
  /** Eskiden yeniye sıralı. */
  items: AdminChatMessage[];
  /** Daha eski sayfa için `before` imleci; yoksa null. */
  nextBefore: number | null;
}
export interface CryptoStatus {
  activeKeyId: string;
  keyIds: string[];
  devKey: boolean;
  adminDecryptEnabled: boolean;
  dekCountsByMasterKey: Record<string, number>;
}

// ---------- Etkinlik başvuruları (yönetici salt okunur) / kulüp denetimi ----------
export interface AdmissionSummary {
  eventId: number;
  mode: string;
  capacity: number | null;
  goingCount: number;
  pending: number;
  accepted: number;
  waitlisted: number;
  rejected: number;
  cancelled: number;
}
export interface ClubAuditRow {
  id: number;
  action: string;
  actorId: number | null;
  actorName: string | null;
  targetUserId: number | null;
  targetName: string | null;
  detail: string | null;
  createdAt: string;
}

// ---------- Destek ----------
export type TicketStatus = 'OPEN' | 'ANSWERED' | 'CLOSED';
export type TicketCategory = 'ACCOUNT' | 'TECHNICAL' | 'CONTENT' | 'OTHER';
export interface AdminTicketSummary {
  id: number;
  userId: number;
  userEmail: string;
  category: TicketCategory;
  subject: string;
  status: TicketStatus;
  createdAt: string;
  updatedAt: string;
}
export interface TicketSummary {
  id: number;
  category: TicketCategory;
  subject: string;
  status: TicketStatus;
  createdAt: string;
  updatedAt: string;
}
export interface TicketMessage {
  id: number;
  fromStaff: boolean;
  text: string;
  createdAt: string;
}
export interface TicketDetail {
  ticket: TicketSummary;
  messages: TicketMessage[];
}

// ---------- Geri bildirim ----------
export type FeedbackCategory = 'BUG' | 'SUGGESTION' | 'COMPLAINT' | 'PRAISE' | 'OTHER';
export type FeedbackStatus = 'NEW' | 'IN_REVIEW' | 'PLANNED' | 'DONE' | 'REJECTED';
export interface AdminFeedbackView {
  id: number;
  userId: number;
  userEmail: string;
  category: FeedbackCategory;
  subject: string;
  message: string;
  status: FeedbackStatus;
  adminResponse: string | null;
  publicVisible: boolean;
  voteCount: number;
  appVersion: string | null;
  platform: Platform | null;
  createdAt: string;
}
export interface UpdateFeedbackRequest {
  status?: FeedbackStatus;
  adminResponse?: string;
  publicVisible?: boolean;
}

// ---------- Kampanyalar ----------
export type AudienceType = 'ALL' | 'DEPARTMENT' | 'CLASS_YEAR' | 'USERS' | 'ADMINS' | 'SELF';
export type CampaignTargetType = 'NONE' | 'NEWS' | 'EVENT' | 'COMMUNITY' | 'TICKET' | 'URL';
export type CampaignStatus = 'SCHEDULED' | 'SENDING' | 'SENT' | 'CANCELLED' | 'FAILED';
export type NotificationType = 'NEWS' | 'ANNOUNCEMENT' | 'EVENT' | 'MESSAGE' | 'COMMUNITY' | 'SYSTEM';
export interface CampaignAudience {
  type: AudienceType;
  value?: string | null;
}
export interface CampaignContent {
  title: string;
  body: string;
}
export interface CampaignTarget {
  type: CampaignTargetType;
  value?: string | null;
}
export interface CreateCampaignRequest {
  type?: NotificationType;
  audience: CampaignAudience;
  tr: CampaignContent;
  en?: CampaignContent;
  ar?: CampaignContent;
  target?: CampaignTarget;
  /** ISO-8601; boş/geçmiş ise hemen gönderilir */
  scheduledAt?: string;
}
export interface CampaignView {
  id: number;
  createdBy: number;
  type: NotificationType;
  audience: CampaignAudience;
  tr: CampaignContent;
  en: CampaignContent | null;
  ar: CampaignContent | null;
  target: CampaignTarget | null;
  status: CampaignStatus;
  scheduledAt: string | null;
  startedAt: string | null;
  finishedAt: string | null;
  recipientCount: number | null;
  error: string | null;
  createdAt: string;
}
export interface AudienceCount {
  count: number;
}

// ---------- Topluluk / etkinlik ----------
export type CommunityStatus = 'PENDING_REVIEW' | 'ACTIVE' | 'REJECTED' | 'HIDDEN';
export interface CommunityView {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  category: string | null;
  coverUrl: string | null;
  joinPolicy: 'OPEN' | 'APPROVAL';
  visibility: 'PUBLIC' | 'PRIVATE';
  status: CommunityStatus;
  ownerId: number;
  memberCount: number;
  createdAt: string;
}
export type EventStatus = 'PENDING_REVIEW' | 'ACTIVE' | 'REJECTED' | 'CANCELLED' | 'HIDDEN';
export interface EventView {
  id: number;
  title: string;
  description: string | null;
  startsAt: string;
  endsAt: string;
  location: string | null;
  coverUrl: string | null;
  capacity: number | null;
  goingCount: number;
  interestedCount: number | null;
  communityId: number | null;
  communityName: string | null;
  createdBy: number;
  organizerName: string | null;
  status: EventStatus;
  createdAt: string;
}

// ---------- Haberler ----------
export type NewsType = 'HABER' | 'DUYURU' | 'ETKINLIK';
export interface NewsSummary {
  id: number;
  type: NewsType;
  title: string;
  summary: string | null;
  imageUrl: string | null;
  publishedDate: string | null;
  url: string;
}
export interface AdminNewsRow extends NewsSummary {
  hidden: boolean;
}
export interface NewsListParams {
  q?: string;
  type?: NewsType;
  hidden?: boolean;
  page?: number;
  size?: number;
}

// ---------- Denetim ----------
export interface AuditRow {
  id: number;
  adminId: number | null;
  adminEmail: string | null;
  method: string;
  path: string;
  status: number;
  at: string;
  ip: string | null;
}
export interface AuditParams {
  page?: number;
  size?: number;
  adminId?: number;
  method?: string;
  q?: string;
}
