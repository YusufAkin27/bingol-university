import 'package:flutter/material.dart';

import '../../core/connectivity/offline_banner.dart' show StaleLabel;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../core/typography.dart';
import '../news/news_tile.dart' show newsMonthName, newsWeekdayName;
import '../polls/poll_menu_card.dart';
import 'menu_models.dart';
import 'menu_photo.dart';

String _monthParam(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

/// Yemek listesi: gün seçici (önceki/sonraki gün) + öğle yemeği kartı (fotoğraflı ya da fotoğrafsız)
/// + günlük menü puanlama.
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
  Map<int, MenuDay> _menus = {}; // gün -> yemekler + fotoğraf
  bool _loading = true;
  bool _maintenance = false;
  Object? _error;
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    _load();
  }

  /// Liste önbellekten (bayat) geldiyse sunucudan alındığı an.
  DateTime? _staleAt;

  Future<void> _load({bool silent = false}) async {
    final id = ++_reqId;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = widget.session.api;
      final resp = await api.getResponse('/menu?month=${_monthParam(_month)}');
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
          if (d == null || d.year != _month.year || d.month != _month.month) continue;
          map[d.day] = MenuDay.fromJson(e);
        }
      }
      if (!mounted || id != _reqId) return;
      setState(() {
        _menus = map;
        _staleAt = resp.fromCache ? resp.cachedAt : null;
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

  /// Gün ±1; ay sınırı aşılırsa o ayın listesi yüklenir.
  void _step(int delta) {
    final d = DateTime(_selected.year, _selected.month, _selected.day + delta);
    final monthChanged = d.year != _month.year || d.month != _month.month;
    setState(() {
      _selected = d;
      if (monthChanged) {
        _month = DateTime(d.year, d.month);
        _menus = {};
      }
    });
    if (monthChanged) _load();
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
          _dayStepper(t),
          if (_maintenance && !_loading)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: StaleBanner(text: context.l10n.menuStale),
            ),
          if (!_loading) StaleLabel(cachedAt: _staleAt, padding: const EdgeInsets.fromLTRB(20, 8, 20, 0)),
          Expanded(child: _body(t)),
        ],
      ),
    );
  }

  Widget _dayStepper(BuTokens t) {
    final d = _selected;
    final l = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final title = '${d.day} ${newsMonthName(context, d.month)} ${newsWeekdayName(context, d.weekday)}';
    Widget arrow(IconData icon, String tip, int delta) => IconButton(
          key: ValueKey('yemek_day_${delta < 0 ? 'prev' : 'next'}'),
          tooltip: tip,
          onPressed: () => _step(delta),
          icon: Icon(icon, size: 20, color: t.ink),
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 18, _hPad, 0),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.bd),
        ),
        child: Row(
          children: [
            // Simgeler RTL'de kendiliğinden çevrilmez: "önceki" = başlangıç tarafı.
            arrow(rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft, l.yemekPrevDay, -1),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.heading.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: t.ink)),
                  if (_isToday(d))
                    Text(l.yemekToday,
                        style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: t.pr)),
                ],
              ),
            ),
            arrow(rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight, l.yemekNextDay, 1),
          ],
        ),
      ),
    );
  }

  Widget _body(BuTokens t) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!, onRetry: _load);

    final day0 = _menus[_selected.day];
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(_hPad, 14, _hPad, 24),
        children: [
          if (_menus.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: EmptyView(icon: LucideIcons.utensils, text: context.l10n.menuNoMenuMonth),
            )
          else
            _lunch(t, day0?.items, day0?.imageUrl),
          if (_isToday(_selected)) PollMenuCard(session: widget.session),
        ],
      ),
    );
  }

  /// Öğle yemeği: fotoğraf varsa üstte 16:9 fotoğraf (başlık + saat rozeti koyu degrade üstünde).
  Widget _lunch(BuTokens t, List<String>? items, String? imageUrl) {
    final empty = items == null || items.isEmpty;
    final l = context.l10n;
    return MenuPhotoGate(
      url: imageUrl,
      builder: (context, photo) {
        final hasPhoto = photo != null;
        final list = BuCard(
          radius: 20,
          padding: EdgeInsetsDirectional.fromSTEB(18, hasPhoto ? 6 : 16, 18, 6),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasPhoto)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(l.yemekLunch,
                              style: BuType.title.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: t.ink)),
                        ),
                        const SizedBox(width: 8),
                        Text(_time, style: BuType.label.copyWith(fontSize: 12, color: t.mut)),
                      ],
                    ),
                  ),
                if (empty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l.menuNoMenuDay, style: BuType.heading.copyWith(height: 1.5, color: t.ink)),
                  )
                else
                  for (var i = 0; i < items.length; i++)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: hasPhoto ? 10 : 13),
                      decoration: BoxDecoration(
                        border: i == 0 ? null : Border(top: BorderSide(color: t.bd.withAlpha(150))),
                      ),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(items[i],
                                style: BuType.heading.copyWith(fontWeight: FontWeight.w600, height: 1.35, color: t.ink)),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
        if (!hasPhoto) return Padding(padding: const EdgeInsets.only(bottom: 14), child: list);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              image: true,
              label: l.menuPhotoLabel,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      photo,
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              stops: [0, .55, 1],
                              colors: [Color(0xEB171E33), Color(0x8C171E33), Color(0x00171E33)],
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: 16,
                        end: 16,
                        bottom: 12,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(l.yemekTodaysMenu,
                                      style: BuType.label.copyWith(fontSize: 12, color: Colors.white)),
                                  Text(l.yemekLunch,
                                      style: BuType.title.copyWith(
                                          fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 28,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0x33FFFFFF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0x66FFFFFF)),
                              ),
                              child: Text(_time,
                                  style: BuType.label.copyWith(
                                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            list,
            const SizedBox(height: 14),
          ],
        );
      },
    );
  }
}
