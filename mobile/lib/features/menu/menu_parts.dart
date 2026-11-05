import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import '../news/news_tile.dart' show newsWeekdayName;
import 'menu_models.dart';
import 'menu_photo.dart';

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

/// Gün seçici (Stitch v3): yatay kaydırılan 7+ günlük şerit. Her gün 42 dp genişliğinde, 48 dp yüksekliğinde
/// bir hap: hafta kısaltması (12 sp/500, büyük harf, soluk) + gün numarası (16 sp/600). Seçili gün `soft`
/// zeminli hap, metni `pr` (kısaltma 600, numara 700); diğerlerinin zemini yok. Dokunma alanı 46 x 48 dp.
class MenuDayStrip extends StatefulWidget {
  const MenuDayStrip({super.key, required this.days, required this.selected, required this.onSelect});

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  State<MenuDayStrip> createState() => _MenuDayStripState();
}

class _MenuDayStripState extends State<MenuDayStrip> {
  /// Yuva genişliği = hap 42 + aralık 4.
  static const _slot = 46.0;
  static const _pill = 42.0;
  static const _hPad = 20.0;
  final _ctrl = ScrollController();
  bool _jumped = false;

  static bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _center(double w) {
    final idx = widget.days.indexWhere((d) => _same(d, widget.selected));
    if (idx < 0 || !_ctrl.hasClients) return;
    final target = _hPad + idx * _slot - (w - _slot) / 2;
    final to = target.clamp(0.0, _ctrl.position.maxScrollExtent);
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
    final w = MediaQuery.sizeOf(context).width;
    if (!_jumped) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _center(w);
      });
    }
    // Yazı ölçeği büyüdükçe hap uzar; sabit yükseklik yerine ölçekle büyür.
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return SizedBox(
      height: 48 * scale.clamp(1.0, 1.4),
      child: ListView.builder(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _hPad),
        itemCount: widget.days.length,
        itemExtent: _slot,
        itemBuilder: (context, i) {
          final d = widget.days[i];
          final sel = _same(d, widget.selected);
          final dayName = trUpper(newsWeekdayName(context, d.weekday, short: true));
          final dur = BuMotion.of(context, BuMotion.short);
          return Semantics(
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
              child: Center(
                child: AnimatedContainer(
                  duration: dur,
                  width: _pill,
                  decoration: BoxDecoration(color: sel ? t.pr : t.pr.withValues(alpha: 0), borderRadius: BorderRadius.circular(BuRadius.pill)),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Metin rengi de hapla birlikte yumuşakça değişir (150 ms).
                    AnimatedDefaultTextStyle(
                      duration: dur,
                      maxLines: 1,
                      style: BuType.caption.copyWith(fontSize: 11.5, height: 1.2, color: sel ? t.onPr : t.mut),
                      child: Text(dayName),
                    ),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: dur,
                      maxLines: 1,
                      style: BuType.caption.copyWith(
                          fontSize: 15,
                          height: 1.3,
                          color: sel ? t.onPr : t.ink,
                          fontFeatures: const [FontFeature.tabularFigures()]),
                      child: Text('${d.day}'),
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

/// "Bugün · 31 Ekim" etiketi: 14 sp, soluk, düz metin (büyük harf/simge yok).
class MenuDayLabel extends StatelessWidget {
  const MenuDayLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      header: true,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 13, height: 1.5, letterSpacing: .13, color: t.mut)),
    );
  }
}

/// Öğle yemeği yüzeyi (Stitch v3): tek beyaz yüzey (1 dp `bd`, 22 köşe, iç 20 dp). Başlık 20 sp/600 solda,
/// saat 14 sp soluk sağda; her yemek 1 dp çizgili satır (ad 16 sp, kcal 14 sp soluk; kcal yoksa "–");
/// "Toplam enerji" satırı. Yönetici fotoğraf yüklediyse kartın üstünde 16:9 fotoğraf; yoksa yer tutucu çizilmez.
class MenuMealCard extends StatelessWidget {
  const MenuMealCard({super.key, required this.day, required this.time});

  final MenuDay day;
  final String time;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.bd)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Menü fotoğrafı (yönetici yüklediyse): kartın en üstünde 16:9; yok ya da yüklenemezse hiçbir şey çizilmez.
          MenuPhotoGate(
            url: day.imageUrl,
            builder: (context, photo) => photo == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Semantics(
                      image: true,
                      label: l.menuPhotoLabel,
                      excludeSemantics: true,
                      child: ClipRRect(borderRadius: BuRadius.bSm, child: AspectRatio(aspectRatio: 16 / 9, child: photo)),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: t.okSoft, borderRadius: BorderRadius.circular(14)),
                child: Icon(BuIcons.utensils, size: 22, color: t.onOkSoft)),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.yemekLunch, style: BuType.caption.copyWith(fontSize: 17, height: 1.3, fontWeight: FontWeight.w400, color: t.ink)),
                ),
              ),
              const SizedBox(width: 12),
              Text(time, maxLines: 1, style: BuType.caption.copyWith(fontSize: 14, height: 1.4, color: t.mut)),
            ]),
          ),
          for (final d in day.dishes) _DishRow(dish: d),
          if (day.totalKcal != null) _TotalRow(total: day.totalKcal!, complete: day.kcalComplete),
        ]),
      ),
    );
  }
}

/// Yemek satırı: üstte 1 dp çizgi, dikey 14 dp; ad solda 16 sp, kcal sağda 14 sp soluk ("–" = girilmemiş).
class _DishRow extends StatelessWidget {
  const _DishRow({required this.dish});

  final MenuDish dish;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final kcal = dish.kcal;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.bd))),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
          Expanded(child: Text(menuDishTitle(dish.name), style: BuType.caption.copyWith(fontSize: 14, height: 1.43, color: t.ink))),
          const SizedBox(width: 12),
          if (kcal != null)
            Text(l.p03MenuKcal('$kcal'),
                maxLines: 1, style: BuType.caption.copyWith(fontSize: 13, height: 1.4, color: t.mut))
          else
            Semantics(
              label: l.p03MenuKcalNone,
              excludeSemantics: true,
              child: Text('–', style: BuType.caption.copyWith(fontSize: 13, height: 1.4, color: t.mut)),
            ),
      ]),
    );
  }
}

/// Günlük toplam: tamamsa "Toplam enerji  930 kcal"; eksikse "En az 550 kcal" + altında 12 sp not.
class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total, required this.complete});

  final int total;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final number = BuType.caption.copyWith(fontSize: 15, height: 1.3, fontWeight: FontWeight.w400, color: t.ink, fontFeatures: const [FontFeature.tabularFigures()]);
    return Container(
      decoration: BoxDecoration(color: t.okSoft, borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      child: Semantics(
          container: true,
          label: complete ? '${l.p03MenuTotalEnergy} ${l.p03MenuKcal('$total')}' : '${l.p03MenuTotalEnergy} ${l.p03MenuAtLeast('$total')}',
          excludeSemantics: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(child: Text(l.p03MenuTotalEnergy, style: BuType.caption.copyWith(fontSize: 14, height: 1.43, fontWeight: BuType.emphasisWeight, color: t.ink))),
                  const SizedBox(width: 12),
                  if (complete)
                    // Toplam kalori gün değişince 0'dan sayarak oturur (animasyonları azalt açıkken anında).
                    BuCountUp(key: ValueKey('menu-total-$total'), value: total, format: (v) => l.p03MenuKcal('$v'), style: number)
                  else
                    Flexible(child: Text(l.p03MenuAtLeast('$total'), textAlign: TextAlign.end, style: number)),
                ]),
            if (!complete)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l.p03MenuKcalMissing, style: BuType.caption.copyWith(fontSize: 12, height: 1.4, color: t.mut)),
              ),
          ]),
      ),
    );
  }
}

/// Bayat liste bandı (Stitch v3): `warnSoft` zemin, 1 dp ince amber çerçeve, 16 köşe, 13 sp `onWarnSoft` metin.
class MenuStaleBanner extends StatelessWidget {
  const MenuStaleBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.warnSoft, borderRadius: BuRadius.bMd, border: Border.all(color: t.warn.withValues(alpha: .25))),
        child: Text(text, style: BuType.caption.copyWith(fontSize: 13, height: 1.4, color: t.onWarnSoft)),
      ),
    );
  }
}

/// Liste yok: ortada soluk tek cümle (16 sp); bakımdaysa altında 14 sp "Sistem bakımda." Simge/kart yok.
class MenuEmptyCard extends StatelessWidget {
  const MenuEmptyCard({super.key, required this.maintenance});

  final bool maintenance;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Column(children: [
        Semantics(
          header: true,
          child: Text(l.p03MenuNoList, textAlign: TextAlign.center, style: BuType.caption.copyWith(fontSize: 16, height: 1.5, color: t.mut)),
        ),
        if (maintenance) ...[
          const SizedBox(height: 4),
          Text(l.p03MenuMaintenance, textAlign: TextAlign.center, style: BuType.caption.copyWith(fontSize: 14, height: 1.4, color: t.mut)),
        ],
      ]),
    );
  }
}

/// Yükleniyor iskeleti: gün şeridi + yemek yüzeyi.
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (strip) ...[
                Row(children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    const Expanded(child: BuSkeleton(height: 48, radius: BuRadius.pill)),
                  ],
                ]),
                const SizedBox(height: 16),
              ],
              const BuSkeleton(width: 120, height: 14),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bMd, border: Border.all(color: t.bd)),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton(width: 160, height: 22),
                    SizedBox(height: 24),
                    BuSkeleton(height: 18, radius: BuRadius.xs),
                    SizedBox(height: 30),
                    BuSkeleton(height: 18, radius: BuRadius.xs),
                    SizedBox(height: 30),
                    BuSkeleton(height: 18, radius: BuRadius.xs),
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
