import { api } from './client';
import type { CommunityStatus, CommunityView, CursorPage, EventStatus, EventView } from './types';

// Topluluk ve etkinlik onayı. Varsayılan durum: PENDING_REVIEW (id'ye göre azalan).
export const listCommunities = (
  p: { status?: CommunityStatus; cursor?: number | null; size?: number } = {},
) =>
  api.get<CursorPage<CommunityView>>('/admin/communities', {
    status: p.status,
    cursor: p.cursor,
    size: p.size,
  });
export const approveCommunity = (id: number) => api.post(`/admin/communities/${id}/approve`);
export const rejectCommunity = (id: number, reason?: string) =>
  api.post(`/admin/communities/${id}/reject`, { reason });

export const listEvents = (p: { status?: EventStatus; cursor?: number | null; size?: number } = {}) =>
  api.get<CursorPage<EventView>>('/admin/events', { status: p.status, cursor: p.cursor, size: p.size });
export const approveEvent = (id: number) => api.post(`/admin/events/${id}/approve`);
export const rejectEvent = (id: number, reason?: string) =>
  api.post(`/admin/events/${id}/reject`, { reason });
