# iOS (WidgetKit) tasarım eşleşme tablosu — `mobile/ios/BUWidgets/`

Kaynak: `DESIGN_SYSTEM.md` (belirteçler), `DATA_CONTRACT.md` (veri), her slug'ın `README.md` + PNG'leri. Uygulama: SwiftUI + WidgetKit, ölçüler yalnız `Shared/BuWidgetTokens.swift`'ten (ham sayı yok; tek istisna aşağıda).

**DURUM: HİÇBİRİ cihazda/simülatörde görsel olarak DOĞRULANMADI.** Bu makine Windows (Xcode/Swift derleyicisi yok). Aşağıdaki "Uyum" sütunu *koddan okunarak* karşılaştırmadır; piksel doğrulaması macOS CI/cihazda yapılacaktır. Yazı tipi: PNG'ler Inter, widget SF (DESIGN_SYSTEM bölüm 1 kararı; boyutlar aynı, genişlikler ±birkaç pt oynar).

## Kabuk (tüm widget'lar)

| Öğe | Spec | Kod | Uyum |
|---|---|---|---|
| Zemin | tek düz `bg`, gölge/gradyan yok | `BuBackground`: `ContainerRelativeShape().fill(theme.bg)`; iOS 17+ `containerBackground(for: .widget)`, eski `background` | kodda evet |
| Kenarlık | 1 px `border`, köşe 22 | `ContainerRelativeShape().strokeBorder(border, 1)` (köşe sistemden; sabit 22 değil) | **fark:** köşeyi sistem verir (cihazda 22 ± birkaç pt), amaç hizalama |
| İç boşluk | 16 (hızlı erişim small 12) | `BuInset` -> iOS 17+: `widgetContentMargins` farkı tamamlar (`target - margin`, en az 0), eski: `padding(target)` | kodda evet; iOS 17'de sistem kenar boşluğu >16 ise (iPad) 16'ya inemez |
| Tema | sistem açık/koyu | `@Environment(\.colorScheme)` -> `BuWidgetPalette` | evet |
| Dinamik yazı | sabit (`...large`) | `.dynamicTypeSize(...DynamicTypeSize.large)`; yazılar `.system(size:)` (ölçeklenmez) | evet |
| Yön | `rtl` snapshot'tan | `.environment(\.layoutDirection)`; `leading/trailing`; chevron `mirrorsInRTL` | evet |
| Ağırlık | yalnız 400 | her yerde `.regular` (`BuWidgetTokens.fontWeight`); static kontrol `weight: .x` tarar | evet |
| Harf aralığı | em x boyut | `kerning(trackingPoints)`; Arapçada 0 (bağlantı bozulmasın) | evet (+AR kararı) |
| Satır yüksekliği | boyut/satır | tek satır: `frame(height: line)`; çok satır: `lineSpacing(max(0, line-1.2*size))` | yaklaşık (SF doğal satırı Inter'den farklı) |
| Kesme | tek satır `...`, çok satır N | `lineLimit` + `truncationMode(.tail)`, küçültme yok | evet |
| Logo | 12 (events/duyuru 14), opaklık 0.9, sağ üst | `BuLogo`, asset `BuLogo` açık/koyu | evet |
| İkonlar | Lucide, 1.5 vuruş, round | `BuIcon` + `BuIconData` (tasarım üreticisindeki SVG yolları, Python ile Bezier'e çevrildi, önizleme gözle doğrulandı) | evet |
| Dokunma | gövde `widgetURL`, satır `Link` | `BuFrame(link:)`, `BuLinkRow`; yalnız `bukampus://` kabul | evet |

## Menü (`BUMenuWidget`, `bukampus://menu`)

| Boyut | Spec | Kod |
|---|---|---|
| small | başlık `ÖĞLE`+sun; display 22/26 en çok 2 satır; sub small t2 tek satır (üst 4); alta flame 12 + kcal satırı | `smallView`: `BuHeader(sun)`, `display` lines=`menuSmallMainLines`(2), `small` t2 padding s4, `Spacer`, flame `iconHeader` + `small.kcalLine` |
| medium | başlık tarih+utensils (alt 8); 2 sütun, 16 aralık, 1 px ayraç; sütun: caption(12 ikon, alt 6)+3 yemek (13/18, +2); alt flame + `totalLine` (üst 4) | `mediumView`: `gap: s8`, `HStack(spacing: s16)`+`BuVDivider`, `columnView` (spacing s2 + caption alt s4 = 6), `menuMediumDishes`=3, tek öğünde ilk 3/sonraki 3 |
| large | tarih başlık; bölüm başlığı (ikon+caption, toplam sağda small t2, alt 6); 4 (tek öğünde 8) yemek (ad body, kcal small t3 sağda); bölümler arası 1 px, dikey 10; chip 36/12 flame 14 "Günlük toplam"; `+N yemek` | `largeView`/`mealSection`: `menuLargeDishes`(4)/`...SingleMeal`(8), `BuDivider` + `padding(.vertical, s10)`, chip `kcalChipHeight` + `radiusChip` + `iconMetaLarge` |
| boş | small: `YEMEK` + display 2 satır + small t3; medium/large: `YEMEK MENÜSÜ` + display + body t2 (sola hizalı, dikey ortalı) | `emptyView` + `BuEmptyLeading` |
| not | iki sütunlu tek öğünde ikinci sütunun caption'ı yok | ikinci sütunda boş yer tutucu (12+4) ile satırlar hizalı (README belirsizdi) |

## Ders (`BUTimetableWidget`, `bukampus://timetable`)

| Boyut | Spec | Kod |
|---|---|---|
| small | `SIRADAKİ`+clock; ters rozet (köşe 8, 2x8) + 8 + "N dk sonra" small t3; ders adı title 17/22 2 satır (üst 8); alta pin 12 + derslik small t2; süren derste "Şu an" rozeti + bitiş | `smallView`; rozet `radiusBadgeSmall`, `timetableSmallTitleLines`; `isCurrent` -> `nowBadge` + `endsAt` |
| medium | başlık `headerNext` + clock; 2 satır, h 36, aralık 4, köşe 12, iç 8; sıradaki satır chip + ters rozet 52; geçmiş 0.5 | `mediumView`/`rowsView` (`rowTimetableMedium`, `s4`, `badgeTimetableWidth`, `opacityPastLesson`), yükseklik `BuFit.rows` ile düşer |
| large | tarih+calendar; "Bugün N ders" title + sağ small t2 (alt 12); 4 satır h 40 aralık 6; alt not `Son ders ... biter` / `+N ders daha` | `largeView` (`rowTimetableLarge`, `s6`, `timetableLargeRows`); pencere = aktif dersten başlar |
| boş | `DERS` / `DERS PROGRAMI`; display; `Sıradaki: Pzt 08:30` | `emptyView` + `nextLabel` (snapshot.next geçerliyse, değilse sonraki günlerden; kısa gün adı yedeği `prefix(3)`) |
| zaman | giriş: her ders başlangıç/bitiş, 00:00, 00:05, `.after(30 dk)` | `BuTimeline.timetable` + `BuProvider` |

## Etkinlik (`BUEventsWidget`, `bukampus://events`, satır `events/{id}`)

| Boyut | Spec | Kod |
|---|---|---|
| small | calendar 14 + "Yaklaşan" micro t2 (logo yok); gün 34/36 + ay 12/16 +0.08em (taban hizası, 6); esnek; başlık 14/18 2 satır; clock 12 + saat micro t2 (üst 6); tüm widget `events[0].deepLink` | `smallView`, `eventDayHero`, **`buEventMonthSmall` = TextRole(12,16,+0.08)** (belirteç tablosunda karşılığı yok: tek ham sayı), `bodyL`, `BuEventsView.link` |
| medium | logo 14 + başlık micro t2 (alt 10); ≤3 satır h 30; rozet 30x30 köşe 8 + 1 px kenar, gün 13/13 + ay 9/10; başlık 13, kulüp 11 t2; sağda clock + saat 12 | `mediumView` (`rowEvents`=30, `badgeDaySmall/MonthSmall`, `radiusBadgeSmall`), <3 satırda aralık 6 |
| large | başlık + sağda "{n} etkinlik" t3; 1 px ayırıcı (üst 12/alt 4); 3 eşit satır + ayırıcı; rozet 44x48 köşe 10 (18/20 + 10/12); başlık 15/20, kulüp 12/16, meta clock 14 + saat, pin 14 + mekan (mekan yoksa gizli) | `largeView`/`largeRow` (`badgeEventLarge*`, `radiusBadgeLarge`, `iconMetaLarge`) |
| boş | ikon + başlık yatay ortalı; small/medium/large ikon 20/22/28 | `BuEmptyCentered` |
| eleme | `startsAt < şimdi-1sa` satır düşer | `BuEventsSnap.upcoming(at:)` + `BuTimeline.events` (başlangıç+1sa girişi) |

## Duyuru (`BUAnnouncementsWidget`, `bukampus://news`, satır `news/{id}`)

| Boyut | Spec | Kod |
|---|---|---|
| small | megaphone 14 + "Duyurular" (logo yok); başlık 15/20 4 satır; alta meta 11/14 t2 | `smallView` (`announcementsSmallTitleLines`=4, `question`, `micro`) |
| medium | logo+başlık; ≤3 satır h 30; nokta 4x4 + 8; başlık 13 (ilk t1, diğer t2), meta 11 t3; nokta: ilk `text1`, diğer `dotPassive` | `mediumRow` (`s4` nokta, `rowEvents`) |
| large | başlık + "Son N"; ayırıcı; 4 eşit satır; başlık 14/18 2 satır (ilk t1), meta t3; nokta yok | `largeView`/`largeRow` (`bodyL`, `announcementsLargeTitleLines`) |
| acil | "Acil" metni `danger`; medium noktası `danger` | `BuMetaLine` (metaText başındaki `urgentLabel` ayrı renk) |
| boş | megaphone 20/22/28 + başlık (+alt metin) | `BuEmptyCentered` |

## Anket (`BUPollWidget`, `bukampus://poll/{id}`)

| Boyut | Spec | Kod |
|---|---|---|
| small | `ANKET`+vote+logo; soru 15/20 3 satır; alta "Oy ver" hapı (h 28, x 14, tam yuvarlak) / "Oy verildi" body t2 | `smallView`, `pill` (`pillHeight`, `pillPaddingX`, `Capsule`) |
| medium | `GÜNÜN ANKETİ` (alt 8); sol %40: soru 3 satır + alta `microLine`; sağ: 3 seçenek (etiket 12/16 + yüzde, 4 px çubuk r 2, 4 boşluk); lider tam, diğerleri 0.45; oy yoksa yalnız etiket + hap | `mediumView`, `BuPollBar` (`barHeight`, `radiusBar`, `opacityNonLeaderBar`); çubuk yalnız `userVoted && resultsVisible && tüm percent dolu` |
| large | başlık (alt 12), soru 17/22 2 satır (alt 16), ≤4 seçenek aralık 14 (13/18 + yüzde, 6, çubuk), esnek, alt: lock 12 + `secretLine`, sağda "Ayrıntı" + chevron | `largeView` |
| boş | `ANKET`/`GÜNÜN ANKETİ`; display; alt metin | `emptyView` |
| etkileşim | yok (iOS 17 AppIntents YAPILMADI) | yalnız `widgetURL` |

## Hızlı Erişim (`BUQuickAccessWidget`, `bukampus://home`, karo başına kendi bağlantısı)

| Boyut | Spec | Kod |
|---|---|---|
| small | başlık/logo yok, iç boşluk 12; 2x2 (smallIds), aralık 8; karo chip r 12, ikon 22, 6, etiket 11/14 | `BuFrame(padding: paddingQuickSmall)`, `grid(columns: 2, iconSize: iconRowLarge, radius: radiusChip)` |
| medium | `HIZLI ERİŞİM`+search+logo (alt 10); 4x2, aralık 8, r 14, ikon 18 + 4 + etiket | `grid(columns: 4, iconTileMedium, radiusTile)` |
| large | caption+logo (alt 4), başlık 17/22, alt metin 12/16 t3 (alt 14), 4x2, ikon 24 | `grid(... iconTileLarge)` |
| boş | yok (items boşsa oturumsuz düzen) | `BuSignedOutView` |

## Sosyal (`BUSocialWidget`, YALNIZ SAYILAR)

| Boyut | Spec | Kod |
|---|---|---|
| small | `MESAJ`+message-square+logo; sayı 34/38; "okunmamış mesaj" 12/16 t2; alt: bell 12 + sayı, 12 aralık, **kırmızı** heart 12 + sayı | `smallView` (`number`, `s12`, `t.heart`) |
| medium | `SOSYAL ÖZET`+message-circle; 3 sütun, 1 px ayraç, 12 aralık; ikon 18 (kalp kırmızı), 6, sayı 34/38, etiket 12/16 t2; sütun başına link | `mediumView` (`iconSocialMedium`) |
| large | başlık (alt 4), "Bugün yeni olanlar" 17/22, "Yalnızca sayılar gösterilir" 12/16 t3 (alt 14); 3 satır h 64 aralık 8 chip r 14, x 14, ikon 22; etiket 13/18 + alt 11/14 t3; sağda 28/32 sayı; satır başına link | `largeView` (`rowSocialLarge`, `radiusTile`, `numberRow`) |
| boş | circle-check + display "Her şey güncel" (+ alt metin), kırmızı yok | `emptyView` |

## Veri / zaman çizelgesi

| Kural | Kod |
|---|---|
| Depo: App Group `group.tr.com.bukampus.app`, anahtar `bu_widget_<slug>` | `BuStore` (`BuWidgetTokens.appGroup/key*`) |
| Anahtar yok/boş/bozuk JSON/`schema>1`/`signedIn=false` -> oturumsuz, çökme yok | `try? JSONDecoder` + `BuResolver.state` |
| `state=empty` ya da `now > expiresAt` -> boş durum, "güncel değil" yazısı yok | `BuResolver.state` |
| Menü: yerel güne eşit `date` (üst düzey/upcoming) | `BuMenuSnap.day(for:)` |
| Girişler: menü 12:00/18:00/gece yarısı; ders başlangıç/bitiş; etkinlik başlangıç+1sa; hepsi + bayatlık anı; `.after(30 dk)` | `BuTimeline`, `BuProvider.entries` (en çok 24 giriş, 8 gün ufku) |
| Galeri: tasarım örneği (`examples/tr`), sabit saat 6 Kas 2026 10:00 | `BuSampleData` (üretilmiş; static kontrol `examples/tr` ile eşitliği denetler) |
| Kind adları `BU<Slug>Widget` | `BUWidgetsBundle` |
| Yerelleştirme: galeri adı/açıklama + oturumsuz yedek metin tr/en/ar | `*.lproj/Localizable.strings`; `Info.plist CFBundleLocalizations` |

## DOĞRULANDI (araçla, bu makinede)

- `check-ios-static.py`: pbxproj eski-biçim plist olarak ayrışıyor (benzersiz anahtar, dengeli parantez), tüm kimlik referansları tanımlı, hedef/yapılandırma/bundle id/iOS 15.0/ortak sürüm, Sources = diskteki `.swift`, token dosyası yalnız uzantıda, gömme fazı + hedef bağımlılığı, App Group (3 entitlements), Info.plist, Localizable anahtar eşitliği, kind adları, yalnız `.regular`, SF Symbols/AppIntents/ağ yok, CI dosyaları.
- Swift modelleri (`BuWidgetModels.swift`'ten ayrıştırılan alan/tip listesi) `examples/{tr,en,ar}/*` + `empty` + `signed-out` + `meta*` toplam 32 JSON'u tip uyuşmazlığı olmadan ayrıştırıyor (Codable için eşdeğer kontrol).
- İkon yolları (Bezier dönüşümü) Python ile çizilip gözle doğrulandı (22 ikon).

## DOĞRULANMADI

- Swift derlemesi (swiftc/Xcode yok): tip, opsiyonel, availability ve result-builder hataları ilk macOS koşusunda çıkabilir.
- Her piksel ölçüsü (yerleşim, taşma, satır kırpma, 3 boyut x açık/koyu x tr/ar), `ContainerRelativeShape` kenar çizgisi, iOS 17 `widgetContentMargins` telafisi, RTL aynalama, Galeri önizlemesi, zaman çizelgesi gerçek davranışı, App Group okuma (imzalı cihaz), `Link` satır dokunmaları.
- Derleme sonrası bakılacak: medium etkinlik/duyuru satırı 30 pt içinde 2 satır metin (13/18 + 11/14 = 32 pt, 1 pt taşar; satır aralığı bunu karşılar).
