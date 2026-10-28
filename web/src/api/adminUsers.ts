// P09 kullanıcı derin yönetimi uçları (api/users.ts'in genişlemesi). Sözleşme: AdminUserExtrasController.
// Yazma uçlarında sebep `X-Admin-Reason` başlığıyla gider (guardHeaders); KVKK dışa aktarma ayrıca `X-Admin-Confirm`.
import { api, apiBlob } from './client';
import { guardHeaders, type GuardOpts } from './guard';
import type { Page } from './types';

/** `qk.users.all` (['users']) ile başlar: kullanıcı işlemlerinde tek `invalidateQueries` hepsini tazeler. */
export const userDeepKeys = {
  sessions: (id: number) => ['users', 'sessions', id] as const,
  pushDevices: (id: number) => ['users', 'push-devices', id] as const,
  notifications: (id: number, unread: boolean, page: number) => ['users', 'notifications', id, unread, page] as const,
};

export interface UserSession {
  /** Opak oturum kimliği (özetin ilk 16 hex'i); belirteç değildir. */
  id: string;
  client: 'web' | 'mobile' | string;
  createdAt: string | null;
  expiresAt: string | null;
}
export interface UserSessionList {
  total: number;
  items: UserSession[];
}

export interface PushDevice {
  id: number;
  platform: string;
  appVersion: string | null;
  locale: string | null;
  /** Token'ın yalnız son karakterleri; tamamı hiçbir uçta dönmez. */
  tokenTail: string;
  createdAt: string | null;
  lastSeenAt: string | null;
}

export interface UserNotification {
  id: number;
  type: string;
  subtype: string | null;
  title: string;
  body: string | null;
  read: boolean;
  groupCount: number;
  createdAt: string | null;
  readAt: string | null;
}

export interface ProfilePatchBody {
  clearAvatar?: boolean;
  clearBio?: boolean;
  displayName?: string;
}
export interface ProfilePatchResult {
  avatarCleared: boolean;
  bioCleared: boolean;
  displayNameChanged: boolean;
}

export type BulkUserAction = 'SUSPEND' | 'UNSUSPEND' | 'REVOKE_SESSIONS';
export type BulkItemStatus = 'DONE' | 'SKIPPED' | 'FAILED';
export interface BulkUserItem {
  id: number;
  status: BulkItemStatus;
  /** DONE iken null; aksi halde makine kodu (SELF, ADMIN_TARGET, ADMIN_EMAIL_PINNED, ALREADY_SUSPENDED...). */
  code: string | null;
}
export interface BulkUserResult {
  action: BulkUserAction;
  requested: number;
  done: number;
  skipped: number;
  failed: number;
  results: BulkUserItem[];
}

/** Tek istekte en çok bu kadar kullanıcı (sunucu sınırı). */
export const USER_BULK_MAX = 100;
/** Kullanıcı adına KVKK dışa aktarma sebebi en az bu kadar karakter. */
export const EXPORT_REASON_MIN = 20;

export const patchUserProfile = (id: number, body: ProfilePatchBody, o?: GuardOpts) =>
  api.patch<ProfilePatchResult>(`/admin/users/${id}/profile`, body, guardHeaders(o));

export const getUserSessions = (id: number) => api.get<UserSessionList>(`/admin/users/${id}/sessions`);
export const revokeUserSession = (id: number, sessionId: string, o?: GuardOpts) =>
  api.del(`/admin/users/${id}/sessions/${encodeURIComponent(sessionId)}`, guardHeaders(o));

export const getUserPushDevices = (id: number) => api.get<PushDevice[]>(`/admin/users/${id}/push-devices`);
export const deleteUserPushDevice = (id: number, deviceId: number, o?: GuardOpts) =>
  api.del(`/admin/users/${id}/push-devices/${deviceId}`, guardHeaders(o));

export const getUserNotifications = (id: number, p: { unread?: boolean; page?: number; size?: number } = {}) =>
  api.get<Page<UserNotification>>(`/admin/users/${id}/notifications`, {
    unread: p.unread ? true : undefined,
    page: p.page ?? 0,
    size: p.size ?? 20,
  });

/**
 * Kullanıcı adına KVKK dışa aktarma (JSON dosyası). Sunucu: sebep >= 20 karakter, `X-Admin-Confirm` kullanıcı kimliğine
 * eşit olmalı, kullanıcı başına günde bir (429). Kullanıcıya bildirim gitmez; denetim kaydına yazılır.
 */
export function exportUserData(id: number, o: GuardOpts): Promise<Blob> {
  const base = guardHeaders(o)?.headers ?? {};
  return apiBlob(`/admin/users/${id}/export`, {
    method: 'POST',
    headers: { ...base, 'X-Admin-Confirm': String(id) },
  });
}

export const bulkUsers = (action: BulkUserAction, ids: number[], reason: string, o?: Pick<GuardOpts, 'idempotencyKey'>) =>
  api.post<BulkUserResult>('/admin/users/bulk', { action, ids, reason }, guardHeaders({ ...o, reason }));
