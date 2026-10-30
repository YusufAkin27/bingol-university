@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/features/chat/chatlist_widgets.dart';
import 'package:bu_kampus/features/shell/floating_nav.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// N4 ekran goruntuleri: yeni yuzen cam alt gezinme + varsayilan profil gorseli.
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (C:\bu_mobile icinde, Git Bash):
///   N4_OUT='C:/Users/.../redesign/n4' flutter test test/redesign/n4_shots_test.dart
/// Istege bagli: `N4_LANG=tr|ar`, `N4_MODES=light,dark,x13,dark_x13`.
const _dpr = 2.5;

Widget _app(Widget home, bool dark, double scale, String lang, GlobalKey key) => RepaintBoundary(
      key: key,
      child: MaterialApp(
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    );

/// Gezinmenin arkasinda kayan sahte icerik (cam/bulaniklik gorunsun diye renkli kartlar).
Widget _backdrop(BuildContext context) {
  final t = context.bu;
  return Container(
    color: t.bg,
    child: Row(children: [
      for (var i = 0; i < 6; i++)
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(4, 14, 4, 40),
            decoration: BoxDecoration(color: t.tint(i).bg, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.bottomCenter,
            child: Container(height: 30, color: t.tint(i).fg.withValues(alpha: .5)),
          ),
        ),
    ]),
  );
}

Widget _row(BuildContext context, int idx, ValueNotifier<int> badge, {ValueNotifier<String?>? url, String name = 'Elif Yıldız'}) {
  return SizedBox(
    height: 118,
    child: Stack(children: [
      Positioned.fill(child: _backdrop(context)),
      Align(
        alignment: Alignment.bottomCenter,
        child: FloatingNav(index: idx, onChanged: (_) {}, chatBadge: badge, avatarUrl: url, avatarName: name),
      ),
    ]),
  );
}

Widget _navSheet() => Builder(builder: (context) {
      final badge = ValueNotifier<int>(7);
      final none = ValueNotifier<int>(0);
      final photo = ValueNotifier<String?>('/files/avatars/me.jpg');
      return Scaffold(
        body: ListView(physics: const NeverScrollableScrollPhysics(), children: [
          for (var i = 0; i < 5; i++) _row(context, i, i == 2 ? none : badge, url: i == 4 ? photo : null),
          // Profil secili degil + fotografli; rozetli (sohbet secili degil).
          _row(context, 0, badge, url: photo),
          _row(context, 4, none, url: null),
          _row(context, 3, ValueNotifier<int>(150), url: null, name: 'Kerem Aksoy'),
        ]),
      );
    });

Widget _avatarSheet() => Builder(builder: (context) {
      final t = context.bu;
      Widget tile(double size, int v, {bool group = false, bool square = false}) => Padding(
            padding: const EdgeInsets.all(5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(square ? size * .34 : size),
              child: BuDefaultAvatar(size: size, variant: v, group: group),
            ),
          );
      Widget line(String label, double size, {bool group = false, bool square = false}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 40, child: Text(label, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.mut))),
              for (var v = 0; v < BuDefaultAvatar.variantCount; v++) tile(size, v, group: group, square: square),
            ]),
          );
      return Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(8), children: [
            line('24', 24),
            line('36', 36),
            line('44', 44),
            line('52 sq', 52, square: true),
            line('72', 72),
            line('grp 36', 36, group: true),
            line('grp 52', 52, group: true, square: true),
            line('grp 72', 72, group: true),
            const SizedBox(height: 8),
            // Gercek bilesenler: sohbet listesi avatari + BuAvatar (foto yok) + kisi-ad varyanti.
            Row(children: [
              for (final n in ['Elif Yıldız', 'Mehmet Demir', 'Zeynep Kaya', 'Burak Şahin', 'Ayşe Nur', 'Emre'])
                Padding(padding: const EdgeInsets.all(5), child: ChatlistAvatar(name: n, size: 44, circle: true)),
            ]),
            Row(children: [
              for (final n in ['Elif Yıldız', 'Mehmet Demir', 'Zeynep Kaya', 'Burak Şahin', 'Ayşe Nur', 'Emre'])
                Padding(padding: const EdgeInsets.all(5), child: BuAvatar(name: n, size: 44, online: n == 'Emre')),
            ]),
          ]),
        ),
      );
    });

Future<void> _snap(WidgetTester tester, GlobalKey key, String out, String name) async {
  await tester.runAsync(() async {
    final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await ro.toImage(pixelRatio: _dpr);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final dir = Directory(out)..createSync(recursive: true);
    final f = File('${dir.path}/$name.png')..writeAsBytesSync(data.buffer.asUint8List());
    // ignore: avoid_print
    print('YAZILDI ${f.path} ${image.width}x${image.height}');
  });
  debugDisableShadows = true; // test gövdesi bitmeden geri al (flutter_test degismezi)
}

Future<void> _fonts(bool arabic) async {
  if (!arabic) return loadTestFonts();
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
  await loadIconFonts();
}

void main() {
  final out = Platform.environment['N4_OUT'];
  final skip = out == null ? 'N4_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  final lang = Platform.environment['N4_LANG'] ?? 'tr';
  final modes = (Platform.environment['N4_MODES'] ?? 'light').split(',');

  setUpAll(() => _fonts(lang == 'ar'));
  setUp(() => debugDisableShadows = false); // gercek bulanik golge

  for (final m in modes) {
    final dark = m.startsWith('dark');
    final scale = m.endsWith('x13') ? 1.3 : 1.0;
    final suffix = '${dark ? 'koyu' : 'acik'}_x${scale == 1 ? '1.0' : '1.3'}_$lang';

    testWidgets('n4 alt gezinme $suffix', skip: skip != null, (tester) async {
      debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = const Size(390 * _dpr, 118.0 * 8 * _dpr);
      addTearDown(tester.view.reset);
      LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
      addTearDown(() => LocaleController.current = null);
      final key = GlobalKey();
      await tester.pumpWidget(_app(_navSheet(), dark, scale, lang, key));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      await _snap(tester, key, out!, 'nav_$suffix');
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('n4 kayma ortasi $suffix', skip: skip != null, (tester) async {
      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = const Size(390 * _dpr, 118.0 * _dpr);
      addTearDown(tester.view.reset);
      LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
      addTearDown(() => LocaleController.current = null);
      final key = GlobalKey();
      final idx = ValueNotifier<int>(0);
      final badge = ValueNotifier<int>(3);
      await tester.pumpWidget(_app(
        Scaffold(
          body: Builder(
            builder: (context) => ValueListenableBuilder<int>(
              valueListenable: idx,
              builder: (_, i, __) => Stack(children: [
                Positioned.fill(child: _backdrop(context)),
                Align(alignment: Alignment.bottomCenter, child: FloatingNav(index: i, onChanged: (v) => idx.value = v, chatBadge: badge)),
              ]),
            ),
          ),
        ),
        dark,
        scale,
        lang,
        key,
      ));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('nav-3')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      await _snap(tester, key, out!, 'kayma_ortasi_$suffix');
      await tester.pump(const Duration(milliseconds: 500));
      await unmount(tester);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('n4 varsayilan avatar ${dark ? 'koyu' : 'acik'}', skip: skip != null, (tester) async {
      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = const Size(390 * _dpr, 780 * _dpr);
      addTearDown(tester.view.reset);
      LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
      addTearDown(() => LocaleController.current = null);
      final key = GlobalKey();
      await tester.pumpWidget(_app(_avatarSheet(), dark, 1, lang, key));
      await settle(tester, const Duration(milliseconds: 400));
      await _snap(tester, key, out!, 'varsayilan_avatar_${dark ? 'koyu' : 'acik'}');
      await unmount(tester);
    });
  }
}
