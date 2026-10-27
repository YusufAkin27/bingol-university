import { api, apiBlob } from './client';

/**
 * Anket yonetimi (ADMIN). Backend (BE4) sozlesmesi hazir olana dek tahmini sozlesmedir; uclar
 * /api/admin/polls altindadir. Gizli ankette sonuc/CSV'de kimlik YOKTUR (yalniz toplamlar).
 */
export type PollType = 'SINGLE' | 'MULTI' | 'RATING';
export type PollStatus = 'DRAFT' | 'SCHEDULED' | 'ACTIVE' | 'CLOSED' | 'CANCELLED';
export type PollScope = 'GENERAL' | 'COMMUNITY' | 'EVENT' | 'MENU';
export type PollAudience = 'ALL' | 'STUDENT' | 'STAFF';

export interface AdminPoll {
  id: number;
  title: string;
  type: PollType;
  status: PollStatus;
  scope: PollScope;
  scopeId: number | null;
  anonymous: boolean;
  audience: PollAudience;
  startsAt: string | null;
  endsAt: string | null;
  options: { id: number; text: string }[];
  voteCount: number;
  createdAt: string;
}
export interface AdminPollPage {
  items: AdminPoll[];
  nextCursor: number | null;
}
export interface PollInput {
  title: string;
  type: PollType;
  scope: PollScope;
  scopeId: number | null;
  anonymous: boolean;
  audience: PollAudience;
  startsAt: string | null;
  endsAt: string | null;
  options: string[];
}
export interface PollResults {
  pollId: number;
  type: PollType;
  anonymous: boolean;
  totalVotes: number;
  eligibleCount: number;
  /** 0..1 */
  participationRate: number;
  options: { id: number; text: string; votes: number; percent: number }[];
  /** Yalniz RATING */
  average?: number | null;
}
export interface MenuRating {
  date: string;
  meal: string;
  average: number;
  count: number;
}
export interface PollFilters {
  status?: PollStatus | '';
  scope?: PollScope | '';
}

export const listPolls = (f: PollFilters, cursor?: number | null, size = 20) =>
  api.get<AdminPollPage>('/admin/polls', {
    cursor,
    size,
    status: f.status || undefined,
    scope: f.scope || undefined,
  });
export const createPoll = (b: PollInput) => api.post<AdminPoll>('/admin/polls', b);
export const updatePoll = (id: number, b: PollInput) => api.put<AdminPoll>(`/admin/polls/${id}`, b);
export const closePoll = (id: number) => api.post<AdminPoll>(`/admin/polls/${id}/close`, {});
export const cancelPoll = (id: number) => api.post<AdminPoll>(`/admin/polls/${id}/cancel`, {});
export const pollResults = (id: number) => api.get<PollResults>(`/admin/polls/${id}/results`);
export const exportPollCsv = (id: number): Promise<Blob> => apiBlob(`/admin/polls/${id}/export.csv`);
export const menuRatings = () => api.get<{ items: MenuRating[] }>('/admin/polls/menu-ratings');
