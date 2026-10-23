import { api, apiFetch } from './client';
import type { AdminMe, LoginRequest, TokenResponse, UserView } from './types';

export const login = (r: LoginRequest) =>
  apiFetch<TokenResponse>('/auth/login', { method: 'POST', body: r, auth: false });

export const refresh = (refreshToken: string) =>
  apiFetch<TokenResponse>('/auth/refresh', { method: 'POST', body: { refreshToken }, auth: false });

export const logout = (refreshToken: string) =>
  apiFetch<void>('/auth/logout', { method: 'POST', body: { refreshToken }, auth: false });

export const getMe = () => api.get<UserView>('/auth/me');

/** Rol doğrulaması: ADMIN değilse 403 döner. */
export const getAdminMe = () => api.get<AdminMe>('/admin/me');
