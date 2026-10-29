import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import 'reminders.dart';

/// Ders programı sayfasının görsel parçaları (Paket 17): dönem çubuğu, sıradaki ders kartı, gün şeridi,
/// zaman çizelgesi satırı, ders kartı, iskelet. Durum ve veri `timetable_page.dart`'ta kalır.

/// Dönem seçme düğmesi (hap) + hafta sayacı + dönem ilerleme çubuğu.
class TtSemesterBar extends StatelessWidget {
  const TtSemesterBar({super.key, required this.name, required this.onTap, this.week, this.weeks, this.progress});

  final String name;
  final VoidCallback onTap;

  /// Dönemin kaçıncı haftası / toplam hafta (dönem tarihleri yoksa null).
  final int? week, weeks;

  /// 0..1 dönem ilerlemesi.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final hasWeek = week != null && weeks != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Flexible(
          child: Semantics(
            button: true,
            label: l.acadTimePickSemester,
            value: name,
            excludeSemantics: true,
            onTap: onTap,
            child: BuPressable(
              scale: .97,
              child: Material(
                color: t.sf,
                shape: StadiumBorder(side: BorderSide(color: t.bd)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () {
                    buHaptic(BuHaptic.selection);
                    onTap();
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.calendarRange, size: 16, color: t.pr),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                        ),
                        const SizedBox(width: 6),
                        Icon(LucideIcons.chevronDown, size: 16, color: t.mut),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasWeek) ...[
          const SizedBox(width: 12),
          Text(l.p17WeekOf('$week', '$weeks'), style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
        ],
      ]),
      if (progress != null) ...[
        const SizedBox(height: 10),
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BuRadius.bPill,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress!.clamp(0.0, 1.0)),
              duration: BuMotion.of(context, BuMotion.long),
              curve: BuMotion.emphasizedDecelerate,
              builder: (c, v, _) => LinearProgressIndicator(value: v, minHeight: 4, color: t.pr, backgroundColor: t.sf2),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Şu an derste / sıradaki ders özeti: ders renginde ton, süren derste ilerleme çubuğu.
class TtNextCard extends StatelessWidget {
  const TtNextCard({super.key, required this.head, required this.line, this.accent, this.progress, this.icon = LucideIcons.clock});

  final String head, line;
  final Color? accent;

  /// Süren dersin ilerlemesi (0..1); null: çubuk yok.
  final double? progress;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final base = accent;
    final bg = base == null ? t.sf2 : akadTint(context, base);
    final fg = base == null ? t.mut : akadOnTint(context, base);
    return Semantics(
      container: true,
      label: '$head. $line',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bLg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: base ?? t.mut, borderRadius: BuRadius.bSm),
                child: Icon(icon, size: 20, color: t.onMedia),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(head, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: fg)),
                  const SizedBox(height: 2),
                  Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink)),
                ]),
              ),
            ]),
            if (progress != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BuRadius.bPill,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress!.clamp(0.0, 1.0)),
                  duration: BuMotion.of(context, BuMotion.long),
                  curve: BuMotion.emphasizedDecelerate,
                  builder: (c, v, _) => LinearProgressIndicator(value: v, minHeight: 5, color: base ?? t.pr, backgroundColor: t.sf.withValues(alpha: .7)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Hafta gün şeridi (Pzt..Paz): seçili gün marka tonunda, bugün halkalı, dersi olan günde nokta.
class TtDayStrip extends StatelessWidget {
  const TtDayStrip({super.key, required this.selected, required this.todayWeekday, required this.dates, required this.hasClass, required this.onSelect});

  final int selected, todayWeekday; // 1..7
  final List<DateTime> dates; // 7 gün
  final List<bool> hasClass;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var d = 1; d <= 7; d++) ...[
          if (d > 1) const SizedBox(width: 6),
          Expanded(
            child: _DayCell(
              day: d,
              date: dates[d - 1],
              selected: selected == d,
              today: todayWeekday == d,
              dot: hasClass[d - 1],
              onTap: () {
                if (selected != d) onSelect(d);
              },
            ),
          ),
        ],
      ]);
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.date, required this.selected, required this.today, required this.dot, required this.onTap});

  final int day;
  final DateTime date;
  final bool selected, today, dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final name = acadDayName(l, day);
    final fg = selected ? t.onSoft : (today ? t.pr : t.ink);
    return Semantics(
      button: true,
      selected: selected,
      label: '${today ? l.acadTimeDayToday(name) : name} ${date.day}',
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        scale: .94,
        child: AnimatedContainer(
          duration: BuMotion.of(context, BuMotion.short),
          curve: BuMotion.standard,
          decoration: ShapeDecoration(
            color: selected ? t.soft : t.sf,
            shape: RoundedRectangleBorder(
              borderRadius: BuRadius.bMd,
              side: BorderSide(color: selected ? t.pr.withValues(alpha: .55) : (today ? t.pr.withValues(alpha: .4) : t.bd), width: selected || today ? 1.5 : 1),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BuRadius.bMd,
              excludeFromSemantics: true,
              onTap: () {
                buHaptic(BuHaptic.selection);
                onTap();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 68),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.25,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(acadDayShort(l, day), style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: selected ? t.onSoft : t.mut)),
                    ),
                    const SizedBox(height: 2),
                    Text('${date.day}', style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: fg)),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: BuMotion.of(context, BuMotion.short),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: dot ? (selected ? t.pr : t.mut) : Colors.transparent),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zaman çizelgesi satırı: saat sütunu + dikey ray (renkli düğüm) + ders kartı.
class TtSlotRow extends StatelessWidget {
  const TtSlotRow({super.key, required this.slot, required this.first, required this.last, required this.onTap});

  final DaySlot slot;
  final bool first, last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final s = slot;
    final c = s.course;
    final color = courseColor(c.color);
    final onTint = akadOnTint(context, color);
    final past = s.status == SlotStatus.past;
    final ongoing = s.status == SlotStatus.ongoing;
    final status = switch (s.status) {
      SlotStatus.ongoing => l.acadTimeStatusNow,
      SlotStatus.past => l.acadTimeStatusDone,
      SlotStatus.upcoming => null,
    };
    final semantic =
        '${l.acadTimeSlotSemantic(c.name, acadDayName(l, s.session.dayOfWeek.clamp(1, 7)), s.session.start, s.session.end)}${s.session.room != null ? ', ${s.session.room}' : ''}${status != null ? ', $status' : ''}';
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(s.session.start, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: past ? t.mut : t.ink)),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(s.session.end, style: tx.labelMedium!.copyWith(color: t.mut)),
                ),
              ]),
            ),
          ),
          SizedBox(
            width: 22,
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _RailPainter(
                  color: past ? color.withValues(alpha: .45) : color,
                  line: t.bd,
                  first: first,
                  last: last,
                  ring: ongoing,
                ),
              ),
            ),
          ),
          Expanded(
            child: ColorCard(
              color: color,
              muted: past,
              onTap: onTap,
              semanticLabel: semantic,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: past ? t.mut : t.ink)),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: 8),
                    AkadPill(status, bg: ongoing ? t.ok : t.sf, fg: ongoing ? t.onPr : t.mut),
                  ],
                ]),
                if (s.session.room != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      ExcludeSemantics(child: Icon(LucideIcons.mapPin, size: 14, color: past ? t.mut : onTint)),
                      const SizedBox(width: 6),
                      Expanded(
                          child:
                              Text(s.session.room!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(color: past ? t.mut : t.ink))),
                    ]),
                  ),
                if (c.code != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(c.code!, style: tx.bodySmall!.copyWith(color: t.mut))),
                if (c.instructor != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(c.instructor!, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({required this.color, required this.line, required this.first, required this.last, required this.ring});

  final Color color, line;
  final bool first, last, ring;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    const dotY = 22.0;
    final p = Paint()
      ..color = line
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (!first) canvas.drawLine(Offset(x, 0), Offset(x, dotY - 8), p);
    if (!last) canvas.drawLine(Offset(x, dotY + 8), Offset(x, size.height + 12), p);
    if (ring) canvas.drawCircle(Offset(x, dotY), 9, Paint()..color = color.withValues(alpha: .25));
    canvas.drawCircle(Offset(x, dotY), 5.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RailPainter old) => old.color != color || old.line != line || old.first != first || old.last != last || old.ring != ring;
}

/// "Derslerim" listesindeki ders kartı: renkli baş harf karosu, ad, hoca ve gün/saat özeti.
class TtCourseTile extends StatelessWidget {
  const TtCourseTile({super.key, required this.course, required this.days, required this.onTap});

  final Course course;
  final String days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final color = courseColor(course.color);
    final initials = _initials(course.code ?? course.name);
    return Semantics(
      container: true,
      button: true,
      label: l.acadTimeCourseSemantic(course.name, days),
      excludeSemantics: true,
      child: AkadCard(
        shadow: false,
        onTap: onTap,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: akadTint(context, color), borderRadius: BuRadius.bSm),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: Text(initials, maxLines: 1, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: akadOnTint(context, color))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(course.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              if (course.instructor != null) MetaLine(LucideIcons.user, course.instructor!),
              MetaLine(LucideIcons.clock, days.isEmpty ? l.acadTimeNoSessions : days),
            ]),
          ),
          Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut),
        ]),
      ),
    );
  }

  static String _initials(String s) {
    final cleaned = s.trim();
    if (cleaned.isEmpty) return '?';
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length == 1) return String.fromCharCodes(words.first.runes.take(3)).toUpperCase();
    return '${String.fromCharCodes(words[0].runes.take(1))}${String.fromCharCodes(words[1].runes.take(1))}'.toUpperCase();
  }
}

/// Gün boş: kahve simgeli sakin kart.
class TtEmptyDay extends StatelessWidget {
  const TtEmptyDay({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bLg),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bSm),
            child: Icon(LucideIcons.coffee, size: 20, color: t.mut),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut))),
        ]),
      ),
    );
  }
}

/// Ders programı yükleniyor iskeleti: ekranın kendi düzenine benzer (dönem, kart, gün şeridi, satırlar).
class TtSkeleton extends StatelessWidget {
  const TtSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      label: l.commonLoading,
      liveRegion: true,
      container: true,
      child: BuSkeletonScope(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(alignment: AlignmentDirectional.centerStart, child: BuSkeleton(width: 190, height: 48, radius: 24)),
            const SizedBox(height: 14),
            const BuSkeleton(height: 68, radius: 20),
            const SizedBox(height: 14),
            Row(children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                const Expanded(child: BuSkeleton(height: 68, radius: 16)),
              ],
            ]),
            const SizedBox(height: 22),
            const BuSkeleton.line(width: 170, height: 20),
            const SizedBox(height: 16),
            for (var i = 0; i < 3; i++) ...[
              const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [BuSkeleton.line(width: 40, height: 14), SizedBox(height: 6), BuSkeleton.line(width: 40, height: 12)]),
                SizedBox(width: 30),
                Expanded(child: BuSkeleton(height: 104, radius: 20)),
              ]),
              const SizedBox(height: 12),
            ],
          ]),
        ),
      ),
    );
  }
}
