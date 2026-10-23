import { publicApi } from '../../../api/client';
import type { LegalSummary, LegalType } from '../../../api/types';

/** Herkese açık sürüm geçmişi: `GET /api/legal/{type}/versions` (başlık, sürüm, tarih; içerik yok). */
export const listPublicLegalVersions = (type: LegalType) =>
  publicApi.get<LegalSummary[]>(`/legal/${type}/versions`);
