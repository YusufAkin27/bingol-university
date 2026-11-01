/**
 * Panel kabuğu (üst çubuk ve yan menü) girdileri: her sayfada bulunan araçlar. Sayfa olarak "Genel bakış" altında listelenir
 * (her yönetici görebilir); anchor'lar `layouts/AdminLayout.tsx` içindedir.
 */
import type { SearchEntry } from '../types';

export const entries: SearchEntry[] = [
  {
    id: 'shell.search',
    kind: 'action',
    page: 'dashboard',
    title: 'Panelde ara',
    section: 'Üst çubuk',
    anchor: 'shell-search',
    keywords: ['ara', 'bul', 'arama kutusu', 'ctrl k', 'hızlı git', 'komut paleti'],
    description: 'Sayfa, bölüm, ayar ve düğme adlarını arar; yazım hatası sorun olmaz.',
  },
  {
    id: 'shell.help',
    kind: 'action',
    page: 'dashboard',
    title: 'Yardım ve klavye kısayolları',
    section: 'Üst çubuk',
    anchor: 'shell-help',
    keywords: ['kısayol', 'klavye', 'yardım', 'nasıl kullanılır', 'ipucu', 'tuş', 'g harfi', 'soru işareti'],
    description: 'Hangi tuşun ne yaptığını ve aramanın nasıl kullanılacağını gösterir.',
  },
  {
    id: 'shell.favorite',
    kind: 'action',
    page: 'dashboard',
    title: 'Sayfayı sık kullanılanlara ekle',
    section: 'Üst çubuk',
    anchor: 'shell-favorite',
    keywords: ['yıldız', 'favori', 'sık kullanılan', 'yer imi', 'kısayol ekle', 'sabitle'],
    description: 'Açık sayfayı menünün en üstüne ve aramanın boş ekranına koyar.',
  },
  {
    id: 'shell.sidebar',
    kind: 'action',
    page: 'dashboard',
    title: 'Yan menüyü daralt ya da genişlet',
    section: 'Yan menü',
    anchor: 'shell-sidebar',
    keywords: ['menüyü küçült', 'menüyü gizle', 'simge çubuğu', 'geniş ekran', 'daralt'],
    description: 'Yan menüyü yalnız simgelere indirir; içerik için yer açar.',
  },
  {
    id: 'shell.menuFilter',
    kind: 'field',
    page: 'dashboard',
    title: 'Menüde ara',
    section: 'Yan menü',
    anchor: 'shell-menu-filter',
    keywords: ['menü süzgeci', 'menüde bul', 'sayfa bul'],
    description: 'Yan menüdeki sayfaları ve sayfaların içindeki bölümleri süzer.',
  },
];
