import { api, apiBlob } from './client';
import type { AdminUserDetail, AdminUserRow, BasicStats, Page, Role, UserListParams } from './types';

export const listUsers = (p: UserListParams = {}) => api.get<Page<AdminUserRow>>('/admin/users', { ...p });
export const getUser = (id: number) => api.get<AdminUserDetail>(`/admin/users/${id}`);
export const setUserRole = (id: number, role: Role) => api.patch(`/admin/users/${id}/role`, { role });
/** Hesabı anonimleştirir (hesap silmeyle aynı mantık); kendini silemez. */
export const deleteUser = (id: number) => api.del(`/admin/users/${id}`);
export const suspendUser = (id: number, reason?: string) =>
  api.post(`/admin/users/${id}/suspend`, { reason });
export const unsuspendUser = (id: number) => api.post(`/admin/users/${id}/unsuspend`);
/** E-postası doğrulanmamış satırı elle doğrular (idempotent, 204). */
export const verifyUserEmail = (id: number) => api.post(`/admin/users/${id}/verify-email`);
/** Kullanıcıya şifre sıfırlama kodu e-postası gönderir (204). */
export const sendUserReset = (id: number) => api.post(`/admin/users/${id}/send-reset`);
/** Kullanıcının tüm oturumlarını kapatır (204). */
export const revokeUserSessions = (id: number) => api.post(`/admin/users/${id}/revoke-sessions`);

/** CSV (UTF-8 BOM, en çok 50.000 satır). Aynı filtreler; sayfalama alanları yoksayılır. */
export function exportUsersCsv(p: Omit<UserListParams, 'page' | 'size'> = {}): Promise<Blob> {
  return apiBlob('/admin/users/export.csv', { query: { ...p } });
}

/** Basit sayaçlar (genel bakış için hafif uç). */
export const getBasicStats = () => api.get<BasicStats>('/admin/stats');
