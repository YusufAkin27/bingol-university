import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart' show LucideIcons;
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
  });

  final Session session;
  final Post post;
  final ValueChanged<Post>? onChanged;
  final bool compact;
  final LikeController? controller;

  static const debounce = Duration(milliseconds: 250);

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  late bool _liked = widget.post.likedByMe;
  late int _count = widget.post.likeCount;

  // Sunucunun son onayladığı durum.
  late bool _confirmedLiked = widget.post.likedByMe;
  late int _confirmedCount = widget.post.likeCount;

  Timer? _timer;
  bool _inflight = false;
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

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
    // Ekrandan çıkarken bekleyen son durum kaybolmasın.
    if (flush && _liked != _confirmedLiked) {
      final api = widget.session.api;
      final id = _post.id;
      final want = _liked;
      unawaited((want ? api.put('/posts/$id/like') : api.delete('/posts/$id/like')).catchError((_) {}));
    }
    super.dispose();
  }

  void _toggle() => _setLiked(!_liked);

  void _setLiked(bool v, {bool onlyIfDifferent = false}) {
    if (onlyIfDifferent && _liked == v) return;
    HapticFeedback.selectionClick();
    setState(() {
      _liked = v;
      _count = math.max(0, _confirmedCount + (v == _confirmedLiked ? 0 : (v ? 1 : -1)));
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
          _count = res.likeCount;
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
        _count = _confirmedCount;
      });
      widget.onChanged?.call(_post.copyWith(likedByMe: _liked, likeCount: _count));
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(errorText(e).isEmpty ? context.l10n.postViewLikeFailed : errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final size = widget.compact ? 20.0 : 24.0;
    final color = _liked ? BuColors.red600 : t.mut;
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.38).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.38, end: .92).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: .92, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    ]).animate(_anim);

    final heart = Semantics(
      button: true,
      label: _liked ? context.l10n.postViewUnlike : context.l10n.postViewLike,
      child: InkResponse(
        key: const ValueKey('like-heart'),
        onTap: _toggle,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (c, _) => CustomPaint(
                painter: _BurstPainter(progress: _anim.isAnimating ? _anim.value : 0, color: BuColors.red600),
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

    final countText = Text(
      '$_count',
      key: const ValueKey('like-count'),
      maxLines: 1,
      style: (widget.compact ? BuType.caption : BuType.label).copyWith(color: _liked ? BuColors.red600 : t.mut),
    );

    return Row(mainAxisSize: MainAxisSize.min, children: [
      heart,
      if (_count > 0)
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: countText,
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
    // Lucide kalbi çizgi ikonudur; dolgu için aynı yolu Material'ın dolu kalbiyle değiştiriyoruz.
    return filled
        ? Icon(Icons.favorite, size: size, color: color)
        : Icon(LucideIcons.heart, size: size, color: color);
  }
}

/// Kalbin etrafında kısa süre dağılan küçük parçacıklar.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final c = size.center(Offset.zero);
    final p = Paint()..color = color.withValues(alpha: (1 - progress).clamp(0, 1));
    const n = 7;
    final r = 10 + 14 * Curves.easeOut.transform(progress);
    for (var i = 0; i < n; i++) {
      final a = (i / n) * 2 * math.pi;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, 2.2 * (1 - progress) + .6, p);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter o) => o.progress != progress || o.color != color;
}

/// Medyaya çift dokunuşla beğeni: büyük kalp belirir ve söner. [onLike] her çift dokunuşta çağrılır
/// (çağıran yalnız beğenilmemişse beğenmeli: [LikeController.like] bunu yapar). [onTap] verilirse tek dokunuş
/// için kullanılır.
class DoubleTapLike extends StatefulWidget {
  const DoubleTapLike({super.key, required this.child, required this.onLike, this.onTap});

  final Widget child;
  final VoidCallback onLike;
  final VoidCallback? onTap;

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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _double,
      onTap: widget.onTap,
      child: Stack(alignment: Alignment.center, children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (c, _) => _c.isAnimating
                  ? Center(
                      child: Opacity(
                        opacity: opacity.value.clamp(0, 1),
                        child: Transform.scale(
                          scale: scale.value,
                          child: const Icon(Icons.favorite,
                              key: ValueKey('double-tap-heart'),
                              size: 88,
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black38, blurRadius: 16)]),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ]),
    );
  }
}
