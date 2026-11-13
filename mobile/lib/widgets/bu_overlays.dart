import 'dart:async';

import 'package:flutter/material.dart';

import '../core/locale_controller.dart';
import '../core/motion/bu_motion_styles.dart';
import '../core/theme.dart';
import '../core/theme/bu_motion.dart';
import '../core/theme/bu_shape.dart';
import 'bu_pressable.dart';
import 'bu_widgets.dart';
import '../core/icons/bu_icons.dart';

// Ortak hareket eklemeleri (D1) tasarım sistemi tek içe aktarmasıyla (`widgets/bu.dart` -> bu_overlays) gelir.
export '../core/motion/bu_count_up.dart';
export '../core/motion/bu_motion_styles.dart';
export '../core/motion/bu_swap_in.dart';

/// Alt sayfa çerçevesi: sürükleme tutamacı (`BuSheet.show` ekler), isteğe bağlı başlık/alt başlık, kaydırılabilir gövde,
/// sabit alt eylem alanı, klavye ve güvenli alan payı. Hazır çerçeve: elle `Container + Column` ile alt sayfa çizmeyin.
class BuBottomSheet extends StatelessWidget {
  const BuBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 8),
    this.scrollable = true,
  });

  final String? title;
  final String? subtitle;
  final Widget child;

  /// Sabit alt eylemler (genelde düğmeler); gövde kayarken yerinde kalır.
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;

  /// false: gövde kendi kaydırmasını yönetir (ListView/DraggableScrollable içeren sayfalar).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final body = Padding(padding: padding, child: child);
    return AnimatedPadding(
      duration: BuMotion.of(context, const Duration(milliseconds: 120)),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(title!, style: tx.titleLarge!.copyWith(color: t.ink))),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: tx.bodyMedium!.copyWith(color: t.mut)),
                    ],
                  ],
                ),
              ),
            if (scrollable) Flexible(child: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, child: body)) else Flexible(child: body),
            if (actions != null && actions!.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[if (i > 0) const SizedBox(height: 8), actions![i]],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `showModalBottomSheet` çerçevesi: tutamaç + köşe + azami yükseklik + klavye payı tek yerde.
abstract final class BuSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    String? title,
    String? subtitle,
    List<Widget>? actions,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useRootNavigator = true,
    bool scrollable = true,
    double maxHeightFactor = .92,
    EdgeInsetsGeometry? padding,
  }) {
    final maxH = MediaQuery.sizeOf(context).height * maxHeightFactor;
    // Açılırken klavye kapalıysa, alt sayfadaki alanın odağı kapanışta temizlenir (klavye geride açık kalmaz).
    final kbWasOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: BuMotionStyles.sheet(context),
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useRootNavigator: useRootNavigator,
      constraints: BoxConstraints(maxHeight: maxH),
      builder: (ctx) => BuBottomSheet(
        title: title,
        subtitle: subtitle,
        actions: actions,
        scrollable: scrollable,
        padding: padding ?? const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 8),
        child: builder(ctx),
      ),
    ).whenComplete(() {
      if (!kbWasOpen) FocusManager.instance.primaryFocus?.unfocus();
    });
  }
}

/// Onay alt sayfası: ikon + başlık + açıklama + iki düğme. `true` = onaylandı, `false`/`null` = vazgeçildi.
abstract final class BuConfirmSheet {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? message,
    required String confirmLabel,
    String? cancelLabel,
    bool destructive = false,
    IconData? icon,
  }) async {
    final l = context.l10n;
    final r = await BuSheet.show<bool>(
      context,
      builder: (ctx) {
        final t = ctx.bu;
        final tx = Theme.of(ctx).textTheme;
        final accent = destructive ? t.danger : t.ink;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ExcludeSemantics(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: destructive ? t.dangerSoft : t.sf2,
                    border: Border.all(color: destructive ? t.danger.withValues(alpha: .25) : t.bdSubtle),
                    borderRadius: BuRadius.bMd,
                  ),
                  child: Icon(icon ?? (destructive ? BuIcons.trash2 : BuIcons.circleHelp), size: 28, color: accent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(title, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink)),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
            ],
            const SizedBox(height: 24),
            BuButton(
              label: confirmLabel,
              kind: destructive ? BuButtonKind.danger : BuButtonKind.primary,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 8),
            // Stitch profil-v4: "Vazgeç" düz gri metin düğmesi (vurgu rengi değil).
            TextButton(
              style: TextButton.styleFrom(foregroundColor: t.mut, minimumSize: const Size.fromHeight(48)),
              onPressed: () {
                buHaptic(BuHaptic.selection);
                Navigator.of(ctx).pop(false);
              },
              child: Text(cancelLabel ?? l.commonCancel, style: tx.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: t.mut)),
            ),
          ],
        );
      },
    );
    return r ?? false;
  }
}

enum BuDialogActionKind { normal, primary, destructive }

/// Diyalog eylem düğmesi (satır içi boyut, 48 dp dokunma alanı). `actions:` listesine konur.
class BuDialogAction extends StatelessWidget {
  const BuDialogAction({super.key, required this.label, required this.onPressed, this.kind = BuDialogActionKind.normal});

  final String label;
  final VoidCallback? onPressed;
  final BuDialogActionKind kind;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const min = Size(64, 48);
    return switch (kind) {
      BuDialogActionKind.normal => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(foregroundColor: context.bu.mut, minimumSize: min),
          child: Text(label),
        ),
      BuDialogActionKind.primary => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(minimumSize: min, padding: const EdgeInsets.symmetric(horizontal: 20)),
          child: Text(label),
        ),
      BuDialogActionKind.destructive => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: min,
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: Text(label),
        ),
    };
  }
}

/// Diyalog (tema: `sf3` yüzey + ince kenarlık, köşe 20, gölgesiz). 25 elle yazılmış `AlertDialog` bunun yerine geçer.
///
/// ```dart
/// final ok = await BuDialog.confirm(context, title: 'Çıkış yapılsın mı?', confirmLabel: 'Çıkış yap', destructive: true);
/// ```
class BuDialog extends StatelessWidget {
  const BuDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.icon,
    this.actions = const [],
    this.destructive = false,
  });

  final String title;
  final String? message;

  /// [message] yerine/ek özel gövde (form alanı vb.).
  final Widget? content;
  final IconData? icon;
  final List<Widget> actions;

  /// Simge ve vurgu kırmızı (silme/çıkış onayı).
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    // Açılışta hafif ölçek (0.94 -> 1); solma showDialog geçişinden gelir. Hareket azaltılmışsa anında.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.94, end: 1),
      duration: BuMotion.of(context, BuMotion.medium),
      curve: BuMotion.emphasizedDecelerate,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: AlertDialog(
      icon: icon == null ? null : Icon(icon, size: 28, color: destructive ? t.danger : t.ink),
      title: Text(title, textAlign: icon == null ? TextAlign.start : TextAlign.center),
      content: (message == null && content == null)
          ? null
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: icon == null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  if (message != null)
                    Text(message!,
                        textAlign: icon == null ? TextAlign.start : TextAlign.center,
                        style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
                  if (content != null) ...[if (message != null) const SizedBox(height: 12), content!],
                ],
              ),
            ),
      actions: actions,
    ));
  }

  /// Özel diyalog göster.
  static Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder, bool barrierDismissible = true}) =>
      showDialog<T>(
          context: context,
          barrierDismissible: barrierDismissible,
          animationStyle: BuMotionStyles.dialog(context),
          builder: builder);

  /// Evet/Hayır onayı: `true` = onaylandı.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    required String confirmLabel,
    String? cancelLabel,
    bool destructive = false,
    IconData? icon,
  }) async {
    final l = context.l10n;
    final r = await showDialog<bool>(
      context: context,
      animationStyle: BuMotionStyles.dialog(context),
      builder: (ctx) => BuDialog(
        title: title,
        message: message,
        icon: icon,
        destructive: destructive,
        actions: [
          BuDialogAction(label: cancelLabel ?? l.commonCancel, onPressed: () => Navigator.of(ctx).pop(false)),
          BuDialogAction(
            label: confirmLabel,
            kind: destructive ? BuDialogActionKind.destructive : BuDialogActionKind.primary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  /// Tek düğmeli bilgi diyaloğu.
  static Future<void> info(BuildContext context, {required String title, String? message, required String okLabel, IconData? icon}) =>
      showDialog<void>(
        context: context,
        animationStyle: BuMotionStyles.dialog(context),
        builder: (ctx) => BuDialog(
          title: title,
          message: message,
          icon: icon,
          actions: [BuDialogAction(label: okLabel, kind: BuDialogActionKind.primary, onPressed: () => Navigator.of(ctx).pop())],
        ),
      );
}

enum BuToastKind { info, success, error, warning }

/// SnackBar içeriğini sarar: [duration] dolunca şeridi KAPATIR. Flutter eylem düğmeli SnackBar'ı kalıcı sayar ya da
/// erişilebilirlik kipinde süreyi yok sayabilir; bu koruma her durumda kapanmayı garanti eder. Zamanlayıcı widget
/// yaşam döngüsüne bağlıdır (şerit/ağaç kalkınca iptal olur, bekleyen zamanlayıcı kalmaz).
class BuToastGuard extends StatefulWidget {
  const BuToastGuard({super.key, required this.duration, required this.messenger, required this.child});

  final Duration duration;
  final ScaffoldMessengerState messenger;
  final Widget child;

  @override
  State<BuToastGuard> createState() => _BuToastGuardState();
}

class _BuToastGuardState extends State<BuToastGuard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) widget.messenger.hideCurrentSnackBar();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Alt bildirim (SnackBar) yardımcısı: simge + metin + isteğe bağlı eylem; eskisini kapatır, ekran okuyucuya duyurur.
///
/// Geçici mesajlar varsayılan 2 sn görünür ve yumuşak solarak kapanır; hiçbir koşulda ekranda takılı kalmaz:
/// Flutter 3.29+ eylem düğmeli SnackBar'ı varsayılan olarak KALICI yapar (`persist`), bu yüzden `persist: false` zorlanır
/// ve ayrıca bir zamanlayıcı yedeği ([autoClose]) vardır (erişilebilirlik kipi vb. süreyi yok saysa bile kapanır).
abstract final class BuToast {
  /// Geçici başarı/bilgi/basit hata mesajı süresi.
  static const Duration defaultDuration = Duration(seconds: 2);

  static void show(
    BuildContext context,
    String message, {
    BuToastKind kind = BuToastKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    Color? actionColor,
    Duration duration = defaultDuration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    // Şerit tema yüzeyidir (`sf3` + ince kenarlık, bkz. snackBarTheme): simge renkleri aynı temanın anlamsal tonlarıdır.
    final inv = context.bu;
    final (icon, color) = switch (kind) {
      BuToastKind.info => (BuIcons.info, inv.mut),
      BuToastKind.success => (BuIcons.circleCheck, inv.ok),
      BuToastKind.error => (BuIcons.circleAlert, inv.danger),
      BuToastKind.warning => (BuIcons.triangleAlert, inv.warn),
    };
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
        snackBarAnimationStyle: BuMotionStyles.toast(context),
        SnackBar(
          duration: duration,
          persist: false,
          content: BuToastGuard(
            duration: duration,
            messenger: messenger,
            child: Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  ExcludeSemantics(child: Icon(icon, size: 20, color: color)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message)),
                ],
              ),
            ),
          ),
          action: actionLabel == null ? null : SnackBarAction(label: actionLabel, textColor: actionColor, onPressed: onAction ?? () {}),
        ),
      );
    buHaptic(kind == BuToastKind.error ? BuHaptic.light : BuHaptic.none);
  }
}
