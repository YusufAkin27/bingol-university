import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Kulüp ekranlarının (K7: 27-30 referansları) ortak yapı taşları: diyalog kartı, simge kutusu, sayfa-içi satır,
/// açılır menü, kilit/bilgi kartları. Yalnız `context.bu` belirteçleri kullanılır.

// ---------------------------------------------------------------------------------------------------------------
// Düğmeler

enum ClubBtnKind { neutral, danger, primary, ink }

/// Diyalog/sheet düğmesi: 48 dp, 16 dp köşe, ortalanmış simge + etiket. Pasifken soluk.
class ClubBtn extends StatelessWidget {
  const ClubBtn({super.key, required this.label, required this.onPressed, this.kind = ClubBtnKind.neutral, this.icon, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final ClubBtnKind kind;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final (bg, fg) = switch (kind) {
      ClubBtnKind.neutral => (t.sf2, t.ink),
      ClubBtnKind.danger => (t.danger, t.onPr),
      ClubBtnKind.primary => (t.pr, t.onPr),
      ClubBtnKind.ink => (t.ink, t.bg),
    };
    final on = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: on,
      label: label,
      child: ExcludeSemantics(
        child: BuPressable(
          scale: .98,
          enabled: on,
          onTap: on
              ? () {
                  buHaptic(BuHaptic.selection);
                  onPressed!();
                }
              : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: on || busy ? bg : bg.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(BuRadius.md),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy) ...[
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
                  const SizedBox(width: 8),
                ] else if (icon != null) ...[
                  Icon(icon, size: 17, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: fg, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Simge kutusu / daire

/// Yuvarlatılmış kare (ya da daire) içinde simge: tonlu zemin. [danger] marka-kırmızı tonu verir.
class ClubIconBox extends StatelessWidget {
  const ClubIconBox({super.key, required this.icon, this.size = 40, this.danger = false, this.circle = false, this.iconSize});

  final IconData icon;
  final double size;
  final bool danger;
  final bool circle;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: danger ? t.soft : t.sf2,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(size * .3),
        ),
        child: Icon(icon, size: iconSize ?? size * .46, color: danger ? t.pr : t.ink),
      ),
    );
  }
}

/// Alt sayfa / menü satırı: simge kutusu + başlık (+ alt yazı) + ok. [danger] kırmızı.
class ClubSheetRow extends StatelessWidget {
  const ClubSheetRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.danger = false,
    this.circle = false,
    this.trailing,
    this.showChevron = true,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool danger;
  final bool circle;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              buHaptic(BuHaptic.selection);
              onTap!();
            },
      borderRadius: BorderRadius.circular(BuRadius.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(
            children: [
              ClubIconBox(icon: icon, danger: danger, circle: circle),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tx.titleSmall!.copyWith(color: danger ? t.pr : t.ink, fontWeight: FontWeight.w700)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tx.bodySmall!.copyWith(color: danger ? t.pr : t.mut)),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (showChevron) ...[
                const SizedBox(width: 8),
                ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: danger ? t.pr : t.mut)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Diyalog

/// Referans diyalog kartı (28 dp köşe): üstte simge (daire ya da sol kutu), başlık, metin, isteğe bağlı gövde, eylem satırı.
/// [leading] true: simge solda başlıkla yan yana (üye çıkar/yasakla); false: ortalı (ayrıl, sil, bilgi).
class ClubDialogCard extends StatelessWidget {
  const ClubDialogCard({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.boldName,
    this.content,
    required this.actions,
    this.leading = false,
    this.danger = true,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Metnin başındaki ad kalın yazılır (üye diyalogları).
  final String? boldName;
  final Widget? content;
  final List<Widget> actions;
  final bool leading;
  final bool danger;

  /// Simge dairesinin köşesindeki küçük rozet simgesi.
  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final msgStyle = tx.bodyMedium!.copyWith(color: t.mut, height: 1.45);
    Widget? msg;
    if (message != null) {
      final n = boldName;
      final at = (n == null || n.isEmpty) ? -1 : message!.indexOf(n);
      if (n != null && at >= 0) {
        msg = Text.rich(
          TextSpan(children: [
            TextSpan(text: message!.substring(0, at)),
            TextSpan(text: n, style: msgStyle.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
            TextSpan(text: message!.substring(at + n.length)),
          ]),
          style: msgStyle,
          textAlign: leading ? TextAlign.start : TextAlign.center,
        );
      } else {
        msg = Text(message!, style: msgStyle, textAlign: leading ? TextAlign.start : TextAlign.center);
      }
    }
    final iconW = leading
        ? ClubIconBox(icon: icon, size: 48, danger: danger)
        : Stack(
            clipBehavior: Clip.none,
            children: [
              ClubIconBox(icon: icon, size: 64, danger: danger, circle: true, iconSize: 28),
              if (badge != null)
                PositionedDirectional(
                  end: -4,
                  bottom: -4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.sf3, width: 2)),
                    child: Icon(badge, size: 13, color: t.onPr),
                  ),
                ),
            ],
          );
    return Dialog(
      backgroundColor: t.sf3,
      elevation: 0,
      surfaceTintColor: t.sf3.withValues(alpha: 0),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.xl)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: leading ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            if (leading)
              Row(
                children: [
                  iconW,
                  const SizedBox(width: 14),
                  Expanded(child: Semantics(header: true, child: Text(title, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)))),
                ],
              )
            else ...[
              iconW,
              const SizedBox(height: 16),
              Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
            ],
            if (msg != null) ...[SizedBox(height: leading ? 10 : 8), msg],
            if (content != null) ...[const SizedBox(height: 16), content!],
            const SizedBox(height: 22),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Açılır menü (⋯)

class ClubMenuEntry {
  const ClubMenuEntry(this.value, this.icon, this.label, {this.danger = false, this.count = 0, this.dividerBefore = false});

  final String value;
  final IconData icon;
  final String label;
  final bool danger;
  final int count;
  final bool dividerBefore;
}

/// [anchor] bağlamının (⋯ düğmesi) altında açılan simgeli açılır menü; seçilen `value` ya da null.
Future<String?> showClubDropdown(BuildContext anchor, List<ClubMenuEntry> entries) {
  final t = anchor.bu;
  final tx = Theme.of(anchor).textTheme;
  final box = anchor.findRenderObject() as RenderBox;
  final overlay = Navigator.of(anchor).overlay!.context.findRenderObject() as RenderBox;
  final rect = Rect.fromPoints(
    box.localToGlobal(Offset.zero, ancestor: overlay),
    box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
  );
  final pos = RelativeRect.fromRect(rect, Offset.zero & overlay.size);
  return showMenu<String>(
    context: anchor,
    position: pos,
    color: t.sf3,
    surfaceTintColor: t.sf3.withValues(alpha: 0),
    elevation: 4,
    shadowColor: t.shadow.withValues(alpha: .18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md), side: BorderSide(color: t.bd)),
    constraints: const BoxConstraints(minWidth: 224),
    items: [
      for (final e in entries) ...[
        if (e.dividerBefore) const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          value: e.value,
          height: 48,
          child: Row(
            children: [
              ExcludeSemantics(child: Icon(e.icon, size: 20, color: e.danger ? t.pr : t.ink)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(e.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.titleSmall!.copyWith(color: e.danger ? t.pr : t.ink, fontWeight: FontWeight.w600)),
              ),
              if (e.count > 0) ...[const SizedBox(width: 10), BuCountBadge(e.count)],
            ],
          ),
        ),
      ],
    ],
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Bilgi / kilit kartları

/// Ortalanmış kilit/boş içerik kartı (özel kulüp, bekleyen istek, yasak).
class ClubLockCard extends StatelessWidget {
  const ClubLockCard({super.key, required this.icon, required this.title, required this.body, this.badge = LucideIcons.shield});

  final IconData icon;
  final String title;
  final String body;
  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return BuCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClubIconBox(icon: icon, size: 56, danger: true, circle: true, iconSize: 26),
                if (badge != null)
                  PositionedDirectional(
                    end: -4,
                    bottom: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle, border: Border.all(color: t.bd)),
                      child: Icon(badge, size: 12, color: t.pr),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
          ],
        ),
      ),
    );
  }
}

/// Simge kutulu bilgi/uyarı kartı: başlık + gövde (+ isteğe bağlı eylem). [tone]: soft (kırmızı), warn (kehribar), neutral.
enum ClubNoteTone { soft, warn, neutral }

class ClubNoteCard extends StatelessWidget {
  const ClubNoteCard({super.key, required this.icon, required this.title, this.body, this.tone = ClubNoteTone.neutral, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final ClubNoteTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final (bg, fg, iconBg) = switch (tone) {
      ClubNoteTone.soft => (t.soft, t.onSoft, t.pr.withValues(alpha: .14)),
      ClubNoteTone.warn => (t.warnSoft, t.onWarnSoft, t.warn.withValues(alpha: .18)),
      ClubNoteTone.neutral => (t.sf, t.ink, t.soft),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BuRadius.lg),
        border: tone == ClubNoteTone.neutral ? Border.all(color: t.bd) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: tone == ClubNoteTone.warn ? t.warn : t.pr),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tx.titleSmall!.copyWith(color: fg, fontWeight: FontWeight.w800)),
                if (body != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(body!, style: tx.bodyMedium!.copyWith(color: tone == ClubNoteTone.neutral ? t.mut : fg, height: 1.4))),
                if (action != null) Padding(padding: const EdgeInsets.only(top: 10), child: action),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
