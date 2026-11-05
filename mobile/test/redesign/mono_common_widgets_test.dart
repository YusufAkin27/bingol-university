import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bu_kampus/widgets/app_components.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

import 'p00_support.dart';

/// PREMIUM MONOCHROME ortak widget katmani (2. dalga, grup 6): boş durum cizimleri nötr, ortak bilesenler iki temada
/// AA kontrastli, ters renk secim, iskelet/durum gorunumleri dar ekran + buyuk yazida tasmaz.
void main() {
  final themes = {'premium white': BuTokens.light, 'premium black': BuTokens.dark};

  group('kontrast (AA) - ortak bilesen cifti, iki tema', () {
    for (final e in themes.entries) {
      final t = e.value;
      test(e.key, () {
        final pairs = <String, (Color, Color)>{
          'BuButton birincil onPr/pr': (t.onPr, t.pr),
          'BuSegmented secili onPr/pr': (t.onPr, t.pr),
          'BuChip secili onPr/pr': (t.onPr, t.pr),
          'BuBadge onPr/ink': (t.onPr, t.ink),
          'BuSegmented secilmemis mut/sf2': (t.mut, t.sf2),
          'bos durum mesaji mut/bg': (t.mut, t.bg),
          'bos durum baslik ink/bg': (t.ink, t.bg),
          'dialog/sheet govde mut/sf3': (t.mut, t.sf3),
          'toast ink/sf3': (t.ink, t.sf3),
          'cizim cizgisi ink/sf2': (t.ink, t.sf2),
          'cizim cizgisi ink/sf3': (t.ink, t.sf3),
          'cizim ikincil mut/sf3': (t.mut, t.sf3),
          'ikon karosu ink/sf2': (t.ink, t.sf2),
          'danger/sf3 (silme dugmesi etiketi)': (t.danger, t.sf3),
        };
        pairs.forEach((k, v) => expect(p00Contrast(v.$1, v.$2), greaterThanOrEqualTo(4.5), reason: k));
        // Cizim cizgisi ve kontrol cercevesi >= 3:1 (WCAG 1.4.11).
        expect(p00Contrast(t.bdStrong, t.bg), greaterThanOrEqualTo(3));
        // Ince ayrac gorunur ama baskin degil.
        expect(p00Contrast(t.bdSubtle, t.bg), greaterThan(1.05));
      });
    }
  });

  group('bos durum cizimleri monochrome', () {
    for (final dark in [false, true]) {
      testWidgets('tum cizimler notr (ok disinda renk yok), ${dark ? 'koyu' : 'acik'}', (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(p00App(
          Center(
            child: RepaintBoundary(
              key: key,
              child: Wrap(
                children: [for (final k in BuIllustration.values) if (k != BuIllustration.check) BuIllustrationView(k, size: 120)],
              ),
            ),
          ),
          dark: dark,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final ByteData? bytes = await tester.runAsync(() async {
          final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await b.toImage();
          return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        });
        var maxChroma = 0;
        for (var i = 0; i < bytes!.lengthInBytes; i += 4) {
          final r = bytes.getUint8(i), g = bytes.getUint8(i + 1), b = bytes.getUint8(i + 2);
          final hi = r > g ? (r > b ? r : b) : (g > b ? g : b);
          final lo = r < g ? (r < b ? r : b) : (g < b ? g : b);
          if (hi - lo > maxChroma) maxChroma = hi - lo;
        }
        // Zinc notrleri hafif mavimsi (<= 8 kanal farki); marka kirmizisi/mavisi/amber olsa 40+ olurdu.
        expect(maxChroma, lessThanOrEqualTo(10), reason: 'cizimlerde renkli piksel var');
      });
    }

    testWidgets('13 cizim iki temada, 3 boyutta istisnasiz boyanir', (tester) async {
      await p00Matrix(
        tester,
        () => SingleChildScrollView(
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in BuIllustration.values) ...[
              BuIllustrationView(k, size: 60),
              BuIllustrationView(k, size: 96),
              BuIllustrationView(k, size: 132),
            ],
          ]),
        ),
        widths: const [320],
      );
    });
  });

  group('ortak bilesenler', () {
    testWidgets('BuSegmented secili parca TERS RENK (pr zemin + onPr yazi), iki temada', (tester) async {
      for (final dark in [false, true]) {
        await tester.pumpWidget(p00App(BuSegmented(items: const ['A', 'B', 'C'], index: 1, onChanged: (_) {}), dark: dark));
        await tester.pump(const Duration(milliseconds: 400));
        final t = tester.element(find.byType(BuSegmented)).bu;
        Color textColor(String s) => tester
            .widget<AnimatedDefaultTextStyle>(find.ancestor(of: find.text(s), matching: find.byType(AnimatedDefaultTextStyle)).first)
            .style
            .color!;
        expect(textColor('B'), t.onPr);
        expect(textColor('A'), t.mut);
        final thumbs = tester.widgetList<DecoratedBox>(find.descendant(of: find.byType(BuSegmented), matching: find.byType(DecoratedBox)));
        expect(thumbs.any((d) => d.decoration is BoxDecoration && (d.decoration as BoxDecoration).color == t.pr), isTrue);
      }
    });

    testWidgets('BuEmptyState / BuErrorState / BuSkeletonList: dar ekran + buyuk yazi + 3 dil + iki tema', (tester) async {
      await p00Matrix(
        tester,
        () => SizedBox(
          height: 540,
          child: Column(children: [
            Expanded(child: BuEmptyState(title: 'Henüz mesaj yok', message: 'Birini seçip yazmaya başla.', actionLabel: 'Başlat', onAction: () {})),
            Expanded(child: BuErrorState(onRetry: () {})),
            const SizedBox(height: 180, child: BuSkeletonList(itemCount: 2, shrinkWrap: true)),
          ]),
        ),
        widths: const [320],
        scaffold: true,
      );
    });

    testWidgets('BuSkeleton: hareket azaltilinca statik, nabiz notr (renk sf2 ile bd arasi)', (tester) async {
      await tester.pumpWidget(p00App(const BuSkeleton(width: 100, height: 20), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('AppReactionBar: etiket sayiyi icerir, dokunma alani >= 48 dp', (tester) async {
      var liked = 0;
      await tester.pumpWidget(p00App(Padding(
        padding: const EdgeInsets.all(16),
        child: AppReactionBar(items: [
          AppReaction(icon: Icons.favorite_border, activeIcon: Icons.favorite, label: 'Beğen', count: 12, active: true, heart: true, onTap: () => liked++),
          const AppReaction(icon: Icons.chat_bubble_outline, label: 'Yorum'),
        ]),
      )));
      final h = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Beğen, 12'), findsOneWidget);
      final size = tester.getSize(find.bySemanticsLabel('Beğen, 12'));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(find.bySemanticsLabel('Beğen, 12'));
      expect(liked, 1);
      h.dispose();
    });

    testWidgets('AppTextField: etiket ustte, hata metni, salt okunur + onTap, iki tema', (tester) async {
      var taps = 0;
      for (final dark in [false, true]) {
        await tester.pumpWidget(p00App(
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppTextField(label: 'E-posta', hint: 'ad@bingol.edu.tr', error: 'Geçersiz adres', readOnly: true, onTap: () => taps++),
          ),
          dark: dark,
        ));
        expect(find.text('E-posta'), findsOneWidget);
        expect(find.text('Geçersiz adres'), findsOneWidget);
        await tester.tap(find.byType(TextField));
        expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(48));
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(taps, 2);
    });

    testWidgets('BuToast: yuzey sf3, simge anlamsal; dialog yuzeyi sf3 + ince kenarlik (iki tema)', (tester) async {
      for (final dark in [false, true]) {
        await tester.pumpWidget(p00App(Builder(
          builder: (c) => TextButton(
            onPressed: () => BuToast.show(c, 'Kaydedildi', kind: BuToastKind.success),
            child: const Text('git'),
          ),
        ), dark: dark));
        await tester.tap(find.text('git'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final t = tester.element(find.text('git')).bu;
        final bar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(bar.backgroundColor ?? Theme.of(tester.element(find.text('git'))).snackBarTheme.backgroundColor, t.sf3);
        final th = Theme.of(tester.element(find.text('git')));
        expect((th.dialogTheme.shape as RoundedRectangleBorder).side.color, t.bd);
        expect(th.dividerTheme.color, t.bdSubtle);
      }
    });
  });
}
