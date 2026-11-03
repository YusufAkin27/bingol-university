import 'package:bu_kampus/core/pin.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/widgets/pin_field.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Gerçek yerelleştirme temsilcileriyle (tr/ar) sarmalayıcı; ölçek ve boyut ayarlanabilir.
Widget _app(Widget child, {String lang = 'tr', bool dark = false, double scale = 1.0, Size size = kPhoneMedium}) => MaterialApp(
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
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: SingleChildScrollView(child: child))),
    );

void main() {
  setUpAll(loadTestFonts);

  group('PIN kuralı (sunucuyla aynı)', () {
    test('tam 6 rakam gerekir', () {
      expect(isPinFormat('481952'), isTrue);
      expect(isPinFormat('48195'), isFalse);
      expect(isPinFormat('4819520'), isFalse);
      expect(isPinFormat('48195a'), isFalse);
      expect(isPinFormat(''), isFalse);
      expect(isPinFormat('٤٨١٩٥٢'), isFalse); // Arapça-Hint rakamlar sunucuya gitmesin
    });

    test('zayıf PIN: tüm aynı, düz artan/azalan, iki rakamlı tekrar', () {
      for (final w in ['000000', '111111', '999999', '123456', '234567', '345678', '456789', '654321', '987654', '543210', '121212', '909090', '565656']) {
        expect(isWeakPin(w), isTrue, reason: w);
        expect(checkNewPin(w), PinCheck.weak, reason: w);
      }
      for (final ok in ['481952', '739204', '120120', '112233', '135791', '123450', '102030']) {
        expect(isWeakPin(ok), isFalse, reason: ok);
        expect(checkNewPin(ok), PinCheck.ok, reason: ok);
      }
      expect(checkNewPin('12345'), PinCheck.format);
    });
  });

  group('PinField', () {
    testWidgets('yalnız rakam kabul eder ve 6 ile sınırlar; rakam klavyesi', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(PinField(controller: c)));
      await tester.enterText(find.byType(TextFormField), '4a8-1 9b5278');
      await tester.pump();
      expect(c.text, '481952');
      expect(tester.widget<TextField>(find.byType(TextField)).keyboardType, TextInputType.number);
      expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
      await tester.enterText(find.byType(TextFormField), '12');
      await tester.pump();
      expect(c.text, '12');
    });

    testWidgets('6. rakamda onCompleted bir kez çağrılır; eksikte çağrılmaz', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      final done = <String>[];
      await tester.pumpWidget(_app(PinField(controller: c, onCompleted: done.add)));
      await tester.enterText(find.byType(TextFormField), '48195');
      await tester.pump();
      expect(done, isEmpty);
      await tester.enterText(find.byType(TextFormField), '481952');
      await tester.pump();
      expect(done, ['481952']);
    });

    testWidgets('göz düğmesi rakamları gösterir/gizler (48 dp hedef)', (tester) async {
      final c = TextEditingController(text: '481952');
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(PinField(controller: c)));
      await tester.pump();
      expect(find.text('4'), findsNothing);
      final eye = find.byType(IconButton);
      final r = tester.getRect(eye);
      expect(r.width, greaterThanOrEqualTo(48));
      expect(r.height, greaterThanOrEqualTo(48));
      await tester.tap(eye);
      await tester.pump(const Duration(milliseconds: 300));
      for (final d in ['4', '8', '1', '9', '5', '2']) {
        expect(find.text(d), findsOneWidget, reason: d);
      }
      await tester.tap(eye);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('4'), findsNothing);
    });

    testWidgets('semantics: tek alan, rakamlar sesli okunmaz', (tester) async {
      final h = tester.ensureSemantics();
      final c = TextEditingController(text: '481');
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(PinField(controller: c, label: 'Yeni şifre')));
      await tester.pump();
      expect(find.bySemanticsLabel('Yeni şifre, 6 haneli, 3 hane girildi'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('481')), findsNothing);
      h.dispose();
    });

    testWidgets('doğrulayıcı hatası gösterilir (Form), düzeltince kalkar', (tester) async {
      final c = TextEditingController();
      final form = GlobalKey<FormState>();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(Form(
        key: form,
        child: PinField(controller: c, validator: (v) => isPinFormat(v ?? '') ? null : 'Şifre 6 haneli rakamlardan oluşmalı.'),
      )));
      await tester.enterText(find.byType(TextFormField), '48');
      expect(form.currentState!.validate(), isFalse);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Şifre 6 haneli rakamlardan oluşmalı.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '481952');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Şifre 6 haneli rakamlardan oluşmalı.'), findsNothing);
    });

    testWidgets('pasif alan girişe kapalıdır', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(PinField(controller: c, enabled: false)));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    for (final lang in ['tr', 'ar']) {
      for (final dark in [false, true]) {
        for (final w in [320.0, 390.0]) {
          for (final scale in [1.0, 1.3]) {
            testWidgets('taşma yok | $lang ${dark ? 'koyu' : 'açık'} ${w.toInt()} x$scale', (tester) async {
              final size = Size(w, 700);
              useScreen(tester, size);
              final c = TextEditingController(text: '481952');
              addTearDown(c.dispose);
              await tester.pumpWidget(_app(
                Column(children: [
                  PinField(controller: c, label: 'Yeni şifre'),
                  PinField(controller: TextEditingController(text: '4'), invalid: true),
                ]),
                lang: lang,
                dark: dark,
                scale: scale,
                size: size,
              ));
              await tester.pump(const Duration(milliseconds: 400));
              // Rakamlar açıkken en geniş durum.
              await tester.tap(find.byType(IconButton).first);
              await tester.pump(const Duration(milliseconds: 400));
              expect(tester.takeException(), isNull);
              final r = tester.getRect(find.byType(PinField).first);
              expect(r.right, lessThanOrEqualTo(w));
              expect(r.left, greaterThanOrEqualTo(0));
            });
          }
        }
      }
    }
  });
}
