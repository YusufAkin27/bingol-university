import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/locale_controller.dart';
import '../core/session.dart' show errorText;
import '../core/theme.dart';
import '../core/theme/bu_motion.dart';
import '../core/theme/bu_shape.dart';
import 'bu_illustrations.dart';
import 'bu_widgets.dart';

/// Sınırlı yükseklikte ortalar, sığmazsa (320 dp + büyük yazı) kaydırır; sınırsızda (ListView içinde) düz ortalar.
class _FitCenter extends StatelessWidget {
  const _FitCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => c.hasBoundedHeight
            ? SingleChildScrollView(
                child: ConstrainedBox(constraints: BoxConstraints(minHeight: c.maxHeight), child: Center(child: child)),
              )
            : Center(child: child),
      );
}

/// Durum içeriği belirirken bir kez (yumuşak yükselme + solma). Hareket azaltılmışsa anında.
class _Enter extends StatelessWidget {
  const _Enter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (BuMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: BuMotion.long,
      curve: BuMotion.emphasizedDecelerate,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: child),
      ),
      child: child,
    );
  }
}

/// Boş durum: kodla çizilmiş illüstrasyon + başlık + açıklama + isteğe bağlı eylem(ler).
///
/// ```dart
/// BuEmptyState(
///   illustration: BuIllustration.message,
///   title: l10n.chatEmptyTitle,
///   message: l10n.chatEmptyBody,
///   actionLabel: l10n.chatStart, onAction: _newChat,
/// )
/// ```
class BuEmptyState extends StatelessWidget {
  const BuEmptyState({
    super.key,
    required this.title,
    this.message,
    this.illustration = BuIllustration.box,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
  });

  final String title;
  final String? message;

  /// Çizili illüstrasyon (varsayılan); [icon] verilirse yerine ikon karosu gösterilir.
  final BuIllustration illustration;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Liste içi küçük boş durum (daha küçük çizim, dar boşluk).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return _FitCenter(
      child: _Enter(
        child: Padding(
          padding: EdgeInsets.all(compact ? 20 : 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  ExcludeSemantics(
                    child: Container(
                      width: compact ? 64 : 80,
                      height: compact ? 64 : 80,
                      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.xl)),
                      child: Icon(icon, size: compact ? 28 : 34, color: t.pr),
                    ),
                  )
                else
                  BuIllustrationView(illustration, size: compact ? 96 : 132),
                SizedBox(height: compact ? 12 : 20),
                Semantics(
                  header: true,
                  child: Text(title, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink)),
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(message!, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
                ],
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(height: compact ? 14 : 22),
                  SizedBox(width: 220, child: BuButton(label: actionLabel!, onPressed: onAction)),
                ],
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(height: 4),
                  BuButton(label: secondaryLabel!, onPressed: onSecondary, kind: BuButtonKind.text, compact: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hata durumu + "Yeniden dene". [error] bir `ApiError` ağ hatasıysa "Bağlantı yok" görünümü, aksi halde genel hata.
/// [title]/[message] verilirse varsayılanı ezer.
class BuErrorState extends StatelessWidget {
  const BuErrorState({super.key, this.error, this.title, this.message, required this.onRetry, this.compact = false});

  final Object? error;
  final String? title;
  final String? message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final net = error is ApiError && (error! as ApiError).isNetwork;
    final body = message ?? (error != null ? errorText(error!) : l.sistemuiOfflineBody);
    return _FitCenter(
      child: _Enter(
        child: Padding(
          padding: EdgeInsets.all(compact ? 20 : 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BuIllustrationView(net ? BuIllustration.wifiOff : BuIllustration.alert, size: compact ? 96 : 132),
                SizedBox(height: compact ? 12 : 20),
                Semantics(
                  header: true,
                  child: Text(title ?? (net ? l.sistemuiOfflineTitle : l.sistemuiErrorTitle),
                      textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink)),
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(body, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
                ),
                SizedBox(height: compact ? 14 : 22),
                SizedBox(
                  width: 220,
                  child: BuButton(label: l.commonRetry, icon: LucideIcons.refreshCw, onPressed: onRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// İnce çevrimdışı şeridi: "İnternet bağlantısı yok" + (isteğe bağlı) "Kayıtlı veriler gösteriliyor" + yeniden dene.
/// Ekranın üstüne (gövdenin başına) koyun; içerik silinmez, eski veri sunulur.
class BuOfflineBanner extends StatelessWidget {
  const BuOfflineBanner({super.key, this.message, this.showCachedHint = true, this.onRetry, this.margin});

  /// Verilirse başlık yerine bu metin gösterilir.
  final String? message;

  /// "Kayıtlı veriler gösteriliyor" ikinci satırı.
  final bool showCachedHint;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        margin: margin ?? const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
        decoration: BoxDecoration(color: t.warnSoft, borderRadius: BuRadius.bMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ExcludeSemantics(child: Icon(LucideIcons.wifiOff, size: 18, color: t.onWarnSoft)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message ?? l.cevrimdisiInternetYok,
                            style: tx.labelLarge!.copyWith(color: t.onWarnSoft, fontWeight: FontWeight.w700)),
                        if (showCachedHint && message == null)
                          Text(l.cevrimdisiKayitliVeri, style: tx.bodySmall!.copyWith(color: t.onWarnSoft)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (onRetry != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(foregroundColor: t.onWarnSoft, minimumSize: const Size(48, 48)),
                  child: Text(l.cevrimdisiYenidenDene),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
