# Play Console: sırayla yapılacaklar (kapalı test)

Bu liste yalnız sizin yapabileceğiniz adımları içerir (hesap, Console formları). Derleme ve imza: [../ANDROID_RELEASE.md](../ANDROID_RELEASE.md). Hazır metin ve cevaplar bu klasördeki diğer dosyalardadır. **Bu adımların hiçbiri henüz yapılmadı.**

## 0. Kapalı test şartı (güncel, doğrulandı 2026-10-29)

Google'ın resmî sayfasına göre (13 Kasım 2023'ten sonra açılmış **kişisel** geliştirici hesapları için): üretime çıkmadan önce uygulamayı en az **12 test kullanıcısı** ile kapalı testte yayınlamanız ve bu kullanıcıların **en az 14 gün kesintisiz** katılmış (opt-in) olması gerekir. 14 günden önce ayrılan kullanıcı sayılmaz; çıkıp yeniden katılanın 14 günü ardışık olmalıdır. Koşullar sağlanınca Dashboard'dan "üretim erişimi için başvuru" yapılır (kapalı testiniz, uygulamanız ve üretime hazırlığınız hakkında sorular cevaplanır). 12'den az kullanıcı ya da yetersiz etkileşim varsa testi sürdürmeniz istenebilir. Kaynak: <https://support.google.com/googleplay/android-developer/answer/14151465>. (Kurumsal/"Organization" hesaplar için bu şart geçerli değildir; siz kişisel hesapla gidiyorsanız geçerlidir.)

Hedef API şartı (aynı gün doğrulandı): yeni uygulama ve güncellemeler **Android 16 (API 36) ya da üstünü** hedeflemeli (31 Ağustos 2026; uzatma talebiyle 1 Kasım 2026). Uygulama `targetSdk=36`. Kaynak: <https://support.google.com/googleplay/android-developer/answer/11926878>.

Pratik sonuç: 12 kişiyi **hemen** toplayın (arkadaş, kulüp üyeleri; hepsinin Play'de kullandığı **Gmail/Google hesabı** gerekir, `bingol.edu.tr` adresi Google hesabı değilse çalışmaz), çünkü 14 gün sayacı kullanıcı katıldığında başlar.

## 1. Geliştirici hesabı
1. <https://play.google.com/console> > hesap oluştur (tek seferlik ücret, kimlik/telefon doğrulaması günler sürebilir; ilk iş olarak başlatın).
2. Kişisel hesapta ad ve adres mağazada herkese görünebilir: [../LEGAL_NOTES.md](../LEGAL_NOTES.md) uyarısını okuyun.

## 2. Uygulamayı oluştur
1. "Uygulama oluştur": ad **BÜ Kampüs** (başlığa üniversite adı/logosu eklemeyin: [README.md](README.md) ilke 1), varsayılan dil Türkçe, "Uygulama", "Ücretsiz".
2. Paket adı AAB'den okunur: **`edu.bingol.bu_kampus`** (ilk yüklemede sabitlenir, sonra değişmez; `google-services.json` içindeki paket adı da aynıdır, uyumlu).
3. **Play App Signing**: ilk AAB yüklenirken kabul edin (yeni uygulamalarda zorunlu). Siz upload anahtarıyla imzalarsınız, Google dağıtım anahtarını tutar.

## 3. Uygulama içeriği (Politika > Uygulama içeriği)
Hepsi için hazır cevaplar: [data_safety.md](data_safety.md), [content_rating.md](content_rating.md).

| Bölüm | Cevap / kaynak |
|---|---|
| Gizlilik politikası | `https://bukampus.com.tr/tr/privacy` (canlıda 200 döndü, 2026-10-29) |
| Uygulama erişimi | Girişli uygulama: inceleyiciye **test hesabı** (e-posta + parola) verin; hesap `bingol.edu.tr` alan adlı olmalı ve doğrulanmış olmalı. Parolayı repoya yazmayın. |
| Reklamlar | Yok |
| İçerik derecelendirme (IARC) | [content_rating.md](content_rating.md); kullanıcı içeriği + sohbet var, raporlama/engelleme var |
| Hedef kitle | 18+ (bkz. content_rating.md "Hedef kitle ve içerik") |
| Veri güvenliği | [data_safety.md](data_safety.md): "Device or other IDs" işaretlenir (FCM belirteci + rastgele uygulama cihaz kimliği), konum **toplanmaz** |
| Hesap silme | Uygulama içinde var; web URL'si: `https://bukampus.com.tr/tr/delete-account` (canlıda 200; sayfa tek sayfa uygulama olduğu için yalnız HTTP kodu doğrulandı, içeriğin tarayıcıda görüntülendiğini siz de bir kez açıp bakın) |
| Haber uygulaması beyanı | Uygulama haber/duyuruyu üniversite sitesinden **derleyip gösterir**; "haber uygulaması" olarak beyan etmeniz gerekirse bağımsız, resmî olmayan olduğunu ve kaynak göstermeyi belirtin |
| COVID-19 / sağlık | Hayır (ilgili değil) |
| Finansal özellikler, sağlık uygulaması, devlet uygulaması | Hayır. **Devlet uygulaması değil** (resmî olmayan kişisel proje) |
| Hassas izinler | `READ_CONTACTS` (rehber eşleştirme, yalnız özet/hash), `READ_MEDIA_IMAGES/VIDEO` (galeri seçici): gerekçe metinleri [data_safety.md](data_safety.md) bölüm 4 |
| Reklam kimliği (AD_ID) | Kullanılmaz: "hayır" |

## 4. Mağaza girişi
1. Metinler: [store_tr.md](store_tr.md) (varsayılan), [store_en.md](store_en.md) (ek dil). Başlık en çok 30, kısa açıklama 80 karakter.
2. Görseller (simge 512x512, öne çıkan 1024x500, telefon ekran görüntüleri): [screenshots.md](screenshots.md). Yalnız sahte tohum hesaplar, üniversite logosu yok.
3. Destek e-postası: `ysufakin23@gmail.com`, web: `https://bukampus.com.tr`.

## 5. Kapalı test sürümü
1. Test > **Kapalı test** > kanal oluştur (varsayılan "Closed testing - Alpha" olur).
2. **Test kullanıcıları**: "E-posta listesi" oluşturun, 12 (tercihen 15+) Google hesabı e-postası ekleyin. Ülke/bölge: Türkiye (+ gerekirse diğerleri).
3. **Yeni sürüm oluştur** > `bu-kampus-1.0.0+1.aab` dosyasını yükleyin (yol: `C:\Users\Toprak Çevik\bu-release\`). Play, upload imzasını kontrol eder; "Debug anahtarıyla imzalı" hatası alırsanız yanlış dosyadır.
4. Sürüm notu (tr/en): [store_tr.md](store_tr.md) "Sürüm notu".
5. İncelemeye gönderin (ilk inceleme birkaç gün sürebilir). Onaylanınca Console "test katılım bağlantısı"nı (opt-in URL) verir.
6. Bağlantıyı test kullanıcılarına gönderin; her biri bağlantıyı açıp **"Tester ol"** demeli ve ardından Play'den kurmalıdır. **14 gün boyunca opt-in kalmaları** istenir (testten çıkmasınlar, uygulamayı kaldırmak sorun değil ama opt-in'i bozmasınlar).
7. Test kullanıcılarına [../DEVICE_TEST_PLAN.md](../DEVICE_TEST_PLAN.md) akışını denemelerini söylemek zorunlu değil, ama geri bildirim toplamak için işe yarar; üretim başvurusunda Google test sırasındaki etkileşimi sorar.

## 6. Üretime çıkış
1. 14 gün ve 12 kullanıcı dolunca Dashboard > "Üretim erişimi için başvur": soruları (test geri bildirimleri, değişiklikler, üretime hazırlık) dürüstçe doldurun.
2. Onaydan sonra Üretim > yeni sürüm (aynı AAB ya da yeni `versionCode`), **aşamalı yayın** (%10 > %50 > %100).
3. Her yeni yüklemede `pubspec.yaml` `version: 1.0.0+N` içinde `N` artırılır.

## 7. Yapılacaklar ve sunucu bağımlılıkları (kullanıcıya özgü)
- **Upload anahtarını yedekleyin:** `C:\Users\Toprak Çevik\bu-secrets\bu-upload-keystore.jks` ve `android-signing.txt` (parolalar içinde). Parola yöneticisi + şifreli çevrimdışı ikinci kopya. OneDrive'a senkronize olan klasöre koymayın.
- **Push gitmesi için** sunucuya Firebase hizmet hesabı kimliği girilmeli (`FCM_CREDENTIALS_JSON`/`FCM_CREDENTIALS_FILE`, [../PUSH_SETUP.md](../PUSH_SETUP.md)); aksi halde uygulama içi bildirim kutusu dolar ama push gelmez. Mağazadan kurulan sürümün gerçek imzası **Play App Signing sertifikasıdır**: Console > Kurulum > Uygulama bütünlüğü'ndeki SHA-1/SHA-256'yı Firebase Android uygulamasına ve (kısıt varsa) Google Cloud API anahtarına ekleyin.
- Test hesabı (inceleyici) ve test kullanıcıları için backend'de `bingol.edu.tr` doğrulamalı hesap gerekir; e-posta gönderimi (`MAIL_ENABLED=true`) canlıda çalışmalıdır, aksi halde doğrulama kodu gelmez.
- Hukuk metinleri taslaktır ([../LEGAL_NOTES.md](../LEGAL_NOTES.md)); yayın öncesi gözden geçirin. Konum izni kaldırıldığı için `privacy_tr.md`/`explicit_consent_tr.md` içindeki konum satırlarının güncellenmesi gerekir.
