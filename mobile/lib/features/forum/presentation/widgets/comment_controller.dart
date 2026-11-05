import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/api.dart' show ApiError;
import '../../data/forum_api.dart';
import '../../data/forum_models.dart';
import 'comment_tree.dart';

/// [CommentsController.focus] sonucu.
enum CommentFocus { found, notFound, needsThread }

class CommentFocusResult {
  const CommentFocusResult(this.kind, {this.threadRoot});

  final CommentFocus kind;

  /// [CommentFocus.needsThread]: hedef yorum bu düğümden başlayan ayrı zincirde (girinti sınırı aşıldı).
  final CommentNode? threadRoot;
}

/// Bir konunun yorum ağacının durumu ve eylemleri. Konu ekranı ile "yanıt zinciri" ekranı AYNI örneği paylaşır
/// (düğümler ortak: bir ekrandaki beğeni/yanıt ötekinde de görünür).
///
/// * Üst düzey yorumlar imleçli sayfalanır; her biri `replyPreview` (≤2) ile gelir, kalanı `replies` ucundan.
/// * Beğeni iyimser; hata olursa son onaylı duruma döner. Aynı yorum için tek uçuşlu istek: art arda dokunuşlar
///   birleşir, sunucuya son istenen durum gider (çift beğeni olmaz).
/// * Yazma eylemleri [ApiError] fırlatır; çağıran toast gösterir. 404 (eşzamanlı silme) için çağıran [load] ile yeniler.
class CommentsController extends ChangeNotifier {
  CommentsController({
    required this.api,
    required this.topicId,
    this.sort = ForumCommentSort.best,
    this.onCountDelta,
    this.pageSize = 15,
    this.collapseDuration = const Duration(milliseconds: 200),
  });

  final ForumApi api;
  final int topicId;
  final int pageSize;

  /// Yorum sayısı değişince (+1 eklendi, -1 silindi) konu sayacını güncellemek için.
  final void Function(int delta)? onCountDelta;

  /// "Yanıtları gizle" kapanma animasyonu süresi (hareket azaltılmışsa 0 verin).
  Duration collapseDuration;

  ForumCommentSort sort;
  final List<CommentNode> roots = [];
  bool loading = false;
  Object? error;
  bool loadingMore = false;
  Object? moreError;
  String? cursor;
  bool loadedOnce = false;

  /// Vurgulanan yorum (bağlantıdan gelen ya da yeni yazılan); kısa süre sonra kalkar.
  int? highlightId;

  /// Yeni eklenen satırlar (giriş animasyonu için kısa süre işaretli).
  final Set<int> freshIds = {};

  int _gen = 0;
  bool _disposed = false;
  Timer? _hlTimer;
  Timer? _freshTimer;
  final List<Timer> _timers = [];

  bool get hasMore => cursor != null && cursor!.isNotEmpty;
  bool get isEmpty => roots.isEmpty;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _hlTimer?.cancel();
    _freshTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  CommentNode? find(int id) {
    for (final r in roots) {
      final n = r.find(id);
      if (n != null) return n;
    }
    return null;
  }

  // ---- Üst düzey liste -----------------------------------------------------------------------------------

  /// İlk sayfa (ya da yenileme). [silent] true ve liste doluysa iskelet göstermeden yeniler.
  Future<void> load({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent || roots.isEmpty) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final page = await api.comments(topicId, sort: sort, size: pageSize);
      if (gen != _gen) return;
      roots
        ..clear()
        ..addAll(page.items.map(CommentNode.new));
      cursor = page.nextCursor;
      loadedOnce = true;
      error = null;
      moreError = null;
    } catch (e) {
      if (gen != _gen) return;
      if (!silent || roots.isEmpty) error = e;
    } finally {
      if (gen == _gen) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || loading || !hasMore) return;
    final gen = _gen;
    loadingMore = true;
    moreError = null;
    notifyListeners();
    try {
      final page = await api.comments(topicId, sort: sort, cursor: cursor, size: pageSize);
      if (gen != _gen) return;
      final have = roots.map((r) => r.id).toSet();
      for (final c in page.items) {
        if (have.add(c.id)) roots.add(CommentNode(c));
      }
      cursor = page.nextCursor;
    } catch (e) {
      if (gen == _gen) moreError = e;
    } finally {
      if (gen == _gen) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> setSort(ForumCommentSort s) async {
    if (s == sort) return;
    sort = s;
    roots.clear();
    cursor = null;
    await load();
  }

  // ---- Yanıtlar ------------------------------------------------------------------------------------------

  /// "N yanıtı göster": açar; yanıtlar henüz tam çekilmediyse `replies` ucundan ilk sayfayı alır.
  Future<void> showReplies(CommentNode n) async {
    n
      ..expanded = true
      ..collapsing = false;
    notifyListeners();
    if (!n.repliesLoaded) await loadReplies(n);
  }

  /// "Yanıtları gizle": kapanma animasyonu sonrası düğümler listeden çıkar.
  void hideReplies(CommentNode n) {
    if (collapseDuration == Duration.zero) {
      n
        ..expanded = false
        ..collapsing = false;
      notifyListeners();
      return;
    }
    n.collapsing = true;
    notifyListeners();
    _timers.add(Timer(collapseDuration, () {
      n
        ..collapsing = false
        ..expanded = false;
      notifyListeners();
    }));
  }

  /// Yanıt sayfası getirir: [more] true ise imleçten devam, değilse ilk sayfa.
  Future<void> loadReplies(CommentNode n, {bool more = false}) async {
    if (n.loadingReplies) return;
    n
      ..loadingReplies = true
      ..repliesError = null;
    notifyListeners();
    try {
      final useCursor = more && n.repliesLoaded ? n.repliesCursor : null;
      final page = await api.replies(n.id, cursor: useCursor, size: kReplyPageSize);
      final fresh = <int>[];
      if (useCursor == null) {
        // İlk sayfa: önizleme/yerel çocukları koru (durumları taşınsın), sunucu sırasını esas al.
        final old = {for (final c in n.children) c.id: c};
        final merged = <CommentNode>[];
        for (final c in page.items) {
          final prev = old.remove(c.id);
          if (prev == null) fresh.add(c.id);
          merged.add(prev ?? CommentNode(c));
        }
        merged.addAll(old.values); // yalnız yerelde bilinenler (az önce yazılan yanıt vb.) sona
        n.children
          ..clear()
          ..addAll(merged);
      } else {
        final have = n.children.map((c) => c.id).toSet();
        for (final c in page.items) {
          if (have.add(c.id)) {
            n.children.add(CommentNode(c));
            fresh.add(c.id);
          }
        }
      }
      n.repliesCursor = page.nextCursor;
      n.repliesLoaded = true;
      if (n.replyCount < n.children.length) n.replyCount = n.children.length;
      _markFresh(fresh);
    } catch (e) {
      n.repliesError = e;
    } finally {
      n.loadingReplies = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreReplies(CommentNode n) => loadReplies(n, more: true);

  // ---- Yazma ---------------------------------------------------------------------------------------------

  /// Yeni yorum/yanıt. [key]: bu gönderme niyetinin `Idempotency-Key`'i (yeniden denemede aynısı verilir).
  Future<CommentNode> create({
    required String body,
    CommentNode? parent,
    required bool anonymous,
    required String key,
  }) async {
    final c = await api.createComment(topicId,
        body: body, parentCommentId: parent?.id, anonymous: anonymous, idempotencyKey: key);
    final node = CommentNode(c);
    if (parent == null) {
      if (find(node.id) == null) {
        // En eskiye göre sıralıyken ve sonraki sayfalar varsa yeni yorum doğal olarak listenin sonundadır
        // (henüz yüklenmedi); diğer sıralamalarda başa konur.
        if (sort == ForumCommentSort.oldest) {
          if (!hasMore) roots.add(node);
        } else {
          roots.insert(0, node);
        }
      }
    } else {
      if (parent.childById(node.id) == null) parent.children.add(node);
      parent.replyCount = parent.replyCount + 1 > parent.children.length ? parent.replyCount + 1 : parent.children.length;
      parent
        ..expanded = true
        ..collapsing = false;
    }
    onCountDelta?.call(1);
    _markFresh([node.id]);
    highlight(node.id);
    notifyListeners();
    return node;
  }

  Future<void> edit(CommentNode n, String body) async {
    final c = await api.editComment(n.id, body);
    n.body = c.body ?? body.trim();
    n.editedAt = (c.editedAt ?? '').isNotEmpty ? c.editedAt : DateTime.now().toUtc().toIso8601String();
    notifyListeners();
  }

  /// Siler: yanıtı olan yorum "silindi" yer tutucusu olarak kalır, olmayan listeden kalkar.
  Future<void> remove(CommentNode n) async {
    await api.deleteComment(n.id);
    _applyRemoved(n);
    notifyListeners();
  }

  void _applyRemoved(CommentNode n) {
    onCountDelta?.call(-1);
    if (n.replyCount > 0 || n.children.isNotEmpty) {
      n
        ..deleted = true
        ..author = null
        ..body = null;
      return;
    }
    _detach(n);
  }

  void _detach(CommentNode n) {
    final p = n.parentId == null ? null : find(n.parentId!);
    if (p == null) {
      roots.removeWhere((r) => r.id == n.id);
      return;
    }
    p.children.removeWhere((c) => c.id == n.id);
    if (p.replyCount > 0) p.replyCount--;
    // Yanıtı kalmayan "silindi" yer tutucusunu da kaldır (artık gösterecek bir şey yok).
    if (p.deleted && p.replyCount == 0 && p.children.isEmpty) _detach(p);
  }

  // ---- Beğeni / kaydet -----------------------------------------------------------------------------------

  /// İyimser beğeni. Tek uçuş: istek sürerken yeni dokunuşlar yalnız yerel durumu çevirir, bitince son istenen
  /// durum gönderilir. Hatada son onaylı duruma döner ve hata yeniden fırlatılır.
  Future<void> toggleLike(CommentNode n) async {
    if (n.deleted) return;
    if (!n.likeBusy) {
      n
        ..confirmedLiked = n.likedByMe
        ..confirmedLikeCount = n.likeCount;
    }
    n.likedByMe = !n.likedByMe;
    n.likeCount = (n.likeCount + (n.likedByMe ? 1 : -1)).clamp(0, 1 << 30);
    notifyListeners();
    if (n.likeBusy) return;
    n.likeBusy = true;
    try {
      while (true) {
        final want = n.likedByMe;
        final r = await api.likeComment(n.id, want);
        n
          ..confirmedLiked = r.liked
          ..confirmedLikeCount = r.likeCount;
        if (n.likedByMe == want) {
          n
            ..likedByMe = r.liked
            ..likeCount = r.likeCount;
          break;
        }
        // Bu arada kullanıcı tekrar çevirdi: son istenen duruma gönder.
      }
    } catch (_) {
      n
        ..likedByMe = n.confirmedLiked
        ..likeCount = n.confirmedLikeCount;
      rethrow;
    } finally {
      n.likeBusy = false;
      notifyListeners();
    }
  }

  Future<void> toggleSave(CommentNode n) async {
    if (n.deleted) return;
    final prev = n.savedByMe;
    n.savedByMe = !prev;
    notifyListeners();
    try {
      final saved = await api.bookmarkComment(n.id, !prev);
      n.savedByMe = saved;
    } catch (_) {
      n.savedByMe = prev;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  // ---- Bağlantıdan / bildirimden açma --------------------------------------------------------------------

  /// [commentId] yorumuna iner: ata zincirini açar, gerekirse listeye ekler, vurgular. Girinti sınırından derin
  /// hedef için [CommentFocus.needsThread] döner (çağıran ayrı zincir ekranını açar).
  /// [from]: ayrı zincir ekranının kök düğümü (verilirse zincir ondan başlar).
  Future<CommentFocusResult> focus(int commentId, {CommentNode? from}) async {
    final ForumComment target;
    try {
      target = await api.comment(commentId);
    } on ApiError {
      return const CommentFocusResult(CommentFocus.notFound);
    }
    final chain = [...target.path, target.id];
    var idx = 0;
    CommentNode? cur;
    if (from != null) {
      idx = chain.indexOf(from.id);
      if (idx < 0) return const CommentFocusResult(CommentFocus.notFound);
      cur = from;
    } else {
      cur = find(chain.first);
      if (cur == null) {
        // Üst düzey yorum henüz yüklenmedi: ucundan alıp listenin başına koy.
        final ForumComment rootC;
        try {
          rootC = chain.length == 1 ? target : await api.comment(chain.first);
        } on ApiError {
          return const CommentFocusResult(CommentFocus.notFound);
        }
        cur = CommentNode(rootC);
        roots.insert(0, cur);
      }
    }
    for (var i = idx + 1; i < chain.length; i++) {
      final level = i - idx;
      if (level > kCommentMaxLevel) {
        return CommentFocusResult(CommentFocus.needsThread, threadRoot: cur);
      }
      cur!
        ..expanded = true
        ..collapsing = false;
      var next = cur.childById(chain[i]);
      var pages = 0;
      while (next == null && pages < 6 && (!cur.repliesLoaded || cur.hasMoreReplies)) {
        await loadReplies(cur, more: cur.repliesLoaded);
        next = cur.childById(chain[i]);
        pages++;
        if (cur.repliesError != null) break;
      }
      if (next == null) {
        // Sayfalarda bulunamadı: tek yorum ucundan ekle.
        try {
          final c = chain[i] == target.id ? target : await api.comment(chain[i]);
          next = CommentNode(c);
          cur.children.insert(0, next);
          if (cur.replyCount < cur.children.length) cur.replyCount = cur.children.length;
        } on ApiError {
          return const CommentFocusResult(CommentFocus.notFound);
        }
      }
      cur = next;
    }
    _markFresh([cur!.id]);
    highlight(cur.id);
    notifyListeners();
    return const CommentFocusResult(CommentFocus.found);
  }

  void highlight(int id) {
    highlightId = id;
    _hlTimer?.cancel();
    _hlTimer = Timer(const Duration(milliseconds: 2800), () {
      highlightId = null;
      notifyListeners();
    });
  }

  void _markFresh(Iterable<int> ids) {
    if (ids.isEmpty) return;
    freshIds.addAll(ids);
    _freshTimer?.cancel();
    _freshTimer = Timer(const Duration(milliseconds: 600), () => freshIds.clear());
  }
}
