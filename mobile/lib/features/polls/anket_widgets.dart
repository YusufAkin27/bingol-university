import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

// Anket ekranlarının (liste, detay, form) ortak yeni parçaları: sekmeler, boş kart, hata şeridi,
// bölüm başlığı, ipucu kutusu. Renkler yalnız belirteçlerden; yönler start/end.

/// Üç sekmeli anahtar (Açık | Katıldıklarım | Kapanan). [badge] yalnız ilk sekmede sayı rozeti gösterir.
class AnketTabs extends StatelessWidget {
  const AnketTabs({super.key, required this.labels, required this.index, required this.onChanged, this.badge});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  /// İlk sekmenin yanındaki sayı (0/null = gösterilmez).
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final n = labels.length;
    final thumb = dark ? Color.alphaBlend(t.ink.withValues(alpha: .16), t.sf2) : t.sf;
    final x = n < 2 ? 0.0 : -1 + 2 * index.clamp(0, n - 1) / (n - 1);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedAlign(
            duration: BuMotion.of(context, BuMotion.medium),
            curve: BuMotion.emphasized,
            alignment: AlignmentDirectional(x, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: thumb,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: dark ? null : [BoxShadow(color: t.shadow.withValues(alpha: .12), blurRadius: 4, offset: const Offset(0, 1))],
                ),
              ),
            ),
          ),
        ),
        Row(children: [
          for (var i = 0; i < n; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: labels[i],
                excludeSemantics: true,
                onTap: () => onChanged(i),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (i != index) buHaptic(BuHaptic.selection);
                    onChanged(i);
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            AnimatedDefaultTextStyle(
                              duration: BuMotion.of(context, BuMotion.short),
                              style: tx.labelLarge!.copyWith(color: i == index ? t.ink : t.mut, fontWeight: i == index ? FontWeight.w700 : FontWeight.w600),
                              child: Text(labels[i], maxLines: 1),
                            ),
                            if (i == 0 && (badge ?? 0) > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                constraints: const BoxConstraints(minWidth: 20),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bPill),
                                child: Text('$badge',
                                    textAlign: TextAlign.center,
                                    style: tx.labelSmall!.copyWith(color: t.onSoft, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// Yuvarlak simge zemini (boş durumlarda): [size] çaplı, yumuşak zeminli daire.
class AnketRoundIcon extends StatelessWidget {
  const AnketRoundIcon(this.icon, {super.key, this.size = 64, this.bg, this.fg});

  final IconData icon;
  final double size;
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg ?? t.sf2, shape: BoxShape.circle),
        child: Icon(icon, size: size * .42, color: fg ?? t.ink),
      ),
    );
  }
}

/// Boş durum kartı (liste sekmeleri): üstte sekme etiketi + küçük simge, ortada yuvarlak simge, başlık, açıklama.
class AnketEmptyCard extends StatelessWidget {
  const AnketEmptyCard({super.key, required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    // Seçili sekme zaten üstte görünür: kartta aynı adı taşıyan rozet/simge tekrarı yok (tek simge, başlık, açıklama).
    return BuCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 28, 16, 28),
      child: SizedBox(
        width: double.infinity,
        child: Column(children: [
          AnketRoundIcon(icon, size: 64, fg: t.ink),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.3)),
          ),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
        ]),
      ),
    );
  }
}

