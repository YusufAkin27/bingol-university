import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'akad_widgets.dart';

/// Akademik sayfaların ortak iskeleti: başlık + gövde (+ alta sabit eylem çubuğu).
/// Yeni sayfalar büyük başlıklı [BuPageScaffold] kullanır; bu iskelet gövdesi kendi kaydırmasını yöneten sayfalar içindir.
class AcademicScaffold extends StatelessWidget {
  const AcademicScaffold({super.key, required this.title, required this.child, this.actions = const [], this.subtitle, this.bottomBar});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  /// Alta sabitlenen eylem çubuğu (içerik altına [AkadBottomBar.reserve] boşluk bırakır).
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
          if (bottomBar != null) PositionedDirectional(start: 0, end: 0, bottom: 0, child: bottomBar!),
        ],
      ),
    );
  }
}

/// Üst başlık: tonal yuvarlak geri düğmesi + başlık (headlineSmall) + sağda eylemler.
class _AkadHeader extends StatelessWidget {
  const _AkadHeader({required this.title, required this.actions, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20, MediaQuery.paddingOf(context).top + 12, 20, 0),
      child: Row(children: [
        BuIconButton(icon: LucideIcons.arrowLeft, tooltip: context.l10n.commonBack, onTap: () => Navigator.maybePop(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.35,
              child: Semantics(
                header: true,
                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.headlineSmall!.copyWith(color: t.ink)),
              ),
            ),
            if (subtitle != null) Text(subtitle!, style: tx.bodySmall!.copyWith(color: t.mut)),
          ]),
        ),
        for (final a in actions) ...[const SizedBox(width: 8), a],
      ]),
    );
  }
}

/// 503 (bakım) için bakım görünümü; diğer hatalarda [BuErrorState] (ağ yoksa "Bağlantı yok").
class AcademicErrorView extends StatelessWidget {
  const AcademicErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e = error;
    final l = context.l10n;
    if (e is ApiError && e.status == 503) {
      return BuEmptyState(
        illustration: BuIllustration.alert,
        title: l.p17MaintenanceTitle,
        message: e.message.isNotEmpty ? e.message : l.acadMaintenance,
        actionLabel: l.acadRetry,
        onAction: onRetry,
      );
    }
    return BuErrorState(error: error, onRetry: onRetry);
  }
}

/// Renk çubuklu ders/sınav kartı kabuğu: kart yüzeyi ders renginin tonu, başlangıç kenarında renk şeridi.
/// [muted] true: geçmiş öğe (yüzey nötr, şerit soluk).
class ColorCard extends StatelessWidget {
  const ColorCard({super.key, required this.color, required this.child, this.onTap, this.semanticLabel, this.muted = false});

  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bg = muted ? t.sf2 : akadTint(context, color);
    final bar = muted ? color.withValues(alpha: .45) : color;
    final card = Material(
      color: bg,
      shape: BuRadius.rect(BuRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                buHaptic(BuHaptic.selection);
                onTap!();
              },
        child: Stack(children: [
          Padding(padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 14, 12), child: child),
          PositionedDirectional(start: 0, top: 0, bottom: 0, width: 6, child: ColoredBox(color: bar)),
        ]),
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: onTap == null ? card : BuPressable(scale: .985, child: card),
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
        ExcludeSemantics(child: Icon(icon, size: 14, color: t.mut)),
        const SizedBox(width: 6),
        Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut))),
      ]),
    );
  }
}

/// Onay diyaloğu (M3 [BuDialog]): `true` = onaylandı. [danger] kırmızı vurgu + çöp simgesi; [icon] ile ezilir.
Future<bool> confirmDialog(BuildContext context, {required String title, required String text, required String action, bool danger = false, IconData? icon}) {
  return BuDialog.confirm(
    context,
    title: title,
    message: text,
    confirmLabel: action,
    cancelLabel: context.l10n.acadCancel,
    destructive: danger,
    icon: icon ?? (danger ? LucideIcons.trash2 : LucideIcons.triangleAlert),
  );
}

/// Kısa bildirim ([BuToast]); varsayılan bilgi, hata için [kind] verin.
void academicToast(BuildContext context, String m, {BuToastKind kind = BuToastKind.info}) => BuToast.show(context, m, kind: kind);

/// Form etiketi.
class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 6, top: 2),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: context.bu.mut)),
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
      child: BuPressable(
        onTap: onTap,
        haptic: BuHaptic.selection,
        scale: .98,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bMd, border: Border.all(color: t.bd)),
          child: Row(children: [
            Icon(icon, size: 18, color: t.mut),
            const SizedBox(width: 10),
            Expanded(
                child: Text(shown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: value == null ? t.mut : t.ink))),
          ]),
        ),
      ),
    );
  }
}
