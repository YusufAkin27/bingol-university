import 'package:flutter/material.dart';

import '../../widgets/bu.dart';
import 'akad_widgets.dart';

/// Akademik giriş sayfasının parçaları (Stitch 43): sıradaki sınav kartı, yaklaşan tarih şeridi, kart satırları.

/// "Sıradaki sınav" kartı: etiket + geri sayım hapı, ad, tarih/derslik kutusu, "Oturum planı" bağlantısı.
class AcadhubNextExamCard extends StatelessWidget {
  const AcadhubNextExamCard({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
    this.countdown,
    required this.dateLabel,
    required this.dateText,
    required this.roomLabel,
    this.room,
    required this.planLabel,
    this.onTap,
  });

  final String label, title, dateLabel, dateText, roomLabel, planLabel;
  final String? subtitle, countdown, room;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    Widget cell(IconData icon, String lab, String value) => Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(10)),
            child: ExcludeSemantics(child: Icon(icon, size: 18, color: t.pr)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lab, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(color: t.mut)),
              Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
            ]),
          ),
        ]);
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: '$label. $title. $dateText${room == null ? '' : ', $room'}${countdown == null ? '' : '. $countdown'}',
      onTap: onTap,
      child: AkadCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BuRadius.bLg,
            gradient: LinearGradient(begin: AlignmentDirectional.topEnd, end: AlignmentDirectional.center, colors: [t.soft.withValues(alpha: .7), t.sf.withValues(alpha: 0)]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(LucideIcons.calendarClock, size: 22, color: t.pr),
              const SizedBox(width: 8),
              Expanded(
                child: Text(akadUpper(context, label),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, letterSpacing: .6, color: t.mut)),
              ),
              if (countdown != null) ...[const SizedBox(width: 8), Flexible(child: AkadPill(countdown!, bg: t.pr, fg: t.onPr))],
            ]),
            const SizedBox(height: 12),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
            if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (room == null)
                  cell(LucideIcons.calendar, dateLabel, dateText)
                else
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 5, child: cell(LucideIcons.calendar, dateLabel, dateText)),
                    const SizedBox(width: 8),
                    Expanded(flex: 4, child: cell(LucideIcons.doorOpen, roomLabel, room!)),
                  ]),
              ]),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(planLabel, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: t.pr)),
                const SizedBox(width: 4),
                Icon(buDirIcon(context, LucideIcons.arrowRight), size: 16, color: t.pr),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class AcadhubDate {
  const AcadhubDate({required this.day, required this.title, this.primary = false});

  final String day, title;
  final bool primary; // ilk çipin noktası marka renginde
}

/// "Yaklaşan tarihler": yatay kayan beyaz hap çipler (nokta + tarih + başlık).
class AcadhubDateStrip extends StatelessWidget {
  const AcadhubDateStrip({super.key, required this.dates, this.onTap});

  final List<AcadhubDate> dates;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final d = dates[i];
          return Center(
            child: Semantics(
              button: true,
              label: '${d.day}. ${d.title}',
              excludeSemantics: true,
              onTap: onTap,
              child: BuPressable(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48, maxWidth: 300),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bPill, border: Border.all(color: t.bd.withValues(alpha: .5)), boxShadow: BuElevation.of(context, 1)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: d.primary ? t.pr : t.ink.withValues(alpha: .7), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(d.day, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                        const SizedBox(width: 8),
                        Text('•', style: tx.labelLarge!.copyWith(color: t.mut)),
                        const SizedBox(width: 8),
                        Flexible(child: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(color: t.mut))),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum AcadhubChipTone { neutral, soft, solid }

/// Kompakt kart: simge karosu + başlık + alt metin + isteğe bağlı durum çipi + ok.
class AcadhubTile extends StatelessWidget {
  const AcadhubTile({
    super.key,
    required this.icon,
    required this.tileBg,
    required this.tileFg,
    required this.title,
    required this.sub,
    this.chip,
    this.chipTone = AcadhubChipTone.neutral,
    this.onTap,
  });

  final IconData icon;
  final Color tileBg, tileFg;
  final String title, sub;
  final String? chip;
  final AcadhubChipTone chipTone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final (bg, fg) = switch (chipTone) {
      AcadhubChipTone.neutral => (t.sf2, t.ink),
      AcadhubChipTone.soft => (t.soft, t.onSoft),
      AcadhubChipTone.solid => (t.pr, t.onPr),
    };
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: '$title. $sub${chip == null ? '' : '. $chip'}',
      onTap: onTap,
      child: AkadCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          AkadIconTile(icon: icon, bg: tileBg, fg: tileFg, size: 56, radius: 16, iconSize: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
              Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
              if (chip != null) ...[
                const SizedBox(height: 8),
                AkadPill(chip!, bg: bg, fg: chipTone == AcadhubChipTone.neutral ? t.ink : fg, dot: chipTone == AcadhubChipTone.neutral),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.mut),
        ]),
      ),
    );
  }
}

/// Verisi olmayan kart: başlık satırı + içte ortalı boş durum kutusu (ya da tek satırlık bilgi kutusu).
class AcadhubEmptyCard extends StatelessWidget {
  const AcadhubEmptyCard({
    super.key,
    required this.icon,
    this.iconBg,
    this.iconFg,
    required this.title,
    this.sub,
    this.badge,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
    this.actionLabel,
    this.onAction,
    this.rowStyle = false,
    this.onTap,
  });

  final IconData icon, emptyIcon;
  final Color? iconBg, iconFg;
  final String title, emptyTitle, emptyBody;
  final String? sub, badge, actionLabel;
  final VoidCallback? onAction, onTap;
  final bool rowStyle;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      button: true,
      label: '$title. $emptyTitle',
      onTap: onTap,
      child: AkadCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            AkadIconTile(icon: icon, bg: iconBg ?? t.tint(1).bg, fg: iconFg ?? t.tint(1).fg, size: 40, radius: 12, iconSize: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
            if (badge != null) ...[const SizedBox(width: 8), Flexible(child: AkadPill(badge!, bg: t.sf2, fg: t.mut))],
          ]),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(sub!, style: tx.bodyMedium!.copyWith(color: t.mut))),
          const SizedBox(height: 14),
          if (rowStyle)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
              child: Row(children: [
                AkadIconTile(icon: emptyIcon, bg: t.sf, fg: t.mut, size: 40, radius: 10, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(emptyTitle, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                    Text(emptyBody, style: tx.bodySmall!.copyWith(color: t.mut)),
                  ]),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle),
                  child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.ink),
                ),
              ]),
            )
          else
            AkadEmptyBox(
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyBody,
              action: actionLabel == null ? null : _WhitePill(label: actionLabel!, onTap: onAction),
            ),
        ]),
      ),
    );
  }
}

/// Boş kutu içindeki beyaz hap eylem ("+ Derslerini ekle"): beyaz zemin, kırmızı yazı, hafif gölge.
class _WhitePill extends StatelessWidget {
  const _WhitePill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        onTap: onTap,
        haptic: BuHaptic.selection,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bPill, boxShadow: BuElevation.of(context, 1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.plus, size: 16, color: t.pr),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: t.pr))),
          ]),
        ),
      ),
    );
  }
}
