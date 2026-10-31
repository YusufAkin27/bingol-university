import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/social_api.dart';

/// Profil alt sayfaları (Pa1-Pa5) ortak bileşenleri: renkler `context.bu` belirteçleri ve M3 yazı ölçeği.

enum ProfilyTone { green, amber, violet, red, mute }

/// Rozet tonu (zemin, yazı): açık/koyu temaya göre tasarım sistemi renklerinden.
(Color, Color) profilyTone(BuildContext context, ProfilyTone tone) {
  final t = context.bu;
  return switch (tone) {
    ProfilyTone.green => (t.okSoft, t.ok),
    ProfilyTone.amber => (t.warnSoft, t.onWarnSoft),
    ProfilyTone.violet => (t.aquaSoft, t.onAquaSoft), // eski ad; renk artık su mavisi
    ProfilyTone.red => (t.soft, t.onSoft),
    ProfilyTone.mute => (t.sf2, t.mut),
  };
}

/// Durum/rol rozeti: hap, 24 dp yükseklik.
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
      padding: EdgeInsets.symmetric(horizontal: small ? 9 : 10, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bPill),
      child: Text(label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: fg)),
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

/// Ad (15/700) + alt yazı sütunu.
class ProfilyTitleBlock extends StatelessWidget {
  const ProfilyTitleBlock({super.key, required this.title, this.sub, this.pill, this.titleSize = 15});

  final String title;
  final String? sub;
  final Widget? pill;

  /// Eski parametre (yazı ölçeği artık temadan gelir); yok sayılır.
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
        if (sub != null && sub!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(sub!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tx.bodySmall!.copyWith(fontWeight: FontWeight.w500, color: t.mut)),
          ),
        if (pill != null) Padding(padding: const EdgeInsets.only(top: 4), child: pill),
      ],
    );
  }
}

/// İki parçalı sekme kutusu (Katıldıklarım | Oluşturduklarım, Takipçiler | Takip edilenler): kayan seçili parça.
class ProfilyTabs extends StatelessWidget {
  const ProfilyTabs({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
        child: BuSegmented(items: labels, index: index, onChanged: onChanged),
      );
}

/// Boş durum kartı: yumuşak halkalı simge + başlık + açıklama (+ eylem). [horizontal] simge solda.
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
    final tx = Theme.of(context).textTheme;
    final tileSize = horizontal ? 52.0 : 72.0;
    // Dış halka + iç daire: boş durumda "boş kutu" yerine yumuşak, ödüllendirici bir vurgu.
    final tile = ExcludeSemantics(
      child: Container(
        width: tileSize,
        height: tileSize,
        decoration: BoxDecoration(shape: BoxShape.circle, color: t.soft.withValues(alpha: .55)),
        alignment: Alignment.center,
        child: Container(
          width: tileSize * .72,
          height: tileSize * .72,
          decoration: BoxDecoration(shape: BoxShape.circle, color: t.soft),
          child: Icon(icon, size: horizontal ? 24 : 28, color: t.onSoft),
        ),
      ),
    );
    final texts = Column(
      crossAxisAlignment: horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            textAlign: horizontal ? TextAlign.start : TextAlign.center,
            style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
        const SizedBox(height: 4),
        Text(body,
            textAlign: horizontal ? TextAlign.start : TextAlign.center,
            style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
        if (action != null) Padding(padding: const EdgeInsets.only(top: 16), child: action),
      ],
    );
    return BuCard(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: horizontal ? 18 : 28),
      child: SizedBox(
        width: double.infinity,
        child: Semantics(
          container: true,
          child: horizontal
              ? Row(children: [tile, const SizedBox(width: 14), Expanded(child: texts)])
              : Column(mainAxisSize: MainAxisSize.min, children: [tile, const SizedBox(height: 14), texts]),
        ),
      ),
    );
  }
}

/// Tam genişlikli ana düğme ([BuButton] birincil): yükleniyor durumunda etiket yerine düğme içi çember.
class ProfilyPrimaryButton extends StatelessWidget {
  const ProfilyPrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) => BuButton(label: label, icon: icon, busy: busy, onPressed: onPressed);
}

/// Takip et / Takiptesin düğmesi. İyimser günceller; hata olursa geri alır. "Takip et" dolu marka, "Takiptesin" tonal.
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
    buHaptic(want ? BuHaptic.light : BuHaptic.selection);
    setState(() {
      _busy = true;
      _followed = want;
    });
    widget.onChanged?.call(want);
    final api = SocialApi(widget.session);
    try {
      await (want ? api.follow(widget.userId) : api.unfollow(widget.userId));
    } catch (e) {
      if (mounted) {
        setState(() => _followed = !want);
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      }
      widget.onChanged?.call(!want);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final on = !_followed; // "Takip et" dolu marka; "Takiptesin" tonal
    return Semantics(
      button: true,
      toggled: _followed,
      label: _followed ? context.l10n.followButtonUnfollow : context.l10n.followButtonFollow,
      excludeSemantics: true,
      child: AnimatedContainer(
        key: const ValueKey('followButton'),
        duration: BuMotion.of(context, BuMotion.short),
        curve: BuMotion.standard,
        decoration: ShapeDecoration(
          color: on ? t.pr : t.sf2,
          shape: StadiumBorder(side: on ? BorderSide.none : BorderSide(color: t.bd)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: _busy ? null : _toggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 96),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: AnimatedSwitcher(
                  duration: BuMotion.of(context, BuMotion.short),
                  child: Row(
                    key: ValueKey(_followed),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_followed ? LucideIcons.userCheck : LucideIcons.userPlus, size: 16, color: on ? t.onPr : t.ink),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _followed ? context.l10n.profilyardFollowingYou : context.l10n.followButtonFollow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge!
                              .copyWith(fontWeight: FontWeight.w700, color: on ? t.onPr : t.ink),
                        ),
                      ),
                    ],
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
        color: t.sf2,
        borderRadius: BuRadius.bMd,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ExcludeSemantics(child: Icon(LucideIcons.info, size: 16, color: t.mut)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1.45, color: t.mut))),
      ]),
    );
  }
}

/// Arama kutusu ([BuSearchField]: odak halkası + temizle), erişilebilirlik etiketiyle.
class ProfilySearchField extends StatelessWidget {
  const ProfilySearchField({super.key, required this.controller, required this.hint, required this.label, this.onChanged});

  final TextEditingController controller;
  final String hint;
  final String label;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        textField: true,
        child: BuSearchField(hint: hint, controller: controller, onChanged: onChanged),
      );
}

/// Tür seçim çipi (Öneri / Hata / Diğer): 48 dp, 16 dp köşe; seçiliyken marka tonu.
class ProfilyTypeChip extends StatelessWidget {
  const ProfilyTypeChip({super.key, required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fg = selected ? t.onSoft : t.ink;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: BuMotion.of(context, BuMotion.short),
        curve: BuMotion.standard,
        decoration: ShapeDecoration(
          color: selected ? t.soft : t.sf,
          shape: RoundedRectangleBorder(
            borderRadius: BuRadius.bMd,
            side: BorderSide(color: selected ? t.pr : t.bd, width: selected ? 1.5 : 1),
          ),
        ),
        child: InkWell(
          customBorder: const RoundedRectangleBorder(borderRadius: BuRadius.bMd),
          excludeFromSemantics: true,
          onTap: () {
            if (!selected) buHaptic(BuHaptic.selection);
            onTap();
          },
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
                    Text(label,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: fg)),
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

/// Form alanı (çok satırda 160 dp, 16 dp köşe; tema doldurma + odak halkası). [counter] true: sağ altta "n / max".
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
    final tx = Theme.of(context).textTheme;
    return Semantics(
      label: label,
      textField: true,
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        style: tx.bodyLarge!.copyWith(height: 1.45, color: t.ink),
        buildCounter: (ctx, {required currentLength, required isFocused, maxLength}) => counter
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(ctx.l10n.profilyardFbCounter('$currentLength', '$maxLength'),
                    style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
              )
            : const SizedBox.shrink(),
        decoration: InputDecoration(
          hintText: hint,
          alignLabelWithHint: true,
          constraints: BoxConstraints(minHeight: maxLines > 1 ? 160 : 56),
        ),
      ),
    );
  }
}
