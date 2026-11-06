import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/widgets/bu_default_avatar.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Varsayilan avatar: boyut/tema/yon matrisi, tasma, rozet konumu, gercek foto gecisi, gorsel cikti.
/// PNG: `design/avatar-alternatives/final-*.png` yalniz AVATAR_SHOTS_OUT verilirse yazilir.
Widget _host(Widget child, {bool dark = false, TextDirection dir = TextDirection.ltr, double text = 1, double width = 390}) =>
    MaterialApp(
      theme: dark ? BuTheme.dark() : BuTheme.light(),
      builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(text), size: Size(width, 800)),
        child: Directionality(textDirection: dir, child: w!),
      ),
      home: Scaffold(body: Center(child: SizedBox(width: width, child: Center(child: child)))),
    );

void main() {
  const sizes = [16.0, 24.0, 32.0, 40.0, 56.0, 96.0, 160.0];

  for (final dark in [false, true]) {
    for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
      testWidgets('boyut matrisi dark=$dark $dir: kutuya sigar, tasma yok', (tester) async {
        for (final s in sizes) {
          for (final group in [false, true]) {
            await tester.pumpWidget(_host(BuAvatar(size: s, group: group), dark: dark, dir: dir));
            expect(tester.takeException(), isNull);
            final r = tester.getRect(find.byKey(const ValueKey('default-avatar-paint')));
            expect(r.size, Size(s, s));
            final d = tester.widget<CustomPaint>(find.byKey(const ValueKey('default-avatar-paint')));
            final p = d.painter! as DefaultAvatarPainter;
            expect(p.detail, s >= 56);
            expect(p.tiny, s < 24);
          }
        }
      });
    }
  }

  test('siluet oranlari kutuya orantili sabitler', () {
    expect(DefaultAvatarPainter.headY - DefaultAvatarPainter.headR, inInclusiveRange(.15, .25));
    expect(DefaultAvatarPainter.headR * 2, inInclusiveRange(.30, .40));
    expect(DefaultAvatarPainter.shoulderTop, inInclusiveRange(.58, .68));
  });

  testWidgets('semantik etiket yalniz verilince; yoksa dekoratif', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(_host(const BuDefaultAvatar(size: 40, semanticLabel: 'Profil')));
    expect(find.bySemanticsLabel('Profil'), findsOneWidget);
    await tester.pumpWidget(_host(const BuDefaultAvatar(size: 40)));
    expect(find.bySemanticsLabel('Profil'), findsNothing);
    h.dispose();
  });

  testWidgets('gercek foto: yok -> varsayilan; url -> varsayilan altta kalir; yuklenemez -> varsayilan', (tester) async {
    await tester.pumpWidget(_host(const BuAvatar(size: 56)));
    expect(find.byType(BuDefaultAvatar), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.pumpWidget(_host(const BuAvatar(size: 56, url: '/files/yok.jpg')));
    expect(find.byType(BuDefaultAvatar), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(BuDefaultAvatar), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BuAvatar)), const Size(56, 56));
  });

  for (final w in [320.0, 390.0]) {
    for (final ts in [1.3, 2.0]) {
      for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
        testWidgets('kamera rozeti w=$w yazi=$ts $dir: sag-alt kenarda, kenara tasar', (tester) async {
          for (final s in [88.0, 96.0, 120.0]) {
            await tester.pumpWidget(_host(
              SizedBox(
                width: s,
                height: s,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(child: ClipOval(child: BuAvatar(size: s))),
                  BuAvatarBadge(avatarSize: s),
                ]),
              ),
              dir: dir,
              text: ts,
              width: w,
            ));
            expect(tester.takeException(), isNull);
            final av = tester.getRect(find.byType(ClipOval));
            final bd = tester.getRect(find.byKey(const ValueKey('avatar-badge')));
            final c = av.center;
            final dx = dir == TextDirection.ltr ? bd.center.dx - c.dx : c.dx - bd.center.dx;
            expect(dx, greaterThan(0));
            expect(bd.center.dy - c.dy, greaterThan(0));
            expect((bd.center - c).distance, closeTo(s / 2, 1.0));
            expect(bd.bottom, greaterThan(av.bottom - 1));
            expect(bd.left >= 0 && bd.right <= 800, isTrue);
            expect(bd.width, closeTo(BuAvatarBadge.outerFor(s), .01));
          }
        });
      }
    }
  }

  testWidgets('rozet onTap: cagrilir', (tester) async {
    var n = 0;
    await tester.pumpWidget(_host(SizedBox(
      width: 120,
      height: 120,
      child: Stack(clipBehavior: Clip.none, children: [
        const BuAvatar(size: 120),
        BuAvatarBadge(avatarSize: 120, onTap: () => n++, tooltip: 'x'),
      ]),
    )));
    await tester.tap(find.byKey(const ValueKey('avatar-badge')));
    expect(n, 1);
  });

  final out = Platform.environment['AVATAR_SHOTS_OUT'];
  testWidgets('gorsel cikti final-*.png', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    for (final dark in [true, false]) {
      final key = GlobalKey();
      Widget cell(double s, {bool group = false, bool square = false}) =>
          Padding(padding: const EdgeInsets.all(12), child: BuAvatar(size: s, group: group, square: square));
      Widget withBadge(double s) => Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
                width: s,
                height: s,
                child: Stack(clipBehavior: Clip.none, children: [BuAvatar(size: s), BuAvatarBadge(avatarSize: s)])),
          );
      await tester.binding.setSurfaceSize(const Size(900, 640));
      await tester.pumpWidget(MaterialApp(
        key: ValueKey(dark),
        theme: dark ? BuTheme.dark() : BuTheme.light(),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Builder(
              builder: (c) => ColoredBox(
                color: c.bu.bg,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [for (final s in [20.0, 32.0, 40.0, 56.0, 96.0, 160.0]) cell(s)]),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [for (final s in [20.0, 32.0, 40.0, 56.0, 96.0, 160.0]) cell(s, group: true)]),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [cell(52, square: true), cell(88, square: true), withBadge(96), withBadge(120)]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/final-${dark ? 'dark' : 'light'}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await tester.binding.setSurfaceSize(null);
  });
}
