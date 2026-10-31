# BÜ Kampüs mobil tasarım sistemi (P0, Material 3 + marka)

> Durum: P0 teslimi (2026-10-29). Bu belge 19 paketin TEK referansıdır. Aşağıdaki "KİLİTLİ" arayüzler **yalnız ekleme** ile değişir (yeni isteğe bağlı parametre/sınıf); var olan imza ve davranış değişmez. Eksik/yanlış bir şey bulursanız P0 sahibine (yönetici) bildirin; kendi pakete eklemek gerekirse **kendi paket klasörünüzde** üretin.
> İlgili: `docs/MOBILE_PAGES.md` (envanter ve kurallar), `docs/MOBILE_UI.md`. Kod: `mobile/lib/core/theme.dart`, `mobile/lib/core/theme/`, `mobile/lib/widgets/`. Görsel kanıt: `mobile/test/redesign/p00_gallery_shots_test.dart`.

## 1. Tek içe aktarma

```dart
import '../../widgets/bu.dart';   // belirteçler + TÜM ortak bileşenler (+ LucideIcons)
```

`bu.dart` şunları dışa aktarır: `core/theme.dart` (BuTokens, `context.bu`, BuTheme), `typography.dart` (BuType), `BuSpace/BuGap`, `BuRadius`, `BuMotion`, `BuElevation`, `bu_widgets` (eski + yeniden biçimlenen çekirdek), `bu_list`, `bu_state`, `bu_skeleton`, `bu_overlays`, `bu_pressable`, `bu_page_scaffold`, `bu_motion_widgets`, `bu_hero`, `bu_illustrations`, `bu_image`. Tarih/format yardımcıları ve `LoadingView/ErrorView/EmptyView` hâlâ `widgets/common.dart`'tadır.

## 2. Tasarım ilkeleri

1. **Material 3 gövde, marka kimliği:** `useMaterial3`, M3 bileşenleri (NavigationBar, FilledButton.tonal, SegmentedButton, SearchBar, BottomSheet...) marka belirteçleriyle temalanır. Marka: sakin kampüs kırmızısı (`pr`), lacivert mürekkep (`ink`), sıcak-nötr zemin (`bg`), beyaz kartlar (`sf`); anlam renkleri mavi/su mavisi/yeşil/amber (bkz. bölüm 3).
2. **Katmanlı yüzeyler:** sayfa `bg` < kart `sf` < ikincil `sf2` < üst katman `sf3` (diyalog, alt sayfa, menü). Açık temada ince çizgi + yumuşak gölge, koyu temada tonal yüzey (gölge yok).
3. **Tonal vurgu:** seçili/etkin durum **marka tonu** (`soft` zemin + `onSoft` yazı + `selectedBorder`; tek stil) ile gösterilir (NavigationBar göstergesi, seçili çip, segment, tonal düğme); dolu kırmızı (`pr`) yalnız birincil eylemde.
4. **Hareket anlamlıdır:** basma (hafif küçülme + titreşim), seçim (kayan gösterge), içerik girişi (aşamalı), durum geçişi (fade-through). 150/250/400 ms; yalnız `transform`/`opacity`. "Animasyonları azalt" açıkken hepsi anlık.
5. **Durumlar eksiksiz:** yükleniyor (iskelet, çember değil) / boş (illüstrasyon + yönlendirme) / hata (yeniden dene) / çevrimdışı (şerit, eski veri) / bakım.
6. **Hız:** `const`, tembel liste, `RepaintBoundary` ile ağır boyacılar izole, tek ticker (iskelet), ağ görselinde `cacheWidth`, kaydırılan listede `Opacity/BackdropFilter/saveLayer` yok.

## 3. Renk (BuTokens - `context.bu`)

Renk yalnız `context.bu` (veya `Theme.of(context).colorScheme`) üzerinden. `Color(0x..)`, `Colors.*` yeni yazılmaz (`test/redesign/renk_paleti_test.dart` `lib/` taramasıyla denetler).

> **RENK-1 (2026-10-31): palet tek ve küçük.** Sakin marka kırmızısı + dört anlam ailesi (koyu mavi, su mavisi, yeşil, amber) + sıcak-nötr yüzeyler. Mor/pembe/turkuaz/çivit/turuncu-sarı ayrı renk olarak KALDIRILDI; kategori ayrımı renkten çok simge + etiketle yapılır. Gerekçe: "çok fazla renk var, sabit ve temiz olsun, göz yormasın". Envanter ve önce/sonra: `docs/design/RENK_ENVANTERI.md`. Bu belgedeki "KİLİTLİ" imzalar değişmedi (yalnız eklendi: `info*`, `aqua*`, `onOkSoft`, `dangerSoft`, `bdStrong`, `selectedBorder`, `BuTintId`); düzen/boyut değişmedi.

| Belirteç | Açık | Koyu | Kullanım |
|---|---|---|---|
| `bg` | #F7F5F2 | #171819 | sayfa zemini (sıcak kırık beyaz / yumuşak kömür) |
| `sf` | #FFFFFF | #202123 | kart, girdi, liste |
| `sf2` | #EEEBE6 | #2A2B2E | ikincil yüzey, segment zemini, yer tutucu, iskelet |
| `sf3` | #FFFFFF | #313235 | diyalog, alt sayfa, menü, NavigationBar |
| `ink` / `mut` | #171E33 / #5C5A56 | #F2EFEA / #A9A7A2 | ana / soluk yazı |
| `bd` | #DAD5CD | #3A3B3F | kart/ayraç çizgisi (dekoratif) |
| `bdStrong` (yeni) | #8A857E | #7D8087 | **kontrol çerçevesi**: giriş alanı, arama, seçilmemiş seçim halkası, outlined düğme. Tüm yüzeylere karşı >= 3:1 (WCAG 1.4.11) |
| `pr` / `onPr` | #C0392B / #FFF | #F0766A / #2A0B07 | birincil eylem, seçili durum vurgusu (yalnız bunlar) |
| `soft` / `onSoft` | #FBE9E6 / #8A2A20 | #3B2321 / #FFBBB2 | seçili/tonal zemin ve yazısı |
| `selectedBorder` (yeni, getter) | `pr` %45 | `pr` %45 | seçili çip/segment çerçevesi |
| `info` / `infoSoft` / `onInfoSoft` (yeni) | #1F4E96 / #E4ECF8 / #173F7B | #8DB4F0 / #1B2B45 / #B9D2FA | bilgi, haber, duyuru (koyu mavi) |
| `aqua` / `aquaSoft` / `onAquaSoft` (yeni) | #0B6E86 / #DDF1F6 / #0A5468 | #6CCBE0 / #11323B / #A6E3F0 | ikincil vurgu (su mavisi) |
| `ok` / `okSoft` / `onOkSoft` | #1E7A50 / #E0F2E8 / #0F5132 | #6FD0A0 / #16301F / #9BE3BE | başarı, yemek |
| `warn` / `warnSoft` / `onWarnSoft` | #9A5700 / #FFF1D6 / #6B3E00 | #F2B24A / #3A2B0E / #FFD98F | uyarı, hatırlatma, bekleyen, çevrimdışı/bakım şeridi |
| `danger` / `dangerSoft` | #A3162E / #FBE4E8 | #FF8FA0 / #3D1D24 | hata, yıkıcı eylem (marka kırmızısından ton olarak ayrı) |
| `nav` / `onNav` | #171E33 / #FFF | #35373B / #F2EFEA | yüzen/koyu hap |
| `h1`/`h2` + `hero` | #C8402F -> #BB3628 | #B5362B -> #992E24 | yalnız vitrin; iki uç neredeyse eş (düz görünür) |
| `onMedia` | #FFFFFF | #FFFFFF | fotoğraf/video üstü yazı-simge |
| `scrim` | #000000 | #000000 | medya zemini ve karartma (`.withValues(alpha:)`) |
| `qrInk` / `qrPaper` | #000 / #FFF | aynı | QR (her temada yüksek kontrast) |
| `shadow` | #171E33 | #000 | gölge |
| `tints` / `tint(i)` | 6 çift | 6 çift | kategori renkleri; `context.bu.tint(BuTintId.blue)`; indeksler: 0 marka, 1 mavi, 2 yeşil, 3 amber, 4 su mavisi, 5 nötr |

**Seçili çip/segment: TEK stil** (A6-03): `soft` zemin + `onSoft` yazı + `selectedBorder` çerçeve (`BuChip` ile aynı). Keşfet, Sohbet, Kulüpler, Akademik (gün, sınav, bildirim süzgeçleri), Etkinlik, Arama, Destek, Bildirimler artık bu stili kullanır; "lacivert/beyaz ters çevrilen" ve "dolu kırmızı" çipler kaldırıldı. Dolu `pr` yalnız birincil eylem düğmesindedir.

**Kontrol çerçevesi / kart ayrımı** (A6-02): metin alanı ve seçim halkası çizgisi `bdStrong` (3:1 üstü); kartlar `bd` çizgisi + yumuşak gölgeyle ayrılır, yüzey koyulaştırılmaz. Çizgi `bd` biraz güçlendirildi (#E3DFD9 -> #DAD5CD).

**Anlam kuralları:** mavi = bilgi/haber/kişisel hesap; su mavisi = ikincil (etkinlik, topluluk, duyuru rozeti); yeşil = başarı/yemek; amber = uyarı/hatırlatma/bekleyen/etkinlik tarihi; kırmızı `pr` = eylem/seçili, `danger` = hata. Yeni kategori için yeni renk eklenmez, simge + etiket kullanılır.

ColorScheme eşlemesi: `primary=pr`, `primaryContainer=soft`, `secondary=ink`, `secondaryContainer=soft`, `tertiary=ok`, `error=danger`, `errorContainer=dangerSoft`, `surface=sf`, `surfaceContainerHigh=sf3`, `surfaceContainerHighest=sf2`, `outline=mut`, `outlineVariant=bd`. Kontrast: tüm metin çiftleri AA (>= 4.5:1), kontrol çerçeveleri >= 3:1; test: `test/redesign/p00_theme_test.dart` ve `test/redesign/renk_paleti_test.dart`. Durum çubuğu: `AppBar.systemOverlayStyle` açık/koyu için açıkça verilir (Android ikon parlaklığı, iOS `statusBarBrightness`); Cupertino bileşenleri `cupertinoOverrideTheme` ile aynı belirteçleri kullanır.

Geçmiş: INT-I2'de açık tema Stitch'in soğuk gri-mavi tonlarına çekilmişti (`bg` #F8F9FC, `sf2` #EDEEF1, `bd` #E7E8EB, `mut` #575E76); RENK-1 bunu sıcak-nötr yüzeylerle değiştirdi (kullanıcı isteği: sakin, kırık beyaz zemin; koyu temada saf siyah değil yumuşak kömür). `SistemTones.radioOff` artık `mut` %70.

## 4. Yazı (Inter; `Theme.of(context).textTheme`)

| Rol | Boyut/ağırlık | Kullanım |
|---|---|---|
| displayLarge / Medium / Small | 40 / 34 / 30, 800 | karşılama, büyük sayı |
| headlineLarge / Medium / Small | 28 / 24 / 20, 800-700 | büyük sayfa başlığı (large app bar genişken: headlineMedium), bölüm başlığı |
| titleLarge | 18, 700 | app bar başlığı (daralmış), diyalog/alt sayfa başlığı, boş durum başlığı |
| titleMedium | 15.3, 700 | kart/bölüm başlığı, düğme (tam genişlik) |
| titleSmall | 13.5, 600 | satır başlığı |
| bodyLarge / Medium / Small | 15 / 13.5 / 12, 400 | gövde, açıklama, yardımcı metin |
| labelLarge / Medium / Small | 13.5 / 12 / 11, 600-500 | düğme, çip, rozet, zaman |

- Yeni kodda **`textTheme`** kullanın; `BuType` (eski ölçek: display 23.4 … micro 9.9) KİLİTLİ ve çalışır, ama yeni ekranda tercih edilmez. Elle `fontSize:` yazılmaz; renk `.copyWith(color: t.mut)` ile verilir.
- Arapça: harf aralığı 0, satır yüksekliği ×1.12 (`BuTheme.light()/dark()` `LocaleController.current` dilinden seçer; test için `BuTheme.forLocale(Brightness, 'ar')`). Başlıkta elle `letterSpacing` verirseniz Arapçada 0 yapın.
- En küçük metin 11 dp (`labelSmall`); 1.3x ölçekte taşma olmamalı (`maxLines` + `overflow` + esnek düzen; gerekirse `MediaQuery.withClampedTextScaling`).

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

Kurallar: "animasyonları azalt" (`MediaQuery.disableAnimations`) açıkken tüm bu bileşenler anlık çalışır (süre 0; `BuMotion.of`); yalnız `transform`/`opacity` canlandırın; uzun/sonsuz animasyonlu listede `RepaintBoundary` ile ayırın. Uygulama içi ayrı bir "hareketi azalt" anahtarı yoktur; yalnız sistem ayarı dikkate alınır.

### 6.6 Tema bileşenleri (M3'ü doğrudan kullanın, ek stil gerekmez)

`FilledButton`/`.tonal`/`OutlinedButton`/`TextButton` (tema **tam genişlik 54 dp**; satır içinde `minimumSize: Size(0, 48)` verin), `IconButton(.filled/.filledTonal)`, `NavigationBar` (hap gösterge = `soft`), `AppBar`/`SliverAppBar(.large)`, `Card`, `FilterChip/ChoiceChip/InputChip/ActionChip` (hap, seçili `soft`), `TextField` (dolu + çerçeveli, odak 2 dp `pr`), `SearchBar/SearchAnchor`, `SegmentedButton`, `BottomSheet`, `AlertDialog`, `SnackBar`, `ListTile`, `Switch/Checkbox/Radio/Slider`, `Linear/CircularProgressIndicator`, `Badge`, `Divider`, `Tooltip`, `PopupMenu`, `TabBar`, `ExpansionTile`, `FloatingActionButton`, `showDatePicker/showTimePicker`. Hepsi `lib/core/theme/bu_component_themes.dart` içinde.

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
  BuSettingsTile(icon: LucideIcons.globe, title: l10n.language, value: _langName, tint: context.bu.tint(1), onTap: _pickLang),
  BuSettingsTile.toggle(icon: LucideIcons.bell, title: l10n.notifications, value: _on, onChanged: _setOn),
  BuSettingsTile(icon: LucideIcons.logOut, title: l10n.signOut, danger: true, onTap: _confirmSignOut),
]);

final ok = await BuDialog.confirm(context, title: l10n.signOutQ, confirmLabel: l10n.signOut, destructive: true, icon: LucideIcons.logOut);
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
