import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/analytics.dart';
import '../../../core/api.dart';
import '../../../core/platform/image_service.dart';
import '../../../core/session.dart';
import 'forum_models.dart';

/// Kampüs Forum uçları (`/api/forum/**`, sözleşme: FORUM_API.md). Tek HTTP katmanı `session.api` (ETag/304,
/// tek uçuşlu refresh); hatalar [ApiError] olarak fırlar. Yeni HTTP istemcisi yoktur.
/// Yetkisiz işlemi sunucu reddeder; istemci yalnız `mine/canEdit/canDelete/canModerate` ile gösterimi belirler.
Map<String, dynamic>? _m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

class ForumApi {
  ForumApi(this.session);

  final Session session;

  ApiClient get _api => session.api;

  static String _q(Map<String, Object?> p) {
    final parts = <String>[
      for (final e in p.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) '${e.key}=${Uri.encodeQueryComponent('${e.value}')}',
    ];
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  /// Çift gönderimi engelleyen anahtar: aynı anahtarla tekrar gönderilen istek aynı kaydı döner. Bir "gönderme niyeti"
  /// için BİR kez üretilip yeniden denemelerde aynen kullanılmalıdır.
  static String newIdempotencyKey() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = (Object().hashCode ^ t.hashCode).toRadixString(36);
    return 'f$t-$r';
  }

  // ---- Kategoriler ----------------------------------------------------------------------------------------

  Future<List<ForumCategory>> categories({bool force = false}) async {
    final r = await _api.get('/forum/categories', force: force);
    final list = r is List ? r : (r is Map && r['items'] is List ? r['items'] as List : const []);
    return [for (final e in list) if (e is Map) ForumCategory.fromJson(Map<String, dynamic>.from(e))];
  }

  // ---- Konular --------------------------------------------------------------------------------------------

  /// Konu listesi. İmleçsiz çağrı (ilk sayfa/yenileme) ağdan doğrulanır.
  Future<ForumPage<TopicSummary>> topics({
    ForumSort sort = ForumSort.forYou,
    int? categoryId,
    String? cursor,
    int size = 15,
    bool force = false,
  }) async =>
      ForumPage.parse(
          await _api.get(
              '/forum/topics${_q({'sort': sort.wire, 'categoryId': categoryId, 'cursor': cursor, 'size': size})}',
              force: force || cursor == null),
          TopicSummary.fromJson);

  /// Ağ yokken yedek olarak: önbellekteki (bayat olabilir) ilk sayfa; yoksa null.
  Future<ForumPage<TopicSummary>?> peekTopics({ForumSort sort = ForumSort.forYou, int? categoryId, int size = 15}) async {
    final r = await _api.peekCache('/forum/topics${_q({'sort': sort.wire, 'categoryId': categoryId, 'size': size})}');
    return r == null ? null : ForumPage.parse(r.body, TopicSummary.fromJson);
  }

  Future<TopicView> topic(int id, {bool force = false}) async =>
      TopicView.fromJson(_m(await _api.get('/forum/topics/$id', force: force)));

  /// Yeni konu. [idempotencyKey]: çift basışta çift konu olmasın (yeniden denemede AYNI anahtarı verin).
  Future<TopicView> createTopic({
    required String title,
    required String body,
    required int categoryId,
    bool anonymous = false,
    List<int> imageIds = const [],
    Map<String, dynamic>? poll,
    String? idempotencyKey,
  }) async {
    final r = await _api.post(
      '/forum/topics',
      {
        'title': title.trim(),
        'body': body.trim(),
        'categoryId': categoryId,
        'anonymous': anonymous,
        'imageIds': imageIds,
        if (poll != null) 'poll': poll,
      },
      true,
      {'Idempotency-Key': idempotencyKey ?? newIdempotencyKey()},
    );
    Analytics.instance.action('forum_topic_create');
    return TopicView.fromJson(_m(r));
  }

  Future<TopicView> editTopic(int id, {String? title, String? body, int? categoryId}) async => TopicView.fromJson(_m(
      await _api.patch('/forum/topics/$id', {
        if (title != null) 'title': title.trim(),
        if (body != null) 'body': body.trim(),
        if (categoryId != null) 'categoryId': categoryId,
      })));

  Future<void> deleteTopic(int id) => _api.delete('/forum/topics/$id');

  /// Moderatör: PIN | UNPIN | LOCK | UNLOCK | REMOVE | RESTORE.
  Future<void> moderateTopic(int id, String action, {String? reason}) => _api.post('/forum/topics/$id/moderate', {
        'action': action,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      });

  // ---- Medya ----------------------------------------------------------------------------------------------

  /// `POST /forum/media` (multipart `file`): jpeg/png/webp. Hata: [ImageException] ya da [ApiError].
  Future<ForumImage> uploadImage(Uint8List bytes, {http.Client? client, ImageService? image}) async {
    if (bytes.isEmpty) throw ImageException('EMPTY');
    final prepared = await (image ?? ImageService()).prepare(bytes, limit: 8 * 1024 * 1024);
    final json = await MultipartUploader(session, client: client).upload('/forum/media', prepared);
    if (json is! Map) throw ApiError(500, 'BAD_RESPONSE', '');
    return ForumImage.fromJson(Map<String, dynamic>.from(json));
  }

  // ---- Konu etkileşimleri ---------------------------------------------------------------------------------

  Future<ForumLikeResult> likeTopic(int id, bool like) async => ForumLikeResult.fromJson(
      like ? await _api.put('/forum/topics/$id/like') : await _api.delete('/forum/topics/$id/like'));

  Future<bool> bookmarkTopic(int id, bool saved) async {
    final r = saved ? await _api.put('/forum/topics/$id/bookmark') : await _api.delete('/forum/topics/$id/bookmark');
    return r is Map && r['saved'] is bool ? r['saved'] as bool : saved;
  }

  Future<bool> followTopic(int id, bool follow) async {
    final r = follow ? await _api.put('/forum/topics/$id/follow') : await _api.delete('/forum/topics/$id/follow');
    return r is Map && r['following'] is bool ? r['following'] as bool : follow;
  }

  /// Konu bildirimlerini aç/kapat (`PUT /forum/topics/{id}/notifications`).
  Future<bool> setTopicNotifications(int id, bool enabled) async {
    final r = await _api.put('/forum/topics/$id/notifications', {'enabled': enabled});
    return r is Map && r['enabled'] is bool ? r['enabled'] as bool : enabled;
  }

  // ---- Yorumlar -------------------------------------------------------------------------------------------

  Future<ForumPage<ForumComment>> comments(int topicId,
          {ForumCommentSort sort = ForumCommentSort.best, String? cursor, int size = 15, bool force = false}) async =>
      ForumPage.parse(
          await _api.get('/forum/topics/$topicId/comments${_q({'sort': sort.wire, 'cursor': cursor, 'size': size})}',
              force: force || cursor == null),
          ForumComment.fromJson);

  /// Bir yorumun doğrudan yanıtları.
  Future<ForumPage<ForumComment>> replies(int commentId, {String? cursor, int size = 15, bool force = false}) async =>
      ForumPage.parse(
          await _api.get('/forum/comments/$commentId/replies${_q({'cursor': cursor, 'size': size})}',
              force: force || cursor == null),
          ForumComment.fromJson);

  /// Tek yorum + `topicId` + `path` (bağlantı/bildirimden açma).
  Future<ForumComment> comment(int id) async => ForumComment.fromJson(_m(await _api.get('/forum/comments/$id', force: true)));

  Future<ForumComment> createComment(int topicId,
      {required String body, int? parentCommentId, bool anonymous = false, String? idempotencyKey}) async {
    final r = await _api.post(
      '/forum/topics/$topicId/comments',
      {
        'body': body.trim(),
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
        'anonymous': anonymous,
      },
      true,
      {'Idempotency-Key': idempotencyKey ?? newIdempotencyKey()},
    );
    Analytics.instance.action('forum_comment_create');
    return ForumComment.fromJson(_m(r));
  }

  Future<ForumComment> editComment(int id, String body) async =>
      ForumComment.fromJson(_m(await _api.patch('/forum/comments/$id', {'body': body.trim()})));

  Future<void> deleteComment(int id) => _api.delete('/forum/comments/$id');

  Future<ForumLikeResult> likeComment(int id, bool like) async => ForumLikeResult.fromJson(
      like ? await _api.put('/forum/comments/$id/like') : await _api.delete('/forum/comments/$id/like'));

  Future<bool> bookmarkComment(int id, bool saved) async {
    final r = saved ? await _api.put('/forum/comments/$id/bookmark') : await _api.delete('/forum/comments/$id/bookmark');
    return r is Map && r['saved'] is bool ? r['saved'] as bool : saved;
  }

  /// Moderatör: REMOVE | RESTORE (gerekçe zorunlu).
  Future<void> moderateComment(int id, String action, {required String reason}) =>
      _api.post('/forum/comments/$id/moderate', {'action': action, 'reason': reason.trim()});

  // ---- Anket ----------------------------------------------------------------------------------------------

  Future<ForumPoll> votePoll(int topicId, int optionId) async =>
      ForumPoll.fromJson(_m(await _api.put('/forum/topics/$topicId/poll/vote', {'optionId': optionId})));

  /// Oyu geri alır (yalnız `allowChangeVote` ve açık anket). Sunucu güncel anketi ya da boş gövde döner.
  Future<ForumPoll?> clearPollVote(int topicId) async {
    final r = await _api.delete('/forum/topics/$topicId/poll/vote');
    final m = _m(r);
    return m == null || m['options'] == null ? null : ForumPoll.fromJson(m);
  }

  // ---- Şikâyet, sessize alma, engelleme --------------------------------------------------------------------

  /// `targetType`: [kForumReportTopic] | [kForumReportComment]; `reason`: SPAM, HARASSMENT, INAPPROPRIATE,
  /// PERSONAL_INFO, OTHER. Mevcut `/reports` ucu.
  Future<void> report(String targetType, int targetId, String reason, {String? note}) =>
      _api.post('/reports', {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  Future<void> muteUser(int userId, bool mute) =>
      mute ? _api.put('/forum/mutes/$userId') : _api.delete('/forum/mutes/$userId');

  /// Yazar anonim olsa da engeller; kimlik sızdırmaz (kendi içeriğinde 400).
  Future<void> blockTopicAuthor(int topicId) => _api.post('/forum/topics/$topicId/block-author', {});

  Future<void> blockCommentAuthor(int commentId) => _api.post('/forum/comments/$commentId/block-author', {});

  // ---- Arama ----------------------------------------------------------------------------------------------

  /// `sort`: RELEVANCE | NEWEST | POPULAR. En az 2 karakter (sunucu da doğrular).
  Future<ForumPage<ForumSearchHit>> search(String q,
          {int? categoryId, String sort = 'RELEVANCE', String? cursor, int size = 15}) async =>
      ForumPage.parse(
          await _api.get('/forum/search${_q({'q': q.trim(), 'categoryId': categoryId, 'sort': sort, 'cursor': cursor, 'size': size})}',
              force: true),
          ForumSearchHit.fromJson);

  /// Popüler konular (son 7 gün, en çok 10).
  Future<List<TopicSummary>> popular() async {
    final r = await _api.get('/forum/search/popular');
    final list = r is List ? r : (r is Map && r['items'] is List ? r['items'] as List : const []);
    return [for (final e in list) if (e is Map) TopicSummary.fromJson(Map<String, dynamic>.from(e))];
  }

  // ---- Profil / kendi faaliyetim ---------------------------------------------------------------------------

  /// Açtığım konular (anonim dahil).
  Future<ForumPage<TopicSummary>> myTopics({String? cursor, int size = 15}) async =>
      ForumPage.parse(await _api.get('/forum/me/topics${_q({'cursor': cursor, 'size': size})}', force: cursor == null),
          TopicSummary.fromJson);

  /// Yorumlarım (anonim dahil).
  Future<ForumPage<ForumComment>> myComments({String? cursor, int size = 15}) async =>
      ForumPage.parse(await _api.get('/forum/me/comments${_q({'cursor': cursor, 'size': size})}', force: cursor == null),
          ForumComment.fromJson);

  /// Kaydedilenler: konu ve yorum karışık.
  Future<ForumPage<ForumSavedItem>> saved({String? cursor, int size = 15}) async =>
      ForumPage.parse(await _api.get('/forum/me/saved${_q({'cursor': cursor, 'size': size})}', force: cursor == null),
          ForumSavedItem.fromJson);

  /// Takip ettiğim konular.
  Future<ForumPage<TopicSummary>> following({String? cursor, int size = 15}) async =>
      ForumPage.parse(await _api.get('/forum/me/following${_q({'cursor': cursor, 'size': size})}', force: cursor == null),
          TopicSummary.fromJson);

  /// Başkasının herkese açık (anonim olmayan) konuları.
  Future<ForumPage<TopicSummary>> userTopics(int userId, {String? cursor, int size = 15}) async => ForumPage.parse(
      await _api.get('/forum/users/$userId/topics${_q({'cursor': cursor, 'size': size})}', force: cursor == null),
      TopicSummary.fromJson);

  Future<ForumPage<ForumComment>> userComments(int userId, {String? cursor, int size = 15}) async => ForumPage.parse(
      await _api.get('/forum/users/$userId/comments${_q({'cursor': cursor, 'size': size})}', force: cursor == null),
      ForumComment.fromJson);

  Future<ForumUserSummary> userSummary(int userId) async =>
      ForumUserSummary.fromJson(await _api.get('/forum/users/$userId/summary'));

  // ---- Bildirim tercihleri ---------------------------------------------------------------------------------

  Future<ForumNotificationPrefs> notificationPrefs() async =>
      ForumNotificationPrefs.fromJson(await _api.get('/forum/notification-prefs', force: true));

  Future<ForumNotificationPrefs> saveNotificationPrefs(ForumNotificationPrefs p) async =>
      ForumNotificationPrefs.fromJson(await _api.put('/forum/notification-prefs', p.toJson()));
}
