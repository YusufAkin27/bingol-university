import 'dart:async';

import '../../core/analytics.dart';
import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'club_actions.dart';
import 'club_categories.dart';
import 'club_detail_page.dart';
import 'club_detail_parts.dart' show ClubBarIcon;
import 'club_form_page.dart';
import 'club_join_flow.dart';
import 'clubs_widgets.dart';

/// Keşfet listesi sıralaması (sunucuda sıralama parametresi yok: yüklenen kayıtlar üzerinde istemci tarafında).
enum ClubSort { popular, newest, az }

/// Arama / sıralama için Türkçe karakterleri sadeleştirir ("kulup" -> "Kulüp" eşleşir).
String clubFold(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    b.write(switch (c) {
      'İ' || 'I' || 'ı' => 'i',
      'Ç' || 'ç' => 'c',
      'Ğ' || 'ğ' => 'g',
      'Ö' || 'ö' => 'o',
      'Ş' || 'ş' => 's',
      'Ü' || 'ü' => 'u',
      _ => c.toLowerCase(),
    });
  }
  return b.toString();
}

/// [list]'in sıralı kopyası. "Yeni": `createdAt` azalan (yoksa sunucu sırası); "Popüler": üye sayısı azalan; "A-Z": ad.
List<Map<String, dynamic>> sortClubs(List<Map<String, dynamic>> list, ClubSort sort) {
  final idx = <Map<String, dynamic>, int>{for (var i = 0; i < list.length; i++) list[i]: i};
  int byIndex(Map<String, dynamic> a, Map<String, dynamic> b) => idx[a]!.compareTo(idx[b]!);
  int count(Map<String, dynamic> c) => ((c['memberCount'] as num?) ?? 0).toInt();
  DateTime? created(Map<String, dynamic> c) => DateTime.tryParse('${c['createdAt'] ?? ''}');
  final out = [...list];
  out.sort((a, b) {
    switch (sort) {
      case ClubSort.popular:
        final d = count(b).compareTo(count(a));
        return d != 0 ? d : byIndex(a, b);
      case ClubSort.newest:
        final x = created(a), y = created(b);
        if (x != null && y != null) {
          final d = y.compareTo(x);
          if (d != 0) return d;
        }
        return byIndex(a, b);
      case ClubSort.az:
        final d = clubFold('${a['name'] ?? ''}').compareTo(clubFold('${b['name'] ?? ''}'));
        return d != 0 ? d : byIndex(a, b);
    }
  });
  return out;
}

/// Kulüpler sekmesi: Keşfet (GET /communities) ve Kulüplerim (GET /me/communities).
///
/// Arama kutusu hep görünür: yazdıkça yüklenen kulüpler anında süzülür, kısa bir bekleme sonrası sunucu `q` ile de
/// aranır. Kategori çipleri, sıralama (Popüler / Yeni / A-Z), imleçli sayfalama ve çekerek yenileme.
class ClubsTab extends StatefulWidget {
  const ClubsTab({super.key, required this.session});

  final Session session;

  @override
  State<ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends State<ClubsTab> {
  String? _category; // null = Tümü
  int _seg = 0; // 0 Keşfet, 1 Kulüplerim
  ClubSort _sort = ClubSort.popular;

  /// Sunucuya giden arama (bekleme sonrası); [_typed] kutudaki anlık metin (istemci süzgeci).
  /// Sunucu araması Türkçe karakterleri sadeleştirmeyebilir ("kulup" -> "Kulüp"), bu yüzden sonuçları [_items]'ı
  /// ezmez: ayrı tutulur ([_remote]) ve yüklü kulüplerin istemci süzgeciyle BİRLEŞTİRİLİR.
  String _query = '';
  List<Map<String, dynamic>> _remote = const [];
  int _rgen = 0;
  String _typed = '';
  Timer? _debounce;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<ClubCategory> _categories = const [];
  List<Map<String, dynamic>> _mine = [];

  /// "Bölümüne uygun kulüpler" (GET /communities/recommended): yalnız öneri, boşsa şerit hiç çizilmez.
  List<Map<String, dynamic>> _rec = const [];

  List<Map<String, dynamic>> _items = [];
  String? _cursor;
  bool _loading = true;
  bool _more = false;
  Object? _error;
  int _gen = 0; // eski yanıtları yok saymak için
  final Set<int> _joining = {};

  static const _searchDebounce = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _reload();
    _loadCategories();
    _loadMine();
    _loadRec();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _path(String? cursor, {String? search}) {
    final q = <String>['size=20'];
    if (cursor != null) q.add('cursor=${Uri.encodeQueryComponent(cursor)}');
    if (_category != null) {
      q.add('category=${Uri.encodeQueryComponent(_category!)}');
    }
    if (search != null && search.isNotEmpty) q.add('q=${Uri.encodeQueryComponent(search)}');
    return '/communities?${q.join('&')}';
  }

  /// Sunucu araması (ilk sayfa); hata sessizce yok sayılır, yüklü kulüplerin istemci süzgeci yine çalışır.
  Future<void> _loadRemote() async {
    final gen = ++_rgen;
    final q = _query;
    if (q.isEmpty) {
      if (_remote.isNotEmpty) setState(() => _remote = const []);
      return;
    }
    try {
      final res = await widget.session.api.get(_path(null, search: q), force: true);
      if (!mounted || gen != _rgen) return;
      setState(() => _remote = _parse(res));
    } catch (_) {
      if (mounted && gen == _rgen) setState(() => _remote = const []);
    }
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
        _loadRemote();
      }
    });
  }

  Future<void> _loadRec() async {
    try {
      final res = await widget.session.api.get('/communities/recommended?size=3');
      if (!mounted) return;
      setState(() => _rec = _parse(res));
    } catch (_) {
      // En iyi çaba: öneri gelmezse şerit çizilmez.
    }
  }

  /// "Kulüplerim" şeridi (GET /me/communities); hata şeridi gizler.
  Future<void> _loadMine() async {
    try {
      final res = await widget.session.api.get('/me/communities?size=50');
      if (!mounted) return;
      setState(() => _mine = _parse(res));
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
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
    _loadRec();
    if (_query.isNotEmpty) _loadRemote();
    await _reload(silent: true);
  }

  Future<void> _loadMore() async {
    if (_more || _loading || _cursor == null || _seg != 0) return;
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
    BuToast.show(context, msg);
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
        // Aynı kulüp hem yüklü listede hem arama sonuçlarında olabilir: ikisini de güncelle.
        final done = Set<Map<String, dynamic>>.identity();
        for (final m in [c, ..._items, ..._remote]) {
          if (_id(m) != id || !done.add(m)) continue;
          m['myStatus'] = st;
          if (st == 'ACTIVE') m['memberCount'] = ((m['memberCount'] as num?) ?? 0).toInt() + 1;
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
      MaterialPageRoute(settings: const RouteSettings(name: 'club_detail'),
        builder: (_) => ClubDetailPage(
          session: widget.session,
          communityId: ((c['id'] as num?)?.toInt() ?? -1),
        ),
      ),
    );
    if (mounted) {
      _reload(silent: true);
      _loadMine();
      if (_query.isNotEmpty) _loadRemote();
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
    if (_query.isNotEmpty) _loadRemote();
  }

  void _setSeg(int i) {
    if (i == _seg) return;
    setState(() => _seg = i);
    // Kulüplerim'deyken yazılan arama yalnız istemcide süzülür; Keşfet'e dönünce sunucu araması eşitlenir.
    if (i == 0) _syncQuery();
  }

  void _onTyped(String v) {
    final t = v.trim();
    if (t == _typed) return;
    setState(() => _typed = t);
    _debounce?.cancel();
    if (_seg != 0) return;
    // Silme anında hemen (sonuçlar zaten yüklü), yazarken kısa beklemeyle sunucuya sor.
    if (t.isEmpty) {
      _syncQuery();
    } else {
      _debounce = Timer(_searchDebounce, _syncQuery);
    }
  }

  void _syncQuery() {
    if (!mounted || _typed == _query) return;
    _query = _typed;
    _loadRemote();
  }

  void _submitSearch(String v) {
    _debounce?.cancel();
    _typed = v.trim();
    if (_seg == 0) _syncQuery();
    setState(() {});
  }

  int _id(Map<String, dynamic> c) => ((c['id'] as num?)?.toInt() ?? -1);

  bool _matches(Map<String, dynamic> c) {
    if (_typed.isEmpty) return true;
    final q = clubFold(_typed);
    final hay = clubFold('${c['name'] ?? ''} ${c['description'] ?? ''} ${ClubCategories.labelFor(c['category'] as String?)}');
    return hay.contains(q);
  }

  /// Keşfet: yüklenenler (anlık arama süzgeci) + sunucu arama sonuçları (tekrarsız), sonra sıralama.
  /// Kutudaki metin sunucuya gidenle aynıysa sunucu sonuçlarının hepsi, değilse (yazmaya devam ediliyor) yalnız
  /// süzgece uyanlar alınır.
  List<Map<String, dynamic>> get _discover {
    final seen = <int>{};
    final out = <Map<String, dynamic>>[];
    for (final c in _items) {
      if (_matches(c) && seen.add(_id(c))) out.add(c);
    }
    if (_typed.isNotEmpty) {
      final trust = _typed == _query;
      for (final c in _remote) {
        if ((trust || _matches(c)) && seen.add(_id(c))) out.add(c);
      }
    }
    return sortClubs(out, _sort);
  }

  /// "Kulüplerim" sekmesi: /me/communities + keşfet listesindeki ACTIVE olanlar.
  List<Map<String, dynamic>> get _strip {
    final seen = <int>{};
    final out = <Map<String, dynamic>>[];
    for (final c in [..._mine, ..._items.where((c) => c['myStatus'] == 'ACTIVE')]) {
      if (!seen.add(_id(c))) continue;
      if (!_matches(c)) continue;
      out.add(c);
    }
    return out;
  }

  String _sortName(AppLocalizations l) => switch (_sort) {
        ClubSort.popular => l.clsSortPopular,
        ClubSort.newest => l.clsSortNewest,
        ClubSort.az => l.clsSortAz,
      };

  Future<void> _pickSort() async {
    final l = context.l10n;
    final v = await BuSheet.show<ClubSort>(
      context,
      title: l.clsSortTitle,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in ClubSort.values)
            _SortOption(
              key: ValueKey('clubSort-${s.name}'),
              label: switch (s) {
                ClubSort.popular => l.clsSortPopular,
                ClubSort.newest => l.clsSortNewest,
                ClubSort.az => l.clsSortAz,
              },
              selected: s == _sort,
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (v != null && mounted && v != _sort) setState(() => _sort = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          // Başlık: ekran adı görünmez (yalnız ekran okuyucu etiketi; tasarım sadeleştirmesi); sağda marka renkli "Kulüp kur".
          Padding(
            // Başka sayfadan açıldıysa (Etkinlikler, Kulüplerim, etkinlik formu) sol başa geri oku konur.
            padding: EdgeInsetsDirectional.fromSTEB(canPop ? 8 : 20, MediaQuery.paddingOf(context).top + 16, 8, 0),
            child: Row(
              children: [
                if (canPop) ...[
                  ClubBarIcon(icon: BuIcons.arrowLeft, tooltip: l.commonBack, onTap: () => Navigator.maybePop(context), width: 40),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Semantics(header: true, label: l.clubMgmtClubsTitle, child: const SizedBox(height: 48)),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: t.prText, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  onPressed: _create,
                  child: Text(l.clubMgmtCreateTitle, style: tx.bodyLarge!.copyWith(color: t.prText, fontWeight: FontWeight.w400)),
                ),
              ],
            ),
          ),
          const BuStaleStrip(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: BuSearchField(
              key: const ValueKey('clubsSearch'),
              hint: l.clubMgmtSearchClub,
              controller: _search,
              onChanged: _onTyped,
              onSubmitted: _submitSearch,
            ),
          ),
          ClubTextTabs(
            labels: [l.clubMgmtTabDiscover, l.clubMgmtTabMine],
            index: _seg,
            onChanged: _setSeg,
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    // İskelet -> içerik solarak; Keşfet <-> Kulüplerim geçişinde içerik "fade through" ile yer değiştirir.
    return BuSwapIn(
      loading: _loading && _seg == 0,
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

  /// Durum metni (boş / hata) çekerek yenilenebilir bir alanda.
  Widget _stateScroll(Widget state, {double reserve = 0}) => RefreshIndicator(
        onRefresh: Analytics.pullRefresh(_refresh),
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: kNavInset),
            children: [SizedBox(height: (c.maxHeight - kNavInset - reserve).clamp(240.0, double.infinity), child: state)],
          ),
        ),
      );

  /// Kategori çipleri + (sayı · sıralama) satırı: Keşfet listesinin ilk iki öğesi (liste ile birlikte kayar).
  Widget _filters(int shown) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cats = _categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cats.isNotEmpty)
          // BuChip: görünür 34 dp, dokunma alanı 48 dp (kutu 48 dp, yazı kırpılmaz).
          SizedBox(
            height: 48,
            child: ListView(
              key: const ValueKey('clubsCategoryChips'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
              children: [
                BuChip(label: l.clubMgmtAll, selected: _category == null, onTap: () => _setCategory(null)),
                for (final c in cats) ...[
                  const SizedBox(width: 8),
                  BuChip(label: c.name, selected: _category == c.key, onTap: () => _setCategory(c.key)),
                ],
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(l.clsCount('$shown'), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13)),
              ),
              Semantics(
                button: true,
                excludeSemantics: true,
                label: l.clsSortLabel(_sortName(l)),
                onTap: _pickSort,
                child: InkWell(
                  key: const ValueKey('clubsSortButton'),
                  borderRadius: BuRadius.bXs,
                  onTap: _pickSort,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                          child: Text(l.clsSortLabel(_sortName(l)),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
                        ),
                        const SizedBox(width: 4),
                        Icon(BuIcons.chevronDown, size: 16, color: t.mut),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: t.bd),
      ],
    );
  }

  Widget _content() {
    final l = context.l10n;
    final mine = _seg == 1;
    if (!mine && _error != null && _items.isEmpty) {
      final e = _error!;
      // Ağ yok / bakım: sunucu ya da istemci metni; diğer hatalarda kısa genel metin.
      final detailed = e is ApiError && (e.status == 503 || e.isNetwork);
      return _stateScroll(ClubsStateText(
        text: detailed ? errorText(e) : l.p51ClubsLoadFailed,
        actionLabel: l.commonRetry,
        onAction: _reload,
      ));
    }
    Widget row(Map<String, dynamic> c) => ClubsRowCard(
          club: c,
          mine: mine,
          busy: _joining.contains(_id(c)),
          showDescription: !mine,
          onOpen: () => _open(c),
          onJoin: () => _join(c),
        );
    if (mine) {
      final list = _strip;
      if (list.isEmpty) {
        return _stateScroll(_typed.isNotEmpty
            ? ClubsStateText(text: l.clubMgmtNotFound)
            : ClubsStateText(text: l.clubMgmtEmptyMine, actionLabel: l.kuluplerAllClubs, onAction: () => _setSeg(0)));
      }
      // Bölümlü kısa liste (kaydırma sayfalaması yok).
      final secs = _sections();
      return RefreshIndicator(
        onRefresh: Analytics.pullRefresh(_refresh),
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
    final all = _discover;
    // Öneri şeridi açıkken önerilenler ana listede tekrarlanmaz.
    final showRec = all.isNotEmpty && _rec.isNotEmpty && _typed.isEmpty && _category == null;
    final recIds = showRec ? <Object?>{for (final r in _rec) _id(r)} : const <Object?>{};
    final list = showRec ? [for (final c in all) if (!recIds.contains(_id(c))) c] : all;
    // Ağ hatası olsa da elde kulüp varsa liste gösterilir (çevrimdışı/önbellek); aksi halde boş durum.
    final emptyState = all.isEmpty
        ? (_typed.isNotEmpty || _category != null
            ? ClubsStateText(text: l.clubMgmtNotFound, actionLabel: _typed.isNotEmpty ? null : l.clubMgmtAll, onAction: _typed.isNotEmpty ? null : () => _setCategory(null))
            : ClubsStateText(text: l.p51ClubsEmpty, actionLabel: l.clubMgmtCreateTitle, onAction: _create))
        : null;
    return RefreshIndicator(
      onRefresh: Analytics.pullRefresh(_refresh),
      // İlk 8 öğe sırayla belirir; yenileme/kaydırma geri gelen satırlar tekrar oynamaz (BuStaggerScope).
      child: LayoutBuilder(
        builder: (context, c) => BuStaggeredList(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kNavInset),
          maxAnimated: 10,
          itemCount: 1 + (showRec ? 1 : 0) + (emptyState != null ? 1 : list.length + (_more ? 1 : 0)),
          itemBuilder: (_, k) {
            if (k == 0) return _filters(all.length);
            if (showRec && k == 1) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClubsSectionTitle(l.clubRecommendedTitle, top: 8),
                for (final c in _rec) row(c),
                ClubsSectionTitle(l.clubRecommendedAll, top: 8),
              ]);
            }
            if (emptyState != null) return SizedBox(height: (c.maxHeight - kNavInset - 110).clamp(200.0, double.infinity), child: emptyState);
            final i = k - 1 - (showRec ? 1 : 0);
            if (i >= list.length) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            return row(list[i]);
          },
        ),
      ),
    );
  }
}

/// Sıralama seçeneği satırı (alt sayfa): ad + seçiliyse onay işareti; 56 dp.
class _SortOption extends StatelessWidget {
  const _SortOption({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: InkWell(
        onTap: () {
          buHaptic(BuHaptic.selection);
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(children: [
            Expanded(child: Text(label, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400))),
            if (selected) Icon(BuIcons.check, size: 20, color: t.ink),
          ]),
        ),
      ),
    );
  }
}
