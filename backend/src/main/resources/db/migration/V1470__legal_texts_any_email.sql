-- V1470: Hukuki metinler 5. tur (docs/legal/*.md'den scripts/build-legal-migration-v1470.js ile URETILDI; elle duzenlemeyin).
-- * TERMS, PRIVACY ve KVKK icin yeni surum (COALESCE(MAX(version),0)+1) tr+en+ar ayni numarayla aktif eklenir, onceki aktif
--   surumler pasife alinir (eski surumler ve kayitli onaylar DEGISMEZ). Diger turler degismedi.
-- * Icerik: "yalniz bingol.edu.tr e-postasiyla kayit" kisiti kaldirildi (herhangi bir gecerli e-posta + e-posta dogrulama kodu;
--   uyelik bagi dogrulanmaz); Gizlilik/KVKK'ya istege bagli Google/Apple ile giris veri kategorisi eklendi; alan adi denetimi ve
--   "kurumsal e-posta" ifadeleri duzeltildi; EN ve AR metinler TR ile madde madde esit.
-- * require_reaccept = FALSE (uc tur). Gerekce: docs/LEGAL_NOTES.md bolum 14.

DO $do_terms$
DECLARE
    v INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = 'TERMS';
    UPDATE legal_document SET active = FALSE WHERE type = 'TERMS' AND active;
    INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
    ('TERMS', 'tr', v, $t_terms_tr$Kullanım Koşulları$t_terms_tr$, $c_terms_tr$Bu metin, BÜ Kampüs uygulaması ve web sitesinin ("**Hizmet**") nasıl kullanılacağını, sizin ve bizim hak ve sorumluluklarımızı açıklar. Lütfen dikkatle okuyun. Kayıt sırasında bu koşulları kabul etmeniz istenir; kabulünüz (belge sürümü ve tarihiyle) kaydedilir.

## 1. Taraflar ve kapsam

1. Hizmeti işleten: {{controller.name}}{{?controller.address}}, {{controller.address}}{{/controller.address}} ("**İşletici**", "**biz**").
2. Hizmeti kullanan kişi ("**Kullanıcı**", "**siz**"), bu koşulları kabul etmiş sayılır.
3. Hizmet; haber, duyuru ve etkinlik takibi, yemek listesi, profil, mesajlaşma, topluluklar ve etkinlikler (QR ile yoklama dahil), gönderiler (tek bir fotoğraf ve kısa bir metinden oluşur, beğenilebilir), kullanıcı takibi, anketler, kişisel ders programı ve sınav takibi, bildirimler, arama, favoriler ile destek ve geri bildirim özelliklerinden oluşur.
4. **Yöneticiler.** Hizmetin yönetim paneline erişimi İşletici tarafından tanımlanan hesaplar ("**yönetici**") moderasyon, destek, içerik ve sistem işlerini yürütür. Yöneticiler üniversite adına değil, İşleticinin yetkilendirmesiyle çalışır; kullanıcı verileri üniversiteye aktarılmaz. Yönetici yetkileri 6. bölümde açıklanmıştır. Topluluk/kulüp yöneticileri ise 7. bölümdeki kullanıcı rolleridir ve yönetim paneli yöneticilerinden ayrıdır.
5. Bu koşullar; [Gizlilik Politikası](/legal/privacy), [KVKK Aydınlatma Metni](/legal/kvkk), [Topluluk Kuralları](/legal/community-rules), [Açık Rıza Metni](/legal/explicit-consent), [Çerez ve Yerel Depolama Politikası](/legal/cookies), [İçerik Bildirimi ve Kaldırma](/legal/content-removal) ve [Saklama ve İmha](/legal/retention) metinleriyle birlikte okunur. Topluluk Kuralları bu koşulların ayrılmaz parçasıdır.

> **Özetle:** Hizmeti kullanmak için bu koşulları, Gizlilik Politikasını, KVKK Aydınlatma Metnini ve Topluluk Kurallarını kabul edersiniz. Diğer metinler bilgilendirme veya isteğe bağlı izinler içindir.

## 2. Hesap ve uygunluk

1. **Kimler kayıt olabilir?** Hizmet, Bingöl Üniversitesi topluluğuna yönelik hazırlanmıştır; ancak kayıt için `bingol.edu.tr` uzantılı e-posta adresi zorunlu değildir. Gmail, Outlook, Hotmail, Yahoo gibi sağlayıcıların adresleri ile okul veya kurum e-postaları dahil, size ait geçerli herhangi bir e-posta adresiyle kayıt olabilirsiniz. Hesap, yalnızca e-posta adresinize gönderilen 6 haneli doğrulama kodunu girdiğinizde etkinleşir; kodu girmeden hesap açılmaz. Doğrulama kodu 10 dakika geçerlidir ve sınırlı sayıda deneme hakkı vardır. Kayıt için kullandığınız e-posta adresi üniversiteyle bağlantınızı doğrulamaz; bölüm, fakülte ve sınıf gibi bilgiler profilde sizin beyan ettiğiniz bilgilerdir.
2. **Bilgilerin doğruluğu.** Hesap bilgilerinizin doğru olmasından ve şifrenizin güvenliğinden siz sorumlusunuz. Şifrenizi kimseyle paylaşmayın. Hesabınızın izinsiz kullanıldığını fark ederseniz derhal Destek bölümünden bize bildirin; "tüm oturumları kapat" seçeneğini kullanabilirsiniz.
3. **Hesap devredilemez.** Hesabınızı başkasına devredemez, satamaz veya paylaşamazsınız. Bir kişi birden fazla hesabı kötüye kullanım amacıyla açamaz.
4. **Yaş.** Hizmet üniversite topluluğuna yöneliktir; 18 yaşından küçük kullanıcılara özel olarak yönelik değildir. 18 yaşından küçük bir öğrenci kullanıyorsa, yasal temsilcisinin bilgisi ve izni dahilinde kullanması esastır; bu durumda ilgili kişisel verilerin işlenmesine ilişkin yasal temsilcinin onayı gerekebilir. Bu durumu fark ettiğimiz hesaplarda ek doğrulama isteyebiliriz.
5. **Tek cihaz kuralı (mobil).** Güvenliğiniz için mobil uygulamada aynı anda tek oturum açık kalır: başka bir mobil cihazdan giriş yaptığınızda önceki mobil oturumlarınız sonlandırılır ve önceki cihaza "yeni cihazdan giriş" uyarısı e-postası gönderilebilir. Web üzerindeki oturumlar bu kuraldan etkilenmez.
6. **Oturum süresi.** Erişim anahtarınız kısa ömürlüdür (15 dakika) ve otomatik yenilenir; yenileme anahtarı en çok 30 gün geçerlidir ve tek kullanımlıktır. Şifre sıfırlandığında tüm oturumlarınız kapatılır.

> **Özetle:** Herhangi bir geçerli e-posta adresiyle (bingol.edu.tr zorunlu değildir) kayıt olur, adresinize gelen kodla doğrularsınız. Hesap size aittir ve devredilemez. Mobilde aynı anda tek cihazda oturum açık kalır.

## 3. Kullanıcı içerikleri ve lisans

1. **İçeriğin sahibi sizsiniz.** Mesaj, fotoğraf, video, topluluk gönderisi, etkinlik, profil bilgisi, geri bildirim gibi paylaştığınız içeriklerin ("**Kullanıcı İçeriği**") hakları size aittir. İçeriklerin hukuka uygunluğundan siz sorumlusunuz.
2. **Bize verdiğiniz sınırlı lisans.** Hizmeti sunabilmemiz için, Kullanıcı İçeriğinizi yalnızca şu amaçlarla barındırma, saklama, şifreleme, yeniden boyutlandırma/yeniden kodlama, iletme, görüntüleme ve (içeriği gönderdiğiniz kişi ve topluluklara) sunma konusunda; münhasır olmayan, devredilemez, ücretsiz, dünya çapında ve Hizmet süresiyle sınırlı bir lisans vermiş olursunuz. İçeriğinizi reklam amacıyla kullanmayız, üçüncü kişilere satmayız.
3. **Medyanın işlenmesi.** Yüklenen fotoğraflar (profil, kapak, gönderi, sohbet) türü ve boyutu doğrulandıktan sonra yeniden kodlanır; konum gibi gömülü üst veriler (EXIF) temizlenir. Sohbet fotoğrafları en çok 1600 piksel kenar uzunluğuna indirilir; mesaj başına en çok 10 ek (fotoğraf/video karışık) gönderilebilir. Bir gönderi tek bir fotoğraf ve en çok 7 kelimelik kısa bir metinden oluşur. **Sohbet videoları** cihazınızda sıkıştırılır; sunucu bunları yeniden kodlamaz ve **video dosyasının içindeki üst verileri (örneğin çekim zamanı veya konum etiketi) temizlemez**: sunucu yalnızca dosya türünü, boyutunu ve süresini doğrular ve videoyu şifreli saklar. Cihazınızın sıkıştırması bu üst verileri kaldırmayabilir; konum veya kişisel bilgi içerebilecek videoları göndermeden önce dikkatli olun. Videonun kapak (önizleme) görseli ise fotoğraf gibi yeniden kodlanır ve üst verisi temizlenir. Sohbet videoları en çok 60 saniye ve 40 MB'a kadar kabul edilir; günlük/saatlik yükleme sınırları vardır. Bu sınırlar değişebilir. Tek gönderimlik gösterim yalnızca fotoğraflar için kullanılabilir.
4. **Yasaklı içerik kontrolü.** Yüklenen görsellerin dijital özeti (SHA-256), yetkili yöneticilerin yönettiği "yasaklı içerik" özet listesiyle karşılaştırılır. Eşleşme halinde yükleme reddedilir. Bu kontrol yalnızca özet karşılaştırmasıdır; görsellerin içeriği otomatik olarak analiz edilmez.
5. **Gönderiler.** Gönderilerinizin içeriğinden ve üçüncü kişilere ait hak ve verilerin (örneğin başkasının fotoğrafının) ihlal edilmemesinden siz sorumlusunuz. Gönderiler uygulamaya giriş yapmış diğer kullanıcılara gösterilir ve beğenilebilir. İçerikler yayımlanmadan önce insan denetiminden geçmez; bu nedenle işletici yer sağlayıcı olarak hukuka aykırı içeriği bildirim üzerine kaldırır. Herhangi bir gönderi **Bildir** ile şikâyet edilebilir; yetkili yöneticiler inceler, içeriği gizleyebilir/kaldırabilir, uyarı veya hesap kısıtlaması uygulayabilir. Karara itiraz edebilirsiniz (bkz. 5. bölüm ve [İçerik Bildirimi ve Kaldırma](/legal/content-removal)).
6. **Lisansın sona ermesi.** İçeriğinizi sildiğinizde veya hesabınızı kapattığınızda lisans, 6. bölüm ve Gizlilik Politikası'nda açıklanan istisnalar (örneğin başkalarının sohbet geçmişi, yasal saklama ve güvenlik kayıtları) saklı kalmak üzere sona erer.

> **Özetle:** İçerik sizindir; biz yalnızca Hizmeti sunmak için sınırlı olarak saklar ve işleriz. Reklam için kullanmayız ve satmayız.

## 4. Yasaklı davranışlar

Aşağıdakileri yapmak yasaktır (ayrıntılı örnekler [Topluluk Kuralları](/legal/community-rules) metnindedir):

1. Hukuka aykırı, tehdit, taciz, şantaj, nefret söylemi, ayrımcılık, müstehcen veya şiddet içeren içerik paylaşmak.
2. Başkasının kimliğini taklit etmek; yanıltıcı hesap, topluluk veya etkinlik açmak.
3. Başkalarının kişisel verilerini veya özel yazışmalarını rızası olmadan paylaşmak.
4. Spam, zincir mesaj, izinsiz reklam veya dolandırıcılık girişimi.
5. Hizmeti bozmak: otomatik araçlarla toplu istek, güvenlik açığı sömürme, yetkisiz erişim, hız sınırlarını aşma girişimi, yasaklı IP/cihaz engelini dolanmak (VPN, hesap değiştirme vb.).
6. Kullanıcı rehberini toplu taramak veya kullanıcı bilgilerini sistematik olarak toplamak.
7. Ders ve sınav dürüstlüğünü ihlal etmek (ör. sınav sorusu satışı, kopya organizasyonu).
8. Etkinlik yoklama (QR) sistemini kötüye kullanmak: başkası adına yoklama vermek, kodu paylaşmak/çoğaltmak.
9. Fikri mülkiyet haklarını ihlal etmek (bkz. 8. bölüm).
10. Topluluk, etkinlik, profil, grup başlığı ve gönderi metni gibi herkese açık alanlarda küfür, hakaret, nefret söylemi veya cinsel içerikli ifadeler kullanmak. Bu tür içerik otomatik olarak reddedilebilir. Özel sohbetlerde ve grup mesajlarında içerik ön denetimden geçirilmez; ancak taciz, tehdit veya uygunsuz içerik kullanıcılar tarafından şikâyet edilebilir ve uygulama içi şikâyet/geri bildirim kanalıyla incelenerek içerik kaldırma, uyarı veya hesap kısıtlaması uygulanabilir.

## 5. Moderasyon, askıya alma ve engelleme

1. **Bildirme.** Her kullanıcı kullanıcıları, mesajları, gönderileri, toplulukları ve etkinlikleri "Bildir" ile raporlayabilir. Kötüye kullanımı önlemek için rapor sayısı sınırlıdır; art niyetli veya tekrarlı asılsız raporlar rapor kısıtlamasına yol açabilir.
2. **İnceleme.** Raporlar yetkili yöneticiler tarafından incelenir. İnceleme sırasında raporla ilgili içerik ve ilişkili sohbet bağlamı görülebilir (bkz. 6. bölüm).
3. **Yaptırım basamakları.** Duruma göre: (a) içeriğin kaldırılması veya gizlenmesi (aynı içerik birbirinden bağımsız birkaç hesap tarafından bildirilirse, inceleme tamamlanana kadar otomatik ve geçici olarak gizlenebilir; yönetici incelemesi sonucunda yeniden görünür kılınabilir); (b) uyarı/bildirim; (c) ihlal kaydı (aynı kullanıcı için 180 günlük pencerede çözülmüş 3 ihlal yöneticiye askıya alma önerisi doğurur; eşik ayarlanabilir); (d) geçici askıya alma; (e) kalıcı hesap kapatma; (f) gerekirse IP, ağ aralığı, cihaz veya kullanıcı bazlı erişim engeli. Ağır ihlallerde (ör. çocuk istismarı, terör, tehdit) basamaklar atlanabilir ve yetkili makamlara bildirim yapılabilir.
4. **Erişim engeli (cihaz ve IP).** Güvenlik ve kötüye kullanımın önlenmesi amacıyla giriş/kayıt/istek sırasında IP adresiniz ve cihaz tanımlayıcınızın (geri döndürülemez özet olarak saklanan) kaydı tutulur; yasaklı bir kullanıcının hesabı, cihazı veya IP adresiyle eşleşen yeni hesap/oturum engellenebilir. Anonimleştirici ağlardan (ör. VPN, Tor, veri merkezi aralıkları) gelen istekler de güvenlik amacıyla engellenebilir. Ayrıntı Gizlilik Politikası'ndadır.
5. **Bildirim ve itiraz.** Askıya alma veya içerik kaldırma kararlarında mümkün olduğunca size uygulama içi bildirim yapılır. Karara itiraz için uygulamadaki **itiraz** özelliğini veya Destek bölümünü kullanabilirsiniz; itirazlar bir yönetici tarafından yeniden değerlendirilir ve sonuç size bildirilir. Hesap güvenliğini doğrudan tehdit eden acil durumlarda önlem, itirazdan önce uygulanabilir.
6. **Kullanıcı engellemesi.** Dilediğiniz kullanıcıyı engelleyebilirsiniz. Engelleme gizlilik içindir: engellediğiniz kişinin size gönderdiği mesajlar size iletilmez (geçmişte, bildirimde veya okunmamış sayacında görünmez); engellenen kişiye engellendiğini bildiren bir uyarı gösterilmez. Engel sonradan kaldırılsa bile engel sırasında gönderilmiş mesajlar size iletilmez. Bu mesajlar sistemde kalır; yetkili yöneticiler şikâyet incelemesi sırasında bu mesajları görebilir. Gruplarda engellediğiniz kişinin mesajları sizin için gizlenir, diğer üyeler normal görür.

> **Özetle:** Kurallara aykırı içerik kaldırılabilir, hesap askıya alınabilir veya kapatılabilir; cihaz/IP engeli uygulanabilir. Karara uygulama içinden itiraz edebilirsiniz.

## 6. Mesajlaşma ve yönetici erişimi

Bu bölüm, mesajlarınızın sizinle karşı taraf arasında "tamamen gizli" olmadığını açıkça belirtir. Lütfen dikkatle okuyun.

1. **Şifreleme türü.** Mesajlar iletim sırasında şifrelidir (TLS/WSS) ve sunucuda şifreli (AES-256-GCM) saklanır. Sistem **uçtan uca şifreli değildir**: şifre çözme anahtarları sunucu tarafında tutulur; yetkili yöneticiler gerektiğinde mesajları görüntüleyebilir. Mesajlarınızı kimsenin okuyamayacağı yönünde bir taahhüdümüz yoktur.
2. **Yönetici rolleri ve yetkileri.** Yönetici hesaplarına İşleticinin tanımladığı beş rolden biri verilir: *tam yönetici* (tüm yönetim işlemleri), *moderatör* (moderasyon, rapor incelemesi, mesaj ve sohbet müdahalesi, kullanıcı bilgileri), *destek* (destek talepleri ve geri bildirimler; kullanıcı bilgileri maskeli), *editör* (haber, duyuru ve iletişim içeriklerinin yönetimi) ve *salt okunur* (yalnızca izleme; e-posta/IP gibi kişisel alanlar maskeli). **Özel yazışmaların içeriğine yalnızca tam yönetici ve moderatör rolündeki yöneticiler erişebilir;** diğer roller ve yönetici olmayan hiçbir kullanıcı erişemez. Rol değişiklikleri denetim kaydına yazılır.
3. **Yönetici müdahaleleri.** Yetkili yöneticiler; kurallara aykırı veya şikâyet edilen bir mesajı gizleyebilir (geri alınabilir) ya da kalıcı silebilir, sohbeti kapatabilir veya yeniden açabilir, bir üyeyi sohbetten çıkarabilir, gönderi ve diğer içerikleri gizleyebilir veya kaldırabilir, kuralları ihlal eden bir topluluğu kapatabilir. Bu işlemlerde yönetici yazılı bir gerekçe girmek zorundadır; işlem, gerekçe, yönetici ve zaman denetim kaydına yazılır ve ilgili kullanıcıya uygulama içi bildirim yapılabilir.
4. **Yönetici erişimi ne zaman?** Mesaj içeriğine yalnızca şikâyet ve rapor incelemesi, hesap güvenliği, kötüye kullanım ve yasa dışı faaliyet şüphesi, mahkeme/savcılık/kolluk gibi yetkili makam talepleri veya kullanıcının kendi başvurusu gibi gerekçelerle erişilir. Yönetim paneli teknik olarak bir kullanıcının üyesi olduğu veya olmuş olduğu sohbetleri (silinmiş, düzenlenmiş ve gizlenmiş mesajlar dahil) listeleyebildiğinden, bu yetki yalnızca sayılan gerekçelerle ve her seferinde yazılı gerekçeyle kullanılır. Meraktan veya amaç dışı görüntüleme yasaktır; yöneticilerin gizlilik yükümlülüğüne uyması esastır.
5. **Denetim.** Yöneticinin mesaj içeriğini görüntülemesi için yazılı bir gerekçe girmesi zorunludur (en az 10 karakter; hukuki talep üzerine sohbet dışa aktarımında en az 20 karakter ve ayrıca ikinci bir onay adımı). Görüntüleme, içerik gösterilmeden önce otomatik olarak değiştirilemez bir erişim kaydına yazılır (yönetici, görüntülenen kullanıcı, sohbet, kaç mesaj, gerekçe, IP adresi, zaman). Kayıt yazılamazsa içerik gösterilmez. Erişim kayıtları hukuki ve güvenlik denetimi amacıyla 730 gün saklanır ve sonra silinir.
6. **Silinen ve düzenlenen mesajlar.** "Herkes için sil" dediğinizde mesaj diğer kullanıcılara "Bu mesaj silindi" olarak görünür; ancak mesajın şifreli kopyası, düzenleme geçmişi ve ekleri güvenlik ve şikâyet incelemesi için sunucuda saklanmaya devam edebilir (varsayılan: süresiz; işletici bir saklama süresi belirlediğinde bu sürenin sonunda kalıcı silinir). Düzenlediğiniz mesajların önceki sürümleri de şifreli olarak saklanır. Kullanıcı arayüzünde silinmiş mesajı bir daha göremezsiniz; "verilerimi indir" çıktısına silinmiş mesajlar dahil edilmez.
7. **Tek gönderimlik fotoğraf.** Bu özellikte alıcı fotoğrafı yalnızca bir kez açabilir; açtıktan sonra (veya gönderimden 24 saat sonra) alıcının erişimi kapanır ve gönderen kendi gönderdiğini yeniden açamaz. Ancak güvenlik ve şikâyet incelemesi için, yetkili yöneticilerin inceleyebilmesi amacıyla fotoğraf dosyası **şifreli olarak sunucuda 365 gün** (ayarlanabilir süre) saklanır ve sonra silinir. Cihazda ekran görüntüsü alınmasına teknik engeller konulsa da **ekran görüntüsü veya ekran kaydı alınmayacağı garanti edilmez**; alıcı başka bir cihazla fotoğraf çekebilir. Bu nedenle, başkasının eline geçmesini istemediğiniz görselleri göndermeyin.
8. **Bildirim önizlemesi.** Varsayılan olarak anlık bildirimlerde mesaj metni yer almaz; "Yeni mesajınız var" türünde genel bir bildirim gönderilir.
9. **Hesap silindiğinde sohbetler.** Hesabınızı sildiğinizde gönderdiğiniz mesajlar karşı tarafın sohbet geçmişinin parçası olduğundan silinmez; yazar adı anonim görünür. Hesabın yüklediği sohbet fotoğrafları silinir.

> **Özetle:** Mesajlar şifreli saklanır ama uçtan uca şifreli değildir. Yetkili yöneticiler yalnızca gerekçeli durumlarda görüntüleyebilir ve her erişim kayda geçer. Silinen mesajların ve tek gönderimlik fotoğrafların şifreli kopyası güvenlik amacıyla bir süre saklanabilir. Ekran görüntüsüne karşı mutlak garanti verilmez.

## 7. Topluluklar ve etkinlikler

1. **Topluluk/kulüp yöneticileri**, kendi topluluklarındaki içerik ve üyelerden sorumludur; Topluluk Kurallarına ve bu koşullara uymak zorundadır. Yöneticilik yetkileri devredilebilir; yetki devrinde sistem onay adımları uygulayabilir. **Kulüp sahibi hesabını silerse** sahiplik, kulübün en eski aktif yönetici (yoksa moderatör) üyesine otomatik devredilir ve yeni sahibe bildirim gider; devralabilecek kimse yoksa kulüp kapatılır, üyelere bildirilir ve kulübe bağlı gelecek etkinlikler iptal edilir. Hizmet yöneticileri de kuralları ihlal eden bir kulübü gerekçeli olarak kapatabilir, yeniden açabilir veya sahipliğini devredebilir.
2. **Etkinlik oluşturanlar** etkinlik bilgilerinin doğruluğundan ve etkinliğin hukuka uygunluğundan sorumludur. Etkinlik yoklaması QR kod veya elle yoklama ile yapılır; yoklama kayıtları etkinlik organizatörüne ve yetkili yöneticilere görünür. Etkinliği oluşturan hesabını silerse, kulübe bağlı olmayan ve bitmemiş etkinlikleri iptal edilir ve açık başvurular kapatılır.
3. **Sohbet odaları.** Topluluk ve etkinlikler için oluşturulan sohbet odalarına katılımınız üyeliğinize bağlıdır; topluluktan çıkarıldığınız veya yasaklandığınızda odadan da düşürülürsünüz. Etkinlik sohbet odaları, etkinlik bittikten sonra varsayılan olarak 7 gün içinde kapanır.
4. İşletici, üniversite birimleri veya topluluklar tarafından düzenlenen etkinliklerin sorumluluğunu, açıkça belirtilmedikçe üstlenmez; etkinliklerin fiziksel güvenliği, içeriği ve iptali organizatörün sorumluluğundadır.

## 8. Fikri mülkiyet ve telif

1. Uygulamanın yazılımı, tasarımı, logosu ve markası ile sunduğumuz özgün içerikler işleticiye veya lisans verenlerine aittir. Yazılımı kopyalayamaz, tersine mühendislik yapamaz veya izinsiz dağıtamazsınız.
2. Başkasına ait telifli içerik paylaşmayın. Telif hakkınızın ihlal edildiğini düşünüyorsanız [İçerik Bildirimi ve Kaldırma](/legal/content-removal) metnindeki usulle başvurun; haklı bildirimlerde içerik kaldırılır, tekrar eden ihlallerde hesap kapatılabilir.
3. "Bingöl Üniversitesi" adı ve logosu ilgili kuruma aittir; Hizmetteki kullanımı bu koşulların sağladığı kullanım hakkı dışında bir hak doğurmaz.

## 9. Kaynak içerikler (haber, duyuru, etkinlik, yemek listesi)

1. Haber, duyuru, etkinlik ve yemek listesi bilgileri Bingöl Üniversitesi'nin resmî internet sitelerinden (bingol.edu.tr ve sks.bingol.edu.tr) derlenerek sunulur. Bu içeriklerin hakları ilgili kuruma aittir.
2. Derleme otomatik ve düzenli aralıklarla yapılır (haberler günlük, yemek listesi aylık); kaynak site değiştiğinde veya ulaşılamadığında bilgiler geçici olarak eksik/eski olabilir ve uygulama "bakımda" uyarısı gösterebilir. **Resmî bilgi için kaynak sayfa esastır;** Hizmet resmî bildirim yerine geçmez.
3. Kaynak içerik uygunsuz veya hatalı ise kaynağın sahibine bildirim yapılması gerekebilir; uygulamadan gizleme talepleri için Destek bölümünü kullanın.

## 10. Hizmet seviyesi, sorumluluk sınırı

1. Hizmet "olduğu gibi" ve "mevcut haliyle" sunulur. Kesintisiz, hatasız veya her cihazda çalışacağı, belirli bir amaca uygun olacağı ya da içeriğinin (özellikle kaynak sitelerden derlenen bilgilerin) doğru, eksiksiz ve güncel olacağı yönünde açık veya zımni bir garanti verilmez; bakım, güncelleme, mücbir sebep ve üçüncü taraf hizmet (e-posta, bildirim altyapısı, barındırma) kesintileri olabilir. Zorunlu güncelleme veya bakım modu uygulanabilir. Bu fıkra, kanunen kaldırılamayan haklarınızı etkilemez.
2. Hizmetin ücretsiz olması nedeniyle, kanunun izin verdiği ölçüde; dolaylı zararlar, kâr kaybı, veri kaybı, itibar kaybı ve üçüncü kişilerin içeriklerinden doğan zararlardan sorumlu değiliz; doğrudan zararlardan sorumluluğumuz da, kasıt ve ağır kusur hariç, kanunun izin verdiği ölçüde ve somut olayda ispatlanan zararla sınırlıdır. Kullanıcıların birbirleriyle ilişkilerinden, buluşmalarından, etkinliklerde yaşananlardan ve Hizmet dışındaki davranışlarından doğan uyuşmazlıklarda taraf değiliz. Bu sınırlama; kasıt, ağır kusur ve kanunen sınırlandırılamayan haller (emredici hukuk kuralları, kişilik hakları ve ölüm/yaralanma zararları dahil) için uygulanmaz.
3. Kullanıcı içeriklerinin doğruluğunu garanti etmeyiz; üçüncü kişilerin paylaşımlarından onlar sorumludur. 5651 sayılı Kanun kapsamında yer sağlayıcı olarak, hukuka aykırı içerikten haberdar edildiğimizde usulüne uygun bildirim üzerine gerekli işlemleri yaparız.
4. **Mesaj ve medya yedekleri.** Mesajlar ve medya şifreli saklandığından, ana şifreleme anahtarının kaybı halinde kurtarılamayabilir; sunucu yedekleri şifreli alınır ve sınırlı süre tutulur. Önemli belgelerinizin yedeğini kendiniz alın.

## 11. Tazminat

Bu koşulları, Topluluk Kurallarını veya hukuku ihlal etmeniz nedeniyle işleticiye yöneltilen üçüncü kişi taleplerinden doğan makul zararların (makul avukatlık giderleri dahil) giderilmesinden, kusurunuz ölçüsünde sorumlu olursunuz. Bu hüküm, kanunun öngördüğü yasal sorumluluk sınırlarını ortadan kaldırmaz.

## 12. Değişiklikler ve yeniden onay

1. Koşulları hukuki veya teknik gereklilikler nedeniyle güncelleyebiliriz. Güncel sürüm ve sürüm geçmişi bu sayfada yer alır.
2. Önemli değişikliklerde uygulama sizden yeni sürümü **yeniden onaylamanızı** ister; yeniden onay verene kadar Hizmetin bazı bölümlerine (özellikle yazma işlemlerine) erişiminiz kısıtlanabilir. Kullanıcı aleyhine olmayan, yalnızca bilgilendirme niteliğindeki düzeltmelerde (örneğin kaldırılan bir özelliğin metinden çıkarılması, saklama sürelerinin kodla uyumlu hale getirilmesi, çevirilerin tamamlanması) yeniden onay istenmeyebilir; yeni sürüm yine bu sayfada yayımlanır.
3. Onay sürümü ve zamanı, hukuki kanıt amacıyla hesap silindikten sonra da saklanır (bkz. Saklama ve İmha).

## 13. Fesih ve hesap kapatma

1. Hesabınızı dilediğiniz zaman uygulamadan veya [hesap silme sayfasından](/delete-account) kapatabilirsiniz. Hesap silme **anonimleştirmedir:** adınız, e-postanız ve profil bilgileriniz anonimleştirilir, bildirim cihaz kayıtlarınız, cihaz/IP ve analitik kayıtlarınız, gönderileriniz, beğenileriniz, takipleriniz, favori haberleriniz, ders programınız ve topluluk üyelikleriniz silinir. Gönderdiğiniz mesajlar ve topluluk gönderilerinin metni başkalarının sohbet/topluluk bağlamının parçası olduğundan yazarı anonim görünerek kalır; sözleşme onay kayıtları ve moderasyon izleri kimliksiz ve sınırlı biçimde korunur. Ayrıntı Gizlilik Politikası bölüm 7'de ve KVKK Aydınlatma Metni'nde açıklanmıştır.
2. Koşulları ihlal ederseniz hesabınızı askıya alabilir veya kapatabiliriz (5. bölüm). Kapatılan hesabın yeniden açılması bize ait takdir yetkisindedir.
3. Fesih, ihlal öncesi doğmuş hak ve yükümlülükleri ve doğası gereği devam etmesi gereken hükümleri (sorumluluk sınırı, fikri mülkiyet, uygulanacak hukuk vb.) etkilemez.

## 14. Uygulanacak hukuk ve yetkili mahkeme

1. Bu koşullara Türkiye Cumhuriyeti hukuku uygulanır.
2. Hizmet ücretsiz sunulur; bu nedenle tüketici mevzuatındaki özel yetki ve başvuru kuralları (6502 sayılı Kanun) yalnızca kanunen uygulanabildiği ölçüde geçerlidir. Bu koşullardan doğan uyuşmazlıklarda **{{controller.jurisdiction|Bingöl}} mahkemeleri ve icra daireleri** yetkilidir; idari işlemlere ilişkin uyuşmazlıklarda ilgili idare mahkemesi görevlidir. Kanunun emredici yetki kuralları (tüketici sıfatınız varsa yerleşim yerinizdeki tüketici mahkemesi veya hakem heyeti dahil) ve yasal başvuru haklarınız saklıdır; bu madde onları sınırlamaz.

## 15. Bingöl Üniversitesi ile ilişki; üçüncü taraf bağlantılar

1. {{controller.relation|Hizmet, Bingöl Üniversitesi'nin resmî uygulaması değildir; üniversite adına açıklama yapmaz, bağlayıcı beyanda bulunmaz ve üniversitenin resmî bildiriminin yerini tutmaz. Üniversiteye ait haber, duyuru, etkinlik ve yemek listesi içeriği "kaynak: bingol.edu.tr" ibaresiyle ve kaynak sayfa bağlantısıyla sunulur. Üyelik, yalnızca üniversiteye ait e-posta adresiyle doğrulama için bu alan adını kullanır; bu durum üniversitenin Hizmeti onayladığı, işlettiği veya sorumluluk üstlendiği anlamına gelmez.}}
2. Hizmet; kaynak site, harici bağlantı, QR veya üçüncü kişilerin paylaştığı bağlantılar aracılığıyla üçüncü taraf sitelere yönlendirebilir. Bu sitelerin içeriği, gizlilik uygulamaları ve güvenliği üzerinde denetimimiz yoktur; bunlardan sorumlu değiliz ve bağlantı onay anlamına gelmez. Bağlantıları kendi sorumluluğunuzda açarsınız.

## 16. Hizmetin değiştirilmesi, kesintiler ve mücbir sebep

1. Hizmeti veya özelliklerini, makul bir bildirimle (acil güvenlik/hukuki gereklilik hallerinde bildirimsiz) değiştirme, kısıtlama, askıya alma veya tamamen sonlandırma hakkımız saklıdır. Hizmetin sona ermesi halinde, mümkün olduğunca önceden duyuru yapar ve [Verilerimi indir](/legal/privacy) özelliğini bir süre açık tutmaya çalışırız. Ücretsiz Hizmetin değiştirilmesi veya sonlandırılması nedeniyle tazminat talep edilemez; kasıt ve ağır kusur halleri ile kanunun emredici hükümleri saklıdır.
2. Bakım, güncelleme veya teknik arıza nedeniyle Hizmet geçici olarak kesilebilir; bu durumlarda uygulama "bakımda" uyarısı gösterebilir.
3. Doğal afet, savaş, terör, salgın, elektrik/internet/altyapı ve üçüncü taraf sağlayıcı kesintileri, siber saldırı, mevzuat veya idari/yargısal karar değişikliği gibi tarafların makul kontrolü dışındaki olaylar (**mücbir sebep**) süresince yükümlülüklerin ifa edilememesinden dolayı sorumluluk doğmaz.

## 17. Delil sözleşmesi ve tebligat

1. Taraflar, Hizmet sunucularındaki kayıtların (sözleşme onay kayıtları, oturum/IP ve cihaz özeti kayıtları, moderasyon ve erişim günlükleri, e-posta ve bildirim kayıtları) 6100 sayılı Hukuk Muhakemeleri Kanunu m.193 anlamında **kesin delil** niteliğinde olduğunu kabul eder. Bu hüküm, emredici hukuka ve Kişisel Verileri Koruma Kurulu veya mahkemenin delil değerlendirme yetkisine halel getirmez; kayıtlara karşı gerçeğe aykırılığı ispat hakkınız saklıdır.
2. Size yapılacak bildirim ve tebligatlar, kayıtlı e-posta adresinize ve uygulama içi bildirim kutusuna gönderilir; gönderim anında tebliğ edilmiş sayılır. E-posta adresinizi ve iletişim bilgilerinizi güncel tutmak sizin sorumluluğunuzdadır. Bize yapılacak bildirimler {{support.email|uygulama içi Destek bölümü}} üzerinden{{?controller.kep}} veya {{controller.kep}} KEP adresine{{/controller.kep}} iletilir.

## 18. Genel hükümler

1. **Bölünebilirlik.** Bu koşulların bir hükmü geçersiz veya uygulanamaz bulunursa, diğer hükümler geçerliliğini korur; geçersiz hüküm, amacına en yakın geçerli hükümle yorumlanır.
2. **Feragat etmeme.** Bir hakkımızı kullanmamamız o haktan feragat anlamına gelmez.
3. **Devir.** Hizmeti ve bu koşullardan doğan haklarımızı, Hizmetin devri, birleşme veya yeniden yapılanma halinde, kişisel verilerin korunmasına ilişkin mevzuata uygun şekilde bir halef kuruma devredebiliriz. Siz haklarınızı bize yazılı onay olmadan devredemezsiniz.
4. **Bütünlük ve dil.** Bu koşullar ve atıf yapılan metinler tarafların anlaşmasının tamamıdır. Türkçe metin esastır; diğer dillerdeki metinler bilgilendirme amaçlı çeviridir ve farklılık halinde Türkçe metin geçerlidir.
5. **Başlıklar.** Başlıklar ve "Özetle" kutuları yalnızca kolaylık içindir; yorumda bağlayıcı değildir.

## 19. İletişim

- Genel sorular, itiraz ve talepler: {{support.email|uygulama içi Destek bölümü}}
{{?controller.email}}- Veri sorumlusu e-posta: {{controller.email}}{{/controller.email}}
{{?controller.kep}}- KEP adresi: {{controller.kep}}{{/controller.kep}}
{{?controller.address}}- Adres: {{controller.address}}{{/controller.address}}$c_terms_tr$, FALSE, TRUE),
    ('TERMS', 'en', v, $t_terms_en$Terms of Use$t_terms_en$, $c_terms_en$*This English text is a translation provided for information only. The Turkish text is authoritative; if there is any difference, the Turkish text prevails.*

This text explains how the BÜ Kampüs application and website (the "**Service**") may be used, and your rights and responsibilities and ours. Please read it carefully. You are asked to accept these terms when you register; your acceptance is recorded (with the document version and date).

## 1. Parties and scope

1. The Service is operated by: {{controller.name}}{{?controller.address}}, {{controller.address}}{{/controller.address}} (the "**Operator**", "**we**").
2. The person using the Service (the "**User**", "**you**") is deemed to have accepted these terms.
3. The Service consists of the following features: following news, announcements and events, the menu, profile, messaging, communities and events (including QR attendance), posts (a post consists of a single photo and a short text, and can be liked), following users, polls, a personal timetable and exam tracking, notifications, search, bookmarks, and support and feedback.
4. **Administrators.** Accounts that the Operator has given access to the management panel of the Service ("**administrators**") carry out moderation, support, content and system tasks. Administrators act under the Operator's authorisation, not on behalf of the university; user data is not transferred to the university. Administrator powers are described in section 6. Community/club administrators, by contrast, are user roles described in section 7 and are distinct from management panel administrators.
5. These terms are read together with the [Privacy Policy](/legal/privacy), the [KVKK Privacy Notice](/legal/kvkk), the [Community Rules](/legal/community-rules), the [Explicit Consent text](/legal/explicit-consent), the [Cookie and Local Storage Policy](/legal/cookies), [Content Notice and Removal](/legal/content-removal) and [Retention and Destruction](/legal/retention). The Community Rules form an integral part of these terms.

> **In short:** To use the Service you accept these terms, the Privacy Policy, the KVKK Privacy Notice and the Community Rules. The other texts are for information or for optional permissions.

## 2. Account and eligibility

1. **Who can register?** The Service is designed for the Bingöl University community, but an e-mail address ending in `bingol.edu.tr` is not required to register. You can register with any valid e-mail address that belongs to you, including addresses from providers such as Gmail, Outlook, Hotmail and Yahoo and school or organisation e-mail addresses. The account is activated only when you enter the 6-digit verification code sent to your e-mail address; no account is opened without entering the code. The verification code is valid for 10 minutes and there is a limited number of attempts. The e-mail address you register with does not verify your connection to the university; information such as department, faculty and class year in your profile is declared by you.
2. **Accuracy of information.** You are responsible for the accuracy of your account information and for the security of your password. Do not share your password with anyone. If you notice that your account is being used without permission, notify us immediately through the Support section; you can use the "sign out of all sessions" option.
3. **The account is not transferable.** You may not transfer, sell or share your account with anyone else. One person may not open multiple accounts for the purpose of abuse.
4. **Age.** The Service is aimed at the university community; it is not specifically aimed at users under 18. If a student under 18 uses it, use with the knowledge and permission of their legal representative is essential; in that case the consent of the legal representative to the processing of the relevant personal data may be required. In accounts where we notice this, we may ask for additional verification.
5. **Single-device rule (mobile).** For your security, only one session stays open at a time in the mobile app: when you sign in from another mobile device, your previous mobile sessions are ended and a "sign-in from a new device" warning e-mail may be sent for the previous device. Sessions on the web are not affected by this rule.
6. **Session duration.** Your access token is short-lived (15 minutes) and is renewed automatically; the refresh token is valid for at most 30 days and is single-use. When your password is reset, all your sessions are closed.

> **In short:** You register with any valid e-mail address (bingol.edu.tr is not required) and verify it with the code sent to that address. The account belongs to you and cannot be transferred. On mobile only one device stays signed in at a time.

## 3. User content and licence

1. **You own the content.** You hold the rights in the content you share, such as messages, photos, videos, community posts, events, profile information and feedback ("**User Content**"). You are responsible for the lawfulness of your content.
2. **The limited licence you give us.** So that we can provide the Service, you grant us a non-exclusive, non-transferable, royalty-free, worldwide licence, limited to the duration of the Service, to host, store, encrypt, resize/re-encode, transmit, display and present (to the persons and communities you send the content to) your User Content only for these purposes. We do not use your content for advertising and do not sell it to third parties.
3. **Processing of media.** Uploaded photos (profile, cover, post, chat) are re-encoded after their type and size have been verified; embedded metadata such as location (EXIF) is removed. Chat photos are reduced to a maximum of 1600 pixels on the longest side; at most 10 attachments (photos/videos mixed) can be sent per message. A post consists of a single photo and a short text of at most 7 words. **Chat videos** are compressed on your device; the server does not re-encode them and **does not remove the metadata inside the video file (for example the recording time or a location tag)**: the server only verifies the file type, size and duration, and stores the video encrypted. Your device's compression may not remove this metadata; be careful before sending videos that may contain location or personal information. The cover (preview) image of a video, however, is re-encoded like a photo and its metadata is removed. Chat videos are accepted up to 60 seconds and 40 MB; there are daily/hourly upload limits. These limits may change. View-once display can only be used for photos.
4. **Prohibited-content check.** The digital digest (SHA-256) of uploaded images is compared with a "prohibited content" digest list managed by authorised administrators. If there is a match, the upload is rejected. This check is only a digest comparison; the content of images is not analysed automatically.
5. **Posts.** You are responsible for the content of your posts and for not infringing the rights and data of third parties (for example another person's photo). Posts are shown to other signed-in users of the app and can be liked. Content does not go through human review before being published; therefore, as a hosting provider, the Operator removes unlawful content upon notice. Any post can be reported with **Report**; authorised administrators review it, may hide/remove the content, and may apply a warning or an account restriction. You may appeal the decision (see section 5 and [Content Notice and Removal](/legal/content-removal)).
6. **End of the licence.** When you delete your content or close your account, the licence ends, subject to the exceptions described in section 6 and the Privacy Policy (for example other people's chat history, legal retention and security records).

> **In short:** The content is yours; we store and process it only in a limited way to provide the Service. We do not use it for advertising and do not sell it.

## 4. Prohibited conduct

The following are prohibited (detailed examples are in the [Community Rules](/legal/community-rules)):

1. Sharing unlawful content, or content that is threatening, harassing, blackmailing, hateful, discriminatory, obscene or violent.
2. Impersonating another person; opening misleading accounts, communities or events.
3. Sharing other people's personal data or private correspondence without their consent.
4. Spam, chain messages, unauthorised advertising or fraud attempts.
5. Disrupting the Service: bulk requests with automated tools, exploiting security vulnerabilities, unauthorised access, attempts to exceed rate limits, circumventing a ban on an IP/device (VPN, switching accounts, etc.).
6. Bulk scraping of the user directory or systematically collecting user information.
7. Violating course and exam integrity (e.g. selling exam questions, organising cheating).
8. Misusing the event attendance (QR) system: giving attendance on behalf of another person, sharing/duplicating the code.
9. Infringing intellectual property rights (see section 8).
10. Using profanity, insults, hate speech or sexually explicit expressions in public areas such as communities, events, profiles, group titles and post text. Such content may be rejected automatically. Content in private chats and group messages is not pre-screened; however, harassment, threats or inappropriate content may be reported by users and, after review through the in-app report/feedback channel, content removal, a warning or an account restriction may be applied.

## 5. Moderation, suspension and blocking

1. **Reporting.** Every user can report users, messages, posts, communities and events with "Report". To prevent abuse the number of reports is limited; malicious or repeated unfounded reports may lead to a reporting restriction.
2. **Review.** Reports are reviewed by authorised administrators. During review the content concerned and the related chat context may be seen (see section 6).
3. **Enforcement steps.** Depending on the situation: (a) removal or hiding of the content (if the same content is reported by several mutually independent accounts, it may be hidden automatically and temporarily until the review is completed; it may be made visible again after administrator review); (b) warning/notification; (c) violation record (3 resolved violations for the same user within a 180-day window lead to a suspension recommendation to an administrator; the threshold is adjustable); (d) temporary suspension; (e) permanent account closure; (f) if necessary, an access ban based on IP, network range, device or user. In serious violations (e.g. child abuse, terrorism, threats) the steps may be skipped and the competent authorities may be notified.
4. **Access ban (device and IP).** For security and to prevent abuse, your IP address and device identifier (stored as a non-reversible digest) are recorded at sign-in/registration/request; a new account/session matching the account, device or IP address of a banned user may be blocked. Requests coming from anonymising networks (e.g. VPN, Tor, data-centre ranges) may also be blocked for security. Details are in the Privacy Policy.
5. **Notification and appeal.** For suspension or content-removal decisions we notify you in the app wherever possible. To appeal a decision you can use the **appeal** feature in the app or the Support section; appeals are re-evaluated by an administrator and the result is notified to you. In emergencies that directly threaten account security, the measure may be applied before the appeal.
6. **Blocking users.** You can block any user you wish. Blocking is for privacy: messages sent to you by the person you blocked are not delivered to you (they do not appear in history, in notifications or in the unread counter); the blocked person is not shown a warning that they were blocked. Even if the block is later removed, messages sent during the block are not delivered to you. These messages remain in the system; authorised administrators can see them during report review. In groups, the messages of a person you blocked are hidden for you; other members see them normally.

> **In short:** Content that violates the rules may be removed, accounts may be suspended or closed; a device/IP ban may be applied. You can appeal a decision from within the app.

## 6. Messaging and administrator access

This section states clearly that your messages are not "completely confidential" between you and the other party. Please read it carefully.

1. **Type of encryption.** Messages are encrypted in transit (TLS/WSS) and stored encrypted on the server (AES-256-GCM). The system is **not end-to-end encrypted**: the decryption keys are held on the server side; authorised administrators can view messages when necessary. We make no commitment that nobody can read your messages.
2. **Administrator roles and powers.** Administrator accounts are given one of five roles defined by the Operator: *full administrator* (all management operations), *moderator* (moderation, report review, message and chat intervention, user information), *support* (support requests and feedback; user information masked), *editor* (management of news, announcements and communication content) and *read-only* (monitoring only; personal fields such as e-mail/IP masked). **Only administrators with the full administrator and moderator roles can access the content of private correspondence;** the other roles and no user who is not an administrator can. Role changes are written to the audit log.
3. **Administrator interventions.** Authorised administrators may hide (reversible) or permanently delete a message that violates the rules or has been reported, close or reopen a chat, remove a member from a chat, hide or remove posts and other content, and close a community that violates the rules. In these operations the administrator must enter a written reason; the operation, reason, administrator and time are written to the audit log, and an in-app notification may be sent to the user concerned.
4. **When can administrators access?** Message content is accessed only for reasons such as report and complaint review, account security, suspicion of abuse and unlawful activity, requests from competent authorities such as courts/prosecutors/law enforcement, or the user's own application. Because the management panel can technically list the chats a user is or has been a member of (including deleted, edited and hidden messages), this power is used only for the reasons listed and each time with a written reason. Viewing out of curiosity or for any other purpose is prohibited; administrators are expected to comply with a duty of confidentiality.
5. **Audit.** An administrator must enter a written reason to view message content (at least 10 characters; for a chat export on a legal request at least 20 characters and a separate second confirmation step). The viewing is written, before the content is shown, to a tamper-resistant access record automatically (administrator, user viewed, chat, number of messages, reason, IP address, time). If the record cannot be written, the content is not shown. Access records are kept for 730 days for legal and security audit purposes and then deleted.
6. **Deleted and edited messages.** When you say "delete for everyone", the message appears to other users as "This message was deleted"; however, the encrypted copy of the message, its edit history and its attachments may continue to be stored on the server for security and report review (default: indefinitely; when the operator sets a retention period, they are permanently deleted at the end of that period). Previous versions of messages you edited are also stored encrypted. In the user interface you can no longer see a deleted message; deleted messages are not included in the "download my data" output.
7. **View-once photo.** With this feature the recipient can open the photo only once; after opening it (or 24 hours after sending) the recipient's access closes and the sender cannot reopen what they sent. However, so that authorised administrators can review it for security and report review, the photo file is **stored encrypted on the server for 365 days** (adjustable period) and then deleted. Although technical barriers are placed against taking screenshots on the device, **it is not guaranteed that no screenshot or screen recording will be taken**; the recipient may photograph it with another device. Therefore do not send images you would not want to end up in someone else's hands.
8. **Notification preview.** By default, push notifications do not contain the message text; a generic notification such as "You have a new message" is sent.
9. **Chats when an account is deleted.** When you delete your account, the messages you sent are not deleted because they are part of the other party's chat history; the author's name appears anonymous. The chat photos uploaded by the account are deleted.

> **In short:** Messages are stored encrypted but are not end-to-end encrypted. Authorised administrators can view them only in reasoned cases and every access is recorded. The encrypted copy of deleted messages and view-once photos may be kept for a period for security. No absolute guarantee is given against screenshots.

## 7. Communities and events

1. **Community/club administrators** are responsible for the content and members of their own communities; they must comply with the Community Rules and these terms. Administrator powers can be delegated; the system may apply approval steps when powers are delegated. **If a club owner deletes their account**, ownership is transferred automatically to the oldest active administrator (or, if none, moderator) member of the club and a notification is sent to the new owner; if there is nobody who can take over, the club is closed, its members are notified and the future events linked to the club are cancelled. Service administrators may also close, reopen or transfer ownership of a club that violates the rules, with a stated reason.
2. **Event creators** are responsible for the accuracy of the event information and the lawfulness of the event. Event attendance is taken by QR code or manually; attendance records are visible to the event organiser and authorised administrators. If the person who created an event deletes their account, their unfinished events that are not linked to a club are cancelled and open applications are closed.
3. **Chat rooms.** Your participation in chat rooms created for communities and events depends on your membership; if you are removed or banned from the community you are also dropped from the room. Event chat rooms close, by default, within 7 days after the event ends.
4. The Operator does not assume responsibility for events organised by university units or communities unless expressly stated; the physical safety, content and cancellation of events are the organiser's responsibility.

## 8. Intellectual property and copyright

1. The software, design, logo and brand of the application and the original content we offer belong to the Operator or its licensors. You may not copy, reverse engineer or distribute the software without permission.
2. Do not share copyrighted content belonging to others. If you believe your copyright has been infringed, apply using the procedure in [Content Notice and Removal](/legal/content-removal); for justified notices the content is removed, and for repeated infringements the account may be closed.
3. The name and logo of "Bingöl Üniversitesi" belong to the institution concerned; their use in the Service gives rise to no right beyond the right of use provided by these terms.

## 9. Source content (news, announcements, events, menu)

1. News, announcements, events and menu information are compiled and presented from the official websites of Bingöl University (bingol.edu.tr and sks.bingol.edu.tr). The rights in this content belong to the institution concerned.
2. Compilation is automatic and at regular intervals (news daily, the menu monthly); when the source site changes or is unreachable, information may be temporarily missing/outdated and the app may show a "maintenance" warning. **For official information the source page is authoritative;** the Service does not replace an official notice.
3. If source content is inappropriate or incorrect, a notice to the owner of the source may be necessary; use the Support section for requests to hide content in the app.

## 10. Service level, limitation of liability

1. The Service is provided "as is" and "as available". No express or implied warranty is given that it will be uninterrupted, error-free or work on every device, that it is fit for a particular purpose, or that its content (especially information compiled from source sites) is accurate, complete and up to date; there may be maintenance, updates, force majeure and interruptions of third-party services (e-mail, notification infrastructure, hosting). A mandatory update or maintenance mode may be applied. This paragraph does not affect rights that cannot be waived by law.
2. Because the Service is free of charge, to the extent permitted by law, we are not liable for indirect damages, loss of profit, loss of data, loss of reputation or damages arising from the content of third parties; our liability for direct damages is also limited, except for intent and gross negligence, to the extent permitted by law and to the damage proven in the specific case. We are not a party to disputes arising from users' relationships with each other, their meetings, what happens at events and their conduct outside the Service. This limitation does not apply to intent, gross negligence and cases that cannot be limited by law (including mandatory rules of law, personality rights and damages for death/injury).
3. We do not guarantee the accuracy of user content; third parties are responsible for their own posts. As a hosting provider under Law No. 5651, when we are informed of unlawful content we take the necessary steps upon a duly made notice.
4. **Message and media backups.** Because messages and media are stored encrypted, they may not be recoverable if the master encryption key is lost; server backups are taken encrypted and kept for a limited time. Take your own backup of important documents.

## 11. Indemnity

You are liable, in proportion to your fault, for compensating reasonable damages (including reasonable attorney's fees) arising from third-party claims made against the Operator because you violated these terms, the Community Rules or the law. This provision does not remove the limits of legal liability provided by law.

## 12. Changes and re-acceptance

1. We may update the terms for legal or technical reasons. The current version and version history appear on this page.
2. For important changes the application asks you to **re-accept** the new version; until you re-accept, your access to some parts of the Service (especially write operations) may be restricted. For corrections that are not to the user's disadvantage and are only informational (for example removing a discontinued feature from the text, aligning retention periods with the code, completing translations), re-acceptance may not be requested; the new version is still published on this page.
3. The acceptance version and time are kept as legal evidence even after the account is deleted (see Retention and Destruction).

## 13. Termination and account closure

1. You can close your account at any time from the app or from the [account deletion page](/delete-account). Account deletion is **anonymisation:** your name, e-mail and profile information are anonymised; your notification device records, device/IP and analytics records, posts, likes, follows, bookmarked news, timetable and community memberships are deleted. The messages you sent and the text of community posts remain, with the author shown anonymously, because they are part of other people's chat/community context; agreement acceptance records and moderation traces are kept without identity and in a limited form. Details are explained in Privacy Policy section 7 and in the KVKK Privacy Notice.
2. If you violate the terms we may suspend or close your account (section 5). Reopening a closed account is at our discretion.
3. Termination does not affect rights and obligations that arose before the violation and provisions that by their nature must continue (limitation of liability, intellectual property, governing law, etc.).

## 14. Governing law and competent court

1. The law of the Republic of Türkiye applies to these terms.
2. The Service is offered free of charge; therefore the special jurisdiction and application rules in consumer legislation (Law No. 6502) apply only to the extent they are legally applicable. In disputes arising from these terms the **courts and enforcement offices of {{controller.jurisdiction|Bingöl}}** have jurisdiction; in disputes concerning administrative acts the relevant administrative court has jurisdiction. The mandatory jurisdiction rules of the law (including, if you are a consumer, the consumer court or arbitration committee at your place of residence) and your statutory rights of application are reserved; this article does not limit them.

## 15. Relationship with Bingöl University; third-party links

1. {{controller.relation|The Service is not an official application of Bingöl University; it makes no statements on behalf of the university, makes no binding declarations and does not replace the university's official notices. Content belonging to the university such as news, announcements, events and menu is presented with the note "source: bingol.edu.tr" and a link to the source page. Membership uses this domain name only to verify a university e-mail address; this does not mean that the university approves or operates the Service or assumes responsibility.}}
2. The Service may direct you to third-party sites through the source site, external links, QR codes or links shared by third parties. We have no control over the content, privacy practices and security of these sites; we are not responsible for them and a link does not mean endorsement. You open links at your own responsibility.

## 16. Changes to the Service, interruptions and force majeure

1. We reserve the right to change, restrict, suspend or completely terminate the Service or its features with reasonable notice (without notice in emergency security/legal cases). If the Service ends, we try to announce this beforehand as far as possible and keep the [Download my data](/legal/privacy) feature open for a period. No compensation can be claimed because of a change to or termination of the free Service; cases of intent and gross negligence and the mandatory provisions of the law are reserved.
2. The Service may be temporarily interrupted due to maintenance, updates or technical faults; in these cases the app may show a "maintenance" warning.
3. Events outside the reasonable control of the parties, such as natural disaster, war, terrorism, epidemic, electricity/internet/infrastructure and third-party provider outages, cyber attack, and changes in legislation or administrative/judicial decisions (**force majeure**), give rise to no liability for failure to perform obligations while they last.

## 17. Evidence agreement and notices

1. The parties accept that the records on the Service's servers (agreement acceptance records, session/IP and device digest records, moderation and access logs, e-mail and notification records) constitute **conclusive evidence** within the meaning of Article 193 of the Code of Civil Procedure No. 6100. This provision does not prejudice mandatory law or the power of the Personal Data Protection Board or the court to evaluate evidence; your right to prove that the records are untrue is reserved.
2. Notices and communications to you are sent to your registered e-mail address and the in-app notification inbox; they are deemed served at the time of sending. Keeping your e-mail address and contact details up to date is your responsibility. Notices to us are made through {{support.email|the in-app Support section}}{{?controller.kep}} or to the KEP address {{controller.kep}}{{/controller.kep}}.

## 18. General provisions

1. **Severability.** If a provision of these terms is found invalid or unenforceable, the other provisions remain valid; the invalid provision is interpreted as the valid provision closest to its purpose.
2. **No waiver.** Our not exercising a right does not mean waiving it.
3. **Assignment.** In the event of a transfer of the Service, a merger or a restructuring, we may assign the Service and our rights under these terms to a successor in accordance with personal data protection legislation. You may not assign your rights without our written approval.
4. **Entire agreement and language.** These terms and the texts referred to are the entire agreement of the parties. The Turkish text is authoritative; texts in other languages are translations for information, and if there is any difference the Turkish text prevails.
5. **Headings.** Headings and "In short" boxes are for convenience only; they are not binding in interpretation.

## 19. Contact

- General questions, appeals and requests: {{support.email|the in-app Support section}}
{{?controller.email}}- Controller e-mail: {{controller.email}}{{/controller.email}}
{{?controller.kep}}- KEP address: {{controller.kep}}{{/controller.kep}}
{{?controller.address}}- Address: {{controller.address}}{{/controller.address}}$c_terms_en$, FALSE, TRUE),
    ('TERMS', 'ar', v, $t_terms_ar$شروط الاستخدام$t_terms_ar$, $c_terms_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

يشرح هذا النص كيفية استخدام تطبيق «BÜ Kampüs» وموقعه الإلكتروني («**الخدمة**»)، وحقوقكم والتزاماتكم وحقوقنا والتزاماتنا. يُرجى قراءته بعناية. يُطلب منكم قبول هذه الشروط عند التسجيل؛ ويُسجَّل قبولكم (مع إصدار الوثيقة وتاريخها).

## 1. الأطراف والنطاق

1. الجهة المشغِّلة للخدمة: {{controller.name}}{{?controller.address}}، {{controller.address}}{{/controller.address}} («**المشغِّل**» و«**نحن**»).
2. يُعدّ الشخص الذي يستخدم الخدمة («**المستخدم**» و«**أنتم**») قد قبل هذه الشروط.
3. تتكوّن الخدمة من الميزات الآتية: متابعة الأخبار والإعلانات والفعاليات، وقائمة الطعام، والملف الشخصي، والمراسلة، والمجتمعات والفعاليات (بما في ذلك تسجيل الحضور عبر QR)، والمنشورات (يتكوّن المنشور من صورة واحدة ونص قصير، ويمكن الإعجاب به)، ومتابعة المستخدمين، والاستطلاعات، والجدول الدراسي الشخصي ومتابعة الامتحانات، والإشعارات، والبحث، والمفضلات، والدعم وإرسال الملاحظات.
4. **المسؤولون.** الحسابات التي منحها المشغِّل صلاحية الوصول إلى لوحة إدارة الخدمة («**المسؤولون**») تتولى أعمال الإشراف والدعم والمحتوى والنظام. يعمل المسؤولون بتفويض من المشغِّل لا باسم الجامعة؛ ولا تُنقل بيانات المستخدمين إلى الجامعة. صلاحيات المسؤولين مبيّنة في القسم 6. أما مسؤولو المجتمعات/الأندية فهم أدوار مستخدمين مبيّنة في القسم 7 ومنفصلون عن مسؤولي لوحة الإدارة.
5. تُقرأ هذه الشروط مع النصوص الآتية: [سياسة الخصوصية](/legal/privacy)، و[نص الإفصاح بموجب قانون حماية البيانات الشخصية (KVKK)](/legal/kvkk)، و[قواعد المجتمع](/legal/community-rules)، و[نص الموافقة الصريحة](/legal/explicit-consent)، و[سياسة ملفات تعريف الارتباط والتخزين المحلي](/legal/cookies)، و[الإبلاغ عن المحتوى وإزالته](/legal/content-removal)، و[الاحتفاظ والإتلاف](/legal/retention). وتُعدّ قواعد المجتمع جزءًا لا يتجزأ من هذه الشروط.

> **باختصار:** لاستخدام الخدمة، تقبلون هذه الشروط وسياسة الخصوصية ونص الإفصاح بموجب KVKK وقواعد المجتمع. أما النصوص الأخرى فهي للإعلام أو للأذونات الاختيارية.

## 2. الحساب والأهلية

1. **من يمكنه التسجيل؟** الخدمة مصمَّمة لمجتمع جامعة بينغول، لكن لا يُشترط للتسجيل بريد إلكتروني ينتهي بالنطاق `bingol.edu.tr`. يمكنكم التسجيل بأي عنوان بريد إلكتروني صالح يخصّكم، بما في ذلك عناوين مزوّدي الخدمة مثل Gmail وOutlook وHotmail وYahoo وعناوين البريد المدرسية أو المؤسسية. لا يُفعَّل الحساب إلا عند إدخالكم رمز التحقق المكوَّن من 6 أرقام المرسل إلى بريدكم الإلكتروني؛ ولا يُفتح الحساب دون إدخال الرمز. رمز التحقق صالح لمدة 10 دقائق، ولكم عدد محدود من المحاولات. ولا يثبت عنوان البريد الإلكتروني المستخدم في التسجيل صلتكم بالجامعة؛ أما معلومات مثل القسم والكلية والصف في الملف الشخصي فهي معلومات تصرّحون بها بأنفسكم.
2. **صحة المعلومات.** أنتم المسؤولون عن صحة معلومات حسابكم وعن أمان كلمة مروركم. لا تشاركوا كلمة مروركم مع أحد. وإذا لاحظتم استخدام حسابكم دون إذن، فأبلغونا فورًا عبر قسم الدعم؛ ويمكنكم استخدام خيار «إنهاء جميع الجلسات».
3. **عدم قابلية الحساب للتنازل.** لا يجوز لكم التنازل عن حسابكم لشخص آخر أو بيعه أو مشاركته. ولا يجوز لأي شخص فتح أكثر من حساب بقصد إساءة الاستخدام.
4. **السن.** الخدمة موجهة لمجتمع الجامعة؛ وليست موجهة تحديدًا للمستخدمين دون 18 عامًا. وإذا كان الطالب دون 18 عامًا يستخدمها، فالأصل أن يكون ذلك بعلم ممثله القانوني وإذنه؛ وفي هذه الحالة قد تلزم موافقة الممثل القانوني على معالجة البيانات الشخصية ذات الصلة. ويجوز لنا طلب تحقق إضافي في الحسابات التي ننتبه فيها إلى هذا الوضع.
5. **قاعدة الجهاز الواحد (الجوال).** حفاظًا على أمانكم، تبقى جلسة واحدة فقط مفتوحة في الوقت نفسه على تطبيق الجوال: عند تسجيل الدخول من جهاز جوال آخر، تُنهى جلساتكم السابقة على الجوال، وقد يُرسل إلى الجهاز السابق بريد إلكتروني تنبيهي بعنوان «تسجيل دخول من جهاز جديد». ولا تتأثر الجلسات على الويب بهذه القاعدة.
6. **مدة الجلسة.** مفتاح الوصول الخاص بكم قصير العمر (15 دقيقة) ويتجدد تلقائيًا؛ أما مفتاح التجديد فصالح 30 يومًا كحد أقصى ولا يُستخدم إلا مرة واحدة. وعند إعادة تعيين كلمة المرور تُغلق جميع جلساتكم.

> **باختصار:** تسجلون بأي بريد إلكتروني صالح (لا يُشترط bingol.edu.tr) وتتحققون منه بالرمز المرسل إلى ذلك العنوان. الحساب ملك لكم ولا يمكن التنازل عنه. على الجوال تبقى جلسة واحدة مفتوحة على جهاز واحد في الوقت نفسه.

## 3. محتوى المستخدم والترخيص

1. **أنتم أصحاب المحتوى.** حقوق المحتويات التي تشاركونها، مثل الرسائل والصور ومقاطع الفيديو ومنشورات المجتمع والفعاليات ومعلومات الملف الشخصي والملاحظات («**محتوى المستخدم**»)، تعود إليكم. وأنتم المسؤولون عن مشروعية محتوياتكم.
2. **الترخيص المحدود الذي تمنحوننا إياه.** لكي نتمكن من تقديم الخدمة، تمنحوننا ترخيصًا غير حصري، وغير قابل للتنازل، ومجانيًا، وعالميًا، ومحدودًا بمدة الخدمة، لاستضافة محتوى المستخدم الخاص بكم وحفظه وتشفيره وتغيير حجمه/إعادة ترميزه ونقله وعرضه وتقديمه (للأشخاص والمجتمعات الذين ترسلون إليهم المحتوى)، وذلك للأغراض الآتية فقط. لا نستخدم محتواكم لأغراض إعلانية ولا نبيعه لأطراف ثالثة.
3. **معالجة الوسائط.** تُعاد ترميز الصور المرفوعة (الملف الشخصي والغلاف والمنشورات والمحادثات) بعد التحقق من نوعها وحجمها؛ وتُزال البيانات الوصفية المضمّنة مثل الموقع (EXIF). تُصغَّر صور المحادثات إلى 1600 بكسل كحد أقصى لطول الضلع؛ ويمكن إرسال 10 مرفقات كحد أقصى في الرسالة الواحدة (صور/فيديو مختلطة). يتكوّن المنشور من صورة واحدة ونص قصير لا يزيد على 7 كلمات. **تُضغط مقاطع فيديو المحادثات** على جهازكم؛ ولا يعيد الخادم ترميزها و**لا يزيل البيانات الوصفية داخل ملف الفيديو (مثل وقت التصوير أو وسم الموقع)**: إذ يتحقق الخادم فقط من نوع الملف وحجمه ومدته، ويحفظ الفيديو مشفّرًا. وقد لا يزيل ضغط جهازكم هذه البيانات الوصفية؛ لذا توخّوا الحذر قبل إرسال مقاطع فيديو قد تتضمن معلومات عن الموقع أو معلومات شخصية. أما صورة الغلاف (المعاينة) للفيديو فتُعاد ترميزها كالصور وتُزال بياناتها الوصفية. تُقبل مقاطع فيديو المحادثات بمدة أقصاها 60 ثانية وحجم يصل إلى 40 ميغابايت، وتوجد حدود يومية/ساعية للرفع. ويجوز أن تتغير هذه الحدود. ولا يمكن استخدام العرض لمرة واحدة إلا للصور.
4. **فحص المحتوى المحظور.** يُقارَن الملخص الرقمي (SHA-256) للصور المرفوعة بقائمة ملخصات «المحتوى المحظور» التي يديرها المسؤولون المخوّلون. وعند التطابق يُرفض الرفع. هذا الفحص مقارنة ملخصات فقط؛ ولا يُحلَّل مضمون الصور تلقائيًا.
5. **المنشورات.** أنتم المسؤولون عن مضمون منشوراتكم وعن عدم انتهاك حقوق الغير وبياناتهم (مثل صورة شخص آخر). تُعرض المنشورات على المستخدمين الآخرين الذين سجلوا الدخول إلى التطبيق ويمكن الإعجاب بها. لا تمر المحتويات بمراجعة بشرية قبل نشرها؛ ولذلك يزيل المشغِّل بصفته مزوّد استضافة المحتوى المخالف للقانون بناءً على إخطار. يمكن الإبلاغ عن أي منشور عبر **إبلاغ**؛ ويراجعه المسؤولون المخوّلون، ويجوز لهم إخفاء المحتوى/إزالته وتوجيه تحذير أو فرض تقييد على الحساب. ولكم الاعتراض على القرار (انظر القسم 5 و[الإبلاغ عن المحتوى وإزالته](/legal/content-removal)).
6. **انتهاء الترخيص.** عند حذفكم محتواكم أو إغلاقكم حسابكم ينتهي الترخيص، مع بقاء الاستثناءات الواردة في القسم 6 وفي سياسة الخصوصية (مثل سجل محادثات الآخرين، والحفظ القانوني، وسجلات الأمان).

> **باختصار:** المحتوى ملك لكم؛ ونحن نحفظه ونعالجه بشكل محدود فقط لتقديم الخدمة. لا نستخدمه للإعلان ولا نبيعه.

## 4. السلوكيات المحظورة

يُحظر القيام بما يأتي (الأمثلة التفصيلية في نص [قواعد المجتمع](/legal/community-rules)):

1. مشاركة محتوى مخالف للقانون، أو تهديد، أو مضايقة، أو ابتزاز، أو خطاب كراهية، أو تمييز، أو محتوى فاحش أو عنيف.
2. انتحال هوية شخص آخر؛ أو فتح حساب أو مجتمع أو فعالية مضلِّلة.
3. مشاركة البيانات الشخصية للآخرين أو مراسلاتهم الخاصة دون موافقتهم.
4. الرسائل المزعجة (سبام)، ورسائل السلاسل، والإعلانات دون إذن، ومحاولات الاحتيال.
5. تعطيل الخدمة: الطلبات الجماعية بأدوات آلية، واستغلال الثغرات الأمنية، والوصول غير المصرّح به، ومحاولة تجاوز حدود المعدل، والتحايل على حظر IP/الجهاز (VPN، تبديل الحسابات، إلخ).
6. المسح الجماعي لدليل المستخدمين أو جمع معلومات المستخدمين بشكل منهجي.
7. الإخلال بنزاهة الدروس والامتحانات (مثل بيع أسئلة الامتحانات وتنظيم الغش).
8. إساءة استخدام نظام تسجيل حضور الفعاليات (QR): تسجيل الحضور باسم شخص آخر، ومشاركة الرمز أو نسخه.
9. انتهاك حقوق الملكية الفكرية (انظر القسم 8).
10. استخدام الشتائم أو الإهانة أو خطاب الكراهية أو العبارات ذات المحتوى الجنسي في المساحات العامة مثل المجتمعات والفعاليات والملف الشخصي وعناوين المجموعات ونص المنشورات. وقد يُرفض هذا النوع من المحتوى تلقائيًا. لا يخضع المحتوى في المحادثات الخاصة ورسائل المجموعات لفحص مسبق؛ غير أنه يمكن للمستخدمين الإبلاغ عن المضايقة أو التهديد أو المحتوى غير اللائق، وتُراجَع عبر قناة الشكوى/الملاحظات داخل التطبيق، وقد يُطبَّق إزالة المحتوى أو التحذير أو تقييد الحساب.

## 5. الإشراف والتعليق والحظر

1. **الإبلاغ.** يمكن لكل مستخدم الإبلاغ عن المستخدمين والرسائل والمنشورات والمجتمعات والفعاليات عبر «إبلاغ». ولمنع إساءة الاستخدام، عدد البلاغات محدود؛ وقد تؤدي البلاغات الكيدية أو المتكررة التي لا أساس لها إلى تقييد حق الإبلاغ.
2. **المراجعة.** يراجع المسؤولون المخوّلون البلاغات. وأثناء المراجعة قد يُطَّلع على المحتوى المتعلق بالبلاغ وعلى سياق المحادثة المرتبط به (انظر القسم 6).
3. **درجات الجزاء.** بحسب الحالة: (أ) إزالة المحتوى أو إخفاؤه (وإذا أُبلغ عن المحتوى نفسه من عدة حسابات مستقلة بعضها عن بعض فقد يُخفى تلقائيًا ومؤقتًا إلى حين اكتمال المراجعة؛ ويجوز إظهاره من جديد بعد مراجعة المسؤول)؛ (ب) تحذير/إشعار؛ (ج) تسجيل مخالفة (3 مخالفات تمت تسويتها للمستخدم نفسه ضمن نافذة 180 يومًا تُنتج توصية للمسؤول بالتعليق؛ والحد قابل للضبط)؛ (د) تعليق مؤقت؛ (هـ) إغلاق الحساب نهائيًا؛ (و) عند الحاجة، حظر وصول على أساس IP أو نطاق شبكة أو جهاز أو مستخدم. وفي المخالفات الجسيمة (مثل استغلال الأطفال والإرهاب والتهديد) يجوز تجاوز الدرجات وإبلاغ السلطات المختصة.
4. **حظر الوصول (الجهاز وIP).** بغرض الأمان ومنع إساءة الاستخدام، يُسجَّل عنوان IP الخاص بكم ومعرّف جهازكم (يُحفظ على شكل ملخص لا يمكن عكسه) عند تسجيل الدخول/التسجيل/الطلب؛ وقد يُحظر أي حساب/جلسة جديدة تطابق حساب مستخدم محظور أو جهازه أو عنوان IP الخاص به. وقد تُحظر أيضًا الطلبات الواردة من شبكات إخفاء الهوية (مثل VPN وTor ونطاقات مراكز البيانات) لأغراض أمنية. التفاصيل في سياسة الخصوصية.
5. **الإشعار والاعتراض.** في قرارات التعليق أو إزالة المحتوى، يُرسَل إليكم قدر الإمكان إشعار داخل التطبيق. وللاعتراض على القرار يمكنكم استخدام ميزة **الاعتراض** في التطبيق أو قسم الدعم؛ ويعيد أحد المسؤولين تقييم الاعتراضات ويُبلَّغ إليكم الناتج. وفي الحالات الطارئة التي تهدد أمان الحساب مباشرة، يجوز تطبيق التدبير قبل الاعتراض.
6. **حظر المستخدمين.** يمكنكم حظر أي مستخدم تشاؤون. الحظر لأجل الخصوصية: فالرسائل التي يرسلها إليكم من حظرتموه لا تُسلَّم إليكم (ولا تظهر في السجل أو الإشعار أو عدّاد غير المقروء)؛ ولا يُعرض على الشخص المحظور تنبيه يفيد بأنه محظور. وحتى لو أُلغي الحظر لاحقًا، فإن الرسائل المرسلة أثناء الحظر لا تُسلَّم إليكم. تبقى هذه الرسائل في النظام؛ ويمكن للمسؤولين المخوّلين الاطلاع عليها أثناء مراجعة الشكاوى. وفي المجموعات تُخفى رسائل من حظرتموه عنكم، بينما يراها الأعضاء الآخرون بشكل طبيعي.

> **باختصار:** قد يُزال المحتوى المخالف للقواعد، وقد يُعلَّق الحساب أو يُغلق؛ وقد يُطبَّق حظر الجهاز/IP. يمكنكم الاعتراض على القرار من داخل التطبيق.

## 6. المراسلة ووصول المسؤولين

يوضح هذا القسم صراحةً أن رسائلكم ليست «سرية تمامًا» بينكم وبين الطرف الآخر. يُرجى قراءته بعناية.

1. **نوع التشفير.** الرسائل مشفّرة أثناء النقل (TLS/WSS) وتُحفظ مشفّرة على الخادم (AES-256-GCM). النظام **غير مشفّر من طرف إلى طرف**: فمفاتيح فك التشفير محفوظة لدى الخادم؛ ويمكن للمسؤولين المخوّلين عرض الرسائل عند الاقتضاء. وليس لدينا أي التزام بأن لا يستطيع أحد قراءة رسائلكم.
2. **أدوار المسؤولين وصلاحياتهم.** تُمنح حسابات المسؤولين أحد خمسة أدوار يحددها المشغِّل: *مسؤول كامل الصلاحيات* (جميع عمليات الإدارة)، و*مشرف* (الإشراف ومراجعة البلاغات والتدخل في الرسائل والمحادثات ومعلومات المستخدمين)، و*دعم* (طلبات الدعم والملاحظات؛ ومعلومات المستخدمين محجوبة جزئيًا)، و*محرِّر* (إدارة الأخبار والإعلانات ومحتوى التواصل)، و*للقراءة فقط* (المراقبة فقط؛ والحقول الشخصية مثل البريد الإلكتروني/IP محجوبة جزئيًا). **لا يصل إلى مضمون المراسلات الخاصة إلا المسؤولون بدور المسؤول الكامل الصلاحيات والمشرف؛** ولا تصل إليها الأدوار الأخرى ولا أي مستخدم ليس مسؤولًا. وتُكتب تغييرات الأدوار في سجل التدقيق.
3. **تدخلات المسؤولين.** يجوز للمسؤولين المخوّلين إخفاء رسالة مخالفة للقواعد أو مُبلَّغ عنها (ويمكن التراجع عن الإخفاء) أو حذفها نهائيًا، وإغلاق محادثة أو إعادة فتحها، وإخراج عضو من محادثة، وإخفاء المنشورات وسائر المحتويات أو إزالتها، وإغلاق مجتمع يخالف القواعد. وفي هذه العمليات يجب على المسؤول إدخال سبب كتابي؛ ويُكتب في سجل التدقيق العملية والسبب والمسؤول والوقت، وقد يُرسَل إشعار داخل التطبيق إلى المستخدم المعني.
4. **متى يصل المسؤولون؟** لا يُطَّلع على مضمون الرسائل إلا بمبررات مثل مراجعة الشكاوى والبلاغات، وأمان الحساب، والاشتباه في إساءة الاستخدام أو نشاط غير قانوني، وطلبات السلطات المختصة كالمحكمة/النيابة العامة/الضابطة العدلية، أو طلب المستخدم نفسه. ولأن لوحة الإدارة تستطيع تقنيًا سرد المحادثات التي يكون المستخدم عضوًا فيها أو كان عضوًا فيها (بما في ذلك الرسائل المحذوفة والمعدّلة والمخفاة)، فلا تُستخدم هذه الصلاحية إلا للمبررات المذكورة وفي كل مرة بسبب كتابي. يُحظر الاطلاع بدافع الفضول أو لغير الغرض؛ ويُنتظر من المسؤولين الالتزام بواجب السرية.
5. **التدقيق.** يجب على المسؤول إدخال سبب كتابي للاطلاع على مضمون الرسائل (10 أحرف على الأقل؛ وفي تصدير المحادثة بناءً على طلب قانوني 20 حرفًا على الأقل مع خطوة تأكيد ثانية منفصلة). ويُكتب الاطلاع تلقائيًا، قبل عرض المحتوى، في سجل وصول غير قابل للتعديل (المسؤول، والمستخدم المعروض، والمحادثة، وعدد الرسائل، والسبب، وعنوان IP، والوقت). وإذا تعذّر كتابة السجل فلا يُعرض المحتوى. وتُحفظ سجلات الوصول 730 يومًا لأغراض التدقيق القانوني والأمني ثم تُحذف.
6. **الرسائل المحذوفة والمعدّلة.** عند اختياركم «حذف للجميع» تظهر الرسالة للمستخدمين الآخرين بعبارة «تم حذف هذه الرسالة»؛ غير أن النسخة المشفّرة من الرسالة وسجل تعديلها ومرفقاتها قد تستمر في الحفظ على الخادم لأغراض الأمان ومراجعة الشكاوى (الافتراضي: دون مدة محددة؛ وعندما يحدد المشغِّل مدة حفظ تُحذف نهائيًا عند انقضائها). كما تُحفظ الإصدارات السابقة من الرسائل التي عدّلتموها مشفّرة. ولا يمكنكم رؤية الرسالة المحذوفة مرة أخرى في واجهة المستخدم؛ ولا تُدرج الرسائل المحذوفة في مخرجات «تنزيل بياناتي».
7. **الصورة ذات الإرسال الواحد.** في هذه الميزة، لا يستطيع المستلم فتح الصورة إلا مرة واحدة؛ وبعد فتحها (أو بعد 24 ساعة من الإرسال) يُغلق وصول المستلم، ولا يستطيع المرسل إعادة فتح ما أرسله. ولكن لأغراض الأمان ومراجعة الشكاوى، ولكي يتمكن المسؤولون المخوّلون من الفحص، يُحفظ ملف الصورة **مشفّرًا على الخادم لمدة 365 يومًا** (مدة قابلة للضبط) ثم يُحذف. ورغم وضع عوائق تقنية أمام التقاط لقطات الشاشة على الجهاز، فإنه **لا يُضمن عدم التقاط لقطة شاشة أو تسجيل للشاشة**؛ إذ يمكن للمستلم تصوير الصورة بجهاز آخر. لذلك لا ترسلوا صورًا لا تريدون أن تقع في يد غيركم.
8. **معاينة الإشعار.** افتراضيًا لا يتضمن الإشعار الفوري نص الرسالة؛ بل يُرسَل إشعار عام من نوع «لديكم رسالة جديدة».
9. **المحادثات عند حذف الحساب.** عند حذفكم حسابكم لا تُحذف الرسائل التي أرسلتموها لأنها جزء من سجل محادثة الطرف الآخر؛ ويظهر اسم الكاتب مجهولًا. أما صور المحادثات التي رفعها الحساب فتُحذف.

> **باختصار:** الرسائل تُحفظ مشفّرة لكنها ليست مشفّرة من طرف إلى طرف. لا يمكن للمسؤولين المخوّلين الاطلاع عليها إلا في حالات مبررة، ويُسجَّل كل وصول. وقد تُحفظ النسخة المشفّرة من الرسائل المحذوفة ومن الصور ذات الإرسال الواحد لمدة لأغراض الأمان. لا يُعطى ضمان مطلق ضد لقطات الشاشة.

## 7. المجتمعات والفعاليات

1. **مسؤولو المجتمعات/الأندية** مسؤولون عن المحتوى والأعضاء في مجتمعاتهم؛ ويجب عليهم الالتزام بقواعد المجتمع وبهذه الشروط. يمكن تفويض صلاحيات الإدارة؛ وقد يطبّق النظام خطوات موافقة عند تفويض الصلاحيات. **إذا حذف مالك النادي حسابه** فتنتقل الملكية تلقائيًا إلى أقدم عضو نشط بدور مسؤول (أو مشرف إن لم يوجد) في النادي، ويُرسَل إشعار إلى المالك الجديد؛ وإن لم يوجد من يتولاها يُغلق النادي ويُبلَّغ أعضاؤه وتُلغى الفعاليات المقبلة المرتبطة به. ويجوز لمسؤولي الخدمة أيضًا إغلاق النادي المخالف للقواعد أو إعادة فتحه أو نقل ملكيته بسبب مُعلَّل.
2. **منشئو الفعاليات** مسؤولون عن صحة معلومات الفعالية وعن مشروعية الفعالية. يتم تسجيل حضور الفعالية برمز QR أو يدويًا؛ وتكون سجلات الحضور مرئية لمنظّم الفعالية وللمسؤولين المخوّلين. وإذا حذف من أنشأ فعالية حسابه، تُلغى فعالياته غير المنتهية التي ليست مرتبطة بنادٍ وتُغلق الطلبات المفتوحة.
3. **غرف المحادثة.** مشاركتكم في غرف المحادثة المنشأة للمجتمعات والفعاليات مرتبطة بعضويتكم؛ وعند إخراجكم من المجتمع أو حظركم تُسقَطون من الغرفة أيضًا. وتُغلق غرف محادثة الفعاليات افتراضيًا خلال 7 أيام بعد انتهاء الفعالية.
4. لا يتحمل المشغِّل مسؤولية الفعاليات التي تنظمها وحدات الجامعة أو المجتمعات ما لم يُنص على خلاف ذلك صراحةً؛ والسلامة الجسدية للفعاليات ومحتواها وإلغاؤها من مسؤولية المنظِّم.

## 8. الملكية الفكرية وحقوق المؤلف

1. برمجية التطبيق وتصميمه وشعاره وعلامته، وكذلك المحتويات الأصلية التي نقدمها، تعود إلى المشغِّل أو إلى مانحي ترخيصه. لا يجوز لكم نسخ البرمجية أو إجراء هندسة عكسية لها أو توزيعها دون إذن.
2. لا تشاركوا محتوى محميًا بحقوق المؤلف يعود لغيركم. وإذا رأيتم أن حق المؤلف الخاص بكم قد انتُهك فتقدموا بالإجراء المبيّن في نص [الإبلاغ عن المحتوى وإزالته](/legal/content-removal)؛ ففي الإخطارات المحقّة يُزال المحتوى، وفي الانتهاكات المتكررة قد يُغلق الحساب.
3. اسم «جامعة بينغول» وشعارها يعودان إلى الجهة المعنية؛ واستخدامهما في الخدمة لا ينشئ أي حق خارج حق الاستخدام الذي تمنحه هذه الشروط.

## 9. المحتويات المصدرية (الأخبار والإعلانات والفعاليات وقائمة الطعام)

1. تُقدَّم معلومات الأخبار والإعلانات والفعاليات وقائمة الطعام بعد تجميعها من المواقع الإلكترونية الرسمية لجامعة بينغول (bingol.edu.tr وsks.bingol.edu.tr). وتعود حقوق هذه المحتويات إلى الجهة المعنية.
2. يتم التجميع تلقائيًا وعلى فترات منتظمة (الأخبار يوميًا وقائمة الطعام شهريًا)؛ وعند تغيّر الموقع المصدر أو تعذّر الوصول إليه قد تكون المعلومات ناقصة/قديمة مؤقتًا وقد يعرض التطبيق تنبيه «قيد الصيانة». **وللحصول على المعلومات الرسمية تكون الصفحة المصدرية هي المعتمدة؛** ولا تحلّ الخدمة محل الإعلان الرسمي.
3. إذا كان المحتوى المصدري غير لائق أو خاطئًا فقد يلزم إبلاغ صاحب المصدر؛ ولطلبات الإخفاء من التطبيق استخدموا قسم الدعم.

## 10. مستوى الخدمة وحدود المسؤولية

1. تُقدَّم الخدمة «كما هي» و«بحالتها المتاحة». ولا يُعطى أي ضمان صريح أو ضمني بأنها ستعمل دون انقطاع أو دون أخطاء أو على كل جهاز، أو بأنها ملائمة لغرض معين، أو بأن محتواها (ولا سيما المعلومات المجمّعة من المواقع المصدرية) صحيح وكامل ومحدَّث؛ وقد تحدث انقطاعات بسبب الصيانة والتحديث والقوة القاهرة وخدمات الأطراف الثالثة (البريد الإلكتروني، وبنية الإشعارات، والاستضافة). وقد يُطبَّق تحديث إلزامي أو وضع الصيانة. لا تمسّ هذه الفقرة حقوقكم التي لا يجوز إسقاطها قانونًا.
2. بما أن الخدمة مجانية، فإننا، بالقدر الذي يسمح به القانون، لا نتحمل المسؤولية عن الأضرار غير المباشرة، وفوات الربح، وفقدان البيانات، وفقدان السمعة، والأضرار الناشئة عن محتويات الأطراف الثالثة؛ ومسؤوليتنا عن الأضرار المباشرة أيضًا، باستثناء العمد والخطأ الجسيم، محدودة بالقدر الذي يسمح به القانون وبالضرر الذي يثبت في الواقعة المعنية. ولسنا طرفًا في النزاعات الناشئة عن علاقات المستخدمين ببعضهم ولقاءاتهم وما يحدث في الفعاليات وتصرفاتهم خارج الخدمة. ولا يسري هذا التحديد في حالات العمد والخطأ الجسيم والحالات التي لا يجوز تحديدها قانونًا (بما في ذلك القواعد القانونية الآمرة وحقوق الشخصية وأضرار الوفاة/الإصابة).
3. لا نضمن صحة محتويات المستخدمين؛ ومشاركات الأطراف الثالثة مسؤوليتهم. وبصفتنا مزوّد استضافة بموجب القانون رقم 5651 (القانون التركي المتعلق بتنظيم المنشورات على الإنترنت ومكافحة الجرائم المرتكبة عبرها)، نتخذ الإجراءات اللازمة بناءً على إخطار مستوفٍ للأصول عند علمنا بمحتوى مخالف للقانون.
4. **النسخ الاحتياطية للرسائل والوسائط.** لأن الرسائل والوسائط تُحفظ مشفّرة، فقد لا يمكن استردادها في حال فقدان مفتاح التشفير الرئيسي؛ وتؤخذ النسخ الاحتياطية للخادم مشفّرة وتُحفظ لمدة محدودة. احتفظوا بنسخة احتياطية من وثائقكم المهمة بأنفسكم.

## 11. التعويض

تكونون مسؤولين، بقدر خطئكم، عن جبر الأضرار المعقولة (بما في ذلك أتعاب المحاماة المعقولة) الناشئة عن مطالبات الأطراف الثالثة الموجهة إلى المشغِّل بسبب إخلالكم بهذه الشروط أو بقواعد المجتمع أو بالقانون. ولا يزيل هذا الحكم حدود المسؤولية القانونية التي ينص عليها القانون.

## 12. التعديلات وإعادة الموافقة

1. يجوز لنا تحديث الشروط لأسباب قانونية أو تقنية. تتوفر النسخة الحالية وسجل الإصدارات في هذه الصفحة.
2. في التعديلات الجوهرية يطلب منكم التطبيق **إعادة الموافقة** على الإصدار الجديد؛ وإلى أن تعيدوا الموافقة قد يُقيَّد وصولكم إلى بعض أجزاء الخدمة (ولا سيما عمليات الكتابة). وفي التصحيحات التي ليست في غير مصلحة المستخدم والتي هي للإعلام فقط (مثل حذف ميزة أُلغيت من النص، أو مواءمة مدد الاحتفاظ مع الشيفرة، أو استكمال الترجمات) قد لا تُطلب إعادة الموافقة؛ ويُنشر الإصدار الجديد مع ذلك في هذه الصفحة.
3. يُحفظ إصدار الموافقة ووقتها لغرض الإثبات القانوني حتى بعد حذف الحساب (انظر الاحتفاظ والإتلاف).

## 13. الإنهاء وإغلاق الحساب

1. يمكنكم إغلاق حسابكم في أي وقت من التطبيق أو من [صفحة حذف الحساب](/delete-account). حذف الحساب **هو إخفاء للهوية (إلغاء ارتباط البيانات بصاحبها):** يُجهَّل اسمكم وبريدكم الإلكتروني ومعلومات ملفكم الشخصي، وتُحذف سجلات أجهزة الإشعارات وسجلات الجهاز/IP والتحليلات ومنشوراتكم وإعجاباتكم ومتابعاتكم والأخبار المفضلة وجدولكم الدراسي وعضوياتكم في المجتمعات. أما الرسائل التي أرسلتموها ونص منشورات المجتمعات فتبقى مع ظهور الكاتب مجهولًا لأنها جزء من سياق محادثات الآخرين/المجتمع؛ وتُحفظ سجلات الموافقة على الشروط وآثار الإشراف دون هوية وبشكل محدود. والتفصيل مبيّن في القسم 7 من سياسة الخصوصية وفي نص الإفصاح بموجب KVKK.
2. إذا خالفتم الشروط جاز لنا تعليق حسابكم أو إغلاقه (القسم 5). وإعادة فتح الحساب المغلق تخضع لسلطتنا التقديرية.
3. لا يمس الإنهاءُ الحقوقَ والالتزامات التي نشأت قبل المخالفة، ولا الأحكام التي تقتضي طبيعتها استمرارها (حدّ المسؤولية، والملكية الفكرية، والقانون الواجب التطبيق، إلخ).

## 14. القانون الواجب التطبيق والمحكمة المختصة

1. يُطبَّق على هذه الشروط قانون الجمهورية التركية.
2. تُقدَّم الخدمة مجانًا؛ ولذلك فإن قواعد الاختصاص والتقدم بالطلبات الخاصة في تشريعات المستهلك (القانون رقم 6502) لا تسري إلا بالقدر الذي ينطبق قانونًا. وفي النزاعات الناشئة عن هذه الشروط يختص **محاكم {{controller.jurisdiction|بينغول}} ودوائر التنفيذ فيها**؛ وفي النزاعات المتعلقة بالإجراءات الإدارية تختص المحكمة الإدارية المعنية. وتبقى محفوظة قواعد الاختصاص الآمرة في القانون (بما في ذلك محكمة المستهلك أو لجنة التحكيم في محل إقامتكم إن كانت لكم صفة المستهلك) وحقوقكم القانونية في التقدم بالطلبات؛ ولا يقيّدها هذا البند.

## 15. العلاقة بجامعة بينغول؛ الروابط الخارجية

1. {{controller.relation|الخدمة ليست التطبيق الرسمي لجامعة بينغول؛ ولا تدلي بتصريحات باسم الجامعة ولا تصدر بيانات ملزمة ولا تحل محل الإعلان الرسمي للجامعة. يُقدَّم محتوى الأخبار والإعلانات والفعاليات وقائمة الطعام الخاص بالجامعة مع عبارة «المصدر: bingol.edu.tr» ورابط الصفحة المصدرية. تستخدم العضوية هذا النطاق فقط للتحقق ببريد إلكتروني يعود للجامعة؛ ولا يعني ذلك أن الجامعة أقرّت الخدمة أو تشغّلها أو تتحمل مسؤوليتها.}}
2. قد توجّهكم الخدمة إلى مواقع أطراف ثالثة عبر الموقع المصدر أو الروابط الخارجية أو QR أو الروابط التي يشاركها الغير. ولا سيطرة لنا على محتوى هذه المواقع وممارسات الخصوصية فيها وأمانها؛ ولا نتحمل المسؤولية عنها، والرابط لا يعني التأييد. وتفتحون الروابط على مسؤوليتكم الخاصة.

## 16. تعديل الخدمة والانقطاعات والقوة القاهرة

1. نحتفظ بحق تعديل الخدمة أو ميزاتها أو تقييدها أو تعليقها أو إنهائها كليًا، بإشعار معقول (ودون إشعار في حالات الضرورة الأمنية/القانونية العاجلة). وفي حال انتهاء الخدمة نعلن ذلك مسبقًا قدر الإمكان ونحاول إبقاء ميزة [تنزيل بياناتي](/legal/privacy) متاحة لمدة. ولا يجوز المطالبة بتعويض بسبب تعديل الخدمة المجانية أو إنهائها؛ وتبقى محفوظة حالات العمد والخطأ الجسيم والأحكام الآمرة في القانون.
2. قد تنقطع الخدمة مؤقتًا بسبب الصيانة أو التحديث أو عطل تقني؛ وفي هذه الحالات قد يعرض التطبيق تنبيه «قيد الصيانة».
3. لا تنشأ مسؤولية عن عدم تنفيذ الالتزامات طوال مدة الأحداث الخارجة عن السيطرة المعقولة للأطراف (**القوة القاهرة**) مثل الكوارث الطبيعية والحرب والإرهاب والأوبئة وانقطاع الكهرباء/الإنترنت/البنية التحتية وانقطاعات مزوّدي الأطراف الثالثة والهجمات السيبرانية وتغيّر التشريعات أو القرارات الإدارية/القضائية.

## 17. اتفاق الإثبات والتبليغ

1. يقرّ الطرفان بأن السجلات الموجودة على خوادم الخدمة (سجلات الموافقة على الشروط، وسجلات الجلسات/IP وملخصات الأجهزة، وسجلات الإشراف والوصول، وسجلات البريد الإلكتروني والإشعارات) تُعدّ **دليلًا قاطعًا** بالمعنى الوارد في المادة 193 من قانون أصول المحاكمات المدنية رقم 6100 (HMK). ولا يخل هذا الحكم بالقانون الآمر ولا بسلطة هيئة حماية البيانات الشخصية أو المحكمة في تقدير الأدلة؛ ويبقى محفوظًا لكم حق إثبات مخالفة السجلات للحقيقة.
2. تُرسَل الإخطارات والتبليغات الموجهة إليكم إلى بريدكم الإلكتروني المسجّل وإلى صندوق الإشعارات داخل التطبيق؛ وتُعدّ مبلَّغة لحظة الإرسال. ويقع على عاتقكم الإبقاء على بريدكم الإلكتروني ومعلومات التواصل الخاصة بكم محدَّثة. وتُرسَل الإخطارات الموجهة إلينا عبر {{support.email|قسم الدعم داخل التطبيق}}{{?controller.kep}} أو إلى عنوان KEP (البريد الإلكتروني المسجّل) {{controller.kep}}{{/controller.kep}}.

## 18. أحكام عامة

1. **قابلية التجزئة.** إذا تبيّن أن أي حكم من هذه الشروط باطل أو غير قابل للتطبيق، تبقى الأحكام الأخرى سارية؛ ويُفسَّر الحكم الباطل بأقرب حكم صحيح لغايته.
2. **عدم التنازل.** عدم ممارستنا لحق ما لا يعني التنازل عنه.
3. **الإحالة.** يجوز لنا، في حال نقل الخدمة أو الاندماج أو إعادة الهيكلة، إحالة الخدمة وحقوقنا الناشئة عن هذه الشروط إلى جهة خلف، وفق التشريعات المتعلقة بحماية البيانات الشخصية. ولا يجوز لكم إحالة حقوقكم دون موافقة خطية منا.
4. **الاكتمال واللغة.** تشكّل هذه الشروط والنصوص المحال إليها كامل اتفاق الطرفين. النص التركي هو المعتمد؛ والنصوص بلغات أخرى ترجمات للإعلام، وعند الاختلاف يسود النص التركي.
5. **العناوين.** العناوين ومربعات «باختصار» للتسهيل فقط؛ وهي غير ملزمة في التفسير.

## 19. التواصل

- الأسئلة العامة والاعتراضات والطلبات: {{support.email|قسم الدعم داخل التطبيق}}
{{?controller.email}}- البريد الإلكتروني للمسؤول عن البيانات: {{controller.email}}{{/controller.email}}
{{?controller.kep}}- عنوان KEP (البريد الإلكتروني المسجّل): {{controller.kep}}{{/controller.kep}}
{{?controller.address}}- العنوان: {{controller.address}}{{/controller.address}}$c_terms_ar$, FALSE, TRUE);
END
$do_terms$;

DO $do_privacy$
DECLARE
    v INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = 'PRIVACY';
    UPDATE legal_document SET active = FALSE WHERE type = 'PRIVACY' AND active;
    INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
    ('PRIVACY', 'tr', v, $t_privacy_tr$Gizlilik Politikası$t_privacy_tr$, $c_privacy_tr$Bu politika, BÜ Kampüs uygulaması ve web sitesini kullanırken hangi verilerinizin işlendiğini, neden, ne kadar süre saklandığını ve haklarınızı sade bir dille anlatır. Hukuki çerçeve ve başvuru usulü için [KVKK Aydınlatma Metni](/legal/kvkk) ile birlikte okuyun.

Veri sorumlusu: {{controller.name}}{{?controller.address}}, {{controller.address}}{{/controller.address}}. İletişim: {{controller.email|uygulama içi Destek bölümü}}.

## 1. Kısaca

1. Verilerinizi **satmayız**, reklam amacıyla üçüncü kişilerle paylaşmayız.
2. Yalnızca hizmeti sunmak, güvenliği sağlamak ve yasal yükümlülükler için gerekli veriyi işleriz.
3. Rehber eşleştirme ve anlık bildirim gibi isteğe bağlı izinler **açık rızanıza** bağlıdır ve istediğiniz zaman geri alınabilir ([Açık Rıza Metni](/legal/explicit-consent)). Uygulama **cihaz konumunuzu istemez, toplamaz ve saklamaz**.
4. Mesajlarınız sunucuda şifreli saklanır; ancak sistem **uçtan uca şifreli değildir** ve yetkili yöneticiler, kayda alınarak, gerekçeli durumlarda mesajları görüntüleyebilir.
5. Hesabınızı silerseniz kişisel verileriniz anonimleştirilir; bazı kayıtlar yasal sebeplerle ve başkalarının haklarını korumak için sınırlı şekilde kalır.

## 2. Hangi verileri işliyoruz?

| Veri | Neden | Hukuki sebep | Saklama süresi |
|---|---|---|---|
| **Hesap:** e-posta adresi (herhangi bir sağlayıcıdan), ad-soyad, şifre (yalnızca tek yönlü özet olarak), dil tercihi | Üyelik, kimlik doğrulama, hizmetin sunulması | Sözleşmenin ifası (KVKK m.5/2-c) | Hesap açık olduğu sürece; silinince anonimleştirilir |
| **Google / Apple ile giriş (isteğe bağlı):** sağlayıcının adı, sağlayıcının hesabınız için verdiği kimlik numarası, sağlayıcının bildirdiği e-posta adresi (Apple'da gizli aktarım adresi olabilir) ve ad-soyad; Google/Apple parolanız bize ulaşmaz | Parolasız giriş ve hesabın sağlayıcı kimliğiyle eşleştirilmesi | Sözleşmenin ifası (KVKK m.5/2-c) | Hesap açık olduğu sürece; hesap silinince silinir |
| **Profil:** fakülte, bölüm, sınıf, biyografi, profil fotoğrafı, gizlilik ayarlarınız | Profilinizin diğer kullanıcılara gösterilmesi (alan bazında gizlenebilir) | Sözleşmenin ifası; isteğe bağlı alanlarda açık rıza (m.5/1) | Hesap açık olduğu sürece |
| **Bekleyen kayıt ve doğrulama kodu:** e-posta, kodun özeti | E-posta doğrulaması | Sözleşme öncesi işlem / sözleşmenin ifası | Bekleyen kayıt 1 saat; doğrulama kodu 10 dakika |
| **Oturum:** yenileme anahtarının özeti, oturum durumu | Güvenli oturum yönetimi | Meşru menfaat (m.5/2-f) | Yenileme anahtarı en çok 30 gün; çıkışta/şifre değişiminde silinir |
| **Mesajlar:** metin, fotoğraf, video, düzenleme geçmişi, tepkiler, okundu bilgisi, sohbet ayarları (sessiz/arşiv) | Mesajlaşma hizmeti | Sözleşmenin ifası | Hesap açık olduğu sürece; silinen mesajların şifreli kopyası ve düzenleme geçmişi güvenlik amacıyla saklanır (varsayılan süresiz, ayarlanabilir) |
| **Tek gönderimlik fotoğraf:** şifreli dosya, açılma kaydı | Mesajlaşma ve güvenlik incelemesi | Sözleşmenin ifası; meşru menfaat | Alıcı erişimi bir kez / en çok 24 saat; şifreli kopya yönetici incelemesi için **365 gün** (ayarlanabilir) |
| **Topluluk ve etkinlik verileri:** üyelikler, gönderiler, RSVP, yoklama (QR/elle), başvuru yanıtları, etkinlik geri bildirimi | Topluluk ve etkinlik hizmetleri | Sözleşmenin ifası | Hesap açık olduğu sürece; yoklama/gönderi kayıtları anonim biçimde kalabilir |
| **Gönderiler (Keşfet):** tek fotoğraf, en çok 7 kelimelik kısa metin, beğeniler | Gönderi paylaşımı ve etkileşim | Sözleşmenin ifası | Hesap açık olduğu sürece; gönderi silinince medya dosyası 30 gün sonra diskten silinir; gönderiye bağlanmamış yüklemeler 24 saat sonra silinir. Kulüp gönderisine eklenen görsel, gönderi/kulüp/hesap silinince hemen diskten silinir |
| **Takip ilişkileri ve favori haberler** | Akışınızı oluşturma, içerikleri sonra okumak üzere saklama | Sözleşmenin ifası | Hesap açık olduğu sürece; hesap silinince silinir |
| **Anketler:** katılım kaydı ve oyunuz | Oylama hizmeti | Sözleşmenin ifası | Hesap açık olduğu sürece; hesap silinince katılım kaydı silinir, oy kaydı kimliksizleşir. Gizli ankette oyunuzun hangi seçeneğe verildiği diğer kullanıcılara ve yöneticilere gösterilmez. Bitmiş anketlerin oy kayıtları için ayrı bir otomatik silme süresi uygulanmaz. |
| **Ders programı, ders ve sınav bilgileri:** kendi girdiğiniz dersler, oturumlar, dönem ve sınav kayıtları; duyuru okundu bilgisi | Kişisel ders programı ve sınav takibi | Sözleşmenin ifası | Hesap açık olduğu sürece; hesap silinince silinir |
| **Bildirim kutusu ve tercihler:** bildirim içerikleri, sessiz saatler, tür tercihleri | Bildirim hizmeti | Sözleşmenin ifası | Okunmuş bildirim 30 gün, okunmamış 90 gün sonra silinir; kullanıcı başına en yeni 200 bildirim tutulur |
| **Cihaz bildirim anahtarı (FCM):** anahtar, platform, uygulama sürümü, dil, son görülme | Anlık bildirim göndermek | Sözleşmenin ifası; açık rıza (bildirim izni) | 60 gün görülmeyen anahtar gece temizlenir; çıkışta/hesap silmede silinir |
| **Push bildirim kuyruğu:** hedef kullanıcı/cihaz, bildirim başlığı ve kısa metni, gönderim durumu | Anlık bildirimin kalıcı kuyruktan, yeniden denemeyle gönderilmesi | Sözleşmenin ifası | Bekleyen kayıt en çok 24 saat denenir; gönderilenler 7 gün, başarısız olanlar 30 gün sonra silinir; çıkışta/hesap silmede silinir |
| **Cihaz kimliği ve IP kayıtları:** cihaz tanımlayıcısının geri döndürülemez özeti (HMAC), platform, uygulama sürümü, IP adresi, son görülme ve olay türü (kayıt/giriş/istek) | Güvenlik, kötüye kullanım ve yasaklı kullanıcı engelinin dolanılmasını önleme | Meşru menfaat (m.5/2-f); hukuki yükümlülük (m.5/2-ç) | Varsayılan **90 gün**; engel kayıtları engel sürdükçe (bkz. 6) |
| **Kullanım olayları (analitik):** ekran adı, olay adı, sınırlı özellik değerleri, zaman; son görülme ve günlük aktiflik | Hizmeti iyileştirme, hata/performans takibi; raporlar toplulaştırılmıştır | Meşru menfaat (m.5/2-f) | Ham olaylar **45 gün** (hesap silinince hemen); sonrasında yalnızca kişiye bağlı olmayan, toplulaştırılmış günlük özetler kalır. Günlük aktiflik kaydı (hangi günlerde uygulamayı açtığınız) **400 gün** (hesap silinince hemen) |
| **Destek, geri bildirim, itiraz, rapor:** metinleriniz ve iletişim e-postanız | Taleplerin yanıtlanması, moderasyon | Sözleşmenin ifası; meşru menfaat; hukuki yükümlülük | Hesap silinince metinler temizlenir, kayıt kimliksiz kalır; herkese açık (girişsiz) destek talepleri 365 gün |
| **Uygunsuz ifade filtresi kaydı:** hangi alanda, hangi kullanıcının içeriğinin reddedildiği/işaretlendiği ve zamanı (reddedilen metin kaydedilmez) | Herkese açık alanlarda kötüye kullanımın önlenmesi | Meşru menfaat (m.5/2-f) | 90 gün |
| **Engelleme ve moderasyon kayıtları:** engellediğiniz kişiler, ihlal kayıtları, rapor kararları, yasak izleri | Güvenlik ve moderasyon | Meşru menfaat; hukuki yükümlülük | Moderasyon izi hesap silindikten sonra da kimliksiz tutulur |
| **Yönetici erişim ve işlem kayıtları** (mesaj görüntüleme kaydı dahil) | Hesap verebilirlik, yetkisiz erişimin önlenmesi | Meşru menfaat; hukuki yükümlülük | Yönetici işlem kaydı (IP dahil) 365 gün; mesaj erişim kaydı ve kulüp yönetim işlem kaydı 730 gün (kayıtlar yalnız eklenir, değiştirilemez); süre sonunda silinir |
| **Sözleşme onayları:** belge türü, sürüm, zaman | Rızanın/onayın ispatı | Hukuki yükümlülük; meşru menfaat | Hesap silindikten sonra da saklanır |
| **E-posta kuyruğu:** alıcı, konu, gönderim durumu | Doğrulama/şifre sıfırlama/güvenlik e-postaları ve yönetici duyuruları | Sözleşmenin ifası; duyurularda meşru menfaat | Gönderilen kayıtlar 7 gün, başarısız (gönderilemeyen) kayıtlar 30 gün sonra silinir |
| **Yönetici duyuru e-postaları (kampanya) kayıtları:** kampanya adı ve durumu, alıcı olarak kullanıcı kimliğiniz ve gönderim durumu | Hizmet ve topluluk duyurularının gönderilmesi (reklam/pazarlama değildir; e-postalardaki bağlantıdan abonelikten çıkabilirsiniz). Duyuruda ad, bölüm, fakülte, sınıf gibi profil alanları kişiselleştirme için kullanılabilir | Meşru menfaat (m.5/2-f); sözleşmenin ifası | Kampanya bitiminden 180 gün sonra silinir; hesap silinince alıcı satırınız hemen silinir |
| **Rehber eşleştirme:** rehberinizdeki e-postaların SHA-256 özeti (yalnızca istek sırasında) | Rehberinizde tanıdıklarınızı bulmak | **Açık rıza** (m.5/1) | **Saklanmaz, kaydedilmez**; yalnızca isteğin işlenmesi süresince bellekte |
| **Cihaz konumu** | — | — | Uygulama konum izni **istemez**; cihaz konumu (GPS/ağ) **toplanmaz, sunucuya gönderilmez ve saklanmaz** (bkz. 5) |

> **Özetle:** İşlediğimiz her veri bir amaca bağlıdır; çoğu hesabınız açık olduğu sürece tutulur. Cihaz/IP kayıtları 90 gün, analitik ham olaylar 45 gün, günlük aktiflik kaydı 400 gün, bildirimler okunmuşsa 30/okunmamışsa 90 gün, e-posta kuyruğu 7 gün (başarısızsa 30 gün), duyuru kampanyası kayıtları 180 gün saklanır.

## 3. Mesajlarınız nasıl saklanır ve kim görebilir?

1. **İletim:** Mesajlar TLS/WSS ile şifreli iletilir.
2. **Saklama:** Sunucuda her sohbet için ayrı bir anahtarla AES-256-GCM ile şifreli saklanır. Anahtarlar ayrı bir ana anahtar ile korunur ve veritabanında değil sunucu ortamında tutulur. Bu, veritabanı yedeği ele geçirilse bile mesajların okunmasını zorlaştırır.
3. **Uçtan uca şifreleme DEĞİLDİR.** Ana anahtar bizde olduğundan, sistem mesajları çözebilir. Bunu bilerek kullanın.
4. **Yönetici erişimi:** Yalnızca yetkili yöneticiler (tam yönetici ve moderatör rolündekiler, bkz. 14); şikâyet incelemesi, güvenlik/kötüye kullanım, yasal talepler ve benzeri gerekçelerle, mesajların ve medyanın içeriğini görüntüleyebilir. Yönetici arayüzü; silinmiş, düzenlenmiş ve moderasyonla gizlenmiş mesajlar ile "tek gönderimlik" fotoğrafları ve engellenen kullanıcıya iletilmeyen mesajları da gösterebilir. Yönetici, içeriği görüntülemek için yazılı bir gerekçe girmek zorundadır (en az 10 karakter). **Her görüntüleme**, içerik gösterilmeden önce otomatik olarak değiştirilemez bir kayda yazılır: kim baktı, kimin sohbetine baktı, kaç mesaj, hangi gerekçeyle, hangi IP'den, ne zaman. Kayıt yazılamazsa içerik gösterilmez.
5. **Silinen mesajlar:** "Herkes için sil" diğer kullanıcılar için mesajı gizler; mesajın şifreli kopyası ve eski sürümleri güvenlik incelemesi için saklanabilir. Saklama süresi işletici tarafından ayarlanır (varsayılan: süresiz).
6. **Tek gönderimlik fotoğraflar:** Alıcı bir kez görür, sonra erişimi kapanır; ancak yönetici incelemesi için şifreli dosya 365 gün (ayarlanabilir) saklanır ve sonra silinir. Ekran görüntüsünün engellenmesi için teknik önlemler olsa da mutlak garanti verilmez.
7. **Bildirim önizlemesi:** Varsayılan olarak anlık bildirimde mesaj metni gösterilmez (ayar açılırsa metin Google FCM/Apple APNs üzerinden geçer). Uygulama içi bildirim kutusuna mesaj içeriği hiçbir zaman yazılmaz.
8. **Fotoğraf ve video işleme:** Fotoğraflar (profil, kapak, gönderi, sohbet) türü/boyutu doğrulanıp yeniden kodlanır, EXIF (konum vb.) temizlenir. **Sohbet videoları** cihazınızda sıkıştırılır; sunucu videoyu yeniden kodlamaz ve **video dosyasının içindeki üst verileri (çekim zamanı, konum etiketi vb.) temizlemez**: yalnızca tür, boyut ve süre doğrulanır, video sohbete özgü anahtarla şifreli saklanır. Cihazınızın sıkıştırması bu üst verileri kaldırmayabilir; konum veya kişisel bilgi içerebilecek videoları göndermeden önce dikkatli olun. Videonun kapak (önizleme) görseli ise fotoğraf gibi yeniden kodlanır ve üst verisi temizlenir. Gönderiler yalnızca tek fotoğraf içerir. Görsellerin özeti, yasaklı içerik özet listesiyle karşılaştırılır; görsel içeriği otomatik analiz edilmez.
9. **Engelleme:** Engellediğiniz kişinin size yazdığı mesajlar size iletilmez; engellenen kişiye bildirim yapılmaz. Bu mesajlar sistemde kalır ve yalnızca yetkili yöneticilerce, şikâyet incelemesi gibi gerekçelerle görülebilir.

> **Özetle:** Mesajlar şifreli saklanır ama uçtan uca değil. Yetkili yöneticiler yalnızca gerekçeli durumda, her seferinde kayda alınarak görüntüleyebilir. Silinen mesajlar ve tek gönderimlik fotoğrafların şifreli kopyası güvenlik için bir süre saklanabilir.

## 4. Verilerinizi kimlerle paylaşırız?

| Alıcı | Ne paylaşılır? | Amaç | Konum |
|---|---|---|---|
| **Google Firebase Cloud Messaging (FCM)** (ve iOS için Apple APNs) | Cihaz bildirim anahtarı, bildirim başlığı/kısa metni, hedef bilgisi | Anlık bildirim iletimi | Yurt dışı (Google/Apple altyapısı); bkz. KVKK Aydınlatma Metni |
| **E-posta gönderim hizmeti sağlayıcısı: Brevo (SMTP)** (veri işleyen) | Alıcı e-posta adresi, e-posta içeriği (doğrulama kodu, duyuru metni; duyurularda kişiselleştirme için ad ve bölüm/fakülte/sınıf bilgisi) | Doğrulama, şifre sıfırlama, güvenlik e-postaları ve yönetici duyuruları | Yurt dışı olabilir (sağlayıcının sunucuları Avrupa'da veya başka ülkelerde bulunabilir); bkz. KVKK Aydınlatma Metni |
| **Barındırma / sunucu sağlayıcısı** | Tüm hizmet verisi (şifreli mesajlar dahil) | Hizmetin barındırılması | {{hosting.location|Barındırma konumu yayın öncesi belirtilir}} |
| **Yetkili kamu kurumları** (mahkeme, savcılık, kolluk, KVKK Kurulu vb.) | Talep kapsamındaki veri | Hukuki yükümlülük | Yurt içi |

Reklam ağları, veri komisyoncuları veya sosyal medya takip araçlarıyla veri paylaşmayız. **Kullanıcı verilerini Bingöl Üniversitesi'ne veya birimlerine aktarmayız;** Hizmet üniversitenin sitelerinden yalnızca herkese açık haber, duyuru, etkinlik ve yemek listesi içeriğini okur. Yönetim paneli yöneticileri üniversite adına çalışmaz (bkz. 14). Bir not: e-postalarımız kayıtlı e-posta adresinize gönderildiğinden, o posta kutusunu işleten kuruluş (e-posta sağlayıcınız; bingol.edu.tr adresi kullanıyorsanız üniversite) e-postayı kendi altyapısında teknik olarak işleyebilir; bu, bizim yaptığımız bir veri aktarımı değil, e-postanın doğasıdır. Google veya Apple ile giriş yaparsanız kimlik doğrulaması cihazınız ile ilgili sağlayıcı arasında gerçekleşir; sunucumuz yalnızca sağlayıcının imzalı kimlik belirtecini doğrular, sizin adınıza sağlayıcıya veri göndermez. Sağlayıcıların kendi işlemeleri kendi gizlilik politikalarına tabidir.

## 5. İzinler ve isteğe bağlı özellikler

1. **Bildirim izni:** İsterseniz anlık bildirim alırsınız. Reddederseniz uygulama içi bildirim kutusu çalışmaya devam eder. Bildirim türlerini ve **sessiz saatleri** ayarlardan yönetirsiniz.
2. **Rehber eşleştirme:** Rehber erişimi izni verirseniz, tanıdıklarınızı bulmak için rehberinizdeki e-posta adreslerinin **yalnızca SHA-256 özeti** (en çok 500 adet / istek) sunucuya gönderilir. Özetler **saklanmaz ve kayda geçirilmez**; yalnızca eşleşen kullanıcılar (gizlilik ayarlarına saygı gösterilerek) cevap olarak size döner. Rehber isimleriniz, telefon numaralarınız sunucuya gönderilmez. Kötüye kullanım için saatlik istek sınırı vardır.
3. **Konum:** Uygulama cihazınızdan konum (GPS/ağ tabanlı) **izni istemez**; konumunuzu toplamaz, sunucuya göndermez ve saklamaz. Güvenlik amacıyla kaydedilen IP adresi (bkz. 6) cihaz konumu değildir; uygulama kodunda IP adresinden konum veya bölge çıkarımı yapılmaz. Barındırma ve ağ altyapısı sağlayıcıları kendi teknik kayıtlarını kendi politikalarına göre tutabilir; bu kayıtlar tarafımızca konum belirlemek için kullanılmaz. Gelecekte konum işlenecekse bu metin güncellenir ve yeniden açık rızanız alınır.
4. İzinleri istediğiniz an cihaz ayarlarından veya uygulamadaki İzinler ekranından geri alabilirsiniz. Geri alma, geri alma anından önceki işlemlerin hukuka uygunluğunu etkilemez.

## 6. Cihaz ve IP kayıtları, erişim engelleri

1. Güvenlik amacıyla; kayıt, giriş, oturum yenileme ve istekler sırasında cihaz tanımlayıcınızın geri döndürülemez özeti, platform, uygulama sürümü, IP adresi ve zaman bilgisi kaydedilir. Ham cihaz tanımlayıcısı saklanmaz.
2. Bu kayıtlar varsayılan **90 gün** saklanır ve gecelik olarak temizlenir. Süre işletici tarafından ayarlanabilir; yasal bir saklama yükümlülüğü doğarsa (ör. 5651 sayılı Kanun kapsamında trafik bilgisi) süre buna göre belirlenebilir ve bu politika güncellenir.
3. Kötüye kullanım nedeniyle yasaklanan bir kullanıcının IP adresi, ağ aralığı, cihaz özeti veya kullanıcı kimliği için **erişim engeli** tanımlanabilir. Engel kaydı (neden kodu, tarih, varsa süre ve notlar) engel sürdükçe ve itiraz/denetim için gerekli süre boyunca saklanır. Engele takılan denemeler (IP, cihaz özeti, istek yolu, zaman) güvenlik kaydı olarak tutulur ve cihaz/IP kayıtlarıyla aynı temizleme ilkesine tabidir. VPN/Tor/veri merkezi gibi anonimleştirici aralıklardan gelen istekler güvenlik amacıyla kısıtlanabilir.
4. Engellendiğinizi düşünüyorsanız Destek bölümünden veya itiraz özelliğinden başvurabilirsiniz.

## 7. Hesap silme ve veri taşınabilirliği

**Verilerimi indir:** Profil > Verilerimi indir ile kendi verilerinizi (günde 3 kez sınırla) JSON olarak indirebilirsiniz. Çıktı; profil ve gizlilik ayarlarınızı, onay kayıtlarınızı, mesajlarınızı ve sohbet üyeliklerinizi, gönderi ve beğenilerinizi, takiplerinizi, favori haberlerinizi, topluluk üyeliklerinizi ve gönderilerinizi, etkinlik katılım, başvuru ve yoklama kayıtlarınızı, oluşturduğunuz etkinlikleri, size gelen duyuru e-postası kampanyalarını, bildirimlerinizi ve cihaz kayıtlarınızı, destek taleplerinizi ve cihaz/IP geçmişinizi içerir. Silinmiş mesajlar çıktıya dahil değildir. Bir bölüm geçici olarak hazırlanamazsa o bölümde hata işareti görünür, diğer bölümler yine verilir.

**Hesap silme = anonimleştirme.** Hesabınızı sildiğinizde:

| Ne olur? | Hangi veriler |
|---|---|
| **Silinir** | Bildirim cihaz anahtarlarınız ve bekleyen push kayıtlarınız, bildirim kutunuz ve tercihleriniz, takip ilişkileriniz, ders programı ve sınav kayıtlarınız, anket katılım kaydınız, beğenileriniz, Keşfet gönderileriniz (medya dosyaları 30 gün sonra diskten kalkar), favori haberleriniz, geri bildirim oylarınız, etkinlik geri bildirimleriniz, engelleme listeniz, kulüp başvuru yanıtlarınız, topluluk üyelikleriniz, duyuru e-postası kampanyalarındaki alıcı satırlarınız, yüklediğiniz sohbet fotoğrafları, **cihaz/IP kayıtlarınız, analitik olaylarınız ve günlük aktiflik kaydınız (hemen)**, kulüp gönderilerine eklediğiniz görseller (hemen, diskten). Etkinlik başvurularınız kapatılır (bekleme listesindeki sıradaki kişi yer alır) ve oluşturduğunuz, kulübe bağlı olmayan bitmemiş etkinlikler iptal edilir. **Kulüp sahibiyseniz:** sahiplik kulübün en eski aktif yöneticisine (yoksa moderatörüne) devredilir; devralacak kimse yoksa kulüp kapatılır ve üyelerine bildirilir |
| **Anonimleştirilir** | Ad, e-posta, profil bilgileri, biyografi, fotoğraf; anket oy kayıtları (kullanıcı bağlantısı koparılır); destek, geri bildirim, itiraz, rapor ve etkinlik başvurusu metinleri temizlenir (kayıt kimliksiz kalır) |
| **Korunur (sınırlı)** | Gönderdiğiniz mesajlar ve topluluk gönderileri (başkalarının sohbet bağlamının parçası; yazar "Silinmiş kullanıcı" gibi anonim görünür); sözleşme onay kayıtları (hukuki kanıt); moderasyon ihlal/rapor ve yasak izleri; anonim yoklama/RSVP sayaçları; yönetici işlem ve erişim kayıtları |
| **Süreyle temizlenir** | Cihaz/IP kayıtları (90 gün), uygunsuz ifade filtresi kaydı (90 gün), analitik ham olaylar (45 gün), günlük aktiflik kaydı (400 gün), e-posta kuyruğu (gönderilen 7 gün, başarısız 30 gün), duyuru kampanyası kayıtları (180 gün), yönetici işlem kaydı (365 gün), mesaj erişim ve kulüp işlem kaydı (730 gün) |

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

Hizmet 18 yaşından küçükler için tasarlanmamıştır; kayıt herhangi bir geçerli e-posta adresiyle yapılabildiğinden kayıt sırasında yaş sorulmaz veya doğrulanmaz. 18 yaşından küçük bir kullanıcının kaydı tespit edilirse yasal temsilcinin bilgisi ve onayı aranabilir; gerekirse hesap kapatılır ve veriler silinir/anonimleştirilir.

## 11. Haklarınız

KVKK m.11 uyarınca verilerinize erişme, düzeltme, silme, itiraz ve diğer haklarınız vardır. Başvuru yolları ve 30 gün yanıt süresi [KVKK Aydınlatma Metni](/legal/kvkk) ve [Saklama ve İmha](/legal/retention) metinlerindedir. Hızlı yollar: Profil bilgilerini düzenleme, gizlilik ayarları, Verilerimi indir, Hesabı sil, Destek bölümü.

## 12. Değişiklikler

Bu politikayı güncelleyebiliriz. Önemli değişikliklerde sizden yeniden onay alırız; güncel sürüm ve geçmiş bu sayfada yer alır.

## 13. Gönderiler ve içerik denetimi

1. **Kimler görür?** Gönderiler uygulamaya giriş yapmış diğer kullanıcılara gösterilir; engellediğiniz veya sizi engelleyen kullanıcılarla karşılıklı görünürlük kapanır. Uygulamada sunulan görünürlük seçenekleri ilgili ekranda gösterilir.
2. **Kulüp gönderisi görselleri.** Kulüp gönderisine eklediğiniz görsel, gönderiyi sildiğinizde, kulüp kapandığında veya hesabınızı sildiğinizde bağlantısı kaldırılır ve dosya diskten silinir.
3. **Uygunsuz ifade filtresi.** Topluluk, etkinlik, profil ve gönderi gibi herkese açık alanlarda küfür, hakaret ve benzeri ifadeler otomatik olarak reddedilebilir. **Sohbet mesajları (birebir ve grup) ön denetimden geçirilmez.** Filtre yalnızca kayıt anında çalışır; hangi alanın, hangi kullanıcının içeriğinin reddedildiği 90 gün saklanır, reddedilen metin kaydedilmez. Reddedilen içerik yayımlanmaz; karar insan incelemesi olmadan otomatik verilir ve itirazınızı Destek bölümünden iletebilirsiniz.
4. **Şikâyet ve kaldırma.** Gönderi ve mesajlar **Bildir** ile şikâyet edilebilir; yetkili yöneticiler inceler, içeriği gizleyebilir veya kaldırabilir. Aynı içerik birbirinden bağımsız birkaç hesap tarafından bildirilirse, inceleme tamamlanana kadar otomatik ve geçici olarak gizlenebilir; yönetici incelemesi sonucunda yeniden görünür kılınabilir. Usul için [İçerik Bildirimi ve Kaldırma](/legal/content-removal) ve [Topluluk Kuralları](/legal/community-rules) metinlerine bakın.

## 14. Yönetici rolleri ve erişim yetkileri

1. **Kimdir?** Yönetim paneline erişen hesaplar İşletici tarafından tanımlanır ve beş rolden birini taşır: *tam yönetici*, *moderatör*, *destek*, *editör*, *salt okunur*. Yöneticiler üniversite adına çalışmaz; bir yönetici rolü, kişisel verinin üniversiteye aktarılması anlamına gelmez.
2. **Kişisel veriye erişim rolle sınırlıdır.** Maskesiz e-posta, IP ve cihaz ayrıntısını yalnızca tam yönetici ve moderatör görür; destek, editör ve salt okunur rollerinde bu alanlar maskelidir (ör. a•••@gmail.com). Destek rolü destek taleplerini ve geri bildirimleri, editör haber, duyuru ve iletişim içeriklerini yönetir; salt okunur rol yalnızca izleme yapar.
3. **Özel yazışmalar.** Mesajların ve sohbet medyasının içeriğine yalnızca tam yönetici ve moderatör erişebilir; yönetici olmayan hiç kimse erişemez. Bu erişim 3. bölümdeki koşullara bağlıdır: yalnızca şikâyet incelemesi, güvenlik/kötüye kullanım şüphesi veya yasal talep gibi gerekçelerle, yazılı gerekçeyle ve değiştirilemez erişim kaydıyla (730 gün). Yönetim paneli teknik olarak bir kullanıcının sohbetlerini listeleyebildiğinden, bu yetkinin amaç dışı kullanılmaması yalnızca bu kurallara ve kayda dayanır; amaç dışı görüntüleme yasaktır.
4. **Müdahale yetkileri.** Yetkili yöneticiler bir mesajı gizleyebilir (geri alınabilir) veya kalıcı silebilir, sohbeti kapatabilir, üyeyi sohbetten çıkarabilir, gönderi ve diğer içerikleri gizleyebilir veya kaldırabilir, kulüp kapatabilir, hesabı askıya alabilir veya erişim engeli tanımlayabilir. Yazma işlemleri yönetici işlem kaydına yazılır (365 gün); kritik işlemlerde (mesaj/sohbet müdahalesi, rol değişikliği, hesap ve kulüp işlemleri) yazılı gerekçe zorunludur.
5. **Rollerin yönetimi.** Yönetici rollerinin atanması ve değiştirilmesi de denetim kaydına yazılır.

## 15. İletişim

{{support.email|Uygulama içi Destek bölümü}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}$c_privacy_tr$, FALSE, TRUE),
    ('PRIVACY', 'en', v, $t_privacy_en$Privacy Policy$t_privacy_en$, $c_privacy_en$*This English text is a translation provided for information only. The Turkish text is authoritative; if there is any difference, the Turkish text prevails.*

This policy explains in plain language which of your data is processed while you use the BÜ Kampüs application and website, why, how long it is kept, and your rights. For the legal framework and the application procedure, read it together with the [KVKK Privacy Notice](/legal/kvkk).

Data controller: {{controller.name}}{{?controller.address}}, {{controller.address}}{{/controller.address}}. Contact: {{controller.email|in-app Support section}}.

## 1. In short

1. We do **not sell** your data and do not share it with third parties for advertising.
2. We process only the data necessary to provide the service, ensure security and meet legal obligations.
3. Optional permissions such as contact matching and push notifications depend on your **explicit consent** and can be withdrawn at any time ([Explicit Consent text](/legal/explicit-consent)). The app **does not ask for, collect or store your device location**.
4. Your messages are stored encrypted on the server; however, the system is **not end-to-end encrypted** and authorised administrators may view messages in reasoned cases, with the access being recorded.
5. If you delete your account, your personal data is anonymised; some records remain in limited form for legal reasons and to protect the rights of others.

## 2. What data do we process?

| Data | Why | Legal basis | Retention period |
|---|---|---|---|
| **Account:** e-mail address (from any provider), name, password (only as a one-way digest), language preference | Membership, authentication, providing the service | Performance of a contract (KVKK Art. 5/2-c) | While the account is open; anonymised on deletion |
| **Sign in with Google / Apple (optional):** name of the provider, the identifier the provider assigns to your account, the e-mail address reported by the provider (may be a private relay address with Apple) and your name; your Google/Apple password never reaches us | Passwordless sign-in and matching the account to the provider identity | Performance of a contract (KVKK Art. 5/2-c) | While the account is open; deleted on account deletion |
| **Profile:** faculty, department, year, biography, profile photo, your privacy settings | Showing your profile to other users (can be hidden field by field) | Performance of a contract; explicit consent for optional fields (Art. 5/1) | While the account is open |
| **Pending registration and verification code:** e-mail, digest of the code | E-mail verification | Pre-contractual step / performance of a contract | Pending registration 1 hour; verification code 10 minutes |
| **Session:** digest of the refresh token, session state | Secure session management | Legitimate interest (Art. 5/2-f) | Refresh token at most 30 days; deleted on sign-out/password change |
| **Messages:** text, photos, videos, edit history, reactions, read state, chat settings (mute/archive) | Messaging service | Performance of a contract | While the account is open; the encrypted copy and edit history of deleted messages are kept for security (default indefinite, adjustable) |
| **View-once photo:** encrypted file, open record | Messaging and security review | Performance of a contract; legitimate interest | Recipient access once / at most 24 hours; encrypted copy for administrator review **365 days** (adjustable) |
| **Community and event data:** memberships, posts, RSVP, attendance (QR/manual), application answers, event feedback | Community and event services | Performance of a contract | While the account is open; attendance/post records may remain anonymously |
| **Posts (Discover):** a single photo, a short text of at most 7 words, likes | Sharing posts and interaction | Performance of a contract | While the account is open; after a post is deleted its media file is removed from disk after 30 days; uploads not attached to a post are deleted after 24 hours. An image attached to a club post is deleted from disk immediately when the post/club/account is deleted |
| **Follow relationships and bookmarked news** | Building your feed, saving content to read later | Performance of a contract | While the account is open; deleted when the account is deleted |
| **Polls:** participation record and your vote | Voting service | Performance of a contract | While the account is open; when the account is deleted the participation record is deleted and the vote record becomes unlinked from you. In a secret poll, which option you voted for is not shown to other users or administrators. No separate automatic deletion period applies to the vote records of finished polls. |
| **Timetable, course and exam information:** courses, sessions, semester and exam records you enter yourself; announcement read state | Personal timetable and exam tracking | Performance of a contract | While the account is open; deleted when the account is deleted |
| **Notification inbox and preferences:** notification contents, quiet hours, type preferences | Notification service | Performance of a contract | Read notifications are deleted after 30 days, unread after 90 days; the newest 200 notifications per user are kept |
| **Device notification token (FCM):** token, platform, app version, language, last seen | Sending push notifications | Performance of a contract; explicit consent (notification permission) | A token unseen for 60 days is cleaned up nightly; deleted on sign-out/account deletion |
| **Push notification queue:** target user/device, notification title and short text, delivery status | Delivering push notifications from a persistent queue with retries | Performance of a contract | A pending entry is retried for at most 24 hours; sent entries are deleted after 7 days, failed ones after 30 days; deleted on sign-out/account deletion |
| **Device ID and IP records:** non-reversible digest of the device identifier (HMAC), platform, app version, IP address, last seen and event type (registration/sign-in/request) | Security, abuse and preventing circumvention of a ban on a banned user | Legitimate interest (Art. 5/2-f); legal obligation (Art. 5/2-ç) | Default **90 days**; ban records for as long as the ban lasts (see 6) |
| **Usage events (analytics):** screen name, event name, limited property values, time; last seen and daily activity | Improving the service, error/performance tracking; reports are aggregated | Legitimate interest (Art. 5/2-f) | Raw events **45 days** (immediately on account deletion); afterwards only non-personal aggregated daily summaries remain. The daily activity record (on which days you opened the app) **400 days** (immediately on account deletion) |
| **Support, feedback, appeal, report:** your texts and contact e-mail | Answering requests, moderation | Performance of a contract; legitimate interest; legal obligation | On account deletion the texts are cleared and the record remains without identity; public (signed-out) support requests 365 days |
| **Inappropriate-language filter record:** in which area, whose content was rejected/flagged and when (the rejected text is not stored) | Preventing abuse in public areas | Legitimate interest (Art. 5/2-f) | 90 days |
| **Blocking and moderation records:** people you blocked, violation records, report decisions, ban traces | Security and moderation | Legitimate interest; legal obligation | The moderation trail is kept without identity even after the account is deleted |
| **Administrator access and action records** (including the message-viewing record) | Accountability, preventing unauthorised access | Legitimate interest; legal obligation | Administrator action record (including IP) 365 days; message-access record and club management action record 730 days (records are append-only and cannot be changed); deleted at the end of the period |
| **Agreement acceptances:** document type, version, time | Proof of consent/acceptance | Legal obligation; legitimate interest | Kept even after the account is deleted |
| **E-mail queue:** recipient, subject, delivery status | Verification/password reset/security e-mails and administrator announcements | Performance of a contract; legitimate interest for announcements | Sent records are deleted after 7 days, failed (undeliverable) records after 30 days |
| **Administrator announcement e-mail (campaign) records:** campaign name and status, your user ID as the recipient and the delivery status | Sending service and community announcements (not advertising/marketing; you can unsubscribe through the link in the e-mails). Profile fields such as name, department, faculty and year may be used for personalisation in announcements | Legitimate interest (Art. 5/2-f); performance of a contract | Deleted 180 days after the campaign ends; your recipient row is deleted immediately when your account is deleted |
| **Contact matching:** SHA-256 digests of the e-mails in your contacts (only during the request) | Finding people you know in your contacts | **Explicit consent** (Art. 5/1) | **Not stored, not recorded**; only in memory while the request is processed |
| **Device location** | — | — | The app **does not ask** for location permission; device location (GPS/network) is **not collected, not sent to the server and not stored** (see 5) |

> **In short:** Every item of data we process is tied to a purpose; most is kept while your account is open. Device/IP records are kept 90 days, raw analytics events 45 days, the daily activity record 400 days, notifications 30 days if read and 90 if unread, the e-mail queue 7 days (30 days if failed), and announcement campaign records 180 days.

## 3. How are your messages stored and who can see them?

1. **Transmission:** Messages are transmitted encrypted with TLS/WSS.
2. **Storage:** On the server each chat is stored encrypted with AES-256-GCM using a separate key. The keys are protected by a separate master key and are kept in the server environment, not in the database. This makes it harder to read the messages even if a database backup is captured.
3. **It is NOT end-to-end encryption.** Because the master key is with us, the system can decrypt messages. Use it knowing this.
4. **Administrator access:** Only authorised administrators (those with the full administrator and moderator roles, see 14) may view the content of messages and media, for reasons such as report review, security/abuse and legal requests. The administrator interface can also show deleted, edited and moderation-hidden messages, "view-once" photos, and messages not delivered to a blocked user. The administrator must enter a written reason to view the content (at least 10 characters). **Every viewing** is written, before the content is shown, to a tamper-resistant record automatically: who looked, whose chat they looked at, how many messages, for what reason, from which IP, and when. If the record cannot be written, the content is not shown.
5. **Deleted messages:** "Delete for everyone" hides the message from other users; the encrypted copy of the message and its old versions may be kept for security review. The retention period is set by the operator (default: indefinite).
6. **View-once photos:** The recipient sees it once, then access closes; however, for administrator review the encrypted file is kept for 365 days (adjustable) and then deleted. Although there are technical measures to prevent screenshots, no absolute guarantee is given.
7. **Notification preview:** By default the message text is not shown in push notifications (if the setting is turned on, the text passes through Google FCM/Apple APNs). Message content is never written to the in-app notification inbox.
8. **Photo and video processing:** Photos (profile, cover, post, chat) are re-encoded after their type/size is verified, and EXIF (location, etc.) is removed. **Chat videos** are compressed on your device; the server does not re-encode the video and **does not remove the metadata inside the video file (recording time, location tag, etc.)**: only the type, size and duration are verified, and the video is stored encrypted with a chat-specific key. Your device's compression may not remove this metadata; be careful before sending videos that may contain location or personal information. The cover (preview) image of a video, however, is re-encoded like a photo and its metadata is removed. Posts contain only a single photo. The digests of images are compared with the prohibited-content digest list; the content of images is not analysed automatically.
9. **Blocking:** Messages written to you by a person you blocked are not delivered to you; the blocked person is not notified. These messages remain in the system and may be seen only by authorised administrators for reasons such as report review.

> **In short:** Messages are stored encrypted but not end-to-end. Authorised administrators may view them only in reasoned cases, each time with a record. The encrypted copies of deleted messages and view-once photos may be kept for a period for security.

## 4. With whom do we share your data?

| Recipient | What is shared? | Purpose | Location |
|---|---|---|---|
| **Google Firebase Cloud Messaging (FCM)** (and Apple APNs for iOS) | Device notification token, notification title/short text, target information | Delivering push notifications | Abroad (Google/Apple infrastructure); see the KVKK Privacy Notice |
| **E-mail delivery service provider: Brevo (SMTP)** (processor) | Recipient e-mail address, e-mail content (verification code, announcement text; in announcements name and department/faculty/year information for personalisation) | Verification, password reset, security e-mails and administrator announcements | May be abroad (the provider's servers may be in Europe or other countries); see the KVKK Privacy Notice |
| **Hosting / server provider** | All service data (including encrypted messages) | Hosting the service | {{hosting.location|The hosting location is stated before publication}} |
| **Competent public authorities** (court, public prosecutor, law enforcement, the KVKK Board, etc.) | Data within the scope of the request | Legal obligation | Domestic |

We do not share data with advertising networks, data brokers or social-media tracking tools. **We do not transfer user data to Bingöl University or its units;** the Service only reads publicly available news, announcements, events and menu content from the university's sites. Management panel administrators do not act on behalf of the university (see 14). A note: because our e-mails are sent to your registered e-mail address, the organisation that operates that mailbox (your e-mail provider; the university if you use a bingol.edu.tr address) may technically process the e-mail on its own infrastructure; this is not a data transfer made by us but the nature of e-mail. If you sign in with Google or Apple, authentication takes place between your device and that provider; our server only verifies the provider's signed identity token and sends no data to the provider on your behalf. The providers' own processing is subject to their own privacy policies.

## 5. Permissions and optional features

1. **Notification permission:** You receive push notifications if you wish. If you decline, the in-app notification inbox continues to work. You manage notification types and **quiet hours** in settings.
2. **Contact matching:** If you grant contacts access, only the **SHA-256 digests** of the e-mail addresses in your contacts (at most 500 per request) are sent to the server in order to find people you know. The digests are **not stored and not recorded**; only the matching users (respecting their privacy settings) are returned to you in the response. Your contact names and phone numbers are not sent to the server. There is an hourly request limit to prevent abuse.
3. **Location:** The app **does not ask for permission** for location (GPS/network based) from your device; it does not collect, send to the server or store your location. The IP address recorded for security (see 6) is not device location; no location or region is derived from the IP address in the application code. Hosting and network infrastructure providers may keep their own technical records according to their own policies; these records are not used by us to determine location. If location is to be processed in the future this text will be updated and your explicit consent will be obtained again.
4. You can withdraw permissions at any time from the device settings or the Permissions screen in the app. Withdrawal does not affect the lawfulness of processing before the moment of withdrawal.

## 6. Device and IP records, access bans

1. For security, at registration, sign-in, session renewal and requests, a non-reversible digest of your device identifier, the platform, app version, IP address and time information are recorded. The raw device identifier is not stored.
2. These records are kept for **90 days** by default and are cleaned up nightly. The period can be adjusted by the operator; if a legal retention duty arises (e.g. traffic information under Law No. 5651), the period may be set accordingly and this policy will be updated.
3. An **access ban** may be defined for the IP address, network range, device digest or user ID of a user banned for abuse. The ban record (reason code, date, duration if any, and notes) is kept for as long as the ban lasts and for the period needed for appeal/audit. Attempts caught by a ban (IP, device digest, request path, time) are kept as a security record and are subject to the same cleanup principle as device/IP records. Requests from anonymising ranges such as VPN/Tor/data centres may be restricted for security.
4. If you think you were banned, you can apply from the Support section or the appeal feature.

## 7. Account deletion and data portability

**Download my data:** With Profile > Download my data you can download your own data (limited to 3 times a day) as JSON. The output includes your profile and privacy settings, your acceptance records, your messages and chat memberships, your posts and likes, your follows, your bookmarked news, your community memberships and posts, your event attendance, application and attendance records, the events you created, the announcement e-mail campaigns sent to you, your notifications and device records, your support requests, and your device/IP history. Deleted messages are not included in the output. If a section cannot be prepared temporarily, an error marker appears in that section and the other sections are still provided.

**Account deletion = anonymisation.** When you delete your account:

| What happens? | Which data |
|---|---|
| **Deleted** | Your notification device tokens and pending push records, your notification inbox and preferences, your follow relationships, your timetable and exam records, your poll participation record, your likes, your Discover posts (media files are removed from disk after 30 days), your bookmarked news, your feedback votes, your event feedback, your block list, your club application answers, your community memberships, your recipient rows in announcement e-mail campaigns, the chat photos you uploaded, **your device/IP records, analytics events and daily activity record (immediately)**, the images you attached to club posts (immediately, from disk). Your event applications are closed (the next person on the waiting list takes the seat) and the unfinished events you created that are not linked to a club are cancelled. **If you are a club owner:** ownership is transferred to the oldest active administrator (or, if none, moderator) of the club; if there is nobody to take over, the club is closed and its members are notified |
| **Anonymised** | Name, e-mail, profile information, biography, photo; poll vote records (the link to the user is cut); support, feedback, appeal, report and event application texts are cleared (the record remains without identity) |
| **Kept (limited)** | The messages you sent and community posts (part of other people's chat context; the author appears anonymous such as "Deleted user"); agreement acceptance records (legal evidence); moderation violation/report and ban traces; anonymous attendance/RSVP counters; administrator action and access records |
| **Cleaned up after a period** | Device/IP records (90 days), inappropriate-language filter record (90 days), raw analytics events (45 days), daily activity record (400 days), e-mail queue (sent 7 days, failed 30 days), announcement campaign records (180 days), administrator action record (365 days), message-access and club action records (730 days) |

> **In short:** When you delete your account your identity is removed and your personal data is deleted or anonymised. To protect the rights of others and legal evidence/security needs, some records remain without identity and in limited form.

## 8. Security measures

1. Passwords are stored as one-way digests; verification codes and refresh tokens are kept as digests.
2. The access token lasts 15 minutes; the refresh token is single-use; all sessions are closed when the password changes.
3. Rate limits apply to sign-in, registration, verification and write operations; generic responses that do not leak user existence are given.
4. Messages are stored encrypted; administrator access is recorded; the management panel works only with an administrator role.
5. Uploaded files are verified for type/size and file names are generated on the server.
6. No system is absolutely secure. If a data breach occurs, we notify the Board and the affected persons in accordance with the legislation.

## 9. Cookies and local storage

**No tracking/advertising cookies are used** on the website. Only necessary local storage such as your language/theme preference and session information is used. For details see the [Cookie and Local Storage Policy](/legal/cookies).

## 10. Children's data

The Service is not designed for persons under 18; because registration is possible with any valid e-mail address, age is not asked or verified at registration. If the registration of a user under 18 is detected, the knowledge and consent of the legal representative may be requested; if necessary the account is closed and the data is deleted/anonymised.

## 11. Your rights

Under KVKK Art. 11 you have the right to access, correct, delete, object to and otherwise exercise rights over your data. The application routes and the 30-day response time are in the [KVKK Privacy Notice](/legal/kvkk) and [Retention and Destruction](/legal/retention) texts. Quick routes: editing profile information, privacy settings, Download my data, Delete account, the Support section.

## 12. Changes

We may update this policy. For important changes we ask for your re-acceptance; the current version and history appear on this page.

## 13. Posts and content moderation

1. **Who sees them?** Posts are shown to other users who are signed in to the app; mutual visibility is closed with users you have blocked or who have blocked you. The visibility options offered in the app are shown on the relevant screen.
2. **Club post images.** An image you attach to a club post has its link removed and the file is deleted from disk when you delete the post, when the club is closed or when you delete your account.
3. **Inappropriate-language filter.** In public areas such as communities, events, profiles and posts, profanity, insults and similar expressions may be rejected automatically. **Chat messages (one-to-one and group) are not pre-screened.** The filter works only at the moment of saving; which area's and which user's content was rejected is kept for 90 days, and the rejected text is not stored. Rejected content is not published; the decision is made automatically without human review and you can send your objection through the Support section.
4. **Reports and removal.** Posts and messages can be reported with **Report**; authorised administrators review them and may hide or remove the content. If the same content is reported by several mutually independent accounts, it may be hidden automatically and temporarily until the review is completed; it may be made visible again after administrator review. For the procedure see the [Content Notice and Removal](/legal/content-removal) and [Community Rules](/legal/community-rules) texts.

## 14. Administrator roles and access powers

1. **Who are they?** Accounts that access the management panel are defined by the Operator and carry one of five roles: *full administrator*, *moderator*, *support*, *editor*, *read-only*. Administrators do not act on behalf of the university; an administrator role does not mean that personal data is transferred to the university.
2. **Access to personal data is limited by role.** Only the full administrator and moderator see the unmasked e-mail, IP and device details; in the support, editor and read-only roles these fields are masked (e.g. a•••@gmail.com). The support role manages support requests and feedback, the editor manages news, announcement and communication content, and the read-only role only monitors.
3. **Private correspondence.** Only the full administrator and moderator can access the content of messages and chat media; no one who is not an administrator can. This access is subject to the conditions in section 3: only for reasons such as report review, security/suspected abuse or a legal request, with a written reason and a tamper-resistant access record (730 days). Because the management panel can technically list a user's chats, preventing this power from being used for other purposes rests solely on these rules and the record; viewing for any other purpose is prohibited.
4. **Intervention powers.** Authorised administrators may hide (reversibly) or permanently delete a message, close a chat, remove a member from a chat, hide or remove posts and other content, close a club, suspend an account or define an access ban. Write operations are written to the administrator action record (365 days); for critical operations (message/chat intervention, role changes, account and club operations) a written reason is mandatory.
5. **Management of roles.** The assignment and changing of administrator roles is also written to the audit log.

## 15. Contact

{{support.email|In-app Support section}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}$c_privacy_en$, FALSE, TRUE),
    ('PRIVACY', 'ar', v, $t_privacy_ar$سياسة الخصوصية$t_privacy_ar$, $c_privacy_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

توضح هذه السياسة بلغة بسيطة أي بياناتك تُعالَج عند استخدام تطبيق «BÜ Kampüs» (جامعة بينغول) وموقعه الإلكتروني، ولماذا تُعالَج، وكم من الوقت تُحفَظ، وما هي حقوقك. للاطلاع على الإطار القانوني وإجراءات التقدّم بالطلبات، اقرأها مع [نص الإفصاح وفق قانون حماية البيانات الشخصية (KVKK)](/legal/kvkk).

المسؤول عن البيانات: {{controller.name}}{{?controller.address}}، {{controller.address}}{{/controller.address}}. وسيلة التواصل: {{controller.email|قسم الدعم داخل التطبيق}}.

## 1. باختصار

1. **لا نبيع** بياناتك، ولا نشاركها مع أطراف ثالثة لأغراض إعلانية.
2. لا نعالج إلا البيانات اللازمة لتقديم الخدمة وضمان الأمن والوفاء بالالتزامات القانونية.
3. الأذونات الاختيارية مثل مطابقة دفتر العناوين والإشعارات الفورية تعتمد على **موافقتك الصريحة**، ويمكن سحبها في أي وقت ([نص الموافقة الصريحة](/legal/explicit-consent)). لا يطلب التطبيق **موقع جهازك ولا يجمعه ولا يخزّنه**.
4. تُخزَّن رسائلك على الخادم مشفّرة؛ غير أن النظام **غير مشفّر من طرف إلى طرف**، ويمكن للمسؤولين المخوَّلين الاطلاع على الرسائل في حالات مسبَّبة، مع تسجيل ذلك.
5. إذا حذفت حسابك فإن بياناتك الشخصية تُجهَّل هويتها؛ وتبقى بعض السجلات بشكل محدود لأسباب قانونية ولحماية حقوق الآخرين.

## 2. ما البيانات التي نعالجها؟

| البيانات | السبب | السند القانوني | مدة الحفظ |
|---|---|---|---|
| **الحساب:** عنوان البريد الإلكتروني (من أي مزوّد)، الاسم واللقب، كلمة المرور (كملخّص أحادي الاتجاه فقط)، تفضيل اللغة | العضوية، والتحقق من الهوية، وتقديم الخدمة | تنفيذ العقد (KVKK م.5/2-ج) | ما دام الحساب مفتوحًا؛ وتُجهَّل هويتها عند الحذف |
| **تسجيل الدخول عبر Google / Apple (اختياري):** اسم المزوّد، والمعرّف الذي يمنحه المزوّد لحسابكم، وعنوان البريد الإلكتروني الذي يبلّغ عنه المزوّد (قد يكون عنوان ترحيل خاصًا لدى Apple) والاسم؛ ولا تصلنا كلمة مرور Google/Apple الخاصة بكم | الدخول دون كلمة مرور ومطابقة الحساب بهوية المزوّد | تنفيذ العقد (KVKK م.5/2-ج) | ما دام الحساب مفتوحًا؛ ويُحذف عند حذف الحساب |
| **الملف الشخصي:** الكلية، القسم، الصف، النبذة التعريفية، صورة الملف الشخصي، إعدادات الخصوصية الخاصة بك | عرض ملفك الشخصي للمستخدمين الآخرين (يمكن إخفاؤه حسب الحقل) | تنفيذ العقد؛ وفي الحقول الاختيارية الموافقة الصريحة (م.5/1) | طوال مدة بقاء الحساب مفتوحًا |
| **الحساب الجاري تسجيله ورمز التحقق:** البريد الإلكتروني، ملخّص الرمز | التحقق من البريد الإلكتروني | إجراء سابق للعقد / تنفيذ العقد | التسجيل المعلّق ساعة واحدة؛ ورمز التحقق 10 دقائق |
| **الجلسة:** ملخّص مفتاح التجديد، حالة الجلسة | إدارة آمنة للجلسات | المصلحة المشروعة (م.5/2-و) | مفتاح التجديد 30 يومًا كحد أقصى؛ ويُحذف عند تسجيل الخروج / تغيير كلمة المرور |
| **الرسائل:** النص، الصور، الفيديو، سجل التعديل، التفاعلات، معلومة القراءة، إعدادات المحادثة (كتم/أرشفة) | خدمة المراسلة | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وتُحفَظ النسخة المشفّرة للرسائل المحذوفة وسجل التعديل لأغراض أمنية (الافتراضي غير محدد المدة، وقابل للضبط) |
| **الصورة ذات الإرسال الواحد:** الملف المشفّر، سجل الفتح | المراسلة والمراجعة الأمنية | تنفيذ العقد؛ المصلحة المشروعة | وصول المستلم مرة واحدة / 24 ساعة كحد أقصى؛ والنسخة المشفّرة لمراجعة المسؤول **365 يومًا** (قابلة للضبط) |
| **بيانات المجتمعات والفعاليات:** العضويات، المنشورات، تأكيد الحضور (RSVP)، تسجيل الحضور (QR/يدويًا)، ردود طلبات الانضمام، تقييمات الفعاليات | خدمات المجتمعات والفعاليات | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وقد تبقى سجلات الحضور/المنشورات مجهولة الهوية |
| **المنشورات (اكتشف):** صورة واحدة ونص قصير لا يزيد على 7 كلمات، الإعجابات | نشر المحتوى والتفاعل | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وعند حذف المنشور يُحذف ملف الوسائط من القرص بعد 30 يومًا؛ وتُحذف الملفات المرفوعة غير المرتبطة بمنشور بعد 24 ساعة. وتُحذف الصورة المرفقة بمنشور نادٍ من القرص فورًا عند حذف المنشور أو النادي أو الحساب |
| **علاقات المتابعة والأخبار المفضلة** | تكوين خلاصتك، وحفظ المحتوى لقراءته لاحقًا | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وتُحذف عند حذف الحساب |
| **الاستطلاعات:** سجل المشاركة وصوتك | خدمة التصويت | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وعند حذف الحساب يُحذف سجل المشاركة ويصبح سجل الصوت مجهول الهوية. في الاستطلاع السري لا يُعرَض للمستخدمين الآخرين ولا للمسؤولين الخيار الذي صوّتَّ له. لا تُطبَّق مدة حذف تلقائي منفصلة على سجلات أصوات الاستطلاعات المنتهية. |
| **الجدول الدراسي ومعلومات المقررات والامتحانات:** المقررات والحصص وسجلات الفصل والامتحانات التي أدخلتها بنفسك؛ معلومة قراءة الإعلانات | متابعة الجدول الدراسي والامتحانات الشخصية | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وتُحذف عند حذف الحساب |
| **صندوق الإشعارات والتفضيلات:** محتوى الإشعارات، ساعات الصمت، تفضيلات الأنواع | خدمة الإشعارات | تنفيذ العقد | تُحذف الإشعارات المقروءة بعد 30 يومًا وغير المقروءة بعد 90 يومًا؛ ويُحتفَظ بأحدث 200 إشعار لكل مستخدم |
| **مفتاح إشعارات الجهاز (FCM):** المفتاح، المنصة، إصدار التطبيق، اللغة، آخر ظهور | إرسال الإشعارات الفورية | تنفيذ العقد؛ الموافقة الصريحة (إذن الإشعارات) | المفتاح الذي لم يُرَ منذ 60 يومًا يُنظَّف ليلًا؛ ويُحذف عند تسجيل الخروج/حذف الحساب |
| **طابور الإشعارات الفورية (push):** المستخدم/الجهاز المستهدف، عنوان الإشعار ونصه القصير، حالة الإرسال | إرسال الإشعار الفوري من طابور دائم مع إعادة المحاولة | تنفيذ العقد | يُحاوَل السجل المعلّق 24 ساعة كحد أقصى؛ وتُحذف المرسَلة بعد 7 أيام والفاشلة بعد 30 يومًا؛ وتُحذف عند تسجيل الخروج/حذف الحساب |
| **معرّف الجهاز وسجلات IP:** ملخّص غير قابل للعكس لمعرّف الجهاز (HMAC)، المنصة، إصدار التطبيق، عنوان IP، آخر ظهور ونوع الحدث (تسجيل/دخول/طلب) | الأمن، ومنع إساءة الاستخدام، ومنع الالتفاف على حظر المستخدمين المحظورين | المصلحة المشروعة (م.5/2-و)؛ الالتزام القانوني (م.5/2-ç) | الافتراضي **90 يومًا**؛ وسجلات الحظر ما دام الحظر قائمًا (انظر 6) |
| **أحداث الاستخدام (التحليلات):** اسم الشاشة، اسم الحدث، قيم خصائص محدودة، الوقت؛ آخر ظهور والنشاط اليومي | تحسين الخدمة، ومتابعة الأخطاء والأداء؛ والتقارير مجمَّعة | المصلحة المشروعة (م.5/2-و) | الأحداث الخام **45 يومًا** (فورًا عند حذف الحساب)؛ وبعدها تبقى فقط ملخصات يومية مجمّعة غير مرتبطة بالأشخاص. وسجل النشاط اليومي (الأيام التي فتحت فيها التطبيق) **400 يوم** (فورًا عند حذف الحساب) |
| **الدعم والملاحظات والاعتراض والبلاغ:** نصوصك وبريدك الإلكتروني للتواصل | الرد على الطلبات، والإشراف | تنفيذ العقد؛ المصلحة المشروعة؛ الالتزام القانوني | عند حذف الحساب تُمحى النصوص ويبقى السجل مجهول الهوية؛ وطلبات الدعم العامة (دون تسجيل دخول) 365 يومًا |
| **سجل مرشّح الألفاظ غير اللائقة:** في أي حقل، ومحتوى أي مستخدم رُفض/وُسم، ووقت ذلك (لا يُحفَظ النص المرفوض) | منع إساءة الاستخدام في المساحات العامة | المصلحة المشروعة (م.5/2-و) | 90 يومًا |
| **سجلات الحظر والإشراف:** الأشخاص الذين حظرتهم، سجلات المخالفات، قرارات البلاغات، آثار الحظر | الأمن والإشراف | المصلحة المشروعة؛ الالتزام القانوني | يُحتفَظ بأثر الإشراف مجهول الهوية حتى بعد حذف الحساب |
| **سجلات وصول المسؤولين وإجراءاتهم** (بما فيها سجل الاطلاع على الرسائل) | المساءلة، ومنع الوصول غير المصرّح به | المصلحة المشروعة؛ الالتزام القانوني | سجل إجراءات المسؤولين (بما فيه IP) 365 يومًا؛ وسجل الوصول إلى الرسائل وسجل إجراءات إدارة النوادي 730 يومًا (السجلات للإضافة فقط ولا تُعدَّل)؛ وتُحذف عند انتهاء المدة |
| **الموافقات على العقود والنصوص:** نوع الوثيقة، الإصدار، الوقت | إثبات الموافقة/القبول | الالتزام القانوني؛ المصلحة المشروعة | تُحفَظ حتى بعد حذف الحساب |
| **طابور البريد الإلكتروني:** المستلم، الموضوع، حالة الإرسال | رسائل التحقق/إعادة تعيين كلمة المرور/الأمن وإعلانات المسؤولين | تنفيذ العقد؛ المصلحة المشروعة في الإعلانات | تُحذف السجلات المرسَلة بعد 7 أيام، والفاشلة (غير القابلة للتسليم) بعد 30 يومًا |
| **سجلات رسائل الإعلانات الإدارية (الحملات):** اسم الحملة وحالتها، ومعرّف مستخدمك بصفة مستلم وحالة التسليم | إرسال إعلانات الخدمة والمجتمعات (ليست إعلانًا تجاريًا أو تسويقًا؛ وفي كل رسالة رابط لإلغاء الاشتراك). وقد تُستخدم حقول الملف الشخصي كالاسم والقسم والكلية والسنة لتخصيص الرسالة | المصلحة المشروعة (م.5/2-و)؛ تنفيذ العقد | تُحذف بعد 180 يومًا من انتهاء الحملة؛ ويُحذف صف المستلم الخاص بك فورًا عند حذف حسابك |
| **مطابقة دفتر العناوين:** ملخّص SHA-256 للبريد الإلكتروني الموجودة في دفتر عناوينك (أثناء الطلب فقط) | العثور على معارفك في دفتر عناوينك | **الموافقة الصريحة** (م.5/1) | **لا يُخزَّن ولا يُسجَّل**؛ يبقى في الذاكرة طوال معالجة الطلب فقط |
| **موقع الجهاز** | — | — | لا يطلب التطبيق إذن الموقع؛ وموقع الجهاز (GPS/الشبكة) **لا يُجمع ولا يُرسَل إلى الخادم ولا يُخزَّن** (انظر 5) |

> **باختصار:** كل بيانات نعالجها مرتبطة بغرض؛ ومعظمها يُحتفَظ به ما دام حسابك مفتوحًا. تُحفَظ سجلات الجهاز/IP 90 يومًا، وأحداث التحليلات الخام 45 يومًا، وسجل النشاط اليومي 400 يوم، والإشعارات 30 يومًا (المقروءة) / 90 يومًا (غير المقروءة)، وطابور البريد الإلكتروني 7 أيام (30 يومًا إن فشل)، وسجلات حملات الإعلانات 180 يومًا.

## 3. كيف تُخزَّن رسائلك ومن يمكنه الاطلاع عليها؟

1. **النقل:** تُنقَل الرسائل مشفّرة عبر TLS/WSS.
2. **التخزين:** تُخزَّن على الخادم مشفّرة بـ AES-256-GCM بمفتاح مستقل لكل محادثة. وتُحمى المفاتيح بمفتاح رئيسي منفصل، ويُحتفَظ بها في بيئة الخادم لا في قاعدة البيانات. وهذا يصعّب قراءة الرسائل حتى لو وقعت نسخة احتياطية من قاعدة البيانات في يد الغير.
3. **النظام ليس مشفّرًا من طرف إلى طرف.** وبما أن المفتاح الرئيسي لدينا، فإن النظام قادر على فك تشفير الرسائل. فاستخدمه وأنت على علم بذلك.
4. **وصول المسؤولين:** لا يمكن إلا للمسؤولين المخوَّلين (بدور المسؤول الكامل الصلاحيات والمشرف، انظر 14) الاطلاع على محتوى الرسائل والوسائط، وذلك لأسباب مثل مراجعة الشكاوى، والأمن/إساءة الاستخدام، والطلبات القانونية وما شابهها. وقد تعرض واجهة المسؤول أيضًا الرسائل المحذوفة والمعدَّلة والمخفية بالإشراف، والصور «ذات الإرسال الواحد»، والرسائل التي لا تُسلَّم إلى المستخدم المحظور. ويجب على المسؤول إدخال سبب كتابي للاطلاع على المحتوى (10 أحرف على الأقل). و**كل اطلاع** يُكتب تلقائيًا في سجل غير قابل للتعديل قبل عرض المحتوى: من اطلع، ومحادثة من اطلع عليها، وكم رسالة، وبأي سبب، ومن أي IP، ومتى. وإذا تعذّر كتابة السجل فلا يُعرَض المحتوى.
5. **الرسائل المحذوفة:** «الحذف للجميع» يخفي الرسالة عن المستخدمين الآخرين؛ وقد تُحفَظ النسخة المشفّرة للرسالة وإصداراتها السابقة لأغراض المراجعة الأمنية. وتُحدَّد مدة الحفظ من قِبل المشغّل (الافتراضي: غير محددة المدة).
6. **الصور ذات الإرسال الواحد:** يراها المستلم مرة واحدة ثم يُغلَق وصوله؛ غير أن الملف المشفّر يُحفَظ 365 يومًا (قابلة للضبط) لمراجعة المسؤول ثم يُحذف. ورغم وجود تدابير تقنية لمنع لقطات الشاشة، فلا تُعطى ضمانة مطلقة.
7. **معاينة الإشعار:** افتراضيًا لا يظهر نص الرسالة في الإشعار الفوري (وإذا فُعِّل الإعداد فإن النص يمر عبر Google FCM/Apple APNs). ولا يُكتب محتوى الرسالة في صندوق الإشعارات داخل التطبيق إطلاقًا.
8. **معالجة الصور والفيديو:** يُتحقَّق من نوع الصور (الملف الشخصي والغلاف والمنشورات والمحادثات) وحجمها وتُعاد ترميزها، وتُزال بيانات EXIF (الموقع وغيره). أما **فيديوهات المحادثة** فتُضغط على جهازك؛ ولا يعيد الخادم ترميز الفيديو و**لا يزيل البيانات الوصفية داخل ملف الفيديو (وقت التصوير، وسم الموقع، إلخ)**: إذ يُتحقَّق فقط من النوع والحجم والمدة، ويُخزَّن الفيديو مشفّرًا بمفتاح خاص بالمحادثة. وقد لا يزيل ضغط جهازك هذه البيانات الوصفية؛ لذا توخَّ الحذر قبل إرسال مقاطع فيديو قد تتضمن معلومات عن الموقع أو معلومات شخصية. أما صورة الغلاف (المعاينة) للفيديو فتُعاد ترميزها كالصور وتُزال بياناتها الوصفية. وتتضمن المنشورات صورة واحدة فقط. ويُقارَن ملخّص الصور بقائمة ملخّصات المحتوى المحظور؛ ولا يُحلَّل المحتوى المرئي للصور آليًا.
9. **الحظر:** لا تُسلَّم إليك الرسائل التي يكتبها لك من حظرتَه؛ ولا يُرسَل إشعار إلى الشخص المحظور. وتبقى هذه الرسائل في النظام ولا يراها إلا المسؤولون المخوَّلون لأسباب مثل مراجعة الشكاوى.

> **باختصار:** تُخزَّن الرسائل مشفّرة لكن ليس من طرف إلى طرف. ولا يمكن للمسؤولين المخوَّلين الاطلاع عليها إلا في حالات مسبَّبة، مع التسجيل في كل مرة. وقد تُحفَظ لفترة النسخة المشفّرة للرسائل المحذوفة والصور ذات الإرسال الواحد لأغراض الأمن.

## 4. مع من نشارك بياناتك؟

| المستلم | ما الذي يُشارَك؟ | الغرض | الموقع |
|---|---|---|---|
| **Google Firebase Cloud Messaging (FCM)** (وApple APNs لنظام iOS) | مفتاح إشعارات الجهاز، عنوان الإشعار/نصه القصير، معلومات الهدف | إيصال الإشعارات الفورية | خارج البلاد (بنية Google/Apple التحتية)؛ انظر نص الإفصاح وفق KVKK |
| **مزوّد خدمة إرسال البريد الإلكتروني: Brevo (SMTP)** (جهة معالجة) | عنوان البريد الإلكتروني للمستلم، محتوى البريد (رمز التحقق، نص الإعلان؛ وفي الإعلانات الاسم والقسم/الكلية/السنة لأغراض التخصيص) | رسائل التحقق وإعادة تعيين كلمة المرور والأمن وإعلانات المسؤولين | قد يكون خارج البلاد (قد توجد خوادم المزوّد في أوروبا أو بلدان أخرى)؛ انظر نص الإفصاح وفق KVKK |
| **مزوّد الاستضافة / الخوادم** | جميع بيانات الخدمة (بما فيها الرسائل المشفّرة) | استضافة الخدمة | {{hosting.location|يُعلَن موقع الاستضافة قبل النشر}} |
| **الجهات العامة المختصة** (المحكمة، النيابة العامة، الضابطة العدلية، مجلس KVKK وغيرها) | البيانات الواقعة ضمن نطاق الطلب | الالتزام القانوني | داخل البلاد |

لا نشارك البيانات مع شبكات الإعلانات أو سماسرة البيانات أو أدوات التتبع في وسائل التواصل الاجتماعي. **ولا ننقل بيانات المستخدمين إلى جامعة بينغول أو وحداتها؛** فالخدمة تقرأ من مواقع الجامعة فقط محتوى الأخبار والإعلانات والفعاليات وقائمة الطعام المتاح للعموم. ولا يعمل مسؤولو لوحة الإدارة باسم الجامعة (انظر 14). ملاحظة: بما أن رسائلنا الإلكترونية تُرسَل إلى عنوان بريدك الإلكتروني المسجّل، فقد تعالج الجهة التي تشغّل صندوق البريد ذاك (مزوّد بريدك الإلكتروني، أو الجامعة إن كنت تستخدم عنوانًا بنطاق bingol.edu.tr) الرسالة تقنيًا على بنيتها التحتية؛ وهذا ليس نقلًا للبيانات من جانبنا بل طبيعة البريد الإلكتروني. وإذا سجّلت الدخول عبر Google أو Apple فإن المصادقة تتم بين جهازك والمزوّد المعني؛ ولا يتحقق خادمنا إلا من رمز الهوية الموقَّع الصادر عن المزوّد، ولا يرسل أي بيانات إلى المزوّد نيابةً عنك. وتخضع معالجة المزوّدين الخاصة لسياساتهم الخاصة بالخصوصية.

## 5. الأذونات والميزات الاختيارية

1. **إذن الإشعارات:** إن شئت تتلقى الإشعارات الفورية. وإذا رفضت يستمر صندوق الإشعارات داخل التطبيق في العمل. وتدير أنواع الإشعارات و**ساعات الصمت** من الإعدادات.
2. **مطابقة دفتر العناوين:** إذا منحت إذن الوصول إلى دفتر العناوين، فإنه للعثور على معارفك يُرسَل إلى الخادم **ملخّص SHA-256 فقط** لعناوين البريد الإلكتروني الموجودة في دفتر عناوينك (500 عنوان كحد أقصى / في الطلب الواحد). **ولا تُخزَّن الملخّصات ولا تُسجَّل**؛ ولا يعود إليك في الرد إلا المستخدمون المطابقون (مع احترام إعدادات الخصوصية). ولا تُرسَل أسماء دفتر عناوينك ولا أرقام هواتفك إلى الخادم. ويوجد حد ساعي للطلبات لمنع إساءة الاستخدام.
3. **الموقع:** لا يطلب التطبيق **إذن الموقع** (المعتمد على GPS/الشبكة) من جهازك؛ ولا يجمع موقعك ولا يرسله إلى الخادم ولا يخزّنه. وعنوان IP المسجَّل لأغراض أمنية (انظر 6) ليس موقع الجهاز؛ ولا يُستنتَج في كود التطبيق موقع أو منطقة من عنوان IP. قد يحتفظ مزوّدو الاستضافة وبنية الشبكة بسجلاتهم الفنية الخاصة وفق سياساتهم؛ ولا نستخدمها لتحديد الموقع. وإذا قرّرنا في المستقبل معالجة الموقع فسيُحدَّث هذا النص وتُؤخَذ موافقتك الصريحة من جديد.
4. يمكنك سحب الأذونات في أي وقت من إعدادات الجهاز أو من شاشة الأذونات في التطبيق. ولا يؤثر السحب في مشروعية العمليات التي تمت قبل لحظة السحب.

## 6. سجلات الجهاز وIP وحالات حظر الوصول

1. لأغراض الأمن؛ يُسجَّل أثناء التسجيل والدخول وتجديد الجلسة والطلبات: الملخّص غير القابل للعكس لمعرّف جهازك، والمنصة، وإصدار التطبيق، وعنوان IP، ومعلومات الوقت. ولا يُحفَظ معرّف الجهاز الخام.
2. تُحفَظ هذه السجلات افتراضيًا **90 يومًا** وتُنظَّف ليلًا. ويمكن للمشغّل ضبط المدة؛ وإذا نشأ التزام قانوني بالحفظ (مثل بيانات حركة المرور وفق القانون رقم 5651) فقد تُحدَّد المدة وفقًا لذلك ويُحدَّث هذا النص.
3. يمكن تعريف **حظر وصول** على عنوان IP المستخدم المحظور بسبب إساءة الاستخدام، أو نطاق شبكته، أو ملخّص جهازه، أو معرّف المستخدم. ويُحفَظ سجل الحظر (رمز السبب، التاريخ، المدة إن وُجدت، الملاحظات) ما دام الحظر قائمًا وللمدة اللازمة للاعتراض/الرقابة. وتُحفَظ المحاولات التي اصطدمت بالحظر (IP، ملخّص الجهاز، مسار الطلب، الوقت) كسجل أمني وتخضع لمبدأ التنظيف نفسه المطبَّق على سجلات الجهاز/IP. وقد تُقيَّد الطلبات الواردة من نطاقات إخفاء الهوية مثل VPN/Tor/مراكز البيانات لأغراض أمنية.
4. إذا رأيت أنك محظور فيمكنك التقدّم من قسم الدعم أو من خاصية الاعتراض.

## 7. حذف الحساب وقابلية نقل البيانات

**تنزيل بياناتي:** يمكنك من الملف الشخصي > تنزيل بياناتي تنزيل بياناتك بصيغة JSON (بحد 3 مرات في اليوم). ولا تدخل الرسائل المحذوفة في المخرجات. ويشمل الملف ملفك الشخصي وإعدادات الخصوصية وسجلات الموافقة والرسائل وعضويات المحادثات والمنشورات والإعجابات والمتابعات والأخبار المفضلة وعضويات المجتمعات ومنشوراتها وسجلات المشاركة والتقديم والحضور في الفعاليات والفعاليات التي أنشأتها وحملات الإعلانات البريدية التي وصلتك والإشعارات وسجلات الأجهزة وطلبات الدعم وسجل الجهاز/IP. وإذا تعذّر إعداد قسم مؤقتًا تظهر علامة خطأ في ذلك القسم وتُسلَّم الأقسام الأخرى.

**حذف الحساب = تجهيل الهوية.** عند حذف حسابك:

| ماذا يحدث؟ | أي البيانات |
|---|---|
| **تُحذف** | مفاتيح إشعارات أجهزتك وسجلات push المعلّقة، وصندوق إشعاراتك وتفضيلاتك، وعلاقات المتابعة، وسجلات الجدول الدراسي والامتحانات، وسجل مشاركتك في الاستطلاعات، وإعجاباتك، ومنشورات اكتشف الخاصة بك (تُزال ملفات الوسائط من القرص بعد 30 يومًا)، وأخبارك المفضلة، وأصوات الملاحظات التي أدليت بها، وتقييمات الفعاليات، وقائمة الحظر، وردود طلبات الانضمام إلى النوادي، وعضوياتك في المجتمعات، وصفوفك في حملات الإعلانات البريدية، وصور المحادثة التي رفعتها، و**سجلات الجهاز/IP وأحداث التحليلات وسجل النشاط اليومي (فورًا)**، والصور التي أرفقتها بمنشورات النوادي (فورًا ومن القرص). وتُغلق طلبات مشاركتك في الفعاليات (ويتقدّم التالي في قائمة الانتظار) وتُلغى الفعاليات غير المنتهية التي أنشأتها وغير المرتبطة بنادٍ. **إذا كنت مالكًا لنادٍ:** تنتقل الملكية إلى أقدم مدير نشط فيه (أو مشرف)؛ وإن لم يوجد من يتولاها يُغلق النادي ويُبلَّغ أعضاؤه |
| **تُجهَّل هويتها** | الاسم، والبريد الإلكتروني، ومعلومات الملف الشخصي، والسيرة الذاتية المختصرة، والصورة؛ وسجلات أصوات الاستطلاعات (يُقطَع الارتباط بالمستخدم)؛ وتُمحى نصوص الدعم والملاحظات والاعتراض والبلاغ وطلبات الانضمام إلى الفعاليات (يبقى السجل مجهول الهوية) |
| **يُحتفَظ بها (بشكل محدود)** | الرسائل التي أرسلتَها ومنشورات المجتمعات (جزء من سياق محادثة الآخرين؛ يظهر الكاتب بشكل مجهول مثل «مستخدم محذوف»)؛ وسجلات الموافقة على العقود (دليل قانوني)؛ وآثار مخالفات الإشراف/البلاغات والحظر؛ وعدّادات الحضور/RSVP المجهولة؛ وسجلات إجراءات المسؤولين ووصولهم |
| **تُنظَّف بمرور المدة** | سجلات الجهاز/IP (90 يومًا)، وسجل مرشّح الألفاظ غير اللائقة (90 يومًا)، وأحداث التحليلات الخام (45 يومًا)، وسجل النشاط اليومي (400 يوم)، وطابور البريد الإلكتروني (المرسل 7 أيام، والفاشل 30 يومًا)، وسجلات حملات الإعلانات (180 يومًا)، وسجل إجراءات المسؤولين (365 يومًا)، وسجلات الوصول إلى الرسائل وإجراءات النوادي (730 يومًا) |

> **باختصار:** عند حذف حسابك تزول هويتك، وتُحذف بياناتك الشخصية أو تُجهَّل هويتها. ولحماية حقوق الآخرين والحاجة القانونية للأدلة والأمن تبقى بعض السجلات مجهولة الهوية وبشكل محدود.

## 8. تدابير الأمن

1. تُخزَّن كلمات المرور كملخّص أحادي الاتجاه؛ وتُحفَظ رموز التحقق ومفاتيح التجديد كملخّصات.
2. مفتاح الوصول صالح 15 دقيقة؛ ومفتاح التجديد للاستخدام مرة واحدة؛ وعند تغيير كلمة المرور تُغلَق جميع الجلسات.
3. يُطبَّق حد للمعدّل على الدخول والتسجيل والتحقق وعمليات الكتابة؛ وتُعطى ردود عامة لا تكشف وجود المستخدم.
4. تُخزَّن الرسائل مشفّرة؛ ووصول المسؤولين مسجَّل؛ ولا تعمل لوحة الإدارة إلا بدور المسؤول.
5. يُتحقَّق من نوع الملفات المرفوعة وحجمها، وتُولَّد أسماؤها على الخادم.
6. لا يوجد نظام آمن أمانًا مطلقًا. وإذا حدث خرق للبيانات فسنبلّغ المجلس (Kurul) والأشخاص المتضررين وفق التشريعات.

## 9. ملفات تعريف الارتباط والتخزين المحلي

**لا تُستخدم** في الموقع الإلكتروني ملفات تعريف ارتباط للتتبع/الإعلان. ولا يُستخدم إلا التخزين المحلي الضروري مثل تفضيل اللغة/السمة ومعلومات الجلسة. وللتفاصيل انظر [سياسة ملفات تعريف الارتباط والتخزين المحلي](/legal/cookies).

## 10. بيانات الأطفال

لم تُصمَّم الخدمة لمن هم دون 18 عامًا؛ وبما أن التسجيل ممكن بأي بريد إلكتروني صالح فلا يُسأل عن السن ولا يُتحقق منه عند التسجيل. وإذا اكتُشف تسجيل مستخدم دون 18 عامًا فقد يُطلَب علم الممثل القانوني وموافقته؛ وعند الاقتضاء يُغلَق الحساب وتُحذف البيانات/تُجهَّل هويتها.

## 11. حقوقك

وفقًا للمادة 11 من KVKK لديك حقوق الوصول إلى بياناتك وتصحيحها وحذفها والاعتراض وغيرها من الحقوق. وسبل التقدّم بالطلبات ومهلة الرد البالغة 30 يومًا واردة في [نص الإفصاح وفق KVKK](/legal/kvkk) ونص [الحفظ والإتلاف](/legal/retention). الطرق السريعة: تعديل معلومات الملف الشخصي، إعدادات الخصوصية، تنزيل بياناتي، حذف الحساب، قسم الدعم.

## 12. التغييرات

يجوز لنا تحديث هذه السياسة. وفي حال التغييرات المهمة نطلب منك الموافقة من جديد؛ ويتوفر الإصدار الحالي والسجل السابق في هذه الصفحة.

## 13. المنشورات والإشراف على المحتوى

1. **من يراها؟** تُعرَض المنشورات للمستخدمين الآخرين الذين سجّلوا الدخول إلى التطبيق؛ ويُغلَق الظهور المتبادل مع المستخدمين الذين حظرتَهم أو حظروك. تُعرض خيارات الظهور المتاحة في التطبيق على الشاشة المعنية.
2. **صور منشورات النوادي.** تُفصَل الصورة المرفقة بمنشور نادٍ وتُحذف من القرص عند حذفك المنشور أو إغلاق النادي أو حذف حسابك.
3. **مرشّح الألفاظ غير اللائقة.** في المساحات العامة مثل المجتمعات والفعاليات والملف الشخصي والمنشورات قد تُرفَض آليًا الشتائم والإهانات وما شابهها من العبارات. و**رسائل المحادثة (الفردية والجماعية) لا تخضع لفحص مسبق.** ويعمل المرشّح لحظة الحفظ فقط؛ ويُحفَظ 90 يومًا أي حقل ومحتوى أي مستخدم رُفض، ولا يُحفَظ النص المرفوض. ولا يُنشَر المحتوى المرفوض؛ ويصدر القرار آليًا دون مراجعة بشرية، ويمكنك تقديم اعتراضك من قسم الدعم.
4. **الشكوى والإزالة.** يمكن الإبلاغ عن المنشورات والرسائل عبر **إبلاغ**؛ ويراجعها المسؤولون المخوَّلون ويمكنهم إخفاء المحتوى أو إزالته. وإذا أُبلغ عن المحتوى نفسه من عدة حسابات مستقلة بعضها عن بعض فقد يُخفى تلقائيًا ومؤقتًا إلى حين اكتمال المراجعة؛ ويجوز إظهاره من جديد بعد مراجعة المسؤول. وللإجراءات انظر نصَّي [الإبلاغ عن المحتوى وإزالته](/legal/content-removal) و[قواعد المجتمع](/legal/community-rules).

## 14. أدوار المسؤولين وصلاحيات الوصول

1. **من هم؟** الحسابات التي تصل إلى لوحة الإدارة يحددها المشغِّل وتحمل أحد خمسة أدوار: *مسؤول كامل الصلاحيات*، و*مشرف*، و*دعم*، و*محرِّر*، و*للقراءة فقط*. لا يعمل المسؤولون باسم الجامعة؛ ودور المسؤول لا يعني نقل بيانات شخصية إلى الجامعة.
2. **الوصول إلى البيانات الشخصية محدود بالدور.** لا يرى البريد الإلكتروني وIP وتفاصيل الجهاز غير المحجوبة إلا المسؤول الكامل الصلاحيات والمشرف؛ وفي أدوار الدعم والمحرِّر والقراءة فقط تكون هذه الحقول محجوبة جزئيًا (مثل a•••@gmail.com). يدير دور الدعم طلبات الدعم والملاحظات، ويدير المحرِّر الأخبار والإعلانات ومحتوى التواصل، ويقتصر دور القراءة فقط على المراقبة.
3. **المراسلات الخاصة.** لا يصل إلى مضمون الرسائل ووسائط المحادثات إلا المسؤول الكامل الصلاحيات والمشرف؛ ولا يصل إليها أي شخص ليس مسؤولًا. ويخضع هذا الوصول للشروط الواردة في القسم 3: لأسباب مثل مراجعة الشكاوى أو الأمن/الاشتباه في إساءة الاستخدام أو طلب قانوني فقط، وبسبب كتابي وسجل وصول غير قابل للتعديل (730 يومًا). ولأن لوحة الإدارة تستطيع تقنيًا سرد محادثات المستخدم، فإن منع استخدام هذه الصلاحية لغير غرضها يقوم على هذه القواعد والسجل وحدهما؛ والاطلاع لأي غرض آخر محظور.
4. **صلاحيات التدخل.** يجوز للمسؤولين المخوَّلين إخفاء رسالة (مع إمكان التراجع) أو حذفها نهائيًا، وإغلاق محادثة، وإخراج عضو من محادثة، وإخفاء المنشورات وسائر المحتويات أو إزالتها، وإغلاق نادٍ، وتعليق حساب، أو تعريف حظر وصول. وتُكتب عمليات الكتابة في سجل إجراءات المسؤولين (365 يومًا)؛ وفي العمليات الحرجة (التدخل في الرسائل/المحادثات، وتغيير الأدوار، وعمليات الحسابات والنوادي) السبب الكتابي إلزامي.
5. **إدارة الأدوار.** يُكتب تعيين أدوار المسؤولين وتغييرها أيضًا في سجل التدقيق.

## 15. التواصل

{{support.email|قسم الدعم داخل التطبيق}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}$c_privacy_ar$, FALSE, TRUE);
END
$do_privacy$;

DO $do_kvkk$
DECLARE
    v INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = 'KVKK';
    UPDATE legal_document SET active = FALSE WHERE type = 'KVKK' AND active;
    INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
    ('KVKK', 'tr', v, $t_kvkk_tr$KVKK Aydınlatma Metni$t_kvkk_tr$, $c_kvkk_tr$6698 sayılı Kişisel Verilerin Korunması Kanunu'nun ("**Kanun**" / "**KVKK**") 10. maddesi ve Aydınlatma Yükümlülüğünün Yerine Getirilmesinde Uyulacak Usul ve Esaslar Hakkında Tebliğ uyarınca, BÜ Kampüs uygulaması ve web sitesini kullanırken kişisel verilerinizin nasıl işlendiği hakkında sizi bilgilendiririz. Bu metin bilgilendirme amaçlıdır; açık rıza gerektiren işlemler ayrıca [Açık Rıza Metni](/legal/explicit-consent) ile sizden ayrı ayrı istenir.

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
| Kimlik | Ad-soyad; Google veya Apple ile girişi (isteğe bağlı) kullanırsanız sağlayıcının adı ve sağlayıcının hesabınız için verdiği kimlik numarası |
| İletişim | E-posta adresi (herhangi bir sağlayıcıdan; Google/Apple ile girişte sağlayıcının bildirdiği adres, Apple'da gizli aktarım adresi olabilir), destek taleplerinde iletişim e-postası |
| Eğitim/mesleki bilgi | Fakülte, bölüm, sınıf, öğrenci/personel rolü |
| Görsel | Profil fotoğrafı; gönderi fotoğrafı (gönderi başına tek fotoğraf); sohbet fotoğrafları ve videoları (fotoğrafların EXIF üst verisi temizlenir; sohbet videoları sunucuda yeniden kodlanmaz ve içlerindeki üst veri temizlenmez, şifreli saklanır) |
| Kullanıcı içeriği | Mesajlar, topluluk gönderileri ve Keşfet gönderileri (tek fotoğraf ve en çok 7 kelimelik metin), anket oyları, etkinlik başvuru yanıtları, geri bildirim, destek ve itiraz metinleri, biyografi |
| Müşteri işlem / kullanım | Topluluk üyelikleri, etkinlik katılımı ve yoklama, favoriler, takip ilişkileri, bildirim ve gizlilik tercihleri, engelleme listesi, aldığınız yönetici duyuru e-postası kampanyalarının kaydı (kampanya ve gönderim durumu) |
| Kişisel plan | Kullanıcının kendi girdiği ders programı, ders, dönem ve sınav kayıtları |
| İşlem güvenliği | Oturum bilgisi, şifre özeti, cihaz tanımlayıcısının geri döndürülemez özeti, IP adresi, platform ve uygulama sürümü, erişim engeli kayıtları, hata ve giriş denemeleri |
| Hukuki işlem / uyum | Sözleşme onay kayıtları, şikâyet/rapor ve moderasyon kayıtları, yönetici erişim kayıtları |
| Pazarlama | İşlenmez (reklam/pazarlama amacıyla işleme yapılmaz). Yöneticilerin gönderdiği duyuru e-postaları hizmet ve topluluk duyurusudur; her e-postada abonelikten çıkış bağlantısı bulunur |
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
9. Gönderi, takip, favori, anket ve kişisel ders programı hizmetlerinin sunulması; yönetici duyuru e-postalarının gönderilmesi.
10. Herkese açık alanlarda uygunsuz ifadenin otomatik filtrelenmesi ve şikâyetlerin yürütülmesi.

## 4. Hukuki sebepler

| Hukuki sebep | Örnek işleme faaliyetleri |
|---|---|
| m.5/2-(a) Kanunlarda açıkça öngörülmesi | Yetkili makamlara bilgi verilmesi, mevzuatın zorunlu kıldığı kayıtlar |
| m.5/2-(c) Sözleşmenin kurulması veya ifası | Üyelik, profil, mesajlaşma, topluluk/etkinlik hizmetleri, bildirim ve e-posta gönderimi |
| m.5/2-(ç) Hukuki yükümlülüğün yerine getirilmesi | Sözleşme onay kayıtları, yasal talepler, ilgili mevzuat gereği saklama |
| m.5/2-(e) Bir hakkın tesisi, kullanılması veya korunması | Moderasyon izleri, itiraz ve uyuşmazlık için delil niteliğindeki kayıtlar |
| m.5/2-(f) Meşru menfaat (temel hak ve özgürlüklere zarar vermemek şartıyla) | Güvenlik, cihaz/IP kaydı, hız sınırlama, yönetici erişim denetimi, analitik |
| m.5/1 Açık rıza | Rehber eşleştirme, anlık bildirim izni, isteğe bağlı profil alanlarının yayımı gibi **isteğe bağlı** işlemler |

(m.5/2-(ç) ve m.5/2-(e) bendleri ilgili işlemlerde birlikte dayanak olabilir.)

## 5. Kişisel verilerin aktarılması

| Alıcı grubu | Aktarılan veri | Amaç | Yurt içi / yurt dışı |
|---|---|---|---|
| Barındırma ve altyapı hizmet sağlayıcıları (veri işleyen) | Hizmet verisi (mesajlar şifreli) | Hizmetin barındırılması | {{hosting.location|Barındırma konumu veri sorumlusunca ayrıca bildirilir}} |
| E-posta gönderim hizmeti sağlayıcısı: Brevo (SMTP; veri işleyen) | Alıcı e-posta, e-posta içeriği; duyuru e-postalarında ad ve bölüm/fakülte/sınıf gibi kişiselleştirme alanları | Doğrulama/şifre sıfırlama/güvenlik e-postaları ve yönetici duyuruları | **Yurt dışı olabilir** (sağlayıcının sunucuları Avrupa'da veya başka ülkelerde bulunabilir) |
| Bildirim sağlayıcısı: Google LLC (Firebase Cloud Messaging) ve iOS için Apple Inc. (APNs) | Cihaz bildirim anahtarı, bildirim başlığı/kısa metni, hedef bilgisi, platform | Anlık bildirim iletimi | **Yurt dışı** |
| Yetkili kamu kurum ve kuruluşları (mahkeme, savcılık, kolluk, Kurul vb.) | Talep kapsamındaki veri | Hukuki yükümlülük | Yurt içi |

**Üniversiteye aktarım yoktur.** Kişisel verileriniz Bingöl Üniversitesi'ne veya birimlerine aktarılmaz: Hizmet üniversitenin sitelerinden yalnızca herkese açık haber, duyuru, etkinlik ve yemek listesi içeriğini okur. Yönetim paneli yöneticileri üniversite adına çalışmaz (bkz. bölüm 8). Not: gönderdiğimiz e-postalar kayıtlı e-posta adresinize ulaştığından, o posta kutusunu işleten kuruluş (e-posta sağlayıcınız; bingol.edu.tr adresi kullanıyorsanız üniversite) e-postayı kendi altyapısında teknik olarak işleyebilir; bu, veri sorumlusunun yaptığı bir aktarım değil, e-postanın doğasıdır. Google veya Apple ile giriş yaparsanız kimlik doğrulaması cihazınız ile ilgili sağlayıcı arasında gerçekleşir; sunucumuz yalnızca sağlayıcının imzalı kimlik belirtecini doğrular, sizin adınıza sağlayıcıya veri göndermez. Sağlayıcıların kendi işlemeleri kendi aydınlatma ve gizlilik metinlerine tabidir.

**Yurt dışına aktarım (m.9).** Anlık bildirim için cihaz bildirim anahtarınız ve bildirim içeriği Firebase/APNs üzerinden yurt dışına aktarılır. Bu aktarım; Kanun'un 9. maddesi ve ilgili Kurul düzenlemeleri çerçevesinde, **bildirim iznine dayanan açık rızanıza** ve/veya yeterlilik/uygun güvence mekanizmalarına (standart sözleşme vb.) dayanır. Bildirim iznini vermemeniz halinde anlık bildirim almazsınız ancak uygulama içi bildirim kutusu ve diğer hizmetler çalışmaya devam eder. Rızanızı cihaz ayarlarından veya uygulamadaki İzinler/Bildirim ayarlarından istediğiniz zaman geri alabilirsiniz. E-posta gönderim hizmeti sağlayıcısının (Brevo) sunucuları da yurt dışında bulunabilir; doğrulama, şifre sıfırlama ve duyuru e-postalarının iletimi için e-posta adresiniz ve e-posta içeriği bu sağlayıcıya aktarılabilir ve bu aktarım da yukarıdaki m.9 çerçevesindeki mekanizmalara dayanır.

## 6. Kişisel verilerin toplanma yöntemi

Verileriniz; uygulama ve web sitesi üzerinden elektronik ortamda, kayıt/profil formları, mesajlaşma ve içerik paylaşımı, destek formları, cihazınızın teknik iletişimi (IP, cihaz özeti, uygulama sürümü), çerez benzeri yerel depolama ve (izin verirseniz) rehber eşleştirme isteği yoluyla otomatik ve kısmen otomatik yöntemlerle toplanır. Haber ve yemek listesi içerikleri kişisel veri içermeyen kamuya açık kaynaklardan derlenir.

## 7. Saklama süresi

Kişisel veriler, işleme amacı için gerekli süre ve ilgili mevzuatta öngörülen süre boyunca saklanır, süre bitiminde silinir, yok edilir veya anonim hale getirilir. Başlıca süreler: bekleyen kayıt 1 saat; doğrulama kodu 10 dakika; yenileme anahtarı en çok 30 gün; okunmuş bildirim 30 gün, okunmamış 90 gün (kullanıcı başına en yeni 200); cihaz bildirim anahtarı 60 gün görülmezse; cihaz/IP güvenlik kayıtları 90 gün; uygunsuz ifade filtresi kaydı 90 gün; push kuyruğu kaydı gönderildikten 7 gün (başarısızsa 30 gün); analitik ham olaylar 45 gün (ardından yalnızca kişiye bağlı olmayan toplulaştırılmış özetler); günlük aktiflik kaydı 400 gün; e-posta kuyruğu gönderilenler 7 gün, başarısızlar 30 gün; yönetici duyuru e-postası (kampanya) kayıtları kampanya bitiminden 180 gün; yönetici işlem kaydı 365 gün; mesaj erişim ve kulüp işlem kaydı 730 gün; tek gönderimlik fotoğrafın şifreli kopyası 365 gün; herkese açık destek talebi 365 gün. Hesap açık olduğu sürece profil ve içerikleriniz saklanır; silinen mesajların şifreli kopyası ve sözleşme onay kayıtları güvenlik/ispat amacıyla ayrıca tutulabilir. Ayrıntılı tablo: [Saklama ve İmha](/legal/retention).

## 8. Yönetici erişimi ve yetkileri (şeffaflık notu)

Mesajlar sunucuda şifreli saklanır ancak sistem uçtan uca şifreli değildir. Yönetim paneli hesapları İşletici tarafından tanımlanır ve beş rolden birini taşır (tam yönetici, moderatör, destek, editör, salt okunur); yöneticiler üniversite adına çalışmaz. Kişisel alanlara (maskesiz e-posta, IP, cihaz ayrıntısı) yalnızca tam yönetici ve moderatör erişir; diğer rollerde bu alanlar maskelidir. **Mesaj ve medya içeriğine yalnızca tam yönetici ve moderatör erişebilir,** yalnızca şikâyet incelemesi, güvenlik, kötüye kullanım ve yasal talepler gibi gerekçelerle, yazılı gerekçe girilerek (en az 10 karakter); her görüntüleme otomatik ve değiştirilemez biçimde kaydedilir (yönetici, görüntülenen kullanıcı, sohbet, mesaj sayısı, gerekçe, IP, zaman; 730 gün) ve kayıt yazılamazsa içerik gösterilmez. Yöneticiler ayrıca mesajı gizleyebilir veya silebilir, sohbeti kapatabilir, içeriği kaldırabilir, kulüp kapatabilir, hesabı askıya alabilir; bu işlemler yönetici işlem kaydına (365 gün) yazılır. Bu işleme faaliyetinin hukuki sebebi meşru menfaat ve hukuki yükümlülüktür (m.5/2-(f), (ç), (e)); ayrıntı [Gizlilik Politikası](/legal/privacy) bölüm 3 ve 14'tedir.

## 9. Otomatik karar verme

Hizmet, hakkınızda yalnızca otomatik işleme ile hukuki sonuç doğuran bir karar vermez. Aynı hesapla ilgili birden çok ihlal kaydı birikmesi halinde sistem yalnızca bir yöneticiye **öneri** üretir; askıya alma kararını bir yönetici verir. Hız sınırlama, yasaklı içerik özeti kontrolü, herkese açık alanlardaki uygunsuz ifade filtresi ve aynı içeriğin birbirinden bağımsız birkaç hesap tarafından bildirilmesi halinde içeriğin inceleme tamamlanana kadar otomatik ve geçici olarak gizlenmesi (yönetici geri açabilir) gibi otomatik önlemler vardır; filtre bir içeriği otomatik reddedebilir (sohbet mesajları bu denetime tabi değildir), itirazınızı Destek bölümünden iletebilirsiniz. Hesabınıza yönelik kalıcı sonuç doğuran kararlar yönetici tarafından verilir.

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
{{?controller.email}}4. **E-posta:** {{controller.email}} adresine, kayıtlı e-posta adresinizden.{{/controller.email}}

Başvurunuzda; ad-soyad, kimlik doğrulamaya yarayan bilgi (hesap e-postası), tebligat adresi, talep konusu belirtilmelidir. Kimliğinizi doğrulamak için ek bilgi isteyebiliriz. Başvurular talebin niteliğine göre **en geç 30 gün** içinde ücretsiz sonuçlandırılır; işlemin ayrıca bir maliyet gerektirmesi halinde Kurul'un belirlediği tarifedeki ücret alınabilir.

Başvurunun reddedilmesi, cevabın yetersiz bulunması veya süresinde cevap verilmemesi halinde, cevabı öğrendiğiniz tarihten itibaren 30 gün ve her halde başvuru tarihinden itibaren 60 gün içinde **Kişisel Verileri Koruma Kurulu'na şikâyet** hakkınız saklıdır.$c_kvkk_tr$, FALSE, TRUE),
    ('KVKK', 'en', v, $t_kvkk_en$KVKK Privacy Notice$t_kvkk_en$, $c_kvkk_en$*This English text is a translation provided for information only. The Turkish text is authoritative; if there is any difference, the Turkish text prevails.*

In accordance with Article 10 of the Personal Data Protection Law No. 6698 (the "**Law**" / "**KVKK**") and the Communiqué on the Procedures and Principles to be Followed in Fulfilling the Obligation to Inform, we inform you how your personal data is processed while you use the BÜ Kampüs application and website. This text is for information; operations that require explicit consent are requested from you separately and individually through the [Explicit Consent text](/legal/explicit-consent).

## 1. Data controller

| | |
|---|---|
| Data controller | {{controller.name}} |
{{?controller.address}}| Address | {{controller.address}} |{{/controller.address}}
{{?controller.email}}| E-mail | {{controller.email}} |{{/controller.email}}
{{?controller.kep}}| KEP address | {{controller.kep}} |{{/controller.kep}}
{{?controller.verbis}}| VERBİS registry no. | {{controller.verbis}} |{{/controller.verbis}}
| In-app application | Support section{{?support.email}} · {{support.email}}{{/support.email}} |

## 2. Categories of personal data processed

| Category | Examples |
|---|---|
| Identity | Name and surname; if you choose to sign in with Google or Apple (optional), the name of the provider and the identifier the provider assigns to your account |
| Contact | E-mail address (from any provider; with Google/Apple sign-in, the address reported by the provider, which may be a private relay address with Apple), contact e-mail in support requests |
| Education/professional information | Faculty, department, year, student/staff role |
| Visual | Profile photo; post photo (a single photo per post); chat photos and videos (the EXIF metadata of photos is removed; chat videos are not re-encoded on the server and the metadata inside them is not removed, they are stored encrypted) |
| User content | Messages, community posts and Discover posts (a single photo and text of at most 7 words), poll votes, event application answers, feedback, support and appeal texts, biography |
| Customer transaction / usage | Community memberships, event attendance and roll call, bookmarks, follow relationships, notification and privacy preferences, block list, the record of the administrator announcement e-mail campaigns you received (campaign and delivery status) |
| Personal plan | The timetable, courses, semester and exam records entered by the user themselves |
| Transaction security | Session information, password digest, non-reversible digest of the device identifier, IP address, platform and app version, access ban records, errors and sign-in attempts |
| Legal transaction / compliance | Agreement acceptance records, complaint/report and moderation records, administrator access records |
| Marketing | Not processed (no processing for advertising/marketing purposes). Announcement e-mails sent by administrators are service and community announcements; every e-mail contains an unsubscribe link |
| Special categories of personal data | Not requested knowingly. Special-category data shared within user content (e.g. in a message) is hosted only within the scope of your own sharing; we do not aim to process it. |

## 3. Purposes of processing

1. Creating membership, identity and e-mail verification, account security.
2. Providing news, announcements, events, menu, community, event, attendance, messaging, search and bookmark services.
3. Sending notifications (in-app, push, e-mail).
4. Handling support, feedback and appeal requests.
5. Security, preventing abuse and the circumvention of a ban on a banned user, moderation.
6. Improving the service, error and performance tracking (aggregated analysis).
7. Fulfilling legal obligations, meeting requests of competent authorities, exercising and defending rights.
8. Keeping agreement and consent records.
9. Providing post, follow, bookmark, poll and personal timetable services; sending administrator announcement e-mails.
10. Automatic filtering of inappropriate language in public areas and handling complaints.

## 4. Legal bases

| Legal basis | Example processing activities |
|---|---|
| Art. 5/2-(a) Expressly provided for by law | Providing information to competent authorities, records required by legislation |
| Art. 5/2-(c) Establishment or performance of a contract | Membership, profile, messaging, community/event services, sending notifications and e-mails |
| Art. 5/2-(ç) Fulfilment of a legal obligation | Agreement acceptance records, legal requests, retention required by relevant legislation |
| Art. 5/2-(e) Establishment, exercise or protection of a right | Moderation traces, records that serve as evidence for appeals and disputes |
| Art. 5/2-(f) Legitimate interest (provided that fundamental rights and freedoms are not harmed) | Security, device/IP records, rate limiting, administrator access audit, analytics |
| Art. 5/1 Explicit consent | **Optional** operations such as contact matching, push notification permission and publishing optional profile fields |

(Sub-paragraphs Art. 5/2-(ç) and Art. 5/2-(e) can together be the basis for the relevant operations.)

## 5. Transfer of personal data

| Recipient group | Data transferred | Purpose | Domestic / abroad |
|---|---|---|---|
| Hosting and infrastructure service providers (processors) | Service data (messages encrypted) | Hosting the service | {{hosting.location|The hosting location is notified separately by the data controller}} |
| E-mail delivery service provider: Brevo (SMTP; processor) | Recipient e-mail, e-mail content; in announcement e-mails personalisation fields such as name and department/faculty/year | Verification/password reset/security e-mails and administrator announcements | **May be abroad** (the provider's servers may be in Europe or other countries) |
| Notification provider: Google LLC (Firebase Cloud Messaging) and Apple Inc. (APNs) for iOS | Device notification token, notification title/short text, target information, platform | Delivering push notifications | **Abroad** |
| Competent public bodies and institutions (court, public prosecutor, law enforcement, the Board, etc.) | Data within the scope of the request | Legal obligation | Domestic |

**There is no transfer to the university.** Your personal data is not transferred to Bingöl University or its units: the Service only reads publicly available news, announcements, events and menu content from the university's sites. Management panel administrators do not act on behalf of the university (see section 8). Note: because the e-mails we send reach your registered e-mail address, the organisation that operates that mailbox (your e-mail provider; the university if you use a bingol.edu.tr address) may technically process the e-mail on its own infrastructure; this is not a transfer made by the data controller but the nature of e-mail. If you sign in with Google or Apple, authentication takes place between your device and that provider; our server only verifies the provider's signed identity token and sends no data to the provider on your behalf. The providers' own processing is subject to their own notices and privacy policies.

**Transfer abroad (Art. 9).** For push notifications, your device notification token and the notification content are transferred abroad through Firebase/APNs. Within the framework of Article 9 of the Law and the relevant Board regulations, this transfer relies on **your explicit consent based on the notification permission** and/or adequacy/appropriate-safeguard mechanisms (standard contract, etc.). If you do not grant the notification permission you will not receive push notifications, but the in-app notification inbox and other services continue to work. You can withdraw your consent at any time from the device settings or the Permissions/Notification settings in the app. The servers of the e-mail delivery service provider (Brevo) may also be abroad; your e-mail address and the e-mail content may be transferred to this provider to deliver verification, password reset and announcement e-mails, and this transfer also relies on the mechanisms under Article 9 above.

## 6. Method of collecting personal data

Your data is collected by automated and partly automated methods electronically through the application and website: registration/profile forms, messaging and content sharing, support forms, the technical communication of your device (IP, device digest, app version), cookie-like local storage and (if you allow it) the contact matching request. News and menu content is compiled from publicly available sources that contain no personal data.

## 7. Retention period

Personal data is kept for the time required for the purpose of processing and for the period provided in the relevant legislation, and at the end of the period it is deleted, destroyed or anonymised. Main periods: pending registration 1 hour; verification code 10 minutes; refresh token at most 30 days; read notifications 30 days, unread 90 days (newest 200 per user); device notification token if unseen for 60 days; device/IP security records 90 days; inappropriate-language filter record 90 days; push queue record 7 days after sending (30 days if failed); raw analytics events 45 days (afterwards only non-personal aggregated summaries); daily activity record 400 days; e-mail queue sent records 7 days, failed records 30 days; administrator announcement e-mail (campaign) records 180 days after the campaign ends; administrator action record 365 days; message-access and club action records 730 days; encrypted copy of a view-once photo 365 days; public support request 365 days. While the account is open your profile and contents are kept; the encrypted copy of deleted messages and agreement acceptance records may also be kept separately for security/evidence purposes. Detailed table: [Retention and Destruction](/legal/retention).

## 8. Administrator access and powers (transparency note)

Messages are stored encrypted on the server, but the system is not end-to-end encrypted. Management panel accounts are defined by the Operator and carry one of five roles (full administrator, moderator, support, editor, read-only); administrators do not act on behalf of the university. Only the full administrator and moderator have access to personal fields (unmasked e-mail, IP, device details); in the other roles these fields are masked. **Only the full administrator and moderator can access the content of messages and media,** only for reasons such as report review, security, abuse and legal requests, by entering a written reason (at least 10 characters); every viewing is recorded automatically and in a tamper-resistant way (administrator, user viewed, chat, number of messages, reason, IP, time; 730 days) and if the record cannot be written the content is not shown. Administrators may also hide or delete a message, close a chat, remove content, close a club and suspend an account; these operations are written to the administrator action record (365 days). The legal basis of this processing activity is legitimate interest and legal obligation (Art. 5/2-(f), (ç), (e)); details are in sections 3 and 14 of the [Privacy Policy](/legal/privacy).

## 9. Automated decision-making

The Service does not make a decision that produces a legal consequence about you solely by automated processing. If several violation records accumulate for the same account, the system only produces a **recommendation** to an administrator; an administrator makes the suspension decision. There are automated measures such as rate limiting, the prohibited-content digest check, the inappropriate-language filter in public areas, and the automatic and temporary hiding of content, until the review is completed, when the same content is reported by several mutually independent accounts (an administrator can reopen it); the filter may reject a content automatically (chat messages are not subject to this check) and you can send your objection through the Support section. Decisions that produce a lasting consequence for your account are made by an administrator.

## 10. Your rights (Art. 11)

By applying to the data controller you may request the following:

1. To learn whether your personal data is processed,
2. To request information if it has been processed,
3. To learn the purpose of processing and whether it is used in line with its purpose,
4. To know the third parties to whom it is transferred at home or abroad,
5. To request correction if it is incomplete or incorrectly processed,
6. To request deletion or destruction within the framework of the conditions in Article 7 of the Law,
7. To request that the operations under (5) and (6) be notified to the third parties to whom the data was transferred,
8. To object to the occurrence of a result against you through the analysis of the processed data exclusively by automated systems,
9. To request compensation for the damage if you suffer damage due to unlawful processing.

In-app shortcuts: Profile editing and privacy settings (correction/control of publication), **Download my data** (access/copy), **Delete account** (deletion/anonymisation).

## 11. How to apply

1. **In-app:** Create a request titled "Personal data request" in the Support section (the identity of a signed-in user is verified through the account).
2. **Written:** By a wet-signed petition{{?controller.address}} to {{controller.address}}{{/controller.address}}, by hand or through a notary.
{{?controller.kep}}3. **KEP:** An application with a secure electronic signature to {{controller.kep}}.{{/controller.kep}}
{{?controller.email}}4. **E-mail:** To {{controller.email}}, from your registered e-mail address.{{/controller.email}}

Your application must state your name and surname, information that verifies your identity (account e-mail), your notification address and the subject of your request. We may ask for additional information to verify your identity. Applications are concluded free of charge, depending on the nature of the request, **within 30 days at the latest**; if the process requires an additional cost, the fee in the tariff determined by the Board may be charged.

If the application is rejected, the reply is found insufficient or no reply is given in time, you retain the right to **complain to the Personal Data Protection Board** within 30 days of learning the reply and in any case within 60 days of the application date.$c_kvkk_en$, FALSE, TRUE),
    ('KVKK', 'ar', v, $t_kvkk_ar$نص الإفصاح بموجب KVKK$t_kvkk_ar$, $c_kvkk_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

عملاً بالمادة 10 من قانون حماية البيانات الشخصية رقم 6698 ("**القانون**" / "**KVKK**") وبالبلاغ المتعلق بالإجراءات والأسس الواجب اتباعها في الوفاء بالتزام الإفصاح، نحيطكم علماً بكيفية معالجة بياناتكم الشخصية عند استخدامكم تطبيق BÜ Kampüs وموقعه الإلكتروني. هذا النص لأغراض الإعلام؛ أما العمليات التي تتطلب الموافقة الصريحة فتُطلب منكم لها موافقة منفصلة بموجب [نص الموافقة الصريحة](/legal/explicit-consent).

## 1. المسؤول عن البيانات

| | |
|---|---|
| المسؤول عن البيانات | {{controller.name}} |
{{?controller.address}}| العنوان | {{controller.address}} |{{/controller.address}}
{{?controller.email}}| البريد الإلكتروني | {{controller.email}} |{{/controller.email}}
{{?controller.kep}}| عنوان KEP (البريد الإلكتروني المسجّل) | {{controller.kep}} |{{/controller.kep}}
{{?controller.verbis}}| رقم السجل في VERBİS | {{controller.verbis}} |{{/controller.verbis}}
| التقديم عبر التطبيق | قسم الدعم{{?support.email}} · {{support.email}}{{/support.email}} |

## 2. فئات البيانات الشخصية المعالَجة

| الفئة | أمثلة |
|---|---|
| الهوية | الاسم واللقب؛ وعند اختياركم تسجيل الدخول عبر Google أو Apple (اختياري) اسم المزوّد والمعرّف الذي يمنحه المزوّد لحسابكم |
| الاتصال | عنوان البريد الإلكتروني (من أي مزوّد؛ وعند الدخول عبر Google/Apple العنوان الذي يبلّغ عنه المزوّد وقد يكون عنوان ترحيل خاصًا لدى Apple)، وبريد التواصل في طلبات الدعم |
| المعلومات التعليمية/المهنية | الكلية، القسم، الصف الدراسي، صفة الطالب/الموظف |
| المرئية | صورة الملف الشخصي؛ صورة المنشور (صورة واحدة لكل منشور)؛ صور ومقاطع فيديو المحادثات (تُزال البيانات الوصفية EXIF من الصور؛ ولا يعيد الخادم ترميز مقاطع فيديو المحادثات ولا يزيل البيانات الوصفية داخلها، وتُخزَّن مشفّرة) |
| محتوى المستخدم | الرسائل، منشورات المجتمعات ومنشورات الاستكشاف (Keşfet) (صورة واحدة ونص لا يزيد على 7 كلمات)، أصوات الاستطلاعات، ردود طلبات المشاركة في الفعاليات، الملاحظات والاقتراحات، ونصوص الدعم والاعتراض، والنبذة التعريفية |
| معاملات العميل / الاستخدام | عضويات المجتمعات، المشاركة في الفعاليات وتسجيل الحضور، المفضلات، علاقات المتابعة، تفضيلات الإشعارات والخصوصية، قائمة الحظر، سجل حملات الإعلانات البريدية للمسؤولين التي وصلتك (الحملة وحالة التسليم) |
| الخطة الشخصية | جدول الدروس والمقررات والفصول الدراسية وسجلات الامتحانات التي يدخلها المستخدم بنفسه |
| أمن المعاملات | معلومات الجلسة، الملخص المجزّأ لكلمة المرور، الملخص غير القابل للعكس لمعرّف الجهاز، عنوان IP، المنصة وإصدار التطبيق، سجلات حظر الوصول، الأخطاء ومحاولات تسجيل الدخول |
| الإجراءات القانونية / الامتثال | سجلات الموافقة على الاتفاقيات، سجلات الشكاوى/البلاغات والإشراف، سجلات وصول المديرين |
| التسويق | لا يُعالَج (لا تجري أي معالجة لأغراض الإعلان/التسويق). والرسائل البريدية التي يرسلها المسؤولون هي إعلانات خدمة ومجتمع، وفي كل رسالة رابط لإلغاء الاشتراك |
| البيانات ذات الطبيعة الخاصة | لا تُطلب عمداً. أما البيانات ذات الطبيعة الخاصة التي تشاركونها ضمن محتوى المستخدم (مثل الرسائل) فتُستضاف في حدود مشاركتكم فقط، ولا نهدف إلى معالجتها. |

## 3. أغراض المعالجة

1. إنشاء العضوية، والتحقق من الهوية والبريد الإلكتروني، وأمن الحساب.
2. تقديم خدمات الأخبار والإعلانات والفعاليات وقائمة الطعام والمجتمعات وتسجيل الحضور والمراسلة والبحث والمفضلات.
3. إرسال الإشعارات (داخل التطبيق، الفورية، البريد الإلكتروني).
4. تنفيذ طلبات الدعم والملاحظات والاعتراضات.
5. الأمن، ومنع إساءة الاستخدام والتحايل على حظر المستخدمين المحظورين، والإشراف.
6. تحسين الخدمة، ومتابعة الأخطاء والأداء (تحليل مجمَّع).
7. الوفاء بالالتزامات القانونية، والاستجابة لطلبات الجهات المختصة، وممارسة الحقوق والدفاع عنها.
8. حفظ سجلات الاتفاقيات والموافقات.
9. تقديم خدمات المنشورات والمتابعة والمفضلات والاستطلاعات والجدول الدراسي الشخصي؛ وإرسال الإعلانات البريدية للمسؤولين.
10. التصفية الآلية للألفاظ غير اللائقة في المساحات العامة وتنفيذ الشكاوى.

## 4. الأسس القانونية

| السبب القانوني | أمثلة على أنشطة المعالجة |
|---|---|
| م.5/2-(a) النص عليه صراحةً في القوانين | إعطاء المعلومات للجهات المختصة، والسجلات التي تفرضها التشريعات |
| م.5/2-(c) إبرام العقد أو تنفيذه | العضوية، الملف الشخصي، المراسلة، خدمات المجتمعات/الفعاليات، إرسال الإشعارات والبريد الإلكتروني |
| م.5/2-(ç) وفاء المسؤول عن البيانات بالتزامه القانوني | سجلات الموافقة على الاتفاقيات، الطلبات القانونية، الحفظ وفق التشريعات ذات الصلة |
| م.5/2-(e) تقرير حق أو ممارسته أو حمايته | آثار الإشراف، والسجلات ذات القيمة الإثباتية للاعتراضات والنزاعات |
| م.5/2-(f) المصلحة المشروعة (بشرط عدم الإضرار بالحقوق والحريات الأساسية) | الأمن، سجل الجهاز/IP، تحديد المعدل، رقابة وصول المديرين، التحليلات |
| م.5/1 الموافقة الصريحة | العمليات **الاختيارية** مثل مطابقة جهات الاتصال، وإذن الإشعارات الفورية، ونشر حقول الملف الشخصي الاختيارية |

(يجوز أن يكون البندان م.5/2-(ç) وم.5/2-(e) أساساً مشتركاً في العمليات ذات الصلة.)

## 5. نقل البيانات الشخصية

| فئة المستلمين | البيانات المنقولة | الغرض | داخل البلاد / خارجها |
|---|---|---|---|
| مزوّدو الاستضافة والبنية التحتية (معالج البيانات) | بيانات الخدمة (الرسائل مشفّرة) | استضافة الخدمة | {{hosting.location|يُبلَّغ موقع الاستضافة لاحقاً من المسؤول عن البيانات}} |
| مزوّد خدمة إرسال البريد الإلكتروني: Brevo (SMTP؛ معالج البيانات) | البريد الإلكتروني للمستلم، محتوى الرسالة؛ وفي الإعلانات الاسم والقسم/الكلية/السنة لأغراض التخصيص | رسائل التحقق/إعادة تعيين كلمة المرور/الأمن وإعلانات المسؤولين | **قد يكون خارج البلاد** (قد توجد خوادم المزوّد في أوروبا أو بلدان أخرى) |
| مزوّد الإشعارات: Google LLC (Firebase Cloud Messaging) وApple Inc. (APNs) لنظام iOS | مفتاح إشعارات الجهاز، عنوان الإشعار/نصه القصير، معلومة الوجهة، المنصة | إيصال الإشعارات الفورية | **خارج البلاد** |
| الجهات والمؤسسات العامة المختصة (المحكمة، النيابة، الضابطة العدلية، هيئة حماية البيانات الشخصية وغيرها) | البيانات ضمن نطاق الطلب | الالتزام القانوني | داخل البلاد |

**لا يوجد نقل إلى الجامعة.** لا تُنقل بياناتكم الشخصية إلى جامعة بينغول أو وحداتها: فالخدمة تقرأ من مواقع الجامعة فقط محتوى الأخبار والإعلانات والفعاليات وقائمة الطعام المتاح للعموم. ولا يعمل مديرو لوحة الإدارة باسم الجامعة (انظر البند 8). ملاحظة: بما أن رسائلنا الإلكترونية تصل إلى عنوان بريدكم الإلكتروني المسجّل، فقد تعالج الجهة التي تشغّل صندوق البريد ذاك (مزوّد بريدكم الإلكتروني، أو الجامعة إن كنتم تستخدمون عنوانًا بنطاق bingol.edu.tr) الرسالة تقنيًا على بنيتها التحتية؛ وهذا ليس نقلًا يجريه المسؤول عن البيانات بل طبيعة البريد الإلكتروني. وإذا سجّلتم الدخول عبر Google أو Apple فإن المصادقة تتم بين جهازكم والمزوّد المعني؛ ولا يتحقق خادمنا إلا من رمز الهوية الموقَّع الصادر عن المزوّد، ولا يرسل أي بيانات إلى المزوّد نيابةً عنكم. وتخضع معالجة المزوّدين الخاصة لإشعاراتهم وسياساتهم الخاصة بالخصوصية.

**النقل إلى الخارج (م.9).** لأجل الإشعارات الفورية، يُنقل مفتاح إشعارات جهازكم ومحتوى الإشعار إلى الخارج عبر Firebase/APNs. ويستند هذا النقل، في إطار المادة 9 من القانون وأنظمة هيئة حماية البيانات الشخصية ذات الصلة، إلى **موافقتكم الصريحة المبنية على إذن الإشعارات** و/أو إلى آليات الكفاية/الضمانات المناسبة (العقد النموذجي وغيره). وإن لم تمنحوا إذن الإشعارات فلن تتلقوا إشعارات فورية، لكن صندوق الإشعارات داخل التطبيق وسائر الخدمات تواصل العمل. ويمكنكم سحب موافقتكم في أي وقت من إعدادات الجهاز أو من إعدادات الأذونات/الإشعارات في التطبيق. وقد توجد خوادم مزوّد خدمة إرسال البريد الإلكتروني (Brevo) خارج البلاد أيضًا؛ وقد يُنقل عنوان بريدكم ومحتوى الرسالة إلى هذا المزوّد لإيصال رسائل التحقق وإعادة تعيين كلمة المرور والإعلانات، ويستند هذا النقل كذلك إلى آليات المادة 9 المذكورة أعلاه.

## 6. طريقة جمع البيانات الشخصية

تُجمع بياناتكم عبر التطبيق والموقع الإلكتروني في البيئة الإلكترونية، بطرق آلية وشبه آلية، من خلال نماذج التسجيل/الملف الشخصي، والمراسلة ومشاركة المحتوى، ونماذج الدعم، والاتصال التقني لجهازكم (IP، ملخص الجهاز، إصدار التطبيق)، والتخزين المحلي الشبيه بملفات تعريف الارتباط، و(إذا منحتم الإذن) طلب مطابقة جهات الاتصال. أما محتويات الأخبار وقائمة الطعام فتُجمع من مصادر عامة لا تتضمن بيانات شخصية.

## 7. مدة الحفظ

تُحفظ البيانات الشخصية للمدة اللازمة لغرض المعالجة وللمدة المنصوص عليها في التشريعات ذات الصلة، وعند انتهاء المدة تُحذف أو تُتلف أو تُجعل مجهولة الهوية. أبرز المدد: التسجيل المعلّق ساعة واحدة؛ رمز التحقق 10 دقائق؛ مفتاح التجديد 30 يوماً على الأكثر؛ الإشعار المقروء 30 يوماً وغير المقروء 90 يوماً (أحدث 200 لكل مستخدم)؛ مفتاح إشعارات الجهاز إذا لم يُشاهَد 60 يوماً؛ سجلات أمن الجهاز/IP 90 يوماً؛ سجل مرشّح الألفاظ غير اللائقة 90 يوماً؛ سجل طابور push بعد 7 أيام من الإرسال (30 يوماً إن فشل)؛ أحداث التحليلات الخام 45 يوماً (وبعدها تبقى فقط ملخصات مجمّعة غير مرتبطة بالأشخاص)؛ سجل النشاط اليومي 400 يوم؛ طابور البريد الإلكتروني: المرسل 7 أيام والفاشل 30 يوماً؛ سجلات حملات الإعلانات البريدية للمسؤولين 180 يوماً بعد انتهاء الحملة؛ سجل إجراءات المسؤولين 365 يوماً؛ سجلات الوصول إلى الرسائل وإجراءات النوادي 730 يوماً؛ النسخة المشفّرة من الصورة ذات الإرسال الواحد 365 يوماً؛ طلب الدعم العام 365 يوماً. وما دام الحساب مفتوحاً يُحفظ ملفكم الشخصي ومحتوياتكم؛ وقد تُحفظ بشكل مستقل لأغراض الأمن/الإثبات النسخة المشفّرة من الرسائل المحذوفة وسجلات الموافقة على الاتفاقيات. الجدول التفصيلي: [الحفظ والإتلاف](/legal/retention).

## 8. وصول المديرين وصلاحياتهم (ملاحظة شفافية)

تُخزَّن الرسائل مشفّرة على الخادم، لكن النظام ليس مشفّراً من طرف إلى طرف. تُعرَّف حسابات لوحة الإدارة من قِبل المشغِّل وتحمل أحد خمسة أدوار (مدير كامل الصلاحيات، مشرف، دعم، محرِّر، للقراءة فقط)؛ ولا يعمل المديرون باسم الجامعة. ولا يصل إلى الحقول الشخصية (البريد الإلكتروني غير المحجوب، وIP، وتفاصيل الجهاز) إلا المدير الكامل الصلاحيات والمشرف؛ وفي الأدوار الأخرى تكون هذه الحقول محجوبة جزئيًا. **ولا يصل إلى مضمون الرسائل والوسائط إلا المدير الكامل الصلاحيات والمشرف،** وذلك لأسباب مثل مراجعة الشكاوى والأمن وإساءة الاستخدام والطلبات القانونية فقط، بإدخال سبب كتابي (10 أحرف على الأقل)؛ ويُسجَّل كل عرض تلقائيًا وبشكل غير قابل للتعديل (المدير، والمستخدم المعروض، والمحادثة، وعدد الرسائل، والسبب، وIP، والوقت؛ 730 يومًا) وإذا تعذّر كتابة السجل فلا يُعرض المحتوى. كما يجوز للمديرين إخفاء رسالة أو حذفها، وإغلاق محادثة، وإزالة محتوى، وإغلاق نادٍ، وتعليق حساب؛ وتُكتب هذه العمليات في سجل إجراءات المديرين (365 يومًا). والسبب القانوني لهذا النشاط هو المصلحة المشروعة والالتزام القانوني (م.5/2-(f)، (ç)، (e))؛ والتفصيل في البندين 3 و14 من [سياسة الخصوصية](/legal/privacy).

## 9. اتخاذ القرارات الآلية

لا تتخذ الخدمة بحقكم قراراً يرتب نتيجة قانونية بالمعالجة الآلية وحدها. فإذا تراكمت سجلات انتهاك متعددة على الحساب نفسه، فإن النظام يولّد لمدير **توصية** فقط؛ أما قرار التعليق فيتخذه مدير. وتوجد تدابير آلية مثل تحديد المعدل، والتحقق من ملخص المحتوى المحظور، ومرشّح الألفاظ غير اللائقة في المساحات العامة، والإخفاء التلقائي المؤقت للمحتوى إلى حين اكتمال المراجعة إذا أُبلغ عنه من عدة حسابات مستقلة بعضها عن بعض (ويجوز للمدير إعادة إظهاره)؛ ويجوز للمرشّح أن يرفض محتوى تلقائياً (رسائل المحادثات غير خاضعة لهذه الرقابة)، ويمكنكم تقديم اعتراضكم من قسم الدعم. أما القرارات التي ترتب نتائج دائمة على حسابكم فيتخذها مدير.

## 10. حقوقكم (م.11)

يمكنكم بالتقدم إلى المسؤول عن البيانات أن تطلبوا ما يأتي:

1. معرفة ما إذا كانت بياناتكم الشخصية قد عُولجت،
2. طلب المعلومات المتعلقة بها إن كانت قد عُولجت،
3. معرفة غرض المعالجة وما إذا كانت تُستخدم وفق غرضها،
4. معرفة الأطراف الثالثة التي نُقلت إليها داخل البلاد أو خارجها،
5. طلب تصحيحها إن كانت ناقصة أو غير صحيحة،
6. طلب حذفها أو إتلافها في إطار الشروط الواردة في المادة 7 من القانون،
7. طلب إبلاغ الأطراف الثالثة التي نُقلت إليها البيانات بالعمليات المنفَّذة وفق البندين (5) و(6)،
8. الاعتراض على ظهور نتيجة ضدكم بسبب تحليل البيانات المعالَجة حصراً بوساطة أنظمة آلية،
9. المطالبة بتعويض الضرر إذا لحق بكم ضرر بسبب معالجة مخالفة للقانون.

الاختصارات داخل التطبيق: تعديل الملف الشخصي وإعدادات الخصوصية (التصحيح/التحكم في النشر)، **تنزيل بياناتي** (الاطلاع/النسخة)، **حذف الحساب** (الحذف/إخفاء الهوية).

## 11. طريق التقديم

1. **داخل التطبيق:** أنشئوا طلباً من قسم الدعم بموضوع "طلب بشأن البيانات الشخصية" (يُتحقق من هوية المستخدم المسجّل دخوله عبر الحساب).
2. **كتابةً:** بعريضة موقّعة بخط اليد{{?controller.address}} إلى العنوان {{controller.address}}{{/controller.address}} تسليماً باليد أو عبر كاتب العدل.
{{?controller.kep}}3. **KEP:** تقديم موقّع بتوقيع إلكتروني آمن إلى العنوان {{controller.kep}}.{{/controller.kep}}
{{?controller.email}}4. **البريد الإلكتروني:** إلى العنوان {{controller.email}} من عنوان بريدكم الإلكتروني المسجّل.{{/controller.email}}

يجب أن يتضمن طلبكم: الاسم واللقب، ومعلومة تفيد في التحقق من الهوية (بريد الحساب الإلكتروني)، وعنوان التبليغ، وموضوع الطلب. وقد نطلب معلومات إضافية للتحقق من هويتكم. وتُنجَز الطلبات مجاناً **في موعد أقصاه 30 يوماً** بحسب طبيعة الطلب؛ وإن استلزمت العملية كلفة إضافية فقد تُتقاضى الرسوم وفق التعرفة التي تحددها الهيئة.

وفي حال رفض الطلب، أو عدم كفاية الرد، أو عدم الرد في المدة المحددة، يحق لكم **تقديم شكوى إلى هيئة حماية البيانات الشخصية** خلال 30 يوماً من تاريخ علمكم بالرد، وعلى أي حال خلال 60 يوماً من تاريخ التقدم بالطلب.$c_kvkk_ar$, FALSE, TRUE);
END
$do_kvkk$;
