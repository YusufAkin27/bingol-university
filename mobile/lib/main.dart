import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/analytics.dart';
import 'core/api.dart';
import 'core/app_gate.dart';
import 'core/app_hooks.dart';
import 'core/nav.dart';
import 'core/push/push_service.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'core/theme_controller.dart';
import 'features/auth/login_page.dart';
import 'features/auth/permissions_page.dart';
import 'features/shell/app_shell.dart';

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
              const Text(
                'Bir şeyler ters gitti',
                textDirection: TextDirection.ltr,
                style: TextStyle(color: Colors.black87, fontSize: 16, decoration: TextDecoration.none),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  final nav = rootNavigatorKey.currentState;
                  if (nav != null && nav.canPop()) nav.popUntil((r) => r.isFirst);
                },
                child: const Text('Yeniden dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _installErrorHandling() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (kReleaseMode) {
      _reportError(details.exception, details.stack);
    } else {
      previous?.call(details); // debug/test: konsolda tam ayrıntı
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _reportError(error, stack);
    return true; // işlendi: süreç düşmez
  };
  if (kReleaseMode) ErrorWidget.builder = (_) => const _ErrorView();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandling();
  final session = Session(ApiClient());
  final theme = ThemeController();
  theme.load();
  Analytics.instance.attach(session);
  final push = PushService(session);
  final hooks = AppLifecycleHooks.instance;
  hooks.onSignedIn.add((_) => push.onSignedIn()); // restore sonrası oturum açıksa bir kez tetiklenir
  hooks.onSignedOut.add((_) => push.onSignedOut());
  session.beforeSignOut.add(push.onSignedOut); // cihaz kaydı, token geçerliyken silinir
  hooks.attach(session);
  session.restore();
  runApp(BingolApp(session: session, themeController: theme, push: push));
}

class BingolApp extends StatelessWidget {
  BingolApp({super.key, required this.session, required this.themeController, this.push});

  final Session session;

  /// İzin sayfasında bildirim izni verilince FCM kaydını başlatmak için.
  final PushService? push;
  final ThemeController themeController;
  final _observer = AnalyticsNavigatorObserver();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'BÜ Kampüs',
        debugShowCheckedModeBanner: false,
        navigatorKey: rootNavigatorKey,
        navigatorObservers: [_observer],
        theme: BuTheme.light(),
        darkTheme: BuTheme.dark(),
        themeMode: themeController.mode,
        builder: (context, child) => AppGate(api: session.api, child: child),
        home: ListenableBuilder(
          listenable: session,
          builder: (context, _) => switch (session.state) {
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
