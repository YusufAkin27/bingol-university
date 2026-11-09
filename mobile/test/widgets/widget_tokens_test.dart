import 'dart:io';

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/widgets/widget_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ucu AYNI degerleri tasir: DESIGN_SYSTEM.md tablolari, Dart (widget_tokens.dart), Swift (BuWidgetTokens.swift),
/// Kotlin (WidgetTokens.kt) ve Android widget_colors.xml (acik/koyu). Renkler BuTokens'tan turetilir.
/// Calisma dizini: mobile/ (flutter test).
String read(String p) => File(p).readAsStringSync();

final md = read('../design/widget-previews/DESIGN_SYSTEM.md');
final swift = read('ios/BUWidgets/Shared/BuWidgetTokens.swift');
final kotlin = read('android/app/src/main/kotlin/edu/bingol/bu_kampus/widgets/WidgetTokens.kt');
final xmlLight = read('android/app/src/main/res/values/widget_colors.xml');
final xmlDark = read('android/app/src/main/res/values-night/widget_colors.xml');

String snake(String camel) => camel.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
String upperSnake(String camel) => snake(camel).toUpperCase();

/// `| `rol` | ... |` satirlari (ilk hucre geri tirnakli ad).
List<List<String>> mdRows(String section) {
  final start = md.indexOf(section);
  expect(start, greaterThan(-1), reason: section);
  final next = md.indexOf('\n## ', start + 5);
  final body = md.substring(start, next < 0 ? md.length : next);
  return [
    for (final line in body.split('\n'))
      if (RegExp(r'^\| `\w+` \|').hasMatch(line)) [for (final c in line.split('|').skip(1)) c.trim().replaceAll('`', '')]..removeLast(),
  ];
}

String hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  final light = WidgetPalette.light, dark = WidgetPalette.dark;

  group('renk', () {
    test('belge tablosu = BuTokens turevi palet (acik + koyu), 15 rol', () {
      final rows = mdRows('## 3. Renk belirteçleri');
      expect(rows.length, 15);
      for (final r in rows) {
        final role = r[0];
        expect(light.byRole.containsKey(role), isTrue, reason: role);
        expect(widgetHex(light.byRole[role]!), r[2], reason: '$role acik');
        expect(widgetHex(dark.byRole[role]!), r[3], reason: '$role koyu');
      }
    });

    test('paletin her rolu BuTokens alanina baglidir (belgedeki BuTokens sutunu dogru)', () {
      final rows = mdRows('## 3. Renk belirteçleri');
      final fields = <String, Map<String, Object>>{
        'bg': {'l': BuTokens.light.bg, 'd': BuTokens.dark.bg},
        'sf2': {'l': BuTokens.light.sf2, 'd': BuTokens.dark.sf2},
        'bd': {'l': BuTokens.light.bd, 'd': BuTokens.dark.bd},
        'ink': {'l': BuTokens.light.ink, 'd': BuTokens.dark.ink},
        'mut': {'l': BuTokens.light.mut, 'd': BuTokens.dark.mut},
        'mutSoft': {'l': BuTokens.light.mutSoft, 'd': BuTokens.dark.mutSoft},
        'pr': {'l': BuTokens.light.pr, 'd': BuTokens.dark.pr},
        'onPr': {'l': BuTokens.light.onPr, 'd': BuTokens.dark.onPr},
        'bdStrong': {'l': BuTokens.light.bdStrong, 'd': BuTokens.dark.bdStrong},
        'heart': {'l': BuTokens.light.heart, 'd': BuTokens.dark.heart},
        'danger': {'l': BuTokens.light.danger, 'd': BuTokens.dark.danger},
      };
      for (final r in rows) {
        final f = fields[r[1]];
        expect(f, isNotNull, reason: 'BuTokens alani ${r[1]}');
        expect(widgetHex(f!['l']! as dynamic), r[2], reason: '${r[0]} ${r[1]} acik');
        expect(widgetHex(f['d']! as dynamic), r[3], reason: '${r[0]} ${r[1]} koyu');
      }
    });

    test('Swift paleti = belge', () {
      for (final mode in ['light', 'dark']) {
        final block = RegExp('static let $mode = BuWidgetPalette\\(([^)]*)\\)', dotAll: true).firstMatch(swift)!.group(1)!;
        final p = mode == 'light' ? light : dark;
        for (final e in p.byRole.entries) {
          final m = RegExp('\\b${e.key}: 0x([0-9A-Fa-f]{6})').firstMatch(block);
          expect(m, isNotNull, reason: 'Swift $mode ${e.key}');
          expect('#${m!.group(1)!.toUpperCase()}', widgetHex(e.value), reason: 'Swift $mode ${e.key}');
        }
      }
    });

    test('Kotlin paleti = belge', () {
      for (final mode in ['LIGHT', 'DARK']) {
        final block = RegExp('val $mode = Palette\\(([^)]*)\\)', dotAll: true).firstMatch(kotlin)!.group(1)!;
        final p = mode == 'LIGHT' ? light : dark;
        for (final e in p.byRole.entries) {
          final m = RegExp('\\b${e.key} = 0xFF([0-9A-Fa-f]{6})').firstMatch(block);
          expect(m, isNotNull, reason: 'Kotlin $mode ${e.key}');
          expect('#${m!.group(1)!.toUpperCase()}', widgetHex(e.value), reason: 'Kotlin $mode ${e.key}');
        }
      }
    });

    test('Android widget_colors.xml (values / values-night) = belge', () {
      for (final mode in ['light', 'dark']) {
        final xml = mode == 'light' ? xmlLight : xmlDark;
        final p = mode == 'light' ? light : dark;
        for (final e in p.byRole.entries) {
          final m = RegExp('<color name="bu_widget_${snake(e.key)}">(#[0-9A-Fa-f]{6})</color>').firstMatch(xml);
          expect(m, isNotNull, reason: 'xml $mode ${e.key}');
          expect(m!.group(1)!.toUpperCase(), widgetHex(e.value), reason: 'xml $mode ${e.key}');
        }
        expect(RegExp('<color ').allMatches(xml).length, p.byRole.length);
      }
    });

    test('kirmizi yalniz kalp ve acil: diger rollerde kirmizi ton yok', () {
      for (final p in [light, dark]) {
        for (final e in p.byRole.entries) {
          if (e.key == 'heart' || e.key == 'danger') continue;
          final c = e.value;
          final r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();
          expect(r - ((g + b) / 2) < 24, isTrue, reason: '${e.key} kirmizi tonlu');
        }
      }
    });
  });

  group('tipografi', () {
    test('belge tablosu = Dart rolleri = Swift = Kotlin; agirlik 400', () {
      final rows = mdRows('## 4. Tipografi');
      expect(rows.length, WidgetTokens.roles.length);
      for (final r in rows) {
        final role = WidgetTokens.roles[r[0]];
        expect(role, isNotNull, reason: r[0]);
        expect(role!.size, double.parse(r[1]), reason: '${r[0]} boyut');
        expect(role.line, double.parse(r[2]), reason: '${r[0]} satir');
        expect(role.tracking, double.parse(r[3]), reason: '${r[0]} harf araligi');
        expect(role.caps, r[4] == 'evet', reason: '${r[0]} caps');

        final sm = RegExp('static let ${r[0]} = TextRole\\((\\d+), (\\d+)(?:, tracking: (-?[0-9.]+))?(?:, caps: (true|false))?\\)').firstMatch(swift);
        expect(sm, isNotNull, reason: 'Swift ${r[0]}');
        expect(double.parse(sm!.group(1)!), role.size, reason: 'Swift ${r[0]}');
        expect(double.parse(sm.group(2)!), role.line, reason: 'Swift ${r[0]}');
        expect(double.parse(sm.group(3) ?? '0'), role.tracking, reason: 'Swift ${r[0]}');
        expect(sm.group(4) == 'true', role.caps, reason: 'Swift ${r[0]}');

        final km = RegExp('val ${upperSnake(r[0])} = TextRole\\((\\d+), (\\d+)(?:, (-?[0-9.]+)f)?(?:, (true|false))?\\)').firstMatch(kotlin);
        expect(km, isNotNull, reason: 'Kotlin ${r[0]}');
        expect(double.parse(km!.group(1)!), role.size, reason: 'Kotlin ${r[0]}');
        expect(double.parse(km.group(2)!), role.line, reason: 'Kotlin ${r[0]}');
        expect(double.parse(km.group(3) ?? '0'), role.tracking, reason: 'Kotlin ${r[0]}');
        expect(km.group(4) == 'true', role.caps, reason: 'Kotlin ${r[0]}');
      }
    });

    test('tek agirlik 400: Dart, Swift, Kotlin ve widget dosyalarinda kalin yazi yok', () {
      expect(WidgetTokens.fontWeight, 400);
      expect(swift, contains('fontWeight: Font.Weight = .regular'));
      expect(kotlin, contains('FONT_WEIGHT = 400'));
      expect(RegExp(r'(weight:|Weight =) \.(bold|semibold|medium|heavy|black|light|thin|ultraLight)').hasMatch(swift), isFalse);
      expect(RegExp(r'FontWeight\.(Bold|Medium|SemiBold|ExtraBold)').hasMatch(kotlin), isFalse);
      for (final f in Directory('lib/features/widgets').listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        expect(RegExp(r'FontWeight\.w[5-9]00|FontWeight\.bold').hasMatch(src), isFalse, reason: f.path);
        expect(RegExp(r'Color\(0x').hasMatch(src), isFalse, reason: '${f.path} ham renk');
      }
    });
  });

  group('olculer', () {
    // ad -> Dart degeri; Swift (camelCase) ve Kotlin (UPPER_SNAKE) ayni adla ayni sayiyi tasimali.
    final scalars = <String, double>{
      'paddingDefault': WidgetTokens.paddingDefault,
      'paddingQuickSmall': WidgetTokens.paddingQuickSmall,
      'borderWidth': WidgetTokens.borderWidth,
      's2': WidgetTokens.s2,
      's4': WidgetTokens.s4,
      's6': WidgetTokens.s6,
      's8': WidgetTokens.s8,
      's10': WidgetTokens.s10,
      's12': WidgetTokens.s12,
      's14': WidgetTokens.s14,
      's16': WidgetTokens.s16,
      'radiusRow': WidgetTokens.radiusRow,
      'radiusTile': WidgetTokens.radiusTile,
      'radiusChip': WidgetTokens.radiusChip,
      'radiusBadgeSmall': WidgetTokens.radiusBadgeSmall,
      'radiusBadgeLarge': WidgetTokens.radiusBadgeLarge,
      'radiusBar': WidgetTokens.radiusBar,
      'iconStroke': WidgetTokens.iconStroke,
      'iconHeader': WidgetTokens.iconHeader,
      'iconHeaderEvents': WidgetTokens.iconHeaderEvents,
      'iconMeta': WidgetTokens.iconMeta,
      'iconMetaLarge': WidgetTokens.iconMetaLarge,
      'iconRowLarge': WidgetTokens.iconRowLarge,
      'iconTileMedium': WidgetTokens.iconTileMedium,
      'iconTileLarge': WidgetTokens.iconTileLarge,
      'iconEmptySmall': WidgetTokens.iconEmptySmall,
      'iconEmptyMedium': WidgetTokens.iconEmptyMedium,
      'iconEmptyLarge': WidgetTokens.iconEmptyLarge,
      'iconSocialMedium': WidgetTokens.iconSocialMedium,
      'headerHeight': WidgetTokens.headerHeight,
      'headerGap': WidgetTokens.headerGap,
      'logoHeight': WidgetTokens.logoHeight,
      'logoHeightEvents': WidgetTokens.logoHeightEvents,
      'logoOpacity': WidgetTokens.logoOpacity,
      'rowTimetableMedium': WidgetTokens.rowTimetableMedium,
      'rowTimetableLarge': WidgetTokens.rowTimetableLarge,
      'rowSocialLarge': WidgetTokens.rowSocialLarge,
      'badgeEventLargeWidth': WidgetTokens.badgeEventLargeWidth,
      'badgeEventLargeHeight': WidgetTokens.badgeEventLargeHeight,
      'badgeTimetableWidth': WidgetTokens.badgeTimetableWidth,
      'pillHeight': WidgetTokens.pillHeight,
      'pillPaddingX': WidgetTokens.pillPaddingX,
      'kcalChipHeight': WidgetTokens.kcalChipHeight,
      'barHeight': WidgetTokens.barHeight,
      'tileGap': WidgetTokens.tileGap,
      'opacityPastLesson': WidgetTokens.opacityPastLesson,
      'opacityNonLeaderBar': WidgetTokens.opacityNonLeaderBar,
      // Boyuta gore icerik sayilari
      'menuSmallMainLines': WidgetLayouts.menuSmallMainLines.toDouble(),
      'menuMediumDishes': WidgetLayouts.menuMediumDishes.toDouble(),
      'menuLargeDishes': WidgetLayouts.menuLargeDishes.toDouble(),
      'menuLargeDishesSingleMeal': WidgetLayouts.menuLargeDishesSingleMeal.toDouble(),
      'timetableSmallTitleLines': WidgetLayouts.timetableSmallTitleLines.toDouble(),
      'timetableMediumRows': WidgetLayouts.timetableMediumRows.toDouble(),
      'timetableLargeRows': WidgetLayouts.timetableLargeRows.toDouble(),
      'eventsSmall': WidgetLayouts.eventsSmall.toDouble(),
      'eventsMedium': WidgetLayouts.eventsMedium.toDouble(),
      'eventsLarge': WidgetLayouts.eventsLarge.toDouble(),
      'announcementsSmall': WidgetLayouts.announcementsSmall.toDouble(),
      'announcementsMedium': WidgetLayouts.announcementsMedium.toDouble(),
      'announcementsLarge': WidgetLayouts.announcementsLarge.toDouble(),
      'announcementsSmallTitleLines': WidgetLayouts.announcementsSmallTitleLines.toDouble(),
      'announcementsLargeTitleLines': WidgetLayouts.announcementsLargeTitleLines.toDouble(),
      'pollSmallQuestionLines': WidgetLayouts.pollSmallQuestionLines.toDouble(),
      'pollMediumQuestionLines': WidgetLayouts.pollMediumQuestionLines.toDouble(),
      'pollMediumOptions': WidgetLayouts.pollMediumOptions.toDouble(),
      'pollLargeQuestionLines': WidgetLayouts.pollLargeQuestionLines.toDouble(),
      'pollLargeOptionsMax': WidgetLayouts.pollLargeOptionsMax.toDouble(),
      'quickSmallTiles': WidgetLayouts.quickSmallTiles.toDouble(),
      'quickMediumTiles': WidgetLayouts.quickMediumTiles.toDouble(),
      'quickLargeTiles': WidgetLayouts.quickLargeTiles.toDouble(),
      'socialMediumColumns': WidgetLayouts.socialMediumColumns.toDouble(),
      'socialLargeRows': WidgetLayouts.socialLargeRows.toDouble(),
    };

    test('Swift ve Kotlin sabitleri Dart ile ayni', () {
      for (final e in scalars.entries) {
        final sm = RegExp('static let ${e.key}\\b[^=\\n]*=\\s*(-?[0-9.]+)').firstMatch(swift);
        expect(sm, isNotNull, reason: 'Swift ${e.key}');
        expect(double.parse(sm!.group(1)!), e.value, reason: 'Swift ${e.key}');
        final km = RegExp('const val ${upperSnake(e.key)}\\s*=\\s*(-?[0-9.]+)f?').firstMatch(kotlin);
        expect(km, isNotNull, reason: 'Kotlin ${upperSnake(e.key)}');
        expect(double.parse(km!.group(1)!), e.value, reason: 'Kotlin ${e.key}');
      }
    });

    test('kabuk: yuzeyler belge tablosuyla ayni, kose iOS 22 / Android 28', () {
      for (final s in WidgetTokens.surfaces) {
        final label = s.platform == 'ios' ? s.name : s.name;
        final row = RegExp('\\| ${s.platform == 'ios' ? 'iOS' : 'Android'} \\| ${label.replaceAll('x', 'x')}(?: \\(\\w+\\))? \\| ${s.width.toInt()}x${s.height.toInt()} \\| ${s.corner.toInt()} \\| 16 \\| 1 \\|').hasMatch(md);
        expect(row, isTrue, reason: '${s.platform} ${s.name}');
      }
      expect(WidgetTokens.cornerIos, 22);
      expect(WidgetTokens.cornerAndroid, 28);
      expect(swift, contains('cornerRadius: CGFloat = 22'));
      expect(kotlin, contains('CORNER_RADIUS = 28'));
      for (final s in WidgetTokens.surfaces) {
        final w = s.platform == 'ios' ? 'sizeSmall|sizeMedium|sizeLarge' : '';
        if (w.isNotEmpty) {
          expect(swift, contains('CGSize(width: ${s.width.toInt()}, height: ${s.height.toInt()})'), reason: s.name);
        } else {
          final tag = s.name.toUpperCase();
          expect(kotlin, contains('SIZE_${tag}_W = ${s.width.toInt()}'), reason: s.name);
          expect(kotlin, contains('SIZE_${tag}_H = ${s.height.toInt()}'), reason: s.name);
        }
      }
    });

    test('bosluk olcegi yalniz 2,4,6,8,10,12,14,16', () {
      expect(WidgetTokens.spacingScale, [2, 4, 6, 8, 10, 12, 14, 16]);
    });
  });

  group('sozlesme sabitleri', () {
    test('depo anahtarlari ve App Group her uc yerde ayni', () {
      const keys = {
        'keyMeta': 'bu_widget_meta',
        'keyMenu': 'bu_widget_menu',
        'keyTimetable': 'bu_widget_timetable',
        'keyEvents': 'bu_widget_events',
        'keyAnnouncements': 'bu_widget_announcements',
        'keyPoll': 'bu_widget_poll',
        'keyQuickAccess': 'bu_widget_quickaccess',
        'keySocial': 'bu_widget_social',
        'keyExams': 'bu_widget_exams',
        'keyAcademic': 'bu_widget_academic',
      };
      final contract = read('../design/widget-previews/DATA_CONTRACT.md');
      for (final e in keys.entries) {
        expect(swift, contains('static let ${e.key} = "${e.value}"'), reason: e.key);
        expect(kotlin, contains('${upperSnake(e.key)} = "${e.value}"'), reason: e.key);
        expect(contract, contains('`${e.value}`'), reason: e.key);
      }
      expect(swift, contains('"group.tr.com.bukampus.app"'));
      expect(read('lib/features/widgets/widget_store.dart'), contains("'group.tr.com.bukampus.app'"));
      expect(kotlin, contains('"HomeWidgetPreferences"'));
      expect(swift, contains('urlScheme = "bukampus"'));
      expect(kotlin, contains('URL_SCHEME = "bukampus"'));
    });

    test('bukampus:// sema iki platformda kayitli', () {
      expect(read('ios/Runner/Info.plist'), contains('<string>bukampus</string>'));
      expect(read('android/app/src/main/AndroidManifest.xml'), contains('android:scheme="bukampus"'));
    });
  });
}
