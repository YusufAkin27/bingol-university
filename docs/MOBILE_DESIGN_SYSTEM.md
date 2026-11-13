# BÜ Kampüs mobil tasarım sistemi (P0, Material 3 + marka)

> Durum: P0 teslimi (2026-10-29). Bu belge 19 paketin TEK referansıdır. Aşağıdaki "KİLİTLİ" arayüzler **yalnız ekleme** ile değişir (yeni isteğe bağlı parametre/sınıf); var olan imza ve davranış değişmez. Eksik/yanlış bir şey bulursanız P0 sahibine (yönetici) bildirin; kendi pakete eklemek gerekirse **kendi paket klasörünüzde** üretin.
> İlgili: `docs/MOBILE_PAGES.md` (envanter ve kurallar), `docs/MOBILE_UI.md`. Kod: `mobile/lib/core/theme.dart`, `mobile/lib/core/theme/`, `mobile/lib/widgets/`. Görsel kanıt: `mobile/test/redesign/p00_gallery_shots_test.dart`.

## 1. Tek içe aktarma

```dart
import '../../widgets/bu.dart';   // belirteçler + TÜM ortak bileşenler (+ BuIcons)
```

`bu.dart` şunları dışa aktarır: `core/theme.dart` (BuTokens, `context.bu`, BuTheme), `typography.dart` (BuType), `BuSpace/BuGap`, `BuRadius`, `BuMotion`, `BuElevation`, `bu_widgets` (eski + yeniden biçimlenen çekirdek), `bu_list`, `bu_state`, `bu_skeleton`, `bu_overlays`, `bu_pressable`, `bu_page_scaffold`, `bu_motion_widgets`, `bu_hero`, `bu_illustrations`, `bu_image`. Tarih/format yardımcıları ve `LoadingView/ErrorView/EmptyView` hâlâ `widgets/common.dart`'tadır.

### 1.1 İkon kuralı (ICONS-MIGRATE, 2026-11-01)

Uygulamanın TEK ikon kapısı `BuIcons` (`lib/core/icons/bu_icons.dart`, `widgets/bu.dart` ile gelir): `Icon(BuIcons.chevronRight, size: 18, color: t.mut)`. Sabitler `IconData`'dır (Hugeicons 4.4.0 glif verisinden üretilmiş `assets/fonts/BuIcons.ttf`, çalışma zamanında SVG yok). **Yeni ikon = `BuIcons`'a eklenir; doğrudan `LucideIcons.*` ya da `Icons.*` kullanılmaz** (iki istisna `BuIcons.delete`/`keyboard`, Lucide'e işaret eder). Eklemek için `mobile/tools/icons/README.md` (eşleme belgesine satır -> `parse_doc_map.py` -> `extract_hugeicons.py` -> `build_icons.py`; üretilen font/Dart elle düzenlenmez). Çizgi kalınlığı sabit 1.75. Dolu hâller (`heartFilled`, `starFilled`, `bookmarkFilled`, `bellFilled`, `playFilled`, `pauseFilled`, `circleCheckFilled`, `circleAlertFilled`, `triangleAlertFilled` vb.) yalnız durum göstergesi içindir (beğeni, kaydet, yıldız, oynat/duraklat, onay/uyarı); alt çubukta etkin sekme çizgi glif + `pr` rengi + yumuşak `soft` hap zemindir. RTL: yön okları (`arrowLeft/Right`, `chevronLeft/Right`) `buDirIcon` ile aynalanır (glifte `matchTextDirection` KULLANILMAZ). 14 dp altı boyut önerilmez (`BuIconSize.minLegible`). MIT lisans notu `registerBuIconLicenses()` ile lisans sayfasına eklenir.

## 2. Tasarım ilkeleri

1. **Material 3 gövde, monokrom kimlik:** `useMaterial3`, M3 bileşenleri BuTokens ile temalanır. Arayüz SİYAH-BEYAZDIR (zinc nötrleri): marka/vurgu kırmızısı YOK; renk yalnız anlamsal durumda (`danger`, `heart`, `ok`, `warn`, `info`). Varsayılan tema koyu ("Premium Black"), açık tema "Premium White".
2. **Katmanlı yüzeyler:** sayfa `bg` < kart `sf` < ikincil `sf2` < üst katman `sf3` (diyalog, alt sayfa, menü). Ayrım gölge/degrade ile değil yüzey tonu + ince `bd` kenarlıkla yapılır; gölge, blur, degrade, glow dekorasyon olarak KULLANILMAZ (görsel üstü okunurluk scrim'i hariç).
3. **Nötr vurgu:** seçili/etkin durum `soft` zemin + `onSoft` yazı + `selectedBorder` (ink %50) ile gösterilir; birincil eylem `pr` (açıkta siyah, koyuda beyaz) dolu düğmedir. Kalın yazı yok: hiyerarşi boyut + `ink`/`mut` renk + boşlukla kurulur (tüm ağırlıklar w400, `BuType.emphasisWeight`).
4. **Hareket anlamlıdır:** basma (hafif küçülme + titreşim), seçim (kayan gösterge), içerik girişi (aşamalı), durum geçişi (fade-through). 150/250/400 ms; yalnız `transform`/`opacity`. "Animasyonları azalt" açıkken hepsi anlık.
5. **Durumlar eksiksiz:** yükleniyor (iskelet, çember değil) / boş (illüstrasyon + yönlendirme) / hata (yeniden dene) / çevrimdışı (şerit, eski veri) / bakım.
6. **Hız:** `const`, tembel liste, `RepaintBoundary` ile ağır boyacılar izole, tek ticker (iskelet), ağ görselinde `cacheWidth`, kaydırılan listede `Opacity/BackdropFilter/saveLayer` yok.

## 3. Renk (BuTokens - `context.bu`)

Renk yalnız `context.bu` (veya `Theme.of(context).colorScheme`) üzerinden. `Color(0x..)`, `Colors.*` yeni yazılmaz (`test/redesign/renk_paleti_test.dart` `lib/` taramasıyla denetler).

> **Monokrom karar (2026-11-06):** eski "kampüs kırmızısı + dört anlam ailesi" paleti kaldırıldı. Kaynak doğruluk: `lib/core/theme.dart` (`BuTokens.light/dark`); aşağıdaki tablo ondan birebir türetilmiştir. `tints` (kategori karoları) nötrdür, ayrım simge + etiketle yapılır.

| Belirteç | Açık | Koyu | Kullanım |
|---|---|---|---|
| `bg` | #FFFFFF | #09090B | sayfa zemini |
| `sf` | #FAFAFA | #141416 | kart, girdi, liste |
| `sf2` | #F4F4F5 | #1C1C1F | ikincil yüzey, segment zemini, iskelet |
| `sf3` | #FFFFFF | #252528 | diyalog, alt sayfa, menü (kenarlıkla ayrışır) |
| `ink` / `mut` / `mutSoft` | #09090B / #52525B / #71717A | #FAFAFA / #A1A1AA / #71717A | ana / ikincil (AA) / ipucu (yalnız dekoratif ya da büyük metin) |
| `bd` / `bdSubtle` | #E4E4E7 / #EFEFF1 | #303034 / #242427 | kart/ayraç çizgisi (dekoratif) |
| `bdStrong` | #8A8A93 | #71717A | **kontrol çerçevesi**: giriş, arama, seçim halkası, `outline` düğme (>= 3:1) |
| `pr` / `onPr` | #09090B / #FFFFFF | #FAFAFA / #09090B | birincil eylem |
| `soft` / `onSoft` | #F4F4F5 / #09090B | #1C1C1F / #FAFAFA | seçili/tonal zemin ve yazısı |
| `selectedBorder` (getter) | `ink` %50 | `ink` %50 | seçili çip/segment çerçevesi |
| `nav*` (alt gezinme) | `navBase` #FFFFFF opak, `navBorder` #E4E4E7, `navAccent` #09090B, pasif #52525B | `navBase` #141416 opak, `navBorder` #303034, `navAccent` #FAFAFA, pasif #A1A1AA | alt çubuk: OPAK, blur/degrade/gölge yok |
| `ok` / `okSoft` | #166534 / #E7F5EC | #4ADE80 / #0F2A1A | başarı (anlamsal) |
| `warn` / `warnSoft` | #946010 / #FDF3DC | #F2B24A / #3A2B0E | uyarı, bekleyen, çevrimdışı/bakım |
| `info` / `infoSoft` | #356BB8 / #E8F0FB | #8DB4F0 / #1B2B45 | bilgi, okundu tiki |
| `danger` / `dangerSoft` | #C81E1E / #FEECEC | #F87171 / #2A1517 | hata, yıkıcı eylem (kırmızı YALNIZ burada) |
| `heart` | #DC2626 | #EF4444 | beğeni kalbi |
| `onMedia` / `scrim` | #FFFFFF / #000000 | aynı | fotoğraf/video üstü yazı-simge ve karartma |
| `qrInk` / `qrPaper` | #000 / #FFF | aynı | QR |
| `tints` / `tint(i)` | 6 nötr çift | 6 nötr çift | kategori karoları; `context.bu.tint(BuTintId.blue)` |

**Seçili çip/segment: TEK stil:** `soft` zemin + `onSoft` yazı + `selectedBorder` çerçeve (`BuChip` ile aynı). Keşfet, Sohbet, Kulüpler, Akademik (gün, sınav, bildirim süzgeçleri), Etkinlik, Arama, Destek, Bildirimler artık bu stili kullanır; "lacivert/beyaz ters çevrilen" ve "dolu kırmızı" çipler kaldırıldı. Dolu `pr` yalnız birincil eylem düğmesindedir (siyah/beyaz).

**Kontrol çerçevesi / kart ayrımı:** metin alanı, seçim halkası ve `BuButtonKind.outline` çerçevesi `bdStrong` (3:1 üstü); kartlar `bd` çizgisiyle ayrılır, gölge kullanılmaz.

**Anlam kuralları:** renk yalnız durum bildirir: yeşil = başarı, amber = uyarı/bekleyen, mavi = bilgi, kırmızı = hata/silme/kalp. Kategori ayrımı için yeni renk eklenmez, simge + etiket kullanılır.

ColorScheme eşlemesi: `primary=pr`, `primaryContainer=soft`, `secondary=ink`, `secondaryContainer=soft`, `tertiary=ok`, `error=danger`, `errorContainer=dangerSoft`, `surface=sf`, `surfaceContainerHigh=sf3`, `surfaceContainerHighest=sf2`, `outline=mut`, `outlineVariant=bd`. Kontrast: tüm metin çiftleri AA (>= 4.5:1), kontrol çerçeveleri >= 3:1; test: `test/redesign/p00_theme_test.dart` ve `test/redesign/renk_paleti_test.dart`. Durum çubuğu: `AppBar.systemOverlayStyle` açık/koyu için açıkça verilir (Android ikon parlaklığı, iOS `statusBarBrightness`); Cupertino bileşenleri `cupertinoOverrideTheme` ile aynı belirteçleri kullanır.

## 4. Yazı (Inter; `Theme.of(context).textTheme`)

| Rol (`BuScale`) | Boyut | Kullanım |
|---|---|---|
| hero | 28 | karşılama, büyük sayı |
| display | 22 | büyük sayfa başlığı, profil adı |
| title | 18 | app bar başlığı, diyalog/alt sayfa başlığı |
| heading | 16 | bölüm/kart başlığı |
| bodyLarge | 15 | uzun okuma |
| body | 14 | gövde, liste satırı, düğme |
| label | 12.5 | etiket, ikincil satır, çip |
| caption | 11.5 | yardımcı metin, saat, rozet (en küçük) |

Tüm ağırlıklar w400 (`BuType.emphasisWeight`); `FontWeight.w500+` yazılmaz. Başlık-gövde ayrımı boyut ve renk (`ink` / `mut`) ile yapılır.

- **Tek ölçek (K-21/T-113):** boyutlar `core/typography.dart` içindeki `BuScale`'de durur (display 24, title 19, heading 16, bodyLarge 15, body 14, label 12.5, caption 11.5); `BuTextTheme` (M3 roller) ve `BuType` ikisi de buradan beslenir, ayrı sayı tutulmaz. Eski `BuType.micro` kaldırıldı, `BuType.caption` (11.5) ile birleşti (saat/rozet: `BuType.caption.copyWith(fontWeight: FontWeight.w500)`). Yeni kodda **`textTheme`** tercih edilir; `BuType` aynı ölçeği taşır. Elle `fontSize:` yazılmaz (rozet içi sayı gibi zorunlu durumda `BuScale.caption`); renk `.copyWith(color: t.mut)` ile verilir.
- Arapça: harf aralığı 0, satır yüksekliği ×1.12 (`BuTheme.light()/dark()` `LocaleController.current` dilinden seçer; test için `BuTheme.forLocale(Brightness, 'ar')`). Başlıkta elle `letterSpacing` verirseniz Arapçada 0 yapın.
- En küçük metin 11.5 sp (`labelSmall` / `BuType.caption`; bunun altında stil tanımlanmaz); 1.3x ölçekte taşma olmamalı (`maxLines` + `overflow` + esnek düzen; gerekirse `MediaQuery.withClampedTextScaling`).

## 5. Boşluk, şekil, yükseklik, hareket

```dart
BuSpace.xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32 · huge 48 · page 20
BuSpace.pageH (EdgeInsetsDirectional yatay 20) · BuSpace.card (16) · BuSpace.row
BuGap.h8 / BuGap.w12 ...   // const SizedBox: h2 h4 h6 h8 h12 h16 h20 h24 h32 h48 · w4 w6 w8 w12 w16 w20 w24
BuRadius.xs 8 · sm 12 · md 16 · lg 20 · xl 28 · pill 999   (+ bXs..bPill BorderRadius, topXl, rect(r, side:))
BuMotion.short 150 ms · medium 250 ms · long 400 ms · stagger 40 ms
BuMotion.standard · emphasized · emphasizedDecelerate (giriş) · emphasizedAccelerate (çıkış) · decelerate
BuMotion.reduced(context) · BuMotion.of(context, duration)   // azaltılmışsa Duration.zero
BuElevation.of(context, level 0..3)  // açık: gölge listesi; koyu: boş
```

Kural: iç içe şekilde iç yarıçap = dış − boşluk; kart 20, düğme/girdi 16, çip/hap 999, alt sayfa üstü 28, diyalog 28. Sayfa yan boşluğu 20. Boşlukta sabit sayı yerine ölçek.

## 6. Bileşen kataloğu (KİLİTLİ imzalar)

### 6.1 Çekirdek (`bu_widgets.dart`; eski imzalar korunur, görünüm M3'e taşındı)

```dart
BuHeader({required String title, VoidCallback? onBack, List<Widget> actions = const [], String? subtitle})
BuIconButton({required IconData icon, VoidCallback? onTap, String? tooltip, bool filled = false, bool badge = false, double size = 44})   // dokunma alanı >=48
BuCard({required Widget child, EdgeInsetsGeometry padding = 14, VoidCallback? onTap, Color? color, double radius = 20,
        bool border = true, BuCardStyle? style, VoidCallback? onLongPress})        // style: outlined|filled|elevated|tonal
BuChip({required String label, bool selected = false, VoidCallback? onTap, IconData? icon})   // seçili = marka tonu, 48 dp hedef
BuBadge(String text, {bool soft = false, Color? color, Color? onColor})
BuAvatar({String? name, String? url, double size = 48, bool square = false, bool dark = false,
          Map<String,String>? headers, bool group = false, bool online = false})
  // N4: foto yok / yuklenirken / hata = VARSAYILAN PROFIL GORSELI (BuDefaultAvatar; bas harf yok); renk `name`den kararli
BuDefaultAvatar({Object? seed, double size = 48, bool group = false, int? variant})   // CustomPainter, 6 marka varyanti, dekoratif (semantik yok)
FloatingNav({required int index, required ValueChanged<int> onChanged, required ValueNotifier<int> chatBadge,
             ValueListenable<String?>? avatarUrl, String? avatarName})   // N4: yuzen cam hap, kayan gosterge, Profil sekmesi = avatar
enum BuButtonKind { primary, outline, soft, text, danger }
BuButton({required String label, VoidCallback? onPressed, IconData? icon, BuButtonKind kind = primary, bool busy = false, bool compact = false})
BuSegmented({required List<String> items, required int index, required ValueChanged<int> onChanged})   // seçili parça kayar
BuSearchField({String? hint, TextEditingController? controller, onChanged, onSubmitted, VoidCallback? onTap, bool readOnly = false, bool autofocus = false})  // odak halkası + temizle
BuSectionTitle(String title, {String? action, VoidCallback? onAction, EdgeInsetsGeometry? padding})
BuHeroCard({required Widget child, EdgeInsetsGeometry padding, double radius = 26})   // eski; yenisi BuGradientHero
BuMenuRow({required IconData icon, required String label, VoidCallback? onTap, Widget? trailing, bool danger = false, bool showChevron = true})
BuGroup({required List<Widget> children, double dividerIndent = 0})
BuMark({double height = 52});  const kNavInset = 100;  trUpper() initialsOf() fileUrl() buDirIcon(context, icon)
```

- **BuButton:** birincil eylem sayfada tek (`primary`); ikincil `soft`/`outline`; "Vazgeç/Tümü" `text`; silme/çıkış `danger`. `compact` içeriği kadar genişler (hap, görsel 36, hedef 48). `busy`: etiket yerine çember (düğme içi tek meşru çember), anlamsal etiket kalır, dokunma kapalı. Her dokunuşta hafif titreşim + 0.98 ölçek.
- **BuCard:** tıklanabilir kartta `onTap` verin (dalga + hafif küçülme). Kaydırılan uzun listede `elevated` yerine `outlined`/`filled` (gölge maliyeti).
- **BuChip:** tek başına çip yerine yatay liste için `BuChipRow`.

### 6.2 Listeler ve başlıklar (`bu_list.dart`)

```dart
BuSectionHeader(String title, {String? action, VoidCallback? onAction, EdgeInsetsGeometry padding = (20,24,12,8)})   // semantics header
BuCountBadge(int count, {bool muted = false, int max = 99})     // 0 → hiçbir şey; 99+
BuListTile({required String title, String? subtitle, Widget? leading, Widget? trailing, VoidCallback? onTap, VoidCallback? onLongPress,
            bool selected = false, bool showChevron = false, bool danger = false, int maxTitleLines = 2, EdgeInsetsGeometry padding})
BuSettingsTile({required IconData icon, required String title, String? subtitle, String? value, Widget? trailing, VoidCallback? onTap, bool danger = false, BuTint? tint})
BuSettingsTile.toggle({required IconData icon, required String title, String? subtitle, required bool value, required ValueChanged<bool>? onChanged, BuTint? tint})
BuChipRow({required List<String> labels, required int selected, required ValueChanged<int> onSelected, List<IconData?>? icons, EdgeInsetsGeometry padding})
```

Ayar sayfası: `BuGroup(dividerIndent: 66, children: [BuSettingsTile(...), ...])`. Simge karosu rengi için `tint: context.bu.tint(i)`.

### 6.3 Durumlar (`bu_state.dart`, `bu_skeleton.dart`, `bu_illustrations.dart`)

```dart
enum BuIllustration { box, message, search, calendar, club, bell, wifiOff, alert, heart, image, lock, check, document }
BuIllustrationView(BuIllustration kind, {double size = 120})            // dekoratif, tema renkli, CustomPainter
BuEmptyState({required String title, String? message, BuIllustration illustration = box, IconData? icon,
              String? actionLabel, VoidCallback? onAction, String? secondaryLabel, VoidCallback? onSecondary, bool compact = false})
BuErrorState({Object? error, String? title, String? message, required VoidCallback onRetry, bool compact = false})   // ApiError ağ hatası → "Bağlantı yok"
BuOfflineBanner({String? message, bool showCachedHint = true, VoidCallback? onRetry, EdgeInsetsGeometry? margin})
BuSkeletonScope({required Widget child})                                 // tek AnimationController
BuSkeleton({double? width, double height = 14, double radius = 8}) · BuSkeleton.circle(double size) · BuSkeleton.line({double? width, double height = 12})
BuSkeletonList({BuSkeletonVariant variant = row | card | grid, int itemCount = 6, EdgeInsetsGeometry padding, bool shrinkWrap = false})
```

- Mevcut `ErrorView`/`EmptyView` (`common.dart`) artık `BuErrorState`/`BuEmptyState` sarmalayıcısıdır (imza aynı; `EmptyView` ikonuna göre illüstrasyon seçer). Yeni kodda doğrudan `BuEmptyState/BuErrorState` kullanın.
- **Yükleniyor = iskelet:** ilk açılışta (önbellek yoksa) `BuSkeletonList`/`BuSkeleton`; ekranınızın kendi düzenine benzeyen iskelet için kutuları `BuSkeletonScope` altında dizin. Dönen çember yalnız düğme içinde.
- Test notu: iskelet sonsuz animasyonludur → `pumpAndSettle` kilitlenir; `pump(Duration)` kullanın ya da `disableAnimations: true`.

### 6.4 Çerçeve ve etkileşim

```dart
BuPageScaffold({required String title, BuViewState state = ready (loading|ready|empty|error), List<Widget> slivers = const [],
  Future<void> Function()? onRefresh, List<Widget>? actions, Widget? leading, bool large = true, Widget? loading, Widget? empty,
  Object? error, VoidCallback? onRetry, Widget? banner, PreferredSizeWidget? bottom, Widget? floatingActionButton, Widget? bottomBar,
  double bottomInset = 24, ScrollController? controller, bool automaticallyImplyLeading = true})
BuSheet.show<T>(context, {required WidgetBuilder builder, String? title, String? subtitle, List<Widget>? actions, bool isDismissible, bool enableDrag,
  bool useRootNavigator = true, bool scrollable = true, double maxHeightFactor = .92, EdgeInsetsGeometry? padding})
BuBottomSheet({String? title, String? subtitle, required Widget child, List<Widget>? actions, EdgeInsetsGeometry padding, bool scrollable = true})  // çerçeve
BuConfirmSheet.show(context, {required String title, String? message, required String confirmLabel, String? cancelLabel, bool destructive = false, IconData? icon}) → Future<bool>
BuDialog({required String title, String? message, Widget? content, IconData? icon, List<Widget> actions, bool destructive})
BuDialog.confirm(context, {title, message, confirmLabel, cancelLabel, destructive, icon}) → Future<bool>
BuDialog.info(context, {title, message, okLabel, icon}) · BuDialog.show<T>(context, builder:, barrierDismissible:)
BuDialogAction({required String label, required VoidCallback? onPressed, BuDialogActionKind kind = normal | primary | destructive})
BuToast.show(context, String message, {BuToastKind kind = info|success|error|warning, String? actionLabel, VoidCallback? onAction, Duration duration})
BuPressable({required Widget child, VoidCallback? onTap, VoidCallback? onLongPress, double scale = .97, BuHaptic haptic = none, bool enabled = true, String? semanticLabel})
buHaptic([BuHaptic kind = selection])     // enum BuHaptic { none, selection, light, medium }
```

- **BuPageScaffold:** büyük başlık kaydırınca daralır (`SliverAppBar.large`), `onRefresh` verilirse çekerek yenile, durum makinesi (iskelet → fade → içerik). İçerik **sliver** olmalı (`SliverList.builder`, `SliverGrid`, `SliverToBoxAdapter`). Yüzen gezinme varsa `bottomInset: kNavInset`.
- **Alt sayfa:** `showModalBottomSheet` + elle `Container` YAZMAYIN; `BuSheet.show` (tutamaç, köşe, klavye payı, azami yükseklik, RTL). Tema `showDragHandle: false`'tur (eski elle tutamaçlı sayfalarda çift çıkmasın); `BuSheet` tutamacı kendi açar. Eski çerçeveler (`SohbetySheetFrame`, `showProfilChoiceSheet`, `ReportSheet`) kademeli olarak `BuSheet`'e geçer.
- **Diyalog:** 25 elle `AlertDialog` → `BuDialog.confirm/info/show`. Eylem düğmeleri `BuDialogAction` (satır içi boyut; `FilledButton` temada tam genişlik olduğundan diyalog `actions:` içinde ham `FilledButton` kullanmayın).
- **BuToast:** `ScaffoldMessenger.showSnackBar` doğrudan yerine; ekran okuyucuya duyurulur.
- **BuPressable:** kendi çizdiğiniz tıklanabilir yüzeyi sarar (görsel kart, ızgara karosu). `onTap` verirseniz dokunmayı kendisi yakalar; vermezseniz yalnız ölçek efekti (içerideki `InkWell` dokunmayı alır).

### 6.5 Hareket, vitrin, adım (`bu_motion_widgets.dart`, `bu_hero.dart`, `bu_image.dart`)

```dart
BuStaggeredList({required int itemCount, required IndexedWidgetBuilder itemBuilder, EdgeInsetsGeometry? padding, ScrollController? controller,
                 ScrollPhysics? physics, IndexedWidgetBuilder? separatorBuilder, bool shrinkWrap = false, int maxAnimated = 8})
BuStaggerScope({required Widget child}) · BuStaggerItem({required int index, required Widget child, int maxAnimated = 8})   // sliver listelerde elle
BuFadeThrough({required Widget child, Duration duration = 250 ms})            // çocuğa ValueKey verin
BuSharedAxis({required Widget child, bool reverse = false, Duration duration, double distance = 30})   // çocuğa ValueKey; RTL otomatik
BuPageRoute<T>({required WidgetBuilder builder, RouteSettings? settings, bool fullscreenDialog})   // özel akışlar; normalde MaterialPageRoute (tema geçişi)
BuGradientHero({required Widget child, EdgeInsetsGeometry padding = 20, double radius = 28, BuHeroPattern pattern = orbs | rings | waves | none,
                double? minHeight, VoidCallback? onTap, String? semanticLabel})
BuProgressSteps({required int count, required int current /*0 tabanlı*/, List<String>? labels, double height = 6})      // "Adım 2 / 3"
BuImage(String? url, {double? width, double? height, BoxFit fit = cover, double radius = 0, Map<String,String>? headers, String? semanticLabel, IconData placeholderIcon, int maxDecodeWidth = 1600})
```

- **Aşamalı giriş:** yalnız ilk 8 öğe, her indeks bir kez; uzun listede kaydırınca yeniden oynamaz.
- **BuGradientHero SADECE vitrinde:** Ana Sayfa öne çıkan kart, etkinlik/kulüp kapağı, karşılama, profil başlığı. Liste öğesi, form, ayarlarda kullanılmaz. İçinde yazı/ikon `onMedia` renginde başlar.
- **BuImage:** ağ görselleri için `Image.network` yerine (decode boyutu = düzen genişliği × DPR, yer tutucu, fade-in, hata yedeği).
- Sayfa geçişleri `ThemeData.pageTransitionsTheme` ile gelir (Android: tahmini geri + M3 fade-forwards, iOS: Cupertino kenar kaydırma; "animasyonları azalt" açıkken anlık). Rota için `MaterialPageRoute` yeterlidir.

#### Hareket (BuMotion) - D1 ortak hareket sistemi

Jetonlar `BuMotion` (150/250/400 ms, eğriler `standard`/`emphasizedDecelerate` giriş/`emphasizedAccelerate` çıkış), aşamalı giriş `BuStaggerItem`/`BuStaggeredList`, geçiş `BuFadeThrough`/`BuSharedAxis`, basma `BuPressable` (0.97) yukarıda. D1 eklemeleri `core/motion/` altındadır ve `widgets/bu.dart` ile gelir:

```dart
BuSwapIn(loading: !loaded, skeleton: const MySkeleton(), child: liste)      // iskelet -> içerik: yalnız opacity, boyut değişmez
BuCountUp(value: n, style: tx.titleLarge)                                    // ilk görünümde 0'dan sayar; okuyucu son değeri okur
BuPop(trigger: liked, child: heartIcon)                                      // trigger değişince bir kez 1 -> 1.18 -> 1 (ilk karede oynamaz)
showModalBottomSheet(sheetAnimationStyle: BuMotionStyles.sheet(context), ...) // BuSheet/BuDialog/BuToast bunu zaten kullanır
```

**Tur 2 (M0) ortak parçalar** - hepsi `widgets/bu.dart` ile gelir:

```dart
BuHero(tag: BuHero.tagOf('news', id), radius: 16, child: BuImage(...))  // liste kartı; detayda aynı etiket + radius: 0 -> uçuşta köşe yarıçapı geçer
Navigator.push(context, BuPageRoute(kind: BuRouteKind.axisY, builder: (_) => const Page()));  // axisX (vars.) | axisY | fadeThrough | containerTransform
BuHaptics.selection(); BuHaptics.light(); BuHaptics.medium();            // çip/anahtar tıkı | eşik (yenile, sürükle, beğeni) | onay/silme; buHaptic(BuHaptic.x) eski çağrı aynı yere gider
BuPressable(scale: .97, pressedOpacity: .92, onTap: ..)                  // basılıyken ölçek 150 ms + opaklık 100 ms; azalt açıkken yok
BuChipRow(labels: l, selected: i, onSelected: f)                          // seçili çip görünür kalır, taşan uçta 24 dp solma ipucu
```

```dart
BuRefreshIndicator(onRefresh: _load, child: liste)        // RefreshIndicator yerine: renk BuTokens, eşikte hafif titreşim
Text('12:45', style: BuType.title.tabular)                 // sayılar için tabular rakam (BuNumberStyle.of(style))
MaterialApp(scrollBehavior: const BuScrollBehavior())      // Android Clamping + M3 stretch, iOS Bouncing (main.dart'ta kurulu)
BuButton(busy: true)                                        // etiket <-> çember 150 ms fade/ölçek; tam genişlikte genişlik sabit
```

Hero kuralları: etiket sayfada benzersiz (`BuHero.tagOf(tür, kimlik)`), iki uçta çocuk sınırı dolduran görsel olsun, `radius` her uçta kendi köşe değeri; `transitionOnUserGestures` varsayılan kapalı (Android tahmini geri ile çakışmasın).

Kurallar: "animasyonları azalt" (`MediaQuery.disableAnimations`) açıkken tüm bu bileşenler anlık çalışır (süre 0; `BuMotion.of`); yalnız `transform`/`opacity` canlandırın; uzun/sonsuz animasyonlu listede `RepaintBoundary` ile ayırın. Uygulama içi ayrı bir "hareketi azalt" anahtarı yoktur; yalnız sistem ayarı dikkate alınır.

### 6.6 Tema bileşenleri (M3'ü doğrudan kullanın, ek stil gerekmez)

`FilledButton`/`.tonal`/`OutlinedButton`/`TextButton` (tema **tam genişlik 54 dp**; satır içinde `minimumSize: Size(0, 48)` verin), `IconButton(.filled/.filledTonal)`, `NavigationBar` (hap gösterge = `soft`), `AppBar`/`SliverAppBar(.large)`, `Card`, `FilterChip/ChoiceChip/InputChip/ActionChip` (hap, seçili `soft`), `TextField` (dolu + çerçeveli, odak 2 dp `pr`), `SearchBar/SearchAnchor`, `SegmentedButton`, `BottomSheet`, `AlertDialog`, `SnackBar`, `ListTile`, `Switch/Checkbox/Radio/Slider`, `Linear/CircularProgressIndicator`, `Badge`, `Divider`, `Tooltip`, `PopupMenu`, `TabBar`, `ExpansionTile`, `FloatingActionButton`, `showDatePicker/showTimePicker`. Hepsi `lib/core/theme/bu_component_themes.dart` içinde.

## 6A. Ortak bileşen kullanım kılavuzu (G1, 2026-11-09; TÜM ekranlar buna uyar)

Yeni ekranda özel düğme/çip/diyalog/uyarı sınıfı YAZILMAZ; aşağıdaki ortak bileşenler kullanılır. Eski özel sınıflar (`ClubBtn`, `AkadButton`, `RefButton`...) yalnız BuButton üstünde ince sarmalayıcıdır; yeni ekranda doğrudan ortak bileşen çağrılır.

| İş | Bileşen | Kural |
|---|---|---|
| Düğme | `BuButton(kind:, compact:, busy:)` | Sayfada tek `primary`; ikincil `soft`/`outline` (çerçeve `bdStrong`); iptal `text`; silme `danger`. Yükseklik 48 (`BuSize.button`), `compact` görsel 36/hedef 48. Özel `minHeight`, `BorderRadius.circular(12\|16)` yazılmaz. Yükleniyor = `busy: true` (düğme içi çember tek meşru çember). |
| Çip/filtre | `BuChip`, yatay liste `BuChipRow` | Seçili = `soft` + `selectedBorder`. Dolu/renkli seçili çip yok. |
| Durum etiketi | `BuBadge`, sayaç `BuCountBadge` | Renk yalnız anlamsal (`ok/warn/info/danger`), diğerleri nötr. |
| Alt sayfa | `BuSheet.show` | Elle `showModalBottomSheet` yok (tutamaç, köşe 28, klavye payı hazır). |
| Onay/bilgi | `BuDialog` (+ `BuDialogAction`) | `AlertDialog` yok. Yıkıcı onayda `destructive: true`. |
| Geçici ileti | `BuToast.show(context, msg, kind:)` | `ScaffoldMessenger.showSnackBar` yok. |
| Yükleniyor | İlk yükleme `BuSkeletonList`/`BuSkeleton*`; satır içi/sayfalama `BuSpinner` | Sayfa ortasında ham `CircularProgressIndicator` yok. |
| Liste satırı / ayar | `BuListTile`, `BuSettingsTile`, `BuGroup` | |
| Boş/hata | `BuEmptyState`, `BuErrorState` (`bu_state.dart`) | Her ekranda yükleniyor/boş/hata durumu. |

Yazı: yalnız `Theme.of(context).textTheme` ya da `BuType`; elle `fontSize:` yazılmaz (ölçek: hero 28, display 22, title 18, heading 16, body 14, label 12.5, caption 11.5; en küçük 11 sp). Renk yalnız `context.bu`. Gölge/degrade/blur yok (görsel üstü okunurluk scrim'i hariç). Dokunma hedefi >= 44 dp. Alt gezinme çubuğu `BukampusBottomNavigationBar`: light'ta OPAK beyaz, dark'ta opak koyu; sahibi G1, ekranlar ona dokunmaz.

## 7. Örnekler

Standart liste sayfası:

```dart
BuPageScaffold(
  title: l10n.newsTitle,
  state: _loading ? BuViewState.loading : _error != null ? BuViewState.error : _items.isEmpty ? BuViewState.empty : BuViewState.ready,
  error: _error, onRetry: _load, onRefresh: _load,
  banner: _stale ? const BuOfflineBanner() : null,
  empty: BuEmptyState(illustration: BuIllustration.document, title: l10n.newsEmptyTitle, message: l10n.newsEmptyBody),
  bottomInset: kNavInset,
  slivers: [
    SliverToBoxAdapter(child: BuChipRow(labels: _tabs, selected: _tab, onSelected: _select)),
    SliverList.builder(itemCount: _items.length, itemBuilder: (c, i) => BuStaggerItem(index: i, child: NewsTile(_items[i]))),
  ],
)
```

Ayar grubu, onay, bildirim:

```dart
BuGroup(dividerIndent: 66, children: [
  BuSettingsTile(icon: BuIcons.globe, title: l10n.language, value: _langName, tint: context.bu.tint(1), onTap: _pickLang),
  BuSettingsTile.toggle(icon: BuIcons.bell, title: l10n.notifications, value: _on, onChanged: _setOn),
  BuSettingsTile(icon: BuIcons.logOut, title: l10n.signOut, danger: true, onTap: _confirmSignOut),
]);

final ok = await BuDialog.confirm(context, title: l10n.signOutQ, confirmLabel: l10n.signOut, destructive: true, icon: BuIcons.logOut);
BuToast.show(context, l10n.saved, kind: BuToastKind.success);
```

Alt sayfa:

```dart
BuSheet.show<void>(context, title: l10n.sortBy, actions: [BuButton(label: l10n.apply, onPressed: _apply)],
  builder: (c) => Column(children: [for (final o in _opts) BuListTile(title: o.label, selected: o == _sel, onTap: () => _pick(o))]));
```

## 8. YAPMA listesi

- Yeni kategori/etiket için yeni renk ekleme (mor, pembe, turkuaz...): palet 4 aileyle sınırlı; ayrımı simge + etiketle yap. Seçili çipte `ink`/`pr` dolgu kullanma (tek stil: `soft` + `onSoft`).
- `Color(0x..)`, `Colors.white/black/...`, sabit `fontSize`, sabit `left/right` (yalnız `start/end`, `EdgeInsetsDirectional`, `PositionedDirectional`, `AlignmentDirectional`) yazma.
- Yükleniyor için tam sayfa `CircularProgressIndicator` kullanma (iskelet). Düğme içi çember serbest.
- `showModalBottomSheet`/`AlertDialog`/`SnackBar`'ı çıplak çağırma (`BuSheet`, `BuDialog`, `BuToast`).
- Kaydırılan listede `Opacity`, `BackdropFilter`, `ShaderMask`, çoklu gölge, `saveLayer` doğuran kombinasyonlar kullanma; ağır boyacıyı `RepaintBoundary` ile izole et.
- `ListView(children: [...])` ile uzun/dinamik liste kurma (`ListView.builder`/`SliverList.builder`).
- Dokunma hedefini 48 dp'nin altına bırakma; yalnız simgeyle bilgi verme (etiket/tooltip).
- Tam genişlik `FilledButton`'ı `Row`/`AlertDialog.actions` içine koyma (sonsuz genişlik).
- Animasyonda düzen değiştirme (yükseklik/genişlik) veya sürekli animasyon (kaydırırken); `AnimationController`'ı dispose etmeden bırakma; `BuMotion.reduced`'ı yok sayma.
- `BuGradientHero`'yu vitrin dışında kullanma; her ekrana gradyan serpme.
- Imza değiştirme/silme. Çok pakette kullanılan modül widget'larında yalnız isteğe bağlı parametre ekle.
- Davranış/API/oturum/realtime/push/FLAG_SECURE dosyalarına dokunma (`docs/MOBILE_PAGES.md` 4.4).

## 9. Test altyapısı

- `test/redesign/p00_support.dart`: `p00App(child, {lang, dark, scale, scaffold, disableAnimations})` ve `p00Matrix(tester, () => widget, {widths})` — bir bileşeni **tr/en/ar × açık/koyu × yazı 1.0/1.3 × 320/390 dp** ile çizer, her birleşimde istisna (taşma dahil) arar. Her yeni ekranın testi bunu kullanmalı.
- Erişilebilirlik: `meetsGuideline(androidTapTargetGuideline)`, `labeledTapTargetGuideline`, `textContrastGuideline` (açık ve koyu temayı **ayrı** testlerde çalıştırın; tema animasyonu ortasında ölçüm yanlış çıkar).
- İskelet testte: `pump(Duration)` veya `disableAnimations: true`.
- Ekran görüntüsü kanıtı: `STORE_SHOTS_OUT='...' flutter test test/redesign/p<NN>_shots_test.dart` (galeri örneği `p00_gallery_shots_test.dart`, `P00_LANG=ar` Arapça için Windows Arial yükler).
- Galeri çıktısı (kanıt): `C:\Users\Toprak Çevik\bu-release\redesign\p00\sonraki\` (`01_renk_yazi` … `18_saat_secici`, `_koyu`, `_x1.3`, `_ar`).

## 10. Bilinen sınırlar

- `BuHeroCard` (eski) korunur ama yeni vitrinlerde `BuGradientHero` tercih edilir.
- `LoadingView` (`common.dart`) hâlâ çemberdir (9 test `CircularProgressIndicator` bekliyor); ekran yenileyen paketler iskelete geçerken testini günceller.
- `sistem_widgets.dart` (`SistemTile/Button/StatusView`) P1 ekranları içindir; `MaintenanceBand` renkleri tokenlara taşındı.
- Test ortamında elevation gölgeleri (FAB, kaydırıcı başparmağı) koyu halka gibi çizilir; cihazda yumuşak gölgedir.
