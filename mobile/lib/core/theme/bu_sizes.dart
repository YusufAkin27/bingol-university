/// Temel öğe boyutları (dp). Düğme, alan, çip, FAB, simge düğmesi, alt gezinme ve liste satırı yükseklikleri TEK
/// yerde durur; ekranlarda `height: 54` gibi sihirli sayı yazılmaz (kaynak: docs/design/BOYUT_OLCUMU.md).
///
/// Ölçüt: Stitch referanslarında (390 dp çerçeve) birincil düğme 48, alan 44-48, yuvarlak düğme 40-44, çip 32-36,
/// alt gezinme 64, başlık çubuğu 56 dp'dir; gerçek telefonda (Redmi 13C ≈ 360 dp) aynı mutlak dp kullanılır.
/// Görünür kutu küçük olabilir; DOKUNMA ALANI her zaman en az [touch] (48) dp kalır.
abstract final class BuSize {
  /// Dokunma hedefi alt sınırı (Material / WCAG 2.5.8): görünür kutu küçük olsa da hit alanı bu kadar.
  static const double touch = 48;

  /// Tam genişlik birincil/ikincil düğme yüksekliği.
  static const double button = 48;

  /// Satır içi (hap) düğme görünür yüksekliği; dokunma alanı [touch].
  static const double buttonCompact = 34;

  /// Metin giriş alanı / seçim kutusu / arama kutusu yüksekliği.
  static const double field = 52;

  /// Arama kutusu (içindeki temizle düğmesi 48 dp dokunma alanını bozmasın diye 48).
  static const double search = 48;

  /// Filtre çipi görünür yüksekliği; dokunma alanı [touch].
  static const double chip = 34;

  /// FAB / "+" yuvarlak eylem düğmesi.
  static const double fab = 48;

  /// Başlık çubuğundaki yuvarlak simge düğmesinin görünür çapı; dokunma alanı [touch].
  static const double iconBtn = 40;

  /// Alt gezinme hapı içerik yüksekliği (yazı ölçeği 1).
  static const double nav = 64;

  /// Alt gezinme hapı dış boşluğu (kenar ve alt).
  static const double navGap = 16;

  /// Kaydırılabilir gövdenin altına bırakılacak pay: hap + alt boşluk + üst nefes.
  static const double navInset = nav + 2 * navGap;

  /// Liste satırı alt sınırı.
  static const double row = 56;

  /// Başlık çubuğu (AppBar) yüksekliği.
  static const double appBar = 56;

  /// Segment kontrolü (iki-üç seçenek) dış yüksekliği.
  static const double segmented = 44;

  /// Sayfa yan boşluğu ile kart iç boşluğu (BuSpace ile aynı).
  static const double cardPad = 16;
}
