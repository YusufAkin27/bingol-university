import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Tarih karosu ton paleti. Adlar eski tasarımdan kalmadır; renkler `BuTintId` tablosuna bağlıdır:
/// red -> amber, blue -> mavi, green -> su mavisi (marka kırmızısı yalnız eylem/seçili durumdadır).
enum EtkinlikTone { red, blue, green }

EtkinlikTone etkinlikToneOf(int id) =>
    EtkinlikTone.values[id.abs() % EtkinlikTone.values.length];

/// Tarih karosu: takvim yaprağı görünümü (üstte ay bandı, altta büyük gün sayısı), 56x64, ton rengi kategori paletinden.
class EtkinlikDateTile extends StatelessWidget {
  const EtkinlikDateTile(
      {super.key, required this.month, required this.day, required this.tone});

  final String month;
  final String day;
  final EtkinlikTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final tint = t.tint(switch (tone) {
      EtkinlikTone.red => BuTintId.amber,
      EtkinlikTone.blue => BuTintId.blue,
      EtkinlikTone.green => BuTintId.aqua,
    });
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BuRadius.bMd,
        child: SizedBox(
          width: 56,
          height: 64,
          child: ColoredBox(
            color: tint.bg,
            child: Column(children: [
              Container(
                height: 22,
                width: double.infinity,
                alignment: Alignment.center,
                color: tint.fg,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(month,
                      maxLines: 1,
                      style: tx.labelSmall!.copyWith(
                          color: tint.bg,
                          fontWeight: FontWeight.w800,
                          letterSpacing: ar ? 0 : .8)),
                ),
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(day,
                          maxLines: 1,
                          style: tx.headlineSmall!
                              .copyWith(color: tint.fg, height: 1.1)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Durum / eylem hapı ("Katılıyorsunuz" yeşil, "Katıl" kırmızı). Görsel yükseklik 36 dp; dokunulabilir olunca
/// hedef 48 dp (çevresi de basılabilir), basınca hafifçe küçülür ve titreşir.
class EtkinlikPill extends StatelessWidget {
  const EtkinlikPill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.onTap,
    this.icon,
    this.busy = false,
  });

  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    final tappable = onTap != null;
    final body = Container(
      constraints: BoxConstraints(minHeight: tappable ? 36 : 30),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (busy)
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (icon != null)
          Icon(icon, size: 15, color: fg),
        if (busy || icon != null) const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx.labelLarge!.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
    if (!tappable) return body;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: BuPressable(
          scale: .95,
          onTap: onTap,
          haptic: BuHaptic.light,
          child: body,
        ),
      ),
    );
  }
}

/// Etkinlik kartı tarih bloğu tonu: marka (Keşfet), mavi-gri (Etkinliklerim), gri (geçmiş / iptal).
enum EtkinlikBlockTone { brand, blue, grey }

/// Yumuşak zeminli tarih bloğu: üstte gün (büyük), altta ay kısaltması. 56 dp, 16 köşe.
class EtkinlikDateBlock extends StatelessWidget {
  const EtkinlikDateBlock({super.key, required this.month, required this.day, this.tone = EtkinlikBlockTone.brand, this.size = 56});

  final String month;
  final String day;
  final EtkinlikBlockTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final (bg, dayFg, monFg) = switch (tone) {
      EtkinlikBlockTone.brand => (t.soft, t.onSoft, t.onSoft),
      EtkinlikBlockTone.blue => (t.infoSoft, t.ink, t.info),
      EtkinlikBlockTone.grey => (t.mut.withValues(alpha: .12), t.mut, t.mut),
    };
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(day, maxLines: 1, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, height: 1.1, color: dayFg)),
                Text(month,
                    maxLines: 1,
                    style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w800, letterSpacing: ar ? 0 : .6, color: monFg)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kart içi eylem düğmesi (Katıl / İlgileniyorum / Detay): 48 dp, 14 köşe, simge + etiket.
class EtkinlikActionButton extends StatelessWidget {
  const EtkinlikActionButton({super.key, required this.label, required this.onTap, this.icon, this.primary = false, this.busy = false, this.grey = false, this.trailing, this.big = false, this.selected = false, this.iconColor});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Dolu marka düğmesi (Katıl).
  final bool primary;

  /// Nötr gri zemin (Detay).
  final bool grey;
  final bool busy;

  /// Etiketten sonra gelen simge (Detay →).
  final IconData? trailing;

  /// Daha yüksek (54 dp) alt çubuk düğmesi.
  final bool big;

  /// Simge rengi (varsayılan: yazı rengi).
  final Color? iconColor;

  /// Seçili (tonal dolgu + kalın çerçeve): "İlgileniyorum" seçiliyken.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final off = onTap == null && !busy;
    final bg = off ? t.mut.withValues(alpha: .12) : (primary ? t.pr : (grey ? t.mut.withValues(alpha: .12) : t.soft));
    final fg = off ? t.mut : (primary ? t.onPr : (grey ? t.ink : t.onSoft));
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        onTap: onTap,
        enabled: onTap != null,
        haptic: primary ? BuHaptic.light : BuHaptic.selection,
        scale: .97,
        child: Container(
          constraints: BoxConstraints(minHeight: big ? 54 : 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(big ? 16 : 14), border: selected ? Border.all(color: t.pr, width: 1.5) : null),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            if (busy)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
            else if (icon != null)
              Icon(icon, size: 18, color: off ? fg : (iconColor ?? fg)),
            if (busy || icon != null) const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: fg))),
            if (trailing != null) ...[const SizedBox(width: 8), Icon(trailing, size: 18, color: fg)],
          ]),
        ),
      ),
    );
  }
}

/// "Detay ›" metin bağlantısı (48 dp hedef).
class EtkinlikDetailLink extends StatelessWidget {
  const EtkinlikDetailLink({super.key, required this.label, required this.onTap, this.muted = false});

  final String label;
  final VoidCallback onTap;

  /// true: soluk gri metin, ok yok (profil kartı "Detay").
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        onTap: onTap,
        haptic: BuHaptic.selection,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: muted ? t.mut : t.pr)),
            if (!muted) ...[
              const SizedBox(width: 4),
              Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.pr),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Alt sekme çipleri (Yaklaşan / Geçmiş): seçili olan koyu mürekkep hap.
class EtkinlikSubChips extends StatelessWidget {
  const EtkinlikSubChips({super.key, required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Row(children: [
      for (var i = 0; i < labels.length; i++) ...[
        Semantics(
          button: true,
          selected: i == selected,
          label: labels[i],
          excludeSemantics: true,
          onTap: () => onSelected(i),
          child: BuPressable(
            onTap: () => onSelected(i),
            haptic: BuHaptic.selection,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                widthFactor: 1,
                child: AnimatedContainer(
                  duration: BuMotion.of(context, BuMotion.short),
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? t.soft : t.sf,
                    borderRadius: BorderRadius.circular(BuRadius.pill),
                    border: Border.all(color: i == selected ? t.selectedBorder : t.bd),
                  ),
                  child: Text(labels[i], style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: i == selected ? t.onSoft : t.mut)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ]);
  }
}

/// Koyu mürekkep dolgulu eylem düğmesi (Etkinlik oluştur / Kulüplere göz at).
class EtkinlikInkButton extends StatelessWidget {
  const EtkinlikInkButton({super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        onTap: onTap,
        haptic: BuHaptic.light,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(BuRadius.md)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: t.bg),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.bg)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Boş durum kartı: yuvarlak simge + başlık + gövde + isteğe bağlı eylem.
class EtkinlikEmptyCard extends StatelessWidget {
  const EtkinlikEmptyCard({super.key, required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return BuCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      radius: 20,
      child: Column(children: [
        ExcludeSemantics(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: t.tint(1).bg, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: t.ink),
          ),
        ),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(body!, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
        ],
        if (action != null) ...[const SizedBox(height: 20), action!],
      ]),
    );
  }
}
