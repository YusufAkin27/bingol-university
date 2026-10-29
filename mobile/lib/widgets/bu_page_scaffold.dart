import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/theme/bu_motion.dart';
import 'bu_pressable.dart';
import 'bu_skeleton.dart';
import 'bu_state.dart';

/// Sayfa veri durumu.
enum BuViewState {
  /// İlk yükleme: iskelet gösterilir (dönen çember değil).
  loading,

  /// İçerik hazır: [BuPageScaffold.slivers] gösterilir (yumuşak belirir).
  ready,

  /// İçerik yok: [BuPageScaffold.empty] gösterilir.
  empty,

  /// Hata: [BuErrorState] + yeniden dene.
  error,
}

/// Standart sayfa iskeleti: büyük, kaydırınca daralan başlık (M3 `SliverAppBar.large`) + çekerek yenile +
/// yükleniyor / boş / hata durum makinesi + üst şerit (çevrimdışı/bakım) yuvası.
///
/// ```dart
/// BuPageScaffold(
///   title: l10n.newsTitle,
///   state: _loading ? BuViewState.loading : _error != null ? BuViewState.error : _items.isEmpty ? BuViewState.empty : BuViewState.ready,
///   error: _error, onRetry: _load, onRefresh: _load,
///   empty: BuEmptyState(illustration: BuIllustration.document, title: l10n.newsEmpty),
///   banner: _stale ? const BuOfflineBanner() : null,
///   slivers: [SliverList.builder(itemCount: _items.length, itemBuilder: (c, i) => NewsTile(_items[i]))],
/// )
/// ```
/// Kaydırma gövdesi tek `CustomScrollView`'dır: liste öğeleri `SliverList.builder` ile tembel kurulur.
class BuPageScaffold extends StatelessWidget {
  const BuPageScaffold({
    super.key,
    required this.title,
    this.state = BuViewState.ready,
    this.slivers = const [],
    this.onRefresh,
    this.actions,
    this.leading,
    this.large = true,
    this.loading,
    this.empty,
    this.error,
    this.onRetry,
    this.banner,
    this.bottom,
    this.floatingActionButton,
    this.bottomBar,
    this.bottomInset = 24,
    this.controller,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final BuViewState state;

  /// [BuViewState.ready] gövdesi (sliver listesi).
  final List<Widget> slivers;

  /// Çekerek yenile; null ise kapalı.
  final Future<void> Function()? onRefresh;
  final List<Widget>? actions;
  final Widget? leading;

  /// true: büyük başlık (kaydırınca daralır); false: tek satır sabit app bar.
  final bool large;

  /// Özel yükleniyor görünümü (varsayılan: [BuSkeletonList]).
  final Widget? loading;

  /// [BuViewState.empty] görünümü (genelde [BuEmptyState]).
  final Widget? empty;

  /// [BuViewState.error] için hata nesnesi ve yeniden dene.
  final Object? error;
  final VoidCallback? onRetry;

  /// Başlığın altında, içeriğin üstünde şerit (örn. [BuOfflineBanner]).
  final Widget? banner;

  /// App bar altına sabitlenen alan (TabBar vb.).
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;

  /// `Scaffold.bottomNavigationBar`.
  final Widget? bottomBar;

  /// Gövde altına bırakılan boşluk (yüzen gezinme için `kNavInset` verin).
  final double bottomInset;
  final ScrollController? controller;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final Widget bar = large
        ? SliverAppBar.large(
            pinned: true,
            title: Text(title),
            leading: leading,
            actions: actions,
            bottom: bottom,
            automaticallyImplyLeading: automaticallyImplyLeading,
            backgroundColor: t.bg,
            scrolledUnderElevation: 0,
          )
        : SliverAppBar(
            pinned: true,
            title: Text(title),
            leading: leading,
            actions: actions,
            bottom: bottom,
            automaticallyImplyLeading: automaticallyImplyLeading,
            backgroundColor: t.bg,
            scrolledUnderElevation: 0,
          );

    // Boş/hata görünümü kalan alanı doldurur (SliverFillRemaining sığ ölçü ister; LayoutBuilder içeren görünümlerle çakışır).
    Widget fill(Widget child) => SliverLayoutBuilder(
          builder: (context, c) => SliverToBoxAdapter(
            child: SizedBox(height: c.remainingPaintExtent < 360 ? 360 : c.remainingPaintExtent, child: child),
          ),
        );
    final body = switch (state) {
      BuViewState.loading => SliverToBoxAdapter(child: loading ?? const BuSkeletonList(shrinkWrap: true)),
      BuViewState.empty => fill(empty ?? const SizedBox.shrink()),
      BuViewState.error => fill(BuErrorState(error: error, onRetry: onRetry ?? () {})),
      BuViewState.ready => _ReadyBody(slivers: [...slivers, SliverToBoxAdapter(child: SizedBox(height: bottomInset))]),
    };

    Widget scroll = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [bar, if (banner != null) SliverToBoxAdapter(child: banner), body],
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator(
        color: t.pr,
        backgroundColor: t.sf3,
        edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
        onRefresh: () {
          buHaptic(BuHaptic.selection);
          return onRefresh!();
        },
        child: scroll,
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      body: scroll,
    );
  }
}

/// İçerik hazır olunca bir kez yumuşakça belirir (iskelet -> veri geçişi).
class _ReadyBody extends StatefulWidget {
  const _ReadyBody({required this.slivers});

  final List<Widget> slivers;

  @override
  State<_ReadyBody> createState() => _ReadyBodyState();
}

class _ReadyBodyState extends State<_ReadyBody> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: BuMotion.medium);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: BuMotion.emphasizedDecelerate);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (BuMotion.reduced(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SliverFadeTransition(opacity: _a, sliver: SliverMainAxisGroup(slivers: widget.slivers));
}
