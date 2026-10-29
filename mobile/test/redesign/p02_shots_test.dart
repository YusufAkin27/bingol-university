@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/academic_catalog.dart';
import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/new_password_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/reset_code_page.dart';
import 'package:bu_kampus/features/auth/reset_success_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:bu_kampus/features/auth/welcome_page.dart';
import 'package:bu_kampus/features/profile/legal_pages.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/academic_pickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// K1 (Paket 2 kimlik + legal_pages) ekran goruntuleri: GERCEK ekranlar + sahte API, 390x844 mantiksal boyut.
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (C:\bu_mobile icinde, Git Bash):
///   K1_OUT='C:/Users/.../redesign/k1/uygulama' flutter test test/redesign/p02_shots_test.dart
/// Istege bagli: `K1_LANG=tr,en,ar`, `K1_DARK=0|1|both`, `K1_ONLY=01,05`, `K1_SCALE=1.3`.
const _w = 390.0;
const _h = 844.0;
const _dpr = 2.0;

/// Etkin dil (metin bulucular dile gore secilir).
String _lang = 'tr';
AppLocalizations get _l => lookupAppLocalizations(Locale(_lang));

class _Shot {
  const _Shot(this.file, this.build, {this.setup, this.after, this.delay});
  final String file;
  final Widget Function(FakeBackend b, Session s) build;
  final void Function(FakeBackend b, Session s)? setup;
  final Future<void> Function(WidgetTester t, Session s)? after;
  final Duration? delay;
}

const _catalog = <String, dynamic>{
  'version': 1,
  'faculties': [
    {
      'id': 'muh',
      'name': 'Mühendislik-Mimarlık Fakültesi',
      'departments': [
        {'id': 'bilgisayar', 'name': 'Bilgisayar Mühendisliği'},
        {'id': 'insaat', 'name': 'İnşaat Mühendisliği'},
      ],
    },
    {
      'id': 'fen',
      'name': 'Fen-Edebiyat Fakültesi',
      'departments': [
        {'id': 'matematik', 'name': 'Matematik'},
      ],
    },
    {
      'id': 'saglik',
      'name': 'Sağlık Bilimleri Fakültesi',
      'departments': [
        {'id': 'hemsirelik', 'name': 'Hemşirelik'},
        {'id': 'beslenme', 'name': 'Beslenme ve Diyetetik'},
      ],
    },
  ],
  'grades': [
    {'id': 'PREP', 'name': 'Hazırlık'},
    {'id': '1', 'name': '1. sınıf'},
    {'id': '2', 'name': '2. sınıf'},
    {'id': '3', 'name': '3. sınıf'},
    {'id': '4', 'name': '4. sınıf'},
    {'id': '5', 'name': '5. sınıf'},
    {'id': '6', 'name': '6. sınıf'},
    {'id': 'MASTER', 'name': 'Yüksek lisans'},
    {'id': 'PHD', 'name': 'Doktora'},
  ],
};

void _cat(FakeBackend b, Session s) => b.on('/catalog/academic', _catalog);

Future<void> _type(WidgetTester t, int field, String text) async {
  await t.enterText(find.byType(TextFormField).at(field), text);
  await t.pump();
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.tap(find.text(text).first);
  await t.pump();
  await t.pump(const Duration(milliseconds: 450));
}

Future<void> _pickDept(WidgetTester t, String row) async {
  await _tapText(t, _l.pickSelectDepartment);
  await t.pump(const Duration(milliseconds: 500));
  await t.tap(find.text(row).first);
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _step1(WidgetTester t) async {
  await _pickDept(t, 'Bilgisayar Mühendisliği');
  await _tapText(t, _l.pickSelectGrade);
  await t.tap(find.text(_l.acadGradeN('2')).last);
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _tapDevam(WidgetTester t) async {
  await t.tap(find.text(_l.authNext));
  await t.pump();
  await t.pump(const Duration(milliseconds: 450));
  await t.pump(const Duration(milliseconds: 450));
}

const _legalDocs = [
  {'type': 'TERMS', 'title': 'Kullanım Koşulları', 'version': 3, 'publishedAt': '2026-10-12T09:00:00Z'},
  {'type': 'PRIVACY', 'title': 'Gizlilik Politikası', 'version': 3, 'publishedAt': '2026-10-12T09:00:00Z'},
  {'type': 'KVKK', 'title': 'KVKK Aydınlatma Metni', 'version': 3, 'publishedAt': '2026-10-12T09:00:00Z'},
  {'type': 'COMMUNITY_RULES', 'title': 'Topluluk Kuralları', 'version': 3, 'publishedAt': '2026-10-12T09:00:00Z'},
];

const _termsBody = '''## 1. Genel Hükümler ve Amaç

İşbu Kullanım Koşulları, **BU Kampüs** bağımsız mobil uygulamasının öğrenciler ve personel tarafından kullanım şartlarını belirlemektedir. Bu metin yer tutucudur.

## 2. Üyelik ve Hesap Güvenliği

1. Uygulamaya kayıt yalnızca `bingol.edu.tr` uzantılı e-posta adresiyle yapılır.
2. Kullanıcı, hesap bilgilerinin ve doğrulama kodlarının güvenliğinden sorumludur.

## 3. Topluluk ve İçerik Kuralları

- Hakaret, nefret söylemi ve ayrımcılık içeren paylaşımlar yasaktır.
- Paylaşımlar bir fotoğraf ve kısa bir metinden oluşur.
- Spam veya reklam amaçlı gönderilere izin verilmez.

## 4. Hesap Kapatma

Kullanıcı dilediği an **Ayarlar** menüsünden hesabını silebilir.''';

final _shots = <_Shot>[
  _Shot('01_karsilama', (b, s) => WelcomePage(onLogin: () {}, onRegister: () {})),
  _Shot('02_giris_hatali_alanlar', (b, s) => LoginPage(session: s), after: (t, s) async {
    await _type(t, 0, 'ahmet.yilmaz@gmail.com');
    await t.ensureVisible(find.text(_l.loginSubmit).last);
    await t.tap(find.text(_l.loginSubmit).last);
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Shot('03a_giris_yukleniyor', (b, s) => LoginPage(session: s), delay: const Duration(seconds: 30), after: (t, s) async {
    await _type(t, 0, '226051015');
    await _type(t, 1, 'Kampus2026!!');
    await t.tap(find.text(_l.loginSubmit).last);
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Shot('03b_giris_istek_siniri', (b, s) => LoginPage(session: s),
      setup: (b, s) => b.on('/auth/login', {'code': 'TOO_MANY_REQUESTS', 'message': 'Çok fazla deneme. Lütfen biraz bekleyin.'},
          status: 429, headers: {'retry-after': '40'}),
      after: (t, s) async {
    await _type(t, 0, '226051015');
    await _type(t, 1, 'Kampus2026!!');
    await t.tap(find.text(_l.loginSubmit).last);
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('04_giris_dogrulama_bekliyor', (b, s) => LoginPage(session: s),
      setup: (b, s) => s.pending.save('ad.soyad@bingol.edu.tr'), after: (t, s) async {
    await _type(t, 0, 'ad.soyad@bingol.edu.tr');
    await _type(t, 1, 'Kampus2026!!');
  }),
  _Shot('05_giris_oturum_hata', (b, s) => LoginPage(session: s), setup: (b, s) {
    s.replacedNotice.value = true;
    b.network('/auth/login');
  }, after: (t, s) async {
    await _type(t, 0, 'ad.soyad@bingol.edu.tr');
    await _type(t, 1, 'Kampus2026!!');
    await t.tap(find.text(_l.loginSubmit).last);
    await t.pump(const Duration(milliseconds: 800));
    await t.pump(const Duration(milliseconds: 800));
  }),
  _Shot('06_kayit_1', (b, s) => RegisterPage(session: s), setup: _cat, after: (t, s) async {
    await _step1(t);
  }),
  _Shot('07_kayit_2_hata', (b, s) => RegisterPage(session: s), setup: _cat, after: (t, s) async {
    await _step1(t);
    await _tapDevam(t);
    await _type(t, 0, 'Elif Yıldız');
    await _type(t, 1, 'elif+test@bingol.edu.tr');
    await _tapDevam(t);
  }),
  _Shot('08_kayit_3', (b, s) => RegisterPage(session: s), setup: _cat, after: (t, s) async {
    await _step1(t);
    await _tapDevam(t);
    await _type(t, 0, 'Elif Yıldız');
    await _type(t, 1, 'elif.yildiz@bingol.edu.tr');
    await _tapDevam(t);
    await _type(t, 0, 'kampus2026');
  }),
  _Shot('09_dogrulama_kodu', (b, s) => VerifyCodePage(session: s..rememberCredentials('ad.soyad@bingol.edu.tr', 'Kampus2026'), email: 'ad.soyad@bingol.edu.tr'),
      setup: (b, s) => b.fail('/auth/verify-email', status: 400, code: 'INVALID_CODE', message: 'Kod hatalı veya süresi dolmuş.'),
      after: (t, s) async {
    await t.enterText(find.byType(EditableText).first, '528412');
    await t.pump(const Duration(milliseconds: 600));
    await t.enterText(find.byType(EditableText).first, '5284');
    await t.pump();
  }),
  _Shot('10a_bolum_secici', (b, s) => RegisterPage(session: s), setup: _cat, after: (t, s) async {
    await _tapText(t, _l.pickSelectDepartment);
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('10b_bolum_secici_mat', (b, s) => RegisterPage(session: s), setup: _cat, after: (t, s) async {
    await _tapText(t, _l.pickSelectDepartment);
    await t.pump(const Duration(milliseconds: 500));
    await t.enterText(find.byType(TextField).first, 'mat');
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Shot('10c_bolum_secici_bos', (b, s) => RegisterPage(session: s), setup: _cat, after: (t, s) async {
    await _tapText(t, _l.pickSelectDepartment);
    await t.pump(const Duration(milliseconds: 500));
    await t.enterText(find.byType(TextField).first, 'zzz');
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Shot('10d_bolum_secici_hata', (b, s) => DepartmentPickerPage(catalog: AcademicCatalog.of(s)),
      setup: (b, s) => b.fail('/catalog/academic'), after: (t, s) async {
    await AcademicCatalog.of(s).load();
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Shot('11_sinif_secici', (b, s) => RegisterPage(session: s), setup: _cat, after: (t, s) async {
    await _pickDept(t, 'Bilgisayar Mühendisliği');
    await _tapText(t, _l.pickSelectGrade);
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('12_sifre_unuttum_gonderildi', (b, s) => ForgotPasswordPage(session: s),
      setup: (b, s) => b.on('/auth/forgot-password', {}), after: (t, s) async {
    await _type(t, 0, '226051015');
    await t.tap(find.text(_l.authSendCode));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('13_kodu_girin', (b, s) => ResetCodePage(session: s, email: 'ad.soyad@bingol.edu.tr'), after: (t, s) async {
    await t.enterText(find.byType(EditableText).first, '4829');
    await t.pump();
    await t.tap(find.text(_l.authVerify));
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('14_yeni_sifre', (b, s) => NewPasswordPage(session: s, email: 'ad.soyad@bingol.edu.tr', resetToken: 't'), after: (t, s) async {
    await _type(t, 0, 'Kampus2026');
    await _type(t, 1, '1234');
    await t.tap(find.text(_l.authUpdatePassword));
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('15_sifre_guncellendi', (b, s) => const ResetSuccessPage()),
  _Shot('16a_sifre_unuttum_sure_doldu', (b, s) => ForgotPasswordPage(session: s),
      setup: (b, s) => ForgotPasswordPage.expiredNotice.value = true),
  _Shot('16c_sifre_unuttum_hiz_siniri', (b, s) => ForgotPasswordPage(session: s),
      setup: (b, s) => b.on('/auth/forgot-password', {'code': 'TOO_MANY_REQUESTS', 'message': 'Çok fazla deneme. Lütfen biraz bekleyin.'},
          status: 429, headers: {'retry-after': '60'}),
      after: (t, s) async {
    await _type(t, 0, '226051015');
    await t.tap(find.text(_l.authSendCode));
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('16b_sifre_unuttum_ag_hatasi', (b, s) => ForgotPasswordPage(session: s), setup: (b, s) => b.network('/auth/forgot-password'),
      after: (t, s) async {
    await _type(t, 0, '226051015');
    await t.tap(find.text(_l.authSendCode));
    await t.pump(const Duration(milliseconds: 800));
    await t.pump(const Duration(milliseconds: 800));
  }),
  _Shot('17_sozlesme_liste', (b, s) => LegalListPage(session: s), setup: (b, s) => b.on('/legal', _legalDocs)),
  _Shot('18_sozlesme_okuyucu', (b, s) => LegalDocPage(session: s, type: 'TERMS'), setup: (b, s) {
    b.on('/legal/TERMS', {
      'type': 'TERMS',
      'title': 'Kullanım Koşulları',
      'version': 3,
      'content': _termsBody,
      'publishedAt': '2026-10-12T09:00:00Z',
      'effectiveAt': '2026-10-12T09:00:00Z',
    });
  }),
  _Shot('19_sozlesme_bos', (b, s) => LegalListPage(session: s), setup: (b, s) => b.on('/legal', [])),
  _Shot('20_sozlesme_hata', (b, s) => LegalListPage(session: s), setup: (b, s) => b.fail('/legal')),
];

Widget _app(Widget home, String lang, bool dark, GlobalKey key, double scale) {
  return RepaintBoundary(
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
  final out = Platform.environment['K1_OUT'];
  final skip = out == null ? 'K1_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  final langs = (Platform.environment['K1_LANG'] ?? 'tr').split(',');
  final darkMode = Platform.environment['K1_DARK'] ?? '0';
  final only = (Platform.environment['K1_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final scale = double.tryParse(Platform.environment['K1_SCALE'] ?? '') ?? 1.0;
  final modes = darkMode == 'both' ? [false, true] : [darkMode == '1'];

  for (final lang in langs) {
    setUpAll(() {
      _lang = lang;
      return _loadFonts(lang == 'ar');
    });
    for (final dark in modes) {
      for (final shot in _shots) {
        if (only.isNotEmpty && !only.any((o) => shot.file.startsWith(o))) continue;
        final name = '${shot.file}${dark ? '_koyu' : ''}_$lang${scale != 1.0 ? '_x$scale' : ''}';
        testWidgets('ekran $name', skip: skip != null, (tester) async {
          _lang = lang;
          tester.view.devicePixelRatio = _dpr;
          tester.view.physicalSize = const Size(_w * _dpr, _h * _dpr);
          addTearDown(tester.view.reset);

          final b = FakeBackend(delay: shot.delay ?? Duration.zero);
          final s = makeSession(b, signedIn: false);
          shot.setup?.call(b, s);
          LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
          addTearDown(() => LocaleController.current = null);
          final key = GlobalKey();
          await tester.pumpWidget(_app(shot.build(b, s), lang, dark, key, scale));
          await settle(tester, const Duration(milliseconds: 1200));
          if (shot.after != null) {
            await shot.after!(tester, s);
            await settle(tester, const Duration(milliseconds: 700));
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
          if (shot.delay != null) await tester.pump(shot.delay! + const Duration(seconds: 1));
          await unmount(tester);
        });
      }
    }
  }
}
