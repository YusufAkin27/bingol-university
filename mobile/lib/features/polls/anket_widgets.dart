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
  const AnketEmptyCard({super.key, required this.tag, required this.tagIcon, required this.icon, required this.title, required this.body});

  final String tag;
  final IconData tagIcon;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return BuCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
      child: SizedBox(
        width: double.infinity,
        child: Column(children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
              child: Text(tag, style: tx.labelSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            ExcludeSemantics(child: Icon(tagIcon, size: 18, color: t.mut)),
          ]),
          const SizedBox(height: 12),
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

/// Kulüp anketi boş kutusu: simge, başlık, açıklama ve "Tüm anketleri gör" bağlantı düğmesi.
class AnketClubEmpty extends StatelessWidget {
  const AnketClubEmpty({super.key, required this.title, required this.body, required this.linkLabel, required this.onLink});

  final String title;
  final String body;
  final String linkLabel;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 16),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        AnketRoundIcon(LucideIcons.calendarX, size: 52, bg: t.sf, fg: t.ink),
        const SizedBox(height: 12),
        Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
        const SizedBox(height: 6),
        Text(body, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45)),
        const SizedBox(height: 14),
        AnketLinkButton(label: linkLabel, onTap: onLink, filled: true),
      ]),
    );
  }
}

/// Kırmızı metin + ok bağlantısı ("Tüm anketleri gör >"). [filled]: beyaz zeminli tam genişlik düğme.
class AnketLinkButton extends StatelessWidget {
  const AnketLinkButton({super.key, required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final row = Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 6),
      ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.arrowRight), size: 16, color: t.pr)),
    ]);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: filled ? MaterialType.canvas : MaterialType.transparency,
        color: filled ? t.sf : null,
        borderRadius: BuRadius.bSm,
        child: InkWell(
          borderRadius: BuRadius.bSm,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: filled ? double.infinity : null, child: Center(widthFactor: filled ? null : 1, child: row)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yükleme hatası şeridi: simge karosu, kırmızı başlık + açıklama, "Yeniden dene" düğmesi.
class AnketErrorBanner extends StatelessWidget {
  const AnketErrorBanner({super.key, required this.title, required this.body, required this.retryLabel, required this.onRetry});

  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 14, 14),
        decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          AnketRoundIcon(LucideIcons.wifiOff, size: 40, bg: t.danger.withValues(alpha: .14), fg: t.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: tx.titleMedium!.copyWith(color: t.danger, fontWeight: FontWeight.w800, height: 1.25)),
              const SizedBox(height: 2),
              Text(body, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.35)),
            ]),
          ),
          const SizedBox(width: 10),
          BuButton(label: retryLabel, icon: LucideIcons.refreshCw, compact: true, onPressed: onRetry),
        ]),
      ),
    );
  }
}

/// Bölüm başlığı: solda küçük renkli nokta (ya da simge) + başlık, sağda yan metin.
class AnketHeading extends StatelessWidget {
  const AnketHeading({super.key, required this.title, this.icon, this.trailing, this.iconColor});

  final String title;
  final IconData? icon;
  final String? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Row(children: [
      ExcludeSemantics(
        child: icon != null
            ? Icon(icon, size: 18, color: iconColor ?? t.pr)
            : Container(width: 8, height: 8, decoration: BoxDecoration(color: t.mut, shape: BoxShape.circle)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Semantics(
          header: true,
          child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
        ),
      ),
      if (trailing != null) ...[
        const SizedBox(width: 8),
        Text(trailing!, maxLines: 1, style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
      ],
    ]);
  }
}

/// İpucu/uyarı kutusu: başta yuvarlak (beyaz) simge, kalın başlık ve açıklama; isteğe bağlı sağ rozet.
class AnketHintBox extends StatelessWidget {
  const AnketHintBox({super.key, required this.icon, this.body, this.title, this.trailing, this.iconColor});

  final IconData icon;
  final String? title;
  final String? body;
  final String? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnketRoundIcon(icon, size: 36, bg: t.sf, fg: iconColor ?? t.ink),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) Text(title!, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.3)),
            if (title != null && body != null) const SizedBox(height: 2),
            if (body != null) Text(body!, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45)),
          ]),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bPill),
            child: Text(trailing!, style: tx.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }
}
