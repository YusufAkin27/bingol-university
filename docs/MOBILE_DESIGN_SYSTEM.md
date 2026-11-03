# Mobil tasarım sistemi: premium renk ve hareket

Hedef: sakin, premium, göz yormayan, tanıdık bir Android sosyal uygulama deneyimi (Material Design 3, soft nötr yüzeyler, ölçülü marka vurgusu, doğal hareket). Gösterişli değil, kaliteli görünür. Light mod birincil, koyu mod sistem tercihine göre.

Tek kaynak: `mobile/lib/core/theme.dart` (`BuTokens`, `context.bu`), hareket için `mobile/lib/core/theme/bu_motion.dart` (`AppMotion`). Ekranlar yalnız bu belirteçleri kullanır; ham `Color(0x..)` ve `Colors.*` yazılmaz (`renk_paleti_test`).

## 1. Renk belirteçleri

| Rol | Açık | Koyu | `BuTokens` alanı |
|---|---|---|---|
| appBackground | #F8F9FA | #101114 | `bg` |
| surface / surfaceElevated | #FFFFFF | #191B20 | `sf` (`sf3` en üst yüzey) |
| surfaceSecondary | #F1F3F5 | #24262D | `sf2` |
| textPrimary | #18181B | #F4F4F5 | `ink` |
| textSecondary | #71717A | #A1A1AA | `mut` |
| textTertiary | #A1A1AA | #71717A | `mutSoft` (yalnız dekoratif/büyük metin) |
| textOnPrimary | #FFFFFF | #2B0A07 | `onPr` |
| borderDefault | #E4E4E7 | #33363D | `bd` |
| borderSubtle | #F1F1F3 | #24262D | `bdSubtle` |
| primary | #DC4C46 | #F0726C | `pr` |
| primaryPressed | #B93833 | #F58A84 | `prPressed` |
| primarySoft | #FCECEB | #3B2223 | `soft` |
| primaryOnSoft | #922D29 | #FFBBB2 | `onSoft` |
| success / warning / error / info | #218563 / #B7791F / #D63C3C / #3973C6 | pastel karşılıkları | `ok` / `warn` / `danger` / `info` |

`bdStrong` yalnız kontrol çerçevesidir (giriş alanı, seçim halkası; zemine karşı >= 3:1).

## 2. Renk kullanım kuralları

- Ekranın büyük bölümü nötr: açık gri zemin, çoğunlukla beyaz kartlar, normal içerik kartlarında ince kenarlık.
- Marka kırmızısı yalnız anlamlı küçük vurgularda: aktif ikon/gösterge, birincil eylem, küçük karo. Büyük kırmızı alan yok.
- Metin saf siyah değil (`ink`); ikincil metin `mut`; pasif ikon `mut`, aktif ikon `pr`.
- Her kartı farklı renge boyamak, neon renk, gereksiz gradyan ve güçlü gölge yok.
- **Kontrast:** beyaz küçük yazı `pr` zeminde AA vermez (4.07:1). Küçük beyaz yazılı dolu düğme `prPressed` zemin kullanır (5.7:1); marka renginde küçük metin/bağlantı `prPressed`. `pr` metin olarak yalnız büyük/kalın başlıkta. Yumuşak zemin üstünde yazı `onSoft`.
- Koyu mod renklerin tersi değil, aynı hiyerarşidir.

## 3. Hareket belirteçleri (`AppMotion`)

| Ad | Süre | Kullanım |
|---|---|---|
| `instant` | 80 ms | anlık geri bildirim |
| `fast` | 140 ms | düğme basma, çip, simge durumu |
| `normal` | 220 ms | bileşen geçişi, sekme, genişleme |
| `emphasized` | 300 ms | vurgulu geçiş |
| `sheet` | 340 ms | alt sayfa |

Eğriler: `standard` easeInOutCubic, `enter` easeOutCubic, `exit` easeInCubic, `interactive` easeOutQuart. Değerleri bileşenin davranışına göre seçin; "animasyonları azalt" açıkken `AppMotion.of(context, …)` sıfır döner. Eski `BuMotion` geriye uyum için durur; yeni kodda `AppMotion`.

## 4. Davranış kuralları

- **Alt gezinme:** seçili ikon rengi yumuşak değişir, uygun yerde dolu varyanta geçer, hafif ölçek (180-220 ms); sekme değişimi sayfayı yeniden başlatmaz, scroll konumu korunur. Ortadaki paylaşım düğmesi basınca çok hafif küçülür, sonra alt sayfa açılır; dönme/zıplama yok.
- **Akış:** beğeni 1.0 → 1.15 → 1.0 (180-240 ms), sürekli bounce yok; kaydet yalnız dolgu/renk geçişi; liste her kaydırmada yeniden fade-in yapmaz.
- **Alt sayfa/diyalog:** alttan kontrollü yükselir, üst köşeler yuvarlak, arka plan hafif kararır, uygun yerde kaydırıp kapatma, klavyede içerik erişilebilir. Diyalog yerel Material davranışında.
- **Yükleme:** ana içerikte iskelet (düşük kontrast, yavaş shimmer, gerçek geometriye uygun); görsel yüklenince kısa crossfade; küçük işlemde düğme yükleniyor durumu, tekrarlanmaz.
- **Kaydırma:** Android doğal kaydırması; scroll ile boyut değiştiren header yok; alt gezinme görünürlüğü rastgele değişmez; iç içe kaydırma doğru yönetilir.
- **Sayfa geçişi:** Android Material geçişleri + tahmini geri; alt sekmelerde tam ekran kayma yok; hero yalnız görsel süreklilik için.
- **Mikro etkileşim:** düğme basma, simge durumu, beğeni, kaydet, takip, sekme, arama odağı, filtre çipi, aç/kapa, alt sayfa. Her biri net geri bildirim verir; gereksiz mikro animasyon eklenmez.

## 5. Performans ve erişilebilirlik

- 60 FPS hedefi, 90/120 Hz'de doğal akıcılık; büyük listelerde pahalı animasyon yok; `RepaintBoundary` yalnız gerekli yerde; `AnimationController` dispose edilir; gereksiz `setState`/rebuild azaltılır. Ölçüm (profil) yapmadan performans iyileştirdiğini iddia etmeyin.
- Azaltılmış hareket tercihine saygı; anlam yalnız animasyonla iletilmez; AA kontrast; büyük yazı tipinde yerleşim bozulmaz; animasyon kullanıcı işlemini engellemez.

## 6. Uygulama durumu

- Yapıldı: renk belirteçleri (`theme.dart`, açık + koyu), `AppMotion`, dolu düğme ve metin bağlantısı kontrastı, **Karşılama** ve **Giriş** ekranları.
- Sırada (ekran ekran, kullanıcı onayıyla): kayıt/doğrulama/şifre sıfırlama, alt gezinme animasyonu, Ana Sayfa, akış kartları, iskelet görünümleri, diğer ekranlardaki eski `t.pr` metin kullanımlarının `prPressed`/`onSoft`'a taşınması.
- Mevcut işlev, API bağlantısı, gezinme ve veri modelleri korunur.
