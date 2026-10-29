import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../clubs/club_detail_page.dart';
import '../events/event_detail_page.dart';
import '../news/icerik_parts.dart';
import '../news/news_detail_page.dart';
import '../news/news_tile.dart' show newsLocalDate, newsMonthName;
import '../posts/post_routes.dart';
import '../profile/user_profile_page.dart';

/// Genel arama: haber/duyuru, kulüp, etkinlik, gönderi ve kişi.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.session});

  final Session session;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

/// Tek tip sonuç satırı (hem /search hem /users/search'ten).
class _Hit {
  _Hit({required this.type, required this.id, required this.title, this.snippet, this.date, this.imageUrl});

  final String type; // NEWS, ANNOUNCEMENT, EVENT_OFFICIAL, COMMUNITY, EVENT, POSTS, USER
  final int id;
  final String title;
  final String? snippet;
  final String? date;
  final String? imageUrl;
}

enum _Tab { all, news, club, event, post, person }

/// Sekme çiplerinin görünüm sırası (Ic1: Tümü, Haber, Etkinlik, Kulüp, Kişi; Gönderi sona eklendi).
const _tabOrder = [_Tab.all, _Tab.news, _Tab.event, _Tab.club, _Tab.person, _Tab.post];

String _tabLabel(AppLocalizations l, _Tab tab) => switch (tab) {
      _Tab.all => l.searchAll,
      _Tab.news => l.newsTypeNews,
      _Tab.club => l.searchClub,
      _Tab.event => l.newsTypeEvent,
      _Tab.post => l.searchPost,
      _Tab.person => l.searchPerson,
    };

_Tab _tabOf(String type) {
  switch (type) {
    case 'NEWS':
    case 'ANNOUNCEMENT':
      return _Tab.news;
    case 'COMMUNITY':
      return _Tab.club;
    case 'EVENT':
    case 'EVENT_OFFICIAL':
      return _Tab.event;
    case 'POSTS':
    case 'POST':
      return _Tab.post;
    default:
      return _Tab.person;
  }
}

String _badgeOf(AppLocalizations l, String type) {
  switch (type) {
    case 'NEWS':
      return l.newsTypeNews;
    case 'ANNOUNCEMENT':
      return l.newsTypeAnnouncement;
    case 'COMMUNITY':
      return l.searchClub;
    case 'EVENT':
    case 'EVENT_OFFICIAL':
      return l.newsTypeEvent;
    case 'POSTS':
    case 'POST':
      return l.searchPost;
    default:
      return l.searchPerson;
  }
}

IconData _iconOf(String type) {
  switch (type) {
    case 'ANNOUNCEMENT':
      return LucideIcons.megaphone;
    default:
      break;
  }
  switch (_tabOf(type)) {
    case _Tab.news:
      return LucideIcons.newspaper;
    case _Tab.club:
      return LucideIcons.users;
    case _Tab.event:
      return LucideIcons.calendar;
    case _Tab.post:
      return LucideIcons.image;
    default:
      return LucideIcons.user;
  }
}

/// Sonuç türüne göre simge karosu tonu (haber marka tonu, diğerleri kategori renkleri).
BuTint _tintOf(BuTokens t, String type) {
  if (type == 'ANNOUNCEMENT') return t.tint(2);
  return switch (_tabOf(type)) {
    _Tab.news => BuTint(t.soft, t.onSoft),
    _Tab.club => t.tint(0),
    _Tab.event => t.tint(1),
    _Tab.post => t.tint(3),
    _ => t.tint(4),
  };
}

/// Sekme başına sayfalama durumu (Tümü hariç).
class _TabData {
  final List<_Hit> hits = [];
  int typeIdx = 0; // sekmenin birden çok türü varsa sıradaki tür
  int? cursor;
  bool loaded = false;
  bool loading = false;
  bool done = false;
  Object? error; // ilk yükleme hatası
  bool moreError = false; // 'daha fazla' hatası (liste kalır)
  DateTime? cooldownUntil; // 429 sonrası bekleme
}

/// Sekme -> /search type değerleri (Kişi ayrı uçtan gelir).
const _tabTypes = <_Tab, List<String>>{
  _Tab.news: ['NEWS', 'ANNOUNCEMENT'],
  _Tab.club: ['COMMUNITY'],
  _Tab.event: ['EVENT', 'EVENT_OFFICIAL'],
  _Tab.post: ['POSTS'],
};

_Hit _hitFromSearch(Map h) => _Hit(
      type: '${h['type']}',
      id: (h['targetId'] as num).toInt(),
      title: '${h['title'] ?? ''}',
      snippet: h['snippet'] as String?,
      date: h['date'] as String?,
      imageUrl: h['imageUrl'] as String?,
    );

_Hit _hitFromUser(Map u, AppLocalizations l) {
  final sub = [u['faculty'], u['department'], if (u['classYear'] != null) l.searchClassYear('${u['classYear']}')]
      .where((e) => e != null && '$e'.isNotEmpty)
      .join(' · ');
  return _Hit(
    type: 'USER',
    id: (u['id'] as num).toInt(),
    title: '${u['displayName'] ?? l.searchUserDefault}',
    snippet: sub.isEmpty ? null : sub,
    imageUrl: u['avatarUrl'] as String?,
  );
}

/// Düz sonuç listesi öğesi: grup başlığı ya da (gruplu kartın parçası olan) sonuç satırı.
class _Entry {
  const _Entry.header(this.tab, this.count, this.more)
      : hit = null,
        first = false,
        last = false;
  const _Entry.row(this.hit, {required this.first, required this.last})
      : tab = null,
        count = 0,
        more = false;

  final _Tab? tab;
  final int count;
  final bool more;
  final _Hit? hit;
  final bool first;
  final bool last;
}

class _SearchPageState extends State<SearchPage> {
  static const _recentKey = 'recent_searches';
  static const _storage = FlutterSecureStorage();
  static const _pageSize = 20;

  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  int _seq = 0; // eski yanıtları yok saymak için

  _Tab _tab = _Tab.all;
  List<String> _recent = [];
  List<_Hit> _hits = []; // Tümü sekmesi
  final Map<_Tab, _TabData> _tabs = {};
  bool _loading = false;
  Object? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_tab == _Tab.all || !_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _loadMore(_tab);
  }

  Future<void> _loadRecent() async {
    try {
      final raw = await _storage.read(key: _recentKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List).map((e) => e.toString()).take(8).toList();
      if (mounted) setState(() => _recent = list);
    } catch (_) {}
  }

  Future<void> _saveRecent(String q) async {
    final list = [q, ..._recent.where((e) => e.toLowerCase() != q.toLowerCase())].take(8).toList();
    if (mounted) setState(() => _recent = list);
    try {
      await _storage.write(key: _recentKey, value: jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = []);
    try {
      await _storage.delete(key: _recentKey);
    } catch (_) {}
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      _seq++;
      setState(() {
        _query = '';
        _hits = [];
        _tabs.clear();
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  void _submit(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.length >= 2) _run(q);
  }

  void _useRecent(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    _debounce?.cancel();
    _run(q);
  }

  void _selectTab(_Tab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_query.isEmpty) return;
    if (tab == _Tab.all) {
      if (_hits.isEmpty) _run(_query);
    } else if (!(_tabs[tab]?.loaded ?? false)) {
      _loadMore(tab);
    }
  }

  /// Yeni sorgu: Tümü sekmesi gruplu yanıtı çeker; tür sekmeleri sıfırlanır.
  Future<void> _run(String q) async {
    if (q.length < 2) return;
    final seq = ++_seq;
    final l = context.l10n;
    setState(() {
      // Sorgu hemen kaydedilir: hata olursa "Yeniden dene" aynı sorguyu tekrarlayabilsin.
      _query = q;
      _loading = true;
      _error = null;
      _tabs.clear();
    });
    if (_tab != _Tab.all) {
      // Tür sekmesi açıkken doğrudan o sekmeyi sayfalı yükle.
      setState(() {
        _query = q;
        _hits = [];
        _loading = false;
      });
      _saveRecent(q);
      await _loadMore(_tab);
      return;
    }
    try {
      final enc = Uri.encodeQueryComponent(q);
      final api = widget.session.api;
      final res = await Future.wait<dynamic>([
        api.get('/search?q=$enc&limit=$_pageSize'),
        api.get('/users/search?q=$enc&size=$_pageSize').catchError((_) => <String, dynamic>{'items': []}),
      ]);
      if (!mounted || seq != _seq) return;
      final hits = <_Hit>[];
      final groups = (res[0] is Map ? res[0]['groups'] : null) as List? ?? [];
      for (final g in groups) {
        final items = (g is Map ? g['items'] : null) as List? ?? [];
        for (final h in items) {
          if (h is! Map || h['targetId'] == null) continue;
          hits.add(_hitFromSearch(h));
        }
      }
      final users = (res[1] is Map ? res[1]['items'] : null) as List? ?? [];
      for (final u in users) {
        if (u is! Map || u['id'] == null) continue;
        hits.add(_hitFromUser(u, l));
      }
      setState(() {
        _query = q;
        _hits = hits;
        _loading = false;
      });
      _saveRecent(q);
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Tür sekmesinin sıradaki sayfasını getirir (ilk yükleme dahil).
  Future<void> _loadMore(_Tab tab) async {
    final d = _tabs.putIfAbsent(tab, _TabData.new);
    if (d.loading || d.done || _query.isEmpty) return;
    final cool = d.cooldownUntil;
    if (cool != null && DateTime.now().isBefore(cool)) return;
    final seq = _seq;
    final q = _query;
    final l = context.l10n;
    setState(() {
      d.loading = true;
      d.error = null;
      d.moreError = false;
    });
    try {
      final enc = Uri.encodeQueryComponent(q);
      final api = widget.session.api;
      final fresh = <_Hit>[];
      // Boş sayfa gelirse (bir tür tükendi) sıradaki türe geç.
      for (var guard = 0; guard < 3 && fresh.isEmpty && !d.done; guard++) {
        final c = d.cursor == null ? '' : '&cursor=${d.cursor}';
        int? next;
        if (tab == _Tab.person) {
          final r = await api.get('/users/search?q=$enc&size=$_pageSize$c');
          if (!mounted || seq != _seq) return;
          for (final u in (r is Map ? r['items'] : null) as List? ?? []) {
            if (u is Map && u['id'] != null) fresh.add(_hitFromUser(u, l));
          }
          next = (r is Map ? r['nextCursor'] as num? : null)?.toInt();
          if (next == null || next > 200) {
            d.done = true;
            d.cursor = null;
          } else {
            d.cursor = next;
          }
        } else {
          final types = _tabTypes[tab]!;
          final r = await api.get('/search?q=$enc&type=${types[d.typeIdx]}&limit=$_pageSize$c');
          if (!mounted || seq != _seq) return;
          for (final g in (r is Map ? r['groups'] : null) as List? ?? []) {
            for (final h in (g is Map ? g['items'] : null) as List? ?? []) {
              if (h is Map && h['targetId'] != null) fresh.add(_hitFromSearch(h));
            }
          }
          next = (r is Map ? r['nextCursor'] as num? : null)?.toInt();
          if (next != null) {
            d.cursor = next;
          } else {
            d.cursor = null;
            d.typeIdx++;
            if (d.typeIdx >= types.length) d.done = true;
          }
        }
      }
      setState(() {
        d.hits.addAll(fresh);
        d.loaded = true;
        d.loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        d.loading = false;
        if (e is ApiError && e.status == 429) {
          d.cooldownUntil = DateTime.now().add(const Duration(seconds: 15));
        }
        if (d.loaded) {
          d.moreError = true;
        } else {
          d.error = e;
        }
      });
    }
  }

  void _open(_Hit h) {
    final s = widget.session;
    Widget page;
    switch (h.type) {
      case 'NEWS':
      case 'ANNOUNCEMENT':
      case 'EVENT_OFFICIAL':
        page = NewsDetailPage(session: s, item: {
          'id': h.id,
          'title': h.title,
          'type': h.type == 'EVENT_OFFICIAL' ? 'EVENT' : h.type,
          'imageUrl': h.imageUrl,
          'publishedDate': h.date,
        });
        break;
      case 'COMMUNITY':
        page = ClubDetailPage(session: s, communityId: h.id);
        break;
      case 'EVENT':
        page = EventDetailPage(session: s, eventId: h.id);
        break;
      case 'POSTS':
      case 'POST':
        openPostDetail(context, s, h.id);
        return;
      default:
        openUserProfile(context, s, userId: h.id, name: h.title, avatarUrl: h.imageUrl);
        return;
    }
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final active = _query.isNotEmpty || _loading || _error != null;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(12, MediaQuery.paddingOf(context).top + 8, 20, 4),
            child: Row(children: [
              IcerikIconButton(
                  icon: buDirIcon(context, LucideIcons.arrowLeft),
                  label: l.authBack,
                  onTap: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              Expanded(
                child: BuSearchField(
                  hint: l.searchHint,
                  controller: _ctrl,
                  autofocus: true,
                  onChanged: _onChanged,
                  onSubmitted: _submit,
                ),
              ),
            ]),
          ),
          AnimatedSize(
            duration: BuMotion.of(context, BuMotion.medium),
            curve: BuMotion.emphasized,
            alignment: Alignment.topCenter,
            child: active
                ? Semantics(
                    container: true,
                    label: l.icerikSearchTabs,
                    child: BuChipRow(
                      labels: [for (final tab in _tabOrder) _tabLabel(l, tab)],
                      selected: _tabOrder.indexOf(_tab),
                      onSelected: (i) => _selectTab(_tabOrder[i]),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (active && _loading && _query.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          Expanded(child: active ? _results(t) : _suggestions(t)),
        ],
      ),
    );
  }

  Widget _suggestions(BuTokens t) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    if (_recent.isEmpty) {
      return BuEmptyState(illustration: BuIllustration.search, title: l.p05SearchIdleTitle, message: l.searchPrompt);
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        BuSectionHeader(l.searchRecent,
            action: l.searchClearRecent, onAction: _clearRecent, padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 0, 4)),
        IcerikCard(
          shadow: false,
          child: Column(children: [
            for (var i = 0; i < _recent.length; i++)
              InkWell(
                onTap: () => _useRecent(_recent[i]),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 8, 6),
                  decoration: i == 0 ? null : BoxDecoration(border: Border(top: BorderSide(color: t.bd.withValues(alpha: .7)))),
                  child: Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                      child: Icon(LucideIcons.clock, size: 15, color: t.mut),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_recent[i],
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w600, color: t.ink)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Directionality.of(context) == TextDirection.rtl ? LucideIcons.arrowUpRight : LucideIcons.arrowUpLeft, size: 16, color: t.mut),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 28),
        const Center(child: BuIllustrationView(BuIllustration.search, size: 96)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(l.searchPrompt, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45)),
        ),
      ],
    );
  }

  /// Tümü sekmesindeki grup başlığı ve etiketi.
  String _groupLabel(AppLocalizations l, _Tab tab) => switch (tab) {
        _Tab.news => l.icerikGroupNews,
        _Tab.club => l.icerikGroupClub,
        _Tab.event => l.icerikGroupEvent,
        _Tab.post => l.icerikGroupPost,
        _ => l.icerikGroupPerson,
      };

  List<_Entry> _entriesFor(List<_Hit> visible, {required bool paged, required bool more}) {
    final out = <_Entry>[];
    void group(_Tab tab, List<_Hit> hits, bool more) {
      out.add(_Entry.header(tab, hits.length, more));
      for (var i = 0; i < hits.length; i++) {
        out.add(_Entry.row(hits[i], first: i == 0, last: i == hits.length - 1));
      }
    }

    if (paged) {
      group(_tab, visible, more);
    } else {
      for (final tab in _tabOrder) {
        if (tab == _Tab.all) continue;
        final g = [for (final h in visible) if (_tabOf(h.type) == tab) h];
        if (g.isNotEmpty) group(tab, g, false);
      }
    }
    return out;
  }

  Widget _results(BuTokens t) {
    final l = context.l10n;
    final paged = _tab != _Tab.all;
    final d = paged ? _tabs[_tab] : null;
    final error = paged ? d?.error : _error;
    if (error != null) {
      return BuErrorState(error: error, onRetry: () => paged ? _retryTab(_tab) : _run(_query));
    }
    final visible = paged ? (d?.hits ?? const <_Hit>[]) : _hits;
    if (paged ? (d == null || !d.loaded) : (_loading && _hits.isEmpty)) {
      return const BuSkeletonList(itemCount: 7);
    }
    if (visible.isEmpty) {
      return BuEmptyState(illustration: BuIllustration.search, title: l.searchNoResults, message: l.p05SearchNoResultsBody);
    }
    final more = paged && !(d?.done ?? true);
    final entries = _entriesFor(visible, paged: paged, more: more);
    return RefreshIndicator(
      color: t.pr,
      backgroundColor: t.sf3,
      onRefresh: () => paged ? _retryTab(_tab) : _run(_query),
      child: BuStaggerScope(
        key: ValueKey('$_seq-${_tab.name}'),
        child: CustomScrollView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final e = entries[i];
                  if (e.hit == null) return _header(t, e);
                  return BuStaggerItem(index: i, child: _row(t, e.hit!, first: e.first, last: e.last));
                },
              ),
            ),
            if (paged) SliverToBoxAdapter(child: _footer(t, d!)),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuTokens t, _Entry e) {
    final l = context.l10n;
    final tab = e.tab!;
    final text = '${_groupLabel(l, tab)} · ${l.searchResultCount('${e.count}${e.more ? '+' : ''}')}';
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 18, bottom: 8),
      child: Row(children: [
        Expanded(child: Semantics(header: true, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: icerikSectionStyle(t)))),
        if (_tab == _Tab.all)
          TextButton(
            style: TextButton.styleFrom(
                minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12), tapTargetSize: MaterialTapTargetSize.padded),
            onPressed: () => _selectTab(tab),
            child: Text(l.postViewSeeAll),
          ),
      ]),
    );
  }

  /// Sekmeyi baştan yükler (yenile / yeniden dene).
  Future<void> _retryTab(_Tab tab) async {
    _tabs.remove(tab);
    if (mounted) setState(() {});
    await _loadMore(tab);
  }

  Widget _footer(BuTokens t, _TabData d) {
    if (d.moreError) {
      final limited = d.cooldownUntil != null && DateTime.now().isBefore(d.cooldownUntil!);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          if (limited)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(context.l10n.searchTooMany,
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut)),
            ),
          BuButton(
            label: context.l10n.commonRetry,
            compact: true,
            kind: BuButtonKind.outline,
            onPressed: () {
              d.cooldownUntil = null;
              _loadMore(_tab);
            },
          ),
        ]),
      );
    }
    if (d.loading) {
      return const BuSkeletonList(itemCount: 2, shrinkWrap: true, padding: EdgeInsets.fromLTRB(20, 8, 20, 8));
    }
    return const SizedBox(height: 4);
  }

  /// Tarih "12 Ekim" (bu yıl) ya da "12 Ekim 2025".
  String _shortDate(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return newsLocalDate(context, iso);
    final base = '${d.day} ${newsMonthName(context, d.month)}';
    return d.year == DateTime.now().year ? base : '$base ${d.year}';
  }

  /// Gruplu kartın bir parçası: dış katman çizgi rengi (kenarlık + satır ayracı), iç katman yüzey.
  Widget _row(BuTokens t, _Hit h, {required bool first, required bool last}) {
    final tx = Theme.of(context).textTheme;
    final person = h.type == 'USER';
    final isNews = _tabOf(h.type) == _Tab.news;
    final snip = (h.snippet ?? '').trim();
    final badge = _badgeOf(context.l10n, h.type);
    String sub;
    if (person) {
      sub = snip;
    } else if (isNews) {
      sub = h.date == null ? badge : '$badge · ${_shortDate(h.date)}';
    } else {
      final parts = [badge, if (h.date != null) _shortDate(h.date), if (snip.isNotEmpty) snip];
      sub = parts.join(' · ');
    }
    const r = Radius.circular(20);
    const ri = Radius.circular(19);
    final outer = BorderRadius.vertical(top: first ? r : Radius.zero, bottom: last ? r : Radius.zero);
    final inner = BorderRadius.vertical(top: first ? ri : Radius.zero, bottom: last ? ri : Radius.zero);
    final tint = _tintOf(t, h.type);
    final hasImage = !person && (h.imageUrl ?? '').isNotEmpty;
    final Widget leading;
    if (person) {
      leading = BuAvatar(name: h.title, url: h.imageUrl, size: 48);
    } else if (hasImage) {
      leading = IcerikThumb(url: h.imageUrl, size: 48, radius: 14, fallbackIcon: _iconOf(h.type), tint: tint);
    } else {
      leading = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(14)),
        child: Icon(_iconOf(h.type), size: 22, color: tint.fg),
      );
    }
    final base = tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink);
    return DecoratedBox(
      decoration: BoxDecoration(color: t.bd, borderRadius: outer),
      child: Padding(
        padding: EdgeInsets.fromLTRB(1, first ? 1 : 0, 1, 1),
        child: Material(
          color: t.sf,
          borderRadius: inner,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('search-hit-${h.type}-${h.id}'),
            onTap: () => _open(h),
            child: Container(
              constraints: const BoxConstraints(minHeight: 68),
              padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
              child: Row(children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text.rich(
                      _highlight(h.title, _query, base, base.copyWith(color: t.onSoft, backgroundColor: t.soft)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sub.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                      ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
                  child: ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Büyük/küçük harf ve Türkçe i/İ/ı/I farkını yok sayan, uzunluğu koruyan sadeleştirme.
String _fold(String s) {
  final b = StringBuffer();
  for (final u in s.runes) {
    final c = String.fromCharCode(u);
    b.write(switch (c) {
      'İ' => 'i',
      'I' => 'ı',
      'ı' => 'ı',
      _ => c.toLowerCase().length == c.length ? c.toLowerCase() : c,
    });
  }
  return b.toString();
}

/// [text] içinde [query] geçen yerleri [mark] stiliyle vurgular.
TextSpan _highlight(String text, String query, TextStyle base, TextStyle mark) {
  final q = query.trim();
  if (q.length < 2) return TextSpan(text: text, style: base);
  final ft = _fold(text);
  final fq = _fold(q);
  if (ft.length != text.length) return TextSpan(text: text, style: base);
  final spans = <TextSpan>[];
  var i = 0;
  while (i < text.length) {
    final at = ft.indexOf(fq, i);
    if (at < 0) {
      spans.add(TextSpan(text: text.substring(i)));
      break;
    }
    if (at > i) spans.add(TextSpan(text: text.substring(i, at)));
    spans.add(TextSpan(text: text.substring(at, at + fq.length), style: mark));
    i = at + fq.length;
  }
  return TextSpan(style: base, children: spans);
}
