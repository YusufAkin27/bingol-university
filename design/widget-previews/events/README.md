# Widget: Yaklasan Etkinlikler (slug: events)

Premium Monochrome (siyah-beyaz, marka rengi yok, Inter 400, 1 px kenarlik). Tasarim hatti: **Stitch** ("BU Widget - events" projesi, ham cikti `stitch/screen.png`, `stitch/code.html`); Stitch tek karanlik iOS panosu uretti, diger boyut/tema/Android varyantlari ayni dille `stitch/render.html` ile turetildi (Stitch'in 10-11 px yazilari gercek widget icin kucuk bulundu; asagidaki degerler buyutulmus nihai olculerdir).

Dosyalar: `ios-{small,medium,large}-{light,dark}.png`, `android-{2x2,4x2,4x4}-{light,dark}.png` (3x piksel, seffaf kose), `home-{ios,android}-{light,dark}.png` (ana ekran maketi), `empty/` (ayni 12 adet bos durum), `stitch/`.

## Icerik ve veri
Ne gosterir: siradaki 1-3 etkinlik, **baslangic zamanina gore artan**, yalniz gelecek/devam eden (`startsAt >= now - 1 sa`), yalniz `ACTIVE` ve herkese acik kulup etkinlikleri.
Alanlar: `id`, `title`, `communityName` (kulup adi), `startsAt` (Europe/Istanbul), `venue` (mekan/bulusma noktasi, bos olabilir).
Bicim: gun = sifirsiz sayi (`5`, `12`); ay = Turkce 3 harf BUYUK: OCA ŞUB MAR NİS MAY HAZ TEM AĞU EYL EKİ KAS ARA; saat = `HH:mm` 24 saat. `venue` bos ise mekan ogesi (pin ikon + metin) tamamen gizlenir.

| Boyut | Etkinlik sayisi | Icerik |
|---|---|---|
| iOS small / Android 2x2 | 1 | baslik ikonu, buyuk gun+ay, baslik (2 satir), saat |
| iOS medium / Android 4x2 | en cok 3 | baslik (logo+ad), satir: rozet + baslik + kulup + saat |
| iOS large / Android 4x4 | en cok 3 | baslik + sayac, satir: buyuk rozet + baslik + kulup + saat + mekan |

## Boyut bazli duzen (ic alan = ic bosluk 16 dusulmus; tum degerler pt/dp)

### Small (158x158 / 170x170)
Dikey yigin, ust-hizali ust, alt-hizali alt:
1. Ust satir: `calendar` ikonu 14 + 6 bosluk + "Yaklaşan" **11/14, 400, t2**.
2. 10 bosluk, sonra gun rakami **34/36, 300 (Light), t1** ile ayni taban cizgisinde ay **12/16, 400, t2, +0.08em, BUYUK**, aralarinda 6.
3. Esnek bosluk (`flex 1`).
4. Baslik **14/18, 400, t1, en cok 2 satir** + ucnokta.
5. 6 bosluk; `clock` 12 + 4 + saat **11/14, 400, t2**. (Kulup ve mekan small'da YOK.)
Bos durum: ust satir ("Etkinlik" 11/14 t2) + ortada `calendar` 20 (t3) + 8 + "Yaklaşan etkinlik yok" **13/17 t2**, ortalanmis.

### Medium (338x158 / 350x170)
1. Baslik satiri (yukseklik 14): logo (h14) + 6 + "Yaklaşan Etkinlikler" **11/14 t2**. Sag tarafta sayac yok.
2. 10 bosluk. Satir alani kalan yukseklik; 3 satir `space-between` (satirlar arasi bosluk iOS ~3-4, Android ~3).
3. **Satir**: yukseklik iOS **30** / Android **36**; soldan saga: rozet (kare, kenar = satir yuksekligi, yaricap **8**, 1 px kenar `Rozet kenari`, dolgu `Rozet dolgusu`) icinde gun **13/13 t1** + 1 bosluk + ay **9/10 t2 +0.08em BUYUK**; 10 bosluk; orta sutun (`flex 1`): baslik **13/17 t1 1 satir ucnokta**, altinda kulup adi **11/14 t2 1 satir ucnokta**; sagda `clock` 12 + 4 + saat **12/14 t2** (kesilmez, sabit genislik).
4. Etkinlik < 3 ise bos satirlar bos birakilir (satirlar ustten dizilir, `space-between` yerine ust-hizali `gap 6`).
Bos durum: baslik satiri + ortada `calendar` 22 (t3), 8, "Yaklaşan etkinlik yok" **13/17 t2**, altinda "Kulüpler yeni etkinlik eklediğinde burada görünür" **11/14 t3** (en cok 1 satir, ucnokta).

### Large (338x354 / 350x350)
1. Baslik satiri: logo + 6 + "Yaklaşan Etkinlikler" **11/14 t2**; sag: "{n} etkinlik" **11/14 t3** (n = gosterilen sayi).
2. Ayirici: 1 px, ust 12 / alt 4 bosluk.
3. Satir alani `flex 1`, 3 satir esit yukseklik, aralarinda 1 px ayirici (ayirici kenarlari ic alan genisliginde, rozet altina girmez); satir icerigi dikey ortali.
4. **Satir**: rozet **44x48**, yaricap **10**, gun **18/20 t1**, ay **10/12 t2 +0.08em BUYUK** (ust bosluk 2); 12 bosluk; metin sutunu: baslik **15/20 t1 1 satir ucnokta**; kulup **12/16 t2 1 satir** (ust 1); meta satiri (ust 4, ogeler arasi 12): `clock` 14 + 4 + saat **12/16 t2**, `map-pin` 14 + 4 + mekan **12/16 t2 1 satir ucnokta** (mekan esnek, saat sabit).
Bos durum: baslik satiri + ortada `calendar` 28 (t3), 8, "Yaklaşan etkinlik yok" **15/20 t2**, altinda aciklama **12/16 t3**, en cok 220 genislik, ortali, en cok 2 satir.

### Android farklari
Yalniz olcu/yaricap (170/350 dp, 28 dp) ve medium'da satir yuksekligi 36; tipografi sp = dp (sistem yazi olcegi uygulanirsa 1.0 ustu sabitlenmez). Material You dinamik renk KULLANILMAZ (monochrome belirtec sabit); acik/koyu sistem temasini izler. Glance'ta kenarlik icin ic ice iki `Box` (dis: kenar rengi + 28 dp, ic: arka plan + 27 dp, 1 dp inset) kullanilir.

## Dokununca nereye gider
- Small ve widget govdesi (baslik/bos alan): uygulamada **Etkinlikler** sekmesi (`/events`).
- Medium/large satiri: o etkinligin **detay ekrani** (`/events/{id}`; derin baglanti semasi uygulama tarafinda `targetType=EVENT`, `targetId=id` ile ayni push yonlendiricisini kullanir).
- Small'da tek etkinlik oldugu icin tum widget `/events/{id}`.
- Bos durum: `/events`. Oturum yoksa giris ekrani.

## Ana ekran gorunumleri
`home-ios-*.png`: iPhone 393x852 pt cerceve (3x), ust: 2 small yan yana (158 + 22 bosluk + 158), altinda medium, altinda large; kenar bosluklari (393-338)/2. `home-android-*.png`: 412x915 dp; 4x2, altinda 2 adet 2x2 (170 + 10 + 170), altinda 4x4; widget'lar arasi bosluk 14. Gercek cihazda duvar kagidi/izgara kullanicinindir; maket yalnizca sahne.
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
