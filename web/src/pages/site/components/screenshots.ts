// Tanıtım sitesindeki telefon ekran görüntüleri: TEK YERDEN eşleme.
//
// Görseller `web/public/site/screens/<ad>-<tema>.webp` (+ aynı adla `.png` yedek) yoluna konur (derlemeye girmez, adres sabittir):
//   <ad> = aşağıdaki `name`, <tema> = light | dark. Her ekran 1179x2556 (19.5:9), uygulamanın GERÇEK ekran çıktısıdır;
//   sistem çubukları kırpılmıştır (PhoneMockup kendi iOS durum çubuğunu ve ana göstergeyi çizer). Yalnız uygulamanın kendi
//   ekranları kullanılır: başka kullanıcıların içeriği/fotoğrafı/adı siteye KONMAZ (KVKK). Üretim: `web/scripts/make-screens.py`.
// Sayfanın o anki temasına göre doğru dosya seçilir. Dosya yoksa PhoneMockup .png'yi, o da yoksa boş zemini çizer (çökmez).
import type { TranslationKey } from '../../../i18n';

export type ShotId = 'home' | 'discover' | 'menu' | 'clubs' | 'events' | 'news' | 'profile' | 'settings' | 'support' | 'delete';

export type ShotTheme = 'light' | 'dark';

/** Ekran görüntülerinin ortak boyutu (iPhone 15 Pro, 1179x2556). <img width/height> olarak yazılır: yerleşim kayması (CLS) olmaz. */
export const SHOT_WIDTH = 1179;
export const SHOT_HEIGHT = 2556;
/** Görsellerin klasörü (public/ altında). */
export const SHOT_DIR = '/site/screens';

export interface Shot {
  /** Dosya adı kökü: `<name>-light.webp` / `<name>-dark.webp` (+ `.png`). */
  name: string;
  width: number;
  height: number;
  alt: TranslationKey;
}

const shot = (name: string, alt: TranslationKey): Shot => ({ name, width: SHOT_WIDTH, height: SHOT_HEIGHT, alt });

export const SHOTS: Record<ShotId, Shot> = {
  home: shot('home', 'site.shot.home.alt'),
  discover: shot('discover', 'site.shot.discover.alt'),
  menu: shot('menu', 'site.shot.menu.alt'),
  clubs: shot('clubs', 'site.shot.clubs.alt'),
  events: shot('events', 'site.shot.events.alt'),
  news: shot('news', 'site.shot.news.alt'),
  profile: shot('profile', 'site.shot.profile.alt'),
  settings: shot('settings', 'site.shot.settings.alt'),
  // Destek / hesap silme ekranları için ayrı görsel yok: Ayarlar ekranı (destek ve gizlilik bağlantıları orada) kullanılır.
  support: shot('settings', 'site.shot.settings.alt'),
  delete: shot('settings', 'site.shot.settings.alt'),
};

/** Görselin adresi: tema başına bir dosya; `ext` webp (varsayılan) ya da png yedek. */
export function shotSrc(s: Shot, theme: ShotTheme, ext: 'webp' | 'png' = 'webp'): string {
  return `${SHOT_DIR}/${s.name}-${theme}.${ext}`;
}
