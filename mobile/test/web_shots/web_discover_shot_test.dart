import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// Tanitim sitesi (web) icin GERCEK Kesfet ekrani goruntusu: uydurma, kampus temali icerik (gercek kisi/fotograf yok).
/// Uretim: WEB_OUT=C:/bu_store/web flutter test test/web_shots/web_discover_shot_test.dart
/// Cikti: <WEB_OUT>/discover-<light|dark>.png (393x852 dp x 3 = 1179x2556)
const _dpr = 3.0;
const _w = 393.0;
const _h = 852.0;

class _Ov extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => StoreImageHttpClient();
}

void main() {
  HttpOverrides.global = _Ov();
  final out = Platform.environment['WEB_OUT'];
  final skip = out == null ? 'WEB_OUT tanimli degil' : null;

  setUpAll(loadTestFonts);

  for (final dark in [false, true]) {
    final name = dark ? 'dark' : 'light';
    testWidgets('web discover $name', skip: skip != null, (tester) async {
      debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = const Size(_w * _dpr, _h * _dpr);
      tester.view.padding = const FakeViewPadding(top: 44 * _dpr, bottom: 20 * _dpr);
      tester.view.viewPadding = const FakeViewPadding(top: 44 * _dpr, bottom: 20 * _dpr);
      addTearDown(tester.view.reset);

      final b = FakeBackend();
      const heights = [1350, 1080, 1620, 1350, 1080, 1480, 1350, 1620, 1080, 1350, 1480, 1080];
      final items = [
        for (var i = 0; i < heights.length; i++)
          samplePost(
            id: 500 - i,
            text: null,
            media: [samplePostMedia(id: (500 - i) * 10, height: heights[i], video: i == 2 || i == 7)],
            likeCount: 12 + (i * 17) % 90,
            commentCount: 2 + i % 6,
            authorName: const ['Elif D.', 'Mert K.', 'Selin A.', 'Can Y.', 'Derya T.', 'Emre S.'][i % 6],
          ),
      ];
      b.on('/feed*', {'items': items, 'nextCursor': null});
      b.on('/feed/seen', null, status: 204);
      b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
      LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
      addTearDown(() => LocaleController.current = null);

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BuTheme.forLocale(Brightness.light, 'tr'),
          darkTheme: BuTheme.forLocale(Brightness.dark, 'tr'),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('tr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null))),
        ),
      ));
      await settle(tester, const Duration(milliseconds: 1500));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
        await tester.pump(const Duration(milliseconds: 400));
      }
      final err = tester.takeException();
      if (err != null) fail('Istisna: $err');
      await tester.runAsync(() async {
        final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await ro.toImage(pixelRatio: _dpr);
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        Directory(out!).createSync(recursive: true);
        File('$out/discover-$name.png').writeAsBytesSync(data.buffer.asUint8List());
      });
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });
  }
}
