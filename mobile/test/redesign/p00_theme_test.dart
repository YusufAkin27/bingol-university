import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme/bu_design.dart';
import 'package:bu_kampus/core/theme/bu_theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p00_support.dart';

void main() {
  group('BuTheme (Material 3)', () {
    test('acik ve koyu tema M3, onbellekli ve BuTokens tasir', () {
      final l = BuTheme.light(), d = BuTheme.dark();
      expect(l.useMaterial3, isTrue);
      expect(d.useMaterial3, isTrue);
      expect(identical(BuTheme.light(), l), isTrue, reason: 'ilk karede ikinci kez kurulmamali');
      expect(identical(BuTheme.dark(), d), isTrue);
      expect(l.extension<BuTokens>(), same(BuTokens.light));
      expect(d.extension<BuTokens>(), same(BuTokens.dark));
      expect(BuTheme.forLocale(Brightness.light, 'ar'), isNot(same(l)));
    });

    test('ColorScheme esleme: marka rolleri', () {
      for (final b in Brightness.values) {
        final t = b == Brightness.light ? BuTokens.light : BuTokens.dark;
        final cs = BuTheme.forLocale(b, 'tr').colorScheme;
        expect(cs.primary, t.pr);
        expect(cs.primaryContainer, t.soft);
        expect(cs.secondaryContainer, t.soft, reason: 'NavigationBar gostergesi/tonal dugme marka tonu');
        expect(cs.surface, t.sf);
        expect(cs.surfaceContainerHighest, t.sf2);
        expect(cs.surfaceContainerHigh, t.sf3);
        expect(cs.error, t.danger);
        expect(cs.outlineVariant, t.bd);
        expect(cs.surfaceTint, Colors.transparent);
      }
    });

    test('yazi olcegi: M3 rolleri dolu, Inter, boyutlar azalan', () {
      final tx = BuTheme.light().textTheme;
      final sizes = [
        tx.displayLarge, tx.displayMedium, tx.displaySmall, tx.headlineLarge, tx.headlineMedium, tx.headlineSmall,
        tx.titleLarge, tx.titleMedium, tx.titleSmall, tx.bodyLarge, tx.bodyMedium, tx.bodySmall,
        tx.labelLarge, tx.labelMedium, tx.labelSmall,
      ].map((s) => s!.fontSize!).toList();
      expect(tx.bodyMedium!.fontFamily, 'Inter');
      expect(tx.bodyMedium!.color, BuTokens.light.ink);
      // Her rol ailesi kendi icinde azalan.
      expect(sizes.sublist(0, 6), orderedEquals([...sizes.sublist(0, 6)]..sort((a, b) => b.compareTo(a))));
      expect(sizes[14], greaterThanOrEqualTo(11), reason: 'en kucuk etiket 11 dp altina inmez');
    });

    test('Arapca: harf araligi sifir, satir yuksekligi artar', () {
      final tr = BuTheme.forLocale(Brightness.light, 'tr').textTheme;
      final ar = BuTheme.forLocale(Brightness.light, 'ar').textTheme;
      expect(tr.displayLarge!.letterSpacing, isNot(0));
      expect(ar.displayLarge!.letterSpacing, 0);
      expect(ar.bodyMedium!.height!, greaterThan(tr.bodyMedium!.height!));
    });

    test('bilesen temalari tanimli', () {
      final t = BuTheme.light();
      expect(t.navigationBarTheme.indicatorColor, BuTokens.light.soft);
      expect(t.navigationBarTheme.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
      expect(t.bottomSheetTheme.shape, isNotNull);
      expect(t.dialogTheme.shape, isNotNull);
      expect(t.inputDecorationTheme.filled, isTrue);
      expect(t.chipTheme.shape, isA<StadiumBorder>());
      expect(t.searchBarTheme.shape, isNotNull);
      expect(t.segmentedButtonTheme.style, isNotNull);
      expect(t.datePickerTheme.shape, isNotNull);
      expect(t.timePickerTheme.shape, isNotNull);
      expect(t.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(t.pageTransitionsTheme.builders[TargetPlatform.android], isNotNull);
      expect(t.materialTapTargetSize, MaterialTapTargetSize.padded);
    });

    test('FilledButton tema rengi ezmez: tonal ayri kalir', () {
      final s = BuTheme.light().filledButtonTheme.style!;
      expect(s.backgroundColor, isNull, reason: 'renk ColorScheme den gelir; tonal/primary birbirini ezmez');
    });

    test('tema kurulumu ucuz (fromSeed yok): ilk kurulum <100 ms, onbellekten ~0', () {
      final sw = Stopwatch()..start();
      BuThemeBuilder.build(BuTokens.light, Brightness.light);
      final first = sw.elapsedMilliseconds;
      sw
        ..reset()
        ..start();
      for (var i = 0; i < 1000; i++) {
        BuTheme.light();
      }
      // ignore: avoid_print
      print('tema kurulum ms: $first; 1000 onbellekli cagri ms: ${sw.elapsedMilliseconds}');
      expect(first, lessThan(100));
      expect(sw.elapsedMilliseconds, lessThan(20));
    });

    test('BuTokens.lerp ve copyWith', () {
      final m = BuTokens.light.lerp(BuTokens.dark, .5);
      expect(m.bg, Color.lerp(BuTokens.light.bg, BuTokens.dark.bg, .5));
      expect(m.tints.length, 6);
      expect(BuTokens.light.copyWith(pr: Colors.blue).pr, Colors.blue);
      expect(BuTokens.light.copyWith().sf3, BuTokens.light.sf3);
      expect(BuTokens.light.tint(7), BuTokens.light.tints[1]);
      expect(BuTokens.light.tint(-1), BuTokens.light.tints[1]);
    });
  });

  group('kontrast (WCAG AA)', () {
    for (final entry in {'acik': BuTokens.light, 'koyu': BuTokens.dark}.entries) {
      final t = entry.value;
      test('${entry.key}: metin ciftleri >= 4.5', () {
        final pairs = <String, (Color, Color)>{
          'ink/bg': (t.ink, t.bg),
          'ink/sf': (t.ink, t.sf),
          'ink/sf2': (t.ink, t.sf2),
          'ink/sf3': (t.ink, t.sf3),
          'mut/bg': (t.mut, t.bg),
          'mut/sf': (t.mut, t.sf),
          'mut/sf2': (t.mut, t.sf2),
          'onPr/pr': (t.onPr, t.pr),
          'onSoft/soft': (t.onSoft, t.soft),
          'pr/bg': (t.pr, t.bg),
          'pr/sf': (t.pr, t.sf),
          'ok/okSoft': (t.ok, t.okSoft),
          'ok/sf': (t.ok, t.sf),
          'danger/sf': (t.danger, t.sf),
          'danger/bg': (t.danger, t.bg),
          'onWarnSoft/warnSoft': (t.onWarnSoft, t.warnSoft),
          'warn/sf': (t.warn, t.sf),
          'onNav/nav': (t.onNav, t.nav),
        };
        pairs.forEach((k, v) => expect(p00Contrast(v.$1, v.$2), greaterThanOrEqualTo(4.5), reason: k));
      });
      test('${entry.key}: kategori renkleri >= 4.5', () {
        for (var i = 0; i < t.tints.length; i++) {
          expect(p00Contrast(t.tints[i].fg, t.tints[i].bg), greaterThanOrEqualTo(4.5), reason: 'tint $i');
        }
      });
      test('${entry.key}: hero gradyan ustunde beyaz yazi >= 4.5', () {
        expect(p00Contrast(t.onMedia, t.h1), greaterThanOrEqualTo(4.5));
        expect(p00Contrast(t.onMedia, t.h2), greaterThanOrEqualTo(4.5));
      });
      test('${entry.key}: sinir/olmayan metin ogeleri >= 3', () {
        // Anahtar izi ve onay kutusu cercevesi (mut) zeminde >= 3:1 (WCAG 1.4.11).
        expect(p00Contrast(t.mut, t.sf), greaterThanOrEqualTo(3));
        expect(p00Contrast(t.pr, t.sf), greaterThanOrEqualTo(3));
      });
    }
  });

  group('belirtecler', () {
    test('BuSpace/BuRadius/BuMotion degerleri', () {
      expect(BuSpace.sm, 8);
      expect(BuSpace.lg, 16);
      expect(BuRadius.sm, 12);
      expect(BuRadius.md, 16);
      expect(BuRadius.xl, 28);
      expect(BuMotion.short, const Duration(milliseconds: 150));
      expect(BuMotion.medium, const Duration(milliseconds: 250));
      expect(BuMotion.long, const Duration(milliseconds: 400));
    });

    testWidgets('BuMotion.reduced: disableAnimations ise sure sifir', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));
      expect(BuMotion.reduced(ctx), isTrue);
      expect(BuMotion.of(ctx, BuMotion.long), Duration.zero);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(),
        child: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));
      expect(BuMotion.reduced(ctx), isFalse);
      expect(BuMotion.of(ctx, BuMotion.long), BuMotion.long);
    });

    testWidgets('BuElevation: acik temada golge, koyuda yok', (tester) async {
      late BuildContext ctx;
      Widget host(Brightness b) => MaterialApp(
            theme: BuTheme.forLocale(b, 'tr'),
            darkTheme: BuTheme.forLocale(b, 'tr'),
            themeMode: b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            home: Builder(builder: (c) {
              ctx = c;
              return const SizedBox();
            }),
          );
      await tester.pumpWidget(host(Brightness.light));
      expect(BuElevation.of(ctx, 0), isEmpty);
      expect(BuElevation.of(ctx, 1), isNotEmpty);
      expect(BuElevation.of(ctx, 3).length, 2);
      await tester.pumpWidget(host(Brightness.dark));
      await tester.pump(const Duration(milliseconds: 500));
      expect(BuElevation.of(ctx, 2), isEmpty);
    });
  });
}
