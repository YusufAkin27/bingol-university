// Tanıtım sitesi: standart site sayfaları (çerez, hesap silme, erişilebilirlik, güvenlik, topluluk kuralları, yardım,
// haberler, yemek listesi, marka kiti, sürüm notları, site haritası), üst menü/alt bilgi ve hata ekranları.
// Bölüm tabanlı sayfalar için anahtar kalıbı: pg.<sayfa>.<bölüm>.h | .p1.. | .l1.. (madde) | .o1.. (numaralı).
const m = {
  // --- ortak ---
  'pg.crumbs': 'Sayfa yolu',
  'pg.crumb.home': 'Ana sayfa',
  'pg.related': 'İlgili sayfalar',
  'pg.updated': 'Son güncelleme: {date}',

  // --- üst menü / alt bilgi ---
  'pg.nav.news': 'Haberler',
  'pg.nav.menu': 'Yemek listesi',
  'pg.nav.help': 'Yardım',
  'pg.foot.org': 'Kurum',
  'pg.foot.product': 'Ürün',
  'pg.foot.support': 'Destek',
  'pg.foot.legal': 'Yasal',
  'pg.foot.get': 'Uygulamayı edinin',
  'pg.foot.contactTitle': 'İletişim',
  'pg.foot.theme': 'Tema ve dil',

  // --- çerez bandı ---
  'pg.cookie.label': 'Çerez bilgilendirmesi',
  'pg.cookie.text':
    'Bu site yalnızca çalışması için gerekli tarayıcı depolamasını (dil ve tema tercihi) kullanır; izleme, analiz veya reklam çerezi kullanmaz.',
  'pg.cookie.more': 'Çerez Politikası',
  'pg.cookie.short': 'Yalnızca zorunlu depolama kullanılır, izleme yok.',
  'pg.cookie.ok': 'Anladım',

  // --- hata / bakım ekranları ---
  'pg.err.title': 'Bir şeyler ters gitti',
  'pg.err.text': 'Beklenmeyen bir hata oluştu. Sayfayı yeniden deneyebilir ya da ana sayfaya dönebilirsiniz.',
  'pg.err.network.title': 'Bağlantı sorunu',
  'pg.err.network.text':
    'Sayfa yüklenemedi. İnternet bağlantınızı kontrol edip yeniden deneyin; sorun sürerse bir süre sonra tekrar gelin.',
  'pg.err.maint.title': 'Bakım çalışması',
  'pg.err.maint.text': 'Hizmet kısa süreliğine bakımda. Lütfen biraz sonra yeniden deneyin.',
  'pg.err.home': 'Ana sayfaya dön',

  // --- Çerez Politikası ---
  'pg.cookies.title': 'Çerez Politikası',
  'pg.cookies.lead':
    'Bu site yalnızca çalışması için gerekli olanı saklar. Reklam, izleme veya analiz amaçlı çerez kullanmıyoruz.',
  'pg.cookies.meta': 'BÜ Kampüs web sitesinin çerez ve tarayıcı depolama kullanımı: yalnızca zorunlu kayıtlar.',
  'pg.cookies.s1.h': 'Çerez nedir?',
  'pg.cookies.s1.p1':
    'Çerezler ve benzeri tarayıcı depolama alanları (yerel depolama, oturum depolaması), bir siteyi ziyaret ettiğinizde tarayıcınızda saklanan küçük kayıtlardır.',
  'pg.cookies.s2.h': 'Hangi kayıtları saklıyoruz?',
  'pg.cookies.s2.p1':
    'Web sitemiz tarayıcınıza HTTP çerezi yazmaz. Yalnızca aşağıdaki zorunlu kayıtları tarayıcınızın yerel ve oturum depolamasında tutar:',
  'pg.cookies.s2.l1': 'bu.lang: seçtiğiniz arayüz dilini hatırlar.',
  'pg.cookies.s2.l2': 'bu.theme: açık veya koyu görünüm tercihinizi hatırlar.',
  'pg.cookies.s2.l3': 'bu.cookies: bu bilgilendirmeyi gördüğünüzü hatırlar.',
  'pg.cookies.s2.l4':
    'Yönetim paneli oturumu (yalnızca yönetici girişinde, oturum depolaması): sekmeyi kapattığınızda silinir.',
  'pg.cookies.s3.h': 'Analiz, reklam ve izleme',
  'pg.cookies.s3.p1':
    'Web sitesinde analiz, reklam veya üçüncü taraf izleme aracı bulunmuyor; bu nedenle onayınızı gerektiren bir çerez yok. İleride eklenirse bu sayfa güncellenir ve önce açık onayınız istenir.',
  'pg.cookies.s4.h': 'Tercihlerinizi yönetme',
  'pg.cookies.s4.p1':
    'Saklanan kayıtları tarayıcı ayarlarından silebilirsiniz; bu durumda dil ve tema tercihiniz sıfırlanır. Aşağıdan bilgilendirme bandını yeniden görüntüleyebilirsiniz.',
  'pg.cookies.s5.h': 'Mobil uygulama',
  'pg.cookies.s5.p1':
    'Mobil uygulamanın veri işleme ayrıntıları Gizlilik Politikası ve KVKK Aydınlatma Metninde yer alır.',
  'pg.cookies.status.ack': 'Bilgilendirmeyi onayladınız.',
  'pg.cookies.status.none': 'Bilgilendirmeyi henüz onaylamadınız.',
  'pg.cookies.reset': 'Bilgilendirme bandını yeniden göster',

  // --- Hesap silme ---
  'pg.delete.title': 'Hesap silme',
  'pg.delete.lead':
    'BÜ Kampüs hesabınızı uygulamadan kendiniz silebilirsiniz. Bu sayfa adımları ve silinen verileri anlatır.',
  'pg.delete.meta': 'BÜ Kampüs hesabınızı uygulama içinden nasıl silersiniz ve hesap silinince hangi veriler kaldırılır.',
  'pg.delete.s1.h': 'Uygulama içinden silme',
  'pg.delete.s1.p1': 'Hesabı silmenin en hızlı yolu uygulamadır:',
  'pg.delete.s1.o1': 'BÜ Kampüs uygulamasını açın ve hesabınızla giriş yapın.',
  'pg.delete.s1.o2': 'Profil ve ayarlar bölümüne gidin.',
  'pg.delete.s1.o3': '“Hesabımı sil” seçeneğine dokunun.',
  'pg.delete.s1.o4': 'Şifrenizi girerek işlemi onaylayın.',
  'pg.delete.s2.h': 'Silinince ne olur?',
  'pg.delete.s2.l1':
    'Adınız, e-posta adresiniz, fakülte, bölüm, sınıf, biyografi ve profil görseliniz kaldırılır; hesabınız “Silinmiş kullanıcı” olarak anonimleştirilir.',
  'pg.delete.s2.l2': 'Kullanım ve etkinlik kayıtlarınız silinir.',
  'pg.delete.s2.l3': 'Etkinlik katılım (RSVP) kayıtlarınız silinir; etkinliklerin kontenjanında yer tutmazsınız.',
  'pg.delete.s2.l4': 'Mevcut oturumlarınız anında geçersiz olur.',
  'pg.delete.s3.h': 'Geri alınamaz',
  'pg.delete.s3.p1':
    'Hesap silme geri alınamaz. İsterseniz silmeden önce verilerinizi uygulamadaki “verilerimi indir” seçeneğiyle dışa aktarabilirsiniz.',
  'pg.delete.s4.h': 'Uygulamaya erişemiyorsanız',
  'pg.delete.s4.p1':
    'Şifrenizi hatırlamıyorsanız veya uygulamayı kuramıyorsanız, veri talebi sayfası ya da iletişim sayfası üzerinden bize ulaşın; talebinizi yasal süreler içinde yanıtlarız.',
  'pg.delete.s5.h': 'Verileriniz hakkında',
  'pg.delete.s5.p1':
    'Hangi verileri hangi amaçla işlediğimiz Gizlilik Politikası ve KVKK Aydınlatma Metninde açıklanır.',

  // --- Erişilebilirlik ---
  'pg.accessibility.title': 'Erişilebilirlik beyanı',
  'pg.accessibility.lead': 'BÜ Kampüs web sitesini herkesin kullanabilmesi için çalışıyoruz.',
  'pg.accessibility.meta': 'BÜ Kampüs web sitesinin erişilebilirlik hedefi, yapılanlar ve bilinen sınırlamalar.',
  'pg.accessibility.s1.h': 'Hedefimiz',
  'pg.accessibility.s1.p1':
    'Sitemizin WCAG 2.1 AA düzeyine uygun olmasını hedefliyoruz. Bağımsız bir erişilebilirlik denetimi henüz yapılmadı; durum kendi değerlendirmemize dayanır.',
  'pg.accessibility.s2.h': 'Yaptıklarımız',
  'pg.accessibility.s2.l1': 'Tüm sayfalarda “İçeriğe geç” bağlantısı ve anlamlı başlık yapısı.',
  'pg.accessibility.s2.l2': 'Klavyeyle tam kullanım ve görünür odak göstergesi.',
  'pg.accessibility.s2.l3':
    'Metin ve arka plan renkleri en az 4,5:1 kontrast oranını sağlar; açık ve koyu tema bulunur.',
  'pg.accessibility.s2.l4': 'Türkçe, İngilizce ve Arapça arayüz; Arapçada sağdan sola düzen.',
  'pg.accessibility.s2.l5': 'Ekran okuyucular için etiketli düğmeler, durum bildirimleri ve sayfa değişiminde başlığa odaklanma.',
  'pg.accessibility.s2.l6': 'Sistemde “hareketi azalt” seçiliyse animasyonlar kapatılır.',
  'pg.accessibility.s3.h': 'Bilinen sınırlamalar',
  'pg.accessibility.s3.l1':
    'Haberler ve duyurular Bingöl Üniversitesi sitesinden alınır; kaynaktaki görsellerde alternatif metin eksik olabilir.',
  'pg.accessibility.s3.l2': 'Harici sitelere giden bağlantıların erişilebilirliği denetimimizde değildir.',
  'pg.accessibility.s4.h': 'Geri bildirim',
  'pg.accessibility.s4.p1':
    'Bir erişilebilirlik sorunuyla karşılaşırsanız bize bildirin; sorunu ve kullandığınız cihazı ya da yardımcı teknolojiyi yazmanız çözümü hızlandırır.',
  'pg.accessibility.s5.h': 'Değerlendirme',
  'pg.accessibility.s5.p1': 'Bu beyan, sitenin Ekim 2026 sürümü için hazırlanmıştır ve site geliştikçe güncellenir.',

  // --- Güvenlik ---
  'pg.security.title': 'Güvenlik',
  'pg.security.lead':
    'Verilerinizi nasıl koruduğumuzu ve bir güvenlik açığını bize nasıl bildirebileceğinizi anlatır.',
  'pg.security.meta': 'BÜ Kampüs güvenlik yaklaşımı ve sorumlu güvenlik açığı bildirimi yönergesi.',
  'pg.security.s1.h': 'Verilerinizi nasıl koruyoruz?',
  'pg.security.s1.l1': 'Uygulama ile sunucu arasındaki iletişim üretim ortamında şifreli bağlantı (HTTPS) üzerinden yapılır.',
  'pg.security.s1.l2':
    'Mesajlar sunucuda şifreli olarak saklanır. Anahtarları sunucu yönetir; bu nedenle mesajlar yalnızca sizin cihazınızda çözülebilen bir korumaya sahip değildir ve yetkili süreçlerce çözülebilir.',
  'pg.security.s1.l3':
    'Yönetici erişimi kayıt altındadır: yetkili yöneticiler güvenlik ve yasal yükümlülükler için konuşmaları görüntüleyebilir ve her erişim değiştirilemez bir denetim kaydına yazılır. Silinen mesajlar güvenlik ve yasal yükümlülükler için saklanabilir.',
  'pg.security.s1.l4':
    'Şifreler geri döndürülemeyecek biçimde (özet olarak) saklanır; oturum yenileme anahtarları da yalnızca özet olarak tutulur.',
  'pg.security.s1.l5': 'Kayıt yalnızca bingol.edu.tr e-posta adresleriyle ve e-posta doğrulamasıyla yapılabilir.',
  'pg.security.s1.l6': 'Giriş, doğrulama ve yazma uçlarında hız sınırı uygulanır.',
  'pg.security.s2.h': 'Güvenlik açığı bildirimi',
  'pg.security.s2.p1':
    'Bir güvenlik açığı bulduğunuzu düşünüyorsanız lütfen önce bize özel olarak bildirin. Aşağıdaki kurallara uyarak iyi niyetle yapılan bildirimleri memnuniyetle karşılarız.',
  'pg.security.s2.l1': 'Bildirimde etkilenen adres veya uç, tekrar üretme adımları ve olası etki bulunsun.',
  'pg.security.s2.l2':
    'Başkalarının verilerine erişmeyin, veri silmeyin veya değiştirmeyin; hizmeti aksatacak testler (yoğun yük, hizmet engelleme) yapmayın.',
  'pg.security.s2.l3': 'Açık giderilene kadar kamuya açıklamayın.',
  'pg.security.s2.l4': 'Bildiriminizi aldığımızda size dönüş yapmaya çalışırız.',
  'pg.security.s3.h': 'Kapsam',
  'pg.security.s3.l1': 'Kapsam içinde: BÜ Kampüs mobil uygulaması, bu web sitesi ve API.',
  'pg.security.s3.l2':
    'Kapsam dışında: bingol.edu.tr ve alt alanlarındaki üniversite sistemleri (bunları ilgili birime bildirin), sosyal mühendislik, fiziksel saldırılar ve üçüncü taraf hizmetler.',
  'pg.security.s4.h': 'İletişim',
  'pg.security.s4.p1': 'Bildirimlerinizi aşağıdaki iletişim adresine gönderin.',
  'pg.security.s5.h': 'Kullanıcılar için öneriler',
  'pg.security.s5.l1': 'Şifrenizi başka hizmetlerde kullanmayın.',
  'pg.security.s5.l2': 'Şüpheli bir içerik veya kullanıcı görürseniz uygulamadan raporlayın.',
  'pg.security.s5.l3': 'Cihazınızı ve uygulamayı güncel tutun.',
  'pg.security.contactNone': 'Şu an kayıtlı bir e-posta adresi yok; iletişim sayfasındaki yolları kullanın.',
  'pg.security.txt': 'security.txt dosyası',

  // --- Topluluk kuralları ---
  'pg.guidelines.title': 'Topluluk kuralları',
  'pg.guidelines.lead':
    'Herkesin kendini güvende hissettiği bir kampüs ortamı için kurallar ve bunların nasıl uygulandığı.',
  'pg.guidelines.meta': 'BÜ Kampüs topluluk kuralları: beklentiler, raporlama, moderasyon kararları ve itiraz süreci.',
  'pg.guidelines.s1.h': 'Beklentilerimiz',
  'pg.guidelines.s1.l1': 'Saygılı olun; taciz, nefret söylemi, tehdit ve zorbalık yasaktır.',
  'pg.guidelines.s1.l2': 'Başkalarının kişisel bilgilerini izinsiz paylaşmayın.',
  'pg.guidelines.s1.l3': 'Yasa dışı, müstehcen veya şiddet içeren içerik paylaşmayın.',
  'pg.guidelines.s1.l4': 'Kendinizi başka biri ya da bir kulüp gibi göstermeyin; spam ve yanıltıcı içerik göndermeyin.',
  'pg.guidelines.s2.h': 'İçeriği nasıl bildirirsiniz?',
  'pg.guidelines.s2.p1':
    'Kullanıcıları, mesajları, gönderileri, toplulukları, etkinlikleri ve görselleri uygulamadan raporlayabilirsiniz. Aynı içeriği kısa sürede tekrar bildirmek mümkün değildir.',
  'pg.guidelines.s2.l1': 'Raporunuz moderatörlerin kuyruğuna düşer; birden çok kişi bildirdiyse önceliği artar.',
  'pg.guidelines.s2.l2':
    'Bazı içerik türlerinde yeterli sayıda ayrı kullanıcı bildirirse içerik incelenene kadar otomatik gizlenebilir.',
  'pg.guidelines.s2.l3': 'Karar verildiğinde bildirimle haberdar edilirsiniz.',
  'pg.guidelines.s3.h': 'Moderasyon kararları',
  'pg.guidelines.s3.p1': 'Moderatörler raporu inceler ve şunlardan birini yapar:',
  'pg.guidelines.s3.l1': 'Raporu reddeder (ihlal bulunmadı).',
  'pg.guidelines.s3.l2': 'İçerik sahibini uyarır.',
  'pg.guidelines.s3.l3': 'İçeriği kaldırır veya gizler.',
  'pg.guidelines.s3.l4':
    'Tekrarlayan ihlallerde yöneticilere hesabı askıya alma önerisi iletilir; son karar bir yöneticiye aittir.',
  'pg.guidelines.s3.p2':
    'Kötü niyetli veya art arda reddedilen asılsız raporlar, rapor özelliğinin geçici olarak kısıtlanmasına yol açabilir.',
  'pg.guidelines.s4.h': 'İtiraz süreci',
  'pg.guidelines.s4.p1':
    'İçeriğiniz gizlendiyse ve bu içerik türü geri alınabiliyorsa, uygulamadan bir kez itiraz edebilirsiniz. İtiraz bir yönetici tarafından incelenir; kabul edilirse içerik yeniden görünür olur ve o içerikten doğan ihlal kaydı iptal edilir.',
  'pg.guidelines.s4.p2':
    'Hesabınız askıya alındıysa uygulamaya giriş yapamayacağınız için itirazınızı iletişim sayfasındaki yollarla iletin.',
  'pg.guidelines.s5.h': 'Bağlayıcı metin',
  'pg.guidelines.s5.p1':
    'Bu sayfa bilgilendiricidir; bağlayıcı metin yasal belgelerdeki Topluluk Kuralları sürümüdür.',
  'pg.guidelines.fullText': 'Topluluk Kuralları tam metni',

  // --- Yardım merkezi ---
  'pg.help.title': 'Yardım merkezi',
  'pg.help.lead': 'Sık sorulan sorular, rehberler ve destek yolları tek yerde.',
  'pg.help.meta': 'BÜ Kampüs yardım merkezi: sık sorulan sorular, hesap, gizlilik, kurallar ve destek.',
  'pg.help.cat.start.title': 'Başlangıç ve hesap',
  'pg.help.cat.start.text': 'Kayıt, e-posta doğrulama, giriş ve profil bilgileri.',
  'pg.help.cat.features.title': 'Mesajlar ve topluluklar',
  'pg.help.cat.features.text': 'Sohbet, kulüpler, etkinlikler ve QR yoklama.',
  'pg.help.cat.safety.title': 'Gizlilik ve güvenlik',
  'pg.help.cat.safety.text': 'Verilerinizin nasıl korunduğu ve güvenlik açığı bildirimi.',
  'pg.help.cat.rules.title': 'Kurallar ve moderasyon',
  'pg.help.cat.rules.text': 'Topluluk kuralları, raporlama ve itiraz.',
  'pg.help.cat.data.title': 'Hesap ve veriler',
  'pg.help.cat.data.text': 'Hesabı silme, verileri indirme ve KVKK başvuruları.',
  'pg.help.open': 'Aç',
  'pg.help.supportTitle': 'Hâlâ yardıma mı ihtiyacınız var?',
  'pg.help.supportText':
    'Sorunuzun yanıtını bulamadıysanız iletişim sayfasındaki adımlarla uygulamadan destek talebi oluşturabilir veya bize yazabilirsiniz.',
  'pg.help.faq': 'Sık sorulan sorular',
  'pg.help.contact': 'Bize ulaşın',


  // --- Haberler ---
  'pg.news.title': 'Haberler ve duyurular',
  'pg.news.lead': 'Bingöl Üniversitesi’nin yayımladığı haber, duyuru ve etkinlikler.',
  'pg.news.meta': 'Bingöl Üniversitesi haberleri, duyuruları ve etkinlikleri BÜ Kampüs’te.',
  'pg.news.filter': 'Tür filtresi',
  'pg.news.type.ALL': 'Tümü',
  'pg.news.type.HABER': 'Haber',
  'pg.news.type.DUYURU': 'Duyuru',
  'pg.news.type.ETKINLIK': 'Etkinlik',
  'pg.news.empty': 'Bu türde içerik yok',
  'pg.news.emptyHint': 'Kaynak sitede yeni içerik yayımlandığında burada görünür.',
  'pg.news.error': 'Haberler yüklenemedi',
  'pg.news.original': 'Orijinal sayfayı aç (bingol.edu.tr)',
  'pg.news.back': 'Tüm haberler',
  'pg.news.notFound': 'İçerik bulunamadı',
  'pg.news.notFoundHint': 'Bu içerik kaldırılmış ya da hiç var olmamış olabilir.',
  'pg.news.noContent': 'Bu içeriğin metni harici bir sitede yayımlanıyor. Tamamını görmek için orijinal sayfayı açın.',
  'pg.news.read': 'Devamını oku',
  'pg.news.untitledImage': 'Haber görseli',

  // --- Yemek listesi ---
  'pg.menu.title': 'Yemek listesi',
  'pg.menu.lead': 'Üniversite yemekhanesinin günlük ve aylık menüsü.',
  'pg.menu.meta': 'Bingöl Üniversitesi yemekhanesinin günlük ve aylık yemek listesi.',
  'pg.menu.view': 'Görünüm',
  'pg.menu.view.day': 'Günlük',
  'pg.menu.view.month': 'Aylık',
  'pg.menu.today': 'Bugün',
  'pg.menu.prevDay': 'Önceki gün',
  'pg.menu.nextDay': 'Sonraki gün',
  'pg.menu.prevMonth': 'Önceki ay',
  'pg.menu.nextMonth': 'Sonraki ay',
  'pg.menu.noDay': 'Bu tarih için menü yok',
  'pg.menu.noDayHint': 'Hafta sonu veya tatil günlerinde menü yayımlanmayabilir.',
  'pg.menu.noMonth': 'Bu ay için menü yayımlanmadı',
  'pg.menu.noMonthHint': 'Menü yayımlandığında burada görünür.',
  'pg.menu.error': 'Yemek listesi yüklenemedi',
  'pg.menu.maintenance': 'Yemek listesi kaynağı şu an bakımda; son başarılı liste gösteriliyor.',

  // --- Marka kiti ---
  'pg.brand.title': 'Basın ve marka kiti',
  'pg.brand.logo.mark': 'Simge',
  'pg.brand.logo.horizontalLight': 'Yatay · açık zemin',
  'pg.brand.logo.horizontalDark': 'Yatay · koyu zemin',
  'pg.brand.logo.verticalLight': 'Dikey · açık zemin',
  'pg.brand.logo.verticalDark': 'Dikey · koyu zemin',
  'pg.brand.logo.horizontalWhite': 'Yatay · tek renk beyaz',
  'pg.brand.logo.horizontalBlack': 'Yatay · tek renk siyah',
  'pg.brand.logo.markWhite': 'Simge · tek renk beyaz',
  'pg.brand.logo.markBlack': 'Simge · tek renk siyah',
  'pg.brand.download': '{name} indir ({format})',

  // --- Sürüm notları ---
  'pg.changelog.title': 'Sürüm notları',
  'pg.changelog.lead': 'BÜ Kampüs’teki önemli değişiklikler.',
  'pg.changelog.meta': 'BÜ Kampüs sürüm notları: yeni özellikler, iyileştirmeler ve güvenlik değişiklikleri.',
  'pg.changelog.empty': 'Henüz sürüm notu yok',
  'pg.changelog.e1.date': '2026-10',
  'pg.changelog.e1.title': 'Ekim 2026',
  'pg.changelog.e1.l1': 'Mesajlar sunucuda şifreli saklanıyor; yönetici erişimi denetim kaydına bağlı, silinen mesajlar güvenlik amacıyla saklanabilir.',
  'pg.changelog.e1.l2': 'Etkinlik başvurusu ve kabul akışı: kabul, ret ve bekleme listesi.',
  'pg.changelog.e1.l3': 'Kulüp yetkileri, sahiplik devri ve davet kodu.',
  'pg.changelog.e1.l4': 'Sohbette görsel paylaşımı; uygunsuz görsel raporlama ve itiraz süreci.',
  'pg.changelog.e1.l5': 'Gizlilik ayarları: profilde kimlerin ne göreceğini siz seçersiniz.',
  'pg.changelog.e1.l6': 'Web sitesi yenilendi: yeni renk paleti, haberler, yemek listesi, yardım ve yasal sayfalar.',
  'pg.changelog.e2.date': '2026-09',
  'pg.changelog.e2.title': 'Eylül 2026',
  'pg.changelog.e2.l1': 'Haber, duyuru ve etkinlikler ile aylık yemek listesi.',
  'pg.changelog.e2.l2': 'Topluluklar, etkinlikler, QR ve elle yoklama.',
  'pg.changelog.e2.l3': 'Türkçe, İngilizce ve Arapça arayüz.',
  'pg.changelog.note': 'Bu liste elle derlenir; küçük düzeltmeler yer almayabilir.',

  // --- Site haritası ---
  'pg.sitemap.title': 'Site haritası',
  'pg.sitemap.lead': 'Sitedeki tüm herkese açık sayfalar.',
  'pg.sitemap.meta': 'BÜ Kampüs web sitesindeki tüm sayfaların listesi.',

  'pg.news.search': 'Haberlerde ara',
  'pg.news.searchPlaceholder': 'Başlık veya içerikte ara…',
  'pg.news.featured': 'Öne çıkan',
  'pg.news.share': 'Paylaş',
  'pg.news.linkCopied': 'Bağlantı kopyalandı',
  'pg.news.related': 'İlgili içerikler',
  'pg.news.prev': 'Önceki haber',
  'pg.news.next': 'Sonraki haber',
  'pg.news.prevNext': 'Önceki ve sonraki içerik',
  'pg.news.emptySearch': 'Aramanızla eşleşen içerik yok',
  'pg.news.emptySearchHint':
    'Farklı anahtar sözcükler deneyin (en az 2 karakter) veya tür filtresini değiştirin.',
  'pg.news.resultCount': '{count} sonuç bulundu',
  'pg.brand.lead':
    'BÜ Kampüs logoları, Kampüs Kırmızısı renk paleti, tipografi ve kullanım kuralları. Dosyaları doğrudan indirebilirsiniz.',
  'pg.brand.meta':
    'BÜ Kampüs basın kiti: logo varyantları (PNG/SVG), Kampüs Kırmızısı renk paleti, koruma alanı, tipografi ve kullanım kuralları.',
  'pg.brand.logos': 'Logolar',
  'pg.brand.logosText':
    'Açık zeminde “açık”, koyu zeminde “koyu” sürümü kullanın. Kırmızı veya yoğun renkli zeminde tek renk beyaz ya da siyah sürümü tercih edin.',
  'pg.brand.group.horizontal': 'Yatay logo',
  'pg.brand.group.horizontalText': 'Başlıklar, üst çubuk ve geniş alanlar için ana kilit.',
  'pg.brand.group.vertical': 'Dikey logo',
  'pg.brand.group.verticalText': 'Kare ve dar alanlar, afiş ve kapak kullanımı için.',
  'pg.brand.group.mark': 'Amblem',
  'pg.brand.group.markText': 'Uygulama ikonu, avatar ve çok küçük alanlar için.',
  'pg.brand.pngMeta': 'PNG · {w} × {h} px · {kb} KB',
  'pg.brand.svgMeta': 'SVG · {kb} KB',
  'pg.brand.space.title': 'Koruma alanı',
  'pg.brand.space.text':
    'Logonun her yönünde amblem yüksekliğinin %25’i (x) kadar boşluk bırakın. Bu alana başka öğe, metin veya kenar girmez.',
  'pg.brand.min.title': 'En küçük boyut',
  'pg.brand.min.text': 'Bu boyutların altında logo okunaksız hâle gelir.',
  'pg.brand.min.mark': 'Amblem: 16 px',
  'pg.brand.min.horizontal': 'Yatay: 28 px yükseklik',
  'pg.brand.min.vertical': 'Dikey: 64 px yükseklik',
  'pg.brand.dont.title': 'Yapmayın',
  'pg.brand.dont.text': 'Logoyu aşağıdaki biçimlerde değiştirmeyin.',
  'pg.brand.dont.stretch': 'Germeyin veya sıkıştırmayın',
  'pg.brand.dont.rotate': 'Döndürmeyin',
  'pg.brand.dont.recolor': 'Renklerini değiştirmeyin',
  'pg.brand.dont.shadow': 'Gölge veya parlama eklemeyin',
  'pg.brand.dont.busy': 'Renkli logoyu kırmızı veya yoğun zemine koymayın',
  'pg.brand.do.label': 'Doğru kullanım',
  'pg.brand.dont.label': 'Yanlış kullanım',
  'pg.brand.colors': 'Kampüs Kırmızısı paleti',
  'pg.brand.colorsText':
    'Marka kırmızı, lacivert-mürekkep ve sıcak bir zeminden oluşur. Değerler arayüz tasarım belirteçleriyle aynıdır.',
  'pg.brand.copyHex': '{hex} kodunu kopyala',
  'pg.brand.color.campus': 'Kampüs Kırmızısı',
  'pg.brand.color.campusUse': 'Logo, büyük yüzeyler ve görsel vurgu.',
  'pg.brand.color.campusContrast': 'Beyaz yazıyla 3,8:1: yalnızca büyük ve kalın metinde kullanın.',
  'pg.brand.color.action': 'Eylem Kırmızısı',
  'pg.brand.color.actionUse': 'Düğmeler, bağlantılar ve etkileşimli öğeler.',
  'pg.brand.color.actionContrast': 'Beyaz yazıyla 5,6:1 (AA).',
  'pg.brand.color.deep': 'Derin Kırmızı',
  'pg.brand.color.deepUse': 'Yumuşak zemin üzerindeki vurgulu metin, basılı durum.',
  'pg.brand.color.deepContrast': 'Yumuşak Kırmızı üzerinde 7,7:1 (AAA).',
  'pg.brand.color.soft': 'Yumuşak Kırmızı',
  'pg.brand.color.softUse': 'Rozet ve hafif vurgu zeminleri.',
  'pg.brand.color.softContrast': 'Mürekkep yazıyla 14:1 (AAA).',
  'pg.brand.color.ink': 'Mürekkep',
  'pg.brand.color.inkUse': 'Ana metin, koyu yüzeyler ve logo yazısı.',
  'pg.brand.color.inkContrast': 'Sıcak zeminde 15,4:1 (AAA).',
  'pg.brand.color.paper': 'Sıcak Zemin',
  'pg.brand.color.paperUse': 'Sayfa ve kart arka planı.',
  'pg.brand.color.paperContrast': 'Mürekkep yazıyla 15,4:1 (AAA).',
  'pg.brand.type.title': 'Tipografi',
  'pg.brand.type.text':
    'Ek yazı tipi yüklenmez: gövde metni için cihazın sistem sans-serif yazı tipi, başlıklar için serif yığını kullanılır.',
  'pg.brand.type.display': 'Başlık · serif',
  'pg.brand.type.displaySample': 'BÜ Kampüs',
  'pg.brand.type.body': 'Metin · sistem sans-serif',
  'pg.brand.type.bodySample': 'Bingöl Üniversitesi öğrencileri ve personeli için kampüs uygulaması.',
  'pg.brand.rules': 'Kısa kullanım kuralları',
  'pg.brand.rule.1': 'Ürün adı her yerde “BÜ Kampüs” biçiminde yazılır; Arapça metinde de çevrilmez.',
  'pg.brand.rule.2':
    'Zemine uygun sürümü seçin: açık zeminde açık, koyu zeminde koyu, kırmızı zeminde tek renk beyaz.',
  'pg.brand.rule.3': 'Koruma alanına ve en küçük boyuta uyun.',
  'pg.brand.rule.4':
    'Logoyu yalnızca verilen dosyalardan kullanın; yeniden çizmeyin veya başka bir yazı tipiyle dizmeyin.',
  'pg.brand.rule.5':
    'Bingöl Üniversitesi’nin resmî logosu bu kitin parçası değildir; kurumsal kullanım için üniversiteye başvurun.',
  'pg.brand.pressTitle': 'Basın iletişimi',
  'pg.brand.pressText': 'Basın soruları, görsel talepleri ve logo kullanım onayı için bize yazın.',
  'pg.brand.pressEmail': 'E-posta: {email}',
  'pg.brand.pressContact': 'İletişim sayfası',
} as const;
export default m;
