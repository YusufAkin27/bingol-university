# Mobil: PREMIUM MONOCHROME tasarım sistemi (1. dalga, temel)

Tarih: 2026-11-05. Dal: `feat/mono-ds`. Belirteç tablosu ve kurallar: [docs/MOBILE_DESIGN_SYSTEM.md](../MOBILE_DESIGN_SYSTEM.md). Kullanıcı brief'i: Premium Black (koyu, varsayılan) + Premium White (açık), siyah-beyaz arayüz, marka kırmızısı arayüzden çekildi.

## 1. Bu dalgada yapılanlar

- `BuTokens` (açık + koyu) monochrome'a taşındı; alan adları korundu (600+ kullanım derlenir). Yeni alan: `heart` (kalp kırmızısı). `prText` artık `ink` döner (kırmızı değil), `pr` koyuda #FAFAFA / açıkta #09090B, `soft`/`onSoft` nötr (sf2/ink), `prPressed == pr`, `selectedBorder` nötr, kategori karoları (`tints`) nötr, `aqua*` nötr, `h1 == h2` (gradyan yok).
- `BuType.emphasisWeight` (= `FontWeight.w400`) tek vurgu belirteci; **69 dosyada** `FontWeight.w500..w900/bold` buna bağlandı (kodda artık `w500+` yok). Hero ölçeği eklendi (`BuScale.hero` 28, `BuType.hero`); M3 display/headline boyutları brief aralığına çekildi.
- M3 bileşen temaları (düğmeler, çip, segment, giriş, kart, dialog, sheet, snackbar, menü, switch/checkbox/radio/slider, tab, nav, FAB, badge) nötr; radius: kart 16, buton/giriş 12, compact buton 10, alt sayfa/dialog 20; gölge yok (açıkta çok hafif).
- Ortak widget'lar: `BuButton` (birincil = `pr`, ikincil = ince kenarlık, hap değil), `BuChip` (seçili = ters renk), `BuSegmented`, `BuCard` (16), `BuBadge`, `BuSearchField` (12, odakta `ink`), `BuHeroCard` (düz sf2, süs yok), `BuToast` (tema yüzeyi).
- `FloatingNav`: `sf` + `bd` kenarlık, gölge yok, aktif `ink`, pasif `mut`, Paylaş = `pr` daire.
- `lib/widgets/app_components.dart`: `AppButton/AppCard/AppAvatar/AppBottomSheet/AppDialog/AppTopBar/AppBottomNavigation/AppEmptyState/AppSkeleton/AppPostCard/AppListTile` typedef'leri + yeni `AppTextField`, `AppReactionBar`/`AppReaction`, `AppDivider`, `AppRadius`.
- Tema: `ThemeController.defaultMode = dark` (kayıtlı tercih, Sistem dahil, korunur); durum/gezinme çubuğu ikonları temaya uyar (`main.dart`); `MaterialApp` yeniden kurulmaz, durum korunur.
- Beğeni kalpleri `t.heart`'a taşındı (post/forum/reels/kulüp: 8 dosya); splash tema zeminine taşındı; haber/yer tutucu gradyanları düz sf2.
- Ham renk istisna listesi küçüldü: `Color(0x..)` yalnız `core/theme.dart` ve `features/academic/academic_models.dart` (ders renk anahtarları; arayüz teması değil). `sohbety_widgets.dart` (kullanılmayan `sohbetyShadow` silindi) ve `media_preview_page.dart` listeden çıktı. Ders rengi `green` AA için koyulaştırıldı.
- Testler: `renk_paleti_test` (brief hex'leri birebir, nötrlük, anlamsal renkler, iki tema bağımsızlığı), `theme_test`, `p00_theme_test`, yeni `mono_theme_state_test` (varsayılan koyu, Sistem/Açık/Koyu geçişinde yazılmış metin + kaydırma + state korunumu, platform parlaklığı değişimi, birincil düğme 7:1 + yüzey belirteçleri).

## 2. ENVANTER: ekran gruplarının kalan işi (ölçüm: lib/ grep, 2026-11-05)

Anlam: **pr** = `t.pr` (artık beyaz/siyah: ikon/metin/dolgu olarak kullanılan yerler gözden geçirilmeli), **prText** = `prText` (artık `ink`), **soft** = `t.soft/onSoft` (artık nötr sf2/ink: "marka karosu" görünümü kaybolur, düzen/vurgu yeniden düşünülmeli), **tint** = `tint()/tints` (artık nötr), **prP** = `prPressed` (artık `pr`), **danger** = `t.danger` (anlamsal: doğrulanmalı), **heart** = kalp ikonu kullanımı.

| Grup | dosya | satır | pr | prText | soft | tint | prP | danger | gradyan | blur | pill |
|---|---|---|---|---|---|---|---|---|---|---|---|
| features/chat | 48 | 21.8k | 56 | 18 | 61 | 1 | 3 | 42 | 7 | 5 | 35 |
| features/events | 15 | 8.3k | 19 | 29 | 37 | 5 | 0 | 75 | - | 1 | 13 |
| features/forum | 52 | 10.9k | 15 | 18 | 16 | 0 | 1 | 13 | - | - | - |
| features/profile | 23 | 8.6k | 14 | 12 | 19 | 11 | 2 | 31 | 3 | - | 8 |
| features/academic | 21 | 7.1k | 20 | 14 | 25 | 2 | 0 | 22 | - | - | - |
| features/posts | 25 | 6.9k | 8 | 3 | 5 | 0 | 0 | 5 | 2 | - | 12 |
| features/clubs | 14 | 5.8k | 14 | 17 | 11 | 4 | 0 | 11 | - | - | 8 |
| features/auth | 25 | 5.9k | 13 | 1 | 8 | 3 | 6 | 18 | - | - | - |
| features/polls | 13 | 3.2k | 22 | 19 | 13 | 9 | 0 | 6 | - | - | - |
| features/home | 6 | 3.6k | 4 | 5 | 9 | 0 | 11 | 0 | - | - | - |
| features/media_crop | 8 | 3.2k | 5 | 3 | 9 | 0 | 2 | 10 | - | 2 | 7 |
| features/support | 7 | 2.5k | 9 | 6 | 20 | 9 | 0 | 13 | 1 | - | 6 |
| features/search | 5 | 2.3k | 3 | 12 | 4 | 0 | 0 | 0 | 1 | - | 7 |
| features/news | 4 | 1.8k | 2 | 7 | 5 | 4 | 0 | 1 | - | - | - |
| features/follow | 11 | 2.2k | 2 | 0 | 6 | 0 | 4 | 0 | - | - | - |
| features/notifications | 4 | 1.4k | 4 | 3 | 0 | 0 | 0 | 5 | - | - | - |
| features/reels, discover, menu, share, legal, system, shell, platform | 28 | 8.9k | 15 | 8 | 12 | 2 | 1 | 3 | 2 | - | - |
| core (push kartları, realtime, theme dışı) | 82 | 14k | 26 | 4 | 13 | 7 | 14 | 9 | - | - | - |
| widgets (ortak) | 25 | 6.4k | 48 | 8 | 31 | 5 | 0 | 10 | 1 | 2 | - |

Not: `core/theme*` ve `widgets/bu_widgets.dart` bu dalgada yapıldı (sayılar o dosyaların hâlâ geçerli `t.pr` kullanımlarını da içerir). Marka kırmızısı sabiti: `BuColors`/`kBrandRed` yalnız `core/theme.dart`, `widgets/bu_widgets.dart` (`kBrandRed`, logo için) ve `features/notifications/notification_exam_detail.dart` (2 kullanım: `BuColors.ink/red100`, gömülü kırmızı ton: 2. dalga temizler). Okundu tiki: `message_bubble.dart` `readSky/readDeep` zaten balon parlaklığına göre seçilir (koyuda beyaz balon -> `readDeep`, açıkta siyah balon -> `readSky`), doğrulama sohbet ajanında.

### En yoğun dosyalar (vurgu belirteci kullanımı >= 10)

`widgets/bu_illustrations.dart` (28: boş durum çizimleri marka tonlu: nötre çekilecek), `features/support/support_common.dart` (24), `features/chat/chat_detail_page.dart` (21), `chat/sohbety_widgets.dart` (21), `chat/message_bubble.dart` (20), `polls/anket_art.dart` (19), `home/home_parts.dart` (19), `clubs/club_ref_widgets.dart` (16), `events/etkinlik2_widgets.dart` (16), `academic/semester_sheet.dart` (15), `profile/user_profile_page.dart` (15), `events/etkinlik_parts.dart` (14), `events/events_page.dart` (14), `auth/widgets/auth_ref.dart` (14), `news/icerik_parts.dart` (14), `academic/akad_widgets.dart` (13), `widgets/academic_pickers.dart` (13), `media_crop/avatar_editor_page.dart` (12), `search/search_page.dart` (12), `support/support_suggestions_page.dart`, `events/event_form_page.dart`, `chat/media_picker_page.dart`, `forum/.../comment_section.dart`, `polls/poll_detail_page.dart` (10-11).

### Tema-bağımsız (bilerek) kullanımlar: `BuTokens.light/dark` doğrudan

Medya/tuval üstü: `chat/chatd_parts.dart`, `chat/message_bubble.dart` (navy 2 yer), `events/event_detail_page.dart:1094` (kapak üstü hap), `events/event_parts.dart:323`, `events/qr_painter.dart` (QR siyah/beyaz: doğru), `media_crop/*` (koyu tuval: doğru), `profile/user_profile_page.dart:780` (avatar üstü karartma), `system/error_views.dart`. 2. dalga ajanı kendi grubundakileri tema belirtecine (`t.*`) çevirir ya da "medya üstü" gerekçesini yorumla belirtir.

### Diğer temizlik kalemleri (2. dalga)

- Gradyan (`LinearGradient/RadialGradient`): chat 7, profile 3, posts 2, reels/search/support/shell/`widgets/bu_list.dart` 1'er. Medya karartma geçişleri kalabilir; dekoratif gradyan kalkar.
- `BackdropFilter/ImageFilter.blur` (cam): chat 5, media_crop 2, `widgets/profile_photo_viewer.dart` 2, events 1: yalnız medya üstü karartma gereken yerde kalır.
- `BoxShadow(`: events 4, chat 3, polls/home/news/platform/`widgets/sistem_widgets.dart` 1'er: koyuda kaldır, açıkta `BuElevation` ya da kenarlık.
- Pill (`StadiumBorder/BuRadius.pill/bPill`) düğmeler: chat 35, events 13, posts 12, clubs/profile 8, media_crop/search 7, support 6: düğme -> 10-12 radius; çip/etiket pill kalabilir.
- Profil menüsü `ProfilIconTile`, "Tümünü gör" gibi `prText` bağlantıları, kategori karolarının (`BuTintId`) anlamsal kullanımı (`core/push/push_card_parts.dart`, `news/news_tile.dart`, `share/share_card.dart`) artık nötr: gerekirse simge ile ayrım güçlendirilecek.
- `widgets/bu_widgets.dart` `BuMenuRow`/`BuFeatureIcon` simge karosu (`soft` zemin + `onSoft`) nötr oldu: görünüm kabul edilebilir, 2. dalga isterse sadeleştirir.

## 3. Önerilen 2. dalga bölünmesi (paralel ajanlar; çakışmayan dosya kümeleri)

1. **Sohbet**: `features/chat/**` (48 dosya, balonlar gelen koyu gri/giden açık ton, okundu tikleri, giriş alanı, duvar kağıdı, medya seçici, `sohbety_widgets.dart`, `chatd_parts.dart`).
2. **Ana sayfa + Keşfet + Gönderi + Reels + Arama + Takip**: `features/home`, `discover`, `posts`, `reels`, `search`, `follow`, `share`, `news` (feed, kategori filtreleri, gönderi kartı, `AppReactionBar`'a geçiş, kalpler).
3. **Profil + Ayarlar + Medya seçme/kırpma + Destek**: `features/profile`, `media_crop`, `support`, `legal`, `system`, `menu`, `platform`.
4. **Etkinlikler + Kulüpler + Anketler**: `features/events`, `clubs`, `polls` (QR, yoklama, `anket_art.dart`).
5. **Forum + Akademik + Kimlik doğrulama + Bildirimler**: `features/forum`, `academic`, `auth`, `notifications`, `core/push/*`.
6. **Ortak widget'lar + boş durum çizimleri**: `lib/widgets/*` (özellikle `bu_illustrations.dart`, `bu_state.dart`, `bu_skeleton.dart`, `bu_overlays.dart`, `bu_list.dart`, `bu_page_scaffold.dart`), `core/**` kalan.

Her ajan: kendi grubunda `t.pr/prText/soft/tint` kullanımını tek tek gözden geçirir (anlamsal olarak kırmızı kalması gereken: hata/silme/engelle/kalp), pill düğmeleri 12'ye çeker, dekoratif gradyan/blur/gölgeyi kaldırır, açık + koyu + büyük yazı + dar ekran widget testlerini çalıştırır, `renk_paleti_test` (ham renk yasağı) yeşil kalır.

## 4. Test sonucu ve bilinen kırıklar

Tam tur (`flutter test --concurrency=4 --timeout=90s`, 2026-11-05): +5944 geçti, ~1738 atlandı (skip), -34 kırık (turun sonunda). Bu dalganın neden olduğu 8 kırık düzeltildi (kalp renk beklentileri `t.heart`, FloatingNav artık gölgesiz, `ok/okSoft` AA için `ok` #166534); düzeltilen testler tek tek yeniden koşuldu ve geçti. Kalan kırıklar önceden bilinenlerdir: `bu_icons_test`, `db_redesign` (bildirim), `p49_motion` (3), `p61`/`p62` (yemek/bildirim ölçüleri), `p63`, `pages_a` (home Tümü), `p3_profile` (Gizlilik), `w1j`, `student_number`, `p17`/`p69` kontrast, `p65`/`da_auth` (Sözleşme listesi), `p3feed` "tam ekran" (tek dokunuşta tam ekran kaldırıldığı için), ayrıca `p16_test` "Yoklama açık: kontrast" (Gelmedi çipi, yazı 12.5 sp, `textContrastGuideline` 3.4:1 ölçüyor; belirteç çifti `mut/sf` 7.6:1; ölçüm kaynağı ekran görüntüsü örnekleme gibi görünüyor, bu dalganın bozduğu doğrulanmadı). `test/share_test.dart:288` analyze hatası dal başlangıcından gelir.

## 5. 2. dalga, Grup 2: Ana sayfa / Keşfet / Gönderi / Haber / Arama / Takip (`feat/mono-home`)

- Ana sayfa: `HomeSurface` ve haber/etkinlik kartları 16 radius + `bd` kenarlık, gölge yok; arama kutusu hap değil radius 12; başlık "BÜ Kampüs" minimal yazı wordmark (logo görseli ve kırmızı yok); `prPressed/prText` -> `ink`/`pr`; yerleşim düzenleme sayfasında sürüklenen satır gölgesiz (kenarlık güçlenir).
- Gönderi: `PostCard` yüzeyi `sf` + `bd`, radius 16 (gölge yok), fotoğraf radius 16; oluşturma/video kırpma düğmeleri radius 12 (hap değil), medya üstü düğmeler 10; kalp kırmızısı yalnız `t.heart`.
- Haber: `IcerikTabs` seçili parça ters renk (`pr` + `onPr`), yükseltilmiş varyantta `sf` + kenarlık; `IcerikCard`/`NewsFeaturedCard` gölgesiz, radius 16; yer tutucu karolar nötr; kayıtlı durum dolu simgeyle ayrışır (renkle değil).
- Arama: giriş alanları radius 12, odakta `ink` kenarlık; seçili çip ters renk; eşleşme vurgusu renksiz alt çizgi (`searchHighlight`); "Katıl" küçük düğmesi `pr` zemin radius 10.
- Takip: düğmeler (satır/hap/çip/medya) radius 10-12; birincil = `pr`/`onPr`.
- Korunan medya karartmaları (okunurluk için `scrim` gradyanı) ve kaydırma kenarı solması (`bg` -> şeffaf) bilerek kalır. Kategori süzgeci (Senin için/Takip/...) Keşfet'e EKLENMEDİ: önceki kararla "filtre/kapsül yok", sunucu uçları da yok.
- Test: `test/redesign/mono_home_group_test.dart` (iki temada yüzey/arama/segment/vurgu).
