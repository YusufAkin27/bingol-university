import 'package:flutter/material.dart';

import '../../../core/locale_controller.dart';
import '../../../core/session.dart';
import '../../../widgets/bu.dart';
import 'comment_sheet.dart';
import 'comments_api.dart';

/// Gönderi kartı eylem satırında beğeninin yanındaki yorum simgesi + sayı. Dokununca yorum alt sayfası açılır;
/// sayfada ekleme/silme sayacı anında günceller ([onCountChanged] üst katmanı da haberdar eder).
class CommentButton extends StatefulWidget {
  const CommentButton({
    super.key,
    required this.session,
    required this.postId,
    required this.count,
    this.onCountChanged,
    this.size = 22,
    this.api,
  });

  final Session session;
  final int postId;
  final int count;
  final ValueChanged<int>? onCountChanged;
  final double size;

  /// Test için sahte erişim; null: gerçek uçlar.
  final CommentsApi? api;

  @override
  State<CommentButton> createState() => _CommentButtonState();
}

class _CommentButtonState extends State<CommentButton> {
  late int _count = widget.count;

  @override
  void didUpdateWidget(covariant CommentButton old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) _count = widget.count;
  }

  Future<void> _open() => showCommentSheet(
        context,
        session: widget.session,
        postId: widget.postId,
        commentCount: _count,
        api: widget.api,
        onCountChanged: (n) {
          if (mounted) setState(() => _count = n);
          widget.onCountChanged?.call(n);
        },
      );

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      button: true,
      label: l.kesActionComments,
      value: l.pcmCommentCountA11y('$_count'),
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('post-comments-${widget.postId}'),
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(BuIcons.messageCircle, size: widget.size, color: t.ink),
              if (_count > 0) ...[
                const SizedBox(width: 4),
                Text('$_count',
                    key: const ValueKey('comment-count'),
                    maxLines: 1,
                    style: tt.titleSmall?.copyWith(
                        fontSize: 15, fontWeight: BuType.emphasisWeight, color: t.ink, height: 1.2, fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
