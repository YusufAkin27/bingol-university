import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'post_models.dart';

/// Dışarıdan (çift dokunuş gibi) beğeni tetiklemek için: yalnız beğenilmemişse beğenir.
class LikeController {
  _LikeButtonState? _state;

  /// Beğenilmemişse beğenir (çift dokunuş). Beğenilmişse hiçbir şey yapmaz.
  void like() => _state?._setLiked(true, onlyIfDifferent: true);

  bool get liked => _state?._liked ?? false;
}

/// Kalp + sayı. Dokununca İYİMSER günceller, 250 ms içindeki art arda dokunuşları birleştirip yalnız son durumu
/// sunucuya yollar (PUT/DELETE `/posts/{id}/like`); hata olursa son onaylı duruma döner.
class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.session,
    required this.post,
    this.onChanged,
    this.compact = false,
    this.controller,
    this.countLabel,
    this.size,
  });

  final Session session;
  final Post post;
  final ValueChanged<Post>? onChanged;
  final bool compact;
  final LikeController? controller;

  /// Sayacın metni (varsayılan: yalnız sayı); örn. "284 beğeni" için.
  final String Function(int count)? countLabel;

  /// Kalp boyutu (varsayılan 26, kompaktta 22).
  final double? size;

  static const debounce = Duration(milliseconds: 250);

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with TickerProviderStateMixin {
  late bool _liked = widget.post.likedByMe;
  late int _count = widget.post.likeCount;

  // Sunucunun son onayladığı durum.
  late bool _confirmedLiked = widget.post.likedByMe;
  late int _confirmedCount = widget.post.likeCount;

  Timer? _timer;
  bool _inflight = false;
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  // Sayaç değişimi: eski sayı yukarı kayıp solar, yenisi aşağıdan gelir.
  late final AnimationController _countAnim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 250), value: 1);
  int _prevCount = 0;

  Post get _post => widget.post;
  bool get _pending => _timer != null || _inflight;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(LikeButton old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller!._state = null;
      widget.controller?._state = this;
    }
    // Bekleyen istek yokken dışarıdan gelen durum esastır.
    if (!_pending && (widget.post.likedByMe != _liked || widget.post.likeCount != _count)) {
      _liked = _confirmedLiked = widget.post.likedByMe;
      _count = _confirmedCount = widget.post.likeCount;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    final flush = _timer != null;
    _timer?.cancel();
    _timer = null;
    _anim.dispose();
    _countAnim.dispose();
    // Ekrandan çıkarken bekleyen son durum kaybolmasın.
    if (flush && _liked != _confirmedLiked) {
      final api = widget.session.api;
      final id = _post.id;
      final want = _liked;
      unawaited((want ? api.put('/posts/$id/like') : api.delete('/posts/$id/like')).catchError((_) {}));
    }
    super.dispose();
  }

  String _label(int n) => widget.countLabel?.call(n) ?? '$n';
  void _toggle() => _setLiked(!_liked);

  /// Sayacı değiştirir; değer farklıysa eski sayı solarak yenisiyle yer değiştirir (setState içinde çağrılır).
  void _changeCount(int v) {
    if (v == _count) return;
    _prevCount = _count;
    _count = v;
    _countAnim.forward(from: 0);
  }

  void _setLiked(bool v, {bool onlyIfDifferent = false}) {
    if (onlyIfDifferent && _liked == v) return;
    HapticFeedback.selectionClick();
    setState(() {
      _liked = v;
      _changeCount(math.max(0, _confirmedCount + (v == _confirmedLiked ? 0 : (v ? 1 : -1))));
    });
    if (v) _anim.forward(from: 0);
    widget.onChanged?.call(_post.copyWith(likedByMe: _liked, likeCount: _count));
    _timer?.cancel();
    _timer = Timer(LikeButton.debounce, _flush);
  }

  Future<void> _flush() async {
    _timer = null;
    if (_inflight) return; // bitince yeniden bakılır
    if (_liked == _confirmedLiked) return;
    final want = _liked;
    _inflight = true;
    try {
      final api = widget.session.api;
      final r = want ? await api.put('/posts/${_post.id}/like') : await api.delete('/posts/${_post.id}/like');
      final res = LikeResult.fromJson(r is Map ? Map<String, dynamic>.from(r) : null);
      _confirmedLiked = res.liked;
      _confirmedCount = res.likeCount;
      _inflight = false;
      if (!mounted) return;
      if (_timer == null && _liked == want) {
        // Kullanıcı bu arada değiştirmediyse sunucu sayısını esas al.
        setState(() {
          _liked = res.liked;
          _changeCount(res.likeCount);
        });
        widget.onChanged?.call(_post.copyWith(likedByMe: _liked, likeCount: _count));
      } else if (_timer == null && _liked != _confirmedLiked) {
        await _flush();
      }
    } catch (e) {
      _inflight = false;
      if (!mounted) return;
      setState(() {
        _liked = _confirmedLiked;
        _changeCount(_confirmedCount);
      });
      widget.onChanged?.call(_post.copyWith(likedByMe: _liked, likeCount: _count));
      // İyimser güncelleme geri alındı: uyarı + "Tekrar dene" (aynı beğeni/vazgeçme yeniden denenir).
      BuToast.show(context, context.l10n.postViewLikeFailed,
          kind: BuToastKind.warning,
          actionLabel: context.l10n.commonRetryShort,
          onAction: () {
            if (mounted) _setLiked(want);
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final size = widget.size ?? (widget.compact ? 22.0 : 26.0);
    final color = _liked ? t.pr : t.mut;
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: .92).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: .92, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    ]).animate(_anim);

    // Kalp, fotoğrafın başlangıç kenarıyla hizalı (kutu yalnız dokunma hedefini büyütür).
    final heart = Semantics(
      button: true,
      label: _liked ? context.l10n.postViewUnlike : context.l10n.postViewLike,
      child: InkResponse(
        key: const ValueKey('like-heart'),
        onTap: _toggle,
        radius: 24,
        child: SizedBox(
          width: size + 10,
          height: 44,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (c, _) => CustomPaint(
                painter: _BurstPainter(progress: _anim.isAnimating ? _anim.value : 0, color: t.pr),
                child: Transform.scale(
                  scale: scale.value,
                  child: _HeartIcon(filled: _liked, color: color, size: size),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final style = (widget.compact ? tt.titleSmall : tt.titleMedium)?.copyWith(color: t.ink, height: 1.2);
    final countText = Text(_label(_count), key: const ValueKey('like-count'), maxLines: 1, style: style);
    final count = AnimatedBuilder(
      animation: _countAnim,
      builder: (c, _) {
        final v = Curves.easeOut.transform(_countAnim.value);
        if (v >= 1) return countText;
        return Stack(alignment: AlignmentDirectional.centerStart, children: [
          Opacity(
            opacity: 1 - v,
            child: Transform.translate(
                offset: Offset(0, -8 * v), child: Text(_label(_prevCount), maxLines: 1, style: style)),
          ),
          Opacity(
            opacity: v,
            child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: countText),
          ),
        ]);
      },
    );

    return Row(mainAxisSize: MainAxisSize.min, children: [
      heart,
      if (_count > 0 || _countAnim.value < 1)
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: count,
        ),
    ]);
  }
}

class _HeartIcon extends StatelessWidget {
  const _HeartIcon({required this.filled, required this.color, required this.size});

  final bool filled;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Tasarım 17: dolu kalp ve çizgi kalp aynı Material kalp ailesindendir.
    return Icon(filled ? Icons.favorite : Icons.favorite_border, size: size, color: color);
  }
}

/// Kalbin etrafında kısa süre dağılan sekiz nokta + yumuşak ışıma (tasarım 17, ekran 2).
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final c = size.center(Offset.zero);
    final fade = (1 - progress).clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      30,
      Paint()
        ..color = color.withValues(alpha: .28 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    final p = Paint()..color = color.withValues(alpha: .75 * fade);
    const n = 8;
    final r = 17 + 12 * Curves.easeOut.transform(progress);
    for (var i = 0; i < n; i++) {
      final a = (i / n) * 2 * math.pi;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, 3 * fade + .8, p);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter o) => o.progress != progress || o.color != color;
}

/// Medyaya çift dokunuşla beğeni: büyük kalp belirir ve söner. [onLike] her çift dokunuşta çağrılır
/// (çağıran yalnız beğenilmemişse beğenmeli: [LikeController.like] bunu yapar). [onTap] verilirse tek dokunuş
/// için kullanılır.
class DoubleTapLike extends StatefulWidget {
  const DoubleTapLike({super.key, required this.child, required this.onLike, this.onTap, this.onLongPress, this.radius = 0});

  final Widget child;
  final VoidCallback onLike;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Kararma katmanının köşe yarıçapı (çocuğun köşesiyle aynı olmalı).
  final double radius;

  @override
  State<DoubleTapLike> createState() => _DoubleTapLikeState();
}

class _DoubleTapLikeState extends State<DoubleTapLike> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _double() {
    widget.onLike();
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: .3, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 20),
    ]).animate(_c);
    final opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_c);
    final t = context.bu;
    final dim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_c);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _double,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Stack(alignment: Alignment.center, children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (c, _) => _c.isAnimating
                  ? Stack(alignment: Alignment.center, children: [
                      // Fotoğraf hafif kararır (köşeler fotoğrafla aynı yuvarlaklıkta).
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(widget.radius),
                          child: ColoredBox(color: t.scrim.withValues(alpha: .18 * dim.value.clamp(0, 1))),
                        ),
                      ),
                      Opacity(
                        opacity: opacity.value.clamp(0, 1),
                        child: Transform.scale(
                          scale: scale.value,
                          child: Icon(Icons.favorite,
                              key: const ValueKey('double-tap-heart'),
                              size: 88,
                              color: t.onMedia,
                              shadows: [Shadow(color: t.scrim.withValues(alpha: .3), blurRadius: 16)]),
                        ),
                      ),
                    ])
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ]),
    );
  }
}
