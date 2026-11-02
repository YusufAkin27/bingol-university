// Kullanım istatistikleri API'si: GET /api/admin/analytics/usage/* (docs/USAGE_STATS.md, docs/ADMIN_API.md).
// Hepsi toplulaştırılmış ve kimliksizdir; "userDays" = günlük tekil kullanıcıların aralık boyunca toplamı.
import { api } from './client';
import type { DateRange } from './types';

const U = '/admin/analytics/usage';

export interface UsageDay {
  date: string;
  dau: number;
  reportingUsers: number;
  sessions: number;
  screenViews: number;
}
export interface UsageSummary {
  from: string;
  to: string;
  totalSessions: number;
  totalScreenViews: number;
  avgDau: number;
  avgReportingUsers: number;
  /** Veri yoksa null. */
  avgSessionSeconds: number | null;
  topScreen: string | null;
  topAction: string | null;
  daily: UsageDay[];
}

export interface UsageScreen {
  screen: string;
  views: number;
  userDays: number;
  avgDailyUsers: number;
  avgSeconds: number | null;
  medianSeconds: number | null;
  /** 0-100: ardından başka ekrana geçilmeyen görüntüleme yüzdesi. */
  exitPercent: number;
  /** `dates` ile aynı uzunlukta günlük görüntüleme. */
  trend: number[];
}
export interface UsageTopScreens {
  from: string;
  to: string;
  dates: string[];
  totalViews: number;
  items: UsageScreen[];
}

export interface UsageAction {
  action: string;
  count: number;
  userDays: number;
  adoptionPercent: number;
  trend: number[];
}
export interface UsageTopActions {
  from: string;
  to: string;
  dates: string[];
  totalEvents: number;
  avgReportingUsers: number;
  items: UsageAction[];
}

export interface UsageEdge {
  from: string;
  to: string;
  count: number;
}
export interface UsageFlow {
  from: string;
  to: string;
  totalTransitions: number;
  edges: UsageEdge[];
}

export interface UsageHourCell {
  /** ISO hafta günü: 1 = Pazartesi … 7 = Pazar. */
  dow: number;
  /** İstanbul saati 0-23. */
  hour: number;
  sessions: number;
  views: number;
}
export interface UsageHourly {
  from: string;
  to: string;
  totalSessions: number;
  totalViews: number;
  peak: { dow: number; hour: number; sessions: number } | null;
  cells: UsageHourCell[];
}

export interface UsageSegmentItem {
  /** 'other' = k-anonimlik eşiğinin altında birleşenler, 'unknown' = bilinmeyen. */
  key: string;
  userDays: number;
  percent: number;
}
export interface UsageSegments {
  from: string;
  to: string;
  kAnonymity: number;
  platforms: UsageSegmentItem[];
  versions: UsageSegmentItem[];
  faculties: UsageSegmentItem[];
  departments: UsageSegmentItem[];
}

export interface UsageFeature {
  feature: string;
  users: number;
  percentOfMau: number;
}
export interface UsageFeatures {
  /** 30 günlük pencerenin son günü; veri yoksa null. */
  asOf: string | null;
  mau: number;
  reportingUsers: number;
  items: UsageFeature[];
}

export const getUsageSummary = (r: DateRange = {}) => api.get<UsageSummary>(`${U}/summary`, { ...r });
export const getUsageScreens = (r: DateRange = {}) => api.get<UsageTopScreens>(`${U}/top-screens`, { ...r });
export const getUsageActions = (r: DateRange = {}) => api.get<UsageTopActions>(`${U}/top-actions`, { ...r });
export const getUsageFlow = (r: DateRange = {}) => api.get<UsageFlow>(`${U}/flow`, { ...r });
export const getUsageHourly = (r: DateRange = {}) => api.get<UsageHourly>(`${U}/hourly`, { ...r });
export const getUsageSegments = (r: DateRange = {}) => api.get<UsageSegments>(`${U}/segments`, { ...r });
export const getUsageFeatures = (r: DateRange = {}) => api.get<UsageFeatures>(`${U}/features`, { ...r });
