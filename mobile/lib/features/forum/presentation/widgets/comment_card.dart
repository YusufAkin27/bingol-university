import 'package:flutter/material.dart';

import '../../../../core/icons/bu_icons.dart';
import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../core/theme.dart';
import '../../../../core/theme/bu_shape.dart' show BuRadius;
import '../../../../core/theme/bu_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../widgets/bu_pressable.dart';
import '../../../../widgets/bu_widgets.dart';
import '../../../../widgets/common.dart' show relativeTime;
import '../../../posts/post_models.dart' show postAuthHeaders;
import 'comment_like_button.dart';
import 'comment_text.dart';
import 'comment_tree.dart';

/// Görünen yazar adı: anonimde sunucunun "Anonim #N" adı; silinmiş hesapta "Silinmiş hesap".
String commentAuthorName(BuildContext context, CommentNode n) {
  final l = context.l10n;
  if (n.authorGone) return l.forumDetailDeletedAccount;
  final name = n.author?.displayName ?? '';
  return name.isEmpty ? l.forumDetailDeletedAccount : name;
}

/// Yorum kartının dışarıya bağlandığı eylemler.
class CommentCardActions {
  const CommentCardActions({
    required this.onReply,
    required this.onMore,
    required this.onLike,
    required this.onOpenProfile,
  });

  final void Function(CommentNode) onReply;
  final void Function(CommentNode) onMore;
  final void Function(CommentNode) onLike;
  final void Function(CommentNode) onOpenProfile;
}

/// Tek yorum (Reddit tarzı iç içe konuşma satırı): girinti çizgileri + avatar + ad/zaman/etiketler + metin +
/// beğeni / Yanıtla / ⋯. Silinmiş yorum yer tutucu olarak çizilir ("Bu yorum silindi"), eylemleri yoktur.
class CommentCard extends StatelessWidget {
  const CommentCard({
    super.key,
    required this.node,
    required this.level,
    required this.session,
    required this.actions,
    this.highlighted = false,
    this.canReply = true,
  });

  final CommentNode node;
  final int level;
  final Session session;
  final CommentCardActions actions;
  final bool highlighted;

  /// false: kilitli konu (Yanıtla gizlenir).
  final bool canReply;

  static const double indentStep = 20;
  static const double _pad = 16;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final n = node;
    final start = _pad + level * indentStep;
    final avatar = level == 0 ? 32.0 : 28.0;

    final Widget content = n.deleted ? _deleted(context, tx, t) : _body(context, tx, t, avatar, l);

    return AnimatedContainer(
      key: ValueKey('commentCard-${n.id}'),
      duration: BuMotion.of(context, const Duration(milliseconds: 400)),
      curve: Curves.easeOut,
      color: highlighted ? t.soft.withValues(alpha: .5) : Colors.transparent,
      child: Stack(children: [
        // Girinti kılavuz çizgileri (her seviye için ince dikey çizgi).
        for (var i = 0; i < level; i++)
          PositionedDirectional(
            start: _pad + i * indentStep + 13,
            top: 0,
            bottom: 0,
            width: 1,
            child: ExcludeSemantics(child: ColoredBox(color: t.bdSubtle)),
          ),
        Padding(
          padding: EdgeInsetsDirectional.only(start: start, end: _pad, top: 8, bottom: 2),
          child: content,
        ),
      ]),
    );
  }

  Widget _avatar(BuildContext context, double size) {
    final n = node;
    final tappable = n.author?.userId != null && !n.deleted && !n.authorGone;
    final av = BuAvatar(
      name: commentAuthorName(context, n),
      url: n.author?.anonymous == true ? null : n.author?.avatarUrl,
      size: size,
      headers: postAuthHeaders(session),
    );
    if (!tappable) return av;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => actions.onOpenProfile(n),
      child: av,
    );
  }

  Widget _deleted(BuildContext context, TextTheme tx, BuTokens t) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        ExcludeSemantics(child: Icon(BuIcons.trash2, size: 16, color: t.mutSoft)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(l.forumCommentDeletedPlaceholder, key: const ValueKey('commentDeletedPlaceholder'), style: tx.bodyMedium!.copyWith(color: t.mut)),
        ),
      ]),
    );
  }

  Widget _body(BuildContext context, TextTheme tx, BuTokens t, double avatar, AppLocalizations l) {
    final n = node;
    final name = commentAuthorName(context, n);
    final time = relativeTime(n.createdAt, context: context);
    final tappableName = n.author?.userId != null && !n.authorGone;
    final nameText = Text(name,
        maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: n.authorGone ? t.mut : t.ink));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _avatar(context, avatar),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ad · zaman · etiketler: dar ekran / büyük yazıda satır kırılır.
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: tappableName
                    ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => actions.onOpenProfile(n), child: nameText)
                    : nameText,
              ),
              if (n.topicAuthor)
                Container(
                  key: const ValueKey('commentAuthorBadge'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.pill)),
                  child: Text(l.forumCommentAuthorBadge, style: tx.bodySmall!.copyWith(color: t.onSoft, fontSize: 11.5)),
                ),
              if (time.isNotEmpty) Text(time, style: tx.bodySmall!.copyWith(color: t.mut)),
              if (n.edited)
                Text(l.forumCommentEdited, key: const ValueKey('commentEdited'), style: tx.bodySmall!.copyWith(color: t.mut)),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => actions.onMore(n),
            child: CommentText(n.body ?? '', style: tx.bodyMedium!.copyWith(color: t.ink, height: 1.45)),
          ),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            CommentLikeButton(liked: n.likedByMe, count: n.likeCount, onTap: () => actions.onLike(n)),
            if (canReply)
              BuPressable(
                key: ValueKey('commentReply-${n.id}'),
                onTap: () => actions.onReply(n),
                haptic: BuHaptic.selection,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(BuIcons.reply, size: 18, color: t.mut),
                      const SizedBox(width: 6),
                      Text(l.forumCommentReply, style: tx.bodySmall!.copyWith(color: t.mut)),
                    ]),
                  ),
                ),
              ),
            Semantics(
              button: true,
              label: l.forumCommentMore,
              excludeSemantics: true,
              child: BuPressable(
                key: ValueKey('commentMore-${n.id}'),
                onTap: () => actions.onMore(n),
                haptic: BuHaptic.selection,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: Icon(BuIcons.ellipsis, size: 20, color: t.mut)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }
}
