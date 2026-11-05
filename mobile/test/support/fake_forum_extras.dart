import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fake_app.dart';
import 'fake_forum.dart';

/// MB-D sahte uçları (FakeForum tabanının ÜSTÜNE): arama, popüler, kaydedilenler, faaliyetim, başkasının profili,
/// bildirim tercihleri, sessize alınanlar, şikâyet (409 yinelenen), yazar engelleme, tek yorum.
/// Kayıt/liste durumu FakeForum ile paylaşılır: `f.saved` kümesi konu kaydını, `savedComments` yorum kaydını belirler.

/// Örnek yorum (`CommentView`).
Map<String, dynamic> sampleForumCommentD({
  required int id,
  required int topicId,
  String? body,
  bool anonymous = false,
  bool mine = false,
  int likeCount = 0,
  int replyCount = 0,
  bool deleted = false,
}) =>
    {
      'id': id,
      'topicId': topicId,
      'parentCommentId': null,
      'depth': 0,
      'author': deleted
          ? null
          : anonymous
              ? sampleForumAnonAuthor(3)
              : {'userId': mine ? 1 : 12, 'displayName': mine ? 'Ayşe Yılmaz' : 'Mehmet Kaya', 'avatarUrl': null, 'anonymous': false},
      'body': deleted ? null : (body ?? 'Yorum $id metni'),
      'anonymous': anonymous,
      'createdAt': DateTime.now().toUtc().subtract(Duration(hours: id % 30)).toIso8601String(),
      'editedAt': null,
      'likeCount': likeCount,
      'likedByMe': false,
      'savedByMe': false,
      'replyCount': replyCount,
      'mine': mine,
      'deleted': deleted,
      'canModerate': false,
      'topicAuthor': false,
    };

class FakeForumExtras {
  FakeForumExtras(this.f, {this.pageSize = 15}) {
    f.backend.handlers.add(handle);
  }

  final FakeForum f;
  final int pageSize;

  // ---- arama ----
  /// Her arama isteğinin sorgu dizgesi ("q=kantin&sort=RELEVANCE...") sırayla.
  final List<String> searchQueries = [];
  bool failSearch = false;
  bool failPopular = false;

  /// Verilirse arama bunu döner (süzülmez); verilmezse konu başlığında geçenler `matchedIn: TITLE` ile döner.
  List<Map<String, dynamic>>? searchOverride;
  List<Map<String, dynamic>> popular = [];

  // ---- profil / faaliyet ----
  final List<Map<String, dynamic>> myTopics = [];
  final List<Map<String, dynamic>> myComments = [];
  final List<Map<String, dynamic>> following = [];
  final Map<int, List<Map<String, dynamic>>> userTopics = {};
  final Map<int, List<Map<String, dynamic>>> userComments = {};
  final Map<int, Map<String, dynamic>> summaries = {};
  final Map<int, Map<String, dynamic>> commentsById = {};
  final Set<int> savedComments = {};
  bool failSaved = false;

  // ---- tercihler / sessize alma ----
  Map<String, dynamic> prefs = {'all': true, 'topicComments': true, 'commentReplies': true, 'likes': true, 'followedTopics': true};
  final List<Map<String, dynamic>> prefsPuts = [];
  bool failPrefsPut = false;
  bool failPrefsGet = false;
  final List<Map<String, dynamic>> mutes = [];
  bool failMutesGet = false;

  // ---- güvenlik ----
  final Set<String> reported = {};
  final List<Map<String, dynamic>> reports = [];
  bool failReport = false;
  bool failBlock = false;

  /// "topic:5" / "comment:9" sırayla.
  final List<String> blocks = [];

  Map<String, dynamic> _page(List<Map<String, dynamic>> list, Uri uri) {
    final size = int.tryParse(uri.queryParameters['size'] ?? '') ?? pageSize;
    final cursor = uri.queryParameters['cursor'];
    final page = cursor == null || cursor.isEmpty ? 1 : int.tryParse(cursor.replaceFirst('p', '')) ?? 1;
    final from = (page - 1) * size;
    final slice = from >= list.length ? <Map<String, dynamic>>[] : list.skip(from).take(size).toList();
    return {'items': slice, 'nextCursor': from + size < list.length ? 'p${page + 1}' : null};
  }

  FakeResult? handle(http.Request req, String path) {
    final m = req.method;
    final uri = req.url;
    Object? body() {
      try {
        return req.body.isEmpty ? null : jsonDecode(req.body);
      } catch (_) {
        return null;
      }
    }

    const err500 = FakeResult.json({'code': 'SERVER_ERROR', 'message': 'Sunucu hatası.'}, status: 500);

    if (path == '/forum/search' && m == 'GET') {
      searchQueries.add(uri.query);
      if (failSearch) return err500;
      final q = (uri.queryParameters['q'] ?? '').toLowerCase();
      final cat = int.tryParse(uri.queryParameters['categoryId'] ?? '');
      List<Map<String, dynamic>> hits;
      if (searchOverride != null) {
        hits = searchOverride!;
      } else {
        hits = [
          for (final t in f.topics)
            if (t['status'] != 'REMOVED' &&
                (t['title'] as String).toLowerCase().contains(q) &&
                (cat == null || (t['category'] as Map)['id'] == cat))
              {...t, 'matchedIn': 'TITLE', 'snippet': null},
        ];
      }
      return FakeResult.json(_page(hits, uri));
    }
    if (path == '/forum/search/popular' && m == 'GET') {
      if (failPopular) return err500;
      return FakeResult.json(popular);
    }

    if (path == '/forum/me/topics' && m == 'GET') return FakeResult.json(_page(myTopics, uri));
    if (path == '/forum/me/comments' && m == 'GET') return FakeResult.json(_page(myComments, uri));
    if (path == '/forum/me/following' && m == 'GET') return FakeResult.json(_page(following, uri));
    if (path == '/forum/me/saved' && m == 'GET') {
      if (failSaved) return err500;
      final items = <Map<String, dynamic>>[
        for (final id in f.saved)
          if (f.byId(id) != null) {'type': 'TOPIC', 'topic': {...f.byId(id)!, 'savedByMe': true}},
        for (final id in savedComments)
          if (commentsById[id] != null)
            {
              'type': 'COMMENT',
              'comment': commentsById[id],
              'topic': f.byId(commentsById[id]!['topicId'] as int),
            },
      ];
      return FakeResult.json(_page(items, uri));
    }

    final um = RegExp(r'^/forum/users/(\d+)/(topics|comments|summary)$').firstMatch(path);
    if (um != null && m == 'GET') {
      final uid = int.parse(um.group(1)!);
      switch (um.group(2)) {
        case 'topics':
          return FakeResult.json(_page(userTopics[uid] ?? [], uri));
        case 'comments':
          return FakeResult.json(_page(userComments[uid] ?? [], uri));
        default:
          final s = summaries[uid];
          if (s == null) return const FakeResult.json({'code': 'FORUM_NOT_FOUND', 'message': 'Yok'}, status: 404);
          return FakeResult.json(s);
      }
    }

    if (path == '/forum/notification-prefs') {
      if (m == 'GET') return failPrefsGet ? err500 : FakeResult.json(prefs);
      if (m == 'PUT') {
        if (failPrefsPut) return err500;
        final b = body();
        if (b is Map) {
          prefsPuts.add(Map<String, dynamic>.from(b));
          prefs = Map<String, dynamic>.from(b);
        }
        return FakeResult.json(prefs);
      }
    }

    if (path == '/forum/mutes' && m == 'GET') return failMutesGet ? err500 : FakeResult.json({'items': mutes, 'nextCursor': null});
    final mu = RegExp(r'^/forum/mutes/(\d+)$').firstMatch(path);
    if (mu != null) {
      final id = int.parse(mu.group(1)!);
      if (m == 'PUT') {
        if (!mutes.any((e) => e['userId'] == id)) mutes.add({'userId': id, 'displayName': 'Kullanıcı $id', 'avatarUrl': null});
        return const FakeResult.json(null, status: 204);
      }
      if (m == 'DELETE') {
        mutes.removeWhere((e) => e['userId'] == id);
        return const FakeResult.json(null, status: 204);
      }
    }

    if (path == '/reports' && m == 'POST') {
      final b = body();
      if (b is Map && '${b['targetType']}'.startsWith('FORUM_')) {
        if (failReport) return err500;
        final key = '${b['targetType']}:${b['targetId']}';
        if (reported.contains(key)) {
          return const FakeResult.json({'code': 'ALREADY_REPORTED', 'message': 'Bu içeriği zaten raporladınız.'}, status: 409);
        }
        reported.add(key);
        reports.add(Map<String, dynamic>.from(b));
        return const FakeResult.json({'id': 1}, status: 201);
      }
      return null;
    }

    final ba = RegExp(r'^/forum/(topics|comments)/(\d+)/block-author$').firstMatch(path);
    if (ba != null && m == 'POST') {
      if (failBlock) return err500;
      blocks.add('${ba.group(1) == 'topics' ? 'topic' : 'comment'}:${ba.group(2)}');
      return const FakeResult.json(null, status: 204);
    }

    final cm = RegExp(r'^/forum/comments/(\d+)$').firstMatch(path);
    if (cm != null && m == 'GET') {
      final c = commentsById[int.parse(cm.group(1)!)];
      if (c == null) return const FakeResult.json({'code': 'FORUM_COMMENT_NOT_FOUND', 'message': 'Yorum bulunamadı.'}, status: 404);
      return FakeResult.json({...c, 'path': <int>[]});
    }
    final cb = RegExp(r'^/forum/comments/(\d+)/bookmark$').firstMatch(path);
    if (cb != null && (m == 'PUT' || m == 'DELETE')) {
      final id = int.parse(cb.group(1)!);
      m == 'PUT' ? savedComments.add(id) : savedComments.remove(id);
      return FakeResult.json({'saved': m == 'PUT'});
    }
    return null;
  }
}

FakeForumExtras fakeForumExtras(FakeForum f, {int pageSize = 15}) => FakeForumExtras(f, pageSize: pageSize);
