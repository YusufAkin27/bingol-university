import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../widgets/bu.dart';
import '../../../notifications/notifications_page.dart';
import '../../data/forum_feed_controller.dart';
import '../../forum_routes.dart';
import '../widgets/category_chips.dart';
import '../widgets/forum_state_views.dart';
import '../widgets/topic_actions.dart';
import '../widgets/topic_card.dart';

String forumSortLabel(AppLocalizations l, ForumSort s) => switch (s) {
      ForumSort.forYou => l.forumHomeSortForYou,
      ForumSort.newest => l.forumHomeSortNewest,
      ForumSort.popular => l.forumHomeSortPopular,
      ForumSort.mostCommented => l.forumHomeSortMostCommented,
      ForumSort.following => l.forumHomeSortFollowing,
    };

/// Forum ana sayfası: arama + bildirim + yeni konu eylemleri, kategori çipleri, sıralama, konu kartları.
/// Sayfa başlığı metni YOK (kullanıcı kuralı); ekran okuyucu etiketi korunur, ipucu satırı kalır.
class ForumHomePage extends StatefulWidget {
  const ForumHomePage({super.key, required this.session, this.api, this.initialCategoryId});

  final Session session;

  /// Testlerde sahte uçla kurulur; verilmezse oturumun HTTP katmanı kullanılır.
  final ForumApi? api;
  final int? initialCategoryId;

  @override
  State<ForumHomePage> createState() => _ForumHomePageState();
}

class _ForumHomePageState extends State<ForumHomePage> {
  late final ForumApi _api = widget.api ?? ForumApi(widget.session);
  late final ForumFeedController _feed = ForumFeedController(_api, categoryId: widget.initialCategoryId);
  final _scroll = ScrollController();

  List<ForumCategory> _cats = const [];
  bool _catsLoading = true;

  @override
  void initState() {
    super.initState();
    _feed.addListener(_onFeed);
    _feed.load();
    _loadCategories();
  }

  @override
  void dispose() {
    _feed.removeListener(_onFeed);
    _feed.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onFeed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCategories() async {
    try {
      final c = await _api.categories();
      if (!mounted) return;
      setState(() {
        _cats = [...c]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _catsLoading = false;
      });
    } catch (_) {
      // Kategoriler yüklenemezse yalnız "Tümü" çipi kalır; akış çalışmaya devam eder.
      if (mounted) setState(() => _catsLoading = false);
    }
  }

  Future<void> _refresh() async {
    _loadCategories();
    await _feed.load();
    final e = _feed.lastRefreshError;
    if (mounted && e != null) BuToast.show(context, forumErrorText(e, context.l10n), kind: BuToastKind.error);
  }

  Future<void> _open(TopicSummary t) async {
    final r = await openTopicDetail(context, widget.session, t.id, initial: t);
    if (!mounted || r == null) return;
    if (r.removed) {
      _feed.remove(r.id);
    } else {
      _feed.replace(r);
    }
  }

  Future<void> _newTopic() async {
    final r = await openCreateTopic(context, widget.session, categoryId: _feed.categoryId);
    if (!mounted || r == null) return;
    final fits = _feed.categoryId == null || r.category?.id == _feed.categoryId;
    if (fits && (_feed.sort == ForumSort.forYou || _feed.sort == ForumSort.newest)) {
      _feed.insertFirst(r);
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: BuMotion.of(context, BuMotion.long), curve: BuMotion.emphasizedDecelerate);
      }
    } else {
      _feed.load();
    }
  }

  void _menuResult(TopicSummary t, TopicMenuResult r) {
    switch (r) {
      case TopicMenuResult.hideTopic:
        _feed.remove(t.id);
      case TopicMenuResult.hideAuthor:
        final uid = t.author.userId;
        uid == null ? _feed.remove(t.id) : _feed.removeByAuthor(uid);
      case TopicMenuResult.none:
        break;
    }
  }

  Future<void> _pickSort() async {
    final l = context.l10n;
    final picked = await BuSheet.show<ForumSort>(
      context,
      title: l.forumHomeSortTitle,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        for (final s in ForumSort.values)
          BuListTile(
            key: ValueKey('forum-sort-${s.wire}'),
            title: forumSortLabel(l, s),
            selected: s == _feed.sort,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
            trailing: s == _feed.sort ? Icon(BuIcons.check, size: 20, color: ctx.bu.ink) : null,
            onTap: () => Navigator.of(ctx).pop(s),
          ),
      ]),
    );
    if (picked != null && picked != _feed.sort) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
      await _feed.setSort(picked);
    }
  }

  Future<void> _moreMenu() async {
    final l = context.l10n;
    final t = context.bu;
    final r = await BuSheet.show<int>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        for (final (i, e) in [
          (BuIcons.bookmark, l.forumHomeMenuSaved),
          (BuIcons.messageSquareText, l.forumHomeMenuActivity),
          (BuIcons.bellRing, l.forumHomeMenuPrefs),
        ].indexed)
          BuListTile(
            key: ValueKey('forum-more-menu-$i'),
            title: e.$2,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 6),
            leading: Icon(e.$1, size: 22, color: t.ink),
            onTap: () => Navigator.of(ctx).pop(i),
          ),
      ]),
    );
    if (r == null || !mounted) return;
    switch (r) {
      case 0:
        await openForumSaved(context, widget.session);
      case 1:
        await openMyForumActivity(context, widget.session);
      case 2:
        await openForumPrefs(context, widget.session);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical && n.metrics.pixels >= n.metrics.maxScrollExtent - 700) {
      _feed.loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, top + BuSpace.sm, 0, 0),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
            child: SizedBox(
              height: BuSize.touch,
              child: Row(children: [
                BuIconButton(
                  key: const ValueKey('forum-back'),
                  icon: BuIcons.arrowLeft,
                  tooltip: l.commonBack,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Semantics(header: true, label: l.forumHomeA11y, child: const SizedBox.expand()),
                ),
                BuIconButton(
                  key: const ValueKey('forum-bell'),
                  icon: BuIcons.bell,
                  tooltip: l.forumHomeNotifications,
                  onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                      settings: const RouteSettings(name: 'notifications'),
                      builder: (_) => NotificationsPage(session: widget.session))),
                ),
                BuGap.w8,
                BuIconButton(
                  key: const ValueKey('forum-new'),
                  icon: BuIcons.plus,
                  tooltip: l.forumHomeNewTopic,
                  filled: true,
                  onTap: _newTopic,
                ),
              ]),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, 2, BuSpace.page, 12),
          child: Text(l.forumHomeHint,
              key: const ValueKey('forum-hint'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.mut)),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, 0, BuSpace.page, 8),
          // Görünür arama kutusu: dokununca tam arama sayfası açılır (yazma orada; son aramalar + popüler konular).
          child: Semantics(
            button: true,
            label: l.forumHomeSearch,
            excludeSemantics: true,
            child: BuSearchField(
              key: const ValueKey('forum-search'),
              hint: l.forumSearchHint,
              readOnly: true,
              onTap: () => openForumSearch(context, widget.session),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: ForumCategoryChips(
          categories: _cats,
          selectedId: _feed.categoryId,
          loading: _catsLoading,
          onSelected: (id) {
            if (_scroll.hasClients) _scroll.jumpTo(0);
            _feed.setCategory(id);
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page - 8, 0, 8, 0),
          child: Row(children: [
            Semantics(
              button: true,
              label: '${l.forumHomeSortTitle}: ${forumSortLabel(l, _feed.sort)}',
              excludeSemantics: true,
              child: BuPressable(
                key: const ValueKey('forum-sort'),
                onTap: _pickSort,
                scale: .96,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: BuSize.touch),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(BuIcons.slidersHorizontal, size: 18, color: t.mut),
                      BuGap.w8,
                      Text(forumSortLabel(l, _feed.sort),
                          key: const ValueKey('forum-sort-label'),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
                      BuGap.w4,
                      Icon(BuIcons.chevronDown, size: 18, color: t.mut),
                    ]),
                  ),
                ),
              ),
            ),
            const Spacer(),
            BuIconButton(
              key: const ValueKey('forum-overflow'),
              icon: BuIcons.ellipsis,
              tooltip: l.forumHomeMore,
              size: 40,
              onTap: _moreMenu,
            ),
          ]),
        ),
      ),
      ..._body(context, bottom),
    ];

    return Scaffold(
      backgroundColor: t.bg,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: BuRefreshIndicator(
          onRefresh: _refresh,
          edgeOffset: top,
          child: CustomScrollView(
            key: const ValueKey('forum-scroll'),
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: slivers,
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, double bottom) {
    final l = context.l10n;
    final f = _feed;
    // Durum görünümleri sınırlı yükseklik ister (içlerinde LayoutBuilder var): sliver içinde sabit pay verilir.
    final stateHeight = math.max(380.0, MediaQuery.sizeOf(context).height - 340);
    if (f.error != null && !f.loaded) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: stateHeight,
            child: ForumErrorView(error: f.error!, onRetry: () => f.load(reset: true)),
          ),
        ),
      ];
    }
    if (f.loading && !f.loaded) {
      return [
        SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(BuSpace.page, 4, BuSpace.page, 24 + bottom),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox.shrink(),
            itemBuilder: (_, __) => const Padding(
                padding: EdgeInsetsDirectional.only(bottom: 12), child: TopicCardSkeleton(key: ValueKey('forum-skeleton'))),
          ),
        ),
      ];
    }
    if (f.isEmpty) {
      final following = f.sort == ForumSort.following;
      final category = f.categoryId != null;
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: stateHeight,
            child: ForumEmptyView(
            key: const ValueKey('forum-empty'),
            title: following
                ? l.forumHomeEmptyFollowingTitle
                : category
                    ? l.forumHomeEmptyCategoryTitle
                    : l.forumHomeEmptyTitle,
            message: following
                ? l.forumHomeEmptyFollowingBody
                : category
                    ? l.forumHomeEmptyCategoryBody
                    : l.forumHomeEmptyBody,
            actionLabel: following ? null : l.forumHomeEmptyAction,
            onAction: following ? null : _newTopic,
          ),
          ),
        ),
      ];
    }
    final items = f.items;
    return [
      SliverPadding(
        padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, 4, BuSpace.page, 0),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => BuGap.h12,
          findItemIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            final i = items.indexWhere((e) => 'forum-item-${e.id}' == key.value);
            return i < 0 ? null : i;
          },
          itemBuilder: (context, i) {
            final topic = items[i];
            final card = TopicCard(
              session: widget.session,
              api: _api,
              topic: topic,
              showDivider: false,
              onOpen: () => _open(topic),
              onChanged: _feed.replace,
              onMenuResult: _menuResult,
            );
            return _Entrance(key: ValueKey('forum-item-${topic.id}'), animate: topic.id == f.justAddedId, child: card);
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(BuSpace.page, 16, BuSpace.page, 32 + bottom),
          child: f.moreFailed
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(
                    child: Text(l.forumHomeLoadMoreFailed,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.bu.mut)),
                  ),
                  BuButton(
                      key: const ValueKey('forum-more-retry'),
                      label: l.commonRetryShort,
                      kind: BuButtonKind.text,
                      compact: true,
                      onPressed: f.loadMore),
                ])
              : f.loadingMore
                  ? const Center(
                      child: SizedBox(
                          key: ValueKey('forum-loading-more'),
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.4)))
                  : const SizedBox(height: 4),
        ),
      ),
    ];
  }
}

/// Yeni eklenen konu kartı: yukarıdan hafifçe kayıp belirir (hareket azaltılmışsa anında).
class _Entrance extends StatelessWidget {
  const _Entrance({super.key, required this.child, required this.animate});

  final Widget child;

  /// true yalnız yeni eklenen konuda; diğerlerinde başlangıç = bitiş olduğundan animasyon çalışmaz (öğe yeniden
  /// kurulsa da widget türü sabit kaldığından kart durumu korunur).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (BuMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : 1, end: 1),
      duration: BuMotion.long,
      curve: BuMotion.emphasizedDecelerate,
      builder: (context, v, child) =>
          Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, (1 - v) * -16), child: child)),
      child: child,
    );
  }
}
