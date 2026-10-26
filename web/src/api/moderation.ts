import { api } from './client';
import type {
  AppealStatus,
  AppealView,
  BlocklistEntry,
  CursorPage,
  HashCursorPage,
  SuspendRecommendation,
} from './types';

// İtirazlar
export const listAppeals = (p: { status?: AppealStatus; cursor?: number | null; size?: number } = {}) =>
  api.get<CursorPage<AppealView>>('/admin/moderation/appeals', {
    status: p.status ?? 'OPEN',
    cursor: p.cursor,
    size: p.size,
  });
export const decideAppeal = (id: number, accept: boolean, note?: string) =>
  api.post(`/admin/moderation/appeals/${id}/decide`, { accept, note: note || undefined });

// Tekrarlayan ihlal sonucu askı önerileri
export const listSuspendRecommendations = (
  p: { status?: SuspendRecommendation['status']; cursor?: number | null; size?: number } = {},
) =>
  api.get<CursorPage<SuspendRecommendation>>('/admin/moderation/suspend-recommendations', {
    status: p.status ?? 'OPEN',
    cursor: p.cursor,
    size: p.size,
  });
export const acceptRecommendation = (id: number) =>
  api.post(`/admin/moderation/suspend-recommendations/${id}/accept`);
export const dismissRecommendation = (id: number) =>
  api.post(`/admin/moderation/suspend-recommendations/${id}/dismiss`);

// Yasaklı görsel özetleri (SHA-256)
export const listBlocklist = (p: { cursor?: string | null; size?: number } = {}) =>
  api.get<HashCursorPage<BlocklistEntry>>('/admin/moderation/blocklist', { cursor: p.cursor, size: p.size });
export const addBlocklist = (sha256: string, note?: string) =>
  api.post<BlocklistEntry>('/admin/moderation/blocklist', { sha256, note: note || undefined });
export const removeBlocklist = (sha256: string) => api.del(`/admin/moderation/blocklist/${sha256}`);
