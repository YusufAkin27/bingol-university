import '../../core/analytics.dart';
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final loading = _items.isEmpty && _loading;
    return Scaffold(
      backgroundColor: t.bg,
      body: BuSwapIn(
        loading: loading,
        skeleton: const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: Padding(padding: EdgeInsets.only(top: 140), child: IcerikListSkeleton(featured: false, count: 5)),
        ),
        child: BuRefreshIndicator(
          onRefresh: Analytics.pullRefresh(_reload),
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Geri (40 dp daire) + büyük başlık "Favori haberler" + soluk "3 kayıtlı haber".
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, MediaQuery.paddingOf(context).top + 24, 20, 0),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IcerikIconButton(
                        icon: buDirIcon(context, BuIcons.arrowLeft), label: l.commonBack, shadow: true, onTap: () => Navigator.maybePop(context)),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Semantics(
                    header: true,
                    child: BuFeatureTitle(title: l.icerikFavorites, icon: BuIcons.bookmark),
                  ),
                ),
              ),
              if (_items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Text(
                      _hasMore ? l.profileNewsCountMore('${_items.length}') : l.icerikSavedCount('${_items.length}'),
                      style: tx.bodyMedium!.copyWith(fontSize: 14, color: t.mut),
                    ),
                  ),
                ),
              if (_items.isEmpty && _error != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: IcerikErrorCard(title: l.p05ListErrorTitle, retryLabel: l.commonRetry, onRetry: _reload),
                  ),
                )
              else if (_items.isEmpty)
                // Boş: ortada soluk tek cümle + küçük ipucu (illüstrasyon/eylem yok).
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 64, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(children: [
                      Text(l.p05SavedEmptyTitle2, textAlign: TextAlign.center, style: tx.bodyLarge!.copyWith(fontSize: 16, color: t.mut)),
                      const SizedBox(height: 8),
                      Text(l.p05SavedEmptyBody2, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(fontSize: 14, color: t.mut)),
                    ]),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: BuStaggerScope(
                    child: SliverList.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const NewsRowDivider(),
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
                              onToggleSave: () => _remove(n),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(settings: const RouteSettings(name: 'news_detail'), 
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
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
            ],
          ),
        ),
      ),
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
      return IcerikLoadMore(text: l.p05NewsLoadingMore);
    }
    return const SizedBox(height: 4);
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
