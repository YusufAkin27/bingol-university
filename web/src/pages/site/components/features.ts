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
  { id: 'communities', icon: 'community', title: 'site.feat.communities.title', text: 'site.feat.communities.text' },
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
  { id: 'notifications', icon: 'bell', title: 'site.feat.notifications.title', text: 'site.feat.notifications.text' },
  { id: 'forum', icon: 'message', title: 'site.feat.forum.title', text: 'site.feat.forum.text' },
  { id: 'moderation', icon: 'shield', title: 'site.feat.moderation.title', text: 'site.feat.moderation.text' },
  { id: 'languages', icon: 'globe', title: 'site.feat.languages.title', text: 'site.feat.languages.text' },
  { id: 'privacy', icon: 'shield', title: 'site.feat.privacy.title', text: 'site.feat.privacy.text' },
];

/** Telefon ekranıyla gösterilen vitrin özellikleri (Özellikler sayfasındaki satırlar, Ana Sayfa'daki kartlar). */
export interface Showcase {
  id: string;
  shot: ShotId;
  /** İkinci (arka) telefon. */
  secondShot?: ShotId;
  title: TranslationKey;
  text: TranslationKey;
}

export const SHOWCASE: Showcase[] = [
  { id: 'home', shot: 'home', title: 'site.show.home.title', text: 'site.show.home.text' },
  { id: 'menu', shot: 'menu', title: 'site.show.menu.title', text: 'site.show.menu.text' },
  { id: 'clubs', shot: 'clubs', title: 'site.show.clubs.title', text: 'site.show.clubs.text' },
  { id: 'events', shot: 'events', title: 'site.show.events.title', text: 'site.show.events.text' },
  { id: 'news', shot: 'news', title: 'site.show.news.title', text: 'site.show.news.text' },
  { id: 'profile', shot: 'profile', title: 'site.show.profile.title', text: 'site.show.profile.text' },
  { id: 'settings', shot: 'settings', title: 'site.show.settings.title', text: 'site.show.settings.text' },
];

/** Ayrıntı ızgarasında, satırlarla çakışmayan (yinelenmeyen) özellikler. */
export const MORE_FEATURE_IDS = FEATURES.filter((f) => !['menu', 'chat', 'communities', 'events'].includes(f.id)).map(
  (f) => f.id,
);
