import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fake_app.dart';

/// Kampüs Forum sahte uçları (MB-A tabanı). Diğer mobil ajanlar kendi uçlarını AYRI dosyada
/// (`fake_forum_*.dart`) ekler; ortak veri bu sınıftadır (konular, kategoriler, kullanıcı kümeleri).
///
/// Kullanım:
/// ```dart
/// final b = FakeBackend();
/// final f = fakeForum(b, count: 30);       // 8 kategori + 30 konu, sayfa 15
/// final s = makeSession(b);
/// ```
/// Kapsam: kategoriler, konu listesi (sort/categoryId/imleç), konu detayı, konu beğeni/kaydet/takip/bildirim,
/// konu oluştur (Idempotency-Key tekilleştirir), düzenle, sil. Yorum/anket/arama/şikâyet YOK (diğer dosyalar).

/// Örnek kategori (`GET /forum/categories` öğesi).
Map<String, dynamic> sampleForumCategory(int id, String name, {String? slug, int topicCount = 0}) =>
    {'id': id, 'slug': slug ?? name.toLowerCase(), 'name': name, 'sortOrder': id, 'topicCount': topicCount};

const kForumCategoryNames = [
  'Gündem',
  'Yemekhane',
  'Dersler',
  'Kampüs Yaşamı',
  'Yurtlar',
  'Etkinlikler',
  'Serbest Kürsü',
  'Öneri & Şikâyet',
];

/// Örnek anonim yazar (`Anonim #N`; kimlik/avatar yok).
Map<String, dynamic> sampleForumAnonAuthor([int n = 7]) =>
    {'userId': null, 'displayName': 'Anonim #$n', 'avatarUrl': null, 'department': null, 'anonymous': true};

/// Örnek konu özeti/detayı (sözleşme `TopicSummary` + `TopicView` alanları).
Map<String, dynamic> sampleForumTopic({
  required int id,
  String? title,
  String? body,
  int categoryId = 1,
  String categoryName = 'Gündem',
  bool anonymous = false,
  int likeCount = 0,
  int commentCount = 0,
  bool likedByMe = false,
  bool savedByMe = false,
  bool followedByMe = false,
  bool pinned = false,
  bool locked = false,
  bool mine = false,
  bool withImage = false,
  bool hasPoll = false,
  String status = 'ACTIVE',
  String? createdAt,
  int authorId = 12,
  String authorName = 'Mehmet Kaya',
}) {
  final text = body ?? 'Konu $id ayrıntısı. Kampüste konuşulan şeyler hakkında uzunca bir açıklama metni.';
  return {
    'id': id,
    'title': title ?? 'Konu başlığı $id',
    'body': text,
    'bodyPreview': text.length > 280 ? text.substring(0, 280) : text,
    'category': {'id': categoryId, 'name': categoryName, 'slug': categoryName.toLowerCase()},
    'author': anonymous
        ? sampleForumAnonAuthor(id % 9 + 1)
        : {'userId': mine ? 1 : authorId, 'displayName': mine ? 'Ayşe Yılmaz' : authorName, 'avatarUrl': null, 'department': 'Bilgisayar Mühendisliği', 'anonymous': false},
    'createdAt': createdAt ?? DateTime.now().toUtc().subtract(Duration(hours: id % 48)).toIso8601String(),
    'editedAt': null,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'likedByMe': likedByMe,
    'savedByMe': savedByMe,
    'followedByMe': followedByMe,
    'thumbnail': withImage ? {'url': '/api/forum/media/${id * 10}', 'thumbUrl': '/api/forum/media/${id * 10}?thumb', 'width': 800, 'height': 600} : null,
    'imageCount': withImage ? 1 : 0,
    'hasPoll': hasPoll,
    'pinned': pinned,
    'locked': locked,
    'mine': mine,
    'canModerate': false,
    'canEdit': mine && !locked,
    'canDelete': mine,
    'notificationsEnabled': true,
    'images': withImage ? [{'id': id * 10, 'url': '/api/forum/media/${id * 10}', 'thumbUrl': '/api/forum/media/${id * 10}?thumb', 'width': 800, 'height': 600}] : <Object>[],
    'poll': null,
    'status': status,
  };
}

class FakeForum {
  FakeForum(this.backend, {int count = 20, this.pageSize = 15, bool categories = true}) {
    if (categories) {
      for (var i = 0; i < kForumCategoryNames.length; i++) {
        this.categories.add(sampleForumCategory(i + 1, kForumCategoryNames[i], topicCount: 0));
      }
    }
    for (var i = 0; i < count; i++) {
      final id = 500 - i;
      final cat = i % kForumCategoryNames.length;
      topics.add(sampleForumTopic(
        id: id,
        categoryId: cat + 1,
        categoryName: kForumCategoryNames[cat],
        likeCount: i % 7,
        commentCount: (count - i) % 9,
        anonymous: i % 5 == 3,
        pinned: i == 0,
        withImage: i % 4 == 1,
        createdAt: DateTime.utc(2026, 11, 4, 12).subtract(Duration(hours: i)).toIso8601String(),
      ));
    }
  }

  final FakeBackend backend;
  final int pageSize;

  final List<Map<String, dynamic>> categories = [];

  /// `GET /forum/categories` sorgu dizeleri (q= dahil) ve isteğe bağlı sunucu tarafı arama simülasyonu.
  final List<String> categoryQueries = [];
  List<Map<String, dynamic>> Function(String q)? categorySearch;

  /// En yeni başta.
  final List<Map<String, dynamic>> topics = [];

  /// Kullanıcının beğendikleri / kaydettikleri / takip ettikleri (konu id).
  final Set<int> liked = {}, saved = {}, followed = {};

  /// true iken konu listesi 500 döner.
  bool failTopics = false;

  /// true iken beğeni/kaydet yazmaları 500 döner (geri alma testi).
  bool failWrites = false;

  /// Boş forum.
  bool empty = false;

  /// `Idempotency-Key` -> oluşan konu (çift gönderim aynı konuyu döner).
  final Map<String, Map<String, dynamic>> byKey = {};

  int _nextTopic = 900;

  /// Sorgu parametreleri kaydı: "sort=NEWEST&categoryId=2" biçiminde, sırayla.
  final List<String> topicQueries = [];

  Map<String, dynamic>? byId(int id) {
    for (final t in topics) {
      if (t['id'] == id) return t;
    }
    return null;
  }

  Map<String, dynamic> _withMine(Map<String, dynamic> t) => {
        ...t,
        'likedByMe': liked.contains(t['id']),
        'savedByMe': saved.contains(t['id']),
        'followedByMe': followed.contains(t['id']),
      };

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

    const err500 = FakeResult.json({'code': 'SERVER_ERROR', 'message': 'Hata'}, status: 500);
    const notFound = FakeResult.json({'code': 'FORUM_TOPIC_NOT_FOUND', 'message': 'Konu bulunamadı.'}, status: 404);

    if (path == '/forum/categories' && m == 'GET') {
      categoryQueries.add(uri.query);
      final q = uri.queryParameters['q'];
      final search = categorySearch;
      if (q != null && q.isNotEmpty && search != null) return FakeResult.json(search(q));
      return FakeResult.json(categories);
    }

    if (path == '/forum/topics' && m == 'GET') {
      if (failTopics) return err500;
      topicQueries.add(uri.query);
      final sort = uri.queryParameters['sort'] ?? 'FOR_YOU';
      final cat = int.tryParse(uri.queryParameters['categoryId'] ?? '');
      var list = [
        for (final t in topics)
          if (t['status'] != 'REMOVED' && (cat == null || (t['category'] as Map)['id'] == cat)) _withMine(t),
      ];
      if (sort == 'POPULAR') list.sort((a, b) => (b['likeCount'] as int).compareTo(a['likeCount'] as int));
      if (sort == 'MOST_COMMENTED') list.sort((a, b) => (b['commentCount'] as int).compareTo(a['commentCount'] as int));
      if (sort == 'FOLLOWING') list = [for (final t in list) if (followed.contains(t['id'])) t];
      if (empty) list = [];
      final size = int.tryParse(uri.queryParameters['size'] ?? '') ?? pageSize;
      final cursor = uri.queryParameters['cursor'];
      final page = cursor == null || cursor.isEmpty ? 1 : int.tryParse(cursor.replaceFirst('p', '')) ?? 1;
      final from = (page - 1) * size;
      final slice = from >= list.length ? <Map<String, dynamic>>[] : list.skip(from).take(size).toList();
      final more = from + size < list.length;
      return FakeResult.json({'items': slice, 'nextCursor': more ? 'p${page + 1}' : null});
    }

    if (path == '/forum/topics' && m == 'POST') {
      final key = req.headers['Idempotency-Key'];
      if (key != null && byKey.containsKey(key)) return FakeResult.json(byKey[key], status: 201);
      final b = body();
      final map = b is Map ? b : const {};
      final catId = (map['categoryId'] as num?)?.toInt() ?? 1;
      final t = sampleForumTopic(
        id: _nextTopic++,
        title: '${map['title']}',
        body: '${map['body']}',
        categoryId: catId,
        categoryName: kForumCategoryNames[(catId - 1).clamp(0, kForumCategoryNames.length - 1)],
        anonymous: map['anonymous'] == true,
        mine: true,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
      topics.insert(0, t);
      if (key != null) byKey[key] = t;
      return FakeResult.json(t, status: 201);
    }

    final one = RegExp(r'^/forum/topics/(\d+)$').firstMatch(path);
    if (one != null) {
      final t = byId(int.parse(one.group(1)!));
      if (t == null || t['status'] == 'REMOVED') return notFound;
      if (m == 'GET') return FakeResult.json(_withMine(t));
      if (m == 'PATCH') {
        final b = body();
        if (b is Map) {
          if (b['title'] != null) t['title'] = b['title'];
          if (b['body'] != null) {
            t['body'] = b['body'];
            t['bodyPreview'] = '${b['body']}';
          }
          t['editedAt'] = DateTime.now().toUtc().toIso8601String();
        }
        return FakeResult.json(_withMine(t));
      }
      if (m == 'DELETE') {
        t['status'] = 'REMOVED';
        return const FakeResult.json(null, status: 204);
      }
    }

    final act = RegExp(r'^/forum/topics/(\d+)/(like|bookmark|follow|notifications)$').firstMatch(path);
    if (act != null && (m == 'PUT' || m == 'DELETE')) {
      if (failWrites) return err500;
      final id = int.parse(act.group(1)!);
      final t = byId(id);
      if (t == null) return notFound;
      final on = m == 'PUT';
      switch (act.group(2)) {
        case 'like':
          final was = liked.contains(id);
          if (on && !was) {
            liked.add(id);
            t['likeCount'] = (t['likeCount'] as int) + 1;
          } else if (!on && was) {
            liked.remove(id);
            t['likeCount'] = (t['likeCount'] as int) - 1;
          }
          return FakeResult.json({'liked': liked.contains(id), 'likeCount': t['likeCount']});
        case 'bookmark':
          on ? saved.add(id) : saved.remove(id);
          return FakeResult.json({'saved': on});
        case 'follow':
          on ? followed.add(id) : followed.remove(id);
          return FakeResult.json({'following': on});
        default:
          final b = body();
          final en = b is Map ? b['enabled'] != false : true;
          t['notificationsEnabled'] = en;
          return FakeResult.json({'enabled': en});
      }
    }
    return null;
  }
}

/// Sahte forumu kurar ve `b.handlers` içine ekler.
FakeForum fakeForum(FakeBackend b, {int count = 20, int pageSize = 15, bool categories = true}) {
  final f = FakeForum(b, count: count, pageSize: pageSize, categories: categories);
  b.handlers.add(f.handle);
  return f;
}
