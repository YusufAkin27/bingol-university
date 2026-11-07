// Yedekleme sayfası saf yardımcıları (birim testli): Drive durumu, yedek tazeliği, "ne kadar önce".
import { isApiError } from '../../../api/client';
import type { BackupStatus } from '../../../api/backup';

export type DriveState = 'UNAVAILABLE' | 'NOT_CONFIGURED' | 'ERROR' | 'PENDING' | 'OK';

/** Uç henüz yoksa (backend sonraki dalda) 404/501: sayfa hata göstermez, rehber görünür kalır. */
export function isEndpointMissing(e: unknown): boolean {
  return isApiError(e) && (e.status === 404 || e.status === 501);
}

/**
 * Uzak (Google Drive) durumu. Hata mesajı varsa ERROR; yapılandırılmış ama hiç yükleme/doğrulama yoksa PENDING;
 * en az bir doğrulama varsa OK. Durum hiç alınamadıysa UNAVAILABLE.
 */
export function driveState(s: BackupStatus | null | undefined): DriveState {
  const r = s?.remote;
  if (!s || !r) return 'UNAVAILABLE';
  if (!r.configured) return 'NOT_CONFIGURED';
  if (r.lastError && r.lastError.trim() !== '') return 'ERROR';
  if (r.lastVerifiedAt || r.lastSuccessAt) return r.lastVerifiedAt ? 'OK' : 'PENDING';
  return 'PENDING';
}

export type Freshness = 'FRESH' | 'STALE' | 'OLD' | 'FAILED' | 'NONE';

const HOUR = 3_600_000;

/** Son başarılı yedeğin tazeliği: saatlik yedekte 3 saatten eski = gecikmiş, 24 saatten eski = eski. */
export function freshness(s: BackupStatus | null | undefined, now: number): Freshness {
  if (!s) return 'NONE';
  const st = (s.lastStatus ?? '').toLowerCase();
  const failed = st.includes('fail') || st.includes('error') || st === '0';
  if (!s.lastSuccessAt) return failed ? 'FAILED' : 'NONE';
  const t = Date.parse(s.lastSuccessAt);
  if (!Number.isFinite(t)) return 'NONE';
  const age = now - t;
  if (failed) return 'FAILED';
  if (age > 24 * HOUR) return 'OLD';
  if (age > 3 * HOUR) return 'STALE';
  return 'FRESH';
}

export type AgoUnit = 'now' | 'min' | 'hour' | 'day';

/** ISO zamanı "ne kadar önce" parçasına çevirir; geçersizse null. */
export function agoParts(iso: string | null | undefined, now: number): { unit: AgoUnit; n: number } | null {
  if (!iso) return null;
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return null;
  const ms = Math.max(0, now - t);
  const min = Math.floor(ms / 60_000);
  if (min < 1) return { unit: 'now', n: 0 };
  if (min < 60) return { unit: 'min', n: min };
  const hour = Math.floor(min / 60);
  if (hour < 48) return { unit: 'hour', n: hour };
  return { unit: 'day', n: Math.floor(hour / 24) };
}
