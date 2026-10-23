import type { Lang, LegalTranslation, LegalType, LegalVersionRow, PublishLegalRequest } from '../../../api/types';

export const LEGAL_TYPES: LegalType[] = ['TERMS', 'PRIVACY', 'KVKK', 'COMMUNITY_RULES'];
export const LEGAL_LANGS: Lang[] = ['tr', 'en', 'ar'];
export const MAX_TITLE = 200;
export const MAX_CONTENT = 100000;

export interface LegalDraft {
  title: string;
  content: string;
}
export type LegalDrafts = Record<Lang, LegalDraft>;

export const emptyDrafts = (): LegalDrafts => ({
  tr: { title: '', content: '' },
  en: { title: '', content: '' },
  ar: { title: '', content: '' },
});

/** İçerikte "TASLAK" ibaresi var mı (Türkçe büyük/küçük harf duyarsız). */
export function containsDraftMarker(text: string): boolean {
  return text.toLocaleUpperCase('tr').includes('TASLAK') || text.toUpperCase().includes('TASLAK');
}

export function isFilled(d: LegalDraft): boolean {
  return d.title.trim() !== '' && d.content.trim() !== '';
}
export function isEmptyDraft(d: LegalDraft): boolean {
  return d.title.trim() === '' && d.content.trim() === '';
}

export type LegalErrorCode = 'trRequired' | 'enIncomplete' | 'arIncomplete' | 'tooLong';

export interface BuildResult {
  request: PublishLegalRequest | null;
  errors: LegalErrorCode[];
  /** Doldurulmamış, dolayısıyla Türkçe gösterilecek diller */
  fallbackLangs: Lang[];
  /** Yayınlanacak diller */
  included: Lang[];
}

/**
 * Taslaklardan yayın isteğini kurar. tr zorunlu; en/ar ya tam dolu ya da tamamen boş olmalı (yarım dil hatadır).
 * `requireReaccept` açıkken tüm kullanıcılar yeni sürümü kabul edene dek bekleyen onay görür.
 */
export function buildPublishRequest(drafts: LegalDrafts, requireReaccept: boolean): BuildResult {
  const errors: LegalErrorCode[] = [];
  const fallbackLangs: Lang[] = [];
  const included: Lang[] = [];
  const trans: Partial<Record<Lang, LegalTranslation>> = {};

  for (const lang of LEGAL_LANGS) {
    const d = drafts[lang];
    if (d.title.length > MAX_TITLE || d.content.length > MAX_CONTENT) errors.push('tooLong');
    if (isFilled(d)) {
      trans[lang] = { title: d.title.trim(), content: d.content.trim() };
      included.push(lang);
    } else if (lang === 'tr') {
      errors.push('trRequired');
    } else {
      if (!isEmptyDraft(d)) errors.push(lang === 'en' ? 'enIncomplete' : 'arIncomplete');
      fallbackLangs.push(lang);
    }
  }
  const request: PublishLegalRequest | null =
    errors.length === 0 && trans.tr
      ? { tr: trans.tr, ...(trans.en ? { en: trans.en } : {}), ...(trans.ar ? { ar: trans.ar } : {}), requireReaccept }
      : null;
  return { request, errors: [...new Set(errors)], fallbackLangs, included };
}

export function isDirty(drafts: LegalDrafts): boolean {
  return LEGAL_LANGS.some((l) => !isEmptyDraft(drafts[l]));
}

/** Yayınlanacak sürüm numarası: mevcut en büyük + 1. */
export function nextVersion(rows: LegalVersionRow[]): number {
  return rows.reduce((m, r) => Math.max(m, r.version), 0) + 1;
}

/** Bir dilin aktif sürümü; yoksa null. */
export function activeVersion(rows: LegalVersionRow[], lang: Lang): LegalVersionRow | null {
  return rows.find((r) => r.lang === lang && r.active) ?? null;
}

/** Kabul oranı 0-1 (kullanıcı yoksa 0). */
export function acceptanceRatio(accepted: number, total: number): number {
  return total <= 0 ? 0 : Math.min(1, accepted / total);
}
