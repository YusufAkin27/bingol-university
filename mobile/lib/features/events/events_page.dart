import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../news/news_detail_page.dart';
import 'event_detail_page.dart';

const _monthNames = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];
const _monthShort = [
  'OCA', 'ŞUB', 'MAR', 'NİS', 'MAY', 'HAZ', 'TEM', 'AĞU', 'EYL', 'EKİ', 'KAS', 'ARA',
];
const _dayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _ym(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Birleşik takvim ve kullanıcı etkinlikleri için ortak, düz model.
Map<String, dynamic> _norm(Map e, {required bool calendar}) {
  final m = Map<String, dynamic>.from(e);
  m['source'] ??= 'USER';
  final start = DateTime.tryParse('${m['startsAt'] ?? ''}')?.toLocal();
  DateTime? day;
  if (start != null) {
    day = DateTime(start.year, start.month, start.day);
  } else {
    final p = DateTime.tryParse('${m['date'] ?? ''}');
    if (p != null) day = DateTime(p.year, p.month, p.day);
  }
  m['_day'] = day;
  m['_start'] = start;
  m['_end'] = DateTime.tryParse('${m['endsAt'] ?? ''}')?.toLocal();
  return m;
}

/// Etkinlikler: gün şeridi, Yaklaşan (birleşik takvim) | Etkinliklerim, RSVP, kod ile yoklama.
class EventsPage extends StatefulWidget {
  const EventsPage({super.key, required this.session});

  final Session session;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  int _tab = 0;
  late final DateTime _today;
  late DateTime _month; // ayın 1'i
  DateTime? _selected;

  final Map<String, List<Map<String, dynamic>>> _cache = {};
  final Map<int, Map<String, dynamic>> _rsvpState = {}; // etkinlik id -> {myRsvp, goingCount}
  final Set<int> _rsvpBusy = {};

  // Etkinliklerim sekmesi
  List<Map<String, dynamic>> _mine = [];
  int? _nextCursor;
  bool _moreBusy = false;

  bool _loading = true;
  Object? _error;
  int _gen = 0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _today = DateTime(n.year, n.month, n.day);
    _month = DateTime(n.year, n.month);
    _scroll.addListener(() {
      if (_tab == 1 && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMoreMine();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parse(dynamic res) {
    final list = res is Map ? res['items'] : res;
    if (list is! List) return [];
    return [for (final e in list) if (e is Map) e.cast<String, dynamic>()];
  }

  Future<List<Map<String, dynamic>>> _fetchMonth(DateTime m) async {
    final res = await widget.session.api.get('/events/calendar?month=${_ym(m)}');
    return [for (final e in _parse(res)) _norm(e, calendar: true)];
  }

  /// Takvim ayları (şerit 7 gün + seçili ay) ve RSVP durumları.
  Future<void> _load({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      if (_tab == 0) {
        final months = <DateTime>{_month};
        for (var i = 0; i < 7; i++) {
          final d = _today.add(Duration(days: i));
          months.add(DateTime(d.year, d.month));
        }
        final results = await Future.wait(months.map(_fetchMonth));
        // RSVP durumları (hata olursa yok sayılır).
        try {
          final mine = await widget.session.api.get('/me/events?size=50');
          for (final e in _parse(mine)) {
            final id = (e['id'] as num?)?.toInt();
            if (id != null) _rsvpState[id] = {'myRsvp': e['myRsvp'], 'goingCount': e['goingCount']};
          }
        } catch (_) {}
        if (!mounted || gen != _gen) return;
        setState(() {
          var i = 0;
          for (final m in months) {
            _cache[_ym(m)] = results[i++];
          }
          _loading = false;
          _error = null;
        });
      } else {
        final res = await widget.session.api.get('/me/events?size=20');
        if (!mounted || gen != _gen) return;
        setState(() {
          _mine = [for (final e in _parse(res)) _norm(e, calendar: false)];
          _nextCursor = (res is Map ? res['nextCursor'] : null) as int?;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() { _error = e; _loading = false; });
    }
  }

  Future<void> _loadMoreMine() async {
    if (_moreBusy || _loading || _nextCursor == null) return;
    final gen = _gen;
    setState(() => _moreBusy = true);
    try {
      final res = await widget.session.api.get('/me/events?size=20&cursor=$_nextCursor');
      if (!mounted || gen != _gen) return;
      setState(() {
        _mine = [..._mine, for (final e in _parse(res)) _norm(e, calendar: false)];
        _nextCursor = (res is Map ? res['nextCursor'] : null) as int?;
        _moreBusy = false;
      });
    } catch (_) {
      if (mounted && gen == _gen) setState(() => _moreBusy = false);
    }
  }

  void _setTab(int i) {
    if (i == _tab) return;
    setState(() { _tab = i; });
    _load();
  }

  Future<void> _goMonth(int delta) async {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = null;
    });
    if (_cache.containsKey(_ym(_month))) return;
    final gen = ++_gen;
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _fetchMonth(_month);
      if (!mounted || gen != _gen) return;
      setState(() { _cache[_ym(_month)] = items; _loading = false; });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() { _error = e; _loading = false; });
    }
  }

  void _pickDay(DateTime d) {
    final sameMonth = d.year == _month.year && d.month == _month.month;
    setState(() {
      _selected = (_selected == d) ? null : d;
      _month = DateTime(d.year, d.month);
    });
    if (!sameMonth && !_cache.containsKey(_ym(_month))) _load();
  }

  List<Map<String, dynamic>> get _monthItems {
    final all = _cache[_ym(_month)] ?? const [];
    return [
      for (final e in all)
        if (e['_day'] != null && !(e['_day'] as DateTime).isBefore(_today)) e,
    ];
  }

  Set<String> get _busyDays {
    final s = <String>{};
    for (final list in _cache.values) {
      for (final e in list) {
        final d = e['_day'] as DateTime?;
        if (d != null) s.add(_ymd(d));
      }
    }
    return s;
  }

  // RSVP durumu: önce yerel (iyimser) durum, sonra /me/events'ten gelen.
  String? _myRsvp(Map<String, dynamic> e) {
    final id = (e['id'] as num).toInt();
    if (e['source'] == 'OFFICIAL') return null;
    final s = _rsvpState[id];
    return s != null ? s['myRsvp'] as String? : e['myRsvp'] as String?;
  }

  int? _going(Map<String, dynamic> e) {
    final id = (e['id'] as num).toInt();
    final v = _rsvpState[id]?['goingCount'] ?? e['goingCount'];
    return (v as num?)?.toInt();
  }

  Future<void> _rsvp(Map<String, dynamic> ev, String? status) async {
    final id = (ev['id'] as num).toInt();
    if (_rsvpBusy.contains(id)) return;
    _rsvpBusy.add(id);
    final oldRsvp = _myRsvp(ev);
    final oldGoing = _going(ev);
    int? going = oldGoing;
    if (going != null) {
      if (oldRsvp == 'GOING') going--;
      if (status == 'GOING') going++;
      if (going < 0) going = 0;
    }
    setState(() => _rsvpState[id] = {'myRsvp': status, 'goingCount': going});
    try {
      final api = widget.session.api;
      final res = status == null
          ? await api.delete('/events/$id/rsvp')
          : await api.put('/events/$id/rsvp', {'status': status});
      if (res is Map && mounted) {
        setState(() => _rsvpState[id] = {'myRsvp': res['myRsvp'], 'goingCount': res['goingCount'] ?? going});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _rsvpState[id] = {'myRsvp': oldRsvp, 'goingCount': oldGoing});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    } finally {
      _rsvpBusy.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _open(Map<String, dynamic> ev) async {
    if (ev['source'] == 'OFFICIAL') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsDetailPage(session: widget.session, item: {
            'id': ev['id'],
            'title': ev['title'],
            'type': 'ETKINLIK',
            'imageUrl': ev['imageUrl'],
            'publishedDate': ev['date'],
            'url': ev['url'],
          }),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailPage(session: widget.session, eventId: (ev['id'] as num).toInt()),
      ),
    );
    if (mounted) _load(silent: true);
  }

  void _openCheckin() {
    final going = <Map<String, dynamic>>[
      for (final e in [..._monthItems, ..._mine])
        if (e['source'] != 'OFFICIAL' && _myRsvp(e) == 'GOING') e,
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bu.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CheckinSheet(session: widget.session, events: going),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: 'Etkinlikler',
            onBack: () => Navigator.pop(context),
            actions: [
              Material(
                color: t.sf,
                shape: StadiumBorder(side: BorderSide(color: t.bd)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _openCheckin,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.scanLine, size: 16, color: t.ink),
                      const SizedBox(width: 6),
                      Text('Yoklama', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: t.ink)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: BuSegmented(items: const ['Yaklaşan', 'Etkinliklerim'], index: _tab, onChanged: _setTab),
          ),
          if (_tab == 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${_monthNames[_month.month - 1]} ${_month.year}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.mut)),
                  ),
                  IconButton(
                    tooltip: 'Önceki ay',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(LucideIcons.chevronLeft, size: 20, color: t.ink),
                    onPressed: (_month.year == _today.year && _month.month == _today.month) ? null : () => _goMonth(-1),
                  ),
                  IconButton(
                    tooltip: 'Sonraki ay',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(LucideIcons.chevronRight, size: 20, color: t.ink),
                    onPressed: () => _goMonth(1),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _dayCell(_today.add(Duration(days: i)))),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime d) {
    final t = context.bu;
    final on = _selected == d;
    final dot = _busyDays.contains(_ymd(d));
    return GestureDetector(
      onTap: () => _pickDay(d),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: on ? t.pr : t.sf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? t.pr : t.bd),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_dayShort[d.weekday - 1],
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: on ? t.onPr : t.mut)),
            const SizedBox(height: 4),
            Text('${d.day}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: on ? t.onPr : t.ink)),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dot ? (on ? t.onPr : t.pr) : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!, onRetry: _load);

    final rows = <Object>[]; // DateTime başlığı veya etkinlik
    String emptyText;
    if (_tab == 1) {
      rows.addAll(_mine);
      emptyText = 'Katılacağın bir etkinlik yok.';
    } else {
      final items = _monthItems.where((e) => _selected == null || e['_day'] == _selected).toList();
      DateTime? last;
      for (final e in items) {
        final d = e['_day'] as DateTime;
        if (_selected == null && d != last) {
          rows.add(d);
          last = d;
        }
        rows.add(e);
      }
      emptyText = _selected != null ? 'Bu gün için etkinlik yok.' : 'Bu ay için etkinlik yok.';
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: rows.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [SizedBox(height: 320, child: EmptyView(icon: LucideIcons.calendarX, text: emptyText))],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, kNavInset),
              itemCount: rows.length + (_moreBusy ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= rows.length) {
                  return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
                }
                final r = rows[i];
                if (r is DateTime) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(2, 10, 0, 8),
                    child: Text(longDate(r),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.bu.mut)),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _card(r as Map<String, dynamic>),
                );
              },
            ),
    );
  }

  Widget _card(Map<String, dynamic> ev) {
    final t = context.bu;
    final official = ev['source'] == 'OFFICIAL';
    final day = ev['_day'] as DateTime?;
    final start = ev['_start'] as DateTime?;
    final end = ev['_end'] as DateTime?;
    final my = _myRsvp(ev);
    final going = _going(ev) ?? 0;
    final place = (ev['location'] as String?)?.trim();
    final org = (ev['communityName'] as String?)?.trim();
    final time = start == null ? '' : (end != null ? '${_hm(start)} – ${_hm(end)}' : _hm(start));

    Widget meta(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(children: [
            Icon(icon, size: 14, color: t.mut),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: t.mut)),
            ),
          ]),
        );

    return BuCard(
      radius: 22,
      onTap: () => _open(ev),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 64,
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(day == null ? '' : _monthShort[day.month - 1],
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.onSoft)),
                Text(day == null ? '' : '${day.day}',
                    style: TextStyle(fontSize: 22, height: 1.1, fontWeight: FontWeight.w800, color: t.onSoft)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (official || my == 'GOING' || my == 'INTERESTED')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: official
                        ? const BuBadge('Resmi', soft: true)
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(color: t.okSoft, borderRadius: BorderRadius.circular(999)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(LucideIcons.circleCheck, size: 12, color: t.ok),
                              const SizedBox(width: 5),
                              Text(my == 'GOING' ? 'Katılıyorsun' : 'İlgileniyorsun',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.ok)),
                            ]),
                          ),
                  ),
                Text('${ev['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: t.ink)),
                if (org != null && org.isNotEmpty) meta(LucideIcons.users, org),
                if (time.isNotEmpty) meta(LucideIcons.clock, time),
                if (place != null && place.isNotEmpty) meta(LucideIcons.mapPin, place),
                if (!official && going > 0) meta(LucideIcons.userCheck, '$going katılıyor'),
                if (!official) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: _actions(ev, my)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(Map<String, dynamic> ev, String? my) {
    final busy = _rsvpBusy.contains((ev['id'] as num).toInt());
    if (my == 'GOING') {
      return [
        BuButton(label: 'Vazgeç', compact: true, kind: BuButtonKind.outline, onPressed: busy ? null : () => _rsvp(ev, null)),
      ];
    }
    return [
      BuButton(label: 'Katılıyorum', compact: true, onPressed: busy ? null : () => _rsvp(ev, 'GOING')),
      if (my == 'INTERESTED')
        BuButton(label: 'Vazgeç', compact: true, kind: BuButtonKind.outline, onPressed: busy ? null : () => _rsvp(ev, null))
      else
        BuButton(label: 'İlgileniyorum', compact: true, kind: BuButtonKind.outline, onPressed: busy ? null : () => _rsvp(ev, 'INTERESTED')),
    ];
  }
}

/// Elle kod girişiyle yoklama: etkinlik seçilir, QR metni yapıştırılır.
class _CheckinSheet extends StatefulWidget {
  const _CheckinSheet({required this.session, required this.events});

  final Session session;
  final List<Map<String, dynamic>> events;

  @override
  State<_CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends State<_CheckinSheet> {
  final _code = TextEditingController();
  int? _eventId;
  bool _busy = false;
  String? _error;
  bool _done = false;
  List<Map<String, dynamic>> _options = [];

  @override
  void initState() {
    super.initState();
    _options = widget.events;
    if (_options.isNotEmpty) _eventId = (_options.first['id'] as num).toInt();
    _loadMine();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    try {
      final res = await widget.session.api.get('/me/events?size=50');
      final list = res is Map ? res['items'] : null;
      if (list is List && mounted) {
        final mine = [
          for (final e in list)
            if (e is Map && e['myRsvp'] == 'GOING') e.cast<String, dynamic>(),
        ];
        final byId = {for (final e in [..._options, ...mine]) (e['id'] as num).toInt(): e};
        setState(() {
          _options = byId.values.toList();
          _eventId ??= _options.isEmpty ? null : (_options.first['id'] as num).toInt();
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (_eventId == null || code.isEmpty) {
      setState(() => _error = _eventId == null ? 'Önce katılacağın bir etkinlik seç.' : 'Kodu yaz.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.session.api.post('/events/$_eventId/check-in', {'code': code});
      if (mounted) setState(() { _busy = false; _done = true; });
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = errorText(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yoklama', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.ink)),
            const SizedBox(height: 6),
            Text('Organizatörün gösterdiği QR kodunun metnini yaz ya da yapıştır.',
                style: TextStyle(fontSize: 13, color: t.mut)),
            const SizedBox(height: 16),
            if (_done) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: t.okSoft, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Icon(LucideIcons.circleCheck, color: t.ok),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Yoklaman alındı.', style: TextStyle(fontWeight: FontWeight.w800, color: t.ok)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              BuButton(label: 'Tamam', onPressed: () => Navigator.pop(context)),
            ] else ...[
              if (_options.isEmpty)
                Text('Yoklama için önce bir etkinliğe "Katılıyorum" demelisin.',
                    style: TextStyle(fontSize: 13, color: t.mut))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                      color: t.sf, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.bd)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _eventId,
                      dropdownColor: t.sf,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink),
                      items: [
                        for (final e in _options)
                          DropdownMenuItem(
                            value: (e['id'] as num).toInt(),
                            child: Text('${e['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() => _eventId = v),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                style: TextStyle(color: t.ink),
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Yoklama kodu',
                  hintStyle: TextStyle(color: t.mut),
                  counterText: '',
                  filled: true,
                  fillColor: t.sf,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.bd)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.bd)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.pr, width: 1.6)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(fontSize: 13, color: t.danger)),
              ],
              const SizedBox(height: 16),
              BuButton(label: 'Yoklamayı gönder', busy: _busy, onPressed: _options.isEmpty ? null : _submit),
            ],
          ],
        ),
      ),
    );
  }
}
