import { api } from './client';
import type {
  AudienceCount,
  CampaignAudience,
  CampaignView,
  CreateCampaignRequest,
  CursorPage,
} from './types';

const P = '/admin/push';

export const countAudience = (a: CampaignAudience) => api.post<AudienceCount>(`${P}/audience-count`, a);
export const createCampaign = (r: CreateCampaignRequest) => api.post<CampaignView>(`${P}/campaigns`, r);
export const listCampaigns = (p: { cursor?: number | null; size?: number } = {}) =>
  api.get<CursorPage<CampaignView>>(`${P}/campaigns`, { cursor: p.cursor, size: p.size });
export const getCampaign = (id: number) => api.get<CampaignView>(`${P}/campaigns/${id}`);
export const cancelCampaign = (id: number) => api.post(`${P}/campaigns/${id}/cancel`);
