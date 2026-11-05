import 'package:flutter/foundation.dart';

import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../posts/social_models.dart';

/// Öneri satırı: kişi + (API verirse) öneri nedeni ve sınıf.
@immutable
class SuggestedPerson {
  const SuggestedPerson(this.user, {this.reason, this.classYear});

  factory SuggestedPerson.fromJson(Map<String, dynamic> m) {
    final y = m['classYear'] ?? m['grade'];
    final n = y is num ? y.toInt() : int.tryParse('${y ?? ''}');
    final reason = m['reason'];
    return SuggestedPerson(
      SocialUser.fromJson(m),
      reason: reason is String && reason.trim().isNotEmpty ? reason.trim() : null,
      classYear: n != null && n > 0 && n <= 6 ? n : null,
    );
  }

  final SocialUser user;
  final String? reason;

  /// Sunucu `reason` değerini ham simge olarak (CLUB / GRADE / DEPARTMENT) gönderir: yerel metne çevrilir.
  /// Büyük harfli bilinmeyen simge (ham sunucu kodu) gösterilmez; okunur serbest metin olduğu gibi gösterilir.
  String? reasonLabel(AppLocalizations l) {
    final r = reason;
    if (r == null) return null;
    switch (r.toUpperCase()) {
      case 'CLUB':
        return l.followReasonClub;
      case 'GRADE':
        return l.followReasonGrade;
      case 'DEPARTMENT':
        return l.followReasonDepartment;
    }
    return RegExp(r'^[A-Z0-9_]+$').hasMatch(r) ? null : r;
  }
  final int? classYear;
}

/// `GET /users/me/follow-suggestions?page=N&size=M` sayfalayıcısı (Ana Sayfa şeridi + "Tümünü gör" sayfası ortak kullanır).
///
/// Sayfa numarası 0'dan başlar. Sunucu `page` parametresini henüz bilmiyorsa aynı listeyi tekrar döner: kimliğe göre
/// tekilleştirilir, yeni kayıt getirmeyen sayfa SON sayfa sayılır (sonsuz döngü olmaz). `size`'dan az gelen sayfa da sondur.
class SuggestionPager extends ChangeNotifier {
  SuggestionPager(this.session, {this.pageSize = 10, this.maxPages = 50});

  final Session session;
  final int pageSize;

  /// Üst sınır: bozuk bir sunucu yanıtı sınırsız istek üretmesin.
  final int maxPages;

  final List<SuggestedPerson> _items = [];
  final Set<int> _seen = {};
  int _page = 0;
  int _gen = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _loadedOnce = false;
  Object? _error;
  Object? _moreError;
  bool _disposed = false;

  List<SuggestedPerson> get items => List.unmodifiable(_items);

  /// İlk sayfa istekte.
  bool get loading => _loading;

  /// Sonraki sayfa istekte.
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;

  /// İlk sayfa en az bir kez başarıyla geldi.
  bool get loaded => _loadedOnce;

  /// İlk sayfa hatası (liste boşken gösterilir).
  Object? get error => _error;

  /// Sonraki sayfa hatası (liste dolu kalır, "Yeniden dene" gösterilir).
  Object? get moreError => _moreError;

  bool get isEmpty => _loadedOnce && _items.isEmpty;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Baştan yükler (ilk açılış, çek-yenile, "Yeniden dene"). Eski liste yeni yanıt gelene dek ekranda kalır.
  Future<void> reload() async {
    final gen = ++_gen;
    _loading = true;
    _loadingMore = false;
    _error = null;
    _moreError = null;
    _notify();
    try {
      final batch = await _fetch(0);
      if (_disposed || gen != _gen) return;
      _items.clear();
      _seen.clear();
      _page = 0;
      final added = _merge(batch);
      _hasMore = _canContinue(batch.length, added);
      _loadedOnce = true;
    } catch (e) {
      if (_disposed || gen != _gen) return;
      _error = e;
    } finally {
      if (!_disposed && gen == _gen) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Sıradaki sayfa. Zaten yükleniyorsa, son sayfaysa ya da ilk yükleme bitmediyse hiçbir şey yapmaz.
  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore || !_loadedOnce) return;
    final gen = _gen;
    _loadingMore = true;
    _moreError = null;
    _notify();
    final next = _page + 1;
    try {
      final batch = await _fetch(next);
      if (_disposed || gen != _gen) return;
      _page = next;
      final added = _merge(batch);
      _hasMore = _canContinue(batch.length, added);
    } catch (e) {
      if (_disposed || gen != _gen) return;
      _moreError = e;
    } finally {
      if (!_disposed && gen == _gen) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  bool _canContinue(int received, int added) => received >= pageSize && added > 0 && _page + 1 < maxPages;

  Future<List<SuggestedPerson>> _fetch(int page) async {
    final r = await session.api.get('/users/me/follow-suggestions?page=$page&size=$pageSize');
    return [for (final m in socialItems(r)) SuggestedPerson.fromJson(m)];
  }

  /// Tekrarlananları ve kendini eler; eklenen kayıt sayısını döner.
  int _merge(List<SuggestedPerson> batch) {
    var added = 0;
    for (final p in batch) {
      final id = p.user.id;
      if (id <= 0 || id == session.userId || !_seen.add(id)) continue;
      _items.add(p);
      added++;
    }
    return added;
  }
}
