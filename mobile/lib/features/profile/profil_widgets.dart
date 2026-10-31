import 'package:flutter/material.dart';

import '../../widgets/bu.dart';
import 'notification_prefs_page.dart' show PrefSwitch;

/// Profil ortak parçaları (kart, satır, bölüm başlığı, anahtar satırı, seçim sayfası). P0 bileşenleri üstüne kurulu;
/// dış imzalar eskisiyle aynıdır (hesap, bildirim, etkinlik, kulüp sayfaları kullanır).

/// Mavi ikon tonu (tasarım sistemindeki mavi kategori rengi; açık/koyu temaya göre okunur ton).
Color profilBlue(BuildContext context) => context.bu.tint(1).fg;

/// Katmanlı kart ([BuCard], ince çizgi + 20 dp köşe); satırlar simge karosunun hizasından başlayan çizgiyle ayrılır.
class ProfilCard extends StatelessWidget {
  const ProfilCard({super.key, required this.children, this.margin});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final card = BuCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.bd),
            children[i],
          ],
        ],
      ),
    );
    return margin == null ? card : Padding(padding: margin!, child: card);
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
    final lang = Localizations.localeOf(context).languageCode;
    // İngilizce dışında (tr; testte varsayılan yerel de) Türkçe büyük harf kuralı; Arapçada harf büyümez.
    final up = lang == 'en' ? text.toUpperCase() : trUpper(text);
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 6, bottom: 8, top: top),
      child: Semantics(
        header: true,
        child: Text(up,
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
                fontWeight: FontWeight.w700, letterSpacing: lang == 'ar' ? 0 : .6, color: t.mut)),
      ),
    );
  }
}

/// 36x36 yuvarlatılmış simge karosu: varsayılan NÖTR (tur 3: listelerde tek simge tonu), [tint] ile verilen ton, [danger] ile hata tonu.
class ProfilIconTile extends StatelessWidget {
  const ProfilIconTile({super.key, required this.icon, this.color, this.tint, this.danger = false});

  final IconData icon;

  /// Yalnız simge rengi (eski kullanım); karo zemini [tint]/marka tonundan gelir.
  final Color? color;
  final BuTint? tint;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bg = danger ? Theme.of(context).colorScheme.errorContainer : (tint?.bg ?? t.sf2);
    final fg = color ?? (danger ? t.danger : (tint?.fg ?? t.ink));
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bSm),
      child: ExcludeSemantics(child: Icon(icon, size: 19, color: fg)),
    );
  }
}

/// Menü satırı: simge karosu + başlık (+ alt yazı) + sağda değer/ok. Dokununca hafif titreşim.
class ProfilRow extends StatelessWidget {
  const ProfilRow({
    super.key,
    required this.icon,
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

  final IconData icon;
  final String label;
  final String? sub;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final bool blue;
  final bool chevron;

  /// Karo rengi (örn. `context.bu.tint(2)`); verilmezse [blue] ya da marka tonu.
  final BuTint? tint;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final c = danger ? t.danger : t.ink;
    final tone = tint ?? (blue ? t.tint(1) : null);
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              buHaptic(BuHaptic.selection);
              onTap!();
            },
      child: Container(
        // Tüm satırlar aynı yükseklikte; yazı ölçeği büyüse de metin tek satırda kalır.
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
        child: Row(
          children: [
            ProfilIconTile(icon: icon, tint: tone, danger: danger),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: tx.bodyLarge!.copyWith(fontWeight: FontWeight.w600, color: c)),
                  if (sub != null)
                    Text(sub!,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: tx.bodySmall!.copyWith(color: t.mut)),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(value!,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            // Ok alanı her satırda sabit genişlikte ayrılır: ok hepsinde aynı konumda.
            const SizedBox(width: 6),
            SizedBox(
              width: 18,
              child: (chevron && !danger && onTap != null)
                  ? ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut))
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
                          style: tx.bodyLarge!.copyWith(fontWeight: FontWeight.w600, color: t.ink)),
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
            trailing: o.$1 == selected ? Icon(LucideIcons.check, color: ctx.bu.pr) : null,
            onTap: () {
              buHaptic(BuHaptic.selection);
              Navigator.pop(ctx, o.$1);
            },
          ),
      ],
    ),
  );
}
