import { api, apiBlob } from './client';
import { guardHeaders, type GuardOpts } from './guard';

/**
 * Anket yonetimi (ADMIN). Sozlesme backend `poll` paketiyle birebirdir (PollAdminController + PollDtos):
 * - Liste SAYFALIDIR: GET /api/admin/polls -> {items,page,size,total}; `status` DB durumudur (DRAFT|OPEN|CLOSED|CANCELLED),
 *   `state` turetilmis gorunum durumudur (DRAFT|SCHEDULED|OPEN|CLOSED|CANCELLED).
 * - Olusturma/duzenleme icin yonetim ucu yoktur: kullanici uclari (POST /api/polls, PATCH /api/polls/{id}) ADMIN JWT ile
 *   calisir (yonetici her ankete `canManage`).
 * - Gizli oyda kimlik HICBIR uc tarafindan donmez (yalniz toplamlar); CSV de kimliksizdir.
 */
export type PollType = 'SINGLE' | 'MULTI' | 'RATING' | 'RANKED';
export type PollScope = 'GLOBAL' | 'COMMUNITY' | 'MENU';
export type PollStatus = 'DRAFT' | 'OPEN' | 'CLOSED' | 'CANCELLED';
export type PollState = 'DRAFT' | 'SCHEDULED' | 'OPEN' | 'CLOSED' | 'CANCELLED';
export type PollShowResults = 'ALWAYS' | 'AFTER_VOTE' | 'AFTER_CLOSE';
export type PollBulkAction = 'CLOSE' | 'CANCEL' | 'DELETE';

export interface AdminPollRow {
  id: number;
  title: string;
  type: PollType;
  scope: PollScope;
  communityId: number | null;
  status: PollStatus;
  state: PollState;
  anonymous: boolean;
  totalVotes: number;
  opensAt: string | null;
  closesAt: string | null;
  createdAt: string;
  createdBy: number | null;
}
export interface AdminPollPage {
  items: AdminPollRow[];
  page: number;
  size: number;
  total: number;
}
export interface AdminPollStats {
  total: number;
  open: number;
  closed: number;
  draft: number;
  cancelled: number;
  totalVotes: number;
  byScope: Partial<Record<PollScope, number>>;
  /** Ortalama katilim yuzdesi (0..100); hesaplanamazsa null. */
  avgTurnoutPercent: number | null;
}
export interface PollAudience {
  faculty: string | null;
  department: string | null;
  grade: string | null;
}
export interface PollOptionView {
  id: number;
  text: string;
  position: number;
}
/** score yalniz RANKED'de (Borda puani). */
export interface PollResult {
  optionId: number;
  count: number;
  percent: number;
  score: number | null;
}
export interface PollTurnout {
  voted: number;
  eligible: number | null;
  percent: number | null;
}
/** GET /api/admin/polls/{id} (PollView; yonetici gorunumu: sonuclar her zaman gorunur, kimlik yok). */
export interface PollDetail {
  id: number;
  title: string;
  description: string | null;
  type: PollType;
  scope: PollScope;
  communityId: number | null;
  communityName: string | null;
  menuDate: string | null;
  menuItems: string[] | null;
  options: PollOptionView[];
  maxChoices: number;
  anonymous: boolean;
  allowChangeVote: boolean;
  showResults: PollShowResults;
  notify: boolean;
  opensAt: string | null;
  closesAt: string | null;
  audience: PollAudience | null;
  status: PollStatus;
  state: PollState;
  createdAt: string;
  closedAt: string | null;
  createdBy: { id: number; displayName: string | null } | null;
  canManage: boolean;
  resultsVisible: boolean;
  results: PollResult[] | null;
  totalVotes: number | null;
  turnout: PollTurnout | null;
  average: number | null;
  ratingCount: number | null;
}
export interface PollBulkResult {
  done: number;
  skipped: number;
}
export interface PollFilters {
  status?: PollStatus | '';
  scope?: PollScope | '';
  q?: string;
}

/** POST /api/polls gövdesi (CreateRequest). Zaman alanlari ISO metindir. */
export interface PollCreateBody {
  title: string;
  description?: string | null;
  type: PollType;
  scope: 'GLOBAL';
  options: string[];
  maxChoices?: number | null;
  anonymous: boolean;
  allowChangeVote: boolean;
  showResults: PollShowResults;
  notify: boolean;
  opensAt?: string | null;
  closesAt?: string | null;
  audience?: PollAudience | null;
  draft: boolean;
}
/** PATCH /api/polls/{id} gövdesi (UpdateRequest): alinmayan alan degismez; closesAt "" kapanisi kaldirir. */
export type PollUpdateBody = Partial<Omit<PollCreateBody, 'scope'>>;

export const listPolls = (f: PollFilters, page = 0, size = 20) =>
  api.get<AdminPollPage>('/admin/polls', {
    page,
    size,
    status: f.status || undefined,
    scope: f.scope || undefined,
    q: f.q?.trim() || undefined,
  });
export const pollStats = () => api.get<AdminPollStats>('/admin/polls/stats');
export const getPoll = (id: number) => api.get<PollDetail>(`/admin/polls/${id}`);
export const closePoll = (id: number, o?: GuardOpts) =>
  api.post<PollDetail>(`/admin/polls/${id}/close`, undefined, guardHeaders(o));
export const cancelPoll = (id: number, o?: GuardOpts) =>
  api.post<PollDetail>(`/admin/polls/${id}/cancel`, undefined, guardHeaders(o));
export const deletePoll = (id: number, o?: GuardOpts) => api.del(`/admin/polls/${id}`, guardHeaders(o));
export const bulkPolls = (ids: number[], action: PollBulkAction, o?: GuardOpts) =>
  api.post<PollBulkResult>('/admin/polls/bulk', { ids, action }, guardHeaders(o));
export const exportPollCsv = (id: number): Promise<Blob> => apiBlob(`/admin/polls/${id}/export.csv`);
export const createPoll = (b: PollCreateBody) => api.post<PollDetail>('/polls', b);
export const updatePoll = (id: number, b: PollUpdateBody) => api.patch<PollDetail>(`/polls/${id}`, b);
