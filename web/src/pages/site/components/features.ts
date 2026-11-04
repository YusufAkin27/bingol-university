import type { IconName } from '../../../components/ui';
import type { TranslationKey } from '../../../i18n';
import type { ShotId } from './screenshots';

/** Ayrıntılı özellik listesi (Özellikler sayfasındaki "Ve daha fazlası" ızgarası ve testler). */
export interface Feature {
  id: string;
  icon: IconName;
  title: TranslationKey;
  text: TranslationKey;
}

export const FEATURES: Feature[] = [
  { id: 'news', icon: 'news', title: 'site.feat.news.title', text: 'site.feat.news.text' },
  { id: 'menu', icon: 'list', title: 'site.feat.menu.title', text: 'site.feat.menu.text' },
  { id: 'chat', icon: 'message', title: 'site.feat.chat.title', text: 'site.feat.chat.text' },
  {
    id: 'communities',
    icon: 'community',
    title: 'site.feat.communities.title',
    text: 'site.feat.communities.text',
  },
  { id: 'events', icon: 'calendar', title: 'site.feat.events.title', text: 'site.feat.events.text' },
  { id: 'support', icon: 'lifebuoy', title: 'site.feat.support.title', text: 'site.feat.support.text' },
  { id: 'admission', icon: 'check', title: 'site.feat.admission.title', text: 'site.feat.admission.text' },
  { id: 'clubroles', icon: 'users', title: 'site.feat.clubroles.title', text: 'site.feat.clubroles.text' },
  { id: 'media', icon: 'message', title: 'site.feat.media.title', text: 'site.feat.media.text' },
  {
    id: 'privacysettings',
    icon: 'eyeOff',
    title: 'site.feat.privacysettings.title',
    text: 'site.feat.privacysettings.text',
  },
  { id: 'secure', icon: 'shield', title: 'site.feat.secure.title', text: 'site.feat.secure.text' },
  {
    id: 'notifications',
    icon: 'bell',
    title: 'site.feat.notifications.title',
    text: 'site.feat.notifications.text',
  },
  { id: 'languages', icon: 'globe', title: 'site.feat.languages.title', text: 'site.feat.languages.text' },
  { id: 'privacy', icon: 'shield', title: 'site.feat.privacy.title', text: 'site.feat.privacy.text' },
];

/** Telefon ekranıyla gösterilen vitrin özellikleri (Özellikler sayfasındaki satırlar, Ana Sayfa'daki kartlar). */
export interface Showcase {
  id: string;
  shot: ShotId;
  /** İkinci (arka) telefon. */
  secondShot?: ShotId;
  /** Özet ızgarası simgesi. */
  icon: IconName;
  /** Satır etiketi (örn. "Beslenme"). */
  category: TranslationKey;
  /** Gerçek uygulama davranışını anlatan üç kısa madde. */
  points: [TranslationKey, TranslationKey, TranslationKey];
  title: TranslationKey;
  text: TranslationKey;
}

export const SHOWCASE: Showcase[] = [
  {
    id: 'home',
    shot: 'home',
    icon: 'home',
    category: 'site.rd02.cat.home',
    points: ['site.rd02.pt.home.1', 'site.rd02.pt.home.2', 'site.rd02.pt.home.3'],
    title: 'site.show.home.title',
    text: 'site.show.home.text',
  },
  {
    id: 'discover',
    shot: 'discover',
    icon: 'image',
    category: 'site.rd02.cat.discover',
    points: ['site.rd02.pt.discover.1', 'site.rd02.pt.discover.2', 'site.rd02.pt.discover.3'],
    title: 'site.show.discover.title',
    text: 'site.show.discover.text',
  },
  {
    id: 'chat',
    shot: 'chat',
    icon: 'message',
    category: 'site.rd02.cat.chat',
    points: ['site.rd02.pt.chat.1', 'site.rd02.pt.chat.2', 'site.rd02.pt.chat.3'],
    title: 'site.show.chat.title',
    text: 'site.show.chat.text',
  },
  {
    id: 'clubs',
    shot: 'clubs',
    icon: 'community',
    category: 'site.rd02.cat.clubs',
    points: ['site.rd02.pt.clubs.1', 'site.rd02.pt.clubs.2', 'site.rd02.pt.clubs.3'],
    title: 'site.show.clubs.title',
    text: 'site.show.clubs.text',
  },
  {
    id: 'events',
    shot: 'events',
    secondShot: 'qr',
    icon: 'calendar',
    category: 'site.rd02.cat.events',
    points: ['site.rd02.pt.events.1', 'site.rd02.pt.events.2', 'site.rd02.pt.events.3'],
    title: 'site.show.events.title',
    text: 'site.show.events.text',
  },
  {
    id: 'menu',
    shot: 'menu',
    icon: 'list',
    category: 'site.rd02.cat.menu',
    points: ['site.rd02.pt.menu.1', 'site.rd02.pt.menu.2', 'site.rd02.pt.menu.3'],
    title: 'site.show.menu.title',
    text: 'site.show.menu.text',
  },
  {
    id: 'polls',
    shot: 'poll',
    icon: 'pie',
    category: 'site.rd02.cat.polls',
    points: ['site.rd02.pt.polls.1', 'site.rd02.pt.polls.2', 'site.rd02.pt.polls.3'],
    title: 'site.show.polls.title',
    text: 'site.show.polls.text',
  },
  {
    id: 'academic',
    shot: 'academic',
    icon: 'graduation',
    category: 'site.rd02.cat.academic',
    points: ['site.rd02.pt.academic.1', 'site.rd02.pt.academic.2', 'site.rd02.pt.academic.3'],
    title: 'site.show.academic.title',
    text: 'site.show.academic.text',
  },
];

/** Ayrıntı ızgarasında, satırlarla çakışmayan (yinelenmeyen) özellikler. */
export const MORE_FEATURE_IDS = FEATURES.filter(
  (f) => !['menu', 'chat', 'communities', 'events'].includes(f.id),
).map((f) => f.id);
