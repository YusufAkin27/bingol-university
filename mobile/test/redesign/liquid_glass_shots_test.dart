import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/features/shell/bukampus_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Alt çubuk Liquid Glass ekran görüntüleri: renkli/akan arka plan üstünde açık + koyu, seçili ve basılı (esneyen) kapsül.
/// Üretim: LGNAV_OUT='C:/bu_qa/shots/liquid-glass' flutter test test/redesign/liquid_glass_shots_test.dart
void main() {
  final out = Platform.environment['LGNAV_OUT'];
  final skip = out == null ? 'LGNAV_OUT tanimli degil' : null;
  setUpAll(loadTestFonts);

  Widget backdrop(bool dark) {
    final palette = dark
        ? const [Color(0xFFE5484D), Color(0xFF3E63DD), Color(0xFF30A46C), Color(0xFFF5A524), Color(0xFF8E4EC6)]
        : const [Color(0xFFFFB4A8), Color(0xFF9DB7FF), Color(0xFF9BE3B4), Color(0xFFFFD98A), Color(0xFFD7B5F7)];
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: dark ? const Color(0xFF09090B) : const Color(0xFFFFFFFF)),
        for (var i = 0; i < 12; i++)
          Positioned(
            left: -40.0 + (i % 3) * 140,
            top: 20.0 + i * 52,
            child: Container(
              width: 190,
              height: 40,
              decoration: BoxDecoration(color: palette[i % palette.length], borderRadius: BorderRadius.circular(20)),
            ),
          ),
        Positioned(
          right: -30,
          bottom: 30,
          child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: palette[1])),
        ),
        // Çubuğun hemen altından geçen beyaz/siyah şerit (kontrast stresi).
        Positioned(left: 0, right: 0, bottom: 0, height: 36, child: ColoredBox(color: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000))),
      ],
    );
  }

  for (final dark in [false, true]) {
    testWidgets('liquid glass ${dark ? 'koyu' : 'acik'}', skip: skip != null, (tester) async {
      const size = Size(390, 300);
      useScreen(tester, size);
      final key = GlobalKey();
      final badge = ValueNotifier<int>(2);
      addTearDown(badge.dispose);
      var index = 0;
      await tester.pumpWidget(StatefulBuilder(builder: (context, set) {
        return buildApp(
          RepaintBoundary(
            key: key,
            child: Stack(
              children: [
                Positioned.fill(child: backdrop(dark)),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: BukampusBottomNavigationBar(index: index, onChanged: (i) => set(() => index = i), chatBadge: badge, onPublish: () {}),
                ),
              ],
            ),
          ),
          brightness: dark ? Brightness.dark : Brightness.light,
          size: size,
        );
      }));

      Future<void> shot(String name) async {
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: 3);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          File('${dir.path}/lg_${dark ? 'koyu' : 'acik'}_$name.png').writeAsBytesSync(data.buffer.asUint8List());
        });
      }

      await tester.pump(const Duration(milliseconds: 500));
      await shot('0_ana');
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await shot('1_kesfet');
      // Basılı tutma: kapsül esner.
      final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('nav-1'))));
      await tester.pump(const Duration(milliseconds: 400));
      await shot('2_basili');
      // Sürükleme: kapsül Sohbet'e doğru.
      await g.moveBy(const Offset(70, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await shot('3_surukle');
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await shot('4_sohbet');
      expect(tester.takeException(), isNull);
    });
  }
}
