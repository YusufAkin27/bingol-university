import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

// Akademik: Stitch v3 ortak parçalar (docs/design/BIREBIR_AKADEMIK.md). Kartsız satır + 1 dp `bd` ayraç, metin
// sekmeleri (2 dp marka alt çizgisi), `pr` metin eylemleri, 48 dp kenarlıklı alanlar. Renk yalnız belirteçlerden.

/// 1 dp ayraç (`bd`). [inset]: başlangıçtan boşluk.
class AcadRule extends StatelessWidget {
  const AcadRule({super.key, this.inset = 0});

  final double inset;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.only(start: inset),
        child: SizedBox(height: 1, width: double.infinity, child: ColoredBox(color: context.bu.bd)),
      );
}

/// Metin sekmeleri: seçili = `ink` kalın metin + 2 dp `pr` alt çizgi; 20 dp girintili 1 dp ayraç. Dar ekranda kayar.
/// Yükseklik 42 dp; her sekme >= 48 dp geniş dokunma alanı.
class AcadTabs extends StatelessWidget {
  const AcadTabs({super.key, required this.labels, required this.index, required this.onChanged, this.padding = const EdgeInsetsDirectional.symmetric(horizontal: 20)});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final EdgeInsetsGeometry padding;

  static const double height = 42;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Stack(children: [
      PositionedDirectional(start: 20, end: 20, bottom: 0, child: SizedBox(height: 1, child: ColoredBox(color: t.bd))),
      SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: padding,
          itemCount: labels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 24),
          itemBuilder: (_, i) {
            final on = i == index;
            return Semantics(
              button: true,
              selected: on,
              label: labels[i],
              excludeSemantics: true,
              onTap: () => onChanged(i),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!on) buHaptic(BuHaptic.selection);
                  onChanged(i);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 48),
                  child: Stack(children: [
                    Center(
                      widthFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: AnimatedDefaultTextStyle(
                          duration: BuMotion.of(context, BuMotion.short),
                          curve: BuMotion.standard,
                          style: tx.bodyLarge!.copyWith(fontSize: 16, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? t.ink : t.mut),
                          child: Text(labels[i], maxLines: 1, softWrap: false),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedContainer(
                        duration: BuMotion.of(context, BuMotion.short),
                        curve: BuMotion.standard,
                        height: 2,
                        color: on ? t.pr : t.pr.withValues(alpha: 0),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/// `pr` metin eylemi (kutusuz): 14 sp/600, dokunma alanı >= 48 dp.
class AcadTextAction extends StatelessWidget {
  const AcadTextAction(this.label, {super.key, required this.onTap, this.size = 14, this.weight = FontWeight.w600, this.color, this.semanticLabel, this.top = false});

  final String label;
  final VoidCallback? onTap;
  final double size;
  final FontWeight weight;
  final Color? color;
  final String? semanticLabel;

  /// true: metin 48 dp dokunma kutusunun üstüne hizalanır (Stitch'te yüksekliği 48'den az satırlar için).
  final bool top;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final c = onTap == null ? t.mut : (color ?? t.pr);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        onTap: onTap,
        scale: .97,
        haptic: BuHaptic.selection,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BuSize.touch, minWidth: BuSize.touch),
          child: Align(
            alignment: top ? AlignmentDirectional.topCenter : Alignment.center,
            widthFactor: 1,
            child: Padding(
              padding: EdgeInsets.only(top: top ? 8 : 0),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: size, fontWeight: weight, color: c)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartsız dokunulabilir satır: en az [minHeight] (76 dp), dikey ortalı, altta 1 dp ayraç (isteğe bağlı).
class AcadRow extends StatelessWidget {
  const AcadRow({super.key, required this.child, this.onTap, this.semanticLabel, this.minHeight = 77, this.rule = true, this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12), this.ruleInset = 0});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double minHeight;
  final bool rule;
  final EdgeInsets padding;
  final double ruleInset;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: padding,
      child: ConstrainedBox(constraints: BoxConstraints(minHeight: minHeight - 1 - (padding.vertical)), child: Align(alignment: AlignmentDirectional.centerStart, child: child)),
    );
    final tappable = onTap == null
        ? body
        : Semantics(
            button: true,
            label: semanticLabel,
            excludeSemantics: semanticLabel != null,
            onTap: onTap,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () {
                  buHaptic(BuHaptic.selection);
                  onTap!();
                },
                child: body,
              ),
            ),
          );
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      tappable,
      if (rule) Padding(padding: const EdgeInsetsDirectional.symmetric(horizontal: 20), child: AcadRule(inset: ruleInset)),
    ]);
  }
}

/// Alan etiketi (ink 13.5 sp/600) + alan gövdesi + isteğe bağlı hata satırı (danger 12.5 sp).
class AcadLabeled extends StatelessWidget {
  const AcadLabeled({super.key, required this.label, required this.child, this.error, this.gap = 8});

  final String label;
  final Widget child;
  final String? error;

  /// Etiket ile alan arası boşluk (çip satırında dokunma kutusunun üst payı için daha az).
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsetsDirectional.only(bottom: gap),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: t.ink)),
      ),
      child,
      AnimatedSize(
        duration: BuMotion.of(context, BuMotion.short),
        curve: BuMotion.standard,
        alignment: Alignment.topCenter,
        child: error == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Semantics(
                  liveRegion: true,
                  child: Text(error!, style: tx.bodySmall!.copyWith(color: t.danger, fontWeight: FontWeight.w500, height: 1.2)),
                ),
              ),
      ),
    ]);
  }
}

/// Alan kutusu dekorasyonu: beyaz yüzey, 1 dp `bdStrong` (hatada 1.5 dp `danger`), 16 dp köşe.
BoxDecoration acadFieldBox(BuildContext context, {bool error = false}) {
  final t = context.bu;
  return BoxDecoration(
    color: t.sf,
    borderRadius: BuRadius.bMd,
    border: Border.all(color: error ? t.danger : t.bdStrong, width: error ? 1.5 : 1),
  );
}

/// Metin alanı (48 dp): etiketli, beyaz, çerçeveli. Hata verilirse `danger` çerçeve + altta hata metni.
class AcadTextField extends StatelessWidget {
  const AcadTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.maxLength,
    this.capitalization = TextCapitalization.none,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint, error;
  final int? maxLength;
  final TextCapitalization capitalization;
  final int? minLines, maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(borderRadius: BuRadius.bMd, borderSide: BorderSide(color: c, width: w));
    final err = error != null;
    return AcadLabeled(
      label: label,
      error: error,
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        textCapitalization: capitalization,
        onChanged: onChanged,
        style: tx.bodyLarge!.copyWith(color: t.ink),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          filled: true,
          fillColor: t.sf,
          isDense: true,
          hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          enabledBorder: b(err ? t.danger : t.bdStrong, err ? 1.5 : 1),
          focusedBorder: b(err ? t.danger : t.pr, 2),
        ),
      ),
    );
  }
}

/// Seçici alan (48 dp): dokununca seçici açar; [trailing] simgesi sağda (takvim/saat/chevron).
class AcadPicker extends StatelessWidget {
  const AcadPicker({super.key, required this.label, required this.onTap, this.value, this.hint, this.trailing, this.error});

  final String label;
  final String? value, hint, error;
  final IconData? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final shown = value ?? hint ?? '';
    return AcadLabeled(
      label: label,
      error: error,
      child: Semantics(
        button: true,
        label: label,
        value: shown,
        excludeSemantics: true,
        onTap: onTap,
        child: BuPressable(
          onTap: onTap,
          haptic: BuHaptic.selection,
          scale: .985,
          child: Container(
            constraints: const BoxConstraints(minHeight: BuSize.touch),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: acadFieldBox(context, error: error != null),
            child: Row(children: [
              Expanded(child: Text(shown, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(color: value == null ? t.mut : t.ink))),
              if (trailing != null) ...[const SizedBox(width: 8), ExcludeSemantics(child: Icon(trailing, size: 20, color: t.mut))],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Küçük "pr" nokta (okunmamış/bugün).
class AcadDot extends StatelessWidget {
  const AcadDot({super.key, this.size = 6, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: Container(width: size, height: size, decoration: BoxDecoration(color: color ?? context.bu.pr, shape: BoxShape.circle)));
}

/// Kehribar not (ikonsuz): `warnSoft` zemin, 14 dp köşe, 16 dp iç boşluk; [action] metin eylemi altta.
class AcadAmberNote extends StatelessWidget {
  const AcadAmberNote({super.key, required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(color: t.warnSoft, borderRadius: BuRadius.bMd),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: tx.bodyLarge!.copyWith(color: t.onWarnSoft, height: 1.4)),
          if (actionLabel != null) AcadTextAction(actionLabel!, onTap: onAction, size: 15, weight: FontWeight.w700) else const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

/// Muted, ortalı tek satır durum metni (boş/hata) + isteğe bağlı `pr` metin eylemi.
class AcadStateText extends StatelessWidget {
  const AcadStateText({super.key, required this.text, this.actionLabel, this.onAction, this.top = 32});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double top;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, top, 20, 8),
      child: Column(children: [
        Semantics(liveRegion: true, child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut))),
        if (actionLabel != null) AcadTextAction(actionLabel!, onTap: onAction, size: 15, weight: FontWeight.w700),
      ]),
    );
  }
}

/// Yükleniyor iskeleti: satır başına iki çubuk (kartsız).
class AcadRowsSkeleton extends StatelessWidget {
  const AcadRowsSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: BuSkeletonScope(
          child: Column(children: [
            for (var i = 0; i < count; i++)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BuSkeleton.line(width: 190, height: 18),
                  SizedBox(height: 10),
                  BuSkeleton.line(width: 130, height: 13),
                ]),
              ),
          ]),
        ),
      );
}
