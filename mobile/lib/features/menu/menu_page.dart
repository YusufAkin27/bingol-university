import '../../core/analytics.dart';
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../academic/academic_models.dart' show istanbulWall;
import '../news/news_tile.dart' show newsMonthName, newsWeekdayName;
import '../polls/poll_menu_card.dart';
import 'menu_models.dart';
import 'menu_parts.dart';
import 'menu_topup.dart';

/// Bugünün Europe/Istanbul takvim günü (cihaz saat dilimi başka olsa da menü günü şaşmaz).
DateTime menuToday([DateTime? now]) {
  final w = istanbulWall(now ?? DateTime.now());
  return DateTime(w.year, w.month, w.day);
}

String _monthParam(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

/// Yemek listesi: gün seçici + öğle yemeği kartı (fotoğraflı ya da fotoğrafsız; yemek başına kalori ve
/// günlük toplam) + günlük menü puanlama.
class MenuPage extends StatefulWidget {
  const MenuPage({super.key, required this.session});

  final Session session;

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  static const _hPad = 20.0;
  static const _time = '11:30–14:00';

  late DateTime _month;
  late DateTime _selected;
  late List<DateTime> _days;
  late DateTime _anchor; // gün şeridinin kurulduğu "bugün" (gece yarısı geçişinde yenilenir)
  final Map<String, Map<int, MenuDay>> _byMonth = {}; // 'yyyy-MM' -> gün -> menü
  bool _loading = true;
  bool _maintenance = false;
  Object? _error;
  int _reqId = 0;

  // Seçici: bir hafta öncesinden dört hafta sonrasına (ay sınırı aşılınca o ay yüklenir).
  void _buildDays(DateTime today) {
    _anchor = today;
    _days = [for (var i = -7; i <= 28; i++) DateTime(today.year, today.month, today.day + i)];
  }

  /// Uygulama gece yarısını aşarak açık kaldıysa şerit ve seçim yeni güne taşınır.
  void _rollOverIfNeeded() {
    final today = menuToday();
    if (today == _anchor) return;
    final wasOnToday = _selected == _anchor;
    _buildDays(today);
    if (wasOnToday) {
      _selected = today;
      if (today.year != _month.year || today.month != _month.month) {
        _month = DateTime(today.year, today.month);
        if (!_byMonth.containsKey(_monthParam(_month))) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _load() : null);
      }
    }
  }

  Map<int, MenuDay> get _menus => _byMonth[_monthParam(_month)] ?? const {};

  @override
  void initState() {
    super.initState();
    final today = menuToday();
    _month = DateTime(today.year, today.month);
    _selected = today;
    _buildDays(today);
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    final id = ++_reqId;
    final month = _month;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = widget.session.api;
      final resp = await api.getResponse('/menu?month=${_monthParam(month)}', force: silent);
      final res = resp.body;
      var maintenance = false;
      try {
        final st = await api.get('/status', force: silent);
        maintenance = (st is Map && st['MENU'] is Map && st['MENU']['maintenance'] == true);
      } catch (_) {
        // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
      }
      final map = <int, MenuDay>{};
      if (res is List) {
        for (final e in res) {
          if (e is! Map) continue;
          final d = DateTime.tryParse('${e['date'] ?? ''}');
          if (d == null || d.year != month.year || d.month != month.month) continue;
          map[d.day] = MenuDay.fromJson(e);
        }
      }
      if (!mounted || id != _reqId) return;
      setState(() {
        _byMonth[_monthParam(month)] = map;
        _maintenance = maintenance;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _select(DateTime d) {
    final monthChanged = d.year != _month.year || d.month != _month.month;
    setState(() {
      _selected = d;
      if (monthChanged) _month = DateTime(d.year, d.month);
    });
    if (monthChanged && !_byMonth.containsKey(_monthParam(_month))) _load();
  }

  /// Yatay kaydırma: komşu güne geç (LTR: sola kaydır = sonraki gün; RTL'de ters). Şerit sınırında durur.
  void _swipeDay(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 350) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final next = rtl ? v > 0 : v < 0;
    final idx = _days.indexWhere((x) => x.year == _selected.year && x.month == _selected.month && x.day == _selected.day);
    final to = idx + (next ? 1 : -1);
    if (idx < 0 || to < 0 || to >= _days.length) return;
    buHaptic(BuHaptic.selection);
    _select(_days[to]);
  }

  bool _isToday(DateTime d) {
    final n = menuToday();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    _rollOverIfNeeded();
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: context.l10n.menuTitle, onBack: () => Navigator.pop(context)),
          const BuStaleStrip(),
          if (_maintenance && !_loading && _menus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(_hPad, 12, _hPad, 0),
              child: MenuStaleBanner(text: context.l10n.menuStale),
            ),
          // İskelet -> içerik: yalnız opaklık geçişi (düzen kayması yok).
          Expanded(
            child: BuSwapIn(
              loading: _loading && _byMonth.isEmpty,
              skeleton: const MenuSkeleton(),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: MenuDayStrip(days: _days, selected: _selected, onSelect: _select),
                ),
                // Gövdede sağa/sola kaydırmak gün değiştirir (dikey kaydırma ve çekip yenileme aynen çalışır).
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('menu-swipe'),
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: _swipeDay,
                    child: _body(t),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuTokens t) {
    if (_loading) return const MenuSkeleton(strip: false);
    if (_error != null && _menus.isEmpty) return ErrorView(error: _error!, onRetry: _load);

    final l = context.l10n;
    final d = _selected;
    final today = _isToday(d);
    final date = '${d.day} ${newsMonthName(context, d.month)}';
    final label = today ? '${l.yemekToday} · $date' : '${newsWeekdayName(context, d.weekday)} · $date';
    final day = _menus[d.day];
    final has = day != null && day.items.isNotEmpty;
    return BuRefreshIndicator(
      onRefresh: Analytics.pullRefresh(() => _load(silent: true)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(_hPad, 22, _hPad, 32),
        children: [
          // Gün değişince etiket + kart kısa süre solarak yer değiştirir (puanlama kartı yeniden kurulmaz).
          BuFadeThrough(
            child: Column(
              key: ValueKey('menu-day-${d.year}-${d.month}-${d.day}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MenuDayLabel(text: label),
                const SizedBox(height: 8),
                if (has) MenuMealCard(day: day, time: _time) else MenuEmptyCard(maintenance: _maintenance),
              ],
            ),
          ),
          if (today && has) ...[const SizedBox(height: 24), PollMenuCard(session: widget.session)],
          // Başka günün menüsünde puanlama kapalıdır; nedeni açıkla (kart yalnız bugün için vardır).
          if (!today && has) ...[
            const SizedBox(height: 16),
            Text(l.d1MenuRateTodayOnly, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut)),
          ],
          // Bakiye biten öğrenci için yukle.al kartı: menü boş olsa da görünür.
          SizedBox(height: has ? 24 : 0),
          const MenuTopUpCard(),
        ],
      ),
    );
  }
}
