import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'akad_widgets.dart';

/// Akademik sayfaların ortak iskeleti: başlık + gövde.
class AcademicScaffold extends StatelessWidget {
  const AcademicScaffold({super.key, required this.title, required this.child, this.actions = const [], this.subtitle, this.bottomBar});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  /// Alta sabitlenen, sayfa rengine solan eylem çubuğu (içerik altına [AkadBottomBar.reserve] boşluk bırakır).
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          Column(
            children: [
              _AkadHeader(title: title, subtitle: subtitle, actions: actions),
              const SizedBox(height: 8),
              Expanded(child: child),
            ],
          ),
          if (bottomBar != null) Positioned(left: 0, right: 0, bottom: 0, child: bottomBar!),
        ],
      ),
    );
  }
}

/// Üst başlık (Ak tasarımı): 44 dp yuvarlak geri düğmesi + 20/800 başlık + sağda eylemler.
class _AkadHeader extends StatelessWidget {
  const _AkadHeader({required this.title, required this.actions, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20, MediaQuery.of(context).padding.top + 12, 20, 0),
      child: Row(children: [
        BuIconButton(icon: LucideIcons.arrowLeft, tooltip: context.l10n.commonBack, onTap: () => Navigator.maybePop(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.35,
              child: Semantics(
                header: true,
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.title.copyWith(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.3, color: t.ink)),
              ),
            ),
            if (subtitle != null) Text(subtitle!, style: BuType.caption.copyWith(color: t.mut)),
          ]),
        ),
        for (final a in actions) ...[const SizedBox(width: 8), a],
      ]),
    );
  }
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
            child: StaleBanner(text: e.message.isNotEmpty ? e.message : context.l10n.acadMaintenance),
          ),
          Center(child: TextButton(onPressed: onRetry, child: Text(context.l10n.acadRetry))),
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
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: akadTint(context, color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: color),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: child)),
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
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.l10n.acadCancel, style: BuType.bodyStrong.copyWith(color: t.mut))),
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
  const PickerField({super.key, required this.icon, required this.value, required this.onTap, this.hint, this.label});

  final IconData icon;
  final String? value;
  final String? hint;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final shown = value ?? hint ?? context.l10n.acadSelect;
    return Semantics(
      button: true,
      label: label,
      value: shown,
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
                child: Text(shown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.body.copyWith(color: value == null ? t.mut : t.ink))),
          ]),
        ),
      ),
    );
  }
}
