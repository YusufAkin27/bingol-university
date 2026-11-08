# Ana ekran widget tasarım sistemi (Aşama 2)

Bu belge yedi widget'ın (menu, timetable, events, announcements, poll, quickaccess, social) **tek ortak belirteç kaynağıdır**. Aynı değerler üç koda birebir taşınır ve `mobile/test/widgets/widget_tokens_test.dart` bu belgeyi, üç dosyayı ve BuTokens'ı karşılaştırır (bir değer değişirse test kırılır):

| Katman | Dosya |
|---|---|
| Dart (yalnız uygulama içi önizleme/test; renkler `BuTokens`'tan okunur) | `mobile/lib/features/widgets/widget_tokens.dart` |
| iOS (WidgetKit, `BUWidgets` hedefi) | `mobile/ios/BUWidgets/Shared/BuWidgetTokens.swift` |
| Android (Glance) | `mobile/android/app/src/main/kotlin/edu/bingol/bu_kampus/widgets/WidgetTokens.kt` + `res/values/widget_colors.xml` + `res/values-night/widget_colors.xml` |

Veri tarafı: [DATA_CONTRACT.md](DATA_CONTRACT.md). Görsel referans: `<slug>/*.png`. Birim: iOS pt = Android dp = CSS px (1:1); PNG'ler 3x piksel.

## 1. BuTokens uzlaştırması (karar: BuTokens kazanır)

Tasarım operatörleri README'lerdeki onaltılık renkleri `BuTokens`'tan okumadan seçti. Aşağıdaki fark listesi tek seferde çözüldü; **kaynak doğruluk `mobile/lib/core/theme.dart` (`BuTokens.light/dark`)**. Kural: kalın yazı yok (tek ağırlık 400), kırmızı yalnız tehlike/kalp, marka rengi yok.

| Konu | README'deki değer | Karar (BuTokens) | Not |
|---|---|---|---|
| Widget zemini, koyu | #111113 (iOS) / #18181B (Android) | `bg` #09090B | iOS/Android ayrımı kalktı: tek zemin |
| Widget zemini, açık | #FFFFFF | `bg` #FFFFFF | aynı |
| Chip / vurgulu satır, koyu | #1F1F23 / #232327 | `sf2` #1C1C1F | |
| Kenarlık, koyu | #27272A | `bd` #303034 | açık #E4E4E7 aynı |
| Anket çubuğu izi, koyu | #27272A / #2E2E33 | `bd` #303034 | |
| Etkinlik rozeti dolgusu, koyu | #09090B | `sf2` #1C1C1F | #09090B artık zeminle aynı olurdu |
| Rozet kenarı, açık / koyu | #D4D4D8 / #3F3F46 | `bd` #E4E4E7 / #303034 | |
| Pasif nokta (duyuru), açık / koyu | #D4D4D8 / #3F3F46 | `bdStrong` #8A8A93 / #71717A | okunur kalsın |
| Kalp, koyu | #F2555A | `heart` #EF4444 | açık #DC2626 aynı; YALNIZ beğeni kalbi |
| Acil duyuru metni, açık / koyu | #DC2626 / #EF4444 | `danger` #C81E1E / #F87171 | kalp ile aynı kırmızı DEĞİL; YALNIZ "Acil" |
| Etkinlik büyük gün rakamı | Inter Light 300 | 400 | "kalın yazı yok" kuralı: tek ağırlık |
| Satır yükseklikleri (events/announcements) | 13/17, 12/14 | 13/18, 12/16 | ortak ölçeğe normalize (en çok 2 px fark) |
| Yazı tipi | Inter (PNG'ler) | sistem fontu (SF / Roboto; Arapçada sistem yedeği), **aynı boyutlar** | uzantı belleği ve Arapça kapsama için; Inter paketlenirse ölçüler değişmez |

Bilinen sınır: koyu temada `text3` (`mutSoft` #71717A) zemin #09090B üzerinde yaklaşık 4,0:1 kontrast verir (AA küçük metin için 4,5:1). Bu uygulamanın genel `mutSoft` kararıdır; widget'larda `text3` yalnız caption/ipucu/yardımcı metinde kullanılır, tek başına taşıyıcı bilgi `text2` ile yazılır. Açık temada 4,95:1.

## 2. Kabuk ve boyutlar

| Platform | Aile | Referans ölçü | Köşe | İç boşluk | Kenarlık |
|---|---|---|---|---|---|
| iOS | small | 158x158 | 22 | 16 | 1 |
| iOS | medium | 338x158 | 22 | 16 | 1 |
| iOS | large | 338x354 | 22 | 16 | 1 |
| Android | 2x2 (small) | 170x170 | 28 | 16 | 1 |
| Android | 4x2 (medium) | 350x170 | 28 | 16 | 1 |
| Android | 4x4 (large) | 350x350 | 28 | 16 | 1 |

Tek düz zemin (`bg`), gölge ve gradyan yok, kenarlık `border` rengi. Tek istisna: Hızlı Erişim small/2x2 iç boşluğu **12** (karo alanı büyük olsun). iOS 17+: `containerBackground(for: .widget)` aynı renk, tıklama `widgetURL`. Android: dış `Box` kenar rengi 28 dp, iç `Box` zemin 27 dp (1 dp inset); Material You dinamik renk KULLANILMAZ.
Tema = **sistem teması** (uygulama içi tema widget'a yansımaz; meta `theme: system`).

## 3. Renk belirteçleri

Rol adı, BuTokens karşılığı ve değer. (Test bu tabloyu okur: ilk sütun rol, 3. sütun açık, 4. sütun koyu.)

| Rol | BuTokens | Açık | Koyu | Kullanım |
|---|---|---|---|---|
| `bg` | `bg` | #FFFFFF | #09090B | widget zemini |
| `chip` | `sf2` | #F4F4F5 | #1C1C1F | karo, vurgulu satır, kcal chip |
| `border` | `bd` | #E4E4E7 | #303034 | 1 px dış çizgi ve ayırıcılar |
| `text1` | `ink` | #09090B | #FAFAFA | birincil yazı ve ikon |
| `text2` | `mut` | #52525B | #A1A1AA | ikincil yazı |
| `text3` | `mutSoft` | #71717A | #71717A | caption, ipucu, yardımcı metin |
| `inverseBg` | `pr` | #09090B | #FAFAFA | ters rozet, "Oy ver" hapı |
| `inverseFg` | `onPr` | #FFFFFF | #09090B | ters rozet yazısı |
| `barFill` | `pr` | #09090B | #FAFAFA | anket çubuğu (lider tam, diğerleri %45 opaklık) |
| `barTrack` | `bd` | #E4E4E7 | #303034 | anket çubuğu izi |
| `badgeFill` | `sf2` | #F4F4F5 | #1C1C1F | etkinlik tarih rozeti |
| `badgeBorder` | `bd` | #E4E4E7 | #303034 | etkinlik tarih rozeti kenarı |
| `dotPassive` | `bdStrong` | #8A8A93 | #71717A | duyuru pasif noktası |
| `heart` | `heart` | #DC2626 | #EF4444 | YALNIZ beğeni kalbi (sosyal) |
| `danger` | `danger` | #C81E1E | #F87171 | YALNIZ acil duyuru ("Acil" metni, medium noktası) |

Android XML adları: `bu_widget_` + rolün snake hali (`bu_widget_inverse_bg`, `bu_widget_dot_passive`...). Opaklıklar: geçmiş ders satırı 0,5; lider olmayan anket çubuğu 0,45; logo 0,9.

## 4. Tipografi (tek ağırlık: 400)

Satır: boyut/satır yüksekliği. Harf aralığı em cinsinden (negatif sıkıştırır). `caps` = BÜYÜK HARF (Arapçada uygulanmaz; metin zaten hazır büyük yazılır, bkz. DATA_CONTRACT).

| Rol | Boyut | Satır | Harf aralığı | caps | Kullanım |
|---|---|---|---|---|---|
| `caption` | 10 | 12 | 0.08 | evet | başlık etiketi (ÖĞLE, ANKET), tarih |
| `micro` | 11 | 14 | 0 | - | karo etiketi, ipucu, başlık satırı (events/announcements), meta |
| `small` | 12 | 16 | 0 | - | kcal, yüzde, derslik, alt bilgi |
| `body` | 13 | 18 | 0 | - | yemek/ders adı, satır metni |
| `bodyL` | 14 | 18 | 0 | - | etkinlik small başlığı, duyuru large başlığı |
| `question` | 15 | 20 | -0.01 | - | anket sorusu, duyuru small başlığı, etkinlik large başlığı |
| `title` | 17 | 22 | -0.01 | - | small ders adı, large başlıklar |
| `display` | 22 | 26 | -0.02 | - | menü small ana yemek, boş durum, oturumsuz |
| `number` | 34 | 38 | -0.03 | - | sosyal sayı (small, medium) |
| `numberRow` | 28 | 32 | -0.03 | - | sosyal large satır sayısı |
| `badgeDaySmall` | 13 | 13 | 0 | - | etkinlik rozeti gün (satır 30/36) |
| `badgeMonthSmall` | 9 | 10 | 0.08 | evet | etkinlik rozeti ay (satır 30/36) |
| `badgeDayLarge` | 18 | 20 | 0 | - | etkinlik rozeti gün (44x48) |
| `badgeMonthLarge` | 10 | 12 | 0.08 | evet | etkinlik rozeti ay (44x48) |
| `eventDayHero` | 34 | 36 | -0.03 | - | etkinlik small büyük gün rakamı |

iOS: `.font(.system(size: size, weight: .regular))`, `.tracking(em * size)`, `.lineSpacing(max(0, line - 1.2 * size))`. Android: `TextStyle(fontSize = size.sp, fontWeight = Normal)`; sistem yazı ölçeği 1.0 üstüne çıkarsa boyut `size / fontScale` ile sabitlenir (tasarım ölçekle büyümez; satır sayısı sınırları geçerli).

## 5. Boşluk, köşe, ikon, satır ölçüleri

Boşluk ölçeği: 2, 4, 6, 8, 10, 12, 14, 16 (`s2`..`s16`). Başka boşluk kullanılmaz.

| Belirteç | Değer | Nerede |
|---|---|---|
| `paddingDefault` | 16 | tüm widget'lar |
| `paddingQuickSmall` | 12 | yalnız Hızlı Erişim small/2x2 |
| `headerHeight` | 16 | başlık satırı (ikon + caption solda, logo sağda) |
| `headerGap` | 12 | başlık satırı altı (menü/ders medium'da 8-12, sosyal/hızlı erişim large'da 4: widget notu) |
| `tileGap` | 8 | hızlı erişim karoları, sosyal satırlar arası |
| `radiusRow` | 12 | ders satırı, kcal chip, hızlı erişim small karosu (`radiusChip` 12) |
| `radiusTile` | 14 | hızlı erişim medium/large karosu, sosyal large satır |
| `radiusBadgeSmall` | 8 | ters rozet (ders saati), etkinlik rozeti 30/36 |
| `radiusBadgeLarge` | 10 | etkinlik rozeti 44x48 |
| `radiusBar` | 2 | anket çubuğu (yükseklik `barHeight` 4) |
| hap | tam yuvarlak | "Oy ver" (yükseklik `pillHeight` 28, yatay iç boşluk `pillPaddingX` 14) |

İkon: Lucide çizgi, vuruş 1.5, round uç/birleşim, `currentColor` (rol rengi). Native varlık: Lucide adlarıyla SVG/PDF/vector drawable (SF Symbols DEĞİL). Adlar: `vote, utensils, calendar-clock, ticket, users, message-circle, qr-code, newspaper, search, bell, heart, lock, chevron-right, message-square, circle-check, calendar, clock, map-pin, megaphone, sun, moon, flame`.

| İkon belirteci | Boyut | Nerede |
|---|---|---|
| `iconHeader` | 12 | başlık satırı (menü, ders, anket, hızlı erişim, sosyal), satır içi küçük |
| `iconHeaderEvents` | 14 | etkinlik/duyuru başlık ikonu (small) |
| `iconMeta` / `iconMetaLarge` | 12 / 14 | saat, mekan (medium / large) |
| `iconTileMedium` | 18 | hızlı erişim medium karo, sosyal medium sütun |
| `iconRowLarge` | 22 | sosyal large satır, hızlı erişim small karo |
| `iconTileLarge` | 24 | hızlı erişim large karo |
| `iconEmptySmall` / `iconEmptyMedium` / `iconEmptyLarge` | 20 / 22 / 28 | boş durum ikonu |

Logo: `mobile/assets/branding/logo_dark.png` (beyaz glif, KOYU tema), `logo_light.png` (siyah glif, AÇIK tema). Yükseklik `logoHeight` 12 (menü, ders, anket, hızlı erişim, sosyal) / `logoHeightEvents` 14 (etkinlik, duyuru); opaklık 0,9; başlık satırında sağ üst. Hızlı erişim small, etkinlik small ve duyuru small'da logo YOK (yer yok / başlıksız); diğer small'larda sağ üstte var.

Satır/karo ölçüleri:

| Belirteç | Değer | Nerede |
|---|---|---|
| `rowTimetableMedium` | 36 | ders satırı medium (aralık 4) |
| `rowTimetableLarge` | 40 | ders satırı large (aralık 6) |
| `badgeTimetableWidth` | 52 | ters rozet / saat sütunu genişliği |
| `rowEventsIos` / `rowEventsAndroid` | 30 / 36 | etkinlik medium satırı (Android WidgetTokens `ROW_EVENTS` 36) |
| `badgeEventLargeWidth` x `badgeEventLargeHeight` | 44 x 48 | etkinlik large rozeti |
| `rowSocialLarge` | 64 | sosyal large satır |
| `kcalChipHeight` | 36 | menü large "Günlük toplam" chip |

## 6. Boyuta göre içerik (kaç satır / kaç öğe)

`WidgetLayouts` (Dart), `BuWidgetTokens` (Swift), `WidgetTokens` (Kotlin) bu sayıları taşır. Sayılar **tavandır**: veri azsa azı çizilir.

| Widget | small / 2x2 | medium / 4x2 | large / 4x4 |
|---|---|---|---|
| `menu` | öğle ana yemeği (display, en çok **2** satır) + "Çorba · Pilav · Salata" (tek satır) + alt kcal satırı | **3** yemek/sütun (tek öğünde 2 sütun = 6); alt "Toplam N kcal" | **4** yemek/bölüm (tek öğünde **8**), yemek kcal sağda; alt "Günlük toplam" chip; 4'ten çoksa `+N yemek` |
| `timetable` | sıradaki ders: saat rozeti + "N dk sonra" + ad (**2** satır) + derslik | **2** ders satırı | **4** ders satırı + "Bugün N ders" + alt not |
| `events` | **1** etkinlik (büyük gün, başlık **2** satır, saat) | **3** etkinlik (rozet + başlık + kulüp + saat) | **3** etkinlik (+ mekan) |
| `announcements` | **1** duyuru (başlık **4** satır + meta) | **3** duyuru (nokta + başlık 1 satır + meta) | **4** duyuru (başlık **2** satır + meta) |
| `poll` | soru (**3** satır) + "Oy ver" hapı / "Oy verildi" | soru (**3** satır, sol %40) + **3** seçenek çubuğu | soru (**2** satır) + **2-4** seçenek (en çok 4) + alt satır |
| `quickaccess` | **4** karo (2x2) | **8** karo (4x2) | **8** karo (4x2, ikon 24) |
| `social` | 1 büyük sayı (mesaj) + alt satırda bildirim ve beğeni | **3** sütun | **3** satır |

Menü tek öğün uyarlaması: backend menüyü öğüne bölmez (tek liste = öğle). Bu yüzden `meals` dizisinde bugün 1 öğün vardır; medium'da yemekler iki sütuna bölünür (ilk 3 / sonraki 3, ikinci sütunun caption'ı yoktur), large'da tek bölüm 8 yemeğe kadar gider. Akşam öğünü `meals`'a eklendiğinde README'deki iki sütun/iki bölüm düzeni olduğu gibi geçerlidir.

Metin kesme (hepsi): tek satırlık alan `maxLines=1` + kuyruk `…`; çok satırlıda belirtilen satır sayısı sonra `…`. Metin küçültme/otomatik ölçekleme YOK. Kesilmeyenler: tarih, derslik (en çok 8 karakter, uygulama kırpar), saat, sayılar, rozetler.

## 7. Farklı ekran ölçekleri için ölçü kuralları

1. **Referans ölçü yalnız sıfır noktasıdır.** Gerçek cihazda iOS small 141-170 pt, medium 292-364 x 141-170, large 292-382 x 311-382; Android hücre boyutu launcher'a göre ±%15 oynar. Genişlik esner (satır metni `…` ile kesilir), yükseklik esner (esnek boşluk `Spacer`/`flex 1` alt satırları ve ayırıcıları dibe iter).
2. **Sabit kalanlar:** yazı boyutları, ikon boyutları, köşe yarıçapları, iç boşluk 16, kenarlık 1, rozet/pill/chip ölçüleri. Hiçbir şey `scaleEffect`/orantıyla küçültülmez.
3. **Sığmayan satır düşer:** kullanılabilir yükseklik `H = yükseklik - 2*iç boşluk - başlık(headerHeight + headerGap)`. Satır sayısı `n = min(tavan, floor((H + aralık) / (satırYüksekliği + aralık)))`. Önce son satır düşer, ayırıcılar ve başlık korunur. En az 1 satır her zaman çizilir.
4. **Sistem "daha büyük yazı":** iOS `.dynamicTypeSize(...DynamicTypeSize.large)` ile sabitlenir; Android `size / fontScale` ile sabitlenir. Satır sayısı sınırları (bölüm 6) geçerli, taşan satır düşer.
5. **RTL (Arapça):** mantıksal yönler (`leading/trailing`, `Start/End`); chevron ve ters ok simgeleri aynalanır; sayı ve saat Batı rakamlarıyla yazılır (snapshot'ta hazır); `rtl: true` snapshot alanı yerleşimi belirler.
6. **Android 12+ yuvarlak köşe:** sistem `system_app_widget_background_radius` ezebilir; kabuk 28 dp'yi kullanır, uyumsuzlukta `android:background` boş bırakılır ve Glance kenarlık kutuları kullanılır.
7. **Önizleme/galeri:** koyu/açık sistem temasını izler; galeri önizlemesi `bu_widget_*` yoksa "oturumsuz" düzeniyle (Giriş yap) çizilir, hiçbir kişisel veri içermez.

## 8. Widget'a özgü başlık ve düzen notları (README'den, tek yerde)

| Widget | Başlık satırı | Notlar |
|---|---|---|
| `menu` | ikon (sun/moon/utensils) + caption (`ÖĞLE`, tarih); logo sağ; alt boşluk 12 (medium 8) | small'da kcal satırı alt kenarda (flame 12 + metin); chip large'da |
| `timetable` | clock/cal ikonu + caption; alt boşluk 12 | sıradaki satır `chip` zemin + ters rozet; biten satır opaklık 0,5; "Şu an" rozeti |
| `events` | logo (14) + "Yaklaşan Etkinlikler" (`micro`, text2); large'da sağda "{n} etkinlik" (`micro`, text3) | satırlar arası 1 px ayırıcı (large); mekan yoksa mekan öğesi tamamen gizlenir |
| `announcements` | logo + "Kampüs Duyuruları"; large'da sağda "Son {n}" | large'da nokta yok (ilk satır text1); acil: metin başı `danger` |
| `poll` | vote ikonu + caption `ANKET`/`GÜNÜN ANKETİ`; logo sağ | lider seçenek tam renk + yüzde text1; diğerleri çubuk %45 opaklık, yüzde text2 |
| `quickaccess` | small'da başlık YOK; medium'da search ikonu + `HIZLI ERİŞİM` + logo (alt boşluk 10); large'da caption + logo (alt boşluk 4) + başlık/alt metin | karo `chip` zemini; her karo kendi bağlantısı |
| `social` | message-square/message-circle ikonu + caption; logo sağ | kalp `heart` kırmızı (tek kırmızı); 3 sütun arası 1 px `border` ayırıcı |

## 9. Boş / oturumsuz durumlar (tüm widget'lar)

- Veri yok → o slug'ın boş durumu (README'deki ikon + `display` başlık + ikincil metin; metinler snapshot `strings` içinde hazır).
- Oturum yok (`meta.signedIn=false` veya snapshot yok) → `display` "Giriş yap" + `micro` "BÜ Kampüs'ü aç" (dil `meta.lang`), dokununca `bukampus://home`. Hiç eşitlenmemişse (meta yok) native paketindeki iki yerel metin kullanılır.
- "Güncel değil" yazısı GÖSTERİLMEZ (README karar): süresi geçen snapshot boş duruma düşer (bkz. DATA_CONTRACT bayatlık tablosu).

## 10. Flutter köprüsü kararı: `home_widget` ^0.10.0 (kullanıldı)

Karar: **`home_widget` eklentisi kullanılır, kendi MethodChannel köprüsü yazılmaz.** Gerekçe (pub.dev ve paket kaynağı incelendi, 2026-11-06):

- pub.dev: 0.10.0, 160/160 puan, ~2,2 bin beğeni, ~336 bin indirme, yayıncı doğrulanmış (antonborri.es), BSD-3; iOS **ve** Android.
- iOS **SwiftPM destekli** (`ios/home_widget/Package.swift`, yalnız `FlutterFramework`; ek SwiftPM bağımlılığı yok → Firebase/GoogleSignIn bağımlılık grafiğine (docs/IOS_RELEASE.md "Google ile giriş ve SwiftPM") dokunmaz, CocoaPods gerekmez). Platform alt sınırı iOS 14 (uygulama 15).
- Android: `androidx.work` ve `androidx.core` ekler (küçük); `minSdk` uygulamanınkinden (Flutter varsayılanı) düşük/eşit. Eklenti Android'de `HomeWidgetPreferences` SharedPreferences'ına, iOS'ta `setAppGroupId` ile App Group `UserDefaults`'a yazar: sözleşmenin depo kararıyla birebir örtüşür.
- Aynı bağımlılık (path_provider) zaten projede. Eklenen tek yeni paket `home_widget` (`pubspec.lock` +8 satır: home_widget).
- Kendi köprümüz iki platformda native taraf kodu (Swift+Kotlin) gerektirir ve widget ajanlarından önce test edilemez; eklenti bunu hazır ve bakımlı verir. Kullanmadıklarımız: `renderFlutterWidget` (görüntü), arka plan callback'leri, `widgetClicked` akışı (dokunuşlar `bukampus://` URL'si ile `app_links` üzerinden gelir, bölüm DATA_CONTRACT 8).
- Uyumlu kullanım: `HomeWidget.setAppGroupId` (iOS), `saveWidgetData<String>`, `updateWidget(iOSName, qualifiedAndroidName)`, `scheduleWidgetUpdates` (yalnız Android, sağlayıcı yoksa sessiz). Tüm çağrılar `try/catch` içindedir ve yalnız iOS/Android'de çalışır (`HomeWidgetStore`); testler `MemoryWidgetStore` kullanır.

Android ajanının eklemesi gerekenler: widget receiver'ları manifest'e, `es.antonborri.home_widget.HomeWidgetScheduledUpdateReceiver` + `RECEIVE_BOOT_COMPLETED` (gece 00:05 yenilemesi için; `SCHEDULE_EXACT_ALARM` istenmez, alarm esnek kalır). iOS ajanının eklemesi gerekenler: BUWidgets hedefi, App Group yetkisi (Runner + BUWidgets), `Shared/BuWidgetTokens.swift`'i hedefe dahil etmek.

## 11. Doğrulama

`cd mobile && flutter test test/widgets` — `widget_tokens_test.dart` bu belgedeki renk/tipografi tablolarını, `widget_tokens.dart`, `BuWidgetTokens.swift`, `WidgetTokens.kt`, `widget_colors.xml` (açık/koyu) ve BuTokens'ı karşılaştırır; ağırlık 400 dışında yazı ve ham renk sızıntısı da denetlenir.
