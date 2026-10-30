import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Kırpma bölgesi (kaynak görselin DÖNDÜRÜLMÜŞ halinde piksel cinsinden).
class CropRect {
  const CropRect(this.x, this.y, this.w, this.h);

  final double x, y, w, h;
}

/// Görseli [quarterTurns] x 90 derece döndürür, [rect] bölgesini keser, en uzun kenarı [maxEdge]'e indirir ve JPEG'e
/// kodlar (EXIF yönü uygulanır, meta veri taşınmaz). Ağır iş ayrı isolate'ta yapılır; bozuk girdide null döner.
Future<Uint8List?> cropJpeg(Uint8List bytes,
    {required int quarterTurns, required CropRect rect, required int maxEdge, int quality = 88}) {
  return Isolate.run(() => cropJpegSync(bytes, quarterTurns: quarterTurns, rect: rect, maxEdge: maxEdge, quality: quality));
}

/// [cropJpeg]'in eşzamanlı çekirdeği (testlerde doğrudan çağrılabilir).
Uint8List? cropJpegSync(Uint8List bytes,
    {required int quarterTurns, required CropRect rect, required int maxEdge, int quality = 88}) {
  var src = img.decodeImage(bytes);
  if (src == null) return null;
  src = img.bakeOrientation(src);
  final turns = quarterTurns % 4;
  if (turns != 0) src = img.copyRotate(src, angle: 90.0 * turns);
  final x = rect.x.round().clamp(0, src.width - 1);
  final y = rect.y.round().clamp(0, src.height - 1);
  final w = rect.w.round().clamp(1, src.width - x);
  final h = rect.h.round().clamp(1, src.height - y);
  var out = img.copyCrop(src, x: x, y: y, width: w, height: h);
  final long = w >= h ? w : h;
  if (long > maxEdge) {
    out = w >= h ? img.copyResize(out, width: maxEdge) : img.copyResize(out, height: maxEdge);
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}
