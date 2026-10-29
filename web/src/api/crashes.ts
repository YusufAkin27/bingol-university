// Yönetici çökme raporları (CR1): anonim mobil hata raporlarının imzaya göre gruplanmış listesi.
// Sözleşme: docs/ADMIN_API.md "Çökme raporları (CR1)". Durum değişikliği ve silme sebep ister (X-Admin-Reason +
// durum gövdesinde `reason`). Raporlar anonimdir: kullanıcı kimliği/e-posta yoktur, yığın izi sunucuda maskelenmiştir.
import { api } from './client';
import { guardHeaders, type GuardOpts } from './guard';

export type CrashStatus = 'NEW' | 'ACK' | 'RESOLVED';
export type CrashPlatform = 'ANDROID' | 'IOS' | 'OTHER';

export const CRASH_STATUSES: CrashStatus[] = ['NEW', 'ACK', 'RESOLVED'];
export const CRASH_PLATFORMS: CrashPlatform[] = ['ANDROID', 'IOS', 'OTHER'];

/** Sorgu anahtarları (api/queryKeys.ts ortak dosyasına dokunmamak için burada). */
export const crashKeys = {
  all: ['admin', 'crashes'] as const,
  list: ['admin', 'crashes', 'list'] as const,
  summary: ['admin', 'crashes', 'summary'] as const,
  detail: (id: number) => ['admin', 'crashes', 'detail', id] as const,
};

export interface CrashVersionCount {
  version: string;
  platform: string;
  count: number;
}

export interface CrashGroup {
  id: number;
  errorType: string;
  message: string | null;
  topFrame: string | null;
  status: CrashStatus;
  eventCount: number;
  firstSeenAt: string;
  lastSeenAt: string;
  firstVersion: string | null;
  lastVersion: string | null;
  reopenCount: number;
  statusReason: string | null;
  statusBy: string | null;
  statusAt: string | null;
  fixedInVersion: string | null;
  versions: CrashVersionCount[];
}

export interface CrashEvent {
  id: number;
  appVersion: string;
  platform: string;
  osVersion: string | null;
  deviceModel: string | null;
  screen: string | null;
  fatal: boolean;
  message: string | null;
  stack: string;
  occurredAt: string;
  receivedAt: string;
}

export interface CrashDetail {
  group: CrashGroup;
  events: CrashEvent[];
}

export interface CrashSummary {
  newGroups: number;
  ackGroups: number;
  resolvedGroups: number;
  events24h: number;
  reopened: number;
}

export interface CrashPage {
  items: CrashGroup[];
  page: number;
  totalPages: number;
  totalItems: number;
}

export interface CrashFilters {
  status?: CrashStatus | '';
  platform?: CrashPlatform | '';
  version?: string;
  q?: string;
  sort?: 'lastSeen' | 'firstSeen' | 'count';
  page?: number;
  size?: number;
}

export const listCrashes = (f: CrashFilters = {}) =>
  api.get<CrashPage>('/admin/crashes', {
    status: f.status || undefined,
    platform: f.platform || undefined,
    version: f.version?.trim() || undefined,
    q: f.q?.trim() || undefined,
    sort: f.sort ?? 'lastSeen',
    page: f.page ?? 0,
    size: f.size ?? 20,
  });

export const getCrashSummary = () => api.get<CrashSummary>('/admin/crashes/summary');

export const getCrash = (id: number) => api.get<CrashDetail>(`/admin/crashes/${id}`);

/** Durum değiştirir; sebep zorunlu (en az 5 karakter). RESOLVED için `fixedInVersion` isteğe bağlıdır. */
export const setCrashStatus = (
  id: number,
  status: CrashStatus,
  o: GuardOpts & { reason: string; fixedInVersion?: string },
) =>
  api.patch<CrashDetail>(
    `/admin/crashes/${id}/status`,
    { status, reason: o.reason.trim(), fixedInVersion: o.fixedInVersion?.trim() || undefined },
    guardHeaders(o),
  );

export const deleteCrash = (id: number, o: GuardOpts & { reason: string }) =>
  api.del<void>(`/admin/crashes/${id}`, guardHeaders(o));
