import '../../core/session.dart';
import 'post_models.dart';

/// Gönderi uçları (tek fotoğraf + kısa metin + beğeni). Tek HTTP katmanı `session.api`; GET'ler her istekte
/// sunucuya doğrulatılır (ETag/If-None-Match). Hatalar `ApiError` olarak fırlar.
/// Fotoğraf yükleme (`POST /posts/media`) `post_media_uploader.dart` içindedir.
/// Kaldırılan uçlar (yorum, kaydetme, etiket, hikâye) sunucuda 410 `FEATURE_REMOVED` döner; çağrılmaz.
Map<String, dynamic>? _m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

class PostApi {
  PostApi(this.session);

  final Session session;

  String _q(Map<String, Object?> p) {
    final parts = <String>[
      for (final e in p.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) '${e.key}=${Uri.encodeQueryComponent('${e.value}')}',
    ];
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  /// Tanınmayan medya taşıyan kayıtlar akıştan ayıklanır (`nextCursor` sunucudan olduğu gibi kalır).
  /// [force]: ağdan doğrulanır (taze önbellek süresi yok sayılır); imleçsiz ilk sayfalar için: "yenileyince yeni gönderiler".
  Future<PostPage<Post>> _posts(String path, Map<String, Object?> q, {bool force = false}) async =>
      _page(await session.api.get('$path${_q(q)}', force: force));

  PostPage<Post> _page(Object? body) {
    final page = PostPage.parse(body, Post.fromJson);
    return PostPage<Post>(
      items: [for (final p in page.items) if (!p.hiddenInFeed) p],
      nextCursor: page.nextCursor,
      total: page.total,
      exhausted: page.exhausted,
    );
  }

  /// Keşfet akışı: TEK popülerlik sıralaması (`scope=top`; eski `popular`/`latest` değerleri sunucuda aynı akışa
  /// yönlenir). İmleçsiz çağrı (yenileme) sunucuda "görülmüşleri hariç tut" demektir; sayfa içindeki gönderiler
  /// sunucuca görülmüş sayılır. Tüm havuz görüldüyse `exhausted: true` ile baştan tekrar başlar.
  Future<PostPage<Post>> feed({String scope = 'top', String? cursor, int size = 10}) =>
      _posts('/feed', {'scope': scope, 'cursor': cursor, 'size': size}, force: cursor == null);

  /// Reels: yalnız video gönderiler, aynı puan ve görülmüş-hariç mantığı (`GET /feed/reels`).
  Future<PostPage<Post>> reels({String? cursor, int size = 6}) =>
      _posts('/feed/reels', {'cursor': cursor, 'size': size}, force: cursor == null);

  /// Ağa gitmeden, önbellekteki (bayat olabilir) ilk akış sayfası; yoksa null. YALNIZ ağ yokken yedek olarak kullanılır:
  /// yenilemede eski sayfayı göstermek "aynı gönderiler yine geldi" demektir.
  Future<PostPage<Post>?> peekFeed({String scope = 'top', int size = 10}) async {
    final r = await session.api.peekCache('/feed${_q({'scope': scope, 'size': size})}');
    return r == null ? null : _page(r.body);
  }

  /// Seen isteği başına en çok kimlik sayısı (sunucu sınırı).
  static const kFeedSeenBatch = 100;

  /// Ekranda görülen gönderi/reel kimliklerini toplu bildirir (`POST /feed/seen {ids}`, en çok 100/istek). Sessiz:
  /// hata akışı bozmaz (sunucu zaten döndürdüğü sayfayı görülmüş sayar; bu yalnız yedektir).
  Future<void> markSeen(Iterable<int> ids) async {
    final all = ids.where((e) => e > 0).toSet().toList();
    for (var i = 0; i < all.length; i += kFeedSeenBatch) {
      final end = i + kFeedSeenBatch > all.length ? all.length : i + kFeedSeenBatch;
      try {
        await session.api.post('/feed/seen', {'ids': all.sublist(i, end)});
      } catch (_) {}
    }
  }

  /// Video izlenme olayı (`POST /posts/{id}/view`): izlenen süre ve video süresi (ms). Sessiz.
  Future<void> view(int id, {required int watchedMs, required int durationMs}) async {
    if (watchedMs <= 0) return;
    try {
      await session.api.post('/posts/$id/view', {'watchedMs': watchedMs, 'durationMs': durationMs});
    } catch (_) {}
  }

  Future<Post> get(int id) async => Post.fromJson(_m(await session.api.get('/posts/$id')));

  /// Tek fotoğraf ([mediaId], önce `POST /posts/media` ile yüklenir) + isteğe bağlı kısa metin.
  Future<Post> create({String? text, required int mediaId}) async {
    final r = await session.api.post('/posts', {
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      'mediaIds': [mediaId],
    });
    return Post.fromJson(_m(r));
  }

  Future<Post> update(int id, String text) async =>
      Post.fromJson(_m(await session.api.patch('/posts/$id', {'text': text})));

  Future<void> delete(int id) => session.api.delete('/posts/$id');

  Future<LikeResult> like(int id) async =>
      LikeResult.fromJson(_m(await session.api.put('/posts/$id/like')));

  Future<LikeResult> unlike(int id) async =>
      LikeResult.fromJson(_m(await session.api.delete('/posts/$id/like')));

  Future<PostPage<Post>> userPosts(int userId, {String? cursor, int size = 10}) =>
      _posts('/users/$userId/posts', {'cursor': cursor, 'size': size});

  Future<PostPage<Post>> minePosts({String? cursor, int size = 10}) =>
      _posts('/posts/mine', {'cursor': cursor, 'size': size});

  /// `targetType`: `FEED_POST`; `reason`: SPAM, HARASSMENT, INAPPROPRIATE, IMPERSONATION, OTHER.
  Future<void> report(String targetType, int targetId, String reason, {String? note}) =>
      session.api.post('/reports', {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
}
