import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../profile/edit_profile_page.dart';
import 'akad_widgets.dart';

/// Akademik sayfaların ortak iskeleti: başlık + gövde (+ alta sabit eylem çubuğu).
/// Yeni sayfalar büyük başlıklı [BuPageScaffold] kullanır; bu iskelet gövdesi kendi kaydırmasını yöneten sayfalar içindir.
class AcademicScaffold extends StatelessWidget {
  const AcademicScaffold(
      {super.key, required this.title, required this.child, this.actions = const [], this.subtitle, this.bottomBar, this.floatingActionButton});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  /// Alta sabitlenen eylem çubuğu (içerik altına [AkadBottomBar.reserve] boşluk bırakır).
  final Widget? bottomBar;

  /// Yüzen eylem düğmesi (ör. Ders ekle).
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          Column(
            children: [
              _AkadHeader(title: title, subtitle: subtitle, actions: actions),
              Expanded(child: child),
            ],
          ),
          if (bottomBar != null) PositionedDirectional(start: 0, end: 0, bottom: 0, child: bottomBar!),
        ],
      ),
    );
  }
}

//// Üst başlık (referans): yüzey renkli çubuk, düz geri oku, başlık ve sağda eylemler.
class _AkadHeader extends StatelessWidget {
  const _AkadHeader({required this.title, required this.actions, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.sf, boxShadow: BuElevation.of(context, 1)),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(4, MediaQuery.paddingOf(context).top, 12, 0),
        child: SizedBox(
          height: 56,
          child: Row(children: [
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: context.l10n.commonBack,
              icon: Icon(buDirIcon(context, LucideIcons.arrowLeft), size: 24, color: t.ink),
              onPressed: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Semantics(
                  header: true,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                    if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                  ]),
                ),
              ),
            ),
            for (final a in actions) ...[const SizedBox(width: 8), a],
          ]),
        ),
      ),
    );
  }
}

// 503 (bakım) için bakım görünümü; diğer hatalarda [BuErrorState] (ağ yoksa "Bağlantı yok").
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

/// Onay diyaloğu: `true` = onaylandı. [danger] iken referanstaki silme diyaloğu (pembe simge dairesi, ortalı başlık,
/// yan yana "Vazgeç" + kırmızı eylem); aksi halde M3 [BuDialog].
Future<bool> confirmDialog(BuildContext context, {required String title, required String text, required String action, bool danger = false, IconData? icon}) async {
  if (!danger) {
    return BuDialog.confirm(
      context,
      title: title,
      message: text,
      confirmLabel: action,
      cancelLabel: context.l10n.acadCancel,
      icon: icon ?? LucideIcons.triangleAlert,
    );
  }
  final r = await BuDialog.show<bool>(
    context,
    builder: (ctx) {
      final t = ctx.bu;
      final tx = Theme.of(ctx).textTheme;
      return Dialog(
        backgroundColor: t.sf3,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                child: ExcludeSemantics(child: Icon(icon ?? LucideIcons.trash2, size: 24, color: t.pr)),
              ),
            ),
            const SizedBox(height: 14),
            Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: AkadTonalButton(label: ctx.l10n.acadCancel, onPressed: () => Navigator.pop(ctx, false))),
              const SizedBox(width: 10),
              Expanded(child: BuButton(label: action, icon: LucideIcons.trash2, onPressed: () => Navigator.pop(ctx, true))),
            ]),
          ]),
        ),
      );
    },
  );
  return r == true;
}

/// Marka renkli tarih seçici (M3): "Vazgeç" / "Seç"; seçilen gün ya da null.
Future<DateTime?> pickAcadDate(BuildContext context, {required DateTime initial, required DateTime first, required DateTime last, String? help}) {
  final l = context.l10n;
  return showDatePicker(
    context: context,
    initialDate: initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial),
    firstDate: first,
    lastDate: last,
    helpText: help ?? l.p17PickDateHelp,
    cancelText: l.acadCancel,
    confirmText: l.acadSelect,
    builder: (c, child) => Theme(data: _pickerTheme(c), child: child!),
  );
}

/// Seçici diyaloglarında "Seç" dolu marka düğmesi, "Vazgeç" koyu metin; gölge halkası yok.
ThemeData _pickerTheme(BuildContext context) {
  final t = context.bu;
  final base = Theme.of(context);
  final confirm = FilledButton.styleFrom(backgroundColor: t.pr, foregroundColor: t.onPr, minimumSize: const Size(72, 48));
  final cancel = TextButton.styleFrom(foregroundColor: t.ink, minimumSize: const Size(72, 48));
  return base.copyWith(
    datePickerTheme: base.datePickerTheme.copyWith(elevation: 0, confirmButtonStyle: confirm, cancelButtonStyle: cancel),
    timePickerTheme: base.timePickerTheme.copyWith(elevation: 0, confirmButtonStyle: confirm, cancelButtonStyle: cancel),
  );
}

/// Marka renkli saat seçici (M3, 24 saat): seçilen dakika (0..1439) ya da null.
Future<int?> pickAcadTime(BuildContext context, int current, {String? help}) async {
  final l = context.l10n;
  final r = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    helpText: help,
    cancelText: l.acadCancel,
    confirmText: l.acadSelect,
    builder: (c, child) => Theme(data: _pickerTheme(c), child: MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!)),
  );
  return r == null ? null : r.hour * 60 + r.minute;
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

/// "Profili düzenle": profili çekip düzenleme sayfasını açar (bölüm eksik uyarıları).
Future<void> openEditProfile(BuildContext context, Session session) async {
  try {
    final p = await session.api.get('/users/me') as Map<String, dynamic>;
    if (!context.mounted) return;
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EditProfilePage(session: session, profile: p)));
  } catch (e) {
    if (context.mounted) academicToast(context, errorText(e), kind: BuToastKind.error);
  }
}

/// Kart biçimli hata görünümü: 503 bakım notu, diğerleri hata kartı ("Yeniden dene").
class AcademicErrorViewCard extends StatelessWidget {
  const AcademicErrorViewCard({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e = error;
    final l = context.l10n;
    if (e is ApiError && e.status == 503) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AkadNoticeCard(text: e.message.isNotEmpty ? e.message : l.acadMaintenance),
        const SizedBox(height: 12),
        Align(alignment: AlignmentDirectional.centerEnd, child: BuButton(label: l.acadRetry, compact: true, kind: BuButtonKind.soft, onPressed: onRetry)),
      ]);
    }
    return AkadErrorCard(title: l.sistemuiErrorTitle, message: errorText(e), onRetry: onRetry, retryLabel: l.acadRetry);
  }
}
