// Tanıtım sitesi: Çocuk güvenliği standartları sayfası (/child-safety; Google Play CSAE beyanı için herkese açık URL).
// Yalnız uygulamada GERÇEKTEN var olanı anlatır (kaynak: docs/MODERATION.md, docs/legal/*, docs/LEGAL_NOTES.md bölüm 11).
// Anahtar kalıbı: pg.childsafety.<bölüm>.h | .p1.. | .l1.. (InfoPage ve noscript aynı kalıbı okur).
const m = {
  'pg.childsafety.title': 'Çocuk güvenliği standartları',
  'pg.childsafety.lead':
    'BÜ Kampüs’te çocuğun cinsel istismarına ve sömürüsüne sıfır tolerans gösteririz. Bu sayfa, bunu nasıl önlediğimizi, bildirimleri nasıl aldığımızı ve nasıl müdahale ettiğimizi açıklar.',
  'pg.childsafety.meta':
    'BÜ Kampüs çocuk güvenliği standartları: çocuğun cinsel istismarı ve sömürüsü (CSAE) ile çocuk cinsel istismarı materyaline (CSAM) karşı önleme, bildirim ve müdahale.',

  'pg.childsafety.s1.h': 'Amaç ve kapsam',
  'pg.childsafety.s1.p1':
    'BÜ Kampüs, Bingöl Üniversitesi öğrencileri ve personeli için geliştirilmiş bağımsız bir uygulamadır; üniversitenin resmî uygulaması değildir. Çocuklara yönelik değildir: hedef kitle 18 yaş ve üzeridir ve kayıt için doğrulanmış bir bingol.edu.tr e-posta adresi gerekir.',
  'pg.childsafety.s1.p2':
    'Bu sayfa, çocuğun cinsel istismarı ve sömürüsüne (CSAE) ve çocuk cinsel istismarı materyaline (CSAM) karşı standartlarımızı açıklar.',
  'pg.childsafety.s1.p3':
    'Bu içeriklere ve davranışlara uygulamamızda yer yoktur: tespit ettiğimizde kaldırır, hesabı kapatır ve gerektiğinde yetkili makamlara bildiririz.',

  'pg.childsafety.s2.h': 'Neleri yasaklıyoruz?',
  'pg.childsafety.s2.p1': 'Aşağıdakilerin hepsi uygulamada kesinlikle yasaktır:',
  'pg.childsafety.s2.l1':
    'Çocuk cinsel istismarı materyali (CSAM): 18 yaşından küçük birini cinsel içerikli gösteren her fotoğraf, video, çizim veya metni üretmek, paylaşmak, istemek, saklamak ya da bağlantısını vermek.',
  'pg.childsafety.s2.l2':
    'Çocuklara yönelik cinsel içerik ve çocukları cinselleştirme: çocuk hakkında cinsel yorumlar, çocuktan cinsel içerikli görsel veya bilgi istemek.',
  'pg.childsafety.s2.l3':
    'Grooming: cinsel istismar amacıyla bir çocukla güven ilişkisi kurmaya, onu kandırmaya ya da yalnız kalmaya yönlendirmeye çalışmak.',
  'pg.childsafety.s2.l4':
    'Sextortion: çocuğun cinsel içerikli görüntüsüyle tehdit etmek, şantaj yapmak veya bu yolla para ya da yeni görsel istemek.',
  'pg.childsafety.s2.l5': 'Çocukların ticareti ve cinsel amaçlı sömürülmesi, bunlara aracılık etmek veya yönlendirmek.',
  'pg.childsafety.s2.l6': 'Bu davranışları özendiren, normalleştiren veya bu içeriklere nasıl ulaşılacağını anlatan paylaşımlar.',

  'pg.childsafety.s3.h': 'Önleme',
  'pg.childsafety.s3.p1': 'Riski azaltmak için uygulamanın yapısı şöyledir:',
  'pg.childsafety.s3.l1':
    'Kayıt yalnızca doğrulanmış bir üniversite e-postasıyla (bingol.edu.tr) yapılır; e-postaya gelen kod girilmeden hesap açılmaz. Anonim kullanım yoktur.',
  'pg.childsafety.s3.l2':
    'Kötüye kullanım amacıyla birden fazla hesap açmak yasaktır. Yasaklanan bir kullanıcının cihaz veya IP kaydıyla eşleşen yeni hesaplar engellenebilir.',
  'pg.childsafety.s3.l3':
    'Gönderi, tek bir fotoğraf ve en çok 7 kelimelik kısa bir metinden oluşur; gönderilerde yorum, hikâye ve video yoktur. Sohbet birebir ve gruplar içindir; sohbette fotoğraf ve kısa video paylaşılabilir.',
  'pg.childsafety.s3.l4':
    'Yüklenen fotoğraflar sunucuda yeniden kodlanır ve konum gibi gömülü üst veri (EXIF) temizlenir. Yöneticiler belirli bir görselin dijital özetini yasaklı listeye ekleyebilir; birebir aynı dosya yüklenirse reddedilir.',
  'pg.childsafety.s3.l5':
    'Herkese açık alanlardaki metinlerde (gönderi, profil, kulüp, etkinlik) uygunsuz ve cinsel içerikli ifadeler filtrelenir. Özel sohbet mesajları yayımlanmadan önce taranmaz.',
  'pg.childsafety.s3.p2':
    'Açık olalım: uygulamada CSAM’i otomatik tanıyan bir sistem (hash eşleştirme veritabanı, görsel tarama vb.) yoktur. Yüklenen görseller içerik olarak otomatik analiz edilmez; yasaklı liste yalnızca yöneticilerin elle eklediği, birebir aynı dosyaları yakalar. Bu yüzden kullanıcı bildirimleri ve insan incelemesi temel savunmamızdır.',

  'pg.childsafety.s4.h': 'Nasıl bildirirsiniz?',
  'pg.childsafety.s4.p1': 'Çocuk güvenliğini tehdit eden bir içerik veya davranış görürseniz hemen bildirin:',
  'pg.childsafety.s4.l1':
    'Uygulamada kullanıcı, mesaj, gönderi, kulüp veya etkinlik üzerinde “Bildir” seçeneğini kullanın. Ayrı bir çocuk güvenliği nedeni yoktur: “Uygunsuz içerik” ya da “Diğer” nedenini seçip nota “çocuk güvenliği” yazın.',
  'pg.childsafety.s4.l2': 'Şüpheli kullanıcıyı engelleyin; engellenen kişinin mesajları size iletilmez.',
  'pg.childsafety.s4.l3': 'Uygulamadaki Destek bölümünden talep açın ya da web sitesindeki iletişim sayfasını kullanın.',
  'pg.childsafety.s4.l4': 'Doğrudan Çocuk Güvenliği İrtibat Noktası’na e-posta gönderin (bu sayfanın iletişim bölümü).',
  'pg.childsafety.s4.l5':
    'Çocuğun acil tehlikede olduğunu düşünüyorsanız önce 112 Acil Çağrı Merkezi’ni veya en yakın kolluk birimini arayın.',
  'pg.childsafety.s4.p2':
    'Şüpheli görseli başkalarına iletmeyin veya yaymayın; bu da suç olabilir. Bildirimde yeri ve kullanıcıyı belirtmeniz yeterlidir.',

  'pg.childsafety.s5.h': 'Müdahale',
  'pg.childsafety.s5.p1': 'CSAE veya CSAM şüphesi olan bir bildirimde şunları yaparız:',
  'pg.childsafety.s5.l1':
    'İçeriği hemen gizler veya kaldırırız. Aynı gönderi, etkinlik veya sohbet görselini birbirinden bağımsız 3 hesap bildirirse inceleme tamamlanana kadar otomatik ve geçici olarak gizlenir; yöneticiler gerekirse tek bildirimle de gizleyebilir.',
  'pg.childsafety.s5.l2':
    'Bildirilen sohbet içeriğini yetkili yöneticiler yazılı gerekçe girerek inceler; her erişim değiştirilemez bir kayda yazılır.',
  'pg.childsafety.s5.l3':
    'Hesabı askıya alırız veya kalıcı olarak kapatırız. Ağır ihlallerde uyarı gibi ara basamaklar atlanır.',
  'pg.childsafety.s5.l4': 'Gerekirse IP, ağ aralığı veya cihaz bazlı erişim engeli uygularız; yeni hesapla engel aşılamaz.',
  'pg.childsafety.s5.l5':
    'İlgili içeriği ve kayıtları (bildirim, işlem ve erişim kayıtları) yetkili makamlara iletilebilmesi için korumaya çalışırız. Bu kayıtları yalnızca hukuka uygun taleplerle ve gerekli ölçüde paylaşırız.',
  'pg.childsafety.s5.l6':
    'Türkiye’de kolluk kuvvetlerinin siber suçlarla mücadele birimlerine ve savcılığa; uygulanabildiği ölçüde uluslararası çocuk koruma kuruluşlarına ve ihbar hatlarına bildirim yaparız.',
  'pg.childsafety.s5.p2':
    'Geçerli yasalara ve yetkili makamların taleplerine uyarız.',

  'pg.childsafety.s6.h': 'Süreç ve şeffaflık',
  'pg.childsafety.s6.p1':
    'Bildirimleri gecikmeden incelemeye çalışırız; çocuk güvenliği şüphesi taşıyanlar önceliklidir. Kesin bir süre taahhüdü vermiyoruz.',
  'pg.childsafety.s6.p2':
    'İçerik kaldırma veya hesap kısıtlama kararlarına uygulamadaki itiraz özelliğinden ya da Destek bölümünden itiraz edebilirsiniz. Çocuk güvenliği ihlallerinde yetkili makamlara yapılan bildirim, itirazdan bağımsızdır.',
  'pg.childsafety.s6.p3':
    'Bu standartları uygulamadaki değişiklikler, yeni bilgiler ve mevzuat değişiklikleri doğrultusunda güncelleriz. Daha ayrıntılı kurallar için Topluluk Kuralları ve Kullanım Koşulları’na bakın.',
  'pg.childsafety.s6.p4': 'Son güncelleme: 29 Ekim 2026',

  'pg.childsafety.s7.h': 'Çocuk Güvenliği İrtibat Noktası',
  'pg.childsafety.s7.p1':
    'Çocuk güvenliği bildirimleri, yetkili makamların talepleri ve bu standartlara ilişkin sorular için Çocuk Güvenliği İrtibat Noktası’na yazın. Bu görev geliştirici ve yöneticiye aittir.',
  'pg.childsafety.s7.l1': 'E-posta: ysufakin23@gmail.com',
  'pg.childsafety.mail': 'E-posta gönder',
  'pg.childsafety.rules': 'Topluluk Kuralları',
  'pg.childsafety.terms': 'Kullanım Koşulları',
} as const;
export default m;
