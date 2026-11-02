# Mobil hareket sistemi

Kaynak ilkeler: LottieFiles `motion-design-skill` (MIT) ve Apple HIG (hareket, geri bildirim, yükleniyor, erişilebilirlik) bu uygulamaya uyarlandı. Denetim sonuçları: [MOBILE_MOTION_AUDIT.md](MOBILE_MOTION_AUDIT.md). Arayüz kilitli ([MOBILE_DESIGN_SYSTEM.md](MOBILE_DESIGN_SYSTEM.md)): burada yalnız HAREKET anlatılır.

Kod: `mobile/lib/core/motion/bu_motion.dart` (süre, eğri, yay, kademe, azaltılmış hareket) ve `bu_motion_widgets.dart` (`BuFadeSlideIn`, `BuStateSwitcher`, `BuShake`). Diğer bileşenler: `BuPressable`, `BuStaggerItem`/`BuStaggeredList`, `BuSwapIn`, `BuPop`, `BuCountUp`, `BuMotionStyles` (alt sayfa/diyalog/toast), `BuPageRoute`. Hepsi `widgets/bu.dart` ile gelir.

## 1. Kişilik kararı: "kurumsal + sıcak"

- Hızlı 200 ms, standart 300 ms, yavaş 450 ms. Abartılı sekme (bounce) ve elastik yok.
- Başarı geri bildirimi %5-10 taşabilir, ufak geri bildirim (basma, beğeni) %2-5, hata taşmaz (hata = hafif yatay sarsıntı).
- Giriş ease-out, çıkış ease-in ve girişin %65-75'i kadar sürer (`BuMotion.exit`: 0,7x), ekran içi hareket ease-in-out (MD3 Standard `Cubic(0.2, 0, 0, 1)`).
- Uzamsal harekette `linear` YASAK; yalnız ilerleme çubuğu ve dönme için.
- Önemli durum değişimi yalnız opaklık olmaz: solma + kısa yükselme/ölçek.
- Yalnız `transform` ve `opacity` canlandırılır (düzen tetikleyen özellik animasyonu istisnadır: bkz. denetim M-07/M-08).

## 2. Tablolar

### Süreler (`BuMotion.durations`)

| Ad | ms | Kullanım |
|---|---|---|
| `micro` | 120 | basma geri bildirimi, ipucu, klavye payı |
| `quick` | 200 | düğme/anahtar/çip, ikon geçişi, alt sayfa ve diyalog çıkışı, sohbet balonu |
| `standard` | 300 | kart, alt sayfa/diyalog girişi, durum değişimi, bırakma yerleşmesi |
| `slow` | 450 | büyük yüzey, sayaç (`BuCountUp`), beğeni patlaması |
| `page` | 400 | sayfa geçişi (geri 300 ms) |
| `dramatic` | 700 | nadir: açılış/kutlama |
| `shake` | 320 | hata sarsıntısı |
| `reducedFade` | 100 | azaltılmış harekette tek izinli geçiş |
| `ambient` | 1400 | iskelet gibi döngü yarım dalgası |

Eski adlar takma addır (kodlar bozulmaz): `BuMotion.short` = quick, `medium` = standard, `long` = page.

### Eğriler (`BuMotion.curves`)

| Ad | Değer | Ne için |
|---|---|---|
| `standard` | Cubic(0.2, 0, 0, 1) | ekran içi varsayılan |
| `emphasized` | easeInOutCubicEmphasized | konum/boyut iki yönlü |
| `emphasizedDecelerate` | Cubic(0.05, 0.7, 0.1, 1) | giriş (öğe belirir) |
| `emphasizedAccelerate` | Cubic(0.3, 0, 0.8, 0.15) | çıkış (öğe kaybolur) |
| `decelerate` / `accelerate` | Cubic(0,0,0,1) / Cubic(0.3,0,1,1) | basit giriş / çıkış |
| `settle` | Cubic(0.34, 1.3, 0.64, 1) | ~%3 taşma: bırakma, beğeni, rozet |
| `success` | Cubic(0.34, 1.56, 0.64, 1) | ~%7 taşma: onay, seçim işareti |
| `linear` | linear | yalnız ilerleme/dönme |

### Yaylar (`BuMotion.springs`, kütle 1; yalnız sürükle-bırak gibi süresi bilinmeyen hareket)

| Ad | Rijitlik | Sönüm | Davranış |
|---|---|---|---|
| `crisp` | 400 | 40 | kritik, taşmasız |
| `standard` | 300 | 24 | ~%5 taşma |
| `gentle` | 140 | 24 | yumuşak, taşmasız |

Kullanım: `SpringSimulation(BuMotion.springs.crisp, from, to, velocity)`.

### Kademe (`BuMotion.stagger(index, {step = 60 ms, max = 6})`)

Gecikme = `step x min(index, max)`; toplam üst sınır `BuMotion.staggerBudget` (480 ms < 500 ms kuralı). Listede adım 50-100 ms ve yalnız ilk 6-8 öğe canlandırılır (`BuStaggerItem` 50 ms, en çok 8 öğe, en çok 350 ms gecikme); kaydırınca geri gelen öğe yeniden oynamaz (`BuStaggerScope`).

## 3. Kullanım örnekleri

```dart
// Basma geri bildirimi (120 ms ölçek 0,97; bırakınca 300 ms yerleşme)
BuPressable(onTap: kaydet, child: kart)

// Giriş: solma + 12 dp yükselme; liste sırası kademe verir
BuFadeSlideIn(index: i, child: satir)

// Yükleniyor -> içerik -> hata (üst üste, boyut animasyonu yok)
BuStateSwitcher(state: yukleniyor ? 'yuk' : hata != null ? 'hata' : 'ok', child: govde)

// İskelet -> içerik (liste ekranları)
BuSwapIn(loading: !yuklendi, skeleton: const BuListSkeleton(), child: liste)

// Hata: yatay hafif sarsıntı (320 ms, 2,5 salınım, +-6 dp); trigger değişince oynar
BuShake(trigger: hataSayaci, child: alan)

// Başarı/rozet: 1 -> 1,1 -> 1 (beğeni için peak: 1.05)
BuPop(trigger: sayi, child: rozet)

// Süre ve eğri: azaltılmış harekette süre 0
AnimatedOpacity(
  duration: BuMotion.of(context, BuMotion.durations.quick),
  curve: BuMotion.curves.standard,
  opacity: gorunur ? 1 : 0,
  child: ...,
)

// Alt sayfa / diyalog / toast
showModalBottomSheet(context: context, sheetAnimationStyle: BuMotionStyles.sheet(context), ...)

// Kaydırma animasyonu (azaltılmışta anında atlar)
BuMotion.scrollTo(context, controller, 0)
```

Sayfa geçişi tek yerden: `BuPageTransitions.theme` (Android tahmini geri, iOS Cupertino kenar kaydırma). Elle `PageRouteBuilder` yazmayın; özel akış gerekirse `BuPageRoute` (400 ms ileri, 300 ms geri).

## 4. Ne zaman animasyon YOK

- Sohbet mesaj listesi: kaydırırken ve geçmiş yüklenirken animasyon yok; yalnız yeni gelen/gönderilen mesaj balonu 200 ms fade (+10 dp yükselme).
- 8. öğeden sonrası, kaydırınca geri gelen öğeler, yenilemede tekrar yüklenen liste.
- Sık tekrarlanan ve bilgi taşıyan ikinci derece değişimler (sayaç her saniye, bildirim sayısı yoğun güncellemesi).
- Düzen kayması yaratan boyut animasyonları listede/akan içerikte (yalnız form alanı aç-kapa gibi küçük bölgeler).
- Azaltılmış hareket açıkken kayma, ölçek, sarsıntı, döngü, parıltı.

## 5. Azaltılmış hareket (erişilebilirlik)

`MediaQuery.disableAnimations` (iOS "Hareketi Azalt", Android "Animasyonları kaldır") açıkken:

| Hareket | Davranış |
|---|---|
| `BuMotion.of(context, d)` | `Duration.zero` (animasyonlu widget'lar anında) |
| `BuMotion.fadeOf(context, d)` | 100 ms (kayma/ölçek yerine yalnız solma: `BuFadeSlideIn`, `BuStateSwitcher`, `BuSwapIn`, açılış geçişi) |
| Basma ölçeği, `BuPop`, `BuShake`, beğeni kalbi | oynamaz (hata metin/renkle zaten belirtilir) |
| Döngüler (iskelet, yazıyor noktaları, QR tarama çizgisi, ikon nefesi) | durur; durum statik renk/metinle gösterilir |
| `BuMotion.scrollTo` | `jumpTo` |
| Sayfa geçişi | anlık |

Kurallar: hareketle tek başına iletilen bilgi bırakmayın (hata = kırmızı metin + sarsıntı; başarı = ikon + metin + titreşim); 5 sn üstü süren döngüler azaltılmış harekette durur ve sonlu tekrarlıdır (QR çizgisi 3 gidiş-dönüş, ikon nefesi 4 tur).

## 6. Yeni animasyon kontrol listesi

1. Süre `BuMotion.durations`, eğri `BuMotion.curves`'tan mı? (sabit `Duration(milliseconds:)` ve `Curves.*` yok)
2. `BuMotion.of/fadeOf/reduced` ile azaltılmış hareket karşılığı var mı?
3. Giriş >= çıkış süresi mi (çıkış `BuMotion.exit`)? Giriş ease-out, çıkış ease-in mi?
4. Uzamsal harekette `linear` kullanılmadı mı? Hata taşmıyor mu (hata `BuShake`)?
5. Yalnız `opacity` + `transform` mı; önemli durumda yalnız opaklık değil mi?
6. Kademe toplamı < 500 ms, aynı anda hareketli eleman < 20 mi? Uzun listede yalnız ilk görünürler mi?
7. Kaydırmada kare düşürmüyor mu (`RepaintBoundary` yalnız ölçülmüş yerde)? Döngü tek ticker mı?
8. Aynı etkileşim = aynı hareket mi (basma her yerde `BuPressable`)?
9. Dispose edildi mi, `mounted` korunuyor mu?
10. Testte `pumpAndSettle` süreleri ve azaltılmış hareket senaryosu var mı (örnek: `test/motion_system_test.dart`)?
