# MENU: Stitch v3 BIREBİR (Yemek, Bildirimler, Bildirim tercihleri)

Kaynak: `C:\bu_design\stitch\v3_home\2_yemek\*`, `3_bildirimler\*`, `SARTNAME.md` (bölüm 2, 3) ve `_kaynak_html\C_yemek_bildirim\...\*_2\code.html` (px = dp). Hedef dosyalar: `mobile/lib/features/menu/` (`menu_page`, `menu_parts`), `features/notifications/` (`notifications_page`, `notif_row`), `features/profile/notification_prefs_page.dart`.

## Yöntem
1. Referans PNG'ler 706 px genişlik: 390 dp'ye göre ölçek 1,8103 (tercihler PNG'si 612 px: 1,569). Yazı boyutları PNG'deki metin genişliğinden ve HTML belirteçlerinden çıkarıldı. Şartnamedeki sayılar (öğün başlığı 20 sp, satır 16 sp) PNG ile uyuşmuyordu: PNG ve HTML kanundur, **17 / 14 / 13 / 15 sp** (headline-sm / body-md / body-sm / title-md) uygulandı.
2. Uygulandı: yeni renk yok (`context.bu`: bg, sf, bd, pr, soft, warnSoft, onWarnSoft, danger, ink, mut); koyu tema aynı belirteçlerden türer.
3. Ölçü testi: `mobile/test/redesign/p62_birebir_menu_test.dart` (390 x 844, tr) — her satır referans dp ile uygulama dp'sini karşılaştırır, fark sınırı dışındaysa başarısız olur. Yan yana PNG: `C:\bu_qa\shots\tasarim\p3\birebir\menu\yan_yana_*_tr.png` (+ koyu ve ar390 ham görüntüler aynı klasörde). Üretim: `P62_OUT=... flutter test test/redesign/p62_shots_test.dart`.
4. Dikey konumlar "başlık dairesinin görsel üstüne" göredir (`BuHeader` ortak parça: 40 dp daire, 48 dp dokunma kutusu; testte +4 dp düzeltmesi).

## Ölçü tablosu (390 dp)

| Öğe | Referans dp | Uygulama dp | Fark |
|---|---|---|---|
| Gün hapı genişliği | 42 | 42,0 | 0 |
| Gün hapı yüksekliği | 47,5 | 48,0 | +0,5 |
| Gün hapı üstü (daireye göre) | 63,5 | 64,0 | +0,5 |
| Öğün yüzeyi sol / sağ kenar | 20,4 / 369 | 20,0 / 370 | -0,4 / +1,0 |
| Öğün yüzeyi yüksekliği (4 yemek + toplam) | 307,6 | 307,4 | -0,2 |
| Öğün yüzeyi üstü (daireye göre) | 161,9 | 162,0 | +0,1 |
| Gün etiketi sol / merkez (daireye göre) | 20,4 / 144,7 | 20,0 / 144,0 | -0,4 / -0,7 |
| Etiket -> yüzey boşluğu | 9,9 | 8,0 | -1,9 |
| Öğün başlığı sol (yüzeye göre) | 21 | 20 | -1,0 |
| Saat / kcal / toplam sağ kenarı (yüzeye göre) | 20,4 | 20,0 | -0,4 |
| Yemek satır adımı | 49,2 | 49,0 | -0,2 |
| Bildirim satır adımı | 91,1 | 90,0 | -1,1 |
| Bildirim satır genişliği (çizgi) | 350 | 350 | 0 |
| Çip yüksekliği / aralık | 34 / 8 | 34 / 8 | 0 |
| "Tümü" çipi genişliği | 68,5 | 69,7 | +1,2 |
| Çip üstü (daireye göre) | 43,6 | 44,0 | +0,4 |
| Okunmamış nokta çapı | 8 | 8 | 0 |
| Tür etiketi sol (satıra göre) | 19,9 | 20,0 | +0,1 |
| Başlık - tür etiketi dikey | 21 | 21 | 0 |
| Tercih satırı adımı (iki satırlı) | 77,1 | 78,0 | +0,9 |
| Anahtar (genişlik x yükseklik) | 48 x 28 | 48 x 28 | 0 |
| Anahtar sağ kenarı | 353 | 354 | +1,0 |
| Başlık - alt metin dikey (tercih) | 23,6 | 23,5 | -0,1 |

Yazı boyutları (referans PNG genişliğinden): öğün başlığı 17/600, saat 14, yemek adı 14, kcal 13 (oransız rakam), toplam etiketi 14/500, toplam değeri 15/700, gün etiketi 13 (+0,01 em), gün kısaltması 11,5/500, gün numarası 15/600; bildirim tür+zaman 12, başlık 15/600, gövde 14, grup etiketi 13/600 büyük harf, çip 14/500; tercih başlığı 15/500 (üst "Anlık bildirimler" 16/600), alt metin 13, bölüm başlığı 17/600, "Bu cihazda" 13/500.

## Yapılan değişiklikler (ekran bazında)
- **Yemek**: fotoğraf/yer tutucu kartı kalktı (`menu_photo.dart` artık kullanılmıyor, testleri duruyor); gün şeridi 42 dp hap (seçili `soft` + `pr` metin, diğerlerinde zemin yok, bugün noktası yok); tek beyaz yüzey (1 dp `bd`, 16 köşe, iç 20): başlık + saat, 1 dp çizgili satırlar, kalorisiz yemekte "–", "Toplam enerji" (eksikse "En az N kcal" + 12 sp not); bayat bant `warnSoft` + ince amber çerçeve; boş: ortada "Yemek listesi yok." (+ bakımdaysa "Sistem bakımda."), eylem düğmesi yok (yenilemek için çek).
- **Bildirimler**: kart ve simge dairesi yok; satırlar zeminde 1 dp `bd` çizgili; solda 8 dp `pr` nokta (okunmuşta yer boş); tür etiketi + zaman 12 sp; başlık 15/600; gövde tek satır; çipler "Tümü" (`soft`+`pr`) / "Okunmamış" (çerçeveli), sayaç rozeti yok; "Tümünü okundu yap" `pr` metin (dar ekranda başlığın altı); sola kaydırınca `danger` "Sil" levhası; "Hepsi bu kadar"; bir haftadan eski tarih "22 Ekim" (yıl aynıysa); boş "Henüz bildiriminiz yok." / "Okunmamış bildiriminiz yok."; hata: soluk cümle + `pr` "Yeniden dene".
- **Bildirim tercihleri**: yüzey beyaz + 1 dp `bd` (gölge yok); satır iç 16, başlık 15/500 + 13 sp alt metin; anahtar 48 x 28 (açık `pr`, kapalı `bd` iz, 24 dp beyaz topuz); "Anketler" ve "Akademik duyurular" tek satır; "Ayrıntılı tercihler" ve "Sessiz saatler" (sağda "23:00 – 07:00") ayrı yüzeyde; "Sessiz saatler" artık kendi sayfasında (aç/kapat + başlangıç/bitiş satırları, aynı istek gövdesi); "Bu cihazda > Ders ve sınav hatırlatmaları" anahtarı (ders + sınav yerel hatırlatmalarını birlikte açar/kapatır). Ayrıntılı tercihler sayfası: başlık "Ayrıntılı tercihler", her ana bayrak tek yüzey, alt anahtarlar 1 dp çizgili.
- Metinler (ARB, tr/en/ar, yeni anahtar yok): `notifEmpty`, `bildirimEmptyUnread`, `p03MenuKcalMissing` (noktalı cümle).

## Kalan sapmalar ve gerekçeleri
- **Başlık çubuğu** (`BuHeader`, ortak): başlık 28 sp/700 (referans 22 sp), geri düğmesi 40 dp daire + 48 dp dokunma kutusu, üst 8 dp; referansın yatay başlık konumu aynı, dikey ofset durum çubuğundan. M0'a öneri: `BuHeader` başlığı 22 sp.
- **Puanlama satırı** (`features/polls/poll_menu_card.dart`, DD klasörü, dokunulmadı): şartnamedeki düz satır (başlık 16/600, 24 dp yıldız, 13 sp ipucu) için DD'ye öneri. Yemek ekranı kartın üstüne 24 dp boşluk bırakır; kart yalnız bugün ve menü varken gösterilir (boş listede puanlanacak menü yok).
- **Etiket -> yüzey 1,9 dp**: referans PNG'de 9,9 (HTML hesabı 7,3); 8 dp seçildi (HTML `mb-space-sm`).
- **Anketler satırı alt metni**: yalnız bağımlılık varsa ("Duyurular veya Kulüpler kapalıysa ilgili anket bildirimleri gelmez") görünür; referansta Kulüpler kapalıyken not yok. Bilgi kaybı olmasın diye korundu (p26 testleri).
- **"Ders ve sınav hatırlatmaları"**: anahtar referans gibi, ama satıra dokunmak `ReminderSettingsPage`'i açar (süre/izin ayrıntısına erişim kaybolmasın).
- **Push durumu** ("Anlık bildirimler" kartı) Firebase'siz test ortamında okunamaz: kapalı varyantı (başlık + "Henüz yapılandırılmadı"/"Kapalı..." + `pr` "Ayarlardan aç") test edildi; "izin verildi" varyantı referanstaki gibi kodla çizilir, ekran görüntüsünde doğrulanamadı (görüntü kartsız grup içindir).
- **Dokunma alanı**: gün hapı 42 dp görsel, 46 x 48 dp alan; çip 34 dp görsel, 48 dp alan (`BuTouchTarget`, görsel konum 7 dp yukarı alınarak ölçüye oturtuldu).
- Gerçek cihazda (Redmi 13C, iPhone) ve emülatörde görsel kıyas yapılamadı; kıyas widget-test render'ıyladır.
