import 'dart:async';


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/analytics.dart';
import 'core/api.dart';
import 'core/app_gate.dart';
import 'core/app_hooks.dart';
import 'core/locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/device_identity.dart';
import 'core/nav.dart';
import 'core/push/push_service.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'core/theme_controller.dart';
import 'features/auth/login_page.dart';
import 'features/auth/permissions_page.dart';
import 'features/shell/app_shell.dart';
import 'features/system/gate_views.dart';

/// Yakalanmamış hatayı yalnızca tür adıyla (kişisel veri/mesaj içermeden) analitiğe yazar.
void _reportError(Object error, StackTrace? stack) {
  debugPrint('Yakalanmayan hata: ${error.runtimeType}');
  try {
    Analytics.instance.track('app_error', props: {'type': error.runtimeType.toString()});
  } catch (_) {}
}

/// Hata ağaçta çizim yapamadığında kırmızı ekran yerine sade bir görünüm (yalnız release).
class _ErrorView extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context) {
    // Ağaç bozukken Localizations yok olabilir: cihaz dilinden doğrudan çözülür.
    final l = lookupAppLocalizations(resolveAppLocale('system', PlatformDispatcher.instance.locales));
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36, color: Colors.black54),
              const SizedBox(height: 12),
              Text(
                l.commonSomethingWentWrong,
                textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
                style: const TextStyle(color: Colors.black87, fontSize: 16, decoration: TextDecoration.none),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  final nav = rootNavigatorKey.currentState;
                  if (nav != null && nav.canPop()) nav.popUntil((r) => r.isFirst);
                },
                child: Text(l.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
void installErrorHandling({bool release = kReleaseMode}) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (release) {
      _reportError(details.exception, details.stack);
    } else {
      previous?.call(details); // debug/test: konsolda tam ayrıntı
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _reportError(error, stack);
    return true; // işlendi: süreç düşmez
  };
  if (release) ErrorWidget.builder = (_) => const _ErrorView();
}

/// Release derlemede API_BASE https değilse (yanlış derleme) açılışta net hata gösterir.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final l = lookupAppLocalizations(resolveAppLocale('system', PlatformDispatcher.instance.locales));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(l.localeName),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l.configError,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!apiConfigValid()) {
    runApp(const ConfigErrorApp());
    return;
  }
  // Telefonda dikey kilit; tablet (kısa kenar >= 600dp) serbest.
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  if (view.physicalSize.shortestSide / view.devicePixelRatio < 600) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }
  installErrorHandling();
  await DeviceIdentity.instance.load(); // hata fırlatmaz; ilk istekten önce cihaz kimliği hazır
  final session = Session(ApiClient());
  final theme = ThemeController();
  unawaited(theme.load());
  final localeCtl = LocaleController(onResolved: (c) => session.api.lang = c);
  LocaleController.current = localeCtl;
  unawaited(localeCtl.load());
  Analytics.instance.attach(session);
  final push = PushService(session);
  final hooks = AppLifecycleHooks.instance;
  hooks.onSignedIn.add((_) => push.onSignedIn()); // restore sonrası oturum açıksa bir kez tetiklenir
  hooks.onSignedOut.add((_) => push.onSignedOut());
  // Sunucu profil dili uygulama diliyle eşitlenir (bildirim/e-posta dili).
  hooks.onSignedIn.add((_) async {
    try {
      await session.api.patch('/users/me', {'language': localeCtl.locale.languageCode});
    } catch (_) {}
  });
  session.beforeSignOut.add(push.onSignedOut); // cihaz kaydı, token geçerliyken silinir
  hooks.attach(session);
  unawaited(session.restore());
  runApp(BingolApp(session: session, themeController: theme, push: push, localeController: localeCtl));
}

class BingolApp extends StatelessWidget {
  BingolApp({super.key, required this.session, required this.themeController, this.push, this.localeController});

  final LocaleController? localeController;

  final Session session;

  /// İzin sayfasında bildirim izni verilince FCM kaydını başlatmak için.
  final PushService? push;
  final ThemeController themeController;
  final _observer = AnalyticsNavigatorObserver();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeController, if (localeController != null) localeController!]),
      builder: (context, _) => MaterialApp(
        locale: localeController?.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        onGenerateTitle: (_) => 'BÜ Kampüs',
        title: 'BÜ Kampüs',
        debugShowCheckedModeBanner: false,
        navigatorKey: rootNavigatorKey,
        navigatorObservers: [_observer],
        theme: BuTheme.light(),
        darkTheme: BuTheme.dark(),
        themeMode: themeController.mode,
        builder: (context, child) => AppGate(api: session.api, child: child),
        home: ListenableBuilder(
          listenable: Listenable.merge([session, session.accessBlocked]),
          builder: (context, _) => session.accessBlocked.value
              ? AccessBlockedScreen(onRetry: session.dismissAccessBlocked)
              : switch (session.state) {
                  SessionState.loading => const _Splash(),
                  SessionState.signedOut => LoginPage(session: session),
                  // İlk girişte (cihaz başına bir kez) izin sayfası; sonra kabuk.
                  SessionState.signedIn => PostLoginGate(
                      onNotificationsGranted: push == null ? null : () => push!.onSignedIn(),
                      child: AppShell(session: session, themeController: themeController),
                    ),
                },
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
