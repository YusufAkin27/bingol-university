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
                onTap: () {
                  if (!sel) buHaptic(BuHaptic.selection);
                  widget.onSelect(d);
                },
                child: AnimatedContainer(
                  duration: BuMotion.of(context, BuMotion.short),
                  decoration: BoxDecoration(
                    color: sel ? t.soft : t.sf,
                    borderRadius: BorderRadius.circular(BuRadius.md),
                    border: Border.all(color: sel ? t.pr.withValues(alpha: .25) : t.bd),
                  ),
                  alignment: Alignment.center,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Metin rengi de kapsül rengiyle birlikte yumuşakça değişir (150 ms).
                    AnimatedDefaultTextStyle(
                      duration: BuMotion.of(context, BuMotion.short),
                      maxLines: 1,
                      style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: sel ? t.onSoft : t.mut),
                      child: Text(dayName),
                    ),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: BuMotion.of(context, BuMotion.short),
                      maxLines: 1,
                      style: tx.titleLarge!.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: sel ? t.onSoft : t.ink,
                          fontFeatures: const [FontFeature.tabularFigures()]),
                      child: Text('${d.day}'),
                    ),
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

/// "BUGÜN · 29 EKİM" etiketi: yalnız metin (simge/nokta yok), sakin başlık tonu.
class MenuDayLabel extends StatelessWidget {
  const MenuDayLabel({super.key, required this.text, required this.today});

  final String text;

  /// Bugünse etiket ana yazı renginde, değilse soluk (tek vurgu: gün şeridindeki seçili kapsül).
  final bool today;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: today ? t.ink : t.mut, letterSpacing: .3)),
    );
  }
}

/// Öğle yemeği kartı: başlık + saat, (varsa) fotoğraf, yemek adı + kalori satırları, günlük toplam.
/// Fotoğrafsız günde süs yer tutucusu çizilmez; kalorisiz yemekte kalori yazılmaz.
class MenuMealCard extends StatelessWidget {
  const MenuMealCard({super.key, required this.day, required this.photo, required this.time});

  final MenuDay day;

  /// Hazır fotoğraf katmanı; yoksa ya da bozuksa null (kart yalnız metin olur).
  final Widget? photo;
  final String time;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final hasPhoto = photo != null;
    return BuCard(
      radius: BuRadius.lg,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BuRadius.lg - 1),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, hasPhoto ? 12 : 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.yemekLunch, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                ),
              ),
              const SizedBox(width: 12),
              Text(time,
                  maxLines: 1,
                  style: tx.labelLarge!.copyWith(
                      fontWeight: FontWeight.w600, color: t.mut, fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
          ),
          if (hasPhoto)
            Semantics(
              image: true,
              label: l.menuPhotoLabel,
              child: AspectRatio(aspectRatio: 16 / 9, child: photo!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final d in day.dishes) _DishRow(dish: d),
              if (day.totalKcal != null) ...[
                const SizedBox(height: 8),
                Divider(height: 1, thickness: 1, color: t.bd),
                const SizedBox(height: 12),
                _TotalRow(total: day.totalKcal!, complete: day.kcalComplete),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Yemek satırı: ad solda, (varsa) kalori sağda soluk ve tabular. Kalorisiz yemekte sağ taraf boştur.
class _DishRow extends StatelessWidget {
  const _DishRow({required this.dish});

  final MenuDish dish;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final kcal = dish.kcal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(child: Text(menuDishTitle(dish.name), style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w600, height: 1.3, color: t.ink))),
        if (kcal != null) ...[
          const SizedBox(width: 12),
          Text(l.p03MenuKcal('$kcal'),
              maxLines: 1,
              style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w600, color: t.mut, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ]),
    );
  }
}

/// Günlük toplam: tamamsa "Toplam  N kcal", eksikse "Toplam enerji  En az N kcal". Aynı sakin satır, renk yok.
class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total, required this.complete});

  final int total;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final number = tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink, fontFeatures: const [FontFeature.tabularFigures()]);
    return Semantics(
      container: true,
      label: complete ? '${l.p03MenuTotal} ${l.p03MenuKcal('$total')}' : '${l.p03MenuTotalEnergy} ${l.p03MenuAtLeast('$total')}',
      excludeSemantics: true,
      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(child: Text(complete ? l.p03MenuTotal : l.p03MenuTotalEnergy, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w600, color: t.mut))),
        const SizedBox(width: 12),
        if (complete)
          // Toplam kalori gün değişince 0'dan sayarak oturur (animasyonları azalt açıkken anında).
          BuCountUp(key: ValueKey('menu-total-$total'), value: total, format: (v) => l.p03MenuKcal('$v'), style: number)
        else
          Flexible(child: Text(l.p03MenuAtLeast('$total'), textAlign: TextAlign.end, style: number)),
      ]),
    );
  }
}

/// Liste yok / bakım: tek cümle (+ bakımdaysa tek eylem), kart ve süs yok.
class MenuEmptyCard extends StatelessWidget {
  const MenuEmptyCard({super.key, required this.maintenance, required this.onRetry});

  final bool maintenance;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        ExcludeSemantics(child: Icon(LucideIcons.utensils, size: 32, color: t.mut)),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(maintenance ? l.p03MenuMaintenance : l.p03MenuNoList,
              textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
        ),
        if (maintenance) ...[
          const SizedBox(height: 16),
          BuButton(label: l.commonRetry, compact: true, onPressed: onRetry),
        ],
      ]),
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
                const SizedBox(height: 24),
              ],
              const BuSkeleton(width: 140, height: 14),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bLg, border: Border.all(color: t.bd)),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton(width: 160, height: 22),
                    SizedBox(height: 16),
                    BuSkeleton(height: 170, radius: BuRadius.sm),
                    SizedBox(height: 16),
                    BuSkeleton(height: 20, radius: BuRadius.xs),
                    SizedBox(height: 16),
                    BuSkeleton(height: 20, radius: BuRadius.xs),
                    SizedBox(height: 16),
                    BuSkeleton(height: 20, radius: BuRadius.xs),
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
