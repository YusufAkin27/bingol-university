// Tanıtım sitesindeki telefon ekran görüntüleri (uygulamanın kendi ekran çıktıları, RENK-1 paleti, Türkçe).
// Kaynak: C:\bu_qa\shots\tasarim\... (birebir çıktılar). Kişi adı içerenler (Ana Sayfa karşılaması, Keşfet gönderi sahipleri,
// Sohbet başlığı) temizlenmiş, 600 px genişlikte WebP'ye çevrilmiştir (her biri <= 45 KB). Ayrıntı: ../README.md
import type { TranslationKey } from '../../../i18n';
import academic from '../../../assets/site/app-academic.webp';
import chat from '../../../assets/site/app-chat.webp';
import deleteAccount from '../../../assets/site/app-delete.webp';
import clubs from '../../../assets/site/app-clubs.webp';
import discover from '../../../assets/site/app-discover.webp';
import events from '../../../assets/site/app-events.webp';
import home from '../../../assets/site/app-home.webp';
import menu from '../../../assets/site/app-menu.webp';
import poll from '../../../assets/site/app-poll.webp';
import qr from '../../../assets/site/app-qr.webp';
import support from '../../../assets/site/app-support.webp';

export type ShotId = 'home' | 'discover' | 'chat' | 'clubs' | 'events' | 'qr' | 'menu' | 'poll' | 'academic' | 'delete' | 'support';

export interface Shot {
  src: string;
  /** Görselin doğal boyutu: <img width/height> olarak yazılır, yerleşim kayması (CLS) olmaz. */
  width: number;
  height: number;
  /** Altı boş ekranlar kırpılmıştır: telefon "peek" (alttan solarak kaybolan) çizilir. */
  peek: boolean;
  alt: TranslationKey;
}

export const SHOTS: Record<ShotId, Shot> = {
  home: { src: home, width: 600, height: 1298, peek: false, alt: 'site.shot.home.alt' },
  discover: { src: discover, width: 600, height: 1298, peek: false, alt: 'site.shot.discover.alt' },
  chat: { src: chat, width: 600, height: 1298, peek: false, alt: 'site.shot.chat.alt' },
  clubs: { src: clubs, width: 600, height: 1298, peek: false, alt: 'site.shot.clubs.alt' },
  events: { src: events, width: 600, height: 1298, peek: false, alt: 'site.shot.events.alt' },
  qr: { src: qr, width: 600, height: 940, peek: true, alt: 'site.shot.qr.alt' },
  menu: { src: menu, width: 600, height: 900, peek: true, alt: 'site.shot.menu.alt' },
  poll: { src: poll, width: 600, height: 920, peek: true, alt: 'site.shot.poll.alt' },
  support: { src: support, width: 600, height: 1298, peek: false, alt: 'site.shot.support.alt' },
  academic: { src: academic, width: 600, height: 860, peek: true, alt: 'site.shot.academic.alt' },
  delete: { src: deleteAccount, width: 600, height: 1298, peek: false, alt: 'site.shot.delete.alt' },
};
