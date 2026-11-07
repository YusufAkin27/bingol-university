import 'dart:math' as math;

import '../../core/analytics.dart';
import '../../core/session.dart';
import 'post_models.dart';

/// Gönderi uçları (1..10 fotoğraf ya da 1 video + kısa metin + beğeni). Tek HTTP katmanı `session.api`; GET'ler her istekte
/// sunucuya doğrulatılır (ETag/If-None-Match). Hatalar `ApiError` olarak fırlar.
/// Fotoğraf yükleme (`POST /posts/media`) `post_media_uploader.dart` içindedir.
/// Yorum uçları `comments/comments_api.dart` içindedir (2026-11-07 kullanıcı kararıyla yorum geri geldi).
/// Kaldırılan uçlar (kaydetme, etiket, hikâye) sunucuda 410 `FEATURE_REMOVED` döner; çağrılmaz.
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

  /// Keşfet akışı. `scope`: `foryou` (Senin İçin, kişiselleştirilmiş), `popular` (genel popülerlik puanı; eski `top` aynı),
  /// `latest` (En Yeni), `following` (Takip Ettiklerim). `foryou`/`popular` için imleçsiz çağrı (yenileme) sunucuda
  /// "görülmüşleri hariç tut" demektir; döndürülen sayfa sunucuca görülmüş sayılır. Tüm havuz görüldüyse `exhausted: true`
  /// ile en eski görülenlerden tekrar başlar. İmleçler kapsama özeldir.
  Future<PostPage<Post>> feed({String scope = 'foryou', String? cursor, int size = 10}) =>
      _posts('/feed', {'scope': scope, 'cursor': cursor, 'size': size}, force: cursor == null);

  /// Reels: yalnız video gönderiler, öneri algoritması sunucuda (`GET /feed/reels`). İmleçsiz çağrı yeni oturum başlatır
  /// (pull-to-refresh). Aday kalmayınca `items: []`, `nextCursor: null`, `exhausted: true`; [replay] geçmişi bu oturum
  /// için yok sayan "Tekrar izle" oturumunu başlatır.
  Future<PostPage<Post>> reels({String? cursor, int size = 8, bool replay = false}) =>
      _posts('/feed/reels', {'cursor': cursor, 'size': size, if (replay && cursor == null) 'replay': 'true'},
          force: cursor == null);

  /// "İlgilenmiyorum": gönderi bu kullanıcının Reels ve Senin İçin önerilerinden kalkar. [undo] geri alır.
  Future<void> notInterested(int id, {bool undo = false}) =>
      undo ? session.api.delete('/posts/$id/not-interested') : session.api.post('/posts/$id/not-interested', {});

  /// Kaydet / kaydı kaldır (`PUT|DELETE /posts/{id}/save`); yalnız sunucu kaydetmeyi sunuyorsa çağrılır.
  Future<bool> setSaved(int id, bool saved) async {
    final r = saved ? await session.api.put('/posts/$id/save') : await session.api.delete('/posts/$id/save');
    return r is Map && r['saved'] is bool ? r['saved'] as bool : saved;
  }

  /// Ağa gitmeden, önbellekteki (bayat olabilir) ilk akış sayfası; yoksa null. YALNIZ ağ yokken yedek olarak kullanılır:
  /// yenilemede eski sayfayı göstermek "aynı gönderiler yine geldi" demektir.
  Future<PostPage<Post>?> peekFeed({String scope = 'foryou', int size = 10}) async {
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
      } catch (_) {
        // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
      }
    }
  }

  /// Video izlenme olayı (`POST /posts/{id}/view`): izlenen süre ve video süresi (ms). Sessiz.
  Future<void> view(int id, {required int watchedMs, required int durationMs}) async {
    if (watchedMs <= 0) return;
    try {
      await session.api.post('/posts/$id/view', {'watchedMs': watchedMs, 'durationMs': durationMs});
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }

  Future<Post> get(int id) async => Post.fromJson(_m(await session.api.get('/posts/$id')));

  /// Tek medya ([mediaId], önce `POST /posts/media` ile yüklenir) + isteğe bağlı metin (istenen uzunlukta; sunucunun
  /// gizli üst sınırı aşılırsa 422 `POST_TEXT_TOO_LONG`) + etiketlenen kişiler ([mentionUserIds]: yalnız takip ettiklerim,
  /// en çok 10; metindeki `@Ad Soyad` düz metni ayrıca gönderilir).
  /// Bir "paylaşma niyeti" için BİR kez üretilip yeniden denemelerde aynen kullanılır: zaman aşımından sonra
  /// sunucu gönderiyi oluşturmuşsa aynı anahtar aynı gönderiyi döndürür (çift gönderi / yanlış hata olmaz).
  static String newIdempotencyKey() {
    final r = math.Random.secure();
    return 'p${List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join()}';
  }

  /// [mediaIds] verilirse (1..10 fotoğraf, sıralı) [mediaId] yok sayılır; tek `mediaId` eski çağıranlar içindir.
  Future<Post> create(
      {String? text,
      int? mediaId,
      List<int>? mediaIds,
      List<int> mentionUserIds = const [],
      String? idempotencyKey}) async {
    final ids = mediaIds ?? [if (mediaId != null) mediaId];
    assert(ids.isNotEmpty, 'en az bir medya gerekir');
    final r = await session.api.post(
        '/posts',
        {
          if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
          'mediaIds': ids,
          if (mentionUserIds.isNotEmpty) 'mentionUserIds': mentionUserIds,
        },
        true,
        {'Idempotency-Key': idempotencyKey ?? newIdempotencyKey()});
    Analytics.instance.action('post_create');
    return Post.fromJson(_m(r));
  }

  Future<Post> update(int id, String text, {List<int>? mentionUserIds}) async => Post.fromJson(_m(await session.api
      .patch('/posts/$id', {'text': text, if (mentionUserIds != null) 'mentionUserIds': mentionUserIds})));

  Future<void> delete(int id) => session.api.delete('/posts/$id');

  Future<LikeResult> like(int id) async =>
      LikeResult.fromJson(_m(await session.api.put('/posts/$id/like')));

  Future<LikeResult> unlike(int id) async =>
      LikeResult.fromJson(_m(await session.api.delete('/posts/$id/like')));

  Future<PostPage<Post>> userPosts(int userId, {String? cursor, int size = 10}) =>
      _posts('/users/$userId/posts', {'cursor': cursor, 'size': size});

  Future<PostPage<Post>> minePosts({String? cursor, int size = 10}) =>
      _posts('/posts/mine', {'cursor': cursor, 'size': size});

  /// Ayarlar > Beğendiklerim: benim beğendiğim gönderiler/Reels (beğeni anına göre). [kind]: ALL | PHOTO | VIDEO.
  Future<PostPage<Post>> likedPosts({String kind = 'ALL', String? cursor, int size = 12}) =>
      _posts('/posts/liked', {'kind': kind, 'cursor': cursor, 'size': size}, force: cursor == null);

  /// `targetType`: `FEED_POST`; `reason`: SPAM, HARASSMENT, INAPPROPRIATE, IMPERSONATION, OTHER.
  Future<void> report(String targetType, int targetId, String reason, {String? note}) =>
      session.api.post('/reports', {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
}
