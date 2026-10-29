import 'package:flutter/material.dart';

import 'locale_controller.dart';
import 'theme/bu_theme_builder.dart';
import 'typography.dart';

/// Marka renkleri: web/src/styles/tokens.css ile aynı değerler (Kampüs Kırmızısı + lacivert mürekkep).
class BuColors {
  BuColors._();

  static const ink = Color(0xFF171E33);
  static const red600 = Color(0xFFF73A2E); // logo kırmızısı: büyük yüzeyler, hero
  static const red700 = Color(0xFFC62A20); // eylem kırmızısı: düğme/bağlantı
  static const red800 = Color(0xFF8E1B13);
  static const red100 = Color(0xFFFDE7E4);
}

/// Kategori/etiket renk çifti: yumuşak zemin + üstündeki yazı/simge (AA kontrast).
@immutable
class BuTint {
  const BuTint(this.bg, this.fg);

  final Color bg;
  final Color fg;

  static BuTint lerp(BuTint a, BuTint b, double t) => BuTint(Color.lerp(a.bg, b.bg, t)!, Color.lerp(a.fg, b.fg, t)!);
}

/// Tasarım belirteçleri (mobile/design/*.dc.html içindeki CSS değişkenleriyle birebir).
/// Kullanım: `final t = context.bu;` sonra `t.pr`, `t.sf`, `t.mut`...
///
/// Mevcut alanlar KİLİTLİ; P0 ile eklenen alanlar isteğe bağlıdır: `sf3`, `warn`, `warnSoft`, `onWarnSoft`,
/// `onMedia`, `scrim`, `qrInk`, `qrPaper`, `shadow`, `tints`.
@immutable
class BuTokens extends ThemeExtension<BuTokens> {
  const BuTokens({
    required this.bg,
    required this.sf,
    required this.sf2,
    required this.ink,
    required this.mut,
    required this.bd,
    required this.pr,
    required this.onPr,
    required this.soft,
    required this.onSoft,
    required this.nav,
    required this.onNav,
    required this.h1,
    required this.h2,
    required this.ok,
    required this.okSoft,
    required this.danger,
    this.sf3 = const Color(0xFFFFFFFF),
    this.warn = const Color(0xFF9A5700),
    this.warnSoft = const Color(0xFFFFF1D6),
    this.onWarnSoft = const Color(0xFF6B3E00),
    this.onMedia = const Color(0xFFFFFFFF),
    this.scrim = const Color(0xFF000000),
    this.qrInk = const Color(0xFF000000),
    this.qrPaper = const Color(0xFFFFFFFF),
    this.shadow = const Color(0xFF171E33),
    this.tints = _tintsLight,
  });

  final Color bg; // sayfa zemini
  final Color sf; // kart/yüzey
  final Color sf2; // ikincil yüzey (segment, görsel yer tutucu)
  final Color ink; // ana yazı
  final Color mut; // soluk yazı
  final Color bd; // çizgi
  final Color pr; // eylem kırmızısı
  final Color onPr; // pr üstündeki yazı
  final Color soft; // pr'nin yumuşak zemini
  final Color onSoft; // soft üstündeki yazı
  final Color nav; // yüzen gezinme zemini
  final Color onNav;
  final Color h1; // hero gradyan başı
  final Color h2; // hero gradyan sonu
  final Color ok;
  final Color okSoft;
  final Color danger;

  /// En üst yüzey: diyalog, alt sayfa, menü, gezinme çubuğu zemini.
  final Color sf3;

  /// Uyarı (sarı/turuncu) metin/simge rengi; zemini [warnSoft], üstündeki yazı [onWarnSoft].
  final Color warn;
  final Color warnSoft;
  final Color onWarnSoft;

  /// Medya (fotoğraf/video/kamera) üstündeki yazı/simge rengi: her temada açık.
  final Color onMedia;

  /// Medya zemini ve fotoğraf üstü karartma (alfa ile kullanın): her temada koyu.
  final Color scrim;

  /// QR kodun mürekkep ve kâğıt rengi: her temada yüksek kontrast (siyah/beyaz).
  final Color qrInk;
  final Color qrPaper;

  /// Gölge rengi.
  final Color shadow;

  /// Kategori renkleri (kulüp/ders/haber türü): 6 çift. [tint] ile `id` bazlı döngüsel seçilir.
  final List<BuTint> tints;

  LinearGradient get hero => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [h1, h2],
      );

  /// [tints] içinden döngüsel seçim (`tint(club.id)`).
  BuTint tint(int i) => tints[i.abs() % tints.length];

  static const _tintsLight = <BuTint>[
    BuTint(Color(0xFFFDE7E4), Color(0xFF8E1B13)), // kırmızı (marka)
    BuTint(Color(0xFFE3EDFB), Color(0xFF1B4E96)), // mavi
    BuTint(Color(0xFFDFF3E8), Color(0xFF1B6B43)), // yeşil
    BuTint(Color(0xFFFDEFD2), Color(0xFF7A4A00)), // kehribar
    BuTint(Color(0xFFEDE6FA), Color(0xFF55359A)), // mor
    BuTint(Color(0xFFD9F1F1), Color(0xFF115E5E)), // turkuaz
  ];

  static const _tintsDark = <BuTint>[
    BuTint(Color(0xFF3A1F22), Color(0xFFFFB4AC)),
    BuTint(Color(0xFF1B2A44), Color(0xFF9CC2FF)),
    BuTint(Color(0xFF12301F), Color(0xFF7BE0A8)),
    BuTint(Color(0xFF3A2A0C), Color(0xFFF5C46B)),
    BuTint(Color(0xFF2B2347), Color(0xFFC4B0FF)),
    BuTint(Color(0xFF0F3333), Color(0xFF7DD9D9)),
  ];

  static const light = BuTokens(
    bg: Color(0xFFFAF6F3),
    sf: Color(0xFFFFFFFF),
    sf2: Color(0xFFF3ECE7),
    ink: Color(0xFF171E33),
    mut: Color(0xFF5F6577),
    bd: Color(0xFFE8DFD8),
    pr: Color(0xFFC62A20),
    onPr: Color(0xFFFFFFFF),
    soft: Color(0xFFFDE7E4),
    onSoft: Color(0xFF8E1B13),
    nav: Color(0xFF171E33),
    onNav: Color(0xFFFFFFFF),
    h1: Color(0xFFDC3125), // beyaz yazı AA (4.5:1): önceki F73A2E ~3.8:1 idi
    h2: Color(0xFFC62A20),
    ok: Color(0xFF1B7A4B),
    okSoft: Color(0xFFDFF3E8),
    danger: Color(0xFFB3261E),
  );

  static const dark = BuTokens(
    bg: Color(0xFF14161F),
    sf: Color(0xFF1D2030),
    sf2: Color(0xFF24283A),
    ink: Color(0xFFF4EFEB),
    mut: Color(0xFFA5A9BA),
    bd: Color(0xFF2E3247),
    pr: Color(0xFFFF6A5F),
    onPr: Color(0xFF1A0907),
    soft: Color(0xFF3A1F22),
    onSoft: Color(0xFFFFB4AC),
    nav: Color(0xFF232738),
    onNav: Color(0xFFF4EFEB),
    h1: Color(0xFFC62A20),
    h2: Color(0xFF9E1F17),
    ok: Color(0xFF5FD596),
    okSoft: Color(0xFF11301F),
    danger: Color(0xFFFF8A82),
    sf3: Color(0xFF292D42),
    warn: Color(0xFFF5B54A),
    warnSoft: Color(0xFF3A2B0E),
    onWarnSoft: Color(0xFFFFD98F),
    shadow: Color(0xFF000000),
    tints: _tintsDark,
  );

  @override
  BuTokens copyWith({
    Color? bg,
    Color? sf,
    Color? sf2,
    Color? ink,
    Color? mut,
    Color? bd,
    Color? pr,
    Color? onPr,
    Color? soft,
    Color? onSoft,
    Color? nav,
    Color? onNav,
    Color? h1,
    Color? h2,
    Color? ok,
    Color? okSoft,
    Color? danger,
    Color? sf3,
    Color? warn,
    Color? warnSoft,
    Color? onWarnSoft,
    Color? onMedia,
    Color? scrim,
    Color? qrInk,
    Color? qrPaper,
    Color? shadow,
    List<BuTint>? tints,
  }) =>
      BuTokens(
        bg: bg ?? this.bg,
        sf: sf ?? this.sf,
        sf2: sf2 ?? this.sf2,
        ink: ink ?? this.ink,
        mut: mut ?? this.mut,
        bd: bd ?? this.bd,
        pr: pr ?? this.pr,
        onPr: onPr ?? this.onPr,
        soft: soft ?? this.soft,
        onSoft: onSoft ?? this.onSoft,
        nav: nav ?? this.nav,
        onNav: onNav ?? this.onNav,
        h1: h1 ?? this.h1,
        h2: h2 ?? this.h2,
        ok: ok ?? this.ok,
        okSoft: okSoft ?? this.okSoft,
        danger: danger ?? this.danger,
        sf3: sf3 ?? this.sf3,
        warn: warn ?? this.warn,
        warnSoft: warnSoft ?? this.warnSoft,
        onWarnSoft: onWarnSoft ?? this.onWarnSoft,
        onMedia: onMedia ?? this.onMedia,
        scrim: scrim ?? this.scrim,
        qrInk: qrInk ?? this.qrInk,
        qrPaper: qrPaper ?? this.qrPaper,
        shadow: shadow ?? this.shadow,
        tints: tints ?? this.tints,
      );

  @override
  BuTokens lerp(ThemeExtension<BuTokens>? other, double t) {
    if (other is! BuTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return BuTokens(
      bg: c(bg, other.bg),
      sf: c(sf, other.sf),
      sf2: c(sf2, other.sf2),
      ink: c(ink, other.ink),
      mut: c(mut, other.mut),
      bd: c(bd, other.bd),
      pr: c(pr, other.pr),
      onPr: c(onPr, other.onPr),
      soft: c(soft, other.soft),
      onSoft: c(onSoft, other.onSoft),
      nav: c(nav, other.nav),
      onNav: c(onNav, other.onNav),
      h1: c(h1, other.h1),
      h2: c(h2, other.h2),
      ok: c(ok, other.ok),
      okSoft: c(okSoft, other.okSoft),
      danger: c(danger, other.danger),
      sf3: c(sf3, other.sf3),
      warn: c(warn, other.warn),
      warnSoft: c(warnSoft, other.warnSoft),
      onWarnSoft: c(onWarnSoft, other.onWarnSoft),
      onMedia: c(onMedia, other.onMedia),
      scrim: c(scrim, other.scrim),
      qrInk: c(qrInk, other.qrInk),
      qrPaper: c(qrPaper, other.qrPaper),
      shadow: c(shadow, other.shadow),
      tints: [
        for (var i = 0; i < tints.length && i < other.tints.length; i++) BuTint.lerp(tints[i], other.tints[i], t),
      ],
    );
  }
}

extension BuThemeX on BuildContext {
  BuTokens get bu => Theme.of(this).extension<BuTokens>()!;
}

/// Uygulama teması (Material 3 + marka belirteçleri). Örnekler önbelleğe alınır: ilk karede ikinci kez kurulmaz.
/// Arapça arayüzde (`LocaleController.current`) satır yüksekliği artar ve harf aralığı sıfırlanır.
class BuTheme {
  BuTheme._();

  static const fontFamily = BuType.family; // paketlenmis Inter (pubspec fonts); Arapca icin sistem yedegi

  static final _cache = <int, ThemeData>{};

  static bool get _arabic => LocaleController.current?.locale.languageCode == 'ar';

  static ThemeData light() => _get(Brightness.light, _arabic);
  static ThemeData dark() => _get(Brightness.dark, _arabic);

  /// Belirli dil için tema (test/galeri): `BuTheme.forLocale(Brightness.dark, 'ar')`.
  static ThemeData forLocale(Brightness b, String languageCode) => _get(b, languageCode == 'ar');

  static ThemeData _get(Brightness b, bool arabic) => _cache.putIfAbsent(
        (b == Brightness.dark ? 2 : 0) + (arabic ? 1 : 0),
        () => BuThemeBuilder.build(b == Brightness.dark ? BuTokens.dark : BuTokens.light, b, arabic: arabic),
      );
}
