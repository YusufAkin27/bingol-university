import { publicApi } from './client';
import type { AppInfo, Platform, VersionCheck } from './types';

/** Herkese açık: iletişim, banner, bakım modu. */
export const getAppInfo = () => publicApi.get<AppInfo>('/app/info');

/** Mağaza bağlantısı `storeUrl` içinde gelir. Sürüm 0.0.0 verilince `updateRequired` önemsizdir. */
export const checkVersion = (platform: Exclude<Platform, 'WEB'>, version = '0.0.0') =>
  publicApi.get<VersionCheck>('/app/version', { platform, version });

/** `GET /api/faculties` — profil fakülte listesi (herkese açık). */
export const getFaculties = () => publicApi.get<string[]>('/faculties');
