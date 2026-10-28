import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';

/// Kulüp sayfalarının ortak bileşenleri (Kl1-Kl5 tasarımları).

/// Tasarımdaki sabit avatar tonları (açık tema): zemin / yazı.
const _tones = <(Color, Color)>[
  (Color(0xFFFDE7E4), Color(0xFFC62A20)),
  (Color(0xFFE8EDF8), Color(0xFF2F4FA8)),
  (Color(0xFFE6F2EA), Color(0xFF1F7A4A)),
  (Color(0xFFFBEFD9), Color(0xFF8A5200)),
];

/// Ada göre kararlı ton; koyu temada zemin yazı renginin saydam hali, yazı açılır.
(Color, Color) kulupTone(BuildContext context, String? name) {
  final n = (name ?? '').trim();
  var h = 0;
  for (final r in n.runes) {
    h = (h * 31 + r) & 0x7fffffff;
  }
  final (bg, fg) = _tones[h % _tones.length];
  if (Theme.of(context).brightness == Brightness.dark) {
    final light = Color.lerp(fg, Colors.white, .45)!;
    return (fg.withValues(alpha: .28), light);
  }
  return (bg, fg);
}

/// Baş harfli tonlu daire; fotoğraf varsa onu gösterir.
class KulupAvatar extends StatelessWidget {
  const KulupAvatar({super.key, required this.name, this.url, this.size = 42});

  final String? name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) return BuAvatar(name: name, url: url, size: size);
    final (bg, fg) = kulupTone(context, name);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text(initialsOf(name), style: BuType.label.copyWith(fontWeight: FontWeight.w800, color: fg)),
      ),
    );
  }
}

/// Rol etiketi (Yönetici / Moderatör): yumuşak zemin, 22 dp yükseklik.
class KulupRoleBadge extends StatelessWidget {
  const KulupRoleBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(11)),
      child: Text(text, maxLines: 1, style: BuType.micro.copyWith(fontWeight: FontWeight.w700, color: t.onSoft)),
    );
  }
}

/// Yuvarlak köşeli, çizgili, gölgeli açılır menü biçimi (tasarımdaki .mn).
ShapeBorder kulupMenuShape(BuildContext context) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: context.bu.bd));

/// Menü satırı: 44 dp en az yükseklik; [danger] kırmızı yazı; [count] sağda kırmızı sayı hapı.
class KulupMenuRow extends StatelessWidget {
  const KulupMenuRow(this.label, {super.key, this.danger = false, this.count});

  final String label;
  final bool danger;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Row(
      children: [
        Expanded(
          child: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BuType.bodyStrong.copyWith(color: danger ? t.pr : t.ink)),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(minWidth: 22),
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.pr, borderRadius: BorderRadius.circular(11)),
            child: Text('$count', style: BuType.micro.copyWith(fontWeight: FontWeight.w700, color: t.onPr)),
          ),
        ],
      ],
    );
  }
}

/// Üç noktalı (⋯) yatay menü simgesi, dolgulu daireler.
class KulupDots extends StatelessWidget {
  const KulupDots({super.key, this.size = 20, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.more_horiz_rounded, size: size + 2, color: color ?? context.bu.mut);
}

/// Girdi alanı: 1.5 dp çizgi, 16 dp köşe (tasarımdaki .fd/.fa). [error] varsa kırmızı çizgi.
InputDecoration kulupField(BuildContext context, {String? hint, String? error, EdgeInsetsGeometry? pad}) {
  final t = context.bu;
  OutlineInputBorder b(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: 1.5));
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: t.mut),
    errorText: error,
    counterText: '',
    filled: true,
    fillColor: t.sf,
    contentPadding: pad ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: b(error != null ? t.pr : t.bd),
    focusedBorder: b(t.pr),
    errorBorder: b(t.pr),
    focusedErrorBorder: b(t.pr),
    border: b(t.bd),
  );
}

enum KulupPillKind { primary, soft, outline }

/// 44 dp, 14 dp köşeli üyelik / sohbet düğmesi. [staticLook] true: dokunulmaz durum etiketi ("Üyesin").
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
    final (bg, fg, side) = switch (kind) {
      KulupPillKind.primary => (t.pr, t.onPr, BorderSide.none),
      KulupPillKind.soft => (t.soft, t.onSoft, BorderSide.none),
      KulupPillKind.outline => (t.sf, t.ink, BorderSide(color: t.bd)),
    };
    final content = busy
        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
              Flexible(
                child: Text(label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: BuType.bodyStrong.copyWith(fontWeight: FontWeight.w700, color: fg)),
              ),
            ],
          );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: side);
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Center(heightFactor: 1, child: content),
      ),
    );
    return Material(
      color: bg,
      shape: shape,
      shadowColor: t.pr.withValues(alpha: .7),
      elevation: 0,
      child: staticLook
          ? body
          : InkWell(customBorder: shape, onTap: busy ? null : onPressed, child: body),
    );
  }
}

/// 48 dp, 14 dp köşeli işlem düğmesi (başvuru Reddet / Onayla).
class KulupActionButton extends StatelessWidget {
  const KulupActionButton({super.key, required this.label, required this.onPressed, this.primary = false});

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fg = primary ? t.onPr : t.ink;
    final bg = primary ? t.pr : t.sf;
    return Material(
      color: onPressed == null ? bg.withValues(alpha: .6) : bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: primary ? BorderSide.none : BorderSide(color: t.bd, width: 1.5),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            heightFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: BuType.heading.copyWith(color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}
