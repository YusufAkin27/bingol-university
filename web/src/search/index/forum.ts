import type { SearchEntry } from '../types';

/**
 * Arama girdileri: Forum grubu (forumReports, forumTopics, forumActions, forumCategories).
 * Menü sayfalarının kendisi (`page`) otomatik üretilir; burada tekrar yazmayın.
 */
export const entries: SearchEntry[] = [
  // ---- Forum şikâyetleri ----
  {
    id: 'forumReports.list',
    kind: 'section',
    page: 'forumReports',
    title: 'Forum şikâyet listesi',
    anchor: 'freport-list',
    keywords: ['açık şikâyetler', 'kaldır', 'yoksay', 'geri al', 'sabitle', 'kilitle', 'gerekçe', 'anonim yazar'],
    description: 'Konu ve yorum şikâyetleri; içerik önizlemesi, şikâyet nedenleri ve moderatör eylemleri.',
  },
  {
    id: 'forumReports.filters',
    kind: 'field',
    page: 'forumReports',
    title: 'Şikâyet süzgeçleri',
    anchor: 'freport-filters',
    keywords: ['durum', 'tür', 'neden', 'spam', 'hakaret', 'taciz', 'kişisel bilgi', 'konu mu yorum mu'],
    description: 'Şikâyetleri duruma, türe (konu/yorum) ve nedene göre daraltır.',
  },
  // ---- Forum konuları ----
  {
    id: 'forumTopics.list',
    kind: 'section',
    page: 'forumTopics',
    title: 'Forum konu listesi',
    anchor: 'ftopic-list',
    keywords: ['konular', 'sabit konu', 'kilitli konu', 'kaldırılmış konu', 'ayrıntı', 'moderatör eylemi'],
    description: 'Tüm konular; satırdan sabitle, yorumlara kapat, kaldır ya da geri al.',
  },
  {
    id: 'forumTopics.filters',
    kind: 'field',
    page: 'forumTopics',
    title: 'Konu arama ve süzgeçleri',
    anchor: 'ftopic-filters',
    keywords: ['başlık ara', 'içerik ara', 'kategori', 'durum', 'yayında', 'kaldırıldı'],
    description: 'Konuları başlığa/içeriğe, duruma ve kategoriye göre bulur.',
  },
  // ---- Forum işlem kayıtları ----
  {
    id: 'forumActions.list',
    kind: 'section',
    page: 'forumActions',
    title: 'Forum işlem kayıtları listesi',
    anchor: 'faction-list',
    keywords: ['kim kaldırdı', 'gerekçe', 'moderatör', 'kayıt', 'tarih', 'hedef'],
    description: 'Her moderatör eylemi: kim, ne zaman, hangi içerik ve hangi gerekçeyle.',
  },
  {
    id: 'forumActions.filters',
    kind: 'field',
    page: 'forumActions',
    title: 'İşlem kaydı süzgeçleri',
    anchor: 'faction-filters',
    keywords: ['eylem türü', 'konu', 'yorum', 'sabitleme', 'kilitleme', 'kaldırma'],
    description: 'Kayıtları eyleme ve hedef türüne göre daraltır.',
  },
  // ---- Forum kategorileri ----
  {
    id: 'forumCategories.add',
    kind: 'action',
    page: 'forumCategories',
    title: 'Forum kategorisi ekle',
    anchor: 'fcat-add',
    keywords: ['yeni kategori', 'kategori oluştur', 'üç dilli ad', 'türkçe ingilizce arapça'],
    description: 'Foruma yeni bir kategori ekler (Türkçe, İngilizce ve Arapça ad).',
  },
  {
    id: 'forumCategories.list',
    kind: 'section',
    page: 'forumCategories',
    title: 'Forum kategori listesi',
    anchor: 'fcat-list',
    keywords: ['sırala', 'yukarı taşı', 'aşağı taşı', 'arşivle', 'arşivden çıkar', 'konu sayısı'],
    description: 'Kategorileri sıralar, düzenler, arşivler ya da arşivden çıkarır.',
  },
  {
    id: 'forumCategories.names',
    kind: 'field',
    page: 'forumCategories',
    title: 'Kategori adları (tr, en, ar)',
    anchor: 'fcat-names',
    keywords: ['kategori adı', 'çeviri', 'türkçe ad', 'arapça ad', 'slug', 'kısa ad'],
    description: 'Kategorinin üç dildeki adı ve kısa adı.',
  },
];
