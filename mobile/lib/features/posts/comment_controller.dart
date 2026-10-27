import 'package:flutter/foundation.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import 'comment_models.dart';

/// Bir gönderinin yorum ağacının durumu: kök sayfalama, sıralama, kademeli yanıt yükleme,
/// iyimser ekleme/silme/düzenleme. Widget'lardan bağımsızdır (test edilebilir).
class CommentsController extends ChangeNotifier {
  CommentsController(this.session, this.postId, {this.onCountDelta}) : api = CommentApi(session);

  final Session session;
  final int postId;
  final CommentApi api;

  /// Gönderinin `commentCount` değeri değişti (+1 / -1).
  final void Function(int delta)? onCountDelta;

  String sort = 'new';
  final List<CNode> roots = [];
  String? next;
  int total = 0;
  bool loading = true;
  Object? error;
  bool loadingMore = false;
  Object? moreError;

  int _gen = 0;
  int _tempSeq = 0;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  CNode _build(Comment c, CNode? parent) {
    final n = CNode(c, parent: parent);
    for (final p in c.previews) {
      n.children.add(_build(p, n));
    }
    c.previews = const [];
    return n;
  }

  /// İlk yükleme / sıralama değişimi / yenileme.
  Future<void> load({bool refresh = false}) async {
    final gen = ++_gen;
    if (!refresh) {
      loading = true;
      roots.clear();
      next = null;
    }
    error = null;
    moreError = null;
    loadingMore = false;
    notifyListeners();
    try {
      final page = await api.roots(postId, sort: sort);
      if (gen != _gen) return;
      roots
        ..clear()
        ..addAll(page.items.map((c) => _build(c, null)));
      next = page.nextCursor;
      total = page.total ?? roots.length;
      loading = false;
    } catch (e) {
      if (gen != _gen) return;
      error = e;
      loading = false;
    }
    notifyListeners();
  }

  Future<void> setSort(String s) {
    if (s == sort) return Future.value();
    sort = s;
    return load();
  }

  bool get canLoadMore => next != null && !loading && !loadingMore && moreError == null && error == null;

  Future<void> loadMore() async {
    if (next == null || loading || loadingMore) return;
    final gen = _gen;
    loadingMore = true;
    moreError = null;
    notifyListeners();
    try {
      final page = await api.roots(postId, sort: sort, cursor: next);
      if (gen != _gen) return;
      final have = {for (final r in roots) r.c.id};
      for (final c in page.items) {
        if (have.add(c.id)) roots.add(_build(c, null));
      }
      next = page.nextCursor;
      if (page.total != null) total = page.total!;
    } catch (e) {
      if (gen != _gen) return;
      moreError = e;
    }
    loadingMore = false;
    notifyListeners();
  }

  Future<void> retryMore() {
    moreError = null;
    return loadMore();
  }

  // ---- Yanıtlar ----

  /// "N yanıtı göster" / "Daha fazla yanıt göster".
  Future<void> expand(CNode n) async {
    if (n.loading) return;
    if (n.collapsed) {
      n.collapsed = false;
      notifyListeners();
      if (n.children.isNotEmpty) return;
    }
    if (n.children.isNotEmpty && !n.hasMore) return;
    if (!n.hasMore && n.fetched) return;
    n.loading = true;
    n.error = null;
    notifyListeners();
    final first = !n.fetched;
    try {
      final page = await api.replies(n.c.id, cursor: first ? null : n.next);
      final local = n.children.where((c) => c.c.isTemp).toList();
      final existing = {for (final c in n.children.where((c) => !c.c.isTemp)) c.c.id: c};
      final fresh = <CNode>[];
      for (final c in page.items) {
        final old = existing.remove(c.id);
        if (old != null) {
          old.c = c;
          fresh.add(old);
        } else {
          fresh.add(_build(c, n));
        }
      }
      if (first) {
        n.children
          ..clear()
          ..addAll(fresh)
          ..addAll(local);
      } else {
        final keep = n.children.where((c) => !c.c.isTemp).toList();
        final ids = {for (final k in keep) k.c.id};
        n.children
          ..clear()
          ..addAll(keep)
          ..addAll(fresh.where((f) => !ids.contains(f.c.id)))
          ..addAll(local);
      }
      n.fetched = true;
      n.next = page.nextCursor;
    } catch (e) {
      n.error = e;
    }
    n.loading = false;
    notifyListeners();
  }

  void collapse(CNode n) {
    n.collapsed = true;
    notifyListeners();
  }

  // ---- Ekleme ----

  CNode _attachPoint(CNode replyTo) => replyTo.c.depth >= 3 && replyTo.parent != null ? replyTo.parent! : replyTo;

  /// Yorum / yanıt gönderir (iyimser). [replyTo] null ise kök yorum.
  Future<SendOutcome> send(String text, {CNode? replyTo}) async {
    final me = session.userId ?? 0;
    final author = CommentUser(id: me, displayName: session.displayName ?? '');
    final attach = replyTo == null ? null : _attachPoint(replyTo);
    final temp = Comment(
      id: -(++_tempSeq),
      postId: postId,
      depth: replyTo == null ? 0 : (attach == replyTo ? replyTo.c.depth + 1 : replyTo.c.depth),
      author: author,
      parentId: attach?.c.id,
      rootId: attach?.c.rootId ?? attach?.c.id,
      replyToUser: replyTo?.c.author,
      text: text,
      mine: true,
      canEdit: true,
      canDelete: true,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final node = CNode(temp, parent: attach)
      ..pending = true
      ..sendParentId = replyTo?.c.id;
    _insert(node, attach);
    notifyListeners();
    return _post(node, text);
  }

  void _insert(CNode node, CNode? attach) {
    if (attach == null) {
      roots.insert(0, node);
      total++;
    } else {
      attach.children.add(node);
      attach.collapsed = false;
      attach.c.replyCount++;
    }
    onCountDelta?.call(1);
  }

  void _removeNode(CNode node, {bool counted = true}) {
    final p = node.parent;
    if (p == null) {
      if (roots.remove(node)) total--;
    } else {
      p.children.remove(node);
      if (p.c.replyCount > 0) p.c.replyCount--;
    }
    if (counted) onCountDelta?.call(-1);
  }

  Future<SendOutcome> _post(CNode node, String text) async {
    try {
      final res = await api.create(postId, text, parentId: node.sendParentId);
      if (res is Map<String, dynamic> && res['id'] is num) {
        final c = Comment.fromJson(res);
        c.previews = const [];
        node.c = c;
      }
      // Yanıt gövdesi yoksa iyimser kayıt olduğu gibi kalır.
      node.pending = false;
      node.failed = false;
      node.sendError = null;
      notifyListeners();
      return const SendOutcome();
    } catch (e) {
      final msg = errorText(e);
      final validation = e is ApiError && e.status >= 400 && e.status < 500 && e.status != 401;
      if (validation) {
        _removeNode(node);
        notifyListeners();
        return SendOutcome(error: msg, removed: true);
      }
      node.pending = false;
      node.failed = true;
      node.sendError = msg;
      onCountDelta?.call(-1); // başarısız yorum sayıya girmez; yeniden denenince geri eklenir
      notifyListeners();
      return SendOutcome(error: msg);
    }
  }

  /// "Gönderilemedi · Yeniden dene".
  Future<SendOutcome> retry(CNode node) async {
    if (!node.failed) return const SendOutcome();
    node.failed = false;
    node.pending = true;
    node.sendError = null;
    onCountDelta?.call(1);
    notifyListeners();
    return _post(node, node.c.text ?? '');
  }

  /// Başarısız geçici yorumu kaldırır (sayı zaten geri alınmıştı).
  void discard(CNode node) {
    _removeNode(node, counted: false);
    notifyListeners();
  }

  // ---- Düzenleme / silme ----

  Future<void> edit(CNode n, String text) async {
    final res = await api.edit(n.c.id, text);
    if (res is Map<String, dynamic> && res['id'] is num) {
      final c = Comment.fromJson(res);
      n.c
        ..text = c.text ?? text
        ..editedAt = c.editedAt ?? DateTime.now().toUtc().toIso8601String();
    } else {
      n.c
        ..text = text
        ..editedAt = DateTime.now().toUtc().toIso8601String();
    }
    notifyListeners();
  }

  Future<void> remove(CNode n) async {
    await api.remove(n.c.id);
    if (n.c.replyCount > 0 || n.children.isNotEmpty) {
      n.c
        ..deleted = true
        ..text = null
        ..canEdit = false
        ..canDelete = false;
      onCountDelta?.call(-1);
    } else {
      _removeNode(n);
    }
    notifyListeners();
  }

  // ---- Arama ----

  CNode? find(int id) {
    CNode? walk(List<CNode> l) {
      for (final n in l) {
        if (n.c.id == id) return n;
        final r = walk(n.children);
        if (r != null) return r;
      }
      return null;
    }

    return walk(roots);
  }

  /// Hedef yorumu bulmak için sayfa sayfa (ve yanıtları açarak) arar; sınırlıdır. Bulunursa
  /// bulunduğu dalları açar.
  Future<CNode?> reveal(int id) async {
    var requests = 0;
    var scanned = 0; // replies araması yapılan kök sayısı
    while (true) {
      var hit = find(id);
      if (hit != null) {
        for (var p = hit.parent; p != null; p = p.parent) {
          p.collapsed = false;
        }
        notifyListeners();
        return hit;
      }
      for (; scanned < roots.length && requests < 25; scanned++) {
        final r = roots[scanned];
        if (r.hasMore && r.c.replyCount > 0) {
          requests++;
          await _expandAll(r, id);
          if (_disposed) return null;
          hit = find(id);
          if (hit != null) break;
        }
      }
      if (hit != null) continue;
      if (next == null || requests >= 25) return null;
      requests++;
      await loadMore();
      if (_disposed || moreError != null) return null;
    }
  }

  Future<void> _expandAll(CNode n, int id) async {
    var guard = 0;
    await expand(n);
    while (n.fetched && n.next != null && find(id) == null && guard++ < 5) {
      await expand(n);
    }
  }
}
