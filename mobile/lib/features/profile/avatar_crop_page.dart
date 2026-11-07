import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

/// Kırpmadan önce yönü piksellere işlenmiş fotoğraf (görüntü + boyut).
class AvatarSource {
  const AvatarSource(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;
}

typedef AvatarPrepare = Future<AvatarSource> Function(Uint8List bytes);
typedef AvatarRender = Future<Uint8List> Function(AvatarSource src, Rect cropPx);

/// Kare kırpma: [scale] (>= 1, 1 = görüntünün kısa kenarı daireyi tam kaplar) ve görüntü merkezinin daire merkezine göre
/// kayması ([dx], [dy], görünüm pikseli, [viewport] kenarı). Dönüş: kaynak görüntü pikselinde kare.
Rect avatarCropRect({required int width, required int height, required double viewport, required double scale, required double dx, required double dy}) {
  final base = viewport / math.min(width, height);
  final k = base * scale;
  final side = viewport / k;
  final cx = width / 2 - dx / k;
  final cy = height / 2 - dy / k;
  return Rect.fromCenter(center: Offset(cx, cy), width: side, height: side);
}

/// Kaydırmayı daire her zaman görüntüyle dolu kalacak biçimde sınırlar.
Offset clampAvatarOffset({required int width, required int height, required double viewport, required double scale, required Offset offset}) {
  final base = viewport / math.min(width, height);
  final maxX = math.max(0.0, (width * base * scale - viewport) / 2);
  final maxY = math.max(0.0, (height * base * scale - viewport) / 2);
  return Offset(offset.dx.clamp(-maxX, maxX), offset.dy.clamp(-maxY, maxY));
}

/// Yönü piksellere işler, uzun kenarı 2048 px ile sınırlar (EXIF/konum yeniden kodlamayla atılır).
AvatarSource prepareAvatarSource(Uint8List bytes) {
  var im = img.decodeImage(bytes);
  if (im == null) throw const FormatException('decode');
  im = img.bakeOrientation(im);
  const maxEdge = 2048;
  if (im.width > maxEdge || im.height > maxEdge) {
    im = im.width >= im.height ? img.copyResize(im, width: maxEdge) : img.copyResize(im, height: maxEdge);
  }
  return AvatarSource(Uint8List.fromList(img.encodeJpg(im, quality: 92)), im.width, im.height);
}

/// Kırpma karesini keser, en çok 800x800'e küçültür (profil fotoğrafı için yeterli, yüklemeyi küçük tutar).
Uint8List renderAvatarCrop(AvatarSource src, Rect r) {
  final im = img.decodeImage(src.bytes)!;
  final x = r.left.round().clamp(0, im.width - 1);
  final y = r.top.round().clamp(0, im.height - 1);
  final side = math.max(1, math.min(r.width.round(), math.min(im.width - x, im.height - y)));
  var out = img.copyCrop(im, x: x, y: y, width: side, height: side);
  const target = 800;
  if (out.width > target) out = img.copyResize(out, width: target, height: target);
  return Uint8List.fromList(img.encodeJpg(out, quality: 88));
}

Future<AvatarSource> _defaultPrepare(Uint8List b) => Isolate.run(() => prepareAvatarSource(b));
Future<Uint8List> _defaultRender(AvatarSource s, Rect r) => Isolate.run(() => renderAvatarCrop(s, r));

/// Sade profil fotoğrafı kırpma ekranı: dairesel çerçeve, sıkıştırarak yakınlaştır + sürükle, profilde görünecek küçük
/// önizleme, "Onayla" / "İptal". Onayla -> kırpılmış JPEG baytları; İptal / geri -> null.
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({super.key, required this.bytes, this.prepare, this.render});

  final Uint8List bytes;
  final AvatarPrepare? prepare;
  final AvatarRender? render;

  static Future<Uint8List?> open(BuildContext context, Uint8List bytes) => Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(settings: const RouteSettings(name: 'avatar_crop'), fullscreenDialog: true, builder: (_) => AvatarCropPage(bytes: bytes)));

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  static const _maxScale = 6.0;

  AvatarSource? _src;
  Object? _error;
  bool _saving = false;
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  double _viewport = 300;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final s = await (widget.prepare ?? _defaultPrepare)(widget.bytes);
      if (mounted) setState(() => _src = s);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _set(double scale, Offset offset) {
    final s = _src;
    if (s == null) return;
    final sc = scale.clamp(1.0, _maxScale);
    setState(() {
      _scale = sc;
      _offset = clampAvatarOffset(width: s.width, height: s.height, viewport: _viewport, scale: sc, offset: offset);
    });
  }

  Future<void> _confirm() async {
    final s = _src;
    if (s == null || _saving) return;
    setState(() => _saving = true);
    try {
      final r = avatarCropRect(width: s.width, height: s.height, viewport: _viewport, scale: _scale, dx: _offset.dx, dy: _offset.dy);
      final out = await (widget.render ?? _defaultRender)(s, r);
      if (mounted) Navigator.of(context).pop(out);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  /// [side] kenarlı daire içinde, kırpma durumuna göre yerleştirilmiş fotoğraf.
  Widget _photo(AvatarSource s, double side) {
    final k = side / _viewport;
    final base = _viewport / math.min(s.width, s.height);
    final w = s.width * base * _scale * k;
    final h = s.height * base * _scale * k;
    return ClipOval(
      child: SizedBox(
        width: side,
        height: side,
        child: OverflowBox(
          maxWidth: w,
          maxHeight: h,
          child: Transform.translate(
            offset: _offset * k,
            child: Image.memory(s.bytes, width: w, height: h, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.medium),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final s = _src;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          _viewport = math.max(160.0, math.min(c.maxWidth - 48, c.maxHeight * .5));
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                TextButton(
                  key: const ValueKey('avatarCropCancel'),
                  style: TextButton.styleFrom(minimumSize: const Size(64, 48), foregroundColor: t.ink),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(l.avatarCropCancel, style: tt.titleSmall?.copyWith(fontWeight: BuType.emphasisWeight)),
                ),
                Expanded(
                    child: Text(l.avatarCropTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight))),
                TextButton(
                  key: const ValueKey('avatarCropConfirm'),
                  style: TextButton.styleFrom(minimumSize: const Size(64, 48), foregroundColor: t.ink),
                  onPressed: s == null || _saving ? null : _confirm,
                  child: _saving
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: t.ink))
                      : Text(l.avatarCropConfirm, style: tt.titleSmall?.copyWith(fontWeight: BuType.emphasisWeight)),
                ),
              ]),
            ),
            Expanded(
              child: Center(
                child: s == null
                    ? (_error != null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(l.profilePhotoUnreadable, textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: t.mut)))
                        : CircularProgressIndicator(strokeWidth: 2, color: t.ink))
                    : SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Semantics(
                            label: l.avatarCropTitle,
                            child: GestureDetector(
                              key: const ValueKey('avatarCropArea'),
                              onScaleStart: (d) {
                                _startScale = _scale;
                                _startOffset = _offset;
                                _startFocal = d.localFocalPoint;
                              },
                              onScaleUpdate: (d) => _set(_startScale * d.scale, _startOffset + (d.localFocalPoint - _startFocal)),
                              child: SizedBox(
                                width: _viewport,
                                height: _viewport,
                                child: Stack(alignment: Alignment.center, children: [
                                  _photo(s, _viewport),
                                  IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.ink.withValues(alpha: .5), width: 1.5)),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: _viewport,
                            child: Row(children: [
                              Icon(BuIcons.minus, size: 18, color: t.mut),
                              Expanded(
                                child: Slider(
                                  key: const ValueKey('avatarCropZoom'),
                                  value: _scale,
                                  min: 1,
                                  max: _maxScale,
                                  activeColor: t.ink,
                                  inactiveColor: t.bd,
                                  onChanged: (v) => _set(v, _offset),
                                ),
                              ),
                              Icon(BuIcons.plus, size: 18, color: t.mut),
                            ]),
                          ),
                          const SizedBox(height: 4),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            KeyedSubtree(key: const ValueKey('avatarCropPreview'), child: _photo(s, 48)),
                            const SizedBox(width: 12),
                            ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: _viewport - 60),
                                child: Text(l.avatarCropHint, style: tt.bodySmall?.copyWith(color: t.mut))),
                          ]),
                        ]),
                      ),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}
