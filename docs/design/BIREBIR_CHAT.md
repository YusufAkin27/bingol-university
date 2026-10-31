# BIREBIR_CHAT: sohbet ekranları, Stitch v3 referansı ↔ uygulama (dp)

Referans: `C:/bu_design/stitch/v3_chat/` (SARTNAME.md + PNG'ler). Uygulama: `mobile/lib/features/chat/**`. Ölçek: referans PNG 1170 px = 390 dp (3x), uygulama test görüntüsü 975 px = 390 dp (2.5x); ikisi de 924 px geniş gösterildiğinde 1 gösterilen piksel = 0.422 dp, bu yüzden konuşma ekranı yan yana ölçülebildi. "Ölçüm" sütunu: **ölç** = referans ile uygulama görüntüsü yan yana ölçüldü; **şart** = referansın SARTNAME/PNG değeri ile koddaki sabit karşılaştırıldı (piksel farkı alınmadı); **sapma** = bilerek farklı.

## Konuşma ekranı (`01_konusma_desenli_light.png` ↔ `p3chat_bg_shots_test` konusma_acik)

| Öğe | Referans dp | Uygulama dp | Fark | Ölçüm |
|---|---|---|---|---|
| Üst çubuk yüksekliği (durum çubuğu hariç) | 63 | 64 | 1 | ölç |
| Üst çubuk alt çizgisi | 1 dp `bd` | 1 dp `bd` (gölge yok) | 0 | ölç |
| Geri oku merkezi (soldan) | 27.4 | 26.2 (padding 2 + 48 dokunma alanı) | 1.2 | ölç |
| Avatar sol kenarı / boyutu | 54 / 40 | 54 / 40 | 0 | ölç |
| Ad metni sol kenarı | 106 | 106 (avatar kutusu 48 + 8) | 0 | ölç |
| Menü (⋯) merkezi (sağdan) | 34 | 34 (padding 10 + 24) | 0.5 | ölç (düzeltme sonrası, 12 dp iken fark 2.5 dp'ydi) |
| Tarih hapı yüksekliği | 27 | 26 | 1 | ölç |
| Mesaj listesi yan kenarı | 17 | 16 | 1 | ölç |
| Balon köşesi / kuyruk köşesi | 18 / 4 (giden: üst-uç) | 18 / 4 (giden: üst-uç) | 0 | şart |
| Balon iç boşluğu | 14 x 10 | 14 x 10 | 0 | şart |
| Saat konumu | balonun altında sağda (kısa balonda da) | altta sağda (`BubbleTextMeta.stacked`) | 0 | şart |
| Gelen mesaj avatarı (birebir) | yok | yok | 0 | şart |
| Grup gönderen avatarı | 28 dp baş harfli squircle | 28 dp baş harfli squircle | 0 | şart |
| "+" merkezi (soldan) | 30 | 30 (padding 6 + 48 alan) | 0 | ölç |
| Metin alanı sol / sağ kenar | 56 / 377 | 56 / 378 | 0 / 1 | ölç |
| Gönder düğmesi | 44 dp `pr`, yalnız metin varken | 44 dp `pr` (48 dp dokunma), yalnız metin varken | 0 | şart |
| Alt / üst ayırıcı | 1 dp `bd` | 1 dp `bd` | 0 | ölç |
| Gelen / giden balon yüksekliği (tek satır + saat) | 57 | 58 | 1 | ölç |
| Gelen balon sol / giden balon sağ kenarı | 17 / 373.5 | 17 / 374 | 0.5 | ölç |
| "En alta in" | 40 dp, 16 dp sayaç | 40 dp, 16 dp sayaç | 0 | şart |
| Duvar kağıdı | `00_duvar_kagidi_*` (1170x2532) | aynı dosya, `BoxFit.cover`, yalnız mesaj alanı | 0 | şart |

Sapmalar: (1) metin alanı yüksekliği 46 dp (referans 01'de 38-44 arası ölçüldü): Android 48 dp dokunma kuralı için alan + dikey boşluk 48'e tamamlanır. (2) "çevrimiçi" durum satırı l10n anahtarı büyük harfle ("Çevrimiçi"); referansta küçük harf (ölçü aynı, harf büyüklüğü farkı). (3) Üst çubuk avatarında fotoğraf yoksa baş harf (sf2 zemin, ink), fotoğraf varsa fotoğraf.

## Sohbet listesi (`2_liste/01_sohbet_listesi_light.png`) - şart

| Öğe | Referans | Uygulama | Ölçüm |
|---|---|---|---|
| Başlık | 28 sp/700 | `headlineMedium` | şart |
| Arşiv / "+" | düz 24 dp çizgi ikon | 24 dp düz ikon, 48 dp alan | şart |
| Arama | 52 dp, 1 dp `bdStrong`, 16 dp köşe | `BuSize.field` 52, 1 dp `bdStrong`, 16 dp | şart |
| Çip | 34 dp | `BuChipRow` (34) | şart |
| Avatar | 52 dp | 52 dp | şart (testle sabit) |
| Satır ayırıcı | 1 dp `bd`, avatar sonrasından | 1 dp `bd`, 20+52+14 dp'den | şart |
| Okunmamış satır | tam genişlik açık yüzey, saat `pr`, 20 dp sayaç | `sf` tam genişlik, saat `pr`, 22 dp sayaç | sapma 2 dp |
| Yatay kenar | 20 dp | 20 dp | şart |

## Yeni sohbet (`3_yeni_sohbet/01`) - şart
Başlık 20/600, kenar 16 dp, arama 52 dp, eylem satırı 40 dp köşeli karo + `pr` simge (Yeni grup) + düz ok, kişi satırı kartsız 48 dp avatar + alt çizgi, "Mesaj" küçük çerçeveli 34 dp düğme (48 dp dokunma alanı).

## Galeri (`4_galeri`) ve "+" menüsü (`1_konusma_giris/24`) - şart
Izgara 3 sütun, 2 dp aralık, 10 dp köşe, seçili 3 dp `pr` çerçeve + %15 kararma + 22 dp daire; üst çubukta X, albüm, `pr` "Gönder (n)"; alt not. "+" menüsü: iki karo 100 dp (`bg`, 1 dp `bd`, 16 dp köşe, ikon 28), "Son fotoğraflar" + `pr` "Tümü", şerit 72 dp / 12 dp köşe / 8 dp aralık, ipucu metni; izin yoksa tek satır + `pr` "İzin ver".

## Sohbet bilgisi (`5_bilgi/01`) - şart
Tam genişlik bantlar (üst/alt 1 dp `bd`), bantlar arası 24 dp, satırlar kartsız ve simgesiz 56 dp, yıkıcı satırlar `danger` metin, hızlı eylemler kutusuz 24 dp ikon + etiket, avatar 96 dp squircle (20 dp köşe) baş harfli, ad 22/700.

## Sohbet arka planı ayarı (SARTNAME Kategori 6) - şart
Başlık, önizleme (150 dp, 16 dp köşe, 1 dp `bd`), segment Desen | Düz, "Yoğunluk" + segment Hafif | Orta (yalnız Desen'de), 52 dp `pr` "Uygula", `pr` "Varsayılana dön".

## Yapılamayanlar
- Yapışkan tarih başlığı: liste ters sıralı (`reverse: true`) ve satır yükseklikleri değişken; ekranda görünen ilk günü bulmak ölçüm + ayrı kaydırma dinleyicisi ister ve her kaydırmada yeniden çizim doğurur. Davranış katmanına (`_scroll`, `_rowKeys`) dokunmadan güvenilir yapılamadı, yapılmadı.
- Gönderilirken ince ilerleme: görünüm katmanı gönderim durumunu bilmiyor (outbox davranış katmanı); balondaki durum ikonu (saat -> tik) aynen sürüyor.
- Mesaj menüsü / sohbet menüsü / ilet (`30-32`): mevcut menü zaten tepki çubuğu + mesaj önizlemesi + simgeli menü kartı yapısında; ayrı yeniden çizim yapılmadı, piksel karşılaştırması alınmadı.
- Sohbet listesi, yeni sohbet, bilgi ve galeri için referansla yan yana PNG ölçümü yapılmadı (yalnız kod sabitleri ve SARTNAME değerleri karşılaştırıldı).
