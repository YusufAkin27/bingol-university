# STITCH V3 - FEED grubu (ozet)

Tam sartname (repo disi): `C:\bu_design\stitch\v3_feed\SARTNAME.md`; PNG'ler `C:\bu_design\stitch\v3_feed\<kategori>\`. Stitch projesi: "BU Kampus Feed Screens" (15105009382860365130).

## Durum
| Kategori | Durum | Hedef Flutter ajani |
|---|---|---|
| 1 Kesfet (kart yonu secimi + akis + durumlar) | TAMAM, teslim edildi | FEED |
| 2 Yeni gonderi akisi | TAMAM, teslim edildi | FEED |
| 3 Gonderi detayi + tam ekran foto | TAMAM, teslim edildi | FEED |
| 4 Profil ve alt sayfalar | TAMAM, teslim edildi | PROFILE |
| 5 Ayarlar / Gizlilik / Hesap / Verilerim / Hesap sil / Engellenenler | TAMAM, teslim edildi (Hakkinda, Dil sheet, Sohbet arka plani, sifre onay, sikayet sheet: Stitch uretemedi, SARTNAME metinsel spec) | PROFILE |

## Kesfet karar notu
Uc yon denendi: A tek sutun buyuk 4:5 gorsel (bilgi gorsel ustunde, alt %28 gradyan), B iki sutun masonry, C hibrit. **A secildi**: tek odak, en az oge, kontrast gradyanla garanti, mevcut PostCard/LikeButton/cift dokunus korunur. B (gorsel ustunde ad yazisi okunurlugu bozar, 7 kelimelik metin yer bulamaz) ve C (iki kart dili) reddedildi. Olculer: kenar 20 dp, gonderiler arasi 24 dp, kose 24 dp, kalp hapi 44 dp (#171E33 %50), gonderi metni gorsel altinda tek satir 15 sp.

## Yeni gonderi karar notu
Sade akis: bos 4:5 alan + tek birincil "Fotoğraf seç" + "Kamera"; kaynak alt sayfasi iki satir; kirpma yalniz cerceve + Vazgec/Bitti; onizleme 4:5 + TEK satir metin alani ve sessiz sayac (yalniz sinirda vurgu); ust cubuk x / baslik / kucuk "Paylaş" hapi; paylasiliyor/basari (SnackBar)/hata ve uyarilar ayni ekranda. Konum/etiket/kitle yok.

## Yontem notu (sonraki ajanlar icin)
Stitch'in kendi PNG'si (screen.png) eski/soguk renkli ve bazen bayat; **code.html + `_render/render.py`** ile bizim RENK-1 tokenlariyla Chrome headless'ta 2x yeniden render edilir (iframe 390 dp). Koyu tema Stitch'te guvenilir uretilmez; ayni HTML'e koyu token paleti verilerek uretilir (hardcoded renkli HTML'lerde calismaz, o zaman token tablosundan uygulanir). Disa aktarma: proje sayfasi `app-companion` iframe'inde `.react-flow__node-node-screen` baslik etiketine Shift+tikla, Export > .zip (en cok 16 ekran).
