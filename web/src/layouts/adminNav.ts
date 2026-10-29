/**
 * Yönetim menüsü TEK yerde tanımlıdır. Yeni sayfa/öğe eklemek için yalnızca bu dosyayı (ve routes.tsx) düzenleyin.
 * Etiketler çeviri anahtarıdır (i18n/*\/common.ts içindeki `admin.nav.*`).
 */
import type { Permission } from '../api/rbac';
import type { IconName } from '../components/ui/Icon';
import type { TranslationKey } from '../i18n';
import { paths } from '../paths';

export interface AdminNavItem {
  id: string;
  to: string;
  labelKey: TranslationKey;
  icon: IconName;
  /** true: yalnızca tam eşleşmede aktif (örn. Genel bakış) */
  end?: boolean;
  /**
   * P16: bu öğeyi açmak için gereken yönetici izni (backend `PermissionMatrix` anahtarlarıyla aynı). Yetkisiz öğe menüde
   * GİZLENİR ve rota "yetkiniz yok" sayfasına düşer. UI gizlemesi güvenlik değildir: asıl denetim sunucudadır.
   */
  perm?: Permission;
}

export interface AdminNavGroup {
  id: string;
  labelKey: TranslationKey;
  items: AdminNavItem[];
}

export const adminNav: AdminNavGroup[] = [
  {
    id: 'overview',
    labelKey: 'admin.nav.group.overview',
    items: [
      {
        id: 'dashboard',
        perm: 'dashboard.read',
        to: paths.admin.dashboard,
        labelKey: 'admin.nav.dashboard',
        icon: 'home',
        end: true,
      },
      { id: 'analytics', perm: 'analytics.read', to: paths.admin.analytics(), labelKey: 'admin.nav.analytics', icon: 'chart' },
    ],
  },
  {
    id: 'people',
    labelKey: 'admin.nav.group.people',
    items: [
      { id: 'users', perm: 'users.read', to: paths.admin.users, labelKey: 'admin.nav.users', icon: 'users' },
      { id: 'pendingUsers', perm: 'users.pii', to: paths.admin.pendingUsers, labelKey: 'admin.nav.pendingUsers', icon: 'mail' },
      { id: 'suspensions', perm: 'moderation.read', to: paths.admin.suspensions, labelKey: 'admin.nav.suspensions', icon: 'users' },
      { id: 'appeals', perm: 'moderation.read', to: paths.admin.appeals, labelKey: 'admin.nav.appeals', icon: 'alert' },
      { id: 'accessBans', perm: 'moderation.read', to: paths.admin.accessBans, labelKey: 'admin.nav.accessBans', icon: 'shield' },
    ],
  },
  {
    id: 'moderation',
    labelKey: 'admin.nav.group.moderation',
    items: [
      { id: 'reports', perm: 'moderation.read', to: paths.admin.reports, labelKey: 'admin.nav.reports', icon: 'flag' },
      { id: 'chatFeed', perm: 'chat.read', to: paths.admin.chatFeed, labelKey: 'admin.nav.chatFeed', icon: 'message' },
      { id: 'posts', perm: 'content.read', to: paths.admin.posts, labelKey: 'admin.nav.posts', icon: 'list' },
      { id: 'polls', perm: 'content.read', to: paths.admin.polls, labelKey: 'admin.nav.polls', icon: 'chart' },
      { id: 'blocklist', perm: 'moderation.read', to: paths.admin.blocklist, labelKey: 'admin.nav.blocklist', icon: 'eyeOff' },
      { id: 'strikes', perm: 'moderation.read', to: paths.admin.strikes, labelKey: 'admin.p11.nav.strikes', icon: 'alert' },
      { id: 'hiddenContent', perm: 'moderation.read', to: paths.admin.hiddenContent, labelKey: 'admin.p11.nav.hidden', icon: 'eyeOff' },
      { id: 'reasonTemplates', perm: 'moderation.read', to: paths.admin.reasonTemplates, labelKey: 'admin.p11.nav.templates', icon: 'list' },
      { id: 'profanity', perm: 'moderation.read', to: paths.admin.profanity, labelKey: 'admin.nav.profanity', icon: 'eyeOff' },
    ],
  },
  {
    id: 'community',
    labelKey: 'admin.nav.group.community',
    items: [
      {
        id: 'communities',
        perm: 'content.read',
        to: paths.admin.communities,
        labelKey: 'admin.nav.communities',
        icon: 'community',
        end: true,
      },
      {
        id: 'communityCategories',
        perm: 'content.read',
        to: paths.admin.communityCategories,
        labelKey: 'admin.nav.communityCategories',
        icon: 'community',
      },
      { id: 'clubAudit', perm: 'content.read', to: paths.admin.clubAudit, labelKey: 'admin.nav.clubAudit', icon: 'shield' },
      { id: 'contentReview', perm: 'content.read', to: paths.admin.contentReview, labelKey: 'admin.p06.nav.contentReview', icon: 'flag' },
      { id: 'events', perm: 'content.read', to: paths.admin.events, labelKey: 'admin.nav.events', icon: 'calendar', end: true },
      {
        id: 'eventApplications',
        perm: 'content.read',
        to: paths.admin.eventApplications,
        labelKey: 'admin.nav.eventApplications',
        icon: 'list',
      },
    ],
  },
  {
    id: 'academic',
    labelKey: 'admin.nav.group.academic',
    items: [
      { id: 'acdCalendar', perm: 'content.read', to: paths.admin.acdCalendar, labelKey: 'admin.nav.acdCalendar', icon: 'calendar' },
      { id: 'acdExams', perm: 'content.read', to: paths.admin.acdExams, labelKey: 'admin.nav.acdExams', icon: 'list' },
      { id: 'acdAnnouncements', perm: 'content.read', to: paths.admin.acdAnnouncements, labelKey: 'admin.nav.acdAnnouncements', icon: 'news' },
    ],
  },
  {
    id: 'support',
    labelKey: 'admin.nav.group.support',
    items: [
      { id: 'tickets', perm: 'support.read', to: paths.admin.tickets, labelKey: 'admin.nav.tickets', icon: 'lifebuoy' },
      { id: 'feedback', perm: 'support.read', to: paths.admin.feedback, labelKey: 'admin.nav.feedback', icon: 'message' },
    ],
  },
  {
    id: 'content',
    labelKey: 'admin.nav.group.content',
    items: [
      { id: 'legal', perm: 'legal.read', to: paths.admin.legal, labelKey: 'admin.nav.legal', icon: 'file' },
      { id: 'faq', perm: 'content.read', to: paths.admin.faq, labelKey: 'admin.nav.faq', icon: 'help' },
      { id: 'news', perm: 'content.read', to: paths.admin.news, labelKey: 'admin.nav.news', icon: 'news' },
      { id: 'menu', perm: 'content.read', to: paths.admin.menu, labelKey: 'admin.nav.menu', icon: 'calendar' },
    ],
  },
  {
    id: 'notifications',
    labelKey: 'admin.nav.group.notifications',
    items: [
      { id: 'campaigns', perm: 'comms.read', to: paths.admin.campaigns, labelKey: 'admin.nav.campaigns', icon: 'bell' },
      { id: 'mailTemplates', perm: 'comms.read', to: paths.admin.mailTemplates, labelKey: 'admin.nav.mailTemplates', icon: 'file' },
      { id: 'mailCampaigns', perm: 'comms.read', to: paths.admin.mailCampaigns, labelKey: 'admin.nav.mailCampaigns', icon: 'mail' },
      { id: 'mailQueue', perm: 'system.read', to: paths.admin.mailQueue, labelKey: 'admin.p13.nav.queue', icon: 'list' },
      { id: 'mailSuppressions', perm: 'system.read', to: paths.admin.mailSuppressions, labelKey: 'admin.p13.nav.suppressions', icon: 'shield' },
      { id: 'pushOps', perm: 'system.read', to: paths.admin.pushOps, labelKey: 'admin.p14.nav', icon: 'bell' },
    ],
  },
  {
    id: 'system',
    labelKey: 'admin.nav.group.system',
    items: [
      { id: 'system', perm: 'system.read', to: paths.admin.system, labelKey: 'admin.nav.system', icon: 'chart' },
      { id: 'sources', perm: 'content.read', to: paths.admin.sources, labelKey: 'admin.p15.nav.sources', icon: 'news' },
      { id: 'ops', perm: 'system.read', to: paths.admin.ops, labelKey: 'admin.nav.ops', icon: 'panel' },
      { id: 'crashes', perm: 'system.read', to: paths.admin.crashes, labelKey: 'admin.cr1.nav', icon: 'alert' },
      { id: 'settings', perm: 'settings.read', to: paths.admin.settings, labelKey: 'admin.nav.settings', icon: 'settings' },
      { id: 'roles', perm: 'dashboard.read', to: paths.admin.roles, labelKey: 'admin.p16.nav', icon: 'shield' },
      { id: 'audit', perm: 'audit.read', to: paths.admin.audit, labelKey: 'admin.nav.audit', icon: 'list' },
      { id: 'messageAccess', perm: 'audit.read', to: paths.admin.auditMessageAccess, labelKey: 'admin.wp02.nav.messageAccess', icon: 'shield' },
      { id: 'crypto', perm: 'system.read', to: paths.admin.crypto, labelKey: 'admin.nav.crypto', icon: 'shield' },
    ],
  },
];

export const allAdminNavItems: AdminNavItem[] = adminNav.flatMap((g) => g.items);

/**
 * Menü/arama eşleştirmesi için metni sadeleştirir: küçük harf (tr), aksansız. Böylece "gonderi" yazan
 * kullanıcı "Gönderiler"i, "iade" yazan "İtirazlar"daki İ'yi bulur.
 */
export function foldTr(s: string): string {
  return s
    .toLocaleLowerCase('tr')
    .replace(/ı/g, 'i')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');
}

/** Sorgunun tüm sözcükleri etikette geçiyorsa eşleşir (sıra önemsiz). */
export function navMatches(label: string, query: string): boolean {
  const words = foldTr(query).split(/\s+/).filter(Boolean);
  if (words.length === 0) return true;
  const hay = foldTr(label);
  return words.every((w) => hay.includes(w));
}

export interface NavLocation {
  group: AdminNavGroup;
  item: AdminNavItem;
}

/** Yola karşılık gelen menü öğesi (en uzun yol ön eki kazanır; /admin/users/5 → Kullanıcılar). */
export function locateNav(pathname: string): NavLocation | null {
  const clean = pathname.replace(/\/+$/, '') || '/';
  const root = paths.admin.dashboard.replace(/\/+$/, '');
  let best: (NavLocation & { len: number }) | null = null;
  for (const group of adminNav) {
    for (const item of group.items) {
      const base = item.to.split('?')[0].replace(/\/+$/, '') || '/';
      // kök (Genel bakış) yalnız tam eşleşir; diğerlerinde alt yollar (users/5) üst öğeye bağlanır
      const hit = clean === base || (base !== root && clean.startsWith(`${base}/`));
      if (hit && (!best || base.length > best.len)) best = { group, item, len: base.length };
    }
  }
  return best ? { group: best.group, item: best.item } : null;
}
