import { api } from './client';
import type {
  ActiveUsersResponse,
  AnalyticsOverview,
  BreakdownDimension,
  BreakdownResponse,
  ContentAnalytics,
  DateRange,
  EngagementResponse,
  PushAnalytics,
  RegistrationsResponse,
  RetentionResponse,
  SupportAnalytics,
} from './types';

const A = '/admin/analytics';

export const getOverview = () => api.get<AnalyticsOverview>(`${A}/overview`);
export const getRegistrations = (r: DateRange = {}) =>
  api.get<RegistrationsResponse>(`${A}/registrations`, { ...r });
export const getActiveUsers = (r: DateRange = {}) =>
  api.get<ActiveUsersResponse>(`${A}/active-users`, { ...r });
export const getBreakdown = (dimension: BreakdownDimension) =>
  api.get<BreakdownResponse>(`${A}/breakdown`, { dimension });
export const getEngagement = (r: DateRange = {}) => api.get<EngagementResponse>(`${A}/engagement`, { ...r });
export const getRetention = () => api.get<RetentionResponse>(`${A}/retention`);
export const getSupportAnalytics = () => api.get<SupportAnalytics>(`${A}/support`);
export const getPushAnalytics = () => api.get<PushAnalytics>(`${A}/push`);
export const getContentAnalytics = (r: DateRange = {}) => api.get<ContentAnalytics>(`${A}/content`, { ...r });
