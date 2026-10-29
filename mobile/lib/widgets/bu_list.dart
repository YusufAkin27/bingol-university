import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/theme/bu_shape.dart';
import 'bu_widgets.dart';

/// Bölüm başlığı: sol başlık (`titleMedium`) + sağda isteğe bağlı "Tümü" eylemi. Ekran okuyucuda başlık olarak okunur.
class BuSectionHeader extends StatelessWidget {
  const BuSectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 24, 12, 8),
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: tx.titleMedium!.copyWith(color: t.ink))),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Sayı rozeti (okunmamış sayısı): 1-99, üstü "99+". 0 ise hiçbir şey çizmez. [muted] true: gri (sessize alınmış).
class BuCountBadge extends StatelessWidget {
  const BuCountBadge(this.count, {super.key, this.muted = false, this.max = 99});

  final int count;
  final bool muted;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final t = context.bu;
    final text = count > max ? '$max+' : '$count';
    return DecoratedBox(
      decoration: BoxDecoration(color: muted ? t.mut : t.pr, borderRadius: BuRadius.bPill),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall!
                      .copyWith(color: muted ? t.bg : t.onPr, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Genel liste satırı (M3 ListTile'ın marka sürümü): başa simge/avatar, başlık + alt metin, sona eylem/ok.
/// Satır en az 56 dp; dokunma dalgası kart köşesine uyar. Uzun başlık 2 satıra kadar sarar.
class BuListTile extends StatelessWidget {
  const BuListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.showChevron = false,
    this.danger = false,
    this.maxTitleLines = 2,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Seçili satır marka tonunda boyanır (çoklu seçim, geçerli sohbet).
  final bool selected;

  /// Sonda yön oku (RTL'de aynalanır).
  final bool showChevron;

  /// Silme/çıkış gibi yıkıcı eylem rengi.
  final bool danger;
  final int maxTitleLines;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final titleColor = danger ? t.danger : t.ink;
    return Material(
      color: selected ? t.soft : Colors.transparent,
      shape: selected ? BuRadius.rect(BuRadius.md) : const RoundedRectangleBorder(),
      clipBehavior: selected ? Clip.antiAlias : Clip.none,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: maxTitleLines,
                          overflow: TextOverflow.ellipsis,
                          style: tx.bodyLarge!.copyWith(color: titleColor, fontWeight: FontWeight.w600)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
                if (showChevron)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ayar satırı: yumuşak zeminli simge karosu + başlık (+ alt metin) + sağda değer/ok ya da anahtar.
/// Satırları [BuGroup] içinde dizin (`dividerIndent: 64`). Anahtarlı satır için [BuSettingsTile.toggle].
class BuSettingsTile extends StatelessWidget {
  const BuSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.tint,
  })  : switchValue = null,
        onSwitch = null;

  /// Anahtarlı (aç/kapat) ayar satırı. Satırın herhangi bir yerine dokunmak anahtarı çevirir.
  const BuSettingsTile.toggle({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.tint,
  })  : switchValue = value,
        onSwitch = onChanged,
        value = null,
        trailing = null,
        onTap = null,
        danger = false;

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Sağdaki soluk değer metni ("Türkçe", "Açık").
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  /// Simge karosu rengi (`context.bu.tint(i)`); null: marka tonu.
  final BuTint? tint;

  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isSwitch = switchValue != null;
    final bg = danger ? cs.errorContainer : (tint?.bg ?? t.soft);
    final fg = danger ? t.danger : (tint?.fg ?? t.pr);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bSm),
                child: Icon(icon, size: 19, color: fg),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tx.bodyLarge!.copyWith(color: danger ? t.danger : t.ink, fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 10),
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.mut)),
                ),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            if (isSwitch) ...[
              const SizedBox(width: 10),
              ExcludeSemantics(child: Switch(value: switchValue!, onChanged: onSwitch)),
            ] else if (onTap != null && !danger && trailing == null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut)),
              ),
          ],
        ),
      ),
    );
    if (isSwitch) {
      return Semantics(
        container: true,
        toggled: switchValue,
        label: subtitle == null ? title : '$title. $subtitle',
        onTap: onSwitch == null ? null : () => onSwitch!(!switchValue!),
        excludeSemantics: true,
        child: InkWell(onTap: onSwitch == null ? null : () => onSwitch!(!switchValue!), child: row),
      );
    }
    return InkWell(onTap: onTap, child: row);
  }
}

/// Yatay kaydırılan çip satırı (filtre/kategori). [selected] seçili indeks; [onSelected] indeks döner.
/// RTL'de sağdan başlar. Yüksekliği 52 dp'ye sabit (çipin 44 dp dokunma alanı + boşluk).
class BuChipRow extends StatelessWidget {
  const BuChipRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.icons,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: 20),
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  /// İsteğe bağlı çip simgeleri ([labels] ile aynı uzunlukta).
  final List<IconData?>? icons;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => BuChip(
          label: labels[i],
          selected: i == selected,
          icon: icons != null && i < icons!.length ? icons![i] : null,
          onTap: () => onSelected(i),
        ),
      ),
    );
  }
}
