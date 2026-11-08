# Widget: Kampus Duyurulari (slug: announcements)

Premium Monochrome (siyah-beyaz, marka rengi yok, Inter 400, 1 px kenarlik). Tasarim hatti: **Stitch** ("BU Widget - announcements" projesi, ham cikti `stitch/screen.png`, `stitch/code.html`); diger boyut/tema/Android varyantlari ayni dille `stitch/render.html` ile turetildi (Stitch'in 10-12 px yazilari gercek widget icin kucuk bulundu; asagidaki degerler nihai olculerdir). Stitch'in "kirmizi yalniz acil duyuru" notu aynen korundu.

Dosyalar: `ios-{small,medium,large}-{light,dark}.png`, `android-{2x2,4x2,4x4}-{light,dark}.png` (3x piksel, seffaf kose), `home-{ios,android}-{light,dark}.png` (ana ekran maketi), `empty/` (bos durum, 12 adet), `stitch/`.

## Icerik ve veri
Ne gosterir: son duyurular/haberler, **yayin tarihine gore azalan** (en yeni ustte). Kaynak: genel duyuru akisi (`news` tipi duyuru/haber; birim haberi widget'ta YOK, yalniz herkese acik genel akis, giris gerektirmez).
Alanlar: `id`, `title`, `sourceName` (kaynak/birim kisa adi: "SKS", "Öğrenci İşleri", "Uluslararası İlişkiler", "Kütüphane"), `publishedAt`, `urgent` (bool, varsayilan false).
Bicim: tarih = `dd MMM` Turkce, ay yalniz ilk harf buyuk (`05 Kas`, `04 Kas`), yil yok; meta metni = `{sourceName} · {tarih}` (orta nokta U+00B7, iki yanda bosluk). `sourceName` 1 satir ucnokta ile kesilir, tarih ASLA kesilmez.

| Boyut | Duyuru sayisi | Icerik |
|---|---|---|
| iOS small / Android 2x2 | 1 | baslik ikonu, baslik (4 satir), meta |
| iOS medium / Android 4x2 | en cok 3 | logo+ad, satir: nokta + baslik (1 satir) + meta |
| iOS large / Android 4x4 | en cok 4 | logo+ad+sayac, satir: baslik (2 satir) + meta |

## Boyut bazli duzen (tum degerler pt/dp)

### Small (158x158 / 170x170)
1. Ust satir: `megaphone` 14 + 6 + "Duyurular" **11/14 t2**.
2. 10 bosluk; baslik **15/20, 400, t1, en cok 4 satir** + ucnokta.
3. Esnek bosluk, altta meta **11/14 t2, 1 satir ucnokta** (`SKS · 05 Kas`).
Bos durum: ust satir + ortada `megaphone` 20 (t3), 8, "Yeni duyuru yok" **13/17 t2**.

### Medium (338x158 / 350x170)
1. Baslik satiri: logo (h14) + 6 + "Kampüs Duyuruları" **11/14 t2**.
2. 10 bosluk; 3 satir (`space-between`), satir yuksekligi iOS **30** / Android **36**.
3. **Satir**: nokta 4x4 (yuvarlak) + 8 bosluk; metin sutunu: baslik **13/17 1 satir ucnokta**, altinda meta **11/14 t3 1 satir ucnokta**. En yeni (1.) satir: nokta `t1` + baslik `t1`; digerleri: nokta `Rozet kenari/pasif nokta` + baslik `t2`.
Bos durum: baslik satiri + ortada `megaphone` 22 (t3), 8, "Yeni duyuru yok" **13/17 t2**, altinda "Yeni duyurular burada görünür" **11/14 t3**.

### Large (338x354 / 350x350)
1. Baslik satiri: logo + 6 + "Kampüs Duyuruları" **11/14 t2**; sag "Son 4" **11/14 t3** (gosterilen sayi kadar: `Son {n}`).
2. Ayirici 1 px, ust 12 / alt 4.
3. 4 satir esit yukseklik (`flex 1`), aralarinda 1 px ayirici, icerik dikey ortali. Baslik **14/18 400, en cok 2 satir** + ucnokta (ilk satir `t1`, digerleri `t2`); 3 bosluk; meta **11/14 t3 1 satir ucnokta**. Nokta YOK (large'da okunmamis vurgusu ilk satirin t1 tonudur).
Bos durum: baslik satiri + ortada `megaphone` 28 (t3), 8, "Yeni duyuru yok" **15/20 t2**, altinda "Yeni duyurular burada görünür" **12/16 t3** (en cok 220 genislik).

### Acil duyuru (urgent=true) — onizlemede yok, ayni duzende
Kirmizi YALNIZ burada: meta satirinin basina "Acil · " **11/14, tehlike rengi (#DC2626 acik / #EF4444 koyu)**; medium'da nokta da tehlike rengi; baslik tonu degismez. Medium/large'da acil duyuru her zaman en uste cikar. Small'da meta "Acil · SKS · 05 Kas" (kesilme: kaynak adi once kisalir).

### Android farklari
Yalniz olcu/yaricap (170/350 dp, 28 dp) ve medium satir yuksekligi 36. Material You dinamik renk KULLANILMAZ; sistem temasini izler. Glance'ta 1 dp kenarlik icin ic ice iki `Box` (dis kenar rengi 28 dp, ic arka plan 27 dp).

## Dokununca nereye gider
- Small ve widget govdesi/baslik: uygulamada **Duyurular/Haberler** (Ana Sayfa duyuru akisi, `/news`).
- Medium/large satiri: o duyurunun **detay ekrani** (`/news/{id}`).
- Small'da tek duyuru: `/news/{id}`. Bos durum: `/news`. Oturum gerekmez (genel akis); yine de oturum yoksa genel akis gosterilir.

## Ana ekran gorunumleri
`home-ios-*.png`: iPhone 393x852 pt (3x): ust 2 small yan yana (158 + 22 + 158), altinda medium, altinda large; `home-android-*.png`: 412x915 dp: 4x2, 2 adet 2x2 (170 + 10 + 170), 4x4; bosluk 14. Maket yalnizca sahnedir.
## Ortak tasarim belirtimi (iki widget icin gecerli)

Birim: iOS = pt, Android = dp; `render.html` 1 CSS px = 1 pt/dp alir, PNG'ler 3x piksel (ornek ios-medium = 1014x474 px). Yazi tipi **Inter** (yalniz Regular 400; buyuk gun rakami Light 300). **Kalin yazi yok**; hiyerarsi boyut + ton + bosluk ile. Satir araligi asagidaki "boyut/satir" cifti. Harf araligi -0.011em (tum metin); aylar/rozet ay etiketi +0.08em ve BUYUK HARF.

### Boyutlar ve kabuk
| Platform | Boyut | Olcu | Kose | Ic bosluk |
|---|---|---|---|---|
| iOS WidgetKit | systemSmall / Medium / Large | 158x158 / 338x158 / 338x354 pt | 22 pt | 16 pt (1 pt kenarlik + 15 pt) |
| Android Glance | 2x2 / 4x2 / 4x4 | 170x170 / 350x170 / 350x350 dp | 28 dp | 16 dp (1 + 15) |

Kabuk: tek duz arka plan (gradient/golge YOK; golge yalniz maket sahnesinde), **1 px ic kenarlik** (kenar rengi asagida), `overflow: hidden`. iOS 17+: `containerBackground(for: .widget)` ile ayni renk; widget'a dokunma `widgetURL`. Android: `GlanceModifier.background(color).cornerRadius(28.dp)`, `clickable(actionStartActivity)`.

### Renk belirtecleri (BuTokens monochrome ile uyumlu)
| Rol | Acik | Koyu |
|---|---|---|
| Arka plan | #FFFFFF | #18181B |
| Kenarlik / ayirici cizgi (1 px) | #E4E4E7 | #27272A |
| Birincil metin (t1) | #09090B | #FAFAFA |
| Ikincil metin (t2) | #52525B | #A1A1AA |
| Ucuncul metin (t3, sayac/yardimci) | #71717A | #71717A |
| Rozet dolgusu | #F4F4F5 | #09090B |
| Rozet kenari / pasif nokta | #D4D4D8 | #3F3F46 |
| Tehlike (yalniz acil) | #DC2626 | #EF4444 |

Marka rengi yok; kirmizi yalniz tehlike. Tema = sistem temasi (acik/koyu otomatik).

### Ikonlar ve logo
Lucide (cizgi), **1.5 px** vuruş, `round` uc/birlesim, `currentColor`. Boyut: baslik ikonu 14, meta ikonu 12 (kucuk/orta) veya 14 (buyuk), bos durum 20 (small) / 22 (medium) / 28 (large). Kullanilan: `calendar`, `clock`, `map-pin`, `megaphone`. Logo: `mobile/assets/branding/logo_dark.png` (beyaz glif, KOYU tema) / `logo_light.png` (siyah glif, ACIK tema), **yukseklik 14, genislik otomatik (~21)**, orta/buyuk basliginin solunda, logo-metin araligi 6. Kucuk boyutta logo yok (yer yok), yalniz baslik ikonu.

### Metin kesme (kural)
Tek satirlik alan: `maxLines=1`, kuyruk uc nokta (`…`/ellipsis). Cok satirlik: belirtilen satir sayisi, sonra kuyruk ucnokta. Metin kucultme/otomatik font olcekleme YOK. Sistem "daha buyuk yazi" ayarinda boyutlar sabit kalir, satir sayisi sinirlari gecerli (satir sigmazsa en alt satir dusurulur, ayirici cizgiler korunur).

### Genel kurallar
- KVKK: baska kullanicinin adi, fotografi, mesaj icerigi widget'ta ASLA gosterilmez. Yalnizca herkese acik kulup/etkinlik/duyuru verisi.
- Oturum yoksa: tek mesaj "Giris yapin" (bos durum ile ayni duzen, ikon + 13/17 t2) ve dokununca giris ekrani.
- Widget'lar uygulama icinde gercek ekran acar (asagida), her widget butun alani dokunulabilir.
- Veri yenileme: sistem zaman cizelgesi 30 dk'da bir + gece 00:05; uygulama on plana gelince `reloadAllTimelines` (iOS) / `GlanceAppWidget.updateAll` (Android).
- `render.html` ve `make_home_mockups.py` (stitch/ altinda) birebir referans uygulamadir: `?w=...&p=ios|android&s=small|medium|large&t=light|dark&e=0|1` (e=1 bos durum).
