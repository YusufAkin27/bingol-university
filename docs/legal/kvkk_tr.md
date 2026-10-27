# KVKK Aydınlatma Metni

6698 sayılı Kişisel Verilerin Korunması Kanunu'nun ("**Kanun**" / "**KVKK**") 10. maddesi ve Aydınlatma Yükümlülüğünün Yerine Getirilmesinde Uyulacak Usul ve Esaslar Hakkında Tebliğ uyarınca, BÜ Kampüs uygulaması ve web sitesini kullanırken kişisel verilerinizin nasıl işlendiği hakkında sizi bilgilendiririz. Bu metin bilgilendirme amaçlıdır; açık rıza gerektiren işlemler ayrıca [Açık Rıza Metni](/legal/explicit-consent) ile sizden ayrı ayrı istenir.

## 1. Veri sorumlusu

| | |
|---|---|
| Veri sorumlusu | {{controller.name}} |
{{?controller.address}}| Adres | {{controller.address}} |{{/controller.address}}
{{?controller.email}}| E-posta | {{controller.email}} |{{/controller.email}}
{{?controller.kep}}| KEP adresi | {{controller.kep}} |{{/controller.kep}}
{{?controller.verbis}}| VERBİS sicil no | {{controller.verbis}} |{{/controller.verbis}}
| Uygulama içi başvuru | Destek bölümü{{?support.email}} · {{support.email}}{{/support.email}} |

## 2. İşlenen kişisel veri kategorileri

| Kategori | Örnekler |
|---|---|
| Kimlik | Ad-soyad |
| İletişim | Kurumsal e-posta adresi (bingol.edu.tr), destek taleplerinde iletişim e-postası |
| Eğitim/mesleki bilgi | Fakülte, bölüm, sınıf, öğrenci/personel rolü |
| Görsel | Profil fotoğrafı; sohbet/gönderi fotoğrafları ve videoları |
| Kullanıcı içeriği | Mesajlar, topluluk gönderileri, etkinlik başvuru yanıtları, geri bildirim, destek ve itiraz metinleri, biyografi |
| Müşteri işlem / kullanım | Topluluk üyelikleri, etkinlik katılımı ve yoklama, favoriler, bildirim ve gizlilik tercihleri, engelleme listesi |
| İşlem güvenliği | Oturum bilgisi, şifre özeti, cihaz tanımlayıcısının geri döndürülemez özeti, IP adresi, platform ve uygulama sürümü, erişim engeli kayıtları, hata ve giriş denemeleri |
| Hukuki işlem / uyum | Sözleşme onay kayıtları, şikâyet/rapor ve moderasyon kayıtları, yönetici erişim kayıtları |
| Pazarlama | İşlenmez (reklam/pazarlama amacıyla işleme yapılmaz) |
| Özel nitelikli veri | Bilerek talep edilmez. Kullanıcı içeriği içinde (ör. mesajda) paylaşılan özel nitelikli veriler, yalnızca sizin paylaşımınız çerçevesinde barındırılır; bunları işlemeyi amaçlamayız. |

## 3. İşleme amaçları

1. Üyelik oluşturma, kimlik ve e-posta doğrulama, hesap güvenliği.
2. Haber, duyuru, etkinlik, yemek listesi, topluluk, etkinlik, yoklama, mesajlaşma, arama ve favori hizmetlerinin sunulması.
3. Bildirimlerin (uygulama içi, anlık, e-posta) gönderilmesi.
4. Destek, geri bildirim ve itiraz taleplerinin yürütülmesi.
5. Güvenlik, kötüye kullanımın ve yasaklı kullanıcı engelinin dolanılmasının önlenmesi, moderasyon.
6. Hizmetin iyileştirilmesi, hata ve performans takibi (toplulaştırılmış analiz).
7. Hukuki yükümlülüklerin yerine getirilmesi, yetkili makam taleplerinin karşılanması, hakların kullanılması ve savunulması.
8. Sözleşme ve rıza kayıtlarının tutulması.

## 4. Hukuki sebepler

| Hukuki sebep | Örnek işleme faaliyetleri |
|---|---|
| m.5/2-(a) Kanunlarda açıkça öngörülmesi | Yetkili makamlara bilgi verilmesi, mevzuatın zorunlu kıldığı kayıtlar |
| m.5/2-(c) Sözleşmenin kurulması veya ifası | Üyelik, profil, mesajlaşma, topluluk/etkinlik hizmetleri, bildirim ve e-posta gönderimi |
| m.5/2-(ç) Hukuki yükümlülüğün yerine getirilmesi | Sözleşme onay kayıtları, yasal talepler, ilgili mevzuat gereği saklama |
| m.5/2-(e) Bir hakkın tesisi, kullanılması veya korunması | Moderasyon izleri, itiraz ve uyuşmazlık için delil niteliğindeki kayıtlar |
| m.5/2-(f) Meşru menfaat (temel hak ve özgürlüklere zarar vermemek şartıyla) | Güvenlik, cihaz/IP kaydı, hız sınırlama, yönetici erişim denetimi, analitik |
| m.5/1 Açık rıza | Rehber eşleştirme, konum izni, anlık bildirim izni, isteğe bağlı profil alanlarının yayımı gibi **isteğe bağlı** işlemler |

(m.5/2-(ç) ve m.5/2-(e) bendleri ilgili işlemlerde birlikte dayanak olabilir.)

## 5. Kişisel verilerin aktarılması

| Alıcı grubu | Aktarılan veri | Amaç | Yurt içi / yurt dışı |
|---|---|---|---|
| Barındırma ve altyapı hizmet sağlayıcıları (veri işleyen) | Hizmet verisi (mesajlar şifreli) | Hizmetin barındırılması | {{hosting.location|Barındırma konumu veri sorumlusunca ayrıca bildirilir}} |
| E-posta gönderim altyapısı (veri işleyen) | Alıcı e-posta, e-posta içeriği | Doğrulama/şifre sıfırlama/güvenlik e-postaları | {{hosting.location|Sağlayıcının bulunduğu ülke}} |
| Google LLC (Firebase Cloud Messaging) ve iOS için Apple Inc. (APNs) | Cihaz bildirim anahtarı, bildirim başlığı/kısa metni, hedef bilgisi, platform | Anlık bildirim iletimi | **Yurt dışı** |
| Yetkili kamu kurum ve kuruluşları (mahkeme, savcılık, kolluk, Kurul vb.) | Talep kapsamındaki veri | Hukuki yükümlülük | Yurt içi |
| Bingöl Üniversitesi ilgili birimleri / yetkili yöneticiler | Moderasyon, destek ve güvenlik için gerekli veri | Hizmet yönetimi | Yurt içi |

**Yurt dışına aktarım (m.9).** Anlık bildirim için cihaz bildirim anahtarınız ve bildirim içeriği Firebase/APNs üzerinden yurt dışına aktarılır. Bu aktarım; Kanun'un 9. maddesi ve ilgili Kurul düzenlemeleri çerçevesinde, **bildirim iznine dayanan açık rızanıza** ve/veya yeterlilik/uygun güvence mekanizmalarına (standart sözleşme vb.) dayanır. Bildirim iznini vermemeniz halinde anlık bildirim almazsınız ancak uygulama içi bildirim kutusu ve diğer hizmetler çalışmaya devam eder. Rızanızı cihaz ayarlarından veya uygulamadaki İzinler/Bildirim ayarlarından istediğiniz zaman geri alabilirsiniz.

## 6. Kişisel verilerin toplanma yöntemi

Verileriniz; uygulama ve web sitesi üzerinden elektronik ortamda, kayıt/profil formları, mesajlaşma ve içerik paylaşımı, destek formları, cihazınızın teknik iletişimi (IP, cihaz özeti, uygulama sürümü), çerez benzeri yerel depolama ve (izin verirseniz) rehber eşleştirme isteği yoluyla otomatik ve kısmen otomatik yöntemlerle toplanır. Haber ve yemek listesi içerikleri kişisel veri içermeyen kamuya açık kaynaklardan derlenir.

## 7. Saklama süresi

Kişisel veriler, işleme amacı için gerekli süre ve ilgili mevzuatta öngörülen süre boyunca saklanır, süre bitiminde silinir, yok edilir veya anonim hale getirilir. Başlıca süreler: bekleyen kayıt 1 saat; doğrulama kodu 10 dakika; yenileme anahtarı en çok 30 gün; okunmuş bildirim 90 gün, okunmamış 365 gün; cihaz bildirim anahtarı 60 gün görülmezse; cihaz/IP güvenlik kayıtları 90 gün; analitik olaylar 180 gün; e-posta kuyruğu 30 gün; tek gönderimlik fotoğrafın şifreli kopyası 365 gün; herkese açık destek talebi 365 gün. Hesap açık olduğu sürece profil ve içerikleriniz saklanır; silinen mesajların şifreli kopyası ve sözleşme onay kayıtları güvenlik/ispat amacıyla ayrıca tutulabilir. Ayrıntılı tablo: [Saklama ve İmha](/legal/retention).

## 8. Mesajlara yönetici erişimi (şeffaflık notu)

Mesajlar sunucuda şifreli saklanır ancak sistem uçtan uca şifreli değildir. Yetkili yöneticiler, şikâyet incelemesi, güvenlik, kötüye kullanım ve yasal talepler gibi gerekçelerle mesajları ve medyayı görüntüleyebilir; her görüntüleme otomatik ve değiştirilemez biçimde kaydedilir. Bu işleme faaliyetinin hukuki sebebi meşru menfaat ve hukuki yükümlülüktür (m.5/2-(f), (ç), (e)); ayrıntı [Gizlilik Politikası](/legal/privacy) bölüm 3'tedir.

## 9. Otomatik karar verme

Hizmet, hakkınızda yalnızca otomatik işleme ile hukuki sonuç doğuran bir karar vermez. Aynı hesapla ilgili birden çok ihlal kaydı birikmesi halinde sistem yalnızca bir yöneticiye **öneri** üretir; askıya alma kararını bir yönetici verir. Hız sınırlama ve yasaklı içerik özeti kontrolü gibi otomatik güvenlik önlemleri vardır.

## 10. Haklarınız (m.11)

Veri sorumlusuna başvurarak şunları talep edebilirsiniz:

1. Kişisel verilerinizin işlenip işlenmediğini öğrenme,
2. İşlenmişse buna ilişkin bilgi talep etme,
3. İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme,
4. Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme,
5. Eksik veya yanlış işlenmişse düzeltilmesini isteme,
6. Kanun'un 7. maddesindeki şartlar çerçevesinde silinmesini veya yok edilmesini isteme,
7. (5) ve (6) kapsamındaki işlemlerin aktarıldığı üçüncü kişilere bildirilmesini isteme,
8. İşlenen verilerin münhasıran otomatik sistemler ile analiz edilmesi sonucu aleyhinize bir sonuç çıkmasına itiraz etme,
9. Kanuna aykırı işleme nedeniyle zarara uğramanız halinde zararın giderilmesini talep etme.

Uygulama içi kısa yollar: Profil düzenleme ve gizlilik ayarları (düzeltme/yayım kontrolü), **Verilerimi indir** (erişim/kopya), **Hesabı sil** (silme/anonimleştirme).

## 11. Başvuru yolu

1. **Uygulama içi:** Destek bölümünden "Kişisel veri başvurusu" konusuyla talep oluşturun (oturum açmış kullanıcının kimliği hesap üzerinden doğrulanır).
2. **Yazılı:** Islak imzalı dilekçe ile{{?controller.address}} {{controller.address}} adresine{{/controller.address}} elden veya noter vasıtasıyla.
{{?controller.kep}}3. **KEP:** {{controller.kep}} adresine güvenli elektronik imzalı başvuru.{{/controller.kep}}
{{?controller.email}}4. **E-posta:** {{controller.email}} adresine, kayıtlı kurumsal e-posta adresinizden.{{/controller.email}}

Başvurunuzda; ad-soyad, kimlik doğrulamaya yarayan bilgi (hesap e-postası), tebligat adresi, talep konusu belirtilmelidir. Kimliğinizi doğrulamak için ek bilgi isteyebiliriz. Başvurular talebin niteliğine göre **en geç 30 gün** içinde ücretsiz sonuçlandırılır; işlemin ayrıca bir maliyet gerektirmesi halinde Kurul'un belirlediği tarifedeki ücret alınabilir.

Başvurunun reddedilmesi, cevabın yetersiz bulunması veya süresinde cevap verilmemesi halinde, cevabı öğrendiğiniz tarihten itibaren 30 gün ve her halde başvuru tarihinden itibaren 60 gün içinde **Kişisel Verileri Koruma Kurulu'na şikâyet** hakkınız saklıdır.
