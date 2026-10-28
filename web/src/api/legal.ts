import { api, publicApi } from './client';
import { guardHeaders, type GuardOpts } from './guard';
import type {
  LegalAcceptanceStat,
  LegalContent,
  LegalSummary,
  LegalType,
  LegalVersionRow,
  PublishLegalRequest,
} from './types';

export const LEGAL_TYPES: readonly LegalType[] = [
  'TERMS',
  'PRIVACY',
  'KVKK',
  'COMMUNITY_RULES',
  'EXPLICIT_CONSENT',
  'COOKIES',
  'CONTENT_REMOVAL',
  'RETENTION',
];

// --- herkese açık ---
export const listLegal = () => publicApi.get<LegalSummary[]>('/legal');
export const getLegal = (type: LegalType) => publicApi.get<LegalContent>(`/legal/${type}`);

// --- yönetici ---
export const publishLegal = (type: LegalType, body: PublishLegalRequest, o?: GuardOpts) =>
  api.post<{ version: number }>(`/admin/legal/${type}`, body, guardHeaders(o));
export const listLegalVersions = (type: LegalType) =>
  api.get<LegalVersionRow[]>(`/admin/legal/${type}/versions`);
export const getLegalAcceptanceStats = () => api.get<LegalAcceptanceStat[]>('/admin/legal/acceptance-stats');

/** URL'deki `community-rules` gibi yazımları LegalType'a çevirir; bilinmiyorsa null. */
export function parseLegalType(raw: string | undefined): LegalType | null {
  if (!raw) return null;
  const n = raw.toUpperCase().replace(/-/g, '_');
  return (LEGAL_TYPES as readonly string[]).includes(n) ? (n as LegalType) : null;
}
