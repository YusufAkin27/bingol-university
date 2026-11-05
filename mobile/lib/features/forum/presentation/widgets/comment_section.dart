import 'package:flutter/material.dart';

import '../../../../core/api.dart' show ApiError;
import '../../../../core/icons/bu_icon_helpers.dart';
import '../../../../core/icons/bu_icons.dart';
import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../core/theme.dart';
import '../../../../core/theme/bu_motion.dart';
import '../../../../core/theme/bu_shape.dart';
import '../../../../widgets/bu_pressable.dart';
import '../../../../widgets/bu_skeleton.dart';
import '../../../../widgets/bu_state.dart';
import '../../data/forum_models.dart';
import 'comment_card.dart';
import 'comment_controller.dart';
import 'comment_tree.dart';

/// Yorum satırlarını (yorum, yanıt düğmeleri, zincir, yükleniyor, hata) çizen tek parça. Satırın görünürlüğü
/// [_Reveal] ile yumuşak açılıp kapanır: yeni gelen yanıtlar boyu büyüyerek belirir, "Yanıtları gizle" ile kapanır.
class CommentRowTile extends StatelessWidget {
  const CommentRowTile({
    super.key,
    required this.row,
    required this.controller,
    required this.session,
    required this.actions,
    required this.onOpenChain,
    this.canReply = true,
  });

  final CommentRow row;
  final CommentsController controller;
  final Session session;
  final CommentCardActions actions;
  final void Function(CommentNode) onOpenChain;
  final bool canReply;

  @override
  Widget build(BuildContext context) {
    final n = row.node;
    final fresh = controller.freshIds.contains(n.id) && row.kind == CommentRowKind.comment;
    final Widget child = switch (row.kind) {
      CommentRowKind.comment => CommentCard(
          node: n,
          level: row.level,
          session: session,
          actions: actions,
          canReply: canReply,
          highlighted: controller.highlightId == n.id,
        ),
      CommentRowKind.footer => CommentRepliesFooter(node: n, level: row.level, controller: controller),
      CommentRowKind.chain => _ChainButton(node: n, level: row.level, onTap: () => onOpenChain(n)),
      CommentRowKind.loading => _RepliesLoading(level: row.level),
      CommentRowKind.error => _RepliesError(node: n, level: row.level, controller: controller),
    };
    return _Reveal(visible: !row.exiting, animateIn: fresh, child: child);
  }
}

/// Boy + opaklık animasyonu: [visible] false iken yükseklik 0'a iner (içerik ağaçta kalır, kapanırken görünür).
class _Reveal extends StatelessWidget {
  const _Reveal({required this.visible, required this.animateIn, required this.child});

  final bool visible;
  final bool animateIn;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = BuMotion.of(context, const Duration(milliseconds: 200));
    if (d == Duration.zero) return visible ? child : const SizedBox(width: double.infinity);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: animateIn ? 0 : null, end: visible ? 1 : 0),
      duration: d,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, v, c) {
        if (v >= 1) return c!;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: v.clamp(0.0, 1.0),
            child: Opacity(opacity: v.clamp(0.0, 1.0), child: c),
          ),
        );
      },
    );
  }
}

EdgeInsetsDirectional _indent(int level) =>
    EdgeInsetsDirectional.only(start: 16 + level * CommentCard.indentStep + 2, end: 16);

/// "N yanıtı göster" / "Yanıtları gizle" / "N yanıt daha".
class CommentRepliesFooter extends StatelessWidget {
  const CommentRepliesFooter({super.key, required this.node, required this.level, required this.controller});

  final CommentNode node;
  final int level;
  final CommentsController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = node;
    final children = <Widget>[];
    if (!n.expanded) {
      final count = n.replyCount > 0 ? n.replyCount : n.children.length;
      if (count <= 0) return const SizedBox.shrink();
      children.add(_FooterLink(
        key: ValueKey('commentShowReplies-${n.id}'),
        label: l.forumCommentShowReplies(count.toString()),
        icon: BuIcons.chevronDown,
        onTap: () => controller.showReplies(n),
      ));
    } else {
      if (n.hasMoreReplies && !n.loadingReplies && n.repliesError == null) {
        final hidden = n.hiddenReplyCount;
        children.add(_FooterLink(
          key: ValueKey('commentMoreReplies-${n.id}'),
          label: n.repliesLoaded || hidden <= 0
              ? l.forumCommentMoreRepliesGeneric
              : l.forumCommentMoreReplies(hidden.toString()),
          icon: BuIcons.chevronDown,
          onTap: () => n.repliesLoaded ? controller.loadMoreReplies(n) : controller.loadReplies(n),
        ));
      }
      if (n.children.isNotEmpty) {
        children.add(_FooterLink(
          key: ValueKey('commentHideReplies-${n.id}'),
          label: l.forumCommentHideReplies,
          icon: BuIcons.chevronUp,
          muted: true,
          onTap: () => controller.hideReplies(n),
        ));
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: _indent(level),
      child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: children),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({super.key, required this.label, required this.icon, required this.onTap, this.muted = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final color = muted ? t.mut : t.ink;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: BuPressable(
        onTap: onTap,
        haptic: BuHaptic.selection,
        scale: .97,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: tx.bodySmall!.copyWith(color: color))),
            const SizedBox(width: 8),
          ]),
        ),
      ),
    );
  }
}

/// Girinti sınırından derin zincir: "Yanıt zincirini aç · N yanıt".
class _ChainButton extends StatelessWidget {
  const _ChainButton({required this.node, required this.level, required this.onTap});

  final CommentNode node;
  final int level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final label = l.forumCommentOpenChain(node.replyCount.toString());
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 16 + level * CommentCard.indentStep + 38, end: 16),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: BuPressable(
          key: ValueKey('commentChain-${node.id}'),
          onTap: onTap,
          haptic: BuHaptic.selection,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(BuIcons.messageCircle, size: 18, color: t.ink),
              const SizedBox(width: 8),
              Flexible(child: Text(label, style: tx.bodySmall!.copyWith(color: t.ink))),
              const SizedBox(width: 4),
              Icon(buIconDirection(context, BuIcons.chevronRight), size: 18, color: t.ink),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RepliesLoading extends StatelessWidget {
  const _RepliesLoading({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      liveRegion: true,
      label: l.commonLoading,
      child: BuSkeletonScope(
        child: Padding(
          key: const ValueKey('commentRepliesLoading'),
          padding: EdgeInsetsDirectional.only(start: 16 + level * CommentCard.indentStep, end: 16, top: 8, bottom: 8),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BuSkeleton.circle(28),
            SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                BuSkeleton.line(width: 110),
                SizedBox(height: 8),
                BuSkeleton.line(),
                SizedBox(height: 6),
                BuSkeleton.line(width: 160),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RepliesError extends StatelessWidget {
  const _RepliesError({required this.node, required this.level, required this.controller});

  final CommentNode node;
  final int level;
  final CommentsController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: _indent(level),
      child: Row(children: [
        Icon(BuIcons.circleAlert, size: 18, color: t.danger),
        const SizedBox(width: 8),
        Expanded(child: Text(l.forumCommentRepliesFailed, style: tx.bodySmall!.copyWith(color: t.mut))),
        TextButton(
          key: ValueKey('commentRepliesRetry-${node.id}'),
          style: TextButton.styleFrom(minimumSize: const Size(64, 44), foregroundColor: t.ink),
          onPressed: () => controller.loadReplies(node, more: node.repliesLoaded),
          child: Text(l.commonRetry),
        ),
      ]),
    );
  }
}

/// "Yorumlar" üst satırı: sayaç + sıralama çipleri (En İyi / En Yeni / En Eski).
class CommentsHeader extends StatelessWidget {
  const CommentsHeader({super.key, required this.count, required this.sort, required this.onSort});

  final int count;
  final ForumCommentSort sort;
  final ValueChanged<ForumCommentSort> onSort;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final labels = {
      ForumCommentSort.best: l.forumDetailSortBest,
      ForumCommentSort.newest: l.forumDetailSortNewest,
      ForumCommentSort.oldest: l.forumDetailSortOldest,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          header: true,
          child: Text(l.forumDetailCommentsHeader(count.toString()), style: tx.titleMedium!.copyWith(color: t.ink)),
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 0, children: [
          for (final e in labels.entries)
            _SortChip(
              key: ValueKey('commentSort-${e.key.name}'),
              label: e.value,
              selected: sort == e.key,
              onTap: () => onSort(e.key),
            ),
        ]),
      ]),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: BuPressable(
        onTap: selected ? null : onTap,
        enabled: !selected,
        haptic: BuHaptic.selection,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: BuMotion.of(context, BuMotion.short),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? t.pr : Colors.transparent,
                borderRadius: BorderRadius.circular(BuRadius.sm),
                border: Border.all(color: selected ? t.pr : t.bd),
              ),
              child: Text(label, style: tx.bodySmall!.copyWith(color: selected ? t.onPr : t.mut)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yorum listesi gövdesi durumları: yükleniyor iskeleti, hata, boş.
class CommentsStateBox extends StatelessWidget {
  const CommentsStateBox({super.key, required this.controller, required this.slow});

  final CommentsController controller;

  /// Yükleme uzadı: "bağlantı yavaş" ipucu gösterilir.
  final bool slow;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final c = controller;
    if (c.loading && c.roots.isEmpty) {
      return Column(key: const ValueKey('commentsLoading'), children: [
        BuSkeletonScope(
          child: Semantics(
            label: l.commonLoading,
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: [
                for (var i = 0; i < 3; i++)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      BuSkeleton.circle(32),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          BuSkeleton.line(width: 120),
                          SizedBox(height: 8),
                          BuSkeleton.line(),
                          SizedBox(height: 6),
                          BuSkeleton.line(width: 200),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
        if (slow)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(l.forumDetailSlow,
                key: const ValueKey('commentsSlow'), textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut)),
          ),
      ]);
    }
    if (c.error != null && c.roots.isEmpty) {
      final net = c.error is ApiError && (c.error! as ApiError).isNetwork;
      return SizedBox(
        height: 300,
        child: BuErrorState(
          key: const ValueKey('commentsError'),
          error: c.error,
          title: net ? null : l.forumDetailCommentsError,
          onRetry: () => c.load(),
          compact: true,
        ),
      );
    }
    if (c.roots.isEmpty) {
      return SizedBox(
        height: 260,
        child: BuEmptyState(
          key: const ValueKey('commentsEmpty'),
          icon: BuIcons.messageCircle,
          title: l.forumDetailNoComments,
          message: l.forumDetailNoCommentsBody,
          compact: true,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Liste sonu: sayfa yüklenirken iskelet, hata olunca "yeniden dene".
class CommentsFooter extends StatelessWidget {
  const CommentsFooter({super.key, required this.controller});

  final CommentsController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final c = controller;
    if (c.moreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          Text(errorText(c.moreError!), textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut)),
          TextButton(
            key: const ValueKey('commentsMoreRetry'),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44), foregroundColor: t.ink),
            onPressed: c.loadMore,
            child: Text(l.commonRetry),
          ),
        ]),
      );
    }
    if (c.loadingMore) {
      return Padding(
        key: const ValueKey('commentsMoreLoading'),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: t.pr)),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
