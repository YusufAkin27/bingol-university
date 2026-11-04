import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/post_routes.dart';
import '../reels/reels_feed.dart';
import '../search/search_page.dart';
import 'discover_masonry.dart';
import 'discover_suggestions.dart';

/// Keşfet filtreleri (kapsül çipler): sıra ekrandaki sıradır.
enum DiscoverFilter {
  forYou('foryou'),
  popular('popular'),
  reels(null),
  latest('latest'),
  following('following');

  const DiscoverFilter(this.scope);

  /// `GET /api/feed?scope=` değeri (Reels ayrı uç: null).
  final String? scope;
}

/// Keşfet sekmesi: öğrenci gönderileri (fotoğraf ve video), iki sütun masonry akışı.
///
/// Başlık + arama/paylaş simgeleri, altında yatay kaydırılabilir kapsül filtreler: **Senin İçin | Popüler | Reels |
/// En Yeni | Takip Ettiklerim**. Her filtre KENDİ akışını ve kaydırma konumunu korur (ilk seçimde kurulur, sonra canlı
/// kalır; kabuk sekmeyi de canlı tuttuğundan profile gidip dönünce filtre + konum aynen durur). Öneriler masonry'nin ilk
/// 4 kutusundan sonra tam genişlik bant olarak araya girer. "Reels": dikey tam ekran video akışı.
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key, required this.session, required this.typeRequest, this.tabActive = true});

  final Session session;

  /// Sekme şu an görünür mü (kabuk IndexedStack'te gizli sekmeler canlı kalır; Reels gizliyken oynamamalı).
  final bool tabActive;

  /// Ana sayfadaki "Tümü" bağlantıları buraya haber türü yazar. Keşfet artık haber göstermediğinden istek
  /// yalnızca tüketilir (null'lanır); haber akışı için ayrı bir giriş gerekir (bkz. rapor).
  final ValueNotifier<String?> typeRequest;

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  /// Filtre başına denetleyici (oluşturma sonrası gönderi ekleme).
  final Map<DiscoverFilter, DiscoverFeedController> _controllers = {
    for (final f in DiscoverFilter.values)
      if (f != DiscoverFilter.reels) f: DiscoverFeedController(),
  };

  DiscoverFilter _filter = DiscoverFilter.forYou;

  /// Bir kez seçilmiş (kurulmuş) filtreler: kurulmamış filtre ağ isteği/ağaç maliyeti taşımaz.
  final Set<DiscoverFilter> _built = {DiscoverFilter.forYou};

  /// Öneri yok/yüklenemedi: bant hiç kurulmaz, masonry kesintisiz tek ızgara olur.
  bool _noSuggestions = false;

  @override
  void initState() {
    super.initState();
    widget.typeRequest.addListener(_consume);
    _consume();
  }

  @override
  void didUpdateWidget(DiscoverTab old) {
    super.didUpdateWidget(old);
    if (old.typeRequest != widget.typeRequest) {
      old.typeRequest.removeListener(_consume);
      widget.typeRequest.addListener(_consume);
    }
  }

  @override
  void dispose() {
    widget.typeRequest.removeListener(_consume);
    super.dispose();
  }

  void _consume() {
    if (widget.typeRequest.value != null) widget.typeRequest.value = null;
  }

  void _openSearch() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SearchPage(session: widget.session)),
      );

  Future<void> _compose() async {
    final p = await openComposePost(context, widget.session);
    if (p == null || !mounted) return;
    // Yeni gönderi kurulmuş (ve kronolojik/kişisel) akışların başına eklenir.
    for (final f in [DiscoverFilter.forYou, DiscoverFilter.latest, DiscoverFilter.popular]) {
      if (_built.contains(f)) _controllers[f]!.insertPost(p);
    }
  }

  void _select(DiscoverFilter f) {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _built.add(f);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final reels = _filter == DiscoverFilter.reels;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(children: [
        for (final f in DiscoverFilter.values)
          if (_built.contains(f))
            _Pane(
              key: ValueKey('discover-pane-${f.name}'),
              visible: f == _filter,
              child: f == DiscoverFilter.reels
                  ? ReelsFeed(
                      session: widget.session,
                      active: reels && widget.tabActive,
                      onCompose: _compose,
                      topInset: MediaQuery.paddingOf(context).top + 112,
                      onOpenPosts: () => _select(DiscoverFilter.forYou),
                    )
                  : DiscoverMasonryFeed(
                      session: widget.session,
                      controller: _controllers[f],
                      scope: f.scope!,
                      pinnedHeader: _headerDelegate(context),
                      onCompose: _compose,
                      emptyTitle: f == DiscoverFilter.following ? context.l10n.kesFollowingEmptyTitle : null,
                      emptyBody: f == DiscoverFilter.following ? context.l10n.kesFollowingEmptyBody : null,
                      inline: _noSuggestions || f == DiscoverFilter.latest
                          ? null
                          : DiscoverSuggestions(
                              session: widget.session,
                              onUnavailable: () {
                                if (mounted && !_noSuggestions) setState(() => _noSuggestions = true);
                              }),
                    ),
            ),
        if (reels) _reelsOverlay(context),
      ]),
    );
  }

  /// Kapsül filtre satırı (yatay kaydırılır; seçili çip görünür alana getirilir).
  Widget _filters() => _FilterBar(
        key: ValueKey('discover-filters-${_filter.name}'),
        selected: _filter,
        onSelect: _select,
      );

  /// Reels üstünde: koyu degrade üstünde başlık satırı + kapsüller.
  Widget _reelsOverlay(BuildContext context) {
    final t = context.bu;
    final top = MediaQuery.paddingOf(context).top;
    return PositionedDirectional(
      top: 0,
      start: 0,
      end: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.scrim.withValues(alpha: .6), t.scrim.withValues(alpha: 0)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: top + BuSpace.xs, bottom: BuSpace.md),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: BuSpace.pageH,
              child: Row(children: [
                Expanded(
                  child: Text(context.l10n.navDiscover,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: t.onMedia, fontWeight: FontWeight.w700)),
                ),
                BuIconButton(icon: BuIcons.plus, tooltip: context.l10n.discoverCompose, filled: true, size: 44, onTap: _compose),
              ]),
            ),
            _filters(),
          ]),
        ),
      ),
    );
  }

  /// Üst alan: "Keşfet" başlığı + yuvarlak arama + vurgulu "+" paylaş (kaydırınca kaybolur), altında kapsül filtreler
  /// (kaydırınca üstte SABİT kalır: filtre değiştirmek için başa dönmek gerekmez).
  SliverPersistentHeaderDelegate _headerDelegate(BuildContext context) => _DiscoverHeaderDelegate(
        top: MediaQuery.paddingOf(context).top,
        selected: _filter,
        filters: _filters(),
        onSearch: _openSearch,
        onCompose: _compose,
      );
}

/// Kapanan başlık + sabit kapsül satırı. Açıkken: durum çubuğu payı + 44 dp başlık satırı + 48 dp kapsüller; kaydırınca
/// başlık yukarı kayıp solar, kapsüller durum çubuğunun hemen altında kalır.
class _DiscoverHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DiscoverHeaderDelegate({
    required this.top,
    required this.selected,
    required this.filters,
    required this.onSearch,
    required this.onCompose,
  });

  final double top;
  final DiscoverFilter selected;
  final Widget filters;
  final VoidCallback onSearch;
  final VoidCallback onCompose;

  static const _titleH = 44.0;
  static const _chipsH = BuSize.touch;
  static const _gap = 4.0;

  @override
  double get minExtent => top + _chipsH + _gap;

  @override
  double get maxExtent => top + BuSpace.sm + _titleH + _chipsH + _gap;

  @override
  bool shouldRebuild(_DiscoverHeaderDelegate old) => old.top != top || old.selected != selected;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final range = maxExtent - minExtent;
    final collapse = range <= 0 ? 0.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: overlapsContent ? Border(bottom: BorderSide(color: t.bd)) : null,
      ),
      child: ClipRect(
        child: Stack(children: [
          PositionedDirectional(
            start: 0,
            end: 0,
            top: top + BuSpace.sm - shrinkOffset,
            height: _titleH,
            child: IgnorePointer(
              ignoring: collapse > .5,
              child: Opacity(
                opacity: 1 - collapse,
                child: Padding(
                  // Sekme başlıklarıyla aynı 20 dp kenar boşluğu ve 44 dp düğmeler.
                  padding: BuSpace.pageH,
                  child: Row(children: [
                    Expanded(
                      child: Text(l.navDiscover,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.headlineMedium?.copyWith(color: t.ink, fontSize: 28, fontWeight: FontWeight.w700)),
                    ),
                    BuIconButton(
                      key: const ValueKey('discoverSearch'),
                      icon: BuIcons.search,
                      tooltip: l.discoverSearch,
                      size: 44,
                      onTap: onSearch,
                    ),
                    BuGap.w8,
                    BuIconButton(icon: BuIcons.plus, tooltip: l.discoverCompose, filled: true, size: 44, onTap: onCompose),
                  ]),
                ),
              ),
            ),
          ),
          PositionedDirectional(start: 0, end: 0, bottom: _gap, height: _chipsH, child: filters),
        ]),
      ),
    );
  }
}

/// Bir filtrenin paneli: seçili değilken ekrandan kalkar ama durumu (kaydırma, liste) korunur; seçilince kısa solarak belirir.
class _Pane extends StatelessWidget {
  const _Pane({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: visible ? BuMotion.of(context, BuMotion.medium) : Duration.zero,
            curve: BuMotion.standard,
            child: child,
          ),
        ),
      );
}

/// Yatay kaydırılabilir kapsül filtre satırı. Seçili kapsül net (`BuChip` seçili durumu); seçim değişince satır onu
/// görünür alana kaydırır.
class _FilterBar extends StatefulWidget {
  const _FilterBar({super.key, required this.selected, required this.onSelect});

  final DiscoverFilter selected;
  final ValueChanged<DiscoverFilter> onSelect;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  final _keys = {for (final f in DiscoverFilter.values) f: GlobalKey()};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  void _reveal({bool animate = true}) {
    final c = _keys[widget.selected]?.currentContext;
    if (c == null || !mounted) return;
    // YALNIZ yatay satırı kaydırır (Scrollable.ensureVisible üstteki dikey akışı da oynatırdı: konum kaybolurdu).
    final ro = c.findRenderObject();
    final pos = Scrollable.maybeOf(c)?.position;
    if (ro == null || pos == null) return;
    pos.ensureVisible(ro,
        alignment: .5, duration: animate ? BuMotion.of(context, BuMotion.medium) : Duration.zero, curve: BuMotion.standard);
  }

  String _label(BuildContext context, DiscoverFilter f) {
    final l = context.l10n;
    return switch (f) {
      DiscoverFilter.forYou => l.kesFilterForYou,
      DiscoverFilter.popular => l.kesFilterPopular,
      DiscoverFilter.reels => l.kesSegReels,
      DiscoverFilter.latest => l.kesFilterLatest,
      DiscoverFilter.following => l.kesFilterFollowing,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.l10n.kesSegA11y,
      child: SizedBox(
        height: BuSize.touch,
        child: ListView.separated(
          key: const ValueKey('discoverFilters'),
          scrollDirection: Axis.horizontal,
          padding: BuSpace.pageH,
          itemCount: DiscoverFilter.values.length,
          separatorBuilder: (_, __) => BuGap.w8,
          itemBuilder: (_, i) {
            final f = DiscoverFilter.values[i];
            return KeyedSubtree(
              key: _keys[f],
              child: BuChip(
                key: ValueKey('discoverFilter-${f.name}'),
                label: _label(context, f),
                selected: f == widget.selected,
                onTap: () => widget.onSelect(f),
              ),
            );
          },
        ),
      ),
    );
  }
}
