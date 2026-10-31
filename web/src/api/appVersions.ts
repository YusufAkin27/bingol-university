// Yönetici uygulama güncelleme zorlama (UPDATEGATE): sürüm dağılımı ve tek tıkla zorlama.
// Sözleşme: docs/ADMIN_API.md "Uygulama güncelleme zorlama (UPDATEGATE)". Okuma: settings.read; yazma: settings.write.
// Zorlama sebep ister (X-Admin-Reason) ve denetlenir. Sayım kaynağı `source`/`sourceNote` ile dürüstçe etiketlenir.
import { api } from './client';
import { guardHeaders, type GuardOpts } from './guard';

export type AppPlatform = 'android' | 'ios';
export type EnforceMode = 'FORCE' | 'SOFT' | 'OFF';
/** Platformun zorlama durumu: FORCE = zorunlu güncelleme açık, SOFT = yalnız öneri, OFF = kapalı. */
export type EnforceState = 'FORCE' | 'SOFT' | 'OFF';

export const APP_PLATFORMS: AppPlatform[] = ['android', 'ios'];

export const appVersionKeys = {
  all: ['admin', 'app-versions'] as const,
  list: ['admin', 'app-versions', 'list'] as const,
};

export interface VersionRow {
  platform: AppPlatform;
  /** null = sürüm başlığı gelmemiş (bilinmiyor). */
  version: string | null;
  devices: number;
}

export interface PlatformSummary {
  platform: AppPlatform;
  minVersion: string;
  latestVersion: string;
  state: EnforceState;
  total: number;
  unknownVersion: number;
  belowMin: number;
  belowLatest: number;
}

export interface VersionDistribution {
  distribution: VersionRow[];
  platforms: PlatformSummary[];
  total: number;
  belowMin: number;
  belowLatest: number;
  source: string;
  sourceNote: string;
  windowDays: number;
}

export interface EnforceResult {
  platform: AppPlatform;
  mode: EnforceMode;
  state: EnforceState;
  minVersion: string;
  latestVersion: string;
  previousMin: string;
  previousLatest: string;
  /** Sayım başarısızsa null (ayar yine de yazılmıştır). */
  affectedDevices: number | null;
  platformDevices: number | null;
  source: string;
  sourceNote: string;
}

export const getAppVersions = () => api.get<VersionDistribution>('/admin/app-versions');

export const enforceAppVersion = (
  body: { platform: AppPlatform; mode: EnforceMode; version?: string },
  o?: GuardOpts,
) => api.post<EnforceResult>('/admin/app-versions/enforce', body, guardHeaders(o));
