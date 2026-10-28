import type { ComponentType } from 'react';
import { ChatScreen } from './ChatScreen';
import { ClubsScreen } from './ClubsScreen';
import { DiscoverScreen } from './DiscoverScreen';
import { EventsScreen } from './EventsScreen';
import { HomeScreen } from './HomeScreen';
import { MenuScreen } from './MenuScreen';
import { LanguagesScreen, NotificationsScreen, PrivacyScreen } from './SettingsScreens';
import { SupportScreen } from './SupportScreen';

export type ScreenKind =
  | 'home'
  | 'news'
  | 'menu'
  | 'chat'
  | 'communities'
  | 'events'
  | 'support'
  | 'notifications'
  | 'languages'
  | 'privacy';

/** Her ekran türü, mobil uygulamanın ilgili ekranının HTML/CSS ile yeniden çizimidir (görsel dosya yok). */
export const SCREENS: Record<ScreenKind, ComponentType> = {
  home: HomeScreen,
  news: DiscoverScreen,
  menu: MenuScreen,
  chat: ChatScreen,
  communities: ClubsScreen,
  events: EventsScreen,
  support: SupportScreen,
  notifications: NotificationsScreen,
  languages: LanguagesScreen,
  privacy: PrivacyScreen,
};
