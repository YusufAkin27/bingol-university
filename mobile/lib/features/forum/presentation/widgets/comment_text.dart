import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/theme.dart';

/// Uzun metni [maxLines] satırda keser ve "Devamını oku" / "Daha az göster" ile açar. Kesme gerekmiyorsa düz metin
/// çizilir (düğme yok). Ölçüm düzen genişliğiyle yapılır (yazı ölçeği ve dil değişince yeniden hesaplanır).
class CommentText extends StatefulWidget {
  const CommentText(this.text, {super.key, this.style, this.maxLines = 6});

  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  State<CommentText> createState() => _CommentTextState();
}

class _CommentTextState extends State<CommentText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final style = widget.style ?? Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.ink);
    return LayoutBuilder(builder: (context, c) {
      final scaler = MediaQuery.textScalerOf(context);
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: widget.maxLines,
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: c.maxWidth.isFinite ? c.maxWidth : 10000);
      final overflow = painter.didExceedMaxLines;
      painter.dispose();
      final text = Text(
        widget.text,
        style: style,
        maxLines: _open || !overflow ? null : widget.maxLines,
        overflow: _open || !overflow ? TextOverflow.clip : TextOverflow.ellipsis,
      );
      if (!overflow) return text;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.topStart,
          child: text,
        ),
        InkWell(
          key: const ValueKey('commentReadMore'),
          onTap: () => setState(() => _open = !_open),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              child: Text(_open ? l.forumCommentReadLess : l.forumCommentReadMore,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.prText)),
            ),
          ),
        ),
      ]);
    });
  }
}
