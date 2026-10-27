import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fake_app.dart';

/// Gönderi sosyal uçları için durumlu sahte arka uç: anma önerisi, #etiket, takip, hikâyeler.
/// `fakePosts` ÖNCE kurulursa `/feed` onun; takip akışını boşaltmak için bu işleyici önce eklenir ([fakeSocial] her zaman başa ekler).
class FakeSocial {
  FakeSocial(this.backend) {
    users.addAll([
      for (final e in const [
        (21, 'Ali Veli', 'Bilgisayar Mühendisliği'),
        (22, 'Aylin Kaya', 'Hemşirelik'),
        (23, 'Mehmet Demir', 'Bilgisayar Mühendisliği'),
      ])
        {'id': e.$1, 'displayName': e.$2, 'department': e.$3, 'avatarUrl': null, 'followedByMe': false}
    ]);
  }

  final FakeBackend backend;
  final List<Map<String, dynamic>> users = [];
  final Set<int> following = {};

  /// `/feed?scope=following` boş mu döner.
  bool followingFeedEmpty = true;
  List<Map<String, dynamic>> trending = [
    {'tag': 'bahar', 'postCount': 12},
    {'tag': 'kampus', 'postCount': 5},
  ];
  List<Map<String, dynamic>> tagPosts = [];

  /// Hikâye şeridi (sunucu sırası) ve kullanıcı hikâyeleri.
  List<Map<String, dynamic>> tray = [];
  final Map<int, List<Map<String, dynamic>>> stories = {};
  final List<int> viewed = [];
  final List<int> deletedStories = [];
  bool failTray = false;
  int _nextStory = 7000;

  Map<String, dynamic> story(int id,
          {String kind = 'IMAGE', String? bodyText, String? bg, String? caption, bool seen = false, int views = 0, int? durationMs}) =>
      {
        'id': id,
        'kind': kind,
        'media': kind == 'TEXT' ? null : samplePostMedia(id: id * 10, video: kind == 'VIDEO'),
        'bodyText': bodyText,
        'background': bg,
        'caption': caption,
        'viewCount': views,
        'seen': seen,
        'createdAt': DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String(),
        'expiresAt': DateTime.now().toUtc().add(const Duration(hours: 22)).toIso8601String(),
      };

  Map<String, dynamic> group(int userId, String name, {bool unseen = true, bool mine = false}) => {
        'author': {'id': userId, 'displayName': name, 'avatarUrl': null},
        'hasUnseen': unseen,
        'mine': mine,
        'count': stories[userId]?.length ?? 0,
      };

  FakeResult? handle(http.Request req, String path) {
    final m = req.method;
    final q = req.url.queryParameters;
    Object? body() {
      try {
        return req.body.isEmpty ? null : jsonDecode(req.body);
      } catch (_) {
        return null;
      }
    }

    FakeResult page(List<Map<String, dynamic>> items) => FakeResult.json({'items': items, 'nextCursor': null});

    if (path == '/feed' && m == 'GET' && followingFeedEmpty && q['scope'] == 'following') {
      return page(const []);
    }
    if (path == '/users/mention-suggest' && m == 'GET') {
      final s = (q['q'] ?? '').toLowerCase();
      return page([for (final u in users) if (s.isEmpty || (u['displayName'] as String).toLowerCase().contains(s)) u]);
    }
    if (path == '/hashtags/trending' && m == 'GET') return page(trending);
    if (path == '/hashtags/suggest' && m == 'GET') {
      final s = (q['q'] ?? '').toLowerCase();
      return page([for (final t in trending) if ((t['tag'] as String).startsWith(s)) t]);
    }
    if (RegExp(r'^/hashtags/[^/]+/posts$').hasMatch(path) && m == 'GET') return page(tagPosts);

    if (path == '/users/me/follow-suggestions' && m == 'GET') {
      return page([for (final u in users) if (!following.contains(u['id'])) u]);
    }
    final fs = RegExp(r'^/users/(\d+)/follow-stats$').firstMatch(path);
    if (fs != null && m == 'GET') {
      final id = int.parse(fs.group(1)!);
      return FakeResult.json({
        'followerCount': 3 + (following.contains(id) ? 1 : 0),
        'followingCount': 5,
        'followedByMe': following.contains(id),
        'followsMe': false,
      });
    }
    final fo = RegExp(r'^/users/(\d+)/follow$').firstMatch(path);
    if (fo != null && (m == 'PUT' || m == 'DELETE')) {
      final id = int.parse(fo.group(1)!);
      m == 'PUT' ? following.add(id) : following.remove(id);
      return const FakeResult.json(null, status: 204);
    }
    if (RegExp(r'^/users/\d+/(followers|following)$').hasMatch(path) && m == 'GET') {
      return page([for (final u in users) {...u, 'followedByMe': following.contains(u['id'])}]);
    }

    if (path == '/stories/tray' && m == 'GET') {
      if (failTray) return const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'Hata'}, status: 500);
      return page(tray);
    }
    final us = RegExp(r'^/users/(\d+)/stories$').firstMatch(path);
    if (us != null && m == 'GET') return page(stories[int.parse(us.group(1)!)] ?? const []);
    final sv = RegExp(r'^/stories/(\d+)/view$').firstMatch(path);
    if (sv != null && m == 'POST') {
      viewed.add(int.parse(sv.group(1)!));
      return const FakeResult.json(null, status: 204);
    }
    final vw = RegExp(r'^/stories/(\d+)/viewers$').firstMatch(path);
    if (vw != null && m == 'GET') {
      return page([
        {'id': 21, 'displayName': 'Ali Veli', 'avatarUrl': null, 'viewedAt': DateTime.now().toUtc().toIso8601String()},
      ]);
    }
    final sd = RegExp(r'^/stories/(\d+)$').firstMatch(path);
    if (sd != null && m == 'DELETE') {
      final id = int.parse(sd.group(1)!);
      deletedStories.add(id);
      for (final l in stories.values) {
        l.removeWhere((s) => s['id'] == id);
      }
      return const FakeResult.json(null, status: 204);
    }
    if (path == '/stories' && m == 'POST') {
      final b = body() as Map? ?? const {};
      final id = _nextStory++;
      final s = story(id, kind: '${b['kind']}', bodyText: b['bodyText'] as String?, bg: b['background'] as String?, caption: b['caption'] as String?);
      stories.putIfAbsent(1, () => []).add(s);
      return FakeResult.json(s, status: 201);
    }
    return null;
  }
}

/// Sosyal uçları kurar; işleyici EN BAŞA eklenir (`fakePosts` ile birlikte `/feed?scope=following` ezilebilsin).
FakeSocial fakeSocial(FakeBackend b) {
  final f = FakeSocial(b);
  b.handlers.insert(0, f.handle);
  return f;
}
