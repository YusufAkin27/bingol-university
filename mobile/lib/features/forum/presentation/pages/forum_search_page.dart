import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_recent_searches.dart';
import '../../data/forum_search_text.dart';
import '../../forum_routes.dart';
import '../widgets/forum_list_topic_card.dart';
import '../widgets/forum_page_bar.dart';
import '../widgets/forum_paged_list.dart';
import '../widgets/forum_result_tiles.dart';

/// Arama yazıldıktan sonra isteğin gitmesi için beklenen süre (her tuşta istek atılmaz).
const Duration kForumSearchDebounce = Duration(milliseconds: 350);

const List<String> _sortWire = ['RELEVANCE', 'NEWEST', 'POPULAR'];

/// Forum araması (`GET /api/forum/search`): 350 ms bekleme, en az 2 karakter, kategori çipleri, sıralama
/// (İlgili / En yeni / Popüler), eşleşme etiketi + vurgulu kesit, imleçli sayfalama, boş/hata durumları.
/// Kutu boşken: cihazdaki son aramalar (kullanıcıya özel, en çok 10) ve popüler konular.
/// Genel arama (`features/search`) ile karışmaz; yalnız `openForumSearch` ile açılır.
class ForumSearchPage extends StatefulWidget {
  const ForumSearchPage({super.key, required this.session});

  final Session session;

  @override
  State<ForumSearchPage> createState() => _ForumSearchPageState();
}

class _ForumSearchPageState extends State<ForumSearchPage> {
  late final ForumApi _api = ForumApi(widget.session);
  final _ctl = TextEditingController();
  Timer? _debounce;

  /// Sunucuya giden (bekleme dolmuş) sorgu; boş = arama yok.
  String _active = '';
  int _sortIdx = 0;
  int _catIdx = 0;
  List<ForumCategory> _categories = const [];

  List<String> _recent = const [];
  List<TopicSummary>? _popular;
  Object? _popularError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecent());
    unawaited(_loadPopular());
    unawaited(_loadCategories());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final r = await ForumRecentSearches.load();
    if (mounted) setState(() => _recent = r);
  }

  Future<void> _loadPopular() async {
    setState(() => _popularError = null);
    try {
      final p = await _api.popular();
      if (mounted) setState(() => _popular = p);
    } catch (e) {
      if (mounted) {
        setState(() {
          _popular = null;
          _popularError = e;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final c = await _api.categories();
      if (mounted) setState(() => _categories = c);
    } catch (_) {
      // Kategori çipleri isteğe bağlıdır; yüklenemezse yalnız "Tümü" gibi süzgeçsiz arama sürer.
    }
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    setState(() {}); // ipucu satırı
    if (!forumQueryActive(v)) {
      if (_active.isNotEmpty) setState(() => _active = '');
      return;
    }
    _debounce = Timer(kForumSearchDebounce, () {
      final q = normalizeForumQuery(_ctl.text);
      if (mounted && q != _active && forumQueryActive(q)) setState(() => _active = q);
    });
  }

  Future<void> _onSubmitted(String v) async {
    _debounce?.cancel();
    final q = normalizeForumQuery(v);
    if (!forumQueryActive(q)) return;
    if (q != _active) setState(() => _active = q);
    await _remember(q);
  }

  Future<void> _remember(String q) async {
    final r = await ForumRecentSearches.add(q);
    if (mounted) setState(() => _recent = r);
  }

  void _runRecent(String term) {
    _debounce?.cancel();
    _ctl.value = TextEditingValue(text: term, selection: TextSelection.collapsed(offset: term.length));
    setState(() => _active = normalizeForumQuery(term));
    unawaited(_remember(term));
  }

  Future<void> _removeRecent(String term) async {
    final r = await ForumRecentSearches.remove(term);
    if (mounted) setState(() => _recent = r);
  }

  Future<void> _clearRecent() async {
    await ForumRecentSearches.clear();
    if (mounted) setState(() => _recent = const []);
  }

  String _matchLabel(String? where) {
    final l = context.l10n;
    return switch (where) {
      'TITLE' => l.forumSearchMatchTitle,
      'BODY' => l.forumSearchMatchBody,
      'COMMENT' => l.forumSearchMatchComment,
      'CATEGORY' => l.forumSearchMatchCategory,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final searching = _active.isNotEmpty;
    final catLabels = [l.forumSearchAllCategories, ..._categories.map((c) => c.name)];
    final catId = _catIdx > 0 && _catIdx <= _categories.length ? _categories[_catIdx - 1].id : null;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ForumPageBar(
          semanticTitle: l.forumSearchTitle,
          middle: BuSearchField(
            key: const ValueKey('forum-search-field'),
            controller: _ctl,
            hint: l.forumSearchHint,
            autofocus: true,
            onChanged: _onChanged,
            onSubmitted: _onSubmitted,
          ),
        ),
        if (searching) ...[
          if (_categories.isNotEmpty)
            BuChipRow(
              key: const ValueKey('forum-search-categories'),
              labels: catLabels,
              selected: _catIdx,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              onSelected: (i) => setState(() => _catIdx = i),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: BuSegmented(
              key: const ValueKey('forum-search-sort'),
              items: [l.forumSearchSortRelevance, l.forumSearchSortNewest, l.forumSearchSortPopular],
              index: _sortIdx,
              onChanged: (i) => setState(() => _sortIdx = i),
            ),
          ),
        ],
        Expanded(child: searching ? _results(catId) : _idle(t)),
      ]),
    );
  }

  Widget _results(int? catId) {
    final q = _active;
    final sort = _sortWire[_sortIdx];
    return ForumPagedList<ForumSearchHit>(
      key: ValueKey('forum-results|$q|$catId|$sort'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      fetch: (cursor) => _api.search(q, categoryId: catId, sort: sort, cursor: cursor),
      empty: (ctx) => BuEmptyState(
        key: const ValueKey('forum-search-empty'),
        icon: BuIcons.searchX,
        title: ctx.l10n.forumSearchEmptyTitle,
        message: ctx.l10n.forumSearchEmptyBody(q),
        compact: true,
      ),
      itemBuilder: (ctx, hit, list) {
        final label = _matchLabel(hit.matchedIn);
        final id = hit.topic.id;
        return ForumListTopicCard(
          key: ValueKey('forum-hit-$id'),
          session: widget.session,
          api: _api,
          topic: hit.topic,
          onOpened: () => unawaited(_remember(q)),
          onChanged: (t) => list.replaceWhere((h) => h.topic.id == id, ForumSearchHit(topic: t, matchedIn: hit.matchedIn, snippet: hit.snippet)),
          onRemoveTopic: () => list.removeWhere((h) => h.topic.id == id),
          onRemoveAuthor: (uid) => list.removeAllWhere((h) => h.topic.author.userId == uid),
          footer: label.isEmpty ? null : ForumMatchStrip(label: label, query: q, snippet: hit.snippet),
        );
      },
    );
  }

  Widget _idle(BuTokens t) {
    final tx = Theme.of(context).textTheme;
    final loc = context.l10n;
    final short = _ctl.text.trim().isNotEmpty && !forumQueryActive(_ctl.text);
    final popular = _popular;
    final nothing = _recent.isEmpty && popular != null && popular.isEmpty;
    if (nothing && !short) {
      return BuEmptyState(
        key: const ValueKey('forum-search-start'),
        icon: BuIcons.search,
        title: loc.forumSearchStartTitle,
        message: loc.forumSearchStartBody,
        compact: true,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (short)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(loc.forumSearchMinChars, key: const ValueKey('forum-search-min'), style: tx.bodySmall!.copyWith(color: t.mut)),
          ),
        if (_recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 0, 4),
            child: Row(children: [
              Expanded(child: Semantics(header: true, child: Text(loc.forumSearchRecent, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w400)))),
              TextButton(
                key: const ValueKey('forum-recent-clear'),
                onPressed: _clearRecent,
                style: TextButton.styleFrom(foregroundColor: t.prText, minimumSize: const Size(48, 48)),
                child: Text(loc.forumSearchClearAll),
              ),
            ]),
          ),
          for (final term in _recent)
            _RecentRow(
              key: ValueKey('forum-recent-$term'),
              term: term,
              onTap: () => _runRecent(term),
              onRemove: () => _removeRecent(term),
            ),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 0, 8),
          child: Semantics(header: true, child: Text(loc.forumSearchPopular, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w400))),
        ),
        if (_popularError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Text(errorText(_popularError!), style: tx.bodyMedium!.copyWith(color: t.mut))),
              TextButton(onPressed: _loadPopular, child: Text(loc.commonRetry)),
            ]),
          )
        else if (popular == null)
          const BuSkeletonList(variant: BuSkeletonVariant.card, itemCount: 2, shrinkWrap: true, padding: EdgeInsets.zero)
        else if (popular.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(loc.forumSearchPopularEmpty, key: const ValueKey('forum-popular-empty'), style: tx.bodyMedium!.copyWith(color: t.mut)),
          )
        else
          for (final topic in popular)
            ForumListTopicCard(
              key: ValueKey('forum-popular-${topic.id}'),
              session: widget.session,
              api: _api,
              topic: topic,
              onChanged: (t) => setState(() => _popular = [for (final e in _popular ?? const <TopicSummary>[]) e.id == t.id ? t : e]),
              onRemoveTopic: () => setState(() => _popular = [for (final e in _popular ?? const <TopicSummary>[]) if (e.id != topic.id) e]),
              onRemoveAuthor: (uid) => setState(() => _popular = [for (final e in _popular ?? const <TopicSummary>[]) if (e.author.userId != uid) e]),
            ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({super.key, required this.term, required this.onTap, required this.onRemove});

  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Row(children: [
      Expanded(
        child: Semantics(
          button: true,
          label: term,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: BuSize.touch),
              child: Row(children: [
                const SizedBox(width: 4),
                Icon(BuIcons.history, size: 18, color: t.mut),
                const SizedBox(width: 12),
                Expanded(child: Text(term, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400))),
              ]),
            ),
          ),
        ),
      ),
      IconButton(
        key: ValueKey('forum-recent-remove-$term'),
        tooltip: l.forumSearchRemoveRecent,
        constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch),
        onPressed: onRemove,
        icon: Icon(BuIcons.x, size: 18, color: t.mut),
      ),
    ]);
  }
}
