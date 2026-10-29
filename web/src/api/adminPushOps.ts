// Yönetici push altyapısı (P14): FCM durumu/doğrulama, kuyruk listesi/ayrıntı/işlemler, cihaz özeti, kampanya hataları,
// bildirim kutusu istatistikleri. Sözleşme: docs/changes/push.md "P14". Hiçbir yanıt push yükü, ham token ya da tam kullanıcı
// kimliği içermez (hedef maskelidir). Yıkıcı uçlar sebep ister (X-Admin-Reason + gövdede `reason`).
import { api } from './client';
import { guardHeaders, type GuardOpts } from './guard';

export type OutboxStatus = 'PENDING' | 'SENDING' | 'SENT' | 'FAILED' | 'DEAD' | 'CANCELLED';
export const OUTBOX_STATUSES: OutboxStatus[] = ['PENDING', 'SENDING', 'SENT', 'FAILED', 'DEAD', 'CANCELLED'];

/** Bildirim türleri (backend NotificationType). */
export const PUSH_TYPES = [
  'NEWS',
  'ANNOUNCEMENT',
  'EVENT',
  'MESSAGE',
  'COMMUNITY',
  'SYSTEM',
  'POST_LIKE',
  'POST_COMMENT',
  'COMMENT_REPLY',
  'POST_MENTION',
  'USER_FOLLOW',
] as const;

/** GET /api/admin/push/fcm/status | POST .../fcm/validate (mevcut uçlar). */
export interface FcmCheck {
  enabled: boolean;
  validated: boolean;
  projectId: string | null;
  error: string | null;
  /** Başarısızsa maskeli tanı metni (hata sınıfı, kod, HTTP durumu, kısa mesaj). */
  detail?: string | null;
}

export interface OutboxRow {
  id: number;
  status: OutboxStatus;
  type: string | null;
  campaignId: number | null;
  /** Token özetinin ilk 8 hanesi + "..." (geri çözülemez). */
  targetRef: string | null;
  /** Maskeli kullanıcı kimliği (örn. 1***5). */
  userRef: string | null;
  attempts: number;
  errorCode: string | null;
  nextAttemptAt: string | null;
  createdAt: string;
  sentAt: string | null;
}

export interface OutboxDetail extends OutboxRow {
  maxAttempts: number;
  lastError: string | null;
  priority: number;
  leaseUntil: string | null;
  canRetry: boolean;
  canCancel: boolean;
}

export interface OutboxPage {
  items: OutboxRow[];
  page: number;
  totalPages: number;
  totalItems: number;
}

export interface OutboxFilters {
  status?: OutboxStatus | '';
  type?: string;
  campaignId?: number | null;
  /** YYYY-MM-DD (İstanbul günü, ikisi de dahil). */
  from?: string;
  to?: string;
  page?: number;
  size?: number;
}

export interface OutboxActionResult {
  id: number;
  status: OutboxStatus;
}

export type BulkAction = 'RETRY' | 'CANCEL';
export const BULK_MAX = 200;

export interface BulkResult {
  action: BulkAction;
  requested: number;
  succeeded: number;
  failed: { id: number; code: 'NOT_FOUND' | 'INVALID_STATE' | string }[];
}

export interface DeviceSummary {
  totalTokens: number;
  usersWithDevice: number;
  /** Anahtarlar: android, ios, web, other. */
  byPlatform: Record<string, number>;
  byAppVersion: { version: string; count: number }[];
  activeLast7d: number;
  staleOver30d: number;
}

export interface FailureGroup {
  errorCode: string;
  status: 'DEAD' | 'FAILED';
  count: number;
  lastAt: string | null;
}

export interface CampaignFailures {
  campaignId: number;
  /** false: kampanyaya bağlı kuyruk kaydı yok (sürüm öncesi ya da saklama süresi dolmuş). */
  linked: boolean;
  totals: Record<string, number>;
  groups: FailureGroup[];
  truncated: boolean;
}

export interface NotificationStats {
  days: number;
  series: { date: string; created: number; read: number }[];
  /** 0..1; hiç bildirim yoksa null. */
  readRate: number | null;
  created: number;
  read: number;
  byType: { type: string; count: number }[];
  totalRows: number;
  unreadRows: number;
}

export const pushOpsKeys = {
  all: ['adminPushOps'] as const,
  fcm: () => ['adminPushOps', 'fcm'] as const,
  outbox: (f: OutboxFilters) => ['adminPushOps', 'outbox', f] as const,
  outboxAll: () => ['adminPushOps', 'outbox'] as const,
  detail: (id: number) => ['adminPushOps', 'detail', id] as const,
  stats: () => ['adminPushOps', 'stats'] as const,
  devices: () => ['adminPushOps', 'devices'] as const,
  failures: (id: number) => ['adminPushOps', 'failures', id] as const,
  inbox: () => ['adminPushOps', 'inbox'] as const,
};

export const getFcmStatus = () => api.get<FcmCheck>('/admin/push/fcm/status');
/** Firebase'e validateOnly isteği (hiçbir cihaza gitmez); sunucuda dakikada 5 sınırı. */
export const validateFcm = () => api.post<FcmCheck>('/admin/push/fcm/validate');

export const listOutbox = (f: OutboxFilters) =>
  api.get<OutboxPage>('/admin/push/outbox', {
    status: f.status || undefined,
    type: f.type || undefined,
    campaignId: f.campaignId ?? undefined,
    from: f.from || undefined,
    to: f.to || undefined,
    page: f.page ?? 0,
    size: f.size ?? 20,
  });
export const getOutboxDetail = (id: number) => api.get<OutboxDetail>(`/admin/push/outbox/${id}`);
export const retryOutbox = (id: number, o?: GuardOpts) =>
  api.post<OutboxActionResult>(`/admin/push/outbox/${id}/retry`, undefined, guardHeaders(o));
export const cancelOutbox = (id: number, o: GuardOpts & { reason: string }) =>
  api.post<OutboxActionResult>(`/admin/push/outbox/${id}/cancel`, { reason: o.reason }, guardHeaders(o));
export const bulkOutbox = (action: BulkAction, ids: number[], o: GuardOpts & { reason: string }) =>
  api.post<BulkResult>('/admin/push/outbox/bulk', { action, ids, reason: o.reason }, guardHeaders(o));

export const getDeviceSummary = () => api.get<DeviceSummary>('/admin/push/devices/summary');
export const getCampaignFailures = (id: number) => api.get<CampaignFailures>(`/admin/push/campaigns/${id}/failures`);
export const getNotificationStats = (days = 14) =>
  api.get<NotificationStats>('/admin/notifications/stats', { days });
