# Gizlilik Politikası

Bu politika, BÜ Kampüs uygulaması ve web sitesini kullanırken hangi verilerinizin işlendiğini, neden, ne kadar süre saklandığını ve haklarınızı sade bir dille anlatır. Hukuki çerçeve ve başvuru usulü için [KVKK Aydınlatma Metni](/legal/kvkk) ile birlikte okuyun.

Veri sorumlusu: {{controller.name}}{{?controller.address}}, {{controller.address}}{{/controller.address}}. İletişim: {{controller.email|uygulama içi Destek bölümü}}.

## 1. Kısaca

1. Verilerinizi **satmayız**, reklam amacıyla üçüncü kişilerle paylaşmayız.
2. Yalnızca hizmeti sunmak, güvenliği sağlamak ve yasal yükümlülükler için gerekli veriyi işleriz.
3. Konum ve rehber gibi isteğe bağlı izinler **açık rızanıza** bağlıdır ve istediğiniz zaman geri alınabilir ([Açık Rıza Metni](/legal/explicit-consent)).
4. Mesajlarınız sunucuda şifreli saklanır; ancak sistem **uçtan uca şifreli değildir** ve yetkili yöneticiler, kayda alınarak, gerekçeli durumlarda mesajları görüntüleyebilir.
5. Hesabınızı silerseniz kişisel verileriniz anonimleştirilir; bazı kayıtlar yasal sebeplerle ve başkalarının haklarını korumak için sınırlı şekilde kalır.

## 2. Hangi verileri işliyoruz?

| Veri | Neden | Hukuki sebep | Saklama süresi |
|---|---|---|---|
| **Hesap:** e-posta (bingol.edu.tr), ad-soyad, şifre (yalnızca tek yönlü özet olarak), dil tercihi | Üyelik, kimlik doğrulama, hizmetin sunulması | Sözleşmenin ifası (KVKK m.5/2-c) | Hesap açık olduğu sürece; silinince anonimleştirilir |
| **Profil:** fakülte, bölüm, sınıf, biyografi, profil fotoğrafı, gizlilik ayarlarınız | Profilinizin diğer kullanıcılara gösterilmesi (alan bazında gizlenebilir) | Sözleşmenin ifası; isteğe bağlı alanlarda açık rıza (m.5/1) | Hesap açık olduğu sürece |
| **Bekleyen kayıt ve doğrulama kodu:** e-posta, kodun özeti | E-posta doğrulaması | Sözleşme öncesi işlem / sözleşmenin ifası | Bekleyen kayıt 1 saat; doğrulama kodu 10 dakika |
| **Oturum:** yenileme anahtarının özeti, oturum durumu | Güvenli oturum yönetimi | Meşru menfaat (m.5/2-f) | Yenileme anahtarı en çok 30 gün; çıkışta/şifre değişiminde silinir |
| **Mesajlar:** metin, fotoğraf, video, düzenleme geçmişi, tepkiler, okundu bilgisi, sohbet ayarları (sessiz/arşiv) | Mesajlaşma hizmeti | Sözleşmenin ifası | Hesap açık olduğu sürece; silinen mesajların şifreli kopyası ve düzenleme geçmişi güvenlik amacıyla saklanır (varsayılan süresiz, ayarlanabilir) |
| **Tek gönderimlik fotoğraf:** şifreli dosya, açılma kaydı | Mesajlaşma ve güvenlik incelemesi | Sözleşmenin ifası; meşru menfaat | Alıcı erişimi bir kez / en çok 24 saat; şifreli kopya yönetici incelemesi için **365 gün** (ayarlanabilir) |
| **Topluluk ve etkinlik verileri:** üyelikler, gönderiler, RSVP, yoklama (QR/elle), başvuru yanıtları, etkinlik geri bildirimi | Topluluk ve etkinlik hizmetleri | Sözleşmenin ifası | Hesap açık olduğu sürece; yoklama/gönderi kayıtları anonim biçimde kalabilir |
| **Bildirim kutusu ve tercihler:** bildirim içerikleri, sessiz saatler, tür tercihleri | Bildirim hizmeti | Sözleşmenin ifası | Okunmuş bildirim 90 gün, okunmamış 365 gün sonra silinir |
| **Cihaz bildirim anahtarı (FCM):** anahtar, platform, uygulama sürümü, dil, son görülme | Anlık bildirim göndermek | Sözleşmenin ifası; açık rıza (bildirim izni) | 60 gün görülmeyen anahtar gece temizlenir; çıkışta/hesap silmede silinir |
| **Cihaz kimliği ve IP kayıtları:** cihaz tanımlayıcısının geri döndürülemez özeti (HMAC), platform, uygulama sürümü, IP adresi, son görülme ve olay türü (kayıt/giriş/istek) | Güvenlik, kötüye kullanım ve yasaklı kullanıcı engelinin dolanılmasını önleme | Meşru menfaat (m.5/2-f); hukuki yükümlülük (m.5/2-ç) | Varsayılan **90 gün**; engel kayıtları engel sürdükçe (bkz. 6) |
| **Kullanım olayları (analitik):** ekran adı, olay adı, sınırlı özellik değerleri, zaman; son görülme ve günlük aktiflik | Hizmeti iyileştirme, hata/performans takibi; raporlar toplulaştırılmıştır | Meşru menfaat (m.5/2-f) | Olaylar **180 gün** |
| **Destek, geri bildirim, itiraz, rapor:** metinleriniz ve iletişim e-postanız | Taleplerin yanıtlanması, moderasyon | Sözleşmenin ifası; meşru menfaat; hukuki yükümlülük | Hesap silinince metinler temizlenir, kayıt kimliksiz kalır; herkese açık (girişsiz) destek talepleri 365 gün |
| **Engelleme ve moderasyon kayıtları:** engellediğiniz kişiler, ihlal kayıtları, rapor kararları, yasak izleri | Güvenlik ve moderasyon | Meşru menfaat; hukuki yükümlülük | Moderasyon izi hesap silindikten sonra da kimliksiz tutulur |
| **Yönetici erişim ve işlem kayıtları** (mesaj görüntüleme kaydı dahil) | Hesap verebilirlik, yetkisiz erişimin önlenmesi | Meşru menfaat; hukuki yükümlülük | Değiştirilemez biçimde tutulur; yasal/denetim saklama süresi boyunca |
| **Sözleşme onayları:** belge türü, sürüm, zaman | Rızanın/onayın ispatı | Hukuki yükümlülük; meşru menfaat | Hesap silindikten sonra da saklanır |
| **E-posta kuyruğu:** alıcı, konu, gönderim durumu | Doğrulama/şifre sıfırlama/güvenlik e-postaları | Sözleşmenin ifası | Gönderilmiş veya başarısız kayıtlar 30 gün sonra silinir |
| **Rehber eşleştirme:** rehberinizdeki e-postaların SHA-256 özeti (yalnızca istek sırasında) | Rehberinizde tanıdıklarınızı bulmak | **Açık rıza** (m.5/1) | **Saklanmaz, kaydedilmez**; yalnızca isteğin işlenmesi süresince bellekte |
| **Yaklaşık konum izni** | Yakındaki etkinlik/duyuru özelliği için hazırlık | **Açık rıza** (m.5/1) | Mevcut sürümde konum sunucuya **gönderilmez ve saklanmaz** (bkz. 5) |

> **Özetle:** İşlediğimiz her veri bir amaca bağlıdır; çoğu hesabınız açık olduğu sürece tutulur. Cihaz/IP kayıtları 90 gün, analitik olaylar 180 gün, bildirimler 90/365 gün, e-posta kuyruğu 30 gün saklanır.

## 3. Mesajlarınız nasıl saklanır ve kim görebilir?

1. **İletim:** Mesajlar TLS/WSS ile şifreli iletilir.
2. **Saklama:** Sunucuda her sohbet için ayrı bir anahtarla AES-256-GCM ile şifreli saklanır. Anahtarlar ayrı bir ana anahtar ile korunur ve veritabanında değil sunucu ortamında tutulur. Bu, veritabanı yedeği ele geçirilse bile mesajların okunmasını zorlaştırır.
3. **Uçtan uca şifreleme DEĞİLDİR.** Ana anahtar bizde olduğundan, sistem mesajları çözebilir. Bunu bilerek kullanın.
4. **Yönetici erişimi:** Yalnızca yetkili yöneticiler; şikâyet incelemesi, güvenlik/kötüye kullanım, yasal talepler ve benzeri gerekçelerle, mesajların ve medyanın içeriğini görüntüleyebilir. Yönetici arayüzü; silinmiş, düzenlenmiş ve moderasyonla gizlenmiş mesajlar ile "tek gönderimlik" fotoğrafları ve engellenen kullanıcıya iletilmeyen mesajları da gösterebilir. **Her görüntüleme**, içerik gösterilmeden önce otomatik olarak değiştirilemez bir kayda yazılır: kim baktı, kimin sohbetine baktı, kaç mesaj, hangi IP'den, ne zaman. Kayıt yazılamazsa içerik gösterilmez.
5. **Silinen mesajlar:** "Herkes için sil" diğer kullanıcılar için mesajı gizler; mesajın şifreli kopyası ve eski sürümleri güvenlik incelemesi için saklanabilir. Saklama süresi işletici tarafından ayarlanır (varsayılan: süresiz).
6. **Tek gönderimlik fotoğraflar:** Alıcı bir kez görür, sonra erişimi kapanır; ancak yönetici incelemesi için şifreli dosya 365 gün (ayarlanabilir) saklanır ve sonra silinir. Ekran görüntüsünün engellenmesi için teknik önlemler olsa da mutlak garanti verilmez.
7. **Bildirim önizlemesi:** Varsayılan olarak anlık bildirimde mesaj metni gösterilmez (ayar açılırsa metin Google FCM/Apple APNs üzerinden geçer). Uygulama içi bildirim kutusuna mesaj içeriği hiçbir zaman yazılmaz.
8. **Fotoğraf ve video işleme:** Fotoğraflar türü/boyutu doğrulanıp yeniden kodlanır, EXIF (konum vb.) temizlenir. Videolar cihazınızda sıkıştırılır, sunucu yeniden kodlamaz. Görsellerin özeti, yasaklı içerik özet listesiyle karşılaştırılır; görsel içeriği otomatik analiz edilmez.
9. **Engelleme:** Engellediğiniz kişinin size yazdığı mesajlar size iletilmez; engellenen kişiye bildirim yapılmaz. Bu mesajlar sistemde kalır ve yalnızca yetkili yöneticilerce, şikâyet incelemesi gibi gerekçelerle görülebilir.

> **Özetle:** Mesajlar şifreli saklanır ama uçtan uca değil. Yetkili yöneticiler yalnızca gerekçeli durumda, her seferinde kayda alınarak görüntüleyebilir. Silinen mesajlar ve tek gönderimlik fotoğrafların şifreli kopyası güvenlik için bir süre saklanabilir.

## 4. Verilerinizi kimlerle paylaşırız?

| Alıcı | Ne paylaşılır? | Amaç | Konum |
|---|---|---|---|
| **Google Firebase Cloud Messaging (FCM)** (ve iOS için Apple APNs) | Cihaz bildirim anahtarı, bildirim başlığı/kısa metni, hedef bilgisi | Anlık bildirim iletimi | Yurt dışı (Google/Apple altyapısı); bkz. KVKK Aydınlatma Metni |
| **E-posta (SMTP) altyapısı** | Alıcı e-posta adresi, e-posta içeriği (doğrulama kodu vb.) | Doğrulama, şifre sıfırlama ve güvenlik e-postaları | {{hosting.location|Barındırma ve e-posta sağlayıcısının bulunduğu ülke}} |
| **Barındırma / sunucu sağlayıcısı** | Tüm hizmet verisi (şifreli mesajlar dahil) | Hizmetin barındırılması | {{hosting.location|Barındırma konumu yayın öncesi belirtilir}} |
| **Yetkili kamu kurumları** (mahkeme, savcılık, kolluk, KVKK Kurulu vb.) | Talep kapsamındaki veri | Hukuki yükümlülük | Yurt içi |
| **Üniversite yönetimi / yetkili yöneticiler** | Moderasyon ve destek için gerekli veri | Hizmetin yönetimi, güvenlik | Yurt içi |

Reklam ağları, veri komisyoncuları veya sosyal medya takip araçlarıyla veri paylaşmayız.

## 5. İzinler ve isteğe bağlı özellikler

1. **Bildirim izni:** İsterseniz anlık bildirim alırsınız. Reddederseniz uygulama içi bildirim kutusu çalışmaya devam eder. Bildirim türlerini ve **sessiz saatleri** ayarlardan yönetirsiniz.
2. **Rehber eşleştirme:** Rehber erişimi izni verirseniz, tanıdıklarınızı bulmak için rehberinizdeki e-posta adreslerinin **yalnızca SHA-256 özeti** (en çok 500 adet / istek) sunucuya gönderilir. Özetler **saklanmaz ve kayda geçirilmez**; yalnızca eşleşen kullanıcılar (gizlilik ayarlarına saygı gösterilerek) cevap olarak size döner. Rehber isimleriniz, telefon numaralarınız sunucuya gönderilmez. Kötüye kullanım için saatlik istek sınırı vardır.
3. **Konum:** Uygulama "yaklaşık konum" izni isteyebilir (yakındaki etkinlik ve duyuruları göstermek için). **Mevcut sürümde konum bilginiz sunucuya gönderilmez ve saklanmaz.** Gelecekte konumun sunucuda işlenmesi gerekirse bu metin güncellenir ve yeniden açık rızanız alınır.
4. İzinleri istediğiniz an cihaz ayarlarından veya uygulamadaki İzinler ekranından geri alabilirsiniz. Geri alma, geri alma anından önceki işlemlerin hukuka uygunluğunu etkilemez.

## 6. Cihaz ve IP kayıtları, erişim engelleri

1. Güvenlik amacıyla; kayıt, giriş, oturum yenileme ve istekler sırasında cihaz tanımlayıcınızın geri döndürülemez özeti, platform, uygulama sürümü, IP adresi ve zaman bilgisi kaydedilir. Ham cihaz tanımlayıcısı saklanmaz.
2. Bu kayıtlar varsayılan **90 gün** saklanır ve gecelik olarak temizlenir. Süre işletici tarafından ayarlanabilir; yasal bir saklama yükümlülüğü doğarsa (ör. 5651 sayılı Kanun kapsamında trafik bilgisi) süre buna göre belirlenebilir ve bu politika güncellenir.
3. Kötüye kullanım nedeniyle yasaklanan bir kullanıcının IP adresi, ağ aralığı, cihaz özeti veya kullanıcı kimliği için **erişim engeli** tanımlanabilir. Engel kaydı (neden kodu, tarih, varsa süre ve notlar) engel sürdükçe ve itiraz/denetim için gerekli süre boyunca saklanır. Engele takılan denemeler (IP, cihaz özeti, istek yolu, zaman) güvenlik kaydı olarak tutulur ve cihaz/IP kayıtlarıyla aynı temizleme ilkesine tabidir. VPN/Tor/veri merkezi gibi anonimleştirici aralıklardan gelen istekler güvenlik amacıyla kısıtlanabilir.
4. Engellendiğinizi düşünüyorsanız Destek bölümünden veya itiraz özelliğinden başvurabilirsiniz.

## 7. Hesap silme ve veri taşınabilirliği

**Verilerimi indir:** Profil > Verilerimi indir ile kendi verilerinizi (günde 3 kez sınırla) JSON olarak indirebilirsiniz. Silinmiş mesajlar çıktıya dahil değildir.

**Hesap silme = anonimleştirme.** Hesabınızı sildiğinizde:

| Ne olur? | Hangi veriler |
|---|---|
| **Silinir** | Bildirim cihaz anahtarlarınız, bildirim kutunuz ve tercihleriniz, favori haberleriniz, geri bildirim oylarınız, etkinlik geri bildirimleriniz, engelleme listeniz, kulüp başvuru yanıtlarınız, topluluk üyelikleriniz (sahiplik devri yapılmadan sahip satırı silinmez), yüklediğiniz sohbet fotoğrafları |
| **Anonimleştirilir** | Ad, e-posta, profil bilgileri, biyografi, fotoğraf; destek, geri bildirim, itiraz, rapor ve etkinlik başvurusu metinleri temizlenir (kayıt kimliksiz kalır) |
| **Korunur (sınırlı)** | Gönderdiğiniz mesajlar ve topluluk gönderileri (başkalarının sohbet bağlamının parçası; yazar "Silinmiş kullanıcı" gibi anonim görünür); sözleşme onay kayıtları (hukuki kanıt); moderasyon ihlal/rapor ve yasak izleri; anonim yoklama/RSVP sayaçları; yönetici işlem ve erişim kayıtları |
| **Süreyle temizlenir** | Cihaz/IP kayıtları (90 gün), analitik olaylar (180 gün), e-posta kuyruğu (30 gün) |

> **Özetle:** Hesabınızı silince kimliğiniz çıkar, kişisel veriniz silinir veya anonimleşir. Başkalarının haklarını ve yasal delil/güvenlik ihtiyacını korumak için bazı kayıtlar kimliksiz ve sınırlı olarak kalır.

## 8. Güvenlik önlemleri

1. Şifreler tek yönlü özet olarak saklanır; doğrulama kodları ve yenileme anahtarları özet olarak tutulur.
2. Erişim anahtarı 15 dakikalıdır; yenileme anahtarı tek kullanımlıktır; şifre değişiminde tüm oturumlar kapanır.
3. Giriş, kayıt, doğrulama ve yazma işlemlerinde hız sınırı uygulanır; kullanıcı varlığını sızdırmayan genel yanıtlar verilir.
4. Mesajlar şifreli saklanır; yönetici erişimi kayıt altındadır; yönetim paneli yalnızca yönetici rolüyle çalışır.
5. Yüklenen dosyalar tür/boyut doğrulanır, dosya adları sunucuda üretilir.
6. Hiçbir sistem mutlak güvenli değildir. Bir veri ihlali olursa mevzuata uygun şekilde Kurul'a ve etkilenen kişilere bildirim yaparız.

## 9. Çerezler ve yerel depolama

Web sitesinde **izleme/reklam çerezi kullanılmaz**. Yalnızca dil/tema tercihiniz ve oturum bilgisi gibi zorunlu yerel depolama kullanılır. Ayrıntı için [Çerez ve Yerel Depolama Politikası](/legal/cookies).

## 10. Çocukların verileri

Hizmet 18 yaşından küçükler için tasarlanmamıştır; yalnızca üniversite öğrenci/personel e-postasıyla kayıt olunur. 18 yaşından küçük bir kullanıcının kaydı tespit edilirse yasal temsilcinin bilgisi ve onayı aranabilir; gerekirse hesap kapatılır ve veriler silinir/anonimleştirilir.

## 11. Haklarınız

KVKK m.11 uyarınca verilerinize erişme, düzeltme, silme, itiraz ve diğer haklarınız vardır. Başvuru yolları ve 30 gün yanıt süresi [KVKK Aydınlatma Metni](/legal/kvkk) ve [Saklama ve İmha](/legal/retention) metinlerindedir. Hızlı yollar: Profil bilgilerini düzenleme, gizlilik ayarları, Verilerimi indir, Hesabı sil, Destek bölümü.

## 12. Değişiklikler

Bu politikayı güncelleyebiliriz. Önemli değişikliklerde sizden yeniden onay alırız; güncel sürüm ve geçmiş bu sayfada yer alır.

## 13. İletişim

{{support.email|Uygulama içi Destek bölümü}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}
