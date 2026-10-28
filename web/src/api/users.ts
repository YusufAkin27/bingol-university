import { api, apiBlob } from './client';
import { guardHeaders, type GuardOpts } from './guard';
import type { AdminUserDetail, AdminUserRow, BasicStats, Page, Role, UserListParams } from './types';

export const listUsers = (p: UserListParams = {}) => api.get<Page<AdminUserRow>>('/admin/users', { ...p });
export const getUser = (id: number) => api.get<AdminUserDetail>(`/admin/users/${id}`);

// Sebep her yerde `X-Admin-Reason` başlığıyla gider (bilinmeyen JSON alanı eklenmez); yalnız askıda gövde alanı da vardır.
export const setUserRole = (id: number, role: Role, o?: GuardOpts) =>
  api.patch(`/admin/users/${id}/role`, { role }, guardHeaders(o));
/** Hesabı anonimleştirir (hesap silmeyle aynı mantık); kendini silemez. */
export const deleteUser = (id: number, o?: GuardOpts) => api.del(`/admin/users/${id}`, guardHeaders(o));
export const suspendUser = (id: number, reason?: string, o?: Pick<GuardOpts, 'idempotencyKey'>) =>
  api.post(`/admin/users/${id}/suspend`, { reason }, guardHeaders({ ...o, reason }));
export const unsuspendUser = (id: number, o?: GuardOpts) =>
  api.post(`/admin/users/${id}/unsuspend`, undefined, guardHeaders(o));
/** E-postası doğrulanmamış satırı elle doğrular (idempotent, 204). */
export const verifyUserEmail = (id: number, o?: GuardOpts) =>
  api.post(`/admin/users/${id}/verify-email`, undefined, guardHeaders(o));
/** Kullanıcıya şifre sıfırlama kodu e-postası gönderir (204). */
export const sendUserReset = (id: number, o?: GuardOpts) =>
  api.post(`/admin/users/${id}/send-reset`, undefined, guardHeaders(o));
/** Kullanıcının tüm oturumlarını kapatır (204). Sebep isteğe bağlıdır. */
export const revokeUserSessions = (id: number, o?: GuardOpts) =>
  api.post(`/admin/users/${id}/revoke-sessions`, undefined, guardHeaders(o));

/** CSV (UTF-8 BOM, en çok 50.000 satır). Aynı filtreler; sayfalama alanları yoksayılır. */
export function exportUsersCsv(p: Omit<UserListParams, 'page' | 'size'> = {}): Promise<Blob> {
  return apiBlob('/admin/users/export.csv', { query: { ...p } });
}

/** Basit sayaçlar (genel bakış için hafif uç). */
export const getBasicStats = () => api.get<BasicStats>('/admin/stats');
