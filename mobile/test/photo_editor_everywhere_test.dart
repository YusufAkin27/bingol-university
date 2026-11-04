import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/media_crop/avatar_editor_model.dart';
import 'package:bu_kampus/features/media_crop/avatar_editor_page.dart';
import 'package:bu_kampus/features/media_crop/crop_spec.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support/fake_app.dart';

/// Fotoğraf düzenleyici her sayfada: çerçeve oranı ([CropSpec]) saf geometrisi + düzenleyici arayüzü
/// (Oran sekmesi, daire/dikdörtgen maske, çıktı boyutu, yan eylemler, taşma).
Uint8List testPng({int w = 600, int h = 400}) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgb(x, y, (x * 255 ~/ w), (y * 255 ~/ h), 160);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

Widget host(CropSpec spec, void Function(CropOutcome?) done, {String lang = 'tr', bool dark = false, double scale = 1.0}) {
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
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const ValueKey('open'),
            onPressed: () async => done(await Navigator.of(c).push<CropOutcome>(
                MaterialPageRoute(fullscreenDialog: true, builder: (_) => AvatarEditorPage(bytes: testPng(), spec: spec)))),
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

Future<img.Image> finish(WidgetTester tester, CropOutcome? Function() out) async {
  await tester.tap(k('avatarEdDone'));
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
  await tester.pump(const Duration(milliseconds: 500));
  return img.decodeJpg(out()!.bytes!)!;
}

void main() {
  setUpAll(loadTestFonts);

  group('geometri: dikdörtgen çerçeve', () {
    test('çerçeve boyutu: uzun kenar 300, oran korunur', () {
      const g = AvatarGeometry(600, 400, aspect: 16 / 9);
      expect(g.frameW, 300);
      expect(g.frameH, closeTo(300 * 9 / 16, 1e-9));
      const p = AvatarGeometry(600, 400, aspect: 4 / 5);
      expect(p.frameH, 300);
      expect(p.frameW, closeTo(240, 1e-9));
      expect(const AvatarGeometry(600, 400).frameW, 300); // varsayılan kare
    });

    test('doldur/sığdır ölçekleri orana göre', () {
      const p = AvatarGeometry(600, 400, aspect: 4 / 5); // 240 x 300
      expect(p.fillScale(0), closeTo(.75, 1e-9)); // yükseklik belirleyici: 300/400
      expect(p.fitScale(0), closeTo(.4, 1e-9)); // genişlik belirleyici: 240/600
      const w = AvatarGeometry(600, 400, aspect: 16 / 9); // 300 x 168.75
      expect(w.fillScale(0), closeTo(.5, 1e-9));
      expect(w.fitScale(0), closeTo(.421875, 1e-9)); // yükseklik belirleyici: 168.75/400
    });

    test('doldurma durumunda (zoom 1) hiçbir oran/açı/ofset boşluk bırakmaz', () {
      for (final r in AvatarRatio.values) {
        for (final turns in [0, 1]) {
          for (final fine in [-30.0, 0.0, 17.0]) {
            final s0 = AvatarEditState(ratio: r, turns: turns, fine: fine);
            final g = AvatarGeometry.forState(600, 400, s0);
            for (final raw in [const Offset(500, 500), const Offset(-500, 40), const Offset(30, -500), Offset.zero]) {
              final s = s0.copyWith(offset: g.clampOffset(s0, raw));
              expect(g.hasBlank(s), isFalse, reason: '$r turns=$turns fine=$fine raw=$raw');
            }
          }
        }
      }
    });

    test('serbest oran: döndürülmüş görselin kendi oranı; 90° döndürünce tersine döner', () {
      final a = AvatarGeometry.forState(600, 400, const AvatarEditState(ratio: AvatarRatio.free));
      expect(a.aspect, closeTo(1.5, 1e-9));
      final b = AvatarGeometry.forState(600, 400, const AvatarEditState(ratio: AvatarRatio.free, turns: 1));
      expect(b.aspect, closeTo(2 / 3, 1e-9));
      // Serbest + 0°: görsel çerçeveyi tam kaplar, zoom 1'de ofset oynamaz.
      expect(a.clampOffset(const AvatarEditState(ratio: AvatarRatio.free), const Offset(40, 40)), Offset.zero);
    });

    test('çıktı boyutu ve yerleşim: uzun kenar verilir, kısa kenar orandan', () {
      const p = AvatarGeometry(600, 400, aspect: 4 / 5);
      final o = p.outputSize(1350);
      expect((o.w, o.h), (1080, 1350));
      final pl = p.placement(const AvatarEditState(), 1350);
      expect(400 * pl.scale, closeTo(1350, 1e-6)); // dikey doldurma
      expect(pl.cx, closeTo(540, 1e-9));
      expect(pl.cy, closeTo(675, 1e-9));
      const w = AvatarGeometry(600, 400, aspect: 16 / 9);
      final ow = w.outputSize(1280);
      expect(ow.w, 1280);
      expect(ow.h, 720);
    });

    test('nativeLongSide: kaynak çözünürlüğünde çerçevenin uzun kenarı', () {
      const w = AvatarGeometry(600, 400, aspect: 16 / 9);
      expect(w.nativeLongSide(const AvatarEditState(ratio: AvatarRatio.w169)), closeTo(600, 1e-6));
      expect(w.nativeLongSide(const AvatarEditState(ratio: AvatarRatio.w169, zoom: 2)), closeTo(300, 1e-6));
    });

    test('AvatarRatio.nearest', () {
      expect(AvatarRatio.nearest(null), AvatarRatio.free);
      expect(AvatarRatio.nearest(1), AvatarRatio.square);
      expect(AvatarRatio.nearest(4 / 5), AvatarRatio.p45);
      expect(AvatarRatio.nearest(3 / 4), AvatarRatio.p34);
      expect(AvatarRatio.nearest(16 / 9), AvatarRatio.w169);
      expect(AvatarRatio.nearest(1.7), AvatarRatio.w169);
    });

    test('durum eşitliği oranı da içerir (geri al/yinele ayırt eder)', () {
      expect(const AvatarEditState(), isNot(const AvatarEditState(ratio: AvatarRatio.w169)));
      final h = AvatarHistory(const AvatarEditState());
      h.push(const AvatarEditState(ratio: AvatarRatio.p45));
      expect(h.undo().ratio, AvatarRatio.square);
      expect(h.undoDepth, 0);
    });
  });

  group('düzenleyici arayüzü', () {
    testWidgets('gönderi: Oran sekmesi 5 seçenek; varsayılan 4:5 çıktı; 16:9 seçilince çıktı 16:9', (tester) async {
      useScreen(tester, kPhoneMedium);
      CropOutcome? out;
      await tester.pumpWidget(host(const CropSpec.post(), (o) => out = o));
      await openEditor(tester);
      expect(k('avatarEdTab-ratio'), findsOneWidget);
      await tester.tap(k('avatarEdTab-ratio'));
      await tester.pump(const Duration(milliseconds: 300));
      for (final r in ['free', 'square', 'p45', 'p34', 'w169']) {
        expect(k('avatarEdRatio-$r'), findsOneWidget, reason: r);
      }
      await tester.tap(k('avatarEdRatio-w169'));
      await tester.pump(const Duration(milliseconds: 400));
      final dec = await finish(tester, () => out);
      expect(dec.width / dec.height, closeTo(16 / 9, .02));
      expect(math.max(dec.width, dec.height), lessThanOrEqualTo(1350));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('gönderi varsayılanı 4:5', (tester) async {
      useScreen(tester, kPhoneMedium);
      CropOutcome? out;
      await tester.pumpWidget(host(const CropSpec.post(), (o) => out = o));
      await openEditor(tester);
      final dec = await finish(tester, () => out);
      expect(dec.width / dec.height, closeTo(.8, .01));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('gönderi: oran değişimi geri alınır', (tester) async {
      useScreen(tester, kPhoneMedium);
      CropOutcome? out;
      await tester.pumpWidget(host(const CropSpec.post(), (o) => out = o));
      await openEditor(tester);
      await tester.tap(k('avatarEdTab-ratio'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(k('avatarEdRatio-square'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(k('avatarEdUndo'));
      await tester.pump(const Duration(milliseconds: 400));
      final dec = await finish(tester, () => out);
      expect(dec.width / dec.height, closeTo(.8, .01));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('kapak: oran kilitli 16:9 (Oran sekmesi yok); "Kapağı kaldır" yan eylemi', (tester) async {
      useScreen(tester, kPhoneMedium);
      CropOutcome? out;
      await tester.pumpWidget(host(const CropSpec.cover(allowRemove: true), (o) => out = o));
      await openEditor(tester);
      expect(k('avatarEdTab-ratio'), findsNothing);
      expect(k('avatarEdRemove'), findsOneWidget);
      expect(k('avatarEdChange'), findsNothing);
      await tester.tap(k('avatarEdRemove'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(out?.removed, isTrue);
      await tester.pumpWidget(const SizedBox());

      CropOutcome? out2;
      await tester.pumpWidget(host(const CropSpec.cover(), (o) => out2 = o));
      await openEditor(tester);
      final dec = await finish(tester, () => out2);
      expect(dec.width / dec.height, closeTo(16 / 9, .02));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('gönderi: "Fotoğrafı değiştir" yan eylemi changeRequested döndürür', (tester) async {
      useScreen(tester, kPhoneMedium);
      CropOutcome? out;
      await tester.pumpWidget(host(const CropSpec.post(allowChange: true), (o) => out = o));
      await openEditor(tester);
      await tester.tap(k('avatarEdChange'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(out?.changeRequested, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sohbet: serbest oran varsayılan (görselin kendi oranı), 1:1 seçilebilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      CropOutcome? out;
      await tester.pumpWidget(host(const CropSpec.chat(), (o) => out = o));
      await openEditor(tester);
      final dec = await finish(tester, () => out);
      expect(dec.width / dec.height, closeTo(1.5, .02));
      await tester.pumpWidget(const SizedBox());

      CropOutcome? out2;
      await tester.pumpWidget(host(const CropSpec.chat(), (o) => out2 = o));
      await openEditor(tester);
      await tester.tap(k('avatarEdTab-ratio'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(k('avatarEdRatio-square'));
      await tester.pump(const Duration(milliseconds: 400));
      final sq = await finish(tester, () => out2);
      expect(sq.width, sq.height);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('logo: daire maske, oran kilitli, çıktı kare', (tester) async {
      useScreen(tester, kPhoneMedium);
      CropOutcome? out;
      await tester.pumpWidget(host(const CropSpec.logo(), (o) => out = o));
      await openEditor(tester);
      expect(k('avatarEdTab-ratio'), findsNothing);
      final dec = await finish(tester, () => out);
      expect(dec.width, dec.height);
      expect(dec.width, lessThanOrEqualTo(512));
      await tester.pumpWidget(const SizedBox());
    });
  });

  for (final lang in ['tr', 'ar']) {
    for (final dark in [false, true]) {
      for (final size in [kPhoneSmall, kPhoneMedium]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets('taşma yok | gönderi $lang ${dark ? 'koyu' : 'açık'} ${size.width.toInt()} x$scale (5 sekme)', (tester) async {
            useScreen(tester, size);
            await tester.pumpWidget(host(const CropSpec.post(allowChange: true), (_) {}, lang: lang, dark: dark, scale: scale));
            await openEditor(tester);
            expect(tester.takeException(), isNull);
            for (final t in ['crop', 'ratio', 'bg', 'filter', 'adjust']) {
              await tester.tap(k('avatarEdTab-$t'));
              await tester.pump(const Duration(milliseconds: 300));
              expect(tester.takeException(), isNull, reason: t);
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
}
