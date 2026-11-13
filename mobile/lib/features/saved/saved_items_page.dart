import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show LoadingView;
import '../academic/academic_calendar_page.dart';
import '../clubs/club_detail_page.dart';
import '../events/event_detail_page.dart';
import '../forum/forum_routes.dart' show ForumApi, openTopicDetail;
import '../news/news_detail_page.dart';
import '../polls/poll_detail_page.dart';
import '../posts/post_detail_page.dart';
import 'saved_api.dart';

/// Birleşik "Kaydedilenler": haber, etkinlik, kulüp, anket, akademik, gönderi ve forum kayıtları tek listede.
/// Tür süzgeci çipleri, imleçli sonsuz kaydırma, kaydırarak / uzun basarak kaldırma.
/// Veri: `GET /bookmarks?type=&cursor=&size=`, kaldırma tür uçlarında `DELETE`.
class SavedItemsPage extends StatefulWidget {
  const SavedItemsPage({super.key, required this.session});

  final Session session;

  @override
  State<SavedItemsPage> createState() => _SavedItemsPageState();
}

/// Çip sırası -> sunucu `type` değeri (Forum çipi iki türü ayrı ayrı çekmez: konu süzgeci; yorumlar Tümü'de görünür).
const _filterTypes = [kSavedTypeAll, 'NEWS', 'EVENT', 'COMMUNITY', 'POLL', 'POST', 'FORUM_TOPIC'];

/// Art arda bos sayfa gelirse tek yuklemede en cok kac ek sayfa istenir.
const _maxEmptyHops = 5;

class _SavedItemsPageState extends State<SavedItemsPage> {
  late final SavedApi _api = SavedApi(widget.session);
  final _items = <SavedItem>[];
  final _scroll = ScrollController();
  int _filter = 0;
  int? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  /// Süzgeç değişince eski yanıtı yok saymak için.
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
    final gen = _gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Sunucu once sayfalayip sonra erisilemeyenleri eler: bos sayfa + nextCursor gelirse
      // "bos" gostermeden sonraki sayfayi iste (ust sinir _maxEmptyHops).
      for (var hop = 0; hop <= _maxEmptyHops; hop++) {
        final p = await _api.list(type: _filterTypes[_filter], cursor: _cursor);
        if (gen != _gen || !mounted) return;
        _items.addAll(p.items.where((e) => !_items.any((x) => x.key == e.key)));
        _cursor = p.nextCursor;
        _hasMore = p.nextCursor != null;
        if (p.items.isNotEmpty || !_hasMore) break;
      }
    } catch (e) {
      if (gen != _gen) return;
      _error = e;
      _hasMore = false; // otomatik tekrar döngüsünü kes; "Yeniden dene" açar
    }
    if (mounted && gen == _gen) setState(() => _loading = false);
  }

  /// Açılan sayfadan dönünce (kayıt kaldırılmış olabilir) ilk sayfayı sessizce tazeler.
  Future<void> _refreshQuiet() async {
    final gen = _gen;
    try {
      final p = await _api.list(type: _filterTypes[_filter]);
      if (!mounted || gen != _gen) return;
      final fresh = p.items.map((e) => e.key).toSet();
      setState(() {
        if (_items.length <= 20) {
          _items
            ..clear()
            ..addAll(p.items);
          _cursor = p.nextCursor;
          _hasMore = p.nextCursor != null;
        } else {
          // Derin liste: ilk sayfa kapsamindaki kaldirilmis kayitlari dusur.
          final head = _items.take(20).where((x) => !fresh.contains(x.key)).map((x) => x.key).toSet();
          _items.removeWhere((x) => head.contains(x.key));
        }
      });
    } catch (_) {
      // Sessiz tazeleme en iyi çabadır.
    }
  }

  Future<void> _remove(SavedItem it) async {
    final idx = _items.indexWhere((x) => x.key == it.key);
    if (idx < 0) return;
    setState(() => _items.removeAt(idx));
    try {
      await _api.unsaveItem(it);
      Analytics.instance.action('bookmark', target: 'remove');
      if (mounted) BuToast.show(context, context.l10n.svRemoved, kind: BuToastKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _items.insert(idx.clamp(0, _items.length), it));
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _longPress(SavedItem it) async {
    final l = context.l10n;
    final go = await BuSheet.show<bool>(
      context,
      title: it.title,
      builder: (c) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BuButton(
          key: const ValueKey('saved-sheet-remove'),
          label: l.svRemoveAction,
          icon: BuIcons.bookmark,
          kind: BuButtonKind.outline,
          onPressed: () => Navigator.of(c).pop(true),
        ),
        const SizedBox(height: 8),
      ]),
    );
    if (go == true) unawaited(_remove(it));
  }

  Future<void> _push(Widget page, String name) =>
      Navigator.push(context, MaterialPageRoute<void>(settings: RouteSettings(name: name), builder: (_) => page));

  Future<void> _open(SavedItem it) async {
    final s = widget.session;
    try {
      switch (it.type) {
        case 'NEWS':
          final n = it.news;
          if (n == null) return BuToast.show(context, context.l10n.svOpenFailed, kind: BuToastKind.error);
          await _push(NewsDetailPage(session: s, item: n, saved: true), 'news_detail');
        case 'EVENT':
          await _push(EventDetailPage(session: s, eventId: it.targetId), 'event_detail');
        case 'COMMUNITY':
          await _push(ClubDetailPage(session: s, communityId: it.targetId), 'club_detail');
        case 'POLL':
          await _push(PollDetailPage(session: s, pollId: it.targetId), 'poll_detail');
        case 'ACADEMIC':
          await _push(AcademicCalendarPage(session: s), 'academic_calendar');
        case 'POST':
          await _push(PostDetailPage(session: s, postId: it.targetId), 'post_detail');
        case 'FORUM_TOPIC':
          await openTopicDetail(context, s, it.targetId);
        case 'FORUM_COMMENT':
          final c = await ForumApi(s).comment(it.targetId);
          if (!mounted) return;
          if (c.topicId <= 0) return BuToast.show(context, context.l10n.svOpenFailed, kind: BuToastKind.error);
          await openTopicDetail(context, s, c.topicId, commentId: it.targetId);
        default:
          return;
      }
    } catch (e) {
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
      return;
    }
    if (mounted) unawaited(_refreshQuiet());
  }

  String _typeLabel(SavedItem it) {
    final l = context.l10n;
    return switch (it.type) {
      'NEWS' => l.svTypeNews,
      'EVENT' => l.svTypeEvent,
      'COMMUNITY' => l.svTypeCommunity,
      'POLL' => l.svTypePoll,
      'ACADEMIC' => l.svTypeAcademic,
      'POST' => l.svTypePost,
      'FORUM_TOPIC' => l.svTypeTopic,
      'FORUM_COMMENT' => l.svTypeComment,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final labels = [l.svFilterAll, l.svFilterNews, l.svFilterEvents, l.svFilterClubs, l.svFilterPolls, l.svFilterPosts, l.svFilterForum];
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.svTitle, visibleTitle: true, onBack: () => Navigator.maybePop(context)),
        BuChipRow(
          key: const ValueKey('saved-filters'),
          labels: labels,
          selected: _filter,
          onSelected: (i) {
            if (i == _filter) return;
            setState(() => _filter = i);
            _reload();
          },
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    final l = context.l10n;
    if (_items.isEmpty && (_loading || (_hasMore && _error == null))) return const LoadingView();
    if (_items.isEmpty && _error != null) {
      return BuErrorState(error: _error!, onRetry: () {
        setState(() => _hasMore = true);
        _reload();
      });
    }
    if (_items.isEmpty) {
      final all = _filter == 0;
      return BuRefreshIndicator(
        onRefresh: Analytics.pullRefresh(_reload),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: BuEmptyState(
                key: const ValueKey('saved-empty'),
                icon: BuIcons.bookmark,
                title: all ? l.svEmptyTitle : l.svEmptyFilterTitle,
                message: all ? l.svEmptyBody : l.svEmptyFilterBody,
              ),
            ),
          ),
        ),
      );
    }
    return BuStaggerScope(
      child: BuRefreshIndicator(
        onRefresh: Analytics.pullRefresh(_reload),
        child: ListView.builder(
          key: const ValueKey('saved-list'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.paddingOf(context).bottom + 24),
          itemCount: _items.length + 1,
          itemBuilder: (context, i) {
            if (i == _items.length) return _footer();
            final it = _items[i];
            // Yalnız ilk görünen satırlar sırayla belirir (BuStaggerItem: ilk 8, tek sefer, azaltılmış harekette yok).
            return BuStaggerItem(
              key: ValueKey('saved-stagger-${it.key}'),
              index: i,
              child: Dismissible(
                key: ValueKey('saved-${it.key}'),
                direction: DismissDirection.endToStart,
                background: _dismissBg(),
                secondaryBackground: _dismissBg(),
                onDismissed: (_) => _remove(it),
                child: _SavedRow(item: it, typeLabel: _typeLabel(it), onTap: () => _open(it), onLongPress: () => _longPress(it)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dismissBg() {
    final t = context.bu;
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: t.sf,
      child: Icon(BuIcons.trash2, color: t.mut),
    );
  }

  Widget _footer() {
    final l = context.l10n;
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: BuButton(
            key: const ValueKey('saved-footer-retry'),
            label: l.commonRetry,
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
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    return const SizedBox(height: 4);
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({required this.item, required this.typeLabel, required this.onTap, required this.onLongPress});

  final SavedItem item;
  final String typeLabel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final sub = [if (typeLabel.isNotEmpty) typeLabel, if (item.subtitle.isNotEmpty) item.subtitle].join(' · ');
    return Semantics(
      button: true,
      label: '${item.title}. $sub',
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: InkWell(
        key: ValueKey('saved-row-${item.key}'),
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              BuImage(item.imageUrl, width: 56, height: 56, radius: 12, placeholderIcon: BuIcons.bookmark),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(fontSize: 16, color: t.ink)),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontSize: 13, color: t.mut)),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
