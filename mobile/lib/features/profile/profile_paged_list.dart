import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';

import '../../core/session.dart';
import '../../widgets/bu.dart';

/// Profil alt sayfaları için ortak imleçli liste iskeleti (başlık + yenile + sonsuz kaydırma).
class ProfilePagedList extends StatefulWidget {
  const ProfilePagedList({
    super.key,
    required this.session,
    required this.title,
    required this.path,
    required this.emptyIcon,
    required this.emptyText,
    required this.itemBuilder,
    this.header,
  });

  final Session session;
  final String title;
  final String path;
  final IconData emptyIcon;
  final String emptyText;
  final Widget Function(BuildContext context, Map<String, dynamic> item) itemBuilder;

  /// Başlığın altında sabit duran isteğe bağlı alan (örn. filtre çipleri).
  final Widget? header;

  @override
  State<ProfilePagedList> createState() => _ProfilePagedListState();
}

class _ProfilePagedListState extends State<ProfilePagedList> {
  final _items = <Map<String, dynamic>>[];
  int? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProfilePagedList old) {
    super.didUpdateWidget(old);
    // Yol değişirse (filtre) liste baştan yüklenir.
    if (old.path != widget.path) _reload();
  }

  int _gen = 0; // eski yanıtların yeni filtreye karışmasını engeller

  Future<void> _reload() async {
    _gen++;
    setState(() {
      _items.clear();
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
    final gen = _gen;
    try {
      final sep = widget.path.contains('?') ? '&' : '?';
      final c = _cursor == null ? '' : '&cursor=$_cursor';
      final r = await widget.session.api.get('${widget.path}${sep}size=20$c') as Map<String, dynamic>;
      if (gen != _gen) return;
      for (final e in (r['items'] as List? ?? const [])) {
        if (e is Map<String, dynamic>) _items.add(e);
      }
      _cursor = (r['nextCursor'] as num?)?.toInt();
      _hasMore = _cursor != null;
    } catch (e) {
      if (gen != _gen) return;
      _error = e;
      _hasMore = false;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    // İlk sayfa ekranı doldurmuyorsa kaydırma olayı gelmez: sonraki sayfayı kendimiz iste.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hasMore && _scroll.hasClients && _scroll.position.maxScrollExtent < 300) _loadMore();
    });
  }


  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final List<Widget> body;
    if (_items.isEmpty) {
      body = [
        SliverToBoxAdapter(
          child: _loading
              ? const BuSkeletonList(shrinkWrap: true, itemCount: 6)
              : SizedBox(
                  height: 360,
                  child: _error != null
                      ? BuErrorState(error: _error, onRetry: _reload)
                      : BuEmptyState(icon: widget.emptyIcon, title: widget.emptyText),
                ),
        ),
      ];
    } else {
      body = [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverList.separated(
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => BuStaggerItem(index: i, child: widget.itemBuilder(context, _items[i])),
          ),
        ),
        if (_error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
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
            ),
          )
        else if (_hasMore)
          const SliverToBoxAdapter(child: BuSkeletonList(shrinkWrap: true, itemCount: 1)),
      ];
    }
    return BuStaggerScope(
      child: BuPageScaffold(
        title: widget.title,
        controller: _scroll,
        onRefresh: _reload,
        bottomInset: MediaQuery.paddingOf(context).bottom + 28,
        slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header!),
          ...body,
        ],
      ),
    );
  }
}
