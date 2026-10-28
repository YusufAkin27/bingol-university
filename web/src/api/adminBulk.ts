// P15: haber / akademik / menü / bekleyen kayıt toplu işlemleri, CSV ve kaynak durumu (ADMIN).
// Uçlar: POST /admin/news/bulk, /admin/academic/bulk, /admin/menu/bulk-delete, /admin/pending-registrations/bulk-cancel,
// GET .../export.csv, GET /admin/sources/status, POST /admin/sources/sync (backend: admin/bulk/AdminBulkController).
// Yazma uçları sebep ister (en az 5 karakter) ve kısmi başarı raporu döner.
import { api, apiBlob } from './client';
import { guardHeaders, type GuardOpts } from './guard';

/** Tek seferde en çok kayıt (haber, akademik, bekleyen kayıt). */
export const BULK_MAX = 200;
/** Menü toplu silmede en çok gün. */
export const MENU_BULK_MAX = 62;

export type BulkItemStatus = 'DONE' | 'SKIPPED' | 'FAILED';

export interface BulkResultItem {
  /** Kayıt kimliği; bekleyen kayıtta maskeli e-posta, menüde tarih. */
  id: string;
  status: BulkItemStatus;
  /** ALREADY_DONE | NOT_FOUND | hata kodu; DONE ise null. */
  code: string | null;
}

export interface BulkReport {
  requested: number;
  done: number;
  skipped: number;
  failed: number;
  results: BulkResultItem[];
}

export type NewsBulkAction = 'HIDE' | 'UNHIDE';
export type AcademicBulkEntity = 'CALENDAR' | 'EXAM' | 'ANNOUNCEMENT';
export type AcademicBulkAction = 'PUBLISH' | 'UNPUBLISH' | 'DELETE';
export type SourceName = 'NEWS' | 'MENU';

const withReason = (reason: string, o?: GuardOpts) => guardHeaders({ ...o, reason });

export const bulkNews = (action: NewsBulkAction, ids: number[], reason: string, o?: GuardOpts) =>
  api.post<BulkReport>('/admin/news/bulk', { action, ids, reason: reason.trim() }, withReason(reason, o));

export const bulkAcademic = (
  entity: AcademicBulkEntity,
  action: AcademicBulkAction,
  ids: number[],
  reason: string,
  o?: GuardOpts,
) => api.post<BulkReport>('/admin/academic/bulk', { entity, action, ids, reason: reason.trim() }, withReason(reason, o));

export const bulkDeleteMenu = (dates: string[], reason: string, o?: GuardOpts) =>
  api.post<BulkReport>('/admin/menu/bulk-delete', { dates, reason: reason.trim() }, withReason(reason, o));

export const bulkCancelPending = (emails: string[], reason: string, o?: GuardOpts) =>
  api.post<BulkReport>(
    '/admin/pending-registrations/bulk-cancel',
    { emails, reason: reason.trim() },
    withReason(reason, o),
  );

/** CSV'ler Blob olarak alınır (yetki başlığı gerektiğinden `<a href>` yetmez). */
export interface NewsCsvParams {
  q?: string;
  type?: string;
  hidden?: boolean;
}
export const exportNewsCsv = (p: NewsCsvParams = {}): Promise<Blob> =>
  apiBlob('/admin/news/export.csv', { query: { q: p.q || undefined, type: p.type || undefined, hidden: p.hidden } });

export interface AcademicCsvParams {
  entity: AcademicBulkEntity;
  q?: string;
  kind?: string;
  published?: boolean;
  status?: string;
}
export const exportAcademicCsv = (p: AcademicCsvParams): Promise<Blob> =>
  apiBlob('/admin/academic/export.csv', {
    query: {
      entity: p.entity,
      q: p.q || undefined,
      kind: p.kind || undefined,
      published: p.published,
      status: p.status && p.status !== 'all' ? p.status : undefined,
    },
  });

export const exportMenuCsv = (p: { from?: string; to?: string } = {}): Promise<Blob> =>
  apiBlob('/admin/menu/export.csv', { query: { from: p.from || undefined, to: p.to || undefined } });

export const exportPendingCsv = (p: { q?: string } = {}): Promise<Blob> =>
  apiBlob('/admin/pending-registrations/export.csv', { query: { q: p.q || undefined } });

// ---- kaynak durumu ----

export interface NewsSourceStatus {
  maintenance: boolean;
  lastSuccess: string | null;
  lastAttempt: string | null;
  message: string | null;
  itemsLast7d: number;
  total: number;
  hidden: number;
  byType: Record<string, number>;
}

export interface MenuSourceStatus {
  maintenance: boolean;
  lastSuccess: string | null;
  lastAttempt: string | null;
  message: string | null;
  totalDays: number;
  upcomingDays: number;
  withImage: number;
}

export interface SourcesStatus {
  news: NewsSourceStatus;
  menu: MenuSourceStatus;
  /** Kaynak başına saatlik elle senkron hakkı. */
  syncPerHour: number;
}

export interface SourceSyncResult {
  source: SourceName;
  changed: number;
  detail: Record<string, number>;
}

export const getSourcesStatus = () => api.get<SourcesStatus>('/admin/sources/status');

export const syncSource = (source: SourceName, reason: string, o?: GuardOpts) =>
  api.post<SourceSyncResult>('/admin/sources/sync', { source, reason: reason.trim() }, withReason(reason, o));

export const sourcesKeys = { status: ['admin', 'sources', 'status'] as const };
