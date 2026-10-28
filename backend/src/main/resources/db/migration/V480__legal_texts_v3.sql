-- V480: Sozlesme metinleri 5. nesil (docs/legal/*.md'den scripts/build-legal-migration.js ile URETILDI; elle duzenlemeyin).
-- * Arapca (ar) metinler eklendi. Kullanim Kosullari (TERMS), Gizlilik (PRIVACY) ve Icerik Bildirimi (CONTENT_REMOVAL) tr/en metni degistigi icin
--   yeni surum (COALESCE(MAX(version),0)+1) tr+en+ar ayni numarayla aktif eklenir, onceki aktif surumler pasife alinir.
-- * Metni degismeyen turlerde (KVKK, COMMUNITY_RULES, EXPLICIT_CONSENT, COOKIES, RETENTION) mevcut aktif tr surumune ar satiri eklenir; surum degismez, yeniden onay istenmez.
-- * require_reaccept: yeni surumde TERMS ve PRIVACY icin TRUE (mevcut kullanicilar yeniden onaylar), CONTENT_REMOVAL bilgilendirmedir.
-- * Yeni yonetici ayarlari: legal.controller.relation (Universite ile iliski cumlesi), legal.controller.jurisdiction (yetkili mahkeme sehri). Bos birakilirsa metindeki varsayilan cumle/Bingol kullanilir.
-- * Dosya adi V480__legal_texts_v3.sql talep uzerine boyledir (icerik olarak 5. nesil).

INSERT INTO app_setting (setting_key, setting_value) VALUES
 ('legal.controller.relation', ''),
 ('legal.controller.jurisdiction', '')
ON CONFLICT (setting_key) DO NOTHING;

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
3. Hizmet; haber, duyuru ve etkinlik takibi, yemek listesi, profil, mesajlaşma, topluluklar ve etkinlikler (QR ile yoklama dahil), gönderiler, yorumlar ve 24 saatlik hikâyeler, kullanıcı takibi, anketler, kişisel ders programı ve sınav takibi, bildirimler, arama, favoriler ile destek ve geri bildirim özelliklerinden oluşur.
4. Bu koşullar; [Gizlilik Politikası](/legal/privacy), [KVKK Aydınlatma Metni](/legal/kvkk), [Topluluk Kuralları](/legal/community-rules), [Açık Rıza Metni](/legal/explicit-consent), [Çerez ve Yerel Depolama Politikası](/legal/cookies), [İçerik Bildirimi ve Kaldırma](/legal/content-removal) ve [Saklama ve İmha](/legal/retention) metinleriyle birlikte okunur. Topluluk Kuralları bu koşulların ayrılmaz parçasıdır.

> **Özetle:** Hizmeti kullanmak için bu koşulları, Gizlilik Politikasını, KVKK Aydınlatma Metnini ve Topluluk Kurallarını kabul edersiniz. Diğer metinler bilgilendirme veya isteğe bağlı izinler içindir.

## 2. Hesap ve uygunluk

1. **Kimler kayıt olabilir?** Kayıt yalnızca Bingöl Üniversitesi öğrencileri ve personeli içindir ve yalnızca `bingol.edu.tr` (alt alan adları dahil) uzantılı e-posta adresiyle yapılır. E-posta adresinize gönderilen doğrulama kodunu girmeden hesap açılmaz. Doğrulama kodu 10 dakika geçerlidir ve sınırlı sayıda deneme hakkı vardır.
2. **Bilgilerin doğruluğu.** Hesap bilgilerinizin doğru olmasından ve şifrenizin güvenliğinden siz sorumlusunuz. Şifrenizi kimseyle paylaşmayın. Hesabınızın izinsiz kullanıldığını fark ederseniz derhal Destek bölümünden bize bildirin; "tüm oturumları kapat" seçeneğini kullanabilirsiniz.
3. **Hesap devredilemez.** Hesabınızı başkasına devredemez, satamaz veya paylaşamazsınız. Bir kişi birden fazla hesabı kötüye kullanım amacıyla açamaz.
4. **Yaş.** Hizmet üniversite öğrencileri ve personeline yöneliktir; 18 yaşından küçük kullanıcılara özel olarak yönelik değildir. 18 yaşından küçük bir öğrenci kullanıyorsa, yasal temsilcisinin bilgisi ve izni dahilinde kullanması esastır; bu durumda ilgili kişisel verilerin işlenmesine ilişkin yasal temsilcinin onayı gerekebilir. Bu durumu fark ettiğimiz hesaplarda ek doğrulama isteyebiliriz.
5. **Tek cihaz kuralı (mobil).** Güvenliğiniz için mobil uygulamada aynı anda tek oturum açık kalır: başka bir mobil cihazdan giriş yaptığınızda önceki mobil oturumlarınız sonlandırılır ve önceki cihaza "yeni cihazdan giriş" uyarısı e-postası gönderilebilir. Web üzerindeki oturumlar bu kuraldan etkilenmez.
6. **Oturum süresi.** Erişim anahtarınız kısa ömürlüdür (15 dakika) ve otomatik yenilenir; yenileme anahtarı en çok 30 gün geçerlidir ve tek kullanımlıktır. Şifre sıfırlandığında tüm oturumlarınız kapatılır.

> **Özetle:** Yalnızca bingol.edu.tr e-postasıyla, doğrulayarak kayıt olursunuz. Hesap size aittir ve devredilemez. Mobilde aynı anda tek cihazda oturum açık kalır.

## 3. Kullanıcı içerikleri ve lisans

1. **İçeriğin sahibi sizsiniz.** Mesaj, fotoğraf, video, topluluk gönderisi, etkinlik, profil bilgisi, geri bildirim gibi paylaştığınız içeriklerin ("**Kullanıcı İçeriği**") hakları size aittir. İçeriklerin hukuka uygunluğundan siz sorumlusunuz.
2. **Bize verdiğiniz sınırlı lisans.** Hizmeti sunabilmemiz için, Kullanıcı İçeriğinizi yalnızca şu amaçlarla barındırma, saklama, şifreleme, yeniden boyutlandırma/yeniden kodlama, iletme, görüntüleme ve (içeriği gönderdiğiniz kişi ve topluluklara) sunma konusunda; münhasır olmayan, devredilemez, ücretsiz, dünya çapında ve Hizmet süresiyle sınırlı bir lisans vermiş olursunuz. İçeriğinizi reklam amacıyla kullanmayız, üçüncü kişilere satmayız.
3. **Medyanın işlenmesi.** Yüklenen fotoğraflar türü ve boyutu doğrulandıktan sonra yeniden kodlanır; konum gibi gömülü üst veriler (EXIF) temizlenir. Sohbet fotoğrafları en çok 1600 piksel kenar uzunluğuna indirilir; mesaj başına en çok 10 ek (fotoğraf/video karışık) gönderilebilir. Sohbet videoları cihazınızda sıkıştırılır, sunucu bunları yeniden kodlamaz; gönderi (Keşfet) videoları ise yüklendikten sonra sunucuda yeniden kodlanır (H.264, en çok 720p) ve şifreli saklanır. Videolar en çok 60 saniye ve 40 MB'a kadar kabul edilir (hikâye videosu en çok 30 saniye), günlük/saatlik yükleme sınırları vardır. Bu sınırlar değişebilir.
4. **Yasaklı içerik kontrolü.** Yüklenen görsellerin dijital özeti (SHA-256), yetkili yöneticilerin yönettiği "yasaklı içerik" özet listesiyle karşılaştırılır. Eşleşme halinde yükleme reddedilir. Bu kontrol yalnızca özet karşılaştırmasıdır; görsellerin içeriği otomatik olarak analiz edilmez.
5. **Gönderi, yorum ve hikâyeler.** Gönderi, yorum ve hikâyelerinizin içeriğinden, etiketlediğiniz (#) ve andığınız (@) kişilere ilişkin paylaşımlardan ve üçüncü kişilere ait hak ve verilerin ihlal edilmemesinden siz sorumlusunuz. Bu içerikler uygulamaya giriş yapmış diğer kullanıcılara gösterilir; hikâyeler 24 saat görünür ve ardından silinir. İçerikler yayımlanmadan önce insan denetiminden geçmez; bu nedenle işletici yer sağlayıcı olarak hukuka aykırı içeriği bildirim üzerine kaldırır. Herhangi bir gönderi, yorum veya hikâye **Bildir** ile şikâyet edilebilir; yetkili yöneticiler inceler, içeriği gizleyebilir/kaldırabilir, uyarı veya hesap kısıtlaması uygulayabilir. Karara itiraz edebilirsiniz (bkz. 5. bölüm ve [İçerik Bildirimi ve Kaldırma](/legal/content-removal)).
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
10. Topluluk, etkinlik, profil, grup başlığı ve gönderi/yorum/hikâye gibi herkese açık alanlarda küfür, hakaret, nefret söylemi veya cinsel içerikli ifadeler kullanmak. Bu tür içerik otomatik olarak reddedilebilir. Özel sohbetlerde ve grup mesajlarında içerik ön denetimden geçirilmez; ancak taciz, tehdit veya uygunsuz içerik kullanıcılar tarafından şikâyet edilebilir ve uygulama içi şikâyet/geri bildirim kanalıyla incelenerek içerik kaldırma, uyarı veya hesap kısıtlaması uygulanabilir.

## 5. Moderasyon, askıya alma ve engelleme

1. **Bildirme.** Her kullanıcı kullanıcıları, mesajları, gönderileri, toplulukları ve etkinlikleri "Bildir" ile raporlayabilir. Kötüye kullanımı önlemek için rapor sayısı sınırlıdır; art niyetli veya tekrarlı asılsız raporlar rapor kısıtlamasına yol açabilir.
2. **İnceleme.** Raporlar yetkili yöneticiler tarafından incelenir. İnceleme sırasında raporla ilgili içerik ve ilişkili sohbet bağlamı görülebilir (bkz. 6. bölüm).
3. **Yaptırım basamakları.** Duruma göre: (a) içeriğin kaldırılması veya gizlenmesi; (b) uyarı/bildirim; (c) ihlal kaydı (aynı kullanıcı için 180 günlük pencerede çözülmüş 3 ihlal yöneticiye askıya alma önerisi doğurur; eşik ayarlanabilir); (d) geçici askıya alma; (e) kalıcı hesap kapatma; (f) gerekirse IP, ağ aralığı, cihaz veya kullanıcı bazlı erişim engeli. Ağır ihlallerde (ör. çocuk istismarı, terör, tehdit) basamaklar atlanabilir ve yetkili makamlara bildirim yapılabilir.
4. **Erişim engeli (cihaz ve IP).** Güvenlik ve kötüye kullanımın önlenmesi amacıyla giriş/kayıt/istek sırasında IP adresiniz ve cihaz tanımlayıcınızın (geri döndürülemez özet olarak saklanan) kaydı tutulur; yasaklı bir kullanıcının hesabı, cihazı veya IP adresiyle eşleşen yeni hesap/oturum engellenebilir. Anonimleştirici ağlardan (ör. VPN, Tor, veri merkezi aralıkları) gelen istekler de güvenlik amacıyla engellenebilir. Ayrıntı Gizlilik Politikası'ndadır.
5. **Bildirim ve itiraz.** Askıya alma veya içerik kaldırma kararlarında mümkün olduğunca size uygulama içi bildirim yapılır. Karara itiraz için uygulamadaki **itiraz** özelliğini veya Destek bölümünü kullanabilirsiniz; itirazlar bir yönetici tarafından yeniden değerlendirilir ve sonuç size bildirilir. Hesap güvenliğini doğrudan tehdit eden acil durumlarda önlem, itirazdan önce uygulanabilir.
6. **Kullanıcı engellemesi.** Dilediğiniz kullanıcıyı engelleyebilirsiniz. Engelleme gizlilik içindir: engellediğiniz kişinin size gönderdiği mesajlar size iletilmez (geçmişte, bildirimde veya okunmamış sayacında görünmez); engellenen kişiye engellendiğini bildiren bir uyarı gösterilmez. Engel sonradan kaldırılsa bile engel sırasında gönderilmiş mesajlar size iletilmez. Bu mesajlar sistemde kalır; yetkili yöneticiler şikâyet incelemesi sırasında bu mesajları görebilir. Gruplarda engellediğiniz kişinin mesajları sizin için gizlenir, diğer üyeler normal görür.

> **Özetle:** Kurallara aykırı içerik kaldırılabilir, hesap askıya alınabilir veya kapatılabilir; cihaz/IP engeli uygulanabilir. Karara uygulama içinden itiraz edebilirsiniz.

## 6. Mesajlaşma ve yönetici erişimi

Bu bölüm, mesajlarınızın sizinle karşı taraf arasında "tamamen gizli" olmadığını açıkça belirtir. Lütfen dikkatle okuyun.

1. **Şifreleme türü.** Mesajlar iletim sırasında şifrelidir (TLS/WSS) ve sunucuda şifreli (AES-256-GCM) saklanır. Sistem **uçtan uca şifreli değildir**: şifre çözme anahtarları sunucu tarafında tutulur; yetkili yöneticiler gerektiğinde mesajları görüntüleyebilir. Mesajlarınızı kimsenin okuyamayacağı yönünde bir taahhüdümüz yoktur.
2. **Yönetici erişimi ne zaman?** Yalnızca yetkili yöneticiler; şikâyet ve rapor incelemesi, hesap güvenliği, kötüye kullanım ve yasa dışı faaliyet şüphesi, mahkeme/savcılık/kolluk gibi yetkili makam talepleri veya kullanıcının kendi başvurusu gibi gerekçelerle mesajlara erişebilir. Meraktan veya amaç dışı görüntüleme yasaktır; yöneticiler gizlilik taahhüdüne tabidir.
3. **Denetim.** Yöneticinin her mesaj görüntülemesi, içerik gösterilmeden önce otomatik olarak değiştirilemez bir erişim kaydına yazılır (yönetici, görüntülenen kullanıcı, sohbet, kaç mesaj, IP adresi, zaman). Kayıt yazılamazsa içerik gösterilmez. Erişim kayıtları, hukuki ve güvenlik denetimi amacıyla saklanır.
4. **Silinen ve düzenlenen mesajlar.** "Herkes için sil" dediğinizde mesaj diğer kullanıcılara "Bu mesaj silindi" olarak görünür; ancak mesajın şifreli kopyası, düzenleme geçmişi ve ekleri güvenlik ve şikâyet incelemesi için sunucuda saklanmaya devam edebilir (varsayılan: süresiz; işletici bir saklama süresi belirlediğinde bu sürenin sonunda kalıcı silinir). Düzenlediğiniz mesajların önceki sürümleri de şifreli olarak saklanır. Kullanıcı arayüzünde silinmiş mesajı bir daha göremezsiniz; "verilerimi indir" çıktısına silinmiş mesajlar dahil edilmez.
5. **Tek gönderimlik fotoğraf.** Bu özellikte alıcı fotoğrafı yalnızca bir kez açabilir; açtıktan sonra (veya gönderimden 24 saat sonra) alıcının erişimi kapanır ve gönderen kendi gönderdiğini yeniden açamaz. Ancak güvenlik ve şikâyet incelemesi için, yetkili yöneticilerin inceleyebilmesi amacıyla fotoğraf dosyası **şifreli olarak sunucuda 365 gün** (ayarlanabilir süre) saklanır ve sonra silinir. Cihazda ekran görüntüsü alınmasına teknik engeller konulsa da **ekran görüntüsü veya ekran kaydı alınmayacağı garanti edilmez**; alıcı başka bir cihazla fotoğraf çekebilir. Bu nedenle, başkasının eline geçmesini istemediğiniz görselleri göndermeyin.
6. **Bildirim önizlemesi.** Varsayılan olarak anlık bildirimlerde mesaj metni yer almaz; "Yeni mesajınız var" türünde genel bir bildirim gönderilir.
7. **Hesap silindiğinde sohbetler.** Hesabınızı sildiğinizde gönderdiğiniz mesajlar karşı tarafın sohbet geçmişinin parçası olduğundan silinmez; yazar adı anonim görünür. Hesabın yüklediği sohbet fotoğrafları silinir.

> **Özetle:** Mesajlar şifreli saklanır ama uçtan uca şifreli değildir. Yetkili yöneticiler yalnızca gerekçeli durumlarda görüntüleyebilir ve her erişim kayda geçer. Silinen mesajların ve tek gönderimlik fotoğrafların şifreli kopyası güvenlik amacıyla bir süre saklanabilir. Ekran görüntüsüne karşı mutlak garanti verilmez.

## 7. Topluluklar ve etkinlikler

1. **Topluluk/kulüp yöneticileri**, kendi topluluklarındaki içerik ve üyelerden sorumludur; Topluluk Kurallarına ve bu koşullara uymak zorundadır. Yöneticilik yetkileri devredilebilir; yetki devrinde sistem onay adımları uygulayabilir.
2. **Etkinlik oluşturanlar** etkinlik bilgilerinin doğruluğundan ve etkinliğin hukuka uygunluğundan sorumludur. Etkinlik yoklaması QR kod veya elle yoklama ile yapılır; yoklama kayıtları etkinlik organizatörüne ve yetkili yöneticilere görünür.
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
4. **Mesaj ve medya yedekleri.** Ana şifreleme anahtarının kaybı halinde mesajların kurtarılamayacağı riski bulunmaktadır; önemli belgelerinizin yedeğini kendiniz alın.

## 11. Tazminat

Bu koşulları, Topluluk Kurallarını veya hukuku ihlal etmeniz nedeniyle işleticiye yöneltilen üçüncü kişi taleplerinden doğan makul zararların (makul avukatlık giderleri dahil) giderilmesinden, kusurunuz ölçüsünde sorumlu olursunuz. Bu hüküm, kanunun öngördüğü yasal sorumluluk sınırlarını ortadan kaldırmaz.

## 12. Değişiklikler ve yeniden onay

1. Koşulları hukuki veya teknik gereklilikler nedeniyle güncelleyebiliriz. Güncel sürüm ve sürüm geçmişi bu sayfada yer alır.
2. Önemli değişikliklerde uygulama sizden yeni sürümü **yeniden onaylamanızı** ister; yeniden onay verene kadar Hizmetin bazı bölümlerine erişiminiz kısıtlanabilir.
3. Onay sürümü ve zamanı, hukuki kanıt amacıyla hesap silindikten sonra da saklanır (bkz. Saklama ve İmha).

## 13. Fesih ve hesap kapatma

1. Hesabınızı dilediğiniz zaman uygulamadan veya [hesap silme sayfasından](/delete-account) kapatabilirsiniz. Hesap silme **anonimleştirmedir:** adınız, e-postanız ve profil bilgileriniz anonimleştirilir, bildirim cihaz kayıtlarınız silinir; ayrıntı Gizlilik Politikası ve KVKK Aydınlatma Metni'nde açıklanmıştır.
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
2. Size yapılacak bildirim ve tebligatlar, kayıtlı kurumsal e-posta adresinize ve uygulama içi bildirim kutusuna gönderilir; gönderim anında tebliğ edilmiş sayılır. E-posta adresinizi ve iletişim bilgilerinizi güncel tutmak sizin sorumluluğunuzdadır. Bize yapılacak bildirimler {{support.email|uygulama içi Destek bölümü}} üzerinden{{?controller.kep}} veya {{controller.kep}} KEP adresine{{/controller.kep}} iletilir.

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
{{?controller.address}}- Adres: {{controller.address}}{{/controller.address}}$c_terms_tr$, TRUE, TRUE),
    ('TERMS', 'en', v, $t_terms_en$Terms of Use$t_terms_en$, $c_terms_en$*This English text is provided for information only. The Turkish text is authoritative.*

These terms govern your use of the BÜ Kampüs application and website (the "**Service**"). By registering you accept them; your acceptance (document version and time) is recorded.

## 1. Parties and scope

1. The Service is operated by {{controller.name}}{{?controller.address}}, {{controller.address}}{{/controller.address}} ("**Operator**", "**we**").
2. These terms are read together with the [Privacy Policy](/legal/privacy), the [KVKK Notice](/legal/kvkk), the [Community Rules](/legal/community-rules), the [Explicit Consent text](/legal/explicit-consent), the [Cookie Policy](/legal/cookies), [Content Notice and Removal](/legal/content-removal) and [Retention](/legal/retention). The Community Rules form an integral part of these terms.

> **In short:** To use the Service you accept the Terms, Privacy Policy, KVKK Notice and Community Rules.

## 2. Account and eligibility

1. Registration is for Bingöl University students and staff only, with an e-mail address under `bingol.edu.tr` (including subdomains), and requires e-mail verification (code valid 10 minutes, limited attempts).
2. You are responsible for the accuracy of your details and the security of your password. Accounts cannot be transferred or shared.
3. The Service is not specifically aimed at persons under 18. A minor may use it only with the knowledge and consent of a legal representative; we may ask for additional verification.
4. **Single device (mobile):** only one mobile session stays active; signing in on another mobile device ends earlier mobile sessions and may send a "new device sign-in" e-mail. Web sessions are not affected.
5. Access tokens last 15 minutes; refresh tokens last at most 30 days and are single-use. All sessions end when the password is reset.

## 3. User content and licence

1. You own your content (messages, photos, videos, posts, events, feedback) and are responsible for it.
2. You grant us a limited, non-exclusive, non-transferable, royalty-free licence, for the duration of the Service, to host, store, encrypt, resize/re-encode, transmit and display your content solely to provide the Service. We do not use it for advertising and do not sell it.
3. Uploaded photos are validated and re-encoded; embedded metadata (EXIF) is removed. Chat photos are scaled to at most 1600 px; up to 10 attachments per message. Chat videos are compressed on your device (not re-encoded by the server); post (Discover) videos are re-encoded on the server after upload (H.264, at most 720p) and stored encrypted. Videos are accepted up to 60 seconds and 40 MB (story videos up to 30 seconds), with hourly/daily upload limits.
4. Uploaded images are compared by SHA-256 digest with a "prohibited content" list maintained by authorised administrators; a match rejects the upload. Image content is not otherwise analysed automatically.

**Posts, comments and stories.** You are responsible for the content of your posts, comments and stories, for mentions (@) and tags (#) of others, and for not infringing third parties' rights and data. They are shown to other signed-in users; stories are visible for 24 hours and then deleted. Content is not reviewed by humans before publication; as a hosting provider we remove unlawful content upon proper notice. Any post, comment or story can be reported with **Report**; authorised administrators review it and may hide or remove it, issue a warning or restrict the account. You may appeal (see section 5 and [Content Notice and Removal](/legal/content-removal)).

## 4. Prohibited conduct

Unlawful, threatening, harassing, hateful, obscene or violent content; impersonation; sharing others' personal data or private conversations without consent; spam and fraud; abusing the service (bots, scraping the user directory, exploiting vulnerabilities, evading IP/device bans); breaching academic integrity; misusing attendance (QR) check-in; infringing intellectual property. Insults, abuse, hate speech or sexually explicit expressions may not be used in public areas such as communities, events, profiles, group titles, posts, comments and stories; such content may be rejected automatically. Private chats and group messages are not pre-screened; however, harassment, threats or inappropriate content can be reported by users and, after review through the in-app report/feedback channel, content removal, a warning or an account restriction may be applied. See the Community Rules for examples.

## 5. Moderation, suspension and blocking

1. Anyone can report users, messages, posts, communities and events. Reports are limited per day; bad-faith reports may restrict reporting.
2. Reports are reviewed by authorised administrators, who may see the reported content and related chat context.
3. **Sanctions:** content removal/hiding; warning; violation record (3 resolved violations within 180 days trigger a suspension recommendation to an administrator); temporary suspension; permanent closure; and where needed access bans by IP, network range, device or user. Serious violations may skip steps and be reported to authorities.
4. **Device and IP bans:** for security and abuse prevention we record a non-reversible digest of your device identifier, platform, app version, IP address and time; a banned user's account, device or IP may block new accounts or sessions. Requests from anonymising networks (VPN, Tor, data centres) may be restricted. See the Privacy Policy.
5. **Appeal:** you can appeal through the in-app appeal feature or Support; an administrator re-reviews it and informs you. Urgent security measures may apply before the appeal.
6. **Blocking users:** messages sent to you by a user you blocked are not delivered to you (not shown in history, notifications or unread counts) and the blocked user is not told. The messages remain in the system and authorised administrators can see them during report reviews, even if the block is later lifted.

> **In short:** Rule-breaking content can be removed, accounts suspended or closed, device/IP bans applied. You can appeal in the app.

## 6. Messaging and administrator access

1. Messages are encrypted in transit (TLS/WSS) and stored encrypted (AES-256-GCM). The system is **not end-to-end encrypted**: keys are held server-side and authorised administrators can view messages when necessary. We do not promise that no one can read your messages.
2. Administrators may access messages only for report reviews, account security, suspected abuse or unlawful activity, and requests from competent authorities. Curiosity-driven viewing is prohibited and administrators are bound by confidentiality.
3. Every administrator view is automatically written to a tamper-resistant access log (administrator, viewed user, conversation, number of messages, IP, time) before content is shown. If logging fails, no content is shown.
4. "Delete for everyone" hides a message from users, but an encrypted copy, edit history and attachments may be retained for security and report review (default: indefinitely; configurable by the Operator). Deleted messages are excluded from the data export.
5. **View-once photos:** the recipient can open the photo once (recipient access ends after opening or 24 hours). For administrator review, the encrypted file is retained for 365 days (configurable), then deleted. Although screenshot protections may exist, **no absolute guarantee is given that screenshots or screen recordings cannot be taken**, and another device can photograph the screen.
6. By default push notifications do not contain message text.
7. When an account is deleted, its messages stay as part of others' chat history (author appears anonymously); photos uploaded by the account are deleted.

> **In short:** Messages are stored encrypted but not end-to-end; authorised administrators may view them only for stated reasons and every access is logged. Deleted messages and view-once photos may be retained encrypted for a period.

## 7. Communities and events

Community managers are responsible for their content and members and must follow these terms. Event organisers are responsible for the accuracy and lawfulness of events; attendance records are visible to organisers and authorised administrators. Chat rooms follow membership (removed/banned members are dropped) and event rooms close 7 days after the event by default. We are not responsible for events organised by others unless stated.

## 8. Intellectual property

The software, design, logo and brand belong to the Operator or its licensors. Do not copy or reverse engineer. Do not share others' copyrighted content; see [Content Notice and Removal](/legal/content-removal). The name and logo of Bingöl University belong to the University.

## 9. Source content

News, announcements, events and menus are compiled from Bingöl University's official websites (bingol.edu.tr, sks.bingol.edu.tr); rights belong to the University. Compilation is automatic (news daily, menu monthly); information may be temporarily incomplete and a maintenance notice may appear. **The official source page prevails.**

## 10. Service level and liability

1. The Service is provided "as is" and "as available". No express or implied warranty is given that it will be uninterrupted, error-free, fit for a particular purpose, or that its content (especially information compiled from source sites) is accurate, complete or current; maintenance and third-party outages may occur. This does not affect rights that cannot be waived by law.
2. To the extent permitted by law we are not liable for indirect damages, loss of profit, data or reputation, or damage from third-party content; our liability for direct damages is also limited, except for wilful misconduct and gross negligence, to the extent permitted by law and to proven loss. We are not a party to disputes between users or arising from events organised by others. This limitation does not apply to wilful misconduct, gross negligence or matters that cannot be limited by mandatory law.
3. As a hosting provider under Law No. 5651 we act on duly notified unlawful content.

## 11. Indemnity

You are liable, in proportion to your fault, for reasonable damages (including reasonable legal costs) arising from third-party claims caused by your breach of these terms or the law. Statutory limits remain unaffected.

## 12. Changes and re-acceptance

We may update these terms. For material changes the app asks you to re-accept the new version, and access to some parts may be limited until you do. Acceptance records are kept for evidence.

## 13. Termination

You can close your account at any time ([delete account](/delete-account)); deletion means anonymisation (see the Privacy Policy). We may suspend or close accounts that breach these terms. Provisions that by nature continue survive termination.

## 14. Governing law and jurisdiction

Turkish law applies. The Service is free of charge, so consumer-specific rules (Law No. 6502) apply only to the extent they are mandatory. **{{controller.jurisdiction|Bingöl}} courts and enforcement offices** are competent for disputes arising from these terms (administrative courts for administrative acts). Mandatory jurisdiction rules (including, if you are a consumer, the consumer court or arbitration committee of your place of residence) and your statutory rights remain reserved.

## 15. Relationship with Bingöl University; third-party links

1. {{controller.relation|The Service is not an official application of Bingöl University; it makes no statements on the University's behalf and does not replace official University notices. University news, announcements, events and menus are shown with the label "source: bingol.edu.tr" and a link to the source page. The bingol.edu.tr domain is used only to verify membership; this does not mean the University endorses, operates or accepts responsibility for the Service.}}
2. The Service may link to third-party sites. We do not control their content, privacy practices or security, are not responsible for them, and a link is not an endorsement. You open links at your own risk.

## 16. Changes to the Service, outages and force majeure

1. We may change, restrict, suspend or end the Service or its features with reasonable notice (without notice in urgent security or legal cases). If the Service ends we will try to announce it in advance and keep the data-download feature available for a period. No compensation can be claimed for changing or ending a free Service; wilful misconduct, gross negligence and mandatory law remain reserved.
2. The Service may be temporarily interrupted for maintenance or technical faults.
3. We are not liable for failure to perform caused by events beyond reasonable control (**force majeure**), such as natural disaster, war, terrorism, epidemic, power/internet/infrastructure or third-party provider outages, cyber-attack, or changes in legislation or administrative/judicial decisions.

## 17. Evidence agreement and notices

1. The parties accept that the Service's server records (acceptance records, session/IP and device-digest logs, moderation and access logs, e-mail and notification records) are **conclusive evidence** within the meaning of Article 193 of the Code of Civil Procedure No. 6100, without prejudice to mandatory law; your right to prove that a record is untrue remains.
2. Notices to you are sent to your registered institutional e-mail address and the in-app inbox and are deemed delivered when sent. Keeping your contact details current is your responsibility. Notices to us go through {{support.email|the in-app Support section}}{{?controller.kep}} or the KEP address {{controller.kep}}{{/controller.kep}}.

## 18. General provisions

1. **Severability.** If a provision is invalid, the others remain in force and the invalid one is read as the closest valid provision.
2. **No waiver.** Not exercising a right is not a waiver.
3. **Assignment.** We may assign the Service and our rights to a successor in a transfer, merger or restructuring in line with data-protection law; you may not assign your rights without our written consent.
4. **Entire agreement and language.** These terms and the texts they refer to are the entire agreement. The Turkish text prevails; other languages are informational translations.
5. **Headings** and "In short" boxes are for convenience only.

## 19. Contact

- General: {{support.email|in-app Support section}}
{{?controller.email}}- Controller e-mail: {{controller.email}}{{/controller.email}}
{{?controller.kep}}- KEP address: {{controller.kep}}{{/controller.kep}}$c_terms_en$, TRUE, TRUE),
    ('TERMS', 'ar', v, $t_terms_ar$شروط الاستخدام$t_terms_ar$, $c_terms_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

يشرح هذا النص كيفية استخدام تطبيق «BÜ Kampüs» وموقعه الإلكتروني («**الخدمة**»)، وحقوقكم والتزاماتكم وحقوقنا والتزاماتنا. يُرجى قراءته بعناية. يُطلب منكم قبول هذه الشروط عند التسجيل؛ ويُسجَّل قبولكم (مع إصدار الوثيقة وتاريخها).

## 1. الأطراف والنطاق

1. الجهة المشغِّلة للخدمة: {{controller.name}}{{?controller.address}}، {{controller.address}}{{/controller.address}} («**المشغِّل**» و«**نحن**»).
2. يُعدّ الشخص الذي يستخدم الخدمة («**المستخدم**» و«**أنتم**») قد قبل هذه الشروط.
3. تتكوّن الخدمة من الميزات الآتية: متابعة الأخبار والإعلانات والفعاليات، وقائمة الطعام، والملف الشخصي، والمراسلة، والمجتمعات والفعاليات (بما في ذلك تسجيل الحضور عبر QR)، والمنشورات والتعليقات والقصص لمدة 24 ساعة، ومتابعة المستخدمين، والاستطلاعات، والجدول الدراسي الشخصي ومتابعة الامتحانات، والإشعارات، والبحث، والمفضلات، والدعم وإرسال الملاحظات.
4. تُقرأ هذه الشروط مع النصوص الآتية: [سياسة الخصوصية](/legal/privacy)، و[نص الإفصاح بموجب قانون حماية البيانات الشخصية (KVKK)](/legal/kvkk)، و[قواعد المجتمع](/legal/community-rules)، و[نص الموافقة الصريحة](/legal/explicit-consent)، و[سياسة ملفات تعريف الارتباط والتخزين المحلي](/legal/cookies)، و[الإبلاغ عن المحتوى وإزالته](/legal/content-removal)، و[الاحتفاظ والإتلاف](/legal/retention). وتُعدّ قواعد المجتمع جزءًا لا يتجزأ من هذه الشروط.

> **باختصار:** لاستخدام الخدمة، تقبلون هذه الشروط وسياسة الخصوصية ونص الإفصاح بموجب KVKK وقواعد المجتمع. أما النصوص الأخرى فهي للإعلام أو للأذونات الاختيارية.

## 2. الحساب والأهلية

1. **من يمكنه التسجيل؟** التسجيل مخصص حصرًا لطلاب جامعة بينغول وموظفيها، ويتم فقط ببريد إلكتروني ينتهي بالنطاق `bingol.edu.tr` (بما في ذلك النطاقات الفرعية). لا يُفتح الحساب ما لم تُدخلوا رمز التحقق المرسل إلى بريدكم الإلكتروني. رمز التحقق صالح لمدة 10 دقائق، ولكم عدد محدود من المحاولات.
2. **صحة المعلومات.** أنتم المسؤولون عن صحة معلومات حسابكم وعن أمان كلمة مروركم. لا تشاركوا كلمة مروركم مع أحد. وإذا لاحظتم استخدام حسابكم دون إذن، فأبلغونا فورًا عبر قسم الدعم؛ ويمكنكم استخدام خيار «إنهاء جميع الجلسات».
3. **عدم قابلية الحساب للتنازل.** لا يجوز لكم التنازل عن حسابكم لشخص آخر أو بيعه أو مشاركته. ولا يجوز لأي شخص فتح أكثر من حساب بقصد إساءة الاستخدام.
4. **السن.** الخدمة موجهة لطلاب الجامعة وموظفيها؛ وليست موجهة تحديدًا للمستخدمين دون 18 عامًا. وإذا كان الطالب دون 18 عامًا يستخدمها، فالأصل أن يكون ذلك بعلم ممثله القانوني وإذنه؛ وفي هذه الحالة قد تلزم موافقة الممثل القانوني على معالجة البيانات الشخصية ذات الصلة. ويجوز لنا طلب تحقق إضافي في الحسابات التي ننتبه فيها إلى هذا الوضع.
5. **قاعدة الجهاز الواحد (الجوال).** حفاظًا على أمانكم، تبقى جلسة واحدة فقط مفتوحة في الوقت نفسه على تطبيق الجوال: عند تسجيل الدخول من جهاز جوال آخر، تُنهى جلساتكم السابقة على الجوال، وقد يُرسل إلى الجهاز السابق بريد إلكتروني تنبيهي بعنوان «تسجيل دخول من جهاز جديد». ولا تتأثر الجلسات على الويب بهذه القاعدة.
6. **مدة الجلسة.** مفتاح الوصول الخاص بكم قصير العمر (15 دقيقة) ويتجدد تلقائيًا؛ أما مفتاح التجديد فصالح 30 يومًا كحد أقصى ولا يُستخدم إلا مرة واحدة. وعند إعادة تعيين كلمة المرور تُغلق جميع جلساتكم.

> **باختصار:** تسجلون ببريد bingol.edu.tr فقط ومع التحقق منه. الحساب ملك لكم ولا يمكن التنازل عنه. على الجوال تبقى جلسة واحدة مفتوحة على جهاز واحد في الوقت نفسه.

## 3. محتوى المستخدم والترخيص

1. **أنتم أصحاب المحتوى.** حقوق المحتويات التي تشاركونها، مثل الرسائل والصور ومقاطع الفيديو ومنشورات المجتمع والفعاليات ومعلومات الملف الشخصي والملاحظات («**محتوى المستخدم**»)، تعود إليكم. وأنتم المسؤولون عن مشروعية محتوياتكم.
2. **الترخيص المحدود الذي تمنحوننا إياه.** لكي نتمكن من تقديم الخدمة، تمنحوننا ترخيصًا غير حصري، وغير قابل للتنازل، ومجانيًا، وعالميًا، ومحدودًا بمدة الخدمة، لاستضافة محتوى المستخدم الخاص بكم وحفظه وتشفيره وتغيير حجمه/إعادة ترميزه ونقله وعرضه وتقديمه (للأشخاص والمجتمعات الذين ترسلون إليهم المحتوى)، وذلك للأغراض الآتية فقط. لا نستخدم محتواكم لأغراض إعلانية ولا نبيعه لأطراف ثالثة.
3. **معالجة الوسائط.** تُعاد ترميز الصور المرفوعة بعد التحقق من نوعها وحجمها؛ وتُزال البيانات الوصفية المضمّنة مثل الموقع (EXIF). تُصغَّر صور المحادثات إلى 1600 بكسل كحد أقصى لطول الضلع؛ ويمكن إرسال 10 مرفقات كحد أقصى في الرسالة الواحدة (صور/فيديو مختلطة). تُضغط مقاطع فيديو المحادثات على جهازكم ولا يعيد الخادم ترميزها؛ أما مقاطع فيديو المنشورات (استكشف) فتُعاد ترميزها على الخادم بعد رفعها (H.264، بحد أقصى 720p) وتُحفظ مشفّرة. تُقبل مقاطع الفيديو بمدة أقصاها 60 ثانية وحجم يصل إلى 40 ميغابايت (ومقطع القصة 30 ثانية كحد أقصى)، وتوجد حدود يومية/ساعية للرفع. ويجوز أن تتغير هذه الحدود.
4. **فحص المحتوى المحظور.** يُقارَن الملخص الرقمي (SHA-256) للصور المرفوعة بقائمة ملخصات «المحتوى المحظور» التي يديرها المسؤولون المخوّلون. وعند التطابق يُرفض الرفع. هذا الفحص مقارنة ملخصات فقط؛ ولا يُحلَّل مضمون الصور تلقائيًا.
5. **المنشورات والتعليقات والقصص.** أنتم المسؤولون عن مضمون منشوراتكم وتعليقاتكم وقصصكم، وعن المشاركات المتعلقة بالأشخاص الذين تضعون لهم وسمًا (#) أو تذكرونهم (@)، وعن عدم انتهاك حقوق الغير وبياناتهم. تُعرض هذه المحتويات على المستخدمين الآخرين الذين سجلوا الدخول إلى التطبيق؛ وتبقى القصص ظاهرة 24 ساعة ثم تُحذف. لا تمر المحتويات بمراجعة بشرية قبل نشرها؛ ولذلك يزيل المشغِّل بصفته مزوّد استضافة المحتوى المخالف للقانون بناءً على إخطار. يمكن الإبلاغ عن أي منشور أو تعليق أو قصة عبر **إبلاغ**؛ ويراجعها المسؤولون المخوّلون، ويجوز لهم إخفاء المحتوى/إزالته وتوجيه تحذير أو فرض تقييد على الحساب. ولكم الاعتراض على القرار (انظر القسم 5 و[الإبلاغ عن المحتوى وإزالته](/legal/content-removal)).
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
10. استخدام الشتائم أو الإهانة أو خطاب الكراهية أو العبارات ذات المحتوى الجنسي في المساحات العامة مثل المجتمعات والفعاليات والملف الشخصي وعناوين المجموعات والمنشورات/التعليقات/القصص. وقد يُرفض هذا النوع من المحتوى تلقائيًا. لا يخضع المحتوى في المحادثات الخاصة ورسائل المجموعات لفحص مسبق؛ غير أنه يمكن للمستخدمين الإبلاغ عن المضايقة أو التهديد أو المحتوى غير اللائق، وتُراجَع عبر قناة الشكوى/الملاحظات داخل التطبيق، وقد يُطبَّق إزالة المحتوى أو التحذير أو تقييد الحساب.

## 5. الإشراف والتعليق والحظر

1. **الإبلاغ.** يمكن لكل مستخدم الإبلاغ عن المستخدمين والرسائل والمنشورات والمجتمعات والفعاليات عبر «إبلاغ». ولمنع إساءة الاستخدام، عدد البلاغات محدود؛ وقد تؤدي البلاغات الكيدية أو المتكررة التي لا أساس لها إلى تقييد حق الإبلاغ.
2. **المراجعة.** يراجع المسؤولون المخوّلون البلاغات. وأثناء المراجعة قد يُطَّلع على المحتوى المتعلق بالبلاغ وعلى سياق المحادثة المرتبط به (انظر القسم 6).
3. **درجات الجزاء.** بحسب الحالة: (أ) إزالة المحتوى أو إخفاؤه؛ (ب) تحذير/إشعار؛ (ج) تسجيل مخالفة (3 مخالفات تمت تسويتها للمستخدم نفسه ضمن نافذة 180 يومًا تُنتج توصية للمسؤول بالتعليق؛ والحد قابل للضبط)؛ (د) تعليق مؤقت؛ (هـ) إغلاق الحساب نهائيًا؛ (و) عند الحاجة، حظر وصول على أساس IP أو نطاق شبكة أو جهاز أو مستخدم. وفي المخالفات الجسيمة (مثل استغلال الأطفال والإرهاب والتهديد) يجوز تجاوز الدرجات وإبلاغ السلطات المختصة.
4. **حظر الوصول (الجهاز وIP).** بغرض الأمان ومنع إساءة الاستخدام، يُسجَّل عنوان IP الخاص بكم ومعرّف جهازكم (يُحفظ على شكل ملخص لا يمكن عكسه) عند تسجيل الدخول/التسجيل/الطلب؛ وقد يُحظر أي حساب/جلسة جديدة تطابق حساب مستخدم محظور أو جهازه أو عنوان IP الخاص به. وقد تُحظر أيضًا الطلبات الواردة من شبكات إخفاء الهوية (مثل VPN وTor ونطاقات مراكز البيانات) لأغراض أمنية. التفاصيل في سياسة الخصوصية.
5. **الإشعار والاعتراض.** في قرارات التعليق أو إزالة المحتوى، يُرسَل إليكم قدر الإمكان إشعار داخل التطبيق. وللاعتراض على القرار يمكنكم استخدام ميزة **الاعتراض** في التطبيق أو قسم الدعم؛ ويعيد أحد المسؤولين تقييم الاعتراضات ويُبلَّغ إليكم الناتج. وفي الحالات الطارئة التي تهدد أمان الحساب مباشرة، يجوز تطبيق التدبير قبل الاعتراض.
6. **حظر المستخدمين.** يمكنكم حظر أي مستخدم تشاؤون. الحظر لأجل الخصوصية: فالرسائل التي يرسلها إليكم من حظرتموه لا تُسلَّم إليكم (ولا تظهر في السجل أو الإشعار أو عدّاد غير المقروء)؛ ولا يُعرض على الشخص المحظور تنبيه يفيد بأنه محظور. وحتى لو أُلغي الحظر لاحقًا، فإن الرسائل المرسلة أثناء الحظر لا تُسلَّم إليكم. تبقى هذه الرسائل في النظام؛ ويمكن للمسؤولين المخوّلين الاطلاع عليها أثناء مراجعة الشكاوى. وفي المجموعات تُخفى رسائل من حظرتموه عنكم، بينما يراها الأعضاء الآخرون بشكل طبيعي.

> **باختصار:** قد يُزال المحتوى المخالف للقواعد، وقد يُعلَّق الحساب أو يُغلق؛ وقد يُطبَّق حظر الجهاز/IP. يمكنكم الاعتراض على القرار من داخل التطبيق.

## 6. المراسلة ووصول المسؤولين

يوضح هذا القسم صراحةً أن رسائلكم ليست «سرية تمامًا» بينكم وبين الطرف الآخر. يُرجى قراءته بعناية.

1. **نوع التشفير.** الرسائل مشفّرة أثناء النقل (TLS/WSS) وتُحفظ مشفّرة على الخادم (AES-256-GCM). النظام **غير مشفّر من طرف إلى طرف**: فمفاتيح فك التشفير محفوظة لدى الخادم؛ ويمكن للمسؤولين المخوّلين عرض الرسائل عند الاقتضاء. وليس لدينا أي التزام بأن لا يستطيع أحد قراءة رسائلكم.
2. **متى يصل المسؤولون؟** لا يصل إلى الرسائل إلا المسؤولون المخوّلون، وبمبررات مثل مراجعة الشكاوى والبلاغات، وأمان الحساب، والاشتباه في إساءة الاستخدام أو نشاط غير قانوني، وطلبات السلطات المختصة كالمحكمة/النيابة العامة/الضابطة العدلية، أو طلب المستخدم نفسه. يُحظر الاطلاع بدافع الفضول أو لغير الغرض؛ ويلتزم المسؤولون بتعهد السرية.
3. **التدقيق.** كل اطلاع من المسؤول على الرسائل يُكتب تلقائيًا، قبل عرض المحتوى، في سجل وصول غير قابل للتعديل (المسؤول، والمستخدم المعروض، والمحادثة، وعدد الرسائل، وعنوان IP، والوقت). وإذا تعذّر كتابة السجل فلا يُعرض المحتوى. وتُحفظ سجلات الوصول لأغراض التدقيق القانوني والأمني.
4. **الرسائل المحذوفة والمعدّلة.** عند اختياركم «حذف للجميع» تظهر الرسالة للمستخدمين الآخرين بعبارة «تم حذف هذه الرسالة»؛ غير أن النسخة المشفّرة من الرسالة وسجل تعديلها ومرفقاتها قد تستمر في الحفظ على الخادم لأغراض الأمان ومراجعة الشكاوى (الافتراضي: دون مدة محددة؛ وعندما يحدد المشغِّل مدة حفظ تُحذف نهائيًا عند انقضائها). كما تُحفظ الإصدارات السابقة من الرسائل التي عدّلتموها مشفّرة. ولا يمكنكم رؤية الرسالة المحذوفة مرة أخرى في واجهة المستخدم؛ ولا تُدرج الرسائل المحذوفة في مخرجات «تنزيل بياناتي».
5. **الصورة ذات الإرسال الواحد.** في هذه الميزة، لا يستطيع المستلم فتح الصورة إلا مرة واحدة؛ وبعد فتحها (أو بعد 24 ساعة من الإرسال) يُغلق وصول المستلم، ولا يستطيع المرسل إعادة فتح ما أرسله. ولكن لأغراض الأمان ومراجعة الشكاوى، ولكي يتمكن المسؤولون المخوّلون من الفحص، يُحفظ ملف الصورة **مشفّرًا على الخادم لمدة 365 يومًا** (مدة قابلة للضبط) ثم يُحذف. ورغم وضع عوائق تقنية أمام التقاط لقطات الشاشة على الجهاز، فإنه **لا يُضمن عدم التقاط لقطة شاشة أو تسجيل للشاشة**؛ إذ يمكن للمستلم تصوير الصورة بجهاز آخر. لذلك لا ترسلوا صورًا لا تريدون أن تقع في يد غيركم.
6. **معاينة الإشعار.** افتراضيًا لا يتضمن الإشعار الفوري نص الرسالة؛ بل يُرسَل إشعار عام من نوع «لديكم رسالة جديدة».
7. **المحادثات عند حذف الحساب.** عند حذفكم حسابكم لا تُحذف الرسائل التي أرسلتموها لأنها جزء من سجل محادثة الطرف الآخر؛ ويظهر اسم الكاتب مجهولًا. أما صور المحادثات التي رفعها الحساب فتُحذف.

> **باختصار:** الرسائل تُحفظ مشفّرة لكنها ليست مشفّرة من طرف إلى طرف. لا يمكن للمسؤولين المخوّلين الاطلاع عليها إلا في حالات مبررة، ويُسجَّل كل وصول. وقد تُحفظ النسخة المشفّرة من الرسائل المحذوفة ومن الصور ذات الإرسال الواحد لمدة لأغراض الأمان. لا يُعطى ضمان مطلق ضد لقطات الشاشة.

## 7. المجتمعات والفعاليات

1. **مسؤولو المجتمعات/الأندية** مسؤولون عن المحتوى والأعضاء في مجتمعاتهم؛ ويجب عليهم الالتزام بقواعد المجتمع وبهذه الشروط. يمكن تفويض صلاحيات الإدارة؛ وقد يطبّق النظام خطوات موافقة عند تفويض الصلاحيات.
2. **منشئو الفعاليات** مسؤولون عن صحة معلومات الفعالية وعن مشروعية الفعالية. يتم تسجيل حضور الفعالية برمز QR أو يدويًا؛ وتكون سجلات الحضور مرئية لمنظّم الفعالية وللمسؤولين المخوّلين.
3. **غرف المحادثة.** مشاركتكم في غرف المحادثة المنشأة للمجتمعات والفعاليات مرتبطة بعضويتكم؛ وعند إخراجكم من المجتمع أو حظركم تُسقَطون من الغرفة أيضًا. وتُغلق غرف محادثة الفعاليات افتراضيًا خلال 7 أيام بعد انتهاء الفعالية.
4. لا يتحمل المشغِّل مسؤولية الفعاليات التي تنظمها وحدات الجامعة أو المجتمعات ما لم يُنص على خلاف ذلك صراحةً؛ والسلامة الجسدية للفعاليات ومحتواها وإلغاؤها من مسؤولية المنظِّم.

## 8. الملكية الفكرية وحقوق المؤلف

1. برمجية التطبيق وتصميمه وشعاره وعلامته، وكذلك المحتويات الأصلية التي نقدمها، تعود إلى المشغِّل أو إلى مانحي ترخيصه. لا يجوز لكم نسخ البرمجية أو إجراء هندسة عكسية لها أو توزيعها دون إذن.
2. لا تشاركوا محتوى محميًا بحقوق المؤلف يعود لغيركم. وإذا رأيتم أن حق المؤلف الخاص بكم قد انتُهك فتقدموا بالإجراء المبيّن في نص [الإبلاغ عن المحتوى وإزالته](/legal/content-removal)؛ ففي الإخطارات المحقّة يُزال المحتوى، وفي الانتهاكات المتكررة قد يُغلق الحساب.3. اسم «جامعة بينغول» وشعارها يعودان إلى الجهة المعنية؛ واستخدامهما في الخدمة لا ينشئ أي حق خارج حق الاستخدام الذي تمنحه هذه الشروط.

## 9. المحتويات المصدرية (الأخبار والإعلانات والفعاليات وقائمة الطعام)

1. تُقدَّم معلومات الأخبار والإعلانات والفعاليات وقائمة الطعام بعد تجميعها من المواقع الإلكترونية الرسمية لجامعة بينغول (bingol.edu.tr وsks.bingol.edu.tr). وتعود حقوق هذه المحتويات إلى الجهة المعنية.
2. يتم التجميع تلقائيًا وعلى فترات منتظمة (الأخبار يوميًا وقائمة الطعام شهريًا)؛ وعند تغيّر الموقع المصدر أو تعذّر الوصول إليه قد تكون المعلومات ناقصة/قديمة مؤقتًا وقد يعرض التطبيق تنبيه «قيد الصيانة». **وللحصول على المعلومات الرسمية تكون الصفحة المصدرية هي المعتمدة؛** ولا تحلّ الخدمة محل الإعلان الرسمي.
3. إذا كان المحتوى المصدري غير لائق أو خاطئًا فقد يلزم إبلاغ صاحب المصدر؛ ولطلبات الإخفاء من التطبيق استخدموا قسم الدعم.

## 10. مستوى الخدمة وحدود المسؤولية

1. تُقدَّم الخدمة «كما هي» و«بحالتها المتاحة». ولا يُعطى أي ضمان صريح أو ضمني بأنها ستعمل دون انقطاع أو دون أخطاء أو على كل جهاز، أو بأنها ملائمة لغرض معين، أو بأن محتواها (ولا سيما المعلومات المجمّعة من المواقع المصدرية) صحيح وكامل ومحدَّث؛ وقد تحدث انقطاعات بسبب الصيانة والتحديث والقوة القاهرة وخدمات الأطراف الثالثة (البريد الإلكتروني، وبنية الإشعارات، والاستضافة). وقد يُطبَّق تحديث إلزامي أو وضع الصيانة. لا تمسّ هذه الفقرة حقوقكم التي لا يجوز إسقاطها قانونًا.
2. بما أن الخدمة مجانية، فإننا، بالقدر الذي يسمح به القانون، لا نتحمل المسؤولية عن الأضرار غير المباشرة، وفوات الربح، وفقدان البيانات، وفقدان السمعة، والأضرار الناشئة عن محتويات الأطراف الثالثة؛ ومسؤوليتنا عن الأضرار المباشرة أيضًا، باستثناء العمد والخطأ الجسيم، محدودة بالقدر الذي يسمح به القانون وبالضرر الذي يثبت في الواقعة المعنية. ولسنا طرفًا في النزاعات الناشئة عن علاقات المستخدمين ببعضهم ولقاءاتهم وما يحدث في الفعاليات وتصرفاتهم خارج الخدمة. ولا يسري هذا التحديد في حالات العمد والخطأ الجسيم والحالات التي لا يجوز تحديدها قانونًا (بما في ذلك القواعد القانونية الآمرة وحقوق الشخصية وأضرار الوفاة/الإصابة).
3. لا نضمن صحة محتويات المستخدمين؛ ومشاركات الأطراف الثالثة مسؤوليتهم. وبصفتنا مزوّد استضافة بموجب القانون رقم 5651 (القانون التركي المتعلق بتنظيم المنشورات على الإنترنت ومكافحة الجرائم المرتكبة عبرها)، نتخذ الإجراءات اللازمة بناءً على إخطار مستوفٍ للأصول عند علمنا بمحتوى مخالف للقانون.
4. **النسخ الاحتياطية للرسائل والوسائط.** ثمة خطر ألا يمكن استرداد الرسائل في حال فقدان مفتاح التشفير الرئيسي؛ لذا احتفظوا بنسخة احتياطية من وثائقكم المهمة بأنفسكم.

## 11. التعويض

تكونون مسؤولين، بقدر خطئكم، عن جبر الأضرار المعقولة (بما في ذلك أتعاب المحاماة المعقولة) الناشئة عن مطالبات الأطراف الثالثة الموجهة إلى المشغِّل بسبب إخلالكم بهذه الشروط أو بقواعد المجتمع أو بالقانون. ولا يزيل هذا الحكم حدود المسؤولية القانونية التي ينص عليها القانون.

## 12. التعديلات وإعادة الموافقة

1. يجوز لنا تحديث الشروط لأسباب قانونية أو تقنية. تتوفر النسخة الحالية وسجل الإصدارات في هذه الصفحة.
2. في التعديلات الجوهرية يطلب منكم التطبيق **إعادة الموافقة** على الإصدار الجديد؛ وإلى أن تعيدوا الموافقة قد يُقيَّد وصولكم إلى بعض أجزاء الخدمة.
3. يُحفظ إصدار الموافقة ووقتها لغرض الإثبات القانوني حتى بعد حذف الحساب (انظر الاحتفاظ والإتلاف).

## 13. الإنهاء وإغلاق الحساب

1. يمكنكم إغلاق حسابكم في أي وقت من التطبيق أو من [صفحة حذف الحساب](/delete-account). حذف الحساب **هو إخفاء للهوية (إلغاء ارتباط البيانات بصاحبها):** يُجهَّل اسمكم وبريدكم الإلكتروني ومعلومات ملفكم الشخصي، وتُحذف سجلات أجهزة الإشعارات؛ والتفصيل مبيّن في سياسة الخصوصية ونص الإفصاح بموجب KVKK.
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
2. تُرسَل الإخطارات والتبليغات الموجهة إليكم إلى بريدكم الإلكتروني المؤسسي المسجّل وإلى صندوق الإشعارات داخل التطبيق؛ وتُعدّ مبلَّغة لحظة الإرسال. ويقع على عاتقكم الإبقاء على بريدكم الإلكتروني ومعلومات التواصل الخاصة بكم محدَّثة. وتُرسَل الإخطارات الموجهة إلينا عبر {{support.email|قسم الدعم داخل التطبيق}}{{?controller.kep}} أو إلى عنوان KEP (البريد الإلكتروني المسجّل) {{controller.kep}}{{/controller.kep}}.

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
{{?controller.address}}- العنوان: {{controller.address}}{{/controller.address}}$c_terms_ar$, TRUE, TRUE);
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
| **Hesap:** e-posta (bingol.edu.tr), ad-soyad, şifre (yalnızca tek yönlü özet olarak), dil tercihi | Üyelik, kimlik doğrulama, hizmetin sunulması | Sözleşmenin ifası (KVKK m.5/2-c) | Hesap açık olduğu sürece; silinince anonimleştirilir |
| **Profil:** fakülte, bölüm, sınıf, biyografi, profil fotoğrafı, gizlilik ayarlarınız | Profilinizin diğer kullanıcılara gösterilmesi (alan bazında gizlenebilir) | Sözleşmenin ifası; isteğe bağlı alanlarda açık rıza (m.5/1) | Hesap açık olduğu sürece |
| **Bekleyen kayıt ve doğrulama kodu:** e-posta, kodun özeti | E-posta doğrulaması | Sözleşme öncesi işlem / sözleşmenin ifası | Bekleyen kayıt 1 saat; doğrulama kodu 10 dakika |
| **Oturum:** yenileme anahtarının özeti, oturum durumu | Güvenli oturum yönetimi | Meşru menfaat (m.5/2-f) | Yenileme anahtarı en çok 30 gün; çıkışta/şifre değişiminde silinir |
| **Mesajlar:** metin, fotoğraf, video, düzenleme geçmişi, tepkiler, okundu bilgisi, sohbet ayarları (sessiz/arşiv) | Mesajlaşma hizmeti | Sözleşmenin ifası | Hesap açık olduğu sürece; silinen mesajların şifreli kopyası ve düzenleme geçmişi güvenlik amacıyla saklanır (varsayılan süresiz, ayarlanabilir) |
| **Tek gönderimlik fotoğraf:** şifreli dosya, açılma kaydı | Mesajlaşma ve güvenlik incelemesi | Sözleşmenin ifası; meşru menfaat | Alıcı erişimi bir kez / en çok 24 saat; şifreli kopya yönetici incelemesi için **365 gün** (ayarlanabilir) |
| **Topluluk ve etkinlik verileri:** üyelikler, gönderiler, RSVP, yoklama (QR/elle), başvuru yanıtları, etkinlik geri bildirimi | Topluluk ve etkinlik hizmetleri | Sözleşmenin ifası | Hesap açık olduğu sürece; yoklama/gönderi kayıtları anonim biçimde kalabilir |
| **Gönderiler (Keşfet):** metin, fotoğraf, video, etiketler (#), anmalar (@), beğeniler, yorumlar | Gönderi paylaşımı ve etkileşim | Sözleşmenin ifası | Hesap açık olduğu sürece; gönderi silinince medya dosyası 30 gün sonra diskten silinir; gönderiye bağlanmamış yüklemeler 24 saat sonra silinir |
| **Hikâyeler:** fotoğraf/video, metin, görüntüleyenler | 24 saatlik geçici paylaşım | Sözleşmenin ifası | 24 saat görünür; bitişinden 24 saat sonra kalıcı silinir (ayarlanabilir) |
| **Takip ilişkileri ve kaydedilen gönderiler** | Akışınızı oluşturma, içerikleri sonra okumak üzere saklama | Sözleşmenin ifası | Hesap açık olduğu sürece; hesap silinince silinir |
| **Anketler:** katılım kaydı ve oyunuz | Oylama hizmeti | Sözleşmenin ifası | Hesap açık olduğu sürece; hesap silinince katılım kaydı silinir, oy kaydı kimliksizleşir. Gizli ankette oyunuzun hangi seçeneğe verildiği diğer kullanıcılara ve yöneticilere gösterilmez. Bitmiş anketlerin oy kayıtları için ayrı bir otomatik silme süresi uygulanmaz. |
| **Ders programı, ders ve sınav bilgileri:** kendi girdiğiniz dersler, oturumlar, dönem ve sınav kayıtları; duyuru okundu bilgisi | Kişisel ders programı ve sınav takibi | Sözleşmenin ifası | Hesap açık olduğu sürece; hesap silinince silinir |
| **Bildirim kutusu ve tercihler:** bildirim içerikleri, sessiz saatler, tür tercihleri | Bildirim hizmeti | Sözleşmenin ifası | Okunmuş bildirim 90 gün, okunmamış 365 gün sonra silinir |
| **Cihaz bildirim anahtarı (FCM):** anahtar, platform, uygulama sürümü, dil, son görülme | Anlık bildirim göndermek | Sözleşmenin ifası; açık rıza (bildirim izni) | 60 gün görülmeyen anahtar gece temizlenir; çıkışta/hesap silmede silinir |
| **Push bildirim kuyruğu:** hedef kullanıcı/cihaz, bildirim başlığı ve kısa metni, gönderim durumu | Anlık bildirimin kalıcı kuyruktan, yeniden denemeyle gönderilmesi | Sözleşmenin ifası | Bekleyen kayıt en çok 24 saat denenir; gönderilenler 7 gün, başarısız olanlar 30 gün sonra silinir; çıkışta/hesap silmede silinir |
| **Cihaz kimliği ve IP kayıtları:** cihaz tanımlayıcısının geri döndürülemez özeti (HMAC), platform, uygulama sürümü, IP adresi, son görülme ve olay türü (kayıt/giriş/istek) | Güvenlik, kötüye kullanım ve yasaklı kullanıcı engelinin dolanılmasını önleme | Meşru menfaat (m.5/2-f); hukuki yükümlülük (m.5/2-ç) | Varsayılan **90 gün**; engel kayıtları engel sürdükçe (bkz. 6) |
| **Kullanım olayları (analitik):** ekran adı, olay adı, sınırlı özellik değerleri, zaman; son görülme ve günlük aktiflik | Hizmeti iyileştirme, hata/performans takibi; raporlar toplulaştırılmıştır | Meşru menfaat (m.5/2-f) | Olaylar **180 gün** |
| **Destek, geri bildirim, itiraz, rapor:** metinleriniz ve iletişim e-postanız | Taleplerin yanıtlanması, moderasyon | Sözleşmenin ifası; meşru menfaat; hukuki yükümlülük | Hesap silinince metinler temizlenir, kayıt kimliksiz kalır; herkese açık (girişsiz) destek talepleri 365 gün |
| **Uygunsuz ifade filtresi kaydı:** hangi alanda, hangi kullanıcının içeriğinin reddedildiği/işaretlendiği ve zamanı (reddedilen metin kaydedilmez) | Herkese açık alanlarda kötüye kullanımın önlenmesi | Meşru menfaat (m.5/2-f) | 90 gün |
| **Engelleme ve moderasyon kayıtları:** engellediğiniz kişiler, ihlal kayıtları, rapor kararları, yasak izleri | Güvenlik ve moderasyon | Meşru menfaat; hukuki yükümlülük | Moderasyon izi hesap silindikten sonra da kimliksiz tutulur |
| **Yönetici erişim ve işlem kayıtları** (mesaj görüntüleme kaydı dahil) | Hesap verebilirlik, yetkisiz erişimin önlenmesi | Meşru menfaat; hukuki yükümlülük | Değiştirilemez biçimde tutulur; yasal/denetim saklama süresi boyunca |
| **Sözleşme onayları:** belge türü, sürüm, zaman | Rızanın/onayın ispatı | Hukuki yükümlülük; meşru menfaat | Hesap silindikten sonra da saklanır |
| **E-posta kuyruğu:** alıcı, konu, gönderim durumu | Doğrulama/şifre sıfırlama/güvenlik e-postaları | Sözleşmenin ifası | Gönderilmiş veya başarısız kayıtlar 30 gün sonra silinir |
| **Rehber eşleştirme:** rehberinizdeki e-postaların SHA-256 özeti (yalnızca istek sırasında) | Rehberinizde tanıdıklarınızı bulmak | **Açık rıza** (m.5/1) | **Saklanmaz, kaydedilmez**; yalnızca isteğin işlenmesi süresince bellekte |
| **Cihaz konumu** | — | — | Uygulama konum izni **istemez**; cihaz konumu (GPS/ağ) **toplanmaz, sunucuya gönderilmez ve saklanmaz** (bkz. 5) |

> **Özetle:** İşlediğimiz her veri bir amaca bağlıdır; çoğu hesabınız açık olduğu sürece tutulur. Cihaz/IP kayıtları 90 gün, analitik olaylar 180 gün, bildirimler 90/365 gün, hikâyeler görünürlük bitiminden sonra 24 saat, e-posta kuyruğu 30 gün saklanır.

## 3. Mesajlarınız nasıl saklanır ve kim görebilir?

1. **İletim:** Mesajlar TLS/WSS ile şifreli iletilir.
2. **Saklama:** Sunucuda her sohbet için ayrı bir anahtarla AES-256-GCM ile şifreli saklanır. Anahtarlar ayrı bir ana anahtar ile korunur ve veritabanında değil sunucu ortamında tutulur. Bu, veritabanı yedeği ele geçirilse bile mesajların okunmasını zorlaştırır.
3. **Uçtan uca şifreleme DEĞİLDİR.** Ana anahtar bizde olduğundan, sistem mesajları çözebilir. Bunu bilerek kullanın.
4. **Yönetici erişimi:** Yalnızca yetkili yöneticiler; şikâyet incelemesi, güvenlik/kötüye kullanım, yasal talepler ve benzeri gerekçelerle, mesajların ve medyanın içeriğini görüntüleyebilir. Yönetici arayüzü; silinmiş, düzenlenmiş ve moderasyonla gizlenmiş mesajlar ile "tek gönderimlik" fotoğrafları ve engellenen kullanıcıya iletilmeyen mesajları da gösterebilir. **Her görüntüleme**, içerik gösterilmeden önce otomatik olarak değiştirilemez bir kayda yazılır: kim baktı, kimin sohbetine baktı, kaç mesaj, hangi IP'den, ne zaman. Kayıt yazılamazsa içerik gösterilmez.
5. **Silinen mesajlar:** "Herkes için sil" diğer kullanıcılar için mesajı gizler; mesajın şifreli kopyası ve eski sürümleri güvenlik incelemesi için saklanabilir. Saklama süresi işletici tarafından ayarlanır (varsayılan: süresiz).
6. **Tek gönderimlik fotoğraflar:** Alıcı bir kez görür, sonra erişimi kapanır; ancak yönetici incelemesi için şifreli dosya 365 gün (ayarlanabilir) saklanır ve sonra silinir. Ekran görüntüsünün engellenmesi için teknik önlemler olsa da mutlak garanti verilmez.
7. **Bildirim önizlemesi:** Varsayılan olarak anlık bildirimde mesaj metni gösterilmez (ayar açılırsa metin Google FCM/Apple APNs üzerinden geçer). Uygulama içi bildirim kutusuna mesaj içeriği hiçbir zaman yazılmaz.
8. **Fotoğraf ve video işleme:** Fotoğraflar türü/boyutu doğrulanıp yeniden kodlanır, EXIF (konum vb.) temizlenir. **Sohbet videoları** cihazınızda sıkıştırılır; sunucu bunları yeniden kodlamaz, sohbete özgü anahtarla şifreli saklanır. **Gönderi (Keşfet) videoları** yüklendikten sonra sunucuda yeniden kodlanır (H.264 video, en çok 720p yükseklik, AAC ses; GPS gibi meta veriler atılır) ve diskte dosya başına rastgele üretilen bir anahtarla şifreli saklanır; bu anahtar da ana anahtarla sarılarak veritabanında tutulur. Yeniden kodlama bitene kadar yüklediğiniz özgün (şifreli) dosya oynatılabilir, bitince özgün dosya silinir. Görsellerin özeti, yasaklı içerik özet listesiyle karşılaştırılır; görsel içeriği otomatik analiz edilmez.
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
3. **Konum:** Uygulama cihazınızdan konum (GPS/ağ tabanlı) **izni istemez**; konumunuzu toplamaz, sunucuya göndermez ve saklamaz. Güvenlik amacıyla kaydedilen IP adresi (bkz. 6) cihaz konumu değildir; uygulama kodunda IP adresinden konum veya bölge çıkarımı yapılmaz. Barındırma ve ağ altyapısı sağlayıcıları kendi teknik kayıtlarını kendi politikalarına göre tutabilir; bu kayıtlar tarafımızca konum belirlemek için kullanılmaz. Gelecekte konum işlenecekse bu metin güncellenir ve yeniden açık rızanız alınır.
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
| **Silinir** | Bildirim cihaz anahtarlarınız ve bekleyen push kayıtlarınız, bildirim kutunuz ve tercihleriniz, kaydedilen gönderileriniz, takip ilişkileriniz, hikâyeleriniz, ders programı ve sınav kayıtlarınız, anket katılım kaydınız, beğeni ve yorumlarınız (başkasının gönderisindeki yorumlar "silindi" olarak görünür), Keşfet gönderileriniz (medya dosyaları 30 gün sonra diskten kalkar), favori haberleriniz, geri bildirim oylarınız, etkinlik geri bildirimleriniz, engelleme listeniz, kulüp başvuru yanıtlarınız, topluluk üyelikleriniz (sahiplik devri yapılmadan sahip satırı silinmez), yüklediğiniz sohbet fotoğrafları |
| **Anonimleştirilir** | Ad, e-posta, profil bilgileri, biyografi, fotoğraf; anket oy kayıtları (kullanıcı bağlantısı koparılır); destek, geri bildirim, itiraz, rapor ve etkinlik başvurusu metinleri temizlenir (kayıt kimliksiz kalır) |
| **Korunur (sınırlı)** | Gönderdiğiniz mesajlar ve topluluk gönderileri (başkalarının sohbet bağlamının parçası; yazar "Silinmiş kullanıcı" gibi anonim görünür); sözleşme onay kayıtları (hukuki kanıt); moderasyon ihlal/rapor ve yasak izleri; anonim yoklama/RSVP sayaçları; yönetici işlem ve erişim kayıtları |
| **Süreyle temizlenir** | Cihaz/IP kayıtları (90 gün), uygunsuz ifade filtresi kaydı (90 gün), analitik olaylar (180 gün), e-posta kuyruğu (30 gün) |

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

## 13. Gönderiler, hikâyeler, yorumlar ve içerik denetimi

1. **Kimler görür?** Gönderi, yorum, hikâye, etiket (#) ve anmalar (@) uygulamaya giriş yapmış diğer kullanıcılara gösterilir; engellediğiniz veya sizi engelleyen kullanıcılarla karşılıklı görünürlük kapanır. Uygulamada sunulan görünürlük seçenekleri ilgili ekranda gösterilir.
2. **Anma ve etiket.** Bir gönderide `@` ile andığınız kullanıcıya bildirim gidebilir; `#` etiketleri gönderilerin etikete göre listelenmesi için kullanılır.
3. **Hikâyeler** 24 saat görünür; kimin görüntülediği hikâye sahibi için kaydedilir; süre bitiminden 24 saat sonra kalıcı silinir.
4. **Uygunsuz ifade filtresi.** Topluluk, etkinlik, profil, gönderi, yorum ve hikâye gibi herkese açık alanlarda küfür, hakaret ve benzeri ifadeler otomatik olarak reddedilebilir. **Sohbet mesajları (birebir ve grup) ön denetimden geçirilmez.** Filtre yalnızca kayıt anında çalışır; hangi alanın, hangi kullanıcının içeriğinin reddedildiği 90 gün saklanır, reddedilen metin kaydedilmez. Reddedilen içerik yayımlanmaz; karar insan incelemesi olmadan otomatik verilir ve itirazınızı Destek bölümünden iletebilirsiniz.
5. **Şikâyet ve kaldırma.** Gönderi, yorum, hikâye ve mesajlar **Bildir** ile şikâyet edilebilir; yetkili yöneticiler inceler, içeriği gizleyebilir veya kaldırabilir. Usul için [İçerik Bildirimi ve Kaldırma](/legal/content-removal) ve [Topluluk Kuralları](/legal/community-rules) metinlerine bakın.

## 14. İletişim

{{support.email|Uygulama içi Destek bölümü}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}$c_privacy_tr$, TRUE, TRUE),
    ('PRIVACY', 'en', v, $t_privacy_en$Privacy Policy$t_privacy_en$, $c_privacy_en$*This English text is provided for information only. The Turkish text is authoritative.*

This policy explains which of your data is processed, why, for how long, and your rights. Read it together with the [KVKK Notice](/legal/kvkk).

Controller: {{controller.name}}{{?controller.address}}, {{controller.address}}{{/controller.address}}. Contact: {{controller.email|in-app Support section}}.

## 1. In short

1. We do **not sell** your data or share it for advertising.
2. We process only what is needed to provide the service, keep it secure and meet legal obligations.
3. Optional permissions (contacts, push notifications) rely on your **explicit consent** and can be withdrawn at any time ([Explicit Consent](/legal/explicit-consent)). The app does **not ask for, collect or store your device location**.
4. Messages are stored encrypted but the system is **not end-to-end encrypted**; authorised administrators may view them for stated reasons, with every access logged.
5. Deleting your account anonymises your data; some records remain in limited form for legal reasons and to protect others.

## 2. Data we process

| Data | Why | Legal basis | Retention |
|---|---|---|---|
| **Account:** e-mail (bingol.edu.tr), name, password (one-way hash only), language | Membership, authentication | Contract (KVKK 5/2-c) | While the account is open; anonymised on deletion |
| **Profile:** faculty, department, year, bio, avatar, privacy settings | Showing your profile (field-level visibility) | Contract; explicit consent for optional fields | While the account is open |
| **Pending registration / code:** e-mail, code digest | E-mail verification | Contract | Pending registration 1 hour; code 10 minutes |
| **Session:** refresh token digest | Secure sessions | Legitimate interest | At most 30 days; removed on logout/password change |
| **Messages:** text, photos, videos, edit history, reactions, read state, chat settings | Messaging | Contract | While the account is open; encrypted copies of deleted messages and edit history kept for security (default indefinite, configurable) |
| **View-once photo:** encrypted file, open record | Messaging; security review | Contract; legitimate interest | Recipient access once / max 24 h; encrypted copy for admin review **365 days** (configurable) |
| **Community and event data:** memberships, posts, RSVP, attendance, application answers | Community and event features | Contract | While the account is open; some records stay anonymous |
| **Posts (Discover):** text, photos, videos, hashtags (#), mentions (@), likes, comments | Posting and interaction | Contract | While the account is open; after a post is deleted its media files are removed from disk after 30 days; uploads not attached to a post are deleted after 24 hours |
| **Stories:** photo/video, text, viewers | 24-hour temporary sharing | Contract | Visible for 24 hours; permanently deleted 24 hours after expiry (configurable) |
| **Follows and saved posts** | Building your feed, saving items for later | Contract | While the account is open; deleted with the account |
| **Polls:** participation record and your vote | Voting | Contract | While the account is open; on account deletion the participation record is deleted and the vote is detached from you. In a secret poll, which option you chose is not shown to other users or administrators. No separate automatic deletion period applies to the vote records of finished polls. |
| **Timetable, course and exam data:** courses, sessions, semester and exams you enter yourself; announcement read marks | Personal timetable and exam tracking | Contract | While the account is open; deleted with the account |
| **Notification inbox and preferences** | Notifications | Contract | Read 90 days, unread 365 days |
| **Device push token (FCM):** token, platform, app version, language, last seen | Push notifications | Contract; explicit consent (notification permission) | Removed after 60 days unseen; on logout/deletion |
| **Push notification queue:** target user/device, title and short text, delivery status | Delivering push notifications from a durable queue with retries | Contract | Pending entries are retried for at most 24 hours; sent entries are deleted after 7 days, failed ones after 30 days; deleted on logout/account deletion |
| **Inappropriate-language filter log:** which field, which user's content was rejected/flagged, and when (the rejected text is not stored) | Preventing abuse in public areas | Legitimate interest | 90 days |
| **Device and IP records:** non-reversible HMAC digest of device identifier, platform, app version, IP, last seen and event type | Security, abuse prevention, ban evasion | Legitimate interest; legal obligation | Default **90 days**; ban records while a ban lasts |
| **Usage events (analytics):** screen, event name, limited values, time | Improving the service; reports are aggregated | Legitimate interest | **180 days** |
| **Support, feedback, appeals, reports** | Handling requests, moderation | Contract; legitimate interest; legal obligation | Texts scrubbed on account deletion; public (logged-out) tickets 365 days |
| **Blocks and moderation records** | Safety and moderation | Legitimate interest; legal obligation | Moderation trail kept anonymously |
| **Administrator action and message-access logs** | Accountability | Legitimate interest; legal obligation | Tamper-resistant; for legal/audit period |
| **Agreement acceptances:** document, version, time | Proof of acceptance | Legal obligation; legitimate interest | Kept after account deletion |
| **E-mail queue:** recipient, subject, status | Verification, reset and security e-mails | Contract | Sent/failed entries deleted after 30 days |
| **Contact matching:** SHA-256 digests of e-mails in your address book | Finding people you know | **Explicit consent** | **Not stored or logged**; in memory only while the request is processed |
| **Device location** | — | — | The app does **not ask for location permission**; device location (GPS/network) is **not collected, sent or stored** (see 5) |

> **In short:** Device/IP records 90 days, analytics 180 days, notifications 90/365 days, e-mail queue 30 days.

## 3. How messages are stored and who can see them

1. Transit: TLS/WSS. Storage: AES-256-GCM with a separate key per conversation, protected by a master key held in the server environment, not in the database.
2. **Not end-to-end encrypted.** Because we hold the master key, the system can decrypt messages.
3. Authorised administrators may view messages and media for report reviews, security/abuse, and legal requests. The admin view can also show deleted, edited and moderation-hidden messages, view-once photos and messages not delivered because of a block. **Every view is automatically written to a tamper-resistant record before content is shown** (who, whose chat, how many messages, IP, time); if logging fails, content is not shown.
4. "Delete for everyone" hides the message from users; the encrypted copy and previous versions may be retained for security (default indefinite).
5. View-once photos: recipient sees once; the encrypted file is kept 365 days (configurable) for administrator review, then deleted. No absolute guarantee against screenshots.
6. Push previews: by default message text is not shown in push notifications; the in-app inbox never stores message content.
7. Photos are validated and re-encoded, EXIF removed; chat videos are compressed on your device and are not re-encoded by the server (they are stored encrypted with a per-conversation key). Post (Discover) videos are re-encoded on the server after upload (H.264, at most 720p, AAC audio, metadata such as GPS removed) and stored on disk encrypted with a random per-file key that is itself wrapped by the master key; until re-encoding finishes the encrypted original stays playable and is then deleted. Image digests are matched against a prohibited-content digest list; images are not analysed automatically.
8. Blocking: messages from someone you blocked are not delivered to you and the blocked person is not notified; they remain stored and visible to authorised administrators during report reviews.

## 4. Who we share data with

| Recipient | What | Purpose | Location |
|---|---|---|---|
| **Google Firebase Cloud Messaging** (and Apple APNs for iOS) | Device push token, notification title/short text, target | Push delivery | Outside Türkiye |
| **E-mail (SMTP) provider** | Recipient address, e-mail content | Verification, reset, security e-mails | {{hosting.location|Provider's country}} |
| **Hosting provider** | All service data (messages encrypted) | Hosting | {{hosting.location|Stated before publication}} |
| **Competent public authorities** | Data within the request | Legal obligation | Türkiye |
| **University / authorised administrators** | Data needed for moderation and support | Service administration | Türkiye |

We do not share data with ad networks, data brokers or social-media trackers.

## 5. Permissions

1. **Notifications:** optional; notification types and **quiet hours** are configurable. Without permission, the in-app inbox still works.
2. **Contact matching:** only SHA-256 digests of e-mails (up to 500 per request) are sent; they are **not stored or logged**; names and phone numbers are never sent.
3. **Location:** the app does **not ask for location permission** and does not collect, send or store your location. The IP address recorded for security (see 6) is not device location, and the application code does not infer location or region from IP addresses. Hosting and network infrastructure providers may keep their own technical logs under their own policies; we do not use them to determine location. If location is ever processed we will update this text and ask for consent again.

## 6. Device/IP records and access bans

Device-identifier digest, platform, app version, IP and time are recorded on registration, login, refresh and requests for security. The raw identifier is not stored. Records are kept **90 days** by default (configurable); if a legal retention duty arises (e.g. Law No. 5651 traffic data) the period may change and this policy will be updated. Access bans (IP, network range, device digest or user) keep reason code, date, optional expiry and notes while the ban lasts; blocked attempts are logged as security records. Requests from anonymising networks may be restricted. You may contest a ban via Support or the appeal feature.

## 7. Account deletion and data export

**Download my data:** Profile > Download my data (JSON, up to 3 per day; deleted messages excluded).

**Account deletion = anonymisation**

| What happens | Data |
|---|---|
| **Deleted** | Push tokens and pending push entries, notification inbox and preferences, saved posts, follows, stories, timetable and exam data, poll participation record, likes and comments (comments on others' posts show as deleted), Discover posts (media files removed after 30 days), bookmarks, feedback votes and event feedback, block list, club application answers, community memberships, chat photos you uploaded |
| **Anonymised** | Name, e-mail, profile, bio, photo; poll vote records (link to you removed); support, feedback, appeal, report and event application texts are scrubbed |
| **Kept (limited)** | Messages and community posts (others' context; author appears anonymous), agreement acceptances, moderation records, anonymous attendance/RSVP counters, administrator action and access logs |
| **Cleaned by time** | Device/IP records (90 days), language-filter log (90 days), analytics (180 days), e-mail queue (30 days) |

## 8. Security

One-way password hashes; digests of codes and refresh tokens; 15-minute access tokens; single-use refresh tokens; rate limits; generic responses that do not reveal whether an account exists; encrypted message storage; logged administrator access; validated uploads. No system is perfectly secure; in a breach we notify the Board and affected persons as required.

## 9. Cookies and local storage

No tracking or advertising cookies. See the [Cookie Policy](/legal/cookies).

## 10. Children

The service is not designed for persons under 18; if such a registration is found we may require a legal representative's consent or close the account.

## 11. Posts, stories, comments and content moderation

1. Posts, comments, stories, hashtags (#) and mentions (@) are shown to other signed-in users; visibility is mutually closed with users you block or who block you. Any visibility options offered in the app are shown on the relevant screen.
2. Mentioning a user with `@` may send them a notification.
3. Stories are visible for 24 hours; the story owner can see who viewed it; they are permanently deleted 24 hours after expiry.
4. **Language filter.** Insults, abuse, hate speech or sexually explicit expressions in public areas (communities, events, profiles, group titles, posts, comments, stories) may be rejected automatically. **Chat messages (one-to-one and group) are not pre-screened.** The filter acts at submission time; which field and which user's content was rejected is kept for 90 days, the rejected text is not stored. The decision is automatic without human review; you may contest it through Support.
5. **Reports and removal.** Posts, comments, stories and messages can be reported with **Report**; authorised administrators review and may hide or remove content. See [Content Notice and Removal](/legal/content-removal) and the [Community Rules](/legal/community-rules).

## 12. Your rights, changes, contact

Your KVKK Article 11 rights and the application route (30-day response) are in the [KVKK Notice](/legal/kvkk). We may update this policy; for material changes we ask for re-acceptance. Contact: {{support.email|in-app Support section}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}$c_privacy_en$, TRUE, TRUE),
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
| **الحساب:** البريد الإلكتروني (bingol.edu.tr)، الاسم واللقب، كلمة المرور (كملخّص أحادي الاتجاه فقط)، تفضيل اللغة | العضوية، والتحقق من الهوية، وتقديم الخدمة | تنفيذ العقد (KVKK م.5/2-ج) | ما دام الحساب مفتوحًا؛ وتُجهَّل هويتها عند الحذف |
| **الملف الشخصي:** الكلية، القسم، الصف، النبذة التعريفية، صورة الملف الشخصي، إعدادات الخصوصية الخاصة بك | عرض ملفك الشخصي للمستخدمين الآخرين (يمكن إخفاؤه حسب الحقل) | تنفيذ العقد؛ وفي الحقول الاختيارية الموافقة الصريحة (م.5/1) | طوال مدة بقاء الحساب مفتوحًا |
| **الحساب الجاري تسجيله ورمز التحقق:** البريد الإلكتروني، ملخّص الرمز | التحقق من البريد الإلكتروني | إجراء سابق للعقد / تنفيذ العقد | التسجيل المعلّق ساعة واحدة؛ ورمز التحقق 10 دقائق |
| **الجلسة:** ملخّص مفتاح التجديد، حالة الجلسة | إدارة آمنة للجلسات | المصلحة المشروعة (م.5/2-و) | مفتاح التجديد 30 يومًا كحد أقصى؛ ويُحذف عند تسجيل الخروج / تغيير كلمة المرور |
| **الرسائل:** النص، الصور، الفيديو، سجل التعديل، التفاعلات، معلومة القراءة، إعدادات المحادثة (كتم/أرشفة) | خدمة المراسلة | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وتُحفَظ النسخة المشفّرة للرسائل المحذوفة وسجل التعديل لأغراض أمنية (الافتراضي غير محدد المدة، وقابل للضبط) |
| **الصورة ذات الإرسال الواحد:** الملف المشفّر، سجل الفتح | المراسلة والمراجعة الأمنية | تنفيذ العقد؛ المصلحة المشروعة | وصول المستلم مرة واحدة / 24 ساعة كحد أقصى؛ والنسخة المشفّرة لمراجعة المسؤول **365 يومًا** (قابلة للضبط) |
| **بيانات المجتمعات والفعاليات:** العضويات، المنشورات، تأكيد الحضور (RSVP)، تسجيل الحضور (QR/يدويًا)، ردود طلبات الانضمام، تقييمات الفعاليات | خدمات المجتمعات والفعاليات | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وقد تبقى سجلات الحضور/المنشورات مجهولة الهوية |
| **المنشورات (اكتشف):** النص، الصور، الفيديو، الوسوم (#)، الإشارات (@)، الإعجابات، التعليقات | نشر المحتوى والتفاعل | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وعند حذف المنشور يُحذف ملف الوسائط من القرص بعد 30 يومًا؛ وتُحذف الملفات المرفوعة غير المرتبطة بمنشور بعد 24 ساعة |
| **القصص:** الصور/الفيديو، النص، المشاهِدون | مشاركة مؤقتة لمدة 24 ساعة | تنفيذ العقد | تظهر 24 ساعة؛ وتُحذف نهائيًا بعد 24 ساعة من انتهاء ظهورها (قابلة للضبط) |
| **علاقات المتابعة والمنشورات المحفوظة** | تكوين خلاصتك، وحفظ المحتوى لقراءته لاحقًا | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وتُحذف عند حذف الحساب |
| **الاستطلاعات:** سجل المشاركة وصوتك | خدمة التصويت | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وعند حذف الحساب يُحذف سجل المشاركة ويصبح سجل الصوت مجهول الهوية. في الاستطلاع السري لا يُعرَض للمستخدمين الآخرين ولا للمسؤولين الخيار الذي صوّتَّ له. لا تُطبَّق مدة حذف تلقائي منفصلة على سجلات أصوات الاستطلاعات المنتهية. |
| **الجدول الدراسي ومعلومات المقررات والامتحانات:** المقررات والحصص وسجلات الفصل والامتحانات التي أدخلتها بنفسك؛ معلومة قراءة الإعلانات | متابعة الجدول الدراسي والامتحانات الشخصية | تنفيذ العقد | ما دام الحساب مفتوحًا؛ وتُحذف عند حذف الحساب |
| **صندوق الإشعارات والتفضيلات:** محتوى الإشعارات، ساعات الصمت، تفضيلات الأنواع | خدمة الإشعارات | تنفيذ العقد | تُحذف الإشعارات المقروءة بعد 90 يومًا وغير المقروءة بعد 365 يومًا |
| **مفتاح إشعارات الجهاز (FCM):** المفتاح، المنصة، إصدار التطبيق، اللغة، آخر ظهور | إرسال الإشعارات الفورية | تنفيذ العقد؛ الموافقة الصريحة (إذن الإشعارات) | المفتاح الذي لم يُرَ منذ 60 يومًا يُنظَّف ليلًا؛ ويُحذف عند تسجيل الخروج/حذف الحساب |
| **طابور الإشعارات الفورية (push):** المستخدم/الجهاز المستهدف، عنوان الإشعار ونصه القصير، حالة الإرسال | إرسال الإشعار الفوري من طابور دائم مع إعادة المحاولة | تنفيذ العقد | يُحاوَل السجل المعلّق 24 ساعة كحد أقصى؛ وتُحذف المرسَلة بعد 7 أيام والفاشلة بعد 30 يومًا؛ وتُحذف عند تسجيل الخروج/حذف الحساب |
| **معرّف الجهاز وسجلات IP:** ملخّص غير قابل للعكس لمعرّف الجهاز (HMAC)، المنصة، إصدار التطبيق، عنوان IP، آخر ظهور ونوع الحدث (تسجيل/دخول/طلب) | الأمن، ومنع إساءة الاستخدام، ومنع الالتفاف على حظر المستخدمين المحظورين | المصلحة المشروعة (م.5/2-و)؛ الالتزام القانوني (م.5/2-ç) | الافتراضي **90 يومًا**؛ وسجلات الحظر ما دام الحظر قائمًا (انظر 6) |
| **أحداث الاستخدام (التحليلات):** اسم الشاشة، اسم الحدث، قيم خصائص محدودة، الوقت؛ آخر ظهور والنشاط اليومي | تحسين الخدمة، ومتابعة الأخطاء والأداء؛ والتقارير مجمَّعة | المصلحة المشروعة (م.5/2-و) | الأحداث **180 يومًا** |
| **الدعم والملاحظات والاعتراض والبلاغ:** نصوصك وبريدك الإلكتروني للتواصل | الرد على الطلبات، والإشراف | تنفيذ العقد؛ المصلحة المشروعة؛ الالتزام القانوني | عند حذف الحساب تُمحى النصوص ويبقى السجل مجهول الهوية؛ وطلبات الدعم العامة (دون تسجيل دخول) 365 يومًا |
| **سجل مرشّح الألفاظ غير اللائقة:** في أي حقل، ومحتوى أي مستخدم رُفض/وُسم، ووقت ذلك (لا يُحفَظ النص المرفوض) | منع إساءة الاستخدام في المساحات العامة | المصلحة المشروعة (م.5/2-و) | 90 يومًا |
| **سجلات الحظر والإشراف:** الأشخاص الذين حظرتهم، سجلات المخالفات، قرارات البلاغات، آثار الحظر | الأمن والإشراف | المصلحة المشروعة؛ الالتزام القانوني | يُحتفَظ بأثر الإشراف مجهول الهوية حتى بعد حذف الحساب |
| **سجلات وصول المسؤولين وإجراءاتهم** (بما فيها سجل الاطلاع على الرسائل) | المساءلة، ومنع الوصول غير المصرّح به | المصلحة المشروعة؛ الالتزام القانوني | تُحفَظ بصورة غير قابلة للتعديل؛ طوال مدة الحفظ القانونية/الرقابية |
| **الموافقات على العقود والنصوص:** نوع الوثيقة، الإصدار، الوقت | إثبات الموافقة/القبول | الالتزام القانوني؛ المصلحة المشروعة | تُحفَظ حتى بعد حذف الحساب |
| **طابور البريد الإلكتروني:** المستلم، الموضوع، حالة الإرسال | رسائل التحقق/إعادة تعيين كلمة المرور/الأمن | تنفيذ العقد | تُحذف السجلات المرسَلة أو الفاشلة بعد 30 يومًا |
| **مطابقة دفتر العناوين:** ملخّص SHA-256 للبريد الإلكتروني الموجودة في دفتر عناوينك (أثناء الطلب فقط) | العثور على معارفك في دفتر عناوينك | **الموافقة الصريحة** (م.5/1) | **لا يُخزَّن ولا يُسجَّل**؛ يبقى في الذاكرة طوال معالجة الطلب فقط |
| **موقع الجهاز** | — | — | لا يطلب التطبيق إذن الموقع؛ وموقع الجهاز (GPS/الشبكة) **لا يُجمع ولا يُرسَل إلى الخادم ولا يُخزَّن** (انظر 5) |

> **باختصار:** كل بيانات نعالجها مرتبطة بغرض؛ ومعظمها يُحتفَظ به ما دام حسابك مفتوحًا. تُحفَظ سجلات الجهاز/IP 90 يومًا، وأحداث التحليلات 180 يومًا، والإشعارات 90/365 يومًا، والقصص 24 ساعة بعد انتهاء ظهورها، وطابور البريد الإلكتروني 30 يومًا.

## 3. كيف تُخزَّن رسائلك ومن يمكنه الاطلاع عليها؟

1. **النقل:** تُنقَل الرسائل مشفّرة عبر TLS/WSS.
2. **التخزين:** تُخزَّن على الخادم مشفّرة بـ AES-256-GCM بمفتاح مستقل لكل محادثة. وتُحمى المفاتيح بمفتاح رئيسي منفصل، ويُحتفَظ بها في بيئة الخادم لا في قاعدة البيانات. وهذا يصعّب قراءة الرسائل حتى لو وقعت نسخة احتياطية من قاعدة البيانات في يد الغير.
3. **النظام ليس مشفّرًا من طرف إلى طرف.** وبما أن المفتاح الرئيسي لدينا، فإن النظام قادر على فك تشفير الرسائل. فاستخدمه وأنت على علم بذلك.
4. **وصول المسؤولين:** لا يمكن إلا للمسؤولين المخوَّلين الاطلاع على محتوى الرسائل والوسائط، وذلك لأسباب مثل مراجعة الشكاوى، والأمن/إساءة الاستخدام، والطلبات القانونية وما شابهها. وقد تعرض واجهة المسؤول أيضًا الرسائل المحذوفة والمعدَّلة والمخفية بالإشراف، والصور «ذات الإرسال الواحد»، والرسائل التي لا تُسلَّم إلى المستخدم المحظور. و**كل اطلاع** يُكتب تلقائيًا في سجل غير قابل للتعديل قبل عرض المحتوى: من اطلع، ومحادثة من اطلع عليها، وكم رسالة، ومن أي IP، ومتى. وإذا تعذّر كتابة السجل فلا يُعرَض المحتوى.
5. **الرسائل المحذوفة:** «الحذف للجميع» يخفي الرسالة عن المستخدمين الآخرين؛ وقد تُحفَظ النسخة المشفّرة للرسالة وإصداراتها السابقة لأغراض المراجعة الأمنية. وتُحدَّد مدة الحفظ من قِبل المشغّل (الافتراضي: غير محددة المدة).
6. **الصور ذات الإرسال الواحد:** يراها المستلم مرة واحدة ثم يُغلَق وصوله؛ غير أن الملف المشفّر يُحفَظ 365 يومًا (قابلة للضبط) لمراجعة المسؤول ثم يُحذف. ورغم وجود تدابير تقنية لمنع لقطات الشاشة، فلا تُعطى ضمانة مطلقة.
7. **معاينة الإشعار:** افتراضيًا لا يظهر نص الرسالة في الإشعار الفوري (وإذا فُعِّل الإعداد فإن النص يمر عبر Google FCM/Apple APNs). ولا يُكتب محتوى الرسالة في صندوق الإشعارات داخل التطبيق إطلاقًا.
8. **معالجة الصور والفيديو:** يُتحقَّق من نوع الصور وحجمها وتُعاد ترميزها، وتُزال بيانات EXIF (الموقع وغيره). أما **فيديوهات المحادثة** فتُضغط على جهازك؛ ولا يعيد الخادم ترميزها، وتُخزَّن مشفّرة بمفتاح خاص بالمحادثة. وأما **فيديوهات المنشورات (اكتشف)** فيعيد الخادم ترميزها بعد الرفع (فيديو H.264، بارتفاع 720p كحد أقصى، وصوت AAC؛ وتُهمَل البيانات الوصفية مثل GPS) وتُخزَّن على القرص مشفّرة بمفتاح يُولَّد عشوائيًا لكل ملف؛ ويُغلَّف هذا المفتاح أيضًا بالمفتاح الرئيسي ويُحفَظ في قاعدة البيانات. وإلى أن تنتهي إعادة الترميز يمكن تشغيل الملف الأصلي (المشفّر) الذي رفعته، وعند انتهائها يُحذف الملف الأصلي. ويُقارَن ملخّص الصور بقائمة ملخّصات المحتوى المحظور؛ ولا يُحلَّل المحتوى المرئي للصور آليًا.
9. **الحظر:** لا تُسلَّم إليك الرسائل التي يكتبها لك من حظرتَه؛ ولا يُرسَل إشعار إلى الشخص المحظور. وتبقى هذه الرسائل في النظام ولا يراها إلا المسؤولون المخوَّلون لأسباب مثل مراجعة الشكاوى.

> **باختصار:** تُخزَّن الرسائل مشفّرة لكن ليس من طرف إلى طرف. ولا يمكن للمسؤولين المخوَّلين الاطلاع عليها إلا في حالات مسبَّبة، مع التسجيل في كل مرة. وقد تُحفَظ لفترة النسخة المشفّرة للرسائل المحذوفة والصور ذات الإرسال الواحد لأغراض الأمن.

## 4. مع من نشارك بياناتك؟

| المستلم | ما الذي يُشارَك؟ | الغرض | الموقع |
|---|---|---|---|
| **Google Firebase Cloud Messaging (FCM)** (وApple APNs لنظام iOS) | مفتاح إشعارات الجهاز، عنوان الإشعار/نصه القصير، معلومات الهدف | إيصال الإشعارات الفورية | خارج البلاد (بنية Google/Apple التحتية)؛ انظر نص الإفصاح وفق KVKK |
| **بنية البريد الإلكتروني (SMTP)** | عنوان البريد الإلكتروني للمستلم، محتوى البريد (رمز التحقق وغيره) | رسائل التحقق وإعادة تعيين كلمة المرور والأمن | {{hosting.location|البلد الذي يوجد فيه مزوّد الاستضافة والبريد الإلكتروني}} |
| **مزوّد الاستضافة / الخوادم** | جميع بيانات الخدمة (بما فيها الرسائل المشفّرة) | استضافة الخدمة | {{hosting.location|يُعلَن موقع الاستضافة قبل النشر}} |
| **الجهات العامة المختصة** (المحكمة، النيابة العامة، الضابطة العدلية، مجلس KVKK وغيرها) | البيانات الواقعة ضمن نطاق الطلب | الالتزام القانوني | داخل البلاد |
| **إدارة الجامعة / المسؤولون المخوَّلون** | البيانات اللازمة للإشراف والدعم | إدارة الخدمة والأمن | داخل البلاد |

لا نشارك البيانات مع شبكات الإعلانات أو سماسرة البيانات أو أدوات التتبع في وسائل التواصل الاجتماعي.

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

**تنزيل بياناتي:** يمكنك من الملف الشخصي > تنزيل بياناتي تنزيل بياناتك بصيغة JSON (بحد 3 مرات في اليوم). ولا تدخل الرسائل المحذوفة في المخرجات.

**حذف الحساب = تجهيل الهوية.** عند حذف حسابك:

| ماذا يحدث؟ | أي البيانات |
|---|---|
| **تُحذف** | مفاتيح إشعارات أجهزتك وسجلات push المعلّقة، وصندوق إشعاراتك وتفضيلاتك، ومنشوراتك المحفوظة، وعلاقات المتابعة، وقصصك، وسجلات الجدول الدراسي والامتحانات، وسجل مشاركتك في الاستطلاعات، وإعجاباتك وتعليقاتك (تظهر التعليقات في منشورات الآخرين بوصفها «محذوفة»)، ومنشورات اكتشف الخاصة بك (تُزال ملفات الوسائط من القرص بعد 30 يومًا)، وأخبارك المفضلة، وأصوات الملاحظات التي أدليت بها، وتقييمات الفعاليات، وقائمة الحظر، وردود طلبات الانضمام إلى النوادي، وعضوياتك في المجتمعات (لا يُحذف سطر المالك دون نقل الملكية)، وصور المحادثة التي رفعتها |
| **تُجهَّل هويتها** | الاسم، والبريد الإلكتروني، ومعلومات الملف الشخصي، والسيرة الذاتية المختصرة، والصورة؛ وسجلات أصوات الاستطلاعات (يُقطَع الارتباط بالمستخدم)؛ وتُمحى نصوص الدعم والملاحظات والاعتراض والبلاغ وطلبات الانضمام إلى الفعاليات (يبقى السجل مجهول الهوية) |
| **يُحتفَظ بها (بشكل محدود)** | الرسائل التي أرسلتَها ومنشورات المجتمعات (جزء من سياق محادثة الآخرين؛ يظهر الكاتب بشكل مجهول مثل «مستخدم محذوف»)؛ وسجلات الموافقة على العقود (دليل قانوني)؛ وآثار مخالفات الإشراف/البلاغات والحظر؛ وعدّادات الحضور/RSVP المجهولة؛ وسجلات إجراءات المسؤولين ووصولهم |
| **تُنظَّف بمرور المدة** | سجلات الجهاز/IP (90 يومًا)، وسجل مرشّح الألفاظ غير اللائقة (90 يومًا)، وأحداث التحليلات (180 يومًا)، وطابور البريد الإلكتروني (30 يومًا) |

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

لم تُصمَّم الخدمة لمن هم دون 18 عامًا؛ ولا يتم التسجيل إلا ببريد إلكتروني لطالب/موظف في الجامعة. وإذا اكتُشف تسجيل مستخدم دون 18 عامًا فقد يُطلَب علم الممثل القانوني وموافقته؛ وعند الاقتضاء يُغلَق الحساب وتُحذف البيانات/تُجهَّل هويتها.

## 11. حقوقك

وفقًا للمادة 11 من KVKK لديك حقوق الوصول إلى بياناتك وتصحيحها وحذفها والاعتراض وغيرها من الحقوق. وسبل التقدّم بالطلبات ومهلة الرد البالغة 30 يومًا واردة في [نص الإفصاح وفق KVKK](/legal/kvkk) ونص [الحفظ والإتلاف](/legal/retention). الطرق السريعة: تعديل معلومات الملف الشخصي، إعدادات الخصوصية، تنزيل بياناتي، حذف الحساب، قسم الدعم.

## 12. التغييرات

يجوز لنا تحديث هذه السياسة. وفي حال التغييرات المهمة نطلب منك الموافقة من جديد؛ ويتوفر الإصدار الحالي والسجل السابق في هذه الصفحة.

## 13. المنشورات والقصص والتعليقات والإشراف على المحتوى

1. **من يراها؟** تُعرَض المنشورات والتعليقات والقصص والوسوم (#) والإشارات (@) للمستخدمين الآخرين الذين سجّلوا الدخول إلى التطبيق؛ ويُغلَق الظهور المتبادل مع المستخدمين الذين حظرتَهم أو حظروك. تُعرض خيارات الظهور المتاحة في التطبيق على الشاشة المعنية.
2. **الإشارة والوسم.** قد يُرسَل إشعار إلى المستخدم الذي تشير إليه بـ `@` في منشور؛ وتُستخدَم وسوم `#` لسرد المنشورات بحسب الوسم.
3. **القصص** تظهر 24 ساعة؛ ويُسجَّل من شاهدها لصاحب القصة؛ وتُحذف نهائيًا بعد 24 ساعة من انتهاء المدة.
4. **مرشّح الألفاظ غير اللائقة.** في المساحات العامة مثل المجتمعات والفعاليات والملف الشخصي والمنشورات والتعليقات والقصص قد تُرفَض آليًا الشتائم والإهانات وما شابهها من العبارات. و**رسائل المحادثة (الفردية والجماعية) لا تخضع لفحص مسبق.** ويعمل المرشّح لحظة الحفظ فقط؛ ويُحفَظ 90 يومًا أي حقل ومحتوى أي مستخدم رُفض، ولا يُحفَظ النص المرفوض. ولا يُنشَر المحتوى المرفوض؛ ويصدر القرار آليًا دون مراجعة بشرية، ويمكنك تقديم اعتراضك من قسم الدعم.
5. **الشكوى والإزالة.** يمكن الإبلاغ عن المنشورات والتعليقات والقصص والرسائل عبر **إبلاغ**؛ ويراجعها المسؤولون المخوَّلون ويمكنهم إخفاء المحتوى أو إزالته. وللإجراءات انظر نصَّي [الإبلاغ عن المحتوى وإزالته](/legal/content-removal) و[قواعد المجتمع](/legal/community-rules).

## 14. التواصل

{{support.email|قسم الدعم داخل التطبيق}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}$c_privacy_ar$, TRUE, TRUE);
END
$do_privacy$;

-- KVKK: mevcut aktif surume Arapca ekle (yoksa)
INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active)
SELECT 'KVKK', 'ar', d.version, $t_kvkk_ar$نص الإفصاح بموجب KVKK$t_kvkk_ar$, $c_kvkk_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

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
| الهوية | الاسم واللقب |
| الاتصال | عنوان البريد الإلكتروني المؤسسي (bingol.edu.tr)، وبريد التواصل في طلبات الدعم |
| المعلومات التعليمية/المهنية | الكلية، القسم، الصف الدراسي، صفة الطالب/الموظف |
| المرئية | صورة الملف الشخصي؛ صور ومقاطع فيديو المحادثات/المنشورات/القصص (يُعاد ترميز مقاطع فيديو المنشورات على الخادم وتُخزَّن مشفّرة) |
| محتوى المستخدم | الرسائل، منشورات المجتمعات والاستكشاف (Keşfet)، التعليقات، القصص التي تدوم 24 ساعة، الوسوم (#) والإشارات (@)، أصوات الاستطلاعات، ردود طلبات المشاركة في الفعاليات، الملاحظات والاقتراحات، ونصوص الدعم والاعتراض، والنبذة التعريفية |
| معاملات العميل / الاستخدام | عضويات المجتمعات، المشاركة في الفعاليات وتسجيل الحضور، المفضلات، علاقات المتابعة، المنشورات المحفوظة، تفضيلات الإشعارات والخصوصية، قائمة الحظر |
| الخطة الشخصية | جدول الدروس والمقررات والفصول الدراسية وسجلات الامتحانات التي يدخلها المستخدم بنفسه |
| أمن المعاملات | معلومات الجلسة، الملخص المجزّأ لكلمة المرور، الملخص غير القابل للعكس لمعرّف الجهاز، عنوان IP، المنصة وإصدار التطبيق، سجلات حظر الوصول، الأخطاء ومحاولات تسجيل الدخول |
| الإجراءات القانونية / الامتثال | سجلات الموافقة على الاتفاقيات، سجلات الشكاوى/البلاغات والإشراف، سجلات وصول المديرين |
| التسويق | لا يُعالَج (لا تجري أي معالجة لأغراض الإعلان/التسويق) |
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
9. تقديم خدمات المنشورات والتعليقات والقصص والمتابعة والحفظ والوسم والاستطلاعات والجدول الدراسي الشخصي.
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
| بنية إرسال البريد الإلكتروني (معالج البيانات) | البريد الإلكتروني للمستلم، محتوى الرسالة | رسائل التحقق/إعادة تعيين كلمة المرور/الأمن | {{hosting.location|بلد مقر المزوّد}} |
| Google LLC (Firebase Cloud Messaging) وApple Inc. (APNs) لنظام iOS | مفتاح إشعارات الجهاز، عنوان الإشعار/نصه القصير، معلومة الوجهة، المنصة | إيصال الإشعارات الفورية | **خارج البلاد** |
| الجهات والمؤسسات العامة المختصة (المحكمة، النيابة، الضابطة العدلية، هيئة حماية البيانات الشخصية وغيرها) | البيانات ضمن نطاق الطلب | الالتزام القانوني | داخل البلاد |
| الوحدات المعنية في جامعة بينغول / المديرون المخوَّلون | البيانات اللازمة للإشراف والدعم والأمن | إدارة الخدمة | داخل البلاد |

**النقل إلى الخارج (م.9).** لأجل الإشعارات الفورية، يُنقل مفتاح إشعارات جهازكم ومحتوى الإشعار إلى الخارج عبر Firebase/APNs. ويستند هذا النقل، في إطار المادة 9 من القانون وأنظمة هيئة حماية البيانات الشخصية ذات الصلة، إلى **موافقتكم الصريحة المبنية على إذن الإشعارات** و/أو إلى آليات الكفاية/الضمانات المناسبة (العقد النموذجي وغيره). وإن لم تمنحوا إذن الإشعارات فلن تتلقوا إشعارات فورية، لكن صندوق الإشعارات داخل التطبيق وسائر الخدمات تواصل العمل. ويمكنكم سحب موافقتكم في أي وقت من إعدادات الجهاز أو من إعدادات الأذونات/الإشعارات في التطبيق.

## 6. طريقة جمع البيانات الشخصية

تُجمع بياناتكم عبر التطبيق والموقع الإلكتروني في البيئة الإلكترونية، بطرق آلية وشبه آلية، من خلال نماذج التسجيل/الملف الشخصي، والمراسلة ومشاركة المحتوى، ونماذج الدعم، والاتصال التقني لجهازكم (IP، ملخص الجهاز، إصدار التطبيق)، والتخزين المحلي الشبيه بملفات تعريف الارتباط، و(إذا منحتم الإذن) طلب مطابقة جهات الاتصال. أما محتويات الأخبار وقائمة الطعام فتُجمع من مصادر عامة لا تتضمن بيانات شخصية.

## 7. مدة الحفظ

تُحفظ البيانات الشخصية للمدة اللازمة لغرض المعالجة وللمدة المنصوص عليها في التشريعات ذات الصلة، وعند انتهاء المدة تُحذف أو تُتلف أو تُجعل مجهولة الهوية. أبرز المدد: التسجيل المعلّق ساعة واحدة؛ رمز التحقق 10 دقائق؛ مفتاح التجديد 30 يوماً على الأكثر؛ الإشعار المقروء 90 يوماً وغير المقروء 365 يوماً؛ مفتاح إشعارات الجهاز إذا لم يُشاهَد 60 يوماً؛ سجلات أمن الجهاز/IP 90 يوماً؛ سجل مرشّح الألفاظ غير اللائقة 90 يوماً؛ القصص بعد 24 ساعة من انتهاء ظهورها؛ سجل طابور push بعد 7 أيام من الإرسال (30 يوماً إن فشل)؛ أحداث التحليلات 180 يوماً؛ طابور البريد الإلكتروني 30 يوماً؛ النسخة المشفّرة من الصورة ذات الإرسال الواحد 365 يوماً؛ طلب الدعم العام 365 يوماً. وما دام الحساب مفتوحاً يُحفظ ملفكم الشخصي ومحتوياتكم؛ وقد تُحفظ بشكل مستقل لأغراض الأمن/الإثبات النسخة المشفّرة من الرسائل المحذوفة وسجلات الموافقة على الاتفاقيات. الجدول التفصيلي: [الحفظ والإتلاف](/legal/retention).

## 8. وصول المديرين إلى الرسائل (ملاحظة شفافية)

تُخزَّن الرسائل مشفّرة على الخادم، لكن النظام ليس مشفّراً من طرف إلى طرف. يجوز للمديرين المخوَّلين عرض الرسائل والوسائط لأسباب مثل مراجعة الشكاوى والأمن وإساءة الاستخدام والطلبات القانونية، ويُسجَّل كل عرض تلقائياً وبشكل غير قابل للتعديل. والسبب القانوني لهذا النشاط هو المصلحة المشروعة والالتزام القانوني (م.5/2-(f)، (ç)، (e))؛ والتفصيل في البند 3 من [سياسة الخصوصية](/legal/privacy).

## 9. اتخاذ القرارات الآلية

لا تتخذ الخدمة بحقكم قراراً يرتب نتيجة قانونية بالمعالجة الآلية وحدها. فإذا تراكمت سجلات انتهاك متعددة على الحساب نفسه، فإن النظام يولّد لمدير **توصية** فقط؛ أما قرار التعليق فيتخذه مدير. وتوجد تدابير آلية مثل تحديد المعدل، والتحقق من ملخص المحتوى المحظور، ومرشّح الألفاظ غير اللائقة في المساحات العامة؛ ويجوز للمرشّح أن يرفض محتوى تلقائياً (رسائل المحادثات غير خاضعة لهذه الرقابة)، ويمكنكم تقديم اعتراضكم من قسم الدعم. أما القرارات التي ترتب نتائج دائمة على حسابكم فيتخذها مدير.

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
{{?controller.email}}4. **البريد الإلكتروني:** إلى العنوان {{controller.email}} من عنوان بريدكم المؤسسي المسجّل.{{/controller.email}}

يجب أن يتضمن طلبكم: الاسم واللقب، ومعلومة تفيد في التحقق من الهوية (بريد الحساب الإلكتروني)، وعنوان التبليغ، وموضوع الطلب. وقد نطلب معلومات إضافية للتحقق من هويتكم. وتُنجَز الطلبات مجاناً **في موعد أقصاه 30 يوماً** بحسب طبيعة الطلب؛ وإن استلزمت العملية كلفة إضافية فقد تُتقاضى الرسوم وفق التعرفة التي تحددها الهيئة.

وفي حال رفض الطلب، أو عدم كفاية الرد، أو عدم الرد في المدة المحددة، يحق لكم **تقديم شكوى إلى هيئة حماية البيانات الشخصية** خلال 30 يوماً من تاريخ علمكم بالرد، وعلى أي حال خلال 60 يوماً من تاريخ التقدم بالطلب.$c_kvkk_ar$, d.require_reaccept, TRUE
FROM legal_document d
WHERE d.type = 'KVKK' AND d.lang = 'tr' AND d.active
  AND NOT EXISTS (SELECT 1 FROM legal_document x WHERE x.type = 'KVKK' AND x.lang = 'ar' AND (x.version = d.version OR x.active));

-- COMMUNITY_RULES: mevcut aktif surume Arapca ekle (yoksa)
INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active)
SELECT 'COMMUNITY_RULES', 'ar', d.version, $t_community_rules_ar$قواعد المجتمع$t_community_rules_ar$, $c_community_rules_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

BÜ Kampüs بيئة آمنة ومحترمة لطلاب جامعة بينغول وموظفيها. وهذه القواعد ملزمة بالاقتران مع [شروط الاستخدام](/legal/terms). والغاية من القواعد ليست المعاقبة، بل تمكين الجميع من الاستخدام براحة.

## 1. المبدأ الأساسي

لا تكتب لأحد ما لا تقوله له وجهاً لوجه؛ وأنت المسؤول عن كل محتوى تشاركه.

## 2. السلوكيات المحظورة وأمثلتها

| القاعدة | المحظورات (أمثلة) | ما لا مشكلة فيه |
|---|---|---|
| **التحرش والتهديد والتنمر** | الرسائل الملحّة غير المرغوبة، التهديد، الابتزاز، الإهانة، التوجيه الجماعي ضد شخص بعينه | التعبير عن الخلاف في الرأي بلطف |
| **الكراهية والتمييز** | الإهانة على أساس الأصل العرقي أو الدين أو المذهب أو الجنس أو الإعاقة أو التوجه أو المنطقة أو الكلية | نقاش محترم |
| **الفحش والعنف** | المحتوى الجنسي، العري، مشاهد العنف، التشجيع على إيذاء النفس | المعلومات التعليمية/الصحية |
| **الرسائل المزعجة والاحتيال** | الرسائل الجماعية المتكررة، الإعلانات دون إذن، "انقر واربح"، التبرعات/الإعلانات المزيفة، رسائل السلسلة | إعلان فعاليات مجتمعك |
| **انتحال الهوية** | التصرف كأنك شخص آخر أو عضو هيئة تدريس أو نادٍ أو مؤسسة؛ الحساب المزيف | استخدم اسمك الحقيقي بدل اسم مستعار؛ وبيّن المزاح/المحاكاة الساخرة في وصف الملف الشخصي |
| **مشاركة البيانات الشخصية** | مشاركة هاتف شخص آخر أو عنوانه أو هويته أو صورته أو مراسلاته الخاصة أو لقطة شاشة منها دون إذن؛ "doxxing" | مشاركة معلوماتك الخاصة عن قصد |
| **نزاهة المقررات والامتحانات** | بيع أو مشاركة أسئلة الامتحانات/مفاتيح الإجابة، تنظيم الغش، بيع الواجبات، تسجيل الحضور باسم شخص آخر | مشاركة ملاحظات المقررات من جهدك الخاص، وتكوين مجموعة دراسة |
| **إدارة الفعاليات والنوادي** | معلومات مضللة عن الفعالية، مشاركة وهمية، جمع رسوم/بيانات من الأعضاء دون إذن، إساءة استخدام الصلاحية، إقصاء الأعضاء تعسفاً | تنظيم الفعالية مع إعلان القواعد بوضوح |
| **المحتوى المخالف للقانون** | التحريض على الجريمة، المخدرات، تجارة الأسلحة، الدعاية الإرهابية، استغلال الأطفال (انتهاك جسيم: تعليق مباشر وإبلاغ الجهات المختصة) | — |
| **إساءة الاستخدام التقنية** | الروبوتات (Bot)، المسح الجماعي، جمع دليل جهات الاتصال/المستخدمين، استغلال الثغرات الأمنية، التحايل على الحظر/المنع (حساب جديد، VPN) | إبلاغ الدعم بالأخطاء |
| **انتهاك حقوق النشر** | مشاركة عمل شخص آخر دون إذن | اقتباس قصير مع ذكر المصدر |

**مرشّح التعبير في المساحات العامة.** في المساحات العامة مثل المجتمع والفعالية والملف الشخصي وعنوان المجموعة والمنشور والتعليق والقصة، لا يجوز استخدام الشتائم أو الإهانات أو خطاب الكراهية أو العبارات ذات المحتوى الجنسي؛ ويجوز رفض هذا المحتوى تلقائياً. أما في المحادثات الخاصة ورسائل المجموعات فلا يخضع المحتوى لفحص مسبق؛ غير أنه يمكن للمستخدمين الإبلاغ عن التحرش أو التهديد أو المحتوى غير اللائق، وبعد مراجعته عبر قناة الشكاوى/الملاحظات داخل التطبيق يجوز تطبيق إزالة المحتوى أو التحذير أو تقييد الحساب.

**المنشورات والتعليقات والقصص.** أنت المسؤول عن المنشورات والتعليقات والقصص التي تشاركها (وعما فيها من وسوم/إشارات). لا تمر المحتويات بمراجعة بشرية قبل نشرها؛ وما خالف القواعد أعلاه يجوز إخفاؤه أو إزالته بناءً على شكوى. لا تشارك صورة شخص آخر أو بياناته الشخصية أو مراسلاته الخاصة دون إذنه.

## 3. قواعد إضافية لمديري الفعاليات والنوادي

1. يجب أن تكون معلومات الفعالية (المكان، التاريخ، الرسوم، السعة) صحيحة؛ وأن تُعلن التغييرات والإلغاءات في وقتها.
2. استخدم معلومات المشاركين لغرض الفعالية فقط؛ ولا تشارك سجلات الحضور.
3. استخدم رموز QR لتسجيل الحضور في مكان الفعالية وخلال مدتها فقط.
4. عند تفويض صلاحياتك الإدارية أبلغ المدير الجديد؛ وطبّق قواعد المجتمع في غرف محادثة الأعضاء.

## 4. المراسلة والخصوصية

1. تُخزَّن رسائلك مشفّرة لكنها ليست مشفّرة من طرف إلى طرف؛ ويجوز للمديرين المخوَّلين عرضها عند مراجعة الشكاوى (ويُسجَّل كل وصول).
2. لا يوجد ضمان مطلق ضد التقاط لقطة شاشة للصورة ذات الإرسال الواحد؛ لا تشارك الصور الحساسة.
3. يمكنك **حظر** من لا ترغب به؛ ولا تصلك رسائل الشخص المحظور.

## 5. كيف يتم الإبلاغ؟

1. استخدم خيار **إبلاغ** على المستخدم أو الرسالة أو المنشور أو التعليق أو القصة أو المجتمع أو الفعالية، واختر السبب، وأضف ملاحظة قصيرة إن شئت.
2. في الحالات العاجلة/الجسيمة (التهديد، الاستغلال) راسلنا أيضاً من قسم الدعم، وتوجّه إلى الجهات الأمنية عند الحاجة.
3. لبلاغات المحتوى المخالف للقانون أو حقوق النشر اتبع إجراء [الإبلاغ عن المحتوى وإزالته](/legal/content-removal).
4. قد تقيّد البلاغات الكيدية أو سيئة النية صلاحيتك في الإبلاغ. وعدد البلاغات اليومية محدود.

## 6. درجات الجزاء

| الدرجة | ماذا يحدث؟ |
|---|---|
| 1. إجراء على المحتوى | يُزال المحتوى أو يُخفى؛ وقد يُرسل إليك إشعار داخل التطبيق |
| 2. تحذير وسجل انتهاك | يُسجَّل الانتهاك على حسابك. عند 3 انتهاكات تمت معالجتها خلال 180 يوماً تصل المدير **توصية** بالتعليق |
| 3. التعليق المؤقت | يتعذر استخدام حسابك لمدة محددة |
| 4. الإغلاق الدائم | يُغلق الحساب نهائياً |
| 5. حظر الوصول | عند الحاجة يُطبَّق حظر على مستوى IP أو نطاق الشبكة أو الجهاز أو المستخدم؛ ولا يمكن التحايل على الحظر بفتح حساب جديد |

في الانتهاكات الجسيمة (مثل استغلال الأطفال والتهديد الخطير والإرهاب) يجوز تجاوز الدرجات وإبلاغ الجهات المختصة. وتصدر القرارات عن مدير مع مراعاة سياق الواقعة.

## 7. الاعتراض

1. إذا رأيت أن قراراً ما خاطئ، فتقدّم من خلال ميزة **الاعتراض** في التطبيق أو من قسم الدعم، مبيناً الواقعة ومسوّغاتك (بحد أقصى 5 اعتراضات يومياً).
2. يعيد مدير تقييم اعتراضك؛ وتُبلَّغ بالنتيجة. وتُلغى الإجراءات التي تبيّن خطؤها (يُعاد نشر المحتوى، ويُرفع التعليق، ويُسحب سجل الانتهاك).
3. ورغم نتيجة الاعتراض تبقى محفوظة حقوقك الناشئة عن التشريعات (بما فيها اللجوء إلى القضاء).

> **باختصار:** كن محترماً، ولا تشارك محتوى مخالفاً للقانون أو ضاراً، ولا تشارك بيانات الآخرين دون إذن. أبلغ عن الانتهاك الذي تراه؛ ويمكنك الاعتراض على أي قرار يُتخذ بحقك.$c_community_rules_ar$, d.require_reaccept, TRUE
FROM legal_document d
WHERE d.type = 'COMMUNITY_RULES' AND d.lang = 'tr' AND d.active
  AND NOT EXISTS (SELECT 1 FROM legal_document x WHERE x.type = 'COMMUNITY_RULES' AND x.lang = 'ar' AND (x.version = d.version OR x.active));

-- EXPLICIT_CONSENT: mevcut aktif surume Arapca ekle (yoksa)
INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active)
SELECT 'EXPLICIT_CONSENT', 'ar', d.version, $t_explicit_consent_ar$نص الموافقة الصريحة$t_explicit_consent_ar$, $c_explicit_consent_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

يتعلق هذا النص بالميزات **الاختيارية** فقط. لا يُشترط أي إذن من الأذونات الواردة أدناه لفتح حساب أو لاستخدام الميزات الأساسية للتطبيق. أنتم تمنحون كل إذن **على حدة** وبإرادتكم الحرة؛ وعدم منحه لا يرتب عليكم أي جزاء ولا يمنعكم من الاستفادة من الخدمة. ويمكنكم سحب أي إذن منحتموه في أي وقت.

المسؤول عن البيانات: {{controller.name}}. يُعدّ هذا النص "موافقة تتعلق بموضوع محدد، ومبنية على العلم، ومعلنة بإرادة حرة" وفق المادتين 3 و5/1 من القانون رقم 6698 (قانون حماية البيانات الشخصية)؛ وللاطلاع على المعلومات التفصيلية ينبغي قراءة [إشعار الإفصاح بموجب قانون حماية البيانات الشخصية (KVKK)](/legal/kvkk) و[سياسة الخصوصية](/legal/privacy).

## المادة 1. مطابقة جهات الاتصال

| | |
|---|---|
| **ماذا يحدث؟** | يُؤخذ **ملخص SHA-256** لعناوين البريد الإلكتروني للأشخاص في دفتر جهات الاتصال بجهازكم، ويُرسل إلى الخادم لمعرفة ما إذا كان معارفكم موجودين في التطبيق. |
| **أي بيانات؟** | ملخصات البريد الإلكتروني فقط (500 ملخص كحد أقصى في الطلب الواحد). **لا تُرسل** الأسماء ولا أرقام الهواتف ولا عناوين البريد الإلكتروني نفسها. |
| **الاحتفاظ** | **لا يحتفظ** الخادم بالملخصات **ولا يسجلها**؛ بل يستخدمها في الذاكرة فقط أثناء معالجة الطلب. يُعرض عليكم المستخدمون المطابقون (بالحقول التي تتوافق مع إعدادات الخصوصية). |
| **الغاية** | العثور على الأشخاص الذين تعرفونهم في دفتر جهات الاتصال وتسهيل التواصل معهم. |
| **النقل** | لا تُنقل إلى أطراف ثالثة ولا إلى الخارج. |
| **مهم** | ملخصات عناوين البريد الإلكتروني لجهات الاتصال في دفتركم هي بيانات أصحابها؛ لذا استخدموها فقط بغرض العثور على معارفكم. ولمنع إساءة الاستخدام يوجد حد أقصى للطلبات في الساعة. |
| **السحب** | أوقفوا إذن جهات الاتصال من إعدادات الجهاز، أو أوقفوا خيار الأذونات > جهات الاتصال في التطبيق. بعد لحظة السحب لا تُرسل ملخصات دفتر جهات الاتصال. |

**الموافقة:** أمنح موافقتي الصريحة على معالجة ملخصات SHA-256 لعناوين البريد الإلكتروني في دفتر جهات الاتصال لدي للغاية المذكورة أعلاه. (تُمنح عبر مربع موافقة مستقل / إذن النظام.)

## المادة 2. الموقع (لا يُعالَج حاليًا)

| | |
|---|---|
| **الوضع الحالي** | **لا يطلب** التطبيق **إذن الموقع** من جهازكم؛ ولا تُجمع معلومات موقعكم ولا تُرسل إلى الخادم ولا تُخزَّن. **لا تؤخذ** موافقتكم بخصوص هذه المادة. |
| **عنوان IP** | عنوان IP المسجل لأغراض الأمان ليس موقع الجهاز ولا يُستخدم لتحديد الموقع (للتفصيل: [سياسة الخصوصية](/legal/privacy) القسمان 5 و6). |
| **مستقبلًا** | إذا لزمت معالجة الموقع فسيُحدَّث هذا النص، وتُبيَّن الغاية ومدة الاحتفاظ، وتُؤخذ **موافقتكم الصريحة من جديد**. |

## المادة 3. الإشعارات الفورية والنقل إلى الخارج

| | |
|---|---|
| **ماذا يحدث؟** | يُعالَج مفتاح الإشعارات الخاص بجهازكم من أجل إرسال إشعارات فورية إلى جهازكم، مثل الرسائل وتذكيرات الفعاليات والإعلانات ونتائج الإشراف. |
| **أي بيانات؟** | مفتاح إشعارات الجهاز (FCM)، والمنصة (Android/iOS)، وإصدار التطبيق، واللغة، وعنوان الإشعار ونصه القصير، ومعلومات الوجهة. لا يظهر نص الرسالة في الإشعار ما لم يُفعَّل الإعداد الخاص بذلك. |
| **إلى من تُنقل؟** | شركة Google LLC (Firebase Cloud Messaging)، وشركة Apple Inc. (APNs) لأجهزة iOS. وخوادم مزودي الخدمة هؤلاء **موجودة في الخارج**. |
| **النقل إلى الخارج** | يستند هذا النقل إلى موافقتكم الصريحة بموجب المادة 9 من القانون (وإلى آليات الحماية الكافية/الضمانات المناسبة إن وُجدت). وتقرّون بأن مستوى الحماية لدى المتلقي في الخارج قد لا يماثل مستواه في تركيا. |
| **تفضيلاتكم** | يمكنكم تغيير أنواع الإشعارات و**الساعات الهادئة** (الافتراضي 22:00-07:00، معطّلة) من الإعدادات. |
| **الاحتفاظ** | يُحذف مفتاح الجهاز الذي لم يُرَ منذ 60 يومًا في التنظيف الليلي؛ ويُحذف عند تسجيل الخروج أو عند حذف الحساب. |
| **السحب** | أوقفوا إذن الإشعارات من إعدادات الجهاز، أو من الإعدادات > الإشعارات في التطبيق. ويعمل صندوق الإشعارات داخل التطبيق حتى مع عدم وجود إذن الإشعارات. |

**الموافقة:** أمنح موافقتي الصريحة على نقل مفتاح إشعارات جهازي ومحتوى الإشعار إلى بنية Google Firebase/Apple في الخارج بغرض تلقي الإشعارات الفورية.

## المادة 4. نشر معلومات الملف الشخصي الاختيارية

أنتم تحددون **لكل حقل على حدة**، من الملف الشخصي > الخصوصية، ما إذا كانت حقول الكلية والقسم والصف والنبذة التعريفية وصورة الملف الشخصي والبريد الإلكتروني ستُعرض للمستخدمين الآخرين. وبجعل هذه الحقول مرئية تكونون قد وافقتم على عرض المعلومات المعنية للمستخدمين الآخرين؛ وعند إيقاف الظهور لا تُعرض المعلومات للمستخدمين الآخرين.

## سحب الموافقة

1. يمكن سحب كل إذن **بسهولة ودون مقابل** من الطريق الذي مُنح منه (إعدادات الجهاز أو شاشتا الأذونات والإعدادات في التطبيق).
2. لا يؤثر سحب الموافقة في مشروعية العمليات التي أُجريت حتى لحظة السحب.
3. إذا رغبتم في حذف جميع بياناتكم الشخصية فيمكنكم إغلاق حسابكم أو استخدام طرق التقديم الواردة في [إشعار الإفصاح بموجب قانون حماية البيانات الشخصية (KVKK)](/legal/kvkk).
4. في حال عدم منح الموافقة أو سحبها، لا يتعذر استخدام سوى الميزة الاختيارية المعنية (مطابقة جهات الاتصال، الإشعارات الفورية).

> **باختصار:** إذنا مطابقة جهات الاتصال والإشعارات الفورية اختياريان، ويُمنحان كلٌّ على حدة، ويمكن سحبهما في أي وقت. لا يُرسل من دفتر جهات الاتصال سوى ملخصات البريد الإلكتروني ولا تُخزَّن؛ ولا يطلب التطبيق إذن الموقع ولا يجمع الموقع؛ وتُرسل الإشعارات الفورية عبر Google Firebase/Apple (في الخارج).$c_explicit_consent_ar$, d.require_reaccept, TRUE
FROM legal_document d
WHERE d.type = 'EXPLICIT_CONSENT' AND d.lang = 'tr' AND d.active
  AND NOT EXISTS (SELECT 1 FROM legal_document x WHERE x.type = 'EXPLICIT_CONSENT' AND x.lang = 'ar' AND (x.version = d.version OR x.active));

-- COOKIES: mevcut aktif surume Arapca ekle (yoksa)
INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active)
SELECT 'COOKIES', 'ar', d.version, $t_cookies_ar$سياسة ملفات تعريف الارتباط والتخزين المحلي$t_cookies_ar$, $c_cookies_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

توضح هذه السياسة ما يخزنه موقع BÜ Kampüs ولوحة الإدارة في متصفحكم. لا يستخدم تطبيق الجوال ملفات تعريف الارتباط؛ وتسري [سياسة الخصوصية](/legal/privacy) على بيانات الجوال.

## 1. باختصار

1. **لا يستخدم موقعنا ملفات تعريف ارتباط للإعلانات أو التتبع أو التنميط.** ولا تُحمَّل نصوص برمجية تحليلية/إعلانية من أطراف ثالثة.
2. يُستخدم فقط **تخزين محلي ضروري** لتشغيل الموقع وتذكر تفضيلاتكم. ولا تلزم موافقة مستقلة على التخزين الضروري (وتُقدَّم المعلومات المعنية لأغراض الإعلام فقط).
3. يمكنكم حذف التخزين المحلي أو حظره من إعدادات المتصفح؛ وفي هذه الحالة تُعاد تهيئة تفضيلات اللغة/المظهر وقد تحتاجون إلى تسجيل الدخول.

## 2. سجلات التخزين التي نستخدمها

| الاسم | النوع | الغاية | المدة | هل هو ضروري؟ |
|---|---|---|---|---|
| `bu.lang` | localStorage | تذكر اللغة التي اخترتموها (tr/en/ar) | حتى تحذفوه | نعم (وظيفي) |
| `bu.theme` | localStorage | تذكر تفضيل المظهر الفاتح/الداكن | حتى تحذفوه | نعم (وظيفي) |
| `bu.cookies` | localStorage | تذكر أنكم اطلعتم على هذا الإشعار | حتى تحذفوه | نعم (وظيفي) |
| مفتاح الوصول ومفتاح التجديد | sessionStorage | استمرار جلسة تسجيل الدخول | يُحذف عند إغلاق التبويب/النافذة | نعم (أمني) |
| `bu.admin.*` (لوحة الإدارة: المسودات، الشريط الجانبي، قوالب الردود) | localStorage | تسهيلات للوحة خاصة بالمديرين فقط | حتى تحذفوه | نعم (للوحة الإدارة فقط) |

## 3. ملفات تعريف الارتباط

لا **يضع** موقعنا حاليًا أي ملف تعريف ارتباط (cookie). ولا تُكتب ملفات تعريف ارتباط في متصفحكم باستثناء الترويسات الضرورية تقنيًا من طبقة الاستضافة/الشبكة. وإذا استُخدم ملف تعريف ارتباط مستقبلًا فستُحدَّث هذه السياسة؛ وتؤخذ موافقتكم مسبقًا على ملفات تعريف الارتباط غير الضرورية.

## 4. الأطراف الثالثة

لا توجد في الموقع إضافات خارجية للتحليلات أو الإعلانات أو تتبع وسائل التواصل الاجتماعي. وتسري السياسات الخاصة بمواقع الأطراف الثالثة التي قد تنتقلون إليها عبر الروابط.

## 5. إدارة تفضيلاتكم

1. يمكنكم حذف السجلات المذكورة أعلاه عبر "مسح بيانات الموقع" في متصفحكم.
2. يمكنكم إعادة تعيين تفضيل هذا الإشعار عبر الخيار الموجود في صفحة ملفات تعريف الارتباط.
3. لإنهاء جلسة تسجيل الدخول يكفي تسجيل الخروج؛ وتُحذف المفاتيح أصلًا عند إغلاق التبويب.

> **باختصار:** لا توجد ملفات تعريف ارتباط للإعلانات/التتبع. لا يُخزَّن سوى اللغة والمظهر وتفضيل الإشعار ومعلومات الجلسة (التي تُحذف عند إغلاق التبويب).

## 6. التواصل

{{support.email|قسم الدعم داخل التطبيق}}$c_cookies_ar$, d.require_reaccept, TRUE
FROM legal_document d
WHERE d.type = 'COOKIES' AND d.lang = 'tr' AND d.active
  AND NOT EXISTS (SELECT 1 FROM legal_document x WHERE x.type = 'COOKIES' AND x.lang = 'ar' AND (x.version = d.version OR x.active));

DO $do_content_removal$
DECLARE
    v INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = 'CONTENT_REMOVAL';
    UPDATE legal_document SET active = FALSE WHERE type = 'CONTENT_REMOVAL' AND active;
    INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
    ('CONTENT_REMOVAL', 'tr', v, $t_content_removal_tr$İçerik Bildirimi ve Kaldırma$t_content_removal_tr$, $c_content_removal_tr$Bu metin, BÜ Kampüs'te yer alan kullanıcı içeriklerine ilişkin hukuka aykırılık, kişilik hakkı ve telif hakkı ihlali bildirimlerinin nasıl yapılacağını ve nasıl değerlendirileceğini açıklar. Hizmet, 5651 sayılı "İnternet Ortamında Yapılan Yayınların Düzenlenmesi ve Bu Yayınlar Yoluyla İşlenen Suçlarla Mücadele Edilmesi Hakkında Kanun" bakımından **yer sağlayıcı** konumundadır; kullanıcı içeriklerini önceden denetlemekle veya hukuka aykırı faaliyet olup olmadığını araştırmakla yükümlü değildir, ancak hukuka aykırı içeriği usulüne uygun bildirim üzerine kaldırır.

## 1. Hangi durumlar için başvurulabilir?

1. İçeriğin hukuka aykırı olduğunu düşünüyorsanız (hakaret, tehdit, müstehcenlik, suça teşvik vb.).
2. Kişilik haklarınızın (ad, görüntü, özel hayat) ihlal edildiğini düşünüyorsanız.
3. Telif hakkınız (5846 sayılı Fikir ve Sanat Eserleri Kanunu, FSEK) ihlal edilmişse.
4. Kişisel verilerinizin hukuka aykırı paylaşıldığını düşünüyorsanız (bu durumda ayrıca [KVKK Aydınlatma Metni](/legal/kvkk) başvuru yolu da kullanılabilir).

## 2. Hızlı yol: uygulama içi bildirim

Kullanıcı, mesaj, gönderi, yorum, hikâye, topluluk veya etkinlik üzerinde **Bildir** seçeneğini kullanın. Gönderi, yorum ve hikâyeler yayımlanmadan önce insan denetiminden geçmez; bildirim üzerine yetkili yöneticiler içeriği inceler, gizler veya kaldırır; içeriği paylaşan kullanıcıya uygulama içi bildirim yapılabilir ve itiraz hakkı saklıdır. Bildirimler yetkili yöneticilerce incelenir; ilgili sohbet bağlamı da görülebilir. Bu yol hızlıdır ve Topluluk Kuralları ihlalleri için uygundur.

## 3. Resmi bildirim usulü

Bildirimi {{support.email|uygulama içi Destek bölümü (konu: "İçerik bildirimi")}} üzerinden{{?controller.kep}} veya {{controller.kep}} KEP adresine{{/controller.kep}}{{?controller.address}} veya {{controller.address}} adresine yazılı olarak{{/controller.address}} iletin. Bildirim şunları içermelidir:

1. Adınız-soyadınız, iletişim bilgileriniz (e-posta/telefon) ve gerekirse kimlik doğrulamaya yarayan belge,
2. Bildirdiğiniz içeriğin yeri (kullanıcı adı, topluluk/etkinlik adı, mesaj/gönderi tarihi, ekran görüntüsü, varsa bağlantı),
3. İçeriğin neden hukuka aykırı olduğuna dair açıklama ve (varsa) dayanak hüküm,
4. Kişilik hakkı ihlallerinde ilgili kişinin kendisi veya yasal temsilcisi olduğunuzu gösteren bilgi/belge,
5. Telif bildirimlerinde ayrıca aşağıdaki 4. bölümdeki bilgiler,
6. Bildirimin doğru ve iyi niyetli olduğuna dair beyan.

## 4. Telif hakkı (FSEK) ihlal bildirimi

Telif bildiriminde şunları belirtin: (a) eserin tanımı ve hak sahibi olduğunuzu gösteren bilgi/belge, (b) ihlal iddiasına konu içeriğin yeri, (c) eseri izinsiz kullanıldığına dair açıklama, (d) bildirimin doğruluğuna ilişkin beyan, (e) iletişim bilgileriniz. Eksik bildirimler tamamlanması için size iade edilebilir. Mümkün olduğunda içerik, değerlendirme süresince **geçici olarak erişime kapatılabilir**.

## 5. Değerlendirme ve süreler

1. Bildiriminiz alındığında incelenir; açıkça hukuka aykırı veya Topluluk Kuralları'na aykırı bulunan içerik **kaldırılır veya gizlenir**. Makul sürede (hedef: iş günü bazında en geç birkaç gün; yasal süre öngörülen hallerde bu süre) sonuç bildirilir.
2. Mahkeme veya yetkili idari makam kararıyla (ör. 5651 m.9) içerik kaldırma/erişim engelleme talepleri, kararda belirtilen süre içinde yerine getirilir.
3. Gerektiğinde içeriği paylaşan kullanıcıya bildirim yapılır; kullanıcı kimliği ve ilgili kayıtlar yalnızca yasal talep halinde yetkili makamlara verilir.
4. Tekrar eden ihlallerde ihlal eden hesap askıya alınabilir veya kapatılabilir.
5. Kötü niyetli veya asılsız bildirimler rapor kısıtlamasına yol açabilir.

## 6. İtiraz ve içeriğin geri alınması

1. İçeriği kaldırılan kullanıcı, kaldırma kararına uygulamadaki **itiraz** özelliğinden veya Destek bölümünden gerekçesiyle itiraz edebilir.
2. İtiraz bir yönetici tarafından yeniden değerlendirilir; haklı bulunursa içerik yeniden yayına alınır. Telif bildirimlerinde itiraz durumunda hak sahibine bilgi verilir; uyuşmazlık devam ederse taraflar yargı yoluna yönlendirilir.
3. Yasal haklarınız (mahkemeye başvuru dahil) saklıdır.

## 7. Yer sağlayıcı konumu, sorumluluk ve trafik bilgisi

1. Yer sağlayıcı olarak yalnızca kendi içeriğimizden değil, kullanıcıların paylaştığı içerikten, **ancak hukuka aykırı olduğunu bildirim veya başka yolla öğrendiğimizde** ve bu içeriği yayından çıkarmadığımız takdirde, kanunda öngörülen ölçüde sorumlu tutulabiliriz (5651 sayılı Kanun m.5). Bu nedenle usulüne uygun bildirimleri öncelikle ve gecikmeksizin değerlendiririz.
2. Kişilik hakkı ihlali iddialarında hâkim kararıyla içeriğin çıkarılması veya erişimin engellenmesi yolu (5651 m.9) ayrıca saklıdır; böyle bir karar bize ulaştığında kararda öngörülen süre içinde uygularız. Bildirimde bulunmanız, bu yargısal yolu kullanmanıza engel değildir.
3. Yer sağlayıcı sıfatıyla, ilgili mevzuatın gerektirdiği trafik bilgilerini (ör. erişim zamanı, IP adresi) mevzuatın öngördüğü süre boyunca, bütünlüğü korunarak saklarız ve yetkili makamlara talep halinde veririz. Uygulamanın olağan işleyişi için tuttuğu cihaz/IP kayıtlarının süreleri [Saklama ve İmha](/legal/retention) metnindedir.
4. İçeriği uygulamadan kaldırmak, içeriğin başka ortamlarda bulunmasını engellemez; içeriği paylaşan kişinin hukuki sorumluluğu kendisine aittir.

## 8. Kayıt ve gizlilik

Bildirim ve kaldırma kayıtları (içeriğin kendisi değil, işlem özeti ve karar) hesap verebilirlik için moderasyon izi olarak saklanır. Bildirimde verdiğiniz kişisel veriler yalnızca başvurunun değerlendirilmesi için kullanılır.

> **Özetle:** Hukuka aykırı içerik için önce uygulama içindeki **Bildir** özelliğini kullanın; resmi bildirimler için yukarıdaki bilgileri e-posta/Destek/KEP üzerinden iletin. İçerik incelenir, gerekirse kaldırılır; kaldırma kararına itiraz edebilirsiniz.$c_content_removal_tr$, FALSE, TRUE),
    ('CONTENT_REMOVAL', 'en', v, $t_content_removal_en$Content Notice and Removal$t_content_removal_en$, $c_content_removal_en$*This English text is provided for information only. The Turkish text is authoritative.*

This text explains how to notify unlawful content, personality-right violations and copyright infringements (Law No. 5846, FSEK). Under Law No. 5651 the Service is a **hosting provider**: it does not monitor user content in advance but removes unlawful content on a duly submitted notice.

## 1. When to apply

Content you consider unlawful (insult, threat, obscenity, incitement); violation of your personality rights (name, image, private life); copyright infringement; unlawful sharing of your personal data (the [KVKK Notice](/legal/kvkk) application route may also be used).

## 2. Fast route: in-app report

Use **Report** on a user, message, post, comment, story, community or event. Posts, comments and stories are not reviewed by humans before publication; upon a report, authorised administrators review, hide or remove the content, the user who shared it may be notified in the app, and the right to appeal is reserved. Authorised administrators review it and may see the related chat context. Suitable for Community Rules violations.

## 3. Formal notice

Send to {{support.email|the in-app Support section (subject: "Content notice")}}{{?controller.kep}} or to KEP {{controller.kep}}{{/controller.kep}}{{?controller.address}} or in writing to {{controller.address}}{{/controller.address}}. Include:

1. Your name and contact details, and an identity document if needed;
2. Location of the content (username, community/event name, date, screenshot, link);
3. Why it is unlawful and the legal provision, if any;
4. For personality rights: that you are the person or their legal representative;
5. For copyright: the information in section 4;
6. A statement that the notice is accurate and in good faith.

## 4. Copyright (FSEK) notice

State: (a) description of the work and proof of ownership; (b) where the content is; (c) how the work was used without permission; (d) a statement of accuracy; (e) contact details. Incomplete notices may be returned. Content may be **temporarily disabled** during review where possible.

## 5. Assessment and timing

1. Content found clearly unlawful or in breach of the Community Rules is **removed or hidden**; the outcome is communicated within a reasonable time.
2. Removal/blocking orders from a court or competent authority (e.g. Law 5651 Art. 9) are executed within the period stated.
3. The uploader may be notified; identity and records are given to authorities only upon lawful request.
4. Repeat infringers may be suspended or closed.
5. Bad-faith or baseless notices may restrict your reporting.

## 6. Counter-appeal and restoration

The user whose content was removed may appeal via the in-app appeal feature or Support. An administrator reviews it and restores the content if justified. For copyright notices the rights holder is informed; if the dispute continues the parties are referred to the courts. Statutory rights remain reserved.

## 7. Hosting-provider position, liability and traffic data

1. As a hosting provider we may be held liable not for our own content but for user content only to the extent provided by law, **when we learn that it is unlawful** (by notice or otherwise) and do not remove it (Law No. 5651, Art. 5). We therefore assess duly made notices first and without delay.
2. The court-order route for personal-rights violations (Art. 9 of Law No. 5651) remains available; when such an order reaches us we comply within the time it sets. Sending a notice does not prevent you from using that route.
3. As a hosting provider we keep the traffic data required by law (for example access time and IP address) with integrity for the period the legislation prescribes and provide it to competent authorities on request. Retention periods of the device/IP records kept for normal operation are in [Retention and Destruction](/legal/retention).
4. Removing content from the app does not prevent it from existing elsewhere; the person who shared it remains legally responsible for it.

## 8. Records

Notice and removal records (action summary and decision, not the content) are kept as a moderation trail. Personal data in a notice is used only to assess it.

> **In short:** Use **Report** first; send formal notices with the details above. Content is reviewed and removed if needed; removals can be appealed.$c_content_removal_en$, FALSE, TRUE),
    ('CONTENT_REMOVAL', 'ar', v, $t_content_removal_ar$الإبلاغ عن المحتوى وإزالته$t_content_removal_ar$, $c_content_removal_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

يوضح هذا النص كيفية تقديم البلاغات المتعلقة بمحتوى المستخدمين في BÜ Kampüs من حيث مخالفته للقانون أو انتهاكه لحقوق الشخصية أو حقوق المؤلف، وكيفية تقييمها. وتُعدّ الخدمة **مزوّد استضافة** بموجب القانون رقم 5651 "بشأن تنظيم البث على الإنترنت ومكافحة الجرائم المرتكبة عبر هذا البث"؛ فهي غير ملزمة بالرقابة المسبقة على محتوى المستخدمين ولا بالتحري عن وجود نشاط مخالف للقانون، غير أنها تزيل المحتوى المخالف للقانون بناءً على بلاغ مستوفٍ للأصول.

## 1. في أي الحالات يمكن التقدم ببلاغ؟

1. إذا كنتم ترون أن المحتوى مخالف للقانون (إهانة، تهديد، فحش، تحريض على ارتكاب جريمة، ونحو ذلك).
2. إذا كنتم ترون أن حقوق شخصيتكم (الاسم، الصورة، الحياة الخاصة) قد انتُهكت.
3. إذا انتُهكت حقوق المؤلف الخاصة بكم (القانون رقم 5846 للمصنفات الفكرية والفنية، FSEK).
4. إذا كنتم ترون أن بياناتكم الشخصية قد نُشرت على نحو مخالف للقانون (وفي هذه الحالة يمكن أيضًا استخدام طريق التقديم الوارد في [إشعار الإفصاح بموجب قانون حماية البيانات الشخصية (KVKK)](/legal/kvkk)).

## 2. الطريق السريع: الإبلاغ داخل التطبيق

استخدموا خيار **إبلاغ** على المستخدم أو الرسالة أو المنشور أو التعليق أو القصة أو المجتمع أو الفعالية. لا تمر المنشورات والتعليقات والقصص بمراجعة بشرية قبل نشرها؛ وبناءً على البلاغ يراجع المديرون المخولون المحتوى ويخفونه أو يزيلونه؛ ويمكن إرسال إشعار داخل التطبيق إلى المستخدم الذي نشر المحتوى، ويبقى حق الاعتراض محفوظًا. وتُراجَع البلاغات من قبل المديرين المخولين؛ ويمكن الاطلاع أيضًا على سياق المحادثة ذي الصلة. هذا الطريق سريع ومناسب لمخالفات قواعد المجتمع.

## 3. إجراء البلاغ الرسمي

أرسلوا البلاغ عبر {{support.email|قسم الدعم داخل التطبيق (الموضوع: "بلاغ عن محتوى")}}{{?controller.kep}} أو إلى عنوان KEP (البريد الإلكتروني المسجل) {{controller.kep}}{{/controller.kep}}{{?controller.address}} أو كتابةً إلى العنوان {{controller.address}}{{/controller.address}}. ويجب أن يتضمن البلاغ ما يلي:

1. اسمكم ولقبكم ومعلومات الاتصال بكم (البريد الإلكتروني/الهاتف) وعند اللزوم مستندًا يفيد في التحقق من الهوية،
2. موضع المحتوى المبلَّغ عنه (اسم المستخدم، اسم المجتمع/الفعالية، تاريخ الرسالة/المنشور، لقطة شاشة، والرابط إن وُجد)،
3. شرحًا لسبب مخالفة المحتوى للقانون، و(إن وُجد) الحكم القانوني المستند إليه،
4. في انتهاكات حقوق الشخصية، معلومات/مستندات تثبت أنكم الشخص المعني نفسه أو ممثله القانوني،
5. في بلاغات حقوق المؤلف، المعلومات الواردة في القسم 4 أدناه علاوة على ما سبق،
6. إقرارًا بأن البلاغ صحيح ومقدَّم بحسن نية.

## 4. بلاغ انتهاك حقوق المؤلف (FSEK)

في بلاغ حقوق المؤلف، بيّنوا ما يلي: (أ) وصف المصنف ومعلومات/مستندات تثبت أنكم صاحب الحق، (ب) موضع المحتوى موضوع ادعاء الانتهاك، (ج) شرحًا يفيد بأن المصنف استُخدم دون إذن، (د) إقرارًا بصحة البلاغ، (هـ) معلومات الاتصال بكم. وقد تُعاد إليكم البلاغات الناقصة لاستكمالها. ويجوز، متى أمكن، **حجب الوصول إلى المحتوى مؤقتًا** طوال مدة التقييم.

## 5. التقييم والمدد

1. يُفحص بلاغكم عند استلامه؛ ويُ**زال أو يُخفى** المحتوى الذي يتبين أنه مخالف للقانون بوضوح أو مخالف لقواعد المجتمع. وتُبلَّغ النتيجة في مدة معقولة (الهدف: بحسب أيام العمل، بضعة أيام على الأكثر؛ وفي الحالات التي ينص فيها القانون على مدة فتُتَّبع تلك المدة).
2. تُنفَّذ طلبات إزالة المحتوى/حجب الوصول الصادرة بقرار من المحكمة أو السلطة الإدارية المختصة (مثل المادة 9 من القانون 5651) خلال المدة المحددة في القرار.
3. يُرسل عند الاقتضاء إشعار إلى المستخدم الذي نشر المحتوى؛ ولا تُسلَّم هوية المستخدم والسجلات ذات الصلة إلى السلطات المختصة إلا بناءً على طلب قانوني.
4. في حالات تكرار المخالفة يجوز تعليق الحساب المخالف أو إغلاقه.
5. قد تؤدي البلاغات سيئة النية أو الكيدية إلى تقييد حق الإبلاغ.

## 6. الاعتراض وإعادة المحتوى

1. يجوز للمستخدم الذي أُزيل محتواه الاعتراض على قرار الإزالة مع بيان الأسباب، عبر خاصية **الاعتراض** في التطبيق أو عبر قسم الدعم.
2. يُعاد تقييم الاعتراض من قبل أحد المديرين؛ وإذا وُجد محقًا يُعاد المحتوى إلى النشر. وفي بلاغات حقوق المؤلف، يُبلَّغ صاحب الحق في حال الاعتراض؛ وإذا استمر النزاع يُحال الطرفان إلى القضاء.
3. حقوقكم القانونية (بما في ذلك اللجوء إلى المحكمة) محفوظة.

## 7. صفة مزوّد الاستضافة والمسؤولية ومعلومات حركة البيانات

1. بصفتنا مزوّد استضافة، قد نُسأل لا عن محتوانا الخاص فحسب، بل عن المحتوى الذي ينشره المستخدمون، **لكن فقط إذا علمنا بمخالفته للقانون عبر بلاغ أو بأي طريق آخر** ولم نُخرجه من النشر، وذلك بالقدر الذي ينص عليه القانون (القانون رقم 5651، المادة 5). ولهذا نقيّم البلاغات المستوفاة للأصول أولًا ودون تأخير.
2. يبقى كذلك محفوظًا طريق إزالة المحتوى أو حجب الوصول إليه بقرار من القاضي في ادعاءات انتهاك حقوق الشخصية (المادة 9 من القانون 5651)؛ وعند وصول قرار كهذا إلينا ننفذه خلال المدة المحددة فيه. ولا يمنعكم تقديم البلاغ من سلوك هذا الطريق القضائي.
3. بصفتنا مزوّد استضافة، نحتفظ بمعلومات حركة البيانات التي تتطلبها التشريعات ذات الصلة (مثل وقت الوصول وعنوان IP) طوال المدة التي تنص عليها التشريعات مع حماية سلامتها، ونسلمها إلى السلطات المختصة عند الطلب. أما مدد سجلات الجهاز/IP التي يحتفظ بها التطبيق لتشغيله المعتاد فمبينة في نص [الاحتفاظ بالبيانات وإتلافها](/legal/retention).
4. إن إزالة المحتوى من التطبيق لا تمنع وجوده في وسائط أخرى؛ وتقع المسؤولية القانونية على عاتق الشخص الذي نشر المحتوى.

## 8. السجلات والخصوصية

تُحفظ سجلات البلاغات والإزالة (ملخص الإجراء والقرار، لا المحتوى نفسه) كأثر إشرافي لأغراض المساءلة. وتُستخدم بياناتكم الشخصية التي قدمتموها في البلاغ لغرض تقييم الطلب فقط.

> **باختصار:** بالنسبة للمحتوى المخالف للقانون، استخدموا أولًا خاصية **إبلاغ** داخل التطبيق؛ وللبلاغات الرسمية أرسلوا المعلومات المذكورة أعلاه عبر البريد الإلكتروني/الدعم/KEP. يُفحص المحتوى ويُزال عند الاقتضاء؛ ويمكنكم الاعتراض على قرار الإزالة.$c_content_removal_ar$, FALSE, TRUE);
END
$do_content_removal$;

-- RETENTION: mevcut aktif surume Arapca ekle (yoksa)
INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active)
SELECT 'RETENTION', 'ar', d.version, $t_retention_ar$الاحتفاظ بالبيانات وإتلافها$t_retention_ar$, $c_retention_ar$*هذا النص العربي ترجمة للاطلاع فقط؛ النص التركي هو المرجع الملزم عند أي اختلاف.*

يبيّن هذا الملخص المدة التي تُحفظ فيها بياناتكم الشخصية وما يحدث لها عند انتهاء المدة. وتُعدّ السياسة التفصيلية الداخلية للمؤسسة أساسًا لهذا الملخص. والمدد معرَّفة في إعدادات التطبيق؛ ويجوز للمشغّل تغييرها، وعند التغيير يُحدَّث هذا النص.

## 1. المبادئ

1. تُحفظ البيانات للمدة اللازمة لغاية المعالجة وطوال المدة التي تسمح بها التشريعات.
2. عند انقضاء المدة تُ**حذف** البيانات أو **تُتلف** أو تُجعل **مجهولة الهوية** تلقائيًا بمهام ليلية.
3. إذا وُجد التزام قانوني بالحفظ فتُحفظ البيانات طوال المدة المعنية.
4. الإتلاف الدوري: تعمل مهام التنظيف الآلي يوميًا/كل ساعة؛ ويُسجَّل إتلاف البيانات الشخصية.

## 2. مدد الاحتفاظ

| البيانات | المدة | عند انتهاء المدة |
|---|---|---|
| التسجيل المعلّق (غير الموثَّق) | ساعة واحدة | يُحذف |
| رمز توثيق البريد الإلكتروني / إعادة تعيين كلمة المرور | 10 دقائق (5 محاولات كحد أقصى) | يصبح غير صالح / يُحذف |
| مفتاح الوصول | 15 دقيقة | يصبح غير صالح |
| مفتاح التجديد (على شكل ملخص) | 30 يومًا كحد أقصى؛ ويُحذف مبكرًا عند تسجيل الخروج/تغيير كلمة المرور/تسجيل دخول جديد من الجوال | يُحذف |
| صندوق الإشعارات | المقروء 90 يومًا، وغير المقروء 365 يومًا | يُحذف |
| مفتاح إشعارات الجهاز | إذا لم يُرَ لمدة 60 يومًا | يُحذف |
| معرّف الجهاز (ملخص) وسجلات IP | 90 يومًا | يُحذف |
| سجل مرشح العبارات غير اللائقة (الحقل، المستخدم، الوقت؛ دون النص) | 90 يومًا | يُحذف |
| طابور الإشعارات الفورية (Push) | تُجرَّب المعلّقة 24 ساعة كحد أقصى؛ المرسلة 7 أيام، والفاشلة 30 يومًا | يُحذف |
| القصة | تظهر 24 ساعة؛ وبعد 24 ساعة من انتهائها | تُحذف نهائيًا |
| ملفات الوسائط الخاصة بمنشور محذوف | 30 يومًا | تُحذف من القرص ومن قاعدة البيانات |
| الوسائط المرفوعة غير المرتبطة بمنشور | 24 ساعة | تُحذف |
| علاقات المتابعة، والمنشورات المحفوظة، والجدول الدراسي الشخصي وسجلات الامتحانات | ما دام الحساب مفتوحًا | تُحذف عند حذف الحساب |
| سجل التصويت في الاستبيان | ما دام الحساب مفتوحًا | عند حذف الحساب ينقطع ارتباطه بالمستخدم (يبقى عدّاد مجهول الهوية)؛ ويُحذف سجل المشاركة |
| سجل حظر الوصول | ما دام الحظر قائمًا والمدة اللازمة للتدقيق | يُحذف / يُعطَّل |
| أحداث التحليلات | 180 يومًا | تُحذف |
| طابور البريد الإلكتروني (المرسل/الفاشل) | 30 يومًا | يُحذف |
| الرسائل | ما دام الحساب مفتوحًا؛ وتبقى حتى بعد حذف الحساب من أجل سياق المحادثة (الكاتب مجهول) | تُحذف عند انتهاء المدة إذا جرى ضبطها |
| النسخة المشفّرة للرسائل المحذوفة وسجل التعديل | افتراضيًا دون أجل (قابل للضبط) | تُحذف نهائيًا إذا ضُبطت مدة |
| النسخة المشفّرة للصورة ذات الإرسال الواحد | 365 يومًا (قابل للضبط) | تُحذف؛ ويبقى سجل المشاهدة |
| الوسائط غير المرسلة في المحادثة (المرفوعة وغير المرتبطة) | 24 ساعة | تُحذف |
| غرفة محادثة الفعالية | تُغلق بعد 7 أيام من انتهاء الفعالية | تُغلق الغرفة |
| طلب الدعم العام (بدون تسجيل دخول) | 365 يومًا | يُحذف |
| طلبات الدعم / الملاحظات / الاعتراضات / ملاحظات البلاغات | تُمسح النصوص عند حذف الحساب | يبقى سجل مجهول الهوية |
| سجلات الموافقة على الاتفاقيات والإقرارات | تبقى حتى بعد حذف الحساب لأغراض الإثبات | حتى نهاية التقادم القانوني |
| آثار مخالفات الإشراف والحظر | تبقى مجهولة الهوية حتى بعد حذف الحساب | طوال مدة الأمان/الإثبات |
| سجل إجراءات المديرين وسجل الوصول إلى الرسائل | غير قابل للتعديل؛ للتدقيق / المدة القانونية | يجوز نقله إلى أرشيف خارجي ثم يُتلف |
| ملخصات مطابقة جهات الاتصال | **لا تُحفظ** | — |
| الموقع | **لا يُجمع ولا يُحفظ** (لا يطلب التطبيق إذن الموقع) | — |

## 3. عند حذف الحساب

حذف الحساب هو **إخفاء للهوية**. المحذوف: مفاتيح إشعارات الأجهزة وسجلات الإشعارات الفورية المعلّقة، وصندوق الإشعارات وتفضيلاته، والمنشورات المحفوظة، وعلاقات المتابعة، والقصص، والجدول الدراسي وسجلات الامتحانات، وسجل المشاركة في الاستبيان، والإعجابات والتعليقات، ومنشورات اكتشاف (الوسائط بعد 30 يومًا)، والمفضلات، والأصوات وملاحظات تقييم الفعاليات، وقائمة الحظر، وردود طلبات الانضمام إلى النوادي، وعضويات المجتمعات، وصور المحادثة المرفوعة. ما يُجعل مجهول الهوية: الاسم والبريد الإلكتروني والملف الشخصي. ما يُحفظ (دون هوية/بشكل محدود): الرسائل ومنشورات المجتمع (لأنها سياق الآخرين)، وإقرارات الاتفاقيات، وآثار الإشراف، وسجلات المديرين، وعدّادات الفعاليات المجهولة. وتُحذف سجلات الجهاز/IP والتحليلات في مددها الخاصة. للتفصيل: [سياسة الخصوصية](/legal/privacy).

## 4. التزامات الاحتفاظ القانونية

بصفتنا مزوّد خدمة، قد نضطر بموجب التشريعات النافذة (ولا سيما القانون رقم 5651 ولوائحه الثانوية) إلى حفظ بعض سجلات الوصول/حركة البيانات لمدة معينة. وعند نشوء التزام كهذا تُحفظ السجلات المعنية طوال المدة المنصوص عليها في التشريعات ويُحدَّث هذا النص. وفي الوضع الحالي فإن مدة الاحتفاظ بسجلات أمان الجهاز/IP هي المدة المبينة في الجدول أعلاه.

## 5. طرق الإتلاف

تُزال سجلات قاعدة البيانات بالحذف الآمن؛ وتُحذف الملفات من التخزين؛ وفي إخفاء الهوية تُستبدل الحقول المحددة للهوية بصورة لا رجعة فيها؛ وفي البيانات المشفّرة يُغلق الوصول مع المفتاح. ويتم الحذف من النسخ الاحتياطية ضمن دورة النسخ الاحتياطي.

## 6. حقوقكم

يمكنكم طلب حذف بياناتكم أو جعلها مجهولة الهوية بالطرق المبينة في القسم 11 من [إشعار الإفصاح بموجب قانون حماية البيانات الشخصية (KVKK)](/legal/kvkk) (الدعم، كتابةً، KEP)؛ وتُجاب الطلبات في أجل أقصاه 30 يومًا.

> **باختصار:** تُحذف معظم السجلات التقنية تلقائيًا خلال أيام أو أشهر؛ أما الرسائل وسجلات الإثبات القانوني فقد تبقى لمدة أطول بصورة محدودة ودون هوية. لا تُحفظ ملخصات جهات الاتصال؛ ولا يُجمع الموقع إطلاقًا.$c_retention_ar$, d.require_reaccept, TRUE
FROM legal_document d
WHERE d.type = 'RETENTION' AND d.lang = 'tr' AND d.active
  AND NOT EXISTS (SELECT 1 FROM legal_document x WHERE x.type = 'RETENTION' AND x.lang = 'ar' AND (x.version = d.version OR x.active));
