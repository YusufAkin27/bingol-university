import { api, apiFetch } from './client';
import type { AdminMe, LoginRequest, TokenResponse, UserView } from './types';

export const login = (r: LoginRequest) =>
  apiFetch<TokenResponse>('/auth/login', { method: 'POST', body: r, auth: false });

export const refresh = (refreshToken: string) =>
  apiFetch<TokenResponse>('/auth/refresh', { method: 'POST', body: { refreshToken }, auth: false });

export const logout = (refreshToken: string) =>
  apiFetch<void>('/auth/logout', { method: 'POST', body: { refreshToken }, auth: false });

/**
 * Kayıt (202 + e-postaya kod). `adminPortal: true` yalnız yönetici paneli kayıt sayfasından gönderilir ve sunucuya
 * YALNIZ daha sıkı davranış ister: adres sunucudaki ADMIN_EMAILS listesinde değilse (bingol.edu.tr dahil) sunucu
 * sessizce 202 döner, kod göndermez, kayıt açmaz. Bayrak hiçbir kuralı gevşetmez; yoksa genel kayıt kuralı geçerlidir.
 */
export interface RegisterRequest {
  email: string;
  password: string;
  displayName: string;
  acceptTerms: boolean;
  language?: 'tr' | 'en' | 'ar';
  adminPortal?: boolean;
}
export const register = (r: RegisterRequest) =>
  apiFetch<{ message?: string }>('/auth/register', { method: 'POST', body: r, auth: false });

export const verifyEmail = (r: { email: string; code: string; password: string }) =>
  apiFetch<TokenResponse>('/auth/verify-email', { method: 'POST', body: { ...r, client: 'web' }, auth: false });

export const resendCode = (email: string) =>
  apiFetch<{ message?: string }>('/auth/resend-code', { method: 'POST', body: { email }, auth: false });

export const getMe = () => api.get<UserView>('/auth/me');

/** Rol doğrulaması: ADMIN değilse 403 döner. */
export const getAdminMe = () => api.get<AdminMe>('/admin/me');
