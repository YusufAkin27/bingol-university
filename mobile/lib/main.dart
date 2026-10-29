import 'dart:async';


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/analytics.dart';
import 'core/api.dart';
import 'core/app_gate.dart';
import 'core/app_hooks.dart';
import 'core/cache/disk_cache.dart';
import 'core/connectivity/connectivity_service.dart';
import 'core/connectivity/offline_banner.dart';
import 'core/crash/crash_reporter.dart';
import 'core/outbox/outbox.dart';
import 'core/locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/device_identity.dart';
import 'core/error_log.dart';
import 'core/nav.dart';
import 'core/push/push_service.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'core/theme_controller.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/auth/welcome_page.dart';
import 'features/auth/permissions_page.dart';
import 'features/legal/legal_reaccept_page.dart';
import 'features/shell/app_shell.dart';
import 'features/system/error_views.dart';
import 'features/system/gate_views.dart';
import 'features/system/splash_screen.dart';

/// Yakalanmamış hatayı yerel günlüğe (disk + bellek) ve — oturum açıksa — anonim `app_error` analitik
/// olayına yazar: yalnız hata türü, ekran adı ve sürüm; mesaj/yığın/kişisel veri yok ([ErrorLog]).
/// Ayrıca (ayar açıksa, yalnız release) maskelenmiş yığın izi kendi sunucumuza anonim raporlanır ([CrashReporter]).
void _reportError(Object error, StackTrace? stack, {String source = 'flutter'}) {
  ErrorLog.instance.report(error, source: source);
  CrashReporter.instance.capture(error, stack, source: source);
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
    _reportError(error, stack, source: 'platform');
    return true; // işlendi: süreç düşmez
  };
  if (release) ErrorWidget.builder = (_) => const RenderErrorView();
}

/// Release derlemede API_BASE https değilse (yanlış derleme) açılışta net hata gösterir (05/6; yalnız geliştirici).
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final l = lookupAppLocalizations(resolveAppLocale('system', PlatformDispatcher.instance.locales));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(l.localeName),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: BuTheme.light(),
      darkTheme: BuTheme.dark(),
      home: const ConfigErrorView(),
    );
  }
}

Future<void> main() async {
  // Çerçeve dışında kalan asenkron hatalar da kendi sunucumuza raporlanır (runZonedGuarded).
  await runZonedGuarded<Future<void>>(_bootstrap, (error, stack) => _reportError(error, stack, source: 'zone'));
}

Future<void> _bootstrap() async {
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
  unawaited(ErrorLog.instance.init());
  await CrashReporter.instance.init(); // ayar + bekleyen raporlar (hata fırlatmaz)
  await DeviceIdentity.instance.load(); // hata fırlatmaz; ilk istekten önce cihaz kimliği hazır
  final connectivity = ConnectivityService.instance;
  final api = ApiClient(diskCache: DiskCache(), connectivity: connectivity);
  final outbox = Outbox();
  api.outbox = outbox;
  CrashReporter.instance.attach(api);
  // Önceki oturumdan kalan raporlar, açılışla yarışmasın diye biraz sonra gönderilir.
  unawaited(Future<void>.delayed(const Duration(seconds: 8), CrashReporter.instance.flush));
  outbox.attach(api, connectivity);
  final session = Session(api);
  final theme = ThemeController();
  unawaited(theme.load());
  final localeCtl = LocaleController(onResolved: (c) => session.api.lang = c);
  LocaleController.current = localeCtl;
  unawaited(localeCtl.load());
  Analytics.instance.attach(session);
  final push = PushService(session);
  final hooks = AppLifecycleHooks.instance;
  hooks.onSignedIn.add((_) => push.onSignedIn()); // restore sonrası oturum açıksa bir kez tetiklenir
  hooks.onSignedIn.add((_) => outbox.load()); // bekleyen mesajlar yüklenir ve gönderilir (oturum açıkken)
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
  runApp(BingolApp(session: session, themeController: theme, push: push, localeController: localeCtl, outbox: outbox));
}

class BingolApp extends StatelessWidget {
  BingolApp({super.key, required this.session, required this.themeController, this.push, this.localeController, this.outbox});

  /// Çevrimdışı mesaj kuyruğu (null ise bekleyen mesaj şeridi gösterilmez).
  final Outbox? outbox;

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
        builder: (context, child) => AppGate(
          api: session.api,
          child: outbox == null || child == null
              ? child
              : OfflineBanner(outbox: outbox!, connectivity: session.api.connectivity, child: child),
        ),
        home: ListenableBuilder(
          listenable: Listenable.merge([session, session.accessBlocked]),
          builder: (context, _) => session.accessBlocked.value
              ? AccessBlockedScreen(onRetry: session.dismissAccessBlocked)
              : switch (session.state) {
                  SessionState.loading => const SplashScreen(),
                  SessionState.signedOut => _SignedOutRoot(session: session),
                  // İlk girişte (cihaz başına bir kez) izin sayfası; sonra kabuk.
                  SessionState.signedIn => PostLoginGate(
                      onNotificationsGranted: push == null ? null : () => push!.onSignedIn(),
                      // Yeni sözleşme sürümü onayı bekleniyorsa kabuğun üstüne tam ekran onay (ağ hatasında açılmaz).
                      child: LegalReacceptGate(
                        session: session,
                        child: AppShell(session: session, themeController: themeController),
                      ),
                    ),
                },
        ),
      ),
    );
  }
}

/// Çıkış yapmış kullanıcı: cihazda ilk kez açılıyorsa karşılama ekranı, sonrasında doğrudan giriş.
class _SignedOutRoot extends StatefulWidget {
  const _SignedOutRoot({required this.session});

  final Session session;

  @override
  State<_SignedOutRoot> createState() => _SignedOutRootState();
}

class _SignedOutRootState extends State<_SignedOutRoot> {
  static const _key = 'welcome_seen';
  final _storage = const FlutterSecureStorage();
  bool? _seen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var seen = true; // okunamazsa karşılama ile engelleme
    try {
      seen = (await _storage.read(key: _key)) == '1';
    } catch (_) {}
    if (mounted) setState(() => _seen = seen);
  }

  Future<void> _finish({required bool register}) async {
    try {
      await _storage.write(key: _key, value: '1');
    } catch (_) {}
    if (!mounted) return;
    setState(() => _seen = true);
    if (register) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegisterPage(session: widget.session)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final seen = _seen;
    // Karşılama -> giriş geçişi: kısa solma + hafif yukarı süzülme (200-300 ms).
    final Widget page = seen == null
        ? const SplashScreen()
        : !seen
            ? WelcomePage(onLogin: () => _finish(register: false), onRegister: () => _finish(register: true))
            : LoginPage(session: widget.session);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(anim), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(page.runtimeType), child: page),
    );
  }
}
