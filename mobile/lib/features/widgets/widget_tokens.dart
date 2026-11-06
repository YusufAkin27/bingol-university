/// Ana ekran widget'larının merkezi tasarım belirteçleri (YALNIZ uygulama içi önizleme/test içindir; widget'ların
/// kendisi native'dir). Aynı değerler `design/widget-previews/DESIGN_SYSTEM.md` tablolarında, iOS'ta
/// `mobile/ios/BUWidgets/Shared/BuWidgetTokens.swift` ve Android'de `.../widgets/WidgetTokens.kt` içinde birebir yer
/// alır; `test/widgets/widget_tokens_test.dart` üçünü karşılaştırır. Birim: iOS pt = Android dp = Dart mantıksal px.
///
/// Renkler BuTokens'tan OKUNUR (ham renk literali yok): kaynak doğruluk BuTokens'tır, tasarım README'lerindeki tahmini
/// onaltılık değerler bunun lehine düzeltildi (bkz. DESIGN_SYSTEM.md "BuTokens uzlaştırması").
library;

import 'package:flutter/painting.dart' show Color;

import '../../core/theme.dart' show BuTokens;

/// Widget renk paleti (açık veya koyu). Tüm alanlar BuTokens'tan türer.
class WidgetPalette {
  const WidgetPalette({
    required this.bg,
    required this.chip,
    required this.border,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.inverseBg,
    required this.inverseFg,
    required this.barFill,
    required this.barTrack,
    required this.badgeFill,
    required this.badgeBorder,
    required this.dotPassive,
    required this.heart,
    required this.danger,
  });

  /// BuTokens → widget rolü eşlemesi (DESIGN_SYSTEM.md "Renk belirteçleri" tablosunun tek kaynağı).
  factory WidgetPalette.from(BuTokens t) => WidgetPalette(
        bg: t.bg,
        chip: t.sf2,
        border: t.bd,
        text1: t.ink,
        text2: t.mut,
        text3: t.mutSoft,
        inverseBg: t.pr,
        inverseFg: t.onPr,
        barFill: t.pr,
        barTrack: t.bd,
        badgeFill: t.sf2,
        badgeBorder: t.bd,
        dotPassive: t.bdStrong,
        heart: t.heart,
        danger: t.danger,
      );

  static final WidgetPalette light = WidgetPalette.from(BuTokens.light);
  static final WidgetPalette dark = WidgetPalette.from(BuTokens.dark);

  final Color bg; // widget zemini (tek düz renk)
  final Color chip; // karo / vurgulu satır / "chip" yüzeyi
  final Color border; // 1 dp dış çizgi ve ayırıcılar
  final Color text1; // birincil yazı ve ikon
  final Color text2; // ikincil yazı
  final Color text3; // üçüncül (caption, ipucu)
  final Color inverseBg; // ters rozet / "Oy ver" hapı zemini
  final Color inverseFg; // ters rozet yazısı
  final Color barFill; // anket çubuğu (lider tam, diğerleri %45 opaklık)
  final Color barTrack; // anket çubuğu izi
  final Color badgeFill; // etkinlik tarih rozeti dolgusu
  final Color badgeBorder; // etkinlik tarih rozeti kenarı
  final Color dotPassive; // duyuru pasif noktası
  final Color heart; // YALNIZ beğeni kalbi
  final Color danger; // YALNIZ acil duyuru

  /// Rol adı → renk (sıra DESIGN_SYSTEM.md tablosuyla aynı).
  Map<String, Color> get byRole => {
        'bg': bg,
        'chip': chip,
        'border': border,
        'text1': text1,
        'text2': text2,
        'text3': text3,
        'inverseBg': inverseBg,
        'inverseFg': inverseFg,
        'barFill': barFill,
        'barTrack': barTrack,
        'badgeFill': badgeFill,
        'badgeBorder': badgeBorder,
        'dotPassive': dotPassive,
        'heart': heart,
        'danger': danger,
      };
}

/// `#RRGGBB` (büyük harf). Test ve belge üretimi için.
String widgetHex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Platform widget boyut ailesi.
enum WidgetFamily { small, medium, large }

/// Bir widget yüzeyi: referans ölçü (tasarım PNG'leri bu ölçüde alındı) ve kabuk.
class WidgetSurface {
  const WidgetSurface(this.platform, this.name, this.family, this.width, this.height, this.corner);

  final String platform; // ios | android
  final String name; // small | medium | large | 2x2 | 4x2 | 4x4
  final WidgetFamily family;
  final double width;
  final double height;
  final double corner;
}

/// Tipografi rolü: boyut/satır yüksekliği, harf aralığı (em), büyük harf. Ağırlık HER YERDE 400.
class WidgetTextRole {
  const WidgetTextRole(this.size, this.line, {this.tracking = 0, this.caps = false});

  final double size;
  final double line;
  final double tracking;
  final bool caps;
}

abstract final class WidgetTokens {
  // --- Kabuk ---
  static const double paddingDefault = 16;
  static const double paddingQuickSmall = 12; // yalnız Hızlı Erişim small/2x2 (karo alanı büyük olsun)
  static const double borderWidth = 1;
  static const double cornerIos = 22;
  static const double cornerAndroid = 28;

  static const surfaces = <WidgetSurface>[
    WidgetSurface('ios', 'small', WidgetFamily.small, 158, 158, 22),
    WidgetSurface('ios', 'medium', WidgetFamily.medium, 338, 158, 22),
    WidgetSurface('ios', 'large', WidgetFamily.large, 338, 354, 22),
    WidgetSurface('android', '2x2', WidgetFamily.small, 170, 170, 28),
    WidgetSurface('android', '4x2', WidgetFamily.medium, 350, 170, 28),
    WidgetSurface('android', '4x4', WidgetFamily.large, 350, 350, 28),
  ];

  // --- Yazı: tek ağırlık ---
  static const int fontWeight = 400;

  static const caption = WidgetTextRole(10, 12, tracking: 0.08, caps: true);
  static const micro = WidgetTextRole(11, 14);
  static const small = WidgetTextRole(12, 16);
  static const body = WidgetTextRole(13, 18);
  static const bodyL = WidgetTextRole(14, 18);
  static const question = WidgetTextRole(15, 20, tracking: -0.01);
  static const title = WidgetTextRole(17, 22, tracking: -0.01);
  static const display = WidgetTextRole(22, 26, tracking: -0.02);
  static const number = WidgetTextRole(34, 38, tracking: -0.03);
  static const numberRow = WidgetTextRole(28, 32, tracking: -0.03);
  static const badgeDaySmall = WidgetTextRole(13, 13);
  static const badgeMonthSmall = WidgetTextRole(9, 10, tracking: 0.08, caps: true);
  static const badgeDayLarge = WidgetTextRole(18, 20);
  static const badgeMonthLarge = WidgetTextRole(10, 12, tracking: 0.08, caps: true);
  static const eventDayHero = WidgetTextRole(34, 36, tracking: -0.03);

  static const roles = <String, WidgetTextRole>{
    'caption': caption,
    'micro': micro,
    'small': small,
    'body': body,
    'bodyL': bodyL,
    'question': question,
    'title': title,
    'display': display,
    'number': number,
    'numberRow': numberRow,
    'badgeDaySmall': badgeDaySmall,
    'badgeMonthSmall': badgeMonthSmall,
    'badgeDayLarge': badgeDayLarge,
    'badgeMonthLarge': badgeMonthLarge,
    'eventDayHero': eventDayHero,
  };

  // --- Boşluk ölçeği ---
  static const double s2 = 2, s4 = 4, s6 = 6, s8 = 8, s10 = 10, s12 = 12, s14 = 14, s16 = 16;
  static const List<double> spacingScale = [2, 4, 6, 8, 10, 12, 14, 16];

  // --- Köşe yarıçapları ---
  static const double radiusRow = 12; // ders satırı, kcal chip
  static const double radiusTile = 14; // hızlı erişim karosu, sosyal satır, kcal chip (large)
  static const double radiusChip = 12; // hızlı erişim small karosu
  static const double radiusBadgeSmall = 8; // ters rozet ve etkinlik rozeti (satır 30/36)
  static const double radiusBadgeLarge = 10; // etkinlik rozeti 44x48
  static const double radiusBar = 2; // anket çubuğu
  static const double radiusPill = 999; // "Oy ver"

  // --- İkon (Lucide çizgi, vuruş 1.5, round) ---
  static const double iconStroke = 1.5;
  static const double iconHeader = 12;
  static const double iconHeaderEvents = 14; // etkinlik/duyuru başlık ikonu
  static const double iconMeta = 12;
  static const double iconMetaLarge = 14;
  static const double iconRowLarge = 22; // sosyal large satır, hızlı erişim small karo
  static const double iconTileMedium = 18;
  static const double iconTileLarge = 24;
  static const double iconEmptySmall = 20;
  static const double iconEmptyMedium = 22;
  static const double iconEmptyLarge = 28;
  static const double iconSocialMedium = 18;

  // --- Başlık satırı / logo ---
  static const double headerHeight = 16;
  static const double headerGap = 12; // başlık satırı altı (medium'da 8 bazı widget'ta, DESIGN_SYSTEM.md)
  static const double logoHeight = 12; // menü, ders, anket, hızlı erişim, sosyal
  static const double logoHeightEvents = 14; // etkinlik, duyuru
  static const double logoOpacity = 0.9;

  // --- Satır/karo yükseklikleri ---
  static const double rowTimetableMedium = 36;
  static const double rowTimetableLarge = 40;
  static const double rowEventsIos = 30;
  static const double rowEventsAndroid = 36;
  static const double rowSocialLarge = 64;
  static const double badgeEventLargeWidth = 44;
  static const double badgeEventLargeHeight = 48;
  static const double badgeTimetableWidth = 52;
  static const double pillHeight = 28;
  static const double pillPaddingX = 14;
  static const double kcalChipHeight = 36;
  static const double barHeight = 4;
  static const double tileGap = 8;

  /// Android: yazı sp = dp; sistem yazı ölçeği 1.0 üstüne çıkarsa boyutlar SABİTLENİR (fontScale'e bölünür).
  static const double maxFontScale = 1.0;
  static const double opacityPastLesson = 0.5;
  static const double opacityNonLeaderBar = 0.45;
}

/// Boyuta göre içerik düzeni: her widget için aile başına kaç öğe/satır. DESIGN_SYSTEM.md "Boyuta göre içerik" tablosu.
abstract final class WidgetLayouts {
  // menu
  static const menuSmallMainLines = 2;
  static const menuMediumDishes = 3; // sütun başına; tek öğünde 2 sütun x 3 = 6
  static const menuLargeDishes = 4; // bölüm başına; tek öğünde 8
  static const menuLargeDishesSingleMeal = 8;
  // timetable
  static const timetableSmallTitleLines = 2;
  static const timetableMediumRows = 2;
  static const timetableLargeRows = 4;
  // events
  static const eventsSmall = 1;
  static const eventsMedium = 3;
  static const eventsLarge = 3;
  // announcements
  static const announcementsSmall = 1;
  static const announcementsMedium = 3;
  static const announcementsLarge = 4;
  static const announcementsSmallTitleLines = 4;
  static const announcementsLargeTitleLines = 2;
  // poll
  static const pollSmallQuestionLines = 3;
  static const pollMediumQuestionLines = 3;
  static const pollMediumOptions = 3;
  static const pollLargeQuestionLines = 2;
  static const pollLargeOptionsMax = 4;
  // quickaccess
  static const quickSmallTiles = 4;
  static const quickMediumTiles = 8; // 4 sütun x 2 satır
  static const quickLargeTiles = 8;
  // social
  static const socialSmallRows = 1; // 1 büyük sayı + alt satırda 2 küçük sayı
  static const socialMediumColumns = 3;
  static const socialLargeRows = 3;
}
