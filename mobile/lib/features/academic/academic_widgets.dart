import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';

/// Akademik sayfaların ortak iskeleti: başlık + gövde.
class AcademicScaffold extends StatelessWidget {
  const AcademicScaffold({super.key, required this.title, required this.child, this.actions = const [], this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.bu.bg,
        body: Column(
          children: [
            BuHeader(title: title, subtitle: subtitle, onBack: () => Navigator.maybePop(context), actions: actions),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        ),
      );
}

/// 503 (bakım) için kısa metin; diğer hatalarda ErrorView.
class AcademicErrorView extends StatelessWidget {
  const AcademicErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e = error;
    if (e is ApiError && e.status == 503) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: StaleBanner(text: e.message.isNotEmpty ? e.message : 'Akademik hizmetler bakımda. Daha sonra tekrar deneyin.'),
          ),
          Center(child: TextButton(onPressed: onRetry, child: const Text('Yeniden dene'))),
        ],
      );
    }
    return ErrorView(error: error, onRetry: onRetry);
  }
}

/// Renk çubuklu ders/sınav kartı kabuğu.
class ColorCard extends StatelessWidget {
  const ColorCard({super.key, required this.color, required this.child, this.onTap, this.semanticLabel});

  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: Color.alphaBlend(color.withValues(alpha: .12), t.sf),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.bd)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: color),
                Expanded(child: Padding(padding: const EdgeInsets.all(12), child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Küçük "ikon + metin" satırı (hoca, derslik...).
class MetaLine extends StatelessWidget {
  const MetaLine(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(children: [
        ExcludeSemantics(child: Icon(icon, size: 13, color: t.mut)),
        const SizedBox(width: 6),
        Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut))),
      ]),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String text, required String action, bool danger = false}) async {
  final t = context.bu;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: t.sf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(title, style: BuType.title.copyWith(color: t.ink)),
      content: Text(text, style: BuType.body.copyWith(color: t.mut)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Vazgeç', style: BuType.bodyStrong.copyWith(color: t.mut))),
        TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action, style: BuType.bodyStrong.copyWith(color: danger ? t.danger : t.pr))),
      ],
    ),
  );
  return ok == true;
}

void academicToast(BuildContext context, String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

/// Form etiketi.
class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 6, top: 2),
        child: Text(text, style: BuType.label.copyWith(color: context.bu.mut)),
      );
}

/// Dokununca seçici açan alan (tarih/saat).
class PickerField extends StatelessWidget {
  const PickerField({super.key, required this.icon, required this.value, required this.onTap, this.hint = 'Seç', this.label});

  final IconData icon;
  final String? value;
  final String hint;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      value: value ?? hint,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.bd)),
          child: Row(children: [
            Icon(icon, size: 17, color: t.mut),
            const SizedBox(width: 10),
            Expanded(
                child: Text(value ?? hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.body.copyWith(color: value == null ? t.mut : t.ink))),
          ]),
        ),
      ),
    );
  }
}
