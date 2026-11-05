// Run: flutter test tools/render_chat_wallpapers.dart
// Saydam PNG (yalniz desen, tema zemini altta kalir): boyut kucuk, <= 250 KB.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bu_kampus/features/chat/chat_wallpaper.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render campus wallpapers from the native vector pattern',
      (tester) async {
    final loader = FontLoader('BuIcons')
      ..addFont(rootBundle.load('assets/fonts/BuIcons.ttf'));
    await loader.load();
    for (final dark in [false, true]) {
      final t = dark ? BuTokens.dark : BuTokens.light;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..scale(3);
      // Tam ekran, döşemesiz rastgele sıkı desen (390 x 844 dp = 1170 x 2532 px).
      ChatWallpaper.paintFull(canvas, const ui.Size(390, 844), t.ink.withValues(alpha: dark ? .06 : .07));
      final picture = recorder.endRecording();
      await tester.runAsync(() async {
        final image = await picture.toImage(1170, 2532);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('assets/chat_wallpapers/wp_a_${dark ? 'dark' : 'light'}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      picture.dispose();
    }
  });
}
