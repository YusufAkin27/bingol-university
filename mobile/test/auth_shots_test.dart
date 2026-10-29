@Tags(['auth-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/new_password_page.dart';
import 'package:bu_kampus/features/auth/permissions_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/reset_code_page.dart';
import 'package:bu_kampus/features/auth/reset_success_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:bu_kampus/features/auth/welcome_page.dart';
import 'package:bu_kampus/features/legal/legal_reaccept.dart';
import 'package:bu_kampus/features/legal/legal_reaccept_page.dart';
import 'package:bu_kampus/features/profile/legal_pages.dart';
import 'package:bu_kampus/features/system/gate_views.dart';
import 'package:bu_kampus/features/system/splash_screen.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Kimlik akisi ekran goruntuleri (AUTH1): GERCEK ekran widget'lari + sahte API, 1080x2340 PNG.
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (C:\bu_mobile icinde):
///   AUTH_SHOTS_OUT='C:/.../onceki' flutter test test/auth_shots_test.dart
/// Istege bagli: `AUTH_SHOTS_LANG=tr,en,ar`, `AUTH_SHOTS_DARK=0|1|both`, `AUTH_SHOTS_ONLY=01,05`, `AUTH_SHOTS_SCALE=1.3`.
/// Arapca: Windows'ta Arial yuklenir (testte sistem yedek yazi tipi yok); yalniz yerlesimi gormek icindir.
const _size = Size(360, 780);
const _dpr = 3.0;

class _Shot {
  const _Shot(this.file, this.build, {this.setup, this.after, this.keyboard = false});
  final String file;
  final Widget Function(FakeBackend b) build;
  final void Function(FakeBackend b)? setup;
  final Future<void> Function(WidgetTester t)? after;
  final bool keyboard;
}

Session _s(FakeBackend b) => makeSession(b, signedIn: false);

Future<void> _type(WidgetTester t, int field, String text) async {
  await t.enterText(find.byType(TextFormField).at(field), text);
  await t.pump();
}

Future<void> _pumpFor(WidgetTester t, [int ms = 500]) => settle(t, Duration(milliseconds: ms));

/// Dilden bağımsız: simgeye dokunur, açılan sayfadan ilk satırı seçer.
Future<void> _fillAcademic(WidgetTester t) async {
  Future<void> pick(IconData icon) async {
    await t.ensureVisible(find.byIcon(icon));
    await t.tap(find.byIcon(icon));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.descendant(of: find.byType(ListView), matching: find.byType(InkWell)).at(2));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
  }

  await pick(LucideIcons.graduationCap);
  await pick(LucideIcons.layers);
}

Future<void> _next(WidgetTester t) async {
  await t.tap(find.byType(FilledButton));
  await _pumpFor(t, 600);
}

final _shots = <_Shot>[
  _Shot('01_acilis', (b) => const SplashScreen()),
  _Shot('02_karsilama', (b) => WelcomePage(onLogin: () {}, onRegister: () {})),
  _Shot('03_giris', (b) => LoginPage(session: _s(b))),
  _Shot('04_giris_dolu', (b) => LoginPage(session: _s(b)), after: (t) async {
    await _type(t, 0, 'seed.ayse@bingol.edu.tr');
    await _type(t, 1, 'DevSeed-2026!');
  }),
  _Shot('05_giris_hata', (b) => LoginPage(session: _s(b)),
      setup: (b) => b.fail('/auth/login', status: 401, code: 'INVALID_CREDENTIALS', message: 'E-posta veya şifre hatalı.'),
      after: (t) async {
        await _type(t, 0, 'seed.ayse@bingol.edu.tr');
        await _type(t, 1, 'yanlis-parola');
        await t.tap(find.byType(FilledButton));
        await _pumpFor(t, 400);
      }),
  _Shot('06_giris_dogrulama_hatasi', (b) => LoginPage(session: _s(b)), after: (t) async {
    await t.tap(find.byType(FilledButton));
    await _pumpFor(t, 300);
  }),
  _Shot('07_giris_klavye', (b) => LoginPage(session: _s(b)), keyboard: true, after: (t) async {
    await t.tap(find.byType(TextFormField).at(0));
    await _type(t, 0, '210201005');
  }),
  _Shot('08_kayit_1_akademik', (b) => RegisterPage(session: _s(b)), setup: fakeCatalog),
  _Shot('09_kayit_1_secili', (b) => RegisterPage(session: _s(b)), setup: fakeCatalog, after: (t) async {
    await _fillAcademic(t);
  }),
  _Shot('10_kayit_2_kisisel', (b) => RegisterPage(session: _s(b)), setup: fakeCatalog, after: (t) async {
    await _fillAcademic(t);
    await _next(t);
  }),
  _Shot('11_kayit_3_sifre', (b) => RegisterPage(session: _s(b)), setup: fakeCatalog, after: (t) async {
    await _fillAcademic(t);
    await _next(t);
    await _type(t, 0, 'Ayşe Kaya');
    await _type(t, 1, 'seed.yeni@bingol.edu.tr');
    await _next(t);
    await _type(t, 0, 'Kampus2026');
  }),
  _Shot('12_dogrulama', (b) => VerifyCodePage(session: _s(b), email: 'seed.yeni@bingol.edu.tr')
      , after: (t) async {
    await t.enterText(find.byType(EditableText).first, '4829');
    await t.pump();
  }),
  _Shot('13_dogrulama_hata', (b) => VerifyCodePage(session: _s(b)..rememberCredentials('seed.yeni@bingol.edu.tr', 'Kampus2026'), email: 'seed.yeni@bingol.edu.tr'),
      setup: (b) => b.fail('/auth/verify-email', status: 400, code: 'INVALID_CODE', message: 'Kod geçersiz.'),
      after: (t) async {
        await t.enterText(find.byType(EditableText).first, '123456');
        await _pumpFor(t, 400);
      }),
  _Shot('14_sifremi_unuttum', (b) => ForgotPasswordPage(session: _s(b))),
  _Shot('15_sifre_kodu', (b) => ResetCodePage(session: _s(b), email: 'seed.ayse@bingol.edu.tr')),
  _Shot('16_yeni_sifre', (b) => NewPasswordPage(session: _s(b), email: 'seed.ayse@bingol.edu.tr', resetToken: 't'),
      after: (t) async {
    await _type(t, 0, 'Kampus2026');
  }),
  _Shot(
    '17_sozlesme_yeniden_onay',
    (b) => LegalReacceptPage(
      session: _s(b),
      state: const LegalReaccept([LegalItem('TERMS', 3), LegalItem('PRIVACY', 3), LegalItem('KVKK', 2)], enforced: true),
    ),
  ),
  _Shot('18_izinler', (b) => PermissionsPage(onFinished: () {})),
  _Shot('19_sozlesme_metni', (b) => LegalDocPage(session: _s(b), type: 'TERMS'), setup: (b) {
    b.on('/legal', [
      {'type': 'TERMS', 'title': 'Kullanım Koşulları'},
      {'type': 'PRIVACY', 'title': 'Gizlilik Politikası'},
    ]);
    b.on('/legal/TERMS', {
      'type': 'TERMS',
      'title': 'Kullanım Koşulları',
      'version': 3,
      'content': '# Kullanım Koşulları\n\nBu metin örnek amaçlıdır.\n\n## 1. Kapsam\n\nBÜ Kampüs, Bingöl Üniversitesi öğrenci ve personeli için sunulur.\n\n- Madde bir\n- Madde iki',
      'publishedAt': '2026-09-01T09:00:00Z',
    });
  }),
  _Shot('22_bolum_secici', (b) => RegisterPage(session: _s(b)), setup: fakeCatalog, after: (t) async {
    await t.tap(find.byIcon(LucideIcons.graduationCap));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('23_dil_secici', (b) => LoginPage(session: _s(b)), after: (t) async {
    await t.tap(find.byIcon(LucideIcons.globe));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('24_sifre_basari', (b) => const ResetSuccessPage(), after: (t) async {
    await t.pump(const Duration(milliseconds: 1000));
  }),
  _Shot('25_dogrulama_klavye', (b) => VerifyCodePage(session: _s(b)..rememberCredentials('seed.yeni@bingol.edu.tr', 'Kampus2026'), email: 'seed.yeni@bingol.edu.tr'),
      keyboard: true, after: (t) async {
    await t.enterText(find.byType(EditableText).first, '48');
    await t.pump();
  }),
  _Shot('20_cevrimdisi', (b) => OfflineScreen(onRetry: () {})),
  _Shot('21_bakim', (b) => MaintenanceScreen(onRetry: () {})),
];

Widget _app(Widget home, String lang, bool dark, GlobalKey key, double scale) {
  return RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      darkTheme: BuTheme.dark(),
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
}

Future<void> _loadFonts(bool arabic) async {
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
  final out = Platform.environment['AUTH_SHOTS_OUT'];
  final skip = out == null ? 'AUTH_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  final langs = (Platform.environment['AUTH_SHOTS_LANG'] ?? 'tr').split(',');
  final darkMode = Platform.environment['AUTH_SHOTS_DARK'] ?? '0';
  final only = (Platform.environment['AUTH_SHOTS_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final scale = double.tryParse(Platform.environment['AUTH_SHOTS_SCALE'] ?? '') ?? 1.0;
  final modes = darkMode == 'both' ? [false, true] : [darkMode == '1'];

  for (final lang in langs) {
    setUpAll(() => _loadFonts(lang == 'ar'));
    for (final dark in modes) {
      for (final shot in _shots) {
        if (only.isNotEmpty && !only.any((o) => shot.file.startsWith(o))) continue;
        final name = '${shot.file}${dark ? '_koyu' : ''}_$lang${scale != 1.0 ? '_x$scale' : ''}';
        testWidgets('ekran $name', skip: skip != null, (tester) async {
          tester.view.devicePixelRatio = _dpr;
          tester.view.physicalSize = Size(_size.width * _dpr, _size.height * _dpr);
          tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
          tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
          if (shot.keyboard) tester.view.viewInsets = const FakeViewPadding(bottom: 300 * _dpr);
          addTearDown(tester.view.reset);

          final b = FakeBackend();
          shot.setup?.call(b);
          LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
          addTearDown(() => LocaleController.current = null);
          final key = GlobalKey();
          await tester.pumpWidget(_app(shot.build(b), lang, dark, key, scale));
          await settle(tester, const Duration(milliseconds: 1800));
          if (shot.after != null) {
            await shot.after!(tester);
            await settle(tester, const Duration(milliseconds: 500));
          }
          final err = tester.takeException();
          if (err != null) fail('Istisna: $err');
          await tester.runAsync(() async {
            final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await ro.toImage(pixelRatio: _dpr);
            final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
            final dir = Directory(out!)..createSync(recursive: true);
            final f = File('${dir.path}/$name.png')..writeAsBytesSync(data.buffer.asUint8List());
            // ignore: avoid_print
            print('YAZILDI ${f.path} ${image.width}x${image.height}');
          });
          await unmount(tester);
        });
      }
    }
  }
}
