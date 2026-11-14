import type { SearchEntry } from '../types';

/**
 * Arama girdileri: Akademisyenler (academicians). Menü sayfasının kendisi otomatik üretilir.
 * Akademisyen ayrıntısı `/admin/academicians/:id` kimlik ister; arama oraya doğrudan gidemez, bu yüzden ayrıntı girdileri
 * listeyi açar (anchor yok) ve açıklamada "bir akademisyen açın" der.
 */
export const entries: SearchEntry[] = [
  {
    id: 'academicians.tabs',
    kind: 'section',
    page: 'academicians',
    title: 'Akademisyen başvuru sekmeleri (bekleyen, onaylı, otomatik, reddedilen)',
    anchor: 'acad-tabs',
    keywords: ['akademisyen başvurusu', 'öğretim elemanı', 'hoca', 'bekleyen başvuru', 'onaylı akademisyen', 'reddedilen'],
    description: 'Akademisyen başvurularını duruma göre listeler.',
  },
  {
    id: 'academicians.auto',
    kind: 'section',
    page: 'academicians',
    title: 'Otomatik onaylanan akademisyenler',
    anchor: 'acad-auto',
    keywords: ['kuralla onaylanan', 'denetle', 'kurumsal e-posta', 'insan bakmadan onaylanan', 'şüpheli akademisyen'],
    description: 'Kurala göre kendiliğinden onaylananlar; e-posta biçimine ve tarihe bakıp onayı geri alabilirsiniz.',
  },
  {
    id: 'academicians.list',
    kind: 'section',
    page: 'academicians',
    title: 'Akademisyen listesi',
    anchor: 'acad-list',
    keywords: ['onayla', 'reddet', 'onayı geri al', 'yetkiyi kaldır', 'başvuru kuyruğu', 'gerekçe'],
    description: 'Ad, birim, e-posta, durum, onay biçimi, başvuru tarihi ve kararı veren; satırdan onay, ret ve geri alma.',
  },
  {
    id: 'academicians.filter',
    kind: 'field',
    page: 'academicians',
    title: 'Akademisyen ara (yüklenen kayıtlarda)',
    anchor: 'acad-filter',
    keywords: ['hoca bul', 'ad ile ara', 'e-posta ile ara', 'birim ara'],
    description: 'Ekrana yüklenmiş akademisyenleri ad, e-posta veya birime göre süzer.',
  },
  {
    id: 'academicians.courses',
    kind: 'section',
    page: 'academicians',
    title: 'Akademisyenin dersleri ve yoklaması (salt okunur)',
    keywords: ['ders programı', 'kayıtlı öğrenci', 'yoklama matrisi', 'devamsızlık', 'duyurular', 'ders oturumları', 'ekli dosya indir'],
    description: 'Bir akademisyen açın: dersleri, haftalık program, öğrenciler, yoklama, duyurular ve oturumlar.',
  },
  {
    id: 'academicians.history',
    kind: 'section',
    page: 'academicians',
    title: 'Akademisyen başvuru geçmişi',
    keywords: ['kim onayladı', 'ret gerekçesi', 'karar tarihi', 'denetim kaydı'],
    description: 'Bir akademisyen açın: kararı kimin, ne zaman, hangi gerekçeyle verdiği.',
  },
];
