/**
 * Sözlük birleştirici. Her dil için ad alanı dosyaları (./tr/*.ts, ./en/*.ts, ./ar/*.ts) burada birleşir.
 * Yeni ad alanı eklerken üç dilde de dosya açıp aşağıya ekleyin. Türkçe (tr) kaynak sözlüktür: `TranslationKey`
 * ondan türer; en/ar `Record<TranslationKey, string>` olduğundan eksik anahtar derleme hatası verir.
 */
import type { Lang } from './lang';

import trCommon from './tr/common';
import trSite from './tr/site';
import trAdminDashboard from './tr/admin-dashboard';
import trAdminUsers from './tr/admin-users';
import trAdminAnalytics from './tr/admin-analytics';
import trAdminModeration from './tr/admin-moderation';
import trAdminSupport from './tr/admin-support';
import trAdminContent from './tr/admin-content';
import trAdminCampaigns from './tr/admin-campaigns';
import trAdminSettings from './tr/admin-settings';
import trAdminSafety from './tr/admin-safety';
import trAdminChat from './tr/admin-chat';
import trSiteNew from './tr/site-new';
import trLegal from './tr/legal';
import trPages from './tr/pages';

import enCommon from './en/common';
import enSite from './en/site';
import enAdminDashboard from './en/admin-dashboard';
import enAdminUsers from './en/admin-users';
import enAdminAnalytics from './en/admin-analytics';
import enAdminModeration from './en/admin-moderation';
import enAdminSupport from './en/admin-support';
import enAdminContent from './en/admin-content';
import enAdminCampaigns from './en/admin-campaigns';
import enAdminSettings from './en/admin-settings';
import enAdminSafety from './en/admin-safety';
import enAdminChat from './en/admin-chat';
import enSiteNew from './en/site-new';
import enLegal from './en/legal';
import enPages from './en/pages';

import arCommon from './ar/common';
import arSite from './ar/site';
import arAdminDashboard from './ar/admin-dashboard';
import arAdminUsers from './ar/admin-users';
import arAdminAnalytics from './ar/admin-analytics';
import arAdminModeration from './ar/admin-moderation';
import arAdminSupport from './ar/admin-support';
import arAdminContent from './ar/admin-content';
import arAdminCampaigns from './ar/admin-campaigns';
import arAdminSettings from './ar/admin-settings';
import arAdminSafety from './ar/admin-safety';
import arAdminChat from './ar/admin-chat';
import arSiteNew from './ar/site-new';
import arLegal from './ar/legal';
import arPages from './ar/pages';

const tr = {
  ...trCommon,
  ...trSite,
  ...trAdminDashboard,
  ...trAdminUsers,
  ...trAdminAnalytics,
  ...trAdminModeration,
  ...trAdminSupport,
  ...trAdminContent,
  ...trAdminCampaigns,
  ...trAdminSettings,
  ...trAdminSafety,
  ...trAdminChat,
  ...trSiteNew,
  ...trLegal,
  ...trPages,
};

export type TranslationKey = keyof typeof tr;
export type Dictionary = Record<TranslationKey, string>;
export type TParams = Record<string, string | number>;

const en: Dictionary = {
  ...enCommon,
  ...enSite,
  ...enAdminDashboard,
  ...enAdminUsers,
  ...enAdminAnalytics,
  ...enAdminModeration,
  ...enAdminSupport,
  ...enAdminContent,
  ...enAdminCampaigns,
  ...enAdminSettings,
  ...enAdminSafety,
  ...enAdminChat,
  ...enSiteNew,
  ...enLegal,
  ...enPages,
};

const ar: Dictionary = {
  ...arCommon,
  ...arSite,
  ...arAdminDashboard,
  ...arAdminUsers,
  ...arAdminAnalytics,
  ...arAdminModeration,
  ...arAdminSupport,
  ...arAdminContent,
  ...arAdminCampaigns,
  ...arAdminSettings,
  ...arAdminSafety,
  ...arAdminChat,
  ...arSiteNew,
  ...arLegal,
  ...arPages,
};

export const dictionaries: Record<Lang, Dictionary> = { tr, en, ar };

/** Dinamik (çalışma zamanında üretilen) anahtar sözlükte var mı. */
export function hasKey(key: string): key is TranslationKey {
  return Object.prototype.hasOwnProperty.call(tr, key);
}

/** `{ad}` yer tutucularını doldurur. Eksik anahtarda Türkçeye, o da yoksa anahtarın kendisine düşer. */
export function translate(lang: Lang, key: string, params?: TParams): string {
  const raw =
    (dictionaries[lang] as Record<string, string>)[key] ?? (tr as Record<string, string>)[key] ?? key;
  if (!params) return raw;
  return raw.replace(/\{(\w+)\}/g, (m, name: string) => (name in params ? String(params[name]) : m));
}
