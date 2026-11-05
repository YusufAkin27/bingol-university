import 'dart:math' as math;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/home/home_parts.dart';
import 'package:bu_kampus/features/news/icerik_parts.dart';
import 'package:bu_kampus/features/search/search_fold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p00_support.dart';

/// PREMIUM MONOCHROME (2. dalga, Ana sayfa / Kesfet / Gonderi / Haber grubu): yuzeyler golgesiz + ince kenarlik,
/// secili cip/segment ters renk (AA), arama kutusu radius 12 (hap degil), arama vurgusu renksiz alt cizgi.
double _lum(Color c) {
  double ch(double v) => v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
  return .2126 * ch(c.r) + .7152 * ch(c.g) + .0722 * ch(c.b);
}

double _ratio(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

bool _hasShadow(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .any((d) => d.decoration is BoxDecoration && (d.decoration as BoxDecoration).boxShadow?.isNotEmpty == true);

void main() {
  for (final dark in [false, true]) {
    final name = dark ? 'Premium Black' : 'Premium White';

    testWidgets('HomeSurface: golgesiz, 16 kose, ince kenarlik ($name)', (tester) async {
      await tester.pumpWidget(p00App(const HomeSurface(child: SizedBox(height: 40, width: 100)), dark: dark));
      await tester.pumpAndSettle();
      expect(_hasShadow(tester), isFalse);
      final m = tester.widget<Material>(find.descendant(of: find.byType(HomeSurface), matching: find.byType(Material)).first);
      final shape = m.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
      final t = dark ? BuTokens.dark : BuTokens.light;
      expect(shape.side.color, t.bd);
    });

    testWidgets('HomeSearchBox: radius 12 (hap degil), golgesiz ($name)', (tester) async {
      await tester.pumpWidget(p00App(HomeSearchBox(hint: 'Ara', onTap: () {}), dark: dark));
      await tester.pumpAndSettle();
      expect(_hasShadow(tester), isFalse);
      final m = tester.widget<Material>(find.descendant(of: find.byType(HomeSearchBox), matching: find.byType(Material)).first);
      expect(m.shape, isA<RoundedRectangleBorder>());
      expect((m.shape as RoundedRectangleBorder).borderRadius, BorderRadius.circular(12));
    });

    testWidgets('IcerikTabs: secili parca ters renk pr/onPr, AA kontrast ($name)', (tester) async {
      await tester.pumpWidget(p00App(IcerikTabs(labels: const ['Haber', 'Duyuru'], index: 0, onChanged: (_) {}), dark: dark));
      await tester.pumpAndSettle();
      final t = dark ? BuTokens.dark : BuTokens.light;
      final thumb = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((d) => d.decoration is BoxDecoration && (d.decoration as BoxDecoration).color == t.pr);
      expect(thumb, isNotEmpty, reason: 'secili parca pr zemin');
      expect(_ratio(t.pr, t.onPr), greaterThan(7));
      final selected = tester.widget<AnimatedDefaultTextStyle>(
          find.ancestor(of: find.text('Haber'), matching: find.byType(AnimatedDefaultTextStyle)).first);
      expect(selected.style.color, t.onPr);
      expect(_hasShadow(tester), isFalse);
    });

    testWidgets('IcerikCard: golge yok, ince kenarlik ($name)', (tester) async {
      await tester.pumpWidget(p00App(const IcerikCard(child: SizedBox(height: 30, width: 80)), dark: dark));
      await tester.pumpAndSettle();
      expect(_hasShadow(tester), isFalse);
    });

    testWidgets('searchHighlight: eslesme renksiz alt cizgi ile ayrisir ($name)', (tester) async {
      late InlineSpan span;
      await tester.pumpWidget(p00App(
        Builder(builder: (context) {
          span = searchHighlight(context, 'Bingol Universitesi', 'uni', const TextStyle(fontSize: 14));
          return Text.rich(span);
        }),
        dark: dark,
      ));
      final kids = (span as TextSpan).children!.cast<TextSpan>();
      final hit = kids.firstWhere((s) => s.text == 'Uni');
      expect(hit.style!.decoration, TextDecoration.underline);
      expect(hit.style!.fontWeight!.value, lessThanOrEqualTo(400), reason: 'kalin yazi yok');
    });
  }
}
