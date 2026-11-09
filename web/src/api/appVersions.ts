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

export interface DevicePlatformCount {
  /** other = web / bilinmeyen platform. */
  platform: AppPlatform | 'other';
  total: number;
  active30: number;
  active7: number;
  pushCapable: number;
}

/** Fiziksel cihaz özeti (cihaz kimliği özetine göre tekil). Yalnız toplulaştırılmış sayılar; kimlik/jeton dönmez. */
export interface DeviceSummary {
  totalUnique: number;
  active30: number;
  active7: number;
  /** Cihaz kimliği göndermeyen (eski sürüm) ve kullanıcı başına sayılan aktif cihaz. */
  unidentified30: number;
  onLatest30: number;
  /** Aktif android+ios cihazların en güncel sürümde olan yüzdesi. */
  latestPercent: number;
  unknownVersion30: number;
  /** Geçerli push jetonu olan cihaz. */
  pushCapable: number;
  platforms: DevicePlatformCount[];
  retentionDays: number;
  active30Days: number;
  active7Days: number;
  pushDays: number;
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
  /** Eski sunucu yanıtında yok olabilir. */
  devices?: DeviceSummary;
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
