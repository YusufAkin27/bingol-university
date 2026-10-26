-- Sozlesme metinleri 2. surum: urunun gercek davranisiyla uyumlu, yayina hazir metinler (yalnizca tr).
-- V4'teki 1. surumler degistirilmez; burada eski surumler pasife alinir, yeni surumler aktif eklenir.
-- Surum numarasi tum dillerde ortaktir; en/ar ceviri yoksa tr sunulur (LegalService).

UPDATE legal_document SET active = FALSE WHERE lang = 'tr' AND version = 1 AND active;

INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
('TERMS', 'tr', 2, 'Kullanım Koşulları', $terms$1. Kapsam
Bu koşullar, Bingöl Üniversitesi öğrencileri ve personeli için sunulan BÜ Kampüs uygulaması ile web sitesinin ("Hizmet") kullanımını düzenler. Hizmeti kullanarak bu koşulları kabul etmiş sayılırsınız. Kayıt sırasında koşulların kabulü ayrıca istenir ve kabul kaydınız tutulur.

2. Hesap
- Kayıt yalnızca bingol.edu.tr (alt alan adları dahil) uzantılı e-posta adresiyle ve e-posta doğrulamasıyla yapılır.
- Hesap bilgilerinizin doğruluğundan ve şifrenizin güvenliğinden siz sorumlusunuz. Hesabınızı başkasına devredemezsiniz.
- Hizmet, 18 yaşından küçük kullanıcılara özel olarak yönelik değildir. Üniversite öğrencisi veya personeli olmayan kişiler hesap oluşturamaz.

3. Kullanıcı İçerikleri ve Davranış
- Mesaj, topluluk gönderisi, etkinlik, görsel ve geri bildirim gibi paylaştığınız içeriklerden siz sorumlusunuz.
- Hukuka aykırı, tehdit, taciz, nefret söylemi, müstehcen, yanıltıcı veya spam içerik paylaşmak; başkası gibi davranmak yasaktır.
- Topluluk Kuralları bu koşulların ayrılmaz parçasıdır.

4. Mesajlaşma, Kayıtlar ve Yönetici Erişimi
- Mesajlar şifreli olarak iletilir ve saklanır; şifreleme anahtarlarını sunucu yönetir.
- Güvenliğin sağlanması, şikâyetlerin incelenmesi ve yasal yükümlülüklerin yerine getirilmesi amacıyla, yetkili yöneticiler yazılı gerekçeyle sohbet içeriğine erişebilir. Her erişim değiştirilemez bir denetim kaydına yazılır.
- Sildiğiniz veya düzenlediğiniz mesajlar size görünmez olur; ancak güvenlik ve yasal yükümlülükler için saklanmaya devam edebilir.

5. Moderasyon
Kurallara aykırı içerikler kaldırılabilir; hesaplar geçici veya kalıcı olarak askıya alınabilir. Raporlama ve itiraz için uygulamadaki Destek bölümünü veya iletişim sayfasını kullanabilirsiniz.

6. Kaynak İçerikler
Haber, duyuru, etkinlik ve yemek listesi bilgileri Bingöl Üniversitesi'nin resmî sitelerinden derlenir; bu içeriklerin hakları ilgili kuruma aittir. Resmî bilgiler için kaynak sayfa esas alınır.

7. Sorumluluğun Sınırı
Hizmet "olduğu gibi" sunulur; kesintisiz veya hatasız çalışacağı garanti edilmez. Kaynak sitelerdeki değişiklikler veya bakım çalışmaları nedeniyle bilgiler geçici olarak eksik ya da güncel olmayabilir.

8. Hesabın Kapatılması
Hesabınızı uygulamadan ya da hesap silme sayfasından istediğiniz zaman silebilirsiniz; silme işlemi kişisel verilerinizin anonimleştirilmesi anlamına gelir. Koşulları ihlal eden hesaplar askıya alınabilir veya kapatılabilir.

9. Değişiklikler
Koşullar güncellenebilir; önemli değişikliklerde yeniden onayınız istenir. Yürürlük tarihi, bu sayfada gösterilen yayın tarihidir.

10. İletişim
Sorularınız için uygulamadaki Destek bölümünü veya sitedeki İletişim sayfasını kullanabilirsiniz.$terms$, TRUE, TRUE),
('PRIVACY', 'tr', 2, 'Gizlilik Politikası', $privacy$1. Topladığımız Veriler
- Hesap: e-posta adresi, ad-soyad, isteğe bağlı olarak bölüm, sınıf, biyografi ve profil fotoğrafı.
- Kullanım: bildirim tercihleri, engellediğiniz kullanıcılar, raporlar, geri bildirim ve destek talepleri.
- İçerik: gönderdiğiniz mesajlar ve görseller, topluluk gönderileri, etkinlik kayıtları ve yoklama bilgileri.
- Cihaz: bildirim göndermek için cihaz bildirim anahtarı (FCM).
- Kullanım istatistikleri: toplulaştırılmış ve kişisel olarak tanımlanmayacak biçimde tutulan kullanım olayları; en çok 180 gün saklanır.

2. Kullanım Amaçları
Hizmeti sunmak, hesabı doğrulamak, bildirim göndermek, kötüye kullanımı önlemek ve destek sağlamak.

3. Üyelik ve Doğrulama
Üyelik yalnızca bingol.edu.tr uzantılı e-posta adresleriyle mümkündür. Hesabınız, e-posta adresinize gönderilen doğrulama koduyla doğrulanır. Destek taleplerine ve hesabınızla ilgili bildirimlere yanıtlar e-posta ile de iletilebilir.

4. Mesajlar ve Görseller
- Mesajlar iletim sırasında şifrelenir ve sunucuda şifreli olarak saklanır; anahtarları sunucu yönetir.
- Güvenlik, şikâyet incelemesi ve yasal yükümlülükler için yetkili yöneticiler gerekçeli ve kayıt altına alınan bir yöntemle sohbet içeriğine erişebilir. Her erişim değiştirilemez bir denetim kaydına yazılır.
- Sildiğiniz veya düzenlediğiniz mesajlar size görünmez olur; güvenlik ve yasal yükümlülükler için saklanmaya devam edebilir.
- Yüklediğiniz görseller doğrulanır, yeniden boyutlandırılır ve konum gibi gömülü bilgiler (EXIF üst verisi) temizlenerek saklanır.

5. Paylaşım
Verileriniz satılmaz ve reklam amacıyla kullanılmaz. Anlık bildirim için Google Firebase Cloud Messaging hizmeti kullanılır; bu hizmete yalnızca cihaz bildirim anahtarı ve bildirim içeriği iletilir. Yasal yükümlülüklerde yetkili makamlarla paylaşılabilir.

6. Saklama
Verileriniz hesabınız açık olduğu sürece saklanır. Hesabınızı sildiğinizde kişisel verileriniz anonimleştirilir; yasal yükümlülükler ve güvenlik için gereken kayıtlar kimliğiniz çözülemeyecek biçimde tutulabilir.

7. Haklarınız
Verilerinize erişme (Profil > Verilerimi indir), düzeltme, silme ve itiraz haklarınızı KVKK Aydınlatma Metni'nde belirtilen yollarla, ayrıca sitedeki Kişisel Veri Talebi sayfasından (/data-request) kullanabilirsiniz.

8. Çocuklar ve Yaş
Hizmet üniversite öğrencileri ve personeli içindir; 18 yaşından küçük kullanıcılara özel olarak yönelik değildir. Küçük yaşta bir kullanıcıya ait hesap tespit edilirse hesap kapatılabilir.

9. Güvenlik
Şifreler tek yönlü şifrelenerek saklanır; oturumlar kısa ömürlü anahtarlarla yönetilir; iletişim şifreli bağlantı üzerinden yapılır.

10. İletişim
Gizlilikle ilgili sorularınız için sitedeki İletişim sayfasını veya Kişisel Veri Talebi sayfasını kullanabilirsiniz.$privacy$, TRUE, TRUE),
('KVKK', 'tr', 2, 'KVKK Aydınlatma Metni', $kvkk$6698 sayılı Kişisel Verilerin Korunması Kanunu'nun 10. maddesi uyarınca bilgilendirme:

Veri Sorumlusu: Bingöl Üniversitesi (BÜ Kampüs uygulaması ve web sitesi)
İletişim ve başvuru: sitedeki Kişisel Veri Talebi sayfası (/data-request) ve İletişim sayfasında yer alan e-posta adresi

İşlenen Kişisel Veriler: kimlik (ad-soyad), iletişim (e-posta), eğitim bilgisi (bölüm, sınıf), görsel (profil fotoğrafı ve yüklenen görseller), işlem güvenliği (oturum, cihaz bildirim anahtarı, denetim kayıtları), kullanıcı içeriği (mesaj, gönderi, geri bildirim, destek talebi).

İşleme Amaçları: üyelik ve kimlik doğrulama, hizmetin sunulması, bildirim gönderimi, güvenliğin ve kötüye kullanımın önlenmesi, destek taleplerinin yönetimi, yasal yükümlülüklerin yerine getirilmesi.

Mesajlar ve Yönetici Erişimi: Mesajlar şifreli olarak iletilir ve saklanır. Güvenlik, şikâyet incelemesi ve yasal yükümlülükler kapsamında yetkili yöneticiler gerekçeli olarak sohbet içeriğine erişebilir; her erişim değiştirilemez bir denetim kaydına yazılır. Silinen mesajlar kullanıcıya görünmez olur ancak güvenlik ve yasal yükümlülükler için saklanabilir.

Hukuki Sebep: sözleşmenin ifası (m.5/2-c), hukuki yükümlülük (m.5/2-ç), meşru menfaat (m.5/2-f) ve gereken hallerde açık rıza (m.5/1).

Aktarım: Bildirim hizmeti için yurt dışında yerleşik hizmet sağlayıcılara (Google Firebase) cihaz bildirim anahtarı aktarılabilir; yasal talepler halinde yetkili kurum ve kuruluşlarla paylaşılabilir.

Toplama Yöntemi: Uygulama ve web sitesi üzerinden elektronik ortamda.

Saklama: Hesabınız açık olduğu sürece; hesabınızı sildiğinizde kişisel verileriniz anonimleştirilir.

Haklarınız (m.11): verilerinizin işlenip işlenmediğini öğrenme, bilgi talep etme, amacına uygun kullanılıp kullanılmadığını öğrenme, aktarıldığı kişileri bilme, düzeltme, silme/yok etme, itiraz etme ve zararın giderilmesini talep etme.

Başvuru: Taleplerinizi sitedeki Kişisel Veri Talebi sayfasından (/data-request), uygulamadaki Destek bölümünden veya İletişim sayfasındaki e-posta adresinden iletebilirsiniz. Başvurular en geç otuz gün içinde sonuçlandırılır.$kvkk$, TRUE, TRUE),
('COMMUNITY_RULES', 'tr', 2, 'Topluluk Kuralları', $rules$Bingöl Üniversitesi topluluğu saygı ve güven üzerine kuruludur.

1. Saygılı olun: hakaret, taciz, tehdit, ayrımcılık ve nefret söylemi yasaktır.
2. Spam yapmayın: tekrarlayan, reklam amaçlı veya yanıltıcı içerik paylaşmayın.
3. Gizliliğe saygı gösterin: başkalarının özel bilgilerini ve yazışmalarını izinsiz paylaşmayın.
4. Yasa dışı, müstehcen veya şiddet içeren içerik paylaşmayın.
5. Kimliğinizi gizlemeyin: başkası gibi davranmayın.
6. Etkinlik ve toplulukları gerçek amaçlarla açın; yanıltıcı bilgi vermeyin.
7. Kurallara aykırı bir durum görürseniz "Bildir" ile haber verin; istemediğiniz kullanıcıları engelleyebilirsiniz.

Yaptırımlar: içeriğin kaldırılması, uyarı, geçici veya kalıcı hesap askıya alma. İtirazlar için Destek bölümünü kullanın.$rules$, FALSE, TRUE);
