import { api, apiBlob } from './client';
import { guardHeaders, type GuardOpts } from './guard';
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
export const patchAdminEvent = (id: number, body: AdminEventPatch) =>
  api.patch<AdminEventDetail>(`${P}/${id}`, body);
export const hideEvent = (id: number, reason: string) =>
  api.post<AdminEventDetail>(`${P}/${id}/hide`, { reason });
export const unhideEvent = (id: number, reason: string) =>
  api.post<AdminEventDetail>(`${P}/${id}/unhide`, { reason });
export const cancelEvent = (id: number, reason: string) =>
  api.post<AdminEventDetail>(`${P}/${id}/cancel`, { reason });
export const deleteEvent = (id: number, reason: string) =>
  api.del(`${P}/${id}?reason=${encodeURIComponent(reason)}`);

// ---------- P07: etkinlik derin yönetimi (docs/ADMIN_API.md "Etkinlik derin yönetimi") ----------
// E-posta HER ZAMAN maskeli ("a***@bingol.edu.tr"); geri bildirimde yazan kimliği hiçbir koşulda dönmez.

export type ApplicationStatus = 'PENDING' | 'ACCEPTED' | 'WAITLISTED' | 'REJECTED' | 'CANCELLED';

export interface AdminApplicationSummary {
  mode: 'OPEN' | 'APPROVAL';
  /** null = sınırsız */
  capacity: number | null;
  goingCount: number;
  /** null = sınırsız kapasite */
  seatsLeft: number | null;
  pending: number;
  accepted: number;
  waitlisted: number;
  rejected: number;
  cancelled: number;
}
export interface AdminApplicationRow {
  id: number;
  userId: number;
  displayName: string;
  emailMasked: string | null;
  department: string | null;
  status: ApplicationStatus;
  note: string | null;
  answers: string[];
  queuedAt: string | null;
  decidedBy: number | null;
  decidedAt: string | null;
  decisionNote: string | null;
  createdAt: string;
  updatedAt: string;
}
export interface AdminApplicationPage {
  items: AdminApplicationRow[];
  nextCursor: number | null;
  summary: AdminApplicationSummary;
}
export interface ApplicationDecision {
  id: number;
  userId: number;
  status: ApplicationStatus;
  summary: AdminApplicationSummary;
}
export interface AdminAttendanceRow {
  userId: number;
  displayName: string;
  emailMasked: string | null;
  department: string | null;
  /** GOING | WALK_IN (RSVP'siz, kapıdan) */
  rsvp: 'GOING' | 'WALK_IN';
  /** null = işaretlenmemiş */
  present: boolean | null;
  method: 'QR' | 'MANUAL' | null;
  markedBy: number | null;
  markedByName: string | null;
  markedAt: string | null;
  hasCertificate: boolean;
  certificateRevoked: boolean;
}
export interface AdminAttendanceView {
  rows: AdminAttendanceRow[];
  summary: { going: number; present: number; absent: number; unmarked: number; walkIns: number };
  truncated: boolean;
}
export interface AttendanceMarkResult {
  userId: number;
  present: boolean;
  certificateExists: boolean;
  certificateValid: boolean;
}
export interface AdminCertificateRow {
  id: number;
  userId: number;
  holderName: string;
  emailMasked: string | null;
  codeHint: string;
  issuedAt: string;
  attended: boolean;
  revoked: boolean;
  revokedAt: string | null;
  revokedBy: number | null;
  revokeReason: string | null;
  valid: boolean;
}
export interface AdminFeedbackRow {
  id: number;
  rating: number;
  comment: string | null;
  createdAt: string;
}
export interface AdminFeedbackPage {
  items: AdminFeedbackRow[];
  nextCursor: number | null;
  summary: { total: number; average: number; distribution: number[] };
}
export interface AdminAnnouncementRow {
  id: number;
  senderId: number;
  senderName: string;
  recipients: number;
  createdAt: string;
}
export interface AdminOrganizerRow {
  userId: number;
  displayName: string;
  emailMasked: string | null;
  role: 'OWNER' | 'CO_ORGANIZER';
  addedBy: number | null;
  createdAt: string;
  removable: boolean;
}
export type EventBulkAction = 'HIDE' | 'UNHIDE' | 'CANCEL';
export interface EventBulkItem {
  id: number;
  ok: boolean;
  status: number;
  error: string | null;
}
export interface EventBulkResult {
  action: EventBulkAction;
  requested: number;
  done: number;
  failed: number;
  items: EventBulkItem[];
}
export const EVENT_BULK_MAX = 100;

const withReason = <T extends object>(body: T, o?: GuardOpts) => ({
  ...body,
  ...(o?.reason ? { reason: o.reason.trim() } : {}),
});

export const listEventApplications = (
  id: number,
  p: { status?: ApplicationStatus | ''; cursor?: number | null; size?: number } = {},
) =>
  api.get<AdminApplicationPage>(`${P}/${id}/applications`, {
    status: p.status || undefined,
    cursor: p.cursor,
    size: p.size,
  });
export const acceptApplication = (id: number, userId: number, o?: GuardOpts) =>
  api.post<ApplicationDecision>(`${P}/${id}/applications/${userId}/accept`, undefined, guardHeaders(o));
export const rejectApplication = (id: number, userId: number, o?: GuardOpts) =>
  api.post<ApplicationDecision>(`${P}/${id}/applications/${userId}/reject`, undefined, guardHeaders(o));

export const getEventAttendance = (id: number) => api.get<AdminAttendanceView>(`${P}/${id}/attendance`);
export const markEventAttendance = (id: number, userId: number, present: boolean, o?: GuardOpts) =>
  api.put<AttendanceMarkResult>(
    `${P}/${id}/attendance/${userId}`,
    withReason({ present }, o),
    guardHeaders(o),
  );

export const listEventCertificates = (id: number, p: { cursor?: number | null; size?: number } = {}) =>
  api.get<CursorPage<AdminCertificateRow>>(`${P}/${id}/certificates`, { cursor: p.cursor, size: p.size });
export const revokeCertificate = (id: number, userId: number, o?: GuardOpts) =>
  api.post<AdminCertificateRow>(`${P}/${id}/certificates/${userId}/revoke`, undefined, guardHeaders(o));
export const restoreCertificate = (id: number, userId: number, o?: GuardOpts) =>
  api.post<AdminCertificateRow>(`${P}/${id}/certificates/${userId}/restore`, undefined, guardHeaders(o));

export const listEventFeedback = (id: number, p: { cursor?: number | null; size?: number } = {}) =>
  api.get<AdminFeedbackPage>(`${P}/${id}/feedback`, { cursor: p.cursor, size: p.size });
export const deleteEventFeedback = (id: number, feedbackId: number, o?: GuardOpts) =>
  api.del(`${P}/${id}/feedback/${feedbackId}`, guardHeaders(o));

export const listEventAnnouncements = (id: number, p: { cursor?: number | null; size?: number } = {}) =>
  api.get<CursorPage<AdminAnnouncementRow>>(`${P}/${id}/announcements`, { cursor: p.cursor, size: p.size });
export const deleteEventAnnouncement = (id: number, announcementId: number, o?: GuardOpts) =>
  api.del(`${P}/${id}/announcements/${announcementId}`, guardHeaders(o));

export const listEventOrganizers = (id: number) => api.get<AdminOrganizerRow[]>(`${P}/${id}/organizers`);
export const removeEventOrganizer = (id: number, userId: number, o?: GuardOpts) =>
  api.del(`${P}/${id}/organizers/${userId}`, guardHeaders(o));

export const bulkEvents = (action: EventBulkAction, ids: number[], reason: string, o?: GuardOpts) =>
  api.post<EventBulkResult>(
    `${P}/bulk`,
    { action, ids, reason: reason.trim() },
    guardHeaders({ ...o, reason }),
  );

/** CSV (kişisel veri kısıtlı: e-posta maskeli). Yetki başlığı gerektiğinden Blob olarak alınır. */
export const exportEventAttendanceCsv = (id: number): Promise<Blob> => apiBlob(`${P}/${id}/attendance.csv`);
export const exportEventApplicationsCsv = (id: number, status?: ApplicationStatus | ''): Promise<Blob> =>
  apiBlob(`${P}/${id}/applications.csv`, { query: { status: status || undefined } });
export const exportEventsCsv = (p: Omit<AdminEventListParams, 'cursor' | 'size'> = {}): Promise<Blob> =>
  apiBlob(`${P}/export.csv`, {
    query: {
      status: p.status,
      q: p.q || undefined,
      communityId: p.communityId,
      standalone: p.standalone ? true : undefined,
      joinPolicy: p.joinPolicy,
      from: p.from,
      to: p.to,
    },
  });
