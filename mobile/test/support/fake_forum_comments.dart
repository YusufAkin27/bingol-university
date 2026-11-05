import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fake_app.dart';
import 'fake_forum.dart';

/// Forum YORUM uçlarının durumlu sahte uygulaması (MB-B). `FakeForum` (konular) ile birlikte kurulur:
/// ```dart
/// final b = FakeBackend();
/// final f = fakeForum(b, count: 3);
/// final c = fakeForumComments(b, f);   // konu 500'e tohum yorumlar
/// ```
/// Oturum kullanıcısı id 1'dir (`makeSession`). Sayfalama imleci `pN`. Silinen yanıtlı yorum yer tutucu olur.
Map<String, dynamic> sampleCommentAuthor(int id, String name) =>
    {'userId': id, 'displayName': name, 'avatarUrl': null, 'department': 'Bilgisayar Mühendisliği', 'anonymous': false};

class FakeForumComments {
  FakeForumComments(this.b, this.f) {
    b.handlers.add(handle);
  }

  final FakeBackend b;
  final FakeForum f;

  /// Tüm yorumlar (düz). Alanlar: id, topicId, parent, userId, name, anon, anonN, body, createdAt, editedAt,
  /// likeCount, replyDeleted, deleted.
  final List<Map<String, dynamic>> all = [];

  final Set<int> liked = {}, saved = {};
  final Map<String, Map<String, dynamic>> byKey = {};

  /// İstek kaydı: yorum listesi sorguları ("sort=BEST&size=15"), yanıt sorguları, like çağrıları.
  final List<String> commentQueries = [];
  final List<String> replyQueries = [];
  final List<String> likeCalls = [];

  int _id = 1000;
  int _clock = 0;

  /// true iken yorum yazma 500 döner.
  bool failPost = false;

  /// true iken beğeni 500 döner.
  bool failLike = false;

  /// true iken yorum listesi 500 döner.
  bool failList = false;

  /// true iken yanıt listesi 500 döner.
  bool failReplies = false;

  /// true iken yorum yazma kilitli konu gibi 409 FORUM_TOPIC_LOCKED döner.
  bool lockedOnPost = false;

  /// true iken düzenleme/silme 404 döner (eşzamanlı silme).
  bool goneOnWrite = false;

  /// true iken düzenleme/silme 409 döner (çakışma).
  bool conflictOnWrite = false;

  /// Her yazma yanıtından önce gecikme (çift dokunma testi için).
  Duration postDelay = Duration.zero;
  int postCount = 0;

  /// Yorum yazma isteklerinin `Idempotency-Key` değerleri (sırayla).
  final List<String?> postKeys = [];

  /// Engellenen (block-author) yorum/konu kimlikleri.
  final List<int> blockedComments = [], blockedTopics = [];

  /// Moderasyon çağrıları: "PIN", "LOCK"...
  final List<String> moderations = [];

  Map<String, dynamic> add(
    int topicId,
    String body, {
    int? parent,
    int userId = 12,
    String name = 'Mehmet Kaya',
    bool anon = false,
    int anonN = 7,
    int likeCount = 0,
    bool mine = false,
    int? id,
  }) {
    final c = {
      'id': id ?? ++_id,
      'topicId': topicId,
      'parent': parent,
      'userId': mine ? 1 : userId,
      'name': mine ? 'Ayşe Yılmaz' : name,
      'anon': anon,
      'anonN': anonN,
      'body': body,
      'createdAt': DateTime.utc(2026, 11, 4, 12).add(Duration(minutes: _clock++)).toIso8601String(),
      'editedAt': null,
      'likeCount': likeCount,
      'deleted': false,
    };
    all.add(c);
    return c;
  }

  Map<String, dynamic>? byId(int id) {
    for (final c in all) {
      if (c['id'] == id) return c;
    }
    return null;
  }

  List<Map<String, dynamic>> childrenOf(int? parent, int topicId) =>
      [for (final c in all) if (c['parent'] == parent && c['topicId'] == topicId) c];

  int _depth(Map<String, dynamic> c) {
    var d = 0;
    var p = c['parent'] as int?;
    while (p != null) {
      d++;
      p = byId(p)?['parent'] as int?;
    }
    return d;
  }

  List<int> _path(Map<String, dynamic> c) {
    final out = <int>[];
    var p = c['parent'] as int?;
    while (p != null) {
      out.insert(0, p);
      p = byId(p)?['parent'] as int?;
    }
    return out;
  }

  Map<String, dynamic> view(Map<String, dynamic> c, {bool preview = false}) {
    final kids = childrenOf(c['id'] as int, c['topicId'] as int);
    final deleted = c['deleted'] == true;
    final mine = c['userId'] == 1;
    final anon = c['anon'] == true;
    return {
      'id': c['id'],
      'topicId': c['topicId'],
      'parentCommentId': c['parent'],
      'depth': _depth(c),
      'author': deleted || c['accountGone'] == true
          ? null
          : anon
              ? {'userId': null, 'displayName': 'Anonim #${c['anonN']}', 'avatarUrl': null, 'department': null, 'anonymous': true}
              : sampleCommentAuthor(c['userId'] as int, c['name'] as String),
      'body': deleted ? null : c['body'],
      'anonymous': anon,
      'createdAt': c['createdAt'],
      'editedAt': c['editedAt'],
      'likeCount': c['likeCount'],
      'likedByMe': liked.contains(c['id']),
      'savedByMe': saved.contains(c['id']),
      'replyCount': kids.length,
      if (preview) 'replyPreview': [for (final k in kids.take(2)) view(k)],
      'mine': mine,
      'deleted': deleted,
      'canModerate': false,
      'topicAuthor': c['topicAuthor'] == true,
    };
  }

  FakeResult _j(Object? j, [int status = 200]) => FakeResult.json(j, status: status);

  FakeResult _err(int status, String code, String msg) => FakeResult.json({'code': code, 'message': msg}, status: status);

  FakeResult _page(List<Map<String, dynamic>> list, Uri uri, {bool preview = false}) {
    final size = int.tryParse(uri.queryParameters['size'] ?? '') ?? 15;
    final cursor = uri.queryParameters['cursor'];
    final page = cursor == null || cursor.isEmpty ? 1 : int.tryParse(cursor.replaceFirst('p', '')) ?? 1;
    final from = (page - 1) * size;
    final slice = from >= list.length ? <Map<String, dynamic>>[] : list.skip(from).take(size).toList();
    return _j({'items': [for (final c in slice) view(c, preview: preview)], 'nextCursor': from + size < list.length ? 'p${page + 1}' : null});
  }

  void _syncTopicCount(int topicId) {
    final t = f.byId(topicId);
    if (t == null) return;
    t['commentCount'] = all.where((c) => c['topicId'] == topicId && c['deleted'] != true).length;
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

    // ---- Üst düzey yorumlar -----------------------------------------------------------------------------
    var mt = RegExp(r'^/forum/topics/(\d+)/comments$').firstMatch(path);
    if (mt != null) {
      final tid = int.parse(mt.group(1)!);
      if (m == 'GET') {
        commentQueries.add(uri.query);
        if (failList) return _err(500, 'SERVER_ERROR', 'Hata');
        final sort = uri.queryParameters['sort'] ?? 'BEST';
        // Görünür üst düzey: silinmiş ve yanıtsız olanlar listede yok.
        final tops = [
          for (final c in childrenOf(null, tid))
            if (c['deleted'] != true || childrenOf(c['id'] as int, tid).isNotEmpty) c,
        ];
        int score(Map<String, dynamic> c) => (c['likeCount'] as int) * 2 + childrenOf(c['id'] as int, tid).length;
        switch (sort) {
          case 'NEWEST':
            tops.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
          case 'OLDEST':
            tops.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
          default:
            tops.sort((a, b) {
              final s = score(b).compareTo(score(a));
              return s != 0 ? s : (b['id'] as int).compareTo(a['id'] as int);
            });
        }
        return _page(tops, uri, preview: true);
      }
      if (m == 'POST') {
        postCount++;
        postKeys.add(req.headers['Idempotency-Key']);
        if (lockedOnPost) return _err(409, 'FORUM_TOPIC_LOCKED', 'Bu konu kilitli.');
        if (failPost) return _err(500, 'SERVER_ERROR', 'Sunucu hatası');
        final key = req.headers['Idempotency-Key'];
        if (key != null && byKey.containsKey(key)) return _j(view(byKey[key]!), 201);
        final bd = body();
        final map = bd is Map ? bd : const {};
        final parent = (map['parentCommentId'] as num?)?.toInt();
        if (parent != null && byId(parent) == null) return _err(404, 'FORUM_COMMENT_NOT_FOUND', 'Yorum bulunamadı.');
        final anon = map['anonymous'] == true;
        final c = add(tid, '${map['body']}', parent: parent, mine: true, anon: anon, anonN: 99);
        c['userId'] = 1;
        if (key != null) byKey[key] = c;
        _syncTopicCount(tid);
        return _j(view(c), 201);
      }
    }

    // ---- Yanıtlar ---------------------------------------------------------------------------------------
    mt = RegExp(r'^/forum/comments/(\d+)/replies$').firstMatch(path);
    if (mt != null && m == 'GET') {
      replyQueries.add(uri.query);
      if (failReplies) return _err(500, 'SERVER_ERROR', 'Hata');
      final p = byId(int.parse(mt.group(1)!));
      if (p == null) return _err(404, 'FORUM_COMMENT_NOT_FOUND', 'Yorum bulunamadı.');
      final kids = [
        for (final c in childrenOf(p['id'] as int, p['topicId'] as int))
          if (c['deleted'] != true || childrenOf(c['id'] as int, p['topicId'] as int).isNotEmpty) c,
      ];
      return _page(kids, uri);
    }

    // ---- Tek yorum --------------------------------------------------------------------------------------
    mt = RegExp(r'^/forum/comments/(\d+)$').firstMatch(path);
    if (mt != null) {
      final c = byId(int.parse(mt.group(1)!));
      if (m == 'GET') {
        if (c == null) return _err(404, 'FORUM_COMMENT_NOT_FOUND', 'Yorum bulunamadı.');
        return _j({...view(c, preview: true), 'path': _path(c)});
      }
      if (m == 'PATCH') {
        if (goneOnWrite || c == null || c['deleted'] == true) return _err(404, 'FORUM_COMMENT_NOT_FOUND', 'Yorum bulunamadı.');
        if (conflictOnWrite) return _err(409, 'FORUM_COMMENT_CONFLICT', 'Çakışma.');
        if (c['userId'] != 1) return _err(403, 'FORUM_NOT_OWNER', 'Bu yorum size ait değil.');
        final bd = body();
        c['body'] = bd is Map ? '${bd['body']}' : c['body'];
        c['editedAt'] = DateTime.now().toUtc().toIso8601String();
        return _j(view(c));
      }
      if (m == 'DELETE') {
        if (goneOnWrite || c == null || c['deleted'] == true) return _err(404, 'FORUM_COMMENT_NOT_FOUND', 'Yorum bulunamadı.');
        if (conflictOnWrite) return _err(409, 'FORUM_COMMENT_CONFLICT', 'Çakışma.');
        if (c['userId'] != 1) return _err(403, 'FORUM_NOT_OWNER', 'Bu yorum size ait değil.');
        final tid = c['topicId'] as int;
        if (childrenOf(c['id'] as int, tid).isNotEmpty) {
          c['deleted'] = true;
        } else {
          all.remove(c);
          // Yanıtı kalmayan silinmiş ata yer tutucuları da kalkar.
          var p = c['parent'] as int?;
          while (p != null) {
            final pc = byId(p);
            if (pc == null || pc['deleted'] != true || childrenOf(p, tid).isNotEmpty) break;
            all.remove(pc);
            p = pc['parent'] as int?;
          }
        }
        _syncTopicCount(tid);
        return const FakeResult.json(null, status: 204);
      }
    }

    // ---- Beğeni / kaydet --------------------------------------------------------------------------------
    mt = RegExp(r'^/forum/comments/(\d+)/(like|bookmark)$').firstMatch(path);
    if (mt != null && (m == 'PUT' || m == 'DELETE')) {
      final id = int.parse(mt.group(1)!);
      final c = byId(id);
      if (c == null) return _err(404, 'FORUM_COMMENT_NOT_FOUND', 'Yorum bulunamadı.');
      final on = m == 'PUT';
      if (mt.group(2) == 'like') {
        likeCalls.add('$m $id');
        if (failLike) return _err(500, 'SERVER_ERROR', 'Hata');
        final was = liked.contains(id);
        if (on && !was) {
          liked.add(id);
          c['likeCount'] = (c['likeCount'] as int) + 1;
        } else if (!on && was) {
          liked.remove(id);
          c['likeCount'] = (c['likeCount'] as int) - 1;
        }
        return _j({'liked': liked.contains(id), 'likeCount': c['likeCount']});
      }
      on ? saved.add(id) : saved.remove(id);
      return _j({'saved': on});
    }

    // ---- Engelle / moderasyon ---------------------------------------------------------------------------
    mt = RegExp(r'^/forum/comments/(\d+)/block-author$').firstMatch(path);
    if (mt != null && m == 'POST') {
      blockedComments.add(int.parse(mt.group(1)!));
      return const FakeResult.json(null, status: 204);
    }
    mt = RegExp(r'^/forum/topics/(\d+)/block-author$').firstMatch(path);
    if (mt != null && m == 'POST') {
      blockedTopics.add(int.parse(mt.group(1)!));
      return const FakeResult.json(null, status: 204);
    }
    mt = RegExp(r'^/forum/topics/(\d+)/moderate$').firstMatch(path);
    if (mt != null && m == 'POST') {
      final t = f.byId(int.parse(mt.group(1)!));
      final bd = body();
      final action = bd is Map ? '${bd['action']}' : '';
      moderations.add(action);
      if (t != null) {
        switch (action) {
          case 'PIN':
            t['pinned'] = true;
          case 'UNPIN':
            t['pinned'] = false;
          case 'LOCK':
            t['locked'] = true;
          case 'UNLOCK':
            t['locked'] = false;
        }
      }
      return const FakeResult.json(null, status: 204);
    }
    return null;
  }
}

/// Yorum uçlarını kurar. [seed] true ise konu 500'e tohum yorumlar eklenir (bkz. [seedStandard]).
FakeForumComments fakeForumComments(FakeBackend b, FakeForum f, {bool seed = true}) {
  final c = FakeForumComments(b, f);
  if (seed) seedStandard(c);
  return c;
}

/// Standart tohum (konu 500): c1 (Mehmet, 3 beğeni) -> r1 (Zeynep) -> r2 (ben) -> r3 (derin, seviye 3);
/// c1 -> r4; c6 (benim yorumum); c7 (anonim); c8 (silinmiş yer tutucu) -> c9.
void seedStandard(FakeForumComments c) {
  c.add(500, 'Birinci yorum metni', id: 1, likeCount: 3);
  c.add(500, 'Zeynep yanıtı', id: 2, parent: 1, userId: 13, name: 'Zeynep Demir');
  c.add(500, 'Benim yanıtım', id: 3, parent: 2, mine: true);
  c.add(500, 'Derin yanıt metni', id: 4, parent: 3, userId: 14, name: 'Can Aksoy');
  c.add(500, 'İkinci yanıt', id: 5, parent: 1, userId: 15, name: 'Elif Çelik');
  c.add(500, 'Benim yorumum', id: 6, mine: true);
  c.add(500, 'Anonim görüş', id: 7, anon: true, anonN: 3);
  final del = c.add(500, 'silinecek', id: 8, userId: 16, name: 'Silinmiş Kişi');
  del['deleted'] = true;
  c.add(500, 'Silinmişin yanıtı', id: 9, parent: 8, userId: 17, name: 'Burak Şen');
}
