import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../widgets/bu.dart';
import '../../../posts/post_models.dart' show postAuthHeaders;
import '../../forum_routes.dart';
import '../widgets/forum_page_bar.dart';
import '../widgets/forum_paged_list.dart';
import '../widgets/forum_result_tiles.dart';

/// Kaydedilen konu ve yorumlar (`GET /api/forum/me/saved`): kaldırma iyimser (hata olursa geri gelir), boş durum,
/// sayfalama ve çekerek yenileme. [ForumActivityPage] "Kaydedilenler" sekmesi aynı listeyi kullanır.
class ForumSavedPage extends StatelessWidget {
  const ForumSavedPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ForumPageBar(semanticTitle: context.l10n.forumSavedTitle),
        Expanded(child: ForumSavedList(session: session)),
      ]),
    );
  }
}

/// Kaydedilenler listesi (başlıksız; ev sahibi sayfa/sekme çerçeveyi verir).
class ForumSavedList extends StatefulWidget {
  const ForumSavedList({super.key, required this.session});

  final Session session;

  @override
  State<ForumSavedList> createState() => _ForumSavedListState();
}

class _ForumSavedListState extends State<ForumSavedList> {
  late final ForumApi _api = ForumApi(widget.session);
  late final Map<String, String> _headers = postAuthHeaders(widget.session);

  static bool _is(ForumSavedItem it, ForumSavedItem other) =>
      it.type == other.type && (it.type == 'COMMENT' ? it.comment?.id == other.comment?.id : it.topic?.id == other.topic?.id);

  Future<void> _remove(ForumListHandle<ForumSavedItem> list, ForumSavedItem item) async {
    final restore = list.removeWhere((e) => _is(e, item));
    try {
      if (item.type == 'COMMENT') {
        await _api.bookmarkComment(item.comment!.id, false);
      } else {
        await _api.bookmarkTopic(item.topic!.id, false);
      }
      if (mounted) BuToast.show(context, context.l10n.forumSavedRemoved, kind: BuToastKind.info);
    } catch (e) {
      restore();
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _open(ForumListHandle<ForumSavedItem> list, ForumSavedItem item) async {
    if (item.type == 'COMMENT') {
      final c = item.comment!;
      await openTopicDetail(context, widget.session, c.topicId, commentId: c.id, initial: item.topic);
      return;
    }
    final topic = item.topic!;
    final updated = await openTopicDetail(context, widget.session, topic.id, initial: topic);
    if (updated == null || !mounted) return;
    // Detayda kaydı kaldırdıysa satır da kalkar.
    if (!updated.savedByMe) {
      list.removeWhere((e) => _is(e, item));
    } else {
      list.replaceWhere((e) => _is(e, item), ForumSavedItem(type: 'TOPIC', topic: updated));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ForumPagedList<ForumSavedItem>(
      fetch: (cursor) => _api.saved(cursor: cursor),
      empty: (ctx) => BuEmptyState(
        key: const ValueKey('forum-saved-empty'),
        icon: BuIcons.bookmark,
        title: l.forumSavedEmptyTitle,
        message: l.forumSavedEmptyBody,
        compact: true,
      ),
      itemBuilder: (ctx, item, list) {
        final remove = _RemoveSavedButton(
          key: ValueKey('forum-saved-remove-${item.type}-${item.type == 'COMMENT' ? item.comment?.id : item.topic?.id}'),
          onTap: () => _remove(list, item),
        );
        if (item.type == 'COMMENT' && item.comment != null) {
          return ForumCommentTile(
            comment: item.comment!,
            topicTitle: item.topic?.title,
            headers: _headers,
            trailing: remove,
            onTap: () => _open(list, item),
          );
        }
        final topic = item.topic;
        if (topic == null) return const SizedBox.shrink();
        return ForumTopicTile(topic: topic, headers: _headers, trailing: remove, onTap: () => _open(list, item));
      },
    );
  }
}

class _RemoveSavedButton extends StatelessWidget {
  const _RemoveSavedButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final label = context.l10n.forumSavedRemove;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: BuPressable(
          onTap: onTap,
          haptic: BuHaptic.light,
          child: SizedBox(width: BuSize.touch, height: 44, child: Center(child: Icon(BuIcons.bookmarkFilled, size: 20, color: t.pr))),
        ),
      ),
    );
  }
}
