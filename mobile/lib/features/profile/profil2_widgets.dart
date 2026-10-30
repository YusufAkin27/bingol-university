import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Profil düzenle / Ayarlar / Hesap / Gizlilik / Verilerim / Hesabı sil (Stitch 48, 49, 08) ortak küçük bileşenleri.
/// Renk yalnız `context.bu` ve ColorScheme üzerinden gelir.

/// Bölüm başlığı: küçük, kalın, soluk, büyük harf ("GÖRÜNÜM").
class P2SectionLabel extends StatelessWidget {
  const P2SectionLabel(this.text, {super.key, this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 4, end: 4, bottom: 8, top: top),
      child: Semantics(
        header: true,
        child: Text(
          trUpper(text),
          style: Theme.of(context)
              .textTheme
              .labelMedium!
              .copyWith(color: context.bu.mut, fontWeight: FontWeight.w700, letterSpacing: Directionality.of(context) == TextDirection.rtl ? 0 : .5),
        ),
      ),
    );
  }
}

/// Bölüm başlığı: koyu, kalın ("Şifreyi güncelle", "Dosyada neler var").
class P2Heading extends StatelessWidget {
  const P2Heading(this.text, {super.key, this.top = 0, this.icon});

  final String text;
  final double top;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 4, end: 4, bottom: 10, top: top),
      child: Semantics(
        header: true,
        child: Row(children: [
          if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: 20, color: t.pr)), const SizedBox(width: 8)],
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
          ),
        ]),
      ),
    );
  }
}

/// 36 dp, yumuşak köşeli simge karosu. [tint] verilmezse marka tonu; [danger] kırmızı.
class P2IconTile extends StatelessWidget {
  const P2IconTile({super.key, required this.icon, this.tint, this.danger = false, this.size = 36, this.neutral = false});

  final IconData icon;
  final BuTint? tint;
  final bool danger;
  final double size;

  /// Gri (sf2) zemin, soluk simge.
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final cs = Theme.of(context).colorScheme;
    final bg = danger ? cs.errorContainer : (neutral ? t.sf2 : (tint?.bg ?? t.soft));
    final fg = danger ? t.danger : (neutral ? t.mut : (tint?.fg ?? t.pr));
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * .33)),
        alignment: Alignment.center,
        child: Icon(icon, size: size * .52, color: fg),
      ),
    );
  }
}

enum P2PillTone { ok, mute, danger }

/// Küçük hap rozet (Doğrulandı, Değiştirilemez, Açık).
class P2Pill extends StatelessWidget {
  const P2Pill({super.key, required this.text, this.tone = P2PillTone.mute, this.icon, this.dot = false});

  final String text;
  final P2PillTone tone;
  final IconData? icon;

  /// Simge yerine dolu nokta.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      P2PillTone.ok => (t.okSoft, t.ok),
      P2PillTone.danger => (cs.errorContainer, t.danger),
      P2PillTone.mute => (t.sf2, t.mut),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)), const SizedBox(width: 6)],
          if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: 14, color: fg)), const SizedBox(width: 5)],
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Kırmızı zeminli hata kartı: simge + bir ya da birden çok satır. [bullets] true: satırlar madde işaretli.
class P2NoticeCard extends StatelessWidget {
  const P2NoticeCard({super.key, required this.lines, this.title, this.icon = LucideIcons.circleAlert, this.bullets = false, this.compact = false});

  final List<String> lines;
  final String? title;
  final IconData icon;
  final bool bullets;

  /// Tek satırlık küçük hap kart (fotoğraf hataları).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final cs = Theme.of(context).colorScheme;
    final tx = Theme.of(context).textTheme;
    final fg = cs.onErrorContainer;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: compact ? 10 : 14),
        decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(compact ? BuRadius.sm : BuRadius.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: ExcludeSemantics(child: Icon(icon, size: 20, color: t.danger)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(title!, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: fg)),
                ),
              for (final s in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(bullets ? '•  $s' : s, style: tx.bodyMedium!.copyWith(color: fg, height: 1.35, fontWeight: FontWeight.w500)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Alan etiketi: simge + etiket (+ sağda yardımcı metin).
class P2FieldLabel extends StatelessWidget {
  const P2FieldLabel(this.text, {super.key, this.icon, this.trailing});

  final String text;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2, end: 2, bottom: 8),
      child: Row(children: [
        if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: 16, color: t.mut)), const SizedBox(width: 6)],
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Üç seçenekli parçalı seçici (Herkes | Ortak bağlam | Yalnızca ben): seçili parça koyu (mürekkep).
class P2Segment3 extends StatelessWidget {
  const P2Segment3({super.key, required this.labels, required this.index, required this.onChanged, this.label, this.enabled = true});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  /// Ekran okuyucu etiketi (alan adı).
  final String? label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm + 2)),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                inMutuallyExclusiveGroup: true,
                excludeSemantics: true,
                label: labels[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled ? () => onChanged(i) : null,
                  child: AnimatedContainer(
                    duration: BuMotion.of(context, BuMotion.short),
                    curve: BuMotion.standard,
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: i == index ? t.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(BuRadius.sm),
                    ),
                    alignment: Alignment.center,
                    child: Text(labels[i],
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: i == index ? t.bg : t.mut)),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Yönetim satırı: sağda ok; [value] soluk metin. Kart içinde ayırıcıyla dizilir ([BuGroup]).
class P2LinkRow extends StatelessWidget {
  const P2LinkRow({super.key, required this.icon, required this.title, this.value, this.danger = false, this.tint, required this.onTap});

  final IconData icon;
  final String title;
  final String? value;
  final bool danger;
  final BuTint? tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            P2IconTile(icon: icon, tint: tint, danger: danger),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tx.bodyLarge!.copyWith(fontWeight: FontWeight.w700, color: danger ? t.danger : t.ink)),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(value!, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
            ],
            const SizedBox(width: 8),
            ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: danger ? t.danger : t.mut)),
          ]),
        ),
      ),
    );
  }
}
