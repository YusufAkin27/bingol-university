import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/features/forum/data/forum_api.dart';
import 'package:bu_kampus/features/forum/data/forum_models.dart';
import 'package:bu_kampus/features/forum/presentation/widgets/forum_state_views.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_forum.dart';

/// Forum veri katmanı (MB-A): modeller null-güvenli, ForumApi sözleşmeye uygun istek atar, hata metinleri kısa Türkçe.
void main() {
  group('modeller', () {
    test('bos / bozuk gövde cokmez; bilinmeyen alan yok sayilir', () {
      final t = TopicSummary.fromJson(null);
      expect(t.id, 0);
      expect(t.title, '');
      expect(t.author.anonymous, isFalse);
      expect(t.status, 'ACTIVE');
      expect(TopicView.fromJson({'id': 'x', 'poll': 5, 'images': 'bozuk', 'yeniAlan': 1}).images, isEmpty);
      expect(ForumPage.parse<TopicSummary>('bozuk', TopicSummary.fromJson).items, isEmpty);
      expect(ForumPage.parse<TopicSummary>({'items': [1, 'a', {'id': 3}], 'nextCursor': 7}, TopicSummary.fromJson).items.map((e) => e.id), [3]);
      expect(ForumComment.fromJson({'id': 1, 'replyPreview': [null, {'id': 2}]}).replyPreview.length, 1);
    });

    test('anonim yazar: kimlik/avatar yok; konu ozeti ve detayi dogru ayrisir', () {
      final j = sampleForumTopic(id: 9, anonymous: true, withImage: true, hasPoll: true, pinned: true, locked: true, mine: true);
      j['poll'] = {
        'id': 3,
        'question': 'Soru?',
        'options': [
          {'id': 1, 'text': 'A', 'voteCount': 2, 'percent': 66.7},
          {'id': 2, 'text': 'B', 'voteCount': 1, 'percent': 33.3},
        ],
        'totalVotes': 3,
        'myOptionId': 2,
        'closed': false,
        'allowChangeVote': true,
        'canVote': true,
      };
      final v = TopicView.fromJson(j);
      expect(v.author.anonymous, isTrue);
      expect(v.author.userId, isNull);
      expect(v.author.avatarUrl, isNull);
      expect(v.author.displayName, startsWith('Anonim #'));
      expect(v.thumbnail!.url, 'http://10.0.2.2:8080/api/forum/media/90');
      expect(v.images.single.id, 90);
      expect(v.pinned && v.locked && v.mine && v.hasPoll, isTrue);
      expect(v.poll!.options.map((o) => o.percent), [66.7, 33.3]);
      expect(v.poll!.myOptionId, 2);
      expect(v.poll!.voted, isTrue);
      expect(v.copyWith(likedByMe: true, likeCount: 4).likeCount, 4);
      expect(v.copyWith(likedByMe: true).body, v.body);
    });

    test('silinmis yorum yer tutucusu: yazar ve govde null', () {
      final c = ForumComment.fromJson({'id': 5, 'topicId': 2, 'deleted': true, 'author': null, 'body': null, 'replyCount': 3, 'path': [1, '2']});
      expect(c.deleted, isTrue);
      expect(c.author, isNull);
      expect(c.body, isNull);
      expect(c.path, [1, 2]);
      expect(c.copyWith(deleted: true).body, isNull);
    });

    test('baglanti bicimi sozlesmeyle ayni', () {
      expect(forumTopicLink(12), 'https://bukampus.com.tr/s/f/12');
      expect(forumCommentLink(34), 'https://bukampus.com.tr/s/fc/34');
    });
  });

  group('ForumApi', () {
    test('konu listesi sorgusu: sort, categoryId, imlec, size', () async {
      final b = FakeBackend();
      fakeForum(b, count: 40);
      final api = ForumApi(makeSession(b));
      final p1 = await api.topics(sort: ForumSort.mostCommented, categoryId: 2, size: 5);
      expect(b.requests.last, 'GET /forum/topics?sort=MOST_COMMENTED&categoryId=2&size=5');
      expect(p1.items.every((e) => e.category?.id == 2), isTrue);
      final all = await api.topics();
      expect(all.hasMore, isTrue);
      await api.topics(cursor: all.nextCursor, size: 15);
      expect(b.requests.last, contains('cursor=p2'));
    });

    test('konu olusturma: Idempotency-Key basligi gider; ayni anahtarla ikinci istek ayni konuyu doner', () async {
      final b = FakeBackend();
      final f = fakeForum(b, count: 1);
      String? header;
      b.handlers.insert(0, (req, path) {
        if (path == '/forum/topics' && req.method == 'POST') header = req.headers['Idempotency-Key'];
        return null;
      });
      final api = ForumApi(makeSession(b));
      final a = await api.createTopic(title: ' Başlık ', body: 'Gövde', categoryId: 3, anonymous: true, idempotencyKey: 'k-1');
      expect(header, 'k-1');
      final again = await api.createTopic(title: 'Başlık', body: 'Gövde', categoryId: 3, anonymous: true, idempotencyKey: 'k-1');
      expect(again.id, a.id);
      expect(f.topics.where((t) => t['title'] == 'Başlık').length, 1);
      expect(b.bodies['POST /forum/topics'], containsPair('title', 'Başlık'));
      expect(b.bodies['POST /forum/topics'], containsPair('anonymous', true));
      expect(ForumApi.newIdempotencyKey(), isNot(ForumApi.newIdempotencyKey()));
    });

    test('beğeni/kaydet/takip/bildirim uclari', () async {
      final b = FakeBackend();
      fakeForum(b, count: 2);
      final api = ForumApi(makeSession(b));
      final r = await api.likeTopic(500, true);
      expect(r.liked, isTrue);
      expect(r.likeCount, 1);
      expect((await api.likeTopic(500, false)).liked, isFalse);
      expect(await api.bookmarkTopic(500, true), isTrue);
      expect(await api.followTopic(500, true), isTrue);
      expect(await api.setTopicNotifications(500, false), isFalse);
      expect(b.requests, containsAll(['PUT /forum/topics/500/like', 'DELETE /forum/topics/500/like', 'PUT /forum/topics/500/bookmark', 'PUT /forum/topics/500/follow', 'PUT /forum/topics/500/notifications']));
    });

    test('sikayet mevcut /reports ucuna FORUM_TOPIC ile gider', () async {
      final b = FakeBackend();
      final api = ForumApi(makeSession(b));
      await api.report(kForumReportTopic, 7, 'PERSONAL_INFO', note: ' ayrıntı ');
      expect(b.bodies['POST /reports'], {'targetType': 'FORUM_TOPIC', 'targetId': 7, 'reason': 'PERSONAL_INFO', 'note': 'ayrıntı'});
    });

    test('yorum, anket, engelleme, arama, profil uclarinin yollari', () async {
      final b = FakeBackend();
      final api = ForumApi(makeSession(b));
      b.on('/forum/topics/5/comments*', {'items': <Object>[], 'nextCursor': null});
      await api.comments(5, sort: ForumCommentSort.newest, size: 10);
      await api.createComment(5, body: ' Merhaba ', parentCommentId: 9, anonymous: true, idempotencyKey: 'c1');
      await api.editComment(9, 'Yeni');
      await api.deleteComment(9);
      await api.likeComment(9, true);
      await api.bookmarkComment(9, true);
      await api.votePoll(5, 2);
      await api.clearPollVote(5);
      await api.muteUser(3, true);
      await api.muteUser(3, false);
      await api.blockTopicAuthor(5);
      await api.blockCommentAuthor(9);
      await api.moderateTopic(5, 'PIN');
      await api.moderateComment(9, 'REMOVE', reason: 'spam');
      await api.saveNotificationPrefs(const ForumNotificationPrefs(likes: false));
      expect(b.requests, containsAll([
        'GET /forum/topics/5/comments?sort=NEWEST&size=10',
        'POST /forum/topics/5/comments',
        'PATCH /forum/comments/9',
        'DELETE /forum/comments/9',
        'PUT /forum/comments/9/like',
        'PUT /forum/comments/9/bookmark',
        'PUT /forum/topics/5/poll/vote',
        'DELETE /forum/topics/5/poll/vote',
        'PUT /forum/mutes/3',
        'DELETE /forum/mutes/3',
        'POST /forum/topics/5/block-author',
        'POST /forum/comments/9/block-author',
        'POST /forum/topics/5/moderate',
        'POST /forum/comments/9/moderate',
        'PUT /forum/notification-prefs',
      ]));
      expect(b.bodies['POST /forum/topics/5/comments'], {'body': 'Merhaba', 'parentCommentId': 9, 'anonymous': true});
      expect(b.bodies['PUT /forum/topics/5/poll/vote'], {'optionId': 2});
      expect(b.bodies['PUT /forum/notification-prefs'], containsPair('likes', false));
    });

    test('arama ve profil uclari', () async {
      final b = FakeBackend();
      final api = ForumApi(makeSession(b));
      b.on('/forum/search*', {'items': [{'id': 1, 'title': 'x', 'matchedIn': 'TITLE', 'snippet': 'ab'}], 'nextCursor': null});
      final r = await api.search(' yemek ', categoryId: 2, sort: 'NEWEST');
      expect(b.requests.last, 'GET /forum/search?q=yemek&categoryId=2&sort=NEWEST&size=15');
      expect(r.items.single.matchedIn, 'TITLE');
      b.on('/forum/me/saved*', {'items': [{'type': 'TOPIC', 'topic': {'id': 4}}, {'type': 'COMMENT', 'comment': {'id': 8, 'topicId': 4}}], 'nextCursor': null});
      final s = await api.saved();
      expect(s.items.map((e) => e.type), ['TOPIC', 'COMMENT']);
      expect(s.items[1].comment!.id, 8);
      b.on('/forum/me/*', {'items': <Object>[], 'nextCursor': null});
      b.on('/forum/users/*', {'items': <Object>[], 'nextCursor': null});
      await api.myTopics();
      await api.myComments();
      await api.following();
      await api.userTopics(12);
      await api.userComments(12);
      expect(b.requests, containsAll([
        'GET /forum/me/topics?size=15',
        'GET /forum/me/comments?size=15',
        'GET /forum/me/following?size=15',
        'GET /forum/users/12/topics?size=15',
        'GET /forum/users/12/comments?size=15',
      ]));
    });
  });

  group('forumErrorText', () {
    final l = lookupAppLocalizations(const Locale('tr'));
    test('bilinen kodlar kisa Turkce mesaja; ag hatasi cevrimdisi; bilinmeyen sunucu mesajina', () {
      expect(forumErrorText(ApiError(0, 'NETWORK', ''), l), l.forumStateOffline);
      expect(forumErrorText(ApiError(409, 'FORUM_TOPIC_LOCKED', 'x'), l), l.forumStateLocked);
      expect(forumErrorText(ApiError(403, 'FORUM_NOT_OWNER', ''), l), l.forumStateNotOwner);
      expect(forumErrorText(ApiError(429, 'FORUM_DUPLICATE_CONTENT', ''), l), l.forumStateDuplicate);
      expect(forumErrorText(ApiError(429, 'RATE_LIMITED', ''), l), l.forumStateRateLimited);
      expect(forumErrorText(ApiError(422, 'CONTENT_PROFANITY', ''), l), l.forumStateProfanity);
      expect(forumErrorText(ApiError(409, 'FORUM_POLL_CLOSED', ''), l), l.forumStatePollClosed);
      expect(forumErrorText(ApiError(404, 'FORUM_TOPIC_NOT_FOUND', ''), l), l.forumStateNotFound);
      expect(forumErrorText(ApiError(401, 'X', ''), l), l.forumStateSessionExpired);
      expect(forumErrorText(ApiError(503, 'DB_TIMEOUT', ''), l), l.forumStateServerError);
      expect(forumErrorText(ApiError(400, 'WEIRD', 'Sunucu mesajı'), l), 'Sunucu mesajı');
      expect(forumErrorText(StateError('x'), l), l.forumStateGeneric);
    });
  });
}
