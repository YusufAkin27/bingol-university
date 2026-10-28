// Moderasyon tamamlama (P11): ihlal listesi + af, gizlenen içerik + geri alma, sebep şablonu yönetimi, rapor/itiraz CSV.
// Sözleşme: docs/ADMIN_API.md "P11". Yıkıcı uçlar sebep ister (X-Admin-Reason + gövdede `reason`).
import { api, apiBlob } from './client';
import { guardHeaders, type GuardOpts } from './guard';
import type { MediaPreview, ReportTargetType } from './types';

/** Sayfa tabanlı yanıt (page 0'dan başlar). */
export interface ModPage<T> {
  items: T[];
  page: number;
  size: number;
  total: number;
  totalPages: number;
}

export type StrikeStatus = 'ALL' | 'ACTIVE' | 'REVOKED';
export type StrikeResolution = 'DISMISS' | 'HIDE' | 'WARN' | 'SUSPEND_USER';

export interface StrikeRow {
  id: number;
  userId: number;
  userName: string | null;
  userEmail: string | null;
  reportId: number | null;
  targetType: ReportTargetType;
  targetId: number;
  resolution: StrikeResolution;
  createdAt: string;
  revokedAt: string | null;
  /** true: ihlal sayılıyor. */
  active: boolean;
  /** true: yönetici affı (itiraz kabulüyle iptal edilenler false). */
  forgiven: boolean;
  forgivenBy: number | null;
  forgivenReason: string | null;
}

export interface StrikeFilters {
  userId?: number | null;
  status?: StrikeStatus;
  targetType?: ReportTargetType | '';
  resolution?: StrikeResolution | '';
  from?: string;
  to?: string;
  page?: number;
  size?: number;
}

export interface ForgiveResult {
  id: number;
  userId: number;
  /** Kullanıcının kalan (sayılan) ihlal sayısı. */
  remaining: number;
}

export interface UserStrikes {
  userId: number;
  activeCount: number;
  items: StrikeRow[];
}

export interface HiddenRow {
  targetType: ReportTargetType;
  targetId: number;
  hiddenBy: 'AUTO' | 'ADMIN';
  hiddenAt: string | null;
  /** false: bu tür geri alınamaz (yalnız yönetici kararıyla gizlenir). */
  reversible: boolean;
  /** false: içerik artık yok (silinmiş). */
  exists: boolean;
  ownerId: number | null;
  ownerName: string | null;
  preview: MediaPreview | null;
}

export interface HiddenFilters {
  targetType?: ReportTargetType | '';
  hiddenBy?: 'AUTO' | 'ADMIN' | '';
  from?: string;
  to?: string;
  page?: number;
  size?: number;
}

export interface RestoreResult {
  targetType: ReportTargetType;
  targetId: number;
  unhidden: boolean;
}

export interface ReasonTemplateRow {
  id: number;
  kind: string;
  code: string;
  textTr: string;
  textEn: string | null;
  textAr: string | null;
  active: boolean;
  sortOrder: number;
  updatedAt: string;
}

export interface ReasonTemplateForm {
  code?: string;
  textTr: string;
  textEn?: string;
  textAr?: string;
  active?: boolean;
  sortOrder?: number;
}

export const MAX_REASON_TEMPLATES = 50;

export const listStrikes = (f: StrikeFilters = {}) =>
  api.get<ModPage<StrikeRow>>('/admin/moderation/strikes', {
    userId: f.userId ?? undefined,
    status: f.status && f.status !== 'ALL' ? f.status : undefined,
    targetType: f.targetType || undefined,
    resolution: f.resolution || undefined,
    from: f.from || undefined,
    to: f.to || undefined,
    page: f.page ?? 0,
    size: f.size ?? 20,
  });

export const listUserStrikes = (userId: number) => api.get<UserStrikes>(`/admin/users/${userId}/strikes`);

/** Af: sebep zorunlu (gövde + başlık); kullanıcıya bildirim gider, sayaç düşer. */
export const forgiveStrike = (id: number, o: GuardOpts & { reason: string }) =>
  api.post<ForgiveResult>(`/admin/moderation/strikes/${id}/forgive`, { reason: o.reason.trim() }, guardHeaders(o));

export const listHidden = (f: HiddenFilters = {}) =>
  api.get<ModPage<HiddenRow>>('/admin/moderation/hidden', {
    targetType: f.targetType || undefined,
    hiddenBy: f.hiddenBy || undefined,
    from: f.from || undefined,
    to: f.to || undefined,
    page: f.page ?? 0,
    size: f.size ?? 20,
  });

/** Geri al: yalnız `reversible` türler; geri alınamayan tür 409 TARGET_NOT_REVERSIBLE. */
export const restoreHidden = (type: ReportTargetType, id: number, o: GuardOpts & { reason: string }) =>
  api.post<RestoreResult>(`/admin/moderation/hidden/${type}/${id}/restore`, { reason: o.reason.trim() }, guardHeaders(o));

export const listReasonTemplates = () =>
  api.get<{ items: ReasonTemplateRow[]; max: number }>('/admin/moderation/reason-templates');
export const createReasonTemplate = (r: ReasonTemplateForm) =>
  api.post<ReasonTemplateRow>('/admin/moderation/reason-templates', r);
export const updateReasonTemplate = (id: number, r: ReasonTemplateForm) =>
  api.put<ReasonTemplateRow>(`/admin/moderation/reason-templates/${id}`, r);
export const deleteReasonTemplate = (id: number, o?: GuardOpts) =>
  api.del(`/admin/moderation/reason-templates/${id}`, guardHeaders(o));

export interface ReportCsvFilters {
  status?: 'ALL' | 'OPEN' | 'RESOLVED';
  targetType?: ReportTargetType | '';
  resolution?: StrikeResolution | '';
  from?: string;
  to?: string;
}
export interface AppealCsvFilters {
  status?: 'ALL' | 'OPEN' | 'ACCEPTED' | 'REJECTED';
  targetType?: ReportTargetType | '';
  from?: string;
  to?: string;
}

/** CSV (UTF-8 BOM, formül kaçışlı, en çok 50.000 satır; isteğin kendisi denetlenir). */
export const exportReportsCsv = (f: ReportCsvFilters = {}): Promise<Blob> =>
  apiBlob('/admin/reports/export.csv', {
    query: {
      status: f.status && f.status !== 'ALL' ? f.status : undefined,
      targetType: f.targetType || undefined,
      resolution: f.resolution || undefined,
      from: f.from || undefined,
      to: f.to || undefined,
    },
  });
export const exportAppealsCsv = (f: AppealCsvFilters = {}): Promise<Blob> =>
  apiBlob('/admin/appeals/export.csv', {
    query: {
      status: f.status && f.status !== 'ALL' ? f.status : undefined,
      targetType: f.targetType || undefined,
      from: f.from || undefined,
      to: f.to || undefined,
    },
  });
