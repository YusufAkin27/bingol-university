# Uygulama talimatı: Stitch tasarımını Flutter'a BİREBİR aktarma

Kapsam: Stitch'te üretilen ve doğrulanan tüm mobil ekranlar (docs/design/INDEX.md, referans görseller `C:\bu_design\stitch\<NN>-<ad>\`). 20 ajan paralel, her biri `docs/MOBILE_PAGES.md` paket tanımındaki ayrık dosya kümesine sahiptir.

## Altın kural
1. **Referans görsel kanundur.** Yerleşim, boşluk, renk, köşe yarıçapı, gölge, yazı boyutu/ağırlığı, ikon, metin, sıra, durum varyantları referansla AYNI olacak. "Benzer" kabul edilmez; kendi yorumunu, "iyileştirmeni", ek özellik/öğe ekleme veya çıkarma YAPMA. Referansta bir hata olduğunu düşünürsen DUR, `docs/design/SORULAR.md` dosyasına (paket, ekran, ne) yaz ve o öğeyi referansta olduğu gibi bırak.
2. **Ortak tasarım dili:** yalnızca `context.bu` (BuTokens), Material 3 tema ve `core/widgets` ortak bileşenleri (BuPressable, BuPageScaffold, BuSheet, BuEmptyState/ErrorState, BuSkeleton, BuToast, BuListTile...) kullanılır; sabit renk/ölçü yazma, aynı işi yapan yeni bileşen üretme (eksikse mevcut ortak bileşene ekle ve PR notunda belirt; ortak dosyalara aynı anda yazma çakışmasını `scripts/dev/with-lock.sh` ile önle). Inter yazı tipi.
3. **Her ekran için durum varyantları** (yükleniyor iskeleti, boş, hata, çevrimdışı/bakım, uzun metin, 1,3x yazı ölçeği, koyu tema, Arapça RTL, tr/en/ar) tasarımda neyse aynen uygulanır; tasarımda olmayan varyant mevcut ortak bileşenle yapılır.
4. **Davranış/özellik**: tasarımdaki her öğe ya mevcut işlevle bağlanır ya da (kodda yoksa) EKSTRA-backend.md'ye göre uygulanır. Backend'de eksik alan/uç varsa mobil ajan yapmaz; `docs/design/BACKEND-ISTEK.md` dosyasına yazar (backend ajanları yapar). Mobil bu alan gelene dek alanı opsiyonel okur, çökmez.
5. Yasaklar (değişmez): ödeme/bakiye/QR-ile-öde, hikâye, yorum, #etiket, @bahsetme, video gönderi, kaydet; yalnız bingol.edu.tr; uygulama resmî değil; etkinlik kulüp adına.

## Doğrulama (her ekran)
- Referans PNG ile aynı boyutta (390x844 mantıksal) ekran görüntüsü testi (`mobile/test/` altında, mevcut `store_shots`/`*_shots_test.dart` düzeni, `with-lock.sh fluttertest`). İki görsel yanyana `C:\Users\Toprak Çevik\bu-release\redesign\p<NN>\{referans,uygulama}\` klasörüne koyulur. Ajan kendi görüntüsünü referansla gözle karşılaştırır, farkı düzeltir; kalan fark listesi pakette raporlanır.
- `dart analyze` (ASCII yoldan, `C:\bu_mobile`), `flutter test` yeşil; l10n anahtarları 3 dilde (ARB; `with-lock.sh l10n`).
- Commit: yalnızca `scripts/agent-push.sh "UI-<paket>: ..." <yollar>`; asla `git add .`.

## Sonrası
Entegrasyon (tek ajan): çapraz ekran tutarlılığı, gezinme, yönlendirme; 4 bağımsız tasarım denetçisi referans-vs-uygulama karşılaştırması; backend/web yönetici değişiklikleri; derleme (AAB), sunucuya yükleme (`scripts/deploy.sh`); bitince bilgisayar kapatma.
