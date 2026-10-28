import { api } from './client';
import { guardHeaders, type GuardOpts } from './guard';

export type OpsLevel = 'UP' | 'WARN' | 'DOWN' | 'UNKNOWN';

export interface OpsComponent {
  status: string;
  details?: Record<string, string | number | boolean | null>;
}
export interface OpsHealth {
  status: string;
  components: Record<string, OpsComponent>;
}
export interface MailOutboxStats {
  pending: number;
  sending?: number;
  dead: number;
  sentLast24h?: number;
  oldestPendingAgeSeconds?: number | null;
}
export interface PushOutboxStats {
  enabled: boolean;
  holdWhenDisabled?: boolean;
  pending: number;
  sending: number;
  failed: number;
  dead: number;
  sentLast24h: number;
  oldestPendingAgeSeconds: number | null;
  oldestPendingAt?: string | null;
}
export interface TranscodeStats {
  pending: number;
  processing?: number;
  failed: number;
  doneLast24h?: number;
}
export interface BackupStatus {
  status: 'OK' | 'FAILED' | 'UNKNOWN' | string;
  lastSuccessAt: string | null;
  lastAttemptAt?: string | null;
  sizeBytes?: number | null;
  message?: string | null;
}

export const getHealth = () => api.get<OpsHealth>('/admin/ops/health');
export const getMailStats = () => api.get<MailOutboxStats>('/admin/ops/mail-outbox/stats');
export const retryMailDead = (o?: GuardOpts) =>
  api.post<{ requeued: number }>('/admin/ops/mail-outbox/retry-dead', undefined, guardHeaders(o));
export const getPushStats = () => api.get<PushOutboxStats>('/admin/push/outbox/stats');
export const retryPushDead = (o?: GuardOpts) =>
  api.post<{ requeued: number }>('/admin/push/outbox/retry-dead', undefined, guardHeaders(o));
export const getTranscodeStats = () => api.get<TranscodeStats>('/admin/ops/transcode/stats');
export const getBackupStatus = () => api.get<BackupStatus>('/admin/ops/backup-status');

/** Büyük/küçük harf duyarsız durum -> seviye. */
export function levelOf(status: string | undefined | null): OpsLevel {
  switch ((status ?? '').toUpperCase()) {
    case 'UP':
    case 'OK':
      return 'UP';
    case 'WARN':
    case 'WARNING':
    case 'DEGRADED':
      return 'WARN';
    case 'DOWN':
    case 'OUT_OF_SERVICE':
    case 'FAILED':
      return 'DOWN';
    default:
      return 'UNKNOWN';
  }
}

/** Yalnız https:// bağlantıları dış bağlantı olarak kabul edilir. */
export function safeHttpsUrl(v: string | undefined | null): string | null {
  const s = (v ?? '').trim();
  if (!/^https:\/\//i.test(s)) return null;
  try {
    return new URL(s).toString();
  } catch {
    return null;
  }
}
