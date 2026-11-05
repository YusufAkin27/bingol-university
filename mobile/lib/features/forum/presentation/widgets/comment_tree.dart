import '../../data/forum_models.dart';

/// Yorum ağacı: saf Dart (arayüzsüz). Sunucudan gelen [ForumComment] değişmez; ekranda gösterilen DEĞİŞKEN durum
/// (beğeni, düzenleme, silme, yanıt listesi) [CommentNode] üzerinde tutulur. Düz satır listesine çevirme
/// ([flattenComments]) tembel listeye uygundur: büyük zincir tek seferde çizilmez.

/// Girintili çizilen en derin seviye (üst düzey = 0). Bundan derin yanıtlar "Yanıt zincirini aç" ile ayrı ekranda açılır.
const int kCommentMaxLevel = 2;

/// Bir yorumun yanıtları tek seferde en çok bu kadar istenir (`size`).
const int kReplyPageSize = 15;

class CommentNode {
  CommentNode(ForumComment c)
      : id = c.id,
        topicId = c.topicId,
        parentId = c.parentCommentId,
        depth = c.depth,
        author = c.author,
        body = c.body,
        anonymous = c.anonymous,
        createdAt = c.createdAt,
        editedAt = c.editedAt,
        likeCount = c.likeCount,
        likedByMe = c.likedByMe,
        savedByMe = c.savedByMe,
        replyCount = c.replyCount,
        mine = c.mine,
        deleted = c.deleted,
        canModerate = c.canModerate,
        topicAuthor = c.topicAuthor {
    // Önizleme yanıtları ilk görünen çocuklardır; hepsi değil (tam liste ilk "daha fazla"da gelir).
    for (final p in c.replyPreview) {
      children.add(CommentNode(p));
    }
    expanded = children.isNotEmpty;
    confirmedLiked = likedByMe;
    confirmedLikeCount = likeCount;
  }

  final int id;
  final int topicId;
  final int? parentId;
  final int depth;
  ForumAuthor? author;
  String? body;
  final bool anonymous;
  final String? createdAt;
  String? editedAt;
  int likeCount;
  bool likedByMe;
  bool savedByMe;

  /// Doğrudan yanıt sayısı (sunucu sayacı; yerel ekleme/silmeyle oynar).
  int replyCount;
  final bool mine;
  bool deleted;
  final bool canModerate;
  final bool topicAuthor;

  // ---- Yanıt listesi durumu ------------------------------------------------------------------------------
  final List<CommentNode> children = [];

  /// Sonraki yanıt sayfası imleci; `repliesLoaded` iken null = sayfalar bitti.
  String? repliesCursor;

  /// Yanıtların tamamı `replies` ucundan en az bir kez istendi mi (false: yalnız önizleme / yerel ekleme).
  bool repliesLoaded = false;
  bool expanded = false;
  bool loadingReplies = false;
  Object? repliesError;

  /// Gizleme animasyonu sürerken true: alt satırlar kapanma animasyonuyla görünür kalır.
  bool collapsing = false;

  // ---- Beğeni (iyimser) -----------------------------------------------------------------------------------
  bool likeBusy = false;
  bool confirmedLiked = false;
  int confirmedLikeCount = 0;

  bool get edited => (editedAt ?? '').isNotEmpty;

  /// Yazar bilgisi yok ve silinmiş değil = hesap kaldırılmış yazar.
  bool get authorGone => !deleted && (author == null || (author!.displayName.isEmpty && !author!.anonymous));

  /// Yüklenmemiş yanıt var mı?
  bool get hasMoreReplies {
    if (repliesLoaded) return repliesCursor != null && repliesCursor!.isNotEmpty;
    return children.length < replyCount;
  }

  /// Gösterilmeyen yanıt sayısı (yaklaşık; düğme metni için).
  int get hiddenReplyCount => (replyCount - children.length).clamp(0, 1 << 30);

  CommentNode? childById(int cid) {
    for (final c in children) {
      if (c.id == cid) return c;
    }
    return null;
  }

  /// Bu düğümden başlayarak kimliğe göre ara (derin).
  CommentNode? find(int cid) {
    if (cid == id) return this;
    for (final c in children) {
      final r = c.find(cid);
      if (r != null) return r;
    }
    return null;
  }
}

enum CommentRowKind { comment, footer, chain, loading, error }

/// Düz listedeki tek satır.
class CommentRow {
  const CommentRow(this.kind, this.node, this.level, {this.exiting = false});

  final CommentRowKind kind;
  final CommentNode node;

  /// Girinti seviyesi (üst düzey/ayrı zincir kökü = 0).
  final int level;

  /// Bu satır gizleme animasyonunda kapanıyor.
  final bool exiting;

  /// Liste anahtarı: satır türü + yorum kimliği.
  String get key => '${kind.name}:${node.id}';
}

/// [roots]'u düz satırlara çevirir. [baseDepth]: seviye 0 sayılan `depth` (ayrı zincir ekranında kök yorumun derinliği).
List<CommentRow> flattenComments(List<CommentNode> roots, {int baseDepth = 0, int maxLevel = kCommentMaxLevel}) {
  final rows = <CommentRow>[];
  void emit(CommentNode n, {bool exiting = false}) {
    final level = (n.depth - baseDepth).clamp(0, 1 << 20);
    rows.add(CommentRow(CommentRowKind.comment, n, level, exiting: exiting));
    final show = n.expanded || n.collapsing;
    if (level >= maxLevel) {
      // Daha derin yanıtlar girintilenmez: ayrı zincirde açılır.
      if (n.replyCount > 0) rows.add(CommentRow(CommentRowKind.chain, n, level, exiting: exiting));
      return;
    }
    final kids = show ? n.children : const <CommentNode>[];
    for (final c in kids) {
      emit(c, exiting: exiting || n.collapsing);
    }
    if (n.replyCount <= 0 && n.children.isEmpty) return;
    final childLevel = level + 1;
    if (n.expanded && n.loadingReplies) {
      rows.add(CommentRow(CommentRowKind.loading, n, childLevel, exiting: exiting));
    } else if (n.expanded && n.repliesError != null) {
      rows.add(CommentRow(CommentRowKind.error, n, childLevel, exiting: exiting));
    }
    if (!n.collapsing) {
      rows.add(CommentRow(CommentRowKind.footer, n, childLevel, exiting: exiting));
    }
  }

  for (final r in roots) {
    emit(r);
  }
  return rows;
}

/// Alt ağaçtaki tüm düğümleri (kendileri dahil) dolaşır.
Iterable<CommentNode> walkComments(Iterable<CommentNode> roots) sync* {
  for (final r in roots) {
    yield r;
    yield* walkComments(r.children);
  }
}
