# Gerçek cihaz test planı (Android, hedef 15 dakika)

Amaç: mağazaya (Play kapalı test) göndermeden önce **gerçek bir Android telefonda** uçtan uca çalıştığını tek oturumda doğrulamak. Emülatör bu planın yerine geçmez: R8 küçültme çökmeleri, kamera/QR, gerçek ağ ve push yalnız gerçek cihazda görülür. Bu plan **yazıldı, henüz bir cihazda koşturulmadı** (gerçek cihaz gerektirir); sonuçlar aşağıdaki "Sonuç tablosu"na işlenir.

İlgili: [ANDROID_RELEASE.md](ANDROID_RELEASE.md) (derleme/imza), [LAUNCH_CHECKLIST.md](LAUNCH_CHECKLIST.md) (yayın sırası), [PUSH_SETUP.md](PUSH_SETUP.md), [MOBILE_UI.md](MOBILE_UI.md). Sunucu tarafı canlı denetimi: `BASE=https://... bash scripts/staging-smoke.sh` (telefondan önce çalıştırın).

## 0. Hazırlık (testten önce, ~10 dk, sayılmaz)

1. **Backend ayakta ve https:** `BASE=https://<alan> bash scripts/staging-smoke.sh` tüm maddeler `ok`. Gerçek SMTP (Brevo) açık değilse kayıt kodu gelmez: [MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) bölüm 9.
2. **Sürüm:** release APK/AAB telefona kurulu:
   ```powershell
   # C:\bu_mobile içinde, ortam: ANDROID_RELEASE.md başı
   flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE=https://<alan> --dart-define=APP_VERSION=1.0.0
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```
   Kapalı test paketinden (Play) kuruyorsanız aynısı geçerlidir; **R8 yalnız release'te** çalışır, debug ile test etmeyin.
3. **Hesaplar:** iki gerçek `@bingol.edu.tr` posta kutusu (A ve B; sohbet/etkinlik için) + yönetici paneline erişim (`https://<alan>/admin`). B ikinci bir telefon ya da web/panel yerine geçemez: gerçek zamanlı sohbet için ikinci cihaz (ya da emülatör) gerekir.
4. **Log yakalama (hata raporu için):** bilgisayara USB ile bağlı telefonda ayrı pencerede `adb logcat -v time *:W flutter:V > logcat.txt` çalıştırın. Uygulama içi hata günlüğü kullanıcıya gösterilmez (yerel `error_log.jsonl`); çökme/hata analitik olayı (`app_error`) yöneticiye gider.
5. Telefonda **Geliştirici seçenekleri > Etkinlikleri kaydetme (Don't keep activities)** KAPALI; pil tasarrufu kapalı; saat ve saat dilimi otomatik.

## 1. Zaman çizelgesi (15 dk)

| Dk | Adım |
|---|---|
| 0-3 | T1 Kayıt + e-posta kodu, T2 Giriş/oturum |
| 3-5 | T3 Profil |
| 5-8 | T4 Gönderi, T5 Kulüp/etkinlik/QR |
| 8-11 | T6 Sohbet (gerçek zamanlı), T7 Push |
| 11-15 | T8 Çevrimdışı, T9 Arapça RTL, T10 Koyu tema, T11 Yavaş ağ |

Her adımda **Geçti / Kaldı / Atlandı** işaretleyin. Bir adım kalırsa duraksamayın, "Hata nasıl raporlanır" bölümüne göre kaydedip devam edin.

## 2. Test maddeleri

### T1. Kayıt + e-posta kodu (hesap A)
1. İlk açılış: izin/karşılama ekranları, sözleşme (Kullanım Koşulları, Gizlilik, Açık Rıza) kabul kutusu. Beklenen: kabul edilmeden "Devam" etkin olmaz.
2. `@bingol.edu.tr` dışı bir e-posta yazın. Beklenen: anlaşılır hata, kayıt başlamaz.
3. Gerçek adresle kayıt başlatın, şifre 8+ karakter. Beklenen: **60 sn içinde** 6 haneli kod e-postası (gelen kutusu; spam'e düşerse bunu "Kaldı" yazın ve [MAIL_DELIVERABILITY.md](MAIL_DELIVERABILITY.md) bölüm 6'ya bakın).
4. Yanlış kodu girin. Beklenen: hata, kalan deneme; doğru kod: giriş yapılıp ana ekran.
5. Beklenen yan etki: e-postadaki dil ayarlı dildedir (tr).

### T2. Giriş / oturum
1. Çıkış yapın, aynı bilgilerle girin. Yanlış parola: genel hata (hesap varlığı sızmaz).
2. Uygulamayı **görev yöneticisinden kapatıp** yeniden açın. Beklenen: oturum korunur, açılış kapısı (bakım/güncelleme/sözleşme) varsa gösterilir.
3. "Şifremi unuttum": kod gelir, yeni şifre ile giriş olur (sonra eski şifreyle giremezsiniz).

### T3. Profil
1. Ad/bölüm/sınıf seçin (akademik seçici), **profil fotoğrafı** galeriden yükleyin. Beklenen: izin istemi (Android 13+ fotoğraf izni), yükleme sonrası avatar görünür; uygulamayı yeniden açınca durur.
2. Gizlilik/bildirim tercihleri ekranı açılır, bir anahtarı değiştirip geri alın.

### T4. Gönderi (Keşfet)
1. Keşfet sekmesi: akış yüklenir (iskelet -> içerik), görseller görünür.
2. Yeni gönderi: **1 fotoğraf** + en çok 7 kelime metin. Beklenen: yükleme çubuğu, gönderi akışta görünür; 8+ kelime ya da küfürlü metin: anlaşılır hata (422).
3. Beğen / beğeniyi geri al. Kendi gönderinizi silin. Başka kullanıcıyı (B) takip edin.
4. Bir gönderiyi **raporlayın**. Beklenen: onay metni (Play "kullanıcı içeriği" şartı: rapor/engelle çalışmalı).

### T5. Kulüp, etkinlik, QR yoklama
1. Kulüpler: bir kulüp aç, katıl/başvur. Kulüp sohbet odası açılır (`CLUB`).
2. Etkinlikler: bir etkinlik aç, katıl (RSVP). Yönetici panelinden (ya da kulüp yöneticisi hesabıyla) etkinlik için **QR üret**, telefonda **Yoklama > QR tara**. Beklenen: kamera izni istenir, okutunca "yoklama alındı", ikinci okutma: "zaten alındı" (hata değil).
3. Kamera izni **reddedilirse**: uygulama çökmez, ayarlara yönlendiren metin görünür.

### T6. Sohbet (gerçek zamanlı)
1. Hesap B ile (ikinci cihaz) A'ya birebir mesaj yazın. Beklenen: A'da **anında** (1-2 sn) görünür, "yazıyor..." göstergesi, okundu bilgisi, okunmamış rozeti.
2. A'dan fotoğraf gönderin (sohbet görseli). Beklenen: yükleme + önizleme; B'de açılır.
3. Yanıtla, düzenle, herkes için sil, tepki ekle. Sessize al / arşivle.
4. Wi-Fi'yi 10 sn kapatıp açın. Beklenen: bağlantı kopar, otomatik yeniden bağlanır, kaçan mesajlar tamamlanır (kopya yok).

### T7. Push (FCM anahtarı sonra)
- **FCM anahtarı henüz yoksa bu adım "Atlandı"** (beklenen: hata yok, yalnız uygulama içi bildirim kutusu dolar; `GET /actuator/health` `fcm.enabled=false`). Bu durumda yalnız Bildirimler sekmesini doğrulayın: yeni mesaj/etkinlik duyurusu kutuya düşer.
- Anahtar yüklendikten sonra ([PUSH_SETUP.md](PUSH_SETUP.md)): bildirim izni verin; B'den A'ya mesaj atın, A **uygulama arka plandayken**: bildirim gelir (kanal "Sohbet"), dokununca ilgili sohbet açılır. Yönetici panelinden `SELF` hedefli test kampanyası: kanal "Duyuru". Uygulama ön plandayken aynı sohbet açıkken bildirim **bastırılır**.

### T8. Çevrimdışı
1. Uçak modunu açın, uygulamayı açın/kullanın. Beklenen: önbellekten haber/menü/akış "Eski veri / çevrimdışı" bandıyla görünür, **oturum düşmez** (giriş ekranına atmaz), gönderme denemesinde anlaşılır ağ hatası.
2. Uçak modunu kapatın. Beklenen: kendiliğinden toparlanır, yeniden başlatma gerekmez.

### T9. Arapça (RTL)
Ayarlar > Dil > العربية. Beklenen: tüm düzen sağdan sola aynalanır (geri oku, alt menü sırası, sohbet balonları), metin kesilmez, sayılar okunur, Arapça e-posta/sunucu hata metni gelir. İngilizce'yi de bir kez deneyin. Çeviri hatası **kaldı sayılmaz**, not edilir (Arapça anadil incelemesi bekliyor).

### T10. Koyu tema
Ayarlar > Tema: Koyu / Açık / Sistem. Beklenen: hiçbir ekranda "beyaz patlama", okunamayan metin, görünmez simge yok; QR tarayıcı ve sohbet ekranına bakın.

### T11. Yavaş ağ
Geliştirici seçenekleri ya da ağ sınırlayıcı ile 3G'ye düşürün (veya sinyalsiz bir yer). Akış, haber, gönderi yükleme dener. Beklenen: yükleme göstergeleri, zaman aşımında "yeniden dene", ekran donmaz; büyük fotoğraf yüklemesi kesilirse tekrar denenebilir.

### Ek (süre kalırsa)
- Hesap silme: Profil > Hesabı sil (yalnız **tek kullanımlık test hesabında**). Beklenen: anonimleştirme, çıkış; aynı e-postayla yeniden kayıt olunabilir.
- Destek talebi gönder; yönetici panelinde görünür.
- Yemek listesi, haber detayı, arama.

## 3. Sonuç tablosu (kopyalayıp doldurun)

| # | Madde | Geçti/Kaldı/Atlandı | Not (cihaz, Android sürümü, hata) |
|---|---|---|---|
| T1 | Kayıt + kod | | |
| T2 | Giriş/oturum | | |
| T3 | Profil | | |
| T4 | Gönderi | | |
| T5 | Kulüp/etkinlik/QR | | |
| T6 | Sohbet | | |
| T7 | Push | | |
| T8 | Çevrimdışı | | |
| T9 | Arapça RTL | | |
| T10 | Koyu tema | | |
| T11 | Yavaş ağ | | |

Cihaz: ______ Android: ____ Uygulama sürümü/versionCode: ____ Sunucu: https://____ Tarih: ____ Test eden: ____

**Yayın kararı:** T1-T6 ve T8 "Geçti" olmadan mağazaya gönderilmez. T7 FCM anahtarı yoksa "Atlandı" kabul; T9-T11 kaldıysa düzeltme planıyla gönderilebilir (not edin).

## 3b. iOS ek maddeleri (TestFlight yapısı, gerçek iPhone; Android maddeleri yine geçerli)

Ayrıntı ve gerekçe: [IOS_RELEASE.md](IOS_RELEASE.md) bölüm 6 ve 9. Simülatör APNs almaz: push maddeleri yalnız gerçek cihazda.

| # | Adım | Beklenen |
|---|---|---|
| I1 | Çentik/Dynamic Island'lı modelde Ana Sayfa, Sohbet, Profil | Başlıklar çentiğin altında, alt gezinme ana ekran çubuğunu kapatmıyor |
| I2 | Herhangi bir iç sayfada ekranın sol kenarından sağa kaydır | Önceki sayfaya dönülür (swipe-back); sohbet listesi/ana sekmelerde çıkış yapmaz |
| I3 | Sohbette yazı alanına dokun | Klavye açılır, yazı alanı klavyenin üstünde kalır, son mesaj görünür |
| I4 | Ayarlar > Ekran > Yazı Boyutu'nu en büyüğe al, Ana Sayfa/Kulüpler/Ders programı | Metin kesilmez, düğmeler erişilebilir |
| I5 | İlk giriş izin sayfası: Bildirim, Rehber, Kamera | Her biri sistem penceresiyle (Türkçe açıklama metni) sorulur; reddedince "Ayarlar'ı aç" çalışır |
| I6 | Sohbette galeri/kamera, QR yoklama, görseli kaydet | Fotoğraf seçici ve kamera açılır; kaydetme "yalnız ekleme" izniyle çalışır |
| I7 | Giriş yap, Bildirimler'deki okunmamış sayısını not et, uygulamayı kapat; başka cihazdan mesaj/bildirim ürettir | Bildirim gelir (production APNs); dokunuş ilgili ekranı açar (arka plan ve kapalı) |
| I8 | Bildirimleri okunmuş yap | Uygulama simgesindeki rozet sayısı düşer/kalkar |
| I9 | Akademik > hatırlatma ayarlarını aç, 2-3 dakika sonrasına bir ders/sınav hatırlatması kur (test için) | Zamanında yerel bildirim görünür, dokunuş Akademik'e gider |
| I10 | Uygulamayı sil, yeniden kur | Otomatik giriş YAPMAZ (giriş ekranı gelir) |
| I11 | Sohbette galeriden 40 MB'tan büyük/uzun video seç | Anlaşılır "çok büyük" hatası (iOS'ta sıkıştırma yok: bilinen sınırlama) |
| I12 | Ayarlar > Dil: Arapça | Sağdan sola düzen, izin pencereleri Arapça metinle |

## 4. Hata nasıl raporlanır

Her hata için **tek bir kayıt** (GitHub issue ya da bir metin dosyası) açın; şunlar olmadan kayıt eksik sayılır:

1. **Başlık:** "[T5] QR okutunca uygulama kapanıyor" (adım numarası + belirti).
2. **Adımlar:** 1-2-3 şeklinde, yalnız yaptıklarınız.
3. **Beklenen / gerçekleşen.**
4. **Ortam:** cihaz modeli, Android sürümü, uygulama sürümü (Ayarlar sayfasının altındaki sürüm satırı; Play kurulumunda `versionCode`), ağ türü, dil, tema, hangi hesap (A/B; **parola yazmayın**).
5. **Kanıt:** ekran görüntüsü / ekran kaydı (adb: `adb shell screenrecord /sdcard/r.mp4` + `adb pull /sdcard/r.mp4`) ve `logcat.txt` (hatanın olduğu ±30 sn; token/e-posta içeriyorsa kırpın).
6. **Çökme ise:** `adb logcat -b crash -d > crash.txt`.
7. **Sunucu tarafı şüphesi** (5xx, 401/403): saat (saniyeye kadar, saat dilimi ile) not edin; yanıtta `traceId` görünüyorsa yazın (`X-Request-Id`); sunucu günlüğünde bu iz aranır: `docker compose -p bu -f docker-compose.prod.yml --env-file .env.prod logs backend | grep <traceId>`.
8. **Önem:** Engelleyici (giriş/kayıt/sohbet çalışmıyor, çökme) / Önemli / Küçük (görünüm). Engelleyici olanlar yayını durdurur.

Sır paylaşma kuralı: parola, JWT, FCM/keystore dosyası, `.env.prod` içeriği rapora **asla** konmaz.
