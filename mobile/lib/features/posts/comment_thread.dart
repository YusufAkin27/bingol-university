import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart' show ErrorView;
import 'comment_controller.dart';
import 'comment_models.dart';
import 'comment_tile.dart';

/// Bir yorum + altındaki yanıtlar (özyinelemeli). Girinti ve soluk dikey çizgi ile iç içe görünüm;
/// derinlik 3'ten sonra girinti artmaz (sunucu kardeş olarak ekler).
class CommentThread extends StatelessWidget {
  const CommentThread({
    super.key,
    required this.node,
    required this.controller,
    required this.session,
    required this.onReply,
    this.highlightId,
    this.focusId,
    this.focusKey,
  });

  final CNode node;
  final CommentsController controller;
  final Session session;
  final void Function(CNode) onReply;
  final int? highlightId;
  final int? focusId;
  final GlobalKey? focusKey;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final c = node.c;
    final showChildren = !node.collapsed && node.children.isNotEmpty;
    final toggles = _toggles(context, t);
    final nested = c.depth < 3;

    final tile = CommentTile(
      key: focusId != null && focusId == c.id ? focusKey : ValueKey('tile-${c.id}'),
      node: node,
      controller: controller,
      session: session,
      onReply: onReply,
      highlighted: highlightId == c.id,
    );

    final kids = <Widget>[
      if (showChildren)
        for (final ch in node.children)
          CommentThread(
            key: ValueKey('thread-${ch.c.id}'),
            node: ch,
            controller: controller,
            session: session,
            onReply: onReply,
            highlightId: highlightId,
            focusId: focusId,
            focusKey: focusKey,
          ),
      ...toggles,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        if (kids.isNotEmpty)
          nested
              ? Padding(
                  padding: EdgeInsetsDirectional.only(start: commentAvatarSize(c.depth) / 2 + 4),
                  child: Container(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    decoration: BoxDecoration(
                      border: BorderDirectional(start: BorderSide(color: t.bd.withValues(alpha: .7), width: 1.5)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
                  ),
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
      ],
    );
  }

  List<Widget> _toggles(BuildContext context, BuTokens t) {
    final c = node.c;
    final out = <Widget>[];
    Widget link(String label, VoidCallback onTap, {IconData? icon}) => Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 18, height: 1.5, color: t.bd),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.label.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
                  ),
                  if (icon != null) ...[const SizedBox(width: 4), Icon(icon, size: 14, color: t.mut)],
                ],
              ),
            ),
          ),
        );

    if (node.loading) {
      out.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ));
      return out;
    }
    if (node.error != null) {
      out.add(link('Yanıtlar yüklenemedi · Yeniden dene', () => controller.expand(node)));
      return out;
    }
    final total = c.replyCount;
    if (node.collapsed) {
      if (total > 0) {
        out.add(link('$total yanıtı göster', () => controller.expand(node), icon: LucideIcons.chevronDown));
      }
      return out;
    }
    if (node.hasMore && total > 0) {
      out.add(node.children.isEmpty
          ? link('$total yanıtı göster', () => controller.expand(node), icon: LucideIcons.chevronDown)
          : link('Daha fazla yanıt göster', () => controller.expand(node), icon: LucideIcons.chevronDown));
    }
    if (node.children.any((n) => !n.c.isTemp) || node.children.length > 1) {
      out.add(link('Yanıtları gizle', () => controller.collapse(node), icon: LucideIcons.chevronUp));
    }
    return out;
  }
}

/// Liste altındaki sayfalama durumu (yükleniyor / hata + yeniden dene).
class CommentsFooter extends StatelessWidget {
  const CommentsFooter({super.key, required this.controller});

  final CommentsController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    if (controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (controller.moreError != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: TextButton(
            onPressed: controller.retryMore,
            child: Text('Yorumlar yüklenemedi · Yeniden dene', style: BuType.label.copyWith(color: t.pr)),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}

/// Yorumlar yüklenirken iskelet satırlar.
class CommentsSkeleton extends StatelessWidget {
  const CommentsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget bar(double w, double h) =>
        Container(width: w, height: h, decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(6)));
    return Semantics(
      label: 'Yorumlar yükleniyor',
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [bar(110, 11), const SizedBox(height: 8), bar(double.infinity, 11), const SizedBox(height: 6), bar(160, 11)],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Hata görünümü yeniden kullanımı için ince sarmalayıcı.
class CommentsError extends StatelessWidget {
  const CommentsError({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 220, child: ErrorView(error: error, onRetry: onRetry));
}
