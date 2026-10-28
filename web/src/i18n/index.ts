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
import trAdminPush from './tr/admin-push';
import trAdminEvents from './tr/admin-events';
import trAdminSettings from './tr/admin-settings';
import trAdminSafety from './tr/admin-safety';
import trAdminChat from './tr/admin-chat';
import trAdminPosts from './tr/admin-posts';
import trAdminPolls from './tr/admin-polls';
import trAdminMail from './tr/admin-mail';
import trAdminMenu from './tr/admin-menu';
import trAdminAccessBans from './tr/admin-accessbans';
import trAdminProfanity from './tr/admin-profanity';
import trAdminCommunityCategories from './tr/admin-community-categories';
import trAdminOps from './tr/admin-ops';
import trAdminSystem from './tr/admin-system';
import trAdminPending from './tr/admin-pending';
import trAdminAcademic from './tr/admin-academic';
import trAdminGuard from './tr/admin-guard'; // yalnız tr: en/ar sözlüklerine de aynı Türkçe metin katılır
import trAdminShell from './tr/admin-shell'; // yalnız tr (yönetim kabuğu), aynı kural
import trAdminP05 from './tr/admin-p05'; // yalnız tr (yıkıcı eylem onayları), aynı kural
import trAdminWp02 from './tr/admin-wp02'; // yalnız tr (denetim v2, sohbet sebebi), aynı kural
import trSiteNew from './tr/site-new';
import trLegal from './tr/legal';
import trPages from './tr/pages';
import trSupportPublic from './tr/support-public';
import trSeo from './tr/seo';

import enCommon from './en/common';
import enSite from './en/site';
import enAdminDashboard from './en/admin-dashboard';
import enAdminUsers from './en/admin-users';
import enAdminAnalytics from './en/admin-analytics';
import enAdminModeration from './en/admin-moderation';
import enAdminSupport from './en/admin-support';
import enAdminContent from './en/admin-content';
import enAdminCampaigns from './en/admin-campaigns';
import enAdminPush from './en/admin-push';
import enAdminEvents from './en/admin-events';
import enAdminSettings from './en/admin-settings';
import enAdminSafety from './en/admin-safety';
import enAdminChat from './en/admin-chat';
import enAdminPosts from './en/admin-posts';
import enAdminPolls from './en/admin-polls';
import enAdminMail from './en/admin-mail';
import enAdminMenu from './en/admin-menu';
import enAdminAccessBans from './en/admin-accessbans';
import enAdminProfanity from './en/admin-profanity';
import enAdminCommunityCategories from './en/admin-community-categories';
import enAdminOps from './en/admin-ops';
import enAdminSystem from './en/admin-system';
import enAdminPending from './en/admin-pending';
import enAdminAcademic from './en/admin-academic';
import enSiteNew from './en/site-new';
import enLegal from './en/legal';
import enPages from './en/pages';
import enSupportPublic from './en/support-public';
import enSeo from './en/seo';

import arCommon from './ar/common';
import arSite from './ar/site';
import arAdminDashboard from './ar/admin-dashboard';
import arAdminUsers from './ar/admin-users';
import arAdminAnalytics from './ar/admin-analytics';
import arAdminModeration from './ar/admin-moderation';
import arAdminSupport from './ar/admin-support';
import arAdminContent from './ar/admin-content';
import arAdminCampaigns from './ar/admin-campaigns';
import arAdminPush from './ar/admin-push';
import arAdminEvents from './ar/admin-events';
import arAdminSettings from './ar/admin-settings';
import arAdminSafety from './ar/admin-safety';
import arAdminChat from './ar/admin-chat';
import arAdminPosts from './ar/admin-posts';
import arAdminPolls from './ar/admin-polls';
import arAdminMail from './ar/admin-mail';
import arAdminMenu from './ar/admin-menu';
import arAdminAccessBans from './ar/admin-accessbans';
import arAdminProfanity from './ar/admin-profanity';
import arAdminCommunityCategories from './ar/admin-community-categories';
import arAdminOps from './ar/admin-ops';
import arAdminSystem from './ar/admin-system';
import arAdminPending from './ar/admin-pending';
import arAdminAcademic from './ar/admin-academic';
import arSiteNew from './ar/site-new';
import arLegal from './ar/legal';
import arPages from './ar/pages';
import arSupportPublic from './ar/support-public';
import arSeo from './ar/seo';

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
  ...trAdminPush,
  ...trAdminEvents,
  ...trAdminSettings,
  ...trAdminSafety,
  ...trAdminChat,
  ...trAdminPosts,
  ...trAdminPolls,
  ...trAdminMail,
  ...trAdminMenu,
  ...trAdminAccessBans,
  ...trAdminProfanity,
  ...trAdminCommunityCategories,
  ...trAdminOps,
  ...trAdminSystem,
  ...trAdminPending,
  ...trAdminAcademic,
  ...trAdminGuard,
  ...trAdminShell,
  ...trAdminP05,
  ...trAdminWp02,
  ...trSiteNew,
  ...trLegal,
  ...trPages,
  ...trSupportPublic,
  ...trSeo,
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
  ...enAdminPush,
  ...enAdminEvents,
  ...enAdminSettings,
  ...enAdminSafety,
  ...enAdminChat,
  ...enAdminPosts,
  ...enAdminPolls,
  ...enAdminMail,
  ...enAdminMenu,
  ...enAdminAccessBans,
  ...enAdminProfanity,
  ...enAdminCommunityCategories,
  ...enAdminOps,
  ...enAdminSystem,
  ...enAdminPending,
  ...enAdminAcademic,
  ...trAdminGuard,
  ...trAdminShell,
  ...trAdminP05,
  ...trAdminWp02,
  ...enSiteNew,
  ...enLegal,
  ...enPages,
  ...enSupportPublic,
  ...enSeo,
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
  ...arAdminPush,
  ...arAdminEvents,
  ...arAdminSettings,
  ...arAdminSafety,
  ...arAdminChat,
  ...arAdminPosts,
  ...arAdminPolls,
  ...arAdminMail,
  ...arAdminMenu,
  ...arAdminAccessBans,
  ...arAdminProfanity,
  ...arAdminCommunityCategories,
  ...arAdminOps,
  ...arAdminSystem,
  ...arAdminPending,
  ...arAdminAcademic,
  ...trAdminGuard,
  ...trAdminShell,
  ...trAdminP05,
  ...trAdminWp02,
  ...arSiteNew,
  ...arLegal,
  ...arPages,
  ...arSupportPublic,
  ...arSeo,
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
