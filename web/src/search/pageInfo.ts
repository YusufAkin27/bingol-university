/**
 * Menü sayfalarının arama açıklamaları ve günlük dil anahtar kelimeleri (menü öğe kimliğine göre).
 * Sayfa başlığı `adminNav.ts` etiketinden gelir; burada yalnız zenginleştirme vardır. Yeni menü sayfası = buraya satır.
 * Kurallar için bkz. README.md ("Anahtar kelime yazım kuralları").
 */
export interface PageInfo {
  /** Tek cümlelik düz Türkçe açıklama. */
  d: string;
  /** Günlük dil + eş anlamlılar + yaygın yazımlar. */
  k: string[];
}

export const pageInfo: Record<string, PageInfo> = {
  dashboard: {
    d: 'Bugünün özeti: kaç kişi girdi, neler bekliyor.',
    k: ['ana sayfa', 'özet', 'durum', 'anasayfa', 'başlangıç', 'dashboard', 'pano'],
  },
  analytics: {
    d: 'Kaç kişi kullanıyor, nasıl büyüyor: grafikler.',
    k: ['istatistik', 'grafik', 'rapor', 'kullanım', 'kaç kişi', 'büyüme', 'ziyaretçi', 'günlük aktif', 'bölüm dağılımı'],
  },
  users: {
    d: 'Üyeleri bul, incele, rolünü değiştir ya da hesabı kapat.',
    k: ['üyeler', 'öğrenci', 'kişi', 'hesap', 'kullanıcı ara', 'rol', 'yönetici yap', 'hesabı sil', 'e-posta ara', 'öğrenci numarası'],
  },
  twoFactor: {
    d: 'İki faktörlü doğrulamayı kimler açmış, kaç güvenilen cihaz var.',
    k: ['iki faktörlü', '2fa', 'doğrulama', 'güvenilen cihaz', 'ek koruma', 'giriş kodu', 'iki adımlı doğrulama'],
  },
  pendingUsers: {
    d: 'E-postasını henüz doğrulamamış kayıtlar.',
    k: ['doğrulama bekleyen', 'onaylanmamış', 'kayıt olmuş ama girmemiş', 'bekleyen kayıt', 'kod gelmedi', 'doğrulama kodu'],
  },
  suspensions: {
    d: 'Sistemin askıya alınmasını önerdiği hesaplar.',
    k: ['hesap dondur', 'askıya al', 'ban önerisi', 'uzaklaştır', 'şüpheli hesap'],
  },
  appeals: {
    d: 'Kısıtlanan kullanıcıların kararı yeniden istemesi.',
    k: ['itiraz', 'şikayet karar', 'kararı geri al', 'yeniden inceleme', 'af'],
  },
  accessBans: {
    d: 'IP, cihaz ya da ağ bazlı erişim yasakları.',
    k: ['ip engelle', 'yasakla', 'ban', 'vpn', 'cihaz engeli', 'erişimi kapat', 'kara liste', 'engellenen ip'],
  },
  reports: {
    d: 'Kullanıcıların bildirdiği uygunsuz içerikler.',
    k: ['şikayetler', 'bildirimler', 'ihbar', 'uygunsuz içerik', 'raporlanan', 'moderasyon kuyruğu'],
  },
  chatFeed: {
    d: 'Sohbetlerdeki görseller ve (yetkiliyse) mesajlar.',
    k: ['mesajlar', 'sohbet', 'dm', 'özel mesaj', 'görseller', 'foto', 'konuşma', 'mesajlaşma'],
  },
  posts: {
    d: 'Keşfet akışındaki fotoğraflı paylaşımları denetle.',
    k: ['paylaşım', 'keşfet', 'fotoğraf', 'resim', 'post', 'akış', 'gizle', 'sil', 'beğeni'],
  },
  polls: {
    d: 'Anket aç, kapat ve sonuçlara bak.',
    k: ['anket', 'oylama', 'oy', 'seçim', 'yemek puanı', 'puanlama', 'sonuçlar'],
  },
  blocklist: {
    d: 'Bu görsellerin yüklenmesi engellenir.',
    k: ['yasaklı resim', 'engelli görsel', 'görsel kara liste', 'hash', 'zararlı resim', 'uygunsuz foto'],
  },
  strikes: {
    d: 'Kullanıcılara verilen uyarı ve ihlal puanları.',
    k: ['uyarı', 'ceza', 'ihlal puanı', 'sicil', 'strike', 'kural ihlali'],
  },
  hiddenContent: {
    d: 'Yöneticilerin gizlediği içerikler; geri açılabilir.',
    k: ['gizlenen', 'kaldırılan içerik', 'gizlenmiş paylaşım', 'geri aç', 'görünmez'],
  },
  reasonTemplates: {
    d: 'Karar verirken seçilen hazır gerekçe metinleri.',
    k: ['hazır metin', 'gerekçe', 'şablon', 'ret sebebi', 'sebep listesi', 'karar sebebi'],
  },
  profanity: {
    d: 'Küfür ve uygunsuz sözcük listesi; yazılınca engellenir.',
    k: ['küfür', 'argo', 'yasaklı kelime', 'kelime filtresi', 'hakaret', 'sansür', 'kötü söz', 'kara liste kelime'],
  },
  communities: {
    d: 'Kulüpleri onayla, düzenle, kapat ya da yönetici ata.',
    k: ['kulüp', 'topluluk', 'öğrenci kulübü', 'kulüp onayı', 'başkan', 'kulüp kapat', 'üyeler'],
  },
  communityCategories: {
    d: 'Kulüplerin hangi başlıklar altında listeleneceği.',
    k: ['kategori', 'kulüp türü', 'kulüp grubu', 'sınıflandırma', 'etiket'],
  },
  clubAudit: {
    d: 'Kulüplerin hareketleri ve değişiklik kayıtları.',
    k: ['kulüp kayıtları', 'kulüp geçmişi', 'kulüp log', 'kulüp değişiklikleri', 'denetim'],
  },
  contentReview: {
    d: 'Kulüplerin gönderdiği içerikler onay bekliyor.',
    k: ['kulüp paylaşımı', 'onay bekleyen', 'içerik onayı', 'inceleme kuyruğu', 'etkinlik onayı'],
  },
  events: {
    d: 'Etkinlikleri incele, öne çıkar, düzenle ya da iptal et.',
    k: ['etkinlik', 'program', 'yoklama', 'katılımcı', 'öne çıkan', 'iptal et', 'qr', 'sertifika', 'konser', 'seminer'],
  },
  eventApplications: {
    d: 'Etkinliğe katılmak isteyenlerin başvuruları.',
    k: ['başvuru', 'katılım isteği', 'kayıt olanlar', 'başvuranlar', 'kabul et', 'reddet'],
  },
  acdCalendar: {
    d: 'Dönem başlangıç, tatil ve sınav haftası tarihleri.',
    k: ['takvim', 'tatil', 'dönem', 'ders kaydı', 'bayram', 'final haftası', 'güz', 'bahar'],
  },
  acdExams: {
    d: 'Vize, final ve bütünleme sınav tarihleri.',
    k: ['sınav', 'vize', 'final', 'bütünleme', 'sınav tarihi', 'sınav günü', 'exam'],
  },
  acdAnnouncements: {
    d: 'Fakülte ve bölümlere özel duyuru gönder.',
    k: ['duyuru', 'bölüm duyurusu', 'fakülte duyurusu', 'toplu duyuru', 'öğrencilere haber ver'],
  },
  tickets: {
    d: 'Kullanıcıların yazdığı yardım istekleri ve yanıtlar.',
    k: ['destek', 'yardım', 'talep', 'sorun bildirimi', 'şikayet yanıtla', 'cevap yaz', 'ticket', 'iletişim formu'],
  },
  feedback: {
    d: 'Uygulama hakkında gelen görüş, öneri ve hata bildirimleri.',
    k: ['öneri', 'geri bildirim', 'görüş', 'fikir', 'hata bildirimi', 'memnuniyet', 'yorum'],
  },
  legal: {
    d: 'Kullanım şartları, gizlilik ve KVKK metinleri.',
    k: ['sözleşme', 'gizlilik', 'kvkk', 'kullanım şartları', 'aydınlatma metni', 'yasal metin', 'şartlar', 'politika', 'onay'],
  },
  faq: {
    d: 'Kullanıcıların sık sorduğu soruların yanıtları.',
    k: ['sss', 'soru cevap', 'yardım metni', 'sıkça sorulan', 'faq'],
  },
  news: {
    d: 'Üniversite sitesinden gelen haber ve duyurular.',
    k: ['haber', 'duyuru', 'haberi gizle', 'üniversite haberleri', 'etkinlik haberi', 'manşet'],
  },
  unitNews: {
    d: 'Fakülte, enstitü ve MYO sitelerinden gelen bölüm duyuruları ve kaynakları.',
    k: ['birim haberleri', 'bölüm duyuruları', 'fakülte', 'duyuru', 'alt siteler', 'meslek yüksekokulu', 'enstitü', 'fakülte duyurusu', 'duyuru gizle'],
  },
  menu: {
    d: 'Günlük yemek listesi ve yemeklerin kalorisi.',
    k: ['yemekhane', 'öğle yemeği', 'akşam yemeği', 'kalori', 'günün menüsü', 'yemek listesi', 'kantin', 'sks'],
  },
  campaigns: {
    d: 'Telefona bildirim (push) gönder ya da zamanla.',
    k: ['push', 'bildirim gönder', 'toplu bildirim', 'duyuru gönder', 'telefon bildirimi', 'kampanya', 'zamanlı gönderim'],
  },
  mailTemplates: {
    d: 'Sistemin gönderdiği e-postaların metinleri.',
    k: ['e-posta şablonu', 'mail metni', 'mail tasarımı', 'otomatik mail', 'şablon', 'doğrulama maili'],
  },
  mailCampaigns: {
    d: 'Kullanıcılara toplu e-posta gönder.',
    k: ['toplu mail', 'e-posta gönder', 'mail at', 'bülten', 'mail duyurusu', 'e-bülten'],
  },
  mailQueue: {
    d: 'Gönderilmeyi bekleyen ve gönderilemeyen e-postalar.',
    k: ['mail sırası', 'gitmeyen mail', 'başarısız mail', 'e-posta kuyruğu', 'tekrar dene', 'smtp', 'ölü mektup'],
  },
  mailSuppressions: {
    d: 'E-posta gönderilmeyecek adresler (geri dönenler, şikayet edenler).',
    k: ['bastırma', 'mail engeli', 'geri dönen mail', 'bounce', 'abonelikten çık', 'engelli adres', 'spam'],
  },
  pushOps: {
    d: 'Bildirim kuyruğu ve cihaz kayıtlarının durumu.',
    k: ['push kuyruğu', 'bildirim gitmiyor', 'fcm', 'firebase', 'cihaz token', 'apns', 'bildirim hatası', 'ölü bildirim'],
  },
  system: {
    d: 'Sunucu sağlıklı mı? Kuyruklar, veritabanı, disk.',
    k: ['sağlık', 'sunucu durumu', 'uptime', 'disk', 'veritabanı', 'redis', 'yedek', 'alarm', 'çalışıyor mu', 'izleme'],
  },
  sources: {
    d: 'Haber ve yemek sitelerinden veri çekimi son ne zaman çalıştı?',
    k: ['scraper', 'veri çekme', 'senkron', 'kaynak site', 'haber çekimi', 'bakımda', 'yemek çekimi'],
  },
  ops: {
    d: 'Elle tetiklenen bakım işleri ve zamanlayıcılar.',
    k: ['zamanlayıcı', 'cron', 'görev', 'job', 'elle çalıştır', 'senkronizasyonu başlat', 'önbellek temizle', 'cache'],
  },
  crashes: {
    d: 'Mobil uygulamanın çökme kayıtları, sürüme göre.',
    k: ['hata', 'crash', 'çöktü', 'uygulama kapanıyor', 'hata raporu', 'exception', 'sürüm hatası'],
  },
  backup: {
    d: 'Veritabanı yedekleri ve Google Drive kopyası: durum ve kurulum rehberi.',
    k: ['yedekleme', 'drive', 'yedek', 'geri yükleme', 'rclone', 'google drive', 'yedek al', 'felaket kurtarma'],
  },
  dataRetention: {
    d: 'Şişen kayıt tablolarını yedekleyip temizle.',
    k: ['veri silme', 'temizlik', 'disk doldu', 'log temizle', 'arşivle', 'dışa aktar', 'saklama süresi', 'depolama', 'kayıt temizliği'],
  },
  appVersions: {
    d: 'Hangi sürüm kaç cihazda? Eski sürümü zorla güncelletme.',
    k: ['sürüm', 'güncelleme', 'zorunlu güncelleme', 'zorla güncelle', 'mağaza', 'android', 'ios', 'versiyon', 'eski sürüm', 'en düşük sürüm'],
  },
  settings: {
    d: 'Uygulamanın genel ayarları: ad, iletişim, bakım modu, duyuru bandı.',
    k: ['ayar', 'genel ayarlar', 'yapılandırma', 'konfigürasyon', 'tercihler', 'bakım modu', 'duyuru bandı', 'fakülteler'],
  },
  roles: {
    d: 'Hangi yöneticinin ne yapabileceği (yetki profilleri).',
    k: ['yetki', 'izin', 'rol', 'yönetici yetkisi', 'rbac', 'moderatör', 'editör', 'izleyici', 'yetki ver', 'yetki al'],
  },
  audit: {
    d: 'Yöneticilerin yaptığı her işlemin kaydı.',
    k: ['log', 'kayıt', 'işlem geçmişi', 'kim yaptı', 'ne zaman', 'değişiklik geçmişi', 'denetim izi', 'aktivite'],
  },
  messageAccess: {
    d: 'Bir yöneticinin özel mesajlara ne zaman baktığının kaydı.',
    k: ['mesaj okuma kaydı', 'mesaja bakan', 'gizlilik denetimi', 'erişim logu', 'kim mesaj okudu', 'kvkk denetimi'],
  },
  crypto: {
    d: 'Mesajların şifrelenme durumu ve anahtar bilgisi.',
    k: ['şifreleme', 'anahtar', 'şifre döndür', 'encrypt', 'mesaj şifresi', 'güvenlik', 'master key'],
  },
};
