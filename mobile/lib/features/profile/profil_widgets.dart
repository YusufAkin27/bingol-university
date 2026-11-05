import 'package:flutter/material.dart';

import '../../widgets/bu.dart';
import 'notification_prefs_page.dart' show PrefSwitch;

/// Profil ortak parçaları (kart, satır, bölüm başlığı, anahtar satırı, seçim sayfası). P0 bileşenleri üstüne kurulu;
/// dış imzalar eskisiyle aynıdır (hesap, bildirim, etkinlik, kulüp sayfaları kullanır).

/// Eski ad: artık nötr mürekkep tonu (mavi kategori rengi kalktı).
Color profilBlue(BuildContext context) => context.bu.ink;

/// Çizgili kart ([BuCard] outlined, 16 dp köşe, gölgesiz); satırlar tam genişlikte çok ince çizgiyle ayrılır.
class ProfilCard extends StatelessWidget {
  const ProfilCard({super.key, required this.children, this.margin});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final card = BuCard(
      padding: EdgeInsets.zero,
      radius: 16,
      style: BuCardStyle.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.bdSubtle),
            children[i],
          ],
        ],
      ),
    );
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

/// Üst çubuk: 56 dp, düz geri oku (48 dp dokunma) + sade başlık, çizgisiz. Ekran okuyucuda "Geri".
class ProfilTopBar extends StatelessWidget {
  const ProfilTopBar({super.key, required this.title, this.onBack, this.trailing});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => BuHeader(
        title: title,
        onBack: onBack ?? () => Navigator.maybePop(context),
        actions: [if (trailing != null) trailing!],
      );
}

/// Düz bölüm etiketi: 13 sp mut (kalın değil), büyük harf değil; üstte [top] dp boşluk.
class ProfilFlatSection extends StatelessWidget {
  const ProfilFlatSection(this.text, {super.key, this.top = 24, this.upper = false, this.horizontal = 20});

  final String text;
  final double top;

  /// Alt sayfa etiketleri (Şifreyi güncelle, Oturumlar, Dosyada neler var, Neler olur) referansta büyük harftir.
  final bool upper;

  /// Yatay iç boşluk (listenin kendi 20 dp kenarı varsa 0).
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final lang = Localizations.localeOf(context).languageCode;
    final shown = !upper || lang == 'ar' ? text : (lang == 'en' ? text.toUpperCase() : trUpper(text));
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(horizontal, top, horizontal, 8),
      child: Semantics(
        header: true,
        child: Text(shown,
            style: Theme.of(context)
                .textTheme
                .labelLarge!
                .copyWith(fontSize: 13, fontWeight: upper ? FontWeight.w400 : BuType.emphasisWeight, letterSpacing: upper && lang != 'ar' ? .4 : 0, color: t.mut)),
      ),
    );
  }
}

/// Satır grubu: ince çerçeveli 16 dp kart (gölge yok), satırlar arasında 1 dp ince ayırıcı.
class ProfilFlatGroup extends StatelessWidget {
  const ProfilFlatGroup({super.key, required this.children, this.color, this.outlined = false});

  final List<Widget> children;
  final Color? color;

  /// Eski parametre: her iki değer de aynı gölgesiz çizgili 16 dp kartı verir (gölgeli stil kalktı).
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: BuCard(
        radius: 16,
        style: BuCardStyle.outlined,
        color: color,
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1, thickness: 1, color: t.bdSubtle)),
            children[i],
          ],
        ]),
      ),
    );
  }
}

/// 56 dp düz satır: etiket 16 ink, sağda değer 15 mut + chevron 20 mut. [danger]: etiket danger (chevron yok).
class ProfilFlatRow extends StatelessWidget {
  const ProfilFlatRow({super.key, required this.label, this.value, this.onTap, this.danger = false, this.chevron = true, this.trailing, this.icon, this.plainIcon = false});

  final IconData? icon;

  /// true: simge karosuz, düz 22 dp simge (danger renginde).
  final bool plainIcon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;
  final bool chevron;
  final Widget? trailing;

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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
          child: Row(children: [
            if (icon != null) ...[
              if (plainIcon)
                ExcludeSemantics(child: Icon(icon!, size: 22, color: danger ? t.danger : t.ink))
              else
                ProfilIconTile(icon: icon!, danger: danger),
              SizedBox(width: plainIcon ? 14 : 12),
            ],
            Expanded(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tx.bodyLarge!.copyWith(fontSize: 16, color: danger ? t.danger : t.ink, fontWeight: BuType.emphasisWeight)),
            ),
            if (value != null && value!.isNotEmpty) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontSize: 15, color: t.mut)),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            SizedBox(
              width: 28,
              child: (chevron && !danger && onTap != null)
                  ? Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: ExcludeSemantics(child: Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mut)),
                    )
                  : null,
            ),
          ]),
        ),
      ),
    );
  }
}

/// Anahtarlı düz satır: 56 dp (açıklamalıysa daha uzun), M3 standart anahtar; satırın tamamı dokunulabilir.
class ProfilFlatToggle extends StatelessWidget {
  const ProfilFlatToggle({super.key, required this.label, required this.value, required this.onChanged, this.sub});

  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(label, style: tx.bodyLarge!.copyWith(fontSize: 16, color: t.ink)),
                    if (sub != null) Text(sub!, style: tx.bodySmall!.copyWith(fontSize: 12, color: t.mut, height: 1.35)),
                  ]),
                ),
                const SizedBox(width: 12),
                ExcludeSemantics(child: Switch(value: value, onChanged: onChanged)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bölüm başlığı: küçük, büyük harfli, soluk (ekran okuyucuda başlık).
class ProfilSection extends StatelessWidget {
  const ProfilSection(this.text, {super.key, this.top = 16});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    // Bölüm etiketi 13 sp, soluk, kalın ve BÜYÜK HARF DEĞİL.
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 4, bottom: 10, top: top),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 13, fontWeight: BuType.emphasisWeight, color: t.mut)),
      ),
    );
  }
}

/// Liste simgesi: karo/zemin YOK, tek nötr ton (`mut`); hata/silme satırlarında `danger`. Karo boyutu yalnız satır hizası içindir.
class ProfilIconTile extends StatelessWidget {
  const ProfilIconTile({super.key, required this.icon, this.color, this.tint, this.danger = false, this.size = 36, this.accent = false});

  /// Karo kenarı (dp); simge 0,5 oranında. Stitch profil listeleri 40.
  final double size;

  /// Eski parametre (vurgu rengi kalktı): yok sayılır, simge her zaman nötrdür.
  final bool accent;

  final IconData icon;

  /// Yalnız simge rengi (eski kullanım).
  final Color? color;

  /// Eski parametre: ton karoları kalktı, yok sayılır.
  final BuTint? tint;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fg = color ?? (danger ? t.danger : t.mut);
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: ExcludeSemantics(child: Icon(icon, size: size > 36 ? 22 : 20, color: fg))),
    );
  }
}

/// Menü satırı: simge karosu + başlık (+ alt yazı) + sağda değer/ok. Dokununca hafif titreşim.
class ProfilRow extends StatelessWidget {
  const ProfilRow({
    super.key,
    this.icon,
    required this.label,
    this.sub,
    this.value,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.blue = false,
    this.chevron = true,
    this.tint,
  });

  /// null: simgesiz düz satır (Stitch v3 profil listeleri).
  final IconData? icon;
  final String label;
  final String? sub;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final bool blue;
  final bool chevron;

  /// Eski parametre (ton karoları kalktı): yok sayılır.
  final BuTint? tint;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final c = danger ? t.danger : t.ink;
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              buHaptic(BuHaptic.selection);
              onTap!();
            },
      child: Container(
        // Tüm satırlar aynı yükseklikte; yazı ölçeği büyüse de metin tek satırda kalır.
        constraints: BoxConstraints(minHeight: icon == null ? 56 : 64),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
        child: Row(
          children: [
            if (icon != null) ...[ProfilIconTile(icon: icon!, danger: danger, size: 40), const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: tx.bodyLarge!.copyWith(fontSize: 16, color: c)),
                  if (sub != null) Text(sub!, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(value!,
                    maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontSize: 15, fontWeight: FontWeight.w400, color: t.mut)),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            // Ok alanı her satırda sabit genişlikte ayrılır: ok hepsinde aynı konumda.
            const SizedBox(width: 6),
            SizedBox(
              width: 20,
              child: (chevron && !danger && onTap != null)
                  ? ExcludeSemantics(child: Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mutSoft))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Başlık + alt yazı + sağda anahtar; satırın tamamı dokunulabilir.
class ProfilToggleRow extends StatelessWidget {
  const ProfilToggleRow({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.icon,
    this.onChanged,
  });

  final String label;
  final String? sub;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Semantics(
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: Container(
            constraints: BoxConstraints(minHeight: sub == null ? 52 : 60),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 10, 6),
            child: Row(
              children: [
                if (icon != null) ...[ProfilIconTile(icon: icon!), const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: tx.bodyLarge!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
                      if (sub != null) Text(sub!, style: tx.bodySmall!.copyWith(color: t.mut)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PrefSwitch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Seçim sayfası (dil/tema): tutamaçlı alt sayfa ([BuSheet]), işaretli seçenekler. Seçilen değeri döndürür.
Future<String?> showProfilChoiceSheet(
  BuildContext context, {
  required String title,
  required List<(String, String)> options,
  required String selected,
}) {
  return BuSheet.show<String>(
    context,
    title: title,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final o in options)
          BuListTile(
            title: o.$2,
            selected: o.$1 == selected,
            trailing: o.$1 == selected ? Icon(BuIcons.check, color: ctx.bu.ink) : null,
            onTap: () {
              buHaptic(BuHaptic.selection);
              Navigator.pop(ctx, o.$1);
            },
          ),
      ],
    ),
  );
}

/// Tema seçici: Sistem / Açık / Koyu, her seçenekte küçük önizleme (Açık = Premium White, Koyu = Premium Black,
/// Sistem = ikiye bölünmüş). Seçili seçenek `ink` çerçeve + `ink` etiketle ayırt edilir (gölge/renk yok).
/// Önizleme karoları seçeneğin kendi temasını gösterir; bu yüzden [BuTokens.light]/[BuTokens.dark] doğrudan kullanılır
/// (arayüz rengi değil, "bu temada nasıl görünür" örneğidir).
class ProfilThemePicker extends StatelessWidget {
  const ProfilThemePicker({super.key, required this.mode, required this.onChanged, required this.systemLabel, required this.lightLabel, required this.darkLabel});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  final String systemLabel;
  final String lightLabel;
  final String darkLabel;

  @override
  Widget build(BuildContext context) {
    final options = [
      (ThemeMode.system, systemLabel, const ValueKey('theme-option-system')),
      (ThemeMode.light, lightLabel, const ValueKey('theme-option-light')),
      (ThemeMode.dark, darkLabel, const ValueKey('theme-option-dark')),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _ThemeOption(
              key: options[i].$3,
              label: options[i].$2,
              mode: options[i].$1,
              selected: mode == options[i].$1,
              onTap: () {
                if (mode != options[i].$1) buHaptic(BuHaptic.selection);
                onChanged(options[i].$1);
              },
            ),
          ),
        ],
      ]),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({super.key, required this.label, required this.mode, required this.selected, required this.onTap});

  final String label;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    const light = BuTokens.light;
    const dark = BuTokens.dark;
    Widget half(BuTokens p) => ColoredBox(
          color: p.bg,
          child: Center(child: Text('Aa', style: tx.titleMedium!.copyWith(color: p.ink, fontWeight: BuType.emphasisWeight))),
        );
    final preview = switch (mode) {
      ThemeMode.light => half(light),
      ThemeMode.dark => half(dark),
      ThemeMode.system => Row(children: [Expanded(child: half(light)), Expanded(child: half(dark))]),
    };
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: BuPressable(
        onTap: onTap,
        scale: .97,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: BuMotion.of(context, BuMotion.short),
              curve: BuMotion.standard,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? t.ink : t.bd, width: selected ? 1.5 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: preview,
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (selected) ...[Icon(BuIcons.check, size: 14, color: t.ink), const SizedBox(width: 4)],
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.labelLarge!.copyWith(fontSize: 13, color: selected ? t.ink : t.mut)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
