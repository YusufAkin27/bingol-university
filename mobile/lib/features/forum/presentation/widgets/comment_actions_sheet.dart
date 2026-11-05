import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/icons/bu_icons.dart';
import '../../../../core/locale_controller.dart';
import '../../../../core/theme.dart';
import '../../../../widgets/bu_overlays.dart';
import 'comment_tree.dart';
import 'forum_sheet_row.dart';

/// Yorum eylem sayfasındaki seçenekler.
enum CommentAction { reply, edit, delete, copy, share, like, save, report, block }

/// Gösterilecek eylemler (sıralı). Yetki yalnız GÖSTERİM içindir (`mine`); sunucu yine reddeder.
/// Tehlikeli eylemler (sil / şikâyet / engelle) listenin sonunda, ayrı bir blokta ve uyarı renginde durur.
List<CommentAction> commentActionsFor(CommentNode n, {required bool canReply}) {
  if (n.deleted) return const [];
  return [
    if (canReply) CommentAction.reply,
    if (!n.mine) CommentAction.like,
    CommentAction.save,
    CommentAction.copy,
    CommentAction.share,
    if (n.mine) CommentAction.edit,
    if (n.mine) CommentAction.delete,
    if (!n.mine) CommentAction.report,
    if (!n.mine) CommentAction.block,
  ];
}

bool _danger(CommentAction a) => a == CommentAction.delete || a == CommentAction.report || a == CommentAction.block;

/// Yorum için alt sayfa (uzun basma / ⋯). Seçilen eylemi döner, vazgeçilirse null.
/// Hafif titreşim (selectionClick), yuvarlak üst köşe ([BuSheet]), koyu mod uyumlu.
Future<CommentAction?> showCommentActionsSheet(
  BuildContext context, {
  required CommentNode node,
  required bool canReply,
}) async {
  final actions = commentActionsFor(node, canReply: canReply);
  if (actions.isEmpty) return null;
  HapticFeedback.selectionClick();
  return BuSheet.show<CommentAction>(
    context,
    scrollable: true,
    padding: EdgeInsets.zero,
    builder: (ctx) {
      final t = ctx.bu;
      final safe = actions.where((a) => !_danger(a)).toList();
      final danger = actions.where(_danger).toList();
      return Column(
        key: const ValueKey('commentActionsSheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < safe.length; i++) ...[
            if (i > 0) Divider(height: 1, color: t.bdSubtle),
            _Row(action: safe[i], node: node),
          ],
          if (danger.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, thickness: 1, color: t.bd),
            ),
            for (var i = 0; i < danger.length; i++) ...[
              if (i > 0) Divider(height: 1, color: t.bdSubtle),
              _Row(action: danger[i], node: node),
            ],
          ],
          SizedBox(height: MediaQuery.paddingOf(ctx).bottom > 0 ? 0 : 8),
        ],
      );
    },
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.action, required this.node});

  final CommentAction action;
  final CommentNode node;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final (icon, label) = switch (action) {
      CommentAction.reply => (BuIcons.reply, l.forumCommentReply),
      CommentAction.edit => (BuIcons.pencil, l.forumCommentActionEdit),
      CommentAction.delete => (BuIcons.trash2, l.forumCommentActionDelete),
      CommentAction.copy => (BuIcons.copy, l.forumCommentActionCopy),
      CommentAction.share => (BuIcons.send, l.forumCommentActionShare),
      CommentAction.like =>
        node.likedByMe ? (BuIcons.heartFilled, l.forumCommentActionUnlike) : (BuIcons.heart, l.forumCommentActionLike),
      CommentAction.save =>
        node.savedByMe ? (BuIcons.bookmarkFilled, l.forumCommentActionUnsave) : (BuIcons.bookmark, l.forumCommentActionSave),
      CommentAction.report => (BuIcons.flag, l.forumCommentActionReport),
      CommentAction.block => (BuIcons.ban, l.forumCommentActionBlock),
    };
    return ForumSheetRow<CommentAction>(
      key: ValueKey('commentAction-${action.name}'),
      icon: icon,
      label: label,
      value: action,
      danger: _danger(action),
      iconColor: action == CommentAction.like && node.likedByMe ? t.prText : null,
    );
  }
}
