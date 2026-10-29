import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Tasarım (P8/P10) ton çifti: açık temada pastel zemin + koyu ikon, koyu temada yarı saydam zemin + açık ikon.
class NotifTone {
  const NotifTone(this.lightBg, this.lightFg, this.darkFg);

  final Color lightBg, lightFg, darkFg;

  static const red = NotifTone(Color(0xFFFDE7E4), Color(0xFFC62A20), Color(0xFFFF8A80));
  static const blue = NotifTone(Color(0xFFE8EDF8), Color(0xFF2F4FA8), Color(0xFF9DB4F5));
  static const green = NotifTone(Color(0xFFE6F2EA), Color(0xFF1F7A4A), Color(0xFF7FD6A4));
  static const amber = NotifTone(Color(0xFFFBEFD9), Color(0xFF8A5200), Color(0xFFF2BC66));

  Color fg(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? darkFg : lightFg;
  Color bg(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? darkFg.withValues(alpha: .18) : lightBg;
}

/// Renkli ikon karosu (bildirim satırı ve akademik ekran ortak kullanır).
class NotifIconTile extends StatelessWidget {
  const NotifIconTile({super.key, required this.icon, required this.tone, this.size = 44, this.radius = 14});

  final IconData icon;
  final NotifTone tone;
  final double size, radius;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tone.bg(context), borderRadius: BorderRadius.circular(radius)),
        child: Icon(icon, size: size * .5, color: tone.fg(context)),
      );
}

/// Bildirim satırı (referans: 15/16): sol yuvarlak tür simgesi (okunmamışta köşe noktası), üstte tür etiketi +
/// kısa zaman, altında başlık (tek satır) ve en çok iki satır gövde.
class NotifRow extends StatelessWidget {
  const NotifRow({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.typeLabel,
    required this.time,
    required this.unread,
    required this.onTap,
    this.body = '',
    this.unreadLabel,
    this.strong = false,
  });

  /// true: koyu (mürekkep) daire + açık simge (etkinlik/duyuru türleri).
  final bool strong;
  final IconData icon;
  final NotifTone tone;
  final String title, typeLabel, time, body;
  final bool unread;
  final VoidCallback onTap;
  final String? unreadLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(20);
    final circleBg = strong ? t.ink : tone.bg(context);
    final circleFg = strong ? t.bg : tone.fg(context);
    return Semantics(
      button: true,
      label: unread ? unreadLabel : null,
      child: Container(
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: radius,
          border: Border.all(color: t.bd.withValues(alpha: .6)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 46,
                      height: 46,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(color: circleBg, shape: BoxShape.circle),
                      child: Icon(icon, size: 22, color: circleFg),
                    ),
                    if (unread)
                      PositionedDirectional(
                        end: 0,
                        top: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.sf, width: 2)),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.pill)),
                            child: Text(typeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: t.mut)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(time,
                          maxLines: 1, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w500, color: t.mut)),
                    ]),
                    const SizedBox(height: 6),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx.titleMedium!.copyWith(
                            height: 1.25, color: t.ink, fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                    if (body.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tx.bodyMedium!.copyWith(height: 1.4, color: t.mut)),
                      ),
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
