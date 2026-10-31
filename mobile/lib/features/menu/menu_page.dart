import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../news/news_tile.dart' show newsMonthName, newsWeekdayName;
import '../polls/poll_menu_card.dart';
import 'menu_models.dart';
import 'menu_parts.dart';
import 'menu_photo.dart';

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
  static const _time = '11:30 – 14:00';

  late DateTime _month;
  late DateTime _selected;
  late final List<DateTime> _days;
  final Map<String, Map<int, MenuDay>> _byMonth = {}; // 'yyyy-MM' -> gün -> menü
  bool _loading = true;
  bool _maintenance = false;
  Object? _error;
  int _reqId = 0;

  Map<int, MenuDay> get _menus => _byMonth[_monthParam(_month)] ?? const {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _month = DateTime(now.year, now.month);
    _selected = today;
    // Seçici: bir hafta öncesinden dört hafta sonrasına (ay sınırı aşılınca o ay yüklenir).
    _days = [for (var i = -7; i <= 28; i++) DateTime(today.year, today.month, today.day + i)];
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
        final st = await api.get('/status');
        maintenance = (st is Map && st['MENU'] is Map && st['MENU']['maintenance'] == true);
      } catch (_) {}
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

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: context.l10n.menuTitle, onBack: () => Navigator.pop(context)),
          if (_maintenance && !_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(_hPad, 4, _hPad, 0),
              child: StaleBanner(text: context.l10n.menuStale, icon: LucideIcons.triangleAlert),
            ),
          // İskelet -> içerik: yalnız opaklık geçişi (düzen kayması yok).
          Expanded(
            child: BuSwapIn(
              loading: _loading && _byMonth.isEmpty,
              skeleton: const MenuSkeleton(),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: MenuDayStrip(days: _days, selected: _selected, onSelect: _select),
                ),
                Expanded(child: _body(t)),
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
    final label = trUpper(today ? '${l.yemekToday} · $date' : '${newsWeekdayName(context, d.weekday)} · $date');
    final day = _menus[d.day];
    final has = day != null && day.items.isNotEmpty;
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(_hPad, 16, _hPad, 24),
        children: [
          // Gün değişince etiket + kart kısa süre solarak yer değiştirir (puanlama kartı yeniden kurulmaz).
          BuFadeThrough(
            child: Column(
              key: ValueKey('menu-day-${d.year}-${d.month}-${d.day}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MenuDayLabel(text: label, today: today),
                const SizedBox(height: 12),
                if (has)
                  MenuPhotoGate(
                    url: day.imageUrl,
                    builder: (context, photo) => MenuMealCard(day: day, photo: photo, time: _time),
                  )
                else
                  MenuEmptyCard(maintenance: _maintenance, onRetry: _load),
              ],
            ),
          ),
          if (today) PollMenuCard(session: widget.session),
        ],
      ),
    );
  }
}
