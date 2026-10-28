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

class PostAuthor {
  const PostAuthor({required this.id, required this.displayName, this.avatarUrl, this.department});

  factory PostAuthor.fromJson(Map<String, dynamic>? j) => PostAuthor(
        id: _int(j?['id']),
        displayName: _str(j?['displayName']) ?? '',
        avatarUrl: _str(j?['avatarUrl']),
        department: _str(j?['department']),
      );

  final int id;
  final String displayName;
  final String? avatarUrl;
  final String? department;
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

class Post {
  const Post({
    required this.id,
    required this.author,
    this.text,
    this.media = const [],
    this.likeCount = 0,
    this.likedByMe = false,
    this.mine = false,
    this.canEdit = false,
    this.canDelete = false,
    this.createdAt,
    this.editedAt,
  });

  factory Post.fromJson(Map<String, dynamic>? j) => Post(
        id: _int(j?['id']),
        author: PostAuthor.fromJson(_map(j?['author'])),
        text: _str(j?['text']),
        media: [for (final m in _maps(j?['media'])) PostMedia.fromJson(m)],
        likeCount: _int(j?['likeCount']),
        likedByMe: j?['likedByMe'] == true,
        mine: j?['mine'] == true,
        canEdit: j?['canEdit'] == true,
        canDelete: j?['canDelete'] == true,
        createdAt: _str(j?['createdAt']),
        editedAt: _str(j?['editedAt']),
      );

  final int id;
  final PostAuthor author;
  final String? text;
  final List<PostMedia> media;
  final int likeCount;
  final bool likedByMe;
  final bool mine;
  final bool canEdit;
  final bool canDelete;
  final String? createdAt;
  final String? editedAt;

  bool get hasText => (text ?? '').trim().isNotEmpty;

  /// Gösterilecek tek fotoğraf: çoklu görselli eski gönderilerde yalnız ilk fotoğraf; video yok sayılır.
  PostMedia? get photo {
    for (final m in media) {
      if (!m.isVideo) return m;
    }
    return null;
  }

  /// Eski video-only gönderiler (yalnız video, fotoğraf yok) akışta gösterilmez.
  bool get hiddenInFeed => media.isNotEmpty && photo == null;

  /// [editedAt] ve [text] için null verilemez; `clearText` metni siler.
  Post copyWith({
    bool? likedByMe,
    int? likeCount,
    String? text,
    String? editedAt,
    List<PostMedia>? media,
  }) =>
      Post(
        id: id,
        author: author,
        text: text ?? this.text,
        media: media ?? this.media,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        mine: mine,
        canEdit: canEdit,
        canDelete: canDelete,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
      );
}

/// İmleçli sayfa.
class PostPage<T> {
  const PostPage({required this.items, this.nextCursor, this.total});

  final List<T> items;
  final String? nextCursor;
  final int? total;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  static PostPage<T> parse<T>(Object? body, T Function(Map<String, dynamic>) map) {
    final m = body is Map ? body : const {};
    final c = m['nextCursor'];
    return PostPage<T>(
      items: [for (final e in _maps(m['items'])) map(e)],
      nextCursor: c?.toString(),
      total: _intOrNull(m['total']),
    );
  }
}
