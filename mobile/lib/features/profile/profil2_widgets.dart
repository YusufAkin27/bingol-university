import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';

/// Gizlilik / veriler / hesap güvenliği sayfalarının ortak küçük bileşenleri.

/// Tasarımdaki sabit tonlar (açık/koyu).
class P2Tones {
  const P2Tones._(this.dark);

  factory P2Tones.of(BuildContext context) => P2Tones._(Theme.of(context).brightness == Brightness.dark);

  final bool dark;

  /// Doğrulandı / onay tiki (yeşil).
  Color get okFg => dark ? const Color(0xFF7FD6A1) : const Color(0xFF14633A);
  Color get okBg => dark ? const Color(0xFF16301F) : const Color(0xFFE3F4E8);

  /// Tehlike kırmızısı ve yumuşak zemini.
  Color get dng => dark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E);
  Color get dngBg => dark ? const Color(0xFF3A1C1A) : const Color(0xFFFDE7E4);
  Color get dngBorder => dark ? const Color(0xFF5A2B28) : const Color(0xFFF4C3BE);
  Color get dngText => dark ? const Color(0xFFFFC9C4) : const Color(0xFF7A1812);

  /// Devre dışı tehlike düğmesi.
  Color get dngOff => dark ? const Color(0xFF4A2B29) : const Color(0xFFE9C9C5);

  /// Mavi simge (KVKK metni).
  Color get blue => dark ? const Color(0xFF9DB4F0) : const Color(0xFF2F4FA8);
}

/// Bölüm başlığı: küçük, kalın, soluk.
class P2SectionLabel extends StatelessWidget {
  const P2SectionLabel(this.text, {super.key, this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 6, bottom: 8, top: top),
      child: Semantics(
        header: true,
        child: Text(text, style: BuType.label.copyWith(color: context.bu.mut, fontWeight: FontWeight.w700, letterSpacing: .6)),
      ),
    );
  }
}

/// 36 px, 12 yarıçaplı simge karosu.
class P2IconTile extends StatelessWidget {
  const P2IconTile({super.key, required this.icon, this.color, this.bg, this.size = 36});

  final IconData icon;
  final Color? color;
  final Color? bg;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg ?? t.bg, borderRadius: BorderRadius.circular(size * .33)),
        alignment: Alignment.center,
        child: Icon(icon, size: size * .5, color: color ?? t.pr),
      ),
    );
  }
}

/// Kart içi satır: simge karosu + metin (+ alt metin) + sonda öğe. Dokunulabilir ise InkWell.
class P2Row extends StatelessWidget {
  const P2Row({
    super.key,
    this.icon,
    this.iconColor,
    this.iconBg,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.chevron = false,
    this.minHeight = 60,
    this.busy = false,
  });

  final IconData? icon;
  final Color? iconColor;
  final Color? iconBg;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final bool chevron;
  final double minHeight;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (icon != null) ...[P2IconTile(icon: icon!, color: iconColor, bg: iconBg), const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.bodyStrong.copyWith(color: titleColor ?? t.ink)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(subtitle!, style: BuType.label.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
                    ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsetsDirectional.only(start: 8),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (trailing != null)
              Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: trailing),
            if (chevron && !busy)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: ExcludeSemantics(
                  child: Icon(Directionality.of(context) == TextDirection.rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
                      size: 18, color: t.mut),
                ),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: busy ? null : onTap, child: row);
  }
}

/// Tasarımdaki küçük hap (Doğrulandı vb.).
class P2Pill extends StatelessWidget {
  const P2Pill({super.key, required this.text, required this.fg, required this.bg, this.icon});

  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Flexible(child: Text(text, style: BuType.label.copyWith(color: fg, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

/// Tasarımdaki 48x28 anahtar (kırmızı iz, beyaz kulp), 44 px dokunma alanı.
class P2Switch extends StatelessWidget {
  const P2Switch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: t.pr,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: t.sf2,
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}

/// Madde işaretli (tik / çarpı) satır.
class P2BulletLine extends StatelessWidget {
  const P2BulletLine({super.key, required this.text, required this.icon, required this.color});

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: BuType.body.copyWith(color: t.ink, height: 1.4))),
        ],
      ),
    );
  }
}

/// Büyük yazı ölçeğinde satırları alt alta dizmek için eşik.
bool p2BigText(BuildContext context) => MediaQuery.textScalerOf(context).scale(10) > 13;
