import { api } from './client';

/** GET /api/admin/system/overview ve olu kayit uclari (docs/ADMIN_API.md "Sistem durumu"). */
export type SystemLevel = 'OK' | 'WARN' | 'CRIT' | 'UNKNOWN';

export interface SystemIndicator {
  status: SystemLevel;
  value: number | string | Record<string, unknown> | null;
  threshold: { warn?: number; crit?: number } | null;
  message: string | null;
}

export interface SystemOverview {
  generatedAt: string;
  overall: SystemLevel;
  indicators: Record<string, SystemIndicator>;
}

export interface MailDead {
  id: number;
  template: string;
  to: string;
  attempts: number;
  lastError: string | null;
  createdAt: string | null;
}

export interface PushDead {
  id: number;
  userId: number | null;
  attempts: number;
  lastError: string | null;
  createdAt: string | null;
}

export type DeadKind = 'mail' | 'push';

export const getOverview = () => api.get<SystemOverview>('/admin/system/overview');
export const getDeadMail = () => api.get<MailDead[]>('/admin/system/dead-letters/mail', { limit: 100 });
export const getDeadPush = () => api.get<PushDead[]>('/admin/system/dead-letters/push', { limit: 100 });

/**
 * ids bos = tum olu kayitlar. Yollar SABIT yazilir (kind sablonla degil): backend'in gercek uclari
 * `POST /api/admin/system/dead-letters/{mail|push}/{retry|delete}` (gövdede `ids[]`); sözleşme denetimi
 * (scripts/check-admin-contract.mjs) sabit yolları openapi ile birebir eşler.
 */
export const retryDead = (kind: DeadKind, ids: number[]) =>
  kind === 'mail'
    ? api.post<{ requeued: number }>('/admin/system/dead-letters/mail/retry', { ids })
    : api.post<{ requeued: number }>('/admin/system/dead-letters/push/retry', { ids });
export const deleteDead = (kind: DeadKind, ids: number[]) =>
  kind === 'mail'
    ? api.post<{ deleted: number }>('/admin/system/dead-letters/mail/delete', { ids })
    : api.post<{ deleted: number }>('/admin/system/dead-letters/push/delete', { ids });

/** Bilinmeyen/eksik durumu UNKNOWN sayar. */
export function levelOf(s: string | undefined | null): SystemLevel {
  return s === 'OK' || s === 'WARN' || s === 'CRIT' ? s : 'UNKNOWN';
}

/** Gosterge anahtarini gruplara boler: kuyruklar, altyapi, zamanlayicilar. */
export type SystemGroup = 'queues' | 'infra' | 'jobs';
export function groupOf(key: string): SystemGroup {
  if (key.startsWith('jobs.')) return 'jobs';
  if (key.startsWith('mail.') || key.startsWith('push.') || key.startsWith('campaign.')) return 'queues';
  return 'infra';
}

/** Degerin birimi: saniyeyi dakikaya, yedegi saate vb. cevirmek icin. */
export type SystemUnit = 'minutes' | 'hours' | 'percent' | 'ms' | 'count' | 'object';
export function unitOf(key: string): SystemUnit {
  if (key.endsWith('Age') || key === 'campaign.overdue' || key.startsWith('jobs.')) return 'minutes';
  if (key === 'backup.age') return 'hours';
  if (key === 'disk.storage') return 'percent';
  if (key === 'db' || key === 'redis') return 'ms';
  if (key === 'campaign.counts' || key === 'fcm') return 'object';
  return 'count';
}

/** Sayiyi birime gore cevirir: dakika birimlerinde API saniye dondurur. */
export function toUnit(unit: SystemUnit, n: number): number {
  return unit === 'minutes' ? Math.round(n / 60) : n;
}
