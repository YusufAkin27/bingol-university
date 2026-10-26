import type { IconName } from '../../../components/ui';
import type { TranslationKey } from '../../../i18n';
import type { ScreenKind } from './Phone';

export interface Feature {
  id: string;
  icon: IconName;
  screen: ScreenKind;
  title: TranslationKey;
  text: TranslationKey;
}

export const FEATURES: Feature[] = [
  { id: 'news', icon: 'news', screen: 'news', title: 'site.feat.news.title', text: 'site.feat.news.text' },
  { id: 'menu', icon: 'list', screen: 'menu', title: 'site.feat.menu.title', text: 'site.feat.menu.text' },
  { id: 'chat', icon: 'message', screen: 'chat', title: 'site.feat.chat.title', text: 'site.feat.chat.text' },
  {
    id: 'communities',
    icon: 'community',
    screen: 'communities',
    title: 'site.feat.communities.title',
    text: 'site.feat.communities.text',
  },
  {
    id: 'events',
    icon: 'calendar',
    screen: 'events',
    title: 'site.feat.events.title',
    text: 'site.feat.events.text',
  },
  {
    id: 'support',
    icon: 'lifebuoy',
    screen: 'support',
    title: 'site.feat.support.title',
    text: 'site.feat.support.text',
  },
  {
    id: 'admission',
    icon: 'check',
    screen: 'events',
    title: 'site.feat.admission.title',
    text: 'site.feat.admission.text',
  },
  {
    id: 'clubroles',
    icon: 'users',
    screen: 'communities',
    title: 'site.feat.clubroles.title',
    text: 'site.feat.clubroles.text',
  },
  {
    id: 'media',
    icon: 'message',
    screen: 'chat',
    title: 'site.feat.media.title',
    text: 'site.feat.media.text',
  },
  {
    id: 'privacysettings',
    icon: 'eyeOff',
    screen: 'privacy',
    title: 'site.feat.privacysettings.title',
    text: 'site.feat.privacysettings.text',
  },
  {
    id: 'secure',
    icon: 'shield',
    screen: 'privacy',
    title: 'site.feat.secure.title',
    text: 'site.feat.secure.text',
  },
  {
    id: 'notifications',
    icon: 'bell',
    screen: 'notifications',
    title: 'site.feat.notifications.title',
    text: 'site.feat.notifications.text',
  },
  {
    id: 'languages',
    icon: 'globe',
    screen: 'languages',
    title: 'site.feat.languages.title',
    text: 'site.feat.languages.text',
  },
  {
    id: 'privacy',
    icon: 'shield',
    screen: 'privacy',
    title: 'site.feat.privacy.title',
    text: 'site.feat.privacy.text',
  },
];
