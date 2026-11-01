import { api } from './client';
import type { Page, TwoFactorSummary, TwoFactorUserRow, TwoFactorUsersResponse } from './types';

/** `GET /api/admin/two-factor/summary` (izin: users.read). */
export const getTwoFactorSummary = () => api.get<TwoFactorSummary>('/admin/two-factor/summary');

/**
 * `GET /api/admin/two-factor/users?page&size&q`: 2FA açan kullanıcılar. Yanıt Spring Page biçimindedir
 * (`content/totalElements/number`); arayüzün ortak `Page` tipine (`items/totalItems/page`) çevrilir.
 */
export async function listTwoFactorUsers(
  p: { page?: number; size?: number; q?: string } = {},
): Promise<Page<TwoFactorUserRow>> {
  const r = await api.get<TwoFactorUsersResponse>('/admin/two-factor/users', { ...p });
  return {
    items: r.content ?? [],
    page: r.number ?? 0,
    totalPages: r.totalPages ?? 0,
    totalItems: r.totalElements ?? 0,
  };
}

/**
 * `POST /api/admin/users/{id}/two-factor/disable` (izin: users.write): hesap kurtarma. Gerekçe zorunludur ve
 * denetim kaydına yazılır; güvenilen cihazlar silinir, kullanıcıya bildirim/e-posta gider.
 */
export const disableUserTwoFactor = (id: number, reason: string) =>
  api.post(`/admin/users/${id}/two-factor/disable`, { reason });
