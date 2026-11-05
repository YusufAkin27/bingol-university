import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/clubs/club_ref_widgets.dart';
import 'package:bu_kampus/features/events/etkinlik2_widgets.dart';
import 'package:bu_kampus/features/events/event_parts.dart';
import 'package:bu_kampus/features/polls/anket_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p00_support.dart';

/// Monochrome 2. dalga, grup 4 (etkinlik/kulup/anket): secili = ters renk, golge yok, anlamsal kirmizi, AA kontrast.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + .05) / (lo + .05);
}

void main() {
  for (final dark in [false, true]) {
    final tag = dark ? 'koyu' : 'acik';

    testWidgets('Et2Segment secili parca ters renk (pr) + onPr yazi, AA kontrast ($tag)', (tester) async {
      late BuTokens tk;
      await tester.pumpWidget(p00App(
        Builder(builder: (context) {
          tk = context.bu;
          return Et2Segment<int>(value: 1, options: const [(0, 'Herkes'), (1, 'Istek ile')], onChanged: (_) {});
        }),
        lang: 'tr',
        dark: dark,
        scale: 1,
        scaffold: true,
      ));
      await tester.pump(const Duration(milliseconds: 400));
      final thumbs = tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(Et2Segment<int>), matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == tk.pr);
      expect(thumbs, isNotEmpty, reason: 'secili parca pr dolgulu');
      final sel = tester.widget<AnimatedDefaultTextStyle>(find.ancestor(of: find.text('Istek ile'), matching: find.byType(AnimatedDefaultTextStyle)).first);
      expect(sel.style.color, tk.onPr);
      expect(_contrast(tk.pr, tk.onPr), greaterThanOrEqualTo(7));
      expect(tester.takeException(), isNull);
    });

    testWidgets('EventDateBadge kapak ustunde golgesiz, tema yuzeyi + ince kenarlik ($tag)', (tester) async {
      late BuTokens tk;
      await tester.pumpWidget(p00App(
        Builder(builder: (context) {
          tk = context.bu;
          return EventDateBadge(DateTime(2026, 11, 5), onCover: true);
        }),
        lang: 'tr',
        dark: dark,
        scale: 1,
        scaffold: true,
      ));
      await tester.pump();
      final deco = tester.widget<Container>(find.descendant(of: find.byType(EventDateBadge), matching: find.byType(Container)).first).decoration! as BoxDecoration;
      expect(deco.boxShadow, isNull);
      expect(deco.border, isNotNull);
      expect(deco.color!.withValues(alpha: 1), tk.sf);
    });

    testWidgets('ClubIconBox danger: dangerSoft zemin + danger simge (marka kirmizisi degil) ($tag)', (tester) async {
      late BuTokens tk;
      await tester.pumpWidget(p00App(
        Builder(builder: (context) {
          tk = context.bu;
          return const ClubIconBox(icon: Icons.delete, danger: true);
        }),
        lang: 'tr',
        dark: dark,
        scale: 1,
        scaffold: true,
      ));
      await tester.pump();
      final box = tester.widget<Container>(find.descendant(of: find.byType(ClubIconBox), matching: find.byType(Container)).first);
      expect((box.decoration! as BoxDecoration).color, tk.dangerSoft);
      expect(tester.widget<Icon>(find.byType(Icon)).color, tk.danger);
    });

    testWidgets('AnketArtView notr cizilir, tum turler hatasiz ($tag)', (tester) async {
      await tester.pumpWidget(p00App(
        Wrap(children: [for (final k in AnketArt.values) AnketArtView(k, size: 96)]),
        lang: 'tr',
        dark: dark,
        scale: 1,
        scaffold: true,
      ));
      await tester.pump();
      expect(find.byType(AnketArtView), findsNWidgets(AnketArt.values.length));
      expect(tester.takeException(), isNull);
    });
  }
}
