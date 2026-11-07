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

Sapmalar: (1) metin alanı yüksekliği 46 dp (referans 01'de 38-44 arası ölçüldü): Android 48 dp dokunma kuralı için alan + dikey boşluk 48'e tamamlanır. (2) "çevrimiçi" artık küçük harf (l10n tr/en güncellendi). (3) Üst çubuk avatarında fotoğraf yoksa baş harf (sf2 zemin, ink), fotoğraf varsa fotoğraf.

## Sohbet listesi (`2_liste/01_sohbet_listesi_light.png` ↔ `liste_acik_tr.png`) - ölç

| Öğe | Referans dp | Uygulama dp | Fark | Not |
|---|---|---|---|---|
| Başlık sol kenarı | 16.5 | 16 | 0.5 | ölç |
| "+" merkezi (soldan) | 356 | 356 | 0 | ölç + test (`p3chat_test` hizalama) |
| Arşiv merkezi | 316 | 315.6 | 0.4 | ölç + test |
| Avatar sol kenarı / boyutu | 16 / 52 | 16 / 52 | 0 | ölç + test |
| Metin sol kenarı | 80 | 80 | 0 | ölç |
| Saat sağ kenarı | 373.5 | 373.5 | 0 | ölç |
| Satır yüksekliği (okunmamış) | 76 | 75.5 | 0.5 | ölç |
| Okunmamış sayacı | 20 | 20 | 0 | şart |
| Ayırıcı başlangıcı | 80 | 80 | 0 | ölç |
| Çip sol kenarı | 16 | 16 | 0 | test (`chip.left`; Column `stretch` ile 32'den 16'ya düzeltildi) |
| Arama yüksekliği | 41 (PNG) / 52 (SARTNAME) | 52 | 11 / 0 | **sapma**: PNG ile SARTNAME çelişiyor, SARTNAME + Android dokunma kuralı için 52 |
| Çip yüksekliği | 28 (PNG) / 34 (SARTNAME) | 34 | 6 / 0 | **sapma**: ortak `BuChip` (34), dokunma alanı 48 |

## Sohbet bilgisi (`5_bilgi/01_bilgi_birebir_light.png` ↔ `bilgi_birebir_acik_tr.png`) - ölç

| Öğe | Referans dp | Uygulama dp | Fark |
|---|---|---|---|
| Avatar üstü / boyutu | 80 / 96 | 80 / 96 | 0 |
| Ad merkezi | 199.5 | 200 | 0.5 |
| Alt satır merkezi | 224 | 226.5 | 2.5 |
| Hızlı eylem ikon / etiket merkezi | 270 / 295 | 270 / 295 | 0 |
| İlk bant başlangıcı | 332 | 333.7 | 1.7 |
| Satır yüksekliği | 49 | 48 | 1 |
| Medya başlığı bant başından | 27 | 27 | 0 |
| Küçük resim üstü bant başından / boyutu | 49 / 72 | 49 / 72 | 0 |
| Bantlar arası boşluk | 25 | 25 | 0 |
| Yıkıcı satırlar | `danger` metin, ok yok | aynı | 0 |

## Galeri (`4_galeri/01_galeri_secici_coklu_light.png` ↔ `galeri_acik_tr.png`) - ölç
Başlık çizgisi 52 / 51 dp, kare genişliği 126 / 125.8, aralık 2 / 2, kenar 4 / 4, onay dairesi merkezi karenin sağ-üstünden 19 / 18.4-19, daire 22 / 22. Seçili karede çerçeve/kararma yok (PNG); seçilmemiş karede halka yok. Not "En fazla 10 öğe seçebilirsiniz." ızgaranın altında. Başlıkta albüm pili yok, `pr` "Gönder (n)" sağda. (Küçük resimlerdeki çarpı işaretleri test sahte PNG'sinin çözülememesidir, uygulama kusuru değil.)

## "+" menüsü (`24_arti_menusu_light.png` ↔ `arti_menusu_acik_tr.png`) - şart + görsel
İki karo 100 dp (`bg`, 1 dp `bd`, 16 dp köşe, ikon 28), tutamaç 36x4, "Son fotoğraflar" 14/500 `mut` + `pr` "Tümü", şerit 72 dp / 12 köşe / 8 aralık, ipucu 12 sp `mut`, üst köşe 28 dp (`sf3`). Görüntüde yerleşim referansla aynı; mutlak piksel ölçümü alınmadı.

## Mesaj menüsü (`30_mesaj_menusu_light.png` ↔ `mesaj_menusu_acik_tr.png`)
Satır yüksekliği 52 / 52 dp, kart sol kenarı 16 / 17 dp. **Düzeltildi:** satırlardaki 36 dp simge kutuları kaldırıldı (24 dp düz çizgi ikon, etiket 16 sp normal ağırlık), satır ayırıcıları tam 1 dp `bd`, arka plandaki bulanıklık (`BackdropFilter`) kaldırıldı (düz karartma). Etiketler x: referans 65 dp, uygulama ~58 dp (16 + 24 + 16 = 56 + kart içi) - 2 dp içinde. Tepki çubuğu referansta 6 emoji hapı; uygulamada aynı yapı, çubuk sunucudan gelen emoji listesiyle dolar (test sahte arka ucu boş liste döndürdüğü için görüntüde yok). Sohbet menüsü (`31`) ve ilet (`32`) aynı bileşen ailesini kullanır; ayrı piksel ölçümü alınmadı.

## Yeni sohbet (`3_yeni_sohbet/01`) ve arka plan ayarı - görsel
`yeni_sohbet_*` ve `ayarlar_*` görüntüleri `C:/bu_qa/shots/tasarim/chat_bg/sonra/` altında; kenar 16 dp, kişi satırı alt çizgili, ayarlar segmentli. Ölçüm: şart (kod sabitleri), piksel karşılaştırması alınmadı.

## Yapılamayanlar
- Yapışkan tarih başlığı: liste ters sıralı (`reverse: true`) ve satır yükseklikleri değişken; ekranda görünen ilk günü bulmak ölçüm + ayrı kaydırma dinleyicisi ister ve her kaydırmada yeniden çizim doğurur. Davranış katmanına (`_scroll`, `_rowKeys`) dokunmadan güvenilir yapılamadı, yapılmadı.
- Gönderilirken ince ilerleme: görünüm katmanı gönderim durumunu bilmiyor (outbox davranış katmanı); balondaki durum ikonu (saat -> tik) aynen sürüyor.
- Sohbet menüsü (`31`) ve ilet (`32`): mesaj menüsüyle aynı bileşenler, ayrı ölçüm alınmadı.
