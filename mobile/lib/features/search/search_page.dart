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
  _Hit({
    required this.type,
    required this.id,
    required this.title,
    this.snippet,
    this.date,
    this.imageUrl,
    this.members,
    this.category,
    this.myStatus,
    this.likes,
  });

  final String type; // NEWS, ANNOUNCEMENT, EVENT_OFFICIAL, COMMUNITY, EVENT, POSTS, USER
  final int id;
  final String title;
  final String? snippet;
  final String? date;
  final String? imageUrl;

  // İsteğe bağlı alanlar (sunucu göndermiyorsa null; bkz. docs/design/BACKEND-ISTEK.md).
  final int? members; // kulüp üye sayısı
  final String? category; // kulüp kategorisi
  final String? myStatus; // kulüp: ACTIVE (üye) | NONE/PENDING (değil)
  final int? likes; // gönderi beğeni sayısı
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
  if (type == 'ANNOUNCEMENT') return t.tint(3);
  return switch (_tabOf(type)) {
    _Tab.news => BuTint(t.soft, t.onSoft),
    _Tab.club => t.tint(1),
    _Tab.event => t.tint(2),
    _Tab.post => t.tint(4),
    _ => t.tint(5),
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
      members: (h['memberCount'] as num?)?.toInt(),
      category: h['category'] is String && (h['category'] as String).isNotEmpty ? h['category'] as String : null,
      myStatus: h['myStatus'] as String?,
      likes: (h['likeCount'] as num?)?.toInt(),
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
      if (e is ApiError && e.status == 429) BuToast.show(context, l.searchTooMany, kind: BuToastKind.warning);
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
          BuToast.show(context, l.searchTooMany, kind: BuToastKind.warning);
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
              IcerikIconButton(icon: buDirIcon(context, LucideIcons.arrowLeft), label: l.authBack, onTap: () => Navigator.pop(context)),
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
          Semantics(
            container: true,
            label: l.icerikSearchTabs,
            child: _TabChips(
              labels: [for (final tab in _tabOrder) _tabLabel(l, tab)],
              selected: _tabOrder.indexOf(_tab),
              onSelected: (i) => _selectTab(_tabOrder[i]),
            ),
          ),
          if (active && _loading && _query.isNotEmpty) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
          Expanded(child: active ? _results(t) : _suggestions(t)),
        ],
      ),
    );
  }

  Widget _hint(BuTokens t) {
    final tx = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(LucideIcons.info, size: 18, color: t.mut),
        const SizedBox(width: 12),
        Expanded(child: Text(context.l10n.searchPrompt, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4))),
      ]),
    );
  }

  Widget _suggestions(BuTokens t) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _hint(t),
        if (_recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 0, 4),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.searchRecent, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w800, letterSpacing: .5, color: t.mut)),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: _clearRecent,
                child: Text(l.searchClearRecent, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.pr)),
              ),
            ]),
          ),
          BuCard(
            padding: EdgeInsets.zero,
            radius: 20,
            child: Column(children: [
              for (var i = 0; i < _recent.length; i++)
                Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  decoration: i == 0 ? null : BoxDecoration(border: Border(top: BorderSide(color: t.bd.withValues(alpha: .7)))),
                  child: Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _useRecent(_recent[i]),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 0, 8),
                          child: Row(children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                              child: Icon(LucideIcons.history, size: 18, color: t.mut),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(_recent[i],
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.p05SearchRemoveRecent,
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      onPressed: () => _removeRecent(i),
                      icon: Icon(LucideIcons.x, size: 18, color: t.mut),
                    ),
                  ]),
                ),
            ]),
          ),
        ],
      ],
    );
  }

  Future<void> _removeRecent(int i) async {
    final list = [..._recent]..removeAt(i);
    setState(() => _recent = list);
    try {
      if (list.isEmpty) {
        await _storage.delete(key: _recentKey);
      } else {
        await _storage.write(key: _recentKey, value: jsonEncode(list));
      }
    } catch (_) {}
  }

  /// Tümü sekmesindeki grup başlığı ve etiketi.
  String _groupLabel(AppLocalizations l, String type) => switch (type) {
        'ANNOUNCEMENT' => l.icerikGroupAnnouncement,
        'NEWS' => l.icerikGroupNews,
        _ => switch (_tabOf(type)) {
            _Tab.news => l.icerikGroupNews,
            _Tab.club => l.icerikGroupClub,
            _Tab.event => l.icerikGroupEvent,
            _Tab.post => l.icerikGroupPost,
            _ => l.icerikGroupPerson,
          },
      };

  /// Tümü sekmesi grup sırası: haber, duyuru, etkinlik, kulüp, kişi, gönderi.
  static const _groupOrder = ['NEWS', 'ANNOUNCEMENT', 'EVENT', 'COMMUNITY', 'USER', 'POSTS'];

  String _groupKey(String type) => switch (type) {
        'EVENT_OFFICIAL' => 'EVENT',
        'POST' => 'POSTS',
        _ => type,
      };

  String _foundLabel(AppLocalizations l, _Tab tab, int n, bool more) {
    final c = '$n${more ? '+' : ''}';
    return switch (tab) {
      _Tab.news => l.p05SearchFoundNews(c),
      _Tab.event => l.p05SearchFoundEvents(c),
      _Tab.club => l.p05SearchFoundClubs(c),
      _Tab.person => l.p05SearchFoundPeople(c),
      _Tab.post => l.p05SearchFoundPosts(c),
      _ => l.searchResultCount(c),
    };
  }

  Widget _countLabel(BuTokens t, String text, {String? sub}) {
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 8),
      child: Semantics(
        header: true,
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: text, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w800, letterSpacing: .4, color: t.mut)),
            if (sub != null) TextSpan(text: '   $sub', style: tx.labelMedium!.copyWith(color: t.mut)),
          ]),
        ),
      ),
    );
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
      return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
        BuCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: BuEmptyState(
            illustration: BuIllustration.search,
            title: l.searchNoResults,
            message: l.p05SearchNoResultsBody,
            compact: true,
          ),
        ),
      ]);
    }
    final more = paged && !(d?.done ?? true);
    final List<Widget> blocks;
    if (!paged) {
      blocks = [
        _countLabel(t, l.searchResultCount('${visible.length}'), sub: l.p05SearchCountFor(_query)),
        for (final key in _groupOrder)
          ..._groupCard(t, key, [for (final h in visible) if (_groupKey(h.type) == key) h]),
      ];
    } else {
      blocks = [
        _countLabel(t, _foundLabel(l, _tab, visible.length, more)),
        if (_tab == _Tab.club)
          for (final h in visible) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: _clubCard(t, h))
        else if (_tab == _Tab.post)
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: _postGrid(t, visible))
        else
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: _rowsCard(t, visible)),
        _footer(t, d!),
      ];
    }
    return RefreshIndicator(
      color: t.pr,
      backgroundColor: t.sf3,
      onRefresh: () => paged ? _retryTab(_tab) : _run(_query),
      child: BuStaggerScope(
        key: ValueKey('$_seq-${_tab.name}'),
        child: ListView.builder(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
          itemCount: blocks.length,
          itemBuilder: (context, i) => blocks[i],
        ),
      ),
    );
  }

  /// Tümü sekmesinde bir grup kartı: üstte küçük harfli başlık + "Tümünü gör (N)", altında satırlar.
  List<Widget> _groupCard(BuTokens t, String key, List<_Hit> hits) {
    if (hits.isEmpty) return const [];
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final tab = _tabOf(key);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: BuCard(
          padding: EdgeInsets.zero,
          radius: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 4, 0),
              child: Row(children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(_groupLabel(l, key),
                        style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w800, letterSpacing: .5, color: t.mut)),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  onPressed: () => _selectTab(tab),
                  child: Text(l.p05SearchSeeAllN('${hits.length}'), style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.pr)),
                ),
              ]),
            ),
            _rows(t, hits),
          ]),
        ),
      ),
    ];
  }

  Widget _rowsCard(BuTokens t, List<_Hit> hits) => BuCard(padding: EdgeInsets.zero, radius: 20, child: _rows(t, hits));

  Widget _rows(BuTokens t, List<_Hit> hits) => Column(children: [
        for (var i = 0; i < hits.length; i++)
          Container(
            decoration: i == 0 ? null : BoxDecoration(border: Border(top: BorderSide(color: t.bd.withValues(alpha: .7)))),
            child: _row(t, hits[i]),
          ),
      ]);

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

  /// Tek sonuç satırı (karta gömülü): türüne göre görünüm.
  Widget _row(BuTokens t, _Hit h) {
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final tab = _tabOf(h.type);
    final base = tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, height: 1.25, color: t.ink);
    final snip = (h.snippet ?? '').trim();
    Widget leading;
    Widget sub = const SizedBox.shrink();
    Widget? trailing;
    switch (tab) {
      case _Tab.news:
        leading = (h.imageUrl ?? '').isNotEmpty
            ? IcerikThumb(url: h.imageUrl, size: 56, radius: 12, fallbackIcon: _iconOf(h.type), tint: _tintOf(t, h.type))
            : _iconTile(t, h.type, 56, 12);
        if (h.date != null) {
          sub = Row(children: [
            Icon(LucideIcons.clock, size: 13, color: t.mut),
            const SizedBox(width: 5),
            Flexible(child: Text(_shortDate(h.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
          ]);
        }
      case _Tab.event:
        final d = h.date == null ? null : DateTime.tryParse(h.date!)?.toLocal();
        leading = d == null
            ? _iconTile(t, h.type, 56, 12)
            : Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(trUpper(newsMonthName(context, d.month)).characters.take(3).toString(),
                      style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w800, color: t.onSoft)),
                  Text('${d.day}', style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, height: 1.1, color: t.pr)),
                ]),
              );
        if (snip.isNotEmpty) sub = Text(snip, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut));
      case _Tab.club:
        leading = BuAvatar(name: h.title, url: h.imageUrl, size: 48, group: true);
        final sb = h.members != null ? l.clubMemberCount('${h.members}') : snip;
        if (sb.isNotEmpty) sub = Text(sb, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut));
        if (h.category != null) trailing = _Pill(text: h.category!);
      case _Tab.post:
        leading = IcerikThumb(url: h.imageUrl, size: 56, radius: 12, fallbackIcon: LucideIcons.image, tint: _tintOf(t, h.type));
        if (h.likes != null) {
          sub = Row(children: [
            Icon(LucideIcons.heart, size: 14, color: t.pr),
            const SizedBox(width: 5),
            Text('${h.likes}', style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
          ]);
        }
      case _Tab.person:
      case _Tab.all:
        leading = BuAvatar(name: h.title, url: h.imageUrl, size: 48);
        if (snip.isNotEmpty) sub = Text(snip, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut));
    }
    // Gönderi satırında başlık yerine gönderi metni öne çıkar.
    final isPost = tab == _Tab.post;
    final headline = isPost && snip.isNotEmpty ? snip : h.title;
    return InkWell(
      key: ValueKey('search-hit-${h.type}-${h.id}'),
      onTap: () => _open(h),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
        child: Row(children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text.rich(_highlight(headline, _query, base, base.copyWith(color: t.onSoft, backgroundColor: t.soft)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (sub is! SizedBox) Padding(padding: const EdgeInsets.only(top: 3), child: sub),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
          if (tab == _Tab.person || tab == _Tab.all)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut)),
            ),
        ]),
      ),
    );
  }

  Widget _iconTile(BuTokens t, String type, double size, double radius) {
    final tint = _tintOf(t, type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(radius)),
      child: Icon(_iconOf(type), size: size * .45, color: tint.fg),
    );
  }

  /// Kulüp sekmesi kartı: logo, ad, kategori + üye sayısı, açıklama, üyelik durumu.
  Widget _clubCard(BuTokens t, _Hit h) {
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final base = tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, height: 1.2, color: t.ink);
    final snip = (h.snippet ?? '').trim();
    final status = h.myStatus;
    return BuCard(
      key: ValueKey('search-hit-${h.type}-${h.id}'),
      radius: 20,
      padding: const EdgeInsets.all(16),
      onTap: () => _open(h),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BuAvatar(name: h.title, url: h.imageUrl, size: 56, square: true, group: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(_highlight(h.title, _query, base, base.copyWith(color: t.onSoft, backgroundColor: t.soft)), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (h.category != null || h.members != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (h.category != null) _Pill(text: h.category!),
                    if (h.members != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.users, size: 14, color: t.mut),
                        const SizedBox(width: 4),
                        Text(l.clubMemberCount('${h.members}'), style: tx.labelMedium!.copyWith(color: t.mut)),
                      ]),
                  ]),
                ),
            ]),
          ),
        ]),
        if (snip.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(snip, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
        ],
        if (status != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: status == 'ACTIVE'
                ? BuButton(label: l.clubIsMember, icon: LucideIcons.circleCheck, kind: BuButtonKind.soft, compact: true, onPressed: () => _open(h))
                : BuButton(label: l.clubJoin, icon: LucideIcons.plus, compact: true, onPressed: () => _open(h)),
          ),
        ],
      ]),
    );
  }

  /// Gönderi sekmesi: iki sütunlu fotoğraf kartları (fotoğraf, açıklama, yazar, beğeni sayısı).
  Widget _postGrid(BuTokens t, List<_Hit> hits) {
    final tx = Theme.of(context).textTheme;
    Widget card(_Hit h) {
      final snip = (h.snippet ?? '').trim();
      return BuCard(
        key: ValueKey('search-hit-${h.type}-${h.id}'),
        radius: 20,
        padding: EdgeInsets.zero,
        onTap: () => _open(h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(aspectRatio: 4 / 5, child: BuImage(h.imageUrl, width: double.infinity, height: double.infinity, maxDecodeWidth: 600)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (snip.isNotEmpty)
                  Text(snip, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, height: 1.3, color: t.ink)),
                const SizedBox(height: 8),
                Row(children: [
                  if (h.likes != null) ...[
                    Icon(LucideIcons.heart, size: 14, color: t.pr),
                    const SizedBox(width: 4),
                    Text('${h.likes}', style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: tx.labelMedium!.copyWith(color: t.mut))),
                ]),
              ]),
            ),
          ]),
        ),
      );
    }

    final left = [for (var i = 0; i < hits.length; i += 2) hits[i]];
    final right = [for (var i = 1; i < hits.length; i += 2) hits[i]];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(children: [for (final h in left) Padding(padding: const EdgeInsets.only(bottom: 12), child: card(h))])),
      const SizedBox(width: 12),
      Expanded(child: Column(children: [for (final h in right) Padding(padding: const EdgeInsets.only(bottom: 12), child: card(h))])),
    ]);
  }
}

/// Küçük hap etiket (kulüp kategorisi).
class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.pill)),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: t.mut)),
    );
  }
}

/// Sonuç türü çipleri: seçili = mürekkep zemin (referans), yatay kaydırılır.
class _TabChips extends StatelessWidget {
  const _TabChips({required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = i == selected;
          return Semantics(
            button: true,
            selected: on,
            child: BuPressable(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: BuMotion.of(context, BuMotion.short),
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? t.ink : t.sf,
                  borderRadius: BorderRadius.circular(BuRadius.pill),
                  border: Border.all(color: on ? t.ink : t.bd),
                ),
                child: Text(labels[i], style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: on ? t.bg : t.ink)),
              ),
            ),
          );
        },
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
