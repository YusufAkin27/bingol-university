import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../clubs/club_detail_parts.dart' show ClubBarIcon;
import '../clubs/clubs_tab.dart';
import '../clubs/clubs_widgets.dart' show ClubJoinButton, ClubTextTabs;
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
    final t = context.bu;
    final l = context.l10n;
    final feed = _tab == 0 ? null : _feeds[_feedKey]!;

    // Yükleniyor yalnız iskelet; hata/boş/hazır durumlar kendi blokları ile sliver olarak çizilir.
    final loading = _tab == 0 ? _loading : (feed!.loading && !feed.loaded);
    final Object? err = _tab == 0 ? _error : (feed!.loaded ? null : feed.error);
    final DateTime? stale = _tab == 0 ? _calStale[_ym(_month)] : feed!.staleAt;

    final List<Widget> slivers;
    if (loading) {
      slivers = const [];
    } else if (err != null) {
      slivers = [
        SliverToBoxAdapter(child: _errorCard(cached: stale != null)),
      ];
    } else if (_tab == 0) {
      slivers = _discoverSlivers(stale);
    } else {
      slivers = _feedSlivers(stale);
    }

    return BuStaggerScope(
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(
          children: [
            _header(),
            const SizedBox(height: 4),
            // Metin sekmeleri (Stitch v3): Keşfet | Etkinliklerim | Oluşturduklarım.
            ClubTextTabs(
              labels: [l.eventListTabDiscover, l.eventListTabMine, l.eventListTabCreated],
              index: _tab,
              onChanged: _setTab,
            ),
            Expanded(
              child: BuSwapIn(
                loading: loading,
                skeleton: SingleChildScrollView(primary: false, physics: const NeverScrollableScrollPhysics(), child: _EventSkeleton(calendar: _tab == 0)),
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [...slivers, const SliverToBoxAdapter(child: SizedBox(height: kNavInset))],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Başlık: (varsa) geri oku + "Etkinlikler" 28/700; sağda marka renkli "Yoklama" metni ve "+" (yeni etkinlik).
  Widget _header() {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final canPop = Navigator.of(context).canPop();
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(canPop ? 12 : 20, top, 12, 0),
      child: Row(children: [
        if (canPop) ...[
          ClubBarIcon(icon: LucideIcons.arrowLeft, tooltip: l.commonBack, onTap: () => Navigator.maybePop(context), width: 40),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(l.eventListTitle,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.display.copyWith(fontSize: 28, height: 1.2, color: t.ink)),
          ),
        ),
        TextButton(
          key: const ValueKey('events-checkin'),
          style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 8)),
          onPressed: () {
            buHaptic(BuHaptic.selection);
            _scanCheckin();
          },
          child: Text(l.eventListCheckin, style: tx.bodyLarge!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
        ),
        ClubBarIcon(key: const ValueKey('events-create'), icon: LucideIcons.plus, tooltip: l.eventListCreate, onTap: _create, width: 44),
      ]),
    );
  }

  /// "Yüklenemedi, tekrar dene" + marka renkli "Yeniden dene" (metin düğmesi); ikon/kart yok.
  Widget _errorCard({bool cached = false}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      key: const ValueKey('events-error'),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(l.p51ClubsLoadFailed, style: tx.titleMedium!.copyWith(fontSize: 17, color: t.ink, fontWeight: FontWeight.w600))),
          TextButton(
            key: const ValueKey('events-retry'),
            style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: _tab == 0 ? () => _load() : () => _loadFeed(_feedKey),
            child: Text(l.commonRetry, style: tx.titleMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
          ),
        ]),
        if (cached) Text(l.p14ErrorBodyCache, style: tx.bodySmall!.copyWith(color: t.mut)),
      ]),
    );
  }

  /// Amber not satırı (ikonsuz): çevrimdışı / kesik liste / geçmiş ay.
  Widget _noteRow(String text) {
    final t = context.bu;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: t.warnSoft, borderRadius: BorderRadius.circular(16)),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.onWarnSoft, height: 1.4, fontWeight: FontWeight.w500)),
    );
  }

  /// Boş durum bloğu (sola yaslı): kalın başlık, muted açıklama, marka renkli metin bağlantısı. İllüstrasyon/kart yok.
  Widget _stateBlock({required String title, String? body, String? actionLabel, VoidCallback? onAction, Key? key}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: tx.titleMedium!.copyWith(fontSize: 20, color: t.ink, fontWeight: FontWeight.w700)),
        if (body != null) ...[
          const SizedBox(height: 4),
          Text(body, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.4)),
        ],
        if (actionLabel != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: EdgeInsets.zero),
              onPressed: onAction,
              child: Text(actionLabel, style: tx.bodyLarge!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }

  /// Sekmeye göre boş durum.
  Widget _emptyForTab() {
    final l = context.l10n;
    if (_tab == 0) {
      final day = _selected != null;
      return _stateBlock(
        key: const ValueKey('events-empty'),
        title: day ? l.eventListEmptyDay : l.eventListEmptyMonth,
        body: day ? l.p51EvEmptyDayBody : l.p14EmptyMonthBody,
        actionLabel: l.p51EvBrowseAll,
        onAction: _browseClubs,
      );
    }
    if (_tab == 2) {
      if (_canCreate == false) {
        return _stateBlock(
          key: const ValueKey('events-nocreate'),
          title: l.evcEmptyTitle,
          body: l.evcEmptyBody,
          actionLabel: l.evcBrowseClubs,
          onAction: _browseClubs,
        );
      }
      return _stateBlock(
        key: const ValueKey('events-empty'),
        title: l.eventListEmptyCreated,
        body: l.p14EmptyCreatedBody2,
        actionLabel: l.eventListCreate,
        onAction: _create,
      );
    }
    final past = _sub == 1;
    return _stateBlock(
      key: const ValueKey('events-empty'),
      title: past ? l.eventListEmptyPast : l.eventListEmptyUpcoming,
      body: past ? l.p14EmptyPastBody2 : l.p14EmptyUpcomingBody2,
      actionLabel: past ? null : l.eventListDiscover,
      onAction: past ? null : () => _setTab(0),
    );
  }

  void _browseClubs() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Scaffold(body: ClubsTab(session: widget.session))),
      );

  // ---- Keşfet: takvim (kartsız, Stitch v3) ----

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
    return Column(
      key: const ValueKey('events-calendar'),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 14, 0),
          child: Row(children: [
            Expanded(
              child: Semantics(
                header: true,
                child: BuFadeThrough(
                  duration: BuMotion.short,
                  child: SizedBox(
                    key: ValueKey(_ym(_month)),
                    height: 48,
                    child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(l.eventListMonthYear(eventMonthNameOf(context, _month.month), '${_month.year}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
                  )),
                ),
              ),
            ),
            if (_showToday)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: _goToday,
                child: Text(l.p14Today, style: tx.bodyLarge!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
              ),
            ClubBarIcon(
              icon: LucideIcons.chevronLeft,
              tooltip: l.eventListPrevMonth,
              width: 36,
              color: t.ink,
              onTap: _month.isBefore(DateTime(_today.year - 1, _today.month)) ? null : () => _goMonth(-1),
            ),
            ClubBarIcon(icon: LucideIcons.chevronRight, tooltip: l.eventListNextMonth, width: 36, color: t.ink, onTap: () => _goMonth(1)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 5),
          child: Row(children: [
            for (var i = 1; i <= 7; i++)
              Expanded(
                child: SizedBox(
                  height: 14,
                  child: Text(ar ? eventDayShortOf(context, i) : trUpper(eventDayShortOf(context, i)).characters.first,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w600, color: t.mut, letterSpacing: ar ? 0 : .4)),
                ),
              ),
          ]),
        ),
        // Ay değişince ızgara yatay kayarak yer değiştirir (ileri: sola, geri: sağa; RTL'de aynalanır).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: BuSharedAxis(
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
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: t.bd),
      ],
    );
  }

  Widget _dayCell(DateTime d, Set<String> busy) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final inMonth = d.month == _month.month;
    final on = _selected == d;
    final today = d == _today;
    final dot = inMonth && busy.contains(_ymd(d));
    final fg = on || today ? t.pr : (inMonth ? t.ink : t.mut.withValues(alpha: .45));
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
            height: 41,
            child: Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: Stack(alignment: Alignment.center, children: [
                  // Seçili gün: yumuşak (soft) daire 0.6 -> 1 ölçekle belirir.
                  // Bugün (seçili değilken): sönük yumuşak daire.
                  if (today && !on) DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: t.soft.withValues(alpha: .55)), child: const SizedBox.expand()),
                  AnimatedScale(
                    scale: on ? 1 : .6,
                    duration: BuMotion.of(context, BuMotion.short),
                    curve: BuMotion.emphasizedDecelerate,
                    child: AnimatedOpacity(
                      opacity: on ? 1 : 0,
                      duration: BuMotion.of(context, BuMotion.short),
                      child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: t.soft), child: const SizedBox.expand()),
                    ),
                  ),
                  AnimatedDefaultTextStyle(
                    duration: BuMotion.of(context, BuMotion.short),
                    style: tx.bodyMedium!.copyWith(color: fg, fontWeight: on || today ? FontWeight.w700 : FontWeight.w500),
                    child: Text('${d.day}', maxLines: 1),
                  ),
                  // Etkinlik noktası: muted (seçili günde marka), veri gelince 0 -> 1 ölçekle belirir.
                  PositionedDirectional(
                    bottom: 3,
                    child: AnimatedScale(
                      scale: dot ? 1 : 0,
                      duration: BuMotion.of(context, BuMotion.short),
                      curve: BuMotion.emphasizedDecelerate,
                      child: Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? t.pr : t.mut.withValues(alpha: .7))),
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
        padding: EdgeInsets.zero,
        sliver: SliverList.list(children: [
          _calendarCard(),
          if (stale != null) Padding(padding: const EdgeInsets.only(top: 12), child: _noteRow(context.l10n.p51EvOffline)),
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
          padding: EdgeInsets.zero,
          sliver: SliverList.builder(
            itemCount: others.length,
            itemBuilder: (_, i) => BuStaggerItem(
              index: i,
              child: Padding(
                padding: EdgeInsets.zero,
                child: others[i]['source'] == 'OFFICIAL' ? _officialRow(others[i]) : _card(others[i], _Mode.discover, _effDay(others[i])),
              ),
            ),
          ),
        ),
      if (items.isNotEmpty)
        SliverPadding(
          padding: EdgeInsets.zero,
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
                  padding: EdgeInsets.zero,
                  child: ev['source'] == 'OFFICIAL' ? _officialRow(ev) : _card(ev, _Mode.discover, _effDay(ev)),
                ),
              );
            },
          ),
        ),
    ];
  }

  /// "Yaklaşan diğer günler" başlığı + etkinlik sayısı (muted).
  Widget _otherDaysHeader(int count) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Semantics(
        header: true,
        child: Row(children: [
          Expanded(
            child: Text(l.p14UpcomingOther, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
          ),
          const SizedBox(width: 10),
          Text(l.p14EventCount(count), style: tx.bodySmall!.copyWith(color: t.mut)),
        ]),
      ),
    );
  }

  /// Gün başlığı: "31 Ekim, Cumartesi" 17/600, sağda muted "3 Etkinlik".
  Widget _dayHeader(DateTime d, int count) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 8),
      child: Semantics(
        header: true,
        child: Row(children: [
          Expanded(
            child: Text(eventLongDateOf(context, d),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
          ),
          if (count > 0) ...[
            const SizedBox(width: 10),
            Text(l.p14EventCount(count), style: tx.bodySmall!.copyWith(color: t.mut)),
          ],
        ]),
      ),
    );
  }

  List<Widget> _feedSlivers(DateTime? stale) {
    final f = _feeds[_feedKey]!;
    final l = context.l10n;
    final t = context.bu;
    final mode = _tab == 2 ? _Mode.created : (_sub == 1 ? _Mode.past : _Mode.upcoming);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
        sliver: SliverList.list(children: [
          if (stale != null) _noteRow(l.p51EvOffline),
          if (_tab == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: EtkinlikSubChips(
                labels: [l.eventListUpcoming, l.eventListPast],
                selected: _sub,
                onSelected: _setSub,
              ),
            )
          else if (f.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(l.eventListCreatedHint, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
            ),
          if (f.items.isEmpty) _emptyForTab(),
        ]),
      ),
      if (f.items.isNotEmpty)
        SliverList.builder(
          itemCount: f.items.length + (f.more ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= f.items.length) return const _EventSkeleton(count: 1);
            final ev = f.items[i];
            return BuStaggerItem(index: i, child: _card(ev, mode, ev['_day'] as DateTime?));
          },
        ),
    ];
  }

  /// Kaynak siteden gelen resmi etkinlik: aynı satır biçimi, sağda ok.
  Widget _officialRow(Map<String, dynamic> ev) => _row(ev, _Mode.discover, _effDay(ev));

  Widget _card(Map<String, dynamic> ev, _Mode mode, DateTime? day) => _row(ev, mode, day);

  String _timeOf(Map<String, dynamic> ev) {
    final start = ev['_start'] as DateTime?;
    final end = ev['_end'] as DateTime?;
    if (start == null) return '';
    // LRM: Arapça (RTL) düzende saat aralığı ters dizilmesin.
    return end != null ? '‎${eventHm(start)} – ${eventHm(end)}' : eventHm(start);
  }

  /// Etkinlik satırı (Stitch v3, kartsız): solda gün/ay (karo yok), ortada kulüp (marka) + başlık 17/600 + muted meta,
  /// sağda duruma göre küçük çerçeveli "Katıl" / muted durum metni / üç nokta menüsü. Altta ince ayraç.
  Widget _row(Map<String, dynamic> ev, _Mode mode, DateTime? day) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final id = (ev['id'] as num).toInt();
    final official = ev['source'] == 'OFFICIAL';
    final my = _myRsvp(ev);
    final going = _going(ev) ?? 0;
    final cap = (ev['capacity'] as num?)?.toInt();
    final place = (ev['location'] as String?)?.trim();
    final org = (ev['communityName'] as String?)?.trim();
    final time = _timeOf(ev);
    final cancelled = eventIsCancelled(ev);
    final closed = eventIsClosed(ev) || _closedIds.contains(id);
    final past = mode == _Mode.past || (mode == _Mode.discover && _isPastMonth);
    final full = cap != null && going >= cap && my != 'GOING';
    final live = !official && !cancelled && !past && mode != _Mode.created && _isLive(ev);
    final busy = _rsvpBusy.contains(id);
    final pendingReview = eventIsPendingReview(ev);
    final rejected = eventIsRejected(ev);
    final reason = rejected ? eventRejectReason(ev) : null;
    final pending = [ev['pendingRequestCount'], ev['pendingRequests'], ev['pendingCount']].whereType<num>().firstOrNull?.toInt();
    final dim = past || cancelled || rejected;

    final meta = [if (live) l.p14Live, if (time.isNotEmpty) time, if (place != null && place.isNotEmpty) place].join(' · ');

    Widget statusText(String s, {Color? color, FontWeight? w}) => Text(s,
        maxLines: 2,
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
        style: tx.bodySmall!.copyWith(color: color ?? t.mut, fontSize: 13, fontWeight: w));
    Widget goingText() => Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: statusText(l.p51EvGoingYou)),
          const SizedBox(width: 4),
          ExcludeSemantics(child: Icon(LucideIcons.check, size: 16, color: t.mut)),
        ]);
    Widget menu(List<PopupMenuEntry<String>> Function() items, void Function(String) onSel) => PopupMenuButton<String>(
          tooltip: l.eventListOptions,
          padding: EdgeInsets.zero,
          icon: Icon(LucideIcons.ellipsisVertical, size: 22, color: t.mut),
          onSelected: onSel,
          itemBuilder: (_) => items(),
        );

    Widget? trailing;
    switch (mode) {
      case _Mode.discover:
        if (official) {
          trailing = Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut);
        } else if (cancelled) {
          trailing = statusText(l.eventListCancelled, color: t.danger, w: FontWeight.w600);
        } else if (my == 'GOING') {
          trailing = goingText();
        } else if (past) {
          trailing = null;
        } else if (closed) {
          trailing = statusText(l.eventListRegClosedTag);
        } else if (full) {
          trailing = statusText(l.eventFormCapacityFull);
        } else {
          trailing = Transform.translate(offset: const Offset(0, -6), child: ClubJoinButton(key: ValueKey('ev-join-$id'), label: l.eventListJoin, busy: busy, onPressed: busy ? null : () => _join(ev, 'GOING')));
        }
      case _Mode.upcoming:
        trailing = cancelled
            ? statusText(l.eventListCancelled, color: t.danger, w: FontWeight.w600)
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: my == 'INTERESTED' ? statusText(l.eventListInterested) : goingText()),
                menu(
                  () => [
                    PopupMenuItem(
                        value: 'leave',
                        child: Row(children: [Icon(LucideIcons.logOut, size: 18, color: t.danger), const SizedBox(width: 10), Text(l.eventListLeaveTitle)])),
                  ],
                  (_) => _leave(ev),
                ),
              ]);
      case _Mode.past:
        trailing = cancelled ? statusText(l.eventListCancelled, color: t.danger, w: FontWeight.w600) : statusText(l.p14Attended);
      case _Mode.created:
        final String st;
        Color? stColor;
        if (cancelled) {
          st = l.eventListCancelled;
          stColor = t.danger;
        } else if (pendingReview) {
          st = l.evcStatusPending;
          stColor = t.onWarnSoft;
        } else if (rejected) {
          st = l.evcStatusRejected;
          stColor = t.danger;
        } else if (closed) {
          st = l.eventListRegClosedTag;
        } else {
          st = l.eventListOpen;
        }
        trailing = Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: statusText(st, color: stColor, w: stColor != null ? FontWeight.w600 : null)),
          if (!cancelled)
            menu(
              () => [
                PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [Icon(LucideIcons.pencil, size: 18, color: t.ink), const SizedBox(width: 12), Text(l.eventListEdit)])),
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
              (a) => _manage(ev, a),
            ),
        ]);
    }

    final dayText = day == null ? '' : '${day.day}';
    final monText = day == null ? '' : trUpper(eventMonthShortOf(context, day.month));
    return BuPressable(
      scale: .99,
      child: Material(
        color: t.bg,
        child: InkWell(
          key: ValueKey('ev-card-$id'),
          onTap: () => _open(ev),
          child: Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 32,
                child: ExcludeSemantics(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(dayText, style: tx.titleMedium!.copyWith(fontSize: 22, height: 1.15, fontWeight: FontWeight.w600, color: dim ? t.mut.withValues(alpha: .7) : t.mut)),
                    Text(monText, maxLines: 1, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w600, color: t.mut, letterSpacing: .4)),
                  ]),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (org != null && org.isNotEmpty)
                    Text(org, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: dim ? t.mut : t.pr, fontWeight: FontWeight.w500)),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('${ev['title'] ?? ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: tx.titleMedium!.copyWith(
                          fontSize: 17,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: dim ? t.mut : t.ink,
                          decoration: cancelled ? TextDecoration.lineThrough : null,
                        )),
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.35)),
                    ),
                  if (rejected && reason != null)
                    Padding(
                      key: const ValueKey('ev-reject-reason'),
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(l.evcRejectReason(reason), style: tx.bodySmall!.copyWith(color: t.danger, fontWeight: FontWeight.w600, height: 1.4)),
                    ),
                  if (mode == _Mode.created && !cancelled && !rejected && !pendingReview && pending != null && pending > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(l.profilyardEventPendingCount('$pending'), style: tx.bodySmall!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .36),
                  child: Padding(padding: const EdgeInsets.only(top: 2), child: trailing),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

enum _Mode { discover, upcoming, past, created }

/// Yükleniyor iskeleti (kartsız): (Keşfet'te) ay başlığı + hafta daireleri, ardından satır iskeletleri.
class _EventSkeleton extends StatelessWidget {
  const _EventSkeleton({this.count = 3, this.calendar = false});

  final int count;
  final bool calendar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.eventListLoading,
      liveRegion: true,
      container: true,
      child: BuSkeletonScope(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (calendar) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(children: [BuSkeleton(width: 110, height: 20, radius: 8), Spacer(), BuSkeleton.circle(24), SizedBox(width: 12), BuSkeleton.circle(24)]),
            ),
            for (var r = 0; r < 2; r++)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (var c = 0; c < 7; c++) const BuSkeleton.circle(30)]),
              ),
            const SizedBox(height: 12),
          ],
          for (var i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                BuSkeleton(width: 36, height: 40, radius: 8),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton.line(width: 100, height: 12),
                    SizedBox(height: 10),
                    BuSkeleton.line(height: 16),
                    SizedBox(height: 8),
                    BuSkeleton.line(width: 160),
                  ]),
                ),
                SizedBox(width: 12),
                BuSkeleton(width: 60, height: 34, radius: 17),
              ]),
            ),
        ]),
      ),
    );
  }
}
