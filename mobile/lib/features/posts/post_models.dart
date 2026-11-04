import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/api.dart' show apiOrigin;
import '../../core/locale_controller.dart';
import '../../core/session.dart';

/// Gönderi modelleri: docs/POSTS_DESIGN.md sözleşmesi. Tüm `fromJson`lar null-güvenlidir.

/// Sunucunun göreli yolunu (/api/posts/media/5, /files/...) mutlak adrese çevirir.
/// Yetkili medya uçları için [postAuthHeaders] ile Bearer eklenmelidir.
String postMediaUrl(String path) => path.startsWith('http') ? path : '$apiOrigin$path';

String? postMediaUrlOrNull(String? path) => (path == null || path.isEmpty) ? null : postMediaUrl(path);

/// `/api/posts/media/*` gibi yetkili uçlar için istek başlıkları.
Map<String, String> postAuthHeaders(Session s) {
  final t = s.api.tokens;
  return t == null ? const {} : {'Authorization': 'Bearer ${t.access}'};
}

/// Gönderi zamanı: "şimdi", "5 dk önce", "3 gün önce", sonra yerel tarih (dile göre).
String postRelativeTime(BuildContext context, String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final l = context.l10n;
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return l.postViewAgoNow;
  if (diff.inMinutes < 60) return l.postViewAgoMinFull(diff.inMinutes.toString());
  if (diff.inHours < 24) return l.postViewAgoHourFull(diff.inHours.toString());
  if (diff.inDays < 7) return l.postViewAgoDayFull(diff.inDays.toString());
  try {
    return DateFormat('d MMMM y', Localizations.localeOf(context).toString()).format(d);
  } catch (_) {
    return DateFormat('d MMMM y').format(d);
  }
}

int _int(Object? v, [int def = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? def : def);
int? _intOrNull(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
String? _str(Object? v) => v is String ? v : null;
Map<String, dynamic>? _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;
List<Map<String, dynamic>> _maps(Object? v) =>
    v is List ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)] : const [];

/// Popülerlik puanı: sunucu 0..100 üretir; ondalıklı gelirse yuvarlanır, aralık dışı değer kıstırılır.
int? _scoreOrNull(Object? v) {
  final n = v is num ? v : (v is String ? num.tryParse(v) : null);
  return n?.round().clamp(0, 100);
}

class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.department,
    this.followerCount,
    this.popularityScore,
  });

  factory PostAuthor.fromJson(Map<String, dynamic>? j) => PostAuthor(
        id: _int(j?['id']),
        displayName: _str(j?['displayName']) ?? '',
        avatarUrl: _str(j?['avatarUrl']),
        department: _str(j?['department']),
        followerCount: _intOrNull(j?['followerCount']),
        popularityScore: _scoreOrNull(j?['popularityScore']),
      );

  final int id;
  final String displayName;
  final String? avatarUrl;
  final String? department;

  /// Sunucunun hesapladığı gerçek takipçi sayısı (yoksa null: gösterilmez).
  final int? followerCount;

  /// Yazarın popülerlik puanı 0..100 (yoksa null).
  final int? popularityScore;
}

enum PostMediaKind { image, video }

class PostMedia {
  const PostMedia({
    required this.id,
    required this.kind,
    required this.url,
    this.thumbUrl,
    this.width,
    this.height,
    this.durationMs,
  });

  factory PostMedia.fromJson(Map<String, dynamic>? j) {
    final id = _int(j?['id']);
    return PostMedia(
      id: id,
      kind: _str(j?['kind']) == 'VIDEO' ? PostMediaKind.video : PostMediaKind.image,
      url: postMediaUrl(_str(j?['url']) ?? '/api/posts/media/$id'),
      thumbUrl: postMediaUrlOrNull(_str(j?['thumbUrl'])),
      width: _intOrNull(j?['width']),
      height: _intOrNull(j?['height']),
      durationMs: _intOrNull(j?['durationMs']),
    );
  }

  final int id;
  final PostMediaKind kind;

  /// Mutlak adres (yetkili: Bearer gerekir).
  final String url;
  final String? thumbUrl;
  final int? width;
  final int? height;
  final int? durationMs;

  bool get isVideo => kind == PostMediaKind.video;

  /// Genişlik/yükseklik; bilinmiyorsa 1.0. Aşırı uç oranlar 0.5–1.91 arasına sıkıştırılır.
  double get aspect {
    final w = width, h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return 1.0;
    return (w / h).clamp(0.5, 1.91);
  }
}

class LikeResult {
  const LikeResult({required this.liked, required this.likeCount});

  factory LikeResult.fromJson(Map<String, dynamic>? j) =>
      LikeResult(liked: j?['liked'] == true, likeCount: _int(j?['likeCount']));

  final bool liked;
  final int likeCount;
}

/// Video gönderinin oynatma bilgisi (`video {url, posterUrl, durationMs, width, height}`).
class PostVideo {
  const PostVideo({required this.url, this.posterUrl, this.durationMs, this.width, this.height});

  factory PostVideo.fromJson(Map<String, dynamic> j) => PostVideo(
        url: postMediaUrl(_str(j['url']) ?? ''),
        posterUrl: postMediaUrlOrNull(_str(j['posterUrl']) ?? _str(j['thumbUrl'])),
        durationMs: _intOrNull(j['durationMs']),
        width: _intOrNull(j['width']),
        height: _intOrNull(j['height']),
      );

  /// Eski biçim: `media[]` içindeki `kind: VIDEO` öğesi.
  factory PostVideo.fromMedia(PostMedia m) =>
      PostVideo(url: m.url, posterUrl: m.thumbUrl, durationMs: m.durationMs, width: m.width, height: m.height);

  /// Mutlak adres (yetkili: Bearer gerekir).
  final String url;
  final String? posterUrl;
  final int? durationMs;
  final int? width;
  final int? height;

  /// Genişlik/yükseklik; bilinmiyorsa dikey 9:16 varsayılır (Reels).
  double get aspect {
    final w = width, h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return 9 / 16;
    return w / h;
  }
}

class Post {
  const Post({
    required this.id,
    required this.author,
    this.text,
    this.media = const [],
    this.video,
    this.likeCount = 0,
    this.likedByMe = false,
    this.mine = false,
    this.canEdit = false,
    this.canDelete = false,
    this.createdAt,
    this.editedAt,
    this.popularityScore,
    this.viewCount,
    this.commentCount,
    this.savedByMe,
  });

  factory Post.fromJson(Map<String, dynamic>? j) {
    final media = [for (final m in _maps(j?['media'])) PostMedia.fromJson(m)];
    final v = _map(j?['video']);
    PostVideo? video;
    if (v != null && (_str(v['url']) ?? '').isNotEmpty) {
      video = PostVideo.fromJson(v);
    } else if (_str(j?['type']) == 'VIDEO' || (j?['type'] == null && media.isNotEmpty && media.every((m) => m.isVideo))) {
      for (final m in media) {
        if (m.isVideo) {
          video = PostVideo.fromMedia(m);
          break;
        }
      }
    }
    return Post(
      id: _int(j?['id']),
      author: PostAuthor.fromJson(_map(j?['author'])),
      text: _str(j?['text']),
      media: media,
      video: video,
      likeCount: _int(j?['likeCount']),
      likedByMe: j?['likedByMe'] == true,
      mine: j?['mine'] == true,
      canEdit: j?['canEdit'] == true,
      canDelete: j?['canDelete'] == true,
      createdAt: _str(j?['createdAt']),
      editedAt: _str(j?['editedAt']),
      popularityScore: _scoreOrNull(j?['popularityScore']),
      viewCount: _intOrNull(j?['viewCount']),
      commentCount: _intOrNull(j?['commentCount']),
      savedByMe: j?['savedByMe'] is bool ? j!['savedByMe'] as bool : null,
    );
  }

  final int id;
  final PostAuthor author;
  final String? text;
  final List<PostMedia> media;

  /// Video gönderi: oynatma bilgisi (fotoğraf gönderisinde null).
  final PostVideo? video;
  final int likeCount;
  final bool likedByMe;
  final bool mine;
  final bool canEdit;
  final bool canDelete;
  final String? createdAt;
  final String? editedAt;

  /// Gönderinin popülerlik puanı 0..100 (sunucu hesaplar; yoksa null: gösterge çizilmez).
  final int? popularityScore;

  /// Yalnız video gönderide: izlenme sayısı (yoksa null).
  final int? viewCount;

  /// Yorum sayısı: yalnız sunucu yorum özelliğini sunuyorsa gelir (yoksa null: yorum düğmesi gizlenir).
  final int? commentCount;

  /// Kaydetme durumu: yalnız sunucu kaydetmeyi sunuyorsa gelir (yoksa null: kaydet düğmesi gizlenir).
  final bool? savedByMe;

  bool get hasText => (text ?? '').trim().isNotEmpty;

  bool get isVideo => video != null;

  /// Gösterilecek tek görsel: fotoğraf gönderisinde ilk fotoğraf; video gönderisinde poster kare (poster yoksa null).
  PostMedia? get photo {
    final v = video;
    if (v != null) {
      final poster = v.posterUrl;
      if (poster == null) return null;
      return PostMedia(
          id: -id, kind: PostMediaKind.image, url: poster, thumbUrl: poster, width: v.width, height: v.height, durationMs: v.durationMs);
    }
    for (final m in media) {
      if (!m.isVideo) return m;
    }
    return null;
  }

  /// Ne fotoğrafı ne videosu olan (yalnız bilinmeyen medya taşıyan) kayıtlar akışta gösterilmez.
  bool get hiddenInFeed => media.isNotEmpty && video == null && photo == null;

  /// [editedAt] ve [text] için null verilemez; `clearText` metni siler.
  Post copyWith({
    bool? likedByMe,
    int? likeCount,
    String? text,
    String? editedAt,
    List<PostMedia>? media,
    int? popularityScore,
    int? commentCount,
    bool? savedByMe,
  }) =>
      Post(
        id: id,
        author: author,
        text: text ?? this.text,
        media: media ?? this.media,
        video: video,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        mine: mine,
        canEdit: canEdit,
        canDelete: canDelete,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
        popularityScore: popularityScore ?? this.popularityScore,
        viewCount: viewCount,
        commentCount: commentCount ?? this.commentCount,
        savedByMe: savedByMe ?? this.savedByMe,
      );
}

/// İmleçli sayfa.
class PostPage<T> {
  const PostPage({required this.items, this.nextCursor, this.total, this.exhausted = false});

  final List<T> items;
  final String? nextCursor;
  final int? total;

  /// Keşfet: bütün havuz görülmüştü, sunucu en eski görülenlerden başlayıp tekrar ediyor (`exhausted: true`).
  final bool exhausted;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  static PostPage<T> parse<T>(Object? body, T Function(Map<String, dynamic>) map) {
    final m = body is Map ? body : const {};
    final c = m['nextCursor'];
    return PostPage<T>(
      items: [for (final e in _maps(m['items'])) map(e)],
      nextCursor: c?.toString(),
      total: _intOrNull(m['total']),
      exhausted: m['exhausted'] == true,
    );
  }
}
