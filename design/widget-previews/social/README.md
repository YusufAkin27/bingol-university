# Sosyal Bildirim Ozeti (social) widget tasarim notlari

Bu belge kodlayacak ajanlarin tek referansidir. Gorseller bu klasorde.

## Veri alanlari (YALNIZ sayilar, KVKK)
`unreadMessages`, `newNotifications`, `newLikesAndFollowers` (int). Kisi adi, mesaj icerigi, fotograf, avatar HICBIR boyutta gosterilmez. 99'dan buyuk sayi "99+". Hepsi 0 ise bos durum.

## Dokununca
Mesaj -> `bukampus://chat`, bildirim -> `bukampus://notifications`, begeni/takipci -> `bukampus://discover`. Medium/large'ta sutun/satir basina ayri hedef. Small'da tum widget `bukampus://chat` (mesaj 0 ise sifir olmayan ilk hedef). Baslik: `bukampus://home`.

## Boyuta gore duzen
**Small (iOS 158 / Android 2x2)**: caption "MESAJ" (message-square ikonu), logo sagda. Sayi (okunmamis mesaj) 34/38 birincil; altinda 12/16 ikincil "okunmamis mesaj"; esnek bosluk; alt satir: bell ikonu 12 + sayi 12/16 ikincil, 12 aralik, **kirmizi** heart ikonu 12 (#DC2626 / #F2555A) + sayi 12/16 ikincil.
**Medium (iOS 338x158 / Android 4x2 350x170)**: baslik caption "SOSYAL OZET" (message-circle ikonu), logo sagda (alt bosluk 12). 3 esit sutun, aralarinda 1px bolucu (kenarlik rengi), 12 aralik: ustte ikon 18 (mesaj/bildirim ikincil, kalp kirmizi), 6 bosluk, sayi 34/38, altinda etiket 12/16 ikincil ("Mesaj", "Bildirim", "Begeni").
**Large (iOS 338x354 / Android 4x4 350x350)**: baslik satiri, baslik "Bugun yeni olanlar" 17/22, alt metin "Yalnizca sayilar gosterilir" 12/16 ucuncul (alt bosluk 14). 3 satir, aralari 8; her satir yukseklik 64, chip zemini, yaricap 14, yatay ic bosluk 14, ogeler arasi 12: ikon 22 (kalp kirmizi), orta iki satir: etiket 13/18 birincil ("Okunmamis mesaj", "Yeni bildirim", "Yeni begeni ve takipci") + mikro 11/14 ucuncul ("Sohbetler", "Bildirim kutusu", "Kesfet"), sagda sayi 28/32.
**Bos durum / hepsi 0** (`*-empty-*`): small: caption "SOSYAL", circle-check ikonu 20 + display 22/26 "Her sey guncel". Medium/large: caption "SOSYAL OZET", ikon 22, display "Her sey guncel", govde 13/18 ikincil "Yeni mesaj, bildirim ya da begeni yok"; dikey ortali; kirmizi yok.

## Ortak sistem (3 widget icin ayni)

Kaynak notu: Stitch (stitch.withgoogle.com) hesabi acikti ancak paylasimli Playwright tarayicisi diger operatorlerle ayni sekmeyi kullandigindan istem baska operatorun istemiyle ezildi; bu yuzden **Stitch kullanilamadi**. Tasarim HTML/CSS (Inter) + Playwright ile yedek yoldan uretildi (`_gen/gen_ops3.js`). Kaynak HTML: `stitch/html/*.html`; istemler: `stitch/prompts.md`; belirtec ozeti: `stitch/DESIGN.md`. Ana ekran maketleri: `_gen/home_ops3.py` (Pillow, duvar kagidi + durum cubugu + widget).

Dosyalar: `ios-{small,medium,large}-{light,dark}.png`, `android-{2x2,4x2,4x4}-{light,dark}.png` (3x piksel), `*-empty-*` bos durum (varsa), `home-{ios,android}-{light,dark}.png`.

### Boyutlar
| Platform | Boyut | Olcu | Kose | Ic bosluk | Kenarlik |
|---|---|---|---|---|---|
| iOS | small | 158x158 pt | 22 pt | 16 pt | 1 pt |
| iOS | medium | 338x158 pt | 22 pt | 16 pt | 1 pt |
| iOS | large | 338x354 pt | 22 pt | 16 pt | 1 pt |
| Android | 2x2 | 170x170 dp | 28 dp | 16 dp | 1 dp |
| Android | 4x2 | 350x170 dp | 28 dp | 16 dp | 1 dp |
| Android | 4x4 | 350x350 dp | 28 dp | 16 dp | 1 dp |

Android'de metin sp = dp. Android 4x2/4x4 ayni duzeni iOS medium/large ile paylasir; yalniz olcu degisir, icerik genislikle esner. iOS'ta arka plan `containerBackground` (tek duz renk, gradient/golge yok); kenarlik widget cizimine eklenir.

### Renkler
| Belirtec | Acik | Koyu | Kullanim |
|---|---|---|---|
| zemin iOS | #FFFFFF | #111113 | widget arka plani |
| zemin Android | #FFFFFF | #18181B | widget arka plani |
| yuzey chip | #F4F4F5 | #1F1F23 (iOS) / #232327 (Android) | karo/satir zemini |
| kenarlik | #E4E4E7 | #27272A | 1px dis cizgi, bolucu |
| birincil yazi | #09090B | #FAFAFA | ana metin, ikon |
| ikincil yazi | #52525B | #A1A1AA | alt metin |
| ucuncul / caption | #71717A | #71717A | etiket, ipucu |
| bar dolgu | #09090B | #FAFAFA | anket cubugu (lider tam, digerleri %45 opaklik) |
| bar izi | #E4E4E7 | #27272A (iOS) / #2E2E33 (Android) | cubuk zemini |
| ters pill | zemin #09090B, yazi #FFFFFF | zemin #FAFAFA, yazi #09090B | "Oy ver" |
| kirmizi | #DC2626 | #F2555A | YALNIZ begeni kalbi |

Marka rengi yok. Logo: `mobile/assets/branding/logo_light.png` (acik tema) / `logo_dark.png` (koyu tema); yukseklik 12, sag ust, opaklik 0.9, baslik satirinda (satir yuksekligi 16).

### Tipografi (tek yazi tipi Inter, agirlik HEP 400)
| Rol | boyut/satir | letter-spacing | not |
|---|---|---|---|
| caption (ust etiket) | 10 / 12 | +0.08em, BUYUK HARF | ucuncul renk; solunda 12 px ikon, 4 bosluk |
| mikro | 11 / 14 | 0 | karo etiketi, ipucu (taban 11) |
| kucuk | 12 / 16 | 0 | yuzde, alt bilgi |
| govde | 13 / 18 | 0 | satir metni |
| soru | 15 / 20 | -0.01em | small/medium anket sorusu |
| baslik | 17 / 22 | -0.01em | large baslik/soru |
| display | 22 / 26 | -0.02em | bos durum |
| sayi | 34 / 38 (small, medium), 28 / 32 (large satir) | -0.03em | sosyal sayilar |

### Ikonlar
Lucide benzeri cizgi ikon, 24x24 viewBox, stroke 1.5, round cap/join, renk currentColor. Boyutlar: baslik 12 px, large satir 22 px, karo 18 (medium) / 22 (small) / 24 (large), satir ici kucuk 12 px. Lucide adlari: vote, utensils, calendar-clock, ticket, users, message-circle, qr-code, newspaper, search, bell, heart, lock, chevron-right, message-square, circle-check (mobilde `BuIcons` esdegeri).

### Genel kurallar
Metinler tek satir `ellipsis` (aksi yazilmadikca). Ic bosluk 16, bolumler arasi 8-16. Tum widget tiklanir (derin baglanti asagida). Ekran okuyucu: widget tek oge, ozet cumle. Guncelleme: veri degisince + 30 dk. Oturum yoksa: display 22/26 "Giris yap" + mikro "BU Kampus'u ac", dokununca giris ekrani. Duvar kagidi/telefon cercevesi yalnizca maket icindir, uygulamaya girmez.
