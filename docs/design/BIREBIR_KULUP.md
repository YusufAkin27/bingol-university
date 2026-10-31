# BİREBİR: Kulüpler (Stitch v3, 6 ekran)

Kaynak: `C:\bu_design\stitch\v3_club\kulupler\*_light_crop.png` (488x1280 px, 1.25 px = 1 dp) + `SARTNAME.md` "Kulüpler".
Uygulama: `mobile/lib/features/clubs/*` (ClubsTab, ClubDetailPage, ClubFormPage). Ekran görüntüsü üretimi:
`mobile/test/redesign/p51_kulup_shots_test.dart` (390x844, dpr 2, durum çubuğu ayrıntısı yok: Stitch çerçevesi durum
çubuğunsuz olduğundan ölçüler "içerik üstünden" alınır; gerçek cihazda yukarı safe-area eklenir). Yan yana PNG'ler:
`C:\bu_qa\shots\tasarim\dd\birebir_kulup\yan_yana_01..06.png` (sol referans, sağ uygulama; ikisi de 2 px/dp'ye getirildi).

Ölçüm notu: testlerde `Inter` yerine Roboto yüklüdür (fake font); satır genişlikleri %3-5 sapabilir, boy/konum
ölçüleri güvenilirdir. Gerçek cihazda Inter ile ölçülmedi (doğrulanamadı).

## Ölçü tablosu (dp)

| Ekran / öğe | Referans | Uygulama | Fark | Not |
|---|---|---|---|---|
| 01 Başlık "Kulüpler" ortası (y) | 40 | 40 | 0 | 28 sp/700 (`BuScale.display` 22 olduğundan yerel `fontSize: 28`) |
| 01 Sekme yazısı ortası / alt çizgi (y) | 90 / 111 | 90 / 111 | 0 | 15 sp/600, seçili `pr` + 2 dp çizgi, tam genişlik `bd` ayraç |
| 01 Çip üstü / yüksekliği | 128 / 34 | 128 / 34 | 0 | `BuChip` ortak (seçili çip ince marka çerçevesi taşır, referansta çerçevesiz) |
| 01 Satır yüksekliği / logo | 77 / 48 | 77 / 48 | 0 | kartsız, alt ayraç tam genişlik |
| 01 Ad / alt satır | 16 sp/600, 13 sp | 16 sp/600, 13 sp | 0 | |
| 01 "Katıl" düğmesi | 60x36, r18, 1 dp çerçeve | ~62x36, r18, `bdStrong` 1 dp | <=2 | dokunma alanı 48 dp |
| 01 Üyesin / İstek gönderildi | 13 sp muted, onay `ok` | aynı | 0 | |
| 01 Arama simgesi | yok | 44x48 muted | + | DAVRANIŞ korunur (arama), referansta yok |
| 02 Bölüm etiketi merkezi (y) | 144 | 142 | 2 | 13 sp/600, harf aralıklı, büyük harf |
| 02 Rol metni | "Yönetici" kırmızı | "Yönetici" muted/600 | renk | şartname: tek vurgu kuralı |
| 02 Bekleyen satır alt metni | taşıyor | "Bilim · Başvuru tarihi: 14 May" kısaltılır | - | şartname: ellipsis |
| 03 İskelet | 5 satır, 36 dp daire (çizimde) | 5 satır, 48 dp daire, %70/%45 çubuk | daire | şartname 48 dp (satırla aynı, yer değişimi yok) |
| 03 Boş / hata | muted metin + `pr` metin düğmesi | aynı (16 sp) | 0 | illüstrasyon yok |
| 04 Kapak | 180 | 180 (+ safe-area üstte) | 0 | düz `sf2` + silik "FK" filigranı (88 sp/800, %8) |
| 04 Geri oku / üç nokta merkezi | (36, 27.5) / (354, 27.5) | aynı | 0 | plaka yok |
| 04 Ad (y merkezi) | 217 | 217 | 0 | 28 sp/700 |
| 04 Alt satır | 14 sp muted | 14 sp muted | 0 | |
| 04 Açıklama | 14 sp/23 dp satır | 14 sp/1.65 | 0 | 3 satır, "Devamını göster" ayrı satırda (referansta satır içi) |
| 04 "Katıl" | tam genişlik 48, r16, y=387 | 48, r16, y=392 | 5 | link satırı ayrı (dokunma alanı 40 dp) |
| 04 Sekmeler | metin, 2 dp çizgi, 21 dp aralık | aynı | 0 | Hakkında/Etkinlikler/Üyeler/Gönderiler; Anketler Hakkında altında |
| 04 Hakkında satırı | 48 dp, 15 sp | 48 dp, 15 sp | 0 | satırlar veriden: Kuruluş, Kategori, Katılım (API'de toplantı günü/yönetici adı yok) |
| 05 Düğme satırı | 2x 48, aralık 12 | 2x 48, aralık 12 | 0 | çerçeveli düğme beyaz + `bdStrong` |
| 05 Amber not | 45 dp, ikonsuz + chevron | min 48 dp | 3 | dokunma alanı >= 48 |
| 05 Üye satırı | 73 dp, avatar 44 | 73 dp, avatar 44 | 0 | üç nokta merkezi 18 dp içeriden |
| 06 Üst çubuk | 55 dp, başlık 18/700 | 55 dp | 0 | |
| 06 Kapak seçici | 140, kesik 1 dp | 140, kesik 1 dp `bdStrong` | 0 | |
| 06 Alan / etiket | 52 dp, r16 / 13 sp | 52 dp, r16 / 13 sp | 0 | hata: `danger` 1.5 dp, beyaz dolgu |
| 06 Açıklama alanı | ~100 dp, "0/500" | ~98 dp, "0/1000" | sayaç | sunucu sınırı 1000 |
| 06 Katılım sekmeleri | Herkese açık / İstek ile | aynı (açık/onaylı politikası) | 0 | |
| 06 Eklenen: Logo satırı, Görünürlük | yok | var | + | davranış korunur (logo yükleme, gizli kulüp) |
| 06 "+ Katılma sorusu ekle" / "Oluştur" | var | var (açık katılımda dokununca "İstek ile"ye geçer) | - | soru kaydı yalnız istekli kulüpte geçerli |

## Davranış korunan sapmalar
- Arama simgesi, Logo satırı ve Görünürlük (Gizli) seçici referansta yoktur; ürün özellikleri silinemediği için eklidir.
- Hero (kulüp logosu): detayda logo kalktığı için liste->detay logo uçuşu kaldırıldı.
- Anketler sekmesi Hakkında sekmesinin altına taşındı (anket yoksa ve yönetici değilse bölüm gizlenir).
- Yönetici "Üyeleri yönet" düğmesi kalktı; üye satırındaki üç nokta aynı yönetim sayfasını açar.
- Mavi/yeşil logo tonları kalktı: tüm logolar `sf2` + muted baş harf.

## Ortak dosyalarda öneri (M0)
- `BuScale`: Stitch sayfa başlığı 28 sp ve form başlığı 22 sp; yerel `fontSize: 28` yerine `BuScale.hero` istenir.
- `BuChip`: seçili çip çerçevesiz (soft zemin + `pr` metin) varyantı.

## Doğrulama
- `test/redesign/p51_kulup_test.dart` (6 test: sekme/satır/detay + 3 dil x açık/koyu x 1.0/1.3 x 320/390 taşma matrisi),
  güncellenen `clubs_manage_test`, `club_categories_test`, `k7_club_crop_test`, `kulup_detay_design_test`, `p2_dd_test`,
  `dd_test`, `clubs_tab_design_test` (148+ test yeşil). Ekran görüntüleri: `p51_kulup_shots_test.dart` (tr 390 açık; koyu/ar/x1.3
  için `P51_MODES=dark,x13`, `P51_LANG=ar`; bu turda yalnız tr 390 açık üretildi ve referansla kıyaslandı).
- Emülatör gezisi ve gerçek cihaz akıcılığı bu turda yapılmadı (doğrulanamadı).
