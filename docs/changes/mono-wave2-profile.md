# Mobil: PREMIUM MONOCHROME 2. dalga, grup 3 (profil / ayarlar / destek / sistem)

Tarih: 2026-11-05. Dal: `feat/mono-profile` (kaynak `feat/mono-ds`). Kapsam: `features/profile`, `support`, `media_crop`, `menu`, `system`, `legal`, `platform` (QR tarayıcı).

## Değişenler

- **Profil kimliği kartsız:** `InlineProfileHero` ve başkasının profili artık çerçeveli büyük kart içinde değil; avatar, hero boyutlu (28 sp, kalın değil) ad, bölüm/sınıf seçicileri (12 dp köşeli, hap değil) ve biyografi doğrudan sayfa zemininde. Takipçi/takip/gönderi sayacı `follow/follow_summary.dart` (başka grupta) tarafından çiziliyor.
- **Tema seçici:** Ayarlar > Görünüm'de alt sayfa yerine tek dokunuşluk `ProfilThemePicker` (Sistem / Açık / Koyu, her seçenekte küçük önizleme; Açık = Premium White, Koyu = Premium Black; seçili = `ink` çerçeve + onay işareti). `ThemeController` değişmedi; anahtarlar `settings-theme`, `theme-option-system|light|dark`.
- **Liste bileşenleri nötr:** `ProfilIconTile` karosuz, tek `mut` simge (hata/silme satırı `danger`); `ProfilCard`/`ProfilFlatGroup` gölgesiz 16 dp çerçeveli kart, ayırıcı `bdSubtle`; bölüm etiketi 13 sp; `ProfilRow` 16 sp. `P2Segment3` seçili parça ters renk (`pr`/`onPr`); `ProfilyTypeChip` seçili = `sf2` + `ink` çerçeve; `ProfilyEmptyCard` tek nötr daire.
- **Destek:** durumlar tek vurgu rengi olmadan ayrışır (Yanıtlandı = anlamsal yeşil, Açık = `sf3`+`ink`, Kapalı = soluk); kategori/talep çipleri seçili = ters renk; ekip yanıtı `sf2` + ince `ink` kenar; oy kontrolü seçili = `ink` çerçeve; alt eylem çubuğundaki gradyan düz zemin + ince ayırıcıya döndü.
- **Yasal metin listesi:** kart + simge karosu yok; düz editoryal satırlar + ince ayırıcı.
- **Yemek menüsü gün seçici:** seçili gün `pr` zemin + `onPr` yazı.
- **Gölge/gradyan/hap:** `BuElevation`/`BoxShadow`/`BuCardStyle.elevated` bu gruplardan kalktı (kenarlık + ton); QR tarama çizgisinin parıltısı kalktı; avatar görüntüleyicinin radyal gradyanı kalktı; engeli kaldır / kırpma "Bitti-Kaydet" / yeniden dene düğmeleri 12 dp köşeli. Kalanlar bilerek: medya üstü karartma gradyanları (kapak, reels, QR üst şerit), avatar düzenleyicinin bulanık arka plan/vinyet özelliği (işlev), çip/etiket hapları.
- Testler: `test/redesign/mono_profile_test.dart` (tema seçici, kartsız kimlik, nötr satırlar, kaynak güvenceleri, taşma).
