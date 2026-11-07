import type { SearchEntry } from '../types';

/**
 * Arama girdileri (SİSTEM2): Ayarlar, Uygulama güncelleme, Roller ve izinler, Denetim kaydı sayfalarının yeni bölümleri.
 * Bu sayfaların ilk girdileri `system.ts` ve `notifsysPages.ts` içindedir; burada yalnızca sonradan eklenen
 * bölümler (ayar arama kutusu, son değişiklikler, ısı haritası, zaman çizelgesi, hızlı süzgeçler, sürüm grafiği) bulunur.
 */
export const entries: SearchEntry[] = [
  // ---- Ayarlar ----
  {
    id: 'settings.search-box',
    kind: 'field',
    page: 'settings',
    title: 'Ayarlarda ara',
    anchor: 'settings-search',
    keywords: ['ayar bul', 'hangi ayar', 'ayar ara', 'ayar arama kutusu', 'bakım ayarı nerede'],
    description: 'Tüm ayarları adıyla ya da günlük sözcüklerle ara; sonuçta değeri görürsün.',
  },
  {
    id: 'settings.recent-changes',
    kind: 'section',
    page: 'settings',
    title: 'Son ayar değişiklikleri',
    anchor: 'settings-recent',
    keywords: ['ayarı kim değiştirdi', 'ayar geçmişi', 'son değişiklik', 'ayar kayıtları', 'kim kapattı'],
    description: 'En son değiştirilen ayarlar: kim, ne zaman, hangi sebeple.',
    perm: 'audit.read',
  },

  // ---- Roller ve izinler ----
  {
    id: 'roles.heatmap',
    kind: 'section',
    page: 'roles',
    title: 'Kim neye yetkili? (ısı haritası)',
    anchor: 'roles-heatmap',
    keywords: ['isi haritasi', 'yetki özeti', 'hangi profil ne yapabilir', 'yetki karşılaştırma', 'izin özeti', 'moderatör neye yetkili'],
    description: 'Her yönetici profilinin hangi alanlarda ne kadar yetkili olduğu renklerle.',
  },

  // ---- Denetim kaydı ----
  {
    id: 'audit.summary',
    kind: 'section',
    page: 'audit',
    title: 'Özet grafikler (ne zaman, ne tür, hangi alan)',
    anchor: 'audit-summary',
    keywords: [
      'işlem grafiği',
      'en yoğun saat',
      'eylem türü dağılımı',
      'ekleme silme değiştirme',
      'en çok işlem yapılan alan',
      'denetim özeti',
      'yönetici hareketleri',
    ],
    description: 'Son işlemlerin zamana, eylem türüne ve alana göre dağılımı.',
  },
  {
    id: 'audit.quick-filters',
    kind: 'field',
    page: 'audit',
    title: 'Hızlı süzgeçler (Bugün, Reddedilenler, Silmeler)',
    anchor: 'quick-filters',
    keywords: ['bugünkü işlemler', 'son 7 gün', 'reddedilen işlemler', 'yetkisiz denemeler', 'sunucu hataları', 'silme işlemleri', 'süzgeç çipi'],
    description: 'Tek dokunuşla en sık kullanılan süzgeçleri aç; etkin süzgeçleri çipten kaldır.',
  },
  {
    id: 'audit.view-toggle',
    kind: 'action',
    page: 'audit',
    title: 'Zaman çizelgesi görünümü',
    anchor: 'view-toggle',
    keywords: ['işlemler gün gün', 'zaman çizelgesi', 'tablo görünümü', 'olay akışı', 'kronoloji'],
    description: 'İşlemleri tablo yerine gün gün akış olarak göster.',
  },

  // ---- Uygulama güncelleme ----
  {
    id: 'appVersions.versions-chart',
    kind: 'section',
    page: 'appVersions',
    title: 'Sürüme göre cihaz dağılımı',
    anchor: 'platform-android',
    keywords: ['kaç kişi güncel', 'eski sürüm kullanan', 'sürüm grafiği', 'güncel sürüm oranı', 'hangi sürümü kullanıyor'],
    description: 'Her sürümü kaç cihazın kullandığını çubuklarla gör.',
  },
];
