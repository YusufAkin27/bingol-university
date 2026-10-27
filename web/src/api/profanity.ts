// Uygunsuz ifade filtresi (yönetici). Uçlar: /admin/profanity (liste/ekle/sil/bulk/check/info/stats/export.csv).
// Yerleşik liste kaynak dosyadadır ve silinemez; burada yalnızca yönetici BLOCK/ALLOW kayıtları yönetilir.
import { api, apiBlob } from './client';
import type { CursorPage } from './types';

export type ProfanityKind = 'BLOCK' | 'ALLOW';
export type ProfanityLang = 'ALL' | 'TR' | 'EN' | 'AR';
export const PROFANITY_LANGS: ProfanityLang[] = ['ALL', 'TR', 'EN', 'AR'];

export interface ProfanityTerm {
  id: number;
  term: string;
  kind: ProfanityKind;
  lang: ProfanityLang;
  note: string | null;
  createdBy: number | null;
  createdAt: string;
}

export interface ProfanityInfo {
  builtIn: { tr: number; en: number; ar: number; allow: number; source: string };
  adminBlock: number;
  adminAllow: number;
  settings: { enabled: boolean; mode: 'BLOCK' | 'FLAG' };
}

export interface ProfanityStatRow {
  entity: string;
  field: string;
  count: number;
}
export interface ProfanityStatWindow {
  total: number;
  byField: ProfanityStatRow[];
}
export interface ProfanityStats {
  last24h: ProfanityStatWindow;
  last7d: ProfanityStatWindow;
}

export interface ProfanityCheck {
  blocked: boolean;
  matches: string[];
  normalized: string;
}

export const profanityKeys = {
  all: ['profanity'] as const,
  list: (kind: ProfanityKind, q: string) => ['profanity', 'list', kind, q] as const,
  info: () => ['profanity', 'info'] as const,
  stats: () => ['profanity', 'stats'] as const,
};

export const listTerms = (p: { kind: ProfanityKind; q?: string; cursor?: number | null; size?: number }) =>
  api.get<CursorPage<ProfanityTerm>>('/admin/profanity', {
    kind: p.kind,
    q: p.q || undefined,
    cursor: p.cursor,
    size: p.size,
  });
export const addTerm = (b: { term: string; kind: ProfanityKind; lang: ProfanityLang; note?: string }) =>
  api.post<ProfanityTerm>('/admin/profanity', { ...b, note: b.note || undefined });
export const addBulk = (b: { text: string; kind: ProfanityKind; lang: ProfanityLang }) =>
  api.post<{ added: number; skipped: number; invalid: number }>('/admin/profanity/bulk', b);
export const removeTerm = (id: number) => api.del(`/admin/profanity/${id}`);
export const checkText = (text: string) => api.post<ProfanityCheck>('/admin/profanity/check', { text });
export const getInfo = () => api.get<ProfanityInfo>('/admin/profanity/info');
export const getStats = () => api.get<ProfanityStats>('/admin/profanity/stats');
export const exportCsv = (kind?: ProfanityKind) =>
  apiBlob('/admin/profanity/export.csv', { query: { kind } });
