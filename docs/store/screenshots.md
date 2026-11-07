# Mağaza görselleri: liste, boyutlar ve çekim yönergesi

**Otomatik üretim (IMG1):** emülatör yokken 8 ekran x tr/en görseli (1080x1920 PNG, başlık şeritli) gerçek ekran widget'ları + sahte API verisiyle üretilir: `mobile/test/store_shots_test.dart` (varsayılan `flutter test`te atlanır; `C:\bu_mobile` içinde `STORE_SHOTS_OUT=<klasör> flutter test test/store_shots_test.dart`; isteğe bağlı `STORE_SHOTS_LANG=tr|en`, `STORE_SHOTS_ONLY=01,05`). Görseller kampüs temalı soyut sahnelerdir (`test/support/store_shots_images.dart`), gerçek kişi/fotoğraf/e-posta yoktur; durum çubuğu 9:41 çizimdir. Gerçek cihaz/emülatör çekimi gerekirse aşağıdaki yönerge geçerlidir. Play Console görsel kuralları zamanla değişir; yüklemeden önce güncel kuralı doğrulayın. Aşağıdakiler yazıldığı andaki bilinen sınırlardır.

## Zorunlu / önerilen varlıklar

| Varlık | Boyut / biçim | Not |
|---|---|---|
| Uygulama simgesi | **512 x 512 px**, 32 bit PNG, ≤ 1 MB | Kaynak: `brand/dist/mark-fullbleed-1024.png` (1024'ten küçültün). **Üniversite logosu içermemeli** |
| Öne çıkan grafik (feature graphic) | **1024 x 500 px**, PNG/JPEG | Marka rengi + "BÜ Kampüs" + kısa slogan; üniversite logosu ve "resmî" izlenimi yok. `brand/dist/horizontal-*.png` kullanılabilir |
| Telefon ekran görüntüleri | **2-8 adet**, PNG/JPEG, kenar uzunluğu 320-3840 px, uzun kenar ≤ 2 x kısa kenar. Önerilen: **1080 x 1920** (9:16) ya da 1080 x 2400 | En az 4 adet yüklemek keşfedilebilirliği artırır |
| 7" / 10" tablet görüntüleri | İsteğe bağlı | Uygulama tablette çalışır (>= 600 dp yatay serbest) ama ilk sürüm için gerekmez |
| Tanıtım videosu | İsteğe bağlı (YouTube) | READ_CONTACTS beyanı için kısa bir izin/özellik videosu gerekebilir ([data_safety.md](data_safety.md) bölüm 4) |

## Çekilecek ekranlar (sıra = mağazadaki sıra)

Her biri hem **açık tema**, tr dil. İkinci set: İngilizce dil ile aynı ekranlar (en-US listesi için). Arapça (RTL) için 1-2 ekran isteğe bağlı.

| # | Ekran | Gösterilecek | Başlık önerisi (tr / en, görsel üstü kısa metin) |
|---|---|---|---|
| 1 | Ana Sayfa | Haber kartları, bugünün yemeği, yaklaşan etkinlik | Kampüs bir arada / Campus in one place |
| 2 | Keşfet | 4-6 gönderili akış (tohum veri görselleri) | Paylaş ve keşfet / Share and discover |
| 3 | Sohbet listesi + bir sohbet | Birebir sohbet, fotoğraflı mesaj, tepki | Anında mesajlaş / Chat in real time |
| 4 | Kulüpler | Kulüp listesi / bir kulüp ayrıntısı | Kulüplere katıl / Join clubs |
| 5 | Etkinlikler | Etkinlik ayrıntısı + QR yoklama düğmesi | QR ile yoklama / Check in with QR |
| 6 | Yemek listesi | Aylık/günlük menü | Günün menüsü / Today's menu |
| 7 | Anket | Bir anket + sonuç çubukları | Oy ver / Have your say |
| 8 | Profil / Ayarlar | Profil, koyu tema ya da dil seçimi | Üç dil, iki tema / Three languages, two themes |

Koyu tema ve Arapça: ayrı set gerekmez; 8. ekranda bir tanesini gösterin.

## Nasıl çekilir (tohum veriyle, gerçek kişi verisi olmadan)

1. **Tohum veri:** yerel yığını sıfırlayın ve tohumlayın (bkz. [DEV_SEED.md](../DEV_SEED.md)): `./scripts/reset-dev-db.sh` (12 sahte kullanıcı `seed.*@bingol.edu.tr`, parola `DevSeed-2026!`, 5 kulüp, 11 etkinlik, 15 gönderi, sohbetler, anketler). **Gerçek öğrenci adı, fotoğrafı, e-postası ekran görüntüsüne GİRMEMELİ**; tohum veri tamamen sahtedir, kişisel hesabınızla çekmeyin.
2. **Yemek/haber:** yerel yığında `INITIAL_FILL=true` ile ilk doldurma kaynak siteyi bir kez çeker; gerçek haber başlıkları ekran görüntüsünde görünebilir (kamuya açık içerik, sorun değil). İstemezseniz yönetici panelinden bir haberi gizleyin.
3. **Emülatör:** Pixel 7 profili, API 34-36, ekran 1080 x 2400. Uygulama: `flutter run --release --dart-define=API_BASE=http://10.0.2.2:18080 --dart-define=ALLOW_INSECURE_API=true` (emülatörden ana makine `10.0.2.2`; ortam için [ANDROID_RELEASE.md](../ANDROID_RELEASE.md) başı). Giriş: `seed.ayse@bingol.edu.tr`.
4. **Durum çubuğunu temizleyin** (saat 9:41 sabit, tam şarj, bildirim yok):
   ```bash
   adb shell settings put global sysui_demo_allowed 1
   adb shell am broadcast -a com.android.systemui.demo -e command enter
   adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941
   adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
   adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
   adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
   ```
   Bitince: `adb shell am broadcast -a com.android.systemui.demo -e command exit`.
5. **Çekim:** `adb exec-out screencap -p > 01_ana_sayfa_tr.png` (her ekran için). Uygulama `FLAG_SECURE` kullandığı için **ekran görüntüsü/kayıt siyah çıkabilir** (güvenlik önlemi: [ANDROID_RELEASE.md](../ANDROID_RELEASE.md) bölüm 4). Çözüm: yalnız çekim için debug derlemesinde `MainActivity` içindeki `FLAG_SECURE` satırını yerelde yorum satırı yapın (**commit etmeyin**) ya da emülatörde `adb shell screencap` yerine cihaz ekran kaydı kullanmayın; Play Console ekran görüntüleri yalnız bu yolla alınabilir. Bu madde **doğrulanmadı** (emülatörde denenmedi).
6. **İsimlendirme:** `docs/store/shots/` KULLANMAYIN (ikili dosyalar repoya girmez); `store-assets/` gibi gitignored bir klasörde tutun ya da Drive'a koyun.

## Son kontrol
- Üniversite logosu/arması yok; "resmî" iması yok. Başlık metinlerinde üniversite adı yok.
- Gerçek kişi adı/fotoğrafı/e-postası yok (tohum hesaplar sahte).
- tr ve en setleri aynı sırada; kenar uzunlukları sınırlar içinde.
