import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/features/shell/bukampus_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Alt çubuk (Stitch home-v5 04) ekran görüntüleri: 5 sekme x açık/koyu x 390/320 dp.
/// Üretim: HMNAV_OUT='C:/bu_qa/shots/home-v5/nav' flutter test test/redesign/hm_nav_shots_test.dart
void main() {
  final out = Platform.environment['HMNAV_OUT'];
  final skip = out == null ? 'HMNAV_OUT tanimli degil' : null;
  setUpAll(loadTestFonts);

  for (final width in [390.0, 320.0]) {
    for (final dark in [false, true]) {
      testWidgets('nav ${width.toInt()} ${dark ? 'koyu' : 'acik'}', skip: skip != null, (tester) async {
        final size = Size(width, 150);
        useScreen(tester, size);
        final key = GlobalKey();
        final badge = ValueNotifier<int>(2);
        addTearDown(badge.dispose);
        var index = 0;
        await tester.pumpWidget(StatefulBuilder(builder: (context, set) {
          return buildApp(
            RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: dark ? const Color(0xFF111318) : const Color(0xFFF8F9FA),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: BukampusBottomNavigationBar(index: index, onChanged: (i) => set(() => index = i), chatBadge: badge, onPublish: () {}),
                ),
              ),
            ),
            brightness: dark ? Brightness.dark : Brightness.light,
            size: size,
          );
        }));
        for (final i in const [0, 1, 2, 4]) {
          await tester.tap(find.byKey(ValueKey('nav-$i')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.runAsync(() async {
            final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await ro.toImage(pixelRatio: 3);
            final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
            final dir = Directory(out!)..createSync(recursive: true);
            File('${dir.path}/nav_${width.toInt()}_${dark ? 'koyu' : 'acik'}_$i.png').writeAsBytesSync(data.buffer.asUint8List());
          });
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
