import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../clubs/clubs_tab.dart';
import '../news/news_detail_page.dart';
import '../platform/qr_scan_page.dart';
import 'event_detail_page.dart';
import 'event_form_page.dart';
import 'etkinlik_parts.dart';
import 'event_parts.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _ym(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

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
    final p = DateTime.tryParse('${m['eventDate'] ?? m['date'] ?? ''}') ??
        DateTime.tryParse('${m['date'] ?? ''}');
    if (p != null) day = DateTime(p.year, p.month, p.day);
  }
  final end = DateTime.tryParse('${m['endsAt'] ?? ''}')?.toLocal();
  m['_day'] = day;
  m['_start'] = start;
  m['_end'] = end;
  m['_endDay'] = (end != null &&
          day != null &&
          !DateTime(end.year, end.month, end.day).isBefore(day))
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

  /// Liste önbellekten (bayat) geldiyse sunucudan alındığı an.
  DateTime? staleAt;
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
  int _monthDir = 1; // ay geçişinin yönü (+1 ileri, -1 geri): ızgara kayma yönü
  DateTime? _selected;
  bool? _canCreate; // kulüp yöneticisi mi (Oluşturduklarım boş durumunda kart seçimi)

  final Map<String, List<Map<String, dynamic>>> _cache = {};
  final Set<String> _truncated = {}; // X-Truncated: true dönen aylar
  final Map<int, Map<String, dynamic>> _rsvpState =
      {}; // etkinlik id -> {myRsvp, goingCount}
  final Set<int> _rsvpBusy = {};
  final Set<int> _closedIds =
      {}; // 409 EVENT_REGISTRATION_CLOSED alan etkinlikler

  final Map<String, _Feed> _feeds = {
    'up': _Feed(),
    'past': _Feed(),
    'created': _Feed()
  };

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
    _tab = widget.initialTab.clamp(0, 2);
    _scroll.addListener(() {
      if (_tab != 0 &&
          _scroll.hasClients &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _loadMoreFeed(_feedKey);
      }
    });
    if (_tab == 0) {
      _load();
    } else {
      _loading = false;
      _loadFeed(_feedKey);
      if (_tab == 2) _checkCanCreate();
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
    return [
      for (final e in list)
        if (e is Map) e.cast<String, dynamic>()
    ];
  }

  Future<List<Map<String, dynamic>>> _fetchMonth(DateTime m, {bool force = false}) async {
    final res = await widget.session.api
        .getResponse('/events/calendar?month=${_ym(m)}', force: force);
    if (res.fromCache) {
      _calStale[_ym(m)] = res.cachedAt;
    } else {
      _calStale.remove(_ym(m));
    }
    if (res.headers['x-truncated'] == 'true') {
      _truncated.add(_ym(m));
    } else {
      _truncated.remove(_ym(m));
    }
    return [for (final e in _parse(res.body)) _norm(e)];
  }

  /// Keşfet: seçili ayın takvimi.
  Future<void> _load({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final m = _month;
      final items = await _fetchMonth(m, force: silent);
      if (!mounted || gen != _gen) return;
      setState(() {
        _rsvpState.clear(); // takvim öğesi RSVP için tek kaynak
        _cache[_ym(m)] = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  // ---- kişisel listeler ----

  String _feedPath(String key, {int? cursor}) {
    final mode = switch (key) {
      'created' => 'organizing',
      'past' => 'past',
      _ => 'attending'
    };
    return '/me/events?mode=$mode&size=20${cursor == null ? '' : '&cursor=$cursor'}';
  }

  bool _isPast(Map<String, dynamic> e) {
    final end = (e['_end'] as DateTime?) ?? (e['_start'] as DateTime?);
    return end != null && end.isBefore(DateTime.now());
  }

  bool _isLive(Map<String, dynamic> e) {
    final s = e['_start'] as DateTime?;
    final en = e['_end'] as DateTime?;
    final now = DateTime.now();
    return s != null && en != null && !now.isBefore(s) && now.isBefore(en);
  }

  /// Sunucu modu desteklemese bile Yaklaşan/Geçmiş ayrımı istemcide doğrulanır.
  List<Map<String, dynamic>> _filterFeed(
      String key, List<Map<String, dynamic>> src) {
    final all = [for (final e in src) _norm(e)];
    return switch (key) {
      'up' => all.where((e) => !_isPast(e)).toList(),
      'past' => all.where(_isPast).toList(),
      _ => all,
    };
  }

  final Map<String, DateTime?> _calStale = {};

  Future<void> _loadFeed(String key, {bool silent = false}) async {
    final f = _feeds[key]!;
    final gen = ++f.gen;
    if (!silent || !f.loaded) {
      setState(() {
        f.loading = true;
        f.error = null;
      });
    }
    try {
      final r = await widget.session.api.getResponse(_feedPath(key), force: silent);
      final res = r.body;
      if (!mounted || gen != f.gen) return;
      setState(() {
        f.staleAt = r.fromCache ? r.cachedAt : null;
        f.items = _filterFeed(key, _parse(res));
        f.next = (res is Map ? res['nextCursor'] : null) is num
            ? (res['nextCursor'] as num).toInt()
            : null;
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
        f.next = (res is Map ? res['nextCursor'] : null) is num
            ? (res['nextCursor'] as num).toInt()
            : null;
        f.more = false;
      });
    } catch (_) {
      if (mounted && gen == f.gen) setState(() => f.more = false);
    }
  }

  Future<void> _refresh() =>
      _tab == 0 ? _load(silent: true) : _loadFeed(_feedKey, silent: true);

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
      if (_tab == 2) _checkCanCreate();
    }
  }

  /// Etkinlik açabileceği (yönetici/izinli) kulübü var mı? Yoksa boş durumda "kulübün yöneticisi olmalısın" kartı çıkar.
  Future<void> _checkCanCreate() async {
    if (_canCreate != null) return;
    try {
      final r = await widget.session.api.get('/me/communities?size=50');
      final items = (r is Map ? r['items'] : null) as List? ?? const [];
      final ok = items.whereType<Map>().any((c) => eventClubPublishMode(Map<String, dynamic>.from(c)) != null);
      if (mounted) setState(() => _canCreate = ok);
    } catch (_) {}
  }

  /// Katıldıktan sonra "Etkinliklerim" kısayolu.
  void _openMine() {
    if (!mounted) return;
    setState(() {
      _tab = 1;
      _sub = 0;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _loadFeed('up', silent: _feeds['up']!.loaded);
  }

  // ---- Keşfet takvimi ----

  Future<void> _goMonth(int delta) async {
    setState(() {
      _monthDir = delta >= 0 ? 1 : -1;
      _month = DateTime(_month.year, _month.month + delta);
      _selected = null;
    });
    if (_cache.containsKey(_ym(_month))) return;
    await _load();
  }

  /// Bugünün ayına döner.
  void _goToday() {
    buHaptic(BuHaptic.selection);
    setState(() {
      final to = DateTime(_today.year, _today.month);
      _monthDir = to.isBefore(_month) ? -1 : 1;
      _month = DateTime(_today.year, _today.month);
      _selected = null;
    });
    _load(silent: _cache.containsKey(_ym(_month)));
  }

  void _pickDay(DateTime d) {
    final sameMonth = d.year == _month.year && d.month == _month.month;
    setState(() {
      if (!sameMonth) _monthDir = DateTime(d.year, d.month).isBefore(_month) ? -1 : 1;
      _selected = (_selected == d) ? null : d;
      _month = DateTime(d.year, d.month);
    });
    if (!sameMonth && !_cache.containsKey(_ym(_month))) _load();
  }

  bool get _isPastMonth => DateTime(_month.year, _month.month + 1)
      .isBefore(DateTime(_today.year, _today.month + 1));

  /// "Bugün" yalnız bugünden başka bir ay ya da gün seçilince görünür.
  bool get _showToday {
    final otherMonth = _month.year != _today.year || _month.month != _today.month;
    final otherDay = _selected != null && _selected != _today;
    return otherMonth || otherDay;
  }

  /// Ay dışından süren etkinliklerin günü ay sınırına çekilir (sunucu `date` alanıyla uyumlu).
  DateTime _effDay(Map<String, dynamic> e) {
    var d = e['_day'] as DateTime;
    final first = DateTime(_month.year, _month.month);
    final last = DateTime(_month.year, _month.month + 1, 0);
    if (d.isBefore(first)) d = first;
    if (d.isAfter(last)) d = last;
    // Güncel ayda süren etkinlik "bugün" altında görünür.
    if (!_isPastMonth &&
        d.isBefore(_today) &&
        !(e['_endDay'] as DateTime).isBefore(_today)) {
      d = _today;
    }
    return d;
  }

  List<Map<String, dynamic>> get _monthItems {
    final all = _cache[_ym(_month)] ?? const [];
    return [
      for (final e in all)
        if (e['_day'] != null &&
            (_isPastMonth || !(e['_endDay'] as DateTime).isBefore(_today)))
          e,
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

  /// Seçili güne (yoksa aya) göre süzülmüş, güne göre sıralı Keşfet öğeleri.
  List<Map<String, dynamic>> _visibleDiscover() {
    final sel = _selected;
    return _monthItems.where((e) {
      if (sel == null) return true;
      final d = e['_day'] as DateTime;
      return !d.isAfter(sel) && !(e['_endDay'] as DateTime).isBefore(sel);
    }).toList()
      ..sort((a, b) => _effDay(a).compareTo(_effDay(b)));
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
      _toast(context.l10n.eventListFull, kind: BuToastKind.warning);
      return;
    }
    setState(() => _rsvpBusy.add(id));
    try {
      final res =
          await widget.session.api.put('/events/$id/rsvp', {'status': status});
      if (!mounted) return;
      final going =
          (res is Map ? (res['goingCount'] as num?)?.toInt() : null) ??
              (oldGoing == null
                  ? null
                  : (status == 'GOING' ? oldGoing + 1 : oldGoing));
      setState(() => _rsvpState[id] = {
            'myRsvp': (res is Map ? res['myRsvp'] as String? : null) ?? status,
            'goingCount': going
          });
      buHaptic(BuHaptic.medium);
      showJoinedToast(context, _openMine);
    } catch (e) {
      if (mounted) {
        if (e is ApiError && e.code == 'EVENT_REGISTRATION_CLOSED') {
          setState(() => _closedIds.add(id));
        }
        _toast(eventErrorTextL(context, e), kind: BuToastKind.error);
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
      title: context.l10n.eventListLeaveTitle,
      message: context.l10n.eventListLeaveMsg,
      confirmLabel: context.l10n.eventListLeave,
      danger: true,
      icon: LucideIcons.calendarX,
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
      _toast(context.l10n.eventListLeft, kind: BuToastKind.success);
    } catch (e) {
      if (mounted) _toast(eventErrorTextL(context, e), kind: BuToastKind.error);
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
            MaterialPageRoute(
                builder: (_) =>
                    EventFormPage(session: widget.session, event: ev)),
          );
          if (ok == true && mounted) _loadFeed('created', silent: true);
          return;
        case 'close':
          await api.post('/events/$id/close', {});
          if (mounted) _toast(context.l10n.eventListClosedDone, kind: BuToastKind.success);
        case 'reopen':
          await api.post('/events/$id/reopen', {});
          if (mounted) _toast(context.l10n.eventListReopenedDone, kind: BuToastKind.success);
        case 'cancel':
          final ok = await confirmEventDialog(
            context,
            title: context.l10n.eventListCancelTitle,
            message: context.l10n.eventListCancelMsg,
            confirmLabel: context.l10n.eventListCancelConfirm,
            danger: true,
            icon: LucideIcons.triangleAlert,
            centered: true,
          );
          if (!ok || !mounted) return;
          await api.delete('/events/$id');
          if (mounted) _toast(context.l10n.eventListCancelledDone, kind: BuToastKind.success);
      }
      if (mounted) _loadFeed('created', silent: true);
    } catch (e) {
      if (!mounted) return;
      if (eventIsNotFound(e)) {
        _dropEvent(id);
        _toast(context.l10n.eventFormNotFound, kind: BuToastKind.error);
      } else {
        _toast(eventSaveErrorText(context, e), kind: BuToastKind.error);
      }
    }
  }

  /// Admin gizlediği/silinen etkinlik (404): listelerden düşer.
  void _dropEvent(int id) {
    setState(() {
      for (final f in _feeds.values) {
        f.items = f.items.where((e) => e['id'] != id).toList();
      }
    });
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
        builder: (_) => EventDetailPage(
            session: widget.session, eventId: (ev['id'] as num).toInt()),
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

  /// QR'ı tara (ya da elle kod gir); koddaki etkinlik kimliğiyle yoklama gönderilir. Doğrulama tarayıcı sayfasında
  /// yapılır: hata orada kalıp gösterilir, başarıda "Yoklaman alındı" gösterilip sayfa kapanır.
  /// Kod biçimi: "bingol-checkin:{etkinlikId}.{pencere}.{imza}" (elle girişte önek olmayabilir).
  Future<void> _scanCheckin() async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => QrScanPage(title: context.l10n.eventListScanTitle, onSubmit: _verifyCheckin)),
    );
  }

  Future<String?> _verifyCheckin(String raw) async {
    final l = context.l10n;
    const prefix = 'bingol-checkin:';
    final code = raw.trim().startsWith(prefix) ? raw.trim().substring(prefix.length) : raw.trim();
    final id = int.tryParse(code.split('.').first);
    if (id == null) return l.eventListNotCode;
    try {
      await widget.session.api.post('/events/$id/check-in', {'code': code});
      buHaptic(BuHaptic.medium);
      return null;
    } catch (e) {
      return errorText(e);
    }
  }

  void _toast(String m, {BuToastKind kind = BuToastKind.info}) {
    if (!mounted) return;
    BuToast.show(context, m, kind: kind);
  }

  // ---- görünüm ----

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final narrow = MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(10) > 11.5;
    final feed = _tab == 0 ? null : _feeds[_feedKey]!;

    // Yükleniyor yalnız iskelet; hata/boş/hazır durumlar kendi kartlarıyla sliver olarak çizilir.
    final loading = _tab == 0 ? _loading : (feed!.loading && !feed.loaded);
    final Object? err = _tab == 0 ? _error : (feed!.loaded ? null : feed.error);
    final DateTime? stale = _tab == 0 ? _calStale[_ym(_month)] : feed!.staleAt;

    final List<Widget> slivers;
    if (loading) {
      slivers = const [];
    } else if (err != null) {
      slivers = [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.list(children: [
            _errorCard(cached: stale != null),
          ]),
        ),
      ];
    } else if (_tab == 0) {
      slivers = _discoverSlivers(stale);
    } else {
      slivers = _feedSlivers(stale);
    }

    return BuStaggerScope(
      child: BuPageScaffold(
        title: l.eventListTitle,
        large: false,
        controller: _scroll,
        onRefresh: _refresh,
        bottomInset: 40,
        state: loading ? BuViewState.loading : BuViewState.ready,
        loading: _EventSkeleton(calendar: _tab == 0),
        actions: [
          _HeaderPill(
            label: l.eventListCheckin,
            icon: LucideIcons.scanLine,
            compact: narrow,
            onTap: _scanCheckin,
          ),
          const SizedBox(width: 8),
          _PlusButton(tooltip: l.eventListCreate, onTap: _create),
          const SizedBox(width: 16),
        ],
        // Sabit segment çubuğu: büyük başlık daralsa da üç sekme hep görünür.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
              child: BuSegmented(
                items: [l.eventListTabDiscover, l.eventListTabMine, l.eventListTabCreated],
                index: _tab,
                onChanged: _setTab,
              ),
            ),
          ),
        ),
        slivers: slivers,
      ),
    );
  }

  /// "Yüklenemedi, tekrar dene" kartı.
  Widget _errorCard({bool cached = false}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return BuCard(
      key: const ValueKey('events-error'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      radius: 20,
      child: Column(children: [
        ExcludeSemantics(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: t.tint(1).bg, shape: BoxShape.circle),
            child: Icon(LucideIcons.refreshCcwDot, size: 26, color: t.pr),
          ),
        ),
        const SizedBox(height: 14),
        Text(l.p14ErrorTitle, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
        const SizedBox(height: 6),
        Text(cached ? l.p14ErrorBodyCache : l.p14ErrorBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
        const SizedBox(height: 18),
        BuButton(
          key: const ValueKey('events-retry'),
          label: l.commonRetry,
          icon: LucideIcons.refreshCw,
          onPressed: _tab == 0 ? () => _load() : () => _loadFeed(_feedKey),
        ),
      ]),
    );
  }

  Widget _noteRow(String text) {
    final t = context.bu;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.warnSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.warn.withValues(alpha: .25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(LucideIcons.info, size: 18, color: t.onWarnSoft),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.onWarnSoft, height: 1.4, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  /// Sekmeye göre boş durum.
  Widget _emptyForTab() {
    final l = context.l10n;
    final t = context.bu;
    if (_tab == 0) {
      final day = _selected != null;
      return EtkinlikEmptyCard(
        key: const ValueKey('events-empty'),
        icon: LucideIcons.calendarX,
        title: day ? l.eventListEmptyDay : l.eventListEmptyMonth,
        body: day ? null : l.p14EmptyMonthBody,
      );
    }
    if (_tab == 2) {
      if (_canCreate == false) {
        return BuCard(
          key: const ValueKey('events-nocreate'),
          padding: const EdgeInsets.all(20),
          radius: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ExcludeSemantics(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                  child: Icon(Icons.shield, size: 26, color: t.pr),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(l.evcEmptyTitle,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              ),
            ]),
            const SizedBox(height: 14),
            Text(l.evcEmptyBody, style: Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: EtkinlikInkButton(label: l.evcBrowseClubs, icon: LucideIcons.users, onTap: _browseClubs)),
          ]),
        );
      }
      return EtkinlikEmptyCard(
        key: const ValueKey('events-empty'),
        icon: LucideIcons.calendarPlus,
        title: l.eventListEmptyCreated,
        body: l.p14EmptyCreatedBody2,
        action: SizedBox(width: double.infinity, child: EtkinlikInkButton(label: l.eventListCreate, icon: LucideIcons.circlePlus, onTap: _create)),
      );
    }
    final past = _sub == 1;
    return EtkinlikEmptyCard(
      key: const ValueKey('events-empty'),
      icon: LucideIcons.calendarX,
      title: past ? l.eventListEmptyPast : l.eventListEmptyUpcoming,
      body: past ? l.p14EmptyPastBody2 : l.p14EmptyUpcomingBody2,
      action: past
          ? null
          : BuButton(label: l.eventListDiscover, icon: LucideIcons.compass, onPressed: () => _setTab(0)),
    );
  }

  void _browseClubs() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Scaffold(body: ClubsTab(session: widget.session))),
      );

  // ---- Keşfet: takvim kartı ----

  Widget _calendarCard() {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final first = DateTime(_month.year, _month.month);
    final lead = first.weekday - 1; // Pzt = 0
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();
    final gridStart = DateTime(first.year, first.month, 1 - lead);
    final busy = _busyDaySet();
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return BuCard(
      key: const ValueKey('events-calendar'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      radius: 20,
      child: Column(children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: Row(children: [
            Expanded(
              child: Semantics(
                header: true,
                child: BuFadeThrough(
                  duration: BuMotion.short,
                  child: Align(
                    key: ValueKey(_ym(_month)),
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(l.eventListMonthYear(eventMonthNameOf(context, _month.month), '${_month.year}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                  ),
                ),
              ),
            ),
            if (_showToday)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: _goToday,
                child: Text(l.p14Today, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
              ),
            _BareChevron(
              icon: buDirIcon(context, LucideIcons.chevronLeft),
              tooltip: l.eventListPrevMonth,
              onTap: _month.isBefore(DateTime(_today.year - 1, _today.month)) ? null : () => _goMonth(-1),
            ),
            _BareChevron(
              icon: buDirIcon(context, LucideIcons.chevronRight),
              tooltip: l.eventListNextMonth,
              onTap: () => _goMonth(1),
            ),
          ]),
        ),
        Row(children: [
          for (var i = 1; i <= 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(trUpper(eventDayShortOf(context, i)),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: t.mut, letterSpacing: ar ? 0 : .4)),
              ),
            ),
        ]),
        // Ay değişince ızgara yatay kayarak yer değiştirir (ileri: sola, geri: sağa; RTL'de aynalanır).
        BuSharedAxis(
          reverse: _monthDir < 0,
          distance: 24,
          child: KeyedSubtree(
            key: ValueKey('grid-${_ym(_month)}'),
            child: Column(children: [
              for (var r = 0; r < rows; r++)
                Row(children: [
                  for (var c = 0; c < 7; c++) Expanded(child: _dayCell(DateTime(gridStart.year, gridStart.month, gridStart.day + r * 7 + c), busy)),
                ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _dayCell(DateTime d, Set<String> busy) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final inMonth = d.month == _month.month;
    final on = _selected == d;
    final today = d == _today;
    final dot = inMonth && busy.contains(_ymd(d));
    final fg = on ? t.onPr : (inMonth ? t.ink : t.mut.withValues(alpha: .45));
    return Semantics(
      button: true,
      selected: on,
      label: eventLongDateOf(context, d),
      onTap: () => _pickDay(d),
      child: ExcludeSemantics(
        child: BuPressable(
          scale: .92,
          haptic: BuHaptic.selection,
          onTap: () => _pickDay(d),
          child: SizedBox(
            height: 48,
            child: Center(
              child: SizedBox(
                width: 38,
                height: 38,
                child: Stack(alignment: Alignment.center, children: [
                  // Bugün: yumuşak halka (sabit); seçili gün: dolu daire 0.6 -> 1 ölçekle büyüyerek ve solarak belirir.
                  if (today && !on)
                    DecoratedBox(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: t.soft),
                      child: const SizedBox.expand(),
                    ),
                  AnimatedScale(
                    scale: on ? 1 : .6,
                    duration: BuMotion.of(context, BuMotion.short),
                    curve: BuMotion.emphasizedDecelerate,
                    child: AnimatedOpacity(
                      opacity: on ? 1 : 0,
                      duration: BuMotion.of(context, BuMotion.short),
                      child: DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: t.pr),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  AnimatedDefaultTextStyle(
                    duration: BuMotion.of(context, BuMotion.short),
                    style: tx.bodyMedium!.copyWith(color: on ? fg : (today ? t.onSoft : fg), fontWeight: on || today ? FontWeight.w800 : FontWeight.w500),
                    child: Text('${d.day}', maxLines: 1),
                  ),
                  // Etkinlik noktası: veri gelince 0 -> 1 ölçekle belirir.
                  PositionedDirectional(
                    bottom: 3,
                    child: AnimatedScale(
                      scale: dot ? 1 : 0,
                      duration: BuMotion.of(context, BuMotion.short),
                      curve: BuMotion.emphasizedDecelerate,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: on ? t.onPr : t.pr),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- listeler ----

  List<Widget> _discoverSlivers(DateTime? stale) {
    final items = _visibleDiscover();
    final rows = <Object>[]; // DateTime başlığı ya da etkinlik
    DateTime? last;
    final counts = <DateTime, int>{};
    for (final e in items) {
      final d = _effDay(e);
      counts[d] = (counts[d] ?? 0) + 1;
    }
    for (final e in items) {
      final d = _effDay(e);
      if (_selected != null ? rows.isEmpty : d != last) {
        rows.add(d);
        last = d;
      }
      rows.add(e);
    }
    final note = _isPastMonth
        ? context.l10n.eventListPastMonth
        : (_truncated.contains(_ym(_month)) ? context.l10n.eventListTruncated : null);
    // Seçili gün boşsa: seçili günden sonraki günler "Yaklaşan diğer günler" altında kart olarak sürer (çıkmaz yok).
    final others = <Map<String, dynamic>>[];
    if (_selected != null && items.isEmpty) {
      final sel = _selected!;
      for (final e in _monthItems) {
        if (_effDay(e).isAfter(sel)) others.add(e);
      }
      others.sort((a, b) => _effDay(a).compareTo(_effDay(b)));
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList.list(children: [
          _calendarCard(),
          if (note != null) ...[const SizedBox(height: 12), _noteRow(note)],
          if (items.isEmpty) ...[
            if (_selected != null) _dayHeader(_selected!, 0) else const SizedBox(height: 12),
            _emptyForTab(),
          ],
          if (others.isNotEmpty) _otherDaysHeader(others.length),
        ]),
      ),
      if (others.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: others.length,
            itemBuilder: (_, i) => BuStaggerItem(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: others[i]['source'] == 'OFFICIAL' ? _officialRow(others[i]) : _card(others[i], _Mode.discover, _effDay(others[i])),
              ),
            ),
          ),
        ),
      if (items.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final r = rows[i];
              if (r is DateTime) {
                return _dayHeader(r, _selected != null ? items.length : (counts[r] ?? 0));
              }
              final ev = r as Map<String, dynamic>;
              return BuStaggerItem(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ev['source'] == 'OFFICIAL' ? _officialRow(ev) : _card(ev, _Mode.discover, _effDay(ev)),
                ),
              );
            },
          ),
        ),
    ];
  }

  /// "Yaklaşan diğer günler" başlığı + etkinlik sayısı rozeti.
  Widget _otherDaysHeader(int count) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
      child: Semantics(
        header: true,
        child: Row(children: [
          Expanded(
            child: Text(l.p14UpcomingOther, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.pill)),
            child: Text(l.p14EventCount(count), style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.onSoft)),
          ),
        ]),
      ),
    );
  }

  Widget _dayHeader(DateTime d, int count) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
      child: Semantics(
        header: true,
        child: Row(children: [
          ExcludeSemantics(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(eventLongDateOf(context, d),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
          ),
          if (count > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.pill)),
              child: Text(l.p14EventCount(count), style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.onSoft)),
            ),
          ],
        ]),
      ),
    );
  }

  List<Widget> _feedSlivers(DateTime? stale) {
    final f = _feeds[_feedKey]!;
    final l = context.l10n;
    final mode = _tab == 2 ? _Mode.created : (_sub == 1 ? _Mode.past : _Mode.upcoming);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        sliver: SliverList.list(children: [
          if (_tab == 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: EtkinlikSubChips(
                labels: [l.eventListUpcoming, l.eventListPast],
                selected: _sub,
                onSelected: _setSub,
              ),
            )
          else if (f.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
              child: Text(l.eventListCreatedHint,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.bu.mut, height: 1.4)),
            ),
          if (f.items.isEmpty) _emptyForTab(),
        ]),
      ),
      if (f.items.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: f.items.length + (f.more ? 1 : 0),
            itemBuilder: (_, i) {
              if (i >= f.items.length) return const _EventSkeleton(count: 1, padding: EdgeInsets.zero);
              final ev = f.items[i];
              return BuStaggerItem(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _card(ev, mode, ev['_day'] as DateTime?),
                ),
              );
            },
          ),
        ),
    ];
  }

  /// Kaynak siteden gelen resmi etkinlik: sade satır.
  Widget _officialRow(Map<String, dynamic> ev) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final day = _effDay(ev);
    return BuCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      onTap: () => _open(ev),
      child: Row(children: [
        EtkinlikDateBlock(month: eventMonthShortOf(context, day.month), day: '${day.day}'),
        const SizedBox(width: 14),
        Expanded(
          child: Text('${ev['title'] ?? ''}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink, height: 1.25)),
        ),
        const SizedBox(width: 6),
        Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut),
      ]),
    );
  }

  List<Map<String, dynamic>> _avatarsOf(Map<String, dynamic> ev) {
    final v = ev['attendeesPreview'] ?? ev['avatars'];
    return [
      for (final a in (v is List ? v : const []))
        if (a is Map) a.cast<String, dynamic>()
    ];
  }

  Widget _meta(IconData icon, String text, {int maxLines = 1}) {
    final t = context.bu;
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: ExcludeSemantics(child: Icon(icon, size: 15, color: t.mut)),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut)),
      ),
    ]);
  }

  Widget _clubLine(String? org, {Color? color}) {
    final t = context.bu;
    if (org == null || org.isEmpty) return const SizedBox.shrink();
    final c = color ?? t.pr;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ExcludeSemantics(child: Icon(LucideIcons.users, size: 13, color: c)),
      const SizedBox(width: 6),
      Flexible(
        child: Text(org,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: c)),
      ),
    ]);
  }

  Widget _card(Map<String, dynamic> ev, _Mode mode, DateTime? day) {
    return switch (mode) {
      _Mode.discover => _discoverCard(ev, day),
      _Mode.upcoming => _mineCard(ev, day, past: false),
      _Mode.past => _mineCard(ev, day, past: true),
      _Mode.created => _createdCard(ev, day),
    };
  }

  String _timeOf(Map<String, dynamic> ev) {
    final start = ev['_start'] as DateTime?;
    final end = ev['_end'] as DateTime?;
    if (start == null) return '';
    // LRM: Arapça (RTL) düzende saat aralığı ters dizilmesin.
    return end != null ? '‎${eventHm(start)} – ${eventHm(end)}' : eventHm(start);
  }

  // ---- Keşfet kartı ----

  Widget _discoverCard(Map<String, dynamic> ev, DateTime? day) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final id = (ev['id'] as num).toInt();
    final my = _myRsvp(ev);
    final going = _going(ev) ?? 0;
    final cap = (ev['capacity'] as num?)?.toInt();
    final place = (ev['location'] as String?)?.trim();
    final org = (ev['communityName'] as String?)?.trim();
    final time = _timeOf(ev);
    final cancelled = eventIsCancelled(ev);
    final closed = eventIsClosed(ev) || _closedIds.contains(id);
    final past = _isPastMonth;
    final full = cap != null && going >= cap && my != 'GOING';
    final live = !cancelled && !past && _isLive(ev);
    final busy = _rsvpBusy.contains(id);

    Widget? tag;
    if (cancelled) {
      tag = EventStatusTag(l.eventListCancelled, tone: EventTone.danger);
    } else if (closed) {
      tag = EventStatusTag(l.eventListRegClosedTag, tone: EventTone.neutral);
    } else if (full) {
      tag = EventStatusTag(l.eventFormCapacityFull, tone: EventTone.danger);
    } else if (live) {
      tag = EventStatusTag(l.p14Live, tone: EventTone.brand, icon: LucideIcons.radio);
    }

    final Widget actions;
    if (cancelled || past || closed || full) {
      actions = Align(
        alignment: AlignmentDirectional.centerEnd,
        child: EtkinlikDetailLink(label: l.p14Detail, onTap: () => _open(ev)),
      );
    } else if (my == 'GOING') {
      actions = Align(
        alignment: AlignmentDirectional.centerStart,
        child: EtkinlikPill(label: l.eventListInMine, icon: LucideIcons.calendarCheck, bg: t.okSoft, fg: t.ok, onTap: _openMine),
      );
    } else {
      actions = Row(children: [
        Expanded(
          child: EtkinlikActionButton(
            key: ValueKey('ev-join-$id'),
            label: l.eventListJoin,
            icon: LucideIcons.circleCheck,
            primary: true,
            busy: busy,
            onTap: busy ? null : () => _join(ev, 'GOING'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: EtkinlikActionButton(
            key: ValueKey('ev-interested-$id'),
            label: l.eventListInterested,
            icon: my == 'INTERESTED' ? LucideIcons.star : LucideIcons.star,
            onTap: (busy || my == 'INTERESTED') ? null : () => _join(ev, 'INTERESTED'),
          ),
        ),
      ]);
    }

    return BuCard(
      key: ValueKey('ev-card-$id'),
      padding: const EdgeInsets.all(16),
      radius: 20,
      onTap: () => _open(ev),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          EtkinlikDateBlock(
            month: day == null ? '' : eventMonthShortOf(context, day.month),
            day: day == null ? '' : '${day.day}',
            tone: (cancelled || past) ? EtkinlikBlockTone.grey : EtkinlikBlockTone.brand,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: _clubLine(org))),
                if (tag != null) ...[const SizedBox(width: 8), tag],
              ]),
              const SizedBox(height: 4),
              Text('${ev['title'] ?? ''}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: tx.titleLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: cancelled ? t.mut : t.ink,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  )),
              const SizedBox(height: 8),
              Wrap(spacing: 16, runSpacing: 4, children: [
                if (time.isNotEmpty) _meta(LucideIcons.clock, time),
                if (place != null && place.isNotEmpty) _meta(LucideIcons.mapPin, place, maxLines: 2),
              ]),
              const SizedBox(height: 4),
              _meta(LucideIcons.users, l.eventListAttendeeCount('$going')),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        BuFadeThrough(
          duration: BuMotion.short,
          child: KeyedSubtree(key: ValueKey('${my ?? '-'}$busy$closed$full'), child: actions),
        ),
      ]),
    );
  }

  // ---- Etkinliklerim kartı (Yaklaşan / Geçmiş) ----

  Widget _mineCard(Map<String, dynamic> ev, DateTime? day, {required bool past}) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final id = (ev['id'] as num).toInt();
    final my = _myRsvp(ev);
    final going = _going(ev) ?? 0;
    final place = (ev['location'] as String?)?.trim();
    final org = (ev['communityName'] as String?)?.trim();
    final time = _timeOf(ev);
    final cancelled = eventIsCancelled(ev);
    final live = !past && !cancelled && _isLive(ev);
    final tone = (past || cancelled) ? EtkinlikBlockTone.grey : EtkinlikBlockTone.blue;

    Widget? pill;
    if (cancelled) {
      pill = EventStatusTag(l.eventListCancelled, tone: EventTone.danger);
    } else if (!past) {
      pill = my == 'INTERESTED'
          ? EventStatusTag(l.eventListInterested, tone: EventTone.neutral, icon: LucideIcons.star)
          : EventStatusTag(l.p14StatusGoing, tone: EventTone.brand, dot: true);
    }

    return BuCard(
      key: ValueKey('ev-card-$id'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 6, 14),
      radius: 20,
      color: past ? t.mut.withValues(alpha: .06) : null,
      onTap: () => _open(ev),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          EtkinlikDateBlock(
            month: day == null ? '' : eventMonthShortOf(context, day.month),
            day: day == null ? '' : '${day.day}',
            tone: tone,
            size: 52,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: _clubLine(org, color: past ? t.mut : t.pr))),
                  if (pill != null) ...[const SizedBox(width: 6), pill],
                ]),
                const SizedBox(height: 4),
                Text('${ev['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tx.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: (past || cancelled) ? t.mut : t.ink,
                        decoration: cancelled ? TextDecoration.lineThrough : null)),
              ]),
            ),
          ),
          if (!past && !cancelled)
            PopupMenuButton<String>(
              tooltip: l.eventListOptions,
              icon: Icon(LucideIcons.ellipsis, size: 20, color: t.ink),
              onSelected: (_) => _leave(ev),
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'leave',
                    child: Row(children: [
                      Icon(LucideIcons.logOut, size: 18, color: t.danger),
                      const SizedBox(width: 10),
                      Text(l.eventListLeaveTitle),
                    ])),
              ],
            )
          else if (past)
            PopupMenuButton<String>(
              tooltip: l.eventListOptions,
              icon: Icon(LucideIcons.ellipsis, size: 20, color: t.mut),
              onSelected: (_) => _open(ev),
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'detail',
                    child: Row(children: [
                      Icon(LucideIcons.arrowRight, size: 18, color: t.ink),
                      const SizedBox(width: 10),
                      Text(l.p14Detail),
                    ])),
              ],
            )
          else
            const SizedBox(width: 10),
        ]),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 12),
            if (past)
              Wrap(spacing: 16, runSpacing: 4, children: [
                if (time.isNotEmpty) _meta(LucideIcons.clock, '$time (${l.p14Ended})'),
                if (place != null && place.isNotEmpty) _meta(LucideIcons.mapPin, place),
              ])
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: t.tint(1).bg.withValues(alpha: .55), borderRadius: BorderRadius.circular(12)),
                child: Wrap(spacing: 16, runSpacing: 6, children: [
                  if (time.isNotEmpty) _meta(LucideIcons.clock, time),
                  if (place != null && place.isNotEmpty) _meta(LucideIcons.mapPin, place, maxLines: 2),
                ]),
              ),
            const SizedBox(height: 12),
            if (past)
              Row(children: [
                Flexible(
                  child: Wrap(spacing: 8, runSpacing: 6, children: [
                    EventStatusTag(l.p14Attended, tone: EventTone.neutral, icon: LucideIcons.circleCheck),
                    EventStatusTag(l.p14Completed, tone: EventTone.neutral),
                  ]),
                ),
                const SizedBox(width: 8),
                EtkinlikDetailLink(label: l.p14Detail, onTap: () => _open(ev), muted: true),
              ])
            else
              EtkinlikActionButton(
                label: l.p14Detail,
                grey: true,
                trailing: buDirIcon(context, LucideIcons.arrowRight),
                onTap: () => _open(ev),
              ),
            if (live || going == 0) const SizedBox.shrink(),
          ]),
        ),
      ]),
    );
  }

  // ---- Oluşturduklarım kartı ----

  Widget _createdCard(Map<String, dynamic> ev, DateTime? day) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final id = (ev['id'] as num).toInt();
    final going = _going(ev) ?? 0;
    final org = (ev['communityName'] as String?)?.trim();
    final cancelled = eventIsCancelled(ev);
    final closed = eventIsClosed(ev) || _closedIds.contains(id);
    final pendingReview = eventIsPendingReview(ev);
    final rejected = eventIsRejected(ev);
    final reason = rejected ? eventRejectReason(ev) : null;
    final time = _timeOf(ev);
    final place = (ev['location'] as String?)?.trim();
    final pending = [ev['pendingRequestCount'], ev['pendingRequests'], ev['pendingCount']].whereType<num>().firstOrNull?.toInt();

    final Widget status;
    if (cancelled) {
      status = EventStatusTag(l.eventListCancelled, tone: EventTone.danger, icon: LucideIcons.calendarX);
    } else if (pendingReview) {
      status = EventStatusTag(l.evcStatusPending, tone: EventTone.warn, icon: LucideIcons.hourglass);
    } else if (rejected) {
      status = EventStatusTag(l.evcStatusRejected, tone: EventTone.danger, icon: LucideIcons.circleAlert);
    } else if (closed) {
      status = EventStatusTag(l.eventListRegClosedTag, tone: EventTone.neutral, icon: LucideIcons.lock);
    } else {
      status = EventStatusTag(l.eventListOpen, dot: true);
    }
    final tone = (rejected || cancelled) ? EtkinlikBlockTone.grey : EtkinlikBlockTone.blue;

    return BuCard(
      key: ValueKey('ev-card-$id'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 14),
      radius: 20,
      onTap: () => _open(ev),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          status,
          const SizedBox(width: 10),
          Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: _clubLine(org, color: t.mut))),
          if (!cancelled)
            PopupMenuButton<String>(
              tooltip: l.eventListOptions,
              onSelected: (a) => _manage(ev, a),
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: t.tint(1).bg, shape: BoxShape.circle),
                child: Icon(LucideIcons.ellipsis, size: 18, color: t.ink),
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(LucideIcons.pencil, size: 18, color: t.ink),
                      const SizedBox(width: 12),
                      Text(l.eventListEdit),
                    ])),
                PopupMenuItem(
                    value: closed ? 'reopen' : 'close',
                    child: Row(children: [
                      Icon(closed ? LucideIcons.lockOpen : LucideIcons.lock, size: 18, color: t.ink),
                      const SizedBox(width: 12),
                      Text(closed ? l.eventListReopen : l.eventListClose),
                    ])),
                const PopupMenuDivider(),
                PopupMenuItem(
                    value: 'cancel',
                    child: Row(children: [
                      Icon(LucideIcons.circleX, size: 18, color: t.danger),
                      const SizedBox(width: 12),
                      Text(l.eventListCancelConfirm, style: TextStyle(color: t.danger, fontWeight: FontWeight.w600)),
                    ])),
              ],
            )
          else
            const SizedBox(width: 8),
        ]),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              EtkinlikDateBlock(
                month: day == null ? '' : eventMonthShortOf(context, day.month),
                day: day == null ? '' : '${day.day}',
                tone: tone,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${ev['title'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tx.titleLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: cancelled ? t.mut : t.ink,
                          decoration: cancelled ? TextDecoration.lineThrough : null)),
                  if (time.isNotEmpty || (place != null && place.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(spacing: 16, runSpacing: 4, children: [
                        if (time.isNotEmpty) _meta(LucideIcons.clock, time),
                        if (place != null && place.isNotEmpty) _meta(LucideIcons.mapPin, place),
                      ]),
                    ),
                ]),
              ),
            ]),
            if (rejected && reason != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('ev-reject-reason'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: t.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(LucideIcons.triangleAlert, size: 18, color: t.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l.evcRejectReason(reason),
                        style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: t.danger, height: 1.4)),
                  ),
                ]),
              ),
            ],
            if (!cancelled && !rejected && !pendingReview) ...[
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                EventAvatarStack(avatars: _avatarsOf(ev), total: going),
                if (pending != null && pending > 0)
                  EventStatusTag(l.profilyardEventPendingCount('$pending'), tone: EventTone.warn, icon: LucideIcons.userPlus),
                EtkinlikDetailLink(label: l.eventListAttendees, onTap: () => _open(ev)),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

enum _Mode { discover, upcoming, past, created }

/// Başlık çubuğu hapı ("Yoklama"): nötr gri zemin + marka renkli simge; dar ekranda yalnız simge.
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.label, required this.icon, required this.onTap, required this.compact});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: BuPressable(
          key: const ValueKey('events-checkin'),
          onTap: onTap,
          haptic: BuHaptic.selection,
          child: Container(
            constraints: BoxConstraints(minHeight: 48, minWidth: compact ? 48 : 0),
            alignment: Alignment.center,
            child: Container(
              height: 40,
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
              decoration: BoxDecoration(color: t.tint(1).bg, borderRadius: BorderRadius.circular(BuRadius.pill)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: t.pr),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  Text(label, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Başlık çubuğu "+" düğmesi: koyu mürekkep daire.
class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: BuPressable(
          key: const ValueKey('events-create'),
          onTap: onTap,
          haptic: BuHaptic.light,
          scale: .92,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle),
                child: Icon(LucideIcons.plus, size: 22, color: t.bg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}




/// Yükleniyor iskeleti: (Keşfet'te) takvim kartı (seçili gün dahil) + etkinlik kartları (avatar yığını + tek düğme); küçük "Yükleniyor" etiketi.
class _EventSkeleton extends StatelessWidget {
  const _EventSkeleton({this.count = 3, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0), this.calendar = false});

  final int count;
  final EdgeInsetsGeometry padding;
  final bool calendar;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget card(Widget child) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.bd)),
          child: child,
        );
    return Semantics(
      label: context.l10n.eventListLoading,
      liveRegion: true,
      container: true,
      child: BuSkeletonScope(
        child: Padding(
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (calendar) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(context.l10n.eventListLoading, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.mut)),
              ),
              card(Column(children: [
                const Row(children: [
                  BuSkeleton(width: 112, height: 22, radius: 8),
                  SizedBox(width: 10),
                  BuSkeleton(width: 40, height: 22, radius: 11),
                  Spacer(),
                  BuSkeleton.circle(32),
                  SizedBox(width: 8),
                  BuSkeleton.circle(32),
                ]),
                const SizedBox(height: 16),
                for (var r = 0; r < 4; r++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      for (var c = 0; c < 7; c++)
                        r == 0
                            ? const BuSkeleton(width: 28, height: 10, radius: 5)
                            : (r == 2 && c == 3)
                                ? Container(width: 36, height: 36, decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle))
                                : const BuSkeleton.circle(36),
                    ]),
                  ),
                const SizedBox(height: 6),
                const Row(children: [
                  BuSkeleton.circle(8),
                  SizedBox(width: 8),
                  BuSkeleton(width: 110, height: 12, radius: 6),
                  Spacer(),
                  BuSkeleton(width: 70, height: 12, radius: 6),
                ]),
              ])),
              const SizedBox(height: 18),
            ],
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card(const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton(width: 56, height: 56, radius: 16),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        BuSkeleton(width: 110, height: 14, radius: 7),
                        SizedBox(height: 10),
                        BuSkeleton.line(height: 16),
                        SizedBox(height: 8),
                        BuSkeleton.line(width: 160),
                      ]),
                    ),
                  ]),
                  SizedBox(height: 14),
                  Row(children: [
                    BuSkeleton.circle(26),
                    SizedBox(width: 4),
                    BuSkeleton.circle(26),
                    SizedBox(width: 4),
                    BuSkeleton.circle(26),
                    Spacer(),
                    BuSkeleton(width: 110, height: 44, radius: 14),
                  ]),
                ])),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Takvim başlığı oku: çerçevesiz, yalnız chevron (48 dp hedef).
class _BareChevron extends StatelessWidget {
  const _BareChevron({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: tooltip,
      enabled: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: BuPressable(
          onTap: onTap,
          enabled: onTap != null,
          haptic: BuHaptic.selection,
          scale: .9,
          child: SizedBox(width: 44, height: 48, child: Center(child: Icon(icon, size: 22, color: onTap == null ? t.mut.withValues(alpha: .4) : t.ink))),
        ),
      ),
    );
  }
}
