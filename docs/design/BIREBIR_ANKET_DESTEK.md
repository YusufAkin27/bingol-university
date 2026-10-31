# BİREBİR: Anketler (4 ekran) + Destek (5 ekran) (Stitch v3)

Kaynak: `C:\bu_design\stitch\v3_club\anketler\*_light.png` ve `destek\*_light.png` (390 px = 390 dp, 1 px = 1 dp) +
`SARTNAME.md` "ANKETLER" / "DESTEK". Uygulama: `mobile/lib/features/polls/*`, `mobile/lib/features/support/*`.
Ortak parçalar: `polls/anket_flat.dart` (metin sekmeleri, durum satırı, alan etiketi/süsü, çerçeveli düğme, düz amber not,
radyo/onay işareti, `anketDayLabel`). Ekran görüntüsü üretimi: `mobile/test/redesign/p68_anket_destek_shots_test.dart`
(390x844, dpr 2; sayfa bir rotadan itilir, geri oku görünür). Ölçüm: PNG'de satır bantları (`bands.py` türü, 2 px/dp).
Yan yana PNG'ler: `C:\bu_qa\shots\tasarim\pollsup\yan_*.png` (sol referans, sağ uygulama; koyu `_koyu`, 1.3x/320 `_x1.3_320`,
Arapça `pollsup_ar\`).

Ölçüm notu: testlerde `Inter` yerine Roboto yüklüdür; satır genişlikleri %3-5 sapabilir, boy/konum ölçüleri güvenilirdir.
Gerçek cihazda Inter ile ölçülmedi (doğrulanamadı). Referansta üst çubuk 56 dp + geri oku; uygulamada ortak `BuPageScaffold`
(başlık x farkı: ortak AppBar `titleSpacing 16`, tüm ekranlarda aynı; bu işte dokunulmadı).

## Yapılanlar

- Anketler 01: kartsız satır + `bd` ayraç (başlık 17 sp/600, "Kapsam · Tür · Kalan süre" muted 14 sp, sağda "N katılım" ve `ok` yeşil
  "Oy verdiniz"), metin sekmeleri (`pr` 2 dp alt çizgi), `pr` "+ Yeni" (yalnız yetkili kulüp listesi). Boş/hata = tek soluk satır
  + `pr` metin düğmesi (ikon/kart yok). Satırdaki "Oy ver" düğmesi, sekme rozeti sayısı, "Kapanan" altındaki "Katıldıklarım" bloğu
  ve sonuç özeti kartı kalktı (satır dokunulur).
- Anketler 02: başlık 24 sp/700 + meta ("Yemek · Tek seçim · Gizli oy · 2 gün kaldı") + ayraç; 56 dp beyaz r16 seçenek satırı (seçili
  `soft` + `pr` 1.5 dp çerçeve + `pr` radyo; çoklu = kare, sıralı = numara), "Oy ver" içerikte (sabit alt çubuk kalktı),
  "Kimin ne oy verdiği kimseye gösterilmez." notu. Rozet/kart/ipucu kutuları metne çevrildi, uyarılar ikonsuz amber.
- Anketler 03: seçenek adı + yüzde (16 sp), 8 dp çubuk (kendi seçim/önde `pr`, diğerleri `sf2` üstüne `mut` %18), "Senin oyun" +
  "N oy", "N katılım · kalan süre", çerçeveli "Oyumu geri çek" (+ `pr` metin "Oyu değiştir"). Puanlama sonucu kartsız.
- Anketler 04: etiket üstte (13 sp muted/600), 48 dp beyaz alanlar (`bdStrong` 1 dp, r16), tür metin segmenti (yeni kısa etiketler
  "Çoklu/Sıralı"), "Seçenekler (2-12)" + "2 / 12", x ile silme, "+ Seçenek ekle", satır içi "En az 2 seçenek girin.", bitiş çipleri
  (1/3/7 gün, Tarih seç), sağda radyolu çizgili görünürlük satırları, çizgili anahtar satırları, "Yayınla" içerikte.
- Destek 01: "Sık sorulan sorular" akordeonu ve "Taleplerim" kartsız satırlar ("12 Ekim · Yanıtlandı": `ok` / amber / muted),
  `pr` "Yeni talep", "Geri bildirim · Öneri panosu" metin bağlantıları.
- Destek 02: başlık = talep konusu, "● Yanıtlandı · Bilet #n" + "Talebi kapat" (menü yerine), gün ayracı (çizgi + büyük harf),
  destek balonu beyaz + ince çizgi ("Destek" etiketi), benim balonum `sf2`, saat balon içinde, "Yanıtını yaz" + 44 dp `pr` gönder.
- Destek 03: "Konu" (sağda "Zorunlu", 3 karakter doğrulaması satır içi), "Mesaj" + sayaç, "Yanıtı bildirim ve e-posta ile alırsın.",
  `pr` "Gönder" (ikonsuz). Destek 04: bkz. Anketler 01 durum satırı. Destek 05: metin sıralama, kartsız satır, 56x64 oy kontrolü.

## Ölçü tablosu (dp; referans / uygulama)

| Ekran / öğe | Referans | Uygulama | Fark | Not |
|---|---|---|---|---|
| A01 Sekme yazısı / alt çizgi (y) | 66 / 80-81 | 67 / 80-81 | <=1 | 14 sp; görünür 26 dp, dokunma 48 dp |
| A01 İlk ayraç / satır ayraçları (y) | 106 / 193, 272, 351 | 106 / 193, 273, 353 | <=2 | satır 79-80 dp |
| A01 Başlık / meta bandı (y) | 136-152 / 163-175 | 134.5-151 / 161.5-175 | 1.5 | 17 sp/600, 14 sp |
| A02 Başlık / meta (y) | 85-106 / 116-128 | 85.5-108.5 / 117-129.5 | <=1 | 24 sp/700 |
| A02 Ayraç / seçenekler (y) | 154 / 179, 247, 315, 383 | 154 / 179, 247, 315, 383 | 0 | 56 dp, aralık 12 |
| A02 "Oy ver" / not (y) | 475-522 / 535-547 | 475-522.5 / 534.5-547.5 | 0 | 48 dp |
| A03 Başlık / meta (y) | 70-89 / 100-111 | 69.5-92.5 / 101-113.5 | <=1.5 | |
| A03 Ad / çubuk / alt satır (y) | 144 / 166-173 / 182-194 | 142.5 / 165-172.5 / 181-193 | <=1.5 | çubuk 8 dp |
| A03 Satır adımı | 81-82 | 80 (25.5 dp alt boşlukla ~81.5) | ~1 | |
| A03 Özet / "Oyumu geri çek" (y) | 502 / 532-575 (44) | ~501 / ~531-575 (44) | <=1 | 48 dp dokunma |
| A04 Etiket / alan (y) | 76 / 96-143 | 75.5 / 96-143.5 | 0.5 | alan 48 dp |
| A04 Açıklama alanı | 192-283 | 192.5-283 | 0 | |
| A04 Tür etiketi / segment | 312 / 332-371 (40) | 312 / 330.5-370 (40) | <=1.5 | dokunma 48 dp |
| A04 Seçenek alanları (y) | 422-469, 480-527 | 422.5-470, 480.5-528 | 0.5 | 48 dp, aralık 10 |
| A04 "+ Seçenek ekle" / "Bitiş zamanı" (y) | 544 / 588 | 544 / 588.5 | <=0.5 | |
| A04 Bitiş çipleri (y, yükseklik) | 610-643 (34) | 610-643.5 (34) | 0 | tek satır |
| A04 Görünürlük / anahtar blokları | 692-845 / 870-1012 | 692-851 / 888-1018 | <=6 | radyo satırı 51 dp, çerçeve yok (hairline) |
| A04 "Yayınla" (y) | 1045-1092 | ~1045-1092 | <=1 | 48 dp |
| D01 Bölüm başlığı / ilk soru (y) | 84-98 / 141-156 | 85-97.5 / 140.5-156 | 0.5 | 18 sp/600; soru 16 sp/500 |
| D01 SSS ayraçları (y) | 244, 301, 358 | 245, 302, 359 | 1 | satır 57 dp |
| D01 Talep satırı: başlık / meta / ayraç (y) | 442 / 467 / 499 | 445 / 469.5 / 500 | <=3 | satır 77 dp |
| D01 "Yeni talep" / bağlantılar (y) | 686-733 / 758-771 | 688-735.5 / 760.5-773.5 | 2.5 | 48 dp |
| D02 Durum satırı / ayraç metni (y) | 72-85 / 125-137 | 72-85 / 125.5-136 | 0 | |
| D02 Balonlar (y) | 176-307, 324-431, 468-578 | 175-306.5, ~323-430, 466-574.5 | <=3.5 | r16, sf / sf2 |
| D02 Gönder düğmesi | 44 dp | 44 dp (dokunma 48) | 0 | |
| D03 Etiket / alan (y) | 60-70 / 80-127 | 59.5-69 / 80.5-128 | 0.5 | 48 dp |
| D03 Mesaj etiketi / alan (y) | 148 / 168-307 | 149 / 170-310.5 | 1-3.5 | alan ~141 dp |
| D03 Sayaç (y) | 320-332 | 319.5-331 | 0.5 | |
| D05 Oy kontrolü | 56x64 | 56x64 | 0 | r16, 1 dp çerçeve |
| D05 Satır adımı | 125 | 125 | 0 | başlık 18 sp/600 (ölçüldü; şartname 16 diyor) |

## Davranış korunan / bilinçli sapmalar
- Başlık x konumu (+8): ortak AppBar. "Başka öneri bulunmuyor." ve D05 ilk satırın 14 dp sıkışık alt boşluğu Stitch artefaktı/şartnamede
  yok: uygulanmadı (satır adımı tüm satırlarda eşit). A03/A02 başlık yazı tipi serif görünümü: Inter kalır.
- "Yeni talep" formunda kategori çipleri (tek satır, kaydırılır) referansta yok; API kategori ister, davranış korunur (+~70 dp).
- SSS arama + kategori sekmesi 6'dan çok soruda görünür (referansta üç soru: yok); davranış korunur.
- Destek ana sayfadaki "Sürüm x" satırı ve geri bildirim/öneri "yönetici onayından sonra yayımlanır" notu (liste) kalktı; öneri detayında not duruyor.
- Geri bildirim formu (Stitch ekranı yok) eski görünümde kaldı. Kulüp detayındaki "Anketler" bölümü aynı kartsız satırlara çevrildi.
- Yeni renk yok; koyu tema RENK-1 belirteçlerinden türer (`_koyu` PNG'leri). Referansta yüzde/ad ink rengi sıcak siyah, uygulamada `ink`.

## Doğrulama
- `test/redesign/p68_anket_destek_test.dart` (davranış + 3 dil x açık/koyu x 1.0/1.3 x 320/390 taşma matrisi, 9 ekran) ve güncellenen
  `anket_test`, `polls_test`, `destek_test`, `pages_c_test`, `redesign/k8_polls_test`, `k8_support_test`, `p13_test` (~340 test yeşil).
- Emülatör gezisi ve gerçek cihaz akıcılığı bu turda yapılmadı (doğrulanamadı).
