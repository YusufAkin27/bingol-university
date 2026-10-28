// Yemek menüsü fotoğraf yönetimi (/admin/content/menu).
const m = {
  'admin.nav.menu': 'Yemek menüsü',

  'admin.menu.title': 'Yemek menüsü',
  'admin.menu.subtitle': 'Günün menüsüne isteğe bağlı fotoğraf ekleyin, değiştirin veya kaldırın. Fotoğraf uygulamada menünün yanında görünür.',
  'admin.menu.filters': 'Menü süzgeçleri',
  'admin.menu.month': 'Ay',
  'admin.menu.hint': 'JPEG, PNG veya WebP; en fazla 5 MB.',
  'admin.menu.pickMonth': 'Geçerli bir ay seçin',
  'admin.menu.empty': 'Bu ay için menü yok',
  'admin.menu.noItems': 'Menü kalemi yok',
  'admin.menu.noImage': 'Fotoğraf yok',
  'admin.menu.imageAlt': '{date} menü fotoğrafı',
  'admin.menu.fileInput': '{date} için fotoğraf seç',
  'admin.menu.add': 'Fotoğraf ekle',
  'admin.menu.replace': 'Değiştir',
  'admin.menu.remove': 'Kaldır',
  'admin.menu.uploading': 'Yükleniyor…',
  'admin.menu.uploaded': 'Fotoğraf kaydedildi',
  'admin.menu.removed': 'Fotoğraf kaldırıldı',
  'admin.menu.removeTitle': 'Fotoğraf kaldırılsın mı?',
  'admin.menu.removeMsg': '{date} günü menü fotoğrafı kaldırılacak.',
  'admin.menu.err.type': 'Yalnızca JPEG, PNG veya WebP yüklenebilir.',
  'admin.menu.err.size': 'Dosya en fazla 5 MB olabilir.',
  'admin.menu.err.empty': 'Dosya boş.',
  'admin.err.MENU_DAY_NOT_FOUND': 'Bu güne ait menü bulunamadı.',
} as const;

export default m;
