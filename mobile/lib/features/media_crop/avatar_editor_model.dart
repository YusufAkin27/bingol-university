import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// Fotoğraf düzenleyicisinin SAF mantığı (arayüzden bağımsız, birim testlenir): durum, geometri, geri al/yinele,
/// renk matrisleri. Koordinatlar "çerçeve birimi"dir: çerçevenin UZUN kenarı [AvatarGeometry.frame] (300) birimdir
/// (kare çerçevede iki kenar da 300) ve çerçeve merkezi orijindir; görsel merkezinin konumu [AvatarEditState.offset]'tir.
/// Çerçeve oranı [AvatarGeometry.aspect] ile verilir (profilde 1:1; gönderi/kapak/sohbette 4:5, 16:9, serbest...).

/// Çerçeve boşluğunu doldurma zemini: bulanık (görselin kendisi) ya da sabit düz renk.
enum AvatarBg { blur, white, black, brand, navy, sand }

/// Çerçeve (kırpma) oranı seçenekleri. [free]: görselin (döndürülmüş) kendi oranı; kırpma yapılmaz.
enum AvatarRatio {
  free,
  square,
  p45,
  p34,
  w169;

  /// Genişlik / yükseklik; [free] için null.
  double? get value => switch (this) {
        AvatarRatio.free => null,
        AvatarRatio.square => 1,
        AvatarRatio.p45 => 4 / 5,
        AvatarRatio.p34 => 3 / 4,
        AvatarRatio.w169 => 16 / 9,
      };

  /// [aspect]'e en yakın seçenek (null = serbest).
  static AvatarRatio nearest(double? aspect) {
    if (aspect == null) return AvatarRatio.free;
    var best = AvatarRatio.square;
    var bd = double.infinity;
    for (final r in AvatarRatio.values) {
      final v = r.value;
      if (v == null) continue;
      final d = (math.log(v) - math.log(aspect)).abs();
      if (d < bd) {
        bd = d;
        best = r;
      }
    }
    return best;
  }
}

/// Hazır filtre kartları.
enum AvatarFilter { original, vivid, cool, warm, mono, faded }

/// Elle ince ayarlar. Hepsi -1..1 (vinyet 0..1); 0 = nötr.
@immutable
class AvatarAdjust {
  const AvatarAdjust({this.brightness = 0, this.contrast = 0, this.saturation = 0, this.warmth = 0, this.vignette = 0});

  final double brightness, contrast, saturation, warmth, vignette;

  bool get isNeutral => brightness == 0 && contrast == 0 && saturation == 0 && warmth == 0;

  AvatarAdjust copyWith({double? brightness, double? contrast, double? saturation, double? warmth, double? vignette}) => AvatarAdjust(
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        warmth: warmth ?? this.warmth,
        vignette: vignette ?? this.vignette,
      );

  @override
  bool operator ==(Object other) =>
      other is AvatarAdjust &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.warmth == warmth &&
      other.vignette == vignette;

  @override
  int get hashCode => Object.hash(brightness, contrast, saturation, warmth, vignette);
}

/// Düzenleme durumu (değişmez): geri al/yinele geçmişi bunların listesidir.
@immutable
class AvatarEditState {
  const AvatarEditState({
    this.turns = 0,
    this.fine = 0,
    this.flip = false,
    this.zoom = 1,
    this.offset = Offset.zero,
    this.bg = AvatarBg.blur,
    this.filter = AvatarFilter.original,
    this.adjust = const AvatarAdjust(),
    this.ratio = AvatarRatio.square,
  });

  /// 90 derecelik dönüş sayısı (0..3, saat yönü).
  final int turns;

  /// İnce açı düzeltmesi, derece (-45..45).
  final double fine;

  /// Yatay aynalama (görsel kendi ekseninde, dönmeden önce).
  final bool flip;

  /// Ölçek: görselin çerçeveyi TAM kapladığı ölçeğe oranı. 1 = doldur; < 1 = uzaklaştırılmış (boşluk zeminle dolar).
  final double zoom;

  /// Görsel merkezinin çerçeve merkezine göre konumu (çerçeve birimi).
  final Offset offset;
  final AvatarBg bg;
  final AvatarFilter filter;
  final AvatarAdjust adjust;

  /// Çerçeve oranı (geri al/yinele geçmişine dahildir).
  final AvatarRatio ratio;

  AvatarEditState copyWith({
    int? turns,
    double? fine,
    bool? flip,
    double? zoom,
    Offset? offset,
    AvatarBg? bg,
    AvatarFilter? filter,
    AvatarAdjust? adjust,
    AvatarRatio? ratio,
  }) =>
      AvatarEditState(
        turns: turns ?? this.turns,
        fine: fine ?? this.fine,
        flip: flip ?? this.flip,
        zoom: zoom ?? this.zoom,
        offset: offset ?? this.offset,
        bg: bg ?? this.bg,
        filter: filter ?? this.filter,
        adjust: adjust ?? this.adjust,
        ratio: ratio ?? this.ratio,
      );

  /// Yalnız yerleşim (dönüş, ayna, ölçek, konum) varsayılan mı?
  bool get isTransformDefault => turns == 0 && fine == 0 && !flip && zoom == 1 && offset == Offset.zero;

  @override
  bool operator ==(Object other) =>
      other is AvatarEditState &&
      other.turns == turns &&
      other.fine == fine &&
      other.flip == flip &&
      other.zoom == zoom &&
      other.offset == offset &&
      other.bg == bg &&
      other.filter == filter &&
      other.adjust == adjust &&
      other.ratio == ratio;

  @override
  int get hashCode => Object.hash(turns, fine, flip, zoom, offset, bg, filter, adjust, ratio);
}

/// Görsel boyutuna ve çerçeve oranına bağlı geometri: ölçek aralığı, ofset sınırlandırma, yumuşak sınır, çıktı yerleşimi.
class AvatarGeometry {
  /// [aspect]: çerçevenin genişlik / yüksekliği (varsayılan 1 = kare).
  const AvatarGeometry(this.imageWidth, this.imageHeight, {this.aspect = 1});

  /// Seçili [AvatarEditState.ratio] ve dönüş sayısına göre geometri: serbestte oran, döndürülmüş görselin kendi oranıdır.
  factory AvatarGeometry.forState(double imageWidth, double imageHeight, AvatarEditState s) {
    final v = s.ratio.value ?? (s.turns.isOdd ? imageHeight / imageWidth : imageWidth / imageHeight);
    return AvatarGeometry(imageWidth, imageHeight, aspect: v);
  }

  /// Çerçevenin UZUN kenarı (çerçeve birimi).
  static const double frame = 300;
  static const double maxZoom = 5;

  final double imageWidth, imageHeight;

  /// Çerçeve genişlik / yükseklik.
  final double aspect;

  /// Çerçeve boyutu (çerçeve birimi): uzun kenar [frame].
  double get frameW => aspect >= 1 ? frame : frame * aspect;
  double get frameH => aspect >= 1 ? frame / aspect : frame;

  @override
  bool operator ==(Object other) =>
      other is AvatarGeometry && other.imageWidth == imageWidth && other.imageHeight == imageHeight && other.aspect == aspect;

  @override
  int get hashCode => Object.hash(imageWidth, imageHeight, aspect);

  /// Toplam dönüş açısı (radyan).
  double angle(AvatarEditState s) => (s.turns % 4) * math.pi / 2 + s.fine * math.pi / 180;

  /// Görselin çerçeveyi TAM kapladığı en küçük ölçek (çerçeve birimi / görsel pikseli); döndürmeyi hesaba katar.
  double fillScale(double angleRad) {
    final c = math.cos(angleRad).abs(), s = math.sin(angleRad).abs();
    // Çerçevenin görsel eksenlerindeki sınırlayıcı kutusu.
    final bw = frameW * c + frameH * s;
    final bh = frameW * s + frameH * c;
    return math.max(bw / imageWidth, bh / imageHeight);
  }

  /// Görselin döndürülmüş hâliyle çerçeve içine TAM sığdığı ölçek.
  double fitScale(double angleRad) {
    final c = math.cos(angleRad).abs(), s = math.sin(angleRad).abs();
    final bw = imageWidth * c + imageHeight * s;
    final bh = imageWidth * s + imageHeight * c;
    return math.min(frameW / bw, frameH / bh);
  }

  /// En küçük [AvatarEditState.zoom]: sığdırma ölçeğinin yarısı (belirgin uzaklaştırma, ama kaybolmaz).
  double minZoom(double angleRad) => math.min(1.0, 0.5 * fitScale(angleRad) / fillScale(angleRad));

  /// "Sığdır" ölçeğinin zoom karşılığı (<= 1).
  double fitZoom(double angleRad) => math.min(1.0, fitScale(angleRad) / fillScale(angleRad));

  /// Durumun gerçek ölçeği (çerçeve birimi / piksel).
  double scale(AvatarEditState s) => s.zoom * fillScale(angle(s));

  double clampZoom(double z, double angleRad) => z.clamp(minZoom(angleRad), maxZoom).toDouble();

  /// Çerçevenin uzun kenarının görsel pikselindeki karşılığı (kaynak çözünürlüğünde kırpılan bölgenin uzun kenarı):
  /// çıktı boyutu seçerken gereksiz büyütmeyi önlemek için.
  double nativeLongSide(AvatarEditState s) => frame / scale(s);

  /// [raw] ofsetini geçerli aralığa sınırlar. Zoom >= 1: çerçeve görselin içinde kalır (köşe boşluğu olmaz; tam doğru,
  /// döndürülmüş dikdörtgen için). Zoom < 1: görsel çerçeveye sığıyor/yakın; sınır sınırlayıcı kutu ile.
  Offset clampOffset(AvatarEditState s, Offset raw) {
    final a = angle(s);
    final sc = scale(s);
    final c = math.cos(a), sn = math.sin(a);
    if (s.zoom >= 1 - 1e-9) {
      // Çerçevenin yarı boyutunun görsel eksenlerine izdüşümü.
      final pu = frameW / 2 * c.abs() + frameH / 2 * sn.abs();
      final pv = frameW / 2 * sn.abs() + frameH / 2 * c.abs();
      final limU = math.max(0.0, imageWidth * sc / 2 - pu);
      final limV = math.max(0.0, imageHeight * sc / 2 - pv);
      // u = (cos, sin), v = (-sin, cos): dik birim vektörler; sınırlar bu eksenlerde bağımsız.
      final ou = (raw.dx * c + raw.dy * sn).clamp(-limU, limU).toDouble();
      final ov = (-raw.dx * sn + raw.dy * c).clamp(-limV, limV).toDouble();
      return Offset(ou * c - ov * sn, ou * sn + ov * c);
    }
    final bw = sc * (imageWidth * c.abs() + imageHeight * sn.abs());
    final bh = sc * (imageWidth * sn.abs() + imageHeight * c.abs());
    final lx = (frameW - bw).abs() / 2, ly = (frameH - bh).abs() / 2;
    return Offset(raw.dx.clamp(-lx, lx).toDouble(), raw.dy.clamp(-ly, ly).toDouble());
  }

  /// Durumu geçerli aralığa getirir (zoom + ofset).
  AvatarEditState normalize(AvatarEditState s) {
    final z = clampZoom(s.zoom, angle(s));
    final t = s.copyWith(zoom: z);
    return t.copyWith(offset: clampOffset(t, s.offset));
  }

  /// Yumuşak sınır (rubber-band): [raw] sınır dışına taşarsa taşma [resistance] ile sönümlenir ve [maxOver] ile kısılır.
  Offset rubber(AvatarEditState s, Offset raw, {double resistance = .35, double maxOver = 40}) {
    final cl = clampOffset(s, raw);
    final e = raw - cl;
    if (e == Offset.zero) return raw;
    var d = e * resistance;
    if (d.distance > maxOver) d = d / d.distance * maxOver;
    return cl + d;
  }

  /// Çerçeve içinde görselin dışında kalan alan (zemin görünür) var mı?
  bool hasBlank(AvatarEditState s) {
    final a = angle(s);
    final sc = scale(s);
    final c = math.cos(a), sn = math.sin(a);
    // Çerçeve köşelerinin görsel yerel koordinatları: hepsi görselin içindeyse boşluk yok.
    for (final sx in const [-1.0, 1.0]) {
      for (final sy in const [-1.0, 1.0]) {
        final px = sx * frameW / 2 - s.offset.dx, py = sy * frameH / 2 - s.offset.dy;
        final lx = px * c + py * sn, ly = -px * sn + py * c;
        if (lx.abs() > imageWidth * sc / 2 + 1e-6 || ly.abs() > imageHeight * sc / 2 + 1e-6) return true;
      }
    }
    return false;
  }

  /// Çıktıya ([outSize]: UZUN kenar, piksel) yerleşim: görsel merkezi (çıktının sol üstüne göre) ve piksel başına ölçek.
  /// Kare çerçevede çıktı [outSize] x [outSize]'tır.
  ({double cx, double cy, double scale}) placement(AvatarEditState s, double outSize) {
    final k = outSize / frame;
    return (cx: frameW * k / 2 + s.offset.dx * k, cy: frameH * k / 2 + s.offset.dy * k, scale: scale(s) * k);
  }

  /// Çıktı boyutu (piksel): uzun kenar [longSide], kısa kenar orana göre.
  ({int w, int h}) outputSize(int longSide) =>
      (w: math.max(1, (frameW / frame * longSide).round()), h: math.max(1, (frameH / frame * longSide).round()));

  /// Çift dokunma hedefi: şimdi doldurmaya yakınsa "sığdır", değilse "doldur" (konum ortalanır).
  AvatarEditState toggledFit(AvatarEditState s) {
    final a = angle(s);
    final nearFill = (s.zoom - 1).abs() < 0.02;
    return s.copyWith(zoom: nearFill ? fitZoom(a) : 1, offset: Offset.zero);
  }

  /// 90 derece döndürme: ölçek doldurmaya, konum ortaya döner.
  AvatarEditState rotated(AvatarEditState s, int dir) =>
      s.copyWith(turns: ((s.turns + dir) % 4 + 4) % 4, zoom: 1, offset: Offset.zero);

  /// İnce açı değişimi: zoom oranı korunur (doldurma durumu doldurma olarak kalır); ofset yeniden sınırlanır.
  AvatarEditState withFine(AvatarEditState s, double fineDeg) {
    final t = s.copyWith(fine: fineDeg.clamp(-45.0, 45.0).toDouble());
    return normalize(t);
  }

  /// Zoom'u [newZoom]'a çeker; [focal] (çerçeve merkezine göre) sabit kalır.
  AvatarEditState zoomedAbout(AvatarEditState s, double newZoom, {Offset focal = Offset.zero}) {
    final a = angle(s);
    final z = clampZoom(newZoom, a);
    final ratio = z / s.zoom; // ölçek oranı = zoom oranı (fillScale sabit)
    final raw = focal - (focal - s.offset) * ratio;
    final t = s.copyWith(zoom: z);
    return t.copyWith(offset: clampOffset(t, raw));
  }
}

/// Geri al / yinele geçmişi: en çok [maxDepth] geri alma adımı tutar.
class AvatarHistory {
  AvatarHistory(AvatarEditState initial, {this.maxDepth = 20}) : _current = initial;

  final int maxDepth;
  final List<AvatarEditState> _undo = [];
  final List<AvatarEditState> _redo = [];
  AvatarEditState _current;

  AvatarEditState get current => _current;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoDepth => _undo.length;

  /// Yeni durumu işler (aynıysa yok sayılır); yinele listesi temizlenir.
  void push(AvatarEditState next) {
    if (next == _current) return;
    _undo.add(_current);
    if (_undo.length > maxDepth) _undo.removeAt(0);
    _current = next;
    _redo.clear();
  }

  AvatarEditState undo() {
    if (_undo.isEmpty) return _current;
    _redo.add(_current);
    _current = _undo.removeLast();
    return _current;
  }

  AvatarEditState redo() {
    if (_redo.isEmpty) return _current;
    _undo.add(_current);
    _current = _redo.removeLast();
    return _current;
  }
}

// -----------------------------------------------------------------------------------------------------------------
// Renk matrisleri (ColorFilter.matrix biçimi: 4x5, satır öncelikli; ofset sütunu 0..255 biriminde)

const List<double> kIdentityMatrix = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

/// İki 4x5 matrisin çarpımı: önce [a], sonra [b] uygulanır.
List<double> multiplyColorMatrix(List<double> b, List<double> a) {
  final out = List<double>.filled(20, 0);
  for (var r = 0; r < 4; r++) {
    for (var c = 0; c < 5; c++) {
      var sum = 0.0;
      for (var k = 0; k < 4; k++) {
        sum += b[r * 5 + k] * a[k * 5 + c];
      }
      if (c == 4) sum += b[r * 5 + 4];
      out[r * 5 + c] = sum;
    }
  }
  return out;
}

List<double> _saturation(double s) {
  const lr = .2126, lg = .7152, lb = .0722;
  final inv = 1 - s;
  return [
    lr * inv + s, lg * inv, lb * inv, 0, 0, //
    lr * inv, lg * inv + s, lb * inv, 0, 0,
    lr * inv, lg * inv, lb * inv + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> _contrast(double c) {
  final t = 127.5 * (1 - c);
  return [
    c, 0, 0, 0, t, //
    0, c, 0, 0, t,
    0, 0, c, 0, t,
    0, 0, 0, 1, 0,
  ];
}

List<double> _brightness(double add255) => [
      1, 0, 0, 0, add255, //
      0, 1, 0, 0, add255,
      0, 0, 1, 0, add255,
      0, 0, 0, 1, 0,
    ];

List<double> _gain(double r, double g, double b) => [
      r, 0, 0, 0, 0, //
      0, g, 0, 0, 0,
      0, 0, b, 0, 0,
      0, 0, 0, 1, 0,
    ];

/// Hazır filtrenin matrisi.
List<double> filterMatrix(AvatarFilter f) {
  switch (f) {
    case AvatarFilter.original:
      return kIdentityMatrix;
    case AvatarFilter.vivid:
      return multiplyColorMatrix(_contrast(1.08), _saturation(1.35));
    case AvatarFilter.cool:
      return multiplyColorMatrix(_saturation(1.05), _gain(.92, 1.0, 1.1));
    case AvatarFilter.warm:
      return multiplyColorMatrix(_saturation(1.05), _gain(1.1, 1.02, .88));
    case AvatarFilter.mono:
      return multiplyColorMatrix(_contrast(1.1), _saturation(0));
    case AvatarFilter.faded:
      return multiplyColorMatrix(_brightness(14), multiplyColorMatrix(_contrast(.84), _saturation(.82)));
  }
}

/// Filtre + elle ayarların birleşik matrisi (önce filtre, sonra ayarlar). Nötrse [kIdentityMatrix].
List<double> avatarColorMatrix(AvatarFilter f, AvatarAdjust a) {
  var m = filterMatrix(f);
  if (a.isNeutral) return m;
  if (a.saturation != 0) m = multiplyColorMatrix(_saturation(1 + a.saturation), m);
  if (a.contrast != 0) m = multiplyColorMatrix(_contrast(1 + a.contrast * .5), m);
  if (a.warmth != 0) m = multiplyColorMatrix(_gain(1 + .14 * a.warmth, 1 + .02 * a.warmth, 1 - .14 * a.warmth), m);
  if (a.brightness != 0) m = multiplyColorMatrix(_brightness(a.brightness * 64), m);
  return m;
}

bool isIdentityMatrix(List<double> m) {
  for (var i = 0; i < 20; i++) {
    if ((m[i] - kIdentityMatrix[i]).abs() > 1e-9) return false;
  }
  return true;
}
