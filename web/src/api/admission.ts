import { api } from './client';
import type { AdmissionSummary, ClubAuditRow, CursorPage } from './types';

/** Etkinlik başvuru özeti (ADMIN yönetici yetkisiyle salt okunur). */
export const getAdmissionSummary = (eventId: number) =>
  api.get<AdmissionSummary>(`/events/${eventId}/applications/summary`);

/** Kulüp denetim kaydı (ADMIN tüm kulüpleri görür). */
export const listClubAudit = (communityId: number, p: { cursor?: number | null; size?: number } = {}) =>
  api.get<CursorPage<ClubAuditRow>>(`/communities/${communityId}/audit`, { cursor: p.cursor, size: p.size });
