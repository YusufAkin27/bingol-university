import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../notifications/notif_row.dart';

/// Kırmızı "Sıradaki sınav" kartı (P10).
class AcadhubNextExamCard extends StatelessWidget {
  const AcadhubNextExamCard({super.key, required this.label, required this.title, this.subtitle, this.onTap});

  final String label, title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final radius = BorderRadius.circular(20);
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: '$label. $title${subtitle == null ? '' : '. $subtitle'}',
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.pr,
          borderRadius: radius,
          boxShadow: const [BoxShadow(color: Color(0xB3C62A20), blurRadius: 26, spreadRadius: -14, offset: Offset(0, 14))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: BuType.label.copyWith(fontSize: 12, color: t.onPr.withValues(alpha: .9))),
                const SizedBox(height: 6),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.title.copyWith(fontSize: 20, fontWeight: FontWeight.w800, color: t.onPr)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: BuType.body.copyWith(fontSize: 14, color: t.onPr.withValues(alpha: .92))),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class AcadhubDate {
  const AcadhubDate({required this.month, required this.day, required this.title, required this.range, required this.tone});

  final String month, title, range;
  final int day;
  final NotifTone tone;
}

/// "Yaklaşan tarihler" kartı: ay/gün pulu + başlık + aralık.
class AcadhubUpcomingCard extends StatelessWidget {
  const AcadhubUpcomingCard({super.key, required this.events, required this.emptyText});

  final List<AcadhubDate> events;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.bd),
        boxShadow: const [BoxShadow(color: Color(0x40171E33), blurRadius: 18, spreadRadius: -12, offset: Offset(0, 6))],
      ),
      child: events.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(emptyText, style: BuType.body.copyWith(color: t.mut)),
            )
          : Column(children: [
              for (var i = 0; i < events.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: t.bd))),
                  child: Row(children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(color: events[i].tone.bg(context), borderRadius: BorderRadius.circular(16)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(_abbr(events[i].month),
                            maxLines: 1,
                            style: BuType.micro.copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: events[i].tone.fg(context))),
                        Text('${events[i].day}',
                            style: BuType.title.copyWith(
                                fontSize: 20, fontWeight: FontWeight.w800, height: 1.1, color: events[i].tone.fg(context))),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(events[i].title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink)),
                        const SizedBox(height: 2),
                        Text(events[i].range, style: BuType.caption.copyWith(fontSize: 12, color: t.mut)),
                      ]),
                    ),
                  ]),
                ),
            ]),
    );
  }

  static String _abbr(String m) {
    final r = m.runes.toList();
    return String.fromCharCodes(r.take(3)).toUpperCase();
  }
}
