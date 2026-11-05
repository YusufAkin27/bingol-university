# Mobil: PREMIUM MONOCHROME, 2. dalga, grup 4 (etkinlikler / kulüpler / anketler / yemek)

Dal: `feat/mono-events`. Kapsam: `features/events`, `clubs`, `polls`, `menu` (kampüs haritası ekranı yok).

- **Seçili durum = ters renk** (`pr` zemin + `onPr` yazı): etkinlik segmenti (`Et2Segment`), alt sekme çipleri, takvimde seçili gün (bugün = `bdStrong` halka), yemek gün şeridi, anket tür segmenti ve bitiş çipleri. Seçenek satırlarında (anket oyu, katılım türü) seçili = `sf2`/`soft` zemin + `ink` 1.5 dp çerçeve; seçili değilken `bd` çerçeve.
- **Gradyan/gölge/süs kaldırıldı:** `CalmCover` düz `sf2` + silik simge (daireler ve gradyan yok), tarih rozeti/kapak düğmesi/menü kartları gölgesiz (ince `bd` kenarlık), anket değiştirici thumb gölgesi, "onaya gönderildi" halesi (`BoxShadow` yerine `Border`). Kulüp kapağındaki üst karartma geçişi medya okunurluğu için kalır.
- **Anket illüstrasyonları** (`anket_art.dart`): yalnız `ink`/`bdStrong`/`sf2`/`sf3`; marka tonlu noktalar, kategori tonları ve gölge yok. Sonuç çubukları `ink` dolgu (kazanan/benim oyum), diğerleri nötr gri.
- **Düğme/giriş yarıçapı 10–12:** `EtkinlikBtn`, `Et2GreyButton` (artık `sf` + ince kenarlık), `ClubBtn`, `KulupPill` (statik görünüm), kulüp yorum kutusu, gün şeridi. Hap yalnız çip/etiket/ilerleme çubuğu/kapak rozetinde kaldı. Kart yarıçapı 20/22 -> 16, dialog 28 -> 20.
- **Anlamsal kırmızı:** kulüp `danger` satırları/ikon kutuları artık `danger`/`dangerSoft` (önceden marka kırmızısı olan `pr`); `ClubNoteTone.soft` nötr. Kulüp rol rozeti: yönetici = ters dolgu, moderatör = nötr + kalkan (renk ile ayrım yok).
- **Medya üstü sabit `BuTokens.light` kaldırıldı:** etkinlik kapağı hapı ve tarih rozeti tema yüzeyi (`sf` ~%94) + `ink` kullanır. QR kağıdı/mürekkebi (`qrPaper`/`qrInk`) siyah-beyaz kalır (tarayıcı kontrastı); süresi dolan QR bulanıklığı işlevseldir.
- Etkinlik detay başlığı 26 -> 28 sp (hero ölçeği), ağırlık w400.
- Yemek: gün seçici ters renk, öğle kartı 16 köşe gölgesiz, toplam enerji satırı nötr `sf2`, kart/simge kutuları nötr.
