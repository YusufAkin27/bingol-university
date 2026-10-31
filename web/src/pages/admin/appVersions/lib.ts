/** Uygulama güncelleme zorlama sayfasının saf mantığı (sunucu kurallarıyla aynı; testli). */
import type { AppPlatform, EnforceMode, EnforceState, PlatformSummary, VersionRow } from '../../../api/appVersions';
import { compareVersions } from '../settings/lib';

const VERSION = /^\d+(\.\d+){0,3}$/;
/** Sunucu "zorunluluk kapalı" için bu en düşük sürümü yazar (V5 tohum değeri). */
export const MIN_VERSION_OFF = '1.0.0';

export const isVersion = (v: string): boolean => VERSION.test(v.trim());

/** `version` altındaki bilinen sürümlü cihaz sayısı (sürümü bilinmeyenler sayılmaz). */
export function devicesBelow(rows: VersionRow[], platform: AppPlatform, version: string): number {
  if (!isVersion(version)) return 0;
  let n = 0;
  for (const r of rows) {
    if (r.platform === platform && r.version && isVersion(r.version) && compareVersions(r.version, version) < 0) {
      n += r.devices;
    }
  }
  return n;
}

export type RowStatus = 'FORCED' | 'SUGGESTED' | 'CURRENT' | 'UNKNOWN';

/** Dağılım satırının mevcut ayarlara göre durumu. */
export function rowStatus(r: VersionRow, p: Pick<PlatformSummary, 'minVersion' | 'latestVersion'>): RowStatus {
  if (!r.version || !isVersion(r.version)) return 'UNKNOWN';
  if (compareVersions(r.version, p.minVersion) < 0) return 'FORCED';
  if (compareVersions(r.version, p.latestVersion) < 0) return 'SUGGESTED';
  return 'CURRENT';
}

/** Etki önizlemesi: seçilen kip uygulanırsa kaç cihaz güncelleme ekranı/önerisi görür. */
export function impactOf(rows: VersionRow[], platform: AppPlatform, mode: EnforceMode, version: string): number {
  return mode === 'OFF' ? 0 : devicesBelow(rows, platform, version);
}

export interface StoreInfo {
  /** Yöneticinin yazdığı mağaza bağlantısı (store_url_*). */
  storeUrl: string;
  /** Android paket adı (store_package_android). */
  androidPackage: string;
  /** Apple uygulama kimliği (apple_app_id_ios). */
  appleAppId: string;
}

/** Güncelle düğmesinin gidebileceği bir adres var mı (sunucu türetmesiyle aynı kural). */
export function hasStoreLink(platform: AppPlatform, s: StoreInfo): boolean {
  if (/^https:\/\/\S+$/i.test(s.storeUrl.trim())) return true;
  if (platform === 'android') return true; // paket boşsa sunucu varsayılan paketi kullanır
  return /^\d{5,15}$/.test(s.appleAppId.trim());
}

export type IssueCode =
  | 'VERSION_INVALID'
  | 'BELOW_LATEST'
  | 'BELOW_MIN'
  | 'NO_STORE_LINK'
  | 'IOS_NOT_PUBLISHED'
  | 'ABOVE_EVERYONE';

export interface Issues {
  /** Gönderimi engelleyen hatalar (sunucu da reddeder). */
  errors: IssueCode[];
  /** Uyarılar: devam edilebilir ama dikkat. */
  warnings: IssueCode[];
}

/** Sihirbaz doğrulaması: hatalar sunucu kurallarıyla aynı; uyarılar yöneticiyi yanlış zorlamadan korur. */
export function enforceIssues(args: {
  platform: AppPlatform;
  mode: EnforceMode;
  version: string;
  min: string;
  latest: string;
  store: StoreInfo;
  rows: VersionRow[];
}): Issues {
  const { platform, mode, store } = args;
  const version = args.version.trim();
  const errors: IssueCode[] = [];
  const warnings: IssueCode[] = [];
  if (mode === 'OFF') return { errors, warnings };
  if (!isVersion(version)) {
    errors.push('VERSION_INVALID');
    return { errors, warnings };
  }
  if (mode === 'FORCE' && compareVersions(version, args.latest) < 0) errors.push('BELOW_LATEST');
  if (mode === 'SOFT' && compareVersions(version, args.min) < 0) errors.push('BELOW_MIN');
  if (mode === 'FORCE') {
    if (!hasStoreLink(platform, store)) {
      warnings.push('NO_STORE_LINK');
      if (platform === 'ios') warnings.push('IOS_NOT_PUBLISHED');
    }
    // Hiç cihaz bu sürümün altında değilse zorlama kimseyi etkilemez ama bilinmeyen/daha yeni sürüm yazılmış olabilir.
    const known = args.rows.some((r) => r.platform === platform && r.version);
    const anyAtOrAbove = args.rows.some(
      (r) => r.platform === platform && r.version && isVersion(r.version) && compareVersions(r.version, version) >= 0,
    );
    if (known && !anyAtOrAbove) warnings.push('ABOVE_EVERYONE');
  }
  return { errors, warnings };
}

/** Rozet metni için durum anahtarı (admin.uv.state.*). */
export const stateKey = (s: EnforceState): string => `admin.uv.state.${s}`;

/** min > latest tutarsızlığı (ayarlar elle girildiyse). */
export function isInverted(min: string, latest: string): boolean {
  return isVersion(min) && isVersion(latest) && compareVersions(min, latest) > 0;
}
