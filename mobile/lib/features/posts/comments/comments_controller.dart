import 'package:flutter/foundation.dart';

import '../../../core/api.dart' show ApiError;
import 'comment_models.dart';
import 'comments_api.dart';

/// Bir yorumun yanıt kümesi (tembel yüklenir).
class CommentThread {
  final List<PostComment> items = [];
  String? cursor;
  bool expanded = false;
  bool loading = false;
  bool loaded = false;
  bool error = false;
}

/// Yorum paneli durumu: liste, sıralama, yanıtlar, iyimser ekleme/silme/beğeni. Arayüzden bağımsızdır (test edilebilir);
/// hata bildirimi [onError] ile, kalıcı hatada yazılan metnin geri konması [onRestore] ile yapılır.
class CommentsController extends ChangeNotifier {
  CommentsController({
    required this.api,
    required this.postId,
    required int initialCount,
    required this.me,
    this.focusCommentId,
    this.onCountChanged,
    this.pageSize = 20,
  })  : _count = initialCount,
        sort = focusCommentId == null ? 'top' : 'new';

  final CommentsApi api;
  final int postId;
  final CommentAuthor me;
  final int? focusCommentId;
  final ValueChanged<int>? onCountChanged;
  final int pageSize;

  /// Sunucu hatası kullanıcıya gösterilsin (toast).
  void Function(Object error)? onError;

  /// Kalıcı hata (profanity, çok uzun...): yazılan metin ve yanıtlanan yorum girişe geri konur.
  void Function(String text, PostComment? replyTo)? onRestore;

  final List<PostComment> roots = [];
  final Map<int, CommentThread> threads = {};
  String sort;
  String? _cursor;
  bool loading = true;
  bool loadingMore = false;
  Object? error;
  int? highlightId;
  PostComment? replyTo;
  bool sending = false;

  int _count;
  int get count => _count;
  bool get hasMore => _cursor != null;

  int _gen = 0;
  int _tmp = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _setCount(int n) {
    final v = n < 0 ? 0 : n;
    if (v == _count) return;
    _count = v;
    onCountChanged?.call(v);
  }

  // ---- Yükleme ----

  Future<void> load() async {
    final gen = ++_gen;
    loading = true;
    error = null;
    _notify();
    try {
      final p = await api.list(postId, sort: sort, size: pageSize);
      if (gen != _gen) return;
      roots
        ..clear()
        ..addAll(_dedupe(p.items));
      _cursor = p.nextCursor;
      loading = false;
      _notify();
      if (focusCommentId != null && highlightId == null) await _locate(gen);
    } catch (e) {
      if (gen != _gen) return;
      loading = false;
      error = e;
      _notify();
    }
  }

  List<PostComment> _dedupe(List<PostComment> xs) {
    final seen = <int>{};
    return [for (final c in xs) if (seen.add(c.id)) c];
  }

  Future<void> loadMore() async {
    final cur = _cursor;
    if (cur == null || loadingMore || loading) return;
    final gen = _gen;
    loadingMore = true;
    _notify();
    try {
      final p = await api.list(postId, sort: sort, cursor: cur, size: pageSize);
      if (gen != _gen) return;
      final have = {for (final c in roots) c.id};
      roots.addAll(p.items.where((c) => have.add(c.id)));
      _cursor = p.nextCursor;
    } catch (e) {
      if (gen == _gen) onError?.call(e);
    }
    if (gen == _gen) {
      loadingMore = false;
      _notify();
    }
  }

  void setSort(String s) {
    if (s == sort) return;
    sort = s;
    threads.clear();
    highlightId = null;
    load();
  }

  // ---- Yanıtlar ----

  CommentThread threadOf(int rootId) => threads.putIfAbsent(rootId, CommentThread.new);

  Future<void> toggleReplies(PostComment root) async {
    final t = threadOf(root.id);
    if (t.expanded) {
      t.expanded = false;
      _notify();
      return;
    }
    t.expanded = true;
    _notify();
    if (!t.loaded) await loadReplies(root);
  }

  Future<void> loadReplies(PostComment root, {bool more = false, bool quiet = false}) async {
    final t = threadOf(root.id);
    if (t.loading) return;
    if (more && t.cursor == null) return;
    t.loading = true;
    t.error = false;
    _notify();
    try {
      final p = await api.replies(root.id, cursor: more ? t.cursor : null, size: pageSize);
      final locals = more ? const <PostComment>[] : [for (final c in t.items) if (c.isLocal) c];
      final merged = more ? [...t.items] : <PostComment>[];
      final have = {for (final c in merged) c.id};
      merged.addAll(p.items.where((c) => have.add(c.id)));
      // Sunucu listesine henüz düşmemiş yerel (gönderilen/başarısız) yanıtlar sonda kalır.
      for (final l in locals) {
        if (have.add(l.id)) merged.add(l);
      }
      t.items
        ..clear()
        ..addAll(merged);
      t.cursor = p.nextCursor;
      t.loaded = true;
    } catch (e) {
      t.error = true;
      if (!quiet) onError?.call(e);
    }
    t.loading = false;
    _notify();
  }

  // ---- Derin bağlantı: yorumu bul ----

  /// Sınırlı arama: ilk birkaç sayfa + yanıtı olan ilk yorumların yanıtları. Bulunamazsa sessizce liste açık kalır.
  Future<void> _locate(int gen) async {
    final id = focusCommentId!;
    var pages = 0;
    var replyFetches = 0;
    final checked = <int>{};
    while (gen == _gen) {
      if (roots.any((c) => c.id == id)) {
        highlightId = id;
        _notify();
        return;
      }
      for (final r in List<PostComment>.of(roots)) {
        if (r.replyCount <= 0 || !checked.add(r.id)) continue;
        if (replyFetches >= 12) break;
        replyFetches++;
        await loadReplies(r, quiet: true);
        if (gen != _gen) return;
        if (threadOf(r.id).items.any((c) => c.id == id)) {
          threadOf(r.id).expanded = true;
          highlightId = id;
          _notify();
          return;
        }
      }
      if (_cursor == null || ++pages >= 4) return;
      final p = await api.list(postId, sort: sort, cursor: _cursor, size: pageSize).catchError((_) => const CommentPageData([], null));
      if (gen != _gen) return;
      final have = {for (final c in roots) c.id};
      roots.addAll(p.items.where((c) => have.add(c.id)));
      _cursor = p.nextCursor;
      _notify();
      if (p.items.isEmpty) return;
    }
  }

  void clearHighlight() {
    if (highlightId == null) return;
    highlightId = null;
    _notify();
  }

  // ---- Yazma ----

  void setReplyTo(PostComment? c) {
    replyTo = c;
    _notify();
  }

  /// Yeni yorum / yanıt. Tek uçuşlu: bir gönderim sürerken ikincisi başlamaz. İyimser eklenir.
  Future<bool> send(String raw) async {
    final body = raw.trim();
    if (body.isEmpty || body.length > kCommentMaxLength || sending) return false;
    final target = replyTo;
    final rootId = target == null ? null : (target.parentId ?? target.id);
    final pending = PostComment(
      id: -(++_tmp),
      postId: postId,
      parentId: rootId,
      author: me,
      body: body,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      mine: true,
      canDelete: true,
      sendState: CommentSendState.sending,
      pendingKey: newCommentKey(),
    );
    replyTo = null;
    _insertPending(pending);
    await _deliver(pending, target);
    return true;
  }

  void _insertPending(PostComment p) {
    final rootId = p.parentId;
    if (rootId == null) {
      roots.insert(0, p);
    } else {
      final t = threadOf(rootId);
      t.expanded = true;
      t.items.add(p);
      _bumpReplies(rootId, 1);
      // Yanıtlar henüz yüklenmediyse arkada yüklenir; yerel yanıt sonda korunur.
      if (!t.loaded) {
        final root = roots.where((c) => c.id == rootId);
        if (root.isNotEmpty && root.first.replyCount > 1) loadReplies(root.first, quiet: true);
      }
    }
    _setCount(_count + 1);
    _notify();
  }

  void _bumpReplies(int rootId, int d) {
    final i = roots.indexWhere((c) => c.id == rootId);
    if (i >= 0) roots[i] = roots[i].copyWith(replyCount: (roots[i].replyCount + d).clamp(0, 1 << 30));
  }

  Future<void> _deliver(PostComment pending, PostComment? target) async {
    sending = true;
    _notify();
    try {
      final real = await api.add(postId, pending.body!, parentId: pending.parentId, idempotencyKey: pending.pendingKey!);
      _replaceLocal(pending, real);
    } catch (e) {
      final permanent = e is ApiError && e.status >= 400 && e.status < 500 && e.status != 408 && e.status != 429;
      if (permanent) {
        _removeLocal(pending);
        onRestore?.call(pending.body!, target);
      } else {
        _replaceLocal(pending, pending.copyWith(sendState: CommentSendState.failed), keepId: true);
      }
      onError?.call(e);
    }
    sending = false;
    _notify();
  }

  void _replaceLocal(PostComment old, PostComment next, {bool keepId = false}) {
    final target = keepId ? next : next;
    final rootId = old.parentId;
    final list = rootId == null ? roots : threadOf(rootId).items;
    final i = list.indexWhere((c) => c.id == old.id);
    if (i < 0) return;
    // Gelen gerçek kayıt zaten listede (örn. yanıtlar yeniden yüklendi) ise yerel kopya düşer.
    if (!keepId && list.any((c) => c.id == target.id)) {
      list.removeAt(i);
    } else {
      list[i] = target;
    }
  }

  void _removeLocal(PostComment p) {
    final rootId = p.parentId;
    if (rootId == null) {
      roots.removeWhere((c) => c.id == p.id);
    } else {
      threadOf(rootId).items.removeWhere((c) => c.id == p.id);
      _bumpReplies(rootId, -1);
    }
    _setCount(_count - 1);
  }

  /// "Gönderilemedi · Yeniden dene": aynı Idempotency-Key ile tekrar.
  Future<void> retry(PostComment failed) async {
    if (sending || failed.sendState != CommentSendState.failed) return;
    final sendingNow = failed.copyWith(sendState: CommentSendState.sending);
    _replaceLocal(failed, sendingNow, keepId: true);
    _notify();
    await _deliver(sendingNow, null);
  }

  // ---- Beğeni ----

  final Map<int, bool> _likeInFlight = {};
  final Map<int, bool> _likeWant = {};

  PostComment? _find(int id) {
    for (final c in roots) {
      if (c.id == id) return c;
    }
    for (final t in threads.values) {
      for (final c in t.items) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  void _update(int id, PostComment Function(PostComment) f) {
    for (var i = 0; i < roots.length; i++) {
      if (roots[i].id == id) {
        roots[i] = f(roots[i]);
        return;
      }
    }
    for (final t in threads.values) {
      for (var i = 0; i < t.items.length; i++) {
        if (t.items[i].id == id) {
          t.items[i] = f(t.items[i]);
          return;
        }
      }
    }
  }

  /// İyimser beğeni; art arda dokunuşlar birleşir, hata olursa sunucunun son onayladığı duruma dönülür.
  Future<void> toggleLike(PostComment c) async {
    if (c.isLocal || c.deleted) return;
    final cur = _find(c.id);
    if (cur == null) return;
    final want = !cur.likedByMe;
    _update(c.id, (x) => x.copyWith(likedByMe: want, likeCount: (x.likeCount + (want ? 1 : -1)).clamp(0, 1 << 30)));
    _notify();
    _likeWant[c.id] = want;
    if (_likeInFlight[c.id] == true) return;
    _likeInFlight[c.id] = true;
    var confirmed = cur.likedByMe;
    final confirmedCount = cur.likeCount;
    try {
      while (_likeWant[c.id] != confirmed) {
        final w = _likeWant[c.id]!;
        await api.setLiked(c.id, w);
        confirmed = w;
      }
    } catch (e) {
      _update(c.id, (x) => x.copyWith(likedByMe: confirmed, likeCount: confirmed == cur.likedByMe ? confirmedCount : (confirmed ? confirmedCount + 1 : (confirmedCount - 1).clamp(0, 1 << 30))));
      onError?.call(e);
    }
    _likeInFlight.remove(c.id);
    _likeWant.remove(c.id);
    _notify();
  }

  // ---- Silme ----

  Future<void> delete(PostComment c) async {
    if (c.isLocal) {
      _removeLocal(c);
      _notify();
      return;
    }
    try {
      await api.delete(c.id);
    } catch (e) {
      onError?.call(e);
      return;
    }
    final rootId = c.parentId;
    if (rootId == null) {
      final i = roots.indexWhere((x) => x.id == c.id);
      if (i >= 0) {
        // Yanıtı olan yorum yer tutucuya dönüşür ("Bu yorum silindi"); yanıtlar kalır.
        if (roots[i].replyCount > 0) {
          roots[i] = roots[i].copyWith(deleted: true, clearContent: true);
        } else {
          roots.removeAt(i);
        }
      }
    } else {
      threadOf(rootId).items.removeWhere((x) => x.id == c.id);
      _bumpReplies(rootId, -1);
      final i = roots.indexWhere((x) => x.id == rootId);
      if (i >= 0 && roots[i].deleted && roots[i].replyCount <= 0) roots.removeAt(i);
    }
    _setCount(_count - 1);
    _notify();
  }
}
