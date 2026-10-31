import 'package:flutter/material.dart';

import 'locale_controller.dart';
import 'theme/bu_theme_builder.dart';
import 'typography.dart';

/// Marka renkleri (Kampüs Kırmızısı + lacivert mürekkep). `red600` uygulama simgesiyle aynıdır; arayüzdeki eylem
/// kırmızısı (`red700`) simge tonundan türetilip biraz sakinleştirildi (RENK-1, bkz. docs/design/RENK_ENVANTERI.md).
/// Web (`web/src/styles/tokens.css`) bu sakinleştirmeyi henüz almadı.
class BuColors {
  BuColors._();

  static const ink = Color(0xFF171E33);
  static const red600 = Color(0xFFF73A2E); // logo kırmızısı: simge, splash
  static const red700 = Color(0xFFC0392B); // eylem kırmızısı: düğme/bağlantı (sakinleştirilmiş)
  static const red800 = Color(0xFF8A2A20);
  static const red100 = Color(0xFFFBE9E6);
}

/// Kategori/etiket renk çifti: yumuşak zemin + üstündeki yazı/simge (AA kontrast).
@immutable
class BuTint {
  const BuTint(this.bg, this.fg);

  final Color bg;
  final Color fg;

  static BuTint lerp(BuTint a, BuTint b, double t) => BuTint(Color.lerp(a.bg, b.bg, t)!, Color.lerp(a.fg, b.fg, t)!);
}

/// [BuTokens.tints] indeksleri (anlamlı adlar; eski sayısal kullanım geçerlidir).
abstract final class BuTintId {
  static const brand = 0;
  static const blue = 1; // bilgi, haber, duyuru
  static const green = 2; // başarı, yemek, topluluk
  static const amber = 3; // uyarı, hatırlatma, bekleyen
  static const aqua = 4; // ikincil vurgu (su mavisi)
  static const slate = 5; // nötr (sistem, ayar)
}

/// Tasarım belirteçleri (mobile/design/*.dc.html içindeki CSS değişkenleriyle birebir).
/// Kullanım: `final t = context.bu;` sonra `t.pr`, `t.sf`, `t.mut`...
///
/// Mevcut alanlar KİLİTLİ; P0 ile eklenen alanlar isteğe bağlıdır: `sf3`, `warn`, `warnSoft`, `onWarnSoft`,
/// `onMedia`, `scrim`, `qrInk`, `qrPaper`, `shadow`, `tints`. RENK-1 ile eklenenler (hepsi isteğe bağlı):
/// `info*` (koyu mavi), `aqua*` (su mavisi), `onOkSoft`, `dangerSoft`.
///
/// **Palet tek ve küçüktür: marka (kırmızı) + 4 anlam ailesi.** Her aile üç tondur: ana (simge/çizgi/yazı),
/// yumuşak zemin, zemin üstü yazı. Mavi = bilgi/haber/duyuru, su mavisi = ikincil vurgu, yeşil = başarı/yemek,
/// amber = uyarı/hatırlatma/bekleyen, `danger` = hata (marka kırmızısından ayrı: daha koyu, pembeye yakın).
/// Kategori ayrımı renkten çok simge + etiketle yapılır.
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
    this.bdStrong = const Color(0xFF8A857E),
    this.onOkSoft = const Color(0xFF0F5132),
    this.dangerSoft = const Color(0xFFFBE4E8),
    this.info = const Color(0xFF1F4E96),
    this.infoSoft = const Color(0xFFE4ECF8),
    this.onInfoSoft = const Color(0xFF173F7B),
    this.aqua = const Color(0xFF0B6E86),
    this.aquaSoft = const Color(0xFFDDF1F6),
    this.onAquaSoft = const Color(0xFF0A5468),
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

  /// Kontrol çerçevesi (giriş alanı, seçilmemiş seçim halkası): zemine karşı >= 3:1 (WCAG 1.4.11). Kart/ayraç
  /// çizgisi değildir; onlar için [bd] (kart ayrımı kenarlık + gölgeyle, yüzeyi koyulaştırmadan).
  final Color bdStrong;

  /// Seçili çip/segment çerçevesi: tek "seçili" stili = [soft] zemin + [onSoft] yazı + bu çerçeve (A6-03).
  Color get selectedBorder => pr.withValues(alpha: .45);

  /// `okSoft` zemini üstündeki yazı/simge (başarı ailesinin "zemin üstü yazı" tonu).
  final Color onOkSoft;

  /// Hata yumuşak zemini (üstüne `danger` yazılır); marka `soft` zemininden ayrıdır.
  final Color dangerSoft;

  /// Bilgi / haber / duyuru: koyu mavi ana ton, yumuşak zemin ve zemin üstü yazı.
  final Color info;
  final Color infoSoft;
  final Color onInfoSoft;

  /// İkincil vurgu: su mavisi ana ton, yumuşak zemin ve zemin üstü yazı.
  final Color aqua;
  final Color aquaSoft;
  final Color onAquaSoft;

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

  /// Kategori renkleri (kulüp/ders/haber türü): 6 çift, indeksler [BuTintId]. [tint] ile `id` bazlı döngüsel seçilir.
  /// Değerler yukarıdaki ailelerden gelir: marka, mavi, yeşil, amber, su mavisi, nötr (mor/turkuaz/pembe yok).
  final List<BuTint> tints;

  LinearGradient get hero => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [h1, h2],
      );

  /// [tints] içinden döngüsel seçim (`tint(club.id)`).
  BuTint tint(int i) => tints[i.abs() % tints.length];

  static const _tintsLight = <BuTint>[
    BuTint(Color(0xFFFBE9E6), Color(0xFF8A2A20)), // 0 marka
    BuTint(Color(0xFFE4ECF8), Color(0xFF173F7B)), // 1 mavi (bilgi/haber/duyuru)
    BuTint(Color(0xFFE0F2E8), Color(0xFF0F5132)), // 2 yeşil (başarı/yemek)
    BuTint(Color(0xFFFFF1D6), Color(0xFF6B3E00)), // 3 amber (uyarı/hatırlatma)
    BuTint(Color(0xFFDDF1F6), Color(0xFF0A5468)), // 4 su mavisi (ikincil)
    BuTint(Color(0xFFEAE8E4), Color(0xFF45423E)), // 5 nötr
  ];

  static const _tintsDark = <BuTint>[
    BuTint(Color(0xFF3B2321), Color(0xFFFFBBB2)),
    BuTint(Color(0xFF1B2B45), Color(0xFFB9D2FA)),
    BuTint(Color(0xFF16301F), Color(0xFF9BE3BE)),
    BuTint(Color(0xFF3A2B0E), Color(0xFFFFD98F)),
    BuTint(Color(0xFF11323B), Color(0xFFA6E3F0)),
    BuTint(Color(0xFF2E2F32), Color(0xFFC9C7C2)),
  ];

  static const light = BuTokens(
    // Sıcak-nötr yüzeyler (kırık beyaz), lacivert mürekkep, sakin marka kırmızısı (RENK-1).
    bg: Color(0xFFF7F5F2),
    sf: Color(0xFFFFFFFF),
    sf2: Color(0xFFEEEBE6),
    ink: Color(0xFF171E33),
    mut: Color(0xFF5C5A56),
    bd: Color(0xFFDAD5CD), // kart/ayraç çizgisi; kontrol çerçevesi için bdStrong
    pr: Color(0xFFC0392B),
    onPr: Color(0xFFFFFFFF),
    soft: Color(0xFFFBE9E6),
    onSoft: Color(0xFF8A2A20),
    nav: Color(0xFF171E33),
    onNav: Color(0xFFFFFFFF),
    h1: Color(0xFFC8402F), // beyaz yazı AA (>= 4.5:1); h1-h2 farkı çok hafif (gradyan neredeyse düz)
    h2: Color(0xFFBB3628),
    ok: Color(0xFF1E7A50),
    okSoft: Color(0xFFE0F2E8),
    danger: Color(0xFFA3162E),
  );

  static const dark = BuTokens(
    // Yumuşak kömür (saf siyah değil), sıcak-nötr; ana tonlar açık ve pastel (RENK-1).
    bg: Color(0xFF171819),
    sf: Color(0xFF202123),
    sf2: Color(0xFF2A2B2E),
    ink: Color(0xFFF2EFEA),
    mut: Color(0xFFA9A7A2),
    bd: Color(0xFF3A3B3F),
    pr: Color(0xFFF0766A),
    onPr: Color(0xFF2A0B07),
    soft: Color(0xFF3B2321),
    onSoft: Color(0xFFFFBBB2),
    nav: Color(0xFF35373B),
    onNav: Color(0xFFF2EFEA),
    h1: Color(0xFFB5362B),
    h2: Color(0xFF992E24),
    ok: Color(0xFF6FD0A0),
    okSoft: Color(0xFF16301F),
    danger: Color(0xFFFF8FA0),
    sf3: Color(0xFF313235),
    bdStrong: Color(0xFF7D8087),
    onOkSoft: Color(0xFF9BE3BE),
    dangerSoft: Color(0xFF3D1D24),
    info: Color(0xFF8DB4F0),
    infoSoft: Color(0xFF1B2B45),
    onInfoSoft: Color(0xFFB9D2FA),
    aqua: Color(0xFF6CCBE0),
    aquaSoft: Color(0xFF11323B),
    onAquaSoft: Color(0xFFA6E3F0),
    warn: Color(0xFFF2B24A),
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
    Color? bdStrong,
    Color? onOkSoft,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? onInfoSoft,
    Color? aqua,
    Color? aquaSoft,
    Color? onAquaSoft,
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
        bdStrong: bdStrong ?? this.bdStrong,
        onOkSoft: onOkSoft ?? this.onOkSoft,
        dangerSoft: dangerSoft ?? this.dangerSoft,
        info: info ?? this.info,
        infoSoft: infoSoft ?? this.infoSoft,
        onInfoSoft: onInfoSoft ?? this.onInfoSoft,
        aqua: aqua ?? this.aqua,
        aquaSoft: aquaSoft ?? this.aquaSoft,
        onAquaSoft: onAquaSoft ?? this.onAquaSoft,
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
      bdStrong: c(bdStrong, other.bdStrong),
      onOkSoft: c(onOkSoft, other.onOkSoft),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      info: c(info, other.info),
      infoSoft: c(infoSoft, other.infoSoft),
      onInfoSoft: c(onInfoSoft, other.onInfoSoft),
      aqua: c(aqua, other.aqua),
      aquaSoft: c(aquaSoft, other.aquaSoft),
      onAquaSoft: c(onAquaSoft, other.onAquaSoft),
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
