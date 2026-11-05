// Tanıtım sitesi: yeni özellikler (etkinlik başvurusu, kulüp yetkileri, görsel paylaşımı, gizlilik, şifreleme) ve yönetici erişim bildirimi (T17).
const m = {
  'site.feat.admission.title': 'Etkinlik başvurusu ve kabul',
  'site.feat.admission.text':
    'Etkinliği düzenleyen kişi başvuru isteyebilir; başvurular kabul, ret veya bekleme listesi ile yanıtlanır. Kontenjan dolunca sıradaki kişiye bildirim gider.',
  'site.feat.clubroles.title': 'Kulüp yetkileri',
  'site.feat.clubroles.text':
    'Kulüp sahibi, yönetim ekibine ayrıntılı yetkiler verir; sahiplik devri ve davet kodu ile kulüp yönetimi düzenli kalır. Önemli işlemler kayıt altına alınır.',
  'site.feat.media.title': 'Sohbette görsel paylaşımı',
  'site.feat.media.text':
    'Sohbetlerde görsel gönderin. Uygunsuz görselleri bildirebilir, kullanıcıyı engelleyebilirsiniz; yasaklı görseller yüklenirken otomatik reddedilir.',
  'site.feat.privacysettings.title': 'Gizlilik ayarları',
  'site.feat.privacysettings.text':
    'Profilinizde nelerin kimlere görüneceğini siz seçersiniz. E-posta adresiniz ve diğer bilgileriniz için görünürlüğü istediğiniz zaman değiştirebilirsiniz.',
  'site.feat.secure.title': 'Şifreli iletim ve saklama',
  'site.feat.secure.text':
    'Mesajlarınız iletim sırasında şifrelenir ve sunucuda şifreli olarak saklanır. Anahtarları sunucu yönetir; yetkili yöneticiler gerektiğinde mesajları görüntüleyebilir ve her erişim değiştirilemez denetim kaydına yazılır.',
  'site.home.privacy4': 'Mesajlar şifreli iletilir ve şifreli saklanır; yönetici erişimi denetim kaydına yazılır. Silinen mesajlar güvenlik ve yasal yükümlülükler için saklanabilir.',

  'site.faq.new.title': 'Yeni özellikler hakkında',
  'site.faq.new.apply.q': 'Etkinliğe nasıl başvururum?',
  'site.faq.new.apply.a':
    'Başvuru gerektiren bir etkinliğin sayfasında “Başvur” düğmesine dokunun. Düzenleyen kişi başvurunuzu kabul eder, reddeder veya bekleme listesine alır; sonuç bildirim olarak gelir. Kontenjan doluysa bekleme listesindeki sıranızı görürsünüz.',
  'site.faq.new.clubRoles.q': 'Kulüp yetkileri nasıl çalışır?',
  'site.faq.new.clubRoles.a':
    'Kulüp sahibi, üyelere tek tek yetki verebilir (örneğin üye onaylama veya duyuru yayımlama). Sahiplik, karşı tarafın onayıyla devredilebilir. Yetki değişiklikleri ve üye kararları kulüp denetim kaydında tutulur.',
  'site.faq.new.images.q': 'Sohbette görsel gönderebilir miyim?',
  'site.faq.new.images.a':
    'Evet. Görseller yüklenirken tür ve boyut denetimi yapılır. Uygunsuz bir görseli bildirebilir ve göndereni engelleyebilirsiniz. Bildirilen içerikler moderatörlerce incelenir.',
  'site.faq.new.privacy.q': 'Bilgilerimin kimlere görüneceğini seçebilir miyim?',
  'site.faq.new.privacy.a':
    'Evet. Profil ve gizlilik ayarlarından e-posta adresiniz gibi bilgilerin görünürlüğünü değiştirebilirsiniz. Ayar değişikliği hemen geçerli olur.',
  'site.faq.new.encryption.q': 'Mesajlarım nasıl korunuyor?',
  'site.faq.new.encryption.a':
    'Mesajlar iletim sırasında şifrelenir ve sunucuda şifreli olarak saklanır. Anahtarlar mesaj içeriğinden ayrı yönetilir.',
  'site.faq.new.adminAccess.q': 'Yöneticiler mesajlarımı okuyabilir mi?',
  'site.faq.new.adminAccess.a':
    'Evet, yetkili yöneticiler güvenlik, şikâyet incelemesi ve yasal yükümlülükler için mesajları görüntüleyebilir. Bu erişimin her sayfası değiştirilemez bir denetim kaydına yazılır. Anahtarları sunucu yönettiğinden mesajlar yalnızca iki tarafın çözebileceği bir korumaya sahip değildir. Sildiğiniz mesajlar size görünmez olur ancak güvenlik ve yasal yükümlülükler için saklanabilir.',

  'site.faq.gen.title': 'Uygulama hakkında sık sorulanlar',

  'site.faq.gen.independent.q': 'BÜ Kampüs Bingöl Üniversitesi’nin resmî uygulaması mı?',
  'site.faq.gen.independent.a':
    'Hayır. BÜ Kampüs, Bingöl Üniversitesi öğrencileri ve personeli için geliştirilen bağımsız bir uygulamadır; üniversitenin resmî uygulaması değildir. Amacı ve işleyişi için [Hakkımızda](/about) sayfasına bakın.',
  'site.faq.gen.who.q': 'Uygulamaya kimler kayıt olabilir?',
  'site.faq.gen.who.a':
    'Yalnızca bingol.edu.tr uzantılı üniversite e-posta adresi olanlar kayıt olabilir. Kayıt sırasında sözleşmeleri kabul eder ve adresinize gelen doğrulama kodunu girersiniz. Adımlar [indirme sayfasında](/download) anlatılır.',
  'site.faq.gen.noCode.q': 'Doğrulama kodu e-postama gelmiyor, ne yapmalıyım?',
  'site.faq.gen.noCode.a':
    'Önce gereksiz (spam) klasörüne bakın ve adresi bingol.edu.tr ile doğru yazdığınızdan emin olun. Kod 10 dakika geçerlidir; süre dolduysa uygulamadan yeni kod isteyin. Sorun sürerse [iletişim sayfasından](/contact) bize yazın.',
  'site.faq.gen.free.q': 'BÜ Kampüs ücretsiz mi?',
  'site.faq.gen.free.a':
    'Evet, BÜ Kampüs ücretsizdir. Kayıt için tek koşul bingol.edu.tr uzantılı e-posta adresidir.',
  'site.faq.gen.platforms.q': 'BÜ Kampüs hangi telefonlarda çalışır, nereden indirebilirim?',
  'site.faq.gen.platforms.a':
    'Uygulama Android ve iPhone için hazırlanıyor. Mağaza bağlantıları yayınlandığında [indirme sayfasında](/download) etkinleşir; yayınlanmamış olanların düğmesinde “Yakında” yazar.',
  'site.faq.gen.menuSource.q': 'Yemek listesi nereden geliyor, ne zaman güncellenir?',
  'site.faq.gen.menuSource.a':
    'Liste, üniversite yemekhanesinin (SKS) yayımladığı aylık listeden alınır ve ayda bir güncellenir. Uygulama bağımsızdır; bir fark olursa resmî liste esastır. Güncel menü için [yemek listesi sayfasına](/menu) bakın.',
  'site.faq.gen.calorie.q': 'Yemek kalorileri nasıl hesaplanıyor?',
  'site.faq.gen.calorie.a':
    'Kalori değerlerini yönetici yemek başına girer; üniversitenin listesinden gelmez. Girilen kalori yemek adına kaydedilir, aynı yemek sonraki günlerde otomatik dolar. Kalorisi girilmemiş yemekte değer gösterilmez, günün toplamı bu yüzden eksik olabilir.',
  'site.faq.gen.newsSource.q': 'Haber ve duyurular nereden geliyor, gecikme olur mu?',
  'site.faq.gen.newsSource.a':
    'Bingöl Üniversitesi’nin sitesinde yayımlanan haber, duyuru ve etkinlikler her gece bir kez uygulamaya alınır; bu yüzden yeni bir içerik ertesi güne kadar görünmeyebilir. Her haberde resmî kaynak sayfaya bağlantı bulunur. Tümü [haberler sayfasında](/news) listelenir.',
  'site.faq.gen.academic.q': 'Ders programı ve sınav takvimi uygulamada var mı?',
  'site.faq.gen.academic.a':
    'Evet, ders programı, sınav takvimi ve akademik takvim hatırlatmalarla birlikte uygulamada yer alır. Bir çelişki olursa üniversitenin resmî duyurusu esastır. Tüm özellikler için [özellikler sayfasına](/features) bakın.',
  'site.faq.gen.qr.q': 'Etkinliklerde QR yoklama nasıl çalışır?',
  'site.faq.gen.qr.a':
    'Etkinliklerde yoklama QR kodla ya da etkinliği düzenleyen kişi tarafından elle alınır. Kulüp etkinliklerini takvimden görür ve uygulamadan kaydolursunuz.',
  'site.faq.gen.polls.q': 'Anketlerde verdiğim oy gizli mi?',
  'site.faq.gen.polls.a':
    'Evet. Oylar gizlidir: kimin ne oy verdiği kimseye gösterilmez. Kulüp ve kampüs anketlerine uygulamadan katılırsınız.',
  'site.faq.gen.dataSold.q': 'Verilerim satılıyor mu?',
  'site.faq.gen.dataSold.a':
    'Hayır. Verileriniz satılmaz; yalnızca hizmet için gereken veri işlenir ve kullanım istatistikleri toplulaştırılır. Ayrıntılar [gizlilik politikasında](/privacy) yer alır.',
  'site.faq.gen.export.q': 'Kişisel verilerimi indirebilir miyim?',
  'site.faq.gen.export.a':
    'Evet. Uygulamada Profil > Verilerimi indir bölümünden hesabınıza ait verileri bir dosya olarak alabilirsiniz. Diğer KVKK talepleriniz için [veri talebi sayfasına](/data-request) bakın.',
  'site.faq.gen.delete.q': 'Hesabımı nasıl silerim?',
  'site.faq.gen.delete.a':
    'Hesabınızı uygulamadaki hesap ayarlarından kendiniz silebilirsiniz. Silme, kişisel verilerinizi anonimleştirir ve geri alınamaz. Adımlar ve silinen veriler için [hesap silme sayfasına](/delete-account) bakın.',
  'site.faq.gen.support.q': 'Sorun yaşarsam veya öneri iletmek istersem nereye yazarım?',
  'site.faq.gen.support.a':
    'Uygulamadaki Destek bölümünden talep oluşturabilir ve durumunu aynı yerden izleyebilirsiniz. Hesabınız yoksa [iletişim sayfasındaki](/contact) formu kullanabilirsiniz.',

  'site.links.features.label': 'İlgili sayfalar',
  'site.links.features.text':
    'Özellikleri denemeden önce günün yemek listesine bakabilir, hazır olduğunuzda uygulamayı indirebilirsiniz.',
  'site.links.features.menu': 'Bugünün yemek listesi ve kalori bilgisi',
  'site.links.features.download': 'BÜ Kampüs’ü indirme sayfası',
  'site.links.news.label': 'İlgili sayfalar',
  'site.links.news.text':
    'Haberlerin yanında günün menüsüne bakabilir, duyuruları uygulamada takip edebilirsiniz.',
  'site.links.news.menu': 'Bingöl Üniversitesi yemek listesi',
  'site.links.news.download': 'Duyuruları uygulamada takip etmek için indirme sayfası',
  'site.links.about.label': 'İlgili sayfalar',
  'site.links.about.text':
    'Sorularınız ve önerileriniz için bize yazabilir, en sık sorulan soruların yanıtlarına göz atabilirsiniz.',
  'site.links.about.contact': 'İletişim sayfasından bize ulaşın',
  'site.links.about.faq': 'Sık sorulan sorulara göz atın',

  'pg.menu.about.title': 'Kalori ve veriler nereden geliyor?',
  'pg.menu.about.text':
    'Yemek listesi, üniversite yemekhanesinin (SKS) yayımladığı aylık listeden alınır; BÜ Kampüs bağımsız bir uygulamadır ve bir fark olursa resmî liste esastır. Kalori değerlerini yönetici yemek başına girer; girilen kalori yemek adına kaydedildiği için aynı yemek sonraki günlerde otomatik dolar. Kalorisi girilmemiş yemekte değer gösterilmez.',
  'pg.menu.about.faq': 'Kalori nasıl hesaplanır? Sık sorulan sorulardaki yanıtı okuyun',
  'pg.menu.about.news': 'Bingöl Üniversitesi haber ve duyuruları',

  'legal.adminAccess.title': 'Yönetici erişimi ve silinen mesajların saklanması',
  'legal.adminAccess.body1':
    'Mesajlar iletim sırasında şifrelenir ve sunucuda şifreli saklanır. Anahtarları sunucu yönetir; bu nedenle mesajlar yalnızca sizin cihazınızda çözülebilen bir korumaya sahip değildir.',
  'legal.adminAccess.body2':
    'Yetkili yöneticiler güvenlik, şikâyet incelemesi veya yasal yükümlülük kapsamında kullanıcıların konuşmalarını görüntüleyebilir; yönetici erişimi kayıt altındadır ve her erişim değiştirilemez bir denetim kaydına yazılır. Sildiğiniz veya düzenlediğiniz mesajlar size görünmez olur ancak önceki sürümleriyle birlikte güvenlik ve yasal yükümlülükler için sınırlı bir süre veya süresiz saklanabilir.',
} as const;
export default m;
