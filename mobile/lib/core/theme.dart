import 'package:flutter/material.dart';

import 'locale_controller.dart';
import 'theme/bu_theme_builder.dart';
import 'typography.dart';

/// Marka renkleri (yalnız logo/simge/splash varlıkları için; arayüzde kullanılmaz). Arayüz PREMIUM MONOCHROME'dur:
/// renkler [BuTokens] içindedir (bkz. docs/MOBILE_DESIGN_SYSTEM.md); marka kırmızısı arayüzden çekildi.
class BuColors {
  BuColors._();

  static const ink = Color(0xFF171E33);
  static const red600 = Color(0xFFF73A2E); // logo kırmızısı: simge, splash
  static const red700 = Color(0xFFC62A20); // eylem kırmızısı: düğme/bağlantı (sakinleştirilmiş)
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

/// Tasarım belirteçleri: PREMIUM MONOCHROME (zinc nötrleri; varsayılan tema koyu = "Premium Black").
/// Kullanım: `final t = context.bu;` sonra `t.pr`, `t.sf`, `t.mut`...
///
/// **Arayüz siyah-beyazdır.** `pr` (birincil eylem) koyuda #FAFAFA / açıkta #09090B'dir, `onPr` tersi; `prText`,
/// `soft`/`onSoft`, `selectedBorder` nötrdür (marka kırmızısı YOK). Yüzey ladder'ı: `bg` < `sf` < `sf2` < `sf3`
/// (yükseltilmiş: dialog/alt sayfa/menü). Metin: `ink` (birincil) > `mut` (ikincil, AA) > `mutSoft` (üçüncül,
/// yalnız dekoratif/büyük metin). Kenarlık: `bd`, ince ayraç `bdSubtle`, kontrol çerçevesi `bdStrong` (>= 3:1).
///
/// **Renkli kalanlar yalnızca anlamsal:** `danger` (hata/silme/engelle), `heart` (beğeni kalbi), `ok` (başarı),
/// `warn` (uyarı), `info` (bilgi; okundu çift tiki `readSky/readDeep`). Kategori karoları ([tints]) nötrdür.
/// Kullanıcı fotoğrafı/medya doğal renkte kalır.
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
    required this.prPressed,
    required this.mutSoft,
    required this.bdSubtle,
    this.sf3 = const Color(0xFFFFFFFF),
    this.bdStrong = const Color(0xFF8A8A93),
    this.onOkSoft = const Color(0xFF14532D),
    this.dangerSoft = const Color(0xFFFEECEC),
    this.info = const Color(0xFF356BB8),
    this.infoSoft = const Color(0xFFE8F0FB),
    // Okundu (mavi çift tik): koyu balonda/şeritte açık gök mavisi, açık balonda koyu mavi (tema bağımsız sabitler).
    this.readSky = const Color(0xFF9FDBFF),
    this.readDeep = const Color(0xFF0B4F9C),
    this.onInfoSoft = const Color(0xFF224D8A),
    this.aqua = const Color(0xFF52525B),
    this.aquaSoft = const Color(0xFFF4F4F5),
    this.onAquaSoft = const Color(0xFF27272A),
    this.warn = const Color(0xFF946010),
    this.warnSoft = const Color(0xFFFDF3DC),
    this.onWarnSoft = const Color(0xFF7A4F10),
    this.heart = const Color(0xFFDC2626),
    this.onMedia = const Color(0xFFFFFFFF),
    this.scrim = const Color(0xFF000000),
    this.qrInk = const Color(0xFF000000),
    this.qrPaper = const Color(0xFFFFFFFF),
    this.shadow = const Color(0xFF09090B),
    this.navBase = const Color(0xFFFFFFFF),
    this.navGlass = const Color(0xB8FFFFFF),
    this.navAccent = const Color(0xFF09090B),
    this.navAccentHi = const Color(0xFF09090B),
    this.navIconIdle = const Color(0xFF3F3F46),
    this.navTextIdle = const Color(0xFF3F3F46),
    this.navBorder = const Color(0x14000000),
    this.navGlow = const Color(0x1F000000),
    this.tints = _tintsLight,
  });

  /// Eski "Kulüpler" kısayol karosu: artık nötr (sf2 + ink).
  Color get campusClubSoft => sf2;
  Color get onCampusClubSoft => ink;

  /// Beğeni kalbi (dolu kalp + patlama): kırmızı KALIR (anlamsal; marka rengi değil).
  final Color heart;

  final Color bg; // sayfa zemini
  final Color sf; // kart/yüzey
  final Color sf2; // ikincil yüzey (segment, görsel yer tutucu)
  final Color ink; // ana yazı
  final Color mut; // soluk yazı
  final Color bd; // çizgi
  final Color pr; // birincil eylem: koyuda beyaz, açıkta siyah (düğme, seçili durum, aktif gösterge)
  final Color onPr; // pr üstündeki yazı
  final Color soft; // nötr ince yüzey (sf2); seçili/vurgusuz satır zemini
  final Color onSoft; // soft üstündeki yazı
  final Color nav; // yüzen gezinme zemini
  final Color onNav;
  final Color h1; // koyu yer tutucu/splash zemini (gradyan YOK: iki uç eşit)
  final Color h2;
  final Color ok;
  final Color okSoft;
  final Color danger;

  /// Küçük beyaz yazılı dolu düğme/bağlantı zemini (AA >= 4.5:1; açıkta `pr`'den koyu, koyuda `pr`'den açık).
  final Color prPressed;

  /// Üçüncül metin/ipucu rengi (textTertiary): yalnız dekoratif ya da büyük metinde.
  final Color mutSoft;

  /// Çok ince ayraç (borderSubtle); kart çerçevesi için [bd].
  final Color bdSubtle;

  /// En üst yüzey: diyalog, alt sayfa, menü, gezinme çubuğu zemini.
  final Color sf3;

  /// Kontrol çerçevesi (giriş alanı, seçilmemiş seçim halkası): zemine karşı >= 3:1 (WCAG 1.4.11). Kart/ayraç
  /// çizgisi değildir; onlar için [bd] (kart ayrımı kenarlık + gölgeyle, yüzeyi koyulaştırmadan).
  final Color bdStrong;

  /// Seçili çip/segment çerçevesi: tek "seçili" stili = [soft] zemin + [onSoft] yazı + bu çerçeve (A6-03).
  /// Metin/küçük simge üstünde "vurgu" rengi: monochrome'da vurgu = birincil metin rengi (`ink`); bağlantı/eylem
  /// metni renkle değil konumla/alt çizgiyle ayrışır. Kırmızı değildir.
  Color get prText => ink;

  /// Seçili çip/segment çerçevesi: nötr, ink'in yarı saydamı.
  Color get selectedBorder => ink.withValues(alpha: .5);

  /// `okSoft` zemini üstündeki yazı/simge (başarı ailesinin "zemin üstü yazı" tonu).
  final Color onOkSoft;

  /// Hata yumuşak zemini (üstüne `danger` yazılır); marka `soft` zemininden ayrıdır.
  final Color dangerSoft;

  /// Bilgi / haber / duyuru: koyu mavi ana ton, yumuşak zemin ve zemin üstü yazı.
  final Color info;
  final Color infoSoft;
  final Color readSky;
  final Color readDeep;
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

  /// ALT NAVİGASYON "Soft Glow Premium" belirteçleri. Kırmızı YALNIZ alt çubukta kullanılır (kullanıcı kararı
  /// 2026-11-07); uygulamanın başka yerinde `nav*` kırmızı belirteçleri kullanılmaz.
  final Color navBase; // çubuk zemini (opak yedek, nokta halkası)
  final Color navGlass; // cam yüzey (yarı saydam)
  final Color navAccent; // aktif simge/etiket + Paylaş düğmesi
  final Color navAccentHi; // okunmamış noktası vurgusu
  final Color navIconIdle; // pasif simge
  final Color navTextIdle; // pasif etiket
  final Color navBorder; // ince dış kenarlık
  final Color navGlow; // yumuşak kırmızı ışık yansıması

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

  // Kategori karoları NÖTR: ayrım renkle değil simge + etiketle yapılır (indeksler [BuTintId] yine geçerli).
  static const _tintsLight = <BuTint>[
    BuTint(Color(0xFFF4F4F5), Color(0xFF09090B)), // 0 marka (artık nötr)
    BuTint(Color(0xFFF1F1F3), Color(0xFF18181B)), // 1 bilgi/haber
    BuTint(Color(0xFFEEEEF0), Color(0xFF18181B)), // 2 başarı/yemek
    BuTint(Color(0xFFEBEBEE), Color(0xFF18181B)), // 3 uyarı/hatırlatma
    BuTint(Color(0xFFE8E8EB), Color(0xFF18181B)), // 4 ikincil
    BuTint(Color(0xFFF7F7F8), Color(0xFF27272A)), // 5 nötr
  ];

  static const _tintsDark = <BuTint>[
    BuTint(Color(0xFF1C1C1F), Color(0xFFFAFAFA)),
    BuTint(Color(0xFF202023), Color(0xFFF4F4F5)),
    BuTint(Color(0xFF232326), Color(0xFFF4F4F5)),
    BuTint(Color(0xFF252528), Color(0xFFF4F4F5)),
    BuTint(Color(0xFF28282B), Color(0xFFF4F4F5)),
    BuTint(Color(0xFF1F1F22), Color(0xFFE4E4E7)),
  ];

  /// PREMIUM WHITE (açık): bağımsız tasarım, koyunun tersi DEĞİL. Zemin saf beyaz, kartlar #FAFAFA + ince kenarlık
  /// (gölge neredeyse yok), ikincil yüzey #F4F4F5; siyah yalnız düğme/seçili durumda (`pr`).
  static const light = BuTokens(
    bg: Color(0xFFFFFFFF),
    sf: Color(0xFFFAFAFA),
    sf2: Color(0xFFF4F4F5),
    sf3: Color(0xFFFFFFFF), // yükseltilmiş yüzey: dialog/alt sayfa (kenarlıkla ayrışır)
    ink: Color(0xFF09090B),
    mut: Color(0xFF52525B), // ikincil metin (AA)
    mutSoft: Color(0xFF71717A), // üçüncül/ipucu
    bd: Color(0xFFE4E4E7),
    bdSubtle: Color(0xFFEFEFF1),
    bdStrong: Color(0xFF8A8A93),
    pr: Color(0xFF09090B),
    onPr: Color(0xFFFFFFFF),
    prPressed: Color(0xFF09090B),
    soft: Color(0xFFF4F4F5),
    onSoft: Color(0xFF09090B),
    nav: Color(0xFFFAFAFA),
    onNav: Color(0xFF09090B),
    h1: Color(0xFF18181B),
    h2: Color(0xFF18181B),
    ok: Color(0xFF166534),
    okSoft: Color(0xFFE7F5EC),
    onOkSoft: Color(0xFF14532D),
    danger: Color(0xFFC81E1E),
    dangerSoft: Color(0xFFFEECEC),
    heart: Color(0xFFDC2626),
    info: Color(0xFF356BB8),
    infoSoft: Color(0xFFE8F0FB),
    onInfoSoft: Color(0xFF224D8A),
    warn: Color(0xFF946010),
    warnSoft: Color(0xFFFDF3DC),
    onWarnSoft: Color(0xFF7A4F10),
    shadow: Color(0xFF09090B),
    navBase: Color(0xFFFFFFFF),
    navGlass: Color(0xB8FFFFFF),
    navIconIdle: Color(0xFF3F3F46),
    navTextIdle: Color(0xFF3F3F46),
    navBorder: Color(0x14000000),
    navGlow: Color(0x1F000000),
  );

  /// PREMIUM BLACK (koyu, varsayılan): zemin #09090B, kartlar #141416, ikincil #1C1C1F, yükseltilmiş #252528;
  /// gölge yerine yüzey tonu + ince kenarlık; birincil düğme beyaz + siyah yazı.
  static const dark = BuTokens(
    bg: Color(0xFF09090B),
    sf: Color(0xFF141416),
    sf2: Color(0xFF1C1C1F),
    sf3: Color(0xFF252528),
    ink: Color(0xFFFAFAFA),
    mut: Color(0xFFA1A1AA),
    mutSoft: Color(0xFF71717A),
    bd: Color(0xFF303034),
    bdSubtle: Color(0xFF242427),
    bdStrong: Color(0xFF71717A),
    pr: Color(0xFFFAFAFA),
    onPr: Color(0xFF09090B),
    prPressed: Color(0xFFFAFAFA),
    soft: Color(0xFF1C1C1F),
    onSoft: Color(0xFFFAFAFA),
    nav: Color(0xFF141416),
    onNav: Color(0xFFFAFAFA),
    h1: Color(0xFF1C1C1F),
    h2: Color(0xFF1C1C1F),
    ok: Color(0xFF4ADE80),
    okSoft: Color(0xFF0F2A1A),
    onOkSoft: Color(0xFF86EFAC),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF2A1517),
    heart: Color(0xFFEF4444),
    info: Color(0xFF8DB4F0),
    infoSoft: Color(0xFF1B2B45),
    onInfoSoft: Color(0xFFB9D2FA),
    aqua: Color(0xFFA1A1AA),
    aquaSoft: Color(0xFF1C1C1F),
    onAquaSoft: Color(0xFFD4D4D8),
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
    Color? prPressed,
    Color? mutSoft,
    Color? bdSubtle,
    Color? sf3,
    Color? bdStrong,
    Color? onOkSoft,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? readSky,
    Color? readDeep,
    Color? onInfoSoft,
    Color? aqua,
    Color? aquaSoft,
    Color? onAquaSoft,
    Color? warn,
    Color? warnSoft,
    Color? onWarnSoft,
    Color? heart,
    Color? onMedia,
    Color? scrim,
    Color? qrInk,
    Color? qrPaper,
    Color? shadow,
    Color? navBase,
    Color? navGlass,
    Color? navAccent,
    Color? navAccentHi,
    Color? navIconIdle,
    Color? navTextIdle,
    Color? navBorder,
    Color? navGlow,
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
        prPressed: prPressed ?? this.prPressed,
        mutSoft: mutSoft ?? this.mutSoft,
        bdSubtle: bdSubtle ?? this.bdSubtle,
        sf3: sf3 ?? this.sf3,
        bdStrong: bdStrong ?? this.bdStrong,
        onOkSoft: onOkSoft ?? this.onOkSoft,
        dangerSoft: dangerSoft ?? this.dangerSoft,
        info: info ?? this.info,
        infoSoft: infoSoft ?? this.infoSoft,
        readSky: readSky ?? this.readSky,
        readDeep: readDeep ?? this.readDeep,
        onInfoSoft: onInfoSoft ?? this.onInfoSoft,
        aqua: aqua ?? this.aqua,
        aquaSoft: aquaSoft ?? this.aquaSoft,
        onAquaSoft: onAquaSoft ?? this.onAquaSoft,
        warn: warn ?? this.warn,
        warnSoft: warnSoft ?? this.warnSoft,
        onWarnSoft: onWarnSoft ?? this.onWarnSoft,
        heart: heart ?? this.heart,
        onMedia: onMedia ?? this.onMedia,
        scrim: scrim ?? this.scrim,
        qrInk: qrInk ?? this.qrInk,
        qrPaper: qrPaper ?? this.qrPaper,
        shadow: shadow ?? this.shadow,
        navBase: navBase ?? this.navBase,
        navGlass: navGlass ?? this.navGlass,
        navAccent: navAccent ?? this.navAccent,
        navAccentHi: navAccentHi ?? this.navAccentHi,
        navIconIdle: navIconIdle ?? this.navIconIdle,
        navTextIdle: navTextIdle ?? this.navTextIdle,
        navBorder: navBorder ?? this.navBorder,
        navGlow: navGlow ?? this.navGlow,
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
      prPressed: c(prPressed, other.prPressed),
      mutSoft: c(mutSoft, other.mutSoft),
      bdSubtle: c(bdSubtle, other.bdSubtle),
      sf3: c(sf3, other.sf3),
      bdStrong: c(bdStrong, other.bdStrong),
      onOkSoft: c(onOkSoft, other.onOkSoft),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      info: c(info, other.info),
      infoSoft: c(infoSoft, other.infoSoft),
      readSky: c(readSky, other.readSky),
      readDeep: c(readDeep, other.readDeep),
      onInfoSoft: c(onInfoSoft, other.onInfoSoft),
      aqua: c(aqua, other.aqua),
      aquaSoft: c(aquaSoft, other.aquaSoft),
      onAquaSoft: c(onAquaSoft, other.onAquaSoft),
      warn: c(warn, other.warn),
      warnSoft: c(warnSoft, other.warnSoft),
      onWarnSoft: c(onWarnSoft, other.onWarnSoft),
      heart: c(heart, other.heart),
      onMedia: c(onMedia, other.onMedia),
      scrim: c(scrim, other.scrim),
      qrInk: c(qrInk, other.qrInk),
      qrPaper: c(qrPaper, other.qrPaper),
      shadow: c(shadow, other.shadow),
      navBase: c(navBase, other.navBase),
      navGlass: c(navGlass, other.navGlass),
      navAccent: c(navAccent, other.navAccent),
      navAccentHi: c(navAccentHi, other.navAccentHi),
      navIconIdle: c(navIconIdle, other.navIconIdle),
      navTextIdle: c(navTextIdle, other.navTextIdle),
      navBorder: c(navBorder, other.navBorder),
      navGlow: c(navGlow, other.navGlow),
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
