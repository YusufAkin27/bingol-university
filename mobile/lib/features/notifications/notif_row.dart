import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';

/// Tasarım (P8/P10) ton çifti: açık temada pastel zemin + koyu ikon, koyu temada yarı saydam zemin + açık ikon.
class NotifTone {
  const NotifTone(this.lightBg, this.lightFg, this.darkFg);

  final Color lightBg, lightFg, darkFg;

  static const red = NotifTone(Color(0xFFFDE7E4), Color(0xFFC62A20), Color(0xFFFF8A80));
  static const blue = NotifTone(Color(0xFFE8EDF8), Color(0xFF2F4FA8), Color(0xFF9DB4F5));
  static const green = NotifTone(Color(0xFFE6F2EA), Color(0xFF1F7A4A), Color(0xFF7FD6A4));
  static const amber = NotifTone(Color(0xFFFBEFD9), Color(0xFF8A5200), Color(0xFFF2BC66));

  Color fg(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? darkFg : lightFg;
  Color bg(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? darkFg.withValues(alpha: .18) : lightBg;
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

/// Bildirim satırı: okunmamışta beyaz kart + sol şerit + nokta; sağda kısa zaman.
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
  });

  final IconData icon;
  final NotifTone tone;
  final String title, typeLabel, time, body;
  final bool unread;
  final VoidCallback onTap;
  final String? unreadLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final radius = BorderRadius.circular(20);
    return Semantics(
      button: true,
      label: unread ? unreadLabel : null,
      child: Container(
        decoration: BoxDecoration(
          color: unread ? t.sf : Colors.transparent,
          borderRadius: radius,
          border: Border.all(color: unread ? t.bd : Colors.transparent),
          boxShadow: unread
              ? const [
                  BoxShadow(color: Color(0x0D171E33), blurRadius: 6, offset: Offset(0, 2)),
                  BoxShadow(color: Color(0x0D171E33), blurRadius: 20, offset: Offset(0, 8)),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Stack(children: [
              if (unread)
                PositionedDirectional(
                  start: 0,
                  top: 18,
                  bottom: 18,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: t.pr,
                      borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(4)),
                    ),
                  ),
                ),
              Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: EdgeInsetsDirectional.fromSTEB(unread ? 14 : 15, 10, unread ? 14 : 15, 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  NotifIconTile(icon: icon, tone: tone),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: BuType.heading.copyWith(
                              fontSize: 15,
                              height: 1.35,
                              color: t.ink,
                              fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(typeLabel, style: BuType.caption.copyWith(fontSize: 12, color: t.mut)),
                      ),
                      if (body.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.caption.copyWith(fontSize: 12, height: 1.4, color: t.mut)),
                        ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 40),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(time,
                          maxLines: 1,
                          style: BuType.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.mut)),
                      const SizedBox(height: 6),
                      unread
                          ? Container(width: 9, height: 9, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle))
                          : const SizedBox(width: 9, height: 9),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
