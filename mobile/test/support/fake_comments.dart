import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fake_app.dart';

/// Yorum sözleşmesini (CommentView, sıralama, imleç, yanıtlar, beğeni, silme, rapor) taklit eden durumlu sahte işleyici.
/// `CommentsFake(backend)` kendini `backend.handlers`a ekler.

Map<String, dynamic> commentView(
  int id, {
  int postId = 9,
  int? parentId,
  String body = 'Yorum',
  int likes = 0,
  bool liked = false,
  int replies = 0,
  bool mine = false,
  bool deleted = false,
  String name = 'Deniz Aksoy',
  String? username = 'deniz',
}) =>
    {
      'id': id,
      'postId': postId,
      'parentId': parentId,
      'author': deleted ? null : {'userId': mine ? 1 : 5, 'displayName': name, 'avatarUrl': null, 'username': username},
      'body': deleted ? null : body,
      'createdAt': DateTime.now().subtract(const Duration(minutes: 5)).toUtc().toIso8601String(),
      'likeCount': likes,
      'likedByMe': liked,
      'replyCount': replies,
      'mine': mine,
      'canDelete': mine,
      'deleted': deleted,
    };

class CommentsFake {
  CommentsFake(this.b) {
    b.handlers.add(_handle);
  }

  final FakeBackend b;
  final List<Map<String, dynamic>> roots = [];
  final Map<int, List<Map<String, dynamic>>> replies = {};
  int next = 900;
  int pageSize = 20;

  /// POST /posts/{id}/comments için sıradaki hata (bir kez).
  FakeResult? failAdd;
  bool failList = false;
  bool failLike = false;
  final likes = <String>[];
  final deletes = <int>[];
  final keys = <String>[];
  final bodies = <Map>[];
  final reports = <Map>[];

  FakeResult? _handle(http.Request req, String path) {
    final m = req.method;
    final uri = req.url;
    final list = RegExp(r'^/posts/(\d+)/comments$').firstMatch(path);
    if (list != null) {
      if (m == 'GET') {
        if (failList) return const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500);
        final cursor = int.tryParse(uri.queryParameters['cursor'] ?? '') ?? 0;
        var all = [...roots];
        if (uri.queryParameters['sort'] == 'new') all = all.reversed.toList();
        final slice = all.skip(cursor).take(pageSize).toList();
        final more = cursor + pageSize < all.length;
        return FakeResult.json({'items': slice, 'nextCursor': more ? '${cursor + pageSize}' : null});
      }
      if (m == 'POST') {
        final fail = failAdd;
        if (fail != null) {
          failAdd = null;
          return fail;
        }
        final body = jsonDecode(req.body) as Map;
        bodies.add(body);
        keys.add(req.headers['Idempotency-Key'] ?? '');
        final pid = (body['parentId'] as num?)?.toInt();
        final c = commentView(next++, parentId: pid, body: body['body'] as String, mine: true, name: 'Ayşe Yılmaz', username: 'ayse');
        if (pid == null) {
          roots.insert(0, c);
        } else {
          (replies[pid] ??= []).add(c);
          for (final r in roots) {
            if (r['id'] == pid) r['replyCount'] = (r['replyCount'] as int) + 1;
          }
        }
        return FakeResult.json(c, status: 201);
      }
    }
    final rep = RegExp(r'^/comments/(\d+)/replies$').firstMatch(path);
    if (rep != null && m == 'GET') {
      return FakeResult.json({'items': replies[int.parse(rep.group(1)!)] ?? [], 'nextCursor': null});
    }
    final like = RegExp(r'^/comments/(\d+)/like$').firstMatch(path);
    if (like != null) {
      if (failLike) return const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500);
      likes.add('$m ${like.group(1)}');
      return const FakeResult.json(null, status: 204);
    }
    final del = RegExp(r'^/comments/(\d+)$').firstMatch(path);
    if (del != null && m == 'DELETE') {
      deletes.add(int.parse(del.group(1)!));
      return const FakeResult.json(null, status: 204);
    }
    if (path == '/reports' && m == 'POST') {
      reports.add(jsonDecode(req.body) as Map);
      return const FakeResult.json({}, status: 201);
    }
    return null;
  }
}

