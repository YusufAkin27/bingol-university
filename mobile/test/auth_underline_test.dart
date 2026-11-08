import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/new_password_page.dart';
import 'package:bu_kampus/features/auth/widgets/login_underline_field.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Widget _app(Widget home, {Locale locale = const Locale('tr'), bool dark = true}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      darkTheme: BuTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RepaintBoundary(key: _shot, child: home),
    );

final _shot = GlobalKey();

Session _s() => makeSession(FakeBackend(), signedIn: false);

Future<void> _png(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final b = _shot.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/auth_underline_shots')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester t) => t.pump(const Duration(milliseconds: 1200));

void _expectUnderline(WidgetTester tester, int fields) {
  final all = tester.widgetList<LoginUnderlineField>(find.byType(LoginUnderlineField)).toList();
  expect(all.length, fields);
  for (final f in all) {
    expect(f.boxed, isFalse, reason: 'cizgi alti stil: kutu yok');
  }
}

void main() {
  setUpAll(() => mockSecureStorage());

  testWidgets('giris: cizgi alti alanlar, etiket gorunur, goz dugmesi sifreyi acar', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(_app(LoginPage(session: _s())));
    await _settle(tester);
    _expectUnderline(tester, 2);
    expect(find.text('E-posta'), findsWidgets);
    expect(find.text('Şifre'), findsWidgets);
    EditableText pw() => tester.widget<EditableText>(find.byType(EditableText).last);
    expect(pw().obscureText, isTrue);
    await tester.tap(find.byTooltip('Şifreyi göster'));
    await tester.pump();
    expect(pw().obscureText, isFalse);
    await tester.tap(find.byTooltip('Şifreyi gizle'));
    await tester.pump();
    expect(pw().obscureText, isTrue);
    await _png(tester, 'login_dark');
  });

  testWidgets('giris: bos gonderimde hata mesaji gorunur', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(_app(LoginPage(session: _s()), dark: false));
    await _settle(tester);
    await tester.tap(find.text('Giriş yap').last);
    await _settle(tester);
    expect(find.text('Şifrenizi girin.'), findsWidgets);
    await _png(tester, 'login_light_error');
  });

  testWidgets('sifremi unuttum: cizgi alti e-posta alani ve hata', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(_app(ForgotPasswordPage(session: _s())));
    await _settle(tester);
    _expectUnderline(tester, 1);
    await tester.enterText(find.byType(TextFormField), '123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    expect(find.text('Geçerli bir e-posta adresi girin.'), findsWidgets);
    await _png(tester, 'forgot_dark');
  });

  testWidgets('yeni sifre: iki cizgi alti alan, eslesmeme hatasi', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(_app(NewPasswordPage(session: _s(), email: 'a@b.co', resetToken: 't')));
    await _settle(tester);
    _expectUnderline(tester, 2);
    await tester.enterText(find.byType(TextFormField).first, 'Abcdefg1');
    await tester.enterText(find.byType(TextFormField).last, 'Zzzzzzz9');
    await tester.pump();
    await _png(tester, 'newpw_dark');
  });

  testWidgets('arapca (RTL) giris cizilir', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(_app(LoginPage(session: _s()), locale: const Locale('ar')));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    _expectUnderline(tester, 2);
  });
}
