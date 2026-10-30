import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Kulüp sayfalarının ortak bileşenleri (P11 yeniden tasarım: Material 3 + marka belirteçleri).
/// İmzalar P12 (kulüp formu, katılım akışı, Kulüplerim) tarafından kullanılır; yalnız isteğe bağlı parametre eklenir.

/// Ada göre kararlı ton (kategori renkleri `context.bu.tint`): zemin / yazı. Koyu temada belirteç kendiliğinden uyar.
(Color, Color) kulupTone(BuildContext context, String? name) {
  final n = (name ?? '').trim();
  var h = 0;
  for (final r in n.runes) {
    h = (h * 31 + r) & 0x7fffffff;
  }
  final tint = context.bu.tint(h);
  return (tint.bg, tint.fg);
}

/// Kulüp sayfalarındaki kişi avatarı (yorum yazarı, üye, başvuran): fotoğraf varsa o, yoksa varsayılan profil görseli.
class KulupAvatar extends StatelessWidget {
  const KulupAvatar({super.key, required this.name, this.url, this.size = 42});

  final String? name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) => BuAvatar(name: name, url: url, size: size);
}

/// Rol etiketi (Yönetici / Moderatör): marka tonlu hap, 24 dp yükseklik, isteğe bağlı simge.
class KulupRoleBadge extends StatelessWidget {
  const KulupRoleBadge(this.text, {super.key, this.icon, this.bg, this.fg});

  final String text;
  final IconData? icon;

  /// İsteğe bağlı ton (varsayılan marka tonu): moderatör için mavi gibi.
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final fgc = fg ?? t.onSoft;
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: bg ?? t.soft, borderRadius: BuRadius.bPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: 12, color: fgc)), const SizedBox(width: 4)],
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: fgc)),
          ),
        ],
      ),
    );
  }
}

/// Yuvarlak köşeli, çizgili açılır menü biçimi (P12 `PopupMenuButton`ları için).
ShapeBorder kulupMenuShape(BuildContext context) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md), side: BorderSide(color: context.bu.bd));

/// Menü satırı: 44 dp en az yükseklik; [danger] kırmızı yazı; [count] sağda sayı hapı.
class KulupMenuRow extends StatelessWidget {
  const KulupMenuRow(this.label, {super.key, this.danger = false, this.count});

  final String label;
  final bool danger;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tx.titleSmall!.copyWith(color: danger ? t.danger : t.ink)),
        ),
        if (count != null && count! > 0) ...[const SizedBox(width: 10), BuCountBadge(count!)],
      ],
    );
  }
}

/// Üç noktalı (⋯) yatay menü simgesi.
class KulupDots extends StatelessWidget {
  const KulupDots({super.key, this.size = 20, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(LucideIcons.ellipsis, size: size, color: color ?? context.bu.mut);
}

/// Girdi alanı süsü: tema (`inputDecorationTheme`: dolu + çerçeveli, odakta 2 dp marka rengi) kullanılır.
/// [error] varsa alanın altında hata metni ve kırmızı çizgi görünür.
InputDecoration kulupField(BuildContext context, {String? hint, String? error, EdgeInsetsGeometry? pad}) =>
    InputDecoration(hintText: hint, errorText: error, counterText: '', contentPadding: pad);

enum KulupPillKind { primary, soft, outline }

/// Üyelik / sohbet düğmesi (hap). [staticLook] true: dokunulmaz durum etiketi ("Üyesin").
class KulupPillButton extends StatelessWidget {
  const KulupPillButton({
    super.key,
    required this.label,
    this.icon,
    this.kind = KulupPillKind.primary,
    this.busy = false,
    this.staticLook = false,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final KulupPillKind kind;
  final bool busy;
  final bool staticLook;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    if (!staticLook) {
      return BuButton(
        label: label,
        icon: icon,
        busy: busy,
        compact: true,
        kind: switch (kind) {
          KulupPillKind.primary => BuButtonKind.primary,
          KulupPillKind.soft => BuButtonKind.soft,
          KulupPillKind.outline => BuButtonKind.outline,
        },
        onPressed: onPressed,
      );
    }
    final (bg, fg, side) = switch (kind) {
      KulupPillKind.primary => (t.pr, t.onPr, BorderSide.none),
      KulupPillKind.soft => (t.soft, t.onSoft, BorderSide.none),
      KulupPillKind.outline => (t.sf2, t.mut, BorderSide(color: t.bd)),
    };
    final tx = Theme.of(context).textTheme;
    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: ShapeDecoration(color: bg, shape: StadiumBorder(side: side)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
              Flexible(
                child: Text(label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 48 dp işlem düğmesi (başvuru Reddet / Onayla): M3 dolu ya da çerçeveli düğme, basınca hafif küçülür.
class KulupActionButton extends StatelessWidget {
  const KulupActionButton({super.key, required this.label, required this.onPressed, this.primary = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Flexible(child: Text(label, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
    );
    final void Function()? tap = onPressed == null
        ? null
        : () {
            buHaptic(BuHaptic.selection);
            onPressed!();
          };
    const size = Size(0, 48);
    return BuPressable(
      scale: .98,
      enabled: tap != null,
      child: primary
          ? FilledButton(
              onPressed: tap,
              style: FilledButton.styleFrom(minimumSize: size, padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: child)
          : OutlinedButton(
              onPressed: tap,
              style: OutlinedButton.styleFrom(minimumSize: size, padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: child),
    );
  }
}
