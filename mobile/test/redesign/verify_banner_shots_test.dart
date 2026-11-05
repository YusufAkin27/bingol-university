@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Profil "E-postanızı doğrulayın" kartı + kod sayfası ekran görüntüleri.
/// Üretim: VB_OUT='C:/bu_qa/shots/verify_banner' flutter test test/redesign/verify_banner_shots_test.dart
/// İsteğe bağlı: VB_LANG=tr,ar
void main() {
  final out = Platform.environment['VB_OUT'];
  final langs = (Platform.environment['VB_LANG'] ?? 'tr,ar').split(',');
  const dpr = 2.0;
  setUpAll(loadTestFonts);
  var curLang = 'tr';

  final cases = <String, Future<void> Function(WidgetTester t, FakeBackend b)>{
    'kart': (t, b) async {},
    'kod_sayfasi': (t, b) async {
      await t.tap(find.byType(BuButton));
      await settle(t, const Duration(milliseconds: 900));
    },
    'kod_hata': (t, b) async {
      await t.tap(find.byType(BuButton));
      await settle(t, const Duration(milliseconds: 900));
      await t.enterText(find.byType(TextField), '000000');
      await t.pump(const Duration(milliseconds: 700));
    },
    'kota_bilgisi': (t, b) async {
      await t.tap(find.byType(BuButton));
      await settle(t, const Duration(milliseconds: 900));
      await t.tap(find.text(lookupAppLocalizations(Locale(curLang)).authResendCode));
      await t.pump(const Duration(milliseconds: 500));
    },
  };

  for (final lang in langs) {
    for (final dark in [false, true]) {
      for (final size in const [Size(390, 844), Size(320, 640)]) {
        for (final e in cases.entries) {
          testWidgets('vb ${e.key} ${dark ? 'koyu' : 'acik'} $lang ${size.width.toInt()}', skip: out == null, (tester) async {
            tester.view.devicePixelRatio = dpr;
            tester.view.physicalSize = Size(size.width * dpr, size.height * dpr);
            addTearDown(tester.view.reset);
            final b = FakeBackend()
              ..on('/me/summary', {'communities': 2, 'events': 3, 'bookmarks': 5})
              ..on('/users/me', {
                'id': 1,
                'email': 'ayse@bingol.edu.tr',
                'displayName': 'Ayşe Yılmaz',
                'faculty': 'Mühendislik Fakültesi',
                'department': 'Bilgisayar Mühendisliği',
                'grade': '3',
                'role': 'USER',
                'postCount': 0,
                'reelCount': 0,
                'emailVerified': false,
                'verificationDeferred': true,
              })
              ..on('/users/1', {'id': 1, 'followerCount': 12, 'followingCount': 8, 'followedByMe': false})
              ..fail('/auth/verification/verify', status: 400, code: 'INVALID_CODE', message: lang == 'ar' ? 'الرمز غير صحيح.' : 'Kod hatalı.')
              ..fail('/auth/verification/resend', status: 429, code: 'MAIL_QUOTA_EXCEEDED');
            fakeCatalog(b);
            fakePosts(b, count: 0, empty: true);
            curLang = lang;
            LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
            addTearDown(() => LocaleController.current = null);
            final key = GlobalKey();
            await tester.pumpWidget(RepaintBoundary(
              key: key,
              child: MaterialApp(
                navigatorKey: rootNavigatorKey,
                debugShowCheckedModeBanner: false,
                theme: BuTheme.forLocale(Brightness.light, lang),
                darkTheme: BuTheme.forLocale(Brightness.dark, lang),
                themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                locale: Locale(lang),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) =>
                    MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(size.width < 330 ? 1.3 : 1.0)), child: child!),
                home: ProfileTab(session: makeSession(b), themeController: ThemeController()),
              ),
            ));
            await settle(tester, const Duration(milliseconds: 1400));
            await e.value(tester, b);
            await settle(tester, const Duration(milliseconds: 500));
            final err = tester.takeException();
            if (err != null) fail('Istisna: $err');
            await tester.runAsync(() async {
              final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
              final image = await ro.toImage(pixelRatio: dpr);
              final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
              final dir = Directory(out!)..createSync(recursive: true);
              File('${dir.path}/${e.key}${dark ? '_koyu' : ''}_${lang}_${size.width.toInt()}.png').writeAsBytesSync(data.buffer.asUint8List());
            });
            await unmount(tester);
          });
        }
      }
    }
  }
}
