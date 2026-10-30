import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import '../news/news_tile.dart' show newsWeekdayName;
import 'menu_models.dart';

/// Yönetici girdisi hep BÜYÜK harfle gelebilir ("MERCİMEK ÇORBASI"); tümü büyükse Türkçe kurallarıyla
/// "Mercimek Çorbası" biçimine çevrilir, karışık harfli adlara dokunulmaz.
String menuDishTitle(String s) {
  final hasLower = s.runes.any((r) {
    final c = String.fromCharCode(r);
    return c != c.toUpperCase() && c == c.toLowerCase();
  });
  if (hasLower || s.isEmpty) return s;
  String lower(String c) => switch (c) {
        'İ' => 'i',
        'I' => 'ı',
        _ => c.toLowerCase(),
      };
  String upper(String c) => switch (c) {
        'i' => 'İ',
        'ı' => 'I',
        _ => c.toUpperCase(),
      };
  final out = StringBuffer();
  var start = true;
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final isLetter = c.toLowerCase() != c.toUpperCase();
    if (!isLetter) {
      out.write(c);
      start = true;
    } else {
      out.write(start ? upper(lower(c)) : lower(c));
      start = false;
    }
  }
  // Bağlaçlar küçük kalır: "Orman Kebabı ve Pirinç Pilavı".
  return out.toString().replaceAll(' Ve ', ' ve ').replaceAll(' İle ', ' ile ');
}

/// Gün seçici: kaydırılabilir kısa gün kartları (hafta günü kısaltması + gün numarası).
class MenuDayStrip extends StatefulWidget {
  const MenuDayStrip({super.key, required this.days, required this.selected, required this.onSelect});

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  State<MenuDayStrip> createState() => _MenuDayStripState();
}

class _MenuDayStripState extends State<MenuDayStrip> {
  static const _gap = 8.0;
  static const _hPad = 20.0;
  final _ctrl = ScrollController();
  bool _jumped = false;

  static bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  double _itemWidth(double w) => ((w - 2 * _hPad - 4 * _gap) / 5).clamp(52.0, 120.0);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _center(double w) {
    final idx = widget.days.indexWhere((d) => _same(d, widget.selected));
    if (idx < 0 || !_ctrl.hasClients) return;
    final iw = _itemWidth(w);
    final target = _hPad + idx * (iw + _gap) - (w - iw) / 2;
    final max = _ctrl.position.maxScrollExtent;
    final to = target.clamp(0.0, max);
    if (!_jumped) {
      _ctrl.jumpTo(to);
      _jumped = true;
    } else {
      _ctrl.animateTo(to, duration: BuMotion.of(context, BuMotion.medium), curve: BuMotion.emphasized);
    }
  }

  @override
  void didUpdateWidget(MenuDayStrip old) {
    super.didUpdateWidget(old);
    if (!_same(old.selected, widget.selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _center(MediaQuery.sizeOf(context).width);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final iw = _itemWidth(w);
    final now = DateTime.now();
    if (!_jumped) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _center(w);
      });
    }
    // Yazı ölçeği büyüdükçe kutu uzar; sabit yükseklik yerine ölçekle büyür.
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return SizedBox(
      height: 72 * scale.clamp(1.0, 1.4),
      child: ListView.separated(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _hPad),
        itemCount: widget.days.length,
        separatorBuilder: (_, __) => const SizedBox(width: _gap),
        itemBuilder: (context, i) {
          final d = widget.days[i];
          final sel = _same(d, widget.selected);
          final today = _same(d, now);
          final dayName = trUpper(newsWeekdayName(context, d.weekday, short: true));
          return SizedBox(
            width: iw,
            child: Semantics(
              button: true,
              selected: sel,
              label: '${newsWeekdayName(context, d.weekday)} ${d.day}',
              excludeSemantics: true,
              child: BuPressable(
                key: ValueKey('yemek_day_${d.year}-${d.month}-${d.day}'),
                onTap: () => widget.onSelect(d),
                child: AnimatedContainer(
                  duration: BuMotion.of(context, BuMotion.short),
                  decoration: BoxDecoration(
                    color: sel ? t.soft : t.sf,
                    borderRadius: BorderRadius.circular(BuRadius.md),
                    border: Border.all(color: sel ? t.pr.withValues(alpha: .25) : t.bd),
                  ),
                  alignment: Alignment.center,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(dayName,
                        maxLines: 1,
                        style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: sel ? t.onSoft : t.mut)),
                    const SizedBox(height: 2),
                    Text('${d.day}',
                        maxLines: 1,
                        style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, height: 1.15, color: sel ? t.onSoft : t.ink)),
                    SizedBox(
                      height: 8,
                      child: today ? Center(child: Container(width: 5, height: 5, decoration: BoxDecoration(color: sel ? t.onSoft : t.pr, shape: BoxShape.circle))) : null,
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "BUGÜN · 29 EKİM" etiketi (bugünse takvim simgesi, değilse kırmızı nokta).
class MenuDayLabel extends StatelessWidget {
  const MenuDayLabel({super.key, required this.text, required this.today});

  final String text;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Row(children: [
      today
          ? Icon(LucideIcons.calendar, size: 16, color: t.pr)
          : Container(width: 8, height: 8, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(
        child: Semantics(
          header: true,
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink, letterSpacing: .3)),
        ),
      ),
    ]);
  }
}

/// Öğle yemeği kartı: başlık, fotoğraf (ya da sade yer tutucu), yemek + kalori satırları, toplam.
class MenuMealCard extends StatelessWidget {
  const MenuMealCard({super.key, required this.day, required this.photo, required this.time});

  final MenuDay day;

  /// Hazır fotoğraf katmanı; yoksa ya da bozuksa null (yer tutucu çizilir).
  final Widget? photo;
  final String time;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final hasPhoto = photo != null;
    final timeRow = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.clock, size: 14, color: hasPhoto ? t.onMedia : t.mut),
      const SizedBox(width: 6),
      Text(time, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: hasPhoto ? t.onMedia : t.mut)),
    ]);
    return BuCard(
      radius: 20,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, hasPhoto ? 12 : 4),
            child: Semantics(
              header: true,
              child: Text(l.yemekLunch, style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
            ),
          ),
          if (hasPhoto)
            Semantics(
              image: true,
              label: l.menuPhotoLabel,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(fit: StackFit.expand, children: [
                  photo!,
                  PositionedDirectional(
                    start: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: t.scrim.withValues(alpha: .62), borderRadius: BorderRadius.circular(BuRadius.pill)),
                      child: timeRow,
                    ),
                  ),
                ]),
              ),
            )
          else ...[
            Padding(padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12), child: Align(alignment: AlignmentDirectional.centerStart, child: timeRow)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ExcludeSemantics(
                child: Container(
                  height: 116,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(BuRadius.md),
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [t.sf2, t.soft.withValues(alpha: .55)]),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.md)),
                    child: Icon(LucideIcons.utensils, size: 28, color: t.pr),
                  ),
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < day.dishes.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _DishRow(dish: day.dishes[i]),
              ],
              if (day.totalKcal != null) ...[
                const SizedBox(height: 16),
                _TotalRow(total: day.totalKcal!, complete: day.kcalComplete),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({required this.dish});

  final MenuDish dish;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final kcal = dish.kcal;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm)),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Text(menuDishTitle(dish.name), style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w600, height: 1.3, color: t.ink))),
        const SizedBox(width: 10),
        if (kcal != null)
          Text(l.p03MenuKcal('$kcal'), maxLines: 1, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink))
        else
          Semantics(
            label: l.p03MenuKcalNone,
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: t.bd.withValues(alpha: .7), borderRadius: BorderRadius.circular(BuRadius.xs)),
              child: Text('-', style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.mut)),
            ),
          ),
      ]),
    );
  }
}

/// Günlük toplam: tamamsa koyu şerit, eksikse "En az N kcal" + uyarı notu.
class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total, required this.complete});

  final int total;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    if (complete) {
      return Semantics(
        container: true,
        label: '${l.p03MenuTotal} ${l.p03MenuKcal('$total')}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(BuRadius.md)),
          child: Row(children: [
            Icon(LucideIcons.flame, size: 18, color: t.bg),
            const SizedBox(width: 10),
            Expanded(child: Text(l.p03MenuTotal, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.bg))),
            Text(l.p03MenuKcal('$total'), maxLines: 1, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.soft)),
          ]),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Text(l.p03MenuTotalEnergy, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink))),
          const SizedBox(width: 8),
          Flexible(child: Text(l.p03MenuAtLeast('$total'), textAlign: TextAlign.end, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.pr))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(LucideIcons.info, size: 14, color: t.mut),
          const SizedBox(width: 6),
          Expanded(child: Text(l.p03MenuKcalMissing, style: tx.bodySmall!.copyWith(color: t.mut))),
        ]),
      ]),
    );
  }
}

/// Liste yok / bakım kartı.
class MenuEmptyCard extends StatelessWidget {
  const MenuEmptyCard({super.key, required this.maintenance, required this.onRetry});

  final bool maintenance;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return BuCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: SizedBox(
        width: double.infinity,
        child: Column(children: [
          ExcludeSemantics(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
              child: Icon(LucideIcons.utensils, size: 38, color: t.onSoft),
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(l.p03MenuNoList, textAlign: TextAlign.center, style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
          ),
          if (maintenance) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: t.warnSoft, borderRadius: BorderRadius.circular(BuRadius.pill)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: t.warn, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Flexible(child: Text(l.p03MenuMaintenance, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.onWarnSoft))),
              ]),
            ),
            const SizedBox(height: 20),
            BuButton(label: l.commonRetry, icon: LucideIcons.refreshCw, onPressed: onRetry),
          ],
        ]),
      ),
    );
  }
}

/// Yükleniyor iskeleti: gün seçici + öğle kartı.
class MenuSkeleton extends StatelessWidget {
  const MenuSkeleton({super.key, this.strip = true});

  /// Gün seçici iskeleti de çizilsin mi (seçici zaten ekrandaysa false).
  final bool strip;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: BuSkeletonScope(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              if (strip) ...[
                Row(children: [
                  for (var i = 0; i < 5; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    const Expanded(child: BuSkeleton(height: 72, radius: BuRadius.md)),
                  ],
                ]),
                const SizedBox(height: 20),
              ],
              const BuSkeleton(width: 140, height: 14),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.bd)),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton(width: 160, height: 22),
                    SizedBox(height: 14),
                    BuSkeleton(height: 170, radius: BuRadius.sm),
                    SizedBox(height: 16),
                    BuSkeleton(height: 44, radius: BuRadius.sm),
                    SizedBox(height: 8),
                    BuSkeleton(height: 44, radius: BuRadius.sm),
                    SizedBox(height: 8),
                    BuSkeleton(height: 44, radius: BuRadius.sm),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
