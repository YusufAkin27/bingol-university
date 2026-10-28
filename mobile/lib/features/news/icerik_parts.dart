import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../core/typography.dart';

/// Arama / haber / favori / kullanıcı profili ekranlarının ortak yeni tasarım parçaları
/// (Ic1-Ic5 şablonları): yumuşak gölgeli kart, yuvarlak ikon düğmesi, görsel kutusu.

bool icerikDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

/// Kart: beyaz yüzey, ince çizgi, 20 köşe, yumuşak gölge.
class IcerikCard extends StatelessWidget {
  const IcerikCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.radius = 20,
    this.clip = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: r,
        border: Border.all(color: t.bd),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF171E33).withValues(alpha: icerikDark(context) ? .35 : .09),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: InkWell(onTap: onTap, borderRadius: r, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// 44 dp yuvarlak ikon düğmesi (geri / favori / ara / diğer). [on] true: yumuşak kırmızı seçili hâl.
class IcerikIconButton extends StatelessWidget {
  const IcerikIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.on = false,
    this.toggled,
    this.shadow = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool on;
  final bool? toggled;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = icerikDark(context);
    final bg = on ? t.soft : t.sf;
    final fg = on ? t.pr : t.ink;
    final border = on ? t.pr.withValues(alpha: dark ? .5 : .28) : t.bd;
    return Semantics(
      button: true,
      toggled: toggled,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: border),
            boxShadow: shadow
                ? [
                    BoxShadow(
                        color: const Color(0xFF171E33).withValues(alpha: .18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        spreadRadius: -8)
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Görsel kutusu: sf2 zemin, ağdan yüklenir; hata/boşta bırakılır (zemin kalır).
class IcerikThumb extends StatelessWidget {
  const IcerikThumb({super.key, required this.url, required this.size, this.radius = 16, this.headers});

  final String? url;
  final double size;
  final double radius;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(radius)),
      child: Icon(LucideIcons.image, size: size * .3, color: t.mut),
    );
    final u = url;
    if (u == null || u.isEmpty) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        u,
        width: size,
        height: size,
        cacheWidth: (size * 3).round(),
        cacheHeight: (size * 3).round(),
        headers: headers,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => box,
        loadingBuilder: (_, child, p) => p == null ? child : box,
      ),
    );
  }
}

/// Tür rozeti: haber koyu kırmızı dolgu, diğerleri yumuşak (tasarımdaki .bd / .bd.soft).
class IcerikBadge extends StatelessWidget {
  const IcerikBadge(this.text, {super.key, this.soft = false});

  final String text;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: soft ? t.soft : t.pr, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          maxLines: 1,
          style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, height: 1, color: soft ? t.onSoft : t.onPr)),
    );
  }
}

/// Bölüm başlığı (büyük harf, geniş harf aralığı, soluk).
TextStyle icerikSectionStyle(BuTokens t) =>
    BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .6, color: t.mut);

/// Bakım bandı renkleri (açık/koyu).
({Color bg, Color border, Color fg}) icerikWarnColors(BuildContext context) => icerikDark(context)
    ? (bg: const Color(0xFF3A2C14), border: const Color(0xFF5C4522), fg: const Color(0xFFF3D9A8))
    : (bg: const Color(0xFFFFF3E3), border: const Color(0xFFF3DDBF), fg: const Color(0xFF5B3B0E));

/// Alt sayfa başlığı: geri düğmesi + 20 dp kalın başlık (+ isteğe bağlı sağ eylemler).
class IcerikHeader extends StatelessWidget {
  const IcerikHeader({super.key, required this.title, required this.backLabel, this.actions = const []});

  final String title;
  final String backLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 8, 20, 0),
      child: Row(children: [
        IcerikIconButton(
            icon: buDirIcon(context, LucideIcons.arrowLeft),
            label: backLabel,
            shadow: true,
            onTap: () => Navigator.maybePop(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BuType.display.copyWith(fontSize: 20, letterSpacing: -.3, height: 1.2, color: t.ink)),
          ),
        ),
        for (final a in actions) ...[const SizedBox(width: 10), a],
      ]),
    );
  }
}
