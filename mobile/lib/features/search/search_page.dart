import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../clubs/club_detail_page.dart';
import '../events/event_detail_page.dart';
import '../follow/follow_widgets.dart' show FollowRowButton;
import '../news/icerik_parts.dart';
import '../news/news_detail_page.dart';
import '../news/news_tile.dart' show newsLocalDate, newsMonthName;
import '../posts/post_routes.dart';
import '../posts/social_models.dart' show FollowState, followStateOf;
import '../profile/user_profile_page.dart';
import 'recent_searches.dart';
import '../../core/academic_catalog.dart';

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
    this.endsAt,
    this.followState,
    this.isPrivate = false,
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
  final String? endsAt; // etkinlik bitişi (saat aralığı için)
  final FollowState? followState; // kişi: sunucu `followState` verdiyse (yoksa takip düğmesi çizilmez)
  final bool isPrivate; // kişi: gizli hesap
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
      return BuIcons.megaphone;
    default:
      break;
  }
  switch (_tabOf(type)) {
    case _Tab.news:
      return BuIcons.newspaper;
    case _Tab.club:
      return BuIcons.users;
    case _Tab.event:
      return BuIcons.calendar;
    case _Tab.post:
      return BuIcons.image;
    default:
      return BuIcons.user;
  }
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
      endsAt: h['endsAt'] as String?,
    );

_Hit _hitFromUser(Map u, AppLocalizations l, BuildContext context) {
  final sub = [
    if (u['faculty'] != null) context.facultyName(u['faculty'].toString()),
    if (u['department'] != null) context.departmentName(u['department'].toString(), faculty: u['faculty']?.toString()),
    if (u['classYear'] != null) l.searchClassYear('${u['classYear']}')]
      .where((e) => e.isNotEmpty)
      .join(' · ');
  return _Hit(
    type: 'USER',
    id: (u['id'] as num).toInt(),
    title: '${u['displayName'] ?? l.searchUserDefault}',
    snippet: sub.isEmpty ? null : sub,
    imageUrl: u['avatarUrl'] as String?,
    followState: u['followState'] is String ? followStateOf(u['followState']) : null,
    isPrivate: u['isPrivate'] == true,
  );
}

class _SearchPageState extends State<SearchPage> {
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
    final list = await RecentSearches.load();
    if (mounted && list.isNotEmpty) setState(() => _recent = list);
  }

  Future<void> _saveRecent(String q) async {
    final list = [q, ..._recent.where((e) => e.toLowerCase() != q.toLowerCase())].take(8).toList();
    if (mounted) setState(() => _recent = list);
    await RecentSearches.save(list);
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = []);
    await RecentSearches.clear();
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
        hits.add(_hitFromUser(u, l, context));
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
            if (u is Map && u['id'] != null) fresh.add(_hitFromUser(u, l, context));
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
          // Üst: yalnız BİR geri oku (40 dp daire) + arama alanı (48 dp, 16 köşe, odakta 1,5 dp marka çerçevesi).
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(12, MediaQuery.paddingOf(context).top + 12, 16, 0),
            child: Row(children: [
              IcerikIconButton(icon: buDirIcon(context, BuIcons.arrowLeft), label: l.authBack, onTap: () => Navigator.pop(context)),
              const SizedBox(width: 6),
              Expanded(child: _SearchBox(hint: l.searchHint, controller: _ctrl, onChanged: _onChanged, onSubmitted: _submit)),
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
          // Öneriler <-> sonuçlar yumuşak geçiş (anahtar: etkin mi); sonuç içi iskelet/sıralı giriş kendi içinde.
          Expanded(child: BuFadeThrough(child: KeyedSubtree(key: ValueKey<bool>(active), child: active ? _results(t) : _suggestions(t)))),
        ],
      ),
    );
  }

  /// Başlangıç ekranı: soluk 14 sp ipucu cümlesi + "Son aramalar" (17 sp/600, sağda marka "Temizle") + çizgili satırlar
  /// (sol saat simgesi, 15 sp metin, sağ x); sarmal kart yok.
  Widget _suggestions(BuTokens t) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(l.searchPrompt, style: tx.bodyMedium!.copyWith(fontSize: 13, height: 1.5, color: t.mut)),
        ),
        if (_recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(l.searchRecent, style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 4)),
              onPressed: _clearRecent,
              child: Text(l.searchClearRecent, style: tx.bodySmall!.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.pr)),
            ),
          ]),
          for (var i = 0; i < _recent.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
              child: Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _useRecent(_recent[i]),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Row(children: [
                        const SizedBox(width: 4),
                        Icon(BuIcons.clock, size: 18, color: t.mut),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_recent[i],
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(fontSize: 15, color: t.ink)),
                        ),
                      ]),
                    ),
                  ),
                ),
                // 48 dp dokunma alanı; simge merkezi sağ kenardan 18 dp (referans: 28 dp düğme + 4 dp iç boşluk).
                Semantics(
                  button: true,
                  label: l.p05SearchRemoveRecent,
                  excludeSemantics: true,
                  onTap: () => _removeRecent(i),
                  child: Tooltip(
                    message: l.p05SearchRemoveRecent,
                    excludeFromSemantics: true,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _removeRecent(i),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 10),
                            child: Icon(BuIcons.x, size: 16, color: t.mut),
                          ),
                        ),
                      ),
                    ),
                  ),
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
    if (list.isEmpty) {
      await RecentSearches.clear();
    } else {
      await RecentSearches.save(list);
    }
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

  /// Sonuç sayısı satırı: soluk 13 sp ("6 sonuç"; sayfalı sekmede daha fazla varsa "12+").
  Widget _countLine(BuTokens t, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Semantics(
          header: true,
          child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
        ),
      );

  Widget _results(BuTokens t) {
    final l = context.l10n;
    final paged = _tab != _Tab.all;
    final d = paged ? _tabs[_tab] : null;
    final error = paged ? d?.error : _error;
    if (error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        // Referans: hata satırı çiplerin 20 dp altında; 48 dp dokunma satırı çip kutusunun boş alt bölgesine 20 dp taşar.
        children: [Transform.translate(offset: const Offset(0, -20), child: _errorBlock(t, error, () => paged ? _retryTab(_tab) : _run(_query)))],
      );
    }
    final visible = paged ? (d?.hits ?? const <_Hit>[]) : _hits;
    if (paged ? (d == null || !d.loaded) : (_loading && _hits.isEmpty)) {
      return const BuSkeletonList(itemCount: 7);
    }
    if (visible.isEmpty) {
      // Sonuç yok: ortada tek başlık + tek soluk cümle (illüstrasyon yok).
      final tx = Theme.of(context).textTheme;
      return ListView(padding: const EdgeInsets.fromLTRB(16, 96, 16, 24), children: [
        Text(l.searchNoResults,
            textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: t.ink)),
        const SizedBox(height: 8),
        Text(l.p05SearchNoResultsBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(fontSize: 14, color: t.mut)),
      ]);
    }
    final more = paged && !(d?.done ?? true);
    final List<Widget> blocks;
    if (!paged) {
      final sections = <Widget>[];
      for (final key in _groupOrder) {
        final hits = [for (final h in visible) if (_groupKey(h.type) == key) h];
        if (hits.isEmpty) continue;
        sections.add(_section(t, key, hits, first: sections.isEmpty));
      }
      blocks = [_countLine(t, l.searchResultCount('${visible.length}')), ...sections];
    } else {
      blocks = [
        _countLine(t, l.searchResultCount('${visible.length}${more ? '+' : ''}')),
        if (_tab == _Tab.post)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _postGrid(t, visible))
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const NewsRowDivider(),
                Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: _row(t, visible[i])),
              ],
            ]),
          ),
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

  /// Hata: sol soluk "Yüklenemedi", sağ marka "Yeniden dene"; hız sınırında `warnSoft` bant + 3 satır iskelet.
  Widget _errorBlock(BuTokens t, Object error, VoidCallback onRetry) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final limited = error is ApiError && error.status == 429;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(l.p05SearchErrorTitle, style: tx.bodyLarge!.copyWith(fontSize: 15, color: t.mut)),
          ),
        ),
        TextButton.icon(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 4)),
          onPressed: onRetry,
          icon: Icon(BuIcons.refreshCw, size: 16, color: t.pr),
          label: Text(l.commonRetry, style: tx.bodyMedium!.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: t.pr)),
        ),
      ]),
      if (limited) ...[
        const SizedBox(height: 4),
        IcerikNotice(text: l.searchTooMany, icon: BuIcons.clock),
        const SizedBox(height: 16),
        const _RowsSkeleton(),
      ],
    ]);
  }

  /// Tümü sekmesinde bir tür bölümü: üstte 1 dp çizgi (ilk bölüm hariç), başlık (13 sp/600 soluk büyük harf) + sağda
  /// "Tümünü gör (n)" (13 sp marka), altında satırlar; kart yok.
  Widget _section(BuTokens t, String key, List<_Hit> hits, {required bool first}) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final tab = _tabOf(key);
    final ar = LocaleController.current?.locale.languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: t.bd))),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 48,
              child: Row(children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(_groupLabel(l, key),
                        style: tx.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: ar ? 0 : .6, color: t.mut)),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 4)),
                  onPressed: () => _selectTab(tab),
                  child: Text(l.p05SearchSeeAllN('${hits.length}'), style: tx.bodySmall!.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.pr)),
                ),
              ]),
            ),
            // Başlık 48 dp (dokunma hedefi); satırlar 8 dp yukarı alınır (referans: başlık 20 dp), boşluk bölüm altında kalır.
            Transform.translate(
              offset: const Offset(0, -8),
              child: Column(children: [
                for (var i = 0; i < hits.length && i < _groupPreview; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _row(t, hits[i]),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  /// Tümü sekmesinde bir türden en çok bu kadar satır gösterilir (gerisi tür sekmesinde).
  static const _groupPreview = 4;

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

  /// Etkinlik saat aralığı "17:30 – 19:00" (bitiş yoksa yalnız başlangıç; saat bilgisi yoksa null).
  String? _timeRange(_Hit h) {
    String? hm(String? iso) {
      final d = iso == null ? null : DateTime.tryParse(iso);
      if (d == null || !iso!.contains('T')) return null;
      final dl = d.isUtc ? d.toLocal() : d;
      if (dl.hour == 0 && dl.minute == 0) return null;
      return '${dl.hour.toString().padLeft(2, '0')}:${dl.minute.toString().padLeft(2, '0')}';
    }

    final a = hm(h.date);
    if (a == null) return null;
    final b = hm(h.endsAt);
    return b == null ? a : '$a – $b';
  }

  /// Eşleşen metin (sorgu) marka rengi + 600 ağırlıkla vurgulanır; büyük/küçük harf ve Türkçe i/İ duyarsız.
  InlineSpan _highlight(String text, TextStyle base, BuTokens t) {
    String fold(String x) => x.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    final q = fold(_query.trim());
    if (q.length < 2) return TextSpan(text: text, style: base);
    final src = fold(text);
    if (src.length != text.length) return TextSpan(text: text, style: base);
    final spans = <InlineSpan>[];
    var from = 0;
    while (true) {
      final i = src.indexOf(q, from);
      if (i < 0) break;
      if (i > from) spans.add(TextSpan(text: text.substring(from, i), style: base));
      spans.add(TextSpan(text: text.substring(i, i + q.length), style: base.copyWith(fontWeight: FontWeight.w600, color: t.pr)));
      from = i + q.length;
    }
    if (from < text.length) spans.add(TextSpan(text: text.substring(from), style: base));
    return TextSpan(children: spans);
  }

  /// Kısaltma: kulüp için en çok 3, kişi için en çok 2 baş harf ("KFK", "EY").
  String _initials(String name, int max) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return trUpper(parts.take(max).map((e) => e.characters.first).join());
  }

  Widget _initialsCircle(BuTokens t, String name, int max, {double size = 44}) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
          child: Text(_initials(name, max),
              maxLines: 1, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink)),
        ),
      );

  Widget _chevron(BuTokens t) =>
      ExcludeSemantics(child: Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mut));

  /// Tek sonuç satırı (kartsız): türüne göre görünüm; eşleşen metin vurgulu.
  Widget _row(BuTokens t, _Hit h) {
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final tab = _tabOf(h.type);
    final base = tx.bodyLarge!.copyWith(fontSize: 16, height: 1.3, color: t.ink);
    final mut = tx.bodySmall!.copyWith(fontSize: 13, color: t.mut);
    final snip = (h.snippet ?? '').trim();
    final hasImg = (h.imageUrl ?? '').isNotEmpty;
    Widget? leading;
    String sub = '';
    Widget? trailing;
    var titleLines = 2;
    switch (tab) {
      case _Tab.news:
        if (hasImg) {
          leading = ClipRRect(
            borderRadius: BorderRadius.circular(BuRadius.xs),
            child: SizedBox(
              width: 64,
              height: 56,
              child: BuImage(h.imageUrl, width: 64, height: 56, placeholderIcon: _iconOf(h.type), maxDecodeWidth: 400),
            ),
          );
        }
        if (h.date != null) sub = newsLocalDate(context, h.date);
      case _Tab.event:
        final d = h.date == null ? null : DateTime.tryParse(h.date!)?.toLocal();
        if (d != null) {
          leading = ExcludeSemantics(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(BuRadius.sm), border: Border.all(color: t.bd)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(trUpper(newsMonthName(context, d.month)).characters.take(3).toString(),
                    style: tx.labelSmall!.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.1, color: t.pr)),
                Text('${d.day}',
                    style: tx.titleMedium!.copyWith(
                        fontSize: 20, fontWeight: FontWeight.w600, height: 1.1, color: t.ink, fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          );
        }
        sub = [if (snip.isNotEmpty) snip, if (_timeRange(h) != null) _timeRange(h)!].join(' · ');
        trailing = _chevron(t);
        titleLines = 1;
      case _Tab.club:
        leading = hasImg ? BuAvatar(name: h.title, url: h.imageUrl, size: 44, group: true) : _initialsCircle(t, h.title, 3);
        sub = h.members != null ? l.clubMemberCount('${h.members}') : snip;
        if (h.myStatus == 'ACTIVE') {
          trailing = _ClubPill(text: l.clubIsMember, member: true);
        } else if (h.myStatus != null) {
          trailing = _ClubPill(text: l.clubJoin, member: false);
        }
        titleLines = 1;
      case _Tab.post:
        leading = IcerikThumb(url: h.imageUrl, size: 56, radius: BuRadius.xs, fallbackIcon: BuIcons.image);
        trailing = _chevron(t);
        titleLines = 1;
      case _Tab.person:
      case _Tab.all:
        leading = hasImg ? BuAvatar(name: h.title, url: h.imageUrl, size: 44) : _initialsCircle(t, h.title, 2);
        sub = snip;
        final fs = h.followState;
        // Kişi satırında takip düğmesi (sunucu `followState` verdiyse; kendi satırında yok): 3 durumlu.
        trailing = h.type == 'USER' && fs != null && fs != FollowState.self && h.id != widget.session.userId
            ? FollowRowButton(session: widget.session, userId: h.id, state: fs, isPrivate: h.isPrivate)
            : _chevron(t);
        titleLines = 1;
    }
    // Gönderi satırında başlık yerine gönderi metni öne çıkar; altında kalp + beğeni sayısı.
    final isPost = tab == _Tab.post;
    final headline = isPost && snip.isNotEmpty ? snip : h.title;
    return BuPressable(
      key: ValueKey('search-hit-${h.type}-${h.id}'),
      scale: .985,
      onTap: () => _open(h),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          if (leading != null) ...[leading, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text.rich(_highlight(headline, base, t), maxLines: titleLines, overflow: TextOverflow.ellipsis),
              if (isPost && h.likes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Icon(BuIcons.heart, size: 16, color: t.mut),
                    const SizedBox(width: 6),
                    Text('${h.likes}', style: mut.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  ]),
                )
              else if (sub.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: mut)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ]),
      ),
    );
  }

  /// Gönderi sekmesi: tek sütun gönderi satırları (56 dp kare fotoğraf + altyazı + kalp + beğeni).
  Widget _postGrid(BuTokens t, List<_Hit> hits) => Column(children: [
        for (var i = 0; i < hits.length; i++) ...[
          if (i > 0) const NewsRowDivider(),
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: _row(t, hits[i])),
        ],
      ]);
}

/// Kulüp satırının sağındaki küçük hap: "Katıl" = `soft` zemin + marka metni; "Üyesin" = 1 dp çerçeveli, ink metin + tik.
class _ClubPill extends StatelessWidget {
  const _ClubPill({required this.text, required this.member});

  final String text;
  final bool member;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: member ? t.ink : t.pr);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: member ? Colors.transparent : t.soft,
        borderRadius: BorderRadius.circular(BuRadius.pill),
        border: member ? Border.all(color: t.bd) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (member) ...[Icon(BuIcons.check, size: 14, color: t.ink), const SizedBox(width: 4)],
        Text(text, maxLines: 1, style: style),
      ]),
    );
  }
}

/// Hız sınırı sırasında gösterilen 3 satır iskelet (40 dp daire + iki çubuk, satır arası çizgi).
class _RowsSkeleton extends StatelessWidget {
  const _RowsSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget row(double w1, double w2) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            const BuSkeleton.circle(40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                BuSkeleton.line(width: w1, height: 12),
                const SizedBox(height: 8),
                BuSkeleton.line(width: w2, height: 10),
              ]),
            ),
          ]),
        );
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: BuSkeletonScope(child: Column(children: [row(220, 140), const NewsRowDivider(), row(240, 110), const NewsRowDivider(), row(190, 90)])),
      ),
    );
  }
}

/// Arama alanı: 48 dp, beyaz, 1 dp çizgi (odakta 1,5 dp marka), 16 köşe; sol büyüteç, sağda temizle (24 dp daire x).
class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.hint, required this.controller, required this.onChanged, required this.onSubmitted});

  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: BuMotion.of(context, BuMotion.short),
      height: 48,
      padding: const EdgeInsetsDirectional.only(start: 14, end: 0),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(BuRadius.md),
        border: Border.all(color: focused ? t.pr : t.bd, width: focused ? 1.5 : 1),
      ),
      child: Row(children: [
        Icon(BuIcons.search, size: 18, color: t.mut),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            autofocus: true,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            textInputAction: TextInputAction.search,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 15, color: t.ink),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 14, color: t.mut),
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, v, _) => v.text.isEmpty
              ? const SizedBox(width: 14)
              : IconButton(
                  tooltip: l.searchClear,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                  },
                  icon: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                    child: Icon(BuIcons.x, size: 14, color: t.mut),
                  ),
                ),
        ),
      ]),
    );
  }
}

/// Sonuç türü çipleri (Tümü, Haber, Etkinlik, Kulüp, Kişi, Gönderi): 34 dp yüksek hap; seçili = `soft` zemin + marka metni,
/// diğerleri beyaz + 1 dp çizgi; yatay kaydırılır, seçili çip görünür kaydırılır.
class _TabChips extends StatefulWidget {
  const _TabChips({required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  State<_TabChips> createState() => _TabChipsState();
}

class _TabChipsState extends State<_TabChips> {
  late final List<GlobalKey> _keys = [for (final _ in widget.labels) GlobalKey()];

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(_TabChips old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _keys[widget.selected].currentContext;
      if (!mounted || c == null) return;
      Scrollable.ensureVisible(c, alignment: .5, duration: BuMotion.of(context, BuMotion.medium), curve: BuMotion.emphasized);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    // Tüm çipler (en çok 6) kurulur: ensureVisible her çipin bağlamına ihtiyaç duyar.
    return SizedBox(
      height: 60,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (var i = 0; i < widget.labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            // "button" burada yazılmaz: BuPressable zaten düğme bayrağı koyar.
            Semantics(
              key: _keys[i],
              selected: i == widget.selected,
              child: BuPressable(
                onTap: () => widget.onSelected(i),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    child: AnimatedContainer(
                      duration: BuMotion.of(context, BuMotion.short),
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == widget.selected ? t.soft : t.sf,
                        borderRadius: BorderRadius.circular(BuRadius.pill),
                      ),
                      child: AnimatedDefaultTextStyle(
                        duration: BuMotion.of(context, BuMotion.short),
                        style: tx.labelLarge!.copyWith(
                            fontSize: 13, fontWeight: i == widget.selected ? FontWeight.w500 : FontWeight.w400, color: i == widget.selected ? t.pr : t.ink),
                        child: Text(widget.labels[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
