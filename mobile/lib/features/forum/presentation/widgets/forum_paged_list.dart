import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_models.dart';

/// Liste öğesi güncellemek için [ForumPagedList] tutamacı (iyimser kaldırma, yerinde değiştirme).
abstract interface class ForumListHandle<T> {
  List<T> get items;

  /// [test]'e uyan ilk öğeyi [next] ile değiştirir.
  void replaceWhere(bool Function(T) test, T next);

  /// Öğeyi çıkarır; döndürülen işlev öğeyi eski yerine geri koyar (hata geri alması).
  VoidCallback removeWhere(bool Function(T) test);

  /// [test]'e uyan TÜM öğeleri çıkarır (yazar engeli/sessize alma).
  void removeAllWhere(bool Function(T) test);

  Future<void> reload();
}

typedef ForumFetch<T> = Future<ForumPage<T>> Function(String? cursor);

/// İmleçli, çekerek yenilenen forum listesi (ilk yükleme iskeleti, hata, boş durum, sonsuz kaydırma, alt hata satırı).
/// Eşzamanlı yüklemeler tek uçuştur (çift dokunma/hızlı kaydırma çift istek üretmez); eski yanıt yeni yenilemeyi ezmez.
class ForumPagedList<T> extends StatefulWidget {
  const ForumPagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    required this.empty,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 32),
    this.header,
  });

  final ForumFetch<T> fetch;
  final Widget Function(BuildContext context, T item, ForumListHandle<T> list) itemBuilder;

  /// Liste boşken gösterilen görünüm (genelde [BuEmptyState]).
  final Widget Function(BuildContext context) empty;
  final EdgeInsetsGeometry padding;

  /// Listenin üstünde (kaydırma ile birlikte) çizilen parça.
  final Widget? header;

  @override
  State<ForumPagedList<T>> createState() => ForumPagedListState<T>();
}

class ForumPagedListState<T> extends State<ForumPagedList<T>> implements ForumListHandle<T> {
  final _scroll = ScrollController();
  final List<T> _items = [];
  String? _cursor;
  bool _loading = true;
  bool _more = false;
  Object? _error; // ilk yükleme hatası
  Object? _moreError; // sonraki sayfa hatası
  int _gen = 0;

  @override
  List<T> get items => List.unmodifiable(_items);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _cursor == null || _more || _loading || _moreError != null) return;
    if (_scroll.position.extentAfter < 400) unawaited(_loadMore());
  }

  /// Liste ekranı doldurmuyorsa (kaydırma olayı gelmez) sonraki sayfayı kendiliğinden iste.
  void _maybeFill() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onScroll();
      });

  Future<void> _load({required bool reset}) async {
    final gen = ++_gen;
    if (reset && _items.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await widget.fetch(null);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.hasMore ? page.nextCursor : null;
        _loading = false;
        _error = null;
        _moreError = null;
        _more = false;
      });
      _maybeFill();
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        // Yenilemede var olan liste korunur; yalnız boşken hata ekranı.
        if (_items.isEmpty) _error = e;
      });
      if (_items.isNotEmpty) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _more) return;
    final gen = _gen;
    setState(() {
      _more = true;
      _moreError = null;
    });
    try {
      final page = await widget.fetch(cursor);
      if (!mounted || gen != _gen) return;
      setState(() {
        // Sunucu sayfalarında çakışma olursa aynı öğe iki kez çizilmesin (kimlik yoksa olduğu gibi eklenir).
        _items.addAll(page.items);
        _cursor = page.hasMore ? page.nextCursor : null;
        _more = false;
      });
      _maybeFill();
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _more = false;
        _moreError = e;
      });
    }
  }

  @override
  Future<void> reload() => _load(reset: false);

  @override
  void replaceWhere(bool Function(T) test, T next) {
    final i = _items.indexWhere(test);
    if (i < 0) return;
    setState(() => _items[i] = next);
  }

  @override
  void removeAllWhere(bool Function(T) test) {
    if (!_items.any(test)) return;
    setState(() => _items.removeWhere(test));
  }

  @override
  VoidCallback removeWhere(bool Function(T) test) {
    final i = _items.indexWhere(test);
    if (i < 0) return () {};
    final removed = _items[i];
    setState(() => _items.removeAt(i));
    return () {
      if (!mounted) return;
      setState(() => _items.insert(i.clamp(0, _items.length), removed));
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const BuSkeletonList(variant: BuSkeletonVariant.card, itemCount: 3);
    }
    if (_error != null) {
      return BuErrorState(error: _error, onRetry: () => _load(reset: true));
    }
    final t = context.bu;
    final empty = _items.isEmpty;
    return BuRefreshIndicator(
      onRefresh: () => _load(reset: false),
      child: empty
          ? CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (widget.header != null) SliverToBoxAdapter(child: widget.header),
                // BuEmptyState içinde LayoutBuilder var: SliverFillRemaining sığ ölçü ister, çakışır (BuPageScaffold ile aynı çözüm).
                SliverLayoutBuilder(
                  builder: (ctx, c) => SliverToBoxAdapter(
                    child: SizedBox(height: c.remainingPaintExtent < 360 ? 360 : c.remainingPaintExtent, child: widget.empty(ctx)),
                  ),
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: widget.padding,
              itemCount: _items.length + 1 + (widget.header != null ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (widget.header != null) {
                  if (i == 0) return widget.header!;
                  i -= 1;
                }
                if (i == _items.length) return _footer(ctx, t);
                return widget.itemBuilder(ctx, _items[i], this);
              },
            ),
    );
  }

  Widget _footer(BuildContext context, BuTokens t) {
    if (_moreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton.icon(
            onPressed: _loadMore,
            icon: Icon(BuIcons.refreshCw, size: 16, color: t.prText),
            label: Text(context.l10n.commonRetry, style: TextStyle(color: t.prText)),
          ),
        ),
      );
    }
    if (_more) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    return const SizedBox(height: 8);
  }
}
