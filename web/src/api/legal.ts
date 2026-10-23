import { api, publicApi } from './client';
import type {
  LegalAcceptanceStat,
  LegalContent,
  LegalSummary,
  LegalType,
  LegalVersionRow,
  PublishLegalRequest,
} from './types';

// --- herkese açık ---
export const listLegal = () => publicApi.get<LegalSummary[]>('/legal');
export const getLegal = (type: LegalType) => publicApi.get<LegalContent>(`/legal/${type}`);

// --- yönetici ---
export const publishLegal = (type: LegalType, body: PublishLegalRequest) =>
  api.post<{ version: number }>(`/admin/legal/${type}`, body);
export const listLegalVersions = (type: LegalType) =>
  api.get<LegalVersionRow[]>(`/admin/legal/${type}/versions`);
export const getLegalAcceptanceStats = () => api.get<LegalAcceptanceStat[]>('/admin/legal/acceptance-stats');

/** URL'deki `community-rules` gibi yazımları LegalType'a çevirir; bilinmiyorsa null. */
export function parseLegalType(raw: string | undefined): LegalType | null {
  if (!raw) return null;
  const n = raw.toUpperCase().replace(/-/g, '_');
  return n === 'TERMS' || n === 'PRIVACY' || n === 'KVKK' || n === 'COMMUNITY_RULES' ? n : null;
}
