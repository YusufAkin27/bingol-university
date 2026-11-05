import 'package:flutter/material.dart';

import '../../../../core/icons/bu_icons.dart';
import '../../../../core/locale_controller.dart';
import '../../../../core/theme.dart';
import '../../../../core/theme/bu_motion.dart';
import '../../../../widgets/bu_pressable.dart';

/// Yorum beğeni düğmesi: kalp + sayı. Dokununca anında dolar (iyimser güncelleme [CommentsController]'dadır);
/// beğenilince kalp kısa bir "pop" animasyonu yapar (hareket azaltılmışsa yok). Dokunma alanı en az 44 dp.
class CommentLikeButton extends StatefulWidget {
  const CommentLikeButton({
    super.key,
    required this.liked,
    required this.count,
    required this.onTap,
    this.enabled = true,
  });

  final bool liked;
  final int count;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<CommentLikeButton> createState() => _CommentLikeButtonState();
}

class _CommentLikeButtonState extends State<CommentLikeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));

  @override
  void didUpdateWidget(CommentLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.liked && widget.liked && !BuMotion.reduced(context)) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final liked = widget.liked;
    final color = liked ? t.heart : t.mut;
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 55),
    ]).animate(_pop);
    return Semantics(
      button: true,
      toggled: liked,
      label: liked ? l.forumCommentUnlikeSemantic(widget.count.toString()) : l.forumCommentLikeSemantic(widget.count.toString()),
      excludeSemantics: true,
      child: BuPressable(
        key: const ValueKey('commentLike'),
        onTap: widget.enabled ? widget.onTap : null,
        haptic: BuHaptic.selection,
        scale: .9,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ScaleTransition(
                scale: scale,
                child: Icon(liked ? BuIcons.heartFilled : BuIcons.heart, size: 20, color: color),
              ),
              if (widget.count > 0) ...[
                const SizedBox(width: 6),
                Text(widget.count.toString(),
                    style: tx.bodySmall!.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
