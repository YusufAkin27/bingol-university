import 'dart:typed_data';

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/media_crop/avatar_editor_page.dart';
import 'package:bu_kampus/features/media_crop/crop_spec.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support/fake_app.dart';

/// 600x400 renkli test görseli.
Uint8List testPng({int w = 600, int h = 400}) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgb(x, y, (x * 255 ~/ w), (y * 255 ~/ h), 160);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

Widget editorHost({
  required void Function(CropOutcome?) done,
  String lang = 'tr',
  bool dark = false,
  double scale = 1.0,
  Uint8List? bytes,
}) {
  return MaterialApp(
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
    home: Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const ValueKey('open'),
            onPressed: () async => done(await Navigator.of(c).push<CropOutcome>(
                MaterialPageRoute(fullscreenDialog: true, builder: (_) => AvatarEditorPage(bytes: bytes ?? testPng())))),
            child: const Text('ac'),
          ),
        ),
      ),
    ),
  );
}

Future<void> openEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await tester.pump(const Duration(milliseconds: 400));
}

Finder k(String key) => find.byKey(ValueKey(key));

bool enabled(WidgetTester tester, String key) => tester.widget<IconButton>(k(key)).onPressed != null;

void main() {
  setUpAll(loadTestFonts);

  testWidgets('araçlar görünür: iptal/bitti/geri al/yinele, 4 sekme, döndür/aynala/sıfırla, yakınlaştırma + açı', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(editorHost(done: (_) {}));
    await openEditor(tester);
    expect(k('avatarEdCancel'), findsOneWidget);
    expect(k('avatarEdDone'), findsOneWidget);
    expect(k('avatarEdStage'), findsOneWidget);
    expect(find.text('İptal'), findsOneWidget);
    expect(find.text('Bitti'), findsOneWidget);
    for (final t in ['crop', 'bg', 'filter', 'adjust']) {
      expect(k('avatarEdTab-$t'), findsOneWidget);
    }
    for (final id in ['avatarEdRotL', 'avatarEdRotR', 'avatarEdMirror', 'avatarEdReset', 'avatarEdZoom', 'avatarEdAngle']) {
      expect(k(id), findsOneWidget, reason: id);
    }
    expect(enabled(tester, 'avatarEdUndo'), isFalse);
    expect(enabled(tester, 'avatarEdRedo'), isFalse);
    // Dokunma hedefleri >= 48 dp.
    for (final id in ['avatarEdUndo', 'avatarEdRedo', 'avatarEdCancel', 'avatarEdDone', 'avatarEdRotL']) {
      final s = tester.getSize(k(id));
      expect(s.height, greaterThanOrEqualTo(48), reason: id);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('İptal null döndürür', (tester) async {
    useScreen(tester, kPhoneMedium);
    var called = false;
    CropOutcome? out = const CropOutcome.removed();
    await tester.pumpWidget(editorHost(done: (o) {
      called = true;
      out = o;
    }));
    await openEditor(tester);
    await tester.tap(k('avatarEdCancel'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(called, isTrue);
    expect(out, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Bitti 1024x1024 JPEG döndürür; işlem sırasında yükleniyor ve çift dokunma engeli', (tester) async {
    useScreen(tester, kPhoneMedium);
    CropOutcome? out;
    var calls = 0;
    await tester.pumpWidget(editorHost(done: (o) {
      out = o;
      calls++;
    }));
    await openEditor(tester);
    await tester.tap(k('avatarEdDone'));
    await tester.pump();
    expect(k('avatarEdBusy'), findsOneWidget);
    await tester.tap(k('avatarEdDone'), warnIfMissed: false); // ikinci dokunuş yok sayılır
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 1);
    final bytes = out!.bytes!;
    expect(bytes[0], 0xFF);
    expect(bytes[1], 0xD8);
    final dec = img.decodeJpg(bytes)!;
    expect(dec.width, 1024);
    expect(dec.height, 1024);
    // Sol üst köşe ~ görselin sol üstü (kırmızı/yeşil düşük), sağ alt köşe yüksek.
    expect(dec.getPixel(2, 2).r, lessThan(60));
    expect(dec.getPixel(1021, 1021).r, greaterThan(150));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('uzaklaştırılmış + bulanık zemin: çıktı yine 1024 kare, köşelerde dolu zemin', (tester) async {
    useScreen(tester, kPhoneMedium);
    CropOutcome? out;
    await tester.pumpWidget(editorHost(done: (o) => out = o));
    await openEditor(tester);
    await tester.tap(k('avatarEdStage'));
    await tester.pump(const Duration(milliseconds: 50));
    // çift dokunma: sığdır
    await tester.tap(k('avatarEdStage'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(k('avatarEdStage'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('×0.7'), findsOneWidget);
    await tester.tap(k('avatarEdDone'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await tester.pump(const Duration(milliseconds: 500));
    final dec = img.decodeJpg(out!.bytes!)!;
    expect(dec.width, 1024);
    // Üst orta: görsel dışı (bulanık zemin) -> opak
    expect(dec.getPixel(512, 4).a, 255);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('geri al / yinele: döndürme sonrası etkinleşir ve geri alınır', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(editorHost(done: (_) {}));
    await openEditor(tester);
    await tester.tap(k('avatarEdRotR'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(enabled(tester, 'avatarEdUndo'), isTrue);
    expect(enabled(tester, 'avatarEdRedo'), isFalse);
    await tester.tap(k('avatarEdMirror'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(k('avatarEdUndo'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(enabled(tester, 'avatarEdRedo'), isTrue);
    await tester.tap(k('avatarEdUndo'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(enabled(tester, 'avatarEdUndo'), isFalse);
    await tester.tap(k('avatarEdRedo'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(enabled(tester, 'avatarEdUndo'), isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('sürükleme/çimdik hata vermez; sekmeler: zemin, filtre, ayarla', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(editorHost(done: (_) {}));
    await openEditor(tester);
    await tester.drag(k('avatarEdStage'), const Offset(60, 30));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    // Zemin
    await tester.tap(k('avatarEdTab-bg'));
    await tester.pump(const Duration(milliseconds: 300));
    for (final b in ['blur', 'white', 'black', 'brand', 'navy', 'sand']) {
      expect(k('avatarEdBg-$b'), findsOneWidget);
    }
    await tester.tap(k('avatarEdBg-white'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(enabled(tester, 'avatarEdUndo'), isTrue);
    // Filtre
    await tester.tap(k('avatarEdTab-filter'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Orijinal'), findsOneWidget);
    expect(find.text('Canlı'), findsOneWidget);
    expect(find.text('Siyah-beyaz'), findsOneWidget);
    await tester.tap(k('avatarEdFilter-vivid'));
    await tester.pump(const Duration(milliseconds: 300));
    // Ayarla
    await tester.tap(k('avatarEdTab-adjust'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(k('avatarEdAdj-brightness'), findsOneWidget);
    // Çipler yatay kaydırılır (hepsi aynı anda sığmaz): sonuncuya kadar kaydır.
    await tester.scrollUntilVisible(k('avatarEdAdj-vignette'), 120,
        scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
    expect(k('avatarEdAdj-vignette'), findsOneWidget);
    await tester.drag(k('avatarEdAdjSlider'), const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    // Ayarlar sıfırlanabilir
    await tester.tap(k('avatarEdAdjReset'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('bozuk görsel: hata görünür, kapatılabilir', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(editorHost(done: (_) {}, bytes: Uint8List.fromList([1, 2, 3, 4])));
    await openEditor(tester);
    expect(find.byKey(const ValueKey('cropError')), findsOneWidget);
    await tester.tap(k('avatarEdCancel'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AvatarEditorPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final lang in ['tr', 'ar']) {
    for (final dark in [false, true]) {
      for (final size in [kPhoneSmall, kPhoneMedium]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets('taşma yok | $lang ${dark ? 'koyu' : 'açık'} ${size.width.toInt()} x$scale (4 sekme)', (tester) async {
            useScreen(tester, size);
            await tester.pumpWidget(editorHost(done: (_) {}, lang: lang, dark: dark, scale: scale));
            await openEditor(tester);
            expect(tester.takeException(), isNull);
            for (final t in ['crop', 'bg', 'filter', 'adjust']) {
              await tester.tap(k('avatarEdTab-$t'));
              await tester.pump(const Duration(milliseconds: 300));
              expect(tester.takeException(), isNull, reason: t);
              // Bitti ve sekmeler ekran içinde.
              final r = tester.getRect(k('avatarEdDone'));
              expect(r.right, lessThanOrEqualTo(size.width + .5));
              expect(r.left, greaterThanOrEqualTo(-.5));
            }
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 1));
          });
        }
      }
    }
  }

  testWidgets('azaltılmış hareket: döndürme anında yerleşir, hata yok', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
      child: editorHost(done: (_) {}),
    ));
    await openEditor(tester);
    await tester.tap(k('avatarEdRotL'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
