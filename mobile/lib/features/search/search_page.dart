import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../chat/chat_detail_page.dart';
import '../clubs/club_detail_page.dart';
import '../events/event_detail_page.dart';
import '../news/news_detail_page.dart';

/// Genel arama: haber/duyuru, kulüp, etkinlik ve kişi.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.session});

  final Session session;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

/// Tek tip sonuç satırı (hem /search hem /users/search'ten).
class _Hit {
  _Hit({required this.type, required this.id, required this.title, this.snippet, this.date, this.imageUrl});

  final String type; // NEWS, ANNOUNCEMENT, EVENT_OFFICIAL, COMMUNITY, EVENT, USER
  final int id;
  final String title;
  final String? snippet;
  final String? date;
  final String? imageUrl;
}

enum _Tab { all, news, club, event, person }

const _tabLabels = {
  _Tab.all: 'Tümü',
  _Tab.news: 'Haber',
  _Tab.club: 'Kulüp',
  _Tab.event: 'Etkinlik',
  _Tab.person: 'Kişi',
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
    default:
      return _Tab.person;
  }
}

String _badgeOf(String type) {
  switch (type) {
    case 'NEWS':
      return 'Haber';
    case 'ANNOUNCEMENT':
      return 'Duyuru';
    case 'COMMUNITY':
      return 'Kulüp';
    case 'EVENT':
    case 'EVENT_OFFICIAL':
      return 'Etkinlik';
    default:
      return 'Kişi';
  }
}

IconData _iconOf(String type) {
  switch (_tabOf(type)) {
    case _Tab.news:
      return LucideIcons.newspaper;
    case _Tab.club:
      return LucideIcons.users;
    case _Tab.event:
      return LucideIcons.calendar;
    default:
      return LucideIcons.user;
  }
}

class _SearchPageState extends State<SearchPage> {
  static const _recentKey = 'recent_searches';
  static const _storage = FlutterSecureStorage();

  final _ctrl = TextEditingController();
  Timer? _debounce;
  int _seq = 0; // eski yanıtları yok saymak için

  _Tab _tab = _Tab.all;
  List<String> _recent = [];
  List<_Hit> _hits = [];
  bool _loading = false;
  Object? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
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

  Future<void> _run(String q) async {
    if (q.length < 2) return;
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final enc = Uri.encodeQueryComponent(q);
      final api = widget.session.api;
      final res = await Future.wait<dynamic>([
        api.get('/search?q=$enc&limit=20'),
        api.get('/users/search?q=$enc&size=20').catchError((_) => <String, dynamic>{'items': []}),
      ]);
      if (!mounted || seq != _seq) return;
      final hits = <_Hit>[];
      final groups = (res[0] is Map ? res[0]['groups'] : null) as List? ?? [];
      for (final g in groups) {
        final items = (g is Map ? g['items'] : null) as List? ?? [];
        for (final h in items) {
          if (h is! Map || h['targetId'] == null) continue;
          hits.add(_Hit(
            type: '${h['type']}',
            id: (h['targetId'] as num).toInt(),
            title: '${h['title'] ?? ''}',
            snippet: h['snippet'] as String?,
            date: h['date'] as String?,
            imageUrl: h['imageUrl'] as String?,
          ));
        }
      }
      final users = (res[1] is Map ? res[1]['items'] : null) as List? ?? [];
      for (final u in users) {
        if (u is! Map || u['id'] == null) continue;
        final sub = [u['faculty'], u['department'], if (u['classYear'] != null) '${u['classYear']}. sınıf']
            .where((e) => e != null && '$e'.isNotEmpty)
            .join(' · ');
        hits.add(_Hit(
          type: 'USER',
          id: (u['id'] as num).toInt(),
          title: '${u['displayName'] ?? 'Kullanıcı'}',
          snippet: sub.isEmpty ? null : sub,
          imageUrl: u['avatarUrl'] as String?,
        ));
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
      default:
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _PersonSheet(session: s, userId: h.id, fallbackName: h.title),
        );
        return;
    }
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final active = _query.isNotEmpty || _loading || _error != null;
    final visible = _tab == _Tab.all ? _hits : _hits.where((h) => _tabOf(h.type) == _tab).toList();
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 0),
            child: Row(children: [
              BuIconButton(icon: LucideIcons.arrowLeft, onTap: () => Navigator.pop(context), tooltip: 'Geri'),
              const SizedBox(width: 12),
              Expanded(child: _field(t)),
            ]),
          ),
          if (active)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final tab in _Tab.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: _chip(t, _tabLabels[tab]!, _tab == tab, () => setState(() => _tab = tab)),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(child: active ? _results(t, visible) : _suggestions(t)),
        ],
      ),
    );
  }

  Widget _field(BuTokens t) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.pr, width: 2),
      ),
      child: Row(children: [
        Icon(LucideIcons.search, size: 20, color: t.pr),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (v) {
              setState(() {});
              _onChanged(v);
            },
            onSubmitted: _submit,
            textInputAction: TextInputAction.search,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink),
            cursorColor: t.pr,
            decoration: InputDecoration(
              hintText: 'Haber, kulüp, etkinlik, kişi ara',
              hintStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: t.mut),
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (_ctrl.text.isNotEmpty)
          GestureDetector(
            onTap: () {
              _ctrl.clear();
              _onChanged('');
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Icon(LucideIcons.x, size: 20, color: t.mut),
            ),
          ),
      ]),
    );
  }

  Widget _chip(BuTokens t, String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? t.ink : t.sf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? t.ink : t.bd),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? t.bg : t.mut)),
      ),
    );
  }

  Widget _suggestions(BuTokens t) {
    if (_recent.isEmpty) {
      return const EmptyView(
        icon: LucideIcons.search,
        text: 'Haber, duyuru, kulüp, etkinlik veya kişi aramak için en az 2 karakter yazın.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(children: [
          Expanded(
            child: Text('SON ARAMALAR',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .5, color: t.mut)),
          ),
          GestureDetector(
            onTap: _clearRecent,
            child: Text('Temizle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.pr)),
          ),
        ]),
        const SizedBox(height: 4),
        for (final q in _recent)
          InkWell(
            onTap: () => _useRecent(q),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Icon(LucideIcons.history, size: 18, color: t.mut),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(q,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _results(BuTokens t, List<_Hit> visible) {
    if (_error != null) return ErrorView(error: _error!, onRetry: () => _run(_ctrl.text.trim()));
    if (_loading && _hits.isEmpty) return const LoadingView();
    if (visible.isEmpty) {
      return const EmptyView(icon: LucideIcons.searchX, text: 'Sonuç bulunamadı.');
    }
    return RefreshIndicator(
      onRefresh: () => _run(_query),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: visible.length + 1,
        separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : Divider(height: 1, color: t.bd),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
              child: Text('${visible.length} SONUÇ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .5, color: t.mut)),
            );
          }
          return _row(t, visible[i - 1]);
        },
      ),
    );
  }

  Widget _row(BuTokens t, _Hit h) {
    final person = h.type == 'USER';
    final date = h.date == null ? '' : niceDate(h.date);
    final snip = (h.snippet ?? '').trim();
    return InkWell(
      onTap: () => _open(h),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (person)
            BuAvatar(name: h.title, url: h.imageUrl, size: 48)
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
              child: Icon(_iconOf(h.type), size: 22, color: t.pr),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                BuBadge(_badgeOf(h.type), soft: _tabOf(h.type) != _Tab.news),
                if (date.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(date, style: TextStyle(fontSize: 11, color: t.mut)),
                ],
              ]),
              const SizedBox(height: 6),
              Text(h.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.3, color: t.ink)),
              if (snip.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(snip,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, height: 1.4, color: t.mut)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Kişi için kısa profil alt sayfası.
class _PersonSheet extends StatefulWidget {
  const _PersonSheet({required this.session, required this.userId, required this.fallbackName});

  final Session session;
  final int userId;
  final String fallbackName;

  @override
  State<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<_PersonSheet> {
  Map<String, dynamic>? _p;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await widget.session.api.get('/users/${widget.userId}');
      if (mounted) setState(() => _p = Map<String, dynamic>.from(r as Map));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _message() async {
    setState(() => _busy = true);
    try {
      final r = await widget.session.api.post('/conversations', {'userId': widget.userId});
      if (!mounted) return;
      final nav = Navigator.of(context);
      final conv = Map<String, dynamic>.from(r as Map);
      nav.pop();
      nav.push(MaterialPageRoute<void>(
          builder: (_) => ChatDetailPage(session: widget.session, conversation: conv)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final p = _p;
    final name = (p?['displayName'] as String?) ?? widget.fallbackName;
    final dept = [p?['faculty'], p?['department'], if (p?['classYear'] != null) '${p!['classYear']}. sınıf']
        .where((e) => e != null && '$e'.isNotEmpty)
        .join(' · ');
    final bio = (p?['bio'] as String?)?.trim() ?? '';
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              Text(errorText(_error!), textAlign: TextAlign.center, style: TextStyle(color: t.mut)),
              const SizedBox(height: 12),
              BuButton(label: 'Yeniden dene', onPressed: _load),
            ]),
          )
        else if (p == null)
          const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())
        else ...[
          BuAvatar(name: name, url: p['avatarUrl'] as String?, size: 80),
          const SizedBox(height: 12),
          Text(name,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: t.ink)),
          if (dept.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(dept, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: t.mut)),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(bio, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.45, color: t.ink)),
          ],
          const SizedBox(height: 20),
          BuButton(label: 'Mesaj gönder', icon: LucideIcons.messageCircle, busy: _busy, onPressed: _message),
        ],
      ]),
    );
  }
}
