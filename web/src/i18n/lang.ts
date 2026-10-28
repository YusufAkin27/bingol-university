import { readStorage, writeStorage } from '../lib/storage';

export type Lang = 'tr' | 'en' | 'ar';
export type Dir = 'ltr' | 'rtl';

export const LANGS: { code: Lang; label: string; dir: Dir; locale: string }[] = [
  { code: 'tr', label: 'Türkçe', dir: 'ltr', locale: 'tr-TR' },
  { code: 'en', label: 'English', dir: 'ltr', locale: 'en-US' },
  // Latin rakamlar: tablolar ve grafiklerde tutarlı okunur
  { code: 'ar', label: 'العربية', dir: 'rtl', locale: 'ar-u-nu-latn' },
];

export const DEFAULT_LANG: Lang = 'tr';
const KEY = 'bu.lang';

export function isLang(v: unknown): v is Lang {
  return v === 'tr' || v === 'en' || v === 'ar';
}

export function dirOf(lang: Lang): Dir {
  return lang === 'ar' ? 'rtl' : 'ltr';
}

export function localeOf(lang: Lang): string {
  return LANGS.find((l) => l.code === lang)?.locale ?? 'tr-TR';
}

export function getStoredLang(): Lang {
  const v = readStorage('local', KEY);
  return isLang(v) ? v : DEFAULT_LANG;
}

let current: Lang = getStoredLang();
// Yönetim paneli yalnız Türkçedir: /admin altında etkin dil buraya sabitlenir; site dili tercihi (current/storage) değişmez.
let forced: Lang | null = null;

/** API istemcisi Accept-Language için bunu okur. */
export function getCurrentLang(): Lang {
  return forced ?? current;
}

/** Siteye ait (kayıtlı) dil tercihi; yönetim paneli sabitlemesinden etkilenmez. */
export function getSiteLang(): Lang {
  return current;
}

/** Geçici dil sabitlemesi (yönetim paneli); depoya yazmaz. `null` sabitlemeyi kaldırır. */
export function setForcedLang(lang: Lang | null): void {
  forced = lang;
}

export function setCurrentLang(lang: Lang): void {
  current = lang;
  writeStorage('local', KEY, lang);
  applyDocumentLang(lang);
}

export function applyDocumentLang(lang: Lang): void {
  if (typeof document === 'undefined') return;
  const l = forced ?? lang;
  document.documentElement.lang = l;
  document.documentElement.dir = dirOf(l);
}

/**
 * Ziyaretçinin tercih ettiği dil (kök `/` yönlendirmesi için): kayıtlı `bu.lang`, yoksa tarayıcı dili, yoksa Türkçe.
 * `getStoredLang`tan farkı: kayıt yokken tarayıcı diline bakar.
 */
export function detectPreferredLang(): Lang {
  const stored = readStorage('local', KEY);
  if (isLang(stored)) return stored;
  const nav = typeof navigator !== 'undefined' ? [...(navigator.languages ?? []), navigator.language] : [];
  for (const raw of nav) {
    const code = (raw ?? '').slice(0, 2).toLowerCase();
    if (isLang(code)) return code;
  }
  return DEFAULT_LANG;
}
