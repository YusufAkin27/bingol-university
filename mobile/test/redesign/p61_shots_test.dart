import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Tur 3 (minimal) MENU: "Ayrintili tercihler" sayfasi ekran goruntusu (db_shots_test kapsamiyor).
/// Uretim: P61_OUT='C:/bu_qa/shots/tasarim/p3/bildirim/sonra' P61_W=390 P61_LANG=tr P61_MODES=light,dark,x13
///   flutter test test/redesign/p61_shots_test.dart
const _prefs = {
  'news': true,
  'announcements': true,
  'events': true,
  'communities': false,
  'messages': true,
  'quietHours': {'enabled': true, 'start': '23:00', 'end': '07:00', 'timezone': 'Europe/Istanbul'},
  'subtypes': {
    'MESSAGE_DIRECT': true,
    'MESSAGE_GROUP': true,
    'EVENT_REMINDER': true,
    'EVENT_UPDATE': true,
    'EVENT_ADMISSION': false,
    'COMMUNITY_POST': true,
    'COMMUNITY_ROLE': true,
    'COMMUNITY_JOIN': true,
  },
};

void main() {
  final out = Platform.environment['P61_OUT'];
  final lang = Platform.environment['P61_LANG'] ?? 'tr';
  final w = double.tryParse(Platform.environment['P61_W'] ?? '') ?? 390;
  final modes = (Platform.environment['P61_MODES'] ?? 'light').split(',');
  const dpr = 2.5;
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('', false, 1.0),
    if (modes.contains('dark')) ('_koyu', true, 1.0),
    if (modes.contains('x13')) ('_x1.3', false, 1.3),
  ];

  setUpAll(() async {
    if (lang != 'ar') return loadTestFonts();
    final f = FontLoader('Inter');
    for (final n in ['arial.ttf', 'arialbd.ttf']) {
      final file = File('C:/Windows/Fonts/$n');
      if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await f.load();
    await loadIconFonts();
  });

  for (final v in variants) {
    testWidgets('p61 ayrintili ${v.$1} $lang', skip: out == null, (tester) async {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(w * dpr, 900 * dpr);
      tester.view.padding = const FakeViewPadding(top: 28 * dpr, bottom: 16 * dpr);
      tester.view.viewPadding = const FakeViewPadding(top: 28 * dpr, bottom: 16 * dpr);
      addTearDown(tester.view.reset);
      LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
      addTearDown(() => LocaleController.current = null);
      final key = GlobalKey();
      final b = FakeBackend()..on('/notifications/preferences', _prefs);
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BuTheme.forLocale(Brightness.light, lang),
          darkTheme: BuTheme.forLocale(Brightness.dark, lang),
          themeMode: v.$2 ? ThemeMode.dark : ThemeMode.light,
          locale: Locale(lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(v.$3)),
            child: child!,
          ),
          home: NotificationPrefsPage(session: makeSession(b)),
        ),
      ));
      await settle(tester, const Duration(milliseconds: 1200));
      final l = lookupAppLocalizations(Locale(lang));
      await tester.ensureVisible(find.text(l.profil1Detailed));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text(l.profil1Detailed));
      await settle(tester, const Duration(milliseconds: 1200));
      await tester.runAsync(() async {
        final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await ro.toImage(pixelRatio: dpr);
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final dir = Directory(out!)..createSync(recursive: true);
        File('${dir.path}/34_ayrintili_tercihler${v.$1}_$lang.png').writeAsBytesSync(data.buffer.asUint8List());
      });
      await unmount(tester);
    });
  }
}
