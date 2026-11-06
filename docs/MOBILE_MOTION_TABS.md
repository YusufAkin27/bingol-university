# Mobil: alt çubuk ve sekmeler arası kaydırma animasyonu (kayıtlı belirtim)

Kullanıcı kararı (2026-11-03): uygulamadaki **sağa/sola kaydırarak sekme değiştirme kullanımı beğenildi; korunur** ve tasarım odaklı, **minimal** bir animasyonla güçlendirilir. Bu belge, ana sayfa yenilemesinde (Stitch onayından sonra) uygulanacak hareket belirtimidir. Canlı prototip: [prototypes/motion-tabs.html](prototypes/motion-tabs.html) (tarayıcıda açın; sekmelere dokunun ya da içeriği sürükleyin; "Yavaş çek" ve "Azaltılmış hareket" düğmeleri vardır).

Değerler `AppMotion` belirteçlerine bağlanır ([MOBILE_DESIGN_SYSTEM.md](MOBILE_DESIGN_SYSTEM.md)): `fast` 140 ms, `normal` 220 ms; eğriler `standard` (easeInOutCubic) ve `enter` (easeOutCubic). Azaltılmış harekette (`AppMotion.of`) tüm geçişler anlıktır.

## Alt çubuk
> **Güncel (2026-11-07):** alt çubuk "Soft Glow Premium" olarak yeniden tasarlandı (`features/shell/bukampus_bottom_navigation_bar.dart`: 68 dp kapsül, 58 dp kırmızı Paylaş düğmesi, etiketli outline simgeler, kırmızı vurgu yalnız bu çubukta). Kayan hap yerine aktif simgenin arkasında çok hafif kırmızı yumuşak zemin 220 ms `easeOutCubic` ile kayar; sürükle-esnet kaldırıldı. Aşağıdaki tablo tarihsel belirtimdir; sayfa kaydırma bölümü geçerlidir.

Yüzen beyaz hap, yükseklik 64, kenar boşluğu 16, ince `bd` kenarlık, çok hafif gölge. Öğeler: Ana Sayfa, Keşfet, ortada "+" (yuvarlak, `prPressed` zemin, çubuktan 18 px yukarı taşar), Sohbet (okunmamış rozeti), Profil.

| Öğe | Hareket |
|---|---|
| Seçili sekme | Yumuşak "kayan hap" (`soft` zemin, `onSoft` yazı) yeni sekmeye genişleyerek geçer: 220 ms, `standard`. Genişlik etiket uzunluğuna göre uzar/kısalır (seçili 118 dp, diğerleri 48 dp). |
| Etiket | Yalnız seçili sekmede görünür; 140 ms solarak açılır/kapanır (60 ms gecikmeli). |
| İkon | Çizgi → dolu çapraz geçiş 140 ms; ölçek 1.0 → 1.08 → 1.0 (220 ms). Pasif ikon `mut`, aktif `onSoft`/marka. |
| "+" düğmesi | Basınca 80 ms'de 0.94'e küçülür, bırakınca 140 ms'de döner. Zıplama/dönme yok. Ardından paylaşım alt sayfası açılır. |
| Rozet | İlk belirişte 140 ms ölçek (0 → 1); seçili sekmede gizlenir. |
| Davranış | İçerik kaydırılırken çubuk SABİT kalır (gizlenmez). |

## Sağa/sola kaydırma (sekmeler arası)
Minimal; tam ekran kayma yok.
- Sürüklerken geçerli içerik parmağı **12-16 px** paralaksla takip eder (`dx * 0.08`, ±16 ile sınırlı) ve hafifçe solar (en çok %25).
- Eşik **60 px** (ya da hızlı fırlatma): sekme değişir. Eşik aşılmazsa içerik 140 ms'de yerine döner.
- Değişimde eski içerik ~140 ms'de solar ve 8 px ters yöne kayar; yeni içerik 12 px yandan başlayıp **220 ms**, `enter` ile %100'e gelir (yön: ileri sekmede sağdan, geride soldan).
- Alt çubuk hapı değişimle eş zamanlı yeni sekmeye geçer.
- Sekme içeriği yeniden kurulmaz: kaydırma konumu ve durum korunur (`IndexedStack`/`PageView` + `AutomaticKeepAlive`).
- Yatay kaydırılan iç bileşenler (haber şeridi, harita, görsel galerisi) kaydırmayı yutar; sekme geçişi yalnız boş/dikey içerik alanında yatay sürüklemede başlar.

## Uygulama notları (Flutter)
- `lib/features/shell/app_shell.dart` ve alt gezinme çubuğu bileşeni; `PageView(physics: ClampingScrollPhysics)` + özel `PageTransitions` yerine tek `AnimatedBuilder` ile paralaks/solma.
- Predictive back ve sekme durum koruma davranışı değişmez.
- Test: widget testi (sekme değişince seçili öğe/etiket, eşik altı geri dönme, azaltılmış hareket anlık), ekran görüntüsü testi (çubuk seçili durumları).
- Durum: Stitch ana sayfa tasarımı onaylanınca birlikte uygulanır (ana sayfa + çubuk + geçiş tek iş).
