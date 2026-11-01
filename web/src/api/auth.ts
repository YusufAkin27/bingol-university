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

export const getMe = () => api.get<UserView>('/auth/me');

/** Rol doğrulaması: ADMIN değilse 403 döner. */
export const getAdminMe = () => api.get<AdminMe>('/admin/me');
