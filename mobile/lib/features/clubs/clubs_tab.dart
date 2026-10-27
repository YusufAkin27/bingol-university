import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'club_detail_page.dart';
import 'club_form_page.dart';
import 'club_join_flow.dart';
import '../../core/typography.dart';

/// Kulüpler sekmesi: Keşfet (GET /communities) ve Kulüplerim (GET /me/communities).
class ClubsTab extends StatefulWidget {
  const ClubsTab({super.key, required this.session});

  final Session session;

  @override
  State<ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends State<ClubsTab> {
  int _tab = 0;
  String? _category; // null = Tümü
  String _query = '';
  bool _searching = false;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<String> _categories = const [];

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
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _reload();
    _loadCategories();
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
    if (_tab == 0) {
      if (_category != null) q.add('category=${Uri.encodeQueryComponent(_category!)}');
      if (_query.isNotEmpty) q.add('q=${Uri.encodeQueryComponent(_query)}');
    }
    return '${_tab == 0 ? '/communities' : '/me/communities'}?${q.join('&')}';
  }

  /// Keşfet kategorileri sunucudan gelir (GET /communities/categories); hata çipleri gizler.
  Future<void> _loadCategories() async {
    try {
      final res = await widget.session.api.get('/communities/categories');
      if (!mounted || res is! List) return;
      final cats = <String>[
        for (final e in res)
          if (e is Map && (e['category']?.toString().trim() ?? '').isNotEmpty) e['category'].toString().trim(),
      ];
      setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _reload({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final res = await widget.session.api.get(_path(null));
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
      setState(() { _error = e; _loading = false; });
    }
  }

  Future<void> _refresh() async {
    if (_tab == 0) _loadCategories();
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
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _join(Map<String, dynamic> c) async {
    final id = (c['id'] as num).toInt();
    if (_joining.contains(id)) return;
    setState(() => _joining.add(id));
    try {
      final st = await joinClubFlow(
        context,
        widget.session,
        communityId: id,
        clubName: (c['name'] ?? '').toString(),
        needsApproval: c['joinPolicy'] == 'APPROVAL' || c['visibility'] == 'PRIVATE',
      );
      if (!mounted || st == null) return;
      setState(() {
        c['myStatus'] = st;
        if (c['myStatus'] == 'ACTIVE') c['memberCount'] = ((c['memberCount'] as num?) ?? 0).toInt() + 1;
      });
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
        builder: (_) => ClubDetailPage(session: widget.session, communityId: (c['id'] as num).toInt()),
      ),
    );
    if (mounted) _reload(silent: true);
  }

  /// Kulüp kur: form -> (ACTIVE ise kulüp sayfası / onaya gönderildi bilgisi) -> liste yenilenir.
  Future<void> _create() async {
    final created = await openCreateClub(context, widget.session);
    if (created && mounted) _reload(silent: true);
  }

  void _setTab(int i) {
    if (i == _tab) return;
    setState(() { _tab = i; _category = null; _items = []; _cursor = null; });
    _reload();
  }

  void _setCategory(String? c) {
    if (c == _category) return;
    setState(() => _category = c);
    if (_tab == 0) _reload();
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
    if (_tab == 0) {
      _reload();
    } else {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> get _visible {
    if (_tab == 0) return _items;
    return _items.where((c) {
      if (_category != null && c['category'] != _category) return false;
      if (_query.isNotEmpty && !('${c['name']}').toLowerCase().contains(_query.toLowerCase())) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final list = _visible;
    final cats = _tab == 0 ? _categories : const <String>[];
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: 'Kulüpler',
            actions: [
              BuIconButton(
                icon: LucideIcons.plus,
                tooltip: 'Kulüp kur',
                filled: true,
                onTap: _create,
              ),
              BuIconButton(
                icon: _searching ? LucideIcons.x : LucideIcons.search,
                tooltip: 'Ara',
                onTap: _toggleSearch,
              ),
            ],
          ),
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: BuSearchField(
                hint: 'Kulüp ara',
                controller: _search,
                autofocus: true,
                onSubmitted: _submitSearch,
                onChanged: (v) {
                  if (v.trim().isEmpty && _query.isNotEmpty) _submitSearch('');
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: BuSegmented(items: const ['Keşfet', 'Kulüplerim'], index: _tab, onChanged: _setTab),
          ),
          if (cats.isNotEmpty)
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  BuChip(label: 'Tümü', selected: _category == null, onTap: () => _setCategory(null)),
                  for (final c in cats) ...[
                    const SizedBox(width: 8),
                    BuChip(label: c, selected: _category == c, onTap: () => _setCategory(c)),
                  ],
                ],
              ),
            ).withTop(14),
          Expanded(child: _body(list)),
        ],
      ),
    );
  }

  Widget _body(List<Map<String, dynamic>> list) {
    if (_loading) return const LoadingView();
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error!, onRetry: _reload);
    }
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kNavInset),
          children: [
            SizedBox(
              height: 360,
              child: EmptyView(
                icon: LucideIcons.users,
                text: _tab == 1 ? 'Henüz hiçbir kulübe üye değilsin.' : 'Kulüp bulunamadı.',
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, kNavInset),
        itemCount: list.length + (_more ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i >= list.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final c = list[i];
          return _ClubCard(
            club: c,
            busy: _joining.contains((c['id'] as num).toInt()),
            onOpen: () => _open(c),
            onJoin: () => _join(c),
          );
        },
      ),
    );
  }
}

extension on Widget {
  Widget withTop(double v) => Padding(padding: EdgeInsets.only(top: v), child: this);
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.club, required this.busy, required this.onOpen, required this.onJoin});

  final Map<String, dynamic> club;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final name = (club['name'] as String?) ?? '';
    final category = (club['category'] as String?)?.trim() ?? '';
    final count = ((club['memberCount'] as num?) ?? 0).toInt();
    final status = (club['myStatus'] as String?) ?? 'NONE';
    final sub = [if (category.isNotEmpty) category, '$count üye'].join(' · ');
    final logo = (club['logoUrl'] as String?) ?? (club['coverUrl'] as String?);
    final cover = fileUrl(club['coverUrl'] as String?);
    final member = status == 'ACTIVE';

    final button = _statusButton(status);

    if (status == 'PENDING') {
      // Tasarımdaki kapaksız satır görünümü (istek gönderildi).
      return BuCard(
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: onOpen,
        child: Row(
          children: [
            BuAvatar(name: name, url: club['logoUrl'] as String?, size: 48, square: true),
            const SizedBox(width: 12),
            Expanded(child: _titles(t, name, sub, 15)),
            const SizedBox(width: 8),
            button,
          ],
        ),
      );
    }

    return BuCard(
      radius: 22,
      padding: EdgeInsets.zero,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 74,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null)
                    Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _cover(t, member))
                  else
                    _cover(t, member),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(0, -22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: t.sf,
                          borderRadius: BorderRadius.circular(19),
                          boxShadow: const [BoxShadow(color: Color(0x26171E33), blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: BuAvatar(name: name, url: logo, size: 42, square: true),
                      ),
                      const Spacer(),
                      button,
                    ],
                  ),
                ),
                Transform.translate(offset: const Offset(0, -12), child: _titles(t, name, sub, 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cover(BuTokens t, bool member) {
    return Container(
      decoration: BoxDecoration(
        color: member ? t.ink : null,
        gradient: member ? null : t.hero,
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Transform.translate(
          offset: const Offset(20, -30),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: member ? .10 : .15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titles(BuTokens t, String name, String sub, double size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BuType.title.copyWith(fontSize: size, color: t.ink)),
        const SizedBox(height: 3),
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut)),
      ],
    );
  }

  Widget _statusButton(String status) {
    switch (status) {
      case 'ACTIVE':
        return BuButton(label: 'Üyesin', kind: BuButtonKind.soft, compact: true, onPressed: onOpen);
      case 'PENDING':
        return BuButton(label: 'İstek gönderildi', kind: BuButtonKind.outline, compact: true, onPressed: onOpen);
      case 'BANNED':
        return const BuButton(label: 'Engelli', kind: BuButtonKind.outline, compact: true);
      default:
        return BuButton(label: 'Katıl', compact: true, busy: busy, onPressed: busy ? null : onJoin);
    }
  }
}
