import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../widgets/bu.dart';
import '../../../posts/post_models.dart' show postAuthHeaders;
import '../../forum_routes.dart';
import '../widgets/forum_list_topic_card.dart';
import '../widgets/forum_page_bar.dart';
import '../widgets/forum_paged_list.dart';
import '../widgets/forum_result_tiles.dart';

/// Kaydedilen konu ve yorumlar (`GET /api/forum/me/saved`): konu kartında kaydı kaldırınca satır anında kalkar (hata
/// olursa geri gelir), yorum satırında "kaydı kaldır" düğmesi vardır; boş durum, sayfalama, çekerek yenileme.
/// [ForumActivityPage] "Kaydedilenler" sekmesi aynı listeyi kullanır.
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

  /// Kart içinden kaydı kaldırılan konular için geri alma işlevleri (konu kimliği -> satırı geri koy).
  final Map<int, VoidCallback> _restore = {};

  static bool _isTopic(ForumSavedItem it, int id) => it.type != 'COMMENT' && it.topic?.id == id;
  static bool _isComment(ForumSavedItem it, int id) => it.type == 'COMMENT' && it.comment?.id == id;

  /// Kart eylemi sonucu: kayıt kapandıysa satır kalkar; kaydetme hata verip kart durumu geri alırsa satır geri gelir.
  void _topicChanged(ForumListHandle<ForumSavedItem> list, TopicSummary t) {
    if (!t.savedByMe) {
      if (_restore.containsKey(t.id)) return;
      // Satır sessizce kalkar (kartın kendi kaydetme isteği sürüyor); hata olursa geri gelir ve uyarı çıkar.
      _restore[t.id] = list.removeWhere((e) => _isTopic(e, t.id));
      return;
    }
    final undo = _restore.remove(t.id);
    if (undo != null) {
      undo();
      if (mounted) BuToast.show(context, context.l10n.forumHomeSaveFailed, kind: BuToastKind.error);
    } else {
      list.replaceWhere((e) => _isTopic(e, t.id), ForumSavedItem(type: 'TOPIC', topic: t));
    }
  }

  Future<void> _removeComment(ForumListHandle<ForumSavedItem> list, ForumComment c) async {
    final restore = list.removeWhere((e) => _isComment(e, c.id));
    try {
      await _api.bookmarkComment(c.id, false);
      if (mounted) BuToast.show(context, context.l10n.forumSavedRemoved, kind: BuToastKind.info);
    } catch (e) {
      restore();
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
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
        final comment = item.comment;
        if (item.type == 'COMMENT' && comment != null) {
          return ForumCommentTile(
            comment: comment,
            topicTitle: item.topic?.title,
            headers: _headers,
            trailing: _RemoveSavedButton(key: ValueKey('forum-saved-remove-COMMENT-${comment.id}'), onTap: () => _removeComment(list, comment)),
            onTap: () => openTopicDetail(context, widget.session, comment.topicId, commentId: comment.id, initial: item.topic),
          );
        }
        // Kaydedilenler listesindeki konu tanım gereği kayıtlıdır (sunucu bayrağı eksik gelse de kart doğru çizilsin).
        final raw = item.topic;
        if (raw == null) return const SizedBox.shrink();
        final topic = raw.savedByMe ? raw : raw.copyWith(savedByMe: true);
        return ForumListTopicCard(
          session: widget.session,
          api: _api,
          topic: topic,
          onChanged: (t) => _topicChanged(list, t),
          onRemoveTopic: () => list.removeWhere((e) => _isTopic(e, topic.id)),
          onRemoveAuthor: (uid) => list.removeAllWhere((e) => e.topic?.author.userId == uid),
        );
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
