import { api, publicApi } from './client';
import { adminSeg, guardHeaders, type GuardOpts } from './guard';
import type { Settings, SyncStatus } from './types';

export const getSettings = () => api.get<Settings>('/admin/settings');
/** İstemci tarafında da doğrulayın: sürümler `1.2.3`, bağlantılar `https://`, bakım modu `true|false`. */
export const putSetting = (key: string, value: string, o?: GuardOpts) =>
  api.put(`/admin/settings/${adminSeg(key)}`, { value }, guardHeaders(o));

/** Haber/menü senkron durumu (herkese açık). */
export const getSyncStatus = () => publicApi.get<SyncStatus>('/status');
export const triggerNewsSync = () => api.post('/admin/sync');
export const triggerMenuSync = () => api.post('/admin/sync-menu');
