import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../news/icerik_parts.dart';
import '../news/news_detail_page.dart';
import '../news/news_tile.dart';

/// Favoriye eklenen haberler (imleçli sayfalama).
class SavedNewsPage extends StatefulWidget {
  const SavedNewsPage({super.key, required this.session});

  final Session session;

  @override
  State<SavedNewsPage> createState() => _SavedNewsPageState();
}

class _SavedNewsPageState extends State<SavedNewsPage> {
  final _items = <Map<String, dynamic>>[];

  /// Kaldırma animasyonu oynayan haber kimlikleri (liste kısalmadan önce küçülüp solar).
  final _leaving = <int>{};
  final _scroll = ScrollController();
  int? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _leaving.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = _cursor == null ? '' : '&cursor=$_cursor';
      final r = await widget.session.api.get('/bookmarks?size=20$c') as Map<String, dynamic>;
      for (final b in (r['items'] as List)) {
        final news = (b as Map<String, dynamic>)['news'];
        if (news is Map<String, dynamic>) _items.add(news);
      }
      _cursor = (r['nextCursor'] as num?)?.toInt();
      _hasMore = _cursor != null;
    } catch (e) {
      _error = e;
      _hasMore = false; // otomatik tekrar döngüsünü kes; "Yeniden dene" düğmesi açar
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Önce satır küçülüp solar (250 ms), sonra listeden çıkar; istek hemen gider, hata olursa geri gelir.
  Future<void> _remove(Map<String, dynamic> n) async {
    final id = (n['id'] as num).toInt();
    if (!_leaving.add(id)) return;
    setState(() {});
    unawaited(Future<void>.delayed(BuMotion.of(context, BuMotion.medium), () {
      if (!mounted) return;
      setState(() {
        _items.remove(n);
        _leaving.remove(id);
      });
    }));
    try {
      await widget.session.api.delete('/bookmarks/news/$id');
      if (mounted) BuToast.show(context, context.l10n.p05UnsavedToast, kind: BuToastKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!_items.contains(n)) _items.insert(0, n);
        _leaving.remove(id);
      });
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  BuViewState get _view {
    if (_items.isEmpty) {
      if (_loading) return BuViewState.loading;
      if (_error != null) return BuViewState.error;
      return BuViewState.empty;
    }
    return BuViewState.ready;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    return BuPageScaffold(
      title: l.icerikFavorites,
      state: _view,
      error: _error,
      onRetry: _reload,
      onRefresh: _reload,
      controller: _scroll,
      bottomInset: MediaQuery.paddingOf(context).bottom + 24,
      loading: const IcerikListSkeleton(featured: false, count: 5),
      empty: BuEmptyState(
        illustration: BuIllustration.heart,
        title: l.p05SavedEmptyTitle,
        message: l.profileSavedEmpty,
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.pill)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.bookmarkCheck, size: 14, color: t.onSoft),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _hasMore ? l.profileNewsCountMore('${_items.length}') : l.icerikSavedCount('${_items.length}'),
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.onSoft),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: BuStaggerScope(
            child: SliverList.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final n = _items[i];
                final id = (n['id'] as num).toInt();
                return _Leaving(
                  key: ValueKey('saved-$id'),
                  leaving: _leaving.contains(id),
                  child: BuStaggerItem(
                    index: i,
                    child: NewsTile(
                      item: n,
                      saved: !_leaving.contains(id),
                      thumbSize: 76,
                      showSource: false,
                      onToggleSave: () => _remove(n),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NewsDetailPage(session: widget.session, item: n, saved: true),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(child: _footer()),
      ],
    );
  }

  Widget _footer() {
    final l = context.l10n;
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: BuButton(
            label: l.profileRetry,
            compact: true,
            kind: BuButtonKind.outline,
            onPressed: () {
              setState(() => _hasMore = true);
              _loadMore();
            },
          ),
        ),
      );
    }
    if (_hasMore) {
      // Liste ekranı doldurmuyorsa kaydırma olayı gelmez: sonraki sayfayı kendimiz iste.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
      return const IcerikListSkeleton(featured: false, count: 1, padding: EdgeInsets.fromLTRB(20, 12, 20, 0));
    }
    return const Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, 0), child: _SaveMoreHint());
  }
}

/// Satır kaldırılırken yüksekliği 0'a küçülür ve solar (yalnızca `Align.heightFactor` + saydamlık).
class _Leaving extends StatelessWidget {
  const _Leaving({super.key, required this.leaving, required this.child});

  final bool leaving;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = BuMotion.of(context, BuMotion.medium);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: leaving ? 0.0 : 1.0),
      duration: d,
      curve: BuMotion.emphasized,
      builder: (context, v, c) => v >= 1
          ? c!
          : ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: v.clamp(0.0, 1.0),
                child: Opacity(opacity: v.clamp(0.0, 1.0), child: c),
              ),
            ),
      child: child,
    );
  }
}

/// Listenin sonunda kesikli çerçeveli ipucu kartı (Ic4).
class _SaveMoreHint extends StatelessWidget {
  const _SaveMoreHint();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return CustomPaint(
      painter: _DashedBorder(color: t.bd, radius: 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: SizedBox(
          width: double.infinity,
          child: Column(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
              child: Icon(LucideIcons.bookmark, size: 20, color: t.pr),
            ),
            const SizedBox(height: 10),
            Text(l.icerikSavedMoreTitle,
                textAlign: TextAlign.center, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
            const SizedBox(height: 2),
            Text(l.icerikSavedMoreBody,
                textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(height: 1.4, color: t.mut)),
          ]),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(.75));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}
