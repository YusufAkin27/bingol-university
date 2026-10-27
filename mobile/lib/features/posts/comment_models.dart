import '../../core/api.dart';
import '../../core/session.dart';
import 'post_models.dart' show CommentUser;

export 'post_models.dart' show CommentUser;

/// Sözleşme CommentView. Alanlar iyimser güncelleme için değiştirilebilir.
int? _n(Object? v) => v is num ? v.toInt() : null;
String? _s(Object? v) => v is String ? v : null;

class Comment {
  Comment({
    required this.id,
    required this.postId,
    required this.depth,
    required this.author,
    this.parentId,
    this.rootId,
    this.replyToUser,
    this.text,
    this.deleted = false,
    this.replyCount = 0,
    this.mine = false,
    this.canEdit = false,
    this.canDelete = false,
    this.createdAt,
    this.editedAt,
    this.previews = const [],
  });

  int id;
  int postId;
  int? parentId;
  int? rootId;
  int depth;
  CommentUser author;
  CommentUser? replyToUser;
  String? text;
  bool deleted;
  int replyCount;
  bool mine;
  bool canEdit;
  bool canDelete;
  String? createdAt;
  String? editedAt;
  List<Comment> previews;

  /// Geçici (sunucuya henüz yazılmamış) yorum mu?
  bool get isTemp => id < 0;

  factory Comment.fromJson(Map<String, dynamic> j) {
    final a = j['author'];
    final r = j['replyToUser'];
    final prev = j['previewReplies'];
    return Comment(
      id: _n(j['id']) ?? 0,
      postId: _n(j['postId']) ?? 0,
      parentId: _n(j['parentId']),
      rootId: _n(j['rootId']),
      depth: _n(j['depth']) ?? 0,
      author: a is Map<String, dynamic> ? CommentUser.fromJson(a) : const CommentUser(id: 0, displayName: ''),
      replyToUser: r is Map<String, dynamic> ? CommentUser.fromJson(r) : null,
      text: _s(j['text']),
      deleted: j['deleted'] == true,
      replyCount: _n(j['replyCount']) ?? 0,
      mine: j['mine'] == true,
      canEdit: j['canEdit'] == true,
      canDelete: j['canDelete'] == true,
      createdAt: _s(j['createdAt']),
      editedAt: _s(j['editedAt']),
      previews: prev is List
          ? [for (final p in prev) if (p is Map<String, dynamic>) Comment.fromJson(p)]
          : const [],
    );
  }
}

/// Yorum ağacındaki düğüm: yorum + yüklenmiş çocuklar + gösterim durumu.
class CNode {
  CNode(this.c, {this.parent});

  Comment c;
  CNode? parent;
  final List<CNode> children = [];

  /// Yanıtlar gizlendi mi ("Yanıtları gizle").
  bool collapsed = false;

  /// `replies` ucundan en az bir kez yüklendi mi.
  bool fetched = false;

  /// `replies` ucunun sonraki imleci (fetched iken; null = bitti).
  String? next;
  bool loading = false;
  Object? error;

  /// Gönderim durumu (yalnız geçici yorumlar).
  bool pending = false;
  bool failed = false;
  String? sendError;
  int? sendParentId;

  /// Sunucuda olan çocuk sayısı (geçici/başarısız olanlar hariç).
  int get realChildren => children.where((n) => !n.c.isTemp).length;

  /// Yüklenmemiş yanıt kaldı mı?
  bool get hasMore => fetched ? next != null : c.replyCount > realChildren;
}

/// `session.api` üstünden yorum uçları (sözleşme bölüm 2).
class CommentApi {
  CommentApi(this.session);

  final Session session;
  ApiClient get _api => session.api;

  static String _q(String? cursor) => cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}';

  Future<CommentPage> roots(int postId, {required String sort, String? cursor, int size = 20}) async {
    final j = await _api.get('/posts/$postId/comments?sort=$sort&size=$size${_q(cursor)}');
    return CommentPage.fromJson(j);
  }

  Future<CommentPage> replies(int commentId, {String? cursor, int size = 20}) async {
    final j = await _api.get('/comments/$commentId/replies?size=$size${_q(cursor)}');
    return CommentPage.fromJson(j);
  }

  Future<dynamic> create(int postId, String text, {int? parentId}) =>
      _api.post('/posts/$postId/comments', {'text': text, if (parentId != null) 'parentId': parentId});

  Future<dynamic> edit(int id, String text) => _api.patch('/comments/$id', {'text': text});

  Future<dynamic> remove(int id) => _api.delete('/comments/$id');
}

class CommentPage {
  CommentPage(this.items, this.nextCursor, this.total);

  final List<Comment> items;
  final String? nextCursor;
  final int? total;

  factory CommentPage.fromJson(dynamic j) {
    final m = j is Map<String, dynamic> ? j : const <String, dynamic>{};
    final list = m['items'];
    return CommentPage(
      [if (list is List) for (final e in list) if (e is Map<String, dynamic>) Comment.fromJson(e)],
      _s(m['nextCursor']),
      _n(m['total']),
    );
  }
}

/// Gönderme sonucu: [removed] true ise geçici yorum kaldırıldı (doğrulama/hız sınırı hatası);
/// çağıran metni yazma kutusuna geri koyabilir.
class SendOutcome {
  const SendOutcome({this.error, this.removed = false});

  final String? error;
  final bool removed;
  bool get ok => error == null;
}

/// "2 sa", "5 dk", "3 g", "şimdi" (yorum satırı için kısa biçim).
String shortAgo(String? iso, [DateTime? now]) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'şimdi';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
  if (diff.inHours < 24) return '${diff.inHours} sa';
  if (diff.inDays < 7) return '${diff.inDays} g';
  if (diff.inDays < 365) return '${(diff.inDays / 7).floor()} hf';
  return '${(diff.inDays / 365).floor()} y';
}

String commentErrorText(Object e) => errorText(e);
