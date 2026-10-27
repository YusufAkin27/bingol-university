import '../../core/session.dart';
import 'post_models.dart';
import 'social_models.dart';

/// Gönderi sosyal uçları: kaydetme, @etiketleme, #etiket, takip, hikâyeler.
/// BE5 sözleşmesi (`docs/API_CONTRACTS_V2.md` "Gönderi sosyal") hazır olana dek yollar tahmindir;
/// değişiklik gerekirse yalnız bu dosya düzenlenir. Tek HTTP katmanı `session.api`.
class SocialApi {
  SocialApi(this.session);

  final Session session;

  String _q(Map<String, Object?> p) {
    final parts = <String>[
      for (final e in p.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) '${e.key}=${Uri.encodeQueryComponent('${e.value}')}',
    ];
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  // ---------- Kaydetme ----------

  Future<void> save(int postId) => session.api.put('/posts/$postId/save');

  Future<void> unsave(int postId) => session.api.delete('/posts/$postId/save');

  Future<PostPage<Post>> savedPosts({String? cursor, int size = 10}) async =>
      PostPage.parse(await session.api.get('/posts/saved${_q({'cursor': cursor, 'size': size})}'), Post.fromJson);

  // ---------- @etiketleme / #etiket ----------

  Future<List<SocialUser>> mentionSuggest(String q) async {
    final r = await session.api.get('/users/mention-suggest${_q({'q': q})}');
    return [for (final m in socialItems(r)) SocialUser.fromJson(m)];
  }

  Future<List<TrendingTag>> trending() async {
    final r = await session.api.get('/hashtags/trending');
    return [for (final m in socialItems(r)) TrendingTag.fromJson(m)];
  }

  Future<List<TrendingTag>> hashtagSuggest(String q) async {
    final r = await session.api.get('/hashtags/suggest${_q({'q': q})}');
    return [for (final m in socialItems(r)) TrendingTag.fromJson(m)];
  }

  Future<PostPage<Post>> hashtagPosts(String tag, {String? cursor, int size = 10}) async => PostPage.parse(
      await session.api.get('/hashtags/${Uri.encodeComponent(tag)}/posts${_q({'cursor': cursor, 'size': size})}'),
      Post.fromJson);

  // ---------- Takip ----------

  Future<FollowStats> followStats(int userId) async =>
      FollowStats.fromJson((await session.api.get('/users/$userId/follow-stats')) as Map<String, dynamic>?);

  Future<void> follow(int userId) => session.api.put('/users/$userId/follow');

  Future<void> unfollow(int userId) => session.api.delete('/users/$userId/follow');

  Future<PostPage<SocialUser>> followers(int userId, {String? cursor, int size = 30}) async => PostPage.parse(
      await session.api.get('/users/$userId/followers${_q({'cursor': cursor, 'size': size})}'), SocialUser.fromJson);

  Future<PostPage<SocialUser>> following(int userId, {String? cursor, int size = 30}) async => PostPage.parse(
      await session.api.get('/users/$userId/following${_q({'cursor': cursor, 'size': size})}'), SocialUser.fromJson);

  Future<List<SocialUser>> followSuggestions({int size = 20}) async {
    final r = await session.api.get('/users/me/follow-suggestions${_q({'size': size})}');
    return [for (final m in socialItems(r)) SocialUser.fromJson(m)];
  }

  // ---------- Hikâyeler ----------

  Future<List<StoryGroup>> tray() async {
    final r = await session.api.get('/stories/tray');
    return StoryGroup.ordered([for (final m in socialItems(r)) StoryGroup.fromJson(m, selfId: session.userId)]);
  }

  Future<List<Story>> userStories(int userId) async {
    final r = await session.api.get('/users/$userId/stories');
    return [for (final m in socialItems(r)) Story.fromJson(m)];
  }

  Future<void> markViewed(int storyId) => session.api.post('/stories/$storyId/view');

  Future<List<SocialUser>> viewers(int storyId) async {
    final r = await session.api.get('/stories/$storyId/viewers');
    return [for (final m in socialItems(r)) SocialUser.fromJson(m)];
  }

  Future<void> deleteStory(int storyId) => session.api.delete('/stories/$storyId');

  /// [kind]: IMAGE | VIDEO (`mediaId` ile) ya da TEXT (`bodyText` + `background`).
  Future<Story> createStory({required String kind, int? mediaId, String? caption, String? bodyText, String? background}) async {
    final r = await session.api.post('/stories', {
      'kind': kind,
      if (mediaId != null) 'mediaId': mediaId,
      if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
      if (bodyText != null && bodyText.trim().isNotEmpty) 'bodyText': bodyText.trim(),
      if (background != null) 'background': background,
    });
    return Story.fromJson(r as Map<String, dynamic>?);
  }
}
