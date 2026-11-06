# Widget: Ders Programım (slug `timetable`)

Üretim yolu: Google Stitch kullanılamadı (paylaşımlı tarayıcıda oturum doğrulanamadı); tasarımlar elle HTML/CSS (Inter) ile yazıldı ve Playwright ile 3x ekran görüntüsü alındı. Kaynaklar: `stitch/html/*.html`, üretici `../_gen/gen.js` (+ `../_gen/mock.py`).

Birim: iOS pt = Android dp = CSS px. PNG'ler 3x piksel.

## Dosyalar
`ios-{small,medium,large}-{light,dark}.png`, `android-{2x2,4x2,4x4}-{light,dark}.png`, boş durum: `ios-medium-empty-*.png`, `android-2x2-empty-*.png`, maketler: `home-{ios,android}-{light,dark}.png`.

## Veri alanları
`date`, `lessons[]` = `{start "HH:mm", end, title, room}` (bugün, saate göre sıralı), `next` = şu an bitmemiş ilk ders, `minutesToNext` (`18 dk sonra`; 60 dk üstü `2 sa sonra`; ders sürüyorsa `Şu an` ), boşsa `empty` + `nextDay` ("Pazartesi 08:30"). Veri kullanıcının kendi ders programından (profil/yerel kayıt); başka kullanıcı verisi yok.

## Dokununca
Tüm boyutlar: uygulamada Ders Programı ekranı (bugün sekmesi). Boş durumda da aynı.

## Boyut ölçüleri
| | iOS small | iOS medium | iOS large | Android 2x2 | 4x2 | 4x4 |
|---|---|---|---|---|---|---|
| Boyut | 158x158 | 338x158 | 338x354 | 170x170 | 350x170 | 350x350 |
| Köşe | 22 | 22 | 22 | 28 | 28 | 28 |
Ortak: iç boşluk 16, kenarlık 1px, tek düz arka plan, gölge yok.

## Tipografi (Inter, HER YERDE weight 400)
| Rol | Boyut/satır | Harf aralığı | Kullanım |
|---|---|---|---|
| caption | 10/12 | +0.08em, BÜYÜK | başlık etiketi |
| display | 22/26 | -0.02em | boş durum başlığı |
| title | 17/22 | -0.01em | small ders adı, large "Bugün 4 ders" |
| body | 13/18 | -0.01em saat, 0 ad | saat, ders adı, saat rozeti |
| body-s | 12/16 | 0 | derslik, "18 dk sonra", alt not |

## Renk belirteçleri
| Belirteç | Koyu | Açık |
|---|---|---|
| arka plan iOS | #111113 | #FFFFFF |
| arka plan Android | #18181B | #FFFFFF |
| vurgulu satır yüzeyi iOS / Android | #1F1F23 / #232327 | #F4F4F5 |
| birincil yazı | #FAFAFA | #09090B |
| ikincil yazı | #A1A1AA | #52525B |
| üçüncül | #71717A | #71717A |
| kenarlık | #27272A | #E4E4E7 |
| ters rozet (sıradaki ders saati) arka / yazı | #FAFAFA / #09090B | #09090B / #FFFFFF |
Kırmızı/marka rengi yok. Geçmiş ders: tüm satır opaklık 0.5. Logo ve başlık satırı `menu/README.md` ile aynı (yükseklik 16, alt boşluk 12, medium'da 12; ikon 12px, çizgi 1.5).

## Boyuta göre düzen
- **Small / 2x2:** başlık `SIRADAKİ` (clock ikonu). Satır: ters rozet `10:30` (köşe 8, iç boşluk 2x8, body 13/18) + 8px boşluk + `18 dk sonra` (body-s üçüncül). 8px altında ders adı (title 17/22, en çok 2 satır, `...`). Alt kenarda pin ikonu 12px + derslik (`B-204`, body-s ikincil, tek satır). Ders sürüyorsa rozet yerine `Şu an` rozeti ve bitiş saati.
- **Medium / 4x2:** başlık `Cuma, 6 Kasım · Sıradaki` (clock). Altta en çok 2 ders satırı, aralık 4. Satır: yükseklik 36, yatay iç boşluk 8, köşe 12, öğeler arası 8. Sıradaki satır yüzey rengiyle dolu + ters rozet (genişlik 52, ortalı, saat); diğer satır: saat metni 13/18 (genişlik 52, birincil), ders adı body 13/18 (esnek, tek satır `...`), sağda pin 12px + derslik body-s ikincil (sabit, kesilmez).
- **Large / 4x4:** başlık tarih (cal ikonu). Altında satır: sol `Bugün 4 ders` (title 17/22), sağ `18 dk sonra` (body-s ikincil), alt boşluk 12. Sonra en çok 4 ders satırı, yükseklik 40, aralık 6, aynı satır yapısı; biten dersler opaklık 0.5 ve saat ikincil renk, sıradaki satır yüzeyli + ters rozet. En altta (esnek boşluktan sonra) `Son ders 17:20 de biter` body-s üçüncül. 4'ten çok ders varsa sıradakinden başlayarak 4 gösterilir, alt not `+N ders daha`.
- **Boş durum (ders yok):** small: başlık `DERS`, ortada display `Bugün ders yok` (2 satıra kadar), altında body-s üçüncül `Sıradaki: Pzt 08:30`. Medium: başlık `DERS PROGRAMI`, ortada display tek satır, altında body ikincil `Sıradaki ders: Pazartesi 08:30`. Large/4x4 medium düzeninin dikey ortalanmışı.

## Davranış
Kesme: ders adı tek satır `...` (small hariç 2 satır); derslik asla kesilmez (en çok 8 karakter). Yenileme: her ders başlangıç/bitişinde ve gece yarısı (zaman çizelgesi girişleri). KVKK: yalnız kullanıcının kendi dersi.
