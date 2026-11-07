# BİREBİR: Etkinlikler (Stitch v3, 9 ekran)

Kaynak: `C:\bu_design\stitch\v3_club\etkinlikler\NN_*_light.png` (390 px geniş, 1 px = 1 dp) + `SARTNAME.md` "ETKİNLİKLER".
Uygulama: `mobile/lib/features/events/*` (EventsPage, EventDetailPage, EventFormPage, Etkinlik2QrPage, Etkinlik2RequestsPage,
Etkinlik2AttendancePage); ortak parçalar `clubs/clubs_widgets.dart` (`ClubTextTabs`, `ClubJoinButton`, `ClubOutlineButton`,
`ClubPageHeader`, `DashedRRectPainter`). Ekran görüntüsü: `mobile/test/redesign/p51_etkinlik_shots_test.dart` (390 dp, dpr 2,
durum çubuğu 0: Stitch çerçevesi durum çubuğunsuz). Yan yana PNG: `C:\bu_qa\shots\tasarim\dd\birebir_etkinlik\yan_yana_01..09.png`
(sol referans 2x büyütülmüş, sağ uygulama). Testlerde `Inter` yerine Roboto yüklüdür; satır genişlikleri %3-5 sapabilir.
Stitch'in lavanta zemini/artefaktları (başlık "Etkinlik Durumları", "503", "Önbellek", "Kayıtlı" etiketi...) uygulanmaz.

## Ölçü tablosu (dp)

| Ekran / öğe | Referans | Uygulama | Fark | Not |
|---|---|---|---|---|
| 01 Başlık "Etkinlikler" ortası (y) | 24 | 24 | 0 | 28 sp/700; sağda marka renkli "Yoklama" metni + "+" (48 dp kutu) |
| 01 Metin sekmeleri alt çizgi (y) | 93 | 93 | 0 | seçili `pr` + 2 dp çizgi, 24 dp aralık |
| 01 Takvim başlığı "Ekim 2026" (y) | 132 | 132 | 0 | 17/600; `<` `>` yalın simge (36 dp kutular) |
| 01 Gün harfleri (y) | 163 | 164 | 1 | tek harf (P S Ç ...), muted |
| 01 Gün satırı aralığı | 41 | 41 | 0 | seçili gün soft daire + `pr` nokta; olay günü muted nokta |
| 01 Takvim ızgarası | 2 hafta | tam ay | - | veri doğruluğu: ay ızgarası tam gösterilir (referans iki satırı kısaltılmış çizmiş) |
| 01 Gün başlığı | 17/600 + sağ muted "3 Etkinlik" | aynı | 0 | |
| 01 Satır: gün/ay | 22 sp/600 muted + 11 sp, ortası x=36 | aynı | 0 | karo yok |
| 01 Satır: kulüp / başlık / meta | 13 sp `pr`, 17/600, 14 muted | aynı | 0 | meta başlıktan 8 dp altta |
| 01 "Katıl" düğmesi | 60x36 çerçeveli, kulüp satırı +10 dp | aynı, +10 dp | 0 | `ClubJoinButton` (dokunma alanı 48 dp) |
| 01 "Katılıyorsun ✓" | muted 13 sp, kulüp satırı +9 dp | +3 dp | ~6 | durum metni 6 dp yukarıda (düğme çevirmesi yalnız "Katıl"da) |
| 02 Boş durum | 20/700 başlık, muted açıklama, `pr` metin bağlantısı | aynı | 0 | |
| 02 Hata | solda 17/600 "Yüklenemedi, tekrar dene" + sağda `pr` "Yeniden dene" | aynı | 0 | |
| 02 Çevrimdışı | amber not (ikonsuz) | aynı | 0 | "Çevrimdışısın. Kayıtlı etkinlikler gösteriliyor." |
| 02 İskelet | satır iskeleti | aynı | 0 | tarih + 3 çubuk + düğme |
| 03 Üst çubuk / kapak | 56 / 180 düz | 56 / 180 düz | 0 | silik kulüp baş harfi filigranı (88 sp/800, %8) |
| 03 Kulüp / başlık | `pr` 14 sp, 26/700 | aynı | 0 | |
| 03 Etiket-değer satırları | 52 dp, hairline, ilk satır başlık ayracından 24 dp | aynı | 0 | Tarih, Saat, Yer, Katılımcı (+ Katılım, yalnız istek ile) |
| 03 Açıklama | 16 sp/26 dp satır | 16 sp/1.6 | 0 | |
| 03 Alt çubuk | outlined "İlgileniyorum" + dolu "Katıl", 48 dp, 8 dp aralık | aynı (flex 4:7) | 0 | |
| 04 "Yoklama açık" | yeşil `okSoft` not, ikonsuz | aynı (kapağın altında) | 0 | |
| 04 "Etkinlik sohbeti >" | hairline'lı satır | aynı | 0 | |
| 04 Alt çubuk | "QR ile yoklama ver" + "Kodu elle gir" + "Katılıyorsun ✓" + "Katılımdan ayrıl" | aynı | 0 | |
| 05 Üst çubuk | geri + "Yeni etkinlik" | aynı | 0 | 55 dp |
| 05 Kulüp alanı / amber not | beyaz alan 56 dp + not | aynı | 0 | baş harf dairesi, chevron |
| 05 Alanlar | 52 dp, 16 köşe, hata 1.5 dp `danger` | aynı | 0 | etiket 13 sp/600 muted |
| 05 Çipler | 34 dp, seçili soft + marka çerçeve | aynı (`BuChip`) | 0 | referansta tek satır kaydırma; uygulamada sarar |
| 05 Katılım türü | çerçeveli segment, seçili soft | aynı | 0 | `Et2Segment` yeniden biçimlendi |
| 06 Kulüp gerekli | geri oku, ortada başlık + muted + tek düğme | aynı | 0 | düğme 280 dp; altında "Yetkileri yenile" metin bağlantısı (davranış korunur) |
| 07 Yoklama QR | 240 dp QR, "482 913" büyük, "Kod N sn sonra yenilenir", ilerleme 4 dp, "Yoklama listesi" | aynı | 0 | kod 3-3 bosluklu; "Yoklamayı kapat" uygulanmadı (API yok) |
| 08 Başvurular | kontenjan satırı + 6 dp çubuk, sekmeler Bekleyen/Onaylanan/Reddedilen, satır: daire + ad + muted bölüm·sınıf + Reddet/Onayla | aynı | 0 | sayılar sekme etiketinde ("Bekleyen 3") |
| 08 Amber not | "Kontenjan dolduğunda yeni istek onaylanamaz." | aynı | 0 | doluyken "Kontenjanı artır" bağlantısı |
| 09 Yoklama listesi | "64 geldi · 64 gelmedi" + "Toplam N kişi", çipler, kartsız satır + anahtar | aynı | 0 | anahtarda onay işareti yok |

## Davranış korunan sapmalar / uygulanmayanlar
- Tam ay ızgarası (referans iki hafta), "Yeniden dene" vb. metinler mevcut ARB'den (p51Ev* eklendi).
- "CSV indir" (09) ve "Yoklamayı kapat" (07): mobilde karşılık gelen uç yok; yeni uç eklenmedi.
- Etkinlik satırında "İlgileniyorum" düğmesi yok (yalnız detayda): referansla uyumlu; liste kaybı: ilgilenme durumu satırda gösterilmez.
- Oluşturduklarım/Etkinliklerim satırları aynı düz satır biçimini kullanır; durum metni sağda, işlemler üç nokta menüsünde.
- Etkinlik kartındaki Hero (kapak) yok: listede kapak görseli yok.

## Doğrulama
- `test/redesign/p51_etkinlik_test.dart` (5 davranış + 7 taşma matrisi: 3 dil x açık/koyu x 1.0/1.3 x 320/390),
  güncellenen `events_page_test`, `etkinlik2_test`, `events_cover_test`, `k9_detail_test`, `p16_test`, `dd_test`.
- Emülatör gezisi ve gerçek cihaz akıcılığı yapılmadı (doğrulanamadı); koyu/AR/x1.3 PNG'ler üretilmedi, matris testi taşma/istisna denetler.
