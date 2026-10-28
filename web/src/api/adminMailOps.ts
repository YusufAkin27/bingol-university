// Yönetici mail altyapısı (P13): bastırma listesi, mail kuyruğu, günlük kota.
// Sözleşme: docs/ADMIN_API.md "P13". Yazma uçları sebep ister (X-Admin-Reason + gövdede `reason`); bastırma kaldırmada
// kullanıcının kendi çıkışı (UNSUBSCRIBED/COMPLAINT) için ek onay başlığı `X-Admin-Confirm: <kayıt kimliği>` gerekir.
// Listelerde adres HER ZAMAN maskelidir; kuyruk yanıtlarında posta içeriği/değişkenleri yoktur.
import { api, apiBlob } from './client';
import { guardHeaders, type GuardOpts } from './guard';

export interface MailPage<T> {
  items: T[];
  page: number;
  size: number;
  total: number;
  totalPages: number;
}

export type SuppressionReason = 'UNSUBSCRIBED' | 'BOUNCED' | 'COMPLAINT' | 'MANUAL';
export type MailCategory = 'TRANSACTIONAL' | 'ANNOUNCEMENT';
export type OutboxStatus = 'PENDING' | 'FAILED' | 'SENT' | 'DEAD' | 'SKIPPED';
export type OutboxTemplate =
  | 'VERIFICATION_CODE'
  | 'PASSWORD_RESET_CODE'
  | 'ACCOUNT_DELETED'
  | 'SECURITY_NEW_LOGIN'
  | 'SECURITY_PASSWORD_CHANGED'
  | 'ANNOUNCEMENT'
  | 'CUSTOM';

export const SUPPRESSION_REASONS: SuppressionReason[] = ['UNSUBSCRIBED', 'BOUNCED', 'COMPLAINT', 'MANUAL'];
export const OUTBOX_STATUSES: OutboxStatus[] = ['PENDING', 'FAILED', 'SENT', 'DEAD', 'SKIPPED'];
export const OUTBOX_TEMPLATES: OutboxTemplate[] = [
  'VERIFICATION_CODE',
  'PASSWORD_RESET_CODE',
  'ACCOUNT_DELETED',
  'SECURITY_NEW_LOGIN',
  'SECURITY_PASSWORD_CHANGED',
  'ANNOUNCEMENT',
  'CUSTOM',
];
export const BULK_MAX = 200;
/** Kullanıcının kendi çıkışını (UNSUBSCRIBED/COMPLAINT) kaldırmak için en kısa sebep. */
export const OPT_OUT_MIN_REASON = 20;
export const DEFAULT_MIN_REASON = 5;

/** Sorgu anahtarları (api/queryKeys.ts ortak dosyasına dokunmamak için burada). */
export const mailOpsKeys = {
  all: ['admin', 'mailops'] as const,
  suppressions: ['admin', 'mailops', 'suppressions'] as const,
  outbox: ['admin', 'mailops', 'outbox'] as const,
  quota: ['admin', 'mailops', 'quota'] as const,
};

// ---------------- bastırma ----------------

export interface SuppressionRow {
  id: number;
  /** Maskeli adres; çözülemiyorsa null (adres bastırma tablosunda düz tutulmaz). */
  emailMasked: string | null;
  hashPrefix: string;
  reason: SuppressionReason;
  category: MailCategory;
  note: string | null;
  createdAt: string;
  createdBy: number | null;
  /** Kullanıcının kendi iradesi (abonelikten çıktı ya da şikayet). */
  userOptOut: boolean;
}

export interface SuppressionDetail {
  id: number;
  emailMasked: string | null;
  /** Yalnız bir kullanıcı hesabı bu özetle eşleşiyorsa dolu. */
  fullEmail: string | null;
  fullEmailResolved: boolean;
  userId: number | null;
  hashPrefix: string;
  reason: SuppressionReason;
  category: MailCategory;
  note: string | null;
  createdAt: string;
  createdBy: number | null;
  userOptOut: boolean;
  removeMinReason: number;
  removeNeedsConfirm: boolean;
  removeWarning: string | null;
}

export interface SuppressionFilters {
  reason?: SuppressionReason | '';
  category?: MailCategory | '';
  q?: string;
  from?: string;
  to?: string;
  page?: number;
  size?: number;
}

export interface SuppressionCreate {
  email: string;
  note: string;
}

export const listSuppressions = (f: SuppressionFilters = {}) =>
  api.get<MailPage<SuppressionRow>>('/admin/mail/suppressions', {
    reason: f.reason || undefined,
    category: f.category || undefined,
    q: f.q?.trim() || undefined,
    from: f.from || undefined,
    to: f.to || undefined,
    page: f.page ?? 0,
    size: f.size ?? 20,
  });

export const getSuppression = (id: number) => api.get<SuppressionDetail>(`/admin/mail/suppressions/${id}`);

/** Elle ekleme: not = zorunlu sebep (en az 5 karakter); yalnız MANUAL. */
export const addSuppression = (b: SuppressionCreate, o: GuardOpts = {}) =>
  api.post<SuppressionRow>(
    '/admin/mail/suppressions',
    { email: b.email.trim(), reason: 'MANUAL', note: b.note.trim() },
    guardHeaders({ ...o, reason: o.reason ?? b.note }),
  );

/** Kaldırma; `confirm` yalnız UNSUBSCRIBED/COMPLAINT için gerekir (kayıt kimliği). */
export const removeSuppression = (id: number, o: GuardOpts & { reason: string; confirm?: boolean }) => {
  const base = guardHeaders(o);
  const headers: Record<string, string> = { ...(base?.headers ?? {}) };
  if (o.confirm) headers['X-Admin-Confirm'] = String(id);
  return api.del(`/admin/mail/suppressions/${id}`, { headers });
};

export const exportSuppressionsCsv = (f: SuppressionFilters = {}): Promise<Blob> =>
  apiBlob('/admin/mail/suppressions/export.csv', {
    query: {
      reason: f.reason || undefined,
      category: f.category || undefined,
      q: f.q?.trim() || undefined,
      from: f.from || undefined,
      to: f.to || undefined,
    },
  });

// ---------------- kuyruk ----------------

export interface OutboxRow {
  id: number;
  status: OutboxStatus;
  template: OutboxTemplate;
  category: MailCategory;
  toMasked: string;
  lang: string;
  attempts: number;
  nextAttemptAt: string | null;
  createdAt: string;
  sentAt: string | null;
  lastError: string | null;
  retryable: boolean;
  cancellable: boolean;
}

export interface TimelineEvent {
  at: string | null;
  event: string;
  detail: string | null;
}

/** İçerik ve değişkenler HİÇBİR zaman dönmez (`contentIncluded` her zaman false). */
export interface OutboxDetail {
  id: number;
  status: OutboxStatus;
  template: OutboxTemplate;
  category: MailCategory;
  toMasked: string;
  lang: string;
  attempts: number;
  nextAttemptAt: string | null;
  createdAt: string;
  sentAt: string | null;
  lastError: string | null;
  retryable: boolean;
  /** Yeniden denenemiyorsa nedeni (MAILOPS_RETRY_* hata kodu). */
  retryBlockedCode: string | null;
  cancellable: boolean;
  contentCleared: boolean;
  contentIncluded: boolean;
  timeline: TimelineEvent[];
  warnings: string[];
}

export interface OutboxFilters {
  status?: OutboxStatus | '';
  template?: OutboxTemplate | '';
  category?: MailCategory | '';
  q?: string;
  from?: string;
  to?: string;
  page?: number;
  size?: number;
}

export type BulkAction = 'RETRY' | 'CANCEL';
export interface BulkResult {
  action: BulkAction;
  requested: number;
  succeeded: number;
  failed: { id: number; code: string }[];
}

export const listOutbox = (f: OutboxFilters = {}) =>
  api.get<MailPage<OutboxRow>>('/admin/mail/outbox', {
    status: f.status || undefined,
    template: f.template || undefined,
    category: f.category || undefined,
    q: f.q?.trim() || undefined,
    from: f.from || undefined,
    to: f.to || undefined,
    page: f.page ?? 0,
    size: f.size ?? 20,
  });

export const getOutbox = (id: number) => api.get<OutboxDetail>(`/admin/mail/outbox/${id}`);

export const retryOutbox = (id: number, o: GuardOpts & { reason: string }) =>
  api.post<OutboxDetail>(`/admin/mail/outbox/${id}/retry`, undefined, guardHeaders(o));

export const cancelOutbox = (id: number, o: GuardOpts & { reason: string }) =>
  api.post<OutboxDetail>(`/admin/mail/outbox/${id}/cancel`, undefined, guardHeaders(o));

export const bulkOutbox = (action: BulkAction, ids: number[], o: GuardOpts & { reason: string }) =>
  api.post<BulkResult>('/admin/mail/outbox/bulk', { action, ids, reason: o.reason.trim() }, guardHeaders(o));

// ---------------- kota ----------------

export type QuotaLevel = 'OFF' | 'OK' | 'WARN' | 'CRITICAL';

export interface QuotaView {
  mailEnabled: boolean;
  enabled: boolean;
  limit: number;
  reserve: number;
  announcementCap: number;
  used: number;
  /** Sınırsızsa -1. */
  remaining: number;
  announcementRemaining: number;
  /** Sınırsızsa -1. */
  percent: number;
  level: QuotaLevel;
  resetHourUtc: number;
  dayStart: string;
  nextReset: string;
  publicCodeUsed: number;
  publicCodeCapRegistration: number;
  publicCodeCapReset: number;
  maxCodesPerEmailPerDay: number;
  maxCodeRequestsPerIpPerDay: number;
  history: { date: string; used: number }[];
  historyNote: string;
  queue: { pending: number; failed: number; dead: number; skipped: number; oldestPendingAt: string | null };
}

export const getQuota = () => api.get<QuotaView>('/admin/mail/quota');
