import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'follow_widgets.dart';
import 'suggestion_pager.dart';

/// "Önerilen kişiler" tam sayfası ekran adı (analitik / rota gözlemcisi).
const followSuggestionsRoute = 'follow_suggestions';

/// "Tümünü gör" sayfasını açar (Ana Sayfa şeridi, Keşfet şeridi).
Future<void> openFollowSuggestions(BuildContext context, Session session) => Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: followSuggestionsRoute),
        builder: (_) => FollowSuggestionsPage(session: session),
      ),
    );

/// "Önerilen kişiler" dikey listesi (`GET /users/me/follow-suggestions?page=N&size=M`): kaydırdıkça sıradaki sayfa gelir,
/// çek-yenile ile baştan yüklenir. Yükleniyor / hata / boş durumlarını kendisi yönetir.
class FollowSuggestionsList extends StatefulWidget {
  const FollowSuggestionsList({super.key, required this.session, this.pageSize = 20});

  final Session session;
  final int pageSize;

  @override
  State<FollowSuggestionsList> createState() => _FollowSuggestionsListState();
}

class _FollowSuggestionsListState extends State<FollowSuggestionsList> {
  late final SuggestionPager _pager = SuggestionPager(widget.session, pageSize: widget.pageSize);
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _pager.addListener(_onPager);
    _pager.reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pager.removeListener(_onPager);
    _pager.dispose();
    super.dispose();
  }

  void _onPager() {
    if (!mounted) return;
    setState(() {});
    // İlk sayfa ekranı doldurmadıysa kaydırma olmaz: sıradaki sayfayı kendimiz iste.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_pager.moreError == null && _scroll.position.maxScrollExtent <= 0) _pager.loadMore();
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients || _pager.moreError != null) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 320) _pager.loadMore();
  }

  Future<void> _refresh() => _pager.reload();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _pager.items;
    final bottom = MediaQuery.paddingOf(context).bottom + 24;

    Widget status(Widget child) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
          children: [child],
        );

    final Widget body;
    if (items.isEmpty && _pager.error != null) {
      body = status(FollowStatusCard(
        error: true,
        icon: BuIcons.wifiOff,
        title: l.p18FollowErrorTitle,
        message: errorText(_pager.error!),
        onRetry: _pager.reload,
      ));
    } else if (items.isEmpty && !_pager.loaded) {
      body = status(const FollowSkeletonCard(count: 4));
    } else if (items.isEmpty) {
      body = status(FollowStatusCard(
        icon: BuIcons.userSearch,
        title: l.followSuggestionsEmpty,
        message: l.followFeedHint,
      ));
    } else {
      final t = context.bu;
      final hasFooter = _pager.loadingMore || _pager.moreError != null;
      body = BuStaggerScope(
        child: ListView.builder(
          key: const ValueKey('followSuggestionsList'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.fromSTEB(4, 4, 4, bottom),
          itemCount: items.length + (hasFooter ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= items.length) {
              return _pager.moreError != null
                  ? _MoreError(onRetry: _pager.loadMore)
                  : const BuSkeletonScope(child: _RowSkeleton());
            }
            final it = items[i];
            return Column(mainAxisSize: MainAxisSize.min, children: [
              if (i > 0) Divider(height: 1, indent: 72, endIndent: 16, color: t.bd),
              BuStaggerItem(
                index: i,
                maxAnimated: 8,
                child: FollowPersonRow(
                  key: ValueKey('suggestion-row-${it.user.id}'),
                  session: widget.session,
                  user: it.user,
                  reason: it.reasonLabel(l),
                  classLabel: it.classYear == null ? null : l.p18ClassYear('${it.classYear}'),
                ),
              ),
            ]);
          },
        ),
      );
    }

    return BuRefreshIndicator(onRefresh: Analytics.pullRefresh(_refresh), child: body);
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        child: Row(children: [
          BuSkeleton.circle(44),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BuSkeleton.line(width: 120, height: 14),
              SizedBox(height: 8),
              BuSkeleton.line(width: 160),
            ]),
          ),
          SizedBox(width: 12),
          BuSkeleton(width: 76, height: 40, radius: 14),
        ]),
      );
}

/// Sonraki sayfa yüklenemedi: liste yerinde kalır, altta kısa uyarı + "Yeniden dene".
class _MoreError extends StatelessWidget {
  const _MoreError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
      child: Row(children: [
        Expanded(
          child: Text(l.homeContentLoadFailed,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.bu.mut)),
        ),
        const SizedBox(width: 12),
        BuButton(label: l.commonRetry, icon: BuIcons.refreshCw, compact: true, onPressed: onRetry),
      ]),
    );
  }
}

class FollowSuggestionsPage extends StatelessWidget {
  const FollowSuggestionsPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bu.bg,
      body: Column(children: [
        BuHeader(title: context.l10n.followSuggestionsTitle, onBack: () => Navigator.pop(context)),
        Expanded(child: FollowSuggestionsList(session: session)),
      ]),
    );
  }
}
