// Veri saklama (DS1): depolama doluluğu, log tablosu envanteri, makbuzlu dışa aktarma ve onaylı temizlik.
// Uçlar: GET /admin/system/storage; GET /admin/data-retention/tables, /tables/{t}/purge-preview, /exports[/{id}],
// /purges[/{id}]; POST /admin/data-retention/exports (gzip CSV akışı), POST /admin/data-retention/purges.
// Sözleşme: docs/ADMIN_API.md "Veri saklama (DS1)". UI gizlemesi güvenlik değildir: asıl denetim sunucudadır.
import { api, apiBlobMeta } from './client';
import { guardHeaders, type GuardOpts } from './guard';
import type { SystemLevel } from './system';

export type DiskSource = 'MEASURED' | 'COMPUTED' | 'UNKNOWN';

export interface StorageDisk {
  key: string;
  roles: string[];
  source: DiskSource;
  path: string | null;
  totalBytes: number | null;
  usedBytes: number | null;
  freeBytes: number | null;
  percent: number | null;
  status: SystemLevel;
}

export interface StorageTable {
  name: string;
  totalBytes: number;
  estimatedRows: number | null;
}

export interface StorageReport {
  generatedAt: string;
  status: SystemLevel;
  worstPercent: number | null;
  worstKey: string | null;
  database: { sizeBytes: number | null; topTables: StorageTable[] };
  dbServerDisk: StorageDisk;
  appDisks: StorageDisk[];
  warnPercent: number;
  critPercent: number;
}

export interface RetentionTable {
  name: string;
  label: string;
  description: string;
  estimatedRows: number | null;
  sizeBytes: number | null;
  oldestAt: string | null;
  minRetentionDays: number;
  /** Seçilebilecek en geç bitiş (hariç), yyyy-MM-dd. */
  maxTo: string;
  deletable: boolean;
  notDeletableReason: string | null;
  personalData: boolean;
}

export interface Receipt {
  id: number;
  table: string;
  from: string;
  to: string;
  format: string;
  status: 'RUNNING' | 'COMPLETED' | 'PARTIAL' | 'FAILED';
  rowCount: number;
  byteCount: number;
  sha256: string | null;
  adminId: number | null;
  adminEmail: string | null;
  reason: string | null;
  createdAt: string;
  finishedAt: string | null;
}

export type PurgeBlocker = 'NOT_DELETABLE' | 'NO_RECEIPT' | 'RECEIPT_STALE' | 'NOTHING_TO_DELETE';

export interface PurgePreview {
  table: string;
  from: string;
  to: string;
  rowsInRange: number;
  capped: boolean;
  estimatedBytes: number | null;
  deletable: boolean;
  notDeletableReason: string | null;
  maxTo: string;
  minRetentionDays: number;
  receipt: Receipt | null;
  receiptStale: boolean;
  canPurge: boolean;
  blockers: PurgeBlocker[];
}

export type PurgeStatus = 'RUNNING' | 'COMPLETED' | 'FAILED' | 'INTERRUPTED';

export interface Purge {
  id: number;
  table: string;
  from: string;
  to: string;
  receiptId: number | null;
  forced: boolean;
  status: PurgeStatus;
  estRows: number;
  deletedRows: number;
  oldestAt: string | null;
  newestAt: string | null;
  reason: string;
  adminId: number | null;
  adminEmail: string | null;
  error: string | null;
  startedAt: string;
  updatedAt: string;
  finishedAt: string | null;
  vacuumRecommended: boolean;
}

export interface PurgeBody {
  table: string;
  from?: string;
  to: string;
  confirmTable: string;
  receiptId?: number;
  forceWithoutExport?: boolean;
  reason: string;
}

export const retentionKeys = {
  all: ['admin', 'data-retention'] as const,
  storage: ['admin', 'data-retention', 'storage'] as const,
  tables: ['admin', 'data-retention', 'tables'] as const,
  preview: (table: string, from: string, to: string) => ['admin', 'data-retention', 'preview', table, from, to] as const,
  exports: ['admin', 'data-retention', 'exports'] as const,
  purges: ['admin', 'data-retention', 'purges'] as const,
  purge: (id: number) => ['admin', 'data-retention', 'purges', id] as const,
};

export const getStorage = () => api.get<StorageReport>('/admin/system/storage');
export const getRetentionTables = () => api.get<RetentionTable[]>('/admin/data-retention/tables');
export const getPurgePreview = (table: string, from: string, to: string) =>
  api.get<PurgePreview>(`/admin/data-retention/tables/${encodeURIComponent(table)}/purge-preview`, {
    from: from || undefined,
    to,
  });
export const getReceipts = () => api.get<Receipt[]>('/admin/data-retention/exports');
export const getReceipt = (id: number) => api.get<Receipt>(`/admin/data-retention/exports/${id}`);
export const getPurges = () => api.get<Purge[]>('/admin/data-retention/purges');
export const getPurge = (id: number) => api.get<Purge>(`/admin/data-retention/purges/${id}`);

/** Akışlı gzip CSV; makbuz kimliği `X-Export-Receipt-Id` başlığındadır. Gerekçe gövdede ve `X-Admin-Reason` başlığında. */
export async function exportTable(
  table: string,
  from: string,
  to: string,
  reason: string,
): Promise<{ blob: Blob; receiptId: number | null; filename: string }> {
  const { blob, headers } = await apiBlobMeta('/admin/data-retention/exports', {
    method: 'POST',
    body: { table, from: from || undefined, to, reason },
    headers: guardHeaders({ reason })?.headers,
  });
  const id = Number(headers.get('X-Export-Receipt-Id'));
  const cd = headers.get('Content-Disposition') ?? '';
  const m = /filename="?([^";]+)"?/.exec(cd);
  return { blob, receiptId: Number.isFinite(id) && id > 0 ? id : null, filename: m ? m[1] : `${table}.csv.gz` };
}

/** Silme: `Idempotency-Key` ZORUNLU (sunucu başlıksız isteği reddeder). */
export const startPurge = (body: PurgeBody, opts: GuardOpts) =>
  api.post<Purge>('/admin/data-retention/purges', body, guardHeaders(opts));

/** Uyarı bandı için: WARN/CRIT mi. */
export function isStorageAlert(r: StorageReport | undefined): boolean {
  return r?.status === 'WARN' || r?.status === 'CRIT';
}
