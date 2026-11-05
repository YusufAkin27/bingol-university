import 'dart:math' as math;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/academic/akad_widgets.dart';
import 'package:bu_kampus/features/forum/presentation/widgets/author_line.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_forum.dart';

/// Premium monochrome 2. dalga, grup 5: forum satırı (kutusuz, divider'lı), kenarlıklı etiket, ters renk çip,
/// kontrast ve iki temada hatasız çizim.

Widget _wrap(Widget child, Brightness b) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      darkTheme: BuTheme.dark(),
      themeMode: b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  setUpAll(loadTestFonts);

  for (final b in Brightness.values) {
    final dark = b == Brightness.dark;
    final tag = dark ? 'koyu' : 'acik';
    final tokens = dark ? BuTokens.dark : BuTokens.light;

    testWidgets('AkadChip ($tag): secili = ters renk, secili degil = seffaf + ince kenarlik', (tester) async {
      await tester.pumpWidget(_wrap(
        const Column(mainAxisSize: MainAxisSize.min, children: [
          AkadChip(label: 'Secili', selected: true),
          AkadChip(label: 'Degil'),
        ]),
        b,
      ));
      ShapeDecoration deco(String label) {
        final c = tester.widget<AnimatedContainer>(find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer)).first);
        return c.decoration! as ShapeDecoration;
      }

      final sel = deco('Secili');
      expect(sel.color, tokens.pr);
      expect((sel.shape as OutlinedBorder).side.color, tokens.pr);
      final off = deco('Degil');
      expect(off.color, Colors.transparent);
      expect((off.shape as OutlinedBorder).side.color, tokens.bd);
      expect(tester.widget<Text>(find.text('Secili')).style!.color, tokens.onPr);
      expect(tester.widget<Text>(find.text('Degil')).style!.color, tokens.ink);
      // Secili durum iki temada da okunur: birincil/ters yazi cifti AA (4.5).
      expect(_ratio(tokens.pr, tokens.onPr), greaterThanOrEqualTo(4.5));
    });

    testWidgets('ForumCategoryTag ($tag): dolgusuz, ince kenarlikli', (tester) async {
      await tester.pumpWidget(_wrap(const ForumCategoryTag(label: 'Genel'), b));
      final box = tester.widget<DecoratedBox>(find.byKey(const ValueKey('forum-category-tag')));
      final d = box.decoration as BoxDecoration;
      expect(d.color, isNull);
      expect((d.border! as Border).top.color, tokens.bd);
      expect(d.boxShadow, isNull);
    });

    testWidgets('Forum konu satiri ($tag): kart kutusu/golge yok, yalniz alt ince divider', (tester) async {
      useScreen(tester, kPhoneMedium);
      final back = FakeBackend();
      fakeForum(back, count: 4);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BuTheme.light(),
        darkTheme: BuTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: ForumHomePage(session: makeSession(back)),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final row = find.byKey(const ValueKey('forum-topic-500'));
      expect(row, findsOneWidget);
      final d = tester.widget<DecoratedBox>(row).decoration as BoxDecoration;
      expect(d.color, isNull);
      expect(d.boxShadow, isNull);
      expect(d.borderRadius, isNull);
      final border = d.border! as Border;
      expect(border.bottom.color, tokens.bdSubtle);
      expect(border.top, BorderSide.none);
      expect(tester.takeException(), isNull);
    });
  }
}

double _lum(Color c) {
  double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _ratio(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
