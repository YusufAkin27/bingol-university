import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'notification_prefs_page.dart' show PrefSwitch;

/// P9 profil tasarımındaki ortak parçalar (kart, satır, bölüm başlığı, anahtar satırı).

/// Tasarımdaki mavi ikon tonu (#2F4FA8); koyu temada okunur açık ton.
Color profilBlue(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF9DB4F0) : const Color(0xFF2F4FA8);

/// Başlık altı sessiz ikon zemini: sayfa zemini rengi (kart üstünde hafif çukur).
Color _tile(BuildContext context) => context.bu.bg;

/// Yumuşak gölgeli 20 px köşeli kart; satırlar ince çizgiyle ayrılır.
class ProfilCard extends StatelessWidget {
  const ProfilCard({super.key, required this.children, this.margin});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.bd),
        boxShadow: dark
            ? null
            : const [BoxShadow(color: Color(0x40171E33), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -12)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: t.bd),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bölüm başlığı: küçük, büyük harfli, soluk.
class ProfilSection extends StatelessWidget {
  const ProfilSection(this.text, {super.key, this.top = 16});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    // İngilizce dışında (tr; testte varsayılan yerel de) Türkçe büyük harf kuralı; Arapçada harf büyümez.
    final up = Localizations.localeOf(context).languageCode == 'en' ? text.toUpperCase() : trUpper(text);
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 6, bottom: 8, top: top),
      child: Semantics(
        header: true,
        child: Text(up, style: BuType.label.copyWith(fontWeight: FontWeight.w700, letterSpacing: .6, color: t.mut)),
      ),
    );
  }
}

/// 36x36 yuvarlatılmış ikon zemini.
class ProfilIconTile extends StatelessWidget {
  const ProfilIconTile({super.key, required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: _tile(context), borderRadius: BorderRadius.circular(12)),
        child: ExcludeSemantics(child: Icon(icon, size: 18, color: color ?? context.bu.pr)),
      );
}

/// Menü satırı: ikon zemini + başlık (+ alt yazı) + sağda değer/ok.
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final c = danger ? t.danger : t.ink;
    final tone = danger ? t.danger : (blue ? profilBlue(context) : t.pr);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: sub == null ? 52 : 60),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
        child: Row(
          children: [
            ProfilIconTile(icon: icon, color: tone),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: BuType.bodyStrong.copyWith(fontSize: 14.5, color: c)),
                  if (sub != null) Text(sub!, style: BuType.caption.copyWith(fontSize: 12, color: t.mut)),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.bodyStrong.copyWith(fontSize: 13.5, color: t.mut)),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (chevron && !danger && onTap != null) ...[
              const SizedBox(width: 6),
              Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut),
            ],
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
                      Text(label, style: BuType.bodyStrong.copyWith(fontSize: 14.5, color: t.ink)),
                      if (sub != null) Text(sub!, style: BuType.caption.copyWith(fontSize: 12, color: t.mut)),
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

/// Seçim sayfası (dil/tema): başlık + işaretli seçenekler. Seçilen değeri döndürür.
Future<String?> showProfilChoiceSheet(
  BuildContext context, {
  required String title,
  required List<(String, String)> options,
  required String selected,
}) {
  final t = context.bu;
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: t.sf,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: BuType.heading.copyWith(color: t.ink)),
          const SizedBox(height: 8),
          for (final o in options)
            ListTile(
              title: Text(o.$2, style: BuType.bodyStrong.copyWith(color: t.ink)),
              selected: o.$1 == selected,
              trailing: o.$1 == selected ? Icon(LucideIcons.check, color: t.pr) : null,
              onTap: () => Navigator.pop(ctx, o.$1),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    ),
  );
}
