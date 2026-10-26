# BÜ Kampüs — marka kılavuzu

Ürün adı **BÜ Kampüs** (büyük/küçük harf aynen; Arapçada da çevrilmez). Kurum olarak "Bingöl Üniversitesi" yalnızca alt satırda
(`BİNGÖL ÜNİVERSİTESİ`) ve kurumdan söz eden metinlerde geçer.

Tek kaynak: `source/logo.png` (1254x1254, referans logo; **piksellerine dokunulmaz**). Tüm çıktılar bundan türetilir:

```bash
cd brand && npm install && node build.js
```

Betik: kırmızı kareyi dış beyazdan ayırır (taşırmalı doldurma + kenarda alfa çözümü; beyaz halo yok, harflerin içi dolu kalır),
kareye ölçekler (kaynak 1034x1020 olduğundan ~%1 fark), yatay/dikey kilitleri, mono sürümleri, web/Android/iOS/store varlıklarını üretir.
Yazı yolları `source/wordmark.json` önbelleğindedir (Times New Roman Bold, eğri hâline çevrilmiş; yazı tipi dosyası repoda yok).
Yeniden üretmek için: `REGEN_WORDMARK=1 FONT_FILE=<kalın serif .ttf> node build.js`.

## Renkler

| Ad | Hex | Kullanım |
|---|---|---|
| Logo kırmızısı | `#F73A2E` (kaynaktan ölçüldü) | İkon kare, vurgu (`--red-600` / `--accent`), Android adaptive arka plan |
| Lacivert | `#10264A` | Açık zeminde yazı, store/og zemini |
| Koyu lacivert | `#0B1B36` | Zemin degradesi sonu |
| Alt satır (açık zemin) | `#53607A` | "BİNGÖL ÜNİVERSİTESİ" açık zeminde |
| Alt satır (koyu zemin) | `#B7C6E4` | aynı, koyu zeminde |
| Beyaz | `#FFFFFF` | Koyu zeminde yazı, harfler |

Beyaz metnin `#F73A2E` üstündeki kontrastı yaklaşık 3,8:1'dir (büyük/kalın metin için uygundur); küçük metni kırmızı zemine koymayın.

## Sürümler (`dist/`)

`mark` (kare ikon), `horizontal` (ikon solda), `vertical` (ikon üstte), her biri `-tagline` (altında BİNGÖL ÜNİVERSİTESİ) ile/siz.
**Varsayılan: alt satırsız** (küçük boyutta okunaklı). Alt satırlı sürüm büyük kullanımlar içindir (og, store, kapak).
Tonlar: `-light` (açık zemin, lacivert yazı), `-dark` (koyu zemin, beyaz yazı), `-white` / `-black` (tek renk; ikon harfleri oyuk).
`mark-white/black` = harfleri oyuk kare (bildirim ikonları), `mark-letters-*` = yalnız harfler. Hepsi PNG + SVG (SVG'ye raster gömülüdür).

## Kurallar

- **Koruma alanı:** ikon yüksekliğinin %25'i kadar boşluk (her yönde). İçine başka öğe girmez.
- **En küçük boyut:** ikon 16 px (favicon), yatay kilit 28 px yükseklik, dikey kilit 64 px yükseklik; alt satırlı sürüm en az 64 px yükseklik.
- **Yasaklar:** harfleri/şekli/rengi değiştirmek, döndürmek, gölge-parlama eklemek, ikonu gerdirmek, kırmızı karenin köşesini değiştirmek,
  yazıyı başka yazı tipiyle dizmek, kırmızı/benzer yoğun zeminde renkli sürümü kullanmak (tek renk sürüm kullanın), logoyu fotoğraf üstüne
  kontrast kontrolü yapmadan koymak, "BÜ Kampüs" adını başka yazım biçimiyle yazmak.
- Koyu zemin: `-dark` sürüm; açık zemin: `-light`. Web'de `Logo` bileşeni `tone="auto"` ile temaya göre seçer.

## Hangi dosya nerede

| Yer | Dosya |
|---|---|
| README üstü | `dist/horizontal-light.png` (GitHub'da `docs/brand/`) |
| Web üst çubuk / giriş / yan menü / alt bilgi | `web/src/assets/brand/*.svg` (üretilir; `web/src/components/brand/Logo.tsx`) |
| Web favicon, apple-touch, PWA, OG | `web/public/favicon.ico`, `favicon.svg`, `apple-touch-icon.png`, `icon-192.png`, `icon-512.png`, `icon-maskable-512.png`, `og.png`, `site.webmanifest` |
| Android başlatıcı, bildirim, açılış | `mobile/branding/android/res/` |
| Play Store | `mobile/branding/store/play-store-512.png`, `feature-graphic-1024x500.png` |
| iOS | `mobile/branding/ios/AppIcon.appiconset/` |
| Flutter içi | `mobile/assets/branding/` |
