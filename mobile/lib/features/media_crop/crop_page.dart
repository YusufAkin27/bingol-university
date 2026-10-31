import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'crop_controller.dart';
import 'crop_engine.dart';
import 'crop_spec.dart';

/// Tam ekran kırpma sayfası: koyu tuval + sabit oranlı çerçeve, sürükle/yakınlaştır, döndür, sıfırla, canlı önizleme.
/// Sonucu [CropOutcome] olarak `Navigator.pop` eder; vazgeçilirse null. Genelde [cropImage] ile açılır.
class CropPage extends StatefulWidget {
  const CropPage({super.key, required this.bytes, required this.spec});

  final Uint8List bytes;
  final CropSpec spec;

  @override
  State<CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<CropPage> {
  CropController? _c;
  late Uint8List _src = widget.bytes;
  bool _failed = false;
  bool _busy = false;

  // Çimdik hareketinin başlangıç değerleri.
  double _startZoom = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Çok büyük kaynaklar (>6 MB) önce küçültülür: bellek ve çözümleme süresi.
      if (_src.length > 6 * 1024 * 1024) _src = await shrinkLarge(_src) ?? _src;
      final codec = await ui.instantiateImageCodec(_src);
      final f = await codec.getNextFrame();
      final w = f.image.width, h = f.image.height;
      f.image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() => _c = CropController(spec: widget.spec, imageWidth: w, imageHeight: h));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final c = _c;
    if (c == null || _busy) return;
    setState(() => _busy = true);
    Uint8List? out;
    try {
      out = await cropJpeg(_src, quarterTurns: c.quarterTurns, rect: c.toRect(), maxEdge: widget.spec.maxEdge);
    } catch (_) {
      out = null; // bellek yetersizliği / bozuk veri: hata verip yeniden denemeye izin ver
    }
    if (!mounted) return;
    if (out == null) {
      setState(() => _busy = false);
      BuToast.show(context, context.l10n.p04CropError, kind: BuToastKind.error);
      return;
    }
    Navigator.of(context).pop(CropOutcome.cropped(out));
  }

  String _title(AppLocalizations l) => switch (widget.spec.kind) {
        CropKind.profile => l.p04CropProfileTitle,
        CropKind.post => l.p04CropPostTitle,
        CropKind.logo => l.p04CropLogoTitle,
        CropKind.cover => l.p04CropCoverTitle,
        CropKind.chat => l.p04CropChatTitle,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const d = BuTokens.dark; // tuval her temada koyu
    final t = context.bu;
    final c = _c;
    return Scaffold(
      backgroundColor: d.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _TopBar(title: _title(l), onClose: () => Navigator.of(context).pop()),
          Expanded(
            child: _failed
                ? _Failed(onClose: () => Navigator.of(context).pop())
                : c == null
                    ? const Center(child: BuSkeletonScope(child: BuSkeleton(width: 240, height: 300, radius: 24)))
                    : ListenableBuilder(listenable: c, builder: (context, _) => _body(context, c, d, t, l)),
          ),
          if (c != null && !_failed) _ActionBar(busy: _busy, spec: widget.spec, onCancel: () => Navigator.of(context).pop(), onSave: _save),
        ]),
      ),
    );
  }

  Widget _body(BuildContext context, CropController c, BuTokens d, BuTokens t, AppLocalizations l) {
    final spec = widget.spec;
    final hasPreview = spec.kind != CropKind.profile && spec.kind != CropKind.chat;
    return CustomScrollView(
      slivers: [
        if (spec.kind == CropKind.profile)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _ProfilePanel(controller: c, bytes: _src),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _Stage(
              controller: c,
              bytes: _src,
              onScaleStart: (det) {
                _startZoom = c.zoom;
                _startOffset = c.offset;
                _startFocal = det.localFocalPoint;
              },
              onScaleUpdate: (det) => c.gesture(
                startZoom: _startZoom,
                factor: det.scale,
                startOffset: _startOffset,
                delta: det.localFocalPoint - _startFocal,
              ),
            ),
          ),
        ),
        // Açık alt yüzey kalan yüksekliği doldurur (ölü koyu boşluk kalmaz); araçlar + önizleme burada.
        SliverFillRemaining(
          hasScrollBody: false,
          child: DecoratedBox(
            decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Controls(controller: c),
                if (hasPreview) ...[
                  const SizedBox(height: 16),
                  _Previews(controller: c, bytes: _src, onOutcome: (o) => Navigator.of(context).pop(o)),
                ],
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    const d = BuTokens.dark;
    return SizedBox(
      height: 56,
      child: Row(children: [
        IconButton(
          key: const ValueKey('cropClose'),
          tooltip: context.l10n.postComposeClose,
          onPressed: onClose,
          icon: Icon(LucideIcons.x, color: d.ink),
        ),
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: d.ink, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 48),
      ]),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    const d = BuTokens.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.imageOff, size: 36, color: d.mut),
          const SizedBox(height: 12),
          Text(context.l10n.p04CropError,
              key: const ValueKey('cropError'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: d.ink)),
          const SizedBox(height: 16),
          BuButton(label: context.l10n.postComposeCancel, kind: BuButtonKind.soft, compact: true, onPressed: onClose),
        ]),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.busy, required this.spec, required this.onCancel, required this.onSave});

  final bool busy;
  final CropSpec spec;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final crop = spec.kind == CropKind.post;
    return ColoredBox(
      color: t.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(children: [
            Expanded(
              // Nötr (pembe değil): Vazgeç ikincil eylemdir.
              child: Material(
                key: const ValueKey('cropCancel'),
                color: t.sf2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md)),
                child: InkWell(
                  customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md)),
                  onTap: busy ? null : onCancel,
                  child: SizedBox(
                    height: BuSize.button,
                    child: Center(
                      child: Text(l.postComposeCancel,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BuButton(
                key: const ValueKey('cropSave'),
                label: crop ? l.p04CropCrop : l.postComposeSave,
                icon: crop ? LucideIcons.crop : LucideIcons.check,
                busy: busy,
                onPressed: busy ? null : onSave,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Görseli verilen merkez etrafına yerleştirir (döndürme + ölçek); tuval ve tüm önizlemeler bunu paylaşır.
class _Photo extends StatelessWidget {
  const _Photo({required this.controller, required this.bytes, required this.center});

  final CropController controller;
  final Uint8List bytes;

  /// Görsel merkezinin bulunduğu nokta (yerleşim alanının koordinatında).
  final Offset center;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final w = c.imageWidth * c.scale, h = c.imageHeight * c.scale;
    return Stack(clipBehavior: Clip.hardEdge, children: [
      Positioned(
        left: center.dx - w / 2,
        top: center.dy - h / 2,
        width: w,
        height: h,
        child: Transform.rotate(
          angle: c.quarterTurns * math.pi / 2,
          child: Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.medium),
        ),
      ),
    ]);
  }
}

/// Çerçevenin içini canlı gösterir (önizlemeler): sanal çerçeve boyutunda çizilip hedef boyuta ölçeklenir.
class _FrameView extends StatelessWidget {
  const _FrameView({required this.controller, required this.bytes});

  final CropController controller;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final f = c.frame;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: f.width,
        height: f.height,
        child: _Photo(controller: c, bytes: bytes, center: Offset(f.width / 2, f.height / 2) + c.offset),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.controller, required this.bytes, required this.onScaleStart, required this.onScaleUpdate});

  final CropController controller;
  final Uint8List bytes;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;

  static const pad = 28.0;

  /// Çerçevenin altında ipucu hapına ayrılan boşluk (çerçeve köşelerine binmesin).
  static const hintRoom = 36.0;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final f = c.frame;
    final stage = Size(f.width + pad * 2, f.height + pad * 2 + hintRoom);
    const d = BuTokens.dark;
    final l = context.l10n;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: d.sf2,
        child: AspectRatio(
          aspectRatio: stage.width / stage.height,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              key: const ValueKey('cropStage'),
              width: stage.width,
              height: stage.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: onScaleStart,
                onScaleUpdate: onScaleUpdate,
                child: Stack(children: [
                  Positioned.fill(
                    child: _Photo(controller: c, bytes: bytes, center: Offset(pad + f.width / 2, pad + f.height / 2) + c.offset),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _FramePainter(frame: Rect.fromLTWH(pad, pad, f.width, f.height), circle: c.spec.circle)),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: d.scrim.withValues(alpha: .6), borderRadius: BorderRadius.circular(999)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(LucideIcons.hand, size: 14, color: d.onMedia),
                              const SizedBox(width: 6),
                              Text(l.p04CropHint, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: d.onMedia, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.frame, required this.circle});

  final Rect frame;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final hole = circle ? (Path()..addOval(frame)) : (Path()..addRect(frame));
    canvas.drawPath(Path.combine(PathOperation.difference, all, hole), Paint()..color = BuTokens.dark.scrim.withValues(alpha: .58));
    final line = Paint()
      ..color = BuTokens.dark.onMedia.withValues(alpha: .4)
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final x = frame.left + frame.width * i / 3, y = frame.top + frame.height * i / 3;
      canvas.drawLine(Offset(x, frame.top), Offset(x, frame.bottom), line);
      canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), line);
    }
    canvas.drawRect(
        frame,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = BuTokens.dark.onMedia.withValues(alpha: .7));
    if (circle) {
      canvas.drawOval(
          frame,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = BuTokens.dark.onMedia.withValues(alpha: .85));
    }
    // Köşe tutamaçları.
    final h = Paint()
      ..color = BuTokens.dark.onMedia
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const L = 20.0;
    for (final (corner, dx, dy) in [
      (frame.topLeft, 1.0, 1.0),
      (frame.topRight, -1.0, 1.0),
      (frame.bottomLeft, 1.0, -1.0),
      (frame.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
          Path()
            ..moveTo(corner.dx, corner.dy + dy * L)
            ..lineTo(corner.dx, corner.dy)
            ..lineTo(corner.dx + dx * L, corner.dy),
          h);
    }
  }

  @override
  bool shouldRepaint(_FramePainter o) => o.frame != frame || o.circle != circle;
}

/// Döndür / Ortala / Sıfırla araçları + "Fotoğraf ölçeği" kartı (açık yüzey).
class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final CropController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = context.bu;
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    Widget tool(Key key, IconData icon, String label, VoidCallback onTap, {bool enabled = true, bool accent = false}) => Expanded(
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            enabled: enabled,
            child: GestureDetector(
              key: key,
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? onTap : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Opacity(
                  opacity: enabled ? 1 : .45,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: accent ? t.soft : t.sf2, shape: BoxShape.circle),
                      child: Icon(icon, size: 20, color: accent ? t.onSoft : t.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelMedium?.copyWith(color: accent ? t.onSoft : t.ink, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        );
    return Column(children: [
      Row(children: [
        tool(const ValueKey('cropRotate'), LucideIcons.rotateCw, l.p04CropRotate, c.rotate),
        tool(const ValueKey('cropCenter'), LucideIcons.focus, l.p04CropCenter, c.center, enabled: c.offset != Offset.zero),
        tool(const ValueKey('cropReset'), LucideIcons.rotateCcw, l.p04CropReset, c.reset, enabled: c.isDirty, accent: c.isDirty),
      ]),
      const SizedBox(height: 8),
      DecoratedBox(
        decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.md), border: Border.all(color: t.bd)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text(l.p04CropScale, style: tt.labelLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w600))),
              Text('${c.zoom.toStringAsFixed(1)}x',
                  key: const ValueKey('cropZoomValue'),
                  style: tt.labelLarge?.copyWith(color: t.mut, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
            Row(children: [
              IconButton(
                tooltip: l.p04CropScale,
                onPressed: () => c.setZoom(c.zoom - .25),
                icon: Icon(LucideIcons.minus, size: 18, color: t.mut),
              ),
              Expanded(
                child: Slider(key: const ValueKey('cropZoom'), value: c.zoom, min: 1, max: CropController.maxZoom, onChanged: c.setZoom),
              ),
              IconButton(
                tooltip: l.p04CropScale,
                onPressed: () => c.setZoom(c.zoom + .25),
                icon: Icon(LucideIcons.plus, size: 18, color: t.mut),
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.controller, required this.bytes});

  final CropController controller;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          _Round(size: 96, controller: controller, bytes: bytes, key: const ValueKey('cropPreviewBig')),
          const SizedBox(width: 16),
          _Round(size: 40, controller: controller, bytes: bytes),
          const SizedBox(width: 12),
          Expanded(
            child: Text(context.l10n.p04CropPreviewProfile,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({super.key, required this.size, required this.controller, required this.bytes});

  final double size;
  final CropController controller;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: ClipOval(child: _FrameView(controller: controller, bytes: bytes)),
      );
}

class _Previews extends StatelessWidget {
  const _Previews({required this.controller, required this.bytes, required this.onOutcome});

  final CropController controller;
  final Uint8List bytes;
  final ValueChanged<CropOutcome> onOutcome;

  @override
  Widget build(BuildContext context) {
    final spec = controller.spec;
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    Widget link(Key key, IconData icon, String label, VoidCallback onTap, {Color? color}) => Center(
          child: GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: color ?? t.pr),
                const SizedBox(width: 6),
                Text(label, style: tt.labelLarge?.copyWith(color: color ?? t.pr, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        );
    switch (spec.kind) {
      case CropKind.profile:
      case CropKind.chat:
        return const SizedBox.shrink();
      case CropKind.post:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.p04CropPreviewFeed, style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.lg), boxShadow: BuElevation.of(context, 1)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BuRadius.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    const BuAvatar(size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(spec.previewName ?? '',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                    ),
                    Icon(Icons.more_horiz, size: 18, color: t.ink),
                  ]),
                ),
                AspectRatio(aspectRatio: 4 / 5, key: const ValueKey('cropPreviewFeed'), child: _FrameView(controller: controller, bytes: bytes)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.favorite_border, size: 20, color: t.mut),
                      const SizedBox(width: 6),
                      Text('0', style: tt.labelLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                    ]),
                    if ((spec.previewCaption ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: spec.previewName ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: ' ${spec.previewCaption}'),
                        ]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(color: t.ink),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
          if (spec.allowChange) link(const ValueKey('cropChange'), LucideIcons.repeat, l.gonderiChangePhoto, () => onOutcome(const CropOutcome.change())),
        ]);
      case CropKind.logo:
        return DecoratedBox(
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.p04CropPreviewTitle, style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(children: [
                Column(children: [
                  _Round(size: 72, controller: controller, bytes: bytes, key: const ValueKey('cropPreviewBig')),
                  const SizedBox(height: 6),
                  Text(l.p04CropPreviewClubPage, style: tt.labelSmall?.copyWith(color: t.mut)),
                ]),
                const SizedBox(width: 20),
                Expanded(
                  child: Row(children: [
                    SizedBox.square(
                      dimension: 48,
                      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: _FrameView(controller: controller, bytes: bytes)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(spec.previewName ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                        Text(l.p04CropPreviewClubCard, style: tt.labelSmall?.copyWith(color: t.mut)),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ]),
          ),
        );
      case CropKind.cover:
        return Column(children: [
          DecoratedBox(
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.lg), boxShadow: BuElevation.of(context, 1)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BuRadius.lg),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                key: const ValueKey('cropPreviewCover'),
                child: Stack(fit: StackFit.expand, children: [
                  _FrameView(controller: controller, bytes: bytes),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [t.scrim.withValues(alpha: .7), t.scrim.withValues(alpha: 0)]),
                    ),
                  ),
                  if ((spec.previewDate ?? '').isNotEmpty)
                    PositionedDirectional(
                      top: 10,
                      end: 10,
                      child: DecoratedBox(
                        key: const ValueKey('cropPreviewDate'),
                        decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.pill)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(LucideIcons.calendar, size: 14, color: t.pr),
                            const SizedBox(width: 6),
                            Text(spec.previewDate!, style: tt.labelMedium?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                  PositionedDirectional(
                    start: 14,
                    end: 14,
                    bottom: 8,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      if ((spec.previewSubtitle ?? '').isNotEmpty)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(LucideIcons.users, size: 14, color: t.onMedia),
                          const SizedBox(width: 6),
                          Flexible(child: Text(spec.previewSubtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelMedium?.copyWith(color: t.onMedia))),
                        ]),
                      if ((spec.previewTitle ?? '').isNotEmpty)
                        Text(spec.previewTitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleLarge?.copyWith(color: t.onMedia, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          if (spec.allowRemove)
            link(const ValueKey('cropRemove'), LucideIcons.trash2, l.p04CropRemoveCover, () => onOutcome(const CropOutcome.removed()),
                color: t.danger),
        ]);
    }
  }
}
