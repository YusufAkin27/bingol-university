import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'acad_ref_widgets.dart';
import 'academic_models.dart';
import 'reminders.dart';

/// Ders programı sayfasının görsel parçaları (Stitch v3 02): üst satır (hafta + dönem + "+"), gün şeridi, kartsız
/// zaman çizelgesi satırları, "Şimdi" çizgisi, özet satırı, boş durum, iskelet. Durum/veri `timetable_page.dart`'ta.

/// ".ics" gibi LTR parçayı RTL metin içinde ters dönmeyecek biçimde sarar (Unicode isolate).
String isolateIcs(String s) => s.replaceAll('(.ics)', '\u2066(.ics)\u2069');

/// Toplam süre metni: tam saatse "7 saat", değilse "5 saat 15 dk"; bir saatten kısaysa "45 dk".
String ttHoursText(BuildContext context, int minutes) {
  final l = context.l10n;
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return l.acadTimeMinutes(m.toString());
  if (m == 0) return l.p69Hours(h.toString());
  return '${l.p69Hours(h.toString())} ${l.acadTimeMinutes(m.toString())}';
}

/// Üst satır: solda "Haftalık akış · 5. hafta", sağda dönem hapı (beyaz, 32 dp) ve `soft` daire "+" (30 dp).
/// Hap/artı 48 dp dokunma alanlıdır.
class TtTopRow extends StatelessWidget {
  const TtTopRow({super.key, required this.semester, required this.week, required this.onPickSemester, required this.onAdd});

  final String semester;
  final int? week;
  final VoidCallback onPickSemester, onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final left = Text.rich(
      TextSpan(children: [
        TextSpan(text: l.p69WeeklyFlow, style: tx.bodySmall!.copyWith(fontWeight: FontWeight.w500, color: t.mut)),
        if (week != null) ...[
          TextSpan(text: '  •  ', style: tx.bodySmall!.copyWith(color: t.mut)),
          TextSpan(text: l.p69WeekN(week.toString()), style: tx.bodySmall!.copyWith(fontWeight: FontWeight.w600, color: t.pr)),
        ],
      ]),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    // 48 dp dokunma kutuları üste hizalı: görünür hap/artı Stitch'teki yüksekliklere (y 62-94) oturur.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 11, 0),
      child: SizedBox(
        height: BuSize.touch,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 13), child: left)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .5),
            child: Semantics(
              button: true,
              label: '${l.acadTimePickSemester}: $semester',
              excludeSemantics: true,
              onTap: onPickSemester,
              child: BuPressable(
                onTap: onPickSemester,
                haptic: BuHaptic.selection,
                scale: .97,
                child: SizedBox(
                  height: BuSize.touch,
                  child: Align(
                    alignment: AlignmentDirectional.topCenter,
                    widthFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bPill, border: Border.all(color: t.bd)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(child: Text(semester, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.ink))),
                          const SizedBox(width: 6),
                          ExcludeSemantics(child: Icon(LucideIcons.chevronDown, size: 16, color: t.ink)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: l.acadTimeAddCourse,
            excludeSemantics: true,
            onTap: onAdd,
            child: Tooltip(
              message: l.acadTimeAddCourse,
              excludeFromSemantics: true,
              child: BuPressable(
                onTap: onAdd,
                haptic: BuHaptic.selection,
                scale: .94,
                child: SizedBox(
                  width: BuSize.touch,
                  height: BuSize.touch,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(width: 30, height: 30, decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle), child: Icon(Icons.add, size: 22, color: t.pr)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Gün şeridi: hafta içi 5 gün (Cmt/Paz yalnız dersi varsa ya da seçiliyse) eşit sütunlar; her hücrede gün adı +
/// tarih; seçili = `soft` yuvarlak dikdörtgen + `pr` metin, bugünün altında `pr` nokta. Altta tam genişlik ayraç.
class TtDayStrip extends StatelessWidget {
  const TtDayStrip({super.key, required this.selected, required this.todayWeekday, required this.dates, required this.days, required this.onSelect});

  final int selected, todayWeekday; // 1..7
  final List<int> days; // gösterilecek gün numaraları (1..7)
  final Map<int, DateTime> dates; // gün numarası -> o haftanın tarihi
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: [
        for (final d in days)
          Expanded(
            child: Builder(builder: (context) {
              final sel = selected == d;
              final today = todayWeekday == d;
              final date = dates[d];
              return Semantics(
                button: true,
                selected: sel,
                label: '${today ? l.acadTimeDayToday(acadDayName(l, d)) : acadDayName(l, d)}${date == null ? '' : ' ${date.day}'}',
                excludeSemantics: true,
                onTap: () => onSelect(d),
                child: BuPressable(
                  scale: .96,
                  onTap: () => onSelect(d),
                  haptic: BuHaptic.selection,
                  child: Center(
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.2,
                      child: AnimatedContainer(
                        duration: BuMotion.of(context, BuMotion.short),
                        curve: BuMotion.standard,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: BuSize.touch),
                        padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
                        decoration: BoxDecoration(color: sel ? t.soft : Colors.transparent, borderRadius: BorderRadius.circular(24)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(acadDayShort(l, d), maxLines: 1, style: tx.labelMedium!.copyWith(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w500, color: sel ? t.pr : t.mut)),
                          const SizedBox(height: 2),
                          Text(date == null ? '' : '${date.day}', maxLines: 1, style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w700, color: sel ? t.pr : t.ink)),
                          const SizedBox(height: 3),
                          SizedBox(height: 5, child: today ? const AcadDot(size: 5) : null),
                        ]),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
      ]),
    );
  }
}

/// Zaman çizelgesi satırı (kartsız): solda başlangıç/bitiş saati, 3 dp dikey çubuk (süren ders `pr`), ders adı
/// 17 sp/600 + sağda durum metni, muted "kod · derslik", varsa öğretim üyesi. Altta (satır içi) ayraç ayrı çizilir.
class TtSlotCard extends StatelessWidget {
  const TtSlotCard({super.key, required this.slot, required this.todayView, required this.onTap, this.trailing});

  final DaySlot slot;
  final bool todayView; // seçili gün bugün mü (durum yalnız bugün)
  final VoidCallback onTap;

  /// Sağdaki durum metni ("Tamamlandı", "25 dk kaldı", "1 sa 45 dk sonra", "Son oturum"); null = yok.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final s = slot;
    final c = s.course;
    final past = todayView && s.status == SlotStatus.past;
    final ongoing = todayView && s.status == SlotStatus.ongoing;
    final room = s.session.room;
    final sub = [if (c.code != null) c.code!, if (room != null) l.p17RoomLabel(room)].join(' · ');
    final status = !todayView
        ? null
        : switch (s.status) {
            SlotStatus.ongoing => l.acadTimeStatusNow,
            SlotStatus.past => l.p69Done,
            SlotStatus.upcoming => null,
          };
    final semantic =
        '${l.acadTimeSlotSemantic(c.name, acadDayName(l, s.session.dayOfWeek.clamp(1, 7)), s.session.start, s.session.end)}${room != null ? ', $room' : ''}${status != null ? ', $status' : ''}';
    final titleColor = past ? t.mut : t.ink;
    final barColor = ongoing ? t.pr : t.bd;
    return Semantics(
      container: true,
      button: true,
      label: semantic,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            buHaptic(BuHaptic.selection);
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 24, 20),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: 48,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(s.session.start, maxLines: 1, style: tx.titleSmall!.copyWith(fontSize: 15, fontWeight: past ? FontWeight.w500 : FontWeight.w700, color: past ? t.mut : t.ink, fontFeatures: const [FontFeature.tabularFigures()])),
                    Text(s.session.end, maxLines: 1, style: tx.bodySmall!.copyWith(fontSize: 13, color: past ? t.mut : t.ink.withValues(alpha: .8), fontFeatures: const [FontFeature.tabularFigures()])),
                  ]),
                ),
                const SizedBox(width: 17),
                ExcludeSemantics(child: Container(width: 3, decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: titleColor))),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 0,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(trailing!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, fontWeight: ongoing ? FontWeight.w600 : FontWeight.w400, color: ongoing ? t.pr : t.mut)),
                          ),
                        ),
                      ],
                    ]),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
                    ],
                    if (c.instructor != null) ...[
                      const SizedBox(height: 6),
                      Text(c.instructor!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.ink.withValues(alpha: .8))),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Şimdi · 11:20" çizgisi: `pr` nokta + `pr` metin + ince ayraç. Geçmiş ve yaklaşan dersler arasına konur; bir kez
/// solarak belirir, sürekli hareket yoktur.
class TtNowLine extends StatelessWidget {
  const TtNowLine({super.key, required this.time});

  /// Şimdiki saat, `HH:mm`.
  final String time;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final text = '${l.p69Now} · $time';
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: BuMotion.of(context, BuMotion.long),
        curve: BuMotion.emphasizedDecelerate,
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Padding(padding: EdgeInsetsDirectional.only(start: 4), child: AcadDot(size: 8)),
              const SizedBox(width: 6),
              Text(text, maxLines: 1, style: tx.bodySmall!.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: t.pr, fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: 9),
              const Expanded(child: AcadRule()),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Alt özet: solda küçük simge + "Bugün toplam 4 oturum (7 saat)", sağda `pr` metin bağlantı (Sınav takvimi).
class TtSummary extends StatelessWidget {
  const TtSummary({super.key, required this.text, required this.actionLabel, required this.onAction});

  final String text, actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(children: [
        ExcludeSemantics(child: Icon(LucideIcons.circleCheck, size: 16, color: t.mut)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.ink.withValues(alpha: .8)))),
        const SizedBox(width: 8),
        Flexible(flex: 0, child: AcadTextAction(actionLabel, onTap: onAction, size: 13)),
      ]),
    );
  }
}

/// Dönem ya da ders yokken ortalı boş durum (kartsız): başlık + muted açıklama + birincil düğme.
class TtEmpty extends StatelessWidget {
  const TtEmpty({super.key, required this.title, required this.body, required this.actionLabel, required this.onAction, this.semesterLabel, this.onPickSemester});

  final String title, body, actionLabel;
  final VoidCallback onAction;
  final String? semesterLabel;
  final VoidCallback? onPickSemester;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (semesterLabel != null && onPickSemester != null)
          Align(alignment: AlignmentDirectional.centerStart, child: AcadTextAction(semesterLabel!, onTap: onPickSemester)),
        const SizedBox(height: 32),
        Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink))),
        const SizedBox(height: 6),
        Text(body, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
        const SizedBox(height: 24),
        BuButton(label: actionLabel, onPressed: onAction),
      ]),
    );
  }
}

/// Ders programı yükleniyor iskeleti: üst satır, gün şeridi, satırlar.
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
              BuSkeleton.line(width: 140, height: 14),
              Spacer(),
              BuSkeleton(width: 130, height: 32, radius: 16),
            ]),
            const SizedBox(height: 22),
            Row(children: [
              for (var i = 0; i < 5; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                const Expanded(child: BuSkeleton(height: 56, radius: 24)),
              ],
            ]),
            const SizedBox(height: 28),
            for (var i = 0; i < 3; i++) ...[
              const Row(children: [
                BuSkeleton(width: 48, height: 40, radius: 6),
                SizedBox(width: 24),
                Expanded(child: BuSkeleton(height: 46, radius: 6)),
              ]),
              const SizedBox(height: 28),
            ],
          ]),
        ),
      ),
    );
  }
}
