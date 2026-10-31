import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/typography.dart';

/// Sistem ekranları (izin, bakım, güncelleme, hata, QR) için ortak yapı taşları.
/// Tasarım: Sm1-Sm8, Et3b. Renkler `context.bu`; tasarımdaki sabit tonlar burada.
abstract final class SistemTones {
  /// Bakım bandı (sıcak sarı): belirteçlerden (`warnSoft` / `onWarnSoft`), açık ve koyu temada AA.
  static Color bandBg(BuildContext c) => c.bu.warnSoft;
  static Color bandBd(BuildContext c) => c.bu.warn.withValues(alpha: .28);
  static Color bandFg(BuildContext c) => c.bu.onWarnSoft;

  /// Seçilmemiş radyo halkası.
  static Color radioOff(BuildContext c) => c.bu.mut.withValues(alpha: .7);
}

/// Yumuşak zeminli köşeli ikon karosu (tasarımdaki `.tile` / `.big`).
class SistemTile extends StatelessWidget {
  const SistemTile({super.key, required this.icon, this.size = 48, this.radius, this.iconSize});

  final IconData icon;
  final double size;
  final double? radius;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(radius ?? size / 3)),
        child: Icon(icon, size: iconSize ?? size * 0.46, color: t.pr),
      ),
    );
  }
}

enum SistemButtonKind { primary, outline, link }

/// Tasarımın düğmeleri: dolu kırmızı (gölgeli), çerçeveli, düz bağlantı.
class SistemButton extends StatelessWidget {
  const SistemButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = SistemButtonKind.primary,
    this.height = 54,
    this.radius = 18,
    this.busy = false,
    this.fontSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final SistemButtonKind kind;
  final double height;
  final double radius;
  final bool busy;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final primary = kind == SistemButtonKind.primary;
    final fg = primary ? t.onPr : (kind == SistemButtonKind.link ? t.mut : t.ink);
    final style = (primary ? BuType.heading : BuType.bodyStrong)
        .copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: fontSize);
    final enabled = onPressed != null && !busy;
    final deco = BoxDecoration(
      color: primary ? t.pr : Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      border: kind == SistemButtonKind.outline ? Border.all(color: t.bd, width: 1.5) : null,
      boxShadow: primary && onPressed != null
          ? [BoxShadow(color: t.pr.withValues(alpha: .35), blurRadius: 26, offset: const Offset(0, 14), spreadRadius: -12)]
          : null,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: onPressed == null ? .5 : 1,
        child: DecoratedBox(
          decoration: deco,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: height, minWidth: 44),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: busy
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                        : Text(label, textAlign: TextAlign.center, style: style),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tam ekran durum görünümü (Sm3-Sm6, Sm8): ortada ikon karosu + başlık + açıklama,
/// altta sabit düğmeler. Sığmazsa ortadaki kısım kayar.
class SistemStatusView extends StatelessWidget {
  const SistemStatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.extras = const [],
    this.footer = const [],
    this.alert = false,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Açıklamanın altındaki ek içerik (bant, sürüm satırı…).
  final List<Widget> extras;

  /// Alt düğmeler (üstten alta).
  final List<Widget> footer;

  /// Hata ekranında açıklama `alert` olarak duyurulur.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SistemTile(icon: icon, size: 88, radius: 30, iconSize: 40),
                        const SizedBox(height: 16),
                        Text(title,
                            textAlign: TextAlign.center,
                            style: BuType.display.copyWith(color: t.ink, letterSpacing: -.5)),
                        const SizedBox(height: 10),
                        Semantics(
                          liveRegion: true,
                          child: Text(body,
                              textAlign: TextAlign.center,
                              style: BuType.body.copyWith(color: t.mut, height: 1.5)),
                        ),
                        for (final e in extras) ...[const SizedBox(height: 10), e],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (footer.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (var i = 0; i < footer.length; i++) ...[if (i > 0) const SizedBox(height: 4), footer[i]]],
            ),
          ),
      ],
    );
  }
}

/// Bakım bandı (Sm4): sıcak sarı yuvarlak şerit.
class MaintenanceBand extends StatelessWidget {
  const MaintenanceBand({super.key, required this.text, this.icon = Icons.info_outline, this.margin = EdgeInsets.zero});

  final String text;
  final IconData icon;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final fg = SistemTones.bandFg(context);
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SistemTones.bandBg(context),
        border: Border.all(color: SistemTones.bandBd(context)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 16, color: fg)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: BuType.label.copyWith(color: fg, height: 1.4, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
