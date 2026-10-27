import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../news/news_detail_page.dart';
import '../platform/qr_scan_page.dart';
import 'event_detail_page.dart';
import '../../core/typography.dart';

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
    // Resmi öğede haberin etkinlik tarihi varsa o, yoksa yayın tarihi.
    final p = DateTime.tryParse('${m['eventDate'] ?? m['date'] ?? ''}') ?? DateTime.tryParse('${m['date'] ?? ''}');
    if (p != null) day = DateTime(p.year, p.month, p.day);
  }
  final end = DateTime.tryParse('${m['endsAt'] ?? ''}')?.toLocal();
  m['_day'] = day;
  m['_start'] = start;
  m['_end'] = end;
  m['_endDay'] = (end != null && day != null && !DateTime(end.year, end.month, end.day).isBefore(day))
      ? DateTime(end.year, end.month, end.day)
      : day;
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
  late DateTime _stripStart; // 7 günlük şeridin ilk günü
  DateTime? _selected;
  bool _checkinBusy = false;

  final Map<String, List<Map<String, dynamic>>> _cache = {};
  final Set<String> _truncated = {}; // X-Truncated: true dönen aylar
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
    _stripStart = _today;
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
    final res = await widget.session.api.getResponse('/events/calendar?month=${_ym(m)}');
    if (res.headers['x-truncated'] == 'true') {
      _truncated.add(_ym(m));
    } else {
      _truncated.remove(_ym(m));
    }
    return [for (final e in _parse(res.body)) _norm(e, calendar: true)];
  }

  /// Takvim ayları (şerit 7 gün + seçili ay) ve RSVP durumları.
  Future<void> _load({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      if (_tab == 0) {
        final months = <DateTime>{_month};
        for (var i = 0; i < 7; i++) {
          final d = _stripStart.add(Duration(days: i));
          months.add(DateTime(d.year, d.month));
        }
        final results = await Future.wait(months.map(_fetchMonth));
        if (!mounted || gen != _gen) return;
        setState(() {
          var i = 0;
          _rsvpState.clear(); // takvim öğesi RSVP için tek kaynak
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
      final cur = _month.year == _today.year && _month.month == _today.month;
      _stripStart = cur ? _today : _month;
    });
    final stripMonths = <DateTime>{
      _month,
      for (var i = 0; i < 7; i++) DateTime(_stripStart.add(Duration(days: i)).year, _stripStart.add(Duration(days: i)).month),
    }.where((m) => !_cache.containsKey(_ym(m))).toList();
    if (stripMonths.isEmpty) return;
    final gen = ++_gen;
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait(stripMonths.map(_fetchMonth));
      if (!mounted || gen != _gen) return;
      setState(() {
        for (var i = 0; i < stripMonths.length; i++) {
          _cache[_ym(stripMonths[i])] = results[i];
        }
        _loading = false;
      });
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

  bool get _isPastMonth => DateTime(_month.year, _month.month + 1).isBefore(DateTime(_today.year, _today.month + 1));

  /// Ay dışından süren etkinliklerin günü ay sınırına çekilir (sunucu `date` alanıyla uyumlu).
  DateTime _effDay(Map<String, dynamic> e) {
    var d = e['_day'] as DateTime;
    final first = DateTime(_month.year, _month.month);
    final last = DateTime(_month.year, _month.month + 1, 0);
    if (d.isBefore(first)) d = first;
    if (d.isAfter(last)) d = last;
    // Güncel ayda süren etkinlik "bugün" altında görünür.
    if (!_isPastMonth && d.isBefore(_today) && !(e['_endDay'] as DateTime).isBefore(_today)) d = _today;
    return d;
  }

  List<Map<String, dynamic>> get _monthItems {
    final all = _cache[_ym(_month)] ?? const [];
    return [
      for (final e in all)
        if (e['_day'] != null && (_isPastMonth || !(e['_endDay'] as DateTime).isBefore(_today))) e,
    ];
  }

  Set<String> _busyDaySet() {
    final s = <String>{};
    for (final list in _cache.values) {
      for (final e in list) {
        final d = e['_day'] as DateTime?;
        if (d == null) continue;
        final end = (e['_endDay'] as DateTime?) ?? d;
        var x = d;
        for (var n = 0; n < 31 && !x.isAfter(end); n++) {
          s.add(_ymd(x));
          x = DateTime(x.year, x.month, x.day + 1);
        }
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
    final oldRsvp = _myRsvp(ev);
    final oldGoing = _going(ev);
    final cap = (ev['capacity'] as num?)?.toInt();
    if (status == 'GOING' && oldRsvp != 'GOING' && cap != null && (oldGoing ?? 0) >= cap) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Kontenjan doldu. "İlgileniyorum" ile takipte kalabilirsin.')));
      return;
    }
    int? going = oldGoing;
    if (going != null) {
      if (oldRsvp == 'GOING') going--;
      if (status == 'GOING') going++;
      if (going < 0) going = 0;
    }
    _rsvpBusy.add(id);
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
            if (ev['eventDate'] != null) 'eventDate': ev['eventDate'],
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

  /// QR'ı tara (ya da elle kod gir); koddaki etkinlik kimliğiyle yoklama gönder.
  /// Kod biçimi: "bingol-checkin:{etkinlikId}.{pencere}.{imza}" (elle girişte önek olmayabilir).
  Future<void> _scanCheckin() async {
    if (_checkinBusy) return;
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanPage(title: 'Yoklama QR kodunu tara')),
    );
    if (raw == null || !mounted) return;
    const prefix = 'bingol-checkin:';
    final code = raw.trim().startsWith(prefix) ? raw.trim().substring(prefix.length) : raw.trim();
    final id = int.tryParse(code.split('.').first);
    if (id == null) {
      _snack('Bu bir yoklama kodu değil.');
      return;
    }
    setState(() => _checkinBusy = true);
    try {
      await widget.session.api.post('/events/$id/check-in', {'code': code});
      _snack('Yoklaman alındı.');
    } catch (e) {
      _snack(errorText(e));
    } finally {
      if (mounted) setState(() => _checkinBusy = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final busy = _tab == 0 ? _busyDaySet() : const <String>{};
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
                  onTap: _checkinBusy ? null : _scanCheckin,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _checkinBusy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(LucideIcons.scanLine, size: 16, color: t.ink),
                      const SizedBox(width: 6),
                      Text('Yoklama', style: BuType.label.copyWith(color: t.ink)),
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
                        style: BuType.bodyStrong.copyWith(color: t.mut)),
                  ),
                  IconButton(
                    tooltip: 'Önceki ay',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(LucideIcons.chevronLeft, size: 20, color: t.ink),
                    onPressed: _month.isBefore(DateTime(_today.year - 1, _today.month)) ? null : () => _goMonth(-1),
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
                    Expanded(child: _dayCell(_stripStart.add(Duration(days: i)), busy)),
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

  Widget _dayCell(DateTime d, Set<String> busyDays) {
    final t = context.bu;
    final on = _selected == d;
    final dot = busyDays.contains(_ymd(d));
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
                style: BuType.micro.copyWith(color: on ? t.onPr : t.mut)),
            const SizedBox(height: 4),
            Text('${d.day}',
                style: BuType.title.copyWith(color: on ? t.onPr : t.ink)),
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
      final sel = _selected;
      final items = _monthItems.where((e) {
        if (sel == null) return true;
        final d = e['_day'] as DateTime;
        return !d.isAfter(sel) && !(e['_endDay'] as DateTime).isBefore(sel);
      }).toList()
        ..sort((a, b) => _effDay(a).compareTo(_effDay(b)));
      DateTime? last;
      for (final e in items) {
        final d = _effDay(e);
        if (_selected == null && d != last) {
          rows.add(d);
          last = d;
        }
        rows.add(e);
      }
      emptyText = _selected != null ? 'Bu gün için etkinlik yok.' : 'Bu ay için etkinlik yok.';
      final note = _isPastMonth
          ? 'Geçmiş ay: yalnızca görüntüleme.'
          : (_truncated.contains(_ym(_month)) ? 'Bu ayın tamamı gösterilemiyor; bazı etkinlikler listede yok.' : null);
      if (note != null) rows.insert(0, note);
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
                if (r is String) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Icon(LucideIcons.info, size: 14, color: context.bu.mut),
                      const SizedBox(width: 6),
                      Expanded(child: Text(r, style: BuType.caption.copyWith(color: context.bu.mut))),
                    ]),
                  );
                }
                if (r is DateTime) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(2, 10, 0, 8),
                    child: Text(longDate(r),
                        style: BuType.label.copyWith(color: context.bu.mut)),
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
    final day = ev['_day'] == null ? null : (_tab == 0 ? _effDay(ev) : ev['_day'] as DateTime);
    final past = _isPastMonth && _tab == 0;
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
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut)),
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
                    style: BuType.micro.copyWith(color: t.onSoft)),
                Text(day == null ? '' : '${day.day}',
                    style: BuType.title.copyWith(height: 1.1, color: t.onSoft)),
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
                                  style: BuType.micro.copyWith(color: t.ok)),
                            ]),
                          ),
                  ),
                Text('${ev['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.heading.copyWith(color: t.ink)),
                if (org != null && org.isNotEmpty) meta(LucideIcons.users, org),
                if (time.isNotEmpty) meta(LucideIcons.clock, time),
                if (place != null && place.isNotEmpty) meta(LucideIcons.mapPin, place),
                if (!official && going > 0) meta(LucideIcons.userCheck, '$going katılıyor'),
                if (!official && !past) ...[
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
