-- V290: Sozlesme metinleri 3. nesil (docs/legal/*.md'den scripts/build-legal-migration.js ile URETILDI; elle duzenlemeyin).
-- * legal_type_check 8 ture genisletilir (EXPLICIT_CONSENT, COOKIES, CONTENT_REMOVAL, RETENTION).
-- * Surum numarasi her tur icin COALESCE(MAX(version),0)+1 ile hesaplanir (yerel/test surumlerine dayanikli);
--   onceki aktif surumler (tum diller) pasife alinir, yeni tr+en ayni numarayla aktif eklenir.
-- * Yer tutucular ({{controller.name}} vb.) sunum aninda LegalService tarafindan app_setting'ten doldurulur.
-- * Kayitta zorunlu onay: TERMS, PRIVACY, KVKK, COMMUNITY_RULES (require_reaccept=true). Digerleri bilgilendirmedir.

ALTER TABLE legal_document DROP CONSTRAINT IF EXISTS legal_type_check;
ALTER TABLE legal_document ADD CONSTRAINT legal_type_check CHECK (type IN ('TERMS', 'PRIVACY', 'KVKK', 'COMMUNITY_RULES', 'EXPLICIT_CONSENT', 'COOKIES', 'CONTENT_REMOVAL', 'RETENTION'));

-- Yonetici ayarlari: yer tutucu kaynaklari (legal.* anahtarlari; support_email V5'te vardir)
INSERT INTO app_setting (setting_key, setting_value) VALUES
 ('legal.controller.name', 'Bingöl Üniversitesi'),
 ('legal.controller.address', ''),
 ('legal.controller.email', ''),
 ('legal.controller.kep', ''),
 ('legal.controller.verbis', ''),
 ('legal.hosting.location', '')
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
3. Hizmet; haber, duyuru ve etkinlik takibi, yemek listesi, profil, mesajlaşma, topluluklar ve etkinlikler (QR ile yoklama dahil), bildirimler, arama, favoriler ile destek ve geri bildirim özelliklerinden oluşur.
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
3. **Medyanın işlenmesi.** Yüklenen fotoğraflar türü ve boyutu doğrulandıktan sonra yeniden kodlanır; konum gibi gömülü üst veriler (EXIF) temizlenir. Sohbet fotoğrafları en çok 1600 piksel kenar uzunluğuna indirilir; mesaj başına en çok 10 ek (fotoğraf/video karışık) gönderilebilir. Videolar cihazınızda sıkıştırılır; sunucu videoyu yeniden kodlamaz; en çok 60 saniye ve 40 MB'a kadar kabul edilir, günlük gönderim sınırı vardır. Bu sınırlar değişebilir.
4. **Yasaklı içerik kontrolü.** Yüklenen görsellerin dijital özeti (SHA-256), yetkili yöneticilerin yönettiği "yasaklı içerik" özet listesiyle karşılaştırılır. Eşleşme halinde yükleme reddedilir. Bu kontrol yalnızca özet karşılaştırmasıdır; görsellerin içeriği otomatik olarak analiz edilmez.
5. **Lisansın sona ermesi.** İçeriğinizi sildiğinizde veya hesabınızı kapattığınızda lisans, 6. bölüm ve Gizlilik Politikası'nda açıklanan istisnalar (örneğin başkalarının sohbet geçmişi, yasal saklama ve güvenlik kayıtları) saklı kalmak üzere sona erer.

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

1. Hizmet "olduğu gibi" ve "mevcut haliyle" sunulur. Kesintisiz, hatasız veya her cihazda çalışacağı garanti edilmez; bakım, güncelleme, mücbir sebep ve üçüncü taraf hizmet (e-posta, bildirim altyapısı, barındırma) kesintileri olabilir. Zorunlu güncelleme veya bakım modu uygulanabilir.
2. Hizmetin ücretsiz olması nedeniyle, kanunun izin verdiği ölçüde; dolaylı zararlar, kâr kaybı, veri kaybı, itibar kaybı ve üçüncü kişilerin içeriklerinden doğan zararlardan sorumlu değiliz. Bu sınırlama; kasıt, ağır kusur ve kanunen sınırlandırılamayan haller (emredici hukuk kuralları, kişilik hakları ve ölüm/yaralanma zararları dahil) için uygulanmaz.
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
2. Hizmet, bir kamu üniversitesi bağlamında öğrenci/personel için ücretsiz sunulur ve kullanıcılar bu bağlamda tüketici sıfatıyla ücret karşılığı mal/hizmet almamaktadır; bu nedenle tüketici mevzuatındaki özel yetki kuralları, ancak kanunen uygulanabildiği ölçüde geçerlidir. Uyuşmazlıklarda **Bingöl mahkemeleri ve icra daireleri** yetkilidir; idari işlemlere ilişkin uyuşmazlıklarda ilgili idare mahkemesi görevlidir. Emredici yetki kuralları saklıdır.

## 15. İletişim

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
3. Uploaded photos are validated and re-encoded; embedded metadata (EXIF) is removed. Chat photos are scaled to at most 1600 px; up to 10 attachments per message. Videos are compressed on your device (not re-encoded by the server), up to 60 seconds and 40 MB, with a daily limit.
4. Uploaded images are compared by SHA-256 digest with a "prohibited content" list maintained by authorised administrators; a match rejects the upload. Image content is not otherwise analysed automatically.

## 4. Prohibited conduct

Unlawful, threatening, harassing, hateful, obscene or violent content; impersonation; sharing others' personal data or private conversations without consent; spam and fraud; abusing the service (bots, scraping the user directory, exploiting vulnerabilities, evading IP/device bans); breaching academic integrity; misusing attendance (QR) check-in; infringing intellectual property. See the Community Rules for examples.

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

1. The Service is provided "as is"; uninterrupted or error-free operation is not guaranteed; maintenance and third-party outages may occur.
2. To the extent permitted by law we are not liable for indirect damages, loss of profit, data or reputation, or damage from third-party content. This limitation does not apply to wilful misconduct, gross negligence or matters that cannot be limited by mandatory law.
3. As a hosting provider under Law No. 5651 we act on duly notified unlawful content.

## 11. Indemnity

You are liable, in proportion to your fault, for reasonable damages (including reasonable legal costs) arising from third-party claims caused by your breach of these terms or the law. Statutory limits remain unaffected.

## 12. Changes and re-acceptance

We may update these terms. For material changes the app asks you to re-accept the new version, and access to some parts may be limited until you do. Acceptance records are kept for evidence.

## 13. Termination

You can close your account at any time ([delete account](/delete-account)); deletion means anonymisation (see the Privacy Policy). We may suspend or close accounts that breach these terms. Provisions that by nature continue survive termination.

## 14. Governing law and jurisdiction

Turkish law applies. The Service is offered free of charge to students and staff of a public university; consumer-specific jurisdiction rules apply only to the extent they are mandatory by law. **Bingöl courts and enforcement offices** are competent (administrative courts for administrative acts). Mandatory jurisdiction rules remain reserved.

## 15. Contact

- General: {{support.email|in-app Support section}}
{{?controller.email}}- Controller e-mail: {{controller.email}}{{/controller.email}}
{{?controller.kep}}- KEP address: {{controller.kep}}{{/controller.kep}}$c_terms_en$, TRUE, TRUE);
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

{{support.email|Uygulama içi Destek bölümü}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}$c_privacy_tr$, TRUE, TRUE),
    ('PRIVACY', 'en', v, $t_privacy_en$Privacy Policy$t_privacy_en$, $c_privacy_en$*This English text is provided for information only. The Turkish text is authoritative.*

This policy explains which of your data is processed, why, for how long, and your rights. Read it together with the [KVKK Notice](/legal/kvkk).

Controller: {{controller.name}}{{?controller.address}}, {{controller.address}}{{/controller.address}}. Contact: {{controller.email|in-app Support section}}.

## 1. In short

1. We do **not sell** your data or share it for advertising.
2. We process only what is needed to provide the service, keep it secure and meet legal obligations.
3. Optional permissions (location, contacts) rely on your **explicit consent** and can be withdrawn at any time ([Explicit Consent](/legal/explicit-consent)).
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
| **Notification inbox and preferences** | Notifications | Contract | Read 90 days, unread 365 days |
| **Device push token (FCM):** token, platform, app version, language, last seen | Push notifications | Contract; explicit consent (notification permission) | Removed after 60 days unseen; on logout/deletion |
| **Device and IP records:** non-reversible HMAC digest of device identifier, platform, app version, IP, last seen and event type | Security, abuse prevention, ban evasion | Legitimate interest; legal obligation | Default **90 days**; ban records while a ban lasts |
| **Usage events (analytics):** screen, event name, limited values, time | Improving the service; reports are aggregated | Legitimate interest | **180 days** |
| **Support, feedback, appeals, reports** | Handling requests, moderation | Contract; legitimate interest; legal obligation | Texts scrubbed on account deletion; public (logged-out) tickets 365 days |
| **Blocks and moderation records** | Safety and moderation | Legitimate interest; legal obligation | Moderation trail kept anonymously |
| **Administrator action and message-access logs** | Accountability | Legitimate interest; legal obligation | Tamper-resistant; for legal/audit period |
| **Agreement acceptances:** document, version, time | Proof of acceptance | Legal obligation; legitimate interest | Kept after account deletion |
| **E-mail queue:** recipient, subject, status | Verification, reset and security e-mails | Contract | Sent/failed entries deleted after 30 days |
| **Contact matching:** SHA-256 digests of e-mails in your address book | Finding people you know | **Explicit consent** | **Not stored or logged**; in memory only while the request is processed |
| **Approximate location permission** | Preparation for nearby events/announcements | **Explicit consent** | In the current version location is **not sent to or stored on** our servers |

> **In short:** Device/IP records 90 days, analytics 180 days, notifications 90/365 days, e-mail queue 30 days.

## 3. How messages are stored and who can see them

1. Transit: TLS/WSS. Storage: AES-256-GCM with a separate key per conversation, protected by a master key held in the server environment, not in the database.
2. **Not end-to-end encrypted.** Because we hold the master key, the system can decrypt messages.
3. Authorised administrators may view messages and media for report reviews, security/abuse, and legal requests. The admin view can also show deleted, edited and moderation-hidden messages, view-once photos and messages not delivered because of a block. **Every view is automatically written to a tamper-resistant record before content is shown** (who, whose chat, how many messages, IP, time); if logging fails, content is not shown.
4. "Delete for everyone" hides the message from users; the encrypted copy and previous versions may be retained for security (default indefinite).
5. View-once photos: recipient sees once; the encrypted file is kept 365 days (configurable) for administrator review, then deleted. No absolute guarantee against screenshots.
6. Push previews: by default message text is not shown in push notifications; the in-app inbox never stores message content.
7. Photos are validated and re-encoded, EXIF removed; videos are compressed on your device. Image digests are matched against a prohibited-content digest list; images are not analysed automatically.
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
3. **Location:** the app may ask for approximate location, but the current version does not send or store it. If this changes we will update this text and ask for consent again.

## 6. Device/IP records and access bans

Device-identifier digest, platform, app version, IP and time are recorded on registration, login, refresh and requests for security. The raw identifier is not stored. Records are kept **90 days** by default (configurable); if a legal retention duty arises (e.g. Law No. 5651 traffic data) the period may change and this policy will be updated. Access bans (IP, network range, device digest or user) keep reason code, date, optional expiry and notes while the ban lasts; blocked attempts are logged as security records. Requests from anonymising networks may be restricted. You may contest a ban via Support or the appeal feature.

## 7. Account deletion and data export

**Download my data:** Profile > Download my data (JSON, up to 3 per day; deleted messages excluded).

**Account deletion = anonymisation**

| What happens | Data |
|---|---|
| **Deleted** | Push tokens, notification inbox and preferences, bookmarks, feedback votes and event feedback, block list, club application answers, community memberships, chat photos you uploaded |
| **Anonymised** | Name, e-mail, profile, bio, photo; support, feedback, appeal, report and event application texts are scrubbed |
| **Kept (limited)** | Messages and community posts (others' context; author appears anonymous), agreement acceptances, moderation records, anonymous attendance/RSVP counters, administrator action and access logs |
| **Cleaned by time** | Device/IP records (90 days), analytics (180 days), e-mail queue (30 days) |

## 8. Security

One-way password hashes; digests of codes and refresh tokens; 15-minute access tokens; single-use refresh tokens; rate limits; generic responses that do not reveal whether an account exists; encrypted message storage; logged administrator access; validated uploads. No system is perfectly secure; in a breach we notify the Board and affected persons as required.

## 9. Cookies and local storage

No tracking or advertising cookies. See the [Cookie Policy](/legal/cookies).

## 10. Children

The service is not designed for persons under 18; if such a registration is found we may require a legal representative's consent or close the account.

## 11. Your rights, changes, contact

Your KVKK Article 11 rights and the application route (30-day response) are in the [KVKK Notice](/legal/kvkk). We may update this policy; for material changes we ask for re-acceptance. Contact: {{support.email|in-app Support section}}{{?controller.email}} · {{controller.email}}{{/controller.email}}{{?controller.kep}} · KEP: {{controller.kep}}{{/controller.kep}}$c_privacy_en$, TRUE, TRUE);
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

Başvurunun reddedilmesi, cevabın yetersiz bulunması veya süresinde cevap verilmemesi halinde, cevabı öğrendiğiniz tarihten itibaren 30 gün ve her halde başvuru tarihinden itibaren 60 gün içinde **Kişisel Verileri Koruma Kurulu'na şikâyet** hakkınız saklıdır.$c_kvkk_tr$, TRUE, TRUE),
    ('KVKK', 'en', v, $t_kvkk_en$KVKK Privacy Notice$t_kvkk_en$, $c_kvkk_en$*This English text is provided for information only. The Turkish text is authoritative.*

Under Article 10 of the Personal Data Protection Law No. 6698 ("**KVKK**") and the Communiqué on Procedures and Principles of the Obligation to Inform, we inform you how your personal data is processed. Operations requiring explicit consent are requested separately in the [Explicit Consent text](/legal/explicit-consent).

## 1. Data controller

| | |
|---|---|
| Controller | {{controller.name}} |
{{?controller.address}}| Address | {{controller.address}} |{{/controller.address}}
{{?controller.email}}| E-mail | {{controller.email}} |{{/controller.email}}
{{?controller.kep}}| KEP address | {{controller.kep}} |{{/controller.kep}}
{{?controller.verbis}}| VERBİS registry no. | {{controller.verbis}} |{{/controller.verbis}}
| In-app application | Support section{{?support.email}} · {{support.email}}{{/support.email}} |

## 2. Categories of personal data

Identity (name); contact (university e-mail, contact e-mail in support requests); education/professional (faculty, department, year, role); visual (profile photo, chat/post photos and videos); user content (messages, posts, application answers, feedback, support and appeal texts, bio); usage (memberships, attendance, bookmarks, notification and privacy preferences, block list); transaction security (session data, password hash, non-reversible device-identifier digest, IP address, platform, app version, ban records); legal/compliance (agreement acceptances, reports and moderation records, administrator access records). Marketing: not processed. Special categories: not requested; any shared by you inside content is only hosted as you shared it.

## 3. Purposes

Membership and verification; providing news, announcements, events, menu, communities, events, attendance, messaging, search and bookmarks; notifications; support and appeals; security, abuse prevention and moderation; improving the service (aggregate analytics); legal obligations and defence of rights; keeping agreement and consent records.

## 4. Legal bases

| Basis | Examples |
|---|---|
| Art. 5/2-(a) Provided for by law | Information to authorities, mandatory records |
| Art. 5/2-(c) Performance of a contract | Membership, profile, messaging, communities/events, notifications |
| Art. 5/2-(ç) Legal obligation | Acceptance records, legal requests |
| Art. 5/2-(e) Establishment, exercise or protection of a right | Moderation trail, evidence for disputes |
| Art. 5/2-(f) Legitimate interest | Security, device/IP records, rate limiting, administrator access audit, analytics |
| Art. 5/1 Explicit consent | Optional: contact matching, location, push notifications, optional profile visibility |

## 5. Transfers

| Recipient group | Data | Purpose | Domestic / abroad |
|---|---|---|---|
| Hosting and infrastructure providers (processors) | Service data (messages encrypted) | Hosting | {{hosting.location|Notified separately by the controller}} |
| E-mail delivery provider (processor) | Recipient address, content | Verification/reset/security e-mails | {{hosting.location|Provider's country}} |
| Google LLC (Firebase Cloud Messaging) and Apple Inc. (APNs) | Push token, notification title/short text, target, platform | Push delivery | **Abroad** |
| Competent public authorities | Data within the request | Legal obligation | Domestic |
| University units / authorised administrators | Data needed for moderation, support, security | Administration | Domestic |

**Transfer abroad (Art. 9).** Push delivery transfers your device token and notification content abroad via Firebase/APNs. This relies on your **explicit consent given through the notification permission** and/or adequacy/appropriate-safeguard mechanisms (e.g. standard contract) under Article 9 and the Board's rules. Without notification permission you receive no push notifications but the in-app inbox and other services continue. You can withdraw consent at any time.

## 6. Method of collection

Electronically through the app and website: registration/profile forms, messaging and content, support forms, technical communication of your device (IP, device digest, app version), local storage, and (if you allow) contact matching requests. News and menu content comes from public sources without personal data.

## 7. Retention

Data is kept for the time required by the purpose and applicable law, then deleted, destroyed or anonymised. Main periods: pending registration 1 hour; verification code 10 minutes; refresh token at most 30 days; read notifications 90 days, unread 365; push token after 60 days unseen; device/IP records 90 days; analytics 180 days; e-mail queue 30 days; view-once photo encrypted copy 365 days; public support request 365 days. See [Retention](/legal/retention).

## 8. Administrator access to messages (transparency)

Messages are stored encrypted but the system is not end-to-end encrypted. Authorised administrators may view messages and media for report review, security, abuse and legal requests; every access is automatically recorded in a tamper-resistant log. Legal basis: legitimate interest and legal obligation. See the [Privacy Policy](/legal/privacy) section 3.

## 9. Automated decisions

No decision with legal effect is made solely by automated means. Accumulating violations only generates a **recommendation** to an administrator, who decides on suspension. Rate limits and prohibited-content digest checks are automated security measures.

## 10. Your rights (Art. 11)

You may apply to learn whether your data is processed; request information; learn the purpose and whether it is used accordingly; know recipients at home and abroad; request correction; request deletion or destruction under Article 7; request notification of those operations to third parties; object to an adverse result arising from exclusively automated analysis; and claim compensation for damage from unlawful processing. In-app shortcuts: profile and privacy settings, **Download my data**, **Delete account**.

## 11. How to apply

1. **In-app:** create a Support request titled "Personal data request".
2. **Written:** wet-signed petition{{?controller.address}} to {{controller.address}}{{/controller.address}}, by hand or notary.
{{?controller.kep}}3. **KEP:** to {{controller.kep}} with a secure electronic signature.{{/controller.kep}}
{{?controller.email}}4. **E-mail:** to {{controller.email}} from your registered university address.{{/controller.email}}

State your name, identifying information, notification address and request. We may ask for further information to verify identity. We answer free of charge **within 30 days at the latest**; if the action needs a cost, the Board's tariff may be charged. If your application is rejected, the reply is insufficient or not given in time, you may complain to the **Personal Data Protection Board** within 30 days of learning the reply and in any case within 60 days of applying.$c_kvkk_en$, TRUE, TRUE);
END
$do_kvkk$;

DO $do_community_rules$
DECLARE
    v INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = 'COMMUNITY_RULES';
    UPDATE legal_document SET active = FALSE WHERE type = 'COMMUNITY_RULES' AND active;
    INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
    ('COMMUNITY_RULES', 'tr', v, $t_community_rules_tr$Topluluk Kuralları$t_community_rules_tr$, $c_community_rules_tr$BÜ Kampüs, Bingöl Üniversitesi öğrencileri ve personeli için güvenli ve saygılı bir ortamdır. Bu kurallar, [Kullanım Koşulları](/legal/terms) ile birlikte bağlayıcıdır. Kuralların amacı cezalandırmak değil, herkesin rahat kullanabilmesini sağlamaktır.

## 1. Temel ilke

Başkasına yüz yüze söylemeyeceğiniz bir şeyi yazmayın; paylaştığınız her içerikten siz sorumlusunuz.

## 2. Yasaklı davranışlar ve örnekler

| Kural | Yasak olanlar (örnekler) | Sorun değil |
|---|---|---|
| **Taciz, tehdit, zorbalık** | Israrlı ve istenmeyen mesajlar, tehdit, şantaj, aşağılama, bir kişiyi hedef alan toplu yönlendirme | Nazik bir şekilde fikir ayrılığı belirtmek |
| **Nefret ve ayrımcılık** | Etnik köken, din, mezhep, cinsiyet, engellilik, yönelim, bölge veya fakülte temelli aşağılama | Saygılı bir tartışma |
| **Müstehcenlik ve şiddet** | Cinsel içerik, çıplaklık, şiddet görüntüleri, kendine zarar vermeyi özendirme | Eğitsel/sağlık içerikli bilgilendirme |
| **Spam ve dolandırıcılık** | Tekrarlayan toplu mesaj, izinsiz reklam, "tıkla kazan", sahte bağış/ilan, zincir mesaj | Topluluğunuzun etkinlik duyurusu |
| **Kimlik taklidi** | Başkası, öğretim üyesi, kulüp veya kurum gibi davranmak; sahte hesap | Takma ad kullanmak yerine gerçek adınızı kullanın; profil açıklamasında şaka/parodi belirtin |
| **Kişisel veri paylaşımı** | Başkasının telefon, adres, kimlik, fotoğraf, özel yazışma veya ekran görüntüsünü izinsiz paylaşmak; "doxxing" | Kendi bilgilerinizi bilerek paylaşmak |
| **Ders ve sınav dürüstlüğü** | Sınav sorusu/cevap anahtarı satışı veya paylaşımı, kopya organizasyonu, ödev satışı, yoklamayı başkası adına vermek | Ders notlarını kendi emeğinizle paylaşmak, çalışma grubu kurmak |
| **Etkinlik ve kulüp yönetimi** | Yanıltıcı etkinlik bilgisi, sahte katılım, üyelerden izinsiz ücret/veri toplamak, yetkiyi kötüye kullanmak, üyeleri keyfi dışlamak | Kuralları açık şekilde duyurarak etkinlik düzenlemek |
| **Hukuka aykırı içerik** | Suça teşvik, uyuşturucu, silah ticareti, terör propagandası, çocuk istismarı (ağır ihlal: doğrudan askıya alma ve yetkili makamlara bildirim) | — |
| **Teknik kötüye kullanım** | Bot, toplu tarama, rehber/kullanıcı dizinini toplamak, güvenlik açığı sömürmek, yasak/engel dolanmak (yeni hesap, VPN) | Hataları Destek'e bildirmek |
| **Telif ihlali** | Başkasının eserini izinsiz paylaşmak | Kaynak göstererek kısa alıntı |

## 3. Etkinlik ve kulüp yöneticileri için ek kurallar

1. Etkinlik bilgileri (yer, tarih, ücret, kontenjan) doğru olmalı; değişiklik ve iptaller zamanında duyurulmalı.
2. Katılımcı bilgilerini yalnızca etkinlik amacıyla kullanın; yoklama kayıtlarını paylaşmayın.
3. Yoklama QR kodlarını yalnızca etkinlik yerinde ve süresinde kullanın.
4. Yönetici yetkilerinizi devrederken yeni yöneticiyi bilgilendirin; üyelerin sohbet odalarında Topluluk Kurallarını uygulayın.

## 4. Mesajlaşma ve gizlilik

1. Mesajlarınız şifreli saklanır ancak uçtan uca şifreli değildir; şikâyet incelemesinde yetkili yöneticiler görüntüleyebilir (her erişim kayda alınır).
2. Tek gönderimlik fotoğrafın ekran görüntüsü alınmasına karşı mutlak garanti yoktur; hassas görselleri paylaşmayın.
3. İstemediğiniz kişiyi **engelleyebilirsiniz**; engellenen kişinin mesajları size iletilmez.

## 5. Nasıl bildirilir?

1. Kullanıcı, mesaj, gönderi, topluluk veya etkinlik üzerinde **Bildir** seçeneğini kullanın, nedeni seçin ve isterseniz kısa bir not ekleyin.
2. Acil/ağır durumlarda (tehdit, istismar) ayrıca Destek bölümünden bize yazın ve gerekirse kolluk kuvvetlerine başvurun.
3. Hukuka aykırı içerik veya telif bildirimleri için [İçerik Bildirimi ve Kaldırma](/legal/content-removal) usulünü izleyin.
4. Asılsız veya art niyetli raporlar rapor yapma yetkinizi kısıtlayabilir. Günlük rapor sayısı sınırlıdır.

## 6. Yaptırım basamakları

| Basamak | Ne olur? |
|---|---|
| 1. İçerik işlemi | İçerik kaldırılır veya gizlenir; size uygulama içi bildirim yapılabilir |
| 2. Uyarı ve ihlal kaydı | İhlal hesabınıza kaydedilir. 180 gün içinde çözülmüş 3 ihlalde yöneticiye askıya alma **önerisi** düşer |
| 3. Geçici askıya alma | Süreli olarak hesabınız kullanılamaz |
| 4. Kalıcı kapatma | Hesap kalıcı olarak kapatılır |
| 5. Erişim engeli | Gerekirse IP, ağ aralığı, cihaz veya kullanıcı bazlı engel uygulanır; yeni hesap açarak engel dolanılamaz |

Ağır ihlallerde (ör. çocuk istismarı, ciddi tehdit, terör) basamaklar atlanabilir ve yetkili makamlara bildirim yapılabilir. Kararlar bir yönetici tarafından, olayın bağlamı dikkate alınarak verilir.

## 7. İtiraz

1. Bir kararın hatalı olduğunu düşünüyorsanız uygulamadaki **itiraz** özelliğinden veya Destek bölümünden, olayı ve gerekçenizi yazarak başvurun (günde en fazla 5 itiraz).
2. İtirazınız bir yönetici tarafından yeniden değerlendirilir; sonuç size bildirilir. Hatalı bulunan işlemler geri alınır (içerik yeniden yayına alınır, askı kaldırılır, ihlal kaydı geri çekilir).
3. İtiraz sonucuna rağmen mevzuattan doğan haklarınız (mahkemeye başvuru dahil) saklıdır.

> **Özetle:** Saygılı olun, yasa dışı veya zarar verici içerik paylaşmayın, başkasının verisini izinsiz paylaşmayın. Gördüğünüz ihlali bildirin; verilen bir karara itiraz edebilirsiniz.$c_community_rules_tr$, TRUE, TRUE),
    ('COMMUNITY_RULES', 'en', v, $t_community_rules_en$Community Rules$t_community_rules_en$, $c_community_rules_en$*This English text is provided for information only. The Turkish text is authoritative.*

BÜ Kampüs is a safe and respectful space for Bingöl University students and staff. These rules bind you together with the [Terms of Use](/legal/terms).

## 1. Basic principle

Do not write what you would not say face to face; you are responsible for everything you share.

## 2. Prohibited conduct, with examples

| Rule | Not allowed (examples) | Fine |
|---|---|---|
| **Harassment, threats, bullying** | Persistent unwanted messages, threats, blackmail, humiliation, directing groups at a person | Politely disagreeing |
| **Hate and discrimination** | Demeaning people for ethnicity, religion, sect, gender, disability, orientation, region or faculty | Respectful debate |
| **Obscenity and violence** | Sexual content, nudity, violent imagery, encouraging self-harm | Educational/health information |
| **Spam and fraud** | Repeated bulk messages, unsolicited ads, fake fundraising/listings, chain messages | Announcing your community's event |
| **Impersonation** | Posing as another person, lecturer, club or institution; fake accounts | Clearly labelled parody |
| **Sharing personal data** | Posting others' phone, address, ID, photos, private chats or screenshots without consent; doxxing | Sharing your own details knowingly |
| **Academic integrity** | Selling/sharing exam questions or answer keys, organising cheating, selling assignments, giving attendance for someone else | Sharing your own notes, forming study groups |
| **Event and club management** | Misleading event information, fake attendance, collecting fees/data without permission, abusing authority, arbitrary exclusion | Organising events with clear rules |
| **Unlawful content** | Inciting crime, drugs, weapons trade, terror propaganda, child abuse (severe: direct suspension and report to authorities) | — |
| **Technical abuse** | Bots, scraping, harvesting the user directory, exploiting vulnerabilities, evading bans (new accounts, VPN) | Reporting bugs to Support |
| **Copyright infringement** | Sharing others' works without permission | Short quotes with attribution |

## 3. Extra rules for event and club managers

Keep event details accurate and announce changes in time; use participant information only for the event and do not share attendance records; use attendance QR codes only at the event place and time; when handing over management, inform the new manager and apply these rules in member chat rooms.

## 4. Messaging and privacy

Messages are stored encrypted but not end-to-end; authorised administrators may view them during report reviews (every access is logged). There is no absolute guarantee against screenshots of view-once photos. You can **block** anyone; blocked users' messages are not delivered to you.

## 5. How to report

1. Use **Report** on a user, message, post, community or event, pick a reason and optionally add a note.
2. For urgent or severe cases write to Support and contact law enforcement if needed.
3. For unlawful content or copyright, follow [Content Notice and Removal](/legal/content-removal).
4. Baseless or bad-faith reports may restrict your reporting. Daily reports are limited.

## 6. Sanction ladder

| Step | What happens |
|---|---|
| 1. Content action | Content removed or hidden; you may be notified |
| 2. Warning and violation record | Recorded on your account; 3 resolved violations within 180 days prompt a suspension **recommendation** to administrators |
| 3. Temporary suspension | Account unusable for a period |
| 4. Permanent closure | Account closed permanently |
| 5. Access ban | IP, network range, device or user ban where necessary; cannot be evaded by new accounts |

Severe violations may skip steps and be reported to authorities. Decisions are made by an administrator considering context.

## 7. Appeals

Use the in-app **appeal** feature or Support (up to 5 appeals per day), describing the event and your reasons. An administrator re-reviews and informs you; mistaken actions are reversed. Your statutory rights remain reserved.

> **In short:** Be respectful, do not share unlawful or harmful content or others' data without consent, report violations, and appeal decisions you believe are wrong.$c_community_rules_en$, TRUE, TRUE);
END
$do_community_rules$;

DO $do_explicit_consent$
DECLARE
    v INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = 'EXPLICIT_CONSENT';
    UPDATE legal_document SET active = FALSE WHERE type = 'EXPLICIT_CONSENT' AND active;
    INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
    ('EXPLICIT_CONSENT', 'tr', v, $t_explicit_consent_tr$Açık Rıza Metni$t_explicit_consent_tr$, $c_explicit_consent_tr$Bu metin, yalnızca **isteğe bağlı** özelliklerle ilgilidir. Aşağıdaki izinlerin hiçbiri hesap açmak veya uygulamanın temel özelliklerini kullanmak için zorunlu değildir. Her bir izni **ayrı ayrı**, özgür iradenizle verirsiniz; vermemeniz size herhangi bir yaptırım getirmez, hizmetten yararlanmanıza engel olmaz. Verdiğiniz her izni istediğiniz zaman geri alabilirsiniz.

Veri sorumlusu: {{controller.name}}. Bu metin, 6698 sayılı Kanun'un 3. ve 5/1. maddeleri uyarınca "belirli bir konuya ilişkin, bilgilendirmeye dayanan ve özgür iradeyle açıklanan rıza" niteliğindedir; ayrıntılı bilgilendirme için [KVKK Aydınlatma Metni](/legal/kvkk) ve [Gizlilik Politikası](/legal/privacy) okunmalıdır.

## Madde 1. Rehber eşleştirme

| | |
|---|---|
| **Ne yapılır?** | Cihaz rehberinizdeki kişilerin e-posta adreslerinin **SHA-256 özeti** alınır ve tanıdıklarınızın uygulamada olup olmadığını bulmak için sunucuya gönderilir. |
| **Hangi veri?** | Yalnızca e-posta özetleri (en çok 500 adet / istek). Ad, telefon numarası veya e-posta adreslerinin kendisi **gönderilmez**. |
| **Saklama** | Sunucu özetleri **saklamaz ve kayda geçirmez**; yalnızca isteğin işlenmesi sırasında bellekte kullanır. Eşleşen kullanıcılar (gizlilik ayarlarına uygun alanlarla) size gösterilir. |
| **Amaç** | Rehberinizde tanıdığınız kişileri bulmak ve onlarla bağlantı kurmayı kolaylaştırmak. |
| **Aktarım** | Üçüncü kişilere veya yurt dışına aktarılmaz. |
| **Önemli** | Rehberinizdeki kişilerin e-posta adreslerinin özetleri onların verisidir; yalnızca tanıdıklarınızı bulma amacıyla kullanın. Kötüye kullanımı önlemek için saatlik istek sınırı vardır. |
| **Geri alma** | Cihaz ayarlarından rehber iznini kapatın veya uygulamada İzinler > Rehber seçeneğini kapatın. Geri alma anından sonra rehber özetleri gönderilmez. |

**Onay:** Rehberimdeki e-posta adreslerinin SHA-256 özetlerinin, yukarıda belirtilen amaçla işlenmesine açık rıza veriyorum. (Ayrı onay kutusu / sistem izni ile verilir.)

## Madde 2. Yaklaşık konum

| | |
|---|---|
| **Ne yapılır?** | Uygulama, yakındaki etkinlik ve duyuruları gösterme özelliği için cihazınızdan **yaklaşık konum** izni isteyebilir. |
| **Mevcut durum** | Bu sürümde konum bilginiz **sunucuya gönderilmez ve saklanmaz**; izin yalnızca cihaz üzerinde kullanıma hazırlıktır. |
| **Gelecekte** | Konumun sunucuda işlenmesi gerekirse bu metin güncellenir, hangi amaçla ne kadar süre saklanacağı belirtilir ve **yeniden açık rızanız** alınır. |
| **Geri alma** | Cihaz ayarlarından konum iznini kapatın veya uygulamada İzinler > Konum. |

**Onay:** Yaklaşık konumumun, yukarıda belirtilen amaçla kullanılmasına açık rıza veriyorum.

## Madde 3. Anlık bildirimler ve yurt dışına aktarım

| | |
|---|---|
| **Ne yapılır?** | Mesaj, etkinlik hatırlatması, duyuru, moderasyon sonucu gibi bildirimleri cihazınıza anlık olarak göndermek için cihaz bildirim anahtarınız işlenir. |
| **Hangi veri?** | Cihaz bildirim anahtarı (FCM), platform (Android/iOS), uygulama sürümü, dil, bildirim başlığı ve kısa metni, hedef bilgisi. Mesaj metni, ayar açılmadıkça bildirimde yer almaz. |
| **Kimlere aktarılır?** | Google LLC (Firebase Cloud Messaging) ve iOS için Apple Inc. (APNs). Bu hizmet sağlayıcıların sunucuları **yurt dışındadır**. |
| **Yurt dışı aktarım** | Bu aktarım, Kanun'un 9. maddesi kapsamında açık rızanıza (ve varsa yeterli koruma/uygun güvence mekanizmalarına) dayanır. Yurt dışındaki alıcıda koruma düzeyinin Türkiye'dekiyle aynı olmayabileceğini kabul ettiğinizi beyan edersiniz. |
| **Tercihleriniz** | Bildirim türlerini ve **sessiz saatleri** (varsayılan 22:00-07:00, kapalı) ayarlardan değiştirebilirsiniz. |
| **Saklama** | 60 gün görülmeyen cihaz anahtarı gece temizlenir; çıkışta veya hesap silinince silinir. |
| **Geri alma** | Cihaz ayarlarından bildirim iznini kapatın veya uygulamada Ayarlar > Bildirimler. Bildirim izni olmasa da uygulama içi bildirim kutusu çalışır. |

**Onay:** Anlık bildirim almak amacıyla cihaz bildirim anahtarımın ve bildirim içeriğinin yurt dışındaki Google Firebase/Apple altyapısına aktarılmasına açık rıza veriyorum.

## Madde 4. İsteğe bağlı profil bilgilerinin yayımı

Fakülte, bölüm, sınıf, biyografi, profil fotoğrafı ve e-posta alanlarını, diğer kullanıcılara gösterip göstermeyeceğinizi **alan bazında** Profil > Gizlilik ayarlarından belirlersiniz. Bu alanları görünür yaparak ilgili bilgilerin diğer kullanıcılara gösterilmesine rıza vermiş olursunuz; görünürlüğü kapattığınızda bilgi diğer kullanıcılara gösterilmez.

## Rızanın geri alınması

1. Her izin, verildiği yoldan (cihaz ayarları veya uygulamadaki İzinler ve Ayarlar ekranı) **kolayca ve ücretsiz** geri alınabilir.
2. Rızanın geri alınması, geri alma anına kadar yapılan işlemlerin hukuka uygunluğunu etkilemez.
3. Tüm kişisel verilerinizin silinmesini isterseniz hesabınızı kapatabilir veya [KVKK Aydınlatma Metni](/legal/kvkk) başvuru yollarını kullanabilirsiniz.
4. Rıza vermemeniz veya geri almanız halinde, yalnızca ilgili isteğe bağlı özellik (rehber eşleştirme, konum, anlık bildirim) kullanılamaz.

> **Özetle:** Rehber eşleştirme, konum ve anlık bildirim izinleri isteğe bağlıdır, ayrı ayrı verilir ve her an geri alınır. Rehberden yalnızca e-posta özetleri gönderilir ve saklanmaz; konum şu an sunucuya gitmez; anlık bildirimler Google Firebase/Apple (yurt dışı) üzerinden iletilir.$c_explicit_consent_tr$, FALSE, TRUE),
    ('EXPLICIT_CONSENT', 'en', v, $t_explicit_consent_en$Explicit Consent$t_explicit_consent_en$, $c_explicit_consent_en$*This English text is provided for information only. The Turkish text is authoritative.*

This text concerns **optional** features only. None of the permissions below is required to open an account or use the core features. You give each one **separately** and freely; refusing has no penalty, and you can withdraw any permission at any time.

Controller: {{controller.name}}. This is consent "relating to a specific subject, based on information and given with free will" under Articles 3 and 5/1 of Law No. 6698. Read the [KVKK Notice](/legal/kvkk) and [Privacy Policy](/legal/privacy) for details.

## Item 1. Contact matching

| | |
|---|---|
| What happens | SHA-256 digests of the e-mail addresses in your address book are sent to the server to find people you know who use the app. |
| Data | E-mail digests only (up to 500 per request). Names, phone numbers or the addresses themselves are **not sent**. |
| Retention | The server does **not store or log** the digests; they exist in memory only while the request is processed. Matching users are shown according to their privacy settings. |
| Transfers | None to third parties or abroad. |
| Note | The digests concern other people; use only to find acquaintances. An hourly request limit applies. |
| Withdrawal | Turn off the contacts permission in device settings or Permissions > Contacts in the app. |

**Consent:** I give explicit consent to processing SHA-256 digests of e-mails in my address book for the purpose stated above.

## Item 2. Approximate location

| | |
|---|---|
| What happens | The app may request **approximate location** for a nearby events/announcements feature. |
| Current status | In this version your location is **not sent to or stored on** the server. |
| In future | If server-side processing becomes necessary, this text will be updated and **new explicit consent** requested. |
| Withdrawal | Device settings or Permissions > Location. |

**Consent:** I give explicit consent to the use of my approximate location for the purpose stated above.

## Item 3. Push notifications and transfer abroad

| | |
|---|---|
| What happens | Your device push token is processed to deliver real-time notifications. |
| Data | Push token (FCM), platform, app version, language, notification title/short text, target. Message text is not included unless a setting is enabled. |
| Recipients | Google LLC (Firebase Cloud Messaging) and, for iOS, Apple Inc. (APNs), whose servers are **abroad**. |
| Transfer abroad | Based on your explicit consent (and, where applicable, appropriate safeguards) under Article 9. You acknowledge that protection abroad may differ from that in Türkiye. |
| Your settings | Notification types and **quiet hours** (default 22:00-07:00, off) can be changed in Settings. |
| Retention | Tokens unseen for 60 days are cleaned nightly; deleted on logout or account deletion. |
| Withdrawal | Device settings or Settings > Notifications. The in-app inbox works without push permission. |

**Consent:** I give explicit consent to transferring my push token and notification content to Google Firebase/Apple infrastructure abroad to receive push notifications.

## Item 4. Publishing optional profile fields

You decide **field by field** (Profile > Privacy) whether faculty, department, year, bio, photo and e-mail are visible to other users. Making a field visible means you consent to showing it; turning it off hides it.

## Withdrawing consent

1. Each permission can be withdrawn **easily and free of charge** where it was given.
2. Withdrawal does not affect the lawfulness of processing before it.
3. To delete all your data, close your account or use the routes in the KVKK Notice.
4. If you refuse or withdraw, only the related optional feature is unavailable.

> **In short:** Contacts, location and push are optional, separate and revocable at any time. Only e-mail digests leave your contacts and are not stored; location is not sent today; push goes through Google Firebase/Apple (abroad).$c_explicit_consent_en$, FALSE, TRUE);
END
$do_explicit_consent$;

DO $do_cookies$
DECLARE
    v INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = 'COOKIES';
    UPDATE legal_document SET active = FALSE WHERE type = 'COOKIES' AND active;
    INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
    ('COOKIES', 'tr', v, $t_cookies_tr$Çerez ve Yerel Depolama Politikası$t_cookies_tr$, $c_cookies_tr$Bu politika, BÜ Kampüs web sitesinin ve yönetim panelinin tarayıcınızda neler sakladığını açıklar. Mobil uygulama çerez kullanmaz; mobil verileri için [Gizlilik Politikası](/legal/privacy) geçerlidir.

## 1. Kısaca

1. Sitemiz **reklam, izleme veya profilleme çerezi kullanmaz.** Üçüncü taraf analitik/reklam betikleri yüklenmez.
2. Yalnızca siteyi çalıştırmak ve tercihlerinizi hatırlamak için gerekli **zorunlu yerel depolama** kullanılır. Zorunlu depolama için ayrıca rıza gerekmez (ilgili bilgi yalnızca bilgilendirme amacıyla verilmektedir).
3. Tarayıcı ayarlarından yerel depolamayı silebilir veya engelleyebilirsiniz; bu durumda dil/tema tercihleriniz sıfırlanır ve oturum açmanız gerekebilir.

## 2. Kullandığımız depolama kayıtları

| Ad | Tür | Amaç | Süre | Zorunlu mu? |
|---|---|---|---|---|
| `bu.lang` | localStorage | Seçtiğiniz dili (tr/en/ar) hatırlamak | Siz silene kadar | Evet (işlevsel) |
| `bu.theme` | localStorage | Açık/koyu tema tercihini hatırlamak | Siz silene kadar | Evet (işlevsel) |
| `bu.cookies` | localStorage | Bu bilgilendirmeyi gördüğünüzü hatırlamak | Siz silene kadar | Evet (işlevsel) |
| Erişim ve yenileme anahtarı | sessionStorage | Giriş yapmış oturumunuzu sürdürmek | Sekme/pencere kapanınca silinir | Evet (güvenlik) |
| `bu.admin.*` (yönetim paneli: taslak, kenar çubuğu, yanıt şablonları) | localStorage | Yalnızca yöneticiler için panel kolaylığı | Siz silene kadar | Evet (yalnız yönetici paneli) |

## 3. Çerezler

Şu anda sitemiz bir çerez (cookie) **yerleştirmemektedir**. Barındırma/ağ katmanının teknik olarak gerekli başlıkları dışında tarayıcınıza çerez yazılmaz. İleride bir çerez kullanılırsa bu politika güncellenir; zorunlu olmayan çerezler için önceden onayınız alınır.

## 4. Üçüncü taraflar

Sitede harici analitik, reklam veya sosyal medya takip eklentisi yoktur. Bağlantılar ile gidebileceğiniz üçüncü taraf sitelerin kendi politikaları geçerlidir.

## 5. Tercihlerinizi yönetme

1. Tarayıcınızda "site verilerini temizle" ile yukarıdaki kayıtları silebilirsiniz.
2. Çerez sayfasındaki seçenekle bu bilgilendirme tercihini sıfırlayabilirsiniz.
3. Giriş oturumunuzu sonlandırmak için çıkış yapmanız yeterlidir; anahtarlar sekme kapanınca zaten silinir.

> **Özetle:** Reklam/izleme çerezi yok. Yalnızca dil, tema, bilgilendirme tercihi ve (sekme kapanınca silinen) oturum bilgisi saklanır.

## 6. İletişim

{{support.email|Uygulama içi Destek bölümü}}$c_cookies_tr$, FALSE, TRUE),
    ('COOKIES', 'en', v, $t_cookies_en$Cookie and Local Storage Policy$t_cookies_en$, $c_cookies_en$*This English text is provided for information only. The Turkish text is authoritative.*

This policy describes what the BÜ Kampüs website and admin panel store in your browser. The mobile app does not use cookies; see the [Privacy Policy](/legal/privacy).

## 1. In short

1. We use **no advertising, tracking or profiling cookies** and load no third-party analytics or ad scripts.
2. Only **strictly necessary local storage** is used to run the site and remember your preferences (no consent required; given for information).
3. You can clear or block storage in your browser; language/theme preferences will reset and you may need to sign in again.

## 2. Storage we use

| Name | Type | Purpose | Duration | Necessary? |
|---|---|---|---|---|
| `bu.lang` | localStorage | Remember language (tr/en/ar) | Until you clear it | Yes (functional) |
| `bu.theme` | localStorage | Remember light/dark theme | Until you clear it | Yes (functional) |
| `bu.cookies` | localStorage | Remember you saw this notice | Until you clear it | Yes (functional) |
| Access and refresh token | sessionStorage | Keep your signed-in session | Cleared when the tab/window closes | Yes (security) |
| `bu.admin.*` (admin panel drafts, sidebar, reply templates) | localStorage | Convenience for administrators only | Until you clear it | Yes (admin panel only) |

## 3. Cookies

The site currently sets **no cookies** other than technically necessary headers of the hosting/network layer. If a cookie is added, this policy will be updated and consent obtained first for non-essential ones.

## 4. Third parties

No external analytics, advertising or social tracking. Third-party sites you link to have their own policies.

> **In short:** No ad/tracking cookies. Only language, theme, this-notice preference and a session token (cleared when the tab closes) are stored.

Contact: {{support.email|in-app Support section}}$c_cookies_en$, FALSE, TRUE);
END
$do_cookies$;

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

Kullanıcı, mesaj, gönderi, topluluk veya etkinlik üzerinde **Bildir** seçeneğini kullanın. Bildirimler yetkili yöneticilerce incelenir; ilgili sohbet bağlamı da görülebilir. Bu yol hızlıdır ve Topluluk Kuralları ihlalleri için uygundur.

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

## 7. Kayıt ve gizlilik

Bildirim ve kaldırma kayıtları (içeriğin kendisi değil, işlem özeti ve karar) hesap verebilirlik için moderasyon izi olarak saklanır. Bildirimde verdiğiniz kişisel veriler yalnızca başvurunun değerlendirilmesi için kullanılır.

> **Özetle:** Hukuka aykırı içerik için önce uygulama içindeki **Bildir** özelliğini kullanın; resmi bildirimler için yukarıdaki bilgileri e-posta/Destek/KEP üzerinden iletin. İçerik incelenir, gerekirse kaldırılır; kaldırma kararına itiraz edebilirsiniz.$c_content_removal_tr$, FALSE, TRUE),
    ('CONTENT_REMOVAL', 'en', v, $t_content_removal_en$Content Notice and Removal$t_content_removal_en$, $c_content_removal_en$*This English text is provided for information only. The Turkish text is authoritative.*

This text explains how to notify unlawful content, personality-right violations and copyright infringements (Law No. 5846, FSEK). Under Law No. 5651 the Service is a **hosting provider**: it does not monitor user content in advance but removes unlawful content on a duly submitted notice.

## 1. When to apply

Content you consider unlawful (insult, threat, obscenity, incitement); violation of your personality rights (name, image, private life); copyright infringement; unlawful sharing of your personal data (the [KVKK Notice](/legal/kvkk) application route may also be used).

## 2. Fast route: in-app report

Use **Report** on a user, message, post, community or event. Authorised administrators review it and may see the related chat context. Suitable for Community Rules violations.

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

## 7. Records

Notice and removal records (action summary and decision, not the content) are kept as a moderation trail. Personal data in a notice is used only to assess it.

> **In short:** Use **Report** first; send formal notices with the details above. Content is reviewed and removed if needed; removals can be appealed.$c_content_removal_en$, FALSE, TRUE);
END
$do_content_removal$;

DO $do_retention$
DECLARE
    v INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = 'RETENTION';
    UPDATE legal_document SET active = FALSE WHERE type = 'RETENTION' AND active;
    INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
    ('RETENTION', 'tr', v, $t_retention_tr$Kişisel Veri Saklama ve İmha Politikası (Özet)$t_retention_tr$, $c_retention_tr$Bu özet, kişisel verilerinizin ne kadar süre saklandığını ve süre sonunda ne olduğunu gösterir. Kurum içi ayrıntılı politika bu özetin dayanağıdır. Süreler uygulamanın ayarlarında tanımlıdır; işletici bunları değiştirebilir, değişiklikte bu metin güncellenir.

## 1. İlkeler

1. Veriler, işleme amacı için gerekli süre kadar ve mevzuatın izin verdiği süre boyunca saklanır.
2. Süre dolunca veri otomatik gece işleriyle **silinir**, **yok edilir** veya **anonim** hale getirilir.
3. Yasal bir saklama yükümlülüğü varsa ilgili süre boyunca saklanır.
4. Periyodik imha: otomatik temizleme işleri günlük/saatlik çalışır; kişisel veri imhası kayıt altına alınır.

## 2. Saklama süreleri

| Veri | Süre | Süre sonunda |
|---|---|---|
| Bekleyen kayıt (doğrulanmamış) | 1 saat | Silinir |
| E-posta doğrulama / şifre sıfırlama kodu | 10 dakika (en çok 5 deneme) | Geçersiz olur / silinir |
| Erişim anahtarı | 15 dakika | Geçersiz olur |
| Yenileme anahtarı (özet olarak) | En çok 30 gün; çıkış/şifre değişimi/yeni mobil girişte erken silinir | Silinir |
| Bildirim kutusu | Okunmuş 90 gün, okunmamış 365 gün | Silinir |
| Cihaz bildirim anahtarı | 60 gün görülmezse | Silinir |
| Cihaz kimliği (özet) ve IP kayıtları | 90 gün | Silinir |
| Erişim engeli kaydı | Engel sürdükçe ve denetim için gerekli süre | Silinir / pasifleşir |
| Analitik olaylar | 180 gün | Silinir |
| E-posta kuyruğu (gönderilmiş/başarısız) | 30 gün | Silinir |
| Mesajlar | Hesap açık olduğu sürece; hesap silinse de sohbet bağlamı için kalır (yazar anonim) | Ayarlanırsa süre sonunda silinir |
| Silinen mesajların ve düzenleme geçmişinin şifreli kopyası | Varsayılan süresiz (ayarlanabilir) | Süre ayarlıysa kalıcı silinir |
| Tek gönderimlik fotoğrafın şifreli kopyası | 365 gün (ayarlanabilir) | Silinir; görüntüleme kaydı kalır |
| Sohbette gönderilmemiş (yüklenip bağlanmamış) medya | 24 saat | Silinir |
| Etkinlik sohbet odası | Etkinlik bitiminden 7 gün sonra kapanır | Oda kapanır |
| Herkese açık (girişsiz) destek talebi | 365 gün | Silinir |
| Destek / geri bildirim / itiraz / rapor notları | Hesap silinince metinler temizlenir | Kimliksiz kayıt kalır |
| Sözleşme ve rıza onay kayıtları | Hesap silinse de ispat için | Yasal zamanaşımı sonuna kadar |
| Moderasyon ihlal ve yasak izleri | Hesap silinse de kimliksiz | Güvenlik/ispat süresince |
| Yönetici işlem kaydı ve mesaj erişim kaydı | Değiştirilemez; denetim / yasal süre | Dış arşive aktarılabilir, sonra yok edilir |
| Rehber eşleştirme özetleri | **Saklanmaz** | — |
| Konum | **Sunucuda saklanmaz** (mevcut sürümde gönderilmez) | — |

## 3. Hesap silinince

Hesap silme **anonimleştirmedir**. Silinenler: bildirim cihaz anahtarları, bildirim kutusu ve tercihleri, favoriler, oy ve etkinlik geri bildirimleri, engel listesi, kulüp başvuru yanıtları, topluluk üyelikleri, yüklenen sohbet fotoğrafları. Anonimleştirilenler: ad, e-posta, profil. Korunanlar (kimliksiz/sınırlı): mesajlar ve topluluk gönderileri (başkalarının bağlamı), sözleşme onayları, moderasyon izleri, yönetici kayıtları, anonim etkinlik sayaçları. Cihaz/IP ve analitik kayıtları kendi sürelerinde silinir. Ayrıntı: [Gizlilik Politikası](/legal/privacy).

## 4. Yasal saklama yükümlülükleri

Hizmet sağlayıcı olarak, yürürlükteki mevzuat (özellikle 5651 sayılı Kanun ve ikincil düzenlemeleri) gereği bazı erişim/trafik kayıtlarını belirli süre saklamak zorunda kalabiliriz. Böyle bir yükümlülük doğduğunda ilgili kayıtlar mevzuatta belirtilen süre boyunca saklanır ve bu metin güncellenir. Mevcut sürede cihaz/IP güvenlik kayıtlarının saklama süresi yukarıdaki tabloda belirtilen süredir.

## 5. İmha yöntemleri

Veritabanı kayıtları güvenli silme ile kaldırılır; dosyalar depolamadan silinir; anonimleştirmede kimliği belirleyen alanlar geri döndürülemez şekilde değiştirilir; şifreli verilerde anahtarla birlikte erişim kapatılır. Yedeklerden silinme, yedek döngüsü içinde gerçekleşir.

## 6. Haklarınız

Verilerinizin silinmesini veya anonim hale getirilmesini [KVKK Aydınlatma Metni](/legal/kvkk) bölüm 11'deki yollarla (Destek, yazılı, KEP) isteyebilirsiniz; başvurular en geç 30 gün içinde yanıtlanır.

> **Özetle:** Çoğu teknik kayıt günler veya aylar içinde otomatik silinir; mesajlar ve hukuki ispat kayıtları ise sınırlı biçimde, kimliksiz olarak daha uzun kalabilir. Rehber özetleri ve konum sunucuda saklanmaz.$c_retention_tr$, FALSE, TRUE),
    ('RETENTION', 'en', v, $t_retention_en$Personal Data Retention and Destruction (Summary)$t_retention_en$, $c_retention_en$*This English text is provided for information only. The Turkish text is authoritative.*

This summary shows how long your personal data is kept and what happens afterwards. Periods are defined in application settings and may be changed by the Operator, in which case this text is updated.

## 1. Principles

Data is kept for the time needed for its purpose and as permitted by law, then **deleted**, **destroyed** or **anonymised** by nightly jobs. Where a legal retention duty exists, data is kept for that period.

## 2. Retention periods

| Data | Period | After |
|---|---|---|
| Pending (unverified) registration | 1 hour | Deleted |
| Verification / reset code | 10 minutes (max 5 attempts) | Invalid / deleted |
| Access token | 15 minutes | Expires |
| Refresh token (as digest) | At most 30 days; removed earlier on logout, password change or new mobile login | Deleted |
| Notification inbox | Read 90 days, unread 365 days | Deleted |
| Push token | If unseen for 60 days | Deleted |
| Device identifier digest and IP records | 90 days | Deleted |
| Access-ban record | While the ban lasts and as needed for audit | Deleted / deactivated |
| Analytics events | 180 days | Deleted |
| E-mail queue (sent/failed) | 30 days | Deleted |
| Messages | While the account is open; remain as chat context after deletion (author anonymous) | Deleted if a limit is configured |
| Encrypted copy of deleted messages and edit history | Default indefinite (configurable) | Permanently deleted if a limit is set |
| Encrypted copy of view-once photos | 365 days (configurable) | Deleted; open record remains |
| Uploaded but unattached chat media | 24 hours | Deleted |
| Event chat room | Closes 7 days after the event | Room closed |
| Public (logged-out) support request | 365 days | Deleted |
| Support / feedback / appeal / report notes | Scrubbed when the account is deleted | Anonymous record remains |
| Agreement and consent records | Kept after deletion as proof | Until limitation periods end |
| Moderation violation and ban traces | Kept anonymously after deletion | While needed for security/evidence |
| Administrator action and message-access logs | Tamper-resistant; audit / legal period | May be archived then destroyed |
| Contact matching digests | **Not stored** | — |
| Location | **Not stored on the server** (not sent in the current version) | — |

## 3. When you delete your account

Deletion is **anonymisation**. Deleted: push tokens, inbox and preferences, bookmarks, votes and event feedback, block list, club application answers, community memberships, uploaded chat photos. Anonymised: name, e-mail, profile. Kept (anonymous/limited): messages and community posts (others' context), agreement acceptances, moderation traces, administrator records, anonymous event counters. Device/IP and analytics records are removed within their own periods. See the [Privacy Policy](/legal/privacy).

## 4. Legal retention duties

As a service provider we may be required by law (notably Law No. 5651 and its regulations) to retain certain access/traffic records for a fixed period. If such a duty applies, those records are kept for the legally required period and this text is updated. In the current version, device/IP security records are kept for the period stated above.

## 5. Destruction methods

Database records are deleted securely; files are removed from storage; anonymisation irreversibly replaces identifying fields; for encrypted data, access is closed together with the key. Removal from backups occurs within the backup cycle.

## 6. Your rights

Request deletion or anonymisation through the routes in the [KVKK Notice](/legal/kvkk) section 11; applications are answered within 30 days.

> **In short:** Most technical records are deleted automatically within days or months; messages and legal-proof records may remain longer in limited, anonymous form. Contact digests and location are not stored on the server.$c_retention_en$, FALSE, TRUE);
END
$do_retention$;
