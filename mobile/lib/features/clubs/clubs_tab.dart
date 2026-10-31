import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'club_actions.dart';
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
      if (st == 'ACTIVE') {
        buHaptic(BuHaptic.light);
        _loadMine();
      }
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
          session: widget.session,
          communityId: ((c['id'] as num?)?.toInt() ?? -1),
        ),
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
    final tx = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          // Başlık: "Kulüpler" 28/700 solda; sağda marka renkli metin düğmesi "Kulüp kur" (+ arama simgesi: davranış korunur).
          // Ölçü (Stitch çerçevesi durum çubuğunsuz): başlık ortası içerik üstünden 40 dp = 16 dp boşluk + 24 dp (48 dp satır).
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, MediaQuery.paddingOf(context).top + 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(context.l10n.clubMgmtClubsTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.display.copyWith(fontSize: 28, height: 1.2, color: t.ink)),
                  ),
                ),
                Semantics(
                  button: true,
                  label: context.l10n.clubMgmtSearch,
                  child: BuPressable(
                    onTap: _toggleSearch,
                    child: SizedBox(
                      width: 44,
                      height: 48,
                      child: Icon(_searching ? LucideIcons.x : LucideIcons.search, size: 22, color: t.mut),
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  onPressed: _create,
                  child: Text(context.l10n.clubMgmtCreateTitle, style: tx.bodyLarge!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ClubTextTabs(
            labels: [context.l10n.clubMgmtTabDiscover, context.l10n.clubMgmtTabMine],
            index: _seg,
            onChanged: (i) => setState(() => _seg = i),
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
              padding: const EdgeInsets.only(top: 9),
              // BuChip: görünür 34 dp, dokunma alanı 48 dp (kutu 48 dp, yazı kırpılmaz).
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
    // İskelet -> içerik solarak; Keşfet <-> Kulüplerim geçişinde içerik "fade through" ile yer değiştirir.
    return BuSwapIn(
      loading: _loading,
      skeleton: const Align(alignment: Alignment.topCenter, child: Padding(padding: EdgeInsets.only(top: 8), child: ClubsRowSkeleton())),
      child: BuFadeThrough(
        child: KeyedSubtree(key: ValueKey<int>(_seg), child: _content()),
      ),
    );
  }

  /// Kulüplerim bölümleri: Yönettiklerim / Üye olduklarım / Bekleyen başvurular (boş bölüm gösterilmez).
  List<(String, List<Map<String, dynamic>>)> _sections() {
    final l = context.l10n;
    final list = _strip;
    bool role(Map<String, dynamic> c) => isClubManagerRole(c['myRole']?.toString());
    final pending = list.where((c) => c['myStatus'] == 'PENDING').toList();
    final active = list.where((c) => c['myStatus'] != 'PENDING').toList();
    return [
      (l.p51Managed, active.where(role).toList()),
      (l.profilePrefsClubsMember, active.where((c) => !role(c)).toList()),
      (l.profilePrefsClubsPending, pending),
    ].where((s) => s.$2.isNotEmpty).toList();
  }

  Widget _content() {
    final l = context.l10n;
    if (_error != null && _items.isEmpty) {
      final e = _error!;
      final maintenance = e is ApiError && e.status == 503;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: (c.maxHeight - kNavInset).clamp(240.0, double.infinity),
                child: ClubsStateText(
                  text: maintenance ? errorText(e) : l.p51ClubsLoadFailed,
                  actionLabel: l.commonRetry,
                  onAction: _reload,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final mine = _seg == 1;
    final list = mine ? _strip : _items;
    if (list.isEmpty) {
      final Widget empty = mine && _query.isEmpty
          ? ClubsStateText(text: l.clubMgmtEmptyMine, actionLabel: l.kuluplerAllClubs, onAction: () => setState(() => _seg = 0))
          : _query.isNotEmpty
              ? ClubsStateText(text: l.clubMgmtNotFound)
              : ClubsStateText(text: l.p51ClubsEmpty, actionLabel: l.clubMgmtCreateTitle, onAction: _create);
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: kNavInset),
            children: [SizedBox(height: (c.maxHeight - kNavInset).clamp(240.0, double.infinity), child: empty)],
          ),
        ),
      );
    }
    Widget row(Map<String, dynamic> c) => ClubsRowCard(
          club: c,
          mine: mine,
          busy: _joining.contains(_id(c)),
          onOpen: () => _open(c),
          onJoin: () => _join(c),
        );
    if (mine) {
      // Bölümlü kısa liste (kaydırma sayfalaması yok).
      final secs = _sections();
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kNavInset),
          children: [
            for (final s in secs) ...[
              ClubsSectionTitle(s.$1),
              for (final c in s.$2) row(c),
            ],
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      // İlk 8 satır sırayla belirir; yenileme/kaydırma geri gelen satırlar tekrar oynamaz (BuStaggerScope).
      child: BuStaggeredList(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: kNavInset),
        itemCount: list.length + (_more ? 1 : 0),
        itemBuilder: (_, k) {
          if (k >= list.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          return row(list[k]);
        },
      ),
    );
  }
}
