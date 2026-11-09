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
    final l = AppLocalizations.of(context) ??
        lookupAppLocalizations(
            resolveAppLocale('system', PlatformDispatcher.instance.locales));
    final theme = context.findAncestorWidgetOfExactType<Theme>()?.data;
    final dark =
        (theme?.brightness ?? PlatformDispatcher.instance.platformBrightness) ==
            Brightness.dark;
    final t =
        theme?.extension<BuTokens>() ?? (dark ? BuTokens.dark : BuTokens.light);
    final tx = (theme ?? (dark ? BuTheme.dark() : BuTheme.light())).textTheme;
    final dir = Directionality.maybeOf(context) ??
        (l.localeName == 'ar' ? TextDirection.rtl : TextDirection.ltr);
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
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration:
                          BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                      child:
                          Icon(BuIcons.triangleAlert, size: 48, color: t.ink),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(l.commonSomethingWentWrong,
                      textAlign: TextAlign.center,
                      style: tx.headlineSmall!.copyWith(
                          color: t.ink,
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.none)),
                  const SizedBox(height: 8),
                  Text(l.coreErrGeneric,
                      textAlign: TextAlign.center,
                      style: tx.bodyMedium!.copyWith(
                          color: t.mut,
                          height: 1.5,
                          decoration: TextDecoration.none)),
                  const SizedBox(height: 24),
                  Semantics(
                    button: true,
                    label: l.commonRetry,
                    excludeSemantics: true,
                    child: Material(
                      color: t.sf,
                      shape: RoundedRectangleBorder(
                          borderRadius: BuRadius.bControl,
                          side: BorderSide(color: t.bdStrong)),
                      child: InkWell(
                        borderRadius: BuRadius.bControl,
                        onTap: onRetry ??
                            () {
                              final nav = rootNavigatorKey.currentState;
                              if (nav != null && nav.canPop()) {
                                nav.popUntil((r) => r.isFirst);
                              }
                            },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Center(
                            child: Text(l.commonRetry,
                                style: tx.titleMedium!.copyWith(
                                    color: t.ink,
                                    fontWeight: FontWeight.w400,
                                    decoration: TextDecoration.none)),
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

/// Uygulama hizmete baglanamiyorsa teknik ayrinti icermeyen kullanici ekrani.
class ConfigErrorView extends StatelessWidget {
  const ConfigErrorView({super.key, this.origin = apiOrigin});

  // Teshis/test icin tutulur; adres veya sema arayuzde gosterilmez.
  final String origin;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ExcludeSemantics(
                child: Icon(BuIcons.cloudOff, size: 64, color: t.mut)),
            const SizedBox(height: 24),
            Semantics(
                header: true,
                child: Text(l.p01ConfigTitle,
                    textAlign: TextAlign.center,
                    style: tx.headlineSmall!.copyWith(color: t.ink))),
            const SizedBox(height: 12),
            Text(l.p01ConfigBody,
                textAlign: TextAlign.center,
                style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.6)),
          ]),
        ),
      ))),
    );
  }
}
