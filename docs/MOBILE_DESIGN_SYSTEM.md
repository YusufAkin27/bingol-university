# Mobil tasarım sistemi: PREMIUM MONOCHROME

Hedef: cursor.com'un sakin, rafine, tipografi odaklı karakteri, mobile uyarlanmış. **Arayüz siyah-beyazdır**; kullanıcı fotoğrafı/medya doğal renkte kalır. Gradyan, neon, glow, cam efekti, aşırı gölge, devasa kart, emoji simge ve "her düğme pill" yoktur. İki tema vardır ve ikisi de ayrı tasarlanır (açık tema koyunun tersi değildir):

- **Premium Black** (koyu, **varsayılan**): zemin #09090B, kart #141416, ikincil yüzey #1C1C1F, yükseltilmiş yüzey #252528, yazı #FAFAFA, düğme beyaz zemin + siyah yazı. Gölge yok: ayrım yüzey tonu + ince kenarlık.
- **Premium White** (açık): zemin #FFFFFF, kart #FAFAFA, ikincil yüzey #F4F4F5, yazı #09090B, kenarlık #E4E4E7, düğme siyah zemin + beyaz yazı. İnce kenarlık + çok hafif yüzey farkı, gölge neredeyse yok, büyük siyah alan yok (siyah yalnız düğme/seçili durum).

Tek kaynak: `mobile/lib/core/theme.dart` (`BuTokens`, `context.bu`); hareket `mobile/lib/core/theme/bu_motion.dart` (`AppMotion`). Ekranlar yalnız bu belirteçleri kullanır; ham `Color(0x..)` ve `Colors.*` yazılmaz (`renk_paleti_test`; istisna yalnız `theme.dart` ve ders renkleri `academic_models.dart`).

## 1. Renk belirteçleri (`BuTokens`)

| Rol | Premium White | Premium Black | Alan |
|---|---|---|---|
| Uygulama zemini | #FFFFFF | #09090B | `bg` |
| Birincil yüzey (kart) | #FAFAFA | #141416 | `sf` |
| İkincil yüzey | #F4F4F5 | #1C1C1F | `sf2` |
| Yükseltilmiş yüzey (dialog, alt sayfa, menü, şerit) | #FFFFFF + kenarlık | #252528 | `sf3` |
| Birincil metin | #09090B | #FAFAFA | `ink` |
| İkincil metin (AA) | #52525B | #A1A1AA | `mut` |
| Muted/üçüncül (yalnız dekoratif ya da büyük metin) | #71717A | #71717A | `mutSoft` |
| Kenarlık | #E4E4E7 | #303034 | `bd` |
| İnce ayraç | #EFEFF1 | #242427 | `bdSubtle` |
| Kontrol çerçevesi (giriş, seçim halkası; >= 3:1) | #8A8A93 | #71717A | `bdStrong` |
| **Birincil eylem** (düğme, seçili durum, aktif gösterge) | #09090B | #FAFAFA | `pr` (= `prPressed`) |
| `pr` üstündeki yazı | #FFFFFF | #09090B | `onPr` |
| Vurgu metni/bağlantı | `ink` | `ink` | `prText` (getter, kırmızı DEĞİL) |
| Nötr yumuşak yüzey / üstündeki yazı | #F4F4F5 / #09090B | #1C1C1F / #FAFAFA | `soft` / `onSoft` |
| Devre dışı düğme | `bd` zemin + `mutSoft` yazı | aynı | (BuButton/FilledButton) |
| Kategori karoları (6 adet, indeks `BuTintId`) | nötr gri zemin + `ink` | nötr gri zemin + açık yazı | `tints`, `tint(i)` |

**Renkli kalan tek şey anlamsal renktir:**

| Anlam | Alan | Açık | Koyu |
|---|---|---|---|
| Hata, silme, engelle | `danger` / `dangerSoft` | #C81E1E / #FEECEC | #F87171 / #2A1517 |
| Beğeni kalbi (dolu kalp + patlama) | `heart` | #DC2626 | #EF4444 |
| Başarı | `ok` / `okSoft` / `onOkSoft` | #15803D | #4ADE80 |
| Uyarı | `warn` / `warnSoft` / `onWarnSoft` | #946010 | #F2B24A |
| Bilgi, okundu çift tiki | `info*`, `readSky`/`readDeep` | mavi | mavi |

Okunmamış rozeti **nötrdür**: `ink` zemin + `onPr` yazı (`BuCountBadge`, `BadgeTheme`, `BuIconButton(badge)`); `danger` ile karıştırılmaz. `aqua*` ailesi nötre çekildi (eski su mavisi yok). `h1`/`h2` (splash/yer tutucu) gradyan değil, eşit düz yüzeydir.

## 2. Renk kullanım kuralları

- Marka kırmızısı (#F73A2E) arayüzde YOK; yalnız logo/simge/splash varlıklarında (`BuColors`). Seçili sekme, bağlantı, birincil düğme, odak halkası, anahtar: `pr`/`ink`.
- Seçili çip/segment = **ters renk** (`pr` zemin + `onPr` yazı); seçili olmayan = `sf` + `bd` kenarlık. Alt çubukta zemin/hap yok: aktif ikon `ink`, pasif `mut`.
- Kenarlık 1 dp (`bd`); kart radius 16, giriş/buton radius 12 (compact buton 10), çip pill (yalnız çip/etiket), alt sayfa üst köşe 20, dialog 20. Aşırı gölge yok: `BuElevation` açıkta çok hafif, koyuda sıfır.
- **Kontrast:** tüm metin/zemin çiftleri AA (>= 4.5; `renk_paleti_test`); `mutSoft` küçük gövde metninde KULLANILMAZ. Birincil düğme 7:1'in üstündedir.
- Hata/başarı/uyarı yalnız anlamı olan yerde renklenir; kategori ayrımı renkle değil simge + etiketle yapılır.

## 2b. Tipografi (Inter, paketli; tek ölçek `BuScale`)

| Rol | sp | Belirteç |
|---|---|---|
| Hero (karşılama, büyük sayı) | 28-32 | `BuType.hero`, M3 `displaySmall/Medium/Large` (28/30/32) |
| Sayfa/içerik başlığı (profil adı, konu başlığı) | 22-26 | `BuType.display` (22), `headlineLarge/Medium` (26/22) |
| Bölüm başlığı | 17-19 | `BuType.title` (18), `titleLarge` |
| Gövde | 14-16 | `BuType.body` (14), `bodyLarge` (15), `heading` (16) |
| Caption | 12-13 | `BuType.label` (12.5) |
| Metadata | 11-12 | `BuType.caption` (11.5; **alt sınır**, K-21) |

**Kalın yazı kullanılmaz** (kullanıcı kararı): vurgu `BuType.emphasisWeight` tek belirtecinden gelir (şimdilik `FontWeight.w400`); kodda `FontWeight.w500+` yazılmaz. Semibold'a dönmek için tek satır: `emphasisWeight = FontWeight.w600`. Hiyerarşi boyut + renk (`ink`/`mut`) + boşlukla kurulur. Sayfa/ekran ADI başlıkları gizli kalır (`BuHeader.visibleTitle=false`); güçlü tipografi içerik başlıklarındadır.

## 2c. Bileşen eşlemesi (`lib/widgets/app_components.dart`)

Projede karşılığı olan `Bu*` bileşenler yeniden yazılmadı; `App*` adları aynı sınıfları gösterir:

| Ad | Karşılık |
|---|---|
| `AppButton` | `BuButton` (birincil = `pr`, ikincil `outline` = ince kenarlık, `danger`, `soft`, `text`) |
| `AppCard` | `BuCard` (outlined/filled/elevated/tonal; radius 16) |
| `AppAvatar` | `BuAvatar` |
| `AppBottomSheet` | `BuBottomSheet` |
| `AppDialog` | `BuDialog` |
| `AppTopBar` | `BuHeader` (başlıksız) |
| `AppBottomNavigation` | `FloatingNav` |
| `AppEmptyState` | `BuEmptyState` |
| `AppSkeleton` | `BuSkeleton` |
| `AppPostCard` | `PostCard` |
| `AppListTile` | `BuListTile` |
| `AppTextField` | YENİ: etiket üstte, tema girişi (radius 12, odakta `ink` kenarlık); `readOnly`+`onTap` (seçici), `inputFormatters`, `textCapitalization`, `semanticLabel` |
| `AppButtonKind`, `AppIconButton`, `AppChip`, `AppSegmented` (seçili = TERS RENK `pr`/`onPr`, radius 12), `AppBadge`, `AppCountBadge`, `AppSettingsTile` | takma adlar (`BuButtonKind`, `BuIconButton`, `BuChip`, `BuSegmented`, `BuBadge`, `BuCountBadge`, `BuSettingsTile`) |
| `AppSheet`, `AppConfirmSheet`, `AppToast`/`AppToastKind`, `AppErrorState`, `AppSkeletonList` | takma adlar (`BuSheet`, `BuConfirmSheet`, `BuToast`, `BuErrorState`, `BuSkeletonList`) |
| `AppReactionBar` / `AppReaction` | YENİ: beğen/yorum/paylaş/kaydet satırı (`heart` yalnız beğeni); ekran okuyucu etiketi sayıyı içerir ("Beğen, 12"), düğme >= 48 dp |
| `AppDivider`, `AppRadius` | YENİ: `bdSubtle` ayraç, radius kısayolları |

## 2d. Tema yönetimi

- Ayarlarda **Sistem / Açık / Koyu** seçici durur (`SettingsPage`); seçim `ThemeController` ile cihazda KALICI saklanır (`theme_mode`).
- **Varsayılan: Premium Black.** Kayıtlı tercih yoksa (ilk açılış) koyu; kayıtlı tercih (Sistem dahil) aynen korunur.
- `Sistem` seçiliyken platform parlaklığı değişince `MaterialApp` temayı anında günceller; tema değişiminde uygulama yeniden başlamaz, alt ağaç yeniden kurulmaz (yazılmış metin, kaydırma konumu, sekme/state korunur: `test/redesign/mono_theme_state_test.dart`). Geçiş `AnimatedTheme` ile ~200 ms.
- Durum/gezinme çubuğu ikonları temaya uyar (`main.dart` `AnnotatedRegion` + `AppBarTheme.systemOverlayStyle`).
- Kural: tema-dışı sabit renk yok. `BuTokens.light/dark` doğrudan kullanımı yalnız bilerek tema-bağımsız yüzeylerde (medya üstü, koyu tuval, QR); envanter `docs/changes/mono-ds.md`.

## 3. Hareket belirteçleri (`AppMotion`)

| Ad | Süre | Kullanım |
|---|---|---|
| `instant` | 80 ms | anlık geri bildirim |
| `fast` | 140 ms | düğme basma, çip, simge durumu |
| `normal` | 220 ms | bileşen geçişi, sekme, genişleme |
| `emphasized` | 300 ms | vurgulu geçiş |
| `sheet` | 340 ms | alt sayfa |

Eğriler: `standard` easeInOutCubic, `enter` easeOutCubic, `exit` easeInCubic, `interactive` easeOutQuart. Değerleri bileşenin davranışına göre seçin; "animasyonları azalt" açıkken `AppMotion.of(context, …)` sıfır döner. Eski `BuMotion` geriye uyum için durur; yeni kodda `AppMotion`.

## 4. Davranış kuralları

- **Alt gezinme:** seçili ikon ink (açıkta siyah), pasif mut, zemin/hap yok; Paylaş = pr daire (beyaz zemin + siyah artı); ikon yumuşak değişir, uygun yerde dolu varyanta geçer, hafif ölçek (180-220 ms); sekme değişimi sayfayı yeniden başlatmaz, scroll konumu korunur. Ortadaki paylaşım düğmesi basınca çok hafif küçülür, sonra alt sayfa açılır; dönme/zıplama yok.
- **Akış:** beğeni 1.0 → 1.15 → 1.0 (180-240 ms), sürekli bounce yok; kaydet yalnız dolgu/renk geçişi; liste her kaydırmada yeniden fade-in yapmaz.
- **Alt sayfa/diyalog:** alttan kontrollü yükselir, üst köşeler yuvarlak, arka plan hafif kararır, uygun yerde kaydırıp kapatma, klavyede içerik erişilebilir. Diyalog yerel Material davranışında.
- **Yükleme:** ana içerikte iskelet (düşük kontrast, yavaş shimmer, gerçek geometriye uygun); görsel yüklenince kısa crossfade; küçük işlemde düğme yükleniyor durumu, tekrarlanmaz.
- **Kaydırma:** Android doğal kaydırması; scroll ile boyut değiştiren header yok; alt gezinme görünürlüğü rastgele değişmez; iç içe kaydırma doğru yönetilir.
- **Sayfa geçişi:** Android Material geçişleri + tahmini geri; alt sekmelerde tam ekran kayma yok; hero yalnız görsel süreklilik için.
- **Mikro etkileşim:** düğme basma, simge durumu, beğeni, kaydet, takip, sekme, arama odağı, filtre çipi, aç/kapa, alt sayfa. Her biri net geri bildirim verir; gereksiz mikro animasyon eklenmez.

## 5. Performans ve erişilebilirlik

- 60 FPS hedefi, 90/120 Hz'de doğal akıcılık; büyük listelerde pahalı animasyon yok; `RepaintBoundary` yalnız gerekli yerde; `AnimationController` dispose edilir; gereksiz `setState`/rebuild azaltılır. Ölçüm (profil) yapmadan performans iyileştirdiğini iddia etmeyin.
- Azaltılmış hareket tercihine saygı; anlam yalnız animasyonla iletilmez; AA kontrast; büyük yazı tipinde yerleşim bozulmaz; animasyon kullanıcı işlemini engellemez.

## 6. Uygulama durumu

- Yapıldı (1. dalga, temel): monochrome BuTokens (açık + koyu), tipografi belirteci, M3 bileşen temaları, ortak widget'lar (BuButton/BuChip/BuSegmented/BuCard/BuBadge/BuSearchField), alt çubuk, pp_components.dart, tema varsayılanı/yönetimi, testler.
- Sırada (2. dalga, ekran grupları): 	.pr/prText/soft ile dolaşan eski vurgu kullanımları, kategori karoları, kalp/rozet ayrımı, sohbet balonları, gradyan/blur/gölge temizliği, pill buton -> 12 radius. Envanter ve bölünme: docs/changes/mono-ds.md.
- Mevcut işlev, API bağlantısı, gezinme ve veri modelleri korunur.
