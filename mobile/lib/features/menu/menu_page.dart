import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../core/typography.dart';
import '../polls/poll_menu_card.dart';

const _months = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];
const _daysShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _daysLong = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

String _monthParam(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

/// Yemek listesi: ay seçici, gün şeridi, seçili günün hero kartı ve sonraki günler.
class MenuPage extends StatefulWidget {
  const MenuPage({super.key, required this.session});

  final Session session;

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  static const _gap = 8.0;
  static const _hPad = 20.0;

  late DateTime _month;
  late DateTime _selected;
  Map<int, List<String>> _menus = {}; // gün -> yemekler
  bool _loading = true;
  bool _maintenance = false;
  Object? _error;
  int _reqId = 0;
  final _strip = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    _load();
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

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
      final res = await api.get('/menu?month=${_monthParam(_month)}');
      var maintenance = false;
      try {
        final st = await api.get('/status');
        maintenance = (st is Map && st['MENU'] is Map && st['MENU']['maintenance'] == true);
      } catch (_) {}
      final map = <int, List<String>>{};
      if (res is List) {
        for (final e in res) {
          if (e is! Map) continue;
          final d = DateTime.tryParse('${e['date'] ?? ''}');
          if (d == null || d.year != _month.year || d.month != _month.month) continue;
          final items = [
            for (final x in (e['items'] as List? ?? const [])) '$x'.trim()
          ].where((s) => s.isNotEmpty).toList();
          map[d.day] = items;
        }
      }
      if (!mounted || id != _reqId) return;
      setState(() {
        _menus = map;
        _maintenance = maintenance;
        _loading = false;
        _error = null;
      });
      _scrollToSelected();
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  int get _daysInMonth => DateUtils.getDaysInMonth(_month.year, _month.month);

  void _changeMonth(int delta) {
    final m = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    setState(() {
      _month = m;
      _menus = {};
      _selected = (m.year == now.year && m.month == now.month)
          ? DateTime(now.year, now.month, now.day)
          : DateTime(m.year, m.month, 1);
    });
    _load();
  }

  void _select(int day) {
    setState(() => _selected = DateTime(_month.year, _month.month, day));
    _scrollToSelected();
  }

  double _cellWidth(double total) => (total - _hPad * 2 - _gap * 4) / 5;

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_strip.hasClients) return;
      final w = _cellWidth(MediaQuery.of(context).size.width);
      // Seçili günü ortada tut (5 hücreli görünümde 3. sıra).
      final target = ((_selected.day - 1) - 2) * (w + _gap);
      final max = _strip.position.maxScrollExtent;
      _strip.animateTo(target.clamp(0.0, max), duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
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
          BuHeader(title: 'Yemek listesi', onBack: () => Navigator.pop(context)),
          _monthBar(t),
          _dayStrip(t),
          if (_maintenance && !_loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: StaleBanner(text: 'Yemek listesi güncellenemedi; son bilinen liste gösteriliyor.'),
            ),
          Expanded(child: _body(t)),
        ],
      ),
    );
  }

  Widget _monthBar(BuTokens t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 16, _hPad, 0),
      child: Row(
        children: [
          BuIconButton(icon: LucideIcons.chevronLeft, size: 44, tooltip: 'Önceki ay', onTap: () => _changeMonth(-1)),
          Expanded(
            child: Text('${_months[_month.month - 1]} ${_month.year}',
                textAlign: TextAlign.center,
                style: BuType.bodyStrong.copyWith(color: t.ink)),
          ),
          BuIconButton(icon: LucideIcons.chevronRight, size: 44, tooltip: 'Sonraki ay', onTap: () => _changeMonth(1)),
        ],
      ),
    );
  }

  Widget _dayStrip(BuTokens t) {
    final w = _cellWidth(MediaQuery.of(context).size.width);
    // Büyük yazı ölçeğinde gün hücresi taşmasın: yükseklik yazı ölçeğiyle büyür.
    final stripH = MediaQuery.textScalerOf(context).scale(48).clamp(66.0, 130.0);
    return SizedBox(
      height: stripH,
      child: ListView.separated(
        key: ValueKey(_monthParam(_month)),
        controller: _strip,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(_hPad, 0, _hPad, 0),
        itemCount: _daysInMonth,
        separatorBuilder: (_, __) => const SizedBox(width: _gap),
        itemBuilder: (_, i) {
          final d = DateTime(_month.year, _month.month, i + 1);
          final on = d.day == _selected.day;
          return SizedBox(
            width: w,
            child: Semantics(
              button: true,
              selected: on,
              label: '${d.day} ${_months[d.month - 1]}',
              child: ExcludeSemantics(
            child: Material(
              color: on ? t.pr : t.sf,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: on ? t.pr : t.bd),
              ),
              child: InkWell(
                customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                onTap: () => _select(d.day),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_daysShort[d.weekday - 1],
                        style: BuType.micro.copyWith(color: on ? t.onPr : t.mut)),
                    const SizedBox(height: 3),
                    Text('${d.day}',
                        style: BuType.heading.copyWith(color: on ? t.onPr : t.ink)),
                  ],
                ),
              ),
            ))),
          );
        },
      ),
    ).withTop(12);
  }

  Widget _body(BuTokens t) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!, onRetry: _load);

    final items = _menus[_selected.day];
    final label = '${_isToday(_selected) ? 'BUGÜN · ' : ''}${_selected.day} ${trUpper(_months[_selected.month - 1])}';
    final later = _menus.keys.where((d) => d > _selected.day).toList()..sort();

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(_hPad, 16, _hPad, 24),
        children: [
          BuHeroCard(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(LucideIcons.utensils, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(label, style: BuType.label.copyWith(letterSpacing: .4)),
                  ]),
                  const SizedBox(height: 12),
                  if (items == null || items.isEmpty)
                    Text('Bu gün için yemek listesi yok.',
                        style: BuType.heading.copyWith(height: 1.5))
                  else
                    for (final m in items)
                      Text(m, style: BuType.title.copyWith(height: 1.5)),
                ],
              ),
            ),
          ),
          if (_isToday(_selected)) PollMenuCard(session: widget.session),
          if (_menus.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: EmptyView(icon: LucideIcons.utensils, text: 'Bu ay için yemek listesi henüz yayınlanmadı.'),
            )
          else ...[
            const SizedBox(height: 12),
            for (final day in later) ...[
              _dayCard(t, day, _menus[day]!),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  Widget _dayCard(BuTokens t, int day, List<String> items) {
    final d = DateTime(_month.year, _month.month, day);
    return BuCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => _select(day),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$day ${_months[d.month - 1]}, ${_daysLong[d.weekday - 1]}',
                style: BuType.label.copyWith(color: t.mut)),
            const SizedBox(height: 6),
            if (items.isEmpty)
              Text('Yemek listesi yok.', style: BuType.body.copyWith(color: t.mut))
            else
              for (final m in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 7),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(m, style: BuType.body.copyWith(height: 1.4, color: t.ink))),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

extension on Widget {
  Widget withTop(double v) => Padding(padding: EdgeInsets.only(top: v), child: this);
}
