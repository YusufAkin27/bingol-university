import 'package:flutter/material.dart';

import '../../widgets/bu.dart';
import '../../widgets/common.dart' show niceDate;

// Anketler + Destek: Stitch v3 ortak parçaları (docs/design/BIREBIR_ANKET_DESTEK.md).
// Kartsız satır + ince `bd` ayraç, metin sekmeleri (2 dp marka alt çizgisi), beyaz 48 dp alan (1 dp `bdStrong`, r16),
// tek `pr` birincil düğme. Renk yalnız belirteçlerden; gölge/gradyan yok.

/// Sayfa kenar boşluğu (Stitch: 20 dp).
const double kAnketPad = 20;

/// Satır/başlık yazısı: 17 sp/600 (Stitch satır başlığı; ölçekte 17 yok, yerel boyut).
TextStyle anketRowTitle(BuildContext context) =>
    Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: context.bu.ink, height: 1.3);

/// Soluk ikincil satır: 14 sp muted.
TextStyle anketMeta(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.bu.mut, height: 1.4);

/// Metin sekmeleri: seçili = `pr` metin + 2 dp `pr` alt çizgi, dolu hap yok. Görünür gövde 30 dp, dokunma alanı 48 dp
/// (alt kısım boş). Dar ekranda/büyük yazıda yatay kayar.
class AnketTextTabs extends StatelessWidget {
  const AnketTextTabs({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  static const double height = 48;
  static const double visible = 26;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: kAnketPad),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 24),
        itemBuilder: (_, i) {
          final on = i == index;
          return Semantics(
            button: true,
            selected: on,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!on) buHaptic(BuHaptic.selection);
                onChanged(i);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    height: visible,
                    child: Stack(children: [
                      Center(
                        widthFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: AnimatedDefaultTextStyle(
                            duration: BuMotion.of(context, BuMotion.short),
                            curve: BuMotion.standard,
                            style: tx.bodyMedium!.copyWith(fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? t.pr : t.mut),
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
                  const Expanded(child: SizedBox.shrink()),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tam genişlik ince ayraç (`bd`, 1 dp); [inset] true ise yan kenar 20 dp.
class AnketRule extends StatelessWidget {
  const AnketRule({super.key, this.inset = true});

  final bool inset;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: inset ? kAnketPad : 0),
        child: Container(height: 1, color: context.bu.bd),
      );
}

/// Durum satırı (boş / hata): tek soluk satır + isteğe bağlı `pr` metin düğmesi. İkon/kart yok.
class AnketStateLine extends StatelessWidget {
  const AnketStateLine({super.key, required this.text, this.actionLabel, this.onAction, this.padding});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: padding ?? const EdgeInsetsDirectional.fromSTEB(kAnketPad, 20, kAnketPad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
          if (actionLabel != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: EdgeInsets.zero, alignment: AlignmentDirectional.centerStart),
                onPressed: onAction,
                child: Text(actionLabel!, style: tx.titleSmall!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Tek satırlık iskelet satırı (başlık + meta çubuğu), kartsız ayraçlı.
class AnketSkeletonRow extends StatelessWidget {
  const AnketSkeletonRow({super.key, this.titleWidth = 220});

  final double titleWidth;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 19, kAnketPad, 18),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.bu.bd))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BuSkeleton.line(width: titleWidth, height: 18),
          const SizedBox(height: 10),
          const BuSkeleton.line(width: 150, height: 12),
        ]),
      );
}

/// Alan etiketi: 13 sp muted/600, alanın üstünde; [trailing] (örn. "Zorunlu", "2 / 12") sağda soluk.
class AnketFieldLabel extends StatelessWidget {
  const AnketFieldLabel(this.text, {super.key, this.trailing, this.top = 0, this.bottom = 6.5});

  final String text;
  final String? trailing;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final style = tx.labelLarge!.copyWith(color: t.mut, fontSize: 13, fontWeight: FontWeight.w600);
    return Padding(
      padding: EdgeInsetsDirectional.only(top: top, bottom: bottom),
      child: Row(children: [
        Expanded(child: Semantics(header: true, child: Text(text, style: style))),
        if (trailing != null) Text(trailing!, style: tx.bodySmall!.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
      ]),
    );
  }
}

/// Beyaz alan süsü: 1 dp `bdStrong`, r16, odakta `pr` 1.5 dp; hata: `danger` 1.5 dp (beyaz dolgu korunur).
InputDecoration anketFieldDeco(BuildContext context,
    {String? hint, bool hasError = false, EdgeInsetsGeometry? pad, Widget? suffixIcon}) {
  final t = context.bu;
  OutlineInputBorder b(Color c, double w) => OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    counterText: '',
    filled: true,
    fillColor: t.sf,
    hintStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w400),
    isDense: true,
    constraints: const BoxConstraints(minHeight: 48),
    contentPadding: pad ?? const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 13),
    suffixIcon: suffixIcon,
    border: b(hasError ? t.danger : t.bdStrong, hasError ? 1.5 : 1),
    enabledBorder: b(hasError ? t.danger : t.bdStrong, hasError ? 1.5 : 1),
    focusedBorder: b(hasError ? t.danger : t.pr, 1.5),
  );
}

/// Alan altı hata satırı: `danger` 12.5 sp, ikonsuz.
class AnketFieldError extends StatelessWidget {
  const AnketFieldError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        container: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.bu.danger, height: 1.35)),
        ),
      );
}

/// Çerçeveli (outlined) 44 dp düğme, 48 dp dokunma alanı: "Oyumu geri çek", "Yoklama listesi" türü ikincil eylem.
class AnketOutlineButton extends StatelessWidget {
  const AnketOutlineButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: Center(
            child: Container(
              height: 44,
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: t.sf,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.bdStrong),
              ),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: onPressed == null ? t.mut : t.ink, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Düz not (uyarı): `warnSoft` zemin + `onWarnSoft` yazı, ikonsuz, r12.
class AnketAmberNote extends StatelessWidget {
  const AnketAmberNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        decoration: BoxDecoration(color: t.warnSoft, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.onWarnSoft, height: 1.45)),
      ),
    );
  }
}

/// Radyo/onay işareti (Stitch v3): [size] 20 dp. Kapalı: `sf2` dolu (çerçevesiz); açık: `pr` dolu + beyaz iç nokta
/// (radyo) ya da onay işareti ([square]). Geçiş yumuşak.
class AnketMarkFlat extends StatelessWidget {
  const AnketMarkFlat({super.key, required this.on, this.square = false, this.size = 20});

  final bool on;
  final bool square;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final d = BuMotion.of(context, BuMotion.short);
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: d,
        curve: BuMotion.standard,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: on ? t.pr : t.sf2,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(6) : null,
          border: on ? null : Border.all(color: t.bd),
        ),
        child: AnimatedScale(
          scale: on ? 1 : 0,
          duration: d,
          curve: Curves.easeOutBack,
          child: Center(
            child: square
                ? Icon(Icons.check_rounded, size: size - 4, color: t.onPr)
                : DecoratedBox(decoration: BoxDecoration(color: t.onPr, shape: BoxShape.circle), child: SizedBox(width: size * .4, height: size * .4)),
          ),
        ),
      ),
    );
  }
}

/// "12 Ekim" (bu yıl) ya da "12 Ekim 2025": ay adları l10n'dan gelir (intl yerel verisine bağlı değil).
String anketDayLabel(BuildContext context, DateTime d) {
  final full = niceDate(d.toIso8601String(), context: context);
  return d.year == DateTime.now().year ? full.replaceFirst(' ${d.year}', '') : full;
}
