// Örnek tip güvenli modül: yönetici kullanıcı listesi/ayrıntısı (şema: docs/openapi.json). Elle yazılmış users.ts'e dokunmaz.
import type { components } from '../generated/schema';
import { typedGet, typedSend } from './typedApi';

export type AdminUserRowT = components['schemas']['AdminUserRow'];

export const listUsersTyped = (query: { page?: number; size?: number; q?: string } = {}) =>
  typedGet('/api/admin/users', { query: query as never });

export const getUserTyped = (id: number) => typedGet('/api/admin/users/{id}', { path: { id } });

export const unsuspendUserTyped = (id: number) =>
  typedSend('/api/admin/users/{id}/unsuspend', 'POST', undefined, { path: { id } });
