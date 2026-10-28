import { api } from './client';
import type { CursorPage, EventJoinPolicy, EventStatus, EventView } from './types';

const P = '/admin/events';

export type EventStatusFilter = EventStatus | 'ALL';
export type EventAction = 'approve' | 'reject' | 'edit' | 'hide' | 'unhide' | 'cancel' | 'delete';

export interface AdminEventListParams {
  status?: EventStatusFilter;
  q?: string;
  communityId?: number;
  standalone?: boolean;
  joinPolicy?: EventJoinPolicy;
  from?: string;
  to?: string;
  cursor?: number | null;
  size?: number;
}

export interface EventModerationEntry {
  id: number;
  adminId: number | null;
  adminName: string | null;
  /** HIDE | UNHIDE | CANCEL | DELETE | EDIT | REPORT_HIDE | REPORT_UNHIDE */
  action: string;
  fromStatus: EventStatus | null;
  toStatus: EventStatus | null;
  reason: string | null;
  createdAt: string;
}

export interface AdminEventDetail {
  event: EventView;
  organizerEmail: string | null;
  requests: { pending: number; waitlisted: number; accepted: number; rejected: number; cancelled: number };
  attendedCount: number;
  reviewNote: string | null;
  moderationReason: string | null;
  moderatedBy: number | null;
  moderatedAt: string | null;
  history: EventModerationEntry[];
  allowedActions: string[];
}

export interface AdminEventPatch {
  title?: string;
  description?: string;
  startsAt?: string;
  endsAt?: string;
  location?: string;
  /** 0 = sınırsız */
  capacity?: number;
  joinPolicy?: EventJoinPolicy;
  reason?: string;
}

export const listAdminEvents = (p: AdminEventListParams = {}) =>
  api.get<CursorPage<EventView>>(P, {
    status: p.status,
    q: p.q || undefined,
    communityId: p.communityId,
    standalone: p.standalone ? true : undefined,
    joinPolicy: p.joinPolicy,
    from: p.from,
    to: p.to,
    cursor: p.cursor,
    size: p.size,
  });
export const getAdminEvent = (id: number) => api.get<AdminEventDetail>(`${P}/${id}`);
export const patchAdminEvent = (id: number, body: AdminEventPatch) => api.patch<AdminEventDetail>(`${P}/${id}`, body);
export const hideEvent = (id: number, reason: string) => api.post<AdminEventDetail>(`${P}/${id}/hide`, { reason });
export const unhideEvent = (id: number, reason: string) => api.post<AdminEventDetail>(`${P}/${id}/unhide`, { reason });
export const cancelEvent = (id: number, reason: string) => api.post<AdminEventDetail>(`${P}/${id}/cancel`, { reason });
export const deleteEvent = (id: number, reason: string) =>
  api.del(`${P}/${id}?reason=${encodeURIComponent(reason)}`);
