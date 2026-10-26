import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../clubs/club_detail_page.dart';
import '../events/event_detail_page.dart';
import '../events/events_page.dart';
import '../menu/menu_page.dart';
import '../news/news_detail_page.dart';
import '../notifications/notifications_page.dart';
import '../search/search_page.dart';
import '../support/support_page.dart';

/// Ana sayfa: selamlama, arama, sıradaki etkinlik, hızlı erişim, bento kutular, kulüpler, gündem.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.session, required this.onOpenTab});

  final Session session;

  /// Alt sekmeye geç (0 Ana Sayfa, 1 Keşfet, 2 Sohbet, 3 Kulüpler, 4 Profil); haber türü verilirse o filtre seçilir.
  final void Function(int tab, {String? newsType}) onOpenTab;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

const _newsTypes = [('HABER', 'Haber'), ('DUYURU', 'Duyuru'), ('ETKINLIK', 'Etkinlik')];
const _monthNames = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

class _HomeTabState extends State<HomeTab> {
  // Bölümler bağımsız yüklenir; null = henüz gelmedi ya da düştü.
  Map<String, dynamic>? _info;
  Map<String, dynamic>? _today;
  Map<String, dynamic>? _event;
  List<Map<String, dynamic>>? _clubs;
  final Map<String, List<Map<String, dynamic>>> _news = {};
  bool _newsStale = false;

  bool _loading = true;
  Object? _error;
  int _gen = 0;
  String _newsType = 'DUYURU';
  bool _rsvpBusy = false;

  Session get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gen = ++_gen;
    final api = _s.api;
    var ok = 0;
    Object? firstError;
    Future<void> step(Future<void> Function() f) async {
      try {
        await f();
        ok++;
      } catch (e) {
        firstError ??= e;
      }
    }

    void apply(VoidCallback f) {
      if (mounted && gen == _gen) setState(f);
    }

    await Future.wait([
      step(() async {
        final r = await api.get('/app/info');
        apply(() => _info = r is Map<String, dynamic> ? r : null);
      }),
      step(() async {
        final r = await api.get('/menu/today');
        apply(() => _today = r is Map<String, dynamic> ? r : null);
      }),
      step(() async {
        final now = DateTime.now();
        final months = <DateTime>[now];
        if (now.day >= 22) months.add(DateTime(now.year, now.month + 1, 1));
        Map<String, dynamic>? best;
        DateTime? bestAt;
        Object? err;
        var got = 0;
        for (final m in months) {
          try {
            final mm = '${m.year}-${m.month.toString().padLeft(2, '0')}';
            final r = await api.get('/events/calendar?month=$mm');
            got++;
            if (r is! List) continue;
            for (final e in r) {
              if (e is! Map<String, dynamic>) continue;
              final st = DateTime.tryParse((e['startsAt'] as String?) ?? '')?.toLocal();
              final d = st ?? DateTime.tryParse((e['date'] as String?) ?? '');
              if (d == null) continue;
              final upcoming = st != null
                  ? st.isAfter(now.subtract(const Duration(hours: 1)))
                  : !DateTime(d.year, d.month, d.day).isBefore(DateTime(now.year, now.month, now.day));
              if (!upcoming) continue;
              if (bestAt == null || d.isBefore(bestAt)) {
                best = e;
                bestAt = d;
              }
            }
          } catch (e) {
            err ??= e;
          }
        }
        if (got == 0 && err != null) throw err;
        if (best != null && best['source'] == 'USER' && best['id'] != null) {
          try {
            final d = await api.get('/events/${best['id']}');
            if (d is Map<String, dynamic>) best = {...best, 'goingCount': d['goingCount'], 'myRsvp': d['myRsvp']};
          } catch (_) {}
        }
        apply(() => _event = best);
      }),
      step(() async {
        final r = await api.get('/me/communities?size=20') as Map<String, dynamic>;
        final l = List<Map<String, dynamic>>.from(r['items'] as List);
        apply(() => _clubs = l);
      }),
      for (final t in _newsTypes)
        step(() async {
          final r = await api.get('/news?type=${t.$1}&page=0&size=3') as Map<String, dynamic>;
          final l = List<Map<String, dynamic>>.from(r['items'] as List);
          apply(() => _news[t.$1] = l);
        }),
      step(() async {
        final st = await api.get('/status') as Map<String, dynamic>;
        final stale = (st['NEWS'] as Map?)?['maintenance'] == true || (st['MENU'] as Map?)?['maintenance'] == true;
        apply(() => _newsStale = stale);
      }),
    ]);
    if (!mounted || gen != _gen) return;
    setState(() {
      _loading = false;
      _error = (ok == 0) ? firstError : null;
    });
  }

  Future<void> _reload() async {
    await _load();
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return 'İyi geceler';
    if (h < 12) return 'Günaydın';
    if (h < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  Future<void> _openUrl(String? url) async {
    final u = url == null ? null : Uri.tryParse(url);
    if (u != null && u.scheme == 'https') {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _rsvp() async {
    final ev = _event;
    final id = (ev?['id'] as num?)?.toInt();
    if (ev == null || id == null || _rsvpBusy) return;
    setState(() => _rsvpBusy = true);
    try {
      final r = await _s.api.put('/events/$id/rsvp', {'status': 'GOING'});
      if (!mounted) return;
      setState(() {
        _event = {
          ...ev,
          if (r is Map) 'myRsvp': r['myRsvp'] ?? 'GOING',
          if (r is Map && r['goingCount'] != null) 'goingCount': r['goingCount'],
        };
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    } finally {
      if (mounted) setState(() => _rsvpBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null) {
      body = ErrorView(error: _error!, onRetry: () {
        setState(() => _loading = true);
        _load();
      });
    } else {
      body = RefreshIndicator(
        color: t.pr,
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.only(bottom: kNavInset),
          physics: const AlwaysScrollableScrollPhysics(),
          children: _content(context),
        ),
      );
    }
    return ColoredBox(color: t.bg, child: body);
  }

  List<Widget> _content(BuildContext context) {
    final t = context.bu;
    final maintenance = _info?['maintenance'] as Map?;
    final banner = _info?['banner'] as Map?;
    final clubs = _clubs;
    final news = _news[_newsType] ?? const <Map<String, dynamic>>[];
    return [
      _header(context),
      if (maintenance?['enabled'] == true)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: StaleBanner(text: (maintenance?['message'] as String?) ?? 'Sistem bakımda.'),
        ),
      if (banner != null && ((banner['text'] ?? banner['message']) as String?)?.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: InkWell(
            onTap: () => _openUrl(banner['url'] as String?),
            child: StaleBanner(
                text: (banner['text'] ?? banner['message']) as String, icon: LucideIcons.megaphone),
          ),
        ),
      if (_newsStale)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: StaleBanner(text: 'Kaynak site şu an ulaşılamıyor; veriler güncel olmayabilir.'),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: BuSearchField(
          hint: 'Haber, kulüp, etkinlik ara',
          readOnly: true,
          onTap: () => _push(SearchPage(session: _s)),
        ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: _eventCard(context)),
      Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), child: _quickAccess(context)),
      Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), child: _bento(context)),
      if (clubs != null && clubs.isNotEmpty) ...[
        BuSectionTitle('Kulüplerimden',
            action: 'Tümü', onAction: () => widget.onOpenTab(3), padding: const EdgeInsets.fromLTRB(20, 20, 20, 10)),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: clubs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _clubCard(clubs[i], i),
          ),
        ),
      ],
      BuSectionTitle('Gündem',
          action: 'Tümü',
          onAction: () => widget.onOpenTab(1, newsType: _newsType),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10)),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          for (final nt in _newsTypes) ...[
            BuChip(label: nt.$2, selected: _newsType == nt.$1, onTap: () => setState(() => _newsType = nt.$1)),
            const SizedBox(width: 8),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      if (news.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Text('Henüz içerik yok.', textAlign: TextAlign.center, style: TextStyle(color: t.mut)),
        )
      else
        for (final n in news)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: _newsRow(context, n),
          ),
    ];
  }

  Widget _header(BuildContext context) {
    final t = context.bu;
    final name = (_s.displayName ?? '').trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 0),
      child: Row(
        children: [
          BuAvatar(name: name, size: 44, dark: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting, style: TextStyle(fontSize: 13, color: t.mut)),
                Text(name.isEmpty ? 'BÜ Kampüs' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: t.ink)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<int>(
            valueListenable: _s.badges.notifications,
            builder: (_, n, __) => BuIconButton(
              icon: LucideIcons.bell,
              badge: n > 0,
              tooltip: 'Bildirimler',
              onTap: () => _push(NotificationsPage(session: _s)),
            ),
          ),
        ],
      ),
    );
  }

  String _eventWhen(Map<String, dynamic> e) {
    final d = DateTime.tryParse((e['startsAt'] as String?) ?? '')?.toLocal();
    if (d == null) return '';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_monthNames[d.month - 1]} · $hh:$mm';
  }

  Widget _eventCard(BuildContext context) {
    final e = _event;
    if (e == null) {
      return BuHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroPill(LucideIcons.calendar, 'Sıradaki etkinlik'),
            const SizedBox(height: 12),
            const Text('Yaklaşan etkinlik yok',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 14),
            _whitePill('Etkinliklere göz at', () => _push(EventsPage(session: _s))),
          ],
        ),
      );
    }
    final id = (e['id'] as num?)?.toInt();
    final official = e['source'] == 'OFFICIAL';
    final going = (e['goingCount'] as num?)?.toInt() ?? 0;
    final mine = e['myRsvp'] == 'GOING';
    final loc = (e['location'] as String?) ?? '';
    final when = official ? niceDate(e['date'] as String?) : _eventWhen(e);
    return GestureDetector(
      onTap: id == null
          ? null
          : () => official
              ? _push(NewsDetailPage(session: _s, item: {
                    'id': id,
                    'title': e['title'],
                    'type': 'ETKINLIK',
                    'imageUrl': e['imageUrl'],
                    'publishedDate': e['date'],
                    'url': e['url'],
                  }))
              : _push(EventDetailPage(session: _s, eventId: id)),
      child: BuHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroPill(LucideIcons.calendar, official ? 'Resmi etkinlik' : 'Sıradaki etkinlik'),
            const SizedBox(height: 10),
            Text((e['title'] as String?) ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 6),
            Wrap(spacing: 14, runSpacing: 2, children: [
              if (when.isNotEmpty) Text(when, style: const TextStyle(fontSize: 12)),
              if (loc.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(loc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ),
            ]),
            const SizedBox(height: 14),
            if (!official)
              Row(children: [
                const Icon(LucideIcons.users, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('$going kişi katılıyor',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                if (mine)
                  _whitePill('Katılıyorsun', null)
                else
                  _whitePill('Katıl', id == null ? null : _rsvp, busy: _rsvpBusy),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _heroPill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      );

  Widget _whitePill(String label, VoidCallback? onTap, {bool busy = false}) {
    return Material(
      color: Colors.white.withValues(alpha: onTap == null ? .75 : 1),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: BuColors.red700))
              : Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF8E1B13))),
        ),
      ),
    );
  }

  Widget _quickAccess(BuildContext context) {
    final items = <(IconData, String, ValueListenable<int>?, VoidCallback)>[
      (LucideIcons.messageCircle, 'Sohbet', _s.badges.chat, () => widget.onOpenTab(2)),
      (LucideIcons.users, 'Kulüpler', null, () => widget.onOpenTab(3)),
      (LucideIcons.calendar, 'Etkinlik', null, () => _push(EventsPage(session: _s))),
      (LucideIcons.utensils, 'Yemek', null, () => _push(MenuPage(session: _s))),
      (LucideIcons.lifeBuoy, 'Destek', null, () => _push(SupportPage(session: _s))),
    ];
    return Row(
      children: [
        for (final it in items)
          Expanded(child: _QuickItem(icon: it.$1, label: it.$2, badge: it.$3, onTap: it.$4)),
      ],
    );
  }

  Widget _bento(BuildContext context) {
    final t = context.bu;
    final items = List<String>.from((_today?['items'] as List?) ?? const []);
    final clubCount = _clubs?.length;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 115,
            child: Material(
              color: t.soft,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _push(MenuPage(session: _s)),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 150),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(LucideIcons.utensils, size: 20, color: t.onSoft),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Bugünün yemeği',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: t.onSoft)),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Text(
                        items.isEmpty ? 'Bugün için liste yok' : items.take(4).join('\n'),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.5, color: t.onSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 100,
            child: Column(
              children: [
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _s.badges.chat,
                    builder: (_, n, __) => _statBox(
                      color: t.ink,
                      value: '$n',
                      label: 'yeni mesaj',
                      fg: t.bg,
                      sub: t.bg.withValues(alpha: .85),
                      arrow: t.bg,
                      border: false,
                      onTap: () => widget.onOpenTab(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _statBox(
                    color: t.sf,
                    value: clubCount == null ? '–' : '$clubCount',
                    label: 'kulüp üyeliği',
                    fg: t.ink,
                    sub: t.mut,
                    arrow: t.pr,
                    border: true,
                    onTap: () => widget.onOpenTab(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox({
    required Color color,
    required String value,
    required String label,
    required Color fg,
    required Color sub,
    required Color arrow,
    required bool border,
    required VoidCallback onTap,
  }) {
    final t = context.bu;
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: border ? BorderSide(color: t.bd) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg, height: 1.2)),
                  Text(label,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: sub)),
                ],
              ),
            ),
            Icon(LucideIcons.arrowRight, size: 22, color: arrow),
          ]),
        ),
      ),
    );
  }

  Widget _clubCard(Map<String, dynamic> c, int i) {
    final t = context.bu;
    final id = (c['id'] as num?)?.toInt();
    final members = (c['memberCount'] as num?)?.toInt();
    return SizedBox(
      width: 168,
      child: BuCard(
        padding: const EdgeInsets.all(14),
        onTap: id == null ? null : () => _push(ClubDetailPage(session: _s, communityId: id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuAvatar(name: c['name'] as String?, url: c['coverUrl'] as String?, size: 36, square: true, dark: i.isOdd),
            const SizedBox(height: 10),
            Text((c['name'] as String?) ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.ink)),
            const SizedBox(height: 2),
            Text(members == null ? '' : '$members üye',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: t.mut)),
          ],
        ),
      ),
    );
  }

  Widget _newsRow(BuildContext context, Map<String, dynamic> n) {
    final t = context.bu;
    final img = n['imageUrl'] as String?;
    final type = n['type'] as String?;
    return BuCard(
      padding: const EdgeInsets.all(12),
      radius: 18,
      onTap: () => _push(NewsDetailPage(session: _s, item: n)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NewsThumb(img, width: 72, height: 72, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  BuBadge(TypeBadge.label(type), soft: type == 'ETKINLIK'),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(fmtDate(n['publishedDate'] as String?),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: t.mut)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text((n['title'] as String?) ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w700, color: t.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickItem extends StatelessWidget {
  const _QuickItem({required this.icon, required this.label, required this.onTap, this.badge});

  final IconData icon;
  final String label;
  final ValueListenable<int>? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: t.sf,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: t.bd),
                  ),
                  child: Icon(icon, size: 24, color: t.pr),
                ),
                if (badge != null)
                  ValueListenableBuilder<int>(
                    valueListenable: badge!,
                    builder: (_, n, __) => n <= 0
                        ? const SizedBox.shrink()
                        : Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 18),
                              height: 18,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: t.pr,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: t.bg, width: 2),
                              ),
                              child: Text(n > 99 ? '99+' : '$n',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: t.onPr)),
                            ),
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.ink)),
        ],
      ),
    );
  }
}
