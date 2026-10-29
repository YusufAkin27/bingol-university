# Play Console: "Veri güvenliği" formu cevapları

Kaynak gerçekler: [docs/legal/privacy_tr.md](../legal/privacy_tr.md) bölüm 4 (hangi veri/amaç/süre), [ANDROID_RELEASE.md](../ANDROID_RELEASE.md) bölüm 5-6 (izinler), [ENCRYPTION.md](../ENCRYPTION.md), [DATABASE.md](../DATABASE.md). **Form, gizlilik politikasıyla birebir tutarlı olmalıdır**; ikisinden biri değişirse diğeri de güncellenir. Play'in form alanları zamanla değişir: aşağıdaki başlıklar yazıldığı andaki yapıya göredir; Console'da karşılaştığınız ifade farklıysa anlamca eşleştirin. **Bu cevaplar henüz Play Console'a girilmedi** (hesap gerekir).

## 1. Genel sorular

| Soru | Cevap | Not |
|---|---|---|
| Uygulama kullanıcıdan veri topluyor/paylaşıyor mu? | **Evet, topluyor** | |
| Toplanan tüm veri aktarımda şifreli mi? | **Evet** | Üretimde yalnız HTTPS/WSS; Android cleartext kapalı (`ALLOW_INSECURE_API` yalnız elden test) |
| Kullanıcılar verilerinin silinmesini isteyebilir mi? | **Evet** | Uygulama içi "Hesabı sil" (anonimleştirme) + web: `https://bukampus.com.tr/tr/delete-account` (tr/en/ar) ve `.../data-request` |
| Hesap oluşturma yöntemi | Kullanıcı adı yok; **e-posta + parola** (bingol.edu.tr, e-posta kodu doğrulaması) | |
| Hesap silme URL'si (Play "Hesap silme" bölümü) | `https://bukampus.com.tr/tr/delete-account` | Sayfa, silinen/saklanan verilerin tablosunu içerir |
| Bağımsız güvenlik incelemesi (MASA vb.) | **Hayır** | Yalnız iç denetimler ([SECURITY_AUDIT_2026-10-28.md](../SECURITY_AUDIT_2026-10-28.md)); "evet" demeyin |
| Play Families politikası | **Uygulanmaz** | Hedef kitle 18+ (bkz. [content_rating.md](content_rating.md)) |

## 2. Veri türleri (her biri: Toplanıyor? Paylaşılıyor? Zorunlu mu? Amaç)

"Paylaşım" = Play tanımıyla üçüncü taraflara aktarım. **Hizmet sağlayıcılar** (Google Firebase Cloud Messaging bildirim iletimi için; Brevo e-posta iletimi için, ikincisi zaten sunucu tarafıdır) bizim adımıza işlem yapan sağlayıcı olduğundan Play kuralına göre **"paylaşım" sayılmaz**; hiçbir veri reklam/analitik/veri komisyoncusu amacıyla paylaşılmıyor. Hepsi için "Paylaşılıyor: Hayır".

| Play kategorisi / tür | Topl. | Zorunlu | Amaç (Play seçenekleri) | Ayrıntı |
|---|---|---|---|---|
| Kişisel bilgiler > **Ad** | Evet | Evet | Uygulama işlevselliği; Hesap yönetimi | Ad-soyad (görünen ad) |
| Kişisel bilgiler > **E-posta adresi** | Evet | Evet | Uygulama işlevselliği; Hesap yönetimi; İletişim (doğrulama/parola sıfırlama/duyuru) | bingol.edu.tr |
| Kişisel bilgiler > **Kullanıcı kimlikleri** | Evet | Evet | Uygulama işlevselliği; Hesap yönetimi | İç kullanıcı numarası; isteğe bağlı okul numarası, bölüm/fakülte/sınıf (profil alanı) |
| Kişisel bilgiler > Diğer bilgiler | Evet | Hayır | Uygulama işlevselliği | Fakülte/bölüm/sınıf ve benzeri isteğe bağlı profil alanları |
| Mesajlar > **Uygulama içi mesajlar** | Evet | Hayır (özelliği kullanana) | Uygulama işlevselliği | Sohbet metinleri; sunucuda zarf şifreleme (`CRYPTO_MASTER_KEYS`), yönetici erişimi denetim kaydıyla |
| Fotoğraflar ve videolar > **Fotoğraflar** | Evet | Hayır | Uygulama işlevselliği | Profil, gönderi, sohbet görselleri (EXIF/GPS temizlenir, yeniden kodlanır) |
| Fotoğraflar ve videolar > **Videolar** | Evet | Hayır | Uygulama işlevselliği | Sohbet videosu (gönderi videosu özelliği kaldırıldı). Sohbet videosunda dosya içi üst veri temizlenmiyor: bkz. [LEGAL_NOTES.md](../LEGAL_NOTES.md) madde 12 |
| Ses dosyaları > **Ses/ses kayıtları** | Evet | Hayır | Uygulama işlevselliği | Yalnız video kaydının ses kanalı (ayrı sesli mesaj özelliği yok). Video ile birlikte beyan etmek güvenli taraftır |
| Kişiler > **Kişiler** | Evet (geçici) | Hayır | Uygulama işlevselliği (tanıdıkları bul) | Rehber e-postalarının **SHA-256 özeti**; saklanmaz, yalnız istek sırasında bellekte. Play'in "geçici işleme (ephemeral)" istisnası uygulanabilir ama ihtiyatlı yol "toplanıyor, paylaşılmıyor, isteğe bağlı" beyanıdır. Kullanıcı açık izin vermeden okunmaz (READ_CONTACTS) |
| Uygulama etkinliği > **Uygulama etkileşimleri** | Evet | Evet (kapatılamaz) | Analitik; Uygulama işlevselliği | Ekran/olay adı, zaman; **toplulaştırılmış**, ham olaylar 45 gün |
| Uygulama etkinliği > Diğer kullanıcı tarafından oluşturulan içerik | Evet | Hayır | Uygulama işlevselliği | Gönderi metni, kulüp/etkinlik başvuru yanıtları, anket oyu (gizli: kimlik hiçbir uçta gösterilmez), destek/geri bildirim metni |
| Uygulama bilgileri ve performans > **Çökme günlükleri** / **Tanılama** | Evet | Evet (kapatılamaz) | Analitik | Anonim `app_error` olayı: tür, kaynak, sürüm, ekran; mesaj/yığın/kişisel veri yok |
| Cihaz veya diğer kimlikler | Evet | Evet | Uygulama işlevselliği (bildirim); **Dolandırıcılık önleme, güvenlik ve uyumluluk** | (1) FCM belirteci + platform/sürüm/dil. (2) Uygulamaya özel rastgele cihaz kimliği (`X-Device-Id`; IMEI/ANDROID_ID/reklam kimliği **okunmaz**), sunucuda yalnız HMAC özeti, 90 gün. Reklam/izleme için kullanılmaz |
| Konum (yaklaşık/kesin) | **Hayır** | | | İzin yok (kaldırıldı). IP adresi güvenlik günlüğünde 90 gün tutulur; Play bunu "konum" saymaz, gizlilik politikasında açıktır |
| Finansal bilgiler, Sağlık ve fitness, Web geçmişi, SMS/arama, Takvim, Dosyalar ve belgeler | **Hayır** | | | Toplanmaz |

Play formu "isteğe bağlı mı" sorarsa: kullanıcı özelliği hiç kullanmadan uygulamayı kullanabiliyorsa "isteğe bağlı". Zorunlu olanlar: e-posta, ad, kullanıcı kimliği, cihaz kimlikleri/FCM, analitik, çökme günlüğü.

## 3. Silme ve saklama (formdaki açıklama için kısa metin)

> Hesabınızı uygulamadan silebilirsiniz; hesap hemen anonimleştirilir (ad, e-posta, profil, mesaj içerikleri, gönderiler). Cihaz/IP kayıtları 90 gün, ham kullanım olayları 45 gün, bildirimler 30/90 gün, e-posta kuyruğu 7/30 gün sonra silinir. Yedekler (şifreli) en çok birkaç saat tutulur; yedekten geri yükleme olursa silinen hesaplar yeniden anonimleştirilir. Ayrıntı: gizlilik politikası ve `.../delete-account` sayfası.

## 4. Play'in ayrıca isteyebileceği beyanlar (hazırlık)

| Konu | Cevap / hazırlık | Risk |
|---|---|---|
| **Hassas izin beyanı: READ_CONTACTS** | Gerekçe: "rehberdeki kişilerden uygulamayı kullananları bulma; yalnız e-posta özeti (hash) gider, saklanmaz; kullanıcı izin vermezse özellik gizlenir." Tanıtım videosu istenebilir | Play bu izin için genelde form/video ister; reddedilirse özelliği kaldırıp izni silmek yayın yolunu açar |
| **READ_MEDIA_IMAGES / READ_MEDIA_VIDEO** | Play "Foto/video izinleri" politikası: çekirdek işlev değilse **sistem fotoğraf seçici (Photo Picker)** kullanılmalı | **Doğrulanmadı:** sohbet galerisi `photo_manager` ile bu izinleri kullanıyor; Play beyan formu isteyebilir ya da kabul etmeyebilir. Plan B: seçiciyi Photo Picker'a taşımak (`image_picker`) ve izinleri kaldırmak |
| **Hedef kitle** | **Yalnızca 18+** işaretleyin (çocuklara yönelik değil) | Kullanım Koşulları madde 4 18 yaş altına "yasal temsilci izniyle" izin veriyor: [LEGAL_NOTES.md](../LEGAL_NOTES.md) madde 10 avukat sorusu |
| **Reklam** | Reklam yok | |
| **Uygulama erişimi (App access)** | Giriş gerekli: **inceleyici için hazır hesap** (e-posta kodu inceleyicide olmayacağı için) | `bingol.edu.tr` kutusu olan önceden doğrulanmış tek bir hesap açıp kullanıcı adı/parolayı Play "Uygulama erişimi" alanına yazın; hesabı yedeklemeyin/silmeyin. Parolayı bu repoya YAZMAYIN |
| **Kullanıcı tarafından oluşturulan içerik** | Moderasyon: raporla, engelle, otomatik gizleme (3 bağımsız rapor), yönetici incelemesi, uygunsuz ifade filtresi (sohbet hariç), 7/24 değil ama panel + destek | Politika şartları (rapor/engel/sahip iletişimi) uygulamada var |
| **Hesap silme** | Uygulama içi + web URL | |
| **Reklam kimliği** | **Kullanmıyor** ("Reklam kimliği" bildirimi: Hayır) | |
| **Tam ekran niyet / ön plan hizmeti / VPN** | Yok | |
| **Hükümet/sağlık/finans uygulaması mı** | Hayır; **resmî kurum uygulaması değil** (Taklit politikası: açıklamada ve ekranda "resmî değildir" ifadesi var) | Uygulama simgesi/mağaza görselleri üniversite logosu içermemeli; yayından önce simgeyi gözle kontrol edin (`brand/dist`, `mobile/android/app/src/main/res/mipmap-*`) |
