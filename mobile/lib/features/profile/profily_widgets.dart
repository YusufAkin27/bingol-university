import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../posts/social_api.dart';

/// Profil alt sayfaları (Pa1-Pa5) ortak bileşenleri: renkler `context.bu`; tasarımdaki sabit tonlar burada.

enum ProfilyTone { green, amber, violet, red, mute }

bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Rozet tonu (zemin, yazı). Açık/koyu temaya göre.
(Color, Color) profilyTone(BuildContext context, ProfilyTone tone) {
  final t = context.bu;
  final d = _dark(context);
  return switch (tone) {
    ProfilyTone.green => d ? (const Color(0xFF143A2E), const Color(0xFF7BD9B8)) : (const Color(0xFFE6F4EF), const Color(0xFF1F6B5A)),
    ProfilyTone.amber => d ? (const Color(0xFF3A2A12), const Color(0xFFF2B866)) : (const Color(0xFFFFF3E3), const Color(0xFF8A5410)),
    ProfilyTone.violet => d ? (const Color(0xFF2A2550), const Color(0xFFB7ACF5)) : (const Color(0xFFF1EEFB), const Color(0xFF4A3DB0)),
    ProfilyTone.red => (t.soft, t.pr),
    ProfilyTone.mute => (t.sf2, t.mut),
  };
}

/// Durum/rol rozeti (tasarımdaki .pill): 24 px yükseklik, 12 px köşe.
class ProfilyPill extends StatelessWidget {
  const ProfilyPill(this.label, {super.key, this.tone = ProfilyTone.red, this.small = false});

  final String label;
  final ProfilyTone tone;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = profilyTone(context, tone);
    return Container(
      constraints: BoxConstraints(minHeight: small ? 22 : 24),
      alignment: AlignmentDirectional.centerStart,
      padding: EdgeInsets.symmetric(horizontal: small ? 9 : 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(small ? 11 : 12)),
      child: Text(label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: BuType.caption.copyWith(fontSize: small ? 11.5 : 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// Kartın içindeki satır: iç boşluk + (varsa) dokunma.
class ProfilyRow extends StatelessWidget {
  const ProfilyRow({super.key, required this.child, this.onTap, this.minHeight = 72, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final double minHeight;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: padding ?? const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          child: child,
        ),
      );
}

/// Ad (15/700) + alt yazı (12.5) sütunu.
class ProfilyTitleBlock extends StatelessWidget {
  const ProfilyTitleBlock({super.key, required this.title, this.sub, this.pill, this.titleSize = 15});

  final String title;
  final String? sub;
  final Widget? pill;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: BuType.bodyStrong.copyWith(fontSize: titleSize, fontWeight: FontWeight.w700, color: t.ink)),
        if (sub != null && sub!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(sub!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BuType.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.mut)),
          ),
        if (pill != null) Padding(padding: const EdgeInsets.only(top: 4), child: pill),
      ],
    );
  }
}

/// İki parçalı sekme kutusu (Katıldıklarım | Oluşturduklarım, Takipçiler | Takip edilenler).
class ProfilyTabs extends StatelessWidget {
  const ProfilyTabs({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = _dark(context);
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              button: true,
              selected: i == index,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == index ? (dark ? Color.alphaBlend(t.ink.withValues(alpha: .12), t.sf2) : t.sf) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: i == index && !dark
                        ? const [BoxShadow(color: Color(0x59171E33), blurRadius: 12, offset: Offset(0, 4), spreadRadius: -8)]
                        : null,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(labels[i],
                        maxLines: 1,
                        style: BuType.bodyStrong.copyWith(
                            fontSize: 14, fontWeight: FontWeight.w700, color: i == index ? t.pr : t.mut)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Boş durum kartı: kırmızı yumuşak ikon zemini + başlık + açıklama (+ eylem). [horizontal] ikon solda.
class ProfilyEmptyCard extends StatelessWidget {
  const ProfilyEmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.horizontal = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = _dark(context);
    final tileSize = horizontal ? 52.0 : 64.0;
    final tile = ExcludeSemantics(
      child: Container(
        width: tileSize,
        height: tileSize,
        decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(horizontal ? 16 : 20)),
        child: Icon(icon, size: horizontal ? 26 : 30, color: t.pr),
      ),
    );
    final texts = Column(
      crossAxisAlignment: horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            textAlign: horizontal ? TextAlign.start : TextAlign.center,
            style: BuType.heading.copyWith(fontSize: horizontal ? 15 : 16, fontWeight: FontWeight.w800, color: t.ink)),
        const SizedBox(height: 4),
        Text(body,
            textAlign: horizontal ? TextAlign.start : TextAlign.center,
            style: BuType.body.copyWith(fontSize: 13.5, height: 1.45, color: t.mut)),
        if (action != null) Padding(padding: const EdgeInsets.only(top: 14), child: action),
      ],
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: horizontal ? 18 : 26),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.bd),
        boxShadow: dark
            ? null
            : const [BoxShadow(color: Color(0x40171E33), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -12)],
      ),
      child: Semantics(
        container: true,
        child: horizontal
            ? Row(children: [tile, const SizedBox(width: 14), Expanded(child: texts)])
            : Column(mainAxisSize: MainAxisSize.min, children: [tile, const SizedBox(height: 12), texts]),
      ),
    );
  }
}

/// Tam genişlikli ana düğme (56 px, 18 px köşe, kırmızı gölge): tasarımdaki .btn.
class ProfilyPrimaryButton extends StatelessWidget {
  const ProfilyPrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: _dark(context) || !enabled
              ? null
              : const [BoxShadow(color: Color(0x99C62A20), blurRadius: 26, offset: Offset(0, 14), spreadRadius: -12)],
        ),
        child: Material(
          color: enabled ? t.pr : t.pr.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            excludeFromSemantics: true,
            onTap: enabled ? onPressed : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Center(
                heightFactor: 1,
                child: busy
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: t.onPr))
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (icon != null) ...[Icon(icon, size: 20, color: t.onPr), const SizedBox(width: 8)],
                          Flexible(
                            child: Text(label,
                                textAlign: TextAlign.center,
                                style: BuType.heading.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: t.onPr)),
                          ),
                        ]),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Takip et / Takiptesin düğmesi (44 px, 14 px köşe). İyimser günceller; hata olursa geri alır.
class ProfilyFollowButton extends StatefulWidget {
  const ProfilyFollowButton({super.key, required this.session, required this.userId, required this.followed, this.onChanged});

  final Session session;
  final int userId;
  final bool followed;
  final ValueChanged<bool>? onChanged;

  @override
  State<ProfilyFollowButton> createState() => _ProfilyFollowButtonState();
}

class _ProfilyFollowButtonState extends State<ProfilyFollowButton> {
  late bool _followed = widget.followed;
  bool _busy = false;

  @override
  void didUpdateWidget(ProfilyFollowButton old) {
    super.didUpdateWidget(old);
    if (old.followed != widget.followed && !_busy) _followed = widget.followed;
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final want = !_followed;
    setState(() {
      _busy = true;
      _followed = want;
    });
    widget.onChanged?.call(want);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final api = SocialApi(widget.session);
    try {
      await (want ? api.follow(widget.userId) : api.unfollow(widget.userId));
    } catch (e) {
      if (mounted) setState(() => _followed = !want);
      widget.onChanged?.call(!want);
      messenger?.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final on = !_followed; // "Takip et" dolu kırmızı; "Takiptesin" çizgili
    return Semantics(
      button: true,
      toggled: _followed,
      label: _followed ? context.l10n.followButtonUnfollow : context.l10n.followButtonFollow,
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('followButton'),
        color: on ? t.pr : t.sf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: on ? BorderSide.none : BorderSide(color: t.bd, width: 1.5),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: _busy ? null : _toggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 96),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  _followed ? context.l10n.profilyardFollowingYou : context.l10n.followButtonFollow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BuType.bodyStrong.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? t.onPr : t.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Düz renkli açıklama kutusu (Pa1 üstündeki not).
class ProfilyNote extends StatelessWidget {
  const ProfilyNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.bd),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ExcludeSemantics(child: Icon(LucideIcons.info, size: 16, color: t.mut)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: BuType.body.copyWith(fontSize: 13, height: 1.45, color: t.mut))),
      ]),
    );
  }
}

/// Arama kutusu: 56 px, 16 px köşe, başta büyüteç (tasarımdaki .in + simge).
class ProfilySearchField extends StatelessWidget {
  const ProfilySearchField({super.key, required this.controller, required this.hint, required this.label, this.onChanged});

  final TextEditingController controller;
  final String hint;
  final String label;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    OutlineInputBorder b(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: 1.5));
    return Semantics(
      label: label,
      textField: true,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: BuType.body.copyWith(fontSize: 16, color: t.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: BuType.body.copyWith(fontSize: 16, color: t.mut),
          filled: true,
          fillColor: t.sf,
          constraints: const BoxConstraints(minHeight: 56),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: ExcludeSemantics(child: Icon(LucideIcons.search, size: 20, color: t.mut)),
          prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 56),
          enabledBorder: b(t.bd),
          focusedBorder: b(t.pr),
          border: b(t.bd),
        ),
      ),
    );
  }
}

/// Tür seçim çipi (Öneri / Hata / Diğer): 48 px, 16 px köşe; seçiliyken yumuşak kırmızı zemin.
class ProfilyTypeChip extends StatelessWidget {
  const ProfilyTypeChip({super.key, required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fg = selected ? t.pr : t.ink;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? t.soft : t.sf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? t.pr : t.bd, width: 1.5),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          excludeFromSemantics: true,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Center(
                heightFactor: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    ExcludeSemantics(child: Icon(icon, size: 18, color: fg)),
                    const SizedBox(width: 6),
                    Text(label, maxLines: 1, style: BuType.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Form alanı (56 px / çok satırda 160 px, 16 px köşe). [counter] true: sağ altta "n / max".
class ProfilyField extends StatelessWidget {
  const ProfilyField({
    super.key,
    required this.controller,
    required this.hint,
    required this.label,
    required this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.counter = false,
  });

  final TextEditingController controller;
  final String hint;
  final String label;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final bool counter;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    OutlineInputBorder b(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: 1.5));
    return Semantics(
      label: label,
      textField: true,
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        style: BuType.body.copyWith(fontSize: 16, height: 1.45, color: t.ink),
        buildCounter: (ctx, {required currentLength, required isFocused, maxLength}) => counter
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(ctx.l10n.profilyardFbCounter('$currentLength', '$maxLength'),
                    style: BuType.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.mut)),
              )
            : const SizedBox.shrink(),
        decoration: InputDecoration(
          hintText: hint,
          alignLabelWithHint: true,
          hintStyle: BuType.body.copyWith(fontSize: 16, color: t.mut),
          filled: true,
          fillColor: t.sf,
          constraints: BoxConstraints(minHeight: maxLines > 1 ? 160 : 56),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: b(t.bd),
          focusedBorder: b(t.pr),
          border: b(t.bd),
        ),
      ),
    );
  }
}
