import { api, apiFetch } from './client';
import type {
  AdminMe,
  LoginRequest,
  TokenResponse,
  TwoFactorChallenge,
  TwoFactorVerifyRequest,
  UserView,
} from './types';

/** 200: TokenResponse. 2FA açık ve cihaz tanınmıyorsa 202: TwoFactorChallenge (token yok). */
export type LoginResponse = TokenResponse | TwoFactorChallenge;

export function isTwoFactorChallenge(r: LoginResponse): r is TwoFactorChallenge {
  return (r as TwoFactorChallenge).twoFactorRequired === true;
}

export const login = (r: LoginRequest) =>
  apiFetch<LoginResponse>('/auth/login', { method: 'POST', body: r, auth: false });

/** `POST /auth/login/2fa`: e-postadaki 6 haneli kod. trustDevice=true bu tarayıcıyı güvenilir yapar. */
export const verifyTwoFactorLogin = (r: TwoFactorVerifyRequest) =>
  apiFetch<TokenResponse>('/auth/login/2fa', { method: 'POST', body: r, auth: false });

/** `POST /auth/login/2fa/resend`: 202 `{expiresInSeconds}` (genel cevap; sınır aşılırsa 429). */
export const resendTwoFactorCode = (challengeToken: string) =>
  apiFetch<{ expiresInSeconds: number }>('/auth/login/2fa/resend', {
    method: 'POST',
    body: { challengeToken },
    auth: false,
  });

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
