import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';

/// Tasarımdaki sabit ton paleti (kırmızı / mavi / yeşil) — tarih karosu rengi.
enum EtkinlikTone { red, blue, green }

EtkinlikTone etkinlikToneOf(int id) =>
    EtkinlikTone.values[id.abs() % EtkinlikTone.values.length];

/// Tarih karosu: ay kısaltması + gün (56x64, 16 köşe), renkli.
class EtkinlikDateTile extends StatelessWidget {
  const EtkinlikDateTile(
      {super.key, required this.month, required this.day, required this.tone});

  final String month;
  final String day;
  final EtkinlikTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = switch (tone) {
      EtkinlikTone.red => (t.soft, t.onSoft),
      EtkinlikTone.blue => dark
          ? (const Color(0xFF2F4FA8).withValues(alpha: .28), const Color(0xFFA9BDF2))
          : (const Color(0xFFE8EDF8), const Color(0xFF2F4FA8)),
      EtkinlikTone.green => dark
          ? (const Color(0xFF1F7A4A).withValues(alpha: .30), const Color(0xFF8FDDB0))
          : (const Color(0xFFE6F2EA), const Color(0xFF1F7A4A)),
    };
    return ExcludeSemantics(
      child: Container(
        width: 56,
        height: 64,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(month,
                maxLines: 1,
                style: BuType.micro
                    .copyWith(color: fg, fontWeight: FontWeight.w700)),
            Text(day,
                maxLines: 1,
                style: BuType.title.copyWith(
                    color: fg, height: 1.1, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

/// Durum / eylem hapı ("Katılıyorsunuz" yeşil, "Katıl" kırmızı).
class EtkinlikPill extends StatelessWidget {
  const EtkinlikPill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.onTap,
    this.icon,
    this.busy = false,
  });

  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (busy)
          SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (icon != null)
          Icon(icon, size: 13, color: fg),
        if (busy || icon != null) const SizedBox(width: 5),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BuType.label
                  .copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ]),
    );
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: onTap == null
          ? child
          : InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: child),
    );
  }
}
