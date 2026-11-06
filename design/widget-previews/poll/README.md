# Gunun Anketi (poll) widget tasarim notlari

Bu belge kodlayacak ajanlarin tek referansidir. Gorseller bu klasorde.

## Veri alanlari
`question` (string), `options[]` (`label`, `percent` 0-100 tamsayi), `totalVotes` (int, binlik ayirac nokta), `userVoted` (bool), `pollId`. Kimlik/oy veren asla yok (gizli oy). Yuzde yazimi `%54`. Toplam yuzde 100'e yuvarlanir.

## Dokununca
Tum widget: `bukampus://poll/{pollId}` (anket ekrani); anket yoksa `bukampus://home`.

## Boyuta gore duzen
**Small (iOS 158 / Android 2x2)**: ust satir caption "ANKET" (vote ikonu) solda, logo sagda (satir 16, alt bosluk 12). Soru 15/20, en cok 3 satir, sonra ellipsis. Alt sol: ters renk pill "Oy ver" (yukseklik 28, yatay ic bosluk 14, tam yuvarlak, metin 13/16). Baska hicbir sey yok. Kullanici oy verdiyse pill yerine "Oy verildi" (13/18 ikincil).
**Medium (iOS 338x158 / Android 4x2 350x170)**: baslik satiri (caption "GUNUN ANKETI", alt bosluk 8). Iki sutun, aralarinda 16: sol %40 sabit: soru 15/20 en cok 3 satir; sol alt mikro 11/14 ucuncul "1.284 oy - gizli". Sag sutun: 3 secenek dikey esit dagilmis (space-between); her biri etiket 12/16 (ellipsis) + sagda yuzde 12/16, altinda 4px yuksek cubuk (yaricap 2), 4 bosluk. Lider secenek tam renk + yuzde birincil; digerleri %45 opaklik, yuzde ikincil. Oy verilmediyse sag sutunda yalniz etiketler + "Oy ver" pill (yuzde yok).
**Large (iOS 338x354 / Android 4x4 350x350)**: baslik satiri (alt bosluk 12) -> soru 17/22 en cok 2 satir (alt bosluk 16) -> 4 secenek, aralari 14: etiket 13/18 + sagda yuzde 13/18, 6 bosluk, 4px cubuk -> esnek bosluk -> alt satir: solda lock ikonu 12 + 12/16 ikincil "Oylar gizlidir - 1.284 oy", sagda "Ayrinti" 12/16 birincil + chevron 12. 2-4 secenek desteklenir.
**Bos durum** (`*-empty-*`): small: caption "ANKET", display 22/26 "Bugun anket yok" (en cok 2 satir), altinda 12/16 ucuncul "Yenisi yayimlaninca". Medium/large: caption "GUNUN ANKETI", display "Bugun anket yok", govde 13/18 ikincil "Yeni anket yayimlaninca burada gorunur"; dikey ortali.

## Gercek icerik
Soru "Yemekhanede aksam menusu nasil?"; Cok iyi %54 (large %48), Idare eder %31 (%29), Kotu %15, Fikrim yok %8 (yalniz large); 1.284 oy.

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
