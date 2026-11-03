// Kullanıcı davranış analizi: GET /api/admin/analytics/behavior/* (backend: analytics.behavior.BehaviorController).
// Tipler BRIEF_BEHAVIOR.md sözleşmesiyle birebirdir; süreler milisaniye, oranlar 0..1, günler Europe/Istanbul.
// İzin: özet/ekran/akış/eylem analytics.read; kullanıcı uçları users.pii (ya da FULL) ister ve denetim kaydına yazılır.
import { api } from './client';

const B = '/admin/analytics/behavior';

export interface BehaviorRange {
  from?: string;
  to?: string;
}

export interface BehaviorOverview {
  sessions: number;
  users: number;
  avgSessionMs: number;
  medianSessionMs: number;
  avgScreensPerSession: number;
  sessionsPerUser: number;
  bounceRate: number;
  quickCloseRate: number;
  byDay: { day: string; sessions: number; avgSessionMs: number; bounceRate: number }[];
  durationBuckets: { label: string; sessions: number }[];
}

export type ScreenSort = 'views' | 'users' | 'avgDwellMs' | 'exitRate' | 'bounceRate';
export type SortDir = 'asc' | 'desc';

export interface ScreenStat {
  screen: string;
  views: number;
  users: number;
  avgDwellMs: number;
  medianDwellMs: number;
  p90DwellMs: number;
  exitRate: number;
  bounceRate: number;
  sharePct: number;
}

export interface Paged<T> {
  items: T[];
  page: number;
  size: number;
  total: number;
}

export interface BehaviorFlows {
  topTransitions: { from: string; to: string; count: number }[];
  entryScreens: { screen: string; sessions: number }[];
  exitScreens: { screen: string; sessions: number }[];
  dropOff: { screen: string; entered: number; left: number; leftRate: number }[];
}

export interface BehaviorAction {
  kind: string;
  count: number;
  users: number;
  perScreen: { screen: string; count: number }[];
}

export interface BehaviorActions {
  items: BehaviorAction[];
}

export type UserSort = 'sessions' | 'totalMs' | 'avgSessionMs' | 'bounceRate' | 'quickCloseCount' | 'lastSeenAt';

export interface BehaviorUserRow {
  userId: number;
  displayName: string;
  email: string;
  department: string | null;
  grade: string | null;
  sessions: number;
  totalMs: number;
  avgSessionMs: number;
  bounceRate: number;
  quickCloseCount: number;
  lastSeenAt: string | null;
  topScreens: { screen: string; ms: number }[];
}

export type SessionEndReason = 'background' | 'exit' | 'timeout' | 'derived';

export interface SessionStep {
  type: 'screen' | 'action';
  screen: string | null;
  /** Yalnız type = action iken. */
  kind?: string | null;
  /** Yalnız type = screen iken; ölçülemediyse null. */
  dwellMs?: number | null;
  at: string;
}

export interface BehaviorSession {
  sid: string;
  startedAt: string;
  endedAt: string | null;
  durationMs: number;
  bounce: boolean;
  quickClose: boolean;
  reason: SessionEndReason;
  steps: SessionStep[];
}

export interface BehaviorUserDetail {
  user: {
    userId: number;
    displayName: string;
    email: string;
    department: string | null;
    grade: string | null;
  };
  summary: {
    sessions: number;
    totalMs: number;
    avgSessionMs: number;
    bounceRate: number;
    quickCloseCount: number;
    lastSeenAt: string | null;
  };
  sessions: BehaviorSession[];
}

export interface ListParams<S extends string> {
  from?: string;
  to?: string;
  sort?: S;
  dir?: SortDir;
  page?: number;
  size?: number;
  q?: string;
}

export const getBehaviorOverview = (r: BehaviorRange) => api.get<BehaviorOverview>(`${B}/overview`, { ...r });
export const getBehaviorScreens = (p: ListParams<ScreenSort>) => api.get<Paged<ScreenStat>>(`${B}/screens`, { ...p });
export const getBehaviorFlows = (r: BehaviorRange) => api.get<BehaviorFlows>(`${B}/flows`, { ...r });
export const getBehaviorActions = (r: BehaviorRange) => api.get<BehaviorActions>(`${B}/actions`, { ...r });
export const getBehaviorUsers = (p: ListParams<UserSort>) =>
  api.get<Paged<BehaviorUserRow>>(`${B}/users`, { ...p, q: p.q || undefined });
export const getBehaviorUser = (id: number, days: number) =>
  api.get<BehaviorUserDetail>(`${B}/users/${id}`, { days });
