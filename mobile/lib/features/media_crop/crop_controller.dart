import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'crop_engine.dart';
import 'crop_spec.dart';

/// Kırpma durumu ve geometrisi (arayüzden bağımsız, test edilebilir). Koordinatlar sanal çerçeve birimindedir
/// (en uzun kenar 300). Görsel çerçeveyi her zaman tamamen kaplar.
class CropController extends ChangeNotifier {
  CropController({required this.spec, required this.imageWidth, required this.imageHeight});

  static const maxZoom = 4.0;

  final CropSpec spec;
  final int imageWidth;
  final int imageHeight;

  int _turns = 0;
  double _zoom = 1;
  Offset _offset = Offset.zero;

  int get quarterTurns => _turns;
  double get zoom => _zoom;
  Offset get offset => _offset;

  /// Döndürülmüş görselin boyutu (piksel).
  double get rotatedWidth => (_turns.isOdd ? imageHeight : imageWidth).toDouble();
  double get rotatedHeight => (_turns.isOdd ? imageWidth : imageHeight).toDouble();

  Size get frame => spec.frame(rotatedWidth / rotatedHeight);

  /// Görselin çerçeveyi tam kapladığı en küçük ölçek (sanal birim / piksel).
  double get minScale => math.max(frame.width / rotatedWidth, frame.height / rotatedHeight);
  double get scale => minScale * _zoom;

  bool get isDirty => _turns != 0 || _zoom != 1 || _offset != Offset.zero;

  Offset _clamp(Offset o) {
    final maxX = math.max(0.0, (rotatedWidth * scale - frame.width) / 2);
    final maxY = math.max(0.0, (rotatedHeight * scale - frame.height) / 2);
    return Offset(o.dx.clamp(-maxX, maxX), o.dy.clamp(-maxY, maxY));
  }

  void setZoom(double z) {
    _zoom = z.clamp(1.0, maxZoom);
    _offset = _clamp(_offset);
    notifyListeners();
  }

  void panBy(Offset d) {
    _offset = _clamp(_offset + d);
    notifyListeners();
  }

  /// Çimdik hareketi: [startZoom] hareket başındaki yakınlaştırma, [factor] çimdik oranı, [delta] ek kaydırma.
  void gesture({required double startZoom, required double factor, required Offset startOffset, required Offset delta}) {
    _zoom = (startZoom * factor).clamp(1.0, maxZoom);
    _offset = _clamp(startOffset + delta);
    notifyListeners();
  }

  /// 90 derece saat yönünde döndürür (ölçek ve konum sıfırlanır).
  void rotate() {
    _turns = (_turns + 1) % 4;
    _zoom = 1;
    _offset = Offset.zero;
    notifyListeners();
  }

  /// Görseli çerçeveye ortalar (yakınlaştırma ve dönüş korunur).
  void center() {
    _offset = Offset.zero;
    notifyListeners();
  }

  void reset() {
    _turns = 0;
    _zoom = 1;
    _offset = Offset.zero;
    notifyListeners();
  }

  /// Çerçevenin kaplayacağı bölge (döndürülmüş görselin piksel koordinatlarında).
  CropRect toRect() {
    final s = scale;
    final w = frame.width / s;
    final h = frame.height / s;
    final x = (rotatedWidth * s / 2 - frame.width / 2 - _offset.dx) / s;
    final y = (rotatedHeight * s / 2 - frame.height / 2 - _offset.dy) / s;
    return CropRect(x.clamp(0.0, rotatedWidth - w), y.clamp(0.0, rotatedHeight - h), w, h);
  }
}
