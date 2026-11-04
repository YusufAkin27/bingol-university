// Run: flutter test tools/render_chat_wallpapers.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bu_kampus/features/chat/chat_wallpaper.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/painting.dart';
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
      final tile = ChatWallpaper.tile(t.ink, dark ? .06 : .068, 3)!;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..scale(3);
      const bounds = ui.Rect.fromLTWH(0, 0, 390, 844);
      canvas.drawRect(
          bounds,
          ui.Paint()
            ..shader = ui.Gradient.linear(
              ui.Offset.zero,
              const ui.Offset(390, 844),
              [ui.Color.lerp(t.bg, t.soft, dark ? .055 : .12)!, t.bg],
            ));
      final shader = ui.ImageShader(
          tile,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          Float64List.fromList(
              [1 / 3, 0, 0, 0, 0, 1 / 3, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]));
      canvas.drawRect(bounds, ui.Paint()..shader = shader);
      final picture = recorder.endRecording();
      await tester.runAsync(() async {
        final image = await picture.toImage(1170, 2532);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('assets/chat_wallpapers/wp_a_${dark ? 'dark' : 'light'}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      shader.dispose();
      picture.dispose();
    }
  });
}
