import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// P10 test yardimcisi: renk gecisli sahte fotograf (PNG). 1x1 PNG yerine gercekci kareler
/// ekran goruntusunde izgara/onizleme ritmini gorunur kilar.
Uint8List p10Photo(int seed, {int w = 240, int h = 240}) {
  const palettes = <List<List<int>>>[
    [
      [255, 190, 120],
      [214, 72, 90]
    ],
    [
      [120, 200, 230],
      [40, 80, 150]
    ],
    [
      [170, 220, 150],
      [30, 110, 90]
    ],
    [
      [240, 210, 120],
      [190, 110, 40]
    ],
    [
      [200, 170, 240],
      [80, 60, 160]
    ],
    [
      [250, 170, 190],
      [150, 50, 110]
    ],
  ];
  final p = palettes[seed % palettes.length];
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final t = (x * .55 + y * .45) / (w * .55 + h * .45);
      final r = (p[0][0] + (p[1][0] - p[0][0]) * t).round();
      final g = (p[0][1] + (p[1][1] - p[0][1]) * t).round();
      final b = (p[0][2] + (p[1][2] - p[0][2]) * t).round();
      // Hafif "ufuk" ve daire: dogal gorunum.
      final dx = x - w * (.3 + (seed % 3) * .2), dy = y - h * .35;
      final sun = (dx * dx + dy * dy) < (w * .09) * (w * .09);
      im.setPixelRgb(x, y, sun ? 255 : r, sun ? 244 : g, sun ? 214 : b);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}
