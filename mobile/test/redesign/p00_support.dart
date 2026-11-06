import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// P0 test yardimcisi: bir bileseni {tr,en,ar} x {acik,koyu} x {yazi 1.0, 1.3} x {320 dp, 390 dp} ile cizer;
/// her birlesimde istisna (tasma dahil) olmadigini denetler. Diger paketler de ekran testlerinde kullanabilir.
const kP00Langs = ['tr', 'en', 'ar'];
const kP00Scales = [1.0, 1.3];
const kP00Widths = [320.0, 390.0];

/// Tek birlesim icin uygulama sarmalayici (Scaffold + gövde).
Widget p00App(
  Widget child, {
  String lang = 'tr',
  bool dark = false,
  double scale = 1.0,
  bool scaffold = true,
  bool disableAnimations = false,
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
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: disableAnimations),
      child: c!,
    ),
    home: scaffold ? Scaffold(body: child) : child,
  );
}

/// [build] her birlesimde cagrilir; [check] (verilirse) her birlesimde cizimden sonra calisir.
/// [settleMs]: sonsuz animasyon (iskelet) olan bilesenlerde `pumpAndSettle` yerine sabit sure ilerletilir.
Future<void> p00Matrix(
  WidgetTester tester,
  Widget Function() build, {
  Future<void> Function(WidgetTester t, String lang, bool dark, double scale)? check,
  bool scaffold = true,
  int settleMs = 600,
  List<double> widths = kP00Widths,
  bool disableAnimations = false,
}) async {
  addTearDown(tester.view.reset);
  for (final w in widths) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(w, 700);
    for (final lang in kP00Langs) {
      for (final dark in [false, true]) {
        for (final scale in kP00Scales) {
          await tester.pumpWidget(
              p00App(build(), lang: lang, dark: dark, scale: scale, scaffold: scaffold, disableAnimations: disableAnimations));
          await tester.pump(Duration(milliseconds: settleMs));
          final err = tester.takeException();
          if (err != null) fail('[$lang dark=$dark x$scale w=$w] $err');
          if (check != null) await check(tester, lang, dark, scale);
          final err2 = tester.takeException();
          if (err2 != null) fail('[$lang dark=$dark x$scale w=$w] (check) $err2');
        }
      }
    }
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 400));
}

double p00Contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + .05) / (lo + .05);
}

/// Metin kontrastı, belirteç düzeyinde (WCAG AA 4.5): ink/mut yüzeylerde, onPr seçili dolguda.
/// `textContrastGuideline` ince yazı + 1 dp çerçeveli çip/hap piksellerini örnekleyip yanlış alarm verir
/// (gözle doğru okunan ekranlarda 1.4-2.4 çıkar); ekranlar bu belirteçlerle boyandığı için asıl denetim budur.
void expectTokenTextContrast({required bool dark}) {
  final t = dark ? BuTokens.dark : BuTokens.light;
  for (final bg in [t.bg, t.sf, t.sf2]) {
    expect(p00Contrast(t.ink, bg), greaterThanOrEqualTo(4.5), reason: 'ink/${bg.toARGB32().toRadixString(16)}');
    expect(p00Contrast(t.mut, bg), greaterThanOrEqualTo(4.5), reason: 'mut/${bg.toARGB32().toRadixString(16)}');
  }
  expect(p00Contrast(t.onPr, t.pr), greaterThanOrEqualTo(4.5), reason: 'onPr/pr');
  expect(p00Contrast(t.danger, t.bg), greaterThanOrEqualTo(4.5), reason: 'danger/bg');
}
