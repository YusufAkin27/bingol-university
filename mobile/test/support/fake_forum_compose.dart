import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fake_app.dart';
import 'fake_forum.dart';

/// MB-C sahte uçları (konu oluşturma / düzenleme / anket). `FakeForum` tabanının ÜSTÜNE eklenir:
/// işleyici `FakeForum`dan önce sorulur (hata modları + anket + istek kaydı).
///
/// ```dart
/// final b = FakeBackend();
/// final f = fakeForum(b);
/// final c = fakeForumCompose(b, f);
/// c.createError = const FakeResult.json({'code': 'CONTENT_PROFANITY', 'message': 'x'}, status: 422);
/// ```
class FakeForumCompose {
  FakeForumCompose(this.forum);

  final FakeForum forum;

  /// Dolu iken `POST /forum/topics` bu hatayı döner (null yapılınca normal akış).
  FakeResult? createError;

  /// Dolu iken `PATCH /forum/topics/{id}` bu hatayı döner.
  FakeResult? editError;

  /// `POST /forum/topics` istek sayısı ve her isteğin `Idempotency-Key` başlığı.
  int createCalls = 0;
  final List<String?> createKeys = [];

  /// `PATCH` gövdeleri (sırayla).
  final List<Map<String, dynamic>> patches = [];

  /// Anketler: konu kimliği -> anket (sözleşme `Poll`).
  final Map<int, Map<String, dynamic>> polls = {};

  /// Oy uçları dolu iken bu hatayı döner.
  FakeResult? voteError;

  /// `PUT/DELETE .../poll/vote` çağrı sayısı.
  int voteCalls = 0;

  /// Kullanıcının oyu: konu -> seçenek kimliği.
  final Map<int, int> myVotes = {};

  /// Örnek anket kurar ve `GET /forum/topics/{id}` yanıtına bağlar.
  Map<String, dynamic> addPoll(
    int topicId, {
    List<(int id, String text, int votes)> options = const [(1, 'Evet', 6), (2, 'Hayır', 4)],
    bool allowChangeVote = false,
    bool closed = false,
    String? endsAt,
    String? question,
    int? myOptionId,
  }) {
    final p = {
      'id': topicId * 10,
      'question': question,
      'options': [
        for (final o in options) {'id': o.$1, 'text': o.$2, 'voteCount': o.$3, 'percent': 0.0}
      ],
      'endsAt': endsAt,
      'closed': closed,
      'allowChangeVote': allowChangeVote,
    };
    polls[topicId] = p;
    if (myOptionId != null) myVotes[topicId] = myOptionId;
    return pollJson(topicId);
  }

  /// Sunucunun anket görünümü (yüzdeler sunucuda hesaplanır).
  Map<String, dynamic> pollJson(int topicId) {
    final p = polls[topicId]!;
    final opts = (p['options'] as List).cast<Map<String, dynamic>>();
    final total = opts.fold<int>(0, (a, o) => a + (o['voteCount'] as int));
    final mine = myVotes[topicId];
    final closed = p['closed'] == true;
    return {
      ...p,
      'options': [
        for (final o in opts)
          {...o, 'percent': total == 0 ? 0.0 : ((o['voteCount'] as int) * 1000 / total).round() / 10}
      ],
      'totalVotes': total,
      'myOptionId': mine,
      'canVote': !closed && (mine == null || p['allowChangeVote'] == true),
    };
  }

  FakeResult? handle(http.Request req, String path) {
    final m = req.method;
    Object? body() {
      try {
        return req.body.isEmpty ? null : jsonDecode(req.body);
      } catch (_) {
        return null;
      }
    }

    if (path == '/forum/topics' && m == 'POST') {
      createCalls++;
      createKeys.add(req.headers['Idempotency-Key']);
      if (createError != null) return createError;
      final r = forum.handle(req, path);
      // Oluşan konuya (gövdede anket varsa) anketi bağla.
      final b = body();
      if (r != null && b is Map && b['poll'] is Map) {
        final id = (r.json as Map)['id'] as int;
        final pl = b['poll'] as Map;
        addPoll(id, options: [
          for (var i = 0; i < (pl['options'] as List).length; i++) (i + 1, '${(pl['options'] as List)[i]}', 0)
        ], allowChangeVote: pl['allowChangeVote'] == true, endsAt: pl['endsAt'] as String?);
        (forum.byId(id)!)['poll'] = pollJson(id);
        (forum.byId(id)!)['hasPoll'] = true;
      }
      return r;
    }

    final one = RegExp(r'^/forum/topics/(\d+)$').firstMatch(path);
    if (one != null) {
      final id = int.parse(one.group(1)!);
      if (m == 'PATCH') {
        final b = body();
        if (b is Map) patches.add(Map<String, dynamic>.from(b));
        if (editError != null) return editError;
        final t = forum.byId(id);
        if (t != null && b is Map && b['categoryId'] != null) {
          final cid = (b['categoryId'] as num).toInt();
          t['category'] = {
            'id': cid,
            'name': kForumCategoryNames[(cid - 1).clamp(0, kForumCategoryNames.length - 1)],
            'slug': 'x'
          };
        }
        return null; // FakeForum uygular
      }
      if (m == 'GET' && polls.containsKey(id)) {
        final t = forum.byId(id);
        if (t != null) t['poll'] = pollJson(id);
      }
    }

    final v = RegExp(r'^/forum/topics/(\d+)/poll/vote$').firstMatch(path);
    if (v != null && (m == 'PUT' || m == 'DELETE')) {
      voteCalls++;
      if (voteError != null) return voteError;
      final id = int.parse(v.group(1)!);
      final p = polls[id];
      if (p == null) {
        return const FakeResult.json({'code': 'FORUM_TOPIC_NOT_FOUND', 'message': 'yok'}, status: 404);
      }
      if (p['closed'] == true) {
        return const FakeResult.json({'code': 'FORUM_POLL_CLOSED', 'message': 'kapali'}, status: 409);
      }
      final opts = (p['options'] as List).cast<Map<String, dynamic>>();
      final prev = myVotes[id];
      if (m == 'DELETE') {
        if (prev == null || p['allowChangeVote'] != true) {
          return const FakeResult.json({'code': 'FORUM_POLL_ALREADY_VOTED', 'message': 'x'}, status: 409);
        }
        opts.firstWhere((o) => o['id'] == prev)['voteCount'] = (opts.firstWhere((o) => o['id'] == prev)['voteCount'] as int) - 1;
        myVotes.remove(id);
        return FakeResult.json(pollJson(id));
      }
      final b = body();
      final oid = b is Map ? (b['optionId'] as num).toInt() : -1;
      if (prev != null && p['allowChangeVote'] != true) {
        return const FakeResult.json({'code': 'FORUM_POLL_ALREADY_VOTED', 'message': 'x'}, status: 409);
      }
      if (prev != oid) {
        if (prev != null) {
          final po = opts.firstWhere((o) => o['id'] == prev);
          po['voteCount'] = (po['voteCount'] as int) - 1;
        }
        final no = opts.firstWhere((o) => o['id'] == oid);
        no['voteCount'] = (no['voteCount'] as int) + 1;
        myVotes[id] = oid;
      }
      return FakeResult.json(pollJson(id));
    }
    return null;
  }
}

/// Sahte forum + MB-C uçlarını kurar (MB-C işleyicisi önce sorulur).
FakeForumCompose fakeForumCompose(FakeBackend b, FakeForum f) {
  final c = FakeForumCompose(f);
  b.handlers.insert(0, c.handle);
  return c;
}
