# Widget: Günün Yemek Menüsü (slug `menu`)

Üretim yolu: Google Stitch kullanılamadı (paylaşımlı tarayıcıda oturum doğrulanamadı); tasarımlar elle HTML/CSS (Inter) ile yazıldı ve Playwright ile 3x ekran görüntüsü alındı. Kaynaklar: `stitch/html/*.html`, üretici `../_gen/gen.js` (+ `../_gen/mock.py` ana ekran maketleri).

Birim: iOS pt = Android dp = CSS px (1:1). PNG'ler 3x piksel.

## Dosyalar
`ios-{small,medium,large}-{light,dark}.png`, `android-{2x2,4x2,4x4}-{light,dark}.png`, boş durum: `ios-medium-empty-*.png`, `android-2x2-empty-*.png`, maketler: `home-{ios,android}-{light,dark}.png`.

## Veri alanları
`date` (Europe/Istanbul bugün), `lunch[]` ve `dinner[]` = `{name, kcal}` (API `dishes[{name,kcal}]`), `totalKcal` (API `totalKcal`; `kcalComplete=false` ise toplam yerine "~" öneki ya da kcal gizlenir), menü yoksa `empty`. Kaynak: `GET /api/menu` (widget kendi çekmez; uygulama önbelleği/paylaşılan depodan okur). Sayı biçimi tr: `1.570`.

## Dokununca
Tüm boyutlar: uygulamada Yemek sekmesi (bugünün menüsü). Boş durumda da aynı.

## Boyut ölçüleri
| | iOS small | iOS medium | iOS large | Android 2x2 | 4x2 | 4x4 |
|---|---|---|---|---|---|---|
| Boyut (pt/dp) | 158x158 | 338x158 | 338x354 | 170x170 | 350x170 | 350x350 |
| Köşe | 22 | 22 | 22 | 28 | 28 | 28 |
Ortak: iç boşluk 16 her kenar, kenarlık 1px (`border`), tek düz arka plan (gradyan yok), gölge yok (yalnız maket gölgesi).

## Tipografi (Inter, HER YERDE weight 400)
| Rol | Boyut/satır | Harf aralığı | Kullanım |
|---|---|---|---|
| caption | 10/12 | +0.08em, BÜYÜK HARF | başlık etiketi (ÖĞLE, AKŞAM, tarih) |
| display | 22/26 | -0.02em | small'da ana yemek, boş durum başlığı |
| body | 13/18 | 0 | yemek adları |
| body-s | 12/16 | 0 | kcal, ikincil satır |
Boş durum alt metni: small 12/16, medium 13/18.

## Renk belirteçleri
| Belirteç | Koyu | Açık |
|---|---|---|
| arka plan iOS | #111113 | #FFFFFF |
| arka plan Android | #18181B | #FFFFFF |
| yüzey (chip) iOS / Android | #1F1F23 / #232327 | #F4F4F5 |
| birincil yazı | #FAFAFA | #09090B |
| ikincil yazı | #A1A1AA | #52525B |
| üçüncül (caption, kcal sayıları) | #71717A | #71717A |
| kenarlık/ayraç | #27272A | #E4E4E7 |
Kırmızı kullanılmaz, marka rengi yok. Logo: `mobile/assets/branding/logo_dark.png` (koyu tema, beyaz glif) / `logo_light.png` (açık tema, siyah glif), yükseklik 12, sağ üst, opaklık 0.9.

## Ortak başlık satırı
Yükseklik 16, alt boşluk 12 (medium'da 8). Solda ikon (12px, çizgi 1.5, currentColor, ton = caption rengi) + 4px boşluk + caption; sağda logo.

## Boyuta göre düzen
- **Small / 2x2:** başlık `ÖĞLE` (sun ikonu). Ana: öğle ana yemeği (display 22/26, en çok 2 satır, `...`). Altında 4px boşlukla body-s ikincil "Çorba · Pilav · Salata" (ikincil renk, tek satır, `...`). Alt kenarda (flex boşluk sonrası) flame ikonu 12px + `1.570 kcal bugün` (body-s, ikincil). Akşam saatinde (18:00 sonrası) başlık `AKŞAM` + moon ikonu, ana yemek akşam ana yemeği.
- **Medium / 4x2:** başlık = `Cuma, 6 Kasım` (utensils ikonu). İki sütun, 16px aralık, ortada 1px ayraç (kenarlık rengi). Her sütun: caption başlığı (sun `ÖĞLE` / moon `AKŞAM`, 12px ikon, alt boşluk 6) + en çok 3 yemek (body 13/18, satır aralığı +2px, tek satır `...`). Alt: flame 12px + `Toplam 1.570 kcal` (body-s ikincil), üst boşluk 4. Yemek kcal'ı gösterilmez.
- **Large / 4x4:** başlık tarih. İki bölüm: satır = caption (ikon + ÖĞLE) solda, bölüm toplam kcal sağda (body-s ikincil), alt boşluk 6; ardından 4 yemek: ad body 13/18 (sol, tek satır `...`), kcal body-s üçüncül renk (sağ), satır arası +2. Bölümler arası 1px ayraç, dikey boşluk 10. En altta chip: yükseklik 36, köşe 12, yüzey rengi, iç boşluk 8x12, flame 14px, "Günlük toplam" body, sağda `1.570 kcal` body. Yemek sayısı 4'ten çoksa ilk 4 + (gerekirse) son satır `+2 yemek` body-s üçüncül.
- **Boş durum (menü yok):** small: başlık `YEMEK`, dikey ortada display `Bugün menü yok` (2 satır'a kadar), 4px altında body-s üçüncül `Yemekhane tatilde olabilir`. Medium: başlık `YEMEK MENÜSÜ`, ortada display tek satır + body ikincil `Menü yayımlanınca burada görünür`. Large/4x4 medium düzeninin dikey ortalanmışı.

## Davranış
Metin kesme: tek satır `text-overflow: ellipsis`; yalnız small ana yemek 2 satır. Yenileme: gece yarısı ve 12:00 / 18:00'de. Veri yoksa ve önbellek eskiyse son menü + `Güncel olmayabilir` yok, doğrudan boş durum. KVKK: kişisel veri yok.
