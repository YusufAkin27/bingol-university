import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../../core/api.dart' show apiOrigin;
import '../../core/locale_controller.dart';
import '../../core/nav.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';

/// Çizim hatası ekranı (05/5): kırmızı çökme ekranının yerine geçer (yalnız release; `ErrorWidget.builder`).
/// Ağaç bozukken tema/yerelleştirme olmayabilir: belirteçler ve metinler güvenli yedeklerle çözülür.
class RenderErrorView extends StatelessWidget {
  const RenderErrorView({super.key, this.onRetry});

  /// "Yeniden dene": verilmezse ilk rotaya kadar geri dönülür.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Ağaçta yerelleştirme varsa onu kullan (uygulama dili); yoksa cihaz dilinden çöz.
    final l = AppLocalizations.of(context) ?? lookupAppLocalizations(resolveAppLocale('system', PlatformDispatcher.instance.locales));
    final theme = context.findAncestorWidgetOfExactType<Theme>()?.data;
    final dark = (theme?.brightness ?? PlatformDispatcher.instance.platformBrightness) == Brightness.dark;
    final t = theme?.extension<BuTokens>() ?? (dark ? BuTokens.dark : BuTokens.light);
    final tx = (theme ?? (dark ? BuTheme.dark() : BuTheme.light())).textTheme;
    final dir = Directionality.maybeOf(context) ?? (l.localeName == 'ar' ? TextDirection.rtl : TextDirection.ltr);
    return Directionality(
      textDirection: dir,
      child: Material(
        color: t.bg,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
                      child: Icon(LucideIcons.triangleAlert, size: 28, color: t.mut),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(l.commonSomethingWentWrong,
                      textAlign: TextAlign.center,
                      style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                  const SizedBox(height: 8),
                  Text(l.coreErrGeneric,
                      textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5, decoration: TextDecoration.none)),
                  const SizedBox(height: 24),
                  Semantics(
                    button: true,
                    label: l.commonRetry,
                    excludeSemantics: true,
                    child: Material(
                      color: t.pr,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: onRetry ??
                            () {
                              final nav = rootNavigatorKey.currentState;
                              if (nav != null && nav.canPop()) nav.popUntil((r) => r.isFirst);
                            },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Center(
                            child: Text(l.commonRetry,
                                style: tx.titleMedium!.copyWith(color: t.onPr, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yapılandırma hatası ekranı (05/6; yalnız geliştirici): API_BASE https değil. Düğme yok.
/// Tam adres yazılmaz (yalnız şema): yanlış derlemenin nedeni anlaşılır, adres sızmaz.
class ConfigErrorView extends StatelessWidget {
  const ConfigErrorView({super.key, this.origin = apiOrigin});

  final String origin;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final scheme = Uri.tryParse(origin)?.scheme ?? '';
    final shown = 'API_BASE=${scheme.isEmpty ? '' : '$scheme://'}...';
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: t.soft.withValues(alpha: .5), shape: BoxShape.circle),
                      child: Container(
                        width: 80,
                        height: 80,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(24)),
                        child: Icon(LucideIcons.shieldAlert, size: 36, color: t.pr),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(l.p01ConfigTitle,
                      textAlign: TextAlign.center, style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(l.p01ConfigBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.6)),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16), boxShadow: BuElevation.of(context, 1)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(l.p01ConfigCode,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tx.labelSmall!.copyWith(color: t.mut, letterSpacing: rtl ? 0 : 1.1, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          ExcludeSemantics(child: Icon(LucideIcons.squareTerminal, size: 16, color: t.mut)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: t.bd.withValues(alpha: .6), borderRadius: BorderRadius.circular(12)),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(shown, style: tx.bodyMedium!.copyWith(color: t.ink, fontFamily: 'monospace')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
