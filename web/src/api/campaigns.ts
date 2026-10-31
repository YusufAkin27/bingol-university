import { api } from './client';
import { guardHeaders, type GuardOpts } from './guard';
import type {
  AudienceCount,
  CampaignAudience,
  CampaignContent,
  CampaignStatus,
  CampaignTarget,
  CampaignView,
  CreateCampaignRequest,
  CursorPage,
  NotificationType,
} from './types';

const P = '/admin/push';

/** Alıcı önizleme: count = tekil kitle, willReceive = tercihi kapalı olmayanlar, optedOut = count - willReceive. */
export interface AudiencePreview {
  count: number;
  willReceive: number;
  optedOut: number;
  byLanguage: Record<string, number>;
  sample: { id: number; displayName: string | null; email: string; language: string | null }[];
  notFound: string[];
}

/** Test ve tek kullanıcıya hızlı gönderim gövdesi (kitle sunucuda belirlenir, zamanlama yok). */
export interface QuickSendRequest {
  type?: NotificationType;
  tr: CampaignContent;
  en?: CampaignContent;
  ar?: CampaignContent;
  target?: CampaignTarget;
}

export const countAudience = (a: CampaignAudience) => api.post<AudienceCount>(`${P}/audience-count`, a);
export const previewAudience = (audience: CampaignAudience, type?: NotificationType) =>
  api.post<AudiencePreview>(`${P}/audience/preview`, { audience, type });
// W1-B (T-013): kampanya olusturma / zamanlama / iptal gerekce ister (>= 5 karakter, X-Admin-Reason).
export const createCampaign = (r: CreateCampaignRequest, o?: GuardOpts) =>
  api.post<CampaignView>(`${P}/campaigns`, r, guardHeaders(o));
export const sendTestCampaign = (r: QuickSendRequest) => api.post<CampaignView>(`${P}/campaigns/test`, r);
export const sendToUser = (userId: number, r: QuickSendRequest) =>
  api.post<CampaignView>(`${P}/users/${userId}/send`, r);
export const listCampaigns = (
  p: { cursor?: number | null; size?: number; status?: CampaignStatus } = {},
) => api.get<CursorPage<CampaignView>>(`${P}/campaigns`, { cursor: p.cursor, size: p.size, status: p.status });
export const getCampaign = (id: number) => api.get<CampaignView>(`${P}/campaigns/${id}`);
export const cancelCampaign = (id: number, o?: GuardOpts) =>
  api.post(`${P}/campaigns/${id}/cancel`, undefined, guardHeaders(o));
export const pauseCampaign = (id: number) => api.post(`${P}/campaigns/${id}/pause`);
export const resumeCampaign = (id: number) => api.post(`${P}/campaigns/${id}/resume`);
