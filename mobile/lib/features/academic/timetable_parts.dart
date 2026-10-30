import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'academic_models.dart';
import 'akad_widgets.dart';
import 'reminders.dart';

/// Ders programı sayfasının görsel parçaları (Stitch 43): dönem/aktar satırı, gün hapları, şu an/sıradaki ders kartları,
/// günlük akış satırları, "Derslerim" kartları, boş durum kartları, iskelet. Durum ve veri `timetable_page.dart`'ta kalır.

/// Dönem seçme düğmesi + .ics aktarma düğmesi (yan yana, beyaz kartlar).
class TtTopRow extends StatelessWidget {
  const TtTopRow({super.key, required this.name, required this.onPickSemester, required this.onExport});

  final String name;
  final VoidCallback onPickSemester, onExport;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    Widget box({required VoidCallback onTap, required String semantic, required Widget child}) => Semantics(
          button: true,
          label: semantic,
          excludeSemantics: true,
          onTap: onTap,
          child: AkadCard(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 28), child: child),
          ),
        );
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Flexible(
        flex: 5,
        child: box(
          onTap: onPickSemester,
          semantic: '${l.acadTimePickSemester}: $name',
          child: Row(children: [
            Icon(LucideIcons.graduationCap, size: 18, color: t.pr),
            const SizedBox(width: 8),
            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 16, color: t.mut),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        flex: 4,
        child: box(
          onTap: onExport,
          semantic: l.acadTimeExportTooltip,
          child: Row(children: [
            Icon(LucideIcons.calendarArrowUp, size: 18, color: t.pr),
            const SizedBox(width: 8),
            Expanded(
                child: Text(l.acadTimeExportTooltip, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink))),
          ]),
        ),
      ),
    ]));
  }
}

/// Gün haps şeridi (Pzt..Paz, yatay kayar): seçili gün koyu hap; bugün seçiliyken "Per, bugün" + kırmızı nokta.
class TtDayPills extends StatefulWidget {
  const TtDayPills({super.key, required this.selected, required this.todayWeekday, required this.onSelect});

  final int selected, todayWeekday; // 1..7
  final ValueChanged<int> onSelect;

  @override
  State<TtDayPills> createState() => _TtDayPillsState();
}

class _TtDayPillsState extends State<TtDayPills> {
  final _keys = List.generate(7, (_) => GlobalKey());

  @override
  void didUpdateWidget(TtDayPills old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _keys[widget.selected - 1].currentContext;
        if (c != null && c.mounted) Scrollable.ensureVisible(c, duration: BuMotion.of(c, BuMotion.medium), alignment: .5);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        for (var d = 1; d <= 7; d++) ...[
          if (d > 1) const SizedBox(width: 8),
          Builder(
            key: _keys[d - 1],
            builder: (context) {
              final sel = widget.selected == d;
              final today = widget.todayWeekday == d;
              final short = acadDayShort(l, d);
              final label = sel && today ? l.acadTimeDayToday(short) : short;
              final fg = sel ? t.bg : t.ink;
              return Semantics(
                button: true,
                selected: sel,
                label: today ? l.acadTimeDayToday(acadDayName(l, d)) : acadDayName(l, d),
                excludeSemantics: true,
                onTap: () => widget.onSelect(d),
                child: BuPressable(
                  scale: .95,
                  onTap: () => widget.onSelect(d),
                  haptic: BuHaptic.selection,
                  child: AnimatedContainer(
                    duration: BuMotion.of(context, BuMotion.short),
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(color: sel ? t.ink : t.sf, shape: StadiumBorder(side: BorderSide(color: sel ? t.ink : t.bd.withValues(alpha: .6)))),
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (sel && today) ...[Container(width: 7, height: 7, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)), const SizedBox(width: 6)],
                        Text(label, maxLines: 1, style: tx.labelLarge!.copyWith(fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: fg)),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ]),
    );
  }
}

/// "Şu an derste" kartı: pembe etiket + derslik, ders adı + kalan dk, ilerleme çubuğu.
class TtNowCard extends StatelessWidget {
  const TtNowCard({super.key, required this.name, required this.minutesLeft, required this.progress, this.room});

  final String name;
  final int minutesLeft;
  final double progress;
  final String? room;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      container: true,
      label: '${l.acadTimeNowInClass}. ${l.acadTimeMinLeft(name, minutesLeft.toString())}',
      excludeSemantics: true,
      child: AkadCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            AkadPill(l.acadTimeNowInClass, bg: t.soft, fg: t.onSoft, dot: true),
            const Spacer(),
            if (room != null) Flexible(child: Text(room!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.mut))),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
            const SizedBox(width: 8),
            Text(l.acadCountdownMinutes(minutesLeft.toString()), style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.pr)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BuRadius.bPill,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: BuMotion.of(context, BuMotion.long),
              curve: BuMotion.emphasizedDecelerate,
              builder: (c, v, _) => LinearProgressIndicator(value: v, minHeight: 6, color: t.pr, backgroundColor: t.sf2),
            ),
          ),
        ]),
      ),
    );
  }
}

/// "Sıradaki ders" kartı (ya da hafta bitti / gün tamam bilgi satırı): simge karosu + başlık + sağda hap.
class TtInfoCard extends StatelessWidget {
  const TtInfoCard({super.key, required this.icon, required this.tileBg, required this.tileFg, required this.title, this.label, this.body, this.pill});

  final IconData icon;
  final Color tileBg, tileFg;
  final String title;
  final String? label, body, pill;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      container: true,
      label: [if (label != null) label!, title, if (body != null) body!, if (pill != null) pill!].join('. '),
      excludeSemantics: true,
      child: AkadCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          AkadIconTile(icon: icon, bg: tileBg, fg: tileFg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (label != null)
                Text(akadUpper(context, label!),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, letterSpacing: l.localeName == 'ar' ? 0 : .6, color: t.mut)),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
              if (body != null) Text(body!, style: tx.bodySmall!.copyWith(color: t.mut)),
            ]),
          ),
          if (pill != null) ...[
            const SizedBox(width: 8),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 110), child: AkadPill(pill!, bg: t.sf2, fg: t.ink)),
          ],
        ]),
      ),
    );
  }
}

/// Günlük akış satırı: solda durum çubuğu, durum etiketi + saat hapı, ders adı, derslik ve hoca.
class TtSlotCard extends StatelessWidget {
  const TtSlotCard({super.key, required this.slot, required this.todayView, required this.onTap});

  final DaySlot slot;
  final bool todayView; // seçili gün bugün mü (durum etiketleri yalnız bugün)
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final s = slot;
    final c = s.course;
    final past = todayView && s.status == SlotStatus.past;
    final ongoing = todayView && s.status == SlotStatus.ongoing;
    final status = !todayView
        ? null
        : switch (s.status) {
            SlotStatus.ongoing => l.acadTimeStatusNow,
            SlotStatus.past => l.acadTimeStatusDone,
            SlotStatus.upcoming => l.p17SlotWaiting,
          };
    final bar = ongoing ? t.pr : (past ? t.bd : t.ink.withValues(alpha: .75));
    final semantic =
        '${l.acadTimeSlotSemantic(c.name, acadDayName(l, s.session.dayOfWeek.clamp(1, 7)), s.session.start, s.session.end)}${s.session.room != null ? ', ${s.session.room}' : ''}${status != null ? ', $status' : ''}';
    final timePillBg = ongoing ? t.soft : t.sf2;
    final timePillFg = ongoing ? t.onSoft : (past ? t.mut : t.ink);
    final room = s.session.room;
    final tint = courseColor(c.color);
    return Semantics(
      container: true,
      button: true,
      label: semantic,
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: past ? .62 : 1,
        child: AkadCard(
          onTap: onTap,
          padding: EdgeInsets.zero,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 5, color: bar),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      if (status != null)
                        AkadPill(status, bg: ongoing ? t.soft : t.sf2, fg: ongoing ? t.onSoft : t.mut, dot: ongoing)
                      else if (c.code != null)
                        AkadPill(c.code!, bg: akadTint(context, tint), fg: akadOnTint(context, tint)),
                      const Spacer(),
                      AkadPill('${s.session.start} - ${s.session.end}', bg: timePillBg, fg: timePillFg),
                    ]),
                    const SizedBox(height: 10),
                    Text(c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tx.titleLarge!.copyWith(
                            fontWeight: FontWeight.w800, color: past ? t.mut : t.ink, decoration: past ? TextDecoration.lineThrough : null)),
                    if (room != null || c.instructor != null) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        if (room != null)
                          Flexible(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(LucideIcons.doorOpen, size: 15, color: t.mut),
                              const SizedBox(width: 6),
                              Flexible(child: Text(l.p17RoomLabel(room), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
                            ]),
                          ),
                        if (room != null && c.instructor != null) const SizedBox(width: 12),
                        if (c.instructor != null)
                          Flexible(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(LucideIcons.user, size: 15, color: t.mut),
                              const SizedBox(width: 6),
                              Flexible(child: Text(c.instructor!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
                            ]),
                          ),
                      ]),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Derslerim" ızgara kartı: ders kodu etiketi, ad, haftalık süre.
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
    var mins = 0;
    for (final s in course.sessions) {
      final d = s.endMin - s.startMin;
      if (d > 0) mins += d;
    }
    final hours = mins / 60;
    final hoursText = hours.round().toString();
    return Semantics(
      container: true,
      button: true,
      label: l.acadTimeCourseSemantic(course.name, days),
      excludeSemantics: true,
      onTap: onTap,
      child: AkadCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (course.code != null) AkadPill(course.code!, bg: akadTint(context, color), fg: akadOnTint(context, color)) else const SizedBox(height: 24),
          const SizedBox(height: 14),
          Text(course.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
          const SizedBox(height: 2),
          Text(mins == 0 ? l.acadTimeNoSessions : l.p17HoursPerWeek(hoursText), style: tx.bodySmall!.copyWith(color: t.mut)),
        ]),
      ),
    );
  }
}

/// "Bugün N ders kaldı" alt satırı (kırmızı nokta + metin).
class TtLeftLine extends StatelessWidget {
  const TtLeftLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Flexible(child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600, color: t.mut))),
    ]);
  }
}

/// Dönem yok: büyük simge, başlık, açıklama, "Yeni dönem ekle".
class TtNoSemesterCard extends StatelessWidget {
  const TtNoSemesterCard({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return AkadCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Stack(clipBehavior: Clip.none, children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle), child: Icon(LucideIcons.calendarDays, size: 28, color: t.pr)),
            PositionedDirectional(
              top: -2,
              end: -4,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
                child: Text('!', style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w900, color: t.onPr)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Semantics(header: true, child: Text(l.p17NoSemesterTitle, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
        const SizedBox(height: 6),
        Text(l.p17NoSemesterBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
        const SizedBox(height: 20),
        BuButton(label: l.acadTimeAddSemester, icon: LucideIcons.plus, onPressed: onAdd),
      ]),
    );
  }
}

/// Ders yok: kitap simgesi, başlık, açıklama, koyu "İlk dersini ekle".
class TtNoCourseCard extends StatelessWidget {
  const TtNoCourseCard({super.key, required this.semester, required this.onAdd, required this.onPickSemester});

  final String? semester;
  final VoidCallback onAdd, onPickSemester;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return AkadCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (semester != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GestureDetector(onTap: onPickSemester, child: AkadPill(semester!, bg: t.soft, fg: t.onSoft)),
          ),
        const SizedBox(height: 18),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(20)),
            child: Icon(LucideIcons.bookOpen, size: 28, color: t.ink),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(header: true, child: Text(l.p17NoCourseTitle, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
        const SizedBox(height: 6),
        Text(l.p17NoCourseBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: t.ink, foregroundColor: t.bg, minimumSize: const Size(0, 54)),
          onPressed: onAdd,
          icon: const Icon(LucideIcons.bookPlus, size: 18),
          label: Text(l.acadTimeAddFirst),
        ),
      ]),
    );
  }
}

/// Gün boş: tarih dairesi + gün adı, içte kahve simgeli kutu.
class TtEmptyDay extends StatelessWidget {
  const TtEmptyDay({super.key, required this.dayName, required this.dayOfMonth, required this.text});

  final String dayName, text;
  final int dayOfMonth;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return AkadCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
            child: Text('$dayOfMonth', style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.onSoft)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(dayName, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
        ]),
        const SizedBox(height: 14),
        AkadEmptyBox(icon: LucideIcons.coffee, iconColor: t.pr, title: text, message: l.p17DayFreeBody),
      ]),
    );
  }
}

/// Ders programı yükleniyor iskeleti: ekranın kendi düzenine benzer (üst satır, gün haps, kartlar).
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              Expanded(child: BuSkeleton(height: 48, radius: 16)),
              SizedBox(width: 8),
              Expanded(child: BuSkeleton(height: 48, radius: 16)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              for (var i = 0; i < 5; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                const Expanded(child: BuSkeleton(height: 44, radius: 22)),
              ],
            ]),
            const SizedBox(height: 16),
            const BuSkeleton(height: 96, radius: 20),
            const SizedBox(height: 12),
            const BuSkeleton(height: 64, radius: 20),
            const SizedBox(height: 22),
            const BuSkeleton.line(width: 170, height: 20),
            const SizedBox(height: 14),
            for (var i = 0; i < 3; i++) ...[
              const BuSkeleton(height: 104, radius: 20),
              const SizedBox(height: 12),
            ],
          ]),
        ),
      ),
    );
  }
}
