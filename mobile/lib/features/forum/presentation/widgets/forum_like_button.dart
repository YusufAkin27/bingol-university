import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_models.dart';

/// Konu/yorum beğenisi: kalp + sayı. Dokununca İYİMSER günceller, 250 ms içindeki art arda dokunuşları birleştirip yalnız
/// son durumu sunucuya yollar ([onToggle]); hata olursa son onaylı duruma döner ve "Tekrar dene" bildirimi çıkar.
/// Aynı yorumu iki kez beğenme sunucuda PK ile engellenir; istemci yalnız son istenen durumu gönderir.
///
/// Kalp dolu/boş geçişi ve hafif yay animasyonu (hareket azaltılmışsa yok). [onChanged] her iyimser/onaylı değişimde
/// (liked, count) ile çağrılır: üst liste kendi modelini günceller.
class ForumLikeButton extends StatefulWidget {
  const ForumLikeButton({
    super.key,
    required this.liked,
    required this.count,
    required this.onToggle,
    this.onChanged,
    this.size = 22,
    this.enabled = true,
  });

  final bool liked;
  final int count;

  /// `want` true: beğen (PUT), false: vazgeç (DELETE). Sunucu sonucunu döndürür.
  final Future<ForumLikeResult> Function(bool want) onToggle;
  final void Function(bool liked, int count)? onChanged;
  final double size;
  final bool enabled;

  static const debounce = Duration(milliseconds: 250);

  @override
  State<ForumLikeButton> createState() => _ForumLikeButtonState();
}

class _ForumLikeButtonState extends State<ForumLikeButton> with SingleTickerProviderStateMixin {
  late bool _liked = widget.liked;
  late int _count = widget.count;
  late bool _confirmedLiked = widget.liked;
  late int _confirmedCount = widget.count;
  Timer? _timer;
  bool _inflight = false;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  bool get _pending => _timer != null || _inflight;

  @override
  void didUpdateWidget(ForumLikeButton old) {
    super.didUpdateWidget(old);
    // Bekleyen istek yokken dışarıdan gelen durum esastır.
    if (!_pending && (widget.liked != _liked || widget.count != _count)) {
      _liked = _confirmedLiked = widget.liked;
      _count = _confirmedCount = widget.count;
    }
  }

  @override
  void dispose() {
    final flush = _timer != null && _liked != _confirmedLiked;
    _timer?.cancel();
    _timer = null;
    _anim.dispose();
    // Ekrandan çıkarken bekleyen son durum kaybolmasın (sonuç yok sayılır).
    if (flush) unawaited(widget.onToggle(_liked).then((_) {}, onError: (Object _) {}));
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled) return;
    _set(!_liked);
  }

  void _set(bool v) {
    buHaptic(v ? BuHaptic.light : BuHaptic.selection);
    setState(() {
      _liked = v;
      _count = math.max(0, _confirmedCount + (v == _confirmedLiked ? 0 : (v ? 1 : -1)));
    });
    if (v && !BuMotion.reduced(context)) _anim.forward(from: 0);
    widget.onChanged?.call(_liked, _count);
    _timer?.cancel();
    _timer = Timer(ForumLikeButton.debounce, _flush);
  }

  Future<void> _flush() async {
    _timer = null;
    if (_inflight) return;
    if (_liked == _confirmedLiked) return;
    final want = _liked;
    _inflight = true;
    try {
      final r = await widget.onToggle(want);
      _confirmedLiked = r.liked;
      _confirmedCount = r.likeCount;
      _inflight = false;
      if (!mounted) return;
      if (_timer == null && _liked == want) {
        // Kullanıcı bu arada değiştirmediyse sunucu sayısı esastır (sayılar backend ile senkron).
        setState(() {
          _liked = r.liked;
          _count = r.likeCount;
        });
        widget.onChanged?.call(_liked, _count);
      } else if (_timer == null && _liked != _confirmedLiked) {
        await _flush();
      }
    } catch (_) {
      _inflight = false;
      if (!mounted) return;
      setState(() {
        _liked = _confirmedLiked;
        _count = _confirmedCount;
      });
      widget.onChanged?.call(_liked, _count);
      BuToast.show(context, context.l10n.forumHomeLikeFailed,
          kind: BuToastKind.warning,
          actionLabel: context.l10n.commonRetryShort,
          onAction: () {
            if (mounted) _set(want);
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final color = _liked ? t.heart : t.mut;
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 60),
    ]).animate(_anim);
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: _liked ? t.heart : t.mut,
      fontWeight: FontWeight.w400,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      button: true,
      toggled: _liked,
      label: _liked ? l.forumHomeUnlike : l.forumHomeLike,
      value: l.forumHomeLikesA11y('$_count'),
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('forum-like'),
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BuSize.touch, minWidth: BuSize.touch),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: BuSize.touch - 8,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (_, __) => Transform.scale(
                      scale: scale.value,
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: color),
                        duration: BuMotion.of(context, BuMotion.short),
                        builder: (_, c, __) =>
                            Icon(_liked ? BuIcons.heartFilled : BuIcons.heart, size: widget.size, color: c ?? color),
                      ),
                    ),
                  ),
                ),
              ),
              if (_count > 0) Text('$_count', key: const ValueKey('forum-like-count'), style: style),
            ]),
          ),
        ),
      ),
    );
  }
}
