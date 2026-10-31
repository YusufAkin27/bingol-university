import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show ErrorView;
import 'club_categories.dart';
import 'club_detail_page.dart';
import 'club_form_page.dart';
import 'club_join_flow.dart';
import 'clubs_widgets.dart';

/// Kulüpler sekmesi: Keşfet (GET /communities) ve Kulüplerim (GET /me/communities).
class ClubsTab extends StatefulWidget {
  const ClubsTab({super.key, required this.session});

  final Session session;

  @override
  State<ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends State<ClubsTab> {
  String? _category; // null = Tümü
  int _seg = 0; // 0 Keşfet, 1 Kulüplerim
  String _query = '';
  bool _searching = false;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<ClubCategory> _categories = const [];
  List<Map<String, dynamic>> _mine = [];

  List<Map<String, dynamic>> _items = [];
  String? _cursor;
  bool _loading = true;
  bool _more = false;
  Object? _error;
  int _gen = 0; // eski yanıtları yok saymak için
  final Set<int> _joining = {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _reload();
    _loadCategories();
    _loadMine();
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _path(String? cursor) {
    final q = <String>['size=20'];
    if (cursor != null) q.add('cursor=${Uri.encodeQueryComponent(cursor)}');
    if (_category != null) {
      q.add('category=${Uri.encodeQueryComponent(_category!)}');
    }
    if (_query.isNotEmpty) q.add('q=${Uri.encodeQueryComponent(_query)}');
    return '/communities?${q.join('&')}';
  }

  /// Keşfet kategorileri sunucudan gelir (GET /communities/categories, admin sırasıyla, yalnız aktifler);
  /// boş (count 0) kategoriler çipte gizlenir; hata çipleri gizler.
  Future<void> _loadCategories() async {
    final list = await ClubCategories.load(widget.session.api);
    if (!mounted || list == null) return;
    setState(() {
      _categories = [for (final c in list) if (!c.isEmpty) c];
      // Seçili kategori artık listede yoksa süzgeç sıfırlanır.
      if (_category != null && !_categories.any((c) => c.key == _category)) {
        _category = null;
        _reload(silent: true);
      }
    });
  }

  /// "Kulüplerim" şeridi (GET /me/communities); hata şeridi gizler.
  Future<void> _loadMine() async {
    try {
      final res = await widget.session.api.get('/me/communities?size=50');
      if (!mounted) return;
      setState(() => _mine = _parse(res));
    } catch (_) {}
  }

  Future<void> _reload({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = await widget.session.api.get(_path(null), force: silent);
      if (!mounted || gen != _gen) return;
      final list = _parse(res);
      setState(() {
        _items = list;
        _cursor = res is Map ? res['nextCursor']?.toString() : null;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    _loadCategories();
    _loadMine();
    await _reload(silent: true);
  }

  Future<void> _loadMore() async {
    if (_more || _loading || _cursor == null) return;
    final gen = _gen;
    setState(() => _more = true);
    try {
      final res = await widget.session.api.get(_path(_cursor));
      if (!mounted || gen != _gen) return;
      final list = _parse(res);
      setState(() {
        _items = [..._items, ...list];
        _cursor = res is Map ? res['nextCursor']?.toString() : null;
        _more = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() => _more = false);
      _toast(errorText(e));
    }
  }

  List<Map<String, dynamic>> _parse(dynamic res) {
    final raw = res is Map ? res['items'] : res;
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _join(Map<String, dynamic> c) async {
    final id = ((c['id'] as num?)?.toInt() ?? -1);
    if (_joining.contains(id)) return;
    setState(() => _joining.add(id));
    try {
      final st = await joinClubFlow(
        context,
        widget.session,
        communityId: id,
        clubName: (c['name'] ?? '').toString(),
        needsApproval:
            c['joinPolicy'] == 'APPROVAL' || c['visibility'] == 'PRIVATE',
      );
      if (!mounted || st == null) return;
      setState(() {
        c['myStatus'] = st;
        if (c['myStatus'] == 'ACTIVE') {
          c['memberCount'] = ((c['memberCount'] as num?) ?? 0).toInt() + 1;
        }
      });
      if (st == 'ACTIVE') _loadMine();
    } catch (e) {
      if (mounted) _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _joining.remove(id));
    }
  }

  Future<void> _open(Map<String, dynamic> c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubDetailPage(
            session: widget.session, communityId: ((c['id'] as num?)?.toInt() ?? -1)),
      ),
    );
    if (mounted) {
      _reload(silent: true);
      _loadMine();
    }
  }

  /// Kulüp kur: form -> (ACTIVE ise kulüp sayfası / onaya gönderildi bilgisi) -> liste yenilenir.
  Future<void> _create() async {
    final created = await openCreateClub(context, widget.session);
    if (created && mounted) {
      _reload(silent: true);
      _loadMine();
    }
  }

  void _setCategory(String? c) {
    if (c == _category) return;
    setState(() => _category = c);
    _reload();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching && _query.isNotEmpty) {
        _search.clear();
        _query = '';
        _reload();
      }
    });
  }

  void _submitSearch(String v) {
    final q = v.trim();
    if (q == _query) return;
    _query = q;
    _reload();
  }

  int _id(Map<String, dynamic> c) => ((c['id'] as num?)?.toInt() ?? -1);

  /// "Kulüplerim" sekmesi: /me/communities + keşfet listesindeki ACTIVE olanlar.
  List<Map<String, dynamic>> get _strip {
    final seen = <int>{};
    final out = <Map<String, dynamic>>[];
    for (final c in [..._mine, ..._items.where((c) => c['myStatus'] == 'ACTIVE')]) {
      if (!seen.add(_id(c))) continue;
      if (_query.isNotEmpty &&
          !('${c['name']}').toLowerCase().contains(_query.toLowerCase())) {
        continue;
      }
      out.add(c);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final cats = _categories;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: context.l10n.clubMgmtClubsTitle,
            actions: [
              BuIconButton(
                icon: _searching ? LucideIcons.x : LucideIcons.search,
                tooltip: context.l10n.clubMgmtSearch,
                onTap: _toggleSearch,
              ),
              BuIconButton(
                icon: LucideIcons.plus,
                tooltip: context.l10n.clubMgmtCreateTitle,
                filled: true,
                onTap: _create,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: BuSegmented(
              items: [context.l10n.clubMgmtTabDiscover, context.l10n.clubMgmtTabMine],
              index: _seg,
              onChanged: (i) => setState(() => _seg = i),
            ),
          ),
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: BuSearchField(
                hint: context.l10n.clubMgmtSearchClub,
                controller: _search,
                autofocus: true,
                onSubmitted: _submitSearch,
                onChanged: (v) {
                  if (v.trim().isEmpty && _query.isNotEmpty) _submitSearch('');
                },
              ),
            ),
          if (cats.isNotEmpty && _seg == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              // BuChip kendi 48 dp kutusunu ister; 34 dp kutu yazıyı alttan kırpıyordu ("g" kuyruğu).
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
                  children: [
                    BuChip(
                        label: context.l10n.clubMgmtAll,
                        selected: _category == null,
                        onTap: () => _setCategory(null)),
                    for (final c in cats) ...[
                      const SizedBox(width: 8),
                      BuChip(
                          label: c.name,
                          selected: _category == c.key,
                          onTap: () => _setCategory(c.key)),
                    ],
                  ],
                ),
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    final l = context.l10n;
    if (_loading) return const BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 6);
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error!, onRetry: _reload);
    }
    final mine = _seg == 1;
    final list = mine ? _strip : _items;
    if (list.isEmpty) {
      final Widget empty = mine && _query.isEmpty
          ? BuEmptyState(
              illustration: BuIllustration.club,
              title: l.clubMgmtEmptyMine,
              actionLabel: l.kuluplerAllClubs,
              onAction: () => setState(() => _seg = 0),
            )
          : BuEmptyState(
              illustration: _query.isNotEmpty ? BuIllustration.search : BuIllustration.club,
              title: l.clubMgmtNotFound,
            );
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kNavInset),
          children: [SizedBox(height: 420, child: empty)],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 14, bottom: kNavInset),
        itemCount: list.length + (_more && !mine ? 1 : 0),
        itemBuilder: (_, k) {
          if (k >= list.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final c = list[k];
          return Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, k == list.length - 1 ? 0 : 12),
            child: ClubsRowCard(
              club: c,
              busy: _joining.contains(_id(c)),
              onOpen: () => _open(c),
              onJoin: () => _join(c),
            ),
          );
        },
      ),
    );
  }
}
