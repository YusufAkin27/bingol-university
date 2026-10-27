import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../news/news_detail_page.dart';
import '../platform/qr_scan_page.dart';
import 'event_cover.dart';
import 'event_detail_page.dart';
import 'event_form_page.dart';
import 'event_parts.dart';

const _monthNames = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];
const _dayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _ym(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Birleşik takvim ve kullanıcı etkinlikleri için ortak, düz model.
Map<String, dynamic> _norm(Map e) {
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

/// Sayfalı kişisel liste (Yaklaşan / Geçmiş / Oluşturduklarım) durumu.
class _Feed {
  List<Map<String, dynamic>> items = [];
  int? next;
  bool loading = false;
  bool loaded = false;
  bool more = false;
  Object? error;
  int gen = 0;
}

/// Etkinlikler: Keşfet (takvim) | Etkinliklerim | Oluşturduklarım. Katılım yalnızca burada geri alınır.
class EventsPage extends StatefulWidget {
  const EventsPage({super.key, required this.session, this.initialTab = 0});

  final Session session;

  /// 0 Keşfet, 1 Etkinliklerim, 2 Oluşturduklarım.
  final int initialTab;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  int _tab = 0;
  int _sub = 0; // Etkinliklerim: 0 Yaklaşan, 1 Geçmiş
  late final DateTime _today;
  late DateTime _month; // ayın 1'i
  late DateTime _stripStart; // 7 günlük şeridin ilk günü
  DateTime? _selected;
  bool _checkinBusy = false;

  final Map<String, List<Map<String, dynamic>>> _cache = {};
  final Set<String> _truncated = {}; // X-Truncated: true dönen aylar
  final Map<int, Map<String, dynamic>> _rsvpState = {}; // etkinlik id -> {myRsvp, goingCount}
  final Set<int> _rsvpBusy = {};
  final Set<int> _closedIds = {}; // 409 EVENT_REGISTRATION_CLOSED alan etkinlikler

  final Map<String, _Feed> _feeds = {'up': _Feed(), 'past': _Feed(), 'created': _Feed()};

  bool _loading = true;
  Object? _error;
  int _gen = 0;
  final _scroll = ScrollController();

  String get _feedKey => _tab == 2 ? 'created' : (_sub == 1 ? 'past' : 'up');

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _today = DateTime(n.year, n.month, n.day);
    _month = DateTime(n.year, n.month);
    _stripStart = _today;
    _tab = widget.initialTab.clamp(0, 2);
    _scroll.addListener(() {
      if (_tab != 0 && _scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _loadMoreFeed(_feedKey);
      }
    });
    if (_tab == 0) {
      _load();
    } else {
      _loading = false;
      _loadFeed(_feedKey);
    }
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
    return [for (final e in _parse(res.body)) _norm(e)];
  }

  /// Keşfet: takvim ayları (şerit 7 gün + seçili ay).
  Future<void> _load({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
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
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() { _error = e; _loading = false; });
    }
  }

  // ---- kişisel listeler ----

  String _feedPath(String key, {int? cursor}) {
    final mode = switch (key) { 'created' => 'organizing', 'past' => 'past', _ => 'attending' };
    return '/me/events?mode=$mode&size=20${cursor == null ? '' : '&cursor=$cursor'}';
  }

  bool _isPast(Map<String, dynamic> e) {
    final end = (e['_end'] as DateTime?) ?? (e['_start'] as DateTime?);
    return end != null && end.isBefore(DateTime.now());
  }

  /// Sunucu modu desteklemese bile Yaklaşan/Geçmiş ayrımı istemcide doğrulanır.
  List<Map<String, dynamic>> _filterFeed(String key, List<Map<String, dynamic>> src) {
    final all = [for (final e in src) _norm(e)];
    return switch (key) {
      'up' => all.where((e) => !_isPast(e)).toList(),
      'past' => all.where(_isPast).toList(),
      _ => all,
    };
  }

  Future<void> _loadFeed(String key, {bool silent = false}) async {
    final f = _feeds[key]!;
    final gen = ++f.gen;
    if (!silent || !f.loaded) {
      setState(() { f.loading = true; f.error = null; });
    }
    try {
      final res = await widget.session.api.get(_feedPath(key));
      if (!mounted || gen != f.gen) return;
      setState(() {
        f.items = _filterFeed(key, _parse(res));
        f.next = (res is Map ? res['nextCursor'] : null) is num ? (res['nextCursor'] as num).toInt() : null;
        f.loading = false;
        f.loaded = true;
        f.error = null;
      });
    } catch (e) {
      if (!mounted || gen != f.gen) return;
      setState(() { f.error = e; f.loading = false; });
    }
  }

  Future<void> _loadMoreFeed(String key) async {
    final f = _feeds[key]!;
    if (f.more || f.loading || f.next == null) return;
    final gen = f.gen;
    setState(() => f.more = true);
    try {
      final res = await widget.session.api.get(_feedPath(key, cursor: f.next));
      if (!mounted || gen != f.gen) return;
      setState(() {
        f.items = [...f.items, ..._filterFeed(key, _parse(res))];
        f.next = (res is Map ? res['nextCursor'] : null) is num ? (res['nextCursor'] as num).toInt() : null;
        f.more = false;
      });
    } catch (_) {
      if (mounted && gen == f.gen) setState(() => f.more = false);
    }
  }

  Future<void> _refresh() => _tab == 0 ? _load(silent: true) : _loadFeed(_feedKey, silent: true);

  void _setTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _enterTab();
  }

  void _setSub(int i) {
    if (i == _sub) return;
    setState(() => _sub = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _enterTab();
  }

  void _enterTab() {
    if (_tab == 0) {
      _load(silent: _cache.containsKey(_ym(_month)));
    } else {
      final f = _feeds[_feedKey]!;
      _loadFeed(_feedKey, silent: f.loaded);
    }
  }

  /// Katıldıktan sonra "Etkinliklerim" kısayolu.
  void _openMine() {
    if (!mounted) return;
    setState(() { _tab = 1; _sub = 0; });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _loadFeed('up', silent: _feeds['up']!.loaded);
  }

  // ---- Keşfet takvimi ----

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

  // ---- katılım ----

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

  /// Katıl / İlgileniyorum: yalnızca ekler; geri alma "Etkinliklerim" sayfasındadır.
  Future<void> _join(Map<String, dynamic> ev, String status) async {
    final id = (ev['id'] as num).toInt();
    if (_rsvpBusy.contains(id)) return;
    final oldGoing = _going(ev);
    final cap = (ev['capacity'] as num?)?.toInt();
    if (status == 'GOING' && cap != null && (oldGoing ?? 0) >= cap) {
      _snack('Kontenjan doldu. "İlgileniyorum" ile takipte kalabilirsin.');
      return;
    }
    setState(() => _rsvpBusy.add(id));
    try {
      final res = await widget.session.api.put('/events/$id/rsvp', {'status': status});
      if (!mounted) return;
      final going = (res is Map ? (res['goingCount'] as num?)?.toInt() : null) ??
          (oldGoing == null ? null : (status == 'GOING' ? oldGoing + 1 : oldGoing));
      setState(() => _rsvpState[id] = {'myRsvp': (res is Map ? res['myRsvp'] as String? : null) ?? status, 'goingCount': going});
      showJoinedToast(context, _openMine);
    } catch (e) {
      if (mounted) {
        if (e is ApiError && e.code == 'EVENT_REGISTRATION_CLOSED') setState(() => _closedIds.add(id));
        _snack(eventErrorText(e));
      }
    } finally {
      _rsvpBusy.remove(id);
      if (mounted) setState(() {});
    }
  }

  /// Katılımdan ayrılma yalnızca Etkinliklerim'den, onayla yapılır.
  Future<void> _leave(Map<String, dynamic> ev) async {
    final id = (ev['id'] as num).toInt();
    final ok = await confirmEventDialog(
      context,
      title: 'Katılımdan ayrıl',
      message: 'Bu etkinlik Etkinliklerim listenden çıkarılacak.',
      confirmLabel: 'Ayrıl',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await widget.session.api.delete('/events/$id/rsvp');
      if (!mounted) return;
      setState(() {
        for (final f in _feeds.values) {
          f.items = f.items.where((e) => e['id'] != ev['id']).toList();
        }
        _rsvpState[id] = {'myRsvp': null, 'goingCount': null};
      });
      _snack('Katılımdan ayrıldın.');
    } catch (e) {
      _snack(eventErrorText(e));
    }
  }

  Future<void> _manage(Map<String, dynamic> ev, String action) async {
    final id = (ev['id'] as num).toInt();
    final api = widget.session.api;
    try {
      switch (action) {
        case 'edit':
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => EventFormPage(session: widget.session, event: ev)),
          );
          if (ok == true && mounted) _loadFeed('created', silent: true);
          return;
        case 'close':
          await api.post('/events/$id/close', {});
          _snack('Kayıtlar kapatıldı.');
        case 'reopen':
          await api.post('/events/$id/reopen', {});
          _snack('Kayıtlar yeniden açıldı.');
        case 'cancel':
          final ok = await confirmEventDialog(
            context,
            title: 'Etkinliği iptal et',
            message: 'Bu etkinlik tüm katılımcılar için iptal edilecek.',
            confirmLabel: 'İptal et',
            danger: true,
          );
          if (!ok || !mounted) return;
          await api.delete('/events/$id');
          _snack('Etkinlik iptal edildi.');
      }
      if (mounted) _loadFeed('created', silent: true);
    } catch (e) {
      _snack(eventErrorText(e));
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
    if (mounted) _refresh();
  }

  Future<void> _create() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EventFormPage(session: widget.session)),
    );
    if (ok == true && mounted) {
      _cache.clear();
      for (final f in _feeds.values) {
        f.loaded = false;
      }
      _enterTab();
    }
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

  // ---- görünüm ----

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
              BuIconButton(icon: LucideIcons.plus, tooltip: 'Etkinlik oluştur', filled: true, onTap: _create),
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
                          : Icon(LucideIcons.scanLine, size: 14.5, color: t.ink),
                      const SizedBox(width: 6),
                      Text('Yoklama', style: BuType.label.copyWith(color: t.ink)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinnedBar(
                      color: t.bg,
                      child: _Seg(items: const ['Keşfet', 'Etkinliklerim', 'Oluşturduklarım'], index: _tab, onChanged: _setTab),
                    ),
                  ),
                  ..._tab == 0 ? _discoverSlivers() : _feedSlivers(),
                  const SliverToBoxAdapter(child: SizedBox(height: kNavInset)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _pad = EdgeInsets.symmetric(horizontal: 20);

  Widget _skeleton() {
    final t = context.bu;
    Widget block(double h, {double? w}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(10)),
        );
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      sliver: SliverList.separated(
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Semantics(
          label: 'Yükleniyor',
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: t.sf, borderRadius: BorderRadius.circular(22), border: Border.all(color: t.bd)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              block(110),
              const SizedBox(height: 12),
              block(16),
              const SizedBox(height: 8),
              block(12, w: 160),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stateBox(Widget child) => SliverToBoxAdapter(child: SizedBox(height: 360, child: child));

  List<Widget> _discoverSlivers() {
    final t = context.bu;
    final busy = _busyDaySet();
    final head = SliverToBoxAdapter(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('${_monthNames[_month.month - 1]} ${_month.year}',
                    style: BuType.bodyStrong.copyWith(color: t.mut)),
              ),
              IconButton(
                tooltip: 'Önceki ay',
                visualDensity: VisualDensity.compact,
                icon: Icon(LucideIcons.chevronLeft, size: 18, color: t.ink),
                onPressed: _month.isBefore(DateTime(_today.year - 1, _today.month)) ? null : () => _goMonth(-1),
              ),
              IconButton(
                tooltip: 'Sonraki ay',
                visualDensity: VisualDensity.compact,
                icon: Icon(LucideIcons.chevronRight, size: 18, color: t.ink),
                onPressed: () => _goMonth(1),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _dayCell(_stripStart.add(Duration(days: i)), busy)),
              ],
            ],
          ),
        ),
      ]),
    );
    if (_loading) return [head, _skeleton()];
    if (_error != null) return [head, _stateBox(ErrorView(error: _error!, onRetry: _load))];

    final rows = <Object>[]; // DateTime başlığı, not (String) ya da etkinlik
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
    final emptyText = _selected != null ? 'Bu gün için etkinlik yok.' : 'Bu ay için etkinlik yok.';
    final note = _isPastMonth
        ? 'Geçmiş ay: yalnızca görüntüleme.'
        : (_truncated.contains(_ym(_month)) ? 'Bu ayın tamamı gösterilemiyor; bazı etkinlikler listede yok.' : null);
    if (note != null) rows.insert(0, note);
    if (items.isEmpty) {
      return [head, if (note != null) SliverToBoxAdapter(child: Padding(padding: _pad, child: _noteRow(note))), _stateBox(EmptyView(icon: LucideIcons.calendarX, text: emptyText))];
    }
    return [
      head,
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        sliver: SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final r = rows[i];
            if (r is String) return _noteRow(r);
            if (r is DateTime) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 0, 8),
                child: Text(longDate(r), style: BuType.label.copyWith(color: t.mut)),
              );
            }
            final ev = r as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ev['source'] == 'OFFICIAL' ? _officialRow(ev) : _card(ev, _Mode.discover, _effDay(ev)),
            );
          },
        ),
      ),
    ];
  }

  Widget _noteRow(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(LucideIcons.info, size: 12.5, color: context.bu.mut),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: BuType.caption.copyWith(color: context.bu.mut))),
        ]),
      );

  List<Widget> _feedSlivers() {
    final f = _feeds[_feedKey]!;
    final mode = _tab == 2 ? _Mode.created : (_sub == 1 ? _Mode.past : _Mode.upcoming);
    final subs = _tab == 1
        ? SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                BuChip(label: 'Yaklaşan', selected: _sub == 0, onTap: () => _setSub(0)),
                BuChip(label: 'Geçmiş', selected: _sub == 1, onTap: () => _setSub(1)),
              ]),
            ),
          )
        : SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text('Oluşturduğun etkinlikleri buradan yönetebilirsin.',
                  style: BuType.caption.copyWith(color: context.bu.mut)),
            ),
          );
    if (f.loading && !f.loaded) return [subs, _skeleton()];
    if (f.error != null && !f.loaded) {
      return [subs, _stateBox(ErrorView(error: f.error!, onRetry: () => _loadFeed(_feedKey)))];
    }
    if (f.items.isEmpty) {
      final text = switch (mode) {
        _Mode.upcoming => 'Katılacağın bir etkinlik yok.',
        _Mode.past => 'Geçmiş etkinliğin yok.',
        _ => 'Henüz bir etkinlik oluşturmadın.',
      };
      return [
        subs,
        _stateBox(Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: EmptyView(icon: LucideIcons.calendarX, text: text)),
          if (mode != _Mode.past)
            BuButton(
              label: mode == _Mode.created ? 'Etkinlik oluştur' : 'Etkinlikleri keşfet',
              icon: mode == _Mode.created ? LucideIcons.plus : LucideIcons.compass,
              compact: true,
              onPressed: mode == _Mode.created ? _create : () => _setTab(0),
            ),
        ])),
      ];
    }
    return [
      subs,
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        sliver: SliverList.builder(
          itemCount: f.items.length + (f.more ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= f.items.length) {
              return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
            }
            final ev = f.items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _card(ev, mode, ev['_day'] as DateTime?),
            );
          },
        ),
      ),
    ];
  }

  Widget _dayCell(DateTime d, Set<String> busyDays) {
    final t = context.bu;
    final on = _selected == d;
    final today = d == _today;
    final dot = busyDays.contains(_ymd(d));
    return GestureDetector(
      onTap: () => _pickDay(d),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: on ? t.pr : t.sf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? t.pr : (today ? t.pr.withValues(alpha: .6) : t.bd), width: today && !on ? 1.5 : 1),
        ),
        // Büyük yazı ölçeğinde gün sayısı satıra bölünmesin/taşmasın: içerik hücreye sığacak kadar küçülür.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_dayShort[d.weekday - 1],
                    maxLines: 1, softWrap: false, style: BuType.micro.copyWith(color: on ? t.onPr : t.mut)),
                const SizedBox(height: 4),
                Text('${d.day}',
                    maxLines: 1,
                    softWrap: false,
                    style: BuType.title.copyWith(color: on ? t.onPr : (today ? t.pr : t.ink))),
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
        ),
      ),
    );
  }

  /// Kaynak siteden gelen resmi etkinlik: sade satır.
  Widget _officialRow(Map<String, dynamic> ev) {
    final t = context.bu;
    final day = _effDay(ev);
    return BuCard(
      radius: 18,
      onTap: () => _open(ev),
      child: Row(children: [
        EventDateBadge(day),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const BuBadge('Resmi', soft: true),
            const SizedBox(height: 6),
            Text('${ev['title'] ?? ''}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
          ]),
        ),
        const SizedBox(width: 6),
        Icon(LucideIcons.chevronRight, size: 16, color: t.mut),
      ]),
    );
  }

  List<Map<String, dynamic>> _avatarsOf(Map<String, dynamic> ev) {
    final v = ev['attendeesPreview'] ?? ev['avatars'];
    return [for (final a in (v is List ? v : const [])) if (a is Map) a.cast<String, dynamic>()];
  }

  Widget _card(Map<String, dynamic> ev, _Mode mode, DateTime? day) {
    final t = context.bu;
    final id = (ev['id'] as num).toInt();
    final start = ev['_start'] as DateTime?;
    final end = ev['_end'] as DateTime?;
    final my = _myRsvp(ev);
    final going = _going(ev) ?? 0;
    final place = (ev['location'] as String?)?.trim();
    final org = (ev['communityName'] as String?)?.trim();
    final time = start == null ? '' : (end != null ? '${eventHm(start)} – ${eventHm(end)}' : eventHm(start));
    final cancelled = eventIsCancelled(ev);
    final closed = eventIsClosed(ev) || _closedIds.contains(id);
    final cover = fileUrl((ev['coverUrl'] ?? ev['imageUrl']) as String?);
    final past = mode == _Mode.past || (mode == _Mode.discover && _isPastMonth);

    Widget meta(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(children: [
            Icon(icon, size: 12.5, color: t.mut),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut)),
            ),
          ]),
        );

    Widget? tag;
    if (mode == _Mode.created) {
      tag = cancelled
          ? const EventStatusTag('İptal', tone: EventTone.danger)
          : (closed ? const EventStatusTag('Kayıt kapalı', tone: EventTone.warn) : const EventStatusTag('Açık'));
    } else if (cancelled) {
      tag = const EventStatusTag('İptal', tone: EventTone.danger);
    }

    final bottom = switch (mode) {
      _Mode.discover => _discoverActions(ev, my, going, closed, cancelled, past, id),
      _Mode.created => _createdBar(ev, going, cancelled, closed),
      _ => _mineBar(ev, going),
    };

    return BuCard(
      radius: 22,
      padding: EdgeInsets.zero,
      onTap: () => _open(ev),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 16 / 7,
          child: Stack(fit: StackFit.expand, children: [
            if (cover != null) EventCoverImage(url: cover, cacheWidth: 700) else const EventCoverFallback(),
            Positioned(left: 12, top: 12, child: EventDateBadge(day, onCover: true)),
            if (tag != null)
              Positioned(
                right: 12,
                top: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(999)),
                  child: tag,
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (org != null && org.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.users, size: 10, color: t.onSoft),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(org,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.micro.copyWith(color: t.onSoft)),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            Text('${ev['title'] ?? ''}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(color: t.ink)),
            if (time.isNotEmpty) meta(LucideIcons.clock, time),
            if (place != null && place.isNotEmpty) meta(LucideIcons.mapPin, place),
            const SizedBox(height: 10),
            bottom,
          ]),
        ),
      ]),
    );
  }

  Widget _discoverActions(Map<String, dynamic> ev, String? my, int going, bool closed, bool cancelled, bool past, int id) {
    final t = context.bu;
    final busy = _rsvpBusy.contains(id);
    final stack = EventAvatarStack(avatars: _avatarsOf(ev), total: going);
    Widget? action;
    if (!past && !cancelled) {
      if (my == 'GOING') {
        action = EventJoinedChip(onTap: _openMine);
      } else if (closed) {
        action = Text('Kayıtlar kapalı', style: BuType.label.copyWith(color: t.mut));
      } else {
        action = Wrap(spacing: 8, runSpacing: 8, children: [
          BuButton(label: 'Katıl', compact: true, busy: busy, onPressed: busy ? null : () => _join(ev, 'GOING')),
          if (my == 'INTERESTED')
            const EventStatusTag('İlgileniyorum', tone: EventTone.warn)
          else
            BuButton(
                label: 'İlgileniyorum',
                compact: true,
                kind: BuButtonKind.outline,
                onPressed: busy ? null : () => _join(ev, 'INTERESTED')),
        ]);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        stack,
        const SizedBox(width: 6),
        Expanded(child: Text('katılıyor', style: BuType.caption.copyWith(color: t.mut))),
      ]),
      if (action != null) ...[const SizedBox(height: 10), action],
    ]);
  }

  /// Etkinliklerim: katılımcı sayısı + ⋯ (Katılımdan ayrıl).
  Widget _mineBar(Map<String, dynamic> ev, int going) {
    final t = context.bu;
    return Row(children: [
      EventAvatarStack(avatars: _avatarsOf(ev), total: going),
      const SizedBox(width: 6),
      Expanded(child: Text('katılıyor', style: BuType.caption.copyWith(color: t.mut))),
      PopupMenuButton<String>(
        tooltip: 'Seçenekler',
        icon: Icon(LucideIcons.ellipsis, size: 18, color: t.ink),
        onSelected: (_) => _leave(ev),
        itemBuilder: (_) => const [PopupMenuItem(value: 'leave', child: Text('Katılımdan ayrıl'))],
      ),
    ]);
  }

  /// Oluşturduklarım: katılımcı sayısı, katılımcılara bağlantı, hızlı eylemler.
  Widget _createdBar(Map<String, dynamic> ev, int going, bool cancelled, bool closed) {
    final t = context.bu;
    return Row(children: [
      Icon(LucideIcons.users, size: 13.5, color: t.mut),
      const SizedBox(width: 6),
      // Büyük yazı ölçeğinde kesilmesin: sığmazsa alt satıra kayar.
      Expanded(
        child: Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('$going katılımcı', style: BuType.label.copyWith(color: t.ink)),
          GestureDetector(
            onTap: () => _open(ev),
            child: Text('Katılımcılar', style: BuType.label.copyWith(color: t.pr)),
          ),
        ]),
      ),
      if (!cancelled)
        PopupMenuButton<String>(
          tooltip: 'Seçenekler',
          icon: Icon(LucideIcons.ellipsis, size: 18, color: t.ink),
          onSelected: (a) => _manage(ev, a),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
            PopupMenuItem(value: closed ? 'reopen' : 'close', child: Text(closed ? 'Kayıtları yeniden aç' : 'Kayıtları kapat')),
            PopupMenuItem(value: 'cancel', child: Text('İptal et', style: TextStyle(color: t.danger))),
          ],
        ),
    ]);
  }
}

enum _Mode { discover, upcoming, past, created }

/// Kaydırınca üstte sabit kalan segment çubuğu.
class _PinnedBar extends SliverPersistentHeaderDelegate {
  _PinnedBar({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  double get minExtent => 62;
  @override
  double get maxExtent => 62;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: color, padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), child: child);

  @override
  bool shouldRebuild(covariant _PinnedBar old) => true;
}

/// Üç eşit parçalı segment; dar ekranda etiketler küçülür (kaydırma yok).
class _Seg extends StatelessWidget {
  const _Seg({required this.items, required this.index, required this.onChanged});

  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(23)),
      child: Row(children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i == index ? t.sf : Colors.transparent,
                  borderRadius: BorderRadius.circular(19),
                  boxShadow: i == index
                      ? [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 3, offset: const Offset(0, 1))]
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(items[i], maxLines: 1, style: BuType.label.copyWith(color: i == index ? t.ink : t.mut)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
