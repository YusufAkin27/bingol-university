# iOS ekran görüntüleri: boyut ve üretim

Genel ilkeler Play ile aynıdır ([../store/screenshots.md](../store/screenshots.md): ekran listesi, sahte tohum veri, üniversite logosu/gerçek kişi yok, tr ve en setleri aynı sıra). Burada yalnız Apple'a özgü fark ve üretim yolu.

## Boyutlar (Apple, 2026; Connect'in güncel "Screenshot Specifications" sayfasını yüklemeden önce doğrulayın)

| Grup | Piksel (dikey) | Durum |
|---|---|---|
| **iPhone 6.9"** (iPhone 16/17 Pro Max, Plus sınıfı) | 1320 x 2868 (ya da 1290 x 2796) | **Zorunlu**; en az 1, en çok 10 görsel |
| iPhone 6.5" | 1284 x 2778 ya da 1242 x 2688 | Yalnız 6.9" verilmezse zorunlu; Apple 6.9"u küçültür |
| iPad 13" (2064 x 2752) | | **Gerekmez**: uygulama iPhone-only ([../IOS_RELEASE.md](../IOS_RELEASE.md) K2). iPad desteği açılırsa zorunlu olur |
| Biçim | PNG ya da JPEG, alfasız, RGB | |
| Dil | Her yerelleştirme (tr, en, ar) için ayrı set; yoksa birincil dilinki gösterilir | İlk sürümde tr + en önerilir |

## Üretim yolu A (önerilen): iOS simülatörü (macOS)

```bash
# 1) Yerel tohum yığınını açın (docs/DEV_SEED.md) ve uygulamayı simülatörde çalıştırın:
flutter run --release -d "iPhone 17 Pro Max" \
  --dart-define=API_BASE=http://localhost:18080 --dart-define=ALLOW_INSECURE_API=true
# 2) Durum çubuğunu 9:41 / tam şarj yapın, ekranları gezip çekin:
scripts/ios/simulator-shots.sh prepare "iPhone 17 Pro Max"
scripts/ios/simulator-shots.sh shot 01_ana_sayfa_tr      # her ekran için
scripts/ios/simulator-shots.sh reset
```
Simülatör ekran görüntüsü cihaz çözünürlüğündedir (iPhone 17 Pro Max: 1320 x 2868). Hesap: `seed.ayse@bingol.edu.tr` (sahte). Push ekranı simülatörde yoktur; gerçek cihazdan çekin. Üstüne başlık şeridi eklemek isterseniz (Play görselleri gibi) harici bir tasarım aracı kullanın; ekran içeriği değiştirilmemeli (Apple 2.3.3: ekran görüntüleri gerçek uygulama deneyimini göstermeli).

## Üretim yolu B: Flutter ekran testi (Windows'ta mümkün, yapılmadı)

`mobile/test/store_shots_test.dart` Play için 1080 x 1920 PNG üretir. Apple'a uyarlamak için tuval ve oran (`_canvas`, `_screen`, `_appSize`, `_dpr`) 1320 x 2868 (≈ 9:19,5) için ayrı bir test dosyasına kopyalanmalıdır; çerçeve/çentik çizimi Apple'ın gerçek cihaz görüntüsü beklentisine (2.3.3) aykırı olabileceğinden **A yolu tercih edilir**. Bu uyarlama bu çalışmada yapılmadı.

## Kontrol

- [ ] 6.9" grup tr ve en için yüklendi, sıra tutarlı
- [ ] Gerçek kişi adı/fotoğrafı/e-postası yok; üniversite logosu yok
- [ ] Görsellerde "resmî" izlenimi veren ifade yok
- [ ] Bildirim izni diyalogları ekran görüntüsüne girmedi
