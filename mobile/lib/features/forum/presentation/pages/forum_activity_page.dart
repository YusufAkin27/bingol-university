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
import 'forum_saved_page.dart';

/// Forum faaliyetim: Açtığım Konular | Yorumlarım | Kaydedilenler | Takip Ettiklerim. Anonim içeriklerim yalnız
/// bende "Anonim" rozetiyle görünür. Sekmeler ilk açılışta yüklenir ve açık kaldıkça durumunu korur.
class ForumActivityPage extends StatefulWidget {
  const ForumActivityPage({super.key, required this.session, this.initialTab = 0});

  final Session session;

  /// 0 konularım, 1 yorumlarım, 2 kaydedilenler, 3 takip ettiklerim.
  final int initialTab;

  @override
  State<ForumActivityPage> createState() => _ForumActivityPageState();
}

class _ForumActivityPageState extends State<ForumActivityPage> {
  late int _tab = widget.initialTab.clamp(0, 3);
  late final Set<int> _visited = {_tab};
  late final ForumApi _api = ForumApi(widget.session);
  late final Map<String, String> _headers = postAuthHeaders(widget.session);

  Widget _topics(
    String key,
    ForumFetch<TopicSummary> fetch,
    String emptyTitle,
    String emptyBody,
    IconData icon,
  ) {
    return ForumPagedList<TopicSummary>(
      key: PageStorageKey<String>(key),
      fetch: fetch,
      empty: (ctx) => BuEmptyState(key: ValueKey('$key-empty'), icon: icon, title: emptyTitle, message: emptyBody, compact: true),
      itemBuilder: (ctx, topic, list) => _card(topic, list),
    );
  }

  Widget _card(TopicSummary topic, ForumListHandle<TopicSummary> list) => ForumListTopicCard(
        session: widget.session,
        api: _api,
        topic: topic,
        onChanged: (t) => list.replaceWhere((e) => e.id == topic.id, t),
        onRemoveTopic: () => list.removeWhere((e) => e.id == topic.id),
        onRemoveAuthor: (uid) => list.removeAllWhere((e) => e.author.userId == uid),
      );

  Widget _body(int i) {
    final l = context.l10n;
    switch (i) {
      case 0:
        return _topics('forum-activity-topics', (c) => _api.myTopics(cursor: c), l.forumActivityEmptyTopicsTitle, l.forumActivityEmptyTopicsBody, BuIcons.messageSquareText);
      case 1:
        return ForumPagedList<ForumComment>(
          key: const PageStorageKey<String>('forum-activity-comments'),
          fetch: (c) => _api.myComments(cursor: c),
          empty: (ctx) => BuEmptyState(
            key: const ValueKey('forum-activity-comments-empty'),
            icon: BuIcons.messageCircle,
            title: l.forumActivityEmptyCommentsTitle,
            message: l.forumActivityEmptyCommentsBody,
            compact: true,
          ),
          itemBuilder: (ctx, c, list) => ForumCommentTile(
            comment: c,
            headers: _headers,
            onTap: () => openTopicDetail(context, widget.session, c.topicId, commentId: c.id),
          ),
        );
      case 2:
        return ForumSavedList(key: const PageStorageKey<String>('forum-activity-saved'), session: widget.session);
      default:
        return _topics('forum-activity-following', (c) => _api.following(cursor: c), l.forumActivityEmptyFollowingTitle, l.forumActivityEmptyFollowingBody, BuIcons.bell);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final labels = [l.forumActivityTabTopics, l.forumActivityTabComments, l.forumActivityTabSaved, l.forumActivityTabFollowing];
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ForumPageBar(semanticTitle: l.forumActivityTitle),
        BuChipRow(
          key: const ValueKey('forum-activity-tabs'),
          labels: labels,
          selected: _tab,
          onSelected: (i) => setState(() {
            _tab = i;
            _visited.add(i);
          }),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [for (var i = 0; i < 4; i++) _visited.contains(i) ? _body(i) : const SizedBox.shrink()],
          ),
        ),
      ]),
    );
  }
}

/// Başkasının herkese açık forum faaliyeti: yalnız anonim OLMAYAN, görünür konu ve yorumları (sunucu süzer).
/// [initialTab] 0 konular, 1 yorumlar.
class ForumUserActivityPage extends StatefulWidget {
  const ForumUserActivityPage({super.key, required this.session, required this.userId, this.name, this.initialTab = 0});

  final Session session;
  final int userId;
  final String? name;
  final int initialTab;

  @override
  State<ForumUserActivityPage> createState() => _ForumUserActivityPageState();
}

class _ForumUserActivityPageState extends State<ForumUserActivityPage> {
  late int _tab = widget.initialTab.clamp(0, 1);
  late final Set<int> _visited = {_tab};
  late final ForumApi _api = ForumApi(widget.session);
  late final Map<String, String> _headers = postAuthHeaders(widget.session);

  Widget _body(int i) {
    final l = context.l10n;
    if (i == 0) {
      return ForumPagedList<TopicSummary>(
        key: const PageStorageKey<String>('forum-user-topics'),
        fetch: (c) => _api.userTopics(widget.userId, cursor: c),
        empty: (ctx) => BuEmptyState(
            key: const ValueKey('forum-user-topics-empty'), icon: BuIcons.messageSquareText, title: l.forumActivityUserEmptyTopics, compact: true),
        itemBuilder: (ctx, topic, list) => ForumListTopicCard(
          session: widget.session,
          api: _api,
          topic: topic,
          onChanged: (t) => list.replaceWhere((e) => e.id == topic.id, t),
          onRemoveTopic: () => list.removeWhere((e) => e.id == topic.id),
          onRemoveAuthor: (uid) => list.removeAllWhere((e) => e.author.userId == uid),
        ),
      );
    }
    return ForumPagedList<ForumComment>(
      key: const PageStorageKey<String>('forum-user-comments'),
      fetch: (c) => _api.userComments(widget.userId, cursor: c),
      empty: (ctx) => BuEmptyState(
          key: const ValueKey('forum-user-comments-empty'), icon: BuIcons.messageCircle, title: l.forumActivityUserEmptyComments, compact: true),
      itemBuilder: (ctx, c, list) => ForumCommentTile(
        comment: c,
        headers: _headers,
        onTap: () => openTopicDetail(context, widget.session, c.topicId, commentId: c.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ForumPageBar(semanticTitle: l.forumActivityUserTitle(widget.name ?? '')),
        BuChipRow(
          key: const ValueKey('forum-user-activity-tabs'),
          labels: [l.forumActivityTabTopicsPublic, l.forumActivityTabCommentsPublic],
          selected: _tab,
          onSelected: (i) => setState(() {
            _tab = i;
            _visited.add(i);
          }),
        ),
        Expanded(
          child: IndexedStack(index: _tab, children: [for (var i = 0; i < 2; i++) _visited.contains(i) ? _body(i) : const SizedBox.shrink()]),
        ),
      ]),
    );
  }
}
