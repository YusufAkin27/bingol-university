import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../events/event_detail_page.dart';
import 'profil_widgets.dart' show ProfilCard, ProfilSection;
import 'profily_widgets.dart';

/// Etkinliklerim: Katıldıklarım (yaklaşan + geçmiş) / Oluşturduklarım (GET /me/events?mode=...).
/// Katılımdan ayrılma etkinlik ayrıntı sayfasındadır.
class MyEventsPage extends StatefulWidget {
  const MyEventsPage({super.key, required this.session});

  final Session session;

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _Feed {
  List<Map<String, dynamic>> items = [];
  int? next;
  bool loading = false;
  bool loaded = false;
  bool more = false;
  Object? error;
  int gen = 0;
}

class _MyEventsPageState extends State<MyEventsPage> {
  int _tab = 0;
  final _scroll = ScrollController();
  final Map<String, _Feed> _feeds = {'up': _Feed(), 'past': _Feed(), 'created': _Feed()};

  List<String> get _keys => _tab == 0 ? const ['up', 'past'] : const ['created'];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _loadTab();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadTab({bool silent = false}) {
    for (final k in _keys) {
      _load(k, silent: silent);
    }
  }

  String _path(String key, {int? cursor}) {
    final mode = switch (key) {
      'created' => 'organizing',
      'past' => 'past',
      _ => 'attending',
    };
    return '/me/events?mode=$mode&size=20${cursor == null ? '' : '&cursor=$cursor'}';
  }

  DateTime? _start(Map<String, dynamic> e) => DateTime.tryParse('${e['startsAt'] ?? ''}')?.toLocal();
  DateTime? _end(Map<String, dynamic> e) => DateTime.tryParse('${e['endsAt'] ?? ''}')?.toLocal();

  bool _isPast(Map<String, dynamic> e) {
    final end = _end(e) ?? _start(e);
    return end != null && end.isBefore(DateTime.now());
  }

  /// Sunucu modu desteklemese bile Yaklaşan/Geçmiş ayrımı istemcide doğrulanır.
  List<Map<String, dynamic>> _parse(String key, dynamic res) {
    final list = res is Map ? res['items'] : res;
    if (list is! List) return [];
    final all = [
      for (final e in list)
        if (e is Map) e.cast<String, dynamic>()
    ];
    return switch (key) {
      'up' => all.where((e) => !_isPast(e)).toList(),
      'past' => all.where(_isPast).toList(),
      _ => all,
    };
  }

  int? _next(dynamic res) => (res is Map ? res['nextCursor'] : null) is num ? (res['nextCursor'] as num).toInt() : null;

  Future<void> _load(String key, {bool silent = false}) async {
    final f = _feeds[key]!;
    final gen = ++f.gen;
    if (!silent || !f.loaded) {
      setState(() {
        f.loading = true;
        f.error = null;
      });
    }
    try {
      final res = await widget.session.api.get(_path(key));
      if (!mounted || gen != f.gen) return;
      setState(() {
        f.items = _parse(key, res);
        f.next = _next(res);
        f.loading = false;
        f.loaded = true;
        f.error = null;
      });
    } catch (e) {
      if (!mounted || gen != f.gen) return;
      setState(() {
        f.error = e;
        f.loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    for (final key in _keys) {
      final f = _feeds[key]!;
      if (f.more || f.loading || f.next == null) continue;
      final gen = f.gen;
      setState(() => f.more = true);
      try {
        final res = await widget.session.api.get(_path(key, cursor: f.next));
        if (!mounted || gen != f.gen) return;
        setState(() {
          final seen = f.items.map((e) => e['id']).toSet();
          f.items = [...f.items, ..._parse(key, res).where((e) => seen.add(e['id']))];
          f.next = _next(res);
          f.more = false;
        });
      } catch (_) {
        if (mounted) setState(() => f.more = false);
      }
      return;
    }
  }

  Future<void> _open(Map<String, dynamic> e) async {
    final id = (e['id'] as num?)?.toInt();
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailPage(session: widget.session, eventId: id)),
    );
    if (mounted) _loadTab(silent: true);
  }

  void _switch(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    for (final k in _keys) {
      if (!_feeds[k]!.loaded) _load(k);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final fs = [for (final k in _keys) _feeds[k]!];
    final loading = fs.any((f) => f.loading && !f.loaded);
    final failed = fs.where((f) => f.error != null && f.items.isEmpty).firstOrNull;
    final empty = fs.every((f) => f.items.isEmpty);

    Widget body;
    if (loading && empty) {
      body = const LoadingView();
    } else if (failed != null && empty) {
      body = ErrorView(error: failed.error!, onRetry: () => _loadTab());
    } else if (empty) {
      body = _scrollable(children: [
        ProfilyEmptyCard(
          horizontal: true,
          icon: LucideIcons.calendar,
          title: l.profilyardEventsEmptyTitle,
          body: l.profilyardEventsEmptyBody,
        ),
      ]);
    } else {
      final first = _tab == 0 && _feeds['up']!.items.isNotEmpty;
      body = _scrollable(children: [
        if (_tab == 0) ...[
          if (_feeds['up']!.items.isNotEmpty) ...[
            ProfilSection(l.profilyardEventsUpcoming, top: 0),
            ProfilCard(children: [for (final e in _feeds['up']!.items) _row(e)]),
          ],
          if (_feeds['past']!.items.isNotEmpty) ...[
            ProfilSection(l.profilyardEventsPast, top: first ? 22 : 0),
            ProfilCard(children: [for (final e in _feeds['past']!.items) _row(e)]),
          ],
        ] else
          ProfilCard(children: [for (final e in _feeds['created']!.items) _row(e)]),
        if (fs.any((f) => f.more))
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      ]);
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.profileMyEvents, onBack: () => Navigator.pop(context)),
        const SizedBox(height: 8),
        ProfilyTabs(
          labels: [l.profilyardEventsAttended, l.profilyardEventsCreated],
          index: _tab,
          onChanged: _switch,
        ),
        Expanded(child: body),
      ]),
    );
  }

  Widget _scrollable({required List<Widget> children}) => RefreshIndicator(
        color: context.bu.pr,
        onRefresh: () async => _loadTab(silent: true),
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: children,
        ),
      );

  String _month(int m) {
    final l = context.l10n;
    return [
      l.eventListMon1, l.eventListMon2, l.eventListMon3, l.eventListMon4,
      l.eventListMon5, l.eventListMon6, l.eventListMon7, l.eventListMon8,
      l.eventListMon9, l.eventListMon10, l.eventListMon11, l.eventListMon12,
    ][m - 1];
  }

  String _upper(String s) => Localizations.localeOf(context).languageCode == 'tr' ? trUpper(s) : s.toUpperCase();

  Widget? _pill(Map<String, dynamic> e) {
    final l = context.l10n;
    if (e['status'] == 'CANCELLED') return ProfilyPill(l.eventListCancelled, tone: ProfilyTone.red);
    if (_tab == 1) {
      final n = [e['pendingRequestCount'], e['pendingRequests'], e['pendingCount']].whereType<num>().firstOrNull?.toInt();
      return (n != null && n > 0) ? ProfilyPill(l.profilyardEventPendingCount('$n'), tone: ProfilyTone.red) : null;
    }
    return switch (e['myRsvp']) {
      'GOING' => ProfilyPill(l.profilyardEventGoing, tone: ProfilyTone.green),
      'INTERESTED' => ProfilyPill(l.profilyardEventInterested, tone: ProfilyTone.violet),
      'REQUESTED' || 'PENDING' => ProfilyPill(l.profilyardEventRequested, tone: ProfilyTone.amber),
      _ => null,
    };
  }

  Widget _row(Map<String, dynamic> e) {
    final t = context.bu;
    final start = _start(e);
    final place = (e['location'] as String?)?.trim();
    final hm = start == null
        ? ''
        : '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final sub = [if (place != null && place.isNotEmpty) place, if (hm.isNotEmpty) hm].join(' · ');
    return ProfilyRow(
      minHeight: 76,
      onTap: () => _open(e),
      child: Row(children: [
        ExcludeSemantics(
          child: Container(
            width: 50,
            height: 54,
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.bd),
            ),
            child: start == null
                ? Icon(LucideIcons.calendar, size: 20, color: t.mut)
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(start.day.toString().padLeft(2, '0'),
                        style: BuType.heading.copyWith(fontSize: 18, fontWeight: FontWeight.w800, height: 1.1, color: t.ink)),
                    Text(_upper(_month(start.month)),
                        maxLines: 1,
                        style: BuType.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, height: 1.1, color: t.pr)),
                  ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: ProfilyTitleBlock(title: '${e['title'] ?? ''}', sub: sub, pill: _pill(e), titleSize: 14.5)),
        const SizedBox(width: 6),
        Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut),
      ]),
    );
  }
}
