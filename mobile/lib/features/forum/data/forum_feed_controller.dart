import 'package:flutter/foundation.dart';

import '../../../core/api.dart';
import 'forum_api.dart';
import 'forum_models.dart';

/// Forum ana akışı durumu (konu listesi + kategori süzgeci + sıralama + imleçli sayfalama).
///
/// Yarış koruması: sıralama/kategori hızlıca değişince eski isteğin yanıtı yok sayılır ([_gen]).
/// Yazma sonrası liste yerinde güncellenir ([replace]/[remove]/[insertFirst]); ağdan yeniden çekilmez.
class ForumFeedController extends ChangeNotifier {
  ForumFeedController(this.api, {this.pageSize = 15, ForumSort sort = ForumSort.forYou, int? categoryId})
      : _sort = sort,
        _categoryId = categoryId;

  final ForumApi api;
  final int pageSize;

  ForumSort _sort;
  int? _categoryId;
  int _gen = 0;
  bool _disposed = false;

  List<TopicSummary> _items = const [];
  String? _cursor;

  /// İlk yükleme sürüyor (iskelet gösterilir).
  bool loading = true;

  /// Çekerek yenileme ya da kategori/sıralama değişimi sürerken eski liste ekranda kalır.
  bool refreshing = false;
  bool loadingMore = false;

  /// Sonraki sayfa yüklenemedi (listenin altında "Tekrar dene" satırı).
  bool moreFailed = false;

  /// İlk yükleme başarısız ve gösterilecek veri yok.
  Object? error;

  /// Sunucudan veri geldi mi (boş forum ile yüklenemedi ayrımı).
  bool loaded = false;

  /// Yeni eklenen konu (giriş animasyonu için bir kez okunur).
  int? justAddedId;

  ForumSort get sort => _sort;
  int? get categoryId => _categoryId;
  List<TopicSummary> get items => _items;
  bool get hasMore => _cursor != null && _cursor!.isNotEmpty;
  bool get isEmpty => loaded && _items.isEmpty;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// İlk sayfayı çeker. [reset] true (kategori/sıralama değişimi): liste temizlenip iskelet gösterilir.
  Future<void> load({bool reset = false}) async {
    final g = ++_gen;
    if (reset || !loaded) {
      loading = true;
      refreshing = false;
      if (reset) {
        _items = const [];
        _cursor = null;
        loaded = false;
      }
    } else {
      refreshing = true;
    }
    error = null;
    moreFailed = false;
    loadingMore = false;
    justAddedId = null;
    notifyListeners();
    try {
      final page = await api.topics(sort: _sort, categoryId: _categoryId, size: pageSize, force: true);
      if (g != _gen) return;
      _items = _dedup(page.items);
      _cursor = page.nextCursor;
      loaded = true;
      error = null;
    } catch (e) {
      if (g != _gen) return;
      // Eski liste varsa ekranda kalır (hata yalnız iskelet aşamasında tam ekran olur).
      if (!loaded) error = e;
      lastRefreshError = loaded ? e : null;
    } finally {
      if (g == _gen) {
        loading = false;
        refreshing = false;
        notifyListeners();
      }
    }
  }

  /// Çekerek yenileme başarısız olduysa son hata (liste ekranda kalır; sayfa kısa bir uyarı gösterir).
  Object? lastRefreshError;

  Future<void> setSort(ForumSort s) {
    if (s == _sort) return Future.value();
    _sort = s;
    return load(reset: true);
  }

  Future<void> setCategory(int? id) {
    if (id == _categoryId) return Future.value();
    _categoryId = id;
    return load(reset: true);
  }

  /// Sonraki sayfa (liste sonuna yaklaşınca çağrılır). Eşzamanlı çift çağrıyı yok sayar.
  Future<void> loadMore() async {
    if (loading || refreshing || loadingMore || !hasMore) return;
    final g = _gen;
    loadingMore = true;
    moreFailed = false;
    notifyListeners();
    try {
      final page = await api.topics(sort: _sort, categoryId: _categoryId, cursor: _cursor, size: pageSize);
      if (g != _gen) return;
      _items = _dedup([..._items, ...page.items]);
      _cursor = page.nextCursor;
    } catch (e) {
      if (g != _gen) return;
      moreFailed = true;
      if (e is ApiError && e.isAuthRejected) error = e;
    } finally {
      if (g == _gen) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  List<TopicSummary> _dedup(List<TopicSummary> l) {
    final seen = <int>{};
    return [
      for (final t in l)
        if (seen.add(t.id)) t,
    ];
  }

  /// Aynı kimlikli konuyu günceller (beğeni/kaydet/yorum sayısı); listede yoksa yok sayar.
  void replace(TopicSummary t) {
    final i = _items.indexWhere((e) => e.id == t.id);
    if (i < 0) return;
    _items = [..._items]..[i] = t;
    notifyListeners();
  }

  void remove(int id) {
    if (!_items.any((e) => e.id == id)) return;
    _items = [for (final e in _items) if (e.id != id) e];
    notifyListeners();
  }

  /// Yazarı sessize alınan/engellenen kullanıcının (kimliği bilinen) bütün konularını listeden düşürür.
  void removeByAuthor(int userId) {
    _items = [for (final e in _items) if (e.author.userId != userId) e];
    notifyListeners();
  }

  /// Yeni konuyu listenin başına ekler (sabitlenmişlerin ardına); [justAddedId] animasyonu tetikler.
  void insertFirst(TopicSummary t) {
    if (_items.any((e) => e.id == t.id)) {
      replace(t);
      return;
    }
    final firstUnpinned = _items.indexWhere((e) => !e.pinned);
    final at = firstUnpinned < 0 ? _items.length : firstUnpinned;
    _items = [..._items]..insert(at, t);
    justAddedId = t.id;
    loaded = true;
    notifyListeners();
  }
}
