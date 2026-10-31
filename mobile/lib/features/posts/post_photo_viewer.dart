import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'post_card.dart';
import 'post_models.dart';

/// Gönderi fotoğrafını tam ekran açar: iki parmakla yakınlaştırma, çift dokunuşla yakınlaştır/uzaklaştır,
/// yakınlaştırılmamışken aşağı/yukarı sürükleyerek kapatma (arka plan sürükledikçe açılır). [heroTag] listeden
/// gelen etiketse fotoğraf detaydan buraya paylaşılan öğe olarak uçar.
Future<void> openPostPhotoViewer(BuildContext context, Session session, Post post, {Object? heroTag}) {
  if (post.photo == null) return Future<void>.value();
  return Navigator.of(context).push<void>(PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: false,
    transitionDuration: BuMotion.medium,
    reverseTransitionDuration: BuMotion.short,
    pageBuilder: (_, __, ___) => PostPhotoViewer(session: session, post: post, heroTag: heroTag),
    transitionsBuilder: (context, animation, _, child) {
      if (BuMotion.reduced(context)) return child;
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: BuMotion.standard),
        child: child,
      );
    },
  ));
}

class PostPhotoViewer extends StatefulWidget {
  const PostPhotoViewer({super.key, required this.session, required this.post, this.heroTag});

  final Session session;
  final Post post;
  final Object? heroTag;

  @override
  State<PostPhotoViewer> createState() => _PostPhotoViewerState();
}

class _PostPhotoViewerState extends State<PostPhotoViewer> with TickerProviderStateMixin {
  /// Kapatma eşiği (dp) ve hız (dp/sn).
  static const _dismissDistance = 110.0;
  static const _dismissVelocity = 800.0;

  final _tc = TransformationController();
  final _dy = ValueNotifier<double>(0);
  late final AnimationController _zoomAnim = AnimationController(vsync: this, duration: BuMotion.medium);
  late final AnimationController _backAnim = AnimationController(vsync: this, duration: BuMotion.short);
  Matrix4Tween? _zoomTween;
  Tween<double>? _backTween;
  Offset _focal = Offset.zero;
  bool _zoomed = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransform);
    _zoomAnim.addListener(() {
      final tw = _zoomTween;
      if (tw != null) _tc.value = tw.lerp(BuMotion.standard.transform(_zoomAnim.value));
    });
    _backAnim.addListener(() {
      final tw = _backTween;
      if (tw != null) _dy.value = tw.transform(BuMotion.standard.transform(_backAnim.value));
    });
  }

  @override
  void dispose() {
    _zoomAnim.dispose();
    _backAnim.dispose();
    _tc.dispose();
    _dy.dispose();
    super.dispose();
  }

  void _onTransform() {
    final z = _tc.value.getMaxScaleOnAxis() > 1.02;
    if (z != _zoomed) setState(() => _zoomed = z);
  }

  void _toggleZoom() {
    const s = 2.5;
    final end = _zoomed
        ? Matrix4.identity()
        : Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, -_focal.dx * (s - 1), -_focal.dy * (s - 1), 0, 1);
    buHaptic(BuHaptic.selection);
    if (BuMotion.reduced(context)) {
      _tc.value = end;
      return;
    }
    _zoomTween = Matrix4Tween(begin: _tc.value, end: end);
    _zoomAnim.forward(from: 0);
  }

  void _onUpdate(ScaleUpdateDetails d) {
    // Yalnız tek parmakla ve yakınlaştırılmamışken sürükleme kapatma jestidir.
    if (_zoomed || d.pointerCount != 1 || (d.scale - 1).abs() > .02) return;
    _dragging = true;
    _backAnim.stop();
    _dy.value += d.focalPointDelta.dy;
  }

  void _onEnd(ScaleEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final v = d.velocity.pixelsPerSecond.dy;
    final far = _dy.value.abs() > _dismissDistance || (v.abs() > _dismissVelocity && v.sign == _dy.value.sign);
    if (far) {
      buHaptic(BuHaptic.light);
      Navigator.of(context).maybePop();
      return;
    }
    if (_dy.value == 0) return;
    if (BuMotion.reduced(context)) {
      _dy.value = 0;
      return;
    }
    _backTween = Tween(begin: _dy.value, end: 0);
    _backAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final size = MediaQuery.sizeOf(context);
    final tag = widget.heroTag;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Arka plan: sürükledikçe açılır (yalnız opacity).
          IgnorePointer(
            child: ValueListenableBuilder<double>(
              valueListenable: _dy,
              builder: (_, dy, __) => ColoredBox(
                color: t.scrim.withValues(alpha: 1 - (dy.abs() / (size.height * .5)).clamp(0.0, 1.0)),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onDoubleTapDown: (d) => _focal = d.localPosition,
            onDoubleTap: _toggleZoom,
            child: ValueListenableBuilder<double>(
              valueListenable: _dy,
              child: InteractiveViewer(
                transformationController: _tc,
                minScale: 1,
                maxScale: 4,
                onInteractionUpdate: _onUpdate,
                onInteractionEnd: _onEnd,
                child: Center(
                  child: PostPhoto(
                    session: widget.session,
                    post: widget.post,
                    radius: 0,
                    progressive: true,
                    // Yakınlaştırılmışsa geri uçuş yok (kare yer değiştirmiş olur): etiket değişir, eşleşmez.
                    heroTag: tag == null ? null : (_zoomed ? '$tag-zoomed' : tag),
                  ),
                ),
              ),
              builder: (_, dy, child) => Transform.translate(offset: Offset(0, dy), child: child),
            ),
          ),
          PositionedDirectional(
            top: MediaQuery.paddingOf(context).top + BuSpace.sm,
            start: BuSpace.sm,
            child: AnimatedOpacity(
              opacity: _zoomed ? 0 : 1,
              duration: BuMotion.of(context, BuMotion.short),
              child: IgnorePointer(
                ignoring: _zoomed,
                child: Tooltip(
                  message: context.l10n.chatMiscClose,
                  child: BuPressable(
                    key: const ValueKey('postViewerClose'),
                    onTap: () => Navigator.of(context).maybePop(),
                    semanticLabel: context.l10n.chatMiscClose,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      // Stitch v3 03: saf siyah zemin, tek beyaz 24 dp "x" (48 dp hedef), zemin dairesi yok.
                      child: Center(child: Icon(LucideIcons.x, size: 24, color: t.onMedia)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
