/**
 * Yönetim menüsü TEK yerde tanımlıdır. Yeni sayfa/öğe eklemek için yalnızca bu dosyayı (ve routes.tsx) düzenleyin.
 * Etiketler çeviri anahtarıdır (i18n/*\/common.ts içindeki `admin.nav.*`).
 */
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
        to: paths.admin.dashboard,
        labelKey: 'admin.nav.dashboard',
        icon: 'home',
        end: true,
      },
      { id: 'analytics', to: paths.admin.analytics(), labelKey: 'admin.nav.analytics', icon: 'chart' },
    ],
  },
  {
    id: 'people',
    labelKey: 'admin.nav.group.people',
    items: [
      { id: 'users', to: paths.admin.users, labelKey: 'admin.nav.users', icon: 'users' },
      { id: 'pendingUsers', to: paths.admin.pendingUsers, labelKey: 'admin.nav.pendingUsers', icon: 'mail' },
    ],
  },
  {
    id: 'moderation',
    labelKey: 'admin.nav.group.moderation',
    items: [
      { id: 'reports', to: paths.admin.reports, labelKey: 'admin.nav.reports', icon: 'flag' },
      { id: 'chatFeed', to: paths.admin.chatFeed, labelKey: 'admin.nav.chatFeed', icon: 'message' },
      { id: 'posts', to: paths.admin.posts, labelKey: 'admin.nav.posts', icon: 'list' },
      { id: 'polls', to: paths.admin.polls, labelKey: 'admin.nav.polls', icon: 'chart' },
      {
        id: 'communities',
        to: paths.admin.communities,
        labelKey: 'admin.nav.communities',
        icon: 'community',
        end: true,
      },
      { id: 'events', to: paths.admin.events, labelKey: 'admin.nav.events', icon: 'calendar', end: true },
      { id: 'appeals', to: paths.admin.appeals, labelKey: 'admin.nav.appeals', icon: 'alert' },
      { id: 'suspensions', to: paths.admin.suspensions, labelKey: 'admin.nav.suspensions', icon: 'users' },
      { id: 'blocklist', to: paths.admin.blocklist, labelKey: 'admin.nav.blocklist', icon: 'eyeOff' },
      { id: 'accessBans', to: paths.admin.accessBans, labelKey: 'admin.nav.accessBans', icon: 'shield' },
      { id: 'profanity', to: paths.admin.profanity, labelKey: 'admin.nav.profanity', icon: 'eyeOff' },
      {
        id: 'eventApplications',
        to: paths.admin.eventApplications,
        labelKey: 'admin.nav.eventApplications',
        icon: 'list',
      },
      { id: 'clubAudit', to: paths.admin.clubAudit, labelKey: 'admin.nav.clubAudit', icon: 'shield' },
      { id: 'ops', to: paths.admin.ops, labelKey: 'admin.nav.ops', icon: 'panel' },
    ],
  },
  {
    id: 'academic',
    labelKey: 'admin.nav.group.academic',
    items: [
      { id: 'acdCalendar', to: paths.admin.acdCalendar, labelKey: 'admin.nav.acdCalendar', icon: 'calendar' },
      { id: 'acdExams', to: paths.admin.acdExams, labelKey: 'admin.nav.acdExams', icon: 'list' },
      { id: 'acdAnnouncements', to: paths.admin.acdAnnouncements, labelKey: 'admin.nav.acdAnnouncements', icon: 'news' },
    ],
  },
  {
    id: 'support',
    labelKey: 'admin.nav.group.support',
    items: [
      { id: 'tickets', to: paths.admin.tickets, labelKey: 'admin.nav.tickets', icon: 'lifebuoy' },
      { id: 'feedback', to: paths.admin.feedback, labelKey: 'admin.nav.feedback', icon: 'message' },
    ],
  },
  {
    id: 'content',
    labelKey: 'admin.nav.group.content',
    items: [
      { id: 'legal', to: paths.admin.legal, labelKey: 'admin.nav.legal', icon: 'file' },
      { id: 'faq', to: paths.admin.faq, labelKey: 'admin.nav.faq', icon: 'help' },
      { id: 'news', to: paths.admin.news, labelKey: 'admin.nav.news', icon: 'news' },
    ],
  },
  {
    id: 'notifications',
    labelKey: 'admin.nav.group.notifications',
    items: [{ id: 'campaigns', to: paths.admin.campaigns, labelKey: 'admin.nav.campaigns', icon: 'bell' }],
  },
  {
    id: 'system',
    labelKey: 'admin.nav.group.system',
    items: [
      { id: 'settings', to: paths.admin.settings, labelKey: 'admin.nav.settings', icon: 'settings' },
      { id: 'audit', to: paths.admin.audit, labelKey: 'admin.nav.audit', icon: 'list' },
      { id: 'crypto', to: paths.admin.crypto, labelKey: 'admin.nav.crypto', icon: 'shield' },
    ],
  },
];

export const allAdminNavItems: AdminNavItem[] = adminNav.flatMap((g) => g.items);
