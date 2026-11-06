import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/features/shell/bukampus_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Soft Glow alt cubuk ekran goruntuleri (acik/koyu x 320/390 x sekmeler, nokta var/yok).
/// Uretim: SGNAV_OUT='C:/bu_dsg/nav/design/softglow-nav' flutter test test/redesign/softglow_nav_shots_test.dart
void main() {
  final out = Platform.environment['SGNAV_OUT'];
  setUpAll(loadTestFonts);

  for (final width in [390.0, 320.0]) {
    for (final dark in [false, true]) {
      testWidgets('softglow ${width.toInt()} ${dark ? 'koyu' : 'acik'}', skip: out == null, (tester) async {
        final size = Size(width, 220);
        useScreen(tester, size);
        final key = GlobalKey();
        final badge = ValueNotifier<int>(0);
        addTearDown(badge.dispose);
        var index = 0;
        await tester.pumpWidget(StatefulBuilder(builder: (context, set) {
          return buildApp(
            RepaintBoundary(
              key: key,
              child: Stack(children: [
                // Arkada icerik: cam ve isiltinin icerigi kapatmadigini gormek icin seritler.
                Positioned.fill(
                  child: ColoredBox(
                    color: dark ? const Color(0xFF0B0B0E) : const Color(0xFFF2F2F5),
                    child: Column(children: [
                      for (var i = 0; i < 6; i++)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          height: 28,
                          decoration: BoxDecoration(
                            color: dark ? const Color(0xFF2A2A31) : const Color(0xFFD9DAE0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ]),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: BukampusBottomNavigationBar(index: index, onChanged: (i) => set(() => index = i), chatBadge: badge, onPublish: () {}),
                ),
              ]),
            ),
            brightness: dark ? Brightness.dark : Brightness.light,
            size: size,
          );
        }));
        Future<void> shot(String name) async {
          await tester.pump(const Duration(milliseconds: 500));
          await tester.runAsync(() async {
            final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await ro.toImage(pixelRatio: 3);
            final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
            final dir = Directory(out!)..createSync(recursive: true);
            File('${dir.path}/nav_${width.toInt()}_${dark ? 'koyu' : 'acik'}_$name.png').writeAsBytesSync(data.buffer.asUint8List());
          });
        }

        for (final i in const [0, 1, 2, 4]) {
          await tester.tap(find.byKey(ValueKey('nav-$i')));
          await tester.pump();
          if (i == 1) badge.value = 3;
          await shot('tab$i${badge.value > 0 ? '_nokta' : ''}');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
